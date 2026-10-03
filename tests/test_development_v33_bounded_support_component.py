"""Real exported API; retained inputs are not an alternative physical rollout."""
import copy
import hashlib
import json
import math
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_stance_plane_feasibility as geometry
from test_development_v32_recontact_component import NativeApi

POLICY = 'sporespore_balanced_wave_recovery_bounded_support_v1'
PREVIOUS = 'sporespore_balanced_wave_recovery_swing_end_recontact_v1'
LEGACY = 'sporespore_balanced_wave_bw5r_b_v1'
PROFILE = ROOT/'sdk/development/recovery_candidates/v33-bounded-support-v1.json'


class V33BoundedSupport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure_path = ROOT/'sdk/development/recovery_attempts/987a8848999d457a820c078eb9273dbb.json'
        cls.closure = candidate.read(cls.closure_path)
        cls.report_path = Path(cls.closure['kicked_report']['path'])
        if candidate.sha(cls.closure_path) != 'sha256:c686eb6a455941cefeb2435c2972fae01f8a7c9ccce32a48b0134e9c3f1ac91b' or candidate.sha(cls.report_path) != cls.closure['kicked_report']['raw_sha256']:
            raise AssertionError('V33_RETAINED_SOURCE_DRIFT')
        cls.report = candidate.read(cls.report_path)
        cls.descriptor = cls.report['configuration']['base_descriptor']
        cls.profile = candidate.read(PROFILE)
        cls.binding = candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding = candidate.read(ROOT/'sdk/development/recovery_candidates/v32-swing-end-recontact-v1.runtime.json')
        for binding in (cls.binding, cls.old_binding):
            for image in (Path(binding['runtime']['path']), ROOT/binding['local_build_path']):
                if candidate.sha(image) != binding['runtime']['raw_sha256']:
                    raise AssertionError('V33_COMPONENT_IMAGE_DRIFT')
        cls.native = NativeApi(cls.binding['runtime']['path'])
        cls.old = NativeApi(cls.old_binding['runtime']['path'])

    def initialize(self):
        status, response = self.native.call('ss_balanced_wave_policy_initial_memory_json', dict(
            schema_version='sporespore_balanced_wave_policy_initial_memory_request_v1',
            descriptor=self.descriptor, policy_id=POLICY))
        self.assertEqual(0, status)
        self.assertTrue(response['ok'])
        memory = response['value']
        source = self.report['development_walking_entry']['rows'][0]['request']['memory']
        self.assertIsNone(source['last_semantic_step'])
        # Match BOTH production initializer selections, not just its phase.
        # The former fixture omitted the 1530 evidence clock bound; retain
        # that failed check and use the exact stored initial source here.
        for limb, original in zip(memory['ordered_limb_memory'], source['ordered_limb_memory']):
            self.assertEqual(limb['limb_id'], original['limb_id'])
            self.assertEqual((90, 1530), (original['gait_step'], original['evidence_gait_step_limit']))
            limb['gait_step'] = original['gait_step']
            limb['evidence_gait_step_limit'] = original['evidence_gait_step_limit']
        return memory

    def request(self, entry, policy=POLICY, memory=None):
        request = dict(entry['request'], schema_version='sporespore_balanced_wave_policy_step_request_v1',
                       descriptor=self.descriptor, policy_id=policy)
        if memory is not None:
            request['memory'] = memory
        return request

    def test_component_identity_binding_and_physical_refusal(self):
        request = dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1',
                       descriptor=self.descriptor, policy_id=POLICY)
        status, response = self.native.call('ss_balanced_wave_policy_profile_json', request)
        self.assertEqual(0, status)
        profile = response['value']
        self.assertEqual('all_limb_bounded_plane_observation_z_forward_reference_slew_v1', profile['stance_support_mode_id'])
        self.assertEqual('scheduled_swing_end_recontact_v1', profile['recontact_gate_mode_id'])
        self.assertFalse(profile['physical_acceptance_authority'])
        with self.assertRaisesRegex(ValueError, 'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        self.assertEqual(self.profile['runtime_binding_sha256'], candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        self.assertEqual(298, self.binding['core_test_count'])
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'], candidate.sha(ROOT/source['path']), source['path'])
        print('V33_EXPORTED_PROFILE', json.dumps(dict(profile=profile, component_profile_sha256=candidate.sha(PROFILE),
            native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(profile)).hexdigest(),
            physical_selection_refused=True, world_build_count=0)), flush=True)

    def test_all_retained_old_policy_outputs_and_recovery_fixtures_remain_exact(self):
        count = 0
        for policy in (PREVIOUS, LEGACY):
            for entry in self.report['development_walking_entry']['rows']:
                request = self.request(entry, policy)
                encoded = self.old.canonical(request)
                expected = self.old.raw('ss_balanced_wave_policy_step_json', encoded)
                actual = self.native.raw('ss_balanced_wave_policy_step_json', encoded)
                self.assertEqual(0, expected[0])
                self.assertEqual(expected, actual)
                count += 1
        def fixtures(binding):
            path = Path(binding['compiled_fixtures']['path'])
            self.assertEqual(binding['compiled_fixtures']['raw_sha256'], candidate.sha(path))
            return [line for line in path.read_text().splitlines() if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
        previous, current = fixtures(self.old_binding), fixtures(self.binding)
        self.assertEqual(6, len(previous))
        self.assertEqual(previous, current)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            candidate.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        print('V33_LEGACY_COMPATIBILITY', json.dumps(dict(exact_old_policy_raw_output_count=count,
            policies=[PREVIOUS, LEGACY], exact_recovery_fixture_matches=6, old_records_changed=False)), flush=True)

    def test_all_400_new_commands_have_bounded_references_and_explained_geometry(self):
        memory = self.initialize()
        output_chain = hashlib.sha256()
        projected, slew, zero_first, maximum_residual = 0, 0, False, 0.
        upper = .35*self.descriptor['upper_length_fraction']
        dimensions = (upper, .35-upper, .04*self.descriptor['foot_radius_scale'], self.descriptor['hip_span_scale'])
        count = 0
        for entry in self.report['development_walking_entry']['rows']:
            request = self.request(entry, memory=memory)
            encoded = self.native.canonical(request)
            status, raw = self.native.raw('ss_balanced_wave_policy_step_json', encoded)
            self.assertEqual(0, status)
            self.assertEqual((status, raw), self.native.raw('ss_balanced_wave_policy_step_json', encoded))
            output_chain.update(raw)
            value = json.loads(raw)['value']
            self.assertFalse(value['actuation']['safe_no_actuation'], (entry['session_local_step'], value['actuation']['receipt']['controller_error']))
            receipt = value['actuation']['receipt']['recovery_support_plane']
            before = memory['support_reference']['ordered_target_positions_rad']
            commands = value['actuation']['ordered_commands']
            if count == 0:
                zero_first = all(c['requested_target_position_rad'] == 0 for c in commands)
                self.assertTrue(zero_first)
            for index, command in enumerate(commands):
                limit = .72 if index % 2 == 0 else 1.1
                self.assertLessEqual(abs(command['requested_target_position_rad']), limit)
                self.assertFalse(command['position_saturated'])
                self.assertLessEqual(abs(command['requested_target_position_rad']-before[index]),
                    command['maximum_target_speed_rad_s']*receipt['reference_step_duration_s']+1e-12)
                slew += command['slew_limited']
            # Recover anatomical orientation from the DECLARED input mapping.
            # The independently retained native quaternion is not substituted
            # into the controller input or treated as bit-identical to it.
            q = request['state']['base_pose_world']['orientation_xyzw']; s = math.sqrt(.5)
            pose = dict(position_m=request['state']['base_pose_world']['position_m'], orientation_xyzw=dict(
                x=s*(q['x']+q['z']), y=s*(q['y']-q['w']), z=s*(q['z']-q['x']), w=s*(q['w']+q['y'])))
            directions = {p['limb_id']:p['nominal_leg_direction_rad'] for p in receipt['ordered_limb_proposals']}
            independent = geometry.propose(pose, directions, dimensions)
            self.assertAlmostEqual(independent['proposed_torso_height_m'], receipt['proposed_torso_height_m'], places=13)
            expected = {p['limb']:p for p in independent['proposed_targets']}
            for proposal in receipt['ordered_limb_proposals']:
                reference = expected[proposal['limb_id']]
                self.assertAlmostEqual(reference['proposed_knee_rad'], proposal['unrestricted_knee_rad'], delta=1e-7)
                self.assertAlmostEqual(reference['proposed_hip_rad'], proposal['unrestricted_hip_rad'], delta=1e-7)
                projected += proposal['support_joint_projection_required']
                maximum_residual = max(maximum_residual, abs(proposal['projected_support_nominal_plane_residual_m']))
            self.assertFalse(receipt['all_limb_contact_claim'])
            self.assertEqual(entry['native_output']['next_memory']['ordered_limb_memory'], value['next_memory']['ordered_limb_memory'])
            memory = value['next_memory']
            count += 1
        self.assertEqual(400, count)
        self.assertGreater(projected, 0)
        self.assertGreater(slew, 0)
        print('V33_RETAINED_INPUT_COMMAND_PROBE', json.dumps(dict(input_count=count, command_count=count*8,
            raw_output_chain_sha256='sha256:'+output_chain.hexdigest(), support_joint_projection_count=projected,
            reference_slew_limited_command_count=slew, maximum_projected_support_plane_residual_m=maximum_residual,
            first_command_neutral=zero_first, scheduler_matches_v32_for_all_inputs=True,
            new_physical_trajectory=False, physical_outcome_predicted=False, world_build_count=0, solver_step_count=0)), flush=True)

    def test_exported_missing_corrupt_crossed_and_inverted_inputs_refuse(self):
        entry = self.report['development_walking_entry']['rows'][0]
        request = self.request(entry, memory=self.initialize())
        variants = []
        bad = copy.deepcopy(request); del bad['memory']['support_reference']; variants.append(bad)
        bad = copy.deepcopy(request); bad['memory']['support_reference']['ordered_target_positions_rad'][0] = 1.; variants.append(bad)
        bad = copy.deepcopy(request); bad['state']['ordered_contact_observations'][0]['bears_support'] = None; variants.append(bad)
        bad = copy.deepcopy(request); bad['policy_id'] = PREVIOUS; variants.append(bad)
        bad = copy.deepcopy(request); bad['state']['base_pose_world']['orientation_xyzw'] = dict(x=1., y=0., z=0., w=0.); variants.append(bad)
        for bad in variants:
            status, raw = self.native.raw('ss_balanced_wave_policy_step_json', self.native.canonical(bad))
            self.assertEqual(0, status)
            value = json.loads(raw)['value']
            self.assertTrue(value['actuation']['safe_no_actuation'])
            self.assertTrue(all(c['target_velocity_rad_s'] == 0 for c in value['actuation']['ordered_commands']))
            self.assertEqual(bad['memory'].get('support_reference'), value['next_memory'].get('support_reference'))
        print('V33_EXPORTED_REFUSALS', json.dumps(dict(refusal_count=len(variants), physical_selection_refused=True)), flush=True)


if __name__ == '__main__':
    unittest.main()
