"""Real R10R publisher and cold report reader on synthetic source populations."""
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
import r10r_development as development
import r10r_finite_task_audit as finite
sys.path.insert(0, str(ROOT / 'sdk/python'))
from sporespore_locomotion import LocomotionCore
from test_development_r10q_source_orchestration import GODOT, write
import r10r_native_component as native

PROFILE = ROOT / 'sdk/development/recovery_candidates/r10r-v55-upright-integrated-v3.json'


def declaration(reference, head):
    attempt = uuid.uuid4().hex
    children = [dict(role=role, child_attempt_id=uuid.uuid4().hex, termination_nonce=uuid.uuid4().hex,
        evidence_path=(EVIDENCE / ('development-recovery-smoke-' + attempt) / 'children' / role).as_posix()) for role in [development.ROLES[1]]]
    value = dict(attempt_id=attempt, children=children, candidate_profile=reference,
        source_snapshot=dict(head=head), seed=40946, development_execution_mode=development.SINGLE,
        comparative_authority=False, baseline_reused=False)
    value['r10r_development'] = development.context(development.SINGLE, head, reference)
    return value


class R10RCompleteReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10R_REPORT_ROOT', str(EVIDENCE / ('development-r10r-complete-report-' + uuid.uuid4().hex))))
        cls.out.mkdir(exist_ok=False)
        cls.before = entry._source_snapshot()
        write(cls.out / 'source_before.json', cls.before)
        cls.reference = candidate.reference_for_path(PROFILE)
        cls.selection = candidate.selection(cls.reference)
        cls.declaration = declaration(cls.reference, cls.before['head'])
        write(cls.out / 'synthetic-declaration.json', cls.declaration)
        development.validate_declaration(cls.declaration)
        print('R10R_COMPLETE_REPORT_EVIDENCE ' + str(cls.out), flush=True)
        runtime, old = native.read(native.BINDING), native.read(native.Q_BINDING)
        original = native.fixtures(old['compiled_fixtures']['path'], 'R10Q_UPRIGHT_FIXTURE')
        successor = native.fixtures(runtime['compiled_fixtures']['path'], 'R10R_UPRIGHT_FIXTURE')
        cls.fixtures = cls.out / 'source-fixtures.jsonl'
        with cls.fixtures.open('xb') as stream:
            for fixture in [original[0], *successor]:
                stream.write(('R10R_SOURCE_FIXTURE ' + json.dumps(fixture, allow_nan=False) + '\n').encode())


    @classmethod
    def tearDownClass(cls):
        after = entry._source_snapshot()
        write(cls.out / 'source_after.json', after)
        if after != cls.before:
            raise AssertionError('R10R_REPORT_SOURCE_DRIFT')

    def run_branch(self, branch):
        output = self.out / (branch + '.fixture.json')
        command = [str(GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10r_report_fixture.gd', '--', str(self.fixtures), str(output)]
        environment = dict(os.environ, SPORE_R10R_FIXTURE_DECLARATION=str(self.out / 'synthetic-declaration.json'))
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
            seconds=round(time.monotonic()-started, 3), world_build_count=0, solver_step_count=0))
        error = (self.out / (branch + '.stderr.log')).read_text(encoding='utf-8')
        self.assertNotIn('ERROR:', error)
        self.assertEqual(0, process.returncode, error + (self.out / (branch + '.stdout.log')).read_text(encoding='utf-8')[-4000:])
        fixture = entry.read(output)
        self.assertTrue(fixture['ok'], fixture['failure'])
        results = {}
        for label in ('active',):
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
            self.assertEqual(self.declaration['r10r_development'], report['r10r_development'])
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
                self.assertEqual(branch == 'upright', measured['predicates']['recovery_completed'])
                if branch == 'upright':
                    crossed = copy.deepcopy(report)
                    source = crossed['stance_entry']['readiness_rows'][0]['source']
                    source['readiness']['ready'] = not source['readiness']['ready']
                    refused = self.out / 'upright-crossed-readiness'
                    refused.mkdir()
                    write(refused / 'worker_report.json', crossed)
                    with self.assertRaises(ValueError):
                        entry.run_replay(refused / 'worker_report.json')
            results[label] = observed
        write(self.out / (branch + '.results.json'), results)
        return fixture, results

    def test_complete_initial_single_upright_report(self):
        fixture, results = self.run_branch('upright')
        self.assertEqual((240, 63, 0, 0), tuple(results['active'][key] for key in
            ('entry_observation_count', 'upright_observation_count', 'partial_observation_count', 'canonical_initialization_count')))
        self.assertEqual(1, results['active']['stance_entry_replay']['recomputed_readiness_samples'])


if __name__ == '__main__':
    unittest.main()
