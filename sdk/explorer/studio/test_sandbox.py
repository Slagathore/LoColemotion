import copy
import json
import math
import os
import queue
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch, Mock
import uuid

from sandbox_spec import SCHEMA, validate
from showcase_model import generated


def example():
    return dict(schema_version=SCHEMA,descriptor=generated(42),steps=960,
        phase_mode='clocked',impulses=[dict(step=360,vector_n_s=[0,0,.25])],realtime=True)


class SandboxBoundary(unittest.TestCase):
    def test_interaction_audit_rejects_crossed_and_invented_button_receipts(self):
        from audit_live_interaction import audit_rows
        command=dict(command_id='kick',magnitude=.25,direction='right')
        native=dict(command_id='kick',apply_at_frame=44,impulse_n_s=dict(x=0,y=0,z=.25),
                    interaction_timing=dict(owner_received_perf_counter_ns=1000000,native_application_perf_counter_ns=9000000))
        ui=dict(command_id='kick',applied_frame=44,ui_pressed_ticks_usec=1000,
                ui_observed_ticks_usec=11000,button_to_observed_application_ms=10)
        self.assertEqual(audit_rows([command],[native],[ui])[0]['owner_receipt_to_native_application_ms'],8)
        for field,value in [('command_id','other'),('applied_frame',45),('button_to_observed_application_ms',1),('ui_observed_ticks_usec',0)]:
            changed=dict(ui);changed[field]=value
            with self.assertRaises(ValueError,msg=field):audit_rows([command],[native],[changed])
        with self.assertRaises(ValueError):audit_rows([command],[dict(native,impulse_n_s=dict(x=0,y=0,z=.5))],[ui])
        with self.assertRaises(ValueError):audit_rows([command],[native],[])

    def test_next_step_impulses_preserve_native_validation_and_measure_application(self):
        from live_impulses import InteractiveTransport, mark_native_application
        from showcase_model import impulse
        def transport():
            worker=InteractiveTransport.__new__(InteractiveTransport)
            worker.session_id='test';worker.frame_index=43;worker.command_queue=queue.Queue()
            worker.pending_impulses=[];worker.command_ids=set();worker.interactive_timing={};worker.send=Mock()
            return worker
        def immediate():
            value=impulse('test',1,.25,'right','kick')
            del value['apply_at_frame']
            value.update(apply_when='next_native_step',owner_received_perf_counter_ns=10,owner_sent_perf_counter_ns=20)
            return value
        worker=transport();worker.command_queue.put(immediate())
        due=worker.take_due_impulses()
        self.assertEqual(len(due),1);self.assertEqual(due[0]['apply_at_frame'],44)
        self.assertEqual(due[0]['impulse_n_s'],dict(x=0,y=0,z=.25))
        mark_native_application(due)
        timing=due[0]['interaction_timing']
        self.assertEqual(timing['native_polled_after_frame'],43)
        self.assertGreaterEqual(timing['native_application_perf_counter_ns'],timing['native_polled_perf_counter_ns'])
        self.assertEqual(worker.take_due_impulses(),[])
        worker.command_queue.put(immediate())
        with self.assertRaisesRegex(ValueError,'repeated'):worker.take_due_impulses()
        for field,value in [('session_id','crossed'),('schema_version','crossed'),('message_type','start'),
                ('target_body_id','other'),('impulse_n_s',dict(x=0,y=0,z=9)),
                ('impulse_n_s',dict(x=0,y=0,z=math.nan)),('impulse_n_s',dict(x=True,y=0,z=0)),
                ('command_id','bad/id'),('owner_sent_perf_counter_ns',True),
                ('owner_received_perf_counter_ns',30),('apply_at_frame',44),('apply_when','later')]:
            worker=transport();packet=immediate();packet[field]=value;worker.command_queue.put(packet)
            with self.assertRaises((ValueError,RuntimeError),msg=field):worker.take_due_impulses()
        worker=transport();worker.command_ids={str(i) for i in range(16)};worker.command_queue.put(immediate())
        with self.assertRaisesRegex(ValueError,'population'):worker.take_due_impulses()
        # An explicit future schedule retains its original strict timing.
        worker=transport();packet=impulse('test',1,.25,'left','future');packet['apply_at_frame']=46
        worker.command_queue.put(packet);self.assertEqual(worker.take_due_impulses(),[])
        worker.frame_index=45;self.assertEqual(worker.take_due_impulses()[0]['apply_at_frame'],46)
        worker=transport();packet['apply_at_frame']=True;worker.command_queue.put(packet)
        with self.assertRaisesRegex(ValueError,'integer'):worker.take_due_impulses()

    def test_catalog_sources_are_pinned_and_recipes_do_not_claim_acceptance(self):
        import scenario_catalog
        value=scenario_catalog.load()
        self.assertEqual(len(value['entries']),6)
        self.assertFalse(value['physical_acceptance_authority'])
        with patch.object(scenario_catalog,'sha',return_value='changed'):
            with self.assertRaisesRegex(ValueError,'missing or changed'):scenario_catalog.load()

    def test_valid_untested_body_is_admitted_without_acceptance(self):
        self.assertEqual(validate(example())['descriptor']['morphology_id'],'explorer_seed_42')

    def test_crossed_and_unbounded_requests_refuse(self):
        for field,value in [('steps',True),('steps',119),('steps',121),('steps',7201),('phase_mode','unknown'),('realtime',1),('schema_version','wrong')]:
            v=example();v[field]=value
            with self.assertRaises(ValueError,msg=field):validate(v)
        for row in [dict(step=0,vector_n_s=[0,0,.25]),dict(step=960,vector_n_s=[0,0,.25]),
            dict(step=True,vector_n_s=[0,0,.25]),dict(step=120,vector_n_s=[0,0,9]),
            dict(step=120,vector_n_s=[0,0,math.nan]),dict(step=120,vector_n_s=[0,0,0]),
            dict(step=120,vector_n_s=[True,0,.25]),dict(step=120,vector_n_s=[0,1])]:
            v=example();v['impulses']=[row]
            with self.assertRaises(ValueError):validate(v)
        v=example();v['impulses']*=2
        with self.assertRaises(ValueError):validate(v)
        v=example();v['descriptor']['torso_length_scale']=2
        with self.assertRaises(ValueError):validate(v)

    def test_preflight_uses_native_controller_and_cannot_create_world(self):
        import mujoco_sandbox as worker
        core=worker.bridge.LocomotionCore()
        for seed in [169,42]:
            request=example();request['descriptor']=generated(seed)
            result=worker.preflight(request,core)
            self.assertTrue(result['ok']);self.assertEqual(result['world_build_count'],0)
            self.assertFalse(result['host_profile']['host_response_characterized_for_this_profile'])
        with patch.object(worker.bridge,'build_model_xml',side_effect=lambda *a:worker.mujoco.MjModel.from_xml_string('<mujoco/>')):
            with self.assertRaisesRegex(Exception,'PREFLIGHT_WORLD_CONSTRUCTION_FORBIDDEN|has no attribute'):
                worker.preflight(example(),core)

    def test_bounded_loop_and_native_failure_cleanup_without_world(self):
        import mujoco_sandbox as worker
        for violation in [0,1]:
            folder=Path(os.environ['EXPLORER_TEST_OUTPUT'])/('synthetic-loop-'+uuid.uuid4().hex)
            folder.mkdir()
            spec=example();spec['steps']=120;spec['impulses']=[]
            robot=Mock()
            robot.model_xml='<synthetic-no-world/>'
            robot.morphology={'ordered_limb_ids':[]}
            robot.torso_metrics.return_value=dict(x=0,y=1,z=0)
            robot.state_frame.return_value={}
            robot.model.body.return_value=SimpleNamespace(id=0)
            robot.data=SimpleNamespace(xfrc_applied=worker.np.zeros((1,6)),qpos=worker.np.zeros(1),qvel=worker.np.zeros(1))
            robot.apply_host_mapping.return_value={'portable_impulse_violation_count':violation}
            core=Mock();core.balanced_wave_initial_memory.return_value={}
            session=core.create_balanced_wave_policy_session.return_value
            session.closed=True
            session.step.return_value=dict(next_memory={},actuation=dict(safe_no_actuation=False,failure_codes=[],receipt=dict(controller_error=None)))
            transport=Mock();transport.take_due_impulses.return_value=[]
            event_order=[]
            robot.prepare.side_effect=lambda:event_order.append('prepare')
            robot.apply_host_mapping.side_effect=lambda mapping:(event_order.append('apply') or {'portable_impulse_violation_count':violation})
            transport.frame.side_effect=lambda *args:event_order.append('frame')
            with patch.object(worker,'ExploratoryRobot',return_value=robot),patch.object(worker.bridge,'_ordered_limb_steps',return_value=[]),patch.object(worker.bridge,'compose_bw19v_step',return_value={'host_mapping':{}}):
                if violation:
                    with self.assertRaisesRegex(RuntimeError,'cap violation'):worker.run(spec,core,transport,folder)
                    transport.completed.assert_not_called()
                    self.assertEqual(robot.apply_host_mapping.call_count,1)
                else:
                    worker.run(spec,core,transport,folder)
                    self.assertEqual(robot.apply_host_mapping.call_count,120)
                    transport.completed.assert_called_once()
                    self.assertEqual(event_order,['prepare']+['apply','prepare','frame']*120)
            session.close.assert_called_once()
            summary=json.loads((folder/'summary.json').read_text())
            self.assertEqual(summary['ok'],not bool(violation))
            self.assertFalse(summary['physical_acceptance_authority'])
            self.assertTrue(worker.np.array_equal(robot.data.xfrc_applied,worker.np.zeros((1,6))))


if __name__=='__main__':unittest.main(verbosity=2)
