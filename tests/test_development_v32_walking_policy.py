"""Actual V32 adapter/ledger and cold serialized-reader integration; zero worlds."""
import copy
import json
import io
from pathlib import Path
import subprocess
import unittest
import uuid
from unittest.mock import patch

from development_recovery_candidate_test_support import candidate, ROOT
import test_development_passive_entry_replay as shared

POLICY = 'sporespore_balanced_wave_recovery_swing_end_recontact_v1'


class WalkingPolicy(unittest.TestCase):
    policy_id = POLICY
    component_resource = 'res://sdk/development/recovery_candidates/v32-swing-end-recontact-v1.json'
    policy_contract_path = 'sdk/development/recovery_swing_end_walking_policy_contract_v1.json'
    run_label = 'V32'
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def arguments(cls, reader_input=None):
        args = ['--', '--component-profile='+cls.component_resource,
                '--walking-policy='+cls.policy_id, '--test-label='+cls.run_label]
        return args if reader_input is None else args+[str(reader_input)]

    @classmethod
    def setUpClass(cls):
        cls.root = shared.entry.EVIDENCE / ('development-'+cls.run_label.lower()+'-walking-policy-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print(cls.run_label+'_WALKING_POLICY_ROOT', cls.root, flush=True)
        run = cls._run_retained('res://tests/test_development_v32_walking_policy.gd', cls.arguments(), 'producer', 90)
        # Preserve complete stdout/stderr, but keep a failed test's console compact.
        if not any(line.startswith((cls.run_label+'_WALKING_POLICY_PRODUCER ').encode()) for line in run.stdout.splitlines()):
            raise AssertionError(dict(returncode=run.returncode, stderr=run.stderr.decode(errors='replace')[-6000:]))
        cls.producer = shared.marker(run, cls.run_label+'_WALKING_POLICY_PRODUCER ')
        failed = [key for key, value in cls.producer['checks'].items() if value is not True]
        if failed:
            raise AssertionError(dict(failed_checks=failed, adapter=cls.producer['result'].get('adapter_start'),
                fixtures={key: value.get('failure_code') for key, value in cls.producer['result'].get('fixtures', {}).items()}))
        report = cls.producer['result']['report']
        cases = {'positive': dict(report=report, policy_id=cls.policy_id)}
        for name in ('legacy_reader', 'unknown_reader', 'wrong_session_policy', 'wrong_digest', 'prefix_session',
                     'missing_policy', 'memory_chain', 'raw_response_hash', 'native_output', 'missing_row'):
            item = copy.deepcopy(cases['positive'])
            start = item['report']['retained_arm']['walking_sessions'][0]['start_receipt']
            rows = item['report']['development_walking_entry']['rows']
            if name == 'legacy_reader':
                item['policy_id'] = ''
            elif name == 'unknown_reader':
                item['policy_id'] = 'unknown'
            elif name == 'wrong_session_policy':
                start['selected_policy_id'] = 'sporespore_balanced_wave_bw5r_b_v1'
            elif name == 'wrong_digest':
                start['selected_policy_digest'] = 'sha256:' + '0' * 64
            elif name == 'prefix_session':
                item['report']['retained_arm']['walking_sessions'][0]['evaluation_segment_id'] = 'walking_prefix'
            elif name == 'missing_policy':
                del start['development_walking_policy_id']
            elif name == 'memory_chain':
                rows[1]['request']['memory'] = rows[0]['request']['memory']
            elif name == 'raw_response_hash':
                rows[0]['raw_native_response_sha256'] = 'sha256:' + '0' * 64
            elif name == 'native_output':
                rows[0]['native_output']['actuation']['ordered_commands'][0]['target_velocity_rad_s'] += .1
            else:
                rows.pop()
                item['report']['development_walking_entry']['sample_count'] -= 1
            cases[name] = item
        inputs = cls.root / 'reader_inputs.json'
        inputs.write_text(json.dumps(cases, separators=(',', ':'), allow_nan=False) + '\n', encoding='utf-8')
        run = cls._run_retained('res://tests/test_development_v32_walking_policy.gd', cls.arguments(inputs), 'cold_reader', 90)
        cls.reader = shared.marker(run, cls.run_label+'_WALKING_POLICY_READER ')

    def test_real_adapter_session_and_motor_application(self):
        self.assertTrue(self.producer['ok'])
        self.assertTrue(all(self.producer['checks'].values()))
        for fixture in self.producer['result']['fixtures'].values():
            self.assertEqual(8, fixture['detached_hinge_parameter_container_count'])
            for key in ('world_build_count', 'solver_step_count', 'scene_tree_insertion_count', 'body_construction_count'):
                self.assertEqual(0, fixture[key])
        print(self.run_label+'_WALKING_POLICY_CHECKS', json.dumps(self.producer['checks'], separators=(',', ':')), flush=True)

    def test_distinct_identity_without_legacy_promotion(self):
        fixtures = self.producer['result']['fixtures']
        old, new = (fixtures[key]['ledger_application_intent'] for key in ('legacy', 'new'))
        self.assertEqual('sporespore_balanced_wave_bw5r_b_v1', old['walking_controller_policy_id'])
        self.assertEqual(self.policy_id, new['walking_controller_policy_id'])
        self.assertNotEqual(old['schema_version'], new['schema_version'])
        self.assertEqual('stance', new['controller_owner'])
        self.assertEqual(self.policy_id, new['stance_controller_id'])
        self.assertEqual(candidate.sha(ROOT / self.policy_contract_path), new['walking_controller_policy_digest'])
        for key in ('authorized_host_cap_by_actuator_id', 'published_cap_by_actuator_id'):
            self.assertEqual(old[key], new[key])
        for item in (old, new):
            self.assertFalse(item['physical_acceptance_authority'])
            self.assertFalse(item['release_authority'])

    def test_independent_serialized_reader_and_ten_corruptions(self):
        self.assertTrue(self.reader['positive']['ok'], self.reader['positive'])
        self.assertEqual(200, self.reader['positive']['replayed_walking_steps'])
        self.assertEqual(11, len(self.reader))
        for name, result in self.reader.items():
            if name != 'positive':
                self.assertFalse(result['ok'], (name, result))
        print(self.run_label+'_WALKING_POLICY_READER_RESULTS', json.dumps(self.reader, separators=(',', ':')), flush=True)

    def test_component_profile_still_non_runnable_and_native_graph_exact(self):
        path = candidate.resource_path(self.component_resource)
        with self.assertRaisesRegex(ValueError, 'DEVELOPMENT_CANDIDATE_PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(path))
        profile = candidate.read(path)
        binding = candidate.read(candidate.resource_path(profile['runtime_binding']))
        for source in binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT / source['path']))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))

    def test_legacy_source_suite_has_no_new_failures(self):
        # This old official-source suite has stale location/freeze assertions.
        # Retain and compare its result; do not weaken it or call it green.
        import test_qsdk_r10f_worker_source as legacy
        previous = '7317262bc8d5b4963585578bc7f75a8abdba0aa5'
        paths = [
            'scripts/lab/gait/sdk_godot_jolt_adapter.gd',
            'sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd',
            'sdk/adapters/godot/gdscript/development_recovery_walking_entry_v1.gd',
            'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd',
            'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd',
            'sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd',
            'sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd',
        ]
        frozen = {(ROOT / path).resolve(): subprocess.check_output(
            ['git', 'show', previous + ':' + path], cwd=ROOT) for path in paths}
        original_bytes, original_text = Path.read_bytes, Path.read_text

        def read_bytes(path):
            return frozen[path.resolve()] if path.resolve() in frozen else original_bytes(path)

        def read_text(path, *args, **kwargs):
            if path.resolve() in frozen:
                return frozen[path.resolve()].decode(kwargs.get('encoding', 'utf-8')).replace('\r\n', '\n')
            return original_text(path, *args, **kwargs)

        def run():
            result = unittest.TextTestRunner(stream=io.StringIO()).run(
                unittest.defaultTestLoader.loadTestsFromTestCase(legacy.R10fWorkerSourceTests))
            return dict(test_count=result.testsRun,
                        failures=sorted(test.id().split('.')[-1] for test, _ in result.failures),
                        errors=sorted(test.id().split('.')[-1] for test, _ in result.errors))

        current = run()
        with patch.object(Path, 'read_bytes', read_bytes), patch.object(Path, 'read_text', read_text):
            baseline = run()
        self.assertEqual(44, baseline['test_count'])
        self.assertEqual(current, baseline)
        self.assertEqual(3, len(baseline['failures']))
        self.assertEqual(['test_root_design_freeze_binding_preserves_history_and_exact_successor'], baseline['errors'])
        print('V32_LEGACY_SOURCE_DIFFERENTIAL', json.dumps(dict(source_commit=previous, baseline=baseline,
            current=current, source_files_projected=list(paths), no_new_failures=True,
            historical_suite_passed=False), separators=(',', ':')), flush=True)


if __name__ == '__main__':
    unittest.main()
