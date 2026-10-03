"""V18 host-frame handoff: retained diagnosis and actual zero-world interfaces."""
import copy
import hashlib
import json
import math
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

from development_recovery_candidate_test_support import selected, arguments, candidate, ROOT
import test_development_passive_entry_replay as shared

ATTEMPT = '5436af3ddcad48dda0f2450ce0a9dd7b'
REPORT_SHA = '2ec328e3dac08ff9457c485e49f8a1820756117f45967d7904cc8d444004b7f7'


class WalkingFrame(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.root = shared.entry.EVIDENCE / ('development-walking-frame-' + uuid.uuid4().hex)
        cls.root.mkdir()
        cls.report_path = shared.entry.EVIDENCE / ('development-recovery-smoke-' + ATTEMPT) / 'children/kick_passive_recovery_resume/worker_report.json'
        raw = cls.report_path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != REPORT_SHA:
            raise AssertionError('V17_REPORT_DRIFT')
        cls.report = shared.parse_json(raw.decode())
        packet = cls.report['passive_entry']['canonical_packets'][-1]
        if packet['global_semantic_step'] != 805:
            raise AssertionError('V17_STANDING_COMPLETION_SOURCE')
        observation = shared.parse_json(packet['collection_transport']['request']['utf8_text'])['observation']
        cls.q = observation['state']['base_pose_world']['orientation_xyzw']
        cls.fixture = cls.root / 'retained_frame_input.json'
        cls.fixture.write_text(json.dumps(dict(source_attempt=ATTEMPT, source_report_sha256='sha256:' + REPORT_SHA,
            native_quaternion_at_standing_completion=cls.q, source_step=805,
            original_observation_rewritten=False, physical_acceptance_authority=False), indent=2) + '\n', encoding='utf-8')
        print('DEVELOPMENT_WALKING_FRAME_TEST_ROOT', cls.root, flush=True)

    def test_retained_native_anatomy_exposes_quarter_turn_without_regrading(self):
        x, y, z, w = (self.q[k] for k in ('x', 'y', 'z', 'w'))
        anatomical = (1 - 2*(y*y + z*z), 2*(x*y + w*z), 2*(x*z - w*y))
        legacy = (-2*(x*z + w*y), -2*(y*z - w*x), -(1 - 2*(x*x + y*y)))
        session = self.report['retained_arm']['walking_sessions'][-1]
        start = session['start_receipt']
        observed = start['task_frame_forward_axis_world_host_real']
        self.assertLess(max(abs(a-b) for a, b in zip(legacy, observed)), 2e-6)
        cosine = sum(a*b for a, b in zip(anatomical, observed)) / math.sqrt(sum(a*a for a in anatomical)*sum(a*a for a in observed))
        angle = math.degrees(math.acos(max(-1., min(1., cosine))))
        self.assertAlmostEqual(90., angle, places=4)
        evaluation = session['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(-0.07224338988678158, evaluation['forward_advance_m'])
        self.assertEqual(93, evaluation['trace_row_count'])
        self.assertEqual({240}, set(start['initial_gait_steps'].values()))
        # No alternative projection of those 93 rows is assigned a pass/fail.
        diagnostic = dict(source_report_sha256='sha256:' + REPORT_SHA,
            native_anatomical_forward=anatomical, retained_task_forward=observed,
            angle_between_degrees=angle, original_walking_behavior_passed=False,
            retained_walking_steps=93, declared_gait_cycle_steps=360,
            original_observation_rewritten=False, original_evaluation_replaced=False,
            causal_attribution_proven=False, world_build_count=0, solver_step_count=0)
        (self.root / 'v17_frame_diagnosis.json').write_text(json.dumps(diagnostic, indent=2) + '\n', encoding='utf-8')
        print('V17_FRAME_DIAGNOSIS', json.dumps(diagnostic, separators=(',', ':')), flush=True)

    def test_actual_worker_adapter_evaluator_and_reader_boundaries(self):
        run = self._run_retained('res://tests/test_development_recovery_walking_frame.gd',
            ['--', *arguments(self.selection), str(self.fixture)], 'actual_frame_interfaces', 90)
        result = shared.marker(run, 'DEVELOPMENT_WALKING_FRAME_CHECKS ')
        self.assertTrue(result['ok'], result)
        self.assertTrue(all(result['checks'].values()), result)
        for key in ('model_construction_count', 'world_build_count', 'solver_step_count'):
            self.assertEqual(0, result[key])
        self.assertFalse(result['physical_acceptance_authority'])

    def test_unknown_or_wrong_kind_frame_selection_fails_closed(self):
        schedule_path = candidate.schedule_path(self.selection['candidate']['diagnostic_schedule_id'])
        original = candidate.read(schedule_path)
        original_read = candidate.read
        for bad in (True, None, 18, 'unknown', {'id': 'anatomical_plus_x_horizontal_resume_v1'}):
            changed = copy.deepcopy(original)
            changed['schedules'][self.selection['candidate']['diagnostic_schedule_id']]['walking_resume_frame_id'] = bad
            with self.subTest(value=bad), patch.object(candidate, 'read', side_effect=lambda p: changed if p == schedule_path else original_read(p)):
                with self.assertRaisesRegex(ValueError, 'WALKING_FRAME_SELECTION'):
                    candidate.selection(self.selection['candidate_profile'])

    def test_historical_frame_runtime_and_selected_horizon_preserved(self):
        old = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v17-velocity-damped-stance-v1.json'))
        frame_only = candidate.selection(candidate.reference_for_path(ROOT / 'sdk/development/recovery_candidates/v18-anatomical-walking-frame-v1.json'))
        # V18 changed only the frame. Preserve that historical identity claim
        # without falsely requiring every later controller to use the V17 DLL.
        for key in ('post_kick_controller_id', 'runtime_binding', 'runtime_binding_sha256', 'runtime_sha256', 'extension', 'extension_sha256'):
            self.assertEqual(old['candidate'][key], frame_only['candidate'][key])
        expected_limits = candidate.limits(old)
        if self.selection['diagnostic_schedule'].get('walking_entry_profile_id'):
            warmup = candidate.read(ROOT / 'sdk/development/recovery_walking_entry_contract_v1.json')['warmup_steps']
            for key in ('after_interaction_steps', 'maximum_steps_per_child'):
                expected_limits[key] += warmup
        if self.selection['diagnostic_schedule'].get('walking_policy_id') in ('sporespore_balanced_wave_recovery_remaining_support_release_v1','sporespore_balanced_wave_recovery_startup_reference_velocity_v1', candidate.FINITE_ROUTE_ID, candidate.STANCE_ROUTE_ID, candidate.FLEXED_ROUTE_ID, candidate.HOLD_ROUTE_ID, candidate.R10K_ROUTE_ID, candidate.R10L_ROUTE_ID, candidate.R10M_ROUTE_ID, candidate.R10N_ROUTE_ID, candidate.R10O_ROUTE_ID):
            expected_limits['after_interaction_steps'] = 3160
            expected_limits['maximum_steps_per_child'] = 3512
        self.assertEqual(expected_limits, candidate.limits(self.selection))
        self.assertNotEqual(old['candidate_profile'], self.selection['candidate_profile'])
        self.assertNotIn('walking_resume_frame_id', old['diagnostic_schedule'])
        self.assertEqual('anatomical_plus_x_horizontal_resume_v1', self.selection['diagnostic_schedule']['walking_resume_frame_id'])
        for relative, digest in [
            ('sdk/development/recovery_attempts/' + ATTEMPT + '.json', '9f7af3f0b174571424bdf171bb0a7c947a3bbde626a94c6d8fc39ef13b4eea20'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f'),
        ]:
            self.assertEqual('sha256:' + digest, candidate.sha(ROOT / relative))


if __name__ == '__main__':
    unittest.main()
