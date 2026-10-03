"""Actual V52 C ABI calls on exposed inputs; no physical trajectory is created."""
import copy
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'sdk/python'), str(ROOT/'sdk/conformance')]
from sporespore_locomotion import LocomotionCore
import development_recovery_refusal as refusal
import r10k_development_failure as failure
from test_development_v32_recontact_component import NativeApi

POLICY = 'sporespore_balanced_wave_recovery_extended_support_transfer_v1'
MEMORY = 'sporespore_balanced_wave_recovery_extended_support_transfer_memory_v1'
PARENT = 'sporespore_balanced_wave_recovery_joint_feasible_height_v1'
PARENT_MEMORY = 'sporespore_balanced_wave_recovery_joint_feasible_height_memory_v1'


class ExtendedSupportTransfer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dll = Path(os.environ['SPORE_V52_DLL'])
        cls.output = Path(os.environ['SPORE_V52_COMPONENT_ROOT'])
        cls.core = LocomotionCore(cls.dll)
        cls.native = NativeApi(str(cls.dll))
        cls.closure = failure.read(failure.RECORD)
        for key in ('report', 'descriptor_source'):
            cls.assert_binding(cls.closure[key])
        report = failure.read(cls.closure['report']['path'])
        cls.rows = report['development_walking_entry']['rows']
        cls.failed = report['detail']['portable_step_receipt']['development_native_step_failure']
        cls.descriptor = refusal.integers(failure.read(cls.closure['descriptor_source']['path'])['configuration']['base_descriptor'])

    @staticmethod
    def assert_binding(item):
        if failure.binding(item['path']) != item:
            raise AssertionError('V52_EXPOSED_SOURCE_DRIFT')

    def request(self, original, successor=True):
        q = refusal.integers(dict(copy.deepcopy(original), descriptor=self.descriptor))
        q.update(schema_version='sporespore_balanced_wave_policy_step_request_v3', policy_id=POLICY if successor else PARENT)
        if successor:
            q['memory']['schema_version'] = MEMORY
        return q

    def call(self, q):
        status, raw = self.native.raw('ss_balanced_wave_policy_step_json', self.core._input_bytes(q))
        self.assertEqual(0, status)
        return raw, json.loads(raw)['value']

    def retain(self, name, value):
        with (self.output/name).open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, indent=2, allow_nan=False);stream.write('\n')

    def test_distinct_policy_and_memory_preserve_parent_profile_laws(self):
        parent = self.core.balanced_wave_policy_profile(PARENT, self.descriptor)
        profile = self.core.balanced_wave_policy_profile(POLICY, self.descriptor)
        self.assertEqual(POLICY, profile['policy_id'])
        self.assertEqual('sporespore_balanced_wave_recovery_extended_support_transfer_profile_v1', profile['schema_version'])
        self.assertEqual({k:v for k,v in parent.items() if k not in ('policy_id','schema_version')},
                         {k:v for k,v in profile.items() if k not in ('policy_id','schema_version')})
        self.assertEqual(MEMORY, self.core.balanced_wave_policy_initial_memory(POLICY,self.descriptor)['schema_version'])
        self.assertEqual(PARENT_MEMORY, self.core.balanced_wave_policy_initial_memory(PARENT,self.descriptor)['schema_version'])
        self.retain('policy-identity.json',dict(profile=profile,parent=parent,world_build_count=0,solver_step_count=0))

    def test_all_839_original_v51_commands_and_refusal_remain_byte_exact(self):
        for row in self.rows:
            raw,out = self.call(self.request(row['request'],False))
            self.assertEqual(row['raw_native_response_sha256'],refusal.digest(raw))
            plane=out['actuation']['receipt']['recovery_support_plane']
            self.assertNotIn('maximum_absolute_reference_bias_rad',plane['measured_support_transfer'])
            rebase=plane['anchored_body_pose'].get('origin_rebase')
            if rebase is not None:
                self.assertNotIn('maximum_absolute_reference_bias_rad',rebase)
        raw,out=self.call(self.request(failure.packet.parse_json(self.failed['request']['utf8_text']),False))
        self.assertEqual(self.failed['response']['raw_sha256'],refusal.digest(raw))
        self.assertTrue(out['actuation']['safe_no_actuation'])
        self.retain('v51-byte-compatibility.json',dict(source=self.closure['report'],completed_commands=len(self.rows),
            original_refusal_reproduced=True,world_build_count=0,solver_step_count=0,original_attempt_reclassified=False))

    def test_predeadline_saturated_input_gets_extended_joint_feasible_reference(self):
        q=self.request(self.rows[800]['request'])
        before=q['memory']['measured_support_transfer']
        self.assertEqual(-.25,before['hip_bias_rad'])
        self.assertLess(before['preparation_commands'],240)
        raw,out=self.call(q)
        self.assertFalse(out['actuation']['safe_no_actuation'],out['actuation']['receipt'])
        plane=out['actuation']['receipt']['recovery_support_plane'];transfer=plane['measured_support_transfer']
        self.assertEqual(.30,transfer['maximum_absolute_reference_bias_rad'])
        self.assertLess(transfer['next_memory']['hip_bias_rad'],-.25)
        self.assertGreaterEqual(transfer['next_memory']['hip_bias_rad'],-.30)
        self.assertEqual(before['preparation_commands']+1,transfer['next_memory']['preparation_commands'])
        self.assertFalse(transfer['preparation_released_this_command'])
        height=plane['anchored_body_pose']['joint_feasible_height']
        self.assertTrue(all(v>=height['required_reach_reserve_m'] for v in height['ordered_reach_reserves_m']))
        self.retain('predeadline-reference.json',dict(label='Copied exposed input with V52 identity; no physical continuation.',
            request=q,raw_response_utf8=raw.decode(),raw_response_sha256=refusal.digest(raw),world_build_count=0,solver_step_count=0))

    def test_complete_exposed_input_chain_and_native_session_agree(self):
        memory=self.core.balanced_wave_policy_initial_memory(POLICY,self.descriptor)
        for limb in memory['ordered_limb_memory']:limb['gait_step']=90
        minimum_bias=0.;minimum_height=0.
        with self.core.create_balanced_wave_policy_session(POLICY,self.descriptor) as session:
            for row in self.rows:
                q=self.request(row['request']);q['memory']=memory
                _,out=self.call(q)
                self.assertFalse(out['actuation']['safe_no_actuation'],(q['state']['semantic_step'],out['actuation']['receipt']))
                actual=session.step_with_measured_body({k:v for k,v in q.items() if k not in ('descriptor','policy_id')})
                self.assertEqual(out,actual)
                for command in out['actuation']['ordered_commands']:
                    self.assertLessEqual(abs(command['target_velocity_rad_s']),command['maximum_target_speed_rad_s'])
                plane=out['actuation']['receipt']['recovery_support_plane']
                self.assertEqual(.30,plane['measured_support_transfer']['maximum_absolute_reference_bias_rad'])
                height=plane['anchored_body_pose'].get('joint_feasible_height')
                if height is not None:
                    self.assertTrue(all(v>=height['required_reach_reserve_m'] for v in height['ordered_reach_reserves_m']))
                    self.assertLessEqual(abs(height['selected_correction_m']-height['previous_correction_m']),
                        .24*(q['state']['sample_time_s']-memory['support_reference']['previous_sample_time_s']))
                    minimum_height=min(minimum_height,height['selected_correction_m'])
                memory=out['next_memory'];minimum_bias=min(minimum_bias,memory['measured_support_transfer']['hip_bias_rad'])
        self.assertLess(minimum_bias,-.25)
        self.assertGreaterEqual(minimum_bias,-.30)
        self.assertEqual(240,memory['measured_support_transfer']['preparation_commands'])
        self.retain('counterfactual-native-chain.json',dict(label='Fresh V52 memory over original V51 measurements, not a new physical trajectory.',
            commands=839,stateless_session_equal=True,minimum_bias_rad=minimum_bias,minimum_height_correction_m=minimum_height,
            final_memory=memory,world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False))

    def test_exhausted_unready_deadline_still_refuses_without_clock_reset(self):
        q=self.request(failure.packet.parse_json(self.failed['request']['utf8_text']))
        self.assertEqual(240,q['memory']['measured_support_transfer']['preparation_commands'])
        raw,out=self.call(q)
        self.assertTrue(out['actuation']['safe_no_actuation'])
        self.assertEqual('FRAME_INVALID:measured_support_transfer_preparation_timeout',out['actuation']['receipt']['controller_error'])
        self.assertEqual(q['memory'],out['next_memory'])
        self.assertTrue(all(c['target_velocity_rad_s']==0 for c in out['actuation']['ordered_commands']))
        self.retain('unchanged-deadline.json',dict(request=q,raw_response_utf8=raw.decode(),raw_response_sha256=refusal.digest(raw),
            world_build_count=0,solver_step_count=0,original_attempt_reclassified=False))

    def test_crossed_policy_bounds_clock_and_geometry_refuse(self):
        controls=[]
        for mutation in ('parent_memory','bias_low','bias_high','clock','height','geometry','parent_range'):
            q=self.request(self.rows[800]['request'])
            if mutation=='parent_memory':q['memory']['schema_version']=PARENT_MEMORY
            if mutation=='bias_low':q['memory']['measured_support_transfer']['hip_bias_rad']=-.300001
            if mutation=='bias_high':q['memory']['measured_support_transfer']['hip_bias_rad']=.300001
            if mutation=='clock':q['measured_body_frame']['semantic_step']+=1
            if mutation=='height':q['memory']['anchored_body_pose']['height_correction_m']=-.020001
            if mutation=='geometry':q['memory']['anchored_body_pose']['ordered_feet'][0]['anchor_world_m']['x']+=1
            if mutation=='parent_range':
                q['policy_id']=PARENT;q['memory']['schema_version']=PARENT_MEMORY
                q['memory']['measured_support_transfer']['hip_bias_rad']=-.27
            _,out=self.call(q)
            self.assertTrue(out['actuation']['safe_no_actuation'],mutation)
            self.assertEqual(q['memory'],out['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in out['actuation']['ordered_commands']))
            controls.append(dict(mutation=mutation,error=out['actuation']['receipt']['controller_error']))
        self.retain('negative-controls.json',dict(controls=controls,world_build_count=0,solver_step_count=0))


if __name__=='__main__':unittest.main()
