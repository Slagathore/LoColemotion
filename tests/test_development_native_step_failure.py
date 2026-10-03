"""Real development failure path: unchanged normal output, typed no-act refusal.

No physical run or new controller. The retained V43 input has one explicitly
synthetic hold-counter substitution; original missing command 177 stays unknown.
"""
import json
import os
from pathlib import Path
import shutil
import unittest
import uuid

import test_development_passive_entry_replay as process
import test_development_v43_support_progression_component as component
import development_recovery_v43_invalid_checkpoint as historical

ROOT = component.ROOT
OWNED_SOURCES = (
    'sdk/development/recovery_native_step_failure_contract_v1.json',
    'sdk/adapters/godot/gdscript/development_native_step_failure_v1.gd',
    'scripts/lab/gait/sdk_godot_jolt_adapter.gd',
    'sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd',
    'tests/test_development_native_step_failure.gd',
    'tests/test_development_native_step_failure.py',
    'sdk/run_development_recovery_smoke.ps1',
)


class NativeFailure(unittest.TestCase):
    _run_retained = classmethod(process.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.root = ROOT.parent/'SporeSpore_Evidence'/('development-native-step-failure-'+uuid.uuid4().hex)
        cls.root.mkdir()
        print('DEVELOPMENT_NATIVE_STEP_FAILURE_ROOT', cls.root, flush=True)
        for relative in OWNED_SOURCES:
            path = cls.root/'tested_sources'/relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT/relative, path)
        report = historical.report()
        rows = [dict(request=r['request'], raw_native_response_sha256=r['raw_native_response_sha256'])
                for r in report['development_walking_entry']['rows']]
        path = cls.root/'retained_inputs.json'
        # Exercise the selected candidate's actual runtime when run by the
        # shared gate. The frozen V43 case probes the generic refusal ABI;
        # selected-controller behavior has its own mandatory candidate tests.
        relative = os.environ.get('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE',
            'sdk/development/recovery_candidates/v43-support-progression-integrated-v1.json')
        runtime_profile = (ROOT/relative).resolve()
        component.candidate.reference_for_path(runtime_profile)
        with path.open('xb') as stream:
            stream.write(component.request_bytes(dict(rows=rows,
                runtime_profile='res://'+runtime_profile.relative_to(ROOT).as_posix())))
        run = cls._run_retained('res://tests/test_development_native_step_failure.gd', ['--', str(path)], 'actual_failure_path', 90)
        # Keep a failed probe's checks visible without dumping its raw payloads.
        lines = [json.loads(l.split(' ', 1)[1]) for l in run.stdout.decode().splitlines()
                 if l.startswith('DEVELOPMENT_NATIVE_STEP_FAILURE ')]
        if lines:
            print('DEVELOPMENT_NATIVE_STEP_FAILURE_CHECKS', json.dumps(lines[0]['checks']), flush=True)
        cls.producer = process.marker(run, 'DEVELOPMENT_NATIVE_STEP_FAILURE ')

    def test_actual_adapter_step_and_worker_publication_keep_exact_failure(self):
        self.assertTrue(self.producer['ok'], self.producer['checks'])
        self.assertTrue(all(self.producer['checks'].values()))
        result = self.producer['result']
        self.assertEqual(176, result['normal_commands'])
        failed = result['failed_adapter_result']
        record = failed['development_native_step_failure']
        self.assertFalse(failed['ok'])
        self.assertTrue(record['verified_zero_actuation_refusal'])
        self.assertEqual('CAPABILITY_UNSUPPORTED:support_progression_hold_timeout', record['reported_native_controller_error'])
        self.assertEqual(record, result['published_partial_arm']['last_walking_step_failure']['portable_step_receipt']['development_native_step_failure'])
        self.assertEqual(record['request']['raw_sha256'], historical.digest(record['request']['utf8_text'].encode()))
        self.assertEqual(record['response']['raw_sha256'], historical.digest(record['response']['utf8_text'].encode()))
        # Check every unchanged memory value independently in Python as well.
        request = json.loads(record['request']['utf8_text'])
        response = json.loads(record['response']['utf8_text'])
        self.assertEqual(request['memory'], response['value']['next_memory'])
        for key in ('controller_reinvoked', 'adapter_clock_advanced', 'adapter_memory_advanced', 'motor_application_permitted', 'complete_route_proven', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(record[key], key)
        print('DEVELOPMENT_NATIVE_STEP_FAILURE_VERIFIED', json.dumps(dict(normal_commands_exact=176,
            actual_adapter_failure=failed['detail'], raw_request_sha256=record['request']['raw_sha256'],
            raw_response_sha256=record['response']['raw_sha256'], native_reason=record['reported_native_controller_error'],
            clock_and_memory_unchanged=True, actual_worker_projection=True, world_build_count=0, solver_step_count=0)), flush=True)

    def test_rehashed_native_corruptions_and_forged_records_refuse(self):
        result = self.producer['result']
        self.assertEqual(23, len(result['native_negative_controls']))
        self.assertEqual(6, len(result['forged_retention_controls']))
        self.assertTrue(all(result['native_negative_controls'].values()))
        self.assertTrue(all(result['forged_retention_controls'].values()))
        print('DEVELOPMENT_NATIVE_STEP_FAILURE_REFUSALS', json.dumps(dict(native=result['native_negative_controls'], retention=result['forged_retention_controls'])), flush=True)

    def test_original_invalid_attempt_and_frozen_diagnosis_are_preserved(self):
        self.assertTrue(historical.read(historical.RECORD) == historical.observe())
        self.assertEqual('sha256:a4c4f524e3fde84313ae512b5b25b5a1389460ea93e9069204c784d0c5e31718', historical.identity(historical.RECORD)['raw_sha256'])
        diagnosis = ROOT/'sdk/development/recovery_v43_safe_stop_diagnosis_v1.json'
        self.assertEqual('sha256:ae8014e824b927037fa960fe8903b3c86c86671836dfd6cf8389fe41a93b3f9e', historical.identity(diagnosis)['raw_sha256'])
        runner = (ROOT/'sdk/run_development_recovery_smoke.ps1').read_text()
        self.assertIn("@{id='candidate_native_step_failure';pattern='test_development_native_step_failure.py';tests=3;candidate_profile=$candidatePathRequested}", runner)


if __name__ == '__main__':
    unittest.main()
