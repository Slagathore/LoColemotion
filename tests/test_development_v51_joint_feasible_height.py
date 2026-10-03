"""V51 native calls on retained inputs; these tests create no physics world."""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'sdk/python'), str(ROOT / 'sdk/conformance')]
from sporespore_locomotion import LocomotionCore
import development_recovery_refusal as refusal
import r10j_held_out_failure as failure
from test_development_v32_recontact_component import NativeApi

POLICY = 'sporespore_balanced_wave_recovery_joint_feasible_height_v1'
MEMORY = 'sporespore_balanced_wave_recovery_joint_feasible_height_memory_v1'


class JointFeasibleHeight(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dll = Path(os.environ['SPORE_V51_DLL'])
        cls.core = LocomotionCore(cls.dll)
        cls.native = NativeApi(str(cls.dll))
        cls.evidence = Path(os.environ['SPORE_V51_COMPONENT_ROOT'])
        cls.cases = []
        closure = failure.read(failure.CLOSURE)
        retained = {item['path']: item for item in closure['retained_evidence']['files']}
        claim = failure.read(failure.ROOT / 'campaign_claim.json')
        for pair in claim['pairs']:
            child = pair['children'][0]
            path = Path(child['evidence_path']) / 'worker_report.json'
            raw = path.read_bytes()
            if 'sha256:' + hashlib.sha256(raw).hexdigest() != retained[path.as_posix()]['raw_sha256']:
                raise AssertionError('RETAINED_INPUT_DRIFT')
            report = failure.packet.parse_json(raw.decode())
            case = dict(seed=report['seed'], source=retained[path.as_posix()],
                descriptor=refusal.integers(report.get('configuration', {}).get('base_descriptor')),
                rows=report['development_walking_entry']['rows'])
            if not report['ok']:
                case['failure'] = report['detail']['portable_step_receipt']['development_native_step_failure']
            cls.cases.append(case)
            del raw, report
        # Invalid worker envelopes intentionally have no success configuration.
        # The matched campaign descriptor comes from its retained valid peer;
        # native exact-response checks below also bind each invalid child's IK.
        descriptor = cls.cases[1]['descriptor']
        if descriptor is None:
            raise AssertionError('CAMPAIGN_DESCRIPTOR_MISSING')
        for case in cls.cases:
            if case['descriptor'] is None:
                case['descriptor'] = descriptor
            elif case['descriptor'] != descriptor:
                raise AssertionError('CAMPAIGN_DESCRIPTOR_CROSSED')

    def call(self, request):
        status, raw = self.native.raw('ss_balanced_wave_policy_step_json', self.core._input_bytes(request))
        self.assertEqual(0, status)
        return raw, json.loads(raw)['value']

    def request(self, case, row, successor=False):
        q = refusal.integers(dict(copy.deepcopy(row['request']), descriptor=case['descriptor']))
        q['schema_version'] = 'sporespore_balanced_wave_policy_step_request_v3'
        q['policy_id'] = 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1'
        if successor:
            q['policy_id'] = POLICY
            q['memory']['schema_version'] = MEMORY
            if q['memory'].get('anchored_body_pose') is not None:
                q['memory']['anchored_body_pose']['height_correction_m'] = 0.0
        return q

    def retain(self, name, value):
        with (self.evidence / name).open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, indent=2, allow_nan=False)
            stream.write('\n')

    def test_original_v50_bytes_including_both_refusals_stay_exact(self):
        counts = []
        for case in self.cases:
            for row in case['rows']:
                raw, out = self.call(self.request(case, row))
                self.assertEqual(row['raw_native_response_sha256'], refusal.digest(raw))
                self.assertNotIn('joint_feasible_height', out['actuation']['receipt']['recovery_support_plane']['anchored_body_pose'])
                self.assertNotIn('height_correction_m', out['next_memory']['anchored_body_pose'])
            if 'failure' in case:
                f = case['failure']
                q = failure.packet.parse_json(f['request']['utf8_text'])
                raw, out = self.call(self.request(case, dict(request=q)))
                self.assertEqual(f['response']['raw_sha256'], refusal.digest(raw))
                self.assertTrue(out['actuation']['safe_no_actuation'])
                self.assertTrue(all(c['target_velocity_rad_s'] == 0 for c in out['actuation']['ordered_commands']))
            counts.append(dict(seed=case['seed'], completed_commands=len(case['rows']),
                               original_refusal_reproduced='failure' in case, source=case['source']))
        self.retain('historical-v50-byte-reproduction.json', dict(cases=counts, world_build_count=0,
                    solver_step_count=0, original_result_regraded=False))

    def test_instant_policy_switch_preserves_rate_limit_on_exposed_failed_inputs(self):
        for case in self.cases:
            if 'failure' not in case:
                continue
            original = failure.packet.parse_json(case['failure']['request']['utf8_text'])
            q = self.request(case, dict(request=original), True)
            raw, out = self.call(q)
            self.retain(f"instant-switch-failed-input-{case['seed']}.json", dict(
                label='Instant V51 selection with zero prior height correction on a copied V50 input; no physical or full-sequence result.',
                source=case['source'], original_request_sha256=case['failure']['request']['raw_sha256'],
                request=q, raw_response_utf8=raw.decode(), raw_response_sha256=refusal.digest(raw),
                original_result_regraded=False, world_build_count=0, solver_step_count=0,
                physical_acceptance_authority=False, release_authority=False))
            if case['seed'] == 50641:
                self.assertFalse(out['actuation']['safe_no_actuation'])
                selected = out['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['joint_feasible_height']
                self.assertLess(selected['selected_correction_m'], 0)
                self.assertTrue(all(v >= selected['required_reach_reserve_m'] for v in selected['ordered_reach_reserves_m']))
            else:
                # This instantaneous insertion is not a valid V51 history.
                # The new rate bound must not be relaxed to make it pass.
                self.assertTrue(out['actuation']['safe_no_actuation'])
                self.assertEqual('FRAME_INVALID:joint_feasible_height_no_permitted_pose',
                                 out['actuation']['receipt']['controller_error'])
                self.assertEqual(q['memory'], out['next_memory'])

    def test_complete_retained_input_sequences_with_fresh_v51_memory_accept_both_failed_commands(self):
        summaries = []
        for case in self.cases:
            memory = self.core.balanced_wave_policy_initial_memory(POLICY, case['descriptor'])
            for limb in memory['ordered_limb_memory']:
                limb['gait_step'] = 90
            rows = list(case['rows'])
            if 'failure' in case:
                rows.append(dict(request=failure.packet.parse_json(case['failure']['request']['utf8_text'])))
            minimum_correction = 0.0
            for index, row in enumerate(rows):
                q = self.request(case, row, True)
                q['memory'] = memory
                raw, out = self.call(q)
                self.assertFalse(out['actuation']['safe_no_actuation'], (case['seed'], index, out['actuation']['receipt']))
                pose = out['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']
                height = pose.get('joint_feasible_height')
                if height is not None:
                    self.assertTrue(all(v >= height['required_reach_reserve_m'] for v in height['ordered_reach_reserves_m']))
                    self.assertTrue(all(v < 1e-12 for v in pose['ordered_target_fk_error_m']))
                    minimum_correction = min(minimum_correction, height['selected_correction_m'])
                if index == len(rows) - 1 and 'failure' in case:
                    self.retain(f"sequence-failed-input-{case['seed']}.json", dict(
                        label='V51 memory evolved from initialization on exposed V50 measurements; no counterfactual physical result.',
                        source=case['source'], request=q, raw_response_utf8=raw.decode(), raw_response_sha256=refusal.digest(raw),
                        world_build_count=0, solver_step_count=0, original_result_regraded=False,
                        physical_acceptance_authority=False, release_authority=False))
                memory = out['next_memory']
            summaries.append(dict(seed=case['seed'], commands=len(rows), minimum_correction_m=minimum_correction,
                                  includes_original_failed_command='failure' in case, source=case['source']))
        self.assertEqual(2107, sum(v['commands'] for v in summaries))
        self.retain('counterfactual-input-sequences.json', dict(cases=summaries, world_build_count=0,
                    solver_step_count=0, original_result_regraded=False, physical_acceptance_authority=False,
                    release_authority=False))

    def test_fresh_stateless_and_session_chains_agree_and_preserve_motor_limits(self):
        case = self.cases[0]
        memory = self.core.balanced_wave_policy_initial_memory(POLICY, case['descriptor'])
        for limb in memory['ordered_limb_memory']:
            limb['gait_step'] = 90
        with self.core.create_balanced_wave_policy_session(POLICY, case['descriptor']) as session:
            for row in case['rows'][:80]:
                q = self.request(case, row, True)
                q['memory'] = memory
                _, out = self.call(q)
                self.assertFalse(out['actuation']['safe_no_actuation'], out['actuation']['receipt'])
                actual = session.step_with_measured_body({k: v for k, v in q.items() if k not in ('descriptor', 'policy_id')})
                self.assertEqual(out, actual)
                for c in out['actuation']['ordered_commands']:
                    self.assertLessEqual(abs(c['target_velocity_rad_s']), c['maximum_target_speed_rad_s'])
                height = out['actuation']['receipt']['recovery_support_plane']['anchored_body_pose'].get('joint_feasible_height')
                if height is not None:
                    self.assertLessEqual(abs(height['selected_correction_m'] - height['previous_correction_m']),
                                         .24 * (q['state']['sample_time_s'] - memory['support_reference']['previous_sample_time_s']))
                memory = out['next_memory']

    def test_corrupt_clock_cross_policy_and_impossible_height_leave_memory_and_motors_unchanged(self):
        case, row = self.cases[0], self.cases[0]['rows'][2]
        for mutation in ('old_schema', 'missing_correction', 'positive_correction', 'low_correction', 'clock', 'body_clock', 'impossible'):
            q = self.request(case, row, True)
            pose = q['memory']['anchored_body_pose']
            if mutation == 'old_schema': q['memory']['schema_version'] = 'sporespore_balanced_wave_recovery_startup_reference_velocity_memory_v1'
            if mutation == 'missing_correction': pose.pop('height_correction_m')
            if mutation == 'positive_correction': pose['height_correction_m'] = .001
            if mutation == 'low_correction': pose['height_correction_m'] = -.021
            if mutation == 'clock': pose['last_sample_time_s'] += 1
            if mutation == 'body_clock': q['measured_body_frame']['semantic_step'] += 1
            if mutation == 'impossible':
                pose['ordered_feet'][0]['anchor_world_m']['x'] += 1
            _, out = self.call(q)
            self.assertTrue(out['actuation']['safe_no_actuation'], mutation)
            self.assertEqual(q['memory'], out['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s'] == 0 for c in out['actuation']['ordered_commands']))
        q = self.request(case, row)
        q['memory']['anchored_body_pose']['height_correction_m'] = 0.0
        _, out = self.call(q)
        self.assertTrue(out['actuation']['safe_no_actuation'])
        self.assertEqual(q['memory'], out['next_memory'])


if __name__ == '__main__':
    unittest.main()
