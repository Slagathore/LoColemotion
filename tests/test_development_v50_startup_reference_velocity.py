"""Actual native API on retained measurements; no counterfactual physics claim."""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'sdk/python'), str(ROOT / 'sdk/conformance')]
from sporespore_locomotion import LocomotionCore
from test_development_v32_recontact_component import NativeApi
import development_v49_godot_cycle_stop_diagnosis as godot
import development_v49_cycle_stop_diagnosis as mujoco
from development_v44_mujoco_replay import exact_json_integers

POLICY = 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1'
MEMORY = 'sporespore_balanced_wave_recovery_startup_reference_velocity_memory_v1'


class StartupReferenceVelocity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dll = Path(os.environ['SPORE_V50_DLL'])
        cls.core = LocomotionCore(cls.dll)
        cls.native = NativeApi(str(cls.dll))
        report, _ = godot.read_source()
        cls.godot_rows = report['development_walking_entry']['rows']
        cls.descriptor = exact_json_integers(report['configuration']['base_descriptor'])
        cls.mujoco_rows, value, _ = mujoco.read_source()

    def call(self, request):
        status, raw = self.native.raw('ss_balanced_wave_policy_step_json', self.core._input_bytes(request))
        self.assertEqual(0, status)
        return raw, json.loads(raw)['value']

    def request(self, row, successor=True):
        r = copy.deepcopy(row['request'])
        r['descriptor'] = self.descriptor
        r['schema_version'] = 'sporespore_balanced_wave_policy_step_request_v3'
        r['policy_id'] = POLICY if successor else 'sporespore_balanced_wave_recovery_remaining_support_release_v1'
        if successor:
            r['memory']['schema_version'] = MEMORY
        return exact_json_integers(r)

    def test_all_original_v49_godot_and_mujoco_native_responses_stay_exact(self):
        for row in self.godot_rows:
            raw, out = self.call(self.request(row, False))
            self.assertEqual(row['raw_native_response_sha256'], 'sha256:' + hashlib.sha256(raw).hexdigest())
            # The raw digest is authoritative. Godot's subsequent JSON decoder
            # rounds some retained numeric fields; it is not a raw C ABI oracle.
        for row in self.mujoco_rows:
            raw, out = self.call(row['request'])
            self.assertEqual(row['raw_response_sha256'], 'sha256:' + hashlib.sha256(raw).hexdigest())
            self.assertEqual(row['output'], out)

    def test_startup_equation_removes_second_command_clipping_and_then_returns_to_parent(self):
        for n, row in enumerate(self.godot_rows[:75], 1):
            request = self.request(row)
            _, out = self.call(request)
            self.assertFalse(out['actuation']['safe_no_actuation'])
            old_raw, old = self.call(self.request(row, False))
            self.assertEqual(row['raw_native_response_sha256'], 'sha256:' + hashlib.sha256(old_raw).hexdigest())
            plane = out['actuation']['receipt']['recovery_support_plane']
            pose = plane['anchored_body_pose']
            scale = pose['reference_velocity_startup_scale']
            u = min(1., (n-1)/72)
            self.assertAlmostEqual(3*u*u-2*u*u*u, scale, places=13)
            for key in ('desired_body_position_world_m', 'ordered_foot_targets_world_m', 'ordered_joint_goals_rad', 'next_memory'):
                self.assertEqual(old['actuation']['receipt']['recovery_support_plane']['anchored_body_pose'][key], pose[key])
            old_memory = copy.deepcopy(old['next_memory'])
            old_memory['schema_version'] = MEMORY
            self.assertEqual(old_memory, out['next_memory'])
            for i, command in enumerate(out['actuation']['ordered_commands']):
                observed = request['state']['ordered_joint_observations'][i]
                raw = 8*(command['requested_target_position_rad']-observed['position_rad']) - .65*observed['velocity_rad_s']
                raw += 1.65*plane['ordered_reference_velocity_rad_s'][i]*scale
                limit = command['maximum_target_speed_rad_s']
                self.assertAlmostEqual(-max(-limit, min(limit, raw)), command['target_velocity_rad_s'], places=12)
            if n == 2:
                self.assertTrue(all(not c['velocity_saturated'] for c in out['actuation']['ordered_commands']))
                self.assertLess(max(abs(c['target_velocity_rad_s']) for c in out['actuation']['ordered_commands']), .4)
                self.assertTrue(all(c['velocity_saturated'] for c in old['actuation']['ordered_commands'][4:]))
            if scale == 1.0 or n == 1:
                self.assertEqual(old['actuation']['ordered_commands'], out['actuation']['ordered_commands'])
        self.assertEqual(1., scale)

    def test_fresh_stateless_and_cached_startup_use_the_same_memory_chain(self):
        memory = self.core.balanced_wave_policy_initial_memory(POLICY, self.descriptor)
        for limb in memory['ordered_limb_memory']:
            limb['gait_step'] = 90
        with self.core.create_balanced_wave_policy_session(POLICY, self.descriptor) as session:
            for row in self.godot_rows[:80]:
                r = self.request(row)
                r['memory'] = memory
                _, out = self.call(r)
                self.assertEqual(out, session.step_with_measured_body({k:v for k,v in r.items() if k not in ('descriptor', 'policy_id')}))
                self.assertFalse(out['actuation']['safe_no_actuation'])
                memory = out['next_memory']

    def test_new_selector_preserves_strict_clock_body_and_memory_refusals(self):
        for kind in ('old_memory', 'clock', 'body_clock', 'missing_pose'):
            r = self.request(self.godot_rows[1])
            if kind == 'old_memory': r['memory']['schema_version'] = 'sporespore_balanced_wave_recovery_remaining_support_release_memory_v1'
            elif kind == 'clock': r['memory']['anchored_body_pose']['last_sample_time_s'] += 1.
            elif kind == 'body_clock': r['measured_body_frame']['semantic_step'] += 1
            else: r['memory'].pop('anchored_body_pose')
            _, out = self.call(r)
            self.assertTrue(out['actuation']['safe_no_actuation'], kind)
            self.assertEqual(r['memory'], out['next_memory'])


if __name__ == '__main__':
    unittest.main()
