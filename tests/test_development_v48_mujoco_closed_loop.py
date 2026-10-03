"""Complete affected-route zero-world gate; no native model/data is permitted."""
import copy
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_v48_mujoco_closed_loop as v
import test_development_v44_mujoco_replay as old
import test_development_v48_advancing_body_origin as abi

class Gate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=Path(os.environ['SPORE_V48_GATE_ROOT'])
        for name in ('MjModel','MjData'):
            p=patch.object(v.native.mujoco,name,side_effect=AssertionError('GATE_WORLD_FORBIDDEN'));p.start();cls.addClassCleanup(p.stop)
        cls.core,cls.route,cls.value=v.build_input()
    def unique(self,label):
        p=self.root/(label+'-'+uuid.uuid4().hex);p.mkdir();return p
    fake_world=old.ReplayGate.fake_world
    test_inherited_integer_projection=old.ReplayGate.test_integer_projection_is_exact_and_rejects_fraction_nan_bool
    test_inherited_contact_classifier=old.ReplayGate.test_existing_contact_classifier_and_positive_force_separation
    test_inherited_native_loop_and_refusals=old.ReplayGate.test_real_step_loop_limits_readback_forces_clock_and_warning_refusals
    test_inherited_busy_mutex=old.ReplayGate.test_busy_project_mutex_refuses_in_separate_process
    test_inherited_owned_timeout=old.ReplayGate.test_owned_child_timeout_retains_exit_and_streams
    test_inherited_actual_child_pid=old.ReplayGate.test_actual_python_child_owner_pid_and_venv_import
    test_inherited_serialization=old.ReplayGate.test_serialization_collision_and_nonfinite_refuse

    def snapshot(self):
        bodies=copy.deepcopy(self.value['initial_source_body_states'])
        for b in bodies:
            q=b['pose_world']['orientation_xyzw'];b['pose_world']['orientation_xyzw']=v.native.base._quaternion_xyzw(v.native.rotation(q)@v.RY90.T)
        joints=[{k:j[k] for k in ('joint_id','position_rad','velocity_rad_s')} for j in self.value['initial_native_state']['ordered_joint_observations']]
        return dict(bodies=bodies,joints=joints,nominal_capsule_bottom_m={l:0. for l in v.LIMBS})
    def contacts(self):
        return [dict(index=i,foot_site_id=l+'_foot',force_torque_contact_frame=[1.,0,0,0,0,0]) for i,l in enumerate(v.LIMBS)]

    def test_real_compiler_initial_projection_and_observation_basis(self):
        self.assertEqual(self.value,v.native.read(self.root/'input.json'))
        self.assertEqual(self.value['original_xml_sha256'],'sha256:6bf8b5f26dea05e2495effb76fea7d0878470308173426eabdb039bac17eb01d')
        snapshot=self.snapshot();state,frame=v.observe(snapshot,self.contacts(),1,self.value)
        for observed,expected in zip(frame['ordered_body_states'],self.value['initial_source_body_states']):
            v.native.np.testing.assert_allclose(v.native.rotation(observed['pose_world']['orientation_xyzw']),v.native.rotation(expected['pose_world']['orientation_xyzw']),atol=1e-14)
        native_orientation=v.native.rotation(snapshot['bodies'][0]['pose_world']['orientation_xyzw'])
        v.native.np.testing.assert_allclose(v.native.rotation(state['base_pose_world']['orientation_xyzw'])[:,2],native_orientation[:,0],atol=1e-14)
        self.assertEqual(state['base_twist_world'],frame['ordered_body_states'][0]['twist_world'])
        self.assertTrue(all(c['presence'] and c['bears_support'] for c in state['ordered_contact_observations']))
        contacts=self.contacts();contacts[2]['force_torque_contact_frame'][0]=0.
        state,_=v.observe(snapshot,contacts,2,self.value);self.assertTrue(state['ordered_contact_observations'][2]['presence']);self.assertFalse(state['ordered_contact_observations'][2]['bears_support'])
        qpos,qvel=v.native.project_free_state(self.value['initial_native_state'])
        self.assertEqual(qpos.tolist(),self.value['free_qpos']);self.assertEqual(qvel.tolist(),self.value['free_qvel'])
        self.assertFalse(any(self.value[k] for k in v.FLAGS))

    def test_new_owner_and_gate_source_refusals(self):
        root=self.unique('owner');nonce='a'*32
        ticket=dict(parent_pid=os.getppid(),nonce=nonce,input_sha256=v.native.sha(v.native.encoded(self.value)),
            gate_passed=True,source=v.native.identity(),bindings=[],**v.FLAGS)
        v.native.write_new(root/'ticket.json',ticket)
        with patch.dict(os.environ,SPORE_V48_NONCE=nonce):
            v.validate_ticket(root,self.value)
            for field,replacement in [('parent_pid',0),('nonce','b'*32),('gate_passed',False),('release_authority',True),('input_sha256','sha256:bad')]:
                changed=dict(ticket,**{field:replacement})
                with patch.object(v.native,'read',return_value=changed),self.assertRaises(ValueError):v.validate_ticket(root,self.value)
        wrong=v.native.file_binding(v.PLAN);wrong['sha256']='sha256:bad'
        with self.assertRaisesRegex(ValueError,'CHANGED_INPUT'):v.native.reopen([wrong])

    def test_cycle_requires_release_measured_absence_and_stance_landing(self):
        progress=dict(released={},absent={},completed={})
        out=dict(next_memory=copy.deepcopy(self.value['initial_memory']),actuation=dict(receipt=dict(recovery_support_plane=dict(measured_support_transfer={}))))
        r=out['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
        row=dict(command=1,last_substep_bearing={l:True for l in v.LIMBS})
        for limb in v.LIMBS:
            index=next(i for i,l in enumerate(out['next_memory']['ordered_limb_memory']) if l['limb_id']==limb)
            for l in out['next_memory']['ordered_limb_memory']:l['gait_step']=index*90
            r.update(preparation_released_this_command=True,planned_swing_limb_id=limb)
            self.assertFalse(v.update_cycle(progress,out,row));self.assertNotIn(limb,progress['completed'])
            r['preparation_released_this_command']=False;row['last_substep_bearing'][limb]=False
            self.assertFalse(v.update_cycle(progress,out,row));self.assertIn(limb,progress['absent'])
            row['last_substep_bearing'][limb]=True
            for l in out['next_memory']['ordered_limb_memory']:l['gait_step']+=73
            complete=v.update_cycle(progress,out,row);self.assertIn(limb,progress['completed'])
        self.assertTrue(complete);self.assertEqual(4,len(progress['completed']))

    def test_stop_predicate_is_measured_and_requires_every_contact(self):
        snapshot=self.snapshot()
        for b in snapshot['bodies']:
            b['pose_world']['orientation_xyzw']=dict(x=0.,y=0.,z=0.,w=1.)
            for vector in b['twist_world'].values():vector.update(x=0.,y=0.,z=0.)
        physics=dict(post=snapshot,last_substep_bearing={l:True for l in v.LIMBS})
        compiled=self.core.compile_bounded_quadruped(self.value['descriptor'])
        self.assertTrue(v.settled(physics,compiled))
        for defect in ('contact','linear','angular','tilt'):
            altered=copy.deepcopy(physics)
            if defect=='contact':altered['last_substep_bearing']['rear_left']=False
            elif defect=='linear':altered['post']['bodies'][0]['twist_world']['linear_velocity_m_s']['x']=1.
            elif defect=='angular':altered['post']['bodies'][0]['twist_world']['angular_velocity_rad_s']['x']=1.
            else:altered['post']['bodies'][0]['pose_world']['orientation_xyzw']=dict(x=1.,y=0.,z=0.,w=0.)
            self.assertFalse(v.settled(altered,compiled),defect)

    def test_real_worker_refusal_retention_and_independent_reader_zero_world(self):
        root=self.unique('synthetic-worker');(root/'calls').mkdir();nonce='c'*32
        v.native.write_new(root/'synthetic-test-only.json',dict(actual_world_count=0,actual_solver_step_count=0,model_and_integrator_replaced=True))
        ticket=dict(parent_pid=os.getppid(),nonce=nonce,input_sha256=v.native.sha(v.native.encoded(self.value)),
            gate_passed=True,source=v.native.identity(),bindings=[],**v.FLAGS)
        v.native.write_new(root/'ticket.json',ticket);v.native.write_new(root/'input.json',self.value)
        v.native.write_new(root/'worker-launch.json',dict(child_pid=os.getpid()))
        snapshot=self.snapshot();contacts=self.contacts()
        world=SimpleNamespace(data=SimpleNamespace(ctrl=v.native.np.zeros(8),warning=[SimpleNamespace(number=0)]))
        def step(world,targets,n):
            steps=[dict(native_step=(n-1)*5+j,time_s=((n-1)*5+j)/600,controls=targets,
                actuator_force_nm=[0.]*8,contacts=contacts) for j in range(1,6)]
            return dict(command=n,substeps=steps,post=copy.deepcopy(snapshot),
                any_substep_bearing={l:True for l in v.LIMBS},last_substep_bearing={l:True for l in v.LIMBS},
                absolute_actuator_impulse_nms=[0.]*8)
        with patch.dict(os.environ,SPORE_V48_NONCE=nonce),patch.object(v.native,'MujocoRecoveryMorphologyWorld',return_value=world),\
             patch.object(v.native,'initialize',return_value=dict(snapshot=snapshot,initial_contacts=contacts)),\
             patch.object(v.native,'step_outer',side_effect=step) as integration:
            v.worker(root)
        result=v.read_result(root)
        self.assertTrue(result['controller_refused']);self.assertIn('preparation_timeout',result['refusal_error'])
        self.assertEqual(integration.call_count,result['outer_steps']);self.assertEqual(241,result['outer_steps'])
        self.assertFalse(result['final_30_commands_settled']);self.assertFalse(any(result[k] for k in v.FLAGS))
        receipt=v.native.read(root/'worker-receipt.json');real_read=v.native.read
        for field,replacement in [('release_authority',True),('status','partial'),('solver_step_count',0),('cycle_end_command',1),('controller_refused',False)]:
            altered=dict(receipt,**{field:replacement})
            with patch.object(v.native,'read',side_effect=lambda p:altered if Path(p).name=='worker-receipt.json' else real_read(p)):
                with self.assertRaises(ValueError):v.read_result(root)
        # Tampered final native controls remain invalid even with a rewritten
        # synthetic inventory; the independent row check must catch them.
        rows=[json.loads(line) for line in (root/'trajectory.jsonl').read_text(encoding='utf-8').splitlines()]
        rows[-1]['physics']['substeps'][-1]['controls'][0]+=.1
        (root/'trajectory.jsonl').write_bytes(b''.join(v.native.encoded(r) for r in rows))
        with patch.object(v.native,'reopen'),self.assertRaisesRegex(ValueError,'READER_CONTROLS_CAPS'):v.read_result(root)

    def test_complete_stop_tail_worker_and_reader_with_synthetic_cycle_trigger(self):
        # Cycle semantics have their own four-limb test above. Here inject its
        # trigger to exercise the complete stop/finalization path, keeping real
        # C ABI commands and independent input/memory/command replay throughout.
        root=self.unique('synthetic-stop-tail');(root/'calls').mkdir();nonce='d'*32
        v.native.write_new(root/'synthetic-test-only.json',dict(actual_world_count=0,actual_solver_step_count=0,
            model_and_integrator_replaced=True,cycle_trigger_replaced=True))
        ticket=dict(parent_pid=os.getppid(),nonce=nonce,input_sha256=v.native.sha(v.native.encoded(self.value)),
            gate_passed=True,source=v.native.identity(),bindings=[],**v.FLAGS)
        v.native.write_new(root/'ticket.json',ticket);v.native.write_new(root/'input.json',self.value)
        v.native.write_new(root/'worker-launch.json',dict(child_pid=os.getpid()))
        snapshot=self.snapshot();contacts=self.contacts()
        world=SimpleNamespace(data=SimpleNamespace(ctrl=v.native.np.zeros(8),warning=[SimpleNamespace(number=0)]))
        def step(world,targets,n):
            return dict(command=n,substeps=[dict(native_step=(n-1)*5+j,time_s=((n-1)*5+j)/600,controls=targets,
                actuator_force_nm=[0.]*8,contacts=contacts) for j in range(1,6)],post=copy.deepcopy(snapshot),
                any_substep_bearing={l:True for l in v.LIMBS},last_substep_bearing={l:True for l in v.LIMBS},absolute_actuator_impulse_nms=[0.]*8)
        with patch.dict(os.environ,SPORE_V48_NONCE=nonce),patch.object(v.native,'MujocoRecoveryMorphologyWorld',return_value=world),\
             patch.object(v.native,'initialize',return_value=dict(snapshot=snapshot,initial_contacts=contacts)),\
             patch.object(v.native,'step_outer',side_effect=step),patch.object(v,'update_cycle',side_effect=lambda p,o,r:r['command']==2):
            v.worker(root);result=v.read_result(root)
        self.assertEqual((122,2,120),(result['outer_steps'],result['cycle_end_command'],result['stopping_commands']))
        self.assertTrue(result['final_30_commands_settled']);self.assertFalse(result['controller_refused'])
        self.assertFalse(any(result[k] for k in v.FLAGS))

if __name__=='__main__':
    suite=unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(abi.AdvancingBodyOrigin),unittest.defaultTestLoader.loadTestsFromTestCase(Gate)])
    result=unittest.TextTestRunner(verbosity=2).run(suite);sys.exit(0 if result.wasSuccessful() else 1)
