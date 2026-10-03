"""V40 selection through the shared worker and frozen-source closure resolver."""
import unittest
import test_development_v39_recovery_route as shared


class AbsentContactReferenceRecoveryRoute(shared.AirborneReferenceRecoveryRoute):
    policy_id = 'sporespore_balanced_wave_recovery_absent_contact_reference_v1'
    run_label = 'V40'
    contract_family = 'absent_contact_reference'


if __name__ == '__main__':
    unittest.main()
