"""Source-bound coverage math and real schedule hooks; no physics execution."""
import hashlib
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

from development_recovery_candidate_test_support import selected, arguments, candidate, ROOT
import test_development_passive_entry_replay as shared
import development_recovery_candidate_checkpoint as closure


class CandidateSchedule(unittest.TestCase):
    _run_retained = classmethod(shared.PassiveEntryReplay._run_retained.__func__)

    @classmethod
    def setUpClass(cls):
        cls.selection = selected()
        cls.schedule = cls.selection['diagnostic_schedule']
        cls.root = shared.entry.EVIDENCE / ('development-candidate-schedule-' + uuid.uuid4().hex)
        cls.root.mkdir()
        print('CANDIDATE_SCHEDULE_TEST_ROOT', cls.root, flush=True)

    def test_coverage_math_uses_observed_stance_and_unchanged_timeout(self):
        basis = self.schedule['coverage_basis']
        old = candidate.read(ROOT / basis['source_attempt'])
        self.assertEqual(basis['source_report_sha256'], old['kicked_report']['raw_sha256'])
        stance = next(p for p in old['metrics']['phase_summary'] if p['phase'] == 'stance_dwell')
        self.assertEqual(basis['stance_steps_observed'], stance['sample_count'])
        rules = candidate.read(ROOT / basis['threshold_source'])['threshold_profile']['thresholds']
        values = {r['threshold_id']: r['value'] for r in rules}
        self.assertEqual(60, values['stance_dwell_steps'])
        self.assertEqual(basis['existing_stance_timeout_steps'], values['per_phase_timeout_steps']['stance_dwell'])
        bounds = candidate.limits(self.selection)
        warmup = 0
        if self.schedule.get('walking_entry_profile_id'):
            entry = candidate.read(ROOT / 'sdk/development/recovery_walking_entry_contract_v1.json')
            clocked = candidate.read(ROOT / 'sdk/development/recovery_clocked_walking_entry_contract_v1.json')
            self.assertIn(candidate.walking_entry_phase_family(self.schedule['walking_entry_profile_id']), (entry['profile_id'], clocked['profile_id']))
            warmup = entry['warmup_steps']
            self.assertEqual(360, warmup)
            if self.schedule['walking_entry_profile_id'] in tuple(candidate.read(p)['profile_id'] for p in (candidate.FIRST_SWING_ENTRY_PATH, candidate.JOINT_BOUNDED_ENTRY_PATH, candidate.CONTACT_GATED_ENTRY_PATH, candidate.ROTATED_ENTRY_PATH, candidate.SWING_END_ENTRY_PATH, candidate.SUPPORT_ENTRY_PATH, candidate.FLOOR_ENTRY_PATH, candidate.FEASIBLE_ENTRY_PATH, candidate.SMOOTH_ENTRY_PATH, candidate.REFERENCE_ENTRY_PATH, candidate.WAVE_ENTRY_PATH, candidate.AIRBORNE_ENTRY_PATH, candidate.ABSENT_ENTRY_PATH, candidate.UPRIGHT_ENTRY_PATH, candidate.STANCE_LATCH_ENTRY_PATH, candidate.PROGRESSION_ENTRY_PATH, candidate.POSTURE_ENTRY_PATH)):
                # Preserve the existing observation budget, not the old amplitude duration.
                self.assertEqual(warmup, basis['preserved_walking_observation_budget_steps'])
                self.assertEqual(72, candidate.read(candidate.FIRST_SWING_ENTRY_PATH)['warmup_steps'])
            else:
                self.assertEqual(warmup, basis['additional_walking_warmup_steps'])
        self.assertEqual(basis['original_tail_steps'] + basis['existing_stance_timeout_steps'] - stance['sample_count'] + basis['walking_probe_steps'] + warmup, bounds['after_interaction_steps'])
        self.assertEqual(626 + warmup, bounds['after_interaction_steps'])
        self.assertEqual(978 + warmup, bounds['maximum_steps_per_child'])
        old_profile = candidate.read(ROOT / 'sdk/development/recovery_candidates/v14-knee-fold-replant-v1.json')
        for key in ('post_kick_controller_id', 'runtime_binding', 'runtime_binding_sha256', 'runtime_sha256', 'extension', 'extension_sha256'):
            if (basis.get('new_controller_preserves_v14_recovery_motion') is True
                    or basis.get('new_controller_preserves_existing_limits_and_later_phase_commands') is True
                    or basis.get('new_controller_preserves_pre_stance_motion_and_limits') is True):
                self.assertNotEqual(old_profile[key], self.selection['candidate'][key])
            else:
                self.assertEqual(old_profile[key], self.selection['candidate'][key])

    def test_unknown_crossed_and_drifted_schedule_profiles_refuse(self):
        reference = self.selection['candidate_profile']
        path = candidate.resource_path(reference['resource'])
        original_read = candidate.read
        for key, value in [('diagnostic_schedule_id', 'unknown'), ('diagnostic_schedule_id', '../v14-stance-settling-v1'), ('diagnostic_schedule_sha256', 'sha256:' + '0'*64),
                           ('diagnostic_schedule_id', False), ('schema_version', 'sporespore_development_recovery_candidate_profile_v1')]:
            changed = dict(self.selection['candidate'], **{key: value})
            with self.subTest(key=key, value=value), patch.object(candidate, 'read', side_effect=lambda p: changed if p == path else original_read(p)):
                with self.assertRaises(ValueError):
                    candidate.selection(reference)

    def test_actual_godot_cutoff_retention_close_bound_and_legacy_refusal(self):
        run = self._run_retained('res://tests/test_development_recovery_candidate_schedule.gd',
                                ['--', *arguments(self.selection)], 'schedule_hooks', 60)
        result = shared.marker(run, 'CANDIDATE_SCHEDULE_CHECKS ')
        self.assertTrue(result['ok'], result)
        self.assertTrue(all(result['checks'].values()), result)
        self.assertEqual(candidate.limits(self.selection), result['limits'])
        self.assertEqual(0, result['world_build_count'])

    def test_original_records_and_r173_remain_exact(self):
        # V43's first full-gate attempt never reached physics. Its frozen test
        # omitted the new entry; do not reinterpret it as a controller failure.
        v43 = candidate.read(ROOT / 'sdk/development/recovery_attempts/491a30fb3dcd4e859d3850aa11664a3e.json')
        v43_root = Path(v43['evidence_root'])
        supervisor = candidate.read(v43_root / 'supervisor_result.json')
        self.assertEqual(v43['source_snapshot'], supervisor['source_snapshot'])
        self.assertEqual(v43['failure_code'], supervisor['failure_code'])
        self.assertEqual((81, 77, 4, 3), tuple(v43[k] for k in
            ('completed_test_count', 'passed_tests_in_preceding_stages',
             'failed_stage_completed_test_count', 'passed_tests_within_failed_stage')))
        self.assertFalse(supervisor['physical_attempt_started'])
        self.assertEqual([], supervisor['children'])
        self.assertEqual("KeyError: 'additional_walking_warmup_steps'", v43['original_exception'])
        self.assertIn(v43['original_exception'], (v43_root/'candidate_schedule.stderr.log').read_text())
        frozen = closure.prior.committed(v43['frozen_test']['path'], v43['frozen_test']['source_commit'])
        self.assertEqual(v43['frozen_test']['raw_sha256'], 'sha256:'+hashlib.sha256(frozen).hexdigest())
        self.assertNotIn(b'candidate.PROGRESSION_ENTRY_PATH', frozen)
        for population in v43['retained_populations']:
            directory = Path(population['root'])
            files = [dict(path=p.relative_to(directory).as_posix(), byte_length=p.stat().st_size,
                          raw_sha256=candidate.sha(p)) for p in sorted(directory.rglob('*')) if p.is_file()]
            self.assertEqual(population['files'], files)
            self.assertEqual(population['file_count'], len(files))
            self.assertEqual(population['byte_length'], sum(f['byte_length'] for f in files))
            self.assertEqual(population['inventory_sha256'], 'sha256:'+hashlib.sha256(
                json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest())
        v25 = candidate.read(ROOT / 'sdk/development/recovery_attempts/417a25fee80e4c618cd1a43252e7079c.json')
        v25_root = Path(v25['evidence_root'])
        fixture_root = Path(v25['failed_stage_source_population']['root'])
        self.assertEqual(v25, closure.observe_schedule_gate_failure(v25_root, fixture_root))
        self.assertEqual(['unchanged_or_explicit_successor'], v25['failed_checks'])
        self.assertEqual((77, 73, 4), tuple(v25[k] for k in ('completed_test_count',
            'passed_tests_in_preceding_stages', 'failed_stage_completed_test_count')))
        original_read = closure.smoke.read
        original_supervisor = original_read(v25_root / 'supervisor_result.json')
        for corruption in ({'physical_attempt_started': True}, {'children': [{}]}, {'ok': True}):
            changed = dict(original_supervisor, **corruption)
            with self.subTest(corruption=corruption), patch.object(closure.smoke, 'read',
                    side_effect=lambda p: changed if p == v25_root / 'supervisor_result.json' else original_read(p)):
                with self.assertRaisesRegex(ValueError, 'SCHEDULE_GATE_NO_PHYSICAL_CHILD'):
                    closure.observe_schedule_gate_failure(v25_root, fixture_root)
        stopped = candidate.read(ROOT / 'sdk/development/recovery_attempts/3be9fc86cdfb4d16b30f3617b49469ca.json')
        stopped_supervisor = candidate.read(Path(stopped['evidence_root']) / 'supervisor_result.json')
        self.assertEqual('SMOKE_SAFETY_GATE_FAILED:candidate_schedule', stopped_supervisor['failure_code'])
        self.assertEqual(stopped_supervisor['source_snapshot'], stopped['source_snapshot'])
        self.assertFalse(stopped_supervisor['ok'])
        self.assertFalse(stopped_supervisor['physical_attempt_started'])
        self.assertEqual([], stopped_supervisor['children'])
        self.assertEqual(77, stopped['completed_test_count'])
        for key in ('physical_attempt_started', 'complete_route_proven', 'successful_recovery_proven', 'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            self.assertIs(stopped[key], False)
        for key in ('world_build_count', 'solver_step_count'):
            self.assertEqual(0, stopped[key])
        for population in (stopped['retained_population'], stopped['failed_stage_source_population']):
            population_root = Path(population['root'])
            files = [dict(path=p.relative_to(population_root).as_posix(), byte_length=p.stat().st_size, raw_sha256=candidate.sha(p))
                     for p in sorted(population_root.rglob('*')) if p.is_file()]
            self.assertEqual(population['files'], files)
            self.assertEqual(population['file_count'], len(files))
            self.assertEqual(population['byte_length'], sum(f['byte_length'] for f in files))
            self.assertEqual(population['inventory_sha256'], 'sha256:' + hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest())
        old = candidate.read(ROOT / self.schedule['coverage_basis']['source_attempt'])
        observed = closure.observe(Path(old['evidence_root']), distal_body_origins=True)
        closure.smoke.validate_checkpoint(old, observed)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
                         candidate.sha(ROOT / 'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        failed = candidate.read(ROOT / 'sdk/development/recovery_attempts/f870f80d6bf94943b310549d5b2624e2.json')
        root = Path(failed['evidence_root'])
        result = candidate.read(root / 'supervisor_result.json')
        self.assertFalse(result['ok'])
        self.assertFalse(result['physical_attempt_started'])
        self.assertEqual([], result['children'])
        self.assertEqual(failed['source_snapshot'], result['source_snapshot'])
        self.assertEqual(failed['failure_code'], result['failure_code'])
        self.assertEqual(32, len(failed['retained_files']))
        for item in failed['retained_files']:
            path = root / item['path']
            self.assertEqual(item['byte_length'], path.stat().st_size)
            self.assertEqual(item['raw_sha256'], candidate.sha(path))
        population = failed['reader_fixture_population']
        fixture_root = Path(population['root'])
        files = [dict(path=p.relative_to(fixture_root).as_posix(), byte_length=p.stat().st_size,
                      raw_sha256=candidate.sha(p)) for p in sorted(fixture_root.rglob('*')) if p.is_file()]
        raw = json.dumps(files, sort_keys=True, separators=(',', ':')).encode()
        self.assertEqual(population['file_count'], len(files))
        self.assertEqual(population['byte_length'], sum(p['byte_length'] for p in files))
        self.assertEqual(population['inventory_sha256'], 'sha256:' + hashlib.sha256(raw).hexdigest())
        invalid = candidate.read(ROOT / 'sdk/development/recovery_attempts/4337cdb9c34d4661881a56b6a20175e7.json')
        invalid_root = Path(invalid['evidence_root'])
        supervisor = candidate.read(invalid_root / 'supervisor_result.json')
        report = candidate.read(invalid_root / 'children/kick_passive_recovery_resume/worker_report.json')
        envelope = candidate.read(invalid_root / 'children/kick_passive_recovery_resume/child_envelope.json')
        self.assertEqual(invalid['source_snapshot'], supervisor['source_snapshot'])
        self.assertFalse(supervisor['ok'])
        self.assertTrue(supervisor['physical_attempt_started'])
        self.assertIsNone(supervisor['independent_audit'])
        self.assertEqual(77, sum(s['test_count'] for s in supervisor['safety_stages']))
        self.assertTrue(all(s['passed'] for s in supervisor['safety_stages']))
        self.assertEqual(invalid['failure_code'], supervisor['failure_code'])
        self.assertEqual(invalid['evaluator_failure_code'], report['detail']['retained_failure']['evaluator_failure_code'])
        self.assertEqual([1, 271, 0], [report[k] for k in ('world_build_count', 'solver_step_count', 'external_kick_application_count')])
        self.assertEqual(30, report['partial_arm']['active_walking_session']['scheduled_step_count'])
        self.assertTrue(report['detail']['retained_failure']['trace_slice_valid'])
        self.assertTrue(report['detail']['retained_failure']['completion_receipt']['adapter_shutdown_receipt']['explicit_shutdown_completed'])
        for key in ('termination_protocol_valid', 'engine_health_passed', 'raw_marker_valid'):
            self.assertIs(True, envelope[key])
            self.assertEqual(invalid[key], envelope[key])
        for key in ('complete_route_proven', 'successful_recovery_proven', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(False, invalid[key])
        self.assertEqual(invalid['retained_file_count'], len(invalid['retained_files']))
        self.assertEqual(invalid['retained_byte_length'], sum(f['byte_length'] for f in invalid['retained_files']))
        self.assertEqual({f['path'] for f in invalid['retained_files']},
                         {p.relative_to(invalid_root).as_posix() for p in invalid_root.rglob('*') if p.is_file()})
        for item in invalid['retained_files']:
            path = invalid_root / item['path']
            self.assertEqual(item['byte_length'], path.stat().st_size)
            self.assertEqual(item['raw_sha256'], candidate.sha(path))


if __name__ == '__main__':
    unittest.main()
