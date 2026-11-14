"""Controls for additive capture and exact selected-input retention."""
import copy
import hashlib
import json
import os
from pathlib import Path
import unittest
import uuid

from audit_live_godot import audit_startup_packets
from materialize_startup_capture import materialize,NAME

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]


def snapshot(value):
    text=json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False)
    raw=text.encode()
    return dict(utf8_text=text,utf8_byte_length=len(raw),raw_sha256='sha256:'+hashlib.sha256(raw).hexdigest())


class StartupCaptureControls(unittest.TestCase):
    def folder(self):
        folder=Path(os.environ['EXPLORER_TEST_OUTPUT'])/('startup-capture-control-'+uuid.uuid4().hex)
        folder.mkdir(parents=True,exist_ok=False);return folder

    def test_materializer_preserves_original_route_body_and_one_call(self):
        project=self.folder()
        route=project/'sdk/adapters/godot/gdscript/recovery_native_route_v1.gd'
        worker=project/'sdk/explorer/native_recovery/worker.gd'
        route.parent.mkdir(parents=True);worker.parent.mkdir(parents=True)
        (project/'sdk/explorer/studio').mkdir()
        original=(ROOT/'sdk/adapters/godot/gdscript/recovery_native_route_v1.gd').read_text(encoding='utf-8-sig')
        old=(HERE/'godot_live_walking_worker.gd').read_text()
        route.write_text(original,encoding='utf-8',newline='\n');worker.write_text(old,encoding='utf-8',newline='\n')
        self.assertEqual(materialize(project)['maximum_packets'],16)
        prefix=route.read_text().split('\nconst StartupCapture :=')[0]
        self.assertEqual(prefix.replace('static func _studio_uncaptured_'+NAME+'(','static func '+NAME+'(').rstrip(),original.rstrip())
        self.assertEqual(route.read_text().count('_studio_uncaptured_'+NAME+'('),2)
        with self.assertRaises(ValueError):materialize(project)

    def fixture(self):
        folder=self.folder();target=folder/'physical/startup-packets';target.mkdir(parents=True)
        calls=[dict(global_step=n,phase='first' if n<=100 else 'second') for n in range(1,241)]
        fixed=[1,30,60,120,180,239,240];rows=[]
        for step in sorted(set(fixed)|{101}):
            phase=calls[step-1]['phase']
            sources={key:snapshot(value) for key,value in dict(bound_observation={'observation_v3':{'semantic_step':step}},source_memory={'last_semantic_step':step-1,'phase':phase},source_application={'semantic_step':step}).items()}
            capture=dict(request=snapshot({'request':step}),response=snapshot({'ok':True}),source_links=sources)
            route=dict(ok=True,step_receipt={'step':step},collection_transport_retention=capture)
            selection=dict(fixed_step=step in fixed,first_phase_call=step in [1,101])
            packet=dict(schema_version='locolemotion_studio_startup_replay_packet_v1',route_ok=True,
                global_step=step,phase=phase,selection=selection,context=snapshot({}),sources=sources,
                request=capture['request'],response=capture['response'],expected_step=route['step_receipt'],expected_route=snapshot(route))
            path=target/f'step-{step:03}.json';path.write_text(json.dumps(packet),encoding='utf-8')
            rows.append(dict(global_step=step,phase=phase,selection=selection,path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        summary=dict(ok=True,failure='',observed_calls=calls,fixed_steps=fixed,maximum_packets=16,packets=rows,
            additional_controller_calls=0,additional_physics_reads=0,additional_solver_steps=0,
            performance_comparison_authority=False,physical_acceptance_authority=False,release_authority=False,
            selected_packet_capture_wall_us=100)
        return folder,dict(physical={'completed':{'summary':{'startup_packet_capture':summary}}})

    def test_reader_accepts_complete_capture_and_refuses_crossed_population(self):
        folder,receipt=self.fixture()
        self.assertEqual(len(audit_startup_packets(folder,receipt)['packets']),8)
        mutations=[lambda s:s['observed_calls'].pop(),lambda s:s['packets'].pop(),
            lambda s:s['observed_calls'][2].update(global_step=2),lambda s:s.update(additional_controller_calls=1),
            lambda s:s.update(physical_acceptance_authority=True),lambda s:s['packets'][0].update(phase='crossed'),
            lambda s:s['packets'][0].update(selection={'fixed_step':False,'first_phase_call':True}),
            lambda s:s['packets'][0].update(sha256='0'*64),lambda s:s.update(maximum_packets=17)]
        for mutate in mutations:
            bad=copy.deepcopy(receipt);mutate(bad['physical']['completed']['summary']['startup_packet_capture'])
            with self.assertRaises(ValueError):audit_startup_packets(folder,bad)

    def test_reader_refuses_changed_source_clock_with_refreshed_outer_digest(self):
        folder,receipt=self.fixture();row=receipt['physical']['completed']['summary']['startup_packet_capture']['packets'][0]
        path=Path(row['path']);packet=json.loads(path.read_bytes())
        packet['sources']['source_memory']=snapshot({'last_semantic_step':400,'phase':'first'})
        path.write_text(json.dumps(packet),encoding='utf-8');row['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError,'memory clock'):audit_startup_packets(folder,receipt)


if __name__=='__main__':unittest.main()
