"""New diagnostic lane through actual PowerShell, Godot close and cold replay.

All reports used here are explicitly synthetic fixtures. Original physical and
zero-world populations are read-only; new outputs use fresh durable directories.
"""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'tests'))
import development_passive_entry_profile as entry
import development_recovery_smoke as reader
import development_step_cost_profile as profile
from test_development_recovery_smoke import native
import test_development_recovery_smoke_reader as header_fixture
import test_development_passive_entry_replay as replay_fixture

PWSH = 'C:/Program Files/PowerShell/7/pwsh.exe'


class MeasuredEntryProfile(unittest.TestCase):
    mode = 'ObserveMeasuredProneEntry'
    fields_function = 'Get-DevelopmentMeasuredEntryFields'
    native_script = 'res://tests/test_development_measured_entry_profile.gd'
    producer_script = 'res://tests/test_development_passive_entry_replay_fixture.gd'
    producer_marker = 'DEVELOPMENT_PASSIVE_ENTRY_REPLAY_FIXTURE '
    expected_schema = entry.SCHEMA
    expected_work = entry.WORK
    expected_gate_count = 70
    expected_steps = 276
    missing_cache_code = b'SMOKE_MEASURED_ENTRY_REQUIRES_CONTEXT_CACHE'
    root_prefix = 'development-measured-entry-profile-'

    @classmethod
    def setUpClass(cls):
        cls.root = entry.EVIDENCE / (cls.root_prefix + uuid.uuid4().hex)
        cls.root.mkdir()
        print('ENTRY_PROFILE_TEST_ROOT', cls.root, flush=True)
        command = f". ./sdk/run_development_recovery_smoke.ps1 -Library -ProfileSteps -ReuseContextChecks -{cls.mode}; " \
                  f"ConvertTo-SporeSporeExactJson -Value ([ordered]@{{fields=({cls.fields_function});worker=$script:WorkerResource;schema=$script:RawSchema;work=$script:WorkId;timeout=$TimeoutSeconds;stages=$stages}})"
        run = subprocess.run([PWSH, '-NoProfile', '-NonInteractive', '-Command', command], cwd=ROOT,
                             capture_output=True, timeout=25, creationflags=subprocess.CREATE_NO_WINDOW)
        (cls.root / 'profile.stdout.txt').write_bytes(run.stdout)
        (cls.root / 'profile.stderr.txt').write_bytes(run.stderr)
        if run.returncode:
            raise AssertionError((run.stdout, run.stderr))
        cls.selected = entry.packet.parse_json(run.stdout.decode('utf-8'))
        run = replay_fixture.PassiveEntryReplay._run_retained.__func__(cls, cls.native_script, [], 'native', 60)
        prefix = 'DEVELOPMENT_MEASURED_ENTRY_PROFILE '
        rows = [entry.packet.parse_json(line[len(prefix):]) for line in run.stdout.decode().splitlines() if line.startswith(prefix)]
        if run.returncode or b'ERROR:' in run.stdout + run.stderr or len(rows) != 1:
            raise AssertionError((run.returncode, run.stdout, run.stderr))
        cls.native = rows[0]
        # Generate the current worker-shaped fixture; the historical producer
        # bytes retain the old intent/execution bug and are never rewritten.
        producer = replay_fixture.PassiveEntryReplay._run_retained.__func__(cls, cls.producer_script, [], 'producer', 90)
        fixture = replay_fixture.marker(producer, cls.producer_marker)
        if fixture['ok'] is not True or fixture['synthetic_native_observations_only'] is not True:
            raise AssertionError('CURRENT_SYNTHETIC_FIXTURE_INVALID')
        cls.report_path = cls.root / 'worker_report.json'
        cls.report_path.write_bytes(json.dumps(fixture['full_report_input']['report'], separators=(',', ':'), allow_nan=False).encode())
        cls.replay = entry.run_replay(cls.report_path)
        cls.diagnostic_directory = entry.EVIDENCE / ('development-passive-entry-post-exposure-replay-' + uuid.uuid4().hex)
        cls.original_replay_bindings = entry._original_replay_bindings(cls.report_path)
        cls.diagnostic = entry.run_replay(cls.report_path, diagnostic_directory=cls.diagnostic_directory)
        print('MEASURED_ENTRY_PROFILE_TEST_ROOT', cls.root)
        print(json.dumps(dict(native=cls.native, replay=cls.replay, source_profile=cls.selected)))

    def declaration(self):
        return dict(entry.LIMITS, **self.selected['fields'], worker_resource=self.selected['worker'],
                    context_cache_profile_id=profile.CACHE_PROFILE_ID, context_cache_call_sites=profile.CACHE_CALL_SITES,
                    step_cost_profile_id=profile.PROFILE_ID, official_qualification=False,
                    physical_acceptance_authority=False, release_authority=False)

    def test_actual_supervisor_profile_matches_reader_and_complete_gate(self):
        self.assertEqual(entry.LIMITS, entry.validate_declaration(self.declaration()))
        self.assertEqual(self.expected_schema, self.selected['schema'])
        self.assertEqual(self.expected_work, self.selected['work'])
        self.assertEqual(entry.CHILD_TIMEOUT_SECONDS, self.selected['timeout'])
        self.assertEqual(self.expected_gate_count, sum(stage['tests'] for stage in self.selected['stages']))
        self.assertIs(self.native['ok'], True, self.native)
        self.assertTrue(all(self.native['checks'].values()), self.native)
        self.assertEqual(0, self.native['world_build_count'])

    def test_actual_header_uses_distinct_report_identity_and_bounds(self):
        report, descriptor, declaration = header_fixture.SmokeReader().fixture()
        declaration.update(self.declaration())
        report.update(schema_version=self.expected_schema, work_id=self.expected_work, maximum_solver_step_count=832,
                      solver_step_count=752, global_solver_frame_count=752, after_interaction_step_count=480)
        reader.validate_header(report, descriptor, declaration, 123)
        for key, value in [('work_id', reader.WORK), ('schema_version', reader.SCHEMA), ('solver_step_count', 833),
                           ('after_interaction_step_count', 481), ('complete_route_proven', True), ('synthetic_test_fixture', True)]:
            changed = dict(report, **{key: value})
            with self.subTest(key=key), self.assertRaises(ValueError):
                reader.validate_header(changed, descriptor, declaration, 123)

    def test_declaration_refuses_incomplete_crossed_or_wrong_kinds(self):
        good = self.declaration()
        keys = set(entry.LIMITS) | {'schema_version', 'diagnostic_schedule_id', 'worker_resource', 'passive_entry_runtime',
                                  'timeout_seconds_per_child', 'independent_replay_timeout_seconds',
                                  'context_cache_profile_id', 'physical_acceptance_authority'}
        for key in keys:
            for value in (None, True, 'wrong', 60.5):
                changed = copy.deepcopy(good)
                changed[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    entry.validate_declaration(changed)

    def test_real_cli_rejects_incompatible_modes_before_gate_or_world(self):
        cases = [(['-' + self.mode], self.missing_cache_code),
                 (['-ProfileSteps', '-ReuseContextChecks', '-' + self.mode, '-ObserveProneDeadline'], b'SMOKE_DIAGNOSTIC_SCHEDULES_EXCLUSIVE'),
                 (['-Library', '-RunSmoke'], b'SMOKE_LIBRARY_CANNOT_RUN')]
        for flags, code in cases:
            run = subprocess.run([PWSH, '-NoProfile', '-NonInteractive', '-File', 'sdk/run_development_recovery_smoke.ps1', *flags],
                                 cwd=ROOT, capture_output=True, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
            self.assertNotEqual(0, run.returncode)
            self.assertIn(code, run.stderr)
        # A dot-sourced helper also has a Library switch. Ordinary invocations
        # must still reach the real operation lock, not silently return as a
        # library. Hold that lock so these actual commands cannot open worlds
        # or recursively run the whole safety gate. The outer gate may own it.
        for index, flags in enumerate(('', '-ProfileSteps -ReuseContextChecks',
                                     '-RunSmoke -ProfileSteps -ReuseContextChecks -' + self.mode)):
            command = ". ./sdk/locomotion_operation_lock.ps1; " \
                      "$guard = Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0; " \
                      "try { & 'C:/Program Files/PowerShell/7/pwsh.exe' -NoProfile -NonInteractive -File " \
                      f"sdk/run_development_recovery_smoke.ps1 {flags}; $childExit = $LASTEXITCODE " \
                      "} finally { Exit-SporeSporeLocomotionOperationLock -Receipt $guard }; exit $childExit"
            run = subprocess.run([PWSH, '-NoProfile', '-NonInteractive', '-Command', command], cwd=ROOT,
                                 capture_output=True, timeout=20, creationflags=subprocess.CREATE_NO_WINDOW)
            (self.root / f'ordinary_cli_{index}.stdout.txt').write_bytes(run.stdout)
            (self.root / f'ordinary_cli_{index}.stderr.txt').write_bytes(run.stderr)
            self.assertEqual(1, run.returncode, (run.stdout, run.stderr))
            self.assertIn(b'DEVELOPMENT_RECOVERY_SMOKE_REFUSAL SMOKE_OPERATION_LOCK_BUSY', run.stdout)

    def test_cold_process_consumes_exact_report_and_refuses_changed_provenance(self):
        self.assertEqual(self.expected_steps, self.replay['transition_count'])
        self.assertEqual(1, self.replay['canonical_initialization_count'])
        self.assertIs(self.replay['complete_report_timeline_replayed'], True)
        self.assertIs(self.replay['physical_acceptance_authority'], False)
        self.assertEqual(self.replay, entry.consume_replay(self.report_path))
        directory = self.root / 'passive_entry_replay'
        original_read = entry.read
        execution = original_read(directory / 'execution.json')
        for key, value in [('process_id', -1), ('input_raw_sha256', 'sha256:' + '0' * 64), ('command', []),
                           ('timed_out', True), ('returncode', 1), ('timeout_seconds', 1), ('stdout_binding', {})]:
            changed = dict(execution, **{key: value})
            def altered(path):
                return changed if path == directory / 'execution.json' else original_read(path)
            with self.subTest(key=key), patch.object(entry, 'read', side_effect=altered), self.assertRaises(ValueError):
                entry.consume_replay(self.report_path)
        with self.assertRaises(FileExistsError):
            entry.run_replay(self.report_path)
        self.assertEqual(self.original_replay_bindings, entry._original_replay_bindings(self.report_path))
        self.assertEqual(self.diagnostic, entry.consume_replay(self.report_path, diagnostic_directory=self.diagnostic_directory))
        self.assertIs(self.diagnostic['original_attempt_reclassified'], False)
        self.assertIs(self.diagnostic['complete_route_proven'], False)
        with self.assertRaises(FileExistsError):
            entry.run_replay(self.report_path, diagnostic_directory=self.diagnostic_directory)
        for directory in (self.root, self.root / 'passive_entry_replay', ROOT / 'diagnostic-replay'):
            with self.subTest(directory=directory), self.assertRaises(ValueError):
                entry._paths(self.report_path, directory)
        diagnostic_execution_path = self.diagnostic_directory / 'execution.json'
        diagnostic_execution = original_read(diagnostic_execution_path)
        for key, value in [('original_attempt_reclassified', True), ('source_unchanged_during_replay', False),
                           ('original_replay_bindings', []), ('source_snapshot_binding', {})]:
            changed = dict(diagnostic_execution, **{key: value})
            def altered_diagnostic(path):
                return changed if path == diagnostic_execution_path else original_read(path)
            with self.subTest(key=key), patch.object(entry, 'read', side_effect=altered_diagnostic), self.assertRaises(ValueError):
                entry.consume_replay(self.report_path, diagnostic_directory=self.diagnostic_directory)


if __name__ == '__main__':
    unittest.main()
