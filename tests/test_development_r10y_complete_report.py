"""Actual R10Y retention publisher and cold full-report replay, zero physics."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_passive_entry_profile as entry
import development_recovery_candidate as candidate
import r10y_development as development
import r10y_native_component as native
from test_development_r10q_source_orchestration import GODOT, write

PROFILE = ROOT / 'sdk/development/recovery_candidates/r10y-partial-direct-neutral-integrated-v1.json'
FIXTURES = native.EVIDENCE / 'development-r10k-control-component-90952b02eab94958a0db68ca0ae1a08e/stdout.log'
FIXTURES_SHA = 'sha256:8b389a917370a534accc0502835a2cca66537fe1d6785f7eb5d7b27c7f3441ae'


def declaration(reference, head):
    attempt = uuid.uuid4().hex
    role = development.ROLES[0]
    child = dict(role=role, child_attempt_id=uuid.uuid4().hex, termination_nonce=uuid.uuid4().hex,
        evidence_path=(native.EVIDENCE / ('development-recovery-smoke-' + attempt) / 'children' / role).as_posix())
    value = dict(attempt_id=attempt, children=[child], candidate_profile=reference,
        source_snapshot=dict(head=head), seed=51008, development_execution_mode=development.SINGLE,
        comparative_authority=False, baseline_reused=False)
    value['r10y_development'] = development.context(development.SINGLE, head, reference)
    selected = candidate.selection(reference)
    value.update(candidate.limits(selected), schema_version=selected['worker_selection']['declaration_schema'],
        diagnostic_schedule_id=selected['worker_selection']['schedule'], worker_resource=selected['worker_selection']['worker'],
        passive_entry_runtime=entry.binding(selected)['runtime'], timeout_seconds_per_child=1740,
        independent_replay_timeout_seconds=900, official_qualification=False,
        physical_acceptance_authority=False, release_authority=False,
        context_cache_profile_id=entry.profile.CACHE_PROFILE_ID,
        context_cache_call_sites=entry.profile.CACHE_CALL_SITES, step_cost_profile_id=entry.profile.PROFILE_ID)
    return value


class R10YCompleteReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = native.EVIDENCE / ('r10y-complete-report-' + uuid.uuid4().hex)
        cls.out.mkdir()
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        print('R10Y_COMPLETE_REPORT_ROOT ' + str(cls.out), flush=True)
        assert native.diagnosis.binding(FIXTURES)['raw_sha256'] == FIXTURES_SHA
        native.runtime()
        cls.reference = candidate.reference_for_path(PROFILE)
        cls.selection = candidate.selection(cls.reference)
        cls.declaration = declaration(cls.reference, cls.before['head'])
        development.validate_declaration(cls.declaration)
        write(cls.out / 'synthetic-declaration.json', cls.declaration)
        write(cls.out / 'fixture-source.json', native.diagnosis.binding(FIXTURES))

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        assert after == cls.before, 'R10Y complete report source drift'

    def run_branch(self, branch):
        output = self.out / (branch + '.fixture.json')
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10y_report_fixture.gd', '--', str(FIXTURES), str(output), branch]
        environment = dict(os.environ, SPORE_R10Y_FIXTURE_DECLARATION=str(self.out / 'synthetic-declaration.json'))
        started = time.monotonic()
        with (self.out / (branch + '.stdout.log')).open('xb') as stdout, (self.out / (branch + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                    timeout=420, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / (branch + '.execution.json'), dict(command=command, timed_out=True,
                    direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                raise
        write(self.out / (branch + '.execution.json'), dict(command=command, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (branch + '.stderr.log')).read_text(encoding='utf-8')
        self.assertNotIn('ERROR:', error)
        self.assertEqual(0, process.returncode, error)
        fixture = entry.read(output)
        self.assertTrue(fixture['ok'], dict(failure=fixture['failure'], active=fixture['active'].get('failure_code')))
        self.assertTrue(all(fixture['checks'].values()))
        self.assertTrue(fixture['synthetic_measurements_only'])
        self.assertEqual((0, 0), (fixture['world_build_count'], fixture['solver_step_count']))
        report = fixture['active']['report']
        directory = self.out / branch
        directory.mkdir()
        path = directory / 'worker_report.json'
        write(path, report)
        observed = entry.run_replay(path)
        self.assertEqual(observed, entry.consume_replay(path))
        self.assertTrue(observed['ok'] and observed['complete_report_timeline_replayed'])
        self.assertEqual(0, observed['initial_global_semantic_step'])
        self.assertEqual(report['solver_step_count'], observed['transition_count'])
        self.assertEqual(self.declaration['r10y_development'], report['r10y_development'])
        self.assertEqual((False, 0), (report['held_out'], report['held_out_cell_access_count']))
        self.assertEqual(report['finite_recovery_task'], observed['finite_recovery_task'])
        self.assertFalse(report['finite_recovery_task']['cycle_and_stop_boundary_reached'])
        self.assertEqual('walking_not_reached', observed['finite_walking_measurement']['status'])
        write(directory / 'result.json', observed)
        return fixture, observed

    def test_partial_complete_report_and_changed_readiness_refused(self):
        fixture, result = self.run_branch('partial')
        self.assertEqual((240, 63, 0, 0), tuple(result[key] for key in
            ('entry_observation_count', 'partial_observation_count', 'upright_observation_count', 'canonical_initialization_count')))
        self.assertEqual(1, result['stance_entry_replay']['recomputed_readiness_samples'])
        changed = copy.deepcopy(fixture['active']['report'])
        source = changed['stance_entry']['readiness_rows'][0]['source']
        source['readiness']['ready'] = not source['readiness']['ready']
        directory = self.out / 'partial-crossed-readiness'
        directory.mkdir()
        write(directory / 'worker_report.json', changed)
        with self.assertRaises(ValueError):
            entry.run_replay(directory / 'worker_report.json')

    def test_prone_complete_report_without_walking(self):
        fixture, result = self.run_branch('prone')
        self.assertEqual((1, 13, 0, 0), tuple(result[key] for key in
            ('canonical_initialization_count', 'canonical_observation_count', 'partial_observation_count', 'upright_observation_count')))
        self.assertEqual(12, fixture['active']['report']['retained_arm']['orchestrator_state']['consecutive_prone_sample_count'])


if __name__ == '__main__':
    unittest.main()
