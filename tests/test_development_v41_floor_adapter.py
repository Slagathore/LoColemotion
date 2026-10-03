"""V41 actual adapter/motor ledger and independently reconstructed upright receipt."""
import copy
import hashlib
import json
import unittest

import test_development_v40_floor_adapter as shared
import development_recovery_upright_stance_precheck as precheck
from test_development_passive_entry_replay import marker


class UprightStanceFloorAdapter(shared.AbsentContactReferenceFloorAdapter):
    policy_id = 'sporespore_balanced_wave_recovery_upright_stance_v1'
    candidate_id = 'v41-upright-stance-v1'
    fixture = 'res://tests/test_development_v41_floor_adapter.gd'
    run_label = 'V41'
    receipt_schema = 'sporespore_recovery_upright_stance_controller_step_receipt_v1'
    reference_mode = 'contact_selected_upright_stance_reference_velocity_tracking_v1'

    def test_actual_constructor_adapter_and_ledger(self):
        # Shared V40 checks retain absent-contact rates, all motor limits, floor
        # construction and the ACTUAL production motor-ledger path.
        super().test_actual_constructor_adapter_and_ledger()
        report = self.producer['result']['report']
        descriptor = report['configuration']['base_descriptor']
        upper = .35*descriptor['upper_length_fraction']
        dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
        selected_count = nonbearing_count = transitions = 0
        previous = None; api = self.native_api(); maximum_error = 0.
        for row in report['development_walking_entry']['rows']:
            r = row['native_output']['actuation']['receipt']['recovery_support_plane']
            u = r['upright_stance']; state = row['request']['state']
            expected = precheck.step(row, row['request']['memory']['support_reference']['ordered_target_positions_rad'], dimensions)
            self.assertNotIn('feasible_support_plan', r)
            self.assertEqual(state['semantic_step'], u['source_semantic_step'])
            self.assertEqual(api.canonical(dict(time=state['sample_time_s'])), api.canonical(dict(time=u['source_sample_time_s'])))
            self.assertEqual(state['adapter_capability_sha256'], u['source_adapter_capability_sha256'])
            self.assertEqual(row['request']['floor_reference'], u['source_floor_reference'])
            self.assertEqual('controller_target_not_measured_pose_or_contact', u['reference_geometry_role'])
            self.assertEqual([0., 1., 0.], u['reference_anatomical_vertical_projections'])
            self.assertTrue(u['comparison_uses_current_selector'])
            for plan, values in [(u['measured_pose_baseline_plan'], expected['original_height_plan']),
                                 (u['floor_upright_reference_plan'], expected['upright_height_plan'])]:
                self.assertEqual(4, len(plan['ordered_limb_intervals']))
                for name, number in zip(('common_minimum_torso_height_m', 'common_maximum_torso_height_m', 'requested_stance_torso_height_m'), values):
                    self.assertAlmostEqual(number, plan[name], delta=1e-12)
                self.assertEqual(values[0] <= values[1], plan['common_height_interval_nonempty'])
            for i, limb in enumerate(u['ordered_limbs']):
                contact = state['ordered_contact_observations'][i]
                self.assertEqual(contact, limb['precommand_contact'])
                self.assertEqual(expected['selected'][i], limb['upright_reference_selected'])
                self.assertEqual(r['wave_velocity']['current_wave']['ordered_limbs'][i]['scheduled_phase_step'], limb['scheduled_phase_step'])
                selected_count += expected['selected'][i]
                nonbearing_count += contact['presence'] and not contact['bears_support']
                chosen = u['floor_upright_reference_proposals' if expected['selected'][i] else 'measured_pose_baseline_proposals'][i]
                self.assertEqual(chosen, r['ordered_limb_proposals'][i])
            for i, (motor, actual) in enumerate(zip(expected['motors'], row['native_output']['actuation']['ordered_commands'])):
                for proposal, key in [('measured_pose_baseline_proposals', 'original_goals_rad'), ('floor_upright_reference_proposals', 'upright_goals_rad')]:
                    value = u[proposal][i//2]['goal_hip_rad' if i%2 == 0 else 'goal_knee_rad']
                    self.assertAlmostEqual(value, expected[key][i], delta=1e-12)
                self.assertAlmostEqual(motor['goal_rad'], u['ordered_selected_goals_rad'][i], delta=1e-12)
                self.assertAlmostEqual(motor['target_rad'], actual['requested_target_position_rad'], delta=1e-12)
                self.assertAlmostEqual(motor['comparison_rad'], r['wave_velocity']['ordered_comparison_reference_rad'][i], delta=1e-12)
                error = abs(motor['velocity_rad_s']-actual['target_velocity_rad_s'])
                maximum_error = max(maximum_error, error); self.assertLess(error, 1e-10)
            if previous is not None:
                transitions += sum(a != b for a, b in zip(previous, expected['selected']))
            previous = expected['selected']
        self.assertGreater(selected_count, 0); self.assertGreater(nonbearing_count, 0); self.assertGreater(transitions, 0)
        print('V41_UPRIGHT_ADAPTER_RECONSTRUCTION', json.dumps(dict(commands=200, joint_commands=1600,
            selected_limb_commands=selected_count, present_nonbearing_limb_inputs=nonbearing_count,
            selector_transitions=transitions, maximum_motor_reconstruction_error_rad_s=maximum_error,
            current_mask_comparisons_reconstructed=True, both_geometry_plans_and_actual_goals_verified=True,
            synthetic_inputs_only=True, world_build_count=0, solver_step_count=0)), flush=True)

    def test_cold_reader_complete_population_and_fourteen_refusals(self):
        # Keep all shared floor/context and V40 absent-rate corruption checks.
        super().test_cold_reader_complete_population_and_fourteen_refusals()
        positive = dict(report=self.producer['result']['report'], policy_id=self.policy_id)
        rows = positive['report']['development_walking_entry']['rows']
        index = next(i for i, row in enumerate(rows) if any(l['upright_reference_selected'] for l in
            row['native_output']['actuation']['receipt']['recovery_support_plane']['upright_stance']['ordered_limbs']))
        cases = {'positive': positive}; api = self.native_api()
        for name in ('selector', 'contact', 'source_step', 'source_time', 'source_capability', 'floor',
                     'reference_pose', 'measured_baseline', 'upright_goal', 'upright_plan', 'selected_goal',
                     'actual_top_level_goal', 'same_mask', 'comparison_goal', 'missing_receipt'):
            item = copy.deepcopy(positive); row = item['report']['development_walking_entry']['rows'][index]
            act = row['native_output']['actuation']; support = act['receipt']['recovery_support_plane']; u = support['upright_stance']
            limb = next(l for l in u['ordered_limbs'] if l['upright_reference_selected'])
            if name == 'selector': limb['upright_reference_selected'] = False
            elif name == 'contact': limb['precommand_contact']['bears_support'] = False
            elif name == 'source_step': u['source_semantic_step'] += 1
            elif name == 'source_time': u['source_sample_time_s'] += .01
            elif name == 'source_capability': u['source_adapter_capability_sha256'] = 'sha256:'+'0'*64
            elif name == 'floor': u['source_floor_reference']['height_world_m'] += .01
            elif name == 'reference_pose': u['reference_anatomical_vertical_projections'][0] = .1
            elif name == 'measured_baseline': u['measured_pose_baseline_proposals'][0]['goal_hip_rad'] += .01
            elif name == 'upright_goal': u['floor_upright_reference_proposals'][0]['goal_hip_rad'] += .01
            elif name == 'upright_plan': u['floor_upright_reference_plan']['common_minimum_torso_height_m'] += .01
            elif name == 'selected_goal': u['ordered_selected_goals_rad'][0] += .01
            elif name == 'actual_top_level_goal': support['ordered_limb_proposals'][0]['goal_hip_rad'] += .01
            elif name == 'same_mask': u['comparison_uses_current_selector'] = False
            elif name == 'comparison_goal': u['ordered_same_mask_comparison_goals_rad'] = [9.]*8
            else: del support['upright_stance']
            # A self-consistent rehash must not fool the independent native replay.
            act['receipt_sha256'] = 'sha256:'+hashlib.sha256(api.canonical(act['receipt'])).hexdigest()
            cases[name] = item
        path = self.root/'upright_reader_inputs.json'
        with path.open('x', encoding='utf-8') as stream:
            json.dump(cases, stream, separators=(',', ':'), allow_nan=False)
        run = self._run_retained(self.fixture, ['--', str(path)], 'upright_cold_reader', 90)
        results = marker(run, 'V34_FLOOR_READER ')
        self.assertEqual(16, len(results)); self.assertTrue(results['positive']['ok'])
        self.assertEqual(200, results['positive']['replayed_walking_steps'])
        for name, result in results.items():
            if name != 'positive':
                self.assertFalse(result['ok'], (name, result))
                self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_NATIVE_OUTPUT_MISMATCH', result['failure_code'])
        print('V41_UPRIGHT_COLD_READER', json.dumps(dict(positive_steps=200,
            refused_rehashed_receipt_cases={name:r['failure_code'] for name, r in results.items() if name != 'positive'},
            world_build_count=0, solver_step_count=0)), flush=True)


if __name__ == '__main__':
    unittest.main()
