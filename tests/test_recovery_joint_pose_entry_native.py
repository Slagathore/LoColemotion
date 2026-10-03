"""Actual R10I DLL on retained measurements; counterfactual commands, zero worlds."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'sdk/python'), str(ROOT / 'sdk/conformance')]
from sporespore_locomotion import LocomotionCore
from test_development_v32_recontact_component import NativeApi
from development_v44_mujoco_replay import exact_json_integers

POLICY = 'sporespore_balanced_wave_joint_pose_entry_v1'
V50 = 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1'


class JointPoseEntryNative(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binding = json.loads((ROOT / 'sdk/development/recovery_candidates/r10i-joint-pose-entry-core-v1.runtime.json').read_text(encoding='utf-8'))
        image = Path(cls.binding['runtime']['path'])
        assert 'sha256:'+hashlib.sha256(image.read_bytes()).hexdigest() == cls.binding['runtime']['raw_sha256']
        cls.core = LocomotionCore(image)
        cls.native = NativeApi(image)
        closure = json.loads((ROOT / 'sdk/recovery/r10h_stance_entry_pair_closure_v1.json').read_text(encoding='utf-8'))
        reports = []
        for role in ('matched_no_kick_continuation', 'kick_passive_recovery_resume'):
            bound = closure['roles'][role]['report']
            raw = Path(bound['path']).read_bytes()
            assert 'sha256:'+hashlib.sha256(raw).hexdigest() == bound['raw_sha256']
            reports.append(json.loads(raw))
        cls.descriptor = exact_json_integers(reports[0]['configuration']['base_descriptor'])
        cls.neutral = reports[0]['stance_entry']['neutral_control_rows']
        cls.walking = reports[1]['development_walking_entry']['rows']

    def call(self, request):
        status, raw = self.native.raw('ss_balanced_wave_policy_step_json', self.core._input_bytes(exact_json_integers(request)))
        self.assertEqual(0, status, raw[:800])
        return raw, json.loads(raw)['value']

    def entry_request(self, row, memory):
        request = copy.deepcopy(row['step']['sample_receipt']['request'])
        request.update(schema_version='sporespore_balanced_wave_policy_step_request_v1',
                       descriptor=self.descriptor, policy_id=POLICY, memory=memory)
        request['command']['desired_planar_velocity_task_m_s'] = dict(x=0.0, y=0.0, z=0.0)
        return request

    def test_every_original_v50_native_response_stays_byte_exact(self):
        self.assertEqual(1157, len(self.walking))
        for row in self.walking:
            request = copy.deepcopy(row['request'])
            request.update(schema_version='sporespore_balanced_wave_policy_step_request_v3',
                           descriptor=self.descriptor, policy_id=V50)
            raw, _ = self.call(request)
            self.assertEqual(row['raw_native_response_sha256'], 'sha256:'+hashlib.sha256(raw).hexdigest())

    def test_fresh_stateless_and_cached_entry_match_for_all_240_retained_states(self):
        memory = self.core.balanced_wave_policy_initial_memory(POLICY, self.descriptor)
        previous = None
        with self.core.create_balanced_wave_policy_session(POLICY, self.descriptor) as session:
            for row in self.neutral:
                request = self.entry_request(row, memory)
                _, output = self.call(request)
                self.assertFalse(output['actuation']['safe_no_actuation'])
                cached = session.step({k: v for k, v in request.items() if k not in ('descriptor', 'policy_id')})
                self.assertEqual(output, cached)
                current = []
                for i, command in enumerate(output['actuation']['ordered_commands']):
                    self.assertLessEqual(abs(command['target_velocity_rad_s']), .75)
                    self.assertFalse(command['position_saturated'])
                    current.append(command['requested_target_position_rad'])
                    if previous is not None:
                        self.assertLessEqual(abs(current[i]-previous[i]), .75/120+1e-12)
                previous = current
                memory = output['next_memory']
        self.assertEqual(239, memory['joint_pose_entry']['completed_reference_intervals'])
        self.assertTrue(memory['joint_pose_entry']['reference_ramp_complete'])
        self.assertEqual(memory['joint_pose_entry']['ordered_goal_positions_rad'], previous)

    def test_native_entry_refuses_original_moving_command_and_crossed_memory(self):
        initial = self.core.balanced_wave_policy_initial_memory(POLICY, self.descriptor)
        request = self.entry_request(self.neutral[0], initial)
        request['command']['desired_planar_velocity_task_m_s']['x'] = .2
        _, refused = self.call(request)
        self.assertTrue(refused['actuation']['safe_no_actuation'])
        self.assertEqual(initial, refused['next_memory'])
        request['command']['desired_planar_velocity_task_m_s']['x'] = 0.0
        _, first = self.call(request)
        for field, delta in [('ramp_intervals', 1), ('last_sample_time_s', 1.0/120)]:
            memory = copy.deepcopy(first['next_memory'])
            memory['joint_pose_entry'][field] += delta
            _, refused = self.call(self.entry_request(self.neutral[1], memory))
            self.assertTrue(refused['actuation']['safe_no_actuation'])
            self.assertEqual(memory, refused['next_memory'])


if __name__ == '__main__':
    unittest.main()
