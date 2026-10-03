"""Cold retained-data/Git-object checks: no engine process, physics, or evidence writes."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_smoke as reader


class RetainedSmokeCheckpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = reader.read(ROOT / 'sdk/development_recovery_smoke_retained_checkpoint_v1.json')
        cls.evidence = Path(cls.record['evidence_root'])
        cls.observed = reader.retained_checkpoint(cls.evidence)

    def test_actual_whole_retained_population_and_exact_publication(self):
        reader.validate_checkpoint(self.record, self.observed)
        self.assertEqual(30, self.observed['retained_population']['file_count'])
        self.assertEqual(604, self.observed['observed']['total_solver_steps'])

    def test_initial_prone_deadline_failure_remains_consumed_and_unpromoted(self):
        record = reader.read(ROOT / 'sdk/development_recovery_prone_deadline_initial_failure_v1.json')
        observed = reader.retained_prone_deadline_failure(Path(record['evidence_root']))
        reader.validate_checkpoint(record, observed)
        self.assertEqual(332, observed['solver_steps'])
        self.assertIs(observed['kick_child_started'], False)
        for key in ('complete_route_proven', 'physical_acceptance_authority', 'release_authority',
                    'repeat_consumed_attempt_permitted'):
            changed = copy.deepcopy(record)
            changed[key] = True
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                reader.validate_checkpoint(changed, observed)

    def test_measured_entry_runtime_failure_remains_invalid_despite_worker_ok(self):
        record = reader.read(ROOT / 'sdk/development_measured_entry_runtime_failure_v1.json')
        observed = reader.retained_measured_entry_runtime_failure(Path(record['evidence_root']))
        reader.validate_checkpoint(record, observed)
        self.assertEqual(752, observed['solver_steps'])
        self.assertEqual(36, observed['retained_population']['file_count'])
        self.assertIs(observed['worker_report_ok'], True)
        self.assertIs(observed['enclosing_health_passed'], False)
        for key in ('kick_child_started', 'enclosing_health_passed', 'complete_route_proven',
                    'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            changed = copy.deepcopy(record)
            changed[key] = True
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                reader.validate_checkpoint(changed, observed)

    def test_measured_entry_replay_failure_preserves_native_receipts_and_refuses_promotion(self):
        record = reader.read(ROOT / 'sdk/development_measured_entry_replay_failure_v1.json')
        observed = reader.retained_measured_entry_replay_failure(Path(record['evidence_root']))
        reader.validate_checkpoint(record, observed)
        self.assertEqual(1378, observed['solver_steps'])
        self.assertEqual(354, observed['native_execution_receipt_links_checked'])
        for key in ('original_independent_replay_passed', 'full_recovery_sequence_independently_replayed',
                    'complete_route_proven', 'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            changed = copy.deepcopy(record)
            changed[key] = True
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                reader.validate_checkpoint(changed, observed)
        report = reader.read(Path(record['evidence_root']) / 'children' / reader.ROLES[1] / 'worker_report.json')
        original = report['passive_entry']['entry_packets'][0]
        application = original['source_application']
        bound = copy.deepcopy(original['bound_observations'])
        bound['observation_v3']['applied_actuation']['adapter_receipt_sha256'] = reader.legacy.canonical_sha256_v1(application)
        with self.assertRaisesRegex(ValueError, 'ENTRY_NATIVE_RECEIPT_HASH'):
            reader.measured_entry_native_application_links(application, bound)
        bound = copy.deepcopy(original['bound_observations'])
        components = bound['source_component_receipts']['rotation_aware_source_component_receipts']
        components['application_receipt']['command_id'] = 'crossed_command'
        crossed_hash = reader.legacy.canonical_sha256_v1(components['application_receipt'])
        components['application_receipt_sha256'] = crossed_hash
        bound['observation_v3']['applied_actuation']['adapter_receipt_sha256'] = crossed_hash
        with self.assertRaisesRegex(ValueError, 'ENTRY_NATIVE_COMMAND_LINK'):
            reader.measured_entry_native_application_links(application, bound)

    def test_valid_deadline_pair_retains_the_prone_timeout_without_promotion(self):
        record = reader.read(ROOT / 'sdk/development_recovery_prone_deadline_checkpoint_v1.json')
        root = Path(record['evidence_root'])
        observed = reader.retained_checkpoint(root)
        reader.validate_checkpoint(record, observed)
        self.assertEqual(40, observed['retained_population']['file_count'])
        self.assertEqual(664, observed['observed']['total_solver_steps'])
        self.assertIs(observed['observed']['coverage_complete'], True)
        self.assertIs(observed['observed']['complete_route_proven'], False)
        report = reader.read(root / 'children/kick_passive_recovery_resume/worker_report.json')
        self.assertEqual(120, report['configuration']['physics_solver_policy']['physics_hz'])
        arm = report['retained_arm']
        state = arm['orchestrator_state']
        self.assertEqual('failed', state['phase'])
        self.assertEqual('phase_timeout:confirm_prone', state['terminal_reason'])
        self.assertEqual(60, state['confirm_prone_step_count'])
        self.assertEqual(0, state['consecutive_prone_sample_count'])
        self.assertEqual(0, state['post_kick_recovery_step_count'])
        self.assertEqual(0, state['walking_resume_step_count'])
        rows = [row for row in arm['trace_rows'] if row['global_semantic_step'] > state['epoch_start_global_step']]
        self.assertEqual(60, len(rows))
        self.assertTrue(all(row['no_actuation_requested'] is True for row in rows))
        classifications = [row['recovery_classification'] for row in rows]
        self.assertTrue(all(row['torso_height_ratio'] > 0.25 and row['torso_up_dot'] <= 1.0
                            and row['torso_ventral_contact'] is False and row['entry_prone_gate'] is False
                            for row in classifications))
        self.assertEqual(35, sum(row['joint_limits_respected'] is False for row in classifications))
        self.assertEqual(0.28300270438194275, rows[-1]['torso_position_world_m'][1])

    def test_separate_full_replay_describes_support_timeout_without_reclassifying_attempt(self):
        record = reader.read(ROOT / 'sdk/development_measured_entry_support_diagnosis_v1.json')
        observed = reader.retained_measured_entry_support_diagnosis(Path(record['diagnostic_root']))
        reader.validate_checkpoint(record, observed)
        self.assertEqual(626, observed['independent_replay']['transition_count'])
        self.assertEqual({'0': 220, '1': 14, '2': 6, '3': 0, '4': 0}, observed['metrics']['simultaneous_bearing_foot_count_histogram'])
        self.assertEqual(470, observed['metrics']['first_torso_up_vector_below_horizontal_step'])
        self.assertLess(observed['metrics']['terminal_sample']['torso_up_dot'], -0.999)
        self.assertLess(observed['metrics']['terminal_sample']['maximum_joint_target_error_rad'], 0.000016)
        for key in ('original_attempt_reclassified', 'causal_attribution_proven', 'successful_recovery_proven',
                    'complete_route_proven', 'physical_acceptance_authority', 'release_authority', 'repeat_consumed_attempt_permitted'):
            changed = copy.deepcopy(record)
            changed[key] = True
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                reader.validate_checkpoint(changed, observed)
        report = reader.read(Path(record['original_report']['path']))
        report['passive_entry']['canonical_packets'][-1]['step_receipt']['classification']['distal_support_gate'] = True
        with self.assertRaisesRegex(ValueError, 'SUPPORT_GATE_RECOMPUTATION'):
            reader.measured_entry_support_metrics(report)

    def test_retained_entry_comparison_preserves_the_canonical_positive_and_selects_only_a_hypothesis(self):
        record = reader.read(ROOT / 'sdk/development_rearward_fold_support_v1.json')
        observed = reader.retained_entry_pose_comparison()
        reader.validate_checkpoint(record, observed)
        self.assertEqual(29, observed['canonical_entry']['first_active_step'])
        self.assertEqual(387, observed['fallen_entry']['first_active_step'])
        for entry in ('canonical_entry', 'fallen_entry'):
            self.assertGreater(observed[entry]['torso_up_dot'], 0.999)
            self.assertLess(observed[entry]['angular_speed_rad_s'], 0.001)
        self.assertGreater(observed['joint_comparison'][0]['absolute_entry_difference_degrees'], 160)
        self.assertEqual([-0.6, 1.05] * 4, observed['prospective_controller']['support_targets_rad'])
        for key in ('matched_causal_comparison', 'causal_attribution_proven', 'historical_results_reinterpreted',
                    'physical_acceptance_authority', 'release_authority'):
            changed = copy.deepcopy(record)
            changed[key] = True
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                reader.validate_checkpoint(changed, observed)

    def test_profiled_population_and_exact_timing_publication(self):
        record = reader.read(ROOT / 'sdk/development_recovery_step_cost_checkpoint_v1.json')
        observed = reader.retained_checkpoint(Path(record['evidence_root']))
        reader.validate_checkpoint(record, observed)
        self.assertEqual(34, observed['retained_population']['file_count'])
        self.assertEqual(604, observed['observed']['total_solver_steps'])
        for child in observed['observed']['children']:
            self.assertIs(child['step_cost_profile']['timing']['ok'], True)
            self.assertIs(child['step_cost_profile']['physics_solver_time_isolated'], False)

    def test_every_top_level_field_missing_or_changed_and_claim_promotion_refuse(self):
        for key in self.record:
            for remove in (False, True):
                changed = copy.deepcopy(self.record)
                if remove:
                    del changed[key]
                else:
                    changed[key] = None
                with self.subTest(key=key, remove=remove), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                    reader.validate_checkpoint(changed, self.observed)
        for key in ('complete_route_proven', 'physical_acceptance_authority', 'release_authority'):
            changed = copy.deepcopy(self.record)
            changed['observed'][key] = True
            with self.subTest(promoted=key), self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
                reader.validate_checkpoint(changed, self.observed)

    def test_cached_physical_population_and_exact_reuse_accounting(self):
        record = reader.read(ROOT / 'sdk/development_recovery_context_cache_checkpoint_v1.json')
        observed = reader.retained_checkpoint(Path(record['evidence_root']))
        reader.validate_checkpoint(record, observed)
        self.assertEqual(38, observed['retained_population']['file_count'])
        self.assertEqual(604, observed['observed']['total_solver_steps'])
        for child in observed['observed']['children']:
            cache = child['step_cost_profile']['context_cache']
            self.assertEqual({'epoch_preflight': 302, 'global_context_validation': 302}, cache['call_sites'])
            self.assertEqual(602, cache['hits'])
            self.assertEqual(2, cache['full_checks'])
            self.assertEqual(0, cache['bypasses'])
            self.assertEqual(2, cache['retained_entries'])

    def test_final_marker_corruption_refuses_without_changing_evidence(self):
        original = Path.read_text
        def changed(path, *args, **kwargs):
            value = original(path, *args, **kwargs)
            return value.replace('"ok":true', '"ok":false', 1) if path.name == 'published_marker.txt' else value
        with patch.object(Path, 'read_text', changed), self.assertRaisesRegex(ValueError, 'FINAL_PUBLICATION_BINDING'):
            reader.retained_checkpoint(self.evidence)

    def test_missing_inventory_member_refuses_without_changing_evidence(self):
        paths = [path for path in self.evidence.rglob('*') if path.name != 'published_marker.txt']
        with patch.object(Path, 'rglob', return_value=paths):
            changed = reader.retained_checkpoint(self.evidence)
        with self.assertRaisesRegex(ValueError, 'CHECKPOINT_BINDING'):
            reader.validate_checkpoint(self.record, changed)


if __name__ == '__main__':
    unittest.main()
