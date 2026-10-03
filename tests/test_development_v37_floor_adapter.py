"""V37 data selection for shared actual-floor, motor-ledger and reader checks."""
import unittest
import test_development_v34_floor_adapter as shared


class ReferenceVelocityFloorAdapter(shared.FloorAdapter):
    policy_id = 'sporespore_balanced_wave_recovery_reference_velocity_v1'
    candidate_id = 'v37-reference-velocity-v1'
    fixture = 'res://tests/test_development_v37_floor_adapter.gd'
    run_label = 'V37'

    def test_actual_constructor_adapter_and_ledger(self):
        super().test_actual_constructor_adapter_and_ledger()
        rows = self.producer['result']['report']['development_walking_entry']['rows']
        self.assertEqual(200, len(rows))
        for row in rows:
            output = row['native_output']['actuation']
            self.assertEqual('sporespore_recovery_reference_velocity_controller_step_receipt_v1', output['receipt']['schema_version'])
            receipt = output['receipt']['recovery_support_plane']
            self.assertEqual('bounded_slewed_reference_velocity_tracking_v1', receipt['reference_velocity_mode_id'])
            rates = receipt['ordered_reference_velocity_rad_s']
            self.assertEqual(8, len(rates))
            dt = receipt['reference_step_duration_s']
            prior = row['request']['memory']['support_reference']['ordered_target_positions_rad']
            for i, command in enumerate(output['ordered_commands']):
                cap = command['maximum_target_speed_rad_s']
                rate = max(-cap, min(cap, (command['requested_target_position_rad']-prior[i])/dt)) if dt > 0 else 0.
                self.assertAlmostEqual(rate, rates[i], delta=1e-13)
                self.assertLessEqual(abs(rates[i]), cap)


if __name__ == '__main__':
    unittest.main()
