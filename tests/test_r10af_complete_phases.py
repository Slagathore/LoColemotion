"""Synthetic R10AF upright, hold and fresh-walking reports; no physics result."""
import copy
import json
import os
from pathlib import Path
import unittest
import uuid

import test_r10af_complete_report as shared
import test_development_r10v_preparation_report as preparation
import r10r_native_component as fixtures_native
import r10af_finite_task_audit as finite


class R10AFCompletePhases(unittest.TestCase):
    native = shared.R10AFCompleteReport.native

    @classmethod
    def setUpClass(cls):
        cls.root = shared.identity.EVIDENCE / ('r10af-complete-phases-' + uuid.uuid4().hex)
        cls.root.mkdir(); print('R10AF_COMPLETE_PHASES_ROOT ' + str(cls.root), flush=True)
        cls.before = shared.entry._source_snapshot(); shared.write(cls.root / 'source-before.json', cls.before)
        cls.chosen = shared.candidate.selection(shared.identity.reference()); cls.declaration = shared.declaration_fixture.fixture(cls.before['head'])
        cls.declaration['source_snapshot']['head'] = cls.before['head']
        cls.declaration['r10af_development'] = shared.identity.context(shared.identity.SINGLE, cls.before['head'], shared.identity.reference())
        cls.declaration['runtime'] = shared.host.expected_binding()
        shared.identity.validate_declaration(cls.declaration)
        shared.write(cls.root / 'synthetic-declaration.json', cls.declaration)
        shared.host.bind_runtime(shared.host.expected_binding()['images']['godot_console']['path'],
            shared.host.expected_binding()['images']['powershell_host']['path'])
        cls.frames=cls.root/'frame-fixtures.json'
        from types import SimpleNamespace
        result=cls.native(SimpleNamespace(out=cls.root),'frames','res://tests/test_r10af_contact_report_fixture.gd',
            [cls.root/'synthetic-declaration.json',cls.frames],timeout=60)
        assert result.returncode==0 and result.stderr==b'',result.stdout[-3000:]+result.stderr
        exposed = preparation.exposed_input()
        hold = next(s for s in exposed['segments'] if s['id'] == 'v50_hold_stance_entry')
        walking = copy.deepcopy(next(s for s in exposed['segments'] if s['id'] == 'matched_continuation'))
        walking['id'] = 'walking_resume'
        cls.supplied = dict(source_report=exposed['source_report'], original_result_regraded=False,
            synthetic_counterfactual_only=True, physical_values_are_supplied_not_simulated=True,
            segment=dict(id='v50_post_recovery_settling', start=hold['start'],
                initial_contact_by_limb=hold['traces'][-1]['contact_by_limb']),
            sample=hold['samples'][-1], trace=hold['traces'][-1], readiness=hold['readiness'][-1], walking_segment=walking)
        read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))
        runtime = read(shared.ROOT / 'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')
        old = read(fixtures_native.Q_BINDING)
        sources = [old['compiled_fixtures'], runtime['compiled_fixtures']]
        from r10ac_support_loss_diagnosis import binding
        for source in sources:
            actual = binding(source['path'])
            assert (actual['raw_sha256'], actual['byte_length']) == (source['raw_sha256'], source['byte_length'])
        shared.write(cls.root / 'fixture-sources.json', sources)
        fixtures = [fixtures_native.fixtures(sources[0]['path'], 'R10Q_UPRIGHT_FIXTURE')[0],
            *fixtures_native.fixtures(sources[1]['path'], 'R10R_UPRIGHT_FIXTURE')]
        cls.fixtures = cls.root / 'source-fixtures.jsonl'
        with cls.fixtures.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(''.join('R10V_SOURCE_FIXTURE ' + json.dumps(f) + '\n' for f in fixtures))

    @classmethod
    def tearDownClass(cls):
        after = shared.entry._source_snapshot(); shared.write(cls.root / 'source-after.json', after)
        assert cls.before == after, 'R10AF_PHASE_SOURCE_DRIFT'

    def run_case(self, branch):
        self.out = self.root / branch; self.out.mkdir()
        shared.write(self.out / 'input.json', dict(self.supplied, timeout=branch == 'timeout'))
        env = dict(os.environ, SPORE_R10AF_FIXTURE_DECLARATION=str(self.root / 'synthetic-declaration.json'),
            SPORE_R10AF_FRAME_FIXTURES=str(self.frames), SPORE_R10AF_PHASE_BRANCH=branch,
            SPORE_R10AB_HOLD_REPORT_INPUT=str(self.out / 'input.json'))
        native = self.native('fixture', 'res://tests/test_r10af_complete_phase_fixture.gd',
            [self.fixtures, self.out / 'fixture.json'], env, timeout=420)
        self.assertEqual(b'', native.stderr)
        self.assertEqual(0, native.returncode, native.stdout[-4000:].decode())
        fixed = json.loads((self.out / 'fixture.json').read_text(encoding='utf-8'))
        self.assertIs(fixed['ok'], True); self.assertTrue(all(fixed['checks'].values()))
        self.assertIs(fixed['synthetic_measurements_only'], True)
        self.assertEqual((0, 0), (fixed['world_build_count'], fixed['solver_step_count']))
        report = fixed['active']['report']; shared.identity.validate_report_header(report, self.declaration)
        path = self.out / 'worker_report.json'; shared.write(path, report)
        receipt = self.cold('replay', path, 0)
        expected = shared.replay_host.independent_result(report, self.root / 'synthetic-declaration.json', receipt)
        count = dict(upright=575, ready=605, timeout=815, walking=607)[branch]
        self.assertEqual(count, receipt['transition_count'])
        self.assertEqual(count, expected['diagnostic_steps_replayed'])
        self.assertEqual((240, 63, 0), tuple(receipt[k] for k in
            ('entry_observation_count', 'upright_observation_count', 'partial_observation_count')))
        self.assertEqual(dict(upright=0, ready=30, timeout=240, walking=30)[branch],
            receipt['stance_entry_replay']['replayed_post_recovery_hold_commands'])
        self.assertIs(receipt['controller_and_diagnostic_replay_passed'], True)
        self.assertFalse(receipt['finite_recovery_task']['cycle_and_stop_boundary_reached'])
        self.assertFalse(receipt['physical_acceptance_authority']); self.assertFalse(receipt['release_authority'])
        if branch in ('ready', 'timeout', 'walking'):
            self.assertEqual('timeout' if branch == 'timeout' else 'ready',
                report['retained_arm']['orchestrator_state']['post_recovery_settling']['outcome'])
        shared.write(self.out / 'complete-replay.json', receipt)
        shared.write(self.out / 'independent-contact-replay.json', expected)
        return report, receipt

    def cold(self, label, path, code):
        run = self.native(label, self.chosen['reader'], [path, shared.identity.reference()['resource'],
            shared.identity.PROFILE_SHA, self.root / 'synthetic-declaration.json'], timeout=240)
        self.assertEqual(b'', run.stderr); self.assertEqual(code, run.returncode, run.stdout[-3000:].decode())
        marker = self.chosen['replay_marker']
        rows = [json.loads(line[len(marker):]) for line in run.stdout.decode().splitlines() if line.startswith(marker)]
        self.assertEqual(1, len(rows)); self.assertIs(rows[0]['ok'], code == 0)
        return rows[0]

    def test_direct_upright(self): self.run_case('upright')

    def test_ready_hold(self): self.run_case('ready')

    def test_timeout_hold(self): self.run_case('timeout')

    def test_fresh_walking_and_crossed_reports(self):
        report, receipt = self.run_case('walking')
        self.assertEqual(2, receipt['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(2, receipt['walking_contact_validation']['validated_native_contact_steps'])
        sessions = report['retained_arm']['walking_sessions']
        self.assertEqual(['v50_post_recovery_settling', 'walking_resume'], [s['evaluation_segment_id'] for s in sessions])
        self.assertEqual([30, 2], [len(s['step_receipt_sha256s']) for s in sessions])
        self.assertEqual(2, len({s['session_id'] for s in sessions}))
        for session in sessions:
            self.assertEqual(1, session['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'])
        from sporespore_locomotion import LocomotionCore
        compiled = LocomotionCore(shared.entry.binding(self.chosen)['runtime']['path']).compile_bounded_quadruped(report['configuration']['base_descriptor'])
        measured = finite.measure(report, compiled); shared.write(self.out / 'finite-task.json', measured)
        self.assertFalse(measured['finite_task_predicates_passed'])
        self.assertFalse(measured['predicates']['declared_entry_kind'])
        self.assertFalse(measured['predicates']['planned_cycles'])
        errors = dict(shutdown='R10AB_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
            memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY', capture='R10AF_CONTACT_REPORT_RECORD_POPULATION')
        for label, error in errors.items():
            changed = copy.deepcopy(report)
            if label == 'shutdown': changed['retained_arm']['walking_sessions'][0]['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] = 0
            elif label == 'memory': changed['development_walking_entry']['rows'][0]['request']['memory']['ordered_limb_memory'][0]['gait_step'] += 1
            else: changed['r10af_contact_frames']['records'].pop()
            path = self.out / (label + '.json'); shared.write(path, changed)
            self.assertEqual(error, self.cold(label, path, 1)['failure_code'])


if __name__ == '__main__': unittest.main()
