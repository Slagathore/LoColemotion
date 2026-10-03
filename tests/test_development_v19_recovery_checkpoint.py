"""Cold V19 result and full contact-input diagnosis; never execute another world."""
import copy
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '013cf8e4b52a46e89e68336d4edb3203'
SOURCE = 'ae00d925899ab76fc98392c8616cff0ccdac5cd4'


class V19Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.walk = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.sources = cls.report['development_walking_entry']['rows']
        cls.diagnosis = cls.record['walking_control_diagnosis']

    def test_complete_original_population_full_replay_and_prospective_source(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertEqual((87, 1, 1258), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((51, 896274427), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertEqual('sha256:6a6d0bdeb3ec614267da8b550887b376023ad03a2f07b4c9ba9fcbf34b36ced4', self.record['retained_population']['inventory_sha256'])
        self.assertTrue(self.record['diagnostic_coverage_complete'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertEqual(986, self.report['after_interaction_step_count'])
        self.assertEqual(1441.955, self.record['elapsed_seconds']['whole_invocation'])
        self.assertEqual('sha256:6e0ddb1cd4e92c9b118d4ffa0d1a31d312b672b59d6e84278b9d12c2d1a84bdc', self.record['kicked_report']['raw_sha256'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual(1258, replay['transition_count'])
        self.assertTrue(replay['walking_control_replay']['ok'])
        self.assertEqual(453, replay['walking_control_replay']['replayed_walking_steps'])

    def test_same_body_standing_then_complete_declared_ramp_and_command_population(self):
        packets = {p['global_semantic_step']: p for p in self.report['passive_entry']['canonical_packets']}
        self.assertTrue(all(packets[s]['step_receipt']['classification']['stable_stance_gate'] for s in range(746, 806)))
        self.assertEqual('complete', packets[805]['step_receipt']['next_phase'])
        self.assertEqual(60, packets[805]['step_receipt']['memory']['stance_dwell_steps_observed'])
        self.assertEqual(805, self.walk['start_receipt']['global_start_step'])
        self.assertEqual(list(range(806, 1259)), [r['commanded_global_step'] for r in self.sources])
        self.assertEqual(list(range(805, 1258)), [r['measured_global_step'] for r in self.sources])
        self.assertEqual(453, len(self.walk['step_receipt_sha256s']))
        for row in self.sources:
            self.assertEqual(8, len(row['request']['state']['ordered_joint_observations']))
            self.assertEqual(9, len(row['ordered_body_states']))
            self.assertEqual(self.walk['step_receipt_sha256s'][row['session_local_step']-1], row['full_step_receipt_sha256'])
        self.assertEqual(0., self.diagnosis['first_gait_amplitude'])
        self.assertEqual(1166, self.diagnosis['first_full_amplitude_global_step'])
        self.assertEqual(93, self.diagnosis['full_amplitude_sample_count'])
        self.assertEqual(0.2545977830886841, self.diagnosis['maximum_first_command_target_jump_rad'])
        self.assertEqual(0, self.diagnosis['additional_native_physics_read_count'])
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, self.arm[key])
        self.assertEqual(self.arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])

    def test_all_contact_inputs_and_frozen_shape_lookup_mismatch(self):
        self.assertEqual(self.diagnosis, closure.walking_control_diagnostics(self.report))
        self.assertTrue(all(self.diagnosis['first_precommand_native_contact_map'].values()))
        total = 0
        for limb, expected in [('front_left', 335), ('front_right', 123), ('rear_left', 223), ('rear_right', 413)]:
            row = self.diagnosis['per_limb_contact_observations'][limb]
            self.assertEqual(453, row['sample_count'])
            self.assertEqual(0, row['controller_present_count'])
            self.assertEqual(0, row['controller_support_count'])
            self.assertEqual(expected, row['native_precommand_contact_count'])
            total += expected
        self.assertEqual(1094, total)
        adapter = closure.prior.committed('scripts/lab/gait/sdk_godot_jolt_adapter.gd', SOURCE).decode()
        sampler = adapter.split('static func _foot_bears_floor(', 1)[1].split('static func _canonical_orientation_xyzw(', 1)[0]
        self.assertIn('"has_semantic_contact",\n\t\t\t\t"foot",', sampler.replace('\r\n', '\n'))
        self.assertIn('String(sample.get("local_shape_id", "")) == "foot"', adapter)
        world = closure.prior.committed('sdk/adapters/godot/gdscript/recovery_native_world_v1.gd', SOURCE).decode()
        self.assertIn('shape_node.set_meta("lab_shape_id", body_id)', world)
        self.assertIn('var body := SemanticContactRigidBodyScript.new()', world)
        semantic = closure.prior.committed('scripts/lab/mechanics/semantic_contact_rigid_body.gd', SOURCE).decode()
        self.assertIn('return latest_semantic_contacts.has("%s|%s" % [shape_id, counterparty_id])', semantic)

    def test_negative_motion_timeout_label_limit_and_no_promotion(self):
        evaluation = self.walk['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(-0.5153125617892534, evaluation['forward_advance_m'])
        self.assertEqual(1.728767926699587, evaluation['maximum_tilt_rad'])
        self.assertEqual(52, evaluation['torso_contact_step_count'])
        self.assertEqual(8, len(evaluation['false_walking_receipts']))
        self.assertEqual(0, evaluation['threshold_override_input_count'])
        self.assertEqual([1173, 1202, 1207], [self.diagnosis[k] for k in ('first_tilt_limit_exceeded_global_step', 'first_no_foot_contact_global_step', 'first_torso_contact_global_step')])
        self.assertTrue(self.diagnosis['original_evaluator_timeout_free_flag'])
        self.assertEqual(2, self.diagnosis['actual_native_gate_timeout_total'])
        self.assertFalse(self.diagnosis['original_evaluation_replaced'])
        for key in ('comparative_authority', 'causal_attribution_proven', 'successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.record[key])
            forged = copy.deepcopy(self.record)
            forged[key] = True
            with self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(forged, self.observed)
        for relative, digest in [
            ('sdk/development/recovery_attempts/88d86686f4d1421286b59eb03c7d8115.json', '63b8ab0a2fb5fae54571f2630c3577fcf6e5c15fdf13201a3968646379c85725'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')]:
            self.assertEqual('sha256:' + digest, closure.entry.digest((ROOT / relative).read_bytes()))


if __name__ == '__main__':
    unittest.main()
