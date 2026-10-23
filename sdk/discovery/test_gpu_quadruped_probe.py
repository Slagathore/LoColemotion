"""No-world controls for batch identity, capture capacity and independent reading."""
import copy
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import mujoco
from gpu_quadruped_model import ROOT,FLAGS,load_contract,build_inputs,controls,split_contacts,zero_world,sha,f32
from gpu_quadruped_probe import check_capture
from audit_gpu_quadruped_probe import audit,verify_closure


class QuadrupedControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=Path(os.environ['QUADRUPED_TEST_CORE'])
        cls.c=load_contract();cls.c['steps_per_world']=12
        with patch.object(mujoco,'MjModel',side_effect=AssertionError('world in fixture')),patch.object(mujoco,'MjData',side_effect=AssertionError('data in fixture')):
            cls.compiled,cls.xml,cls.spec=build_inputs(cls.core,cls.c)
        cls.folder=Path(os.environ.get('EXPLORER_TEST_OUTPUT',ROOT.parent/'SporeSpore_Evidence'))/('gpu-quadruped-synthetic-'+uuid.uuid4().hex)
        cls.folder.mkdir()
        cls.rows=[]
        keys=[('gpu',cell,step) for step in range(1,13) for cell in range(4)]
        keys += [('cpu',cell,step) for cell in range(4) for step in range(1,13)]
        for backend,cell,step in keys:
            project=f32 if backend=='gpu' else float
            pose=list(map(project,cls.spec['initial_qpos']));velocity=[0.]*14;velocity[1]=project(cls.spec['initial_lateral_velocities'][cell])
            ctrl=controls(cls.c,cell,step,pose,backend=='gpu')
            caps=[[project(x) for x in pair] for pair in cls.spec['force_ranges']]
            forces=[project(max(lo,min(hi,10*u))) for u,(lo,hi) in zip(ctrl,caps)]
            contact=dict(world=cell,native_index=[1,3,0,2][cell] if backend=='gpu' else 0,geom=[0,cell+2],distance_m=-.0001,position_m=[0.,0.,0.])
            cls.rows.append(dict(backend=backend,cell=cell,cell_id=cls.c['control']['cells'][cell]['id'],step=step,
                before_qpos=pose,before_qvel=velocity,qpos=pose,qvel=velocity,ctrl=ctrl,actuator_force_nm=forces,joint_force_nm=forces,
                on_force_cap=[f<=lo or f>=hi for f,(lo,hi) in zip(forces,caps)],time_s=step*cls.c['timestep_s'],
                contacts=[contact],batch_contacts=4 if backend=='gpu' else 1,nefc=3,overflow=0,warnings=[0]*7 if backend=='cpu' else []))

    def fixture(self,rows=None):
        root=self.folder/uuid.uuid4().hex;folder=root/'physical';folder.mkdir(parents=True)
        (root/'declaration.json').write_text(json.dumps(dict(contract=self.c,synthetic=True)))
        (folder/'model.xml').write_text(self.xml,encoding='utf-8',newline='\n')
        for name,value in [('inputs',self.spec),('compiled',self.compiled)]:
            (folder/(name+'.json')).write_text(json.dumps(value))
        model=dict(nq=15,nv=14,nu=8,nbody=10,ngeom=10,nsensordata=16,sensor_addresses=[[2*i,2*i+1] for i in range(8)],
            model_sha256=sha(folder/'model.xml'),inputs_sha256=sha(folder/'inputs.json'),compiled_sha256=sha(folder/'compiled.json'),
            force_ranges=self.spec['force_ranges'],ordered_geoms=self.spec['geom_names'],contact_and_force_stage='force_evaluation_state',root_post_state_source='qpos')
        (folder/'native-model.json').write_text(json.dumps(model))
        with (folder/'trace.jsonl').open('w') as stream:
            for row in self.rows if rows is None else rows:stream.write(json.dumps(row)+'\n')
        result=dict(ok=True,synthetic=True,completed_steps={key:[12]*4 for key in ['cpu','gpu']},constructed_worlds=dict(cpu=4,gpu=4),
            trace_sha256=sha(folder/'trace.jsonl'),model_sha256=sha(folder/'model.xml'),**{k:False for k in FLAGS})
        (folder/'worker-result.json').write_text(json.dumps(result))
        return folder

    def test_real_compiler_preflight_traps_worlds(self):
        result=zero_world(self.core)
        self.assertTrue(result['ok']);self.assertEqual(result['world_build_count'],0)
        self.assertEqual(result['topology']['named_force_sensors'],16)

    def test_contact_attribution_uses_world_ids_and_refuses_overflow(self):
        args=(3,[2,0,2],[[0,2],[0,3],[0,4]],[-.01,0.,.01],[[0.,0.,0.]]*3)
        result=split_contacts(*args,nworld=4,capacity=4)
        self.assertEqual([[r['native_index'] for r in group] for group in result],[[1],[],[0,2],[]])
        for count,worlds in [(5,args[1]),(3,[2,4,2]),(3,[2,-1,2])]:
            with self.assertRaises(ValueError):split_contacts(count,worlds,*args[2:],nworld=4,capacity=4)

    def test_capture_refuses_overflow_nonfinite_warning_and_force(self):
        caps=[[f32(x) for x in pair] for pair in self.spec['force_ranges']]
        for key,value in [('overflow',1),('nefc',129),('warnings',[1]),('qpos',[float('nan')]*15),('actuator_force_nm',[100.]*8)]:
            row=copy.deepcopy(self.rows[0]);row[key]=value
            with self.assertRaises(ValueError):check_capture(row,self.c,caps)

    def test_complete_synthetic_population_remains_unqualified(self):
        result=audit(self.fixture());self.assertEqual(result['rows'],96);self.assertTrue(result['synthetic'])
        self.assertTrue(all(result[k] is False for k in FLAGS))

    def test_reader_refuses_omitted_native_warnings(self):
        rows=copy.deepcopy(self.rows);rows[48]['warnings']=[]
        with self.assertRaises(ValueError):audit(self.fixture(rows))
        with self.assertRaises(ValueError):check_capture(rows[48],self.c,self.spec['force_ranges'])

    def test_reader_refuses_missing_duplicate_and_crossed_rows(self):
        for rows in [self.rows[:-1],self.rows+[self.rows[0]],self.rows[1:]+self.rows[:1]]:
            with self.assertRaises(ValueError):audit(self.fixture(rows))

    def test_reader_refuses_crossed_contact_command_clock_and_state(self):
        for key,value in [('cell_id','crossed'),('time_s',999.),('ctrl',[0.]*8),('before_qpos',[0.]*15),('overflow',1),('nefc',129)]:
            rows=copy.deepcopy(self.rows);rows[0][key]=value
            with self.assertRaises(ValueError,msg=key):audit(self.fixture(rows))
        for field,value in [('world',1),('native_index',2),('geom',[1,2]),('distance_m',float('nan'))]:
            rows=copy.deepcopy(self.rows);rows[0]['contacts'][0][field]=value
            with self.assertRaises(ValueError,msg=field):audit(self.fixture(rows))

    def test_reader_refuses_relabelled_sampling_stage_and_authority(self):
        folder=self.fixture();path=folder/'native-model.json';value=json.loads(path.read_text())
        value['root_post_state_source']='xpos';path.write_text(json.dumps(value))
        with self.assertRaises(ValueError):audit(folder)
        folder=self.fixture();path=folder/'worker-result.json';value=json.loads(path.read_text())
        value['training_data_authority']=True;path.write_text(json.dumps(value))
        with self.assertRaises(ValueError):audit(folder)

    def test_reader_refuses_changed_raw_bytes_and_clamp_labels(self):
        folder=self.fixture()
        with (folder/'trace.jsonl').open('a') as stream:stream.write('\n')
        with self.assertRaises(ValueError):audit(folder)
        rows=copy.deepcopy(self.rows);rows[0]['on_force_cap'][0]=not rows[0]['on_force_cap'][0]
        with self.assertRaises(ValueError):audit(self.fixture(rows))

    def test_closure_reopens_complete_inventory_and_recomputes(self):
        folder=self.fixture();attempt=folder.parent;source='0'*40;observed=audit(folder)
        declaration=json.loads((attempt/'declaration.json').read_text())
        declaration.update(source_commit=source,binding={})
        (attempt/'declaration.json').write_text(json.dumps(declaration))
        (attempt/'receipt.json').write_text(json.dumps(dict(ok=True,physical_started=True,zero_world_gate_passed=True,
            synthetic=True,source_commit=source,binding={},audit=observed)))
        (attempt/'consumed.json').write_text(json.dumps(dict(source_commit=source,attempt_id=attempt.name)))
        (attempt/'independent-audit.json').write_text(json.dumps(observed))
        for name in ['stdout.log','stderr.log']:(folder/name).write_text('synthetic fixture only')
        artifacts=[dict(evidence_relative_path=p.relative_to(self.folder).as_posix(),byte_length=p.stat().st_size,sha256=sha(p))
                   for p in attempt.rglob('*') if p.is_file()]
        closure=dict(artifacts=artifacts,attempt_id=attempt.name,source_commit=source,synthetic=True,
                     independent_audit=observed,**{k:False for k in FLAGS})
        path=self.folder/(attempt.name+'-closure.json');path.write_text(json.dumps(closure))
        self.assertTrue(verify_closure(path,self.folder)['ok'])
        changed=copy.deepcopy(closure);changed['independent_audit']['rows']=1;path.write_text(json.dumps(changed))
        with self.assertRaisesRegex(ValueError,'audit changed'):verify_closure(path,self.folder)
        path.write_text(json.dumps(closure));(folder/'stderr.log').write_text('changed bytes')
        with self.assertRaisesRegex(ValueError,'artifact changed'):verify_closure(path,self.folder)


if __name__=='__main__':unittest.main()
