"""V35 data selection for the shared actual-floor, motor-ledger and reader checks."""
import unittest
import test_development_v34_floor_adapter as shared


class FeasibleSupportFloorAdapter(shared.FloorAdapter):
    policy_id = 'sporespore_balanced_wave_recovery_feasible_support_v1'
    candidate_id = 'v35-feasible-support-v1'
    fixture = 'res://tests/test_development_v35_floor_adapter.gd'
    run_label = 'V35'


if __name__ == '__main__':
    unittest.main()
