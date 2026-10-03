"""R10Y upright, ready-hold and timeout reports on supplied synthetic poses.

The phase-248 development declaration is an interface fixture only. These
counterfactual branches do not characterize that phase or grant launch authority.
"""
import json
import os
import subprocess
import time
import unittest
import uuid

import test_development_r10y_complete_report as shared
import test_development_r10v_preparation_report as preparation
import r10r_native_component as prior_native


class R10YCompleteHoldReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = shared.native.EVIDENCE / ('r10y-complete-hold-report-' + uuid.uuid4().hex)
        cls.out.mkdir()
        print('R10Y_COMPLETE_HOLD_REPORT_ROOT ' + str(cls.out), flush=True)
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        shared.native.runtime()
        cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
        shared.candidate.selection(cls.reference)
        exposed = preparation.exposed_input()
        segment = next(s for s in exposed['segments'] if s['id'] == 'v50_hold_stance_entry')
        cls.hold = dict(source_report=exposed['source_report'], original_result_regraded=False,
            synthetic_counterfactual_only=True, physical_values_are_supplied_not_simulated=True,
            segment=dict(id='v50_post_recovery_settling', start=segment['start'],
                initial_contact_by_limb=segment['traces'][-1]['contact_by_limb']),
            sample=segment['samples'][-1], trace=segment['traces'][-1], readiness=segment['readiness'][-1])
        runtime = shared.native.read(shared.ROOT / 'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')
        old = shared.native.read(prior_native.Q_BINDING)
        sources = [old['compiled_fixtures'], runtime['compiled_fixtures']]
        for source in sources:
            shared.native.verify(source)
        shared.write(cls.out / 'fixture-sources.json', sources)
        fixtures = [prior_native.fixtures(sources[0]['path'], 'R10Q_UPRIGHT_FIXTURE')[0],
                    *prior_native.fixtures(sources[1]['path'], 'R10R_UPRIGHT_FIXTURE')]
        cls.fixtures = cls.out / 'source-fixtures.jsonl'
        cls.fixtures.write_text(''.join('R10V_SOURCE_FIXTURE ' + json.dumps(f) + '\n' for f in fixtures),
            encoding='utf-8', newline='\n')

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before, 'R10Y_HOLD_REPORT_SOURCE_DRIFT'

    def run_case(self, branch):
        directory = self.out / branch
        directory.mkdir()
        declared = shared.declaration(self.reference, self.before['head'])
        shared.development.validate_declaration(declared)
        shared.write(directory / 'declaration.json', declared)
        shared.write(directory / 'input.json', dict(self.hold, timeout=branch == 'timeout'))
        script = ('test_development_r10y_upright_report_fixture.gd' if branch == 'upright'
                  else 'test_r10y_complete_hold_report.gd')
        command = [str(shared.GODOT), '--headless', '--path', str(shared.ROOT), '--script',
            'res://tests/' + script, '--', str(self.fixtures), str(directory / 'fixture.json')]
        environment = dict(os.environ, SPORE_R10Y_FIXTURE_DECLARATION=str(directory / 'declaration.json'),
            SPORE_R10Y_HOLD_REPORT_INPUT=str(directory / 'input.json'))
        started = time.monotonic()
        with (directory / 'stdout.log').open('xb') as stdout, (directory / 'stderr.log').open('xb') as stderr:
            try:
                process = subprocess.run(command, cwd=shared.ROOT, env=environment, stdout=stdout, stderr=stderr,
                    timeout=420, creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                shared.write(directory / 'execution.json', dict(command=command, timed_out=True,
                    direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                raise
        shared.write(directory / 'execution.json', dict(command=command, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
        self.assertEqual('', (directory / 'stderr.log').read_text(encoding='utf-8'))
        fixture = shared.entry.read(directory / 'fixture.json')
        self.assertTrue(fixture['ok'], dict(failure=fixture['failure'],
            checks={k: v for k, v in fixture['checks'].items() if v is not True},
            active_failure=fixture['active'].get('failure_code')))
        self.assertEqual(0, process.returncode)
        self.assertEqual((0, 0), (fixture['world_build_count'], fixture['solver_step_count']))
        self.assertTrue(fixture['synthetic_measurements_only'])
        report = fixture['active']['report']
        shared.write(directory / 'worker_report.json', report)
        replay = shared.entry.run_replay(directory / 'worker_report.json')
        self.assertEqual(replay, shared.entry.consume_replay(directory / 'worker_report.json'))
        self.assertTrue(replay['ok'] and replay['complete_report_timeline_replayed'])
        self.assertEqual(0, replay['initial_global_semantic_step'])
        expected_hold = {'upright': 0, 'ready': 30, 'timeout': 240}[branch]
        self.assertEqual(575 + expected_hold, replay['transition_count'])
        self.assertEqual(report['solver_step_count'], replay['transition_count'])
        self.assertEqual((240, 63, 0), tuple(replay[k] for k in
            ('entry_observation_count', 'upright_observation_count', 'partial_observation_count')))
        self.assertEqual(expected_hold, replay['stance_entry_replay']['replayed_post_recovery_hold_commands'])
        self.assertEqual(1 + expected_hold, replay['stance_entry_replay']['recomputed_readiness_samples'])
        self.assertEqual(declared['r10y_development'], report['r10y_development'])
        self.assertFalse(replay['finite_recovery_task']['cycle_and_stop_boundary_reached'])
        self.assertEqual('walking_not_reached', replay['finite_walking_measurement']['status'])
        self.assertFalse(replay['physical_acceptance_authority'])
        self.assertFalse(replay['release_authority'])
        if expected_hold:
            settling = report['retained_arm']['orchestrator_state']['post_recovery_settling']
            self.assertEqual('timeout' if branch == 'timeout' else 'ready', settling['outcome'])
        shared.write(directory / 'replay.json', replay)

    def test_direct_upright_complete_report(self):
        self.run_case('upright')

    def test_ready_hold_complete_report(self):
        self.run_case('ready')

    def test_timeout_hold_complete_report(self):
        self.run_case('timeout')


if __name__ == '__main__':
    unittest.main()
