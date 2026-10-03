"""The post-result closure must retain failure and the entire consumed population."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10j_held_out_failure as failure


def cells():
    outcomes = ['invalid_controller_refusal', 'valid_finite_negative', 'valid_finite_positive',
                'valid_finite_negative', 'invalid_controller_refusal', 'valid_finite_negative']
    return [dict(cell_id=c['cell_id'], outcome=outcome, solver_steps=steps,
                 world_build_count=1, retry_count=0, replacement_count=0)
            for c, outcome, steps in zip(failure.authority.population('held_out_finite_decision'),
                                         outcomes, failure.EXPECTED_STEPS)]


def invalid_report():
    return dict(seed=50641, ok=False, status='invalid_or_incomplete_process_isolated_child_development',
        failure_code='QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID', solver_step_count=1343, world_build_count=1,
        finite_recovery_task=dict(planned_cycle_count=3, stopping_commands=0),
        partial_arm=dict(orchestrator_state=dict(hold_entry_step_count=176,
            matched_continuation_step_count=725, terminal_reason='')),
        detail=dict(portable_step_receipt=dict(development_native_step_failure=dict(
            classification='verified_zero_actuation_controller_refusal', verified_zero_actuation_refusal=True,
            reported_native_controller_error='FRAME_INVALID:anchored_body_pose_unreachable_endpoint',
            adapter_clock_advanced=False, adapter_memory_advanced=False, motor_application_permitted=False))))


class FailureClosureTests(unittest.TestCase):
    def test_complete_population_remains_invalid_with_no_acceptance(self):
        result = failure.decision(cells())
        self.assertEqual((result['world_build_count'], result['solver_step_count']), (6, 5825))
        self.assertEqual((result['valid_positive_cells'], result['valid_negative_cells'], result['invalid_cells']), (1, 3, 2))
        self.assertEqual(result['outcome'], 'invalid')
        for key in ('accepted', 'all_six_cells_passed', 'q_sdk_r10_satisfied', 'sdk1_m07_satisfied',
                    'physical_acceptance_authority', 'release_authority', 'retry_permitted', 'replacement_permitted'):
            self.assertIs(result[key], False)

    def test_omitted_reordered_replaced_or_promoted_cells_are_refused(self):
        for mutation in ('omit', 'order', 'replace', 'promote'):
            changed = cells()
            if mutation == 'omit': changed.pop()
            if mutation == 'order': changed.reverse()
            if mutation == 'replace': changed[-1]['cell_id'] = '50644:kick_passive_recovery_resume'
            if mutation == 'promote': changed[0]['outcome'] = 'valid_finite_positive'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                failure.decision(changed)

    def test_extra_worlds_retries_changed_counts_and_float_counts_are_refused(self):
        for key, value in [('world_build_count', 2), ('retry_count', 1), ('replacement_count', 1),
                           ('solver_steps', 1344), ('solver_steps', 1343.0), ('world_build_count', True)]:
            changed = cells(); changed[0][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                failure.decision(changed)

    def test_native_refusal_stays_invalid_and_cannot_hide_actuation(self):
        descriptor = dict(role='matched_no_kick_continuation', cell_id='50641:matched_no_kick_continuation',
                          child_attempt_id='fixture_only_no_world')
        original = invalid_report()
        before = copy.deepcopy(original)
        result = failure.observed_summary(original, descriptor)
        self.assertEqual(result['outcome'], 'invalid_controller_refusal')
        self.assertIs(result['worker_ok'], False)
        self.assertEqual(original, before)
        for key in ('verified_zero_actuation_refusal', 'adapter_clock_advanced',
                    'adapter_memory_advanced', 'motor_application_permitted'):
            changed = copy.deepcopy(original)
            proof = changed['detail']['portable_step_receipt']['development_native_step_failure']
            proof[key] = not proof[key]
            with self.subTest(key=key), self.assertRaises(ValueError):
                failure.observed_summary(changed, descriptor)

    def test_each_completed_step_requires_identity_and_all_physical_invariants(self):
        row = dict(global_semantic_step=1, arm_id='kick_passive_recovery_resume',
                   body_population_instance_sha256='fixture_body')
        invariant = dict(row, all_in_run_physical_invariants_passed=True, predicates=dict(no_cheat=True))
        arm = dict(trace_rows=[row], invariant_receipts=[invariant], body_population_instance_sha256='fixture_body',
                   body_population_rebuild_count=0, body_transform_write_count=0,
                   body_velocity_write_count=0, solver_reset_count=0)
        self.assertEqual(failure.verify_step_invariants(dict(solver_step_count=1), arm, row['arm_id']), 1)
        for mutation in ('missing', 'body', 'predicate', 'reset'):
            changed = copy.deepcopy(arm)
            if mutation == 'missing': changed['invariant_receipts'] = []
            if mutation == 'body': changed['trace_rows'][0]['body_population_instance_sha256'] = 'other'
            if mutation == 'predicate': changed['invariant_receipts'][0]['predicates']['no_cheat'] = False
            if mutation == 'reset': changed['solver_reset_count'] = 1
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                failure.verify_step_invariants(dict(solver_step_count=1), changed, row['arm_id'])


if __name__ == '__main__':
    unittest.main()
