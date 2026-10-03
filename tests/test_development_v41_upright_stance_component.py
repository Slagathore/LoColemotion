"""V41 real native interfaces on retained V40 states, NOT an alternate trajectory."""
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
import development_recovery_upright_stance_precheck as precheck
from test_development_v32_recontact_component import NativeApi
from test_development_v36_smooth_swing_component import request_bytes

POLICY = 'sporespore_balanced_wave_recovery_upright_stance_v1'
PARENT = 'sporespore_balanced_wave_recovery_absent_contact_reference_v1'
MEMORY = 'sporespore_balanced_wave_recovery_upright_stance_memory_v1'
PARENT_MEMORY = 'sporespore_balanced_wave_recovery_absent_contact_reference_memory_v1'
MODE = 'contact_selected_upright_stance_reference_velocity_tracking_v1'
PROFILE = ROOT/'sdk/development/recovery_candidates/v41-upright-stance-v1.json'


class V41UprightStance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        closure_path = ROOT/'sdk/development/recovery_attempts/9791149066cc43e2b42df2f1def7adc1.json'
        assert candidate.sha(closure_path) == 'sha256:7782fc657984a17f426fc63bf0e66d88bb0422237607ec3949e12c89f717827c'
        closure = candidate.read(closure_path)
        path = Path(closure['kicked_report']['path'])
        assert candidate.sha(path) == 'sha256:a1872bd14d79a844e48577bc5338fe7b46f1141d7a1c97460f84d52cb9c915bc'
        cls.report = candidate.read(path)
        cls.entries = cls.report['development_walking_entry']['rows']
        assert len(cls.entries) == 400
        cls.descriptor = cls.report['configuration']['base_descriptor']
        upper = .35*cls.descriptor['upper_length_fraction']
        cls.dimensions = (upper, .35-upper, .04*cls.descriptor['foot_radius_scale'], cls.descriptor['hip_span_scale'])
        cls.profile = candidate.read(PROFILE)
        cls.binding = candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding = candidate.read(ROOT/'sdk/development/recovery_candidates/v40-absent-contact-reference-v1.runtime.json')
        for binding in (cls.binding, cls.old_binding):
            for image in (Path(binding['runtime']['path']), ROOT/binding['local_build_path']):
                assert candidate.sha(image) == binding['runtime']['raw_sha256']
        cls.native = NativeApi(cls.binding['runtime']['path'])
        cls.old = NativeApi(cls.old_binding['runtime']['path'])

    def initial(self):
        status, result = self.native.call('ss_balanced_wave_policy_initial_memory_json', dict(
            schema_version='sporespore_balanced_wave_policy_initial_memory_request_v1', policy_id=POLICY, descriptor=self.descriptor))
        self.assertEqual(0, status)
        memory = result['value']
        self.assertEqual(MEMORY, memory['schema_version'])
        for limb, before in zip(memory['ordered_limb_memory'], self.entries[0]['request']['memory']['ordered_limb_memory']):
            self.assertEqual(limb['limb_id'], before['limb_id'])
            for key in ('gait_step', 'evidence_gait_step_limit'):
                limb[key] = before[key]
        return memory

    def request(self, entry, memory, policy=POLICY):
        request = copy.deepcopy(dict(entry['request'], schema_version='sporespore_balanced_wave_policy_step_request_v2',
            descriptor=self.descriptor, policy_id=policy, memory=memory))
        request['memory']['schema_version'] = MEMORY if policy == POLICY else PARENT_MEMORY
        return request

    def native_value(self, request, api=None):
        status, raw = (api or self.native).raw('ss_balanced_wave_policy_step_json', request_bytes(request))
        self.assertEqual(0, status)
        value = json.loads(raw)['value']
        self.assertFalse(value['actuation']['safe_no_actuation'], value['actuation']['receipt'].get('controller_error'))
        return raw, value

    def test_binding_profile_and_nonrunnable_selection(self):
        self.assertEqual(334, self.binding['core_test_count'])
        self.assertEqual(self.profile['runtime_binding_sha256'], candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        self.assertEqual(self.profile['extension_sha256'], candidate.sha(candidate.resource_path(self.profile['extension'])))
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT/source['path']), source['path'])
        with self.assertRaisesRegex(ValueError, 'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        request = dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1', descriptor=self.descriptor, policy_id=POLICY)
        status, result = self.native.call('ss_balanced_wave_policy_profile_json', request)
        self.assertEqual(0, status)
        status, parent = self.old.call('ss_balanced_wave_policy_profile_json', dict(request, policy_id=PARENT))
        self.assertEqual(0, status)
        self.assertEqual(dict(parent['value'], policy_id=POLICY,
            schema_version='sporespore_balanced_wave_recovery_upright_stance_profile_v1', reference_velocity_mode_id=MODE), result['value'])
        height = self.entries[0]['request']['state']['base_pose_world']['position_m']['y']
        self.assertEqual(height.hex(), json.loads(request_bytes(dict(height=height)))['height'].hex())
        print('V41_EXPORTED_PROFILE', json.dumps(dict(profile=result['value'],
            native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(result['value'])).hexdigest(),
            physical_selection_refused=True)), flush=True)

    def test_4000_old_outputs_and_six_recovery_fixtures_are_exact(self):
        policies = [(PARENT, PARENT_MEMORY, True, True, True)]
        for suffix in ('airborne_reference', 'wave_velocity'):
            policies.append((f'sporespore_balanced_wave_recovery_{suffix}_v1',
                f'sporespore_balanced_wave_recovery_{suffix}_memory_v1', True, True, True))
        for suffix in ('reference_velocity', 'smooth_swing', 'feasible_support', 'floor_support'):
            policies.append((f'sporespore_balanced_wave_recovery_{suffix}_v1',
                f'sporespore_balanced_wave_recovery_{suffix}_memory_v1', True, True, False))
        policies.extend([
            ('sporespore_balanced_wave_recovery_bounded_support_v1', 'sporespore_balanced_wave_recovery_support_memory_v1', False, True, False),
            ('sporespore_balanced_wave_recovery_swing_end_recontact_v1', 'sporespore_balanced_wave_memory_v1', False, False, False),
            ('sporespore_balanced_wave_bw5r_b_v1', 'sporespore_balanced_wave_memory_v1', False, False, False)])
        counts = {}; refusals = {}
        for policy, schema, floor, support, wave in policies:
            counts[policy] = refusals[policy] = 0
            for entry in self.entries:
                r = self.request(entry, entry['request']['memory'])
                r['policy_id'] = policy; r['memory']['schema_version'] = schema
                if not wave: r['memory']['support_reference'].pop('previous_wave', None)
                if not floor:
                    r['schema_version'] = 'sporespore_balanced_wave_policy_step_request_v1'
                    del r['floor_reference']; r['memory'].pop('floor_reference_sha256', None)
                if not support: del r['memory']['support_reference']
                a, expected = self.old.raw('ss_balanced_wave_policy_step_json', request_bytes(r))
                b, actual = self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(r))
                self.assertEqual(0, a); self.assertEqual(a, b); self.assertTrue(expected == actual, f'old output drift: {policy}, {entry["session_local_step"]}')
                self.assertNotIn(b'"upright_stance":', actual)
                value = json.loads(actual)['value']
                if value['actuation']['safe_no_actuation']:
                    self.assertEqual(r['memory'], value['next_memory'])
                    self.assertTrue(all(c['target_velocity_rad_s'] == 0. for c in value['actuation']['ordered_commands']))
                    refusals[policy] += 1
                counts[policy] += 1
        fixtures = []
        for binding in (self.old_binding, self.binding):
            path = Path(binding['compiled_fixtures']['path'])
            self.assertEqual(candidate.sha(path), binding['compiled_fixtures']['raw_sha256'])
            fixtures.append([line for line in path.read_text().splitlines() if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')])
        self.assertEqual(6, len(fixtures[0])); self.assertEqual(*fixtures)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            candidate.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        print('V41_OLD_OUTPUT_COMPATIBILITY', json.dumps(dict(exact_raw_outputs=sum(counts.values()),
            per_policy=counts, preserved_refusals_by_policy=refusals, exact_recovery_fixtures=6,
            old_physical_records_changed=False)), flush=True)

    def check_reconstruction(self, entry, incoming, value, mode):
        expected = precheck.step(entry, incoming['support_reference']['ordered_target_positions_rad'], self.dimensions)
        r = value['actuation']['receipt']['recovery_support_plane']
        u = r['upright_stance']; w = r['wave_velocity']; ar = r['airborne_reference']
        state = entry['request']['state']
        self.assertEqual('sporespore_recovery_upright_stance_controller_step_receipt_v1', value['actuation']['receipt']['schema_version'])
        self.assertEqual(MODE, r['reference_velocity_mode_id'])
        self.assertNotIn('feasible_support_plan', r)  # Two different plans are labeled below.
        self.assertEqual(state['semantic_step'], u['source_semantic_step'])
        self.assertEqual(state['sample_time_s'], u['source_sample_time_s'])
        self.assertEqual(state['adapter_capability_sha256'], u['source_adapter_capability_sha256'])
        self.assertEqual(entry['request']['floor_reference'], u['source_floor_reference'])
        self.assertEqual('controller_target_not_measured_pose_or_contact', u['reference_geometry_role'])
        self.assertEqual([0., 1., 0.], u['reference_anatomical_vertical_projections'])
        self.assertTrue(u['comparison_uses_current_selector'])
        self.assertEqual(incoming['support_reference'].get('previous_wave'), w['previous_wave'])
        archived_wave = entry['native_output']['actuation']['receipt']['recovery_support_plane']['wave_velocity']['current_wave']
        self.assertEqual(archived_wave['active'], w['current_wave']['active'])
        for a, b in zip(archived_wave['ordered_limbs'], w['current_wave']['ordered_limbs']):
            for key in ('limb_id', 'scheduled_phase_step'):
                self.assertEqual(a[key], b[key])
            for key in ('nominal_leg_direction_rad', 'walking_knee_fraction'):
                self.assertAlmostEqual(a[key], b[key], delta=1e-12)
        for plan_name, expected_name in [('measured_pose_baseline_plan', 'original_height_plan'),
                                         ('floor_upright_reference_plan', 'upright_height_plan')]:
            plan = u[plan_name]; values = expected[expected_name]
            self.assertEqual(4, len(plan['ordered_limb_intervals']))
            for name, number in zip(('common_minimum_torso_height_m', 'common_maximum_torso_height_m', 'requested_stance_torso_height_m'), values):
                self.assertAlmostEqual(number, plan[name], delta=1e-12)
            self.assertEqual(values[0] <= values[1], plan['common_height_interval_nonempty'])
        for i, limb in enumerate(u['ordered_limbs']):
            self.assertEqual(limb['precommand_contact'], state['ordered_contact_observations'][i])
            self.assertEqual(limb['scheduled_phase_step'], w['current_wave']['ordered_limbs'][i]['scheduled_phase_step'])
            self.assertEqual(limb['limb_id'], w['current_wave']['ordered_limbs'][i]['limb_id'])
            self.assertEqual(expected['selected'][i], limb['upright_reference_selected'])
            chosen = u['floor_upright_reference_proposals' if expected['selected'][i] else 'measured_pose_baseline_proposals'][i]
            self.assertEqual(chosen, r['ordered_limb_proposals'][i])
        maximum_error = 0.
        for i, (motor, command) in enumerate(zip(expected['motors'], value['actuation']['ordered_commands'])):
            for name, key in [('measured_pose_baseline_proposals', 'original_goals_rad'), ('floor_upright_reference_proposals', 'upright_goals_rad')]:
                goal = u[name][i//2]['goal_hip_rad' if i%2 == 0 else 'goal_knee_rad']
                self.assertAlmostEqual(goal, expected[key][i], delta=1e-12)
            self.assertAlmostEqual(u['ordered_selected_goals_rad'][i], motor['goal_rad'], delta=1e-12)
            self.assertAlmostEqual(command['requested_target_position_rad'], motor['target_rad'], delta=1e-12)
            self.assertEqual(command['requested_target_position_rad'], command['clamped_target_position_rad'])
            self.assertAlmostEqual(w['ordered_comparison_reference_rad'][i], motor['comparison_rad'], delta=1e-12)
            self.assertAlmostEqual(r['ordered_reference_velocity_rad_s'][i], motor['selected_reference_rate_rad_s'], delta=1e-10)
            self.assertAlmostEqual(ar['ordered_full_reference_velocity_rad_s'][i], motor['full_reference_rate_rad_s'], delta=1e-10)
            error = abs(command['target_velocity_rad_s']-motor['velocity_rad_s'])
            maximum_error = max(maximum_error, error); self.assertLess(error, 1e-10)
            self.assertEqual(command['velocity_saturated'], motor['saturated'])
            # Slew is an exact inequality in the native calculation. The
            # independently reconstructed/archive-projected doubles may differ
            # by an ULP at an unslewed endpoint; do not use their != as native
            # truth. Check native truth exactly, and retain EVERY discrepancy.
            actual_goal = u['ordered_selected_goals_rad'][i]
            self.assertEqual(command['slew_limited'], command['requested_target_position_rad'] != actual_goal)
            if command['slew_limited'] != motor['slew_limited']:
                actual_gap = abs(command['requested_target_position_rad']-actual_goal)
                algebra_gap = abs(motor['target_rad']-motor['goal_rad'])
                self.assertLess(actual_gap, 1e-12); self.assertLess(algebra_gap, 1e-12)
                self.slew_projection_boundaries.append(dict(command_local=entry['session_local_step'],
                    actuator_id=command['actuator_id'], mode=mode, native_slew_limited=command['slew_limited'],
                    algebra_slew_limited=motor['slew_limited'], native_endpoint_gap_rad=actual_gap,
                    algebra_endpoint_gap_rad=algebra_gap))
            self.assertLessEqual(abs(command['target_velocity_rad_s']), motor['cap_rad_s'])
            self.assertLessEqual(abs(command['requested_target_position_rad']-motor['prior_reference_rad']),
                motor['cap_rad_s']*expected['reference_step_duration_s']+1e-14)
            self.assertEqual(0., command['residual_contribution_rad_s'])
        pose, wave = precheck.cold.algebra.inputs(entry)
        prior = w['previous_wave']
        if prior is not None and prior['active'] and wave['active']:
            comparisons = precheck.goals(pose, precheck.snapshot(prior), self.dimensions, expected['selected'])[0]
            for a, b in zip(comparisons, u['ordered_same_mask_comparison_goals_rad']):
                self.assertAlmostEqual(a, b, delta=1e-12)
        else:
            self.assertIsNone(u['ordered_same_mask_comparison_goals_rad'])
            self.assertTrue(all(rate == 0. for rate in r['ordered_reference_velocity_rad_s']))
        return expected, maximum_error

    def test_400_chained_session_stateless_and_one_command_comparisons(self):
        create = self.native.library.ss_balanced_wave_policy_session_create_json
        create.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint64)]; create.restype = ctypes.c_int
        data = request_bytes(dict(schema_version='sporespore_balanced_wave_policy_session_create_request_v1', descriptor=self.descriptor, policy_id=POLICY))
        handle = ctypes.c_uint64(); self.assertEqual(0, create(data, len(data), ctypes.byref(handle)))
        session = self.native.library.ss_balanced_wave_policy_session_step_json
        session.argtypes = [ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
        session.restype = ctypes.c_int
        destroy = self.native.library.ss_balanced_wave_policy_session_destroy
        destroy.argtypes = [ctypes.c_uint64]; destroy.restype = ctypes.c_int
        memory = self.initial(); chain = hashlib.sha256()
        self.slew_projection_boundaries = []
        counts = dict(selected_limb_commands=0, one_command_changed=0, one_command_saturated=0,
            chained_changed=0, chained_saturated=0, unselected_carried_reference_changes=0,
            same_memory_unselected_exact_commands=0, selector_transitions=0)
        maximum_error = 0.; previous_mask = None
        try:
            for entry in self.entries:
                request = self.request(entry, memory)
                raw, value = self.native_value(request); chain.update(raw)
                sr = {k:v for k,v in request.items() if k not in ('descriptor', 'policy_id')}
                sr['schema_version'] = 'sporespore_balanced_wave_policy_session_step_request_v2'
                data = request_bytes(sr); size = ctypes.c_size_t()
                session(handle, data, len(data), None, 0, ctypes.byref(size))
                self.assertTrue(0 < size.value < 2_000_000)
                out = ctypes.create_string_buffer(size.value)
                self.assertEqual(0, session(handle, data, len(data), out, size.value, ctypes.byref(size)))
                self.assertTrue(raw == out.raw[:size.value], 'session/stateless drift')
                expected, error = self.check_reconstruction(entry, memory, value, 'chained')
                maximum_error = max(maximum_error, error)
                _, parent = self.native_value(self.request(entry, memory, PARENT), self.old)
                expected_memory = copy.deepcopy(parent['next_memory']); expected_memory['schema_version'] = MEMORY
                expected_memory['support_reference']['ordered_target_positions_rad'] = value['next_memory']['support_reference']['ordered_target_positions_rad']
                self.assertEqual(expected_memory, value['next_memory'])
                # A distinct single-command substitution uses ORIGINAL incoming
                # V40 references, not the chained V41 references.
                original_memory = entry['request']['memory']
                _, one = self.native_value(self.request(entry, original_memory))
                _, original_native = self.native_value(self.request(entry, original_memory, PARENT), self.old)
                _, error = self.check_reconstruction(entry, original_memory, one, 'one_command')
                maximum_error = max(maximum_error, error)
                current_mask = expected['selected']
                counts['selected_limb_commands'] += sum(current_mask)
                if previous_mask is not None:
                    counts['selector_transitions'] += sum(a != b for a, b in zip(previous_mask, current_mask))
                previous_mask = current_mask
                baseline_proposals = value['actuation']['receipt']['recovery_support_plane']['upright_stance']['measured_pose_baseline_proposals']
                self.assertEqual(baseline_proposals, parent['actuation']['receipt']['recovery_support_plane']['ordered_limb_proposals'])
                for i, (actual, single, original, same_memory_parent, native_original) in enumerate(zip(
                        value['actuation']['ordered_commands'], one['actuation']['ordered_commands'],
                        entry['native_output']['actuation']['ordered_commands'], parent['actuation']['ordered_commands'],
                        original_native['actuation']['ordered_commands'])):
                    selected = current_mask[i//2]
                    if not selected:
                        self.assertEqual(actual, same_memory_parent)
                        # The archive's number projection is not raw DLL output.
                        # Exact equality uses TWO native calls on identical input;
                        # original archived values still supply the precheck data.
                        self.assertEqual(single, native_original)
                        counts['same_memory_unselected_exact_commands'] += 1
                        counts['unselected_carried_reference_changes'] += abs(actual['requested_target_position_rad']-original['requested_target_position_rad']) > 1e-12
                    counts['one_command_changed'] += abs(single['target_velocity_rad_s']-original['target_velocity_rad_s']) > 1e-10
                    counts['one_command_saturated'] += single['velocity_saturated']
                    counts['chained_changed'] += abs(actual['target_velocity_rad_s']-original['target_velocity_rad_s']) > 1e-10
                    counts['chained_saturated'] += actual['velocity_saturated']
                memory = value['next_memory']
        finally:
            self.assertEqual(0, destroy(handle))
        self.assertEqual(dict(selected_limb_commands=1037, one_command_changed=2044, one_command_saturated=83,
            chained_changed=2186, chained_saturated=168, unselected_carried_reference_changes=102,
            same_memory_unselected_exact_commands=1126, selector_transitions=47), counts)
        print('V41_RETAINED_INPUT_PROBE', json.dumps(dict(counts, input_count=400, exact_session_stateless_matches=400,
            independently_reconstructed_joint_commands=6400, unchanged_upstream_memories=400,
            maximum_motor_reconstruction_error_rad_s=maximum_error,
            slew_projection_boundary_count=len(self.slew_projection_boundaries),
            slew_projection_boundaries=self.slew_projection_boundaries,
            raw_output_chain_sha256='sha256:'+chain.hexdigest(), input_transport='binary64_roundtrip_not_hash_projection',
            world_build_count=0, solver_step_count=0, new_physical_trajectory=False, physical_acceptance_authority=False)), flush=True)

    def test_missing_crossed_and_malformed_context_refuse(self):
        first = self.request(self.entries[0], self.initial())
        missing = copy.deepcopy(first); del missing['floor_reference']
        self.assertNotEqual(0, self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(missing))[0])
        _, initial = self.native_value(first); memory = initial['next_memory']; negatives = []
        for key, value in [('height_world_m', 1.), ('frame_id', 'body_local'), ('source_instance_id', 'other_world')]:
            r = self.request(self.entries[1], memory); r['floor_reference'][key] = value; negatives.append(r)
        crossed = self.request(self.entries[1], memory); crossed['memory']['schema_version'] = PARENT_MEMORY; negatives.append(crossed)
        stale = self.request(self.entries[1], memory); stale['state']['sample_time_s'] = first['state']['sample_time_s']; negatives.append(stale)
        for mutation in ('missing', 'count', 'order', 'direction', 'fraction', 'phase', 'inactive'):
            r = self.request(self.entries[1], memory); support = r['memory']['support_reference']
            if mutation == 'missing': del support['previous_wave']
            elif mutation == 'count': support['previous_wave']['ordered_limbs'].pop()
            elif mutation == 'order': support['previous_wave']['ordered_limbs'][0]['limb_id'] = 'wrong'
            elif mutation == 'direction': support['previous_wave']['ordered_limbs'][0]['nominal_leg_direction_rad'] = 2.
            elif mutation == 'fraction': support['previous_wave']['ordered_limbs'][0]['walking_knee_fraction'] = 2.
            elif mutation == 'phase': support['previous_wave']['ordered_limbs'][0]['scheduled_phase_step'] = 360
            else: support['previous_wave']['ordered_limbs'][0]['nominal_leg_direction_rad'] = .1
            negatives.append(r)
        for mutation in ('missing_presence', 'missing_bearing', 'missing_contact', 'order', 'identity', 'contradiction', 'quality'):
            r = self.request(self.entries[1], memory); contacts = r['state']['ordered_contact_observations']; c = contacts[0]
            if mutation == 'missing_presence': c['presence'] = None
            elif mutation == 'missing_bearing': c['bears_support'] = None
            elif mutation == 'missing_contact': contacts.pop()
            elif mutation == 'order': contacts[0], contacts[1] = contacts[1], contacts[0]
            elif mutation == 'identity': c['contact_site_id'] = 'another_model_foot'
            elif mutation == 'contradiction': c['presence'] = False; c['bears_support'] = True
            else: c['provenance']['quality'] = 'presence_only'
            negatives.append(r)
        for r in negatives:
            status, raw = self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(r))
            self.assertEqual(0, status); value = json.loads(raw)['value']
            self.assertTrue(value['actuation']['safe_no_actuation']); self.assertEqual(r['memory'], value['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s'] == 0. for c in value['actuation']['ordered_commands']))
            self.assertNotIn('recovery_support_plane', value['actuation']['receipt'])
        for invalid_phase in (True, 1.5):
            malformed = self.request(self.entries[1], memory)
            malformed['memory']['support_reference']['previous_wave']['ordered_limbs'][0]['scheduled_phase_step'] = invalid_phase
            self.assertNotEqual(0, self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(malformed))[0])
        malformed = self.request(self.entries[1], memory); malformed['state']['ordered_contact_observations'][0]['presence'] = 'false'
        self.assertNotEqual(0, self.native.raw('ss_balanced_wave_policy_step_json', request_bytes(malformed))[0])
        print('V41_NATIVE_NEGATIVE_CONTROLS', json.dumps(dict(safe_refusals_with_unchanged_memory=len(negatives),
            malformed_transport_refusals=4, missing_data_interpreted_as_support=False)), flush=True)


if __name__ == '__main__':
    unittest.main()
