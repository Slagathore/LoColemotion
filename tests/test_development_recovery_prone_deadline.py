"""Finite observation cutoff, real worker stop hook and retained-data diagnosis."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'tests'))
import development_recovery_smoke as reader
import development_step_cost_profile as profile
import qsdk_r10f_l14_runtime_binding as runtime
from test_development_recovery_smoke import native
import test_development_recovery_smoke_reader as header_fixture


class ProneDeadline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        runtime.bind_runtime(Path(runtime.IMAGES['godot_console']['path']))
        run = native('tests/test_development_recovery_prone_deadline.gd', timeout=30)
        sys.stdout.buffer.write(run.stdout)
        sys.stdout.buffer.flush()
        prefix = 'DEVELOPMENT_PRONE_DEADLINE '
        rows = [json.loads(line[len(prefix):]) for line in run.stdout.decode().splitlines()
                if line.startswith(prefix)]
        if run.returncode or run.stderr or b'ERROR:' in run.stdout or len(rows) != 1:
            raise AssertionError((run.returncode, run.stdout[-3000:], run.stderr))
        cls.gate = rows[0]

    def declaration(self):
        result = copy.deepcopy(self.gate['declaration_schedule'])
        result.update(context_cache_profile_id=profile.CACHE_PROFILE_ID,
                      context_cache_call_sites=profile.CACHE_CALL_SITES,
                      worker_resource=profile.CACHE_WORKER_RESOURCE,
                      step_cost_profile_id=profile.PROFILE_ID)
        return result

    def test_actual_worker_configuration_stop_hook_and_terminal_branch(self):
        self.assertIs(self.gate['ok'], True)
        self.assertGreaterEqual(len(self.gate['checks']), 45)
        for key in ('default_30_still_reproduces_original_failure',
                    'actual_finish_propagates_declared_60_to_evaluator',
                    'declared_60_refuses_missing_row', 'declared_60_refuses_bad_shutdown_type',
                    'incomplete_shutdown_remains_explicit_negative_receipt'):
            self.assertIs(self.gate['checks'][key], True)
        self.assertTrue(all(value is True for value in self.gate['checks'].values()))
        for key in ('world_build_count', 'solver_step_count', 'native_physics_read_count'):
            self.assertEqual(0, self.gate[key])

    def test_reader_matches_actual_native_schedule_and_rejects_crossed_report(self):
        report, descriptor, declaration = header_fixture.SmokeReader().fixture()
        declaration.update(self.declaration())
        schedule = reader.declared_schedule(declaration)
        self.assertEqual(60, schedule['after_interaction_steps'])
        report.update(maximum_solver_step_count=412, solver_step_count=332,
                      global_solver_frame_count=332, after_interaction_step_count=60)
        reader.validate_header(report, descriptor, declaration, 123)
        for key, value in [('maximum_solver_step_count', 382), ('solver_step_count', 413),
                           ('after_interaction_step_count', 61), ('complete_route_proven', True)]:
            bad = copy.deepcopy(report)
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                reader.validate_header(bad, descriptor, declaration, 123)

    def test_schedule_refuses_missing_changed_noninteger_and_unbound_values(self):
        good = self.declaration()
        for key in good:
            for value in (None, True, 'wrong', 60.5):
                bad = copy.deepcopy(good)
                bad[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    reader.declared_schedule(bad)
            bad = copy.deepcopy(good)
            bad.pop(key)
            with self.subTest(missing=key), self.assertRaises(ValueError):
                reader.declared_schedule(bad)

    def test_actual_cli_refuses_deadline_without_selected_worker(self):
        run = subprocess.run(['C:/Program Files/PowerShell/7/pwsh.exe', '-NoProfile', '-NonInteractive',
                              '-File', 'sdk/run_development_recovery_smoke.ps1', '-ObserveProneDeadline'],
                             cwd=ROOT, capture_output=True, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
        self.assertNotEqual(0, run.returncode)
        self.assertIn(b'SMOKE_PRONE_DEADLINE_REQUIRES_CONTEXT_CACHE', run.stderr)

    def test_retained_short_trace_identifies_unmet_entry_not_a_deadline_result(self):
        failure = reader.read(ROOT / 'sdk/development_recovery_prone_deadline_initial_failure_v1.json')
        reader.validate_checkpoint(failure, reader.retained_prone_deadline_failure(Path(failure['evidence_root'])))
        checkpoint = reader.read(ROOT / 'sdk/development_recovery_context_cache_checkpoint_v1.json')
        root = Path(checkpoint['evidence_root'])
        reader.validate_checkpoint(checkpoint, reader.retained_checkpoint(root))
        report = reader.read(root / 'children/kick_passive_recovery_resume/worker_report.json')
        arm = report['retained_arm']
        capture = json.loads(report['l15_prepared_context_comparison']['observed_capture']['utf8_text'])
        context = json.loads(capture['source_context']['utf8_text'])
        height_scale = context['compiled_recovery_morphology']['geometry']['initial_torso_center_y_m']
        rows = [row for row in arm['trace_rows'] if row['orchestrator_phase'] ==
                'kick_triggered_zero_actuation_passive_fall']
        self.assertEqual(30, len(rows))
        for row in rows:
            value = row['recovery_classification']
            self.assertEqual(row['torso_position_world_m'][1] / height_scale, value['torso_height_ratio'])
            self.assertGreater(value['torso_height_ratio'], 0.25)
            self.assertLessEqual(value['torso_up_dot'], 1.0)
            self.assertIs(value['torso_ventral_contact'], False)
            self.assertIs(value['entry_prone_gate'], False)
        self.assertEqual(list(range(24, 31)), [row['recovery_epoch_local_step'] for row in rows
                         if not row['recovery_classification']['joint_limits_respected']])
        self.assertEqual(30, arm['orchestrator_state']['confirm_prone_step_count'])
        self.assertEqual('', arm['orchestrator_state']['terminal_reason'])
        # Use original compiled response bytes, not its lossy legacy decoded view.
        response = json.loads(arm['last_recovery_collection_transport_retention']['response']['utf8_text'])
        joints = response['value']['observation']['state']['ordered_joint_observations']
        specs = context['compiled_recovery_morphology']['morphology']['morphology_spec']['joints']
        self.assertEqual([joint['joint_id'] for joint in joints], [spec['joint_id'] for spec in specs])
        violations = [joint['joint_id'] for joint, spec in zip(joints, specs)
                      if not spec['lower_limit_rad'] <= joint['position_rad'] <= spec['upper_limit_rad']]
        self.assertEqual(['front_left_knee', 'rear_right_knee'], violations)


if __name__ == '__main__':
    unittest.main()
