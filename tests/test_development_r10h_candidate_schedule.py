"""Both finite role budgets and the existing real finalizer, with unchanged diagnostic values."""
import unittest
import test_development_recovery_candidate_schedule as shared
class FiniteSchedule(shared.CandidateSchedule):
    def test_coverage_math_uses_observed_stance_and_unchanged_timeout(self):
        b = self.schedule["coverage_basis"]
        c = shared.candidate.read(shared.ROOT / b["task_contract"])
        self.assertEqual(b["task_contract_sha256"], shared.candidate.sha(shared.ROOT / b["task_contract"]))
        self.assertEqual(["matched_no_kick_continuation", "kick_passive_recovery_resume"], [x["role"] for x in c["fresh_roles"]])
        limits = c["limits"]
        self.assertEqual(2312, 320+30+2+240+1600+120)
        self.assertEqual(2312, limits["maximum_no_kick_child_solver_steps"])
        self.assertEqual(3512, limits["maximum_kicked_child_solver_steps"])
        self.assertEqual(3160, shared.candidate.limits(self.selection)["after_interaction_steps"])
        self.assertFalse(c["controller_composition"]["rust_controller_change"])
        self.assertFalse(b["baseline_reused"])
        self.assertFalse(b["equal_horizon_effect_claimed"])
        self.assertEqual("r10h_v50_stance_entry_route_v1", self.schedule["walking_policy_id"])
        self.assertFalse(self.schedule["physical_acceptance_authority"])
if __name__ == "__main__": unittest.main()
