"""Actual V42 DLL on all retained V41 inputs; no alternate physical trajectory."""
import copy
import ctypes
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_candidate as candidate
import development_recovery_stance_latch_precheck as sketch
from test_development_v32_recontact_component import NativeApi
from test_development_v36_smooth_swing_component import request_bytes

POLICY='sporespore_balanced_wave_recovery_stance_latched_upright_v1'
PARENT='sporespore_balanced_wave_recovery_upright_stance_v1'
MEMORY='sporespore_balanced_wave_recovery_stance_latched_upright_memory_v1'
PARENT_MEMORY='sporespore_balanced_wave_recovery_upright_stance_memory_v1'
MODE='stance_latched_upright_reference_velocity_tracking_v1'
PROFILE=ROOT/'sdk/development/recovery_candidates/v42-stance-latch-v1.json'


class V42StanceLatch(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        closure=ROOT/'sdk/development/recovery_attempts/f4a08fa3230d4276869bb865c8c25a58.json'
        assert candidate.sha(closure)==sketch.data.CLOSURE_SHA
        cls.record=candidate.read(closure);report=Path(cls.record['kicked_report']['path'])
        assert candidate.sha(report)==sketch.data.REPORT_SHA
        cls.report=candidate.read(report);cls.entries=cls.report['development_walking_entry']['rows']
        assert len(cls.entries)==400
        cls.descriptor=cls.report['configuration']['base_descriptor'];upper=.35*cls.descriptor['upper_length_fraction']
        cls.dimensions=(upper,.35-upper,.04*cls.descriptor['foot_radius_scale'],cls.descriptor['hip_span_scale'])
        cls.profile=candidate.read(PROFILE);cls.binding=candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding=candidate.read(ROOT/'sdk/development/recovery_candidates/v41-upright-stance-v1.runtime.json')
        for binding in (cls.binding,cls.old_binding):
            for path in (Path(binding['runtime']['path']),ROOT/binding['local_build_path']):
                assert candidate.sha(path)==binding['runtime']['raw_sha256']
        cls.native=NativeApi(cls.binding['runtime']['path']);cls.old=NativeApi(cls.old_binding['runtime']['path'])

    def initial(self):
        status,result=self.native.call('ss_balanced_wave_policy_initial_memory_json',dict(
            schema_version='sporespore_balanced_wave_policy_initial_memory_request_v1',policy_id=POLICY,descriptor=self.descriptor))
        self.assertEqual(0,status);memory=result['value'];self.assertEqual(MEMORY,memory['schema_version'])
        for limb,before in zip(memory['ordered_limb_memory'],self.entries[0]['request']['memory']['ordered_limb_memory']):
            self.assertEqual(limb['limb_id'],before['limb_id'])
            for key in ('gait_step','evidence_gait_step_limit'):limb[key]=before[key]
        self.assertEqual([False]*4,[l['upright_reference_latched'] for l in memory['support_reference']['ordered_stance_latches']])
        return memory

    def request(self,entry,memory):
        return copy.deepcopy(dict(entry['request'],schema_version='sporespore_balanced_wave_policy_step_request_v2',
            descriptor=self.descriptor,policy_id=POLICY,memory=memory))

    def value(self,request,api=None):
        status,raw=(api or self.native).raw('ss_balanced_wave_policy_step_json',request_bytes(request))
        self.assertEqual(0,status);value=json.loads(raw)['value']
        self.assertFalse(value['actuation']['safe_no_actuation'],value['actuation']['receipt'].get('controller_error'))
        return raw,value

    def test_binding_profile_and_nonrunnable_component(self):
        self.assertEqual(337,self.binding['core_test_count'])
        self.assertEqual(candidate.sha(candidate.resource_path(self.profile['runtime_binding'])),self.profile['runtime_binding_sha256'])
        self.assertEqual(candidate.sha(candidate.resource_path(self.profile['extension'])),self.profile['extension_sha256'])
        for source in self.binding['source_files']:self.assertEqual(candidate.sha(ROOT/source['path']),source['raw_sha256'])
        with self.assertRaisesRegex(ValueError,'PROFILE_SCHEMA'):candidate.selection(candidate.reference_for_path(PROFILE))
        request=dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1',descriptor=self.descriptor,policy_id=POLICY)
        status,result=self.native.call('ss_balanced_wave_policy_profile_json',request);self.assertEqual(0,status)
        status,old=self.old.call('ss_balanced_wave_policy_profile_json',dict(request,policy_id=PARENT));self.assertEqual(0,status)
        self.assertEqual(dict(old['value'],policy_id=POLICY,schema_version='sporespore_balanced_wave_recovery_stance_latched_upright_profile_v1',reference_velocity_mode_id=MODE),result['value'])
        print('V42_EXPORTED_PROFILE',json.dumps(dict(profile=result['value'],native_profile_sha256='sha256:'+hashlib.sha256(self.native.canonical(result['value'])).hexdigest(),physical_selection_refused=True)),flush=True)

    def test_4400_old_outputs_and_six_recovery_fixtures_are_exact(self):
        policies=[(PARENT,PARENT_MEMORY,True,True,True)]
        for suffix in ('absent_contact_reference','airborne_reference','wave_velocity'):
            policies.append((f'sporespore_balanced_wave_recovery_{suffix}_v1',f'sporespore_balanced_wave_recovery_{suffix}_memory_v1',True,True,True))
        for suffix in ('reference_velocity','smooth_swing','feasible_support','floor_support'):
            policies.append((f'sporespore_balanced_wave_recovery_{suffix}_v1',f'sporespore_balanced_wave_recovery_{suffix}_memory_v1',True,True,False))
        policies.extend([('sporespore_balanced_wave_recovery_bounded_support_v1','sporespore_balanced_wave_recovery_support_memory_v1',False,True,False),
            ('sporespore_balanced_wave_recovery_swing_end_recontact_v1','sporespore_balanced_wave_memory_v1',False,False,False),
            ('sporespore_balanced_wave_bw5r_b_v1','sporespore_balanced_wave_memory_v1',False,False,False)])
        counts={};refusals={}
        for policy,schema,floor,support,wave in policies:
            counts[policy]=refusals[policy]=0
            for entry in self.entries:
                r=self.request(entry,entry['request']['memory']);r['policy_id']=policy;r['memory']['schema_version']=schema
                if not wave:r['memory']['support_reference'].pop('previous_wave',None)
                if not floor:
                    r['schema_version']='sporespore_balanced_wave_policy_step_request_v1';del r['floor_reference'];r['memory'].pop('floor_reference_sha256',None)
                if not support:del r['memory']['support_reference']
                a,expected=self.old.raw('ss_balanced_wave_policy_step_json',request_bytes(r))
                b,actual=self.native.raw('ss_balanced_wave_policy_step_json',request_bytes(r))
                self.assertEqual(0,a);self.assertEqual(a,b);self.assertTrue(expected==actual,f'{policy}:{entry["session_local_step"]}')
                self.assertNotIn(b'"stance_latch":',actual);self.assertNotIn(b'"ordered_stance_latches":',actual)
                value=json.loads(actual)['value'];counts[policy]+=1
                if value['actuation']['safe_no_actuation']:
                    self.assertEqual(r['memory'],value['next_memory']);refusals[policy]+=1
        fixtures=[]
        for binding in (self.old_binding,self.binding):
            p=Path(binding['compiled_fixtures']['path']);self.assertEqual(candidate.sha(p),binding['compiled_fixtures']['raw_sha256'])
            fixtures.append([line for line in p.read_text().splitlines() if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')])
        self.assertEqual(6,len(fixtures[0]));self.assertEqual(*fixtures)
        print('V42_OLD_OUTPUT_COMPATIBILITY',json.dumps(dict(exact_raw_outputs=sum(counts.values()),per_policy=counts,preserved_refusals_by_policy=refusals,exact_recovery_fixtures=6)),flush=True)

    def reconstruct(self,entry,memory,value):
        r=value['actuation']['receipt']['recovery_support_plane'];u=r['upright_stance'];w=r['wave_velocity'];latch=r['stance_latch']
        prior=memory['support_reference'].get('previous_wave');contacts=entry['request']['state']['ordered_contact_observations']
        actual_wave=entry['native_output']['actuation']['receipt']['recovery_support_plane']['wave_velocity']['current_wave']
        self.assertEqual('sporespore_recovery_stance_latched_upright_controller_step_receipt_v1',value['actuation']['receipt']['schema_version'])
        self.assertEqual(MODE,r['reference_velocity_mode_id']);self.assertNotIn('feasible_support_plan',r)
        self.assertEqual(prior,w['previous_wave']);self.assertEqual([0.,1.,0.],u['reference_anatomical_vertical_projections'])
        self.assertEqual(entry['request']['floor_reference'],u['source_floor_reference'])
        self.assertEqual(entry['request']['state']['semantic_step'],latch['source_semantic_step'])
        self.assertTrue(u['comparison_uses_current_selector']);mask=[]
        for i,limb in enumerate(latch['ordered_limbs']):
            phase=actual_wave['ordered_limbs'][i]['scheduled_phase_step'];old_phase=prior['ordered_limbs'][i]['scheduled_phase_step'] if prior else None
            old_active=prior['active'] if prior else False;incoming=memory['support_reference']['ordered_stance_latches'][i]
            chosen=sketch.select(actual_wave['active'],phase,contacts[i]['presence'],contacts[i]['bears_support'],old_active,old_phase,incoming['upright_reference_latched'])
            self.assertEqual(incoming['limb_id'],limb['limb_id']);self.assertEqual(contacts[i],limb['precommand_contact'])
            self.assertEqual(incoming['upright_reference_latched'],limb['incoming_upright_reference_latched'])
            self.assertEqual(old_active,limb['previous_wave_active']);self.assertEqual(old_phase,limb['previous_scheduled_phase_step'])
            self.assertEqual(phase,limb['current_scheduled_phase_step']);self.assertEqual(phase,w['current_wave']['ordered_limbs'][i]['scheduled_phase_step'])
            carry=incoming['upright_reference_latched'] and old_active and old_phase>72 and phase>=old_phase
            self.assertEqual(carry,limb['previous_latch_carry_eligible']);self.assertEqual(chosen,limb['next_upright_reference_latched'])
            self.assertEqual(chosen,u['ordered_limbs'][i]['upright_reference_selected'])
            self.assertEqual(dict(limb_id=limb['limb_id'],upright_reference_latched=chosen),value['next_memory']['support_reference']['ordered_stance_latches'][i])
            self.assertEqual(r['ordered_limb_proposals'][i],u['floor_upright_reference_proposals' if chosen else 'measured_pose_baseline_proposals'][i])
            mask.append(chosen)
        # The actual candidate's preceding wave is retained; no previous pose
        # or fabricated contact is substituted into the independent algebra.
        projected=copy.deepcopy(entry);projected['native_output']['actuation']['receipt']['recovery_support_plane']['wave_velocity']['previous_wave']=prior
        expected=sketch.command(projected,memory['support_reference']['ordered_target_positions_rad'],self.dimensions,mask)
        pose,wave=sketch.pre.cold.algebra.inputs(projected)
        goals,measured,upright,old_plan,new_plan=sketch.pre.goals(pose,wave,self.dimensions,mask)
        for name,plan in [('measured_pose_baseline_plan',old_plan),('floor_upright_reference_plan',new_plan)]:
            self.assertEqual(4,len(u[name]['ordered_limb_intervals']))
            for field,number in zip(('common_minimum_torso_height_m','common_maximum_torso_height_m','requested_stance_torso_height_m'),plan):self.assertAlmostEqual(number,u[name][field],delta=1e-12)
        maximum=0.
        for i,(a,b) in enumerate(zip(expected['motors'],value['actuation']['ordered_commands'])):
            for field,key in [('goal_rad','ordered_selected_goals_rad')]:self.assertAlmostEqual(a[field],u[key][i],delta=1e-12)
            self.assertAlmostEqual(a['target_rad'],b['requested_target_position_rad'],delta=1e-12)
            self.assertAlmostEqual(a['reference_rate_rad_s'],r['ordered_reference_velocity_rad_s'][i],delta=1e-10)
            error=abs(a['host_motor_velocity_rad_s']-b['target_velocity_rad_s']);maximum=max(maximum,error);self.assertLess(error,1e-10)
            self.assertEqual(a['saturated'],b['velocity_saturated']);self.assertEqual(b['slew_limited'],b['requested_target_position_rad']!=u['ordered_selected_goals_rad'][i])
            self.assertLessEqual(abs(b['target_velocity_rad_s']),b['maximum_target_speed_rad_s'])
        return mask,maximum

    def test_400_chained_stateful_stateless_and_one_command_outputs(self):
        create=self.native.library.ss_balanced_wave_policy_session_create_json
        create.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_uint64)];create.restype=ctypes.c_int
        data=request_bytes(dict(schema_version='sporespore_balanced_wave_policy_session_create_request_v1',descriptor=self.descriptor,policy_id=POLICY))
        handle=ctypes.c_uint64();self.assertEqual(0,create(data,len(data),ctypes.byref(handle)))
        step=self.native.library.ss_balanced_wave_policy_session_step_json
        step.argtypes=[ctypes.c_uint64,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_size_t)];step.restype=ctypes.c_int
        destroy=self.native.library.ss_balanced_wave_policy_session_destroy;destroy.argtypes=[ctypes.c_uint64];destroy.restype=ctypes.c_int
        memory=self.initial();chain=hashlib.sha256();prior_mask=None;max_error=0.
        counts=dict(commands=0,selector_transitions=0,selected_limb_inputs=0,carried_absent_limb_inputs=0,chained_clipped=0,one_command_clipped=0)
        try:
            for entry in self.entries:
                request=self.request(entry,memory);raw,value=self.value(request);chain.update(raw)
                sr={k:v for k,v in request.items() if k not in ('descriptor','policy_id')};sr['schema_version']='sporespore_balanced_wave_policy_session_step_request_v2'
                data=request_bytes(sr);size=ctypes.c_size_t();step(handle,data,len(data),None,0,ctypes.byref(size))
                self.assertTrue(0<size.value<2_000_000);buffer=ctypes.create_string_buffer(size.value)
                self.assertEqual(0,step(handle,data,len(data),buffer,size.value,ctypes.byref(size)));self.assertTrue(raw==buffer.raw[:size.value])
                mask,error=self.reconstruct(entry,memory,value);max_error=max(max_error,error)
                parent=copy.deepcopy(request);parent['policy_id']=PARENT;parent['memory']['schema_version']=PARENT_MEMORY;parent['memory']['support_reference'].pop('ordered_stance_latches')
                _,before=self.value(parent,self.old);expected=copy.deepcopy(before['next_memory']);expected['schema_version']=MEMORY
                expected['support_reference']['ordered_target_positions_rad']=value['next_memory']['support_reference']['ordered_target_positions_rad']
                expected['support_reference']['ordered_stance_latches']=value['next_memory']['support_reference']['ordered_stance_latches'];self.assertEqual(expected,value['next_memory'])
                one_memory=copy.deepcopy(entry['request']['memory']);one_memory['schema_version']=MEMORY
                one_memory['support_reference']['ordered_stance_latches']=copy.deepcopy(memory['support_reference']['ordered_stance_latches'])
                _,one=self.value(self.request(entry,one_memory));_,error=self.reconstruct(entry,one_memory,one);max_error=max(max_error,error)
                old_mask=[x['upright_reference_selected'] for x in before['actuation']['receipt']['recovery_support_plane']['upright_stance']['ordered_limbs']]
                for i,(a,b) in enumerate(zip(value['actuation']['ordered_commands'],before['actuation']['ordered_commands'])):
                    if mask[i//2]==old_mask[i//2]:self.assertEqual(a,b)
                counts['commands']+=1;counts['selected_limb_inputs']+=sum(mask)
                counts['carried_absent_limb_inputs']+=sum(m and not c['presence'] for m,c in zip(mask,entry['request']['state']['ordered_contact_observations']))
                counts['selector_transitions']+=sum(a!=b for a,b in zip(mask,prior_mask)) if prior_mask is not None else 0
                counts['chained_clipped']+=sum(c['velocity_saturated'] for c in value['actuation']['ordered_commands'])
                counts['one_command_clipped']+=sum(c['velocity_saturated'] for c in one['actuation']['ordered_commands'])
                prior_mask=mask;memory=value['next_memory']
        finally:self.assertEqual(0,destroy(handle))
        self.assertEqual((400,11,1253,310),(counts['commands'],counts['selector_transitions'],counts['selected_limb_inputs'],counts['carried_absent_limb_inputs']))
        print('V42_NATIVE_RETAINED_INPUT_CHECK',json.dumps(dict(**counts,maximum_motor_error_rad_s=max_error,raw_output_chain_sha256='sha256:'+chain.hexdigest(),world_build_count=0,solver_step_count=0,new_physical_trajectory=False)),flush=True)

    def test_malformed_crossed_and_missing_memory_contact_and_floor_refuse(self):
        first=self.request(self.entries[0],self.initial());_,out=self.value(first);memory=out['next_memory'];negatives=[]
        for kind in ('missing','count','order','identity','crossed','wave','contact_missing','contact_contradictory','floor','clock'):
            r=self.request(self.entries[1],memory);s=r['memory']['support_reference']
            if kind=='missing':s.pop('ordered_stance_latches')
            elif kind=='count':s['ordered_stance_latches'].pop()
            elif kind=='order':s['ordered_stance_latches'][0],s['ordered_stance_latches'][1]=s['ordered_stance_latches'][1],s['ordered_stance_latches'][0]
            elif kind=='identity':s['ordered_stance_latches'][0]['limb_id']='other'
            elif kind=='crossed':r['memory']['schema_version']=PARENT_MEMORY
            elif kind=='wave':s.pop('previous_wave')
            elif kind=='contact_missing':r['state']['ordered_contact_observations'][0]['presence']=None
            elif kind=='contact_contradictory':r['state']['ordered_contact_observations'][0].update(presence=False,bears_support=True)
            elif kind=='floor':r['floor_reference']['source_instance_id']='another_world'
            else:r['state']['sample_time_s']=first['state']['sample_time_s']
            negatives.append(r)
        r=copy.deepcopy(first);r['memory']['support_reference']['ordered_stance_latches'][0]['upright_reference_latched']=True;negatives.append(r)
        for r in negatives:
            status,raw=self.native.raw('ss_balanced_wave_policy_step_json',request_bytes(r));self.assertEqual(0,status);value=json.loads(raw)['value']
            self.assertTrue(value['actuation']['safe_no_actuation']);self.assertEqual(r['memory'],value['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0. for c in value['actuation']['ordered_commands']))
        for invalid in (1,'false',None):
            r=self.request(self.entries[1],memory);r['memory']['support_reference']['ordered_stance_latches'][0]['upright_reference_latched']=invalid
            self.assertNotEqual(0,self.native.raw('ss_balanced_wave_policy_step_json',request_bytes(r))[0])
        print('V42_NATIVE_NEGATIVE_CONTROLS',json.dumps(dict(safe_refusals_with_unchanged_memory=len(negatives),malformed_transport_refusals=3)),flush=True)


if __name__=='__main__':unittest.main()
