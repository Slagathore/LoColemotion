"""V43 in the shared real adapter, motor ledger and cold reader; zero worlds."""
import hashlib
import json
import unittest

import test_development_v40_floor_adapter as rates
import test_development_v42_floor_adapter as shared
import test_development_v43_support_progression_component as component


class SupportProgressionFloorAdapter(shared.StanceLatchFloorAdapter):
    policy_id = component.POLICY
    candidate_id = 'v43-support-progression-v1'
    fixture = 'res://tests/test_development_v43_floor_adapter.gd'
    run_label = 'V43'
    receipt_schema = component.RECEIPT
    reference_mode = 'stance_latched_upright_reference_velocity_tracking_v1'
    call = component.SupportProgression.call

    def test_actual_constructor_adapter_and_ledger(self):
        rates.AbsentContactReferenceFloorAdapter.test_actual_constructor_adapter_and_ledger(self)
        report = self.producer['result']['report']
        self.descriptor = report['configuration']['base_descriptor']
        upper = .35*self.descriptor['upper_length_fraction']
        self.dimensions = (upper, .35-upper, .04*self.descriptor['foot_radius_scale'], self.descriptor['hip_span_scale'])
        self.native = self.native_api()
        old_binding = component.candidate.read(component.ROOT/'sdk/development/recovery_candidates/v42-stance-latch-v1.runtime.json')
        self.assertEqual(old_binding['runtime']['raw_sha256'], component.candidate.sha(component.Path(old_binding['runtime']['path'])))
        self.old = component.NativeApi(old_binding['runtime']['path'])
        counts = dict(commands=0, held_commands=0, released_hold_windows=0)
        maximum_error = 0.
        previous = None
        for row in report['development_walking_entry']['rows']:
            request = component.SupportProgression.request(self, row, row['request']['memory'])
            # Godot's decoded floats are not raw-response authority. Reproduce
            # the exact retained bytes before using Rust-decoded values for the
            # parent/native arithmetic comparison (no tolerance relaxation).
            raw, output = self.call(request)
            self.assertEqual(row['raw_native_response_sha256'],
                             'sha256:'+hashlib.sha256(raw).hexdigest())
            checked = component.SupportProgression.check_output(self, row, request, output)
            self.assertFalse(checked['timeout'])
            if previous is not None:
                self.assertEqual(previous['next_memory'], request['memory'])
            counts['commands'] += 1
            counts['held_commands'] += checked['held']
            counts['released_hold_windows'] += request['memory']['support_progression']['held_steps'] > 0 and not checked['held']
            maximum_error = max(maximum_error, checked['motor_error'])
            previous = row['native_output']
        self.assertEqual(200, counts['commands'])
        self.assertGreater(counts['held_commands'], 0)
        self.assertGreater(counts['released_hold_windows'], 0)
        print('V43_PROGRESSION_ADAPTER_RECONSTRUCTION', json.dumps(dict(counts,
            maximum_motor_reconstruction_error_rad_s=maximum_error,
            all_memory_links_exact=True, all_raw_native_response_hashes_exact=True,
            parent_clock_preview_reconstructed=True,
            contacts_not_inferred=True, synthetic_inputs_only=True,
            world_build_count=0, solver_step_count=0)), flush=True)


def load_tests(loader, _tests, _pattern):
    # Preserve the existing 54 corruption checks; legacy and new guard checks
    # are separate mandatory stages under the unchanged per-stage time bound.
    return unittest.TestSuite(SupportProgressionFloorAdapter(name) for name in
        loader.getTestCaseNames(SupportProgressionFloorAdapter)
        if name != 'test_legacy_source_suite_has_no_new_failures')


if __name__ == '__main__':
    unittest.main()
