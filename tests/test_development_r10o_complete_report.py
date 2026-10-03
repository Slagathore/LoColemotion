"""Real R10O publisher and cold report reader on synthetic source populations."""
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
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_passive_entry_profile as entry
import development_recovery_candidate as candidate
import r10o_development as development
import r10o_finite_task_audit as finite
sys.path.insert(0, str(ROOT / 'sdk/python'))
from sporespore_locomotion import LocomotionCore
from test_development_r10k_worker_component import GODOT, FIXTURES, write

PROFILE = ROOT / 'sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json'


def declaration(reference, head):
    attempt = uuid.uuid4().hex
    children = [dict(role=role, child_attempt_id=uuid.uuid4().hex, termination_nonce=uuid.uuid4().hex,
        evidence_path=(EVIDENCE / ('development-recovery-smoke-' + attempt) / 'children' / role).as_posix()) for role in development.ROLES]
    value = dict(attempt_id=attempt, children=children, candidate_profile=reference,
        source_snapshot=dict(head=head), seed=40741, development_execution_mode=development.PAIR,
        comparative_authority=False, baseline_reused=False)
    value['r10o_development'] = development.context(development.PAIR, head, reference)
    return value


class R10OCompleteReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10O_REPORT_ROOT', str(EVIDENCE / ('development-r10o-complete-report-' + uuid.uuid4().hex))))
        cls.out.mkdir(exist_ok=False)
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        cls.reference = candidate.reference_for_path(PROFILE)
        cls.selection = candidate.selection(cls.reference)
        cls.declaration = declaration(cls.reference, cls.before['head'])
        write(cls.out / 'synthetic-declaration.json', cls.declaration)
        development.validate_declaration(cls.declaration)
        print('R10O_COMPLETE_REPORT_EVIDENCE ' + str(cls.out), flush=True)

    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        if after != cls.before:
            raise AssertionError('R10O_REPORT_SOURCE_DRIFT')

    def run_branch(self, branch):
        output = self.out / (branch + '.fixture.json')
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10o_report_fixture.gd', '--', str(FIXTURES), str(output), branch]
        environment = dict(os.environ, SPORE_R10O_FIXTURE_DECLARATION=str(self.out / 'synthetic-declaration.json'))
        started = time.monotonic()
        with (self.out / (branch + '.stdout.log')).open('xb') as stdout, (self.out / (branch + '.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.run(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                    timeout=240, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                write(self.out / (branch + '.execution.json'), dict(command=command, timed_out=True,
                    direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                raise
        write(self.out / (branch + '.execution.json'), dict(command=command, exit_code=process.returncode,
            seconds=round(time.monotonic()-started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (branch + '.stderr.log')).read_text(encoding='utf-8')
        self.assertNotIn('ERROR:', error)
        self.assertEqual(0, process.returncode, error + (self.out / (branch + '.stdout.log')).read_text(encoding='utf-8')[-4000:])
        fixture = entry.read(output)
        self.assertTrue(fixture['ok'], fixture['failure'])
        results = {}
        for label in ('active', 'baseline'):
            report = fixture[label]['report']
            directory = self.out / (branch + '-' + label)
            directory.mkdir()
            path = directory / 'worker_report.json'
            write(path, report)
            observed = entry.run_replay(path)
            self.assertEqual(observed, entry.consume_replay(path))
            self.assertTrue(observed['ok'] and observed['complete_report_timeline_replayed'])
            self.assertEqual(0, observed['initial_global_semantic_step'])
            self.assertEqual(report['solver_step_count'], observed['transition_count'])
            self.assertEqual(report['finite_recovery_task'], observed['finite_recovery_task'])
            self.assertEqual(self.declaration['r10o_development'], report['r10o_development'])
            self.assertEqual((False, 0), (report['held_out'], report['held_out_cell_access_count']))
            selected = entry.selection_for_report(report)
            core = LocomotionCore(entry.binding(selected)['runtime']['path'])
            compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
            measured = finite.measure(report, compiled)
            write(directory / 'finite-task-measurement.json', measured)
            # These reports end before walking. Even a completed recovery must
            # remain task-negative until every required walking/stop predicate passes.
            self.assertFalse(measured['finite_task_predicates_passed'])
            self.assertFalse(measured['predicates']['planned_cycles'])
            if label == 'active':
                self.assertEqual(branch == 'partial', measured['predicates']['recovery_completed'])
                if branch == 'partial':
                    crossed = copy.deepcopy(report)
                    source = crossed['stance_entry']['readiness_rows'][0]['source']
                    source['readiness']['ready'] = not source['readiness']['ready']
                    refused = self.out / 'partial-crossed-readiness'
                    refused.mkdir()
                    write(refused / 'worker_report.json', crossed)
                    with self.assertRaises(ValueError):
                        entry.run_replay(refused / 'worker_report.json')
            results[label] = observed
        write(self.out / (branch + '.results.json'), results)
        return fixture, results

    def test_b_complete_partial_recovery_report_and_no_kick_boundary(self):
        fixture, results = self.run_branch('partial')
        self.assertEqual((240, 63, 0), tuple(results['active'][key] for key in
            ('entry_observation_count', 'partial_observation_count', 'canonical_initialization_count')))
        self.assertEqual(1, results['active']['stance_entry_replay']['recomputed_readiness_samples'])
        self.assertEqual(272, results['baseline']['transition_count'])

    def test_a_complete_prone_report_and_no_kick_boundary(self):
        fixture, results = self.run_branch('prone')
        self.assertEqual((1, 13, 0), tuple(results['active'][key] for key in
            ('canonical_initialization_count', 'canonical_observation_count', 'partial_observation_count')))
        self.assertEqual(12, fixture['active']['report']['retained_arm']['orchestrator_state']['confirm_prone_step_count'])


if __name__ == '__main__':
    unittest.main()
