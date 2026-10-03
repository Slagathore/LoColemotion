"""Both finite role budgets and the existing real finalizer, with unchanged diagnostic values; R10K preserves preparation and adds distinct partial-fall recovery."""
import unittest
import test_development_recovery_candidate_schedule as shared
class FiniteSchedule(shared.CandidateSchedule):
    def test_coverage_math_uses_observed_stance_and_unchanged_timeout(self):
        b = self.schedule["coverage_basis"]
        c = shared.candidate.read(shared.ROOT / b["task_contract"])
        self.assertEqual(b["task_contract_sha256"], shared.candidate.sha(shared.ROOT / b["task_contract"]))
        self.assertEqual(["matched_no_kick_continuation", "kick_passive_recovery_resume"], [x["role"] for x in c["fresh_roles"]])
        limits = c["limits"]
        self.assertEqual(2552, 320+30+2+240+240+1600+120)
        self.assertEqual(2552, limits["maximum_no_kick_child_solver_steps"])
        self.assertEqual(240, limits["maximum_no_kick_stance_entry_commands"])
        self.assertEqual(240, limits["maximum_no_kick_hold_commands"])
        self.assertEqual(3512, limits["maximum_kicked_child_solver_steps"])
        self.assertEqual(3160, shared.candidate.limits(self.selection)["after_interaction_steps"])
        self.assertTrue(c["controller_composition"]["rust_controller_change"])
        self.assertEqual("sporespore_balanced_wave_recovery_joint_feasible_height_v1", c["controller_composition"]["post_interaction_walking"])
        self.assertEqual(1200, limits["maximum_partial_recovery_commands"])
        self.assertEqual(360, limits["maximum_standing_commands"])
        self.assertTrue(c["controller_composition"]["no_kick_hold_separate_session"])
        self.assertEqual(0.0, c["stance_entry"]["hold"]["gait_amplitude"])
        self.assertEqual(30, c["stance_entry"]["hold"]["ready_consecutive_completed_samples"])
        self.assertFalse(c["controller_composition"]["v50_walking_arithmetic_changed"])
        self.assertFalse(b["baseline_reused"])
        self.assertFalse(b["equal_horizon_effect_claimed"])
        self.assertEqual("r10k_v51_partial_fall_recovery_route_v1", self.schedule["walking_policy_id"])
        self.assertFalse(self.schedule["physical_acceptance_authority"])
    def test_original_records_and_r173_remain_exact(self):
        # R10K is based on the consumed six-cell R10J decision, not the older
        # single-controller source_attempt used by the inherited schedule tests.
        import hashlib
        from pathlib import Path
        path = shared.ROOT / 'sdk/recovery/r10j_held_out_physical_closure_v1.json'
        self.assertEqual('sha256:68267d60c58d39713705224e61cb356826a70012b49586be0ecc53a4d16a4420', shared.candidate.sha(path))
        record = shared.candidate.read(path)
        original = record['original_supervisor']
        self.assertEqual(original['raw_sha256'], shared.candidate.sha(Path(original['path'])))
        supervisor = shared.candidate.read(Path(original['path']))
        self.assertFalse(supervisor['ok'])
        self.assertIsNone(supervisor['independent_audit'])
        self.assertEqual(6, len(record['cells']))
        self.assertEqual(1, sum(c['outcome'] == 'valid_finite_positive' for c in record['cells']))
        self.assertEqual(3, sum(c['outcome'] == 'valid_finite_negative' for c in record['cells']))
        self.assertEqual(2, sum(c['outcome'] == 'invalid_controller_refusal' for c in record['cells']))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f', shared.candidate.sha(shared.ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
if __name__ == "__main__": unittest.main()
