"""Actual candidate DLL/Godot boundary checks; no physics world is launched."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'sdk/python'))
import development_passive_entry_profile as entry
from sporespore_locomotion import LocomotionCore, LocomotionCoreError


class RearwardFoldRuntime(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binding = entry.read(ROOT / 'sdk/development_rearward_fold_runtime_binding_v1.json')
        for path in (ROOT / cls.binding['local_build_path'], Path(cls.binding['runtime']['path'])):
            actual = entry.runtime.file_identity(path)
            for key in ('byte_length', 'raw_sha256'):
                if actual[key] != cls.binding['runtime'][key]:
                    raise AssertionError(('CANDIDATE_RUNTIME_DRIFT', str(path), key))
        for source in cls.binding['source_files']:
            if entry.runtime.file_identity(ROOT / source['path'], display_path=source['path']) != source:
                raise AssertionError(('CANDIDATE_SOURCE_DRIFT', source['path']))
        cls.root = entry.EVIDENCE / ('development-rearward-fold-runtime-test-' + uuid.uuid4().hex)
        cls.root.mkdir()
        command = ['cargo', 'test', '--locked', '--manifest-path', 'sdk/Cargo.toml', '-p', 'sporespore-locomotion-core',
                   '--target-dir', 'sdk/target/development-rearward-fold-v1',
                   'v7_public_json_buffer_and_exported_native_shaped_fixtures', '--', '--nocapture']
        run = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, creationflags=subprocess.CREATE_NO_WINDOW)
        (cls.root / 'fixture.stdout.txt').write_bytes(run.stdout)
        (cls.root / 'fixture.stderr.txt').write_bytes(run.stderr)
        if run.returncode:
            raise AssertionError((run.returncode, run.stdout[-3000:], run.stderr[-3000:]))
        prefix = 'REARWARD_FOLD_CONTROL_FIXTURE '
        cls.fixtures = [entry.packet.parse_json(line[len(prefix):]) for line in run.stdout.decode().splitlines() if line.startswith(prefix)]
        if len(cls.fixtures) != 3:
            raise AssertionError('EXPECTED_THREE_NATIVE_SHAPED_FIXTURES')
        cls.core = LocomotionCore(ROOT / cls.binding['local_build_path'])
        cls.results = [cls.core.recovery_plan_control_v1(case['request']) for case in cls.fixtures]
        result = dict(schema_version='sporespore_development_rearward_fold_runtime_test_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='three_engine_inputs', authority_mode='development_native_dll_interface', question_class='development'),
            command=command, runtime=cls.binding['runtime'], results=cls.results,
            synthetic_native_shaped_observations_only=True, world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False)
        (cls.root / 'actual_dll_results.json').write_text(json.dumps(result, indent=2, allow_nan=False) + '\n', encoding='utf-8')
        print('REARWARD_FOLD_RUNTIME_TEST_ROOT', cls.root)

    def test_actual_candidate_dll_matches_the_portable_requests_and_commands(self):
        for fixture, actual in zip(self.fixtures, self.results):
            self.assertTrue(entry.packet.same(actual, fixture['expected']))
            self.assertEqual([-0.6, 1.05] * 4, [c['target_position_rad'] for c in actual['ordered_commands']])
            self.assertEqual(0, actual['engine_identity_input_count'])
            self.assertIs(actual['physical_acceptance_authority'], False)
        self.assertTrue(all(result['command_sha256'] == self.results[0]['command_sha256'] for result in self.results))

    def test_actual_dll_refuses_crossed_owner_and_unknown_controller(self):
        for owner, controller in [('sporespore_exact_s169_prone_to_standing_controller_v6', 'sporespore_exact_s169_prone_to_standing_controller_v7'),
                                  ('unregistered', 'unregistered')]:
            request = copy.deepcopy(self.fixtures[0]['request'])
            request['controller_id'] = controller
            request['collection']['observation']['controller_ownership']['recovery_controller_id'] = owner
            result = self.core.recovery_plan_control_v1(request)
            self.assertIs(result['no_actuation_requested'], True)
            self.assertEqual([], result['ordered_commands'])
            self.assertNotEqual('supported_exact', result['support_status'])

    def test_actual_godot_planner_and_production_motor_application(self):
        self._run_godot('res://tests/test_development_rearward_fold_native.gd',
                        'DEVELOPMENT_REARWARD_FOLD_NATIVE ', 'godot', 19, True)

    def test_actual_worker_descent_handoff_confirmation_and_first_native_command(self):
        result = self._run_godot('res://tests/test_development_rearward_fold_worker_hooks.gd',
                                'DEVELOPMENT_PASSIVE_ENTRY_WORKER_HOOKS ', 'worker', None, False)
        for key in ('setup_controller_remains_v6', 'postkick_worker_selects_v7',
                    'crossed_v6_owner_refused_by_v7_scheduler',
                    'actual_worker_reaches_support_after_12_prone_samples',
                    'actual_worker_emits_front_mirrored_targets',
                    'actual_worker_applies_first_v7_support_command',
                    'native_application_records_v7_and_global_step',
                    'publication_keeps_both_controllers_and_exact_consumption_context'):
            self.assertIs(result['checks'][key], True)

    def test_v6_worker_compatibility_on_the_new_compiled_superset(self):
        result = self._run_godot('res://tests/test_development_rearward_fold_worker_hooks.gd',
                                'DEVELOPMENT_PASSIVE_ENTRY_WORKER_HOOKS ', 'v6_worker', 28,
                                False, extra_args=('v6_compatibility',))
        self.assertIs(result['checks']['v6_worker_keeps_original_controller_and_record_schema'], True)

    def test_new_worker_refuses_unbound_launch_before_runtime_or_world(self):
        result = self._run_godot('res://sdk/adapters/godot/gdscript/development_rearward_fold_smoke_worker_v1.gd',
                                'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ', 'unbound_worker', None,
                                False, expected_exit=1)
        self.assertEqual('QSDK_R10F_CAMPAIGN_BINDING_INVALID', result['failure_code'])
        self.assertEqual('sporespore_development_rearward_fold_smoke_child_v1', result['schema_version'])
        self.assertNotIn('passive_entry', result)

    def _run_godot(self, script, prefix, artifact_prefix, expected_checks, fixture,
                   extra_args=(), expected_exit=0):
        command = [entry.runtime.IMAGES['godot_engine']['path'], '--headless', '--path', str(ROOT),
                   '--script', script]
        if fixture:
            command += ['--', str(self.root / 'fixture.stdout.txt')]
        elif extra_args:
            command += ['--', *extra_args]
        source_before = entry._source_snapshot()
        snapshot_path = self.root / (artifact_prefix + '.source_snapshot.json')
        snapshot_path.write_text(json.dumps(source_before, indent=2) + '\n', encoding='utf-8')
        started = time.monotonic()
        timed_out = False
        exit_code = None
        try:
            with (self.root / (artifact_prefix + '.stdout.txt')).open('xb') as stdout, (self.root / (artifact_prefix + '.stderr.txt')).open('xb') as stderr:
                run = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=180,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
                exit_code = run.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
        finally:
            execution = dict(command=command, exit_code=exit_code, timed_out=timed_out,
                timeout_seconds=180, elapsed_seconds=time.monotonic() - started,
                source_unchanged_during_execution=entry.packet.same(source_before, entry._source_snapshot()),
                source_snapshot=entry.runtime.file_identity(snapshot_path),
                runtime=self.binding['runtime'], world_build_count=0, solver_step_count=0,
                physical_acceptance_authority=False, release_authority=False)
            (self.root / (artifact_prefix + '.execution.json')).write_text(json.dumps(execution, indent=2) + '\n', encoding='utf-8')
        stdout_raw = (self.root / (artifact_prefix + '.stdout.txt')).read_bytes()
        stderr_raw = (self.root / (artifact_prefix + '.stderr.txt')).read_bytes()
        rows = [entry.packet.parse_json(line[len(prefix):]) for line in stdout_raw.decode().splitlines()
                if line.startswith(prefix)]
        self.assertFalse(timed_out, (stdout_raw[-6000:], stderr_raw))
        self.assertIs(execution['source_unchanged_during_execution'], True)
        self.assertEqual(expected_exit, exit_code, (stdout_raw[-6000:], stderr_raw))
        self.assertFalse(b'ERROR:' in stdout_raw + stderr_raw, stderr_raw[-6000:])
        self.assertEqual(1, len(rows), stdout_raw[-6000:])
        if expected_exit == 0:
            self.assertIs(rows[0]['ok'], True, rows[0])
        if expected_checks is not None:
            self.assertEqual(expected_checks, len(rows[0]['checks']))
        self.assertTrue(all(value is True for value in rows[0].get('checks', {}).values()), rows[0])
        self.assertEqual(0, rows[0]['world_build_count'])
        self.assertEqual(0, rows[0]['solver_step_count'])
        return rows[0]

    def test_malformed_json_boundary_refuses_without_claim_or_runtime_replacement(self):
        with self.assertRaises(LocomotionCoreError):
            self.core.recovery_plan_control_v1({})
        old = entry.read(ROOT / 'sdk/development_passive_entry_runtime_binding_v1.json')
        actual = entry.runtime.file_identity(ROOT / old['local_build_path'])
        self.assertEqual(old['runtime']['raw_sha256'], actual['raw_sha256'])
        self.assertIs(self.binding['physical_worker_integrated'], False)


if __name__ == '__main__':
    unittest.main()
