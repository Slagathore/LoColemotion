import copy
import struct
import unittest
import queue
import hashlib
import json
import os
from pathlib import Path
import uuid
from types import SimpleNamespace

from audit_live_godot import controls_valid, kicks_valid


def sample():
    commands=[dict(actuator_id=str(i),target_velocity_rad_s=.1,maximum_target_speed_rad_s=3.5) for i in range(8)]
    motors=[dict(actuator_id=str(i),controller_target_velocity_rad_s=.1,host_applied_target_velocity_rad_s=.1,
                 motor_target_velocity_readback_rad_s=struct.unpack('<f',struct.pack('<f',.1))[0],
                 declared_maximum_impulse_nms=1,motor_maximum_impulse_readback_nms=1,host_additional_clamp_applied=False) for i in range(8)]
    return dict(local_step=2,global_step=243,request=dict(state=dict(semantic_step=2)),
                native_output=dict(actuation=dict(semantic_step=2,safe_no_actuation=False,failure_codes=[],ordered_commands=commands),next_memory=dict(last_semantic_step=2)),
                application=dict(ok=True,semantic_step=2,applied_command_count=8,ordered_applications=motors,authorized_maximum_impulse_by_actuator_id={str(i):1 for i in range(8)}))


class LiveAudit(unittest.TestCase):
    def test_isolated_source_refuses_changed_missing_extra_and_escape(self):
        from studio_layout import EVIDENCE,SCHEMA,verify_source
        root=Path(os.environ.get('EXPLORER_TEST_OUTPUT',EVIDENCE))/('studio-layout-check-'+uuid.uuid4().hex)
        root.mkdir();source=root/'entry.py';source.write_bytes(b'qualified source\n')
        record=dict(schema_version=SCHEMA,source_commit='a'*40,release_authority=False,physical_acceptance_authority=False,
                    files=[dict(path='entry.py',byte_length=source.stat().st_size,sha256=hashlib.sha256(source.read_bytes()).hexdigest())])
        manifest=root/'studio-layout.json'
        manifest.write_text(json.dumps(record))
        self.assertEqual(verify_source(root=root),'a'*40)
        source.write_bytes(b'changed\n')
        with self.assertRaises(ValueError):verify_source(root=root)
        source.write_bytes(b'qualified source\n');extra=root/'extra.py';extra.write_text('unexpected')
        with self.assertRaises(ValueError):verify_source(root=root)
        extra.unlink();source.rename(root/'moved.py')
        with self.assertRaises(ValueError):verify_source(root=root)
        (root/'moved.py').rename(source)
        for field,value in [('release_authority',True),('source_commit','invalid')]:
            manifest.write_text(json.dumps(dict(record,**{field:value})))
            with self.assertRaises(ValueError):verify_source(root=root)
        record['files'][0]['path']='../entry.py';manifest.write_text(json.dumps(record))
        with self.assertRaises(ValueError):verify_source(root=root)

    def test_desktop_audit_rejects_crossed_event_and_clock(self):
        from audit_godot_interaction import audit_rows
        command=dict(command_id='a',magnitude=.25,direction='right')
        native=dict(command_id='a',impulse_n_s=dict(x=0,y=0,z=.25),apply_at_frame=900)
        ui=dict(command_id='a',session_id='live',applied_frame=900,ui_pressed_ticks_usec=1000,ui_observed_ticks_usec=21000,button_to_observed_application_ms=20)
        self.assertEqual(audit_rows([command],[native],[ui],'live')[0]['button_to_observed_application_ms'],20)
        for field,value in [('session_id','stale'),('applied_frame',901),('command_id','crossed'),('button_to_observed_application_ms',19),('ui_observed_ticks_usec',999)]:
            with self.assertRaises(ValueError,msg=field):audit_rows([command],[native],[dict(ui,**{field:value})],'live')
        with self.assertRaises(ValueError):audit_rows([dict(command,direction='left')],[native],[ui],'live')

    def test_desktop_refuses_stale_setup_and_excess_commands(self):
        from studio_owner import StudioOwner
        owner=object.__new__(StudioOwner)
        owner.session_thread=SimpleNamespace(is_alive=lambda:True)
        owner.status=dict(engine='godot_jolt',state='running',native_session='live')
        owner.frame=dict(session_id='live',frame_index=241)
        owner.godot_command_ids=set();owner.commands=queue.Queue()
        kick=dict(kind='kick',command_id='first',magnitude=.25,direction='right')
        with self.assertRaises(ValueError):owner.command(kick)
        owner.frame=dict(session_id='stale',frame_index=242)
        with self.assertRaises(ValueError):owner.command(kick)
        owner.frame['session_id']='live'
        owner.command(kick)
        self.assertEqual(owner.commands.get_nowait()['command_id'],'first')
        with self.assertRaises(ValueError):owner.command(kick)
        owner.godot_command_ids={str(i) for i in range(16)}
        with self.assertRaises(ValueError):owner.command(kick)
        self.assertTrue(owner.commands.empty())

    def test_native_float_projection_and_refusals(self):
        controls_valid([sample()],241,2)
        for key,value in [('motor_target_velocity_readback_rad_s',.1),('motor_maximum_impulse_readback_nms',.9),('host_applied_target_velocity_rad_s',.2),('host_additional_clamp_applied',True),('actuator_id','crossed')]:
            row=sample();row['application']['ordered_applications'][0][key]=value
            with self.assertRaises(ValueError,msg=key):controls_valid([row],241,2)

    def test_crossed_controller_clocks_and_safety(self):
        for key in ['semantic_step','safe_no_actuation','failure_codes']:
            row=sample();row['native_output']['actuation'][key]={'semantic_step':1,'safe_no_actuation':True,'failure_codes':['refused']}[key]
            with self.assertRaises(ValueError,msg=key):controls_valid([row],241,2)
        with self.assertRaises(ValueError):controls_valid([],241,2)

    def test_next_step_join_and_negative_controls(self):
        sent=[dict(command_id='a',apply_when='next_native_step',owner_observed_frame=80,impulse_n_s=dict(x=0,y=0,z=.25))]
        kick=dict(command_id='a',application_policy='next_native_step',native_polled_after_frame=82,apply_at_frame=83,impulse_n_s=dict(x=0,y=0,z=.25))
        kicks_valid(sent,[kick])
        for field,value in [('apply_at_frame',84),('native_polled_after_frame',79),('impulse_n_s',dict(x=0,y=0,z=.5))]:
            crossed=copy.deepcopy(kick);crossed[field]=value
            with self.assertRaises(ValueError,msg=field):kicks_valid(sent,[crossed])
        with self.assertRaises(ValueError):kicks_valid(sent,[])
        with self.assertRaises(ValueError):kicks_valid(sent*2,[kick]*2)


if __name__=='__main__':unittest.main()
