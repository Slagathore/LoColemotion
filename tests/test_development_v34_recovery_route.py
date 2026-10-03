"""V34 through the same production scheduler and independent event reader."""
import unittest
import test_development_v32_recovery_route as shared


class FloorSupportRecoveryRoute(shared.RecoveryRoute):
    policy_id = 'sporespore_balanced_wave_recovery_floor_support_v1'
    run_label = 'V34'


if __name__ == '__main__':
    unittest.main()
