"""V38 exported calls on all saved V37 inputs; no alternate physics trajectory."""
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
import development_recovery_v37_reference_diagnosis as algebra

POLICY = 'sporespore_balanced_wave_recovery_wave_velocity_v1'
PARENT = 'sporespore_balanced_wave_recovery_reference_velocity_v1'
MEMORY = 'sporespore_balanced_wave_recovery_wave_velocity_memory_v1'
PARENT_MEMORY = 'sporespore_balanced_wave_recovery_reference_velocity_memory_v1'
MODE = 'bounded_pose_separated_wave_velocity_tracking_v1'
PROFILE = ROOT/'sdk/development/recovery_candidates/v38-wave-velocity-v1.json'


class V38ReferenceVelocity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure = candidate.read(ROOT/'sdk/development/recovery_attempts/8ceafcfb9d5c4439859aee7f959e2740.json')
        path = Path(cls.closure['kicked_report']['path'])
        assert candidate.sha(path) == cls.closure['kicked_report']['raw_sha256']
        cls.report = candidate.read(path); cls.entries = cls.report['development_walking_entry']['rows']
        assert len(cls.entries) == 400
        cls.descriptor = cls.report['configuration']['base_descriptor']
        cls.profile = candidate.read(PROFILE)
        cls.binding = candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding = candidate.read(ROOT/'sdk/development/recovery_candidates/v37-reference-velocity-v1.runtime.json')
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
        self.assertEqual(322, self.binding['core_test_count'])
        self.assertEqual(self.profile['runtime_binding_sha256'], candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT/source['path']), source['path'])
        with self.assertRaisesRegex(ValueError, 'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        request = dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1', descriptor=self.descriptor, policy_id=POLICY)
        status, result = self.native.call('ss_balanced_wave_policy_profile_json', request); self.assertEqual(0, status)
        status, old = self.old.call('ss_balanced_wave_policy_profile_json', dict(request, policy_id=PARENT)); self.assertEqual(0, status)
        self.assertEqual(dict(old['value'], policy_id=POLICY,
            schema_version='sporespore_balanced_wave_recovery_wave_velocity_profile_v1', reference_velocity_mode_id=MODE), result['value'])
        height = self.entries[0]['request']['state']['base_pose_world']['position_m']['y']
        self.assertEqual(height.hex(), json.loads(request_bytes(dict(height=height)))['height'].hex())
        self.assertNotEqual(height, json.loads(self.native.canonical(dict(height=height)))['height'])
        print('V38_EXPORTED_PROFILE', json.dumps(dict(profile=result['value'],
            native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(result['value'])).hexdigest(),
            physical_selection_refused=True)), flush=True)

    def test_2800_old_outputs_and_six_recovery_fixtures_are_exact(self):
        policies = (PARENT, 'sporespore_balanced_wave_recovery_smooth_swing_v1', 'sporespore_balanced_wave_recovery_feasible_support_v1',
            'sporespore_balanced_wave_recovery_floor_support_v1', 'sporespore_balanced_wave_recovery_bounded_support_v1',
            'sporespore_balanced_wave_recovery_swing_end_recontact_v1', 'sporespore_balanced_wave_bw5r_b_v1')
        schemas = (PARENT_MEMORY, 'sporespore_balanced_wave_recovery_smooth_swing_memory_v1', 'sporespore_balanced_wave_recovery_feasible_support_memory_v1',
            'sporespore_balanced_wave_recovery_floor_support_memory_v1', 'sporespore_balanced_wave_recovery_support_memory_v1',
            'sporespore_balanced_wave_memory_v1', 'sporespore_balanced_wave_memory_v1')
        counts = {}; refusals = {}; refusal_inputs = []
        for index, (policy, schema) in enumerate(zip(policies, schemas)):
            counts[policy] = 0
            refusals[policy] = 0
            for entry in self.entries:
                r = self.request(entry, entry['request']['memory']); r['policy_id'] = policy; r['memory']['schema_version'] = schema
                if index >= 4:
                    r['schema_version'] = 'sporespore_balanced_wave_policy_step_request_v1'
                    del r['floor_reference']; r['memory'].pop('floor_reference_sha256', None)
                if index >= 5: del r['memory']['support_reference']
                # V37 includes late tilted states outside an older support
                # controller's domain. Preserve that native refusal byte-for-
                # byte; compatibility does not require promoting it to motion.
                a, expected = self.old.raw('ss_balanced_wave_policy_step_json', request_bytes(r))
                b, actual = self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(r))
                self.assertEqual(0,a); self.assertEqual(a,b); self.assertEqual(expected,actual)
                value=json.loads(actual)['value']
                if value['actuation']['safe_no_actuation']:
                    self.assertEqual(r['memory'],value['next_memory'])
                    self.assertTrue(all(c['target_velocity_rad_s']==0. for c in value['actuation']['ordered_commands']))
                    refusals[policy]+=1
                    refusal_inputs.append(dict(policy=policy,command_local=entry['session_local_step'],error=value['actuation']['receipt']['controller_error']))
                counts[policy] += 1
        fixtures = []
        for binding in (self.old_binding, self.binding):
            path = Path(binding['compiled_fixtures']['path'])
            self.assertEqual(candidate.sha(path), binding['compiled_fixtures']['raw_sha256'])
            fixtures.append([line for line in path.read_text().splitlines() if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')])
        self.assertEqual(6, len(fixtures[0])); self.assertEqual(*fixtures)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            candidate.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        print('V38_OLD_OUTPUT_COMPATIBILITY', json.dumps(dict(exact_raw_outputs=sum(counts.values()),
            per_policy=counts, preserved_refusals_by_policy=refusals, preserved_refusal_inputs=refusal_inputs,
            exact_recovery_fixtures=6, old_physical_records_changed=False)), flush=True)

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
        upper = .35*self.descriptor['upper_length_fraction']
        dimensions = (upper,.35-upper,.04*self.descriptor['foot_radius_scale'],self.descriptor['hip_span_scale'])
        maximum_comparison_error = 0.
        def wave(snapshot):
            return dict(active=snapshot['active'],limbs=[(r['nominal_leg_direction_rad'],r['walking_knee_fraction'],r['scheduled_phase_step']) for r in snapshot['ordered_limbs']])
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
                pr['memory']['support_reference'].pop('previous_wave', None)
                _, parent = self.native_value(pr, self.old)
                expected_memory = copy.deepcopy(parent['next_memory']); expected_memory['schema_version'] = MEMORY
                expected_memory['support_reference']['previous_wave'] = value['next_memory']['support_reference']['previous_wave']
                self.assertEqual(expected_memory, value['next_memory'])
                receipt = value['actuation']['receipt']['recovery_support_plane']
                rates = receipt['ordered_reference_velocity_rad_s']; self.assertEqual(8, len(rates))
                wr = receipt['wave_velocity']
                self.assertEqual(memory['support_reference'].get('previous_wave'),wr['previous_wave'])
                self.assertEqual(value['next_memory']['support_reference']['previous_wave'],wr['current_wave'])
                self.assertEqual(dict(parent['actuation']['receipt']['recovery_support_plane'],
                    reference_velocity_mode_id=MODE, ordered_reference_velocity_rad_s=rates, wave_velocity=wr), receipt)
                self.assertEqual('sporespore_recovery_wave_velocity_controller_step_receipt_v1', value['actuation']['receipt']['schema_version'])
                dt = receipt['reference_step_duration_s']
                pose,current = algebra.inputs(dict(request=request,native_output=value))
                self.assertEqual(current,wave(wr['current_wave']))
                caps = [c['maximum_target_speed_rad_s'] for c in value['actuation']['ordered_commands']]
                old_refs = memory['support_reference']['ordered_target_positions_rad']
                prior_wave = wave(wr['previous_wave']) if wr['previous_wave'] is not None else None
                active = prior_wave is not None and prior_wave['active'] and current['active']
                self.assertEqual(active,wr['feedforward_active'])
                comparisons = algebra.bounded_targets(algebra.goals(pose,prior_wave,dimensions)[0],old_refs,caps,dt) if active else [c['requested_target_position_rad'] for c in value['actuation']['ordered_commands']]
                for i, (command, before) in enumerate(zip(value['actuation']['ordered_commands'], parent['actuation']['ordered_commands'])):
                    cap = command['maximum_target_speed_rad_s']; target = command['requested_target_position_rad']
                    prior = memory['support_reference']['ordered_target_positions_rad'][i]
                    error = abs(comparisons[i]-wr['ordered_comparison_reference_rad'][i])
                    maximum_comparison_error = max(maximum_comparison_error,error)
                    self.assertLess(error,1e-12)
                    rate = max(-cap,min(cap,(target-comparisons[i])/dt)) if active and dt>0 else 0.
                    self.assertAlmostEqual(rate,rates[i],delta=1e-10); self.assertLessEqual(abs(rates[i]),cap)
                    joint = request['state']['ordered_joint_observations'][i]
                    raw_velocity = 8.*(target-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
                    expected = -max(-cap, min(cap, raw_velocity))
                    self.assertAlmostEqual(expected, command['target_velocity_rad_s'], delta=1e-10)
                    self.assertLessEqual(abs(command['target_velocity_rad_s']), cap)
                    self.assertEqual(abs(raw_velocity)>cap, command['velocity_saturated'])
                    allowed = {k:command[k] for k in ('target_velocity_rad_s', 'velocity_saturated', 'safety_contribution_rad_s')}
                    self.assertEqual(dict(before, **allowed), command)
                    self.assertEqual(0., command['residual_contribution_rad_s'])
                    changed += abs(command['target_velocity_rad_s']-before['target_velocity_rad_s']) > 1e-12
                    saturated += command['velocity_saturated']; old_saturated += before['velocity_saturated']
                    if local <= 2: self.assertEqual(0., rates[i])
                    if local == 1: self.assertEqual(before, command)
                memory = value['next_memory']
        finally: self.assertEqual(0, destroy(handle))
        self.assertEqual(1491,changed); self.assertEqual(79,saturated); self.assertEqual(465,old_saturated)
        print('V38_RETAINED_INPUT_PROBE', json.dumps(dict(input_count=400, bounded_command_count=3200,
            exact_session_stateless_matches=400, unchanged_parent_position_paths=400, unchanged_parent_gate_memories=400,
            independently_reconstructed_velocity_commands=3200, independently_reconstructed_comparison_references=3200,
            maximum_comparison_reference_error_rad=maximum_comparison_error, changed_commands=changed, velocity_saturated_commands=saturated,
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
        for mutation in ('missing','count','order','direction','fraction','phase','inactive'):
            r=self.request(self.entries[1],memory); support=r['memory']['support_reference']
            if mutation=='missing': del support['previous_wave']
            elif mutation=='count': support['previous_wave']['ordered_limbs'].pop()
            elif mutation=='order': support['previous_wave']['ordered_limbs'][0]['limb_id']='wrong'
            elif mutation=='direction': support['previous_wave']['ordered_limbs'][0]['nominal_leg_direction_rad']=2.
            elif mutation=='fraction': support['previous_wave']['ordered_limbs'][0]['walking_knee_fraction']=2.
            elif mutation=='phase': support['previous_wave']['ordered_limbs'][0]['scheduled_phase_step']=360
            else: support['previous_wave']['ordered_limbs'][0]['nominal_leg_direction_rad']=.1
            negatives.append(r)
        for r in negatives:
            status, raw = self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(r)); self.assertEqual(0, status)
            value = json.loads(raw)['value']; self.assertTrue(value['actuation']['safe_no_actuation'])
            self.assertEqual(r['memory'], value['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in value['actuation']['ordered_commands']))
        malformed=self.request(self.entries[1],memory)
        malformed['memory']['support_reference']['previous_wave']['extra']=True
        self.assertNotEqual(0,self.native.raw('ss_balanced_wave_policy_step_json',request_bytes(malformed))[0])
        malformed=self.request(self.entries[1],memory)
        malformed['memory']['support_reference']['previous_wave']['ordered_limbs'][0]['scheduled_phase_step']=1.5
        self.assertNotEqual(0,self.native.raw('ss_balanced_wave_policy_step_json',request_bytes(malformed))[0])


if __name__ == '__main__':
    unittest.main()
