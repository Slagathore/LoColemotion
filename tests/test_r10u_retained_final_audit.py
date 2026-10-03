"""Required full final-auditor reconstruction, strictly bound to the live key."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10u_retained_final_audit as diagnostic


class RetainedFinalAudit(unittest.TestCase):
    def test_complete_retained_audit_with_bound_new_host_declaration(self):
        observed = diagnostic.verify(replay_original=True)
        self.assertTrue(observed['ok'] and observed['original_full_audit_reconstructed'])
        self.assertGreater(observed['projected_declaration_validation_calls'],0)
        self.assertEqual((0,0),(observed['world_build_count'],observed['solver_step_count']))
        self.assertFalse(observed['original_attempt_reclassified'])
        self.assertFalse(observed['full_r10u_physical_workflow_proven'])
        self.assertFalse(observed['physical_acceptance_authority'] or observed['release_authority'])


if __name__ == '__main__':
    unittest.main()
