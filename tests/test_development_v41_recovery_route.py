"""V41 through the shared worker and immutable-source closure lookup."""
import unittest
import test_development_v39_recovery_route as shared


class UprightStanceRecoveryRoute(shared.AirborneReferenceRecoveryRoute):
    policy_id = 'sporespore_balanced_wave_recovery_upright_stance_v1'
    run_label = 'V41'
    contract_family = 'upright_stance'
    contract_version = 2

    def test_synthetic_scope_and_original_r173_preserved(self):
        super().test_synthetic_scope_and_original_r173_preserved()
        from pathlib import Path
        from unittest import mock
        import development_recovery_candidate_checkpoint as checkpoint
        from development_recovery_candidate_test_support import ROOT
        closure = checkpoint.smoke.read(ROOT / 'sdk/development/recovery_attempts/9ad0a4c4dbc94e899752549d9f3aa457.json')
        root = Path(closure['evidence_root'])
        fixture = Path(closure['failed_stage_source_population']['root'])
        self.assertEqual(closure, checkpoint.observe_floor_gate_failure(root, fixture))
        original_read = checkpoint.smoke.read
        def crossed(path):
            value = original_read(path)
            if path.name == 'supervisor_result.json':
                value['physical_attempt_started'] = True
            return value
        with mock.patch.object(checkpoint.smoke, 'read', side_effect=crossed), self.assertRaisesRegex(ValueError, 'FLOOR_GATE_NO_PHYSICAL_CHILD'):
            checkpoint.observe_floor_gate_failure(root, fixture)


if __name__ == '__main__':
    unittest.main()
