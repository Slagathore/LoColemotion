"""V36 data selection for the shared actual-floor, motor-ledger and reader checks."""
import unittest
import test_development_v34_floor_adapter as shared


class SmoothSwingFloorAdapter(shared.FloorAdapter):
    policy_id = 'sporespore_balanced_wave_recovery_smooth_swing_v1'
    candidate_id = 'v36-smooth-swing-v1'
    fixture = 'res://tests/test_development_v36_floor_adapter.gd'
    run_label = 'V36'


if __name__ == '__main__':
    unittest.main()
