"""Fresh R10N preparation and V54 native sessions on declared exposed inputs."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import unittest
import uuid

import test_development_r10n_complete_report as shared

ROOT = shared.ROOT
EVIDENCE = shared.EVIDENCE
REFUSALS = {
    'ramp_alias': 'DEVELOPMENT_JOINT_ENTRY_SESSION_CROSSED',
    'hold_alias': 'DEVELOPMENT_HOLD_ENTRY_SESSION_CROSSED',
    'ramp_shutdown': 'R10H_ENTRY_REPLAY_HOLD_AFTER_RAMP',
    'hold_shutdown': 'R10H_ENTRY_REPLAY_SESSION_NOT_FRESH',
    'walking_start': 'R10H_ENTRY_REPLAY_WALKING_STARTED_WITHOUT_READY_ENTRY',
    'hold_readiness': 'R10H_ENTRY_REPLAY_READINESS_RECOMPUTATION',
    'fresh_memory': 'DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    'motor_command': 'DEVELOPMENT_WALKING_ENTRY_READER_MOTOR_COMMAND_LINK',
}


def exposed_input():
    closure_path = ROOT / 'sdk/recovery/r10j_held_out_physical_closure_v1.json'
    closure = shared.entry.read(closure_path)
    binding = next(cell['report'] for cell in closure['cells']
                   if cell['seed'] == 50642 and cell['role'] == shared.development.ROLES[0])
    raw = Path(binding['path']).read_bytes()
    assert 'sha256:' + hashlib.sha256(raw).hexdigest() == binding['raw_sha256']
    report = json.loads(raw)
    arm = report['retained_arm']
    result = dict(schema_version='sporespore_r10n_synthetic_preparation_input_v1',
        source_report=binding, original_result_regraded=False,
        synthetic_counterfactual_only=True, model_instance_id=arm['model_instance_id'], segments=[],
        original_policy_report=dict(retained_arm=dict(walking_sessions=arm['walking_sessions'])))
    for session in arm['walking_sessions']:
        segment = session['evaluation_segment_id']
        if segment == 'walking_prefix':
            continue
        start = session['start_receipt']['global_start_step']
        count = 2 if segment == 'matched_continuation' else len(session['step_receipt_sha256s'])
        traces = arm['trace_rows'][start:start + count]
        samples, readiness, native_sources, post_sources = [], [], [], []
        if segment == 'matched_continuation':
            for row in report['development_walking_entry']['rows'][:count]:
                native = next(r for r in report['development_native_walking_contacts']['rows']
                              if r['segment_id'] == segment and r['session_local_step'] == row['session_local_step'])
                samples.append(dict(ok=True, failure_code='', request=row['request'],
                    development_floor_source=row['development_floor_source'],
                    stability_shadow=dict(stability_state=dict(semantic_step=row['session_local_step'],
                        adapter_capability_sha256=row['request']['state']['adapter_capability_sha256'],
                        ordered_body_states=row['ordered_body_states'], ordered_support_contacts=native['stability_contacts']))))
                native_sources.append(native['native_source'])
                post_sources.append(next(r['post_native_source'] for r in report['development_cycle_stop']['rows']
                                         if r['session_local_step'] == row['session_local_step']))
        else:
            controls = report['stance_entry']['hold_control_rows' if segment == 'v50_hold_stance_entry' else 'neutral_control_rows']
            samples = [r['step']['sample_receipt'] for r in controls]
            readiness = [r['source'] for r in report['stance_entry']['readiness_rows'] if start < r['global_semantic_step'] <= start + count]
        result['segments'].append(dict(id=segment, start=session['start_receipt'], samples=samples,
            initial_contact_by_limb={},
            traces=traces, readiness=readiness, native_sources=native_sources, post_sources=post_sources))
        # The initial contact population is an exposed measurement immediately
        # before the new session; it is not a reused physical control baseline.
        result['segments'][-1]['initial_contact_by_limb'] = arm['trace_rows'][start - 1]['contact_by_limb']
    return result


class R10NPreparationReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = Path(os.environ.get('SPORE_R10N_PREPARATION_ROOT', str(EVIDENCE / ('development-r10n-preparation-report-' + uuid.uuid4().hex))))
        cls.out.mkdir()
        print('R10N_PREPARATION_REPORT_EVIDENCE ' + str(cls.out), flush=True)
        cls.before = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_before.json', cls.before)
        cls.reference = shared.candidate.reference_for_path(shared.PROFILE)
        cls.declaration = shared.declaration(cls.reference, cls.before['head'])
        shared.write(cls.out / 'synthetic-declaration.json', cls.declaration)
        shared.development.validate_declaration(cls.declaration)
        shared.write(cls.out / 'input.json', exposed_input())
        command = [str(shared.GODOT), '--headless', '--path', str(ROOT), '--script',
            'res://tests/test_development_r10n_preparation_report.gd', '--',
            str(cls.out / 'input.json'), str(cls.out / 'fixture.json')]
        environment = dict(os.environ, SPORE_R10N_FIXTURE_DECLARATION=str(cls.out / 'synthetic-declaration.json'))
        started = time.monotonic()
        try:
            with (cls.out / 'stdout.log').open('xb') as stdout, (cls.out / 'stderr.log').open('xb') as stderr:
                process = subprocess.run(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                    timeout=300, creationflags=subprocess.CREATE_NO_WINDOW)
            shared.write(cls.out / 'execution.json', dict(command=command, exit_code=process.returncode,
                seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
            error = (cls.out / 'stderr.log').read_text(encoding='utf-8')
            if process.returncode != 0 or 'ERROR:' in error:
                raise AssertionError(error[-5000:] + (cls.out / 'stdout.log').read_text(encoding='utf-8')[-1200:])
            cls.fixture = shared.entry.read(cls.out / 'fixture.json')
            if not cls.fixture['ok']:
                raise AssertionError(cls.fixture['failure'])
            cls.directory = cls.out / 'report'
            cls.directory.mkdir()
            cls.report = cls.fixture['report']
            shared.write(cls.directory / 'worker_report.json', cls.report)
            cls.result = shared.entry.run_replay(cls.directory / 'worker_report.json')
            shared.write(cls.out / 'replay-result.json', cls.result)
        except subprocess.TimeoutExpired:
            shared.write(cls.out / 'execution.json', dict(command=command, timed_out=True,
                direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
            raise
        finally:
            after = shared.entry._source_snapshot()
            shared.write(cls.out / 'setup_source_after.json', after)
            if cls.before != after:
                raise AssertionError('R10N_PREPARATION_SOURCE_DRIFT')

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot()
        shared.write(cls.out / 'source_after.json', after)
        if cls.before != after:
            raise AssertionError('R10N_PREPARATION_SOURCE_DRIFT')

    def test_complete_native_preparation_retention_and_independent_replay(self):
        self.assertTrue(self.result['ok'] and self.result['complete_report_timeline_replayed'])
        self.assertTrue(self.fixture['original_policy_validation']['ok'])
        self.assertEqual(618, self.result['transition_count'])
        stance = self.result['stance_entry_replay']
        self.assertEqual((173, 171, 344), tuple(stance[k] for k in
            ['replayed_neutral_commands', 'replayed_hold_commands', 'recomputed_readiness_samples']))
        sessions = self.report['retained_arm']['walking_sessions']
        self.assertEqual(3, len(sessions))
        self.assertEqual(3, len({s['session_id'] for s in sessions}))
        self.assertEqual([173, 171, 2], [len(s['step_receipt_sha256s']) for s in sessions])
        for session in sessions:
            self.assertEqual(1, session['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'])
        self.assertTrue(self.report['synthetic_test_fixture'])
        self.assertFalse(self.report['finite_recovery_task']['cycle_and_stop_boundary_reached'])
        selection = shared.entry.selection_for_report(self.report)
        core = shared.LocomotionCore(shared.entry.binding(selection)['runtime']['path'])
        compiled = core.compile_bounded_quadruped(self.report['configuration']['base_descriptor'])
        measured = shared.finite.measure(self.report, compiled)
        shared.write(self.out / 'finite-task-measurement.json', measured)
        self.assertFalse(measured['finite_task_predicates_passed'])
        self.assertFalse(measured['predicates']['planned_cycles'])

    def test_cold_reader_refuses_crossed_preparation_and_walking_links(self):
        refusals = {}
        for name, expected_code in REFUSALS.items():
            report = copy.deepcopy(self.report)
            sessions = report['retained_arm']['walking_sessions']
            if name in ['ramp_alias', 'hold_alias']:
                sessions[0 if name == 'ramp_alias' else 1]['start_receipt']['development_walking_policy_id'] = (
                    'r10i_joint_pose_entry_v1' if name == 'ramp_alias' else 'r10j_v50_zero_amplitude_hold_v1')
            elif name in ['ramp_shutdown', 'hold_shutdown']:
                sessions[0 if name == 'ramp_shutdown' else 1]['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] = 0
            elif name == 'walking_start':
                sessions[2]['start_receipt']['global_start_step'] += 1
            elif name == 'hold_readiness':
                report['stance_entry']['readiness_rows'][-1]['source']['readiness']['ready'] = False
            elif name == 'fresh_memory':
                report['development_walking_entry']['rows'][0]['request']['memory']['ordered_limb_memory'][0]['gait_step'] += 1
            else:
                report['development_walking_entry']['rows'][0]['ordered_motor_applications'][0]['host_applied_target_velocity_rad_s'] += .1
            directory = self.out / name
            directory.mkdir()
            shared.write(directory / 'worker_report.json', report)
            with self.assertRaises(ValueError) as caught:
                shared.entry.run_replay(directory / 'worker_report.json')
            replay = directory / 'passive_entry_replay'
            execution = shared.entry.read(replay / 'execution.json')
            self.assertEqual((1, False), (execution['returncode'], execution['timed_out']))
            self.assertNotIn('ERROR:', (replay / 'stderr.txt').read_text(encoding='utf-8'))
            markers = [json.loads(line.split(' ', 1)[1]) for line in
                       (replay / 'stdout.txt').read_text(encoding='utf-8').splitlines()
                       if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
            self.assertEqual(1, len(markers))
            self.assertEqual((False, expected_code), (markers[0]['ok'], markers[0]['failure_code']))
            refusals[name] = dict(wrapper_error=str(caught.exception), failure_code=expected_code)
        shared.write(self.out / 'refusals.json', refusals)


if __name__ == '__main__':
    unittest.main()
