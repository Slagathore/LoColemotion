"""V38 selection for shared actual-floor construction and independent reader."""
import unittest
import test_development_v34_floor_adapter as shared


class WaveVelocityFloorAdapter(shared.FloorAdapter):
    policy_id = 'sporespore_balanced_wave_recovery_wave_velocity_v1'
    candidate_id = 'v38-wave-velocity-v1'
    fixture = 'res://tests/test_development_v38_floor_adapter.gd'
    run_label = 'V38'

    def test_actual_constructor_adapter_and_ledger(self):
        super().test_actual_constructor_adapter_and_ledger()
        rows = self.producer['result']['report']['development_walking_entry']['rows']
        self.assertEqual(200, len(rows))
        for row in rows:
            output = row['native_output']['actuation']
            self.assertEqual('sporespore_recovery_wave_velocity_controller_step_receipt_v1', output['receipt']['schema_version'])
            receipt = output['receipt']['recovery_support_plane']
            self.assertEqual('bounded_pose_separated_wave_velocity_tracking_v1', receipt['reference_velocity_mode_id'])
            rates = receipt['ordered_reference_velocity_rad_s']; wave = receipt['wave_velocity']
            self.assertEqual(8, len(rates)); self.assertEqual(8, len(wave['ordered_comparison_reference_rad']))
            self.assertEqual(row['request']['memory']['support_reference'].get('previous_wave'), wave['previous_wave'])
            self.assertEqual(row['native_output']['next_memory']['support_reference']['previous_wave'],wave['current_wave'])
            dt = receipt['reference_step_duration_s']
            for i, command in enumerate(output['ordered_commands']):
                cap = command['maximum_target_speed_rad_s']
                rate = max(-cap, min(cap, (command['requested_target_position_rad']-wave['ordered_comparison_reference_rad'][i])/dt)) if dt>0 and wave['feedforward_active'] else 0.
                self.assertAlmostEqual(rate,rates[i],delta=1e-13)
                self.assertLessEqual(abs(rates[i]),cap)


if __name__ == '__main__':
    unittest.main()
