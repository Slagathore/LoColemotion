import unittest
import test_development_v39_recovery_route as shared
class StartupReferenceVelocityRecoveryRoute(shared.AirborneReferenceRecoveryRoute):
    policy_id = "sporespore_balanced_wave_recovery_startup_reference_velocity_v1"
    run_label = "V50"
    contract_family = "startup_reference_velocity"
    contract_version = 1
if __name__ == "__main__": unittest.main()
