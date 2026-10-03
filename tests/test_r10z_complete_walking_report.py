"""Fresh native walking after synthetic kicked recovery and a ready hold.

Two walking commands cover session/retention interfaces, not planned cycles,
the full walking horizon, a matched comparison, or physical behavior.
"""
import copy
import json
import os
import subprocess
import time
import unittest
import uuid

import test_development_r10z_complete_report as shared
import test_development_r10v_preparation_report as preparation
import r10r_native_component as fixtures_native
import r10z_finite_task_audit as finite
from sporespore_locomotion import LocomotionCore


class R10ZCompleteWalkingReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = shared.native.EVIDENCE / ('r10z-complete-walking-report-' + uuid.uuid4().hex)
        cls.out.mkdir()
        print('R10Z_COMPLETE_WALKING_REPORT_ROOT ' + str(cls.out), flush=True)
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        try:
            shared.native.runtime()
            cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
            cls.declared = shared.declaration(cls.reference, cls.before['head'])
            shared.development.validate_declaration(cls.declared)
            shared.entry.validate_declaration(cls.declared)
            shared.write(cls.out / 'declaration.json', cls.declared)
            exposed = preparation.exposed_input()
            hold = next(s for s in exposed['segments'] if s['id'] == 'v50_hold_stance_entry')
            walking = copy.deepcopy(next(s for s in exposed['segments'] if s['id'] == 'matched_continuation'))
            walking['id'] = 'walking_resume'
            supplied = dict(source_report=exposed['source_report'], original_result_regraded=False,
                synthetic_counterfactual_only=True, physical_values_are_supplied_not_simulated=True, timeout=False,
                segment=dict(id='v50_post_recovery_settling', start=hold['start'],
                    initial_contact_by_limb=hold['traces'][-1]['contact_by_limb']),
                sample=hold['samples'][-1], trace=hold['traces'][-1], readiness=hold['readiness'][-1], walking_segment=walking)
            shared.write(cls.out / 'input.json', supplied)
            runtime = shared.native.read(shared.ROOT / 'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')
            old = shared.native.read(fixtures_native.Q_BINDING)
            sources = [old['compiled_fixtures'], runtime['compiled_fixtures']]
            for source in sources: shared.native.verify(source)
            shared.write(cls.out / 'fixture-sources.json', sources)
            fixtures = [fixtures_native.fixtures(sources[0]['path'], 'R10Q_UPRIGHT_FIXTURE')[0],
                        *fixtures_native.fixtures(sources[1]['path'], 'R10R_UPRIGHT_FIXTURE')]
            path = cls.out / 'source-fixtures.jsonl'
            path.write_text(''.join('R10V_SOURCE_FIXTURE '+json.dumps(f)+'\n' for f in fixtures), encoding='utf-8', newline='\n')
            command = [str(shared.GODOT), '--headless', '--path', str(shared.ROOT), '--script',
                'res://tests/test_r10z_complete_walking_report.gd', '--', str(path), str(cls.out / 'fixture.json')]
            environment = dict(os.environ, SPORE_R10Z_FIXTURE_DECLARATION=str(cls.out / 'declaration.json'),
                SPORE_R10Z_HOLD_REPORT_INPUT=str(cls.out / 'input.json'))
            started = time.monotonic()
            with (cls.out / 'stdout.log').open('xb') as stdout, (cls.out / 'stderr.log').open('xb') as stderr:
                try:
                    process = subprocess.run(command, cwd=shared.ROOT, env=environment, stdout=stdout, stderr=stderr,
                        timeout=420, creationflags=subprocess.CREATE_NO_WINDOW)
                except subprocess.TimeoutExpired:
                    shared.write(cls.out / 'execution.json', dict(command=command, timed_out=True,
                        direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
                    raise
            shared.write(cls.out / 'execution.json', dict(command=command, exit_code=process.returncode,
                seconds=round(time.monotonic()-started, 3), world_build_count=0, solver_step_count=0))
            error = (cls.out / 'stderr.log').read_text(encoding='utf-8')
            assert error == '', error
            fixture = shared.entry.read(cls.out / 'fixture.json')
            assert fixture['ok'], dict(failure=fixture['failure'], checks={k:v for k,v in fixture['checks'].items() if v is not True})
            assert process.returncode == 0
            cls.report = fixture['active']['report']
            cls.directory = cls.out / 'walking'
            cls.directory.mkdir()
            shared.write(cls.directory / 'worker_report.json', cls.report)
            cls.replay = shared.entry.run_replay(cls.directory / 'worker_report.json')
            shared.write(cls.directory / 'result.json', cls.replay)
        finally:
            after = shared.entry._source_snapshot()
            shared.write(cls.out / 'setup_source_after.json', after)
            assert after == cls.before, 'R10Z_WALKING_REPORT_SETUP_SOURCE_DRIFT'

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        assert after == cls.before, 'R10Z_WALKING_REPORT_SOURCE_DRIFT'

    def test_complete_kicked_hold_and_fresh_walking_report(self):
        self.assertTrue(self.replay['ok'] and self.replay['complete_report_timeline_replayed'])
        self.assertEqual(607, self.replay['transition_count'])
        self.assertEqual(30, self.replay['stance_entry_replay']['replayed_post_recovery_hold_commands'])
        self.assertEqual(2, self.replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(2, self.replay['walking_contact_validation']['validated_native_contact_steps'])
        sessions = self.report['retained_arm']['walking_sessions']
        self.assertEqual(['v50_post_recovery_settling', 'walking_resume'], [s['evaluation_segment_id'] for s in sessions])
        self.assertEqual([30, 2], [len(s['step_receipt_sha256s']) for s in sessions])
        self.assertEqual(2, len({s['session_id'] for s in sessions}))
        for session in sessions:
            self.assertEqual(1, session['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'])
        self.assertFalse(self.replay['finite_recovery_task']['cycle_and_stop_boundary_reached'])
        selected = shared.candidate.selection(self.reference)
        compiled = LocomotionCore(shared.entry.binding(selected)['runtime']['path']).compile_bounded_quadruped(
            self.report['configuration']['base_descriptor'])
        measured = finite.measure(self.report, compiled)
        shared.write(self.out / 'finite-task.json', measured)
        self.assertFalse(measured['finite_task_predicates_passed'])
        self.assertFalse(measured['predicates']['declared_entry_kind'])
        self.assertFalse(measured['predicates']['planned_cycles'])

    def test_cold_reader_refuses_session_memory_and_motor_crosses(self):
        refusals = {}
        expected = dict(shutdown='R10Z_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
            memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY', motor='DEVELOPMENT_WALKING_ENTRY_READER_MOTOR_COMMAND_LINK')
        for variant in expected:
            report = copy.deepcopy(self.report)
            if variant == 'shutdown':
                report['retained_arm']['walking_sessions'][0]['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] = 0
            elif variant == 'memory':
                report['development_walking_entry']['rows'][0]['request']['memory']['ordered_limb_memory'][0]['gait_step'] += 1
            else:
                report['development_walking_entry']['rows'][0]['ordered_motor_applications'][0]['host_applied_target_velocity_rad_s'] += .1
            directory = self.out / variant
            directory.mkdir()
            shared.write(directory / 'worker_report.json', report)
            with self.assertRaises(ValueError):
                shared.entry.run_replay(directory / 'worker_report.json')
            execution = shared.entry.read(directory / 'passive_entry_replay/execution.json')
            self.assertEqual((1, False), (execution['returncode'], execution['timed_out']))
            lines = (directory / 'passive_entry_replay/stdout.txt').read_text(encoding='utf-8').splitlines()
            result = [json.loads(line.split(' ', 1)[1]) for line in lines if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')][0]
            self.assertEqual(expected[variant], result['failure_code'])
            refusals[variant] = result['failure_code']
        shared.write(self.out / 'refusals.json', refusals)


if __name__ == '__main__':
    unittest.main()
