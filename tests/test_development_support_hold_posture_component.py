"""V44 real exported-interface checks on retained inputs; no physical rollout."""
import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_support_hold_diagnosis as diagnosis
import test_development_v43_support_progression_component as parent

POLICY='sporespore_balanced_wave_recovery_support_hold_posture_v1'
MEMORY='sporespore_balanced_wave_recovery_support_hold_posture_memory_v1'
PROFILE=ROOT/'sdk/development/recovery_candidates/v44-support-hold-posture-v1.json'


class SupportHoldPosture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report=diagnosis.source.report();cls.entries=cls.report['development_walking_entry']['rows']
        cls.descriptor=cls.report['passive_entry']['walking_runtime_preflight']['configuration']['base_descriptor']
        cls.dimensions=diagnosis.dimensions(cls.report)
        p=candidate.read(PROFILE);cls.binding=candidate.read(candidate.resource_path(p['runtime_binding']))
        for path in (Path(cls.binding['runtime']['path']),ROOT/cls.binding['local_build_path']):
            assert candidate.sha(path)==cls.binding['runtime']['raw_sha256']
        cls.native=parent.NativeApi(cls.binding['runtime']['path'])

    def request(self,row,memory=None,policy=POLICY):
        r=copy.deepcopy(dict(row['request'],schema_version='sporespore_balanced_wave_policy_step_request_v2',descriptor=self.descriptor,policy_id=policy))
        if memory is not None:r['memory']=copy.deepcopy(memory)
        r['memory']['schema_version']=MEMORY if policy==POLICY else parent.MEMORY
        return r

    def call(self,r):
        status,raw=self.native.raw('ss_balanced_wave_policy_step_json',parent.request_bytes(r))
        self.assertEqual(0,status);return raw,json.loads(raw)['value']

    def check(self,row,request,value):
        self.assertFalse(value['actuation']['safe_no_actuation'])
        s=value['actuation']['receipt']['recovery_support_plane'];h=s['support_hold_posture'];held=s['support_progression']['phase_progression_held']
        self.assertEqual(held,h['enabled']);self.assertFalse(h['physical_acceptance_authority'])
        old_request=copy.deepcopy(request);old_request['policy_id']=parent.POLICY;old_request['memory']['schema_version']=parent.MEMORY
        _,old=self.call(old_request);b=old['actuation']['receipt']['recovery_support_plane']
        self.assertEqual(s['support_progression'],b['support_progression']);self.assertEqual(s['stance_latch'],b['stance_latch'])
        self.assertEqual(value['next_memory']['ordered_limb_memory'],old['next_memory']['ordered_limb_memory'])
        self.assertEqual(value['next_memory']['support_reference']['previous_wave'],old['next_memory']['support_reference']['previous_wave'])
        if held:
            self.assertTrue(all(x['upright_reference_selected'] for x in s['upright_stance']['ordered_limbs']))
            self.assertTrue(all(x['walking_knee_fraction']==0 for x in h['effective_reference_wave']['ordered_limbs']))
            if h['same_mode_comparison_wave'] is not None:self.assertTrue(all(x['walking_knee_fraction']==0 for x in h['same_mode_comparison_wave']['ordered_limbs']))
            self.assertEqual(request['memory']['ordered_limb_memory'],value['next_memory']['ordered_limb_memory'])
        else:self.assertEqual(value['actuation']['ordered_commands'],old['actuation']['ordered_commands'])
        projected=dict(row,request=request,native_output=value)
        expected=diagnosis.command(projected,request['memory']['support_reference']['ordered_target_positions_rad'],self.dimensions,held)
        error=0.
        for i,(a,c) in enumerate(zip(expected['commands'],value['actuation']['ordered_commands'])):
            self.assertAlmostEqual(a['target_rad'],c['requested_target_position_rad'],places=12)
            self.assertAlmostEqual(a['motor_velocity_rad_s'],c['target_velocity_rad_s'],places=10)
            self.assertEqual(a['saturated'],c['velocity_saturated']);self.assertLessEqual(abs(c['target_velocity_rad_s']),c['maximum_target_speed_rad_s'])
            self.assertAlmostEqual(a['goal_rad'],s['upright_stance']['ordered_selected_goals_rad'][i],places=12)
            error=max(error,abs(a['motor_velocity_rad_s']-c['target_velocity_rad_s']))
        return held,error

    def test_complete_retained_geometry_and_original_boundary(self):
        value=diagnosis.summarize(self.report)
        self.assertEqual(704,value['limb_sample_count']);self.assertEqual(0,value['final_rear_right_hold']['contact_samples'])
        self.assertLess(value['frame_axis_maximum_difference'],2e-7)
        self.assertLess(value['ideal_measured_bottom_maximum_absolute_error_m'],.0016)
        rr=value['last_precommand'][-1]
        self.assertAlmostEqual(.07103964834591772,rr['nominal_measured_capsule_bottom_m'],places=12)
        self.assertFalse(rr['position_or_velocity_or_slew_limited'])
        print('V44_GEOMETRY',json.dumps({k:v for k,v in value.items() if k not in ('all_limb_samples','original_checkpoint')}),flush=True)

    def test_binding_profile_and_nonrunnable_component(self):
        p=candidate.read(PROFILE)
        self.assertEqual(347,self.binding['core_test_count'])
        for f in self.binding['source_files']:self.assertEqual(candidate.sha(ROOT/f['path']),f['raw_sha256'])
        self.assertEqual(candidate.sha(candidate.resource_path(p['runtime_binding'])),p['runtime_binding_sha256'])
        self.assertEqual(candidate.sha(candidate.resource_path(p['extension'])),p['extension_sha256'])
        with self.assertRaisesRegex(ValueError,'PROFILE_SCHEMA'):candidate.selection(candidate.reference_for_path(PROFILE))
        r=dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1',descriptor=self.descriptor,policy_id=POLICY)
        status,new=self.native.call('ss_balanced_wave_policy_profile_json',r);self.assertEqual(0,status)
        status,old=self.native.call('ss_balanced_wave_policy_profile_json',dict(r,policy_id=parent.POLICY));self.assertEqual(0,status)
        self.assertEqual(dict(old['value'],policy_id=POLICY,schema_version='sporespore_balanced_wave_recovery_support_hold_posture_profile_v1',
            support_hold_posture_mode_id='finite_hold_all_limb_upright_support_without_swing_lift_v1'),new['value'])
        print('V44_NATIVE_PROFILE',json.dumps(new['value']),flush=True)

    def test_all_retained_inputs_both_interfaces_and_chained_reference_memory(self):
        counts=dict(one_command_inputs=0,chained_inputs=0,held_one_commands=0,held_chained_commands=0,maximum_motor_error_rad_s=0.)
        for chained in (False,True):
            memory=None;session=parent.Session(self.native,self.descriptor,policy=POLICY);sha=hashlib.sha256()
            try:
                for row in self.entries:
                    request=self.request(row,memory);raw,value=self.call(request)
                    self.assertEqual(raw,session.raw(request));sha.update(raw)
                    held,error=self.check(row,request,value)
                    counts['chained_inputs' if chained else 'one_command_inputs']+=1
                    counts['held_chained_commands' if chained else 'held_one_commands']+=held
                    counts['maximum_motor_error_rad_s']=max(counts['maximum_motor_error_rad_s'],error)
                    if chained:memory=value['next_memory']
            finally:session.close()
            counts['chained_raw_sha256' if chained else 'one_command_raw_sha256']='sha256:'+sha.hexdigest()
        self.assertEqual(176,counts['one_command_inputs']);self.assertEqual(176,counts['chained_inputs'])
        self.assertEqual(143,counts['held_one_commands']);self.assertEqual(143,counts['held_chained_commands'])
        print('V44_NATIVE_SAVED_INPUTS',json.dumps(dict(counts,new_physical_trajectory=False,world_build_count=0,solver_step_count=0)),flush=True)

    def test_original_v43_outputs_older_policies_and_recovery_fixtures_are_unchanged(self):
        for row in self.entries:
            raw,value=self.call(self.request(row,policy=parent.POLICY))
            self.assertEqual('sha256:'+hashlib.sha256(raw).hexdigest(),row['raw_native_response_sha256'])
            self.assertNotIn('support_hold_posture',value['actuation']['receipt']['recovery_support_plane'])
        # Reuse the established 12-policy/400-input regression population.
        parent.SupportProgression.setUpClass()
        check=parent.SupportProgression('test_4800_older_outputs_and_six_recovery_fixtures_are_exact')
        check.native=self.native;check.binding=self.binding
        check.test_4800_older_outputs_and_six_recovery_fixtures_are_exact()
        print('V44_OLD_EXACT_OUTPUTS',json.dumps(dict(v43_outputs=176,older_outputs=4800,recovery_fixtures=6)),flush=True)

    def test_missing_crossed_malformed_and_timeout_still_refuse(self):
        row=self.entries[-1]
        for kind in ('missing','too_long','timeout','dwell','contact','contradiction','floor','crossed'):
            r=self.request(row)
            if kind=='missing':r['memory'].pop('support_progression')
            elif kind=='too_long':r['memory']['support_progression']['held_steps']=121
            elif kind=='timeout':r['memory']['support_progression']['held_steps']=120
            elif kind=='dwell':r['memory']['support_progression']['clear_dwell_steps']=3
            elif kind=='contact':r['state']['ordered_contact_observations'][0]['presence']=None
            elif kind=='contradiction':r['state']['ordered_contact_observations'][0].update(presence=False,bears_support=True)
            elif kind=='floor':r['floor_reference']['source_instance_id']='crossed'
            else:r['memory']['schema_version']=parent.MEMORY
            _,v=self.call(r);self.assertTrue(v['actuation']['safe_no_actuation'],kind)
            self.assertEqual(r['memory'],v['next_memory']);self.assertTrue(all(c['target_velocity_rad_s']==0 for c in v['actuation']['ordered_commands']))
        for invalid in (-1,1.5,'1',True):
            r=self.request(row);r['memory']['support_progression']['held_steps']=invalid
            self.assertNotEqual(0,self.native.raw('ss_balanced_wave_policy_step_json',parent.request_bytes(r))[0])
        print('V44_REFUSALS',json.dumps(dict(safe_zero_cases=8,malformed_transport_cases=4)),flush=True)


if __name__=='__main__':unittest.main()
