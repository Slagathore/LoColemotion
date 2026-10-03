"""Affected-route safety gate. No MuJoCo model/data may exist in this process."""
import copy
import json
import math
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_v44_mujoco_replay as replay


class ReplayGate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(os.environ['SPORE_V44_GATE_ROOT'])
        cls.model_patch = patch.object(replay.mujoco, 'MjModel', side_effect=AssertionError('GATE_WORLD_FORBIDDEN'))
        cls.data_patch = patch.object(replay.mujoco, 'MjData', side_effect=AssertionError('GATE_DATA_FORBIDDEN'))
        cls.model_patch.start(); cls.data_patch.start()
        cls.addClassCleanup(cls.model_patch.stop); cls.addClassCleanup(cls.data_patch.stop)
        cls.core, cls.route, cls.value = replay.build_input()
        cls.preflight = replay.read(cls.root/'preflight.json')

    def unique(self, label):
        path = self.root/(label+'-'+uuid.uuid4().hex)
        path.mkdir()
        return path

    def test_real_recovery_compiler_and_all_400_cabi_mappings(self):
        value = self.value
        self.assertEqual(value, replay.read(self.root/'input.json'))
        self.assertEqual(value['original_xml_sha256'], 'sha256:6bf8b5f26dea05e2495effb76fea7d0878470308173426eabdb039bac17eb01d')
        self.assertEqual(len(value['commands']), 400)
        tree = replay.ET.fromstring(self.route.model_xml)
        self.assertEqual(tree.find(".//geom[@name='ground']").get('type'), 'box')
        self.assertTrue(all(g.get('friction').split()[0] == '1.8' for g in tree.iter('geom')))
        for n, row in enumerate(value['commands'], 1):
            self.assertEqual(n, row['command'])
            self.assertEqual(8, len(row['targets']))
            self.assertEqual(row['targets'], [-a['host_applied_target_velocity_rad_s'] for a in row['godot_motor_applications']])
        self.assertFalse(any(value[k] for k in replay.FLAGS))

    def test_integer_projection_is_exact_and_rejects_fraction_nan_bool(self):
        self.assertEqual(1, replay.integral(1.0))
        original = dict(values=[1., .75, -0., True, 2**53*1.])
        projected = replay.exact_json_integers(original)
        self.assertEqual(original, projected)
        self.assertIs(type(projected['values'][0]), int)
        self.assertEqual(-1, math.copysign(1, projected['values'][2]))
        for value in (1.2, float('nan'), float('inf'), -1, True, 2**53):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'INTEGER_PROJECTION'):
                replay.integral(value)

    def test_free_joint_world_to_local_rotation_and_roundtrip(self):
        state = self.value['initial_native_state']
        position, velocity = replay.project_free_state(state)
        rm = replay.C @ replay.rotation(state['base_pose_world']['orientation_xyzw']) @ replay.C.T
        replay.np.testing.assert_allclose(replay.C.T @ position[:3], replay.vector(state['base_pose_world']['position_m']), atol=1e-14)
        replay.np.testing.assert_allclose(replay.C.T @ rm @ velocity[3:], replay.vector(state['base_twist_world']['angular_velocity_rad_s']), atol=1e-14)
        # A rotation around a non-up axis discriminates local from world qvel.
        altered = copy.deepcopy(state)
        altered['base_pose_world']['orientation_xyzw'] = dict(x=math.sin(.6), y=0., z=0., w=math.cos(.6))
        _, v = replay.project_free_state(altered)
        self.assertGreater(replay.np.linalg.norm(v[3:]-replay.C @ replay.vector(state['base_twist_world']['angular_velocity_rad_s'])), .001)

    def test_existing_contact_classifier_and_positive_force_separation(self):
        world = replay.MujocoRecoveryMorphologyWorld.__new__(replay.MujocoRecoveryMorphologyWorld)
        world.contact_sites = {'rear_left_foot': dict(body_id='rear_left_distal', local_center_m=dict(x=0.,y=-.1,z=0.))}
        world._body_local_canonical = lambda body, point: replay.np.asarray(point)
        self.assertTrue(world._is_foot_cap_contact('rear_left_distal', [0.,-.11,0.]))
        self.assertFalse(world._is_foot_cap_contact('rear_left_distal', [0.,.11,0.]))
        rows = [dict(foot_site_id='rear_left_foot', force_torque_contact_frame=[0.,0,0,0,0,0])]
        self.assertFalse(replay.bearing(rows)['rear_left'])
        rows[0]['force_torque_contact_frame'][0] = 1e-8
        self.assertTrue(replay.bearing(rows)['rear_left'])
        rows[0]['foot_site_id'] = None
        self.assertFalse(replay.bearing(rows)['rear_left'])

    def fake_world(self):
        data = SimpleNamespace(ctrl=replay.np.zeros(8), qpos=replay.np.zeros(15), qvel=replay.np.zeros(14),
            warning=[SimpleNamespace(number=0)], time=0., actuator_force=replay.np.zeros(8))
        return SimpleNamespace(data=data, model=object(), prepare=lambda: None)

    def test_real_step_loop_limits_readback_forces_clock_and_warning_refusals(self):
        for defect in (None, 'time', 'nan', 'warning', 'force'):
            world = self.fake_world()
            def advance(model, data):
                data.time += 1/600
                if defect == 'time': data.time += 1.
                if defect == 'nan': data.qpos[0] = float('nan')
                if defect == 'warning': data.warning[0].number = 1
                if defect == 'force': data.actuator_force[0] = 1e8
            with self.subTest(defect=defect), patch.object(replay.mujoco, 'mj_step1'), \
                 patch.object(replay.mujoco, 'mj_step2', side_effect=advance) as step, \
                 patch.object(replay, 'contacts', return_value=[]), patch.object(replay, 'body_snapshot', return_value={}):
                if defect:
                    with self.assertRaises(ValueError): replay.step_outer(world, [0.1]*8, 1)
                    self.assertEqual(1, step.call_count)
                else:
                    result = replay.step_outer(world, [0.1]*8, 1)
                    self.assertEqual(5, step.call_count)
                    self.assertEqual([1,2,3,4,5], [s['native_step'] for s in result['substeps']])
                    self.assertTrue(all(s['controls'] == [0.1]*8 for s in result['substeps']))

    def test_source_reopen_and_owner_gate_authority_refusals(self):
        ticket = dict(parent_pid=123, nonce='a'*32, input_sha256=replay.sha(replay.encoded(self.value)),
            plan_sha256=replay.file_binding(replay.PLAN)['sha256'], gate_passed=True,
            source=replay.identity(), bindings=self.preflight['bindings'], **replay.FLAGS)
        replay.validate_owner(ticket, self.value, 123, 'a'*32)
        for field, replacement in [('parent_pid',124), ('nonce','b'*32), ('gate_passed',False),
                                   ('release_authority',True), ('input_sha256','sha256:bad')]:
            changed = copy.deepcopy(ticket); changed[field] = replacement
            with self.subTest(field=field), self.assertRaises(ValueError):
                replay.validate_owner(changed, self.value, 123, 'a'*32)
        wrong = copy.deepcopy(self.preflight['bindings']); wrong[0]['sha256'] = 'sha256:bad'
        with self.assertRaisesRegex(ValueError, 'CHANGED_INPUT'): replay.reopen(wrong)

    def test_busy_project_mutex_refuses_in_separate_process(self):
        # The real launcher holds the real project lock throughout this gate.
        folder = self.unique('lock-negative')
        script = "import sys; sys.path.insert(0,'sdk/conformance'); from development_v44_mujoco_replay import OperationLock; OperationLock().__enter__()"
        with self.assertRaisesRegex(ValueError, 'LOCK-NEGATIVE_FAILED'):
            replay.run_owned([sys.executable, '-c', script], folder, 'lock-negative', 30)
        self.assertIn('OPERATION_BUSY', (folder/'lock-negative.stderr').read_text(encoding='utf-8'))

    def test_owned_child_timeout_retains_exit_and_streams(self):
        folder = self.unique('timeout-negative')
        with self.assertRaisesRegex(ValueError, 'TIMEOUT-NEGATIVE_FAILED'):
            replay.run_owned([sys.executable, '-c', 'import time; print("owned",flush=True); time.sleep(20)'], folder, 'timeout-negative', 1)
        receipt = replay.read(folder/'timeout-negative-exit.json')
        self.assertTrue(receipt['timed_out'])
        self.assertNotEqual(0, receipt['exit_code'])
        self.assertIn('owned', (folder/'timeout-negative.stdout').read_text(encoding='utf-8'))

    def test_actual_python_child_owner_pid_and_venv_import(self):
        folder = self.unique('actual-owner')
        script = 'import os,json,mujoco,sys; print(json.dumps(dict(pid=os.getpid(),parent=os.getppid(),version=mujoco.__version__,module=mujoco.__file__,executable=sys.executable)))'
        result = replay.run_owned([sys.executable, '-c', script], folder, 'actual-owner', 30)
        observed = json.loads((folder/'actual-owner.stdout').read_text(encoding='utf-8'))
        self.assertEqual(os.getpid(), observed['parent'])
        self.assertEqual(result['child_pid'], observed['pid'])
        self.assertEqual('3.11.0', observed['version'])
        self.assertEqual(Path(replay.mujoco.__file__).resolve(), Path(observed['module']).resolve())
        self.assertEqual(Path(sys._base_executable).resolve(), Path(observed['executable']).resolve())

    def synthetic_rows(self):
        rows = []
        for command in self.value['commands']:
            n = command['command']
            steps = [dict(native_step=(n-1)*5+j, time_s=((n-1)*5+j)/600, controls=command['targets'],
                          actuator_force_nm=[0.]*8, contacts=[]) for j in range(1,6)]
            rows.append(dict(command=n, substeps=steps, absolute_actuator_impulse_nms=[0.]*8,
                any_substep_bearing={k:False for k in replay.LIMBS}, last_substep_bearing={k:False for k in replay.LIMBS},
                post=dict(bodies=copy.deepcopy(self.value['initial_source_body_states']),
                    joints=copy.deepcopy(self.value['initial_native_state']['ordered_joint_observations']),
                    nominal_capsule_bottom_m={k:0. for k in replay.LIMBS})))
        return rows

    def test_full_population_reader_and_crossed_controls_clock_contact_and_partial_refusals(self):
        rows = self.synthetic_rows()
        replay.verify_rows(rows, self.value)
        for defect in ('control','clock','contact','partial','state','impulse','nan'):
            changed = copy.deepcopy(rows)
            if defect == 'control': changed[79]['substeps'][2]['controls'][0] += .01
            if defect == 'clock': changed[2]['substeps'][1]['native_step'] = 88
            if defect == 'contact': changed[20]['any_substep_bearing']['rear_right'] = True
            if defect == 'partial': changed.pop()
            if defect == 'state': changed[18]['post']['bodies'][0]['body_id'] = 'crossed'
            if defect == 'impulse': changed[22]['absolute_actuator_impulse_nms'][0] = .01
            if defect == 'nan': changed[3]['post']['bodies'][0]['pose_world']['position_m']['x'] = float('nan')
            with self.subTest(defect=defect), self.assertRaises(ValueError): replay.verify_rows(changed, self.value)

    def test_full_reader_finalization_and_no_claim_publication(self):
        folder = self.unique('reader-synthetic')
        value, rows = self.value, self.synthetic_rows()
        ticket = dict(nonce='b'*32, parent_pid=123, input_sha256=replay.sha(replay.encoded(value)), bindings=[])
        replay.write_new(folder/'ticket.json', ticket); replay.write_new(folder/'input.json', value)
        replay.write_new(folder/'launch.json', dict(child_pid=456))
        replay.write_new(folder/'initial.json', dict(synthetic=True))
        with (folder/'trajectory.jsonl').open('xb') as stream:
            for row in rows: stream.write(replay.encoded(row))
        receipt = dict(status='complete', nonce=ticket['nonce'], parent_pid=123, child_pid=456,
            input_sha256=ticket['input_sha256'], world_build_count=1, outer_steps=400, solver_step_count=2000,
            policy_feedback_call_count=0, random_draw_count=0, warnings=[0],
            initial=replay.file_binding(folder/'initial.json'), trajectory=replay.file_binding(folder/'trajectory.jsonl'), **replay.FLAGS)
        replay.write_new(folder/'worker-receipt.json', receipt)
        result = replay.read_result(folder)
        self.assertEqual('valid_development_observation', result['status'])
        self.assertFalse(any(result[k] for k in replay.FLAGS))
        self.assertEqual(0, result['world_count_during_read'])
        self.assertTrue(result['per_limb'][0]['any_substep_bearing']['intervals'][0]['initial_absence_censored'])
        for field, replacement in [('release_authority',True), ('status','partial'), ('child_pid',457), ('solver_step_count',1999)]:
            changed = copy.deepcopy(receipt); changed[field] = replacement
            with patch.object(replay, 'read', side_effect=lambda path: changed if Path(path).name == 'worker-receipt.json' else json.loads(Path(path).read_text(encoding='utf-8'))):
                with self.subTest(field=field), self.assertRaises(ValueError): replay.read_result(folder)

    def test_serialization_collision_and_nonfinite_refuse(self):
        folder = self.unique('serialization-negative')
        replay.write_new(folder/'receipt.json', dict(retained=True))
        with self.assertRaises(FileExistsError): replay.write_new(folder/'receipt.json', dict(retained=False))
        self.assertEqual(dict(retained=True), replay.read(folder/'receipt.json'))
        with self.assertRaises(ValueError): replay.encoded(dict(value=float('nan')))


if __name__ == '__main__':
    unittest.main(verbosity=2)
