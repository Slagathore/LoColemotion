"""Cold V18 closure: standing retained, forward startup, three gait negatives."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate_checkpoint as closure

ATTEMPT = '88d86686f4d1421286b59eb03c7d8115'
FRAME = 'anatomical_plus_x_horizontal_resume_v1'


class V18Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.walk = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r['walking_segment_id'] == 'walking_resume']
        cls.packets = {p['global_semantic_step']: p for p in cls.report['passive_entry']['canonical_packets']}

    def test_original_complete_run_replay_population_and_frozen_frame_source(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual((81, 1, 898), tuple(self.record[k] for k in ('safety_test_count', 'world_count', 'solver_step_count')))
        self.assertEqual((49, 813463530), tuple(self.record['retained_population'][k] for k in ('file_count', 'byte_length')))
        self.assertTrue(self.record['diagnostic_coverage_complete'])
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        self.assertEqual(626, self.report['after_interaction_step_count'])
        self.assertEqual(1223.071, self.record['elapsed_seconds']['whole_invocation'])
        self.assertEqual('6b8bda51ee3791fee96a1574db1d01eee03ae871', self.record['source_snapshot']['head'])
        self.assertIn('sdk/development/recovery_walking_frame_contract_v1.json', [r['path'] for r in self.record['rule_sources']])

    def test_standing_completion_and_same_body_handoff_remain_observed(self):
        self.assertTrue(all(self.packets[s]['step_receipt']['classification']['stable_stance_gate'] for s in range(746, 806)))
        last = self.packets[805]['step_receipt']
        self.assertEqual('complete', last['next_phase'])
        self.assertEqual(60, last['memory']['stance_dwell_steps_observed'])
        self.assertEqual([629, 805, 177, 98, 170, 68], [self.record['metrics']['phase_summary'][-1][k]
            for k in ('first_step', 'last_step', 'sample_count', 'support_samples', 'raised_samples', 'stable_samples')])
        self.assertEqual(805, self.walk['start_receipt']['global_start_step'])
        self.assertEqual(list(range(806, 899)), [r['global_semantic_step'] for r in self.rows])
        self.assertEqual(93, len(self.walk['step_receipt_sha256s']))
        self.assertTrue(all(r['control_owner'] == 'walking_bw5r_b' for r in self.rows))
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            self.assertEqual(0, self.arm[key])
        self.assertEqual(self.arm['body_population_instance_sha256'], self.report['terminal_same_body_identity_receipt']['body_population_instance_sha256'])

    def test_native_frame_forward_motion_and_unchanged_negative_evaluation(self):
        start = self.walk['start_receipt']
        request = closure.entry.packet.parse_json(self.packets[805]['collection_transport']['request']['utf8_text'])
        q = request['observation']['state']['base_pose_world']['orientation_xyzw']
        x, y, z, w = (q[k] for k in ('x', 'y', 'z', 'w'))
        side = [2*(x*z+w*y), 0., 1-2*(x*x+y*y)]
        norm = math.sqrt(sum(v*v for v in side))
        side = [v/norm for v in side]
        forward = [side[2], 0., -side[0]]
        self.assertLess(max(abs(a-b) for a,b in zip(forward, start['task_frame_forward_axis_world_host_real'])), 2e-6)
        self.assertLess(max(abs(a-b) for a,b in zip(side, start['task_frame_lateral_axis_world_host_real'])), 2e-6)
        self.assertEqual(FRAME, start['development_walking_frame_id'])
        self.assertTrue(all(r['development_walking_frame_id'] == FRAME for r in self.rows))
        self.assertTrue(all('development_walking_frame_id' not in r for r in self.arm['trace_rows'][:805]))
        self.assertNotIn('development_walking_frame_id', self.arm['walking_sessions'][0]['start_receipt'])
        evaluation = self.walk['evaluation']
        advance = sum((p-o)*f for p,o,f in zip(self.rows[-1]['torso_position_world_m'], start['task_frame_origin_world_m'], start['task_frame_forward_axis_world_host_real']))
        self.assertEqual(advance, evaluation['forward_advance_m'])
        self.assertEqual(0.043314898779652056, advance)
        self.assertEqual(['every_limb_forward_relocation', 'every_limb_two_contact_cycles', 'terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(0, evaluation['threshold_override_input_count'])
        self.assertEqual(.02, evaluation['fixed_thresholds']['minimum_forward_advance_m'])
        self.assertEqual(0, evaluation['torso_contact_step_count'])
        self.assertEqual(0.0678190718221625, evaluation['maximum_tilt_rad'])

    def test_recompute_all_recorded_point_cycles_and_preserve_nonclaims(self):
        events = []
        forward = self.walk['start_receipt']['task_frame_forward_axis_world_host_real']
        evaluation = self.walk['evaluation']
        for limb in ('front_left', 'front_right', 'rear_left', 'rear_right'):
            released = None
            airborne = 0
            distances = []
            for row in self.rows:
                if not row['contact_by_limb'][limb]:
                    released = row if released is None else released
                    airborne += 1
                elif released is not None:
                    if airborne >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        distance = sum((b-a)*f for a,b,f in zip(released['foot_position_world_m_by_limb'][limb], row['foot_position_world_m_by_limb'][limb], forward))
                        distances.append(distance)
                        events.append(dict(limb=limb, liftoff=released['global_semantic_step'], touchdown=row['global_semantic_step'], airborne_steps=airborne, recorded_point_forward_relocation_m=distance))
                    released, airborne = None, 0
            self.assertEqual(len(distances), evaluation['contact_cycle_count_by_limb'][limb])
            self.assertEqual(min(distances) if distances else None, evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb])
        self.assertEqual(5, len(events))
        self.assertEqual(-0.019963547815257776, min(e['recorded_point_forward_relocation_m'] for e in events))
        print('V18_RECORDED_POINT_CYCLES', json.dumps(dict(events=events,
            point_semantics='Historical evaluator uses distal rigid-body origins, not contact-site centers.',
            observation_rewritten=False, longer_horizon_cannot_erase_recorded_minimum=True), separators=(',', ':')))
        for key in ('comparative_authority', 'causal_attribution_proven', 'successful_recovery_proven', 'complete_route_proven', 'physical_acceptance_authority', 'release_authority'):
            self.assertFalse(self.record[key])
            forged = copy.deepcopy(self.record)
            forged[key] = True
            with self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(forged, self.observed)
        for relative, digest in [
            ('sdk/development/recovery_attempts/5436af3ddcad48dda0f2450ce0a9dd7b.json', '9f7af3f0b174571424bdf171bb0a7c947a3bbde626a94c6d8fc39ef13b4eea20'),
            ('sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json', 'c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f')]:
            self.assertEqual('sha256:' + digest, closure.entry.digest((ROOT / relative).read_bytes()))


if __name__ == '__main__':
    unittest.main()
