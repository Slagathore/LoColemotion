"""V43 uses the shared worker and frozen-source resolver, without a new harness."""
import unittest
import test_development_v39_recovery_route as shared


class SupportProgressionRecoveryRoute(shared.AirborneReferenceRecoveryRoute):
    policy_id = 'sporespore_balanced_wave_recovery_support_progression_v1'
    run_label = 'V43'
    contract_family = 'support_progression'
    contract_version = 1


if __name__ == '__main__':
    unittest.main()
