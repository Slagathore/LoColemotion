import unittest
import test_development_recovery_candidate_schedule as shared
class CycleSchedule(shared.CandidateSchedule):
    def test_coverage_math_uses_observed_stance_and_unchanged_timeout(self):
        b = self.schedule["coverage_basis"]
        limits = shared.candidate.limits(self.selection)
        self.assertEqual((240,1200,1600,120,30), tuple(b[k] for k in ("maximum_descent_steps","maximum_canonical_recovery_steps","maximum_walking_commands","stopping_commands","settled_commands")))
        self.assertEqual(3160, sum(b[k] for k in ("maximum_descent_steps","maximum_canonical_recovery_steps","maximum_walking_commands","stopping_commands")))
        self.assertEqual(3160, limits["after_interaction_steps"])
        self.assertEqual(3512, limits["maximum_steps_per_child"])
        closure = shared.candidate.read(shared.ROOT / b["source_closure"])
        self.assertEqual(b["source_closure_sha256"], shared.candidate.sha(shared.ROOT / b["source_closure"]))
        self.assertEqual(4, closure["completed_limb_cycles"])
        self.assertFalse(closure["physical_acceptance_authority"])
        self.assertEqual("sporespore_exact_s169_prone_to_standing_controller_v20", self.selection["post_kick_controller_id"])
        self.assertEqual("sporespore_balanced_wave_recovery_remaining_support_release_v1", self.schedule["walking_policy_id"])
        self.assertFalse(self.schedule["physical_acceptance_authority"])
if __name__ == "__main__": unittest.main()
