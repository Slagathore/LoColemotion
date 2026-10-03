"""V44 through the shared Godot adapter, motor ledger and independent reader."""
import hashlib
import json
import unittest
import test_development_v40_floor_adapter as rates
import test_development_v43_floor_adapter as shared
import test_development_support_hold_posture_component as component


class SupportHoldPostureFloorAdapter(shared.SupportProgressionFloorAdapter):
    policy_id=component.POLICY
    candidate_id='v44-support-hold-posture-v1'
    fixture='res://tests/test_development_v44_floor_adapter.gd'
    run_label='V44'
    receipt_schema='sporespore_recovery_support_hold_posture_controller_step_receipt_v1'
    call=component.SupportHoldPosture.call

    def test_actual_constructor_adapter_and_ledger(self):
        rates.AbsentContactReferenceFloorAdapter.test_actual_constructor_adapter_and_ledger(self)
        report=self.producer['result']['report'];self.descriptor=report['configuration']['base_descriptor']
        upper=.35*self.descriptor['upper_length_fraction']
        self.dimensions=(upper,.35-upper,.04*self.descriptor['foot_radius_scale'],self.descriptor['hip_span_scale'])
        self.native=self.native_api();counts=dict(commands=0,held_commands=0,released_hold_windows=0);error=0.;previous=None
        for row in report['development_walking_entry']['rows']:
            request=component.SupportHoldPosture.request(self,row)
            raw,output=self.call(request)
            self.assertEqual(row['raw_native_response_sha256'],'sha256:'+hashlib.sha256(raw).hexdigest())
            held,difference=component.SupportHoldPosture.check(self,row,request,output)
            if previous is not None:self.assertEqual(previous['next_memory'],request['memory'])
            counts['commands']+=1;counts['held_commands']+=held
            counts['released_hold_windows']+=request['memory']['support_progression']['held_steps']>0 and not held
            error=max(error,difference);previous=row['native_output']
        self.assertEqual(200,counts['commands']);self.assertGreater(counts['held_commands'],0);self.assertGreater(counts['released_hold_windows'],0)
        print('V44_POSTURE_ADAPTER_RECONSTRUCTION',json.dumps(dict(counts,maximum_motor_reconstruction_error_rad_s=error,
            all_memory_links_exact=True,all_raw_native_response_hashes_exact=True,
            support_hold_mode_reconstructed=True,contacts_not_inferred=True,synthetic_inputs_only=True,
            world_build_count=0,solver_step_count=0)),flush=True)


def load_tests(loader,_tests,_pattern):
    return unittest.TestSuite(SupportHoldPostureFloorAdapter(name) for name in
        loader.getTestCaseNames(SupportHoldPostureFloorAdapter) if name!='test_legacy_source_suite_has_no_new_failures')


if __name__=='__main__':unittest.main()
