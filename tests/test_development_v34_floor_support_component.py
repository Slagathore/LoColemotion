"""Actual V34 exports on retained inputs; no alternative physical trajectory."""
import copy
import ctypes
import hashlib
import json
import math
import sys
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_v33_support_tracking_diagnosis as geometry
from test_development_v32_recontact_component import NativeApi

POLICY='sporespore_balanced_wave_recovery_floor_support_v1'
PREVIOUS='sporespore_balanced_wave_recovery_bounded_support_v1'
PROFILE=ROOT/'sdk/development/recovery_candidates/v34-floor-support-v1.json'


class V34FloorSupport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.closure=candidate.read(ROOT/'sdk/development/recovery_attempts/4e5cacbc49e64ceab61fff2762217804.json')
        report_path=Path(cls.closure['kicked_report']['path'])
        if candidate.sha(report_path)!=cls.closure['kicked_report']['raw_sha256']:
            raise AssertionError('V34_RETAINED_REPORT_DRIFT')
        cls.report=candidate.read(report_path)
        cls.descriptor=cls.report['configuration']['base_descriptor']
        cls.entries=cls.report['development_walking_entry']['rows']
        cls.profile=candidate.read(PROFILE)
        cls.binding=candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding=candidate.read(ROOT/'sdk/development/recovery_candidates/v33-bounded-support-v1.runtime.json')
        for binding in (cls.binding,cls.old_binding):
            for path in (Path(binding['runtime']['path']),ROOT/binding['local_build_path']):
                if candidate.sha(path)!=binding['runtime']['raw_sha256']:
                    raise AssertionError('V34_DLL_DRIFT')
        cls.native=NativeApi(cls.binding['runtime']['path'])
        cls.old=NativeApi(cls.old_binding['runtime']['path'])
        cls.floor=dict(schema_version='sporespore_static_horizontal_floor_reference_v1',
            frame_id='sporespore_state_world_y_up_metres_v1',surface_id='floor',
            source_instance_id='component_fixture_not_native_geometry_binding',
            source_kind='declared_static_horizontal_surface',
            geometry_source_sha256='sha256:'+hashlib.sha256(cls.native.canonical(dict(
                fixture='horizontal_top_surface_for_retained_input_probe',height_world_m=0.))).hexdigest(),height_world_m=0.)

    def initial(self):
        status,r=self.native.call('ss_balanced_wave_policy_initial_memory_json',dict(
            schema_version='sporespore_balanced_wave_policy_initial_memory_request_v1',policy_id=POLICY,descriptor=self.descriptor))
        self.assertEqual(0,status)
        memory=r['value']
        for new,old in zip(memory['ordered_limb_memory'],self.entries[0]['request']['memory']['ordered_limb_memory']):
            self.assertEqual(new['limb_id'],old['limb_id'])
            new['gait_step']=old['gait_step']; new['evidence_gait_step_limit']=old['evidence_gait_step_limit']
        return memory

    def request(self,entry,memory):
        return dict(entry['request'],schema_version='sporespore_balanced_wave_policy_step_request_v2',
                    policy_id=POLICY,descriptor=self.descriptor,memory=memory,floor_reference=self.floor)

    def test_component_binding_profile_and_physical_selection_refusal(self):
        self.assertEqual(303,self.binding['core_test_count'])
        self.assertEqual(self.profile['runtime_binding_sha256'],candidate.sha(candidate.resource_path(self.profile['runtime_binding'])))
        for source in self.binding['source_files']:
            self.assertEqual(source['raw_sha256'],candidate.sha(ROOT/source['path']),source['path'])
        with self.assertRaisesRegex(ValueError,'PROFILE_SCHEMA'):
            candidate.selection(candidate.reference_for_path(PROFILE))
        status,response=self.native.call('ss_balanced_wave_policy_profile_json',dict(
            schema_version='sporespore_balanced_wave_policy_profile_request_v1',descriptor=self.descriptor,policy_id=POLICY))
        self.assertEqual(0,status)
        profile=response['value']
        self.assertEqual('explicit_horizontal_floor_bounded_support_reference_slew_v1',profile['stance_support_mode_id'])
        self.assertEqual('scheduled_swing_end_recontact_v1',profile['recontact_gate_mode_id'])
        print('V34_EXPORTED_PROFILE',json.dumps(dict(profile=profile,native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(profile)).hexdigest(),physical_selection_refused=True)),flush=True)

    def test_all_old_policy_outputs_and_recovery_fixtures_remain_exact(self):
        counts={}
        for policy in (PREVIOUS,'sporespore_balanced_wave_recovery_swing_end_recontact_v1','sporespore_balanced_wave_bw5r_b_v1'):
            counts[policy]=0
            for entry in self.entries:
                request=copy.deepcopy(dict(entry['request'],schema_version='sporespore_balanced_wave_policy_step_request_v1',policy_id=policy,descriptor=self.descriptor))
                if policy!=PREVIOUS:
                    # Compatibility probes on these inputs, not an old-policy
                    # physical trajectory. Select the actual old memory shape.
                    del request['memory']['support_reference']
                    request['memory']['schema_version']='sporespore_balanced_wave_memory_v1'
                encoded=self.old.canonical(request)
                expected=self.old.raw('ss_balanced_wave_policy_step_json',encoded)
                self.assertEqual(0,expected[0])
                self.assertFalse(json.loads(expected[1])['value']['actuation']['safe_no_actuation'])
                self.assertEqual(expected,self.native.raw('ss_balanced_wave_policy_step_json',encoded))
                counts[policy]+=1
        def fixtures(binding):
            path=Path(binding['compiled_fixtures']['path'])
            self.assertEqual(binding['compiled_fixtures']['raw_sha256'],candidate.sha(path))
            return [line for line in path.read_text().splitlines() if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
        old,new=fixtures(self.old_binding),fixtures(self.binding)
        self.assertEqual(6,len(old)); self.assertEqual(old,new)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            candidate.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))
        print('V34_LEGACY_COMPATIBILITY',json.dumps(dict(exact_old_policy_raw_output_count=sum(counts.values()),policy_counts=counts,exact_recovery_fixture_matches=6,old_physical_records_changed=False)),flush=True)

    def test_all_400_commands_match_session_path_and_independent_floor_geometry(self):
        create=self.native.library.ss_balanced_wave_policy_session_create_json
        create.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_uint64)]; create.restype=ctypes.c_int
        data=self.native.canonical(dict(schema_version='sporespore_balanced_wave_policy_session_create_request_v1',descriptor=self.descriptor,policy_id=POLICY))
        handle=ctypes.c_uint64(); self.assertEqual(0,create(data,len(data),ctypes.byref(handle)))
        session=self.native.library.ss_balanced_wave_policy_session_step_json
        session.argtypes=[ctypes.c_uint64,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_size_t)]
        session.restype=ctypes.c_int
        destroy=self.native.library.ss_balanced_wave_policy_session_destroy; destroy.argtypes=[ctypes.c_uint64]; destroy.restype=ctypes.c_int
        memory=self.initial(); chain=hashlib.sha256(); projected=slew=0; maximum_residual=0.
        upper=.35*self.descriptor['upper_length_fraction']
        dimensions=(upper,.35-upper,.04*self.descriptor['foot_radius_scale'],self.descriptor['hip_span_scale'])
        try:
            for entry in self.entries:
                request=self.request(entry,memory)
                status,raw=self.native.raw('ss_balanced_wave_policy_step_json',self.native.canonical(request))
                self.assertEqual(0,status); chain.update(raw)
                value=json.loads(raw)['value']
                self.assertFalse(value['actuation']['safe_no_actuation'],value['actuation']['receipt']['controller_error'])
                session_request={k:v for k,v in request.items() if k not in ('policy_id','descriptor')}
                session_request['schema_version']='sporespore_balanced_wave_policy_session_step_request_v2'
                data=self.native.canonical(session_request); size=ctypes.c_size_t()
                session(handle,data,len(data),None,0,ctypes.byref(size))
                self.assertTrue(0<size.value<2_000_000)
                output=ctypes.create_string_buffer(size.value)
                self.assertEqual(0,session(handle,data,len(data),output,size.value,ctypes.byref(size)))
                self.assertEqual(raw,output.raw[:size.value])
                receipt=value['actuation']['receipt']['recovery_support_plane']
                self.assertEqual(self.floor,receipt['floor_reference'])
                self.assertEqual('sha256:'+hashlib.sha256(self.native.canonical(self.floor)).hexdigest(),value['next_memory']['floor_reference_sha256'])
                self.assertEqual(entry['native_output']['next_memory']['ordered_limb_memory'],value['next_memory']['ordered_limb_memory'])
                q=request['state']['base_pose_world']['orientation_xyzw']; s=math.sqrt(.5)
                pose=dict(position_m=request['state']['base_pose_world']['position_m'],orientation_xyzw=dict(
                    x=s*(q['x']+q['z']),y=s*(q['y']-q['w']),z=s*(q['z']-q['x']),w=s*(q['w']+q['y'])))
                for p in receipt['ordered_limb_proposals']:
                    expected=geometry.floor_referenced_target(pose,p['limb_id'],p['nominal_leg_direction_rad'],dimensions,self.floor['height_world_m'])
                    self.assertAlmostEqual(expected['hip_rad'],p['projected_support_hip_rad'],delta=1e-7)
                    self.assertAlmostEqual(expected['knee_rad'],p['projected_support_knee_rad'],delta=1e-7)
                    self.assertAlmostEqual(expected['nominal_floor_residual_m'],p['projected_support_nominal_plane_residual_m'],places=13)
                    self.assertEqual(expected['link_reach_projection_required'],p['link_reach_projection_required'])
                    projected+=p['link_reach_projection_required']
                    maximum_residual=max(maximum_residual,abs(p['projected_support_nominal_plane_residual_m']))
                for i,c in enumerate(value['actuation']['ordered_commands']):
                    lo,hi=(-.72,.72) if i%2==0 else (0.,1.1)
                    self.assertTrue(lo<=c['requested_target_position_rad']<=hi)
                    self.assertLessEqual(abs(c['requested_target_position_rad']-memory['support_reference']['ordered_target_positions_rad'][i]),c['maximum_target_speed_rad_s']*receipt['reference_step_duration_s']+1e-14)
                    self.assertFalse(c['position_saturated']); slew+=c['slew_limited']
                    if entry['session_local_step']==1: self.assertEqual(0,c['requested_target_position_rad'])
                self.assertFalse(receipt['all_limb_contact_claim']); memory=value['next_memory']
        finally:
            self.assertEqual(0,destroy(handle))
        print('V34_RETAINED_INPUT_PROBE',json.dumps(dict(input_count=400,command_count=3200,exact_session_stateless_matches=400,
            raw_output_chain_sha256='sha256:'+chain.hexdigest(),link_reach_projection_count=projected,
            slew_limited_command_count=slew,maximum_nominal_support_residual_m=maximum_residual,
            native_floor_producer_exercised=False,new_physical_trajectory=False,world_build_count=0,solver_step_count=0)),flush=True)

    def test_request_versions_null_frames_and_changed_context_refuse(self):
        first=self.request(self.entries[0],self.initial())
        raw_variants=[]
        bad=copy.deepcopy(first); bad['schema_version']='sporespore_balanced_wave_policy_step_request_v1'; raw_variants.append(bad)
        bad=copy.deepcopy(first); del bad['floor_reference']; raw_variants.append(bad)
        bad=copy.deepcopy(first); bad['floor_reference']=None; raw_variants.append(bad)
        bad=copy.deepcopy(first); bad['floor_reference']['unexpected']=True; raw_variants.append(bad)
        for bad in raw_variants:
            status,raw=self.native.raw('ss_balanced_wave_policy_step_json',self.native.canonical(bad))
            response=json.loads(raw)
            self.assertNotEqual(0,status); self.assertFalse(response['ok'])
        _,raw=self.native.raw('ss_balanced_wave_policy_step_json',self.native.canonical(first))
        memory=json.loads(raw)['value']['next_memory']; next_request=self.request(self.entries[1],memory)
        variants=[]
        for key,value in [('height_world_m',1.),('frame_id','body_local'),('source_instance_id','crossed_world'),('geometry_source_sha256','bad')]:
            bad=copy.deepcopy(next_request); bad['floor_reference'][key]=value; variants.append(bad)
        bad=copy.deepcopy(next_request); bad['policy_id']=PREVIOUS; variants.append(bad)
        for bad in variants:
            encoded=self.native.canonical(bad)
            status,raw=self.native.raw('ss_balanced_wave_policy_step_json',encoded)
            self.assertEqual(0,status); value=json.loads(raw)['value']
            self.assertTrue(value['actuation']['safe_no_actuation'])
            # Compare to the actual encoded input, not a pre-transport float
            # that canonical number projection may legitimately change.
            self.assertEqual(json.loads(encoded)['memory'],value['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in value['actuation']['ordered_commands']))
        print('V34_EXPORTED_REFUSALS',json.dumps(dict(parser_refusals=len(raw_variants),safe_no_actuation_refusals=len(variants))),flush=True)


if __name__=='__main__':
    unittest.main()
