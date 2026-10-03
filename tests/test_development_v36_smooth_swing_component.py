"""Actual V36 DLL on V35 retained inputs; no engine or alternate trajectory."""
import copy
import ctypes
import hashlib
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_candidate as candidate
import test_development_v35_feasible_support_component as previous_component
from test_development_v32_recontact_component import NativeApi

POLICY = 'sporespore_balanced_wave_recovery_smooth_swing_v1'
PARENT = 'sporespore_balanced_wave_recovery_feasible_support_v1'
MODE = 'phase_only_existing_loaded_peak_swing_lift_v1'
PROFILE = ROOT/'sdk/development/recovery_candidates/v36-smooth-swing-v1.json'


def request_bytes(value):
    """Mirror adapter integer normalization, NOT canonical-hash rounding.

    Only integral finite floats become integers; all fractional binary64
    values retain their round-trip JSON precision. This is input transport,
    not permission to normalize immutable closure or evidence records.
    """
    def normalize(item):
        if isinstance(item, dict): return {k: normalize(v) for k, v in item.items()}
        if isinstance(item, list): return [normalize(v) for v in item]
        if isinstance(item, float) and math.isfinite(item) and item.is_integer() and -(1<<63) <= item <= float((1<<63)-1):
            return max(-(1<<63), min((1<<63)-1, int(item)))
        return item
    return json.dumps(normalize(value), sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


class V36SmoothSwing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure = candidate.read(ROOT/'sdk/development/recovery_attempts/2d88c07d2ae0497a8fe9bc1fb60832e5.json')
        path = Path(cls.closure['kicked_report']['path'])
        assert candidate.sha(path) == cls.closure['kicked_report']['raw_sha256']
        cls.report = candidate.read(path)
        cls.entries = cls.report['development_walking_entry']['rows']
        cls.descriptor = cls.report['configuration']['base_descriptor']
        cls.profile = candidate.read(PROFILE)
        cls.binding = candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding = candidate.read(ROOT/'sdk/development/recovery_candidates/v35-feasible-support-v1.runtime.json')
        for binding in (cls.binding, cls.old_binding):
            for p in (Path(binding['runtime']['path']), ROOT/binding['local_build_path']):
                assert candidate.sha(p) == binding['runtime']['raw_sha256']
        cls.native = NativeApi(cls.binding['runtime']['path'])
        cls.old = NativeApi(cls.old_binding['runtime']['path'])
        cls.floor = cls.entries[0]['request']['floor_reference']

    def initial(self):
        status, result = self.native.call('ss_balanced_wave_policy_initial_memory_json', dict(
            schema_version='sporespore_balanced_wave_policy_initial_memory_request_v1', policy_id=POLICY, descriptor=self.descriptor))
        self.assertEqual(0, status)
        memory = result['value']
        for limb, old in zip(memory['ordered_limb_memory'], self.entries[0]['request']['memory']['ordered_limb_memory']):
            self.assertEqual(limb['limb_id'], old['limb_id'])
            limb['gait_step'] = old['gait_step']
            limb['evidence_gait_step_limit'] = old['evidence_gait_step_limit']
        return memory

    def request(self, entry, memory):
        return dict(entry['request'], schema_version='sporespore_balanced_wave_policy_step_request_v2',
            policy_id=POLICY, descriptor=self.descriptor, memory=memory)

    def test_binding_profile_and_nonrunnable_component(self):
        self.assertEqual(314, self.binding['core_test_count'])
        self.assertEqual(self.profile['runtime_binding_sha256'], candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT/source['path']), source['path'])
        with self.assertRaisesRegex(ValueError, 'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        request = dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1', descriptor=self.descriptor, policy_id=POLICY)
        status, result = self.native.call('ss_balanced_wave_policy_profile_json', request)
        self.assertEqual(0, status)
        status, old = self.old.call('ss_balanced_wave_policy_profile_json', dict(request, policy_id=PARENT))
        self.assertEqual(0, status)
        expected = dict(old['value'], policy_id=POLICY,
            schema_version='sporespore_balanced_wave_recovery_smooth_swing_profile_v1', swing_lift_mode_id=MODE)
        self.assertEqual(expected, result['value'])
        height = self.entries[0]['request']['state']['base_pose_world']['position_m']['y']
        self.assertEqual(height.hex(), json.loads(request_bytes(dict(height=height)))['height'].hex())
        rounded = json.loads(self.native.canonical(dict(height=height)))['height']
        self.assertNotEqual(height, rounded)  # Guard the caught canonical-hash/transport confusion.
        print('V36_EXPORTED_PROFILE', json.dumps(dict(profile=result['value'],
            native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(result['value'])).hexdigest(),
            physical_selection_refused=True)), flush=True)

    def test_2000_old_outputs_and_six_recovery_fixtures_remain_exact(self):
        policies = (PARENT, 'sporespore_balanced_wave_recovery_floor_support_v1',
            'sporespore_balanced_wave_recovery_bounded_support_v1',
            'sporespore_balanced_wave_recovery_swing_end_recontact_v1', 'sporespore_balanced_wave_bw5r_b_v1')
        memories = ('sporespore_balanced_wave_recovery_feasible_support_memory_v1',
            'sporespore_balanced_wave_recovery_floor_support_memory_v1',
            'sporespore_balanced_wave_recovery_support_memory_v1',
            'sporespore_balanced_wave_memory_v1', 'sporespore_balanced_wave_memory_v1')
        counts = {}
        for index, (policy, memory_schema) in enumerate(zip(policies, memories)):
            counts[policy] = 0
            for entry in self.entries:
                r = copy.deepcopy(dict(entry['request'], schema_version='sporespore_balanced_wave_policy_step_request_v2',
                    policy_id=policy, descriptor=self.descriptor))
                r['memory']['schema_version'] = memory_schema
                if index >= 2:
                    r['schema_version'] = 'sporespore_balanced_wave_policy_step_request_v1'
                    del r['floor_reference']; r['memory'].pop('floor_reference_sha256', None)
                if index >= 3:
                    del r['memory']['support_reference']
                raw = request_bytes(r)
                expected = self.old.raw('ss_balanced_wave_policy_step_json', raw)
                self.assertEqual(0, expected[0])
                self.assertFalse(json.loads(expected[1])['value']['actuation']['safe_no_actuation'])
                self.assertEqual(expected, self.native.raw('ss_balanced_wave_policy_step_json', raw))
                counts[policy] += 1
        fixtures = []
        for binding in (self.old_binding, self.binding):
            path = Path(binding['compiled_fixtures']['path'])
            self.assertEqual(candidate.sha(path), binding['compiled_fixtures']['raw_sha256'])
            fixtures.append([s for s in path.read_text().splitlines() if s.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')])
        self.assertEqual(6, len(fixtures[0])); self.assertEqual(*fixtures)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            candidate.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        print('V36_OLD_OUTPUT_COMPATIBILITY', json.dumps(dict(exact_raw_outputs=sum(counts.values()),
            per_policy=counts, exact_recovery_fixtures=6, old_physical_records_changed=False)), flush=True)

    def test_400_session_stateless_matches_preserved_plans_gates_and_limits(self):
        create = self.native.library.ss_balanced_wave_policy_session_create_json
        create.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint64)]; create.restype = ctypes.c_int
        data = request_bytes(dict(schema_version='sporespore_balanced_wave_policy_session_create_request_v1', descriptor=self.descriptor, policy_id=POLICY))
        handle = ctypes.c_uint64(); self.assertEqual(0, create(data, len(data), ctypes.byref(handle)))
        session = self.native.library.ss_balanced_wave_policy_session_step_json
        session.argtypes = [ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]; session.restype = ctypes.c_int
        destroy = self.native.library.ss_balanced_wave_policy_session_destroy
        destroy.argtypes = [ctypes.c_uint64]; destroy.restype = ctypes.c_int
        memory = self.initial(); chain = hashlib.sha256(); slew = changed_goals = 0
        try:
            for local, entry in enumerate(self.entries, 1):
                encoded = request_bytes(self.request(entry, memory)); request = json.loads(encoded)
                status, raw = self.native.raw('ss_balanced_wave_policy_step_json', encoded)
                self.assertEqual(0, status); value = json.loads(raw)['value']
                self.assertFalse(value['actuation']['safe_no_actuation']); chain.update(raw)
                if local == 1:
                    # Preserve the caught harness defect as a real negative:
                    # identity/descriptor belong to session creation, not step.
                    bad = request_bytes(dict(request, schema_version='sporespore_balanced_wave_policy_session_step_request_v2'))
                    size_bad = ctypes.c_size_t(); session(handle, bad, len(bad), None, 0, ctypes.byref(size_bad))
                    self.assertTrue(0 < size_bad.value < 2_000_000)
                    out_bad = ctypes.create_string_buffer(size_bad.value)
                    self.assertEqual(3, session(handle, bad, len(bad), out_bad, size_bad.value, ctypes.byref(size_bad)))
                    self.assertIn(b'unknown field', out_bad.raw[:size_bad.value])
                    self.assertIn(b'descriptor', out_bad.raw[:size_bad.value])
                session_request = {k: v for k, v in request.items() if k not in ('descriptor', 'policy_id')}
                session_request['schema_version'] = 'sporespore_balanced_wave_policy_session_step_request_v2'
                data = request_bytes(session_request)
                size = ctypes.c_size_t(); session(handle, data, len(data), None, 0, ctypes.byref(size))
                self.assertTrue(0 < size.value < 2_000_000); out = ctypes.create_string_buffer(size.value)
                self.assertEqual(0, session(handle, data, len(data), out, size.value, ctypes.byref(size)))
                self.assertEqual(raw, out.raw[:size.value])
                self.assertEqual(entry['native_output']['next_memory']['ordered_limb_memory'], value['next_memory']['ordered_limb_memory'])
                receipt = value['actuation']['receipt']['recovery_support_plane']
                # Compare actual parent/native outputs on identical inputs.
                # Only the required policy/memory identity changes; do not use
                # a displayed/host-reserialized old receipt as exact ABI bytes.
                parent_request = copy.deepcopy(request); parent_request['policy_id'] = PARENT
                parent_request['memory']['schema_version'] = 'sporespore_balanced_wave_recovery_feasible_support_memory_v1'
                parent_status, parent_raw = self.old.raw('ss_balanced_wave_policy_step_json', request_bytes(parent_request))
                self.assertEqual(0, parent_status); parent_value = json.loads(parent_raw)['value']
                self.assertFalse(parent_value['actuation']['safe_no_actuation'])
                self.assertEqual(parent_value['next_memory']['ordered_limb_memory'], value['next_memory']['ordered_limb_memory'])
                old = parent_value['actuation']['receipt']['recovery_support_plane']
                self.assertEqual(MODE, receipt['swing_lift_mode_id'])
                self.assertEqual(old['feasible_support_plan'], receipt['feasible_support_plan'])
                self.assertEqual(old['floor_reference'], receipt['floor_reference'])
                for p, before in zip(receipt['ordered_limb_proposals'], old['ordered_limb_proposals']):
                    for key in ('nominal_leg_direction_rad', 'projected_support_hip_rad', 'projected_support_knee_rad',
                                'scheduled_phase_step', 'support_reference_torso_height_m'):
                        self.assertEqual(before[key], p[key])
                    phase = p['scheduled_phase_step']; amplitude = request['command']['gait_amplitude']
                    expected = amplitude*(.82*1.75+.4)*math.sin(math.pi*phase/72) if phase < 72 else 0.
                    self.assertAlmostEqual(expected/1.1, p['walking_knee_fraction'], delta=1e-14)
                    changed_goals += p['goal_knee_rad'] != before['goal_knee_rad']
                for i, c in enumerate(value['actuation']['ordered_commands']):
                    lo, hi = (-.72, .72) if i%2 == 0 else (0., 1.1)
                    self.assertTrue(lo <= c['requested_target_position_rad'] <= hi)
                    self.assertFalse(c['position_saturated'])
                    self.assertLessEqual(abs(c['requested_target_position_rad']-memory['support_reference']['ordered_target_positions_rad'][i]),
                        c['maximum_target_speed_rad_s']*receipt['reference_step_duration_s']+1e-14)
                    slew += c['slew_limited']
                    if local == 1: self.assertEqual(0., c['requested_target_position_rad'])
                memory = value['next_memory']
        finally:
            self.assertEqual(0, destroy(handle))
        self.assertGreater(changed_goals, 0)
        print('V36_RETAINED_INPUT_PROBE', json.dumps(dict(input_count=400, bounded_command_count=3200,
            exact_session_stateless_matches=400, unchanged_parent_height_plans=400, unchanged_parent_limb_gate_memories=400,
            unknown_session_identity_fields_refused=1,
            fractional_input_transport='binary64_roundtrip_no_canonical_hash_projection',
            parent_comparison='same_state_command_and_memory_values_except_required_policy_memory_schema',
            changed_knee_goals=changed_goals, slew_limited_command_count=slew, raw_output_chain_sha256='sha256:'+chain.hexdigest(),
            world_build_count=0, solver_step_count=0, new_physical_trajectory=False, physical_acceptance_authority=False)), flush=True)

    def test_360_fixed_phase_contact_pairs_through_exported_interface(self):
        amplitude = 1.1/(.82*1.75+.4)
        for phase in range(360):
            pair = []
            for bearing in (False, True):
                memory = self.initial()
                for limb in memory['ordered_limb_memory']: limb['gait_step'] = phase+90
                request = copy.deepcopy(self.request(self.entries[0], memory))
                request['command']['gait_amplitude'] = amplitude
                for c in request['state']['ordered_contact_observations']:
                    c['presence'] = bearing; c['bears_support'] = bearing
                status, raw = self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(request)); result = json.loads(raw)
                self.assertEqual(0, status); self.assertFalse(result['value']['actuation']['safe_no_actuation'])
                receipt = result['value']['actuation']['receipt']['recovery_support_plane']
                p = receipt['ordered_limb_proposals'][0]
                self.assertEqual(phase, p['scheduled_phase_step'])
                expected = math.sin(math.pi*phase/72) if phase < 72 else 0.
                self.assertAlmostEqual(expected, p['walking_knee_fraction'], delta=1e-14)
                if phase == 0 or phase >= 72: self.assertEqual(0., p['walking_knee_fraction'])
                pair.append(receipt)
            self.assertEqual(*pair)
        print('V36_FIXED_PHASE_CONTACT_PAIRS', json.dumps(dict(pairs=360, native_outputs=720,
            phase_endpoints_exact=True, contact_independent_raw_lift=True,
            whole_controller_contact_independence_claimed=False, world_build_count=0)), flush=True)

    # The floor/source refusal contract is unchanged; reuse its actual ABI test.
    test_missing_crossed_and_drifting_context_refuse = previous_component.V35FeasibleSupport.test_missing_crossed_and_drifting_context_refuse


if __name__ == '__main__':
    unittest.main()
