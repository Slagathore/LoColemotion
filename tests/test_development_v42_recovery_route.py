"""V42 uses the shared worker and frozen-source resolver, without a new harness."""
import unittest
import test_development_v39_recovery_route as shared


class StanceLatchRecoveryRoute(shared.AirborneReferenceRecoveryRoute):
    policy_id = 'sporespore_balanced_wave_recovery_stance_latched_upright_v1'
    run_label = 'V42'
    contract_family = 'stance_latch'
    contract_version = 1


if __name__ == '__main__':
    unittest.main()
