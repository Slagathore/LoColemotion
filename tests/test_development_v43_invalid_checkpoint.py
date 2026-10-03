"""Original invalid closure plus real native/adapter error-boundary diagnosis."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import unittest
import uuid

import test_development_v43_support_progression_component as component
from test_development_passive_entry_replay import PassiveEntryReplay, marker
import development_recovery_v43_invalid_checkpoint as closure

ROOT = component.ROOT


class InvalidCheckpoint(unittest.TestCase):
    _run_retained = classmethod(PassiveEntryReplay._run_retained.__func__)
    call = component.SupportProgression.call

    @classmethod
    def setUpClass(cls):
        cls.report = closure.report()
        cls.entries = cls.report['development_walking_entry']['rows']
        cls.descriptor = cls.report['passive_entry']['walking_runtime_preflight']['configuration']['base_descriptor']
        upper = .35 * cls.descriptor['upper_length_fraction']
        cls.dimensions = (upper, .35-upper, .04*cls.descriptor['foot_radius_scale'], cls.descriptor['hip_span_scale'])
        binding = component.candidate.read(ROOT/'sdk/development/recovery_candidates/v43-support-progression-v1.runtime.json')
        old = component.candidate.read(ROOT/'sdk/development/recovery_candidates/v42-stance-latch-v1.runtime.json')
        for selected in (binding, old):
            if closure.identity(selected['runtime']['path'])['raw_sha256'] != selected['runtime']['raw_sha256']:
                raise AssertionError('NATIVE_BINDING_DRIFT')
        cls.native, cls.old = component.NativeApi(binding['runtime']['path']), component.NativeApi(old['runtime']['path'])
        cls.root = ROOT.parent/'SporeSpore_Evidence'/('development-v43-invalid-diagnosis-'+uuid.uuid4().hex)
        cls.root.mkdir()
        print('V43_INVALID_DIAGNOSIS_ROOT', cls.root, flush=True)
        for relative in ('sdk/conformance/development_recovery_v43_invalid_checkpoint.py',
                         'tests/test_development_v43_invalid_checkpoint.py',
                         'tests/test_development_v43_safe_stop_transport.gd'):
            target = cls.root/'tested_sources'/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT/relative, target)

    def test_original_closure_reopens_without_regrading(self):
        observed = closure.observe()
        self.assertTrue(closure.read(closure.RECORD) == observed, 'Original closure must reproduce exactly')
        self.assertEqual((114, 1034, 176), (observed['safety_test_count'],
            observed['observation']['solver_step_count'], observed['observation']['resumed_walking_completed_commands']))
        for key in ('complete_route_proven', 'successful_recovery_proven', 'physical_acceptance_authority',
                    'release_authority', 'original_attempt_reclassified', 'repeat_consumed_attempt_permitted'):
            self.assertFalse(observed[key])
        print('V43_ORIGINAL_INVALID_VERIFIED', json.dumps(dict(attempt_id=closure.ATTEMPT,
            retained_file_count=observed['retained_population']['file_count'],
            retained_bytes=observed['retained_population']['byte_length'],
            elapsed_seconds=observed['elapsed_seconds'], safety_test_count=114)), flush=True)

    def test_partial_boundary_corruption_refuses(self):
        # Copy only touched projections, never rewrite original evidence.
        cases = {}
        for name in ('outcome', 'count', 'complete_arm', 'authority', 'clock', 'memory'):
            changed = dict(self.report)
            if name == 'outcome': changed['scientific_outcome'] = 'success'
            elif name == 'count': changed['solver_step_count'] = 1035
            elif name == 'complete_arm': changed['retained_arm'] = {}
            elif name == 'authority': changed['physical_acceptance_authority'] = True
            else:
                rows = list(self.entries)
                rows[-1] = copy.deepcopy(rows[-1])
                changed['development_walking_entry'] = dict(self.report['development_walking_entry'], rows=rows)
                if name == 'clock': rows[-1]['commanded_global_step'] += 1
                else: rows[-1]['request']['memory']['support_progression']['held_steps'] -= 1
            with self.assertRaises(ValueError) as caught:
                closure.summarize(changed)
            cases[name] = str(caught.exception)
        print('V43_INVALID_BOUNDARY_REFUSALS', json.dumps(cases), flush=True)

    def test_all_176_retained_commands_reproduce_exact_native_bytes(self):
        chain = hashlib.sha256()
        maximum_error, held = 0., 0
        previous = None
        session = component.Session(self.native, self.descriptor)
        try:
            for row in self.entries:
                request = component.SupportProgression.request(self, row, row['request']['memory'])
                raw, output = self.call(request)
                self.assertEqual(row['raw_native_response_sha256'], 'sha256:'+hashlib.sha256(raw).hexdigest())
                self.assertEqual(raw, session.raw(request))
                if previous is not None:
                    self.assertEqual(previous['next_memory'], request['memory'])
                checked = component.SupportProgression.check_output(self, row, request, output)
                self.assertFalse(checked['timeout'])
                maximum_error = max(maximum_error, checked['motor_error'])
                held += checked['held']
                chain.update(raw)
                previous = row['native_output']
        finally:
            session.close()
        self.assertEqual(143, held)
        print('V43_RETAINED_PREFIX_REPLAY', json.dumps(dict(commands=176, held_commands=held,
            raw_response_chain_sha256='sha256:'+chain.hexdigest(), all_raw_hashes_exact=True,
            both_exported_interfaces_exact=True, maximum_motor_reconstruction_error_rad_s=maximum_error,
            failed_command_reconstructed=False, complete_route_proven=False,
            new_world_build_count=0, new_native_physics_read_count=0, new_solver_step_count=0)), flush=True)

    def test_actual_godot_adapter_reproduces_synthetic_safe_stop_mismatch(self):
        last = self.entries[-1]
        fixture = dict(descriptor=self.descriptor, request=last['request'],
            raw_native_response_sha256=last['raw_native_response_sha256'])
        path = self.root/'explicit_synthetic_boundary_input.json'
        with path.open('xb') as stream:
            stream.write(component.request_bytes(fixture))
        run = self._run_retained('res://tests/test_development_v43_safe_stop_transport.gd',
                                 ['--', str(path)], 'godot_safe_stop', 90)
        result = marker(run, 'V43_SAFE_STOP_TRANSPORT ')
        self.assertTrue(result['ok'], result['checks'])
        self.assertTrue(all(result['checks'].values()))
        for key in ('world_build_count', 'solver_step_count', 'native_physics_read_count'):
            self.assertEqual(0, result[key])
        self.assertFalse(result['original_failed_request_reconstructed'])
        self.assertFalse(result['original_hidden_error_proven'])
        changed = copy.deepcopy(last['request'])
        changed['memory']['support_progression']['held_steps'] = 120
        # Python and Godot serialized variants can differ at last bits; assert
        # raw exported output bytes separately, not a rounded dictionary hash.
        request = component.SupportProgression.request(self, last, changed['memory'])
        raw, output = self.call(request)
        self.assertEqual(raw.decode(), result['result']['synthetic_raw_response'])
        self.assertEqual(changed['memory'], output['next_memory'])
        self.assertTrue(output['actuation']['safe_no_actuation'])
        print('V43_SAFE_STOP_DIAGNOSIS', json.dumps(dict(checks=result['checks'],
            local_semantic_step=176, only_substitution='incoming held_steps 119 -> 120',
            synthetic_raw_response_sha256='sha256:'+hashlib.sha256(raw).hexdigest(),
            synthetic_controller_error=output['actuation']['receipt']['controller_error'],
            actual_adapter_failure=result['result']['actual_adapter_refusal'],
            original_hidden_error_proven=False, production_fix_implemented=False,
            world_build_count=0, solver_step_count=0)), flush=True)


def load_tests(loader, _tests, _pattern):
    # Import the retained process helper, not its unrelated historical suite.
    return loader.loadTestsFromTestCase(InvalidCheckpoint)


if __name__ == '__main__':
    unittest.main()
