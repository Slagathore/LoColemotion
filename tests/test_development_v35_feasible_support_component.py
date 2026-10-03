"""V35 exported native component on V34 inputs, not a new physical trajectory."""
import copy
import ctypes
import hashlib
import json
import math
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_v28_contact_geometry as geometry
from test_development_v32_recontact_component import NativeApi

POLICY='sporespore_balanced_wave_recovery_feasible_support_v1'
PREVIOUS='sporespore_balanced_wave_recovery_floor_support_v1'
PROFILE=ROOT/'sdk/development/recovery_candidates/v35-feasible-support-v1.json'


class V35FeasibleSupport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure=candidate.read(ROOT/'sdk/development/recovery_attempts/beb9c66e4c194930b6283fd227613f44.json')
        path=Path(cls.closure['kicked_report']['path'])
        assert candidate.sha(path)==cls.closure['kicked_report']['raw_sha256']
        cls.report=candidate.read(path);cls.entries=cls.report['development_walking_entry']['rows']
        cls.descriptor=cls.report['configuration']['base_descriptor']
        cls.profile=candidate.read(PROFILE)
        cls.binding=candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding=candidate.read(ROOT/'sdk/development/recovery_candidates/v34-floor-support-v1.runtime.json')
        for binding in (cls.binding,cls.old_binding):
            for p in (Path(binding['runtime']['path']),ROOT/binding['local_build_path']):
                assert candidate.sha(p)==binding['runtime']['raw_sha256']
        cls.native=NativeApi(cls.binding['runtime']['path']);cls.old=NativeApi(cls.old_binding['runtime']['path'])
        cls.floor=cls.entries[0]['request']['floor_reference']

    def initial(self):
        status,value=self.native.call('ss_balanced_wave_policy_initial_memory_json',dict(
            schema_version='sporespore_balanced_wave_policy_initial_memory_request_v1',policy_id=POLICY,descriptor=self.descriptor))
        self.assertEqual(0,status);memory=value['value']
        for m,old in zip(memory['ordered_limb_memory'],self.entries[0]['request']['memory']['ordered_limb_memory']):
            self.assertEqual(m['limb_id'],old['limb_id']);m['gait_step']=old['gait_step'];m['evidence_gait_step_limit']=old['evidence_gait_step_limit']
        return memory

    def request(self,entry,memory):
        return dict(entry['request'],schema_version='sporespore_balanced_wave_policy_step_request_v2',
            policy_id=POLICY,descriptor=self.descriptor,memory=memory)

    def test_native_binding_distinct_profile_and_nonrunnable_component(self):
        self.assertEqual(310,self.binding['core_test_count'])
        self.assertEqual(self.profile['runtime_binding_sha256'],candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'],candidate.sha(ROOT/source['path']),source['path'])
        with self.assertRaisesRegex(ValueError,'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        status,response=self.native.call('ss_balanced_wave_policy_profile_json',dict(
            schema_version='sporespore_balanced_wave_policy_profile_request_v1',descriptor=self.descriptor,policy_id=POLICY))
        self.assertEqual(0,status);p=response['value']
        self.assertEqual('explicit_floor_joint_feasible_stance_height_reference_slew_v1',p['stance_support_mode_id'])
        self.assertEqual('scheduled_swing_end_recontact_v1',p['recontact_gate_mode_id'])
        print('V35_EXPORTED_PROFILE',json.dumps(dict(profile=p,native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(p)).hexdigest(),physical_selection_refused=True)),flush=True)

    def test_1600_old_policy_raw_outputs_and_six_recovery_fixtures_remain_exact(self):
        policies=(PREVIOUS,'sporespore_balanced_wave_recovery_bounded_support_v1',
            'sporespore_balanced_wave_recovery_swing_end_recontact_v1','sporespore_balanced_wave_bw5r_b_v1')
        counts={p:0 for p in policies}
        for policy in policies:
            for entry in self.entries:
                r=copy.deepcopy(dict(entry['request'],schema_version='sporespore_balanced_wave_policy_step_request_v2',policy_id=policy,descriptor=self.descriptor))
                if policy!=PREVIOUS:
                    r['schema_version']='sporespore_balanced_wave_policy_step_request_v1';del r['floor_reference']
                    r['memory'].pop('floor_reference_sha256',None)
                    if policy==policies[1]:r['memory']['schema_version']='sporespore_balanced_wave_recovery_support_memory_v1'
                    else:
                        r['memory']['schema_version']='sporespore_balanced_wave_memory_v1';del r['memory']['support_reference']
                raw=self.old.canonical(r);expected=self.old.raw('ss_balanced_wave_policy_step_json',raw)
                self.assertEqual(0,expected[0]);self.assertFalse(json.loads(expected[1])['value']['actuation']['safe_no_actuation'])
                self.assertEqual(expected,self.native.raw('ss_balanced_wave_policy_step_json',raw));counts[policy]+=1
        fixtures=[]
        for b in (self.old_binding,self.binding):
            p=Path(b['compiled_fixtures']['path']);self.assertEqual(candidate.sha(p),b['compiled_fixtures']['raw_sha256'])
            fixtures.append([s for s in p.read_text().splitlines() if s.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')])
        self.assertEqual(6,len(fixtures[0]));self.assertEqual(*fixtures)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',candidate.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        print('V35_OLD_OUTPUT_COMPATIBILITY',json.dumps(dict(exact_raw_outputs=sum(counts.values()),per_policy=counts,exact_recovery_fixtures=6,old_physical_records_changed=False)),flush=True)

    def independent_height_interval(self,request,proposals):
        # Independent closed-form beta inverse, not the native 64-step bisection.
        # Quaternion-vector rotation also differs from the native scalar expansion.
        q=request['state']['base_pose_world']['orientation_xyzw']
        f,u,z=(geometry.rotate(q,a)[1] for a in ([0,0,1],[0,1,0],[-1,0,0]))
        upper=.35*self.descriptor['upper_length_fraction'];lower=.35-upper
        radius=.04*self.descriptor['foot_radius_scale'];span=self.descriptor['hip_span_scale']
        result=[]
        for p in proposals:
            a=p['nominal_leg_direction_rad'];limb=p['limb_id']
            anchor=span*((.2 if limb.startswith('front') else -.2)*f+(-.18 if limb.endswith('left') else .18)*z)
            down=u*math.cos(a)-f*math.sin(a)
            beta_max=math.atan2(lower*math.sin(1.1),upper+lower*math.cos(1.1));beta=a+.72
            k=1.1 if beta>=beta_max else beta+math.asin(max(-1.,min(1.,upper/lower*math.sin(beta))))
            length=math.hypot(upper+lower*math.cos(k),lower*math.sin(k))
            result.append((radius-anchor+length*down,radius-anchor+(upper+lower)*down,k))
        return result

    def test_400_session_stateless_matches_and_independent_joint_feasible_heights(self):
        create=self.native.library.ss_balanced_wave_policy_session_create_json
        create.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_uint64)];create.restype=ctypes.c_int
        data=self.native.canonical(dict(schema_version='sporespore_balanced_wave_policy_session_create_request_v1',descriptor=self.descriptor,policy_id=POLICY))
        handle=ctypes.c_uint64();self.assertEqual(0,create(data,len(data),ctypes.byref(handle)))
        session=self.native.library.ss_balanced_wave_policy_session_step_json
        session.argtypes=[ctypes.c_uint64,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_size_t)];session.restype=ctypes.c_int
        destroy=self.native.library.ss_balanced_wave_policy_session_destroy;destroy.argtypes=[ctypes.c_uint64];destroy.restype=ctypes.c_int
        memory=self.initial();chain=hashlib.sha256();lowered=empty=participants=slew=0;maximum_lowering=0.
        try:
            for local,entry in enumerate(self.entries,1):
                encoded=self.native.canonical(self.request(entry,memory));request=json.loads(encoded)
                status,raw=self.native.raw('ss_balanced_wave_policy_step_json',encoded);chain.update(raw)
                self.assertEqual(0,status);value=json.loads(raw)['value']
                self.assertFalse(value['actuation']['safe_no_actuation'],value['actuation']['receipt']['controller_error'])
                sr={k:v for k,v in request.items() if k not in ('descriptor','policy_id')};sr['schema_version']='sporespore_balanced_wave_policy_session_step_request_v2'
                data=self.native.canonical(sr);size=ctypes.c_size_t();session(handle,data,len(data),None,0,ctypes.byref(size))
                self.assertTrue(0<size.value<2_000_000);out=ctypes.create_string_buffer(size.value)
                self.assertEqual(0,session(handle,data,len(data),out,size.value,ctypes.byref(size)));self.assertEqual(raw,out.raw[:size.value])
                self.assertEqual(entry['native_output']['next_memory']['ordered_limb_memory'],value['next_memory']['ordered_limb_memory'])
                receipt=value['actuation']['receipt']['recovery_support_plane'];plan=receipt['feasible_support_plan']
                expected=self.independent_height_interval(request,receipt['ordered_limb_proposals'])
                for e,p in zip(expected,plan['ordered_limb_intervals']):
                    for actual,key in zip(e,('minimum_torso_height_m','maximum_torso_height_m','maximum_direction_preserving_knee_rad')):
                        self.assertAlmostEqual(actual,p[key],delta=1e-12)
                lo=max(e[0] for e in expected);hi=min(e[1] for e in expected)
                h=request['state']['base_pose_world']['position_m']['y']-request['floor_reference']['height_world_m']
                target=min(h,hi) if lo<=hi and h>=lo else h
                self.assertAlmostEqual(target,plan['requested_stance_torso_height_m'],delta=1e-12)
                self.assertLessEqual(plan['requested_stance_torso_height_m'],plan['measured_torso_height_m'])
                chosen=[]
                for p in receipt['ordered_limb_proposals']:
                    phase=p['scheduled_phase_step'];lowering=phase>72 and plan['requested_lowering_m']>0
                    self.assertAlmostEqual(target if lowering else h,p['support_reference_torso_height_m'],delta=1e-12)
                    if lowering:chosen.append(p['limb_id'])
                self.assertEqual(chosen,plan['ordered_lowering_participant_limb_ids'])
                lowered+=plan['requested_lowering_m']>0;empty+=not plan['common_height_interval_nonempty'];participants+=len(chosen)
                maximum_lowering=max(maximum_lowering,plan['requested_lowering_m'])
                for i,c in enumerate(value['actuation']['ordered_commands']):
                    lo,hi=(-.72,.72) if i%2==0 else (0.,1.1)
                    self.assertTrue(lo<=c['requested_target_position_rad']<=hi);self.assertFalse(c['position_saturated'])
                    self.assertLessEqual(abs(c['requested_target_position_rad']-memory['support_reference']['ordered_target_positions_rad'][i]),c['maximum_target_speed_rad_s']*receipt['reference_step_duration_s']+1e-14)
                    slew+=c['slew_limited']
                    if local==1:self.assertEqual(0.,c['requested_target_position_rad'])
                memory=value['next_memory']
        finally:self.assertEqual(0,destroy(handle))
        print('V35_RETAINED_INPUT_PROBE',json.dumps(dict(input_count=400,bounded_command_count=3200,exact_session_stateless_matches=400,
            lowering_requested_steps=lowered,empty_interval_steps=empty,stance_lowering_limb_commands=participants,maximum_requested_lowering_m=maximum_lowering,
            slew_limited_command_count=slew,raw_output_chain_sha256='sha256:'+chain.hexdigest(),
            world_build_count=0,solver_step_count=0,new_physical_trajectory=False,physical_acceptance_authority=False)),flush=True)

    def test_missing_crossed_and_drifting_context_refuse(self):
        first=self.request(self.entries[0],self.initial())
        for field,value in [('schema_version','sporespore_balanced_wave_policy_step_request_v1'),('floor_reference',None)]:
            r=dict(first,**{field:value});status,raw=self.native.raw('ss_balanced_wave_policy_step_json',self.native.canonical(r))
            self.assertNotEqual(0,status);self.assertFalse(json.loads(raw)['ok'])
        missing=dict(first);del missing['floor_reference']
        status,raw=self.native.raw('ss_balanced_wave_policy_step_json',self.native.canonical(missing));self.assertNotEqual(0,status)
        _,raw=self.native.raw('ss_balanced_wave_policy_step_json',self.native.canonical(first));memory=json.loads(raw)['value']['next_memory']
        for key,value in [('height_world_m',1.),('frame_id','body_local'),('source_instance_id','other_world')]:
            r=self.request(self.entries[1],memory);r['floor_reference']=dict(r['floor_reference'],**{key:value});encoded=self.native.canonical(r)
            status,raw=self.native.raw('ss_balanced_wave_policy_step_json',encoded);result=json.loads(raw)['value']
            self.assertEqual(0,status);self.assertTrue(result['actuation']['safe_no_actuation']);self.assertEqual(json.loads(encoded)['memory'],result['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in result['actuation']['ordered_commands']))


if __name__=='__main__':
    unittest.main()
