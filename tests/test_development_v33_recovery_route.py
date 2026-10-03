"""V33 selection through the shared production-worker and event-reader fixture."""
import unittest

import test_development_v32_recovery_route as shared


class BoundedSupportRecoveryRoute(shared.RecoveryRoute):
    policy_id = 'sporespore_balanced_wave_recovery_bounded_support_v1'
    run_label = 'V33'


if __name__ == '__main__':
    unittest.main()
