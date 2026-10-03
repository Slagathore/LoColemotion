"""V37 real exported calls on saved V36 inputs, never a physics rollout."""
import copy
import ctypes
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_candidate as candidate
from test_development_v32_recontact_component import NativeApi
from test_development_v36_smooth_swing_component import request_bytes

POLICY = 'sporespore_balanced_wave_recovery_reference_velocity_v1'
PARENT = 'sporespore_balanced_wave_recovery_smooth_swing_v1'
MEMORY = 'sporespore_balanced_wave_recovery_reference_velocity_memory_v1'
PARENT_MEMORY = 'sporespore_balanced_wave_recovery_smooth_swing_memory_v1'
MODE = 'bounded_slewed_reference_velocity_tracking_v1'
PROFILE = ROOT/'sdk/development/recovery_candidates/v37-reference-velocity-v1.json'


class V37ReferenceVelocity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure = candidate.read(ROOT/'sdk/development/recovery_attempts/9959c99703944cbd80789ac00ed2d90c.json')
        path = Path(cls.closure['kicked_report']['path'])
        assert candidate.sha(path) == cls.closure['kicked_report']['raw_sha256']
        cls.report = candidate.read(path); cls.entries = cls.report['development_walking_entry']['rows']
        assert len(cls.entries) == 400
        cls.descriptor = cls.report['configuration']['base_descriptor']
        cls.profile = candidate.read(PROFILE)
        cls.binding = candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding = candidate.read(ROOT/'sdk/development/recovery_candidates/v36-smooth-swing-v1.runtime.json')
        for binding in (cls.binding, cls.old_binding):
            for image in (Path(binding['runtime']['path']), ROOT/binding['local_build_path']):
                assert candidate.sha(image) == binding['runtime']['raw_sha256']
        cls.native = NativeApi(cls.binding['runtime']['path']); cls.old = NativeApi(cls.old_binding['runtime']['path'])

    def initial(self):
        status, result = self.native.call('ss_balanced_wave_policy_initial_memory_json', dict(
            schema_version='sporespore_balanced_wave_policy_initial_memory_request_v1', policy_id=POLICY, descriptor=self.descriptor))
        self.assertEqual(0, status); memory = result['value']; self.assertEqual(MEMORY, memory['schema_version'])
        for limb, before in zip(memory['ordered_limb_memory'], self.entries[0]['request']['memory']['ordered_limb_memory']):
            self.assertEqual(limb['limb_id'], before['limb_id'])
            for key in ('gait_step', 'evidence_gait_step_limit'): limb[key] = before[key]
        return memory

    def request(self, entry, memory):
        return copy.deepcopy(dict(entry['request'], schema_version='sporespore_balanced_wave_policy_step_request_v2',
            descriptor=self.descriptor, policy_id=POLICY, memory=memory))

    def native_value(self, request, api=None):
        status, raw = (api or self.native).raw('ss_balanced_wave_policy_step_json', request_bytes(request))
        self.assertEqual(0, status); value = json.loads(raw)['value']
        self.assertFalse(value['actuation']['safe_no_actuation']); return raw, value

    def test_binding_profile_and_nonrunnable_selection(self):
        self.assertEqual(318, self.binding['core_test_count'])
        self.assertEqual(self.profile['runtime_binding_sha256'], candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT/source['path']), source['path'])
        with self.assertRaisesRegex(ValueError, 'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        request = dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1', descriptor=self.descriptor, policy_id=POLICY)
        status, result = self.native.call('ss_balanced_wave_policy_profile_json', request); self.assertEqual(0, status)
        status, old = self.old.call('ss_balanced_wave_policy_profile_json', dict(request, policy_id=PARENT)); self.assertEqual(0, status)
        self.assertEqual(dict(old['value'], policy_id=POLICY,
            schema_version='sporespore_balanced_wave_recovery_reference_velocity_profile_v1', reference_velocity_mode_id=MODE), result['value'])
        height = self.entries[0]['request']['state']['base_pose_world']['position_m']['y']
        self.assertEqual(height.hex(), json.loads(request_bytes(dict(height=height)))['height'].hex())
        self.assertNotEqual(height, json.loads(self.native.canonical(dict(height=height)))['height'])
        print('V37_EXPORTED_PROFILE', json.dumps(dict(profile=result['value'],
            native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(result['value'])).hexdigest(),
            physical_selection_refused=True)), flush=True)

    def test_2400_old_outputs_and_six_recovery_fixtures_are_exact(self):
        policies = (PARENT, 'sporespore_balanced_wave_recovery_feasible_support_v1',
            'sporespore_balanced_wave_recovery_floor_support_v1', 'sporespore_balanced_wave_recovery_bounded_support_v1',
            'sporespore_balanced_wave_recovery_swing_end_recontact_v1', 'sporespore_balanced_wave_bw5r_b_v1')
        schemas = (PARENT_MEMORY, 'sporespore_balanced_wave_recovery_feasible_support_memory_v1',
            'sporespore_balanced_wave_recovery_floor_support_memory_v1', 'sporespore_balanced_wave_recovery_support_memory_v1',
            'sporespore_balanced_wave_memory_v1', 'sporespore_balanced_wave_memory_v1')
        counts = {}
        for index, (policy, schema) in enumerate(zip(policies, schemas)):
            counts[policy] = 0
            for entry in self.entries:
                r = self.request(entry, entry['request']['memory']); r['policy_id'] = policy; r['memory']['schema_version'] = schema
                if index >= 3:
                    r['schema_version'] = 'sporespore_balanced_wave_policy_step_request_v1'
                    del r['floor_reference']; r['memory'].pop('floor_reference_sha256', None)
                if index >= 4: del r['memory']['support_reference']
                expected, _ = self.native_value(r, self.old)
                actual, _ = self.native_value(r); self.assertEqual(expected, actual); counts[policy] += 1
        fixtures = []
        for binding in (self.old_binding, self.binding):
            path = Path(binding['compiled_fixtures']['path'])
            self.assertEqual(candidate.sha(path), binding['compiled_fixtures']['raw_sha256'])
            fixtures.append([line for line in path.read_text().splitlines() if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')])
        self.assertEqual(6, len(fixtures[0])); self.assertEqual(*fixtures)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            candidate.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        print('V37_OLD_OUTPUT_COMPATIBILITY', json.dumps(dict(exact_raw_outputs=sum(counts.values()),
            per_policy=counts, exact_recovery_fixtures=6, old_physical_records_changed=False)), flush=True)

    def test_400_session_stateless_matches_preserve_paths_and_reconstruct_velocities(self):
        create = self.native.library.ss_balanced_wave_policy_session_create_json
        create.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint64)]; create.restype = ctypes.c_int
        data = request_bytes(dict(schema_version='sporespore_balanced_wave_policy_session_create_request_v1', descriptor=self.descriptor, policy_id=POLICY))
        handle = ctypes.c_uint64(); self.assertEqual(0, create(data, len(data), ctypes.byref(handle)))
        session = self.native.library.ss_balanced_wave_policy_session_step_json
        session.argtypes = [ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]; session.restype = ctypes.c_int
        destroy = self.native.library.ss_balanced_wave_policy_session_destroy
        destroy.argtypes = [ctypes.c_uint64]; destroy.restype = ctypes.c_int
        memory = self.initial(); chain = hashlib.sha256(); changed = saturated = old_saturated = 0
        try:
            for local, entry in enumerate(self.entries, 1):
                request = self.request(entry, memory); raw, value = self.native_value(request); chain.update(raw)
                if local == 1:
                    bad = request_bytes(dict(request, schema_version='sporespore_balanced_wave_policy_session_step_request_v2'))
                    size = ctypes.c_size_t(); session(handle, bad, len(bad), None, 0, ctypes.byref(size))
                    self.assertTrue(0 < size.value < 2_000_000); out = ctypes.create_string_buffer(size.value)
                    self.assertEqual(3, session(handle, bad, len(bad), out, size.value, ctypes.byref(size)))
                    self.assertIn(b'unknown field', out.raw[:size.value])
                sr = {k:v for k,v in request.items() if k not in ('descriptor', 'policy_id')}
                sr['schema_version'] = 'sporespore_balanced_wave_policy_session_step_request_v2'; data = request_bytes(sr)
                size = ctypes.c_size_t(); session(handle, data, len(data), None, 0, ctypes.byref(size))
                self.assertTrue(0 < size.value < 2_000_000); out = ctypes.create_string_buffer(size.value)
                self.assertEqual(0, session(handle, data, len(data), out, size.value, ctypes.byref(size)))
                self.assertEqual(raw, out.raw[:size.value])
                pr = copy.deepcopy(request); pr['policy_id'] = PARENT; pr['memory']['schema_version'] = PARENT_MEMORY
                _, parent = self.native_value(pr, self.old)
                self.assertEqual(dict(parent['next_memory'], schema_version=MEMORY), value['next_memory'])
                receipt = value['actuation']['receipt']['recovery_support_plane']
                rates = receipt['ordered_reference_velocity_rad_s']; self.assertEqual(8, len(rates))
                self.assertEqual(dict(parent['actuation']['receipt']['recovery_support_plane'],
                    reference_velocity_mode_id=MODE, ordered_reference_velocity_rad_s=rates), receipt)
                self.assertEqual('sporespore_recovery_reference_velocity_controller_step_receipt_v1', value['actuation']['receipt']['schema_version'])
                dt = receipt['reference_step_duration_s']
                for i, (command, before) in enumerate(zip(value['actuation']['ordered_commands'], parent['actuation']['ordered_commands'])):
                    cap = command['maximum_target_speed_rad_s']; target = command['requested_target_position_rad']
                    prior = memory['support_reference']['ordered_target_positions_rad'][i]
                    rate = max(-cap, min(cap, (target-prior)/dt)) if dt > 0 else 0.
                    self.assertAlmostEqual(rate, rates[i], delta=1e-14); self.assertLessEqual(abs(rates[i]), cap)
                    joint = request['state']['ordered_joint_observations'][i]
                    raw_velocity = 8.*(target-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
                    expected = -max(-cap, min(cap, raw_velocity))
                    self.assertAlmostEqual(expected, command['target_velocity_rad_s'], delta=1e-13)
                    self.assertLessEqual(abs(command['target_velocity_rad_s']), cap)
                    self.assertEqual(abs(raw_velocity)>cap, command['velocity_saturated'])
                    allowed = {k:command[k] for k in ('target_velocity_rad_s', 'velocity_saturated', 'safety_contribution_rad_s')}
                    self.assertEqual(dict(before, **allowed), command)
                    self.assertEqual(0., command['residual_contribution_rad_s'])
                    changed += command['target_velocity_rad_s'] != before['target_velocity_rad_s']
                    saturated += command['velocity_saturated']; old_saturated += before['velocity_saturated']
                    if local == 1: self.assertEqual(before, command); self.assertEqual(0., rate)
                memory = value['next_memory']
        finally: self.assertEqual(0, destroy(handle))
        self.assertGreater(changed, 0); self.assertEqual(280, saturated); self.assertEqual(0, old_saturated)
        print('V37_RETAINED_INPUT_PROBE', json.dumps(dict(input_count=400, bounded_command_count=3200,
            exact_session_stateless_matches=400, unchanged_parent_position_paths=400, unchanged_parent_gate_memories=400,
            independently_reconstructed_velocity_commands=3200, changed_commands=changed, velocity_saturated_commands=saturated,
            parent_velocity_saturated_commands=old_saturated, unchanged_initial_commands=8, unknown_session_identity_fields_refused=1,
            raw_output_chain_sha256='sha256:'+chain.hexdigest(), input_transport='binary64_roundtrip_not_hash_projection',
            world_build_count=0, solver_step_count=0, new_physical_trajectory=False, physical_acceptance_authority=False)), flush=True)

    def test_missing_crossed_and_drifting_context_refuse(self):
        first = self.request(self.entries[0], self.initial())
        missing = copy.deepcopy(first); del missing['floor_reference']
        self.assertNotEqual(0, self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(missing))[0])
        _, initial = self.native_value(first); memory = initial['next_memory']
        negatives = []
        for key, value in [('height_world_m', 1.), ('frame_id', 'body_local'), ('source_instance_id', 'other_world')]:
            r = self.request(self.entries[1], memory); r['floor_reference'][key] = value; negatives.append(r)
        crossed = self.request(self.entries[1], memory); crossed['memory']['schema_version'] = PARENT_MEMORY; negatives.append(crossed)
        stale = self.request(self.entries[1], memory); stale['state']['sample_time_s'] = first['state']['sample_time_s']; negatives.append(stale)
        for r in negatives:
            status, raw = self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(r)); self.assertEqual(0, status)
            value = json.loads(raw)['value']; self.assertTrue(value['actuation']['safe_no_actuation'])
            self.assertEqual(r['memory'], value['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in value['actuation']['ordered_commands']))


if __name__ == '__main__':
    unittest.main()
