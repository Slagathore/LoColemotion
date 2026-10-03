"""V40 uses the shared actual adapter/reader tests, selecting absent stance too."""
import unittest
import test_development_v39_floor_adapter as shared


class AbsentContactReferenceFloorAdapter(shared.AirborneReferenceFloorAdapter):
    policy_id = 'sporespore_balanced_wave_recovery_absent_contact_reference_v1'
    candidate_id = 'v40-absent-contact-reference-v1'
    fixture = 'res://tests/test_development_v40_floor_adapter.gd'
    run_label = 'V40'
    receipt_schema = 'sporespore_recovery_absent_contact_reference_controller_step_receipt_v1'
    reference_mode = 'contact_selected_absent_contact_reference_velocity_tracking_v1'
    minimum_cold_probe_phase = 73
    require_selected_stance = True

    def selected_phase(self, phase):
        return 0 <= phase < 360


if __name__ == '__main__':
    unittest.main()
