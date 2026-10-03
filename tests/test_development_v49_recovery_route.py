import unittest
import test_development_v39_recovery_route as shared
class RemainingSupportRecoveryRoute(shared.AirborneReferenceRecoveryRoute):
    policy_id = "sporespore_balanced_wave_recovery_remaining_support_release_v1"
    run_label = "V49"
    contract_family = "remaining_support_release"
    contract_version = 1
if __name__ == "__main__": unittest.main()
