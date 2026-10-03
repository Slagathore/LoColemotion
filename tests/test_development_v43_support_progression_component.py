"""V43 exported native component checks. No new physical trajectory.

One-command substitutions cover all 400 V42 inputs. Chained-memory execution
stops at its first refusal, if any; it never splices or resets past a failure.
"""
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
import development_recovery_v42_relocation_diagnosis as diagnosis
from test_development_v32_recontact_component import NativeApi
from test_development_v36_smooth_swing_component import request_bytes
import test_development_v42_stance_latch_component as v42_checks

POLICY='sporespore_balanced_wave_recovery_support_progression_v1'
MEMORY='sporespore_balanced_wave_recovery_support_progression_memory_v1'
PARENT='sporespore_balanced_wave_recovery_stance_latched_upright_v1'
PARENT_MEMORY='sporespore_balanced_wave_recovery_stance_latched_upright_memory_v1'
RECEIPT='sporespore_recovery_support_progression_controller_step_receipt_v1'
PROFILE=ROOT/'sdk/development/recovery_candidates/v43-support-progression-v1.json'


class Session:
    def __init__(self, api, descriptor, policy=POLICY):
        lib=api.library
        create=lib.ss_balanced_wave_policy_session_create_json
        create.argtypes=[ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_uint64)];create.restype=ctypes.c_int
        raw=request_bytes(dict(schema_version='sporespore_balanced_wave_policy_session_create_request_v1',descriptor=descriptor,policy_id=policy))
        self.handle=ctypes.c_uint64()
        if create(raw,len(raw),ctypes.byref(self.handle))!=0: raise AssertionError('V43_SESSION_CREATE')
        self.step=lib.ss_balanced_wave_policy_session_step_json
        self.step.argtypes=[ctypes.c_uint64,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.POINTER(ctypes.c_size_t)]
        self.step.restype=ctypes.c_int
        self.destroy=lib.ss_balanced_wave_policy_session_destroy
        self.destroy.argtypes=[ctypes.c_uint64];self.destroy.restype=ctypes.c_int

    def raw(self, request):
        r={k:v for k,v in request.items() if k not in ('descriptor','policy_id')}
        r['schema_version']='sporespore_balanced_wave_policy_session_step_request_v2'
        raw=request_bytes(r);size=ctypes.c_size_t()
        self.step(self.handle,raw,len(raw),None,0,ctypes.byref(size))
        if not 0<size.value<2_000_000: raise AssertionError('V43_SESSION_BUFFER')
        out=ctypes.create_string_buffer(size.value)
        status=self.step(self.handle,raw,len(raw),out,size.value,ctypes.byref(size))
        if status!=0: raise AssertionError('V43_SESSION_STEP')
        return out.raw[:size.value]

    def close(self):
        if self.destroy(self.handle)!=0: raise AssertionError('V43_SESSION_DESTROY')


class SupportProgression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        closure=ROOT/'sdk/development/recovery_attempts'/f'{diagnosis.ATTEMPT}.json'
        assert candidate.sha(closure)==diagnosis.CLOSURE_SHA
        cls.record=candidate.read(closure);path=Path(cls.record['kicked_report']['path'])
        assert candidate.sha(path)==diagnosis.REPORT_SHA
        cls.report=candidate.read(path);cls.entries=cls.report['development_walking_entry']['rows']
        assert len(cls.entries)==400
        cls.descriptor=cls.report['configuration']['base_descriptor'];upper=.35*cls.descriptor['upper_length_fraction']
        cls.dimensions=(upper,.35-upper,.04*cls.descriptor['foot_radius_scale'],cls.descriptor['hip_span_scale'])
        cls.profile=candidate.read(PROFILE);cls.binding=candidate.read(candidate.resource_path(cls.profile['runtime_binding']))
        cls.old_binding=candidate.read(ROOT/'sdk/development/recovery_candidates/v42-stance-latch-v1.runtime.json')
        for binding in (cls.binding,cls.old_binding):
            for p in (Path(binding['runtime']['path']),ROOT/binding['local_build_path']):
                assert candidate.sha(p)==binding['runtime']['raw_sha256']
        cls.native=NativeApi(cls.binding['runtime']['path']);cls.old=NativeApi(cls.old_binding['runtime']['path'])

    def request(self, entry, memory):
        return copy.deepcopy(dict(entry['request'],schema_version='sporespore_balanced_wave_policy_step_request_v2',
            descriptor=self.descriptor,policy_id=POLICY,memory=memory))

    def one_memory(self, entry):
        return copy.deepcopy(dict(entry['request']['memory'],schema_version=MEMORY,
            support_progression=dict(held_steps=0,clear_dwell_steps=0)))

    def call(self, request, api=None):
        status,raw=(api or self.native).raw('ss_balanced_wave_policy_step_json',request_bytes(request))
        self.assertEqual(0,status)
        return raw,json.loads(raw)['value']

    def check_output(self, entry, request, value):
        memory=request['memory'];parent=copy.deepcopy(request)
        parent['policy_id']=PARENT;parent['memory']['schema_version']=PARENT_MEMORY
        parent['memory'].pop('support_progression')
        _,preview=self.call(parent,self.old)
        self.assertFalse(preview['actuation']['safe_no_actuation'])
        def phases(m):
            return {l['limb_id']:(l['gait_step']+360-i*90)%360 for i,l in enumerate(m['ordered_limb_memory'])}
        old_phase,new_phase=phases(memory),phases(preview['next_memory'])
        contacts=request['state']['ordered_contact_observations']
        missing=[c['contact_site_id'].removesuffix('_foot') for c in contacts
            if new_phase[c['contact_site_id'].removesuffix('_foot')]>72 and not (c['presence'] and c['bears_support'])]
        enabled=request['command']['gait_amplitude']!=0 and any(old_phase[l]<=72 or new_phase[l]<=72 for l in old_phase)
        before=memory['support_progression'];clear=before['clear_dwell_steps']+1 if not missing else 0
        held=enabled and (bool(missing) or (before['held_steps']>0 and clear<3))
        timeout=held and before['held_steps']==120
        self.assertEqual(timeout,value['actuation']['safe_no_actuation'])
        if timeout:
            self.assertIn('support_progression_hold_timeout',value['actuation']['receipt']['controller_error'])
            self.assertEqual(memory,value['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in value['actuation']['ordered_commands']))
            return dict(held=True,timeout=True,motor_error=0.)
        self.assertEqual(RECEIPT,value['actuation']['receipt']['schema_version'])
        r=value['actuation']['receipt']['recovery_support_plane']['support_progression']
        next_counter=dict(held_steps=before['held_steps']+1,clear_dwell_steps=clear) if held else dict(held_steps=0,clear_dwell_steps=0)
        self.assertEqual((enabled,held,missing,before,next_counter),(r['enabled'],r['phase_progression_held'],r['missing_support_limb_ids'],r['incoming_memory'],r['next_memory']))
        self.assertEqual(next_counter,value['next_memory']['support_progression'])
        self.assertEqual((3,120),(r['minimum_clear_dwell_steps'],r['maximum_held_commands']))
        self.assertEqual(request['state']['semantic_step'],r['source_semantic_step'])
        for limb,c in zip(r['ordered_limbs'],contacts):
            l=limb['limb_id'];self.assertEqual(c,limb['precommand_contact'])
            self.assertEqual((old_phase[l],new_phase[l],old_phase[l] if held else new_phase[l]),
                (limb['incoming_phase'],limb['proposed_phase'],limb['selected_phase']))
            self.assertEqual(limb['selected_phase'],phases(value['next_memory'])[l])
        if held:
            for a,b,p in zip(value['next_memory']['ordered_limb_memory'],memory['ordered_limb_memory'],preview['next_memory']['ordered_limb_memory']):
                self.assertEqual(dict(b,evidence_gait_step_limit=p['evidence_gait_step_limit']),a)
        else:
            self.assertEqual(preview['actuation']['ordered_commands'],value['actuation']['ordered_commands'])
            self.assertEqual(preview['next_memory']['ordered_limb_memory'],value['next_memory']['ordered_limb_memory'])
        # V43 changes scheduling, not V42's downstream math. Reuse its cold
        # arithmetic checker on the ACTUAL V43 wave and explicit memory. The
        # schema alias is test-local, after the distinct V43 receipt is checked.
        projected=copy.deepcopy(entry);projected['request']=request;projected['native_output']=copy.deepcopy(value)
        math_value=copy.deepcopy(value)
        math_value['actuation']['receipt']['schema_version']='sporespore_recovery_stance_latched_upright_controller_step_receipt_v1'
        _,error=v42_checks.V42StanceLatch.reconstruct(self,projected,memory,math_value)
        self.assertEqual('sha256:'+hashlib.sha256(self.native.canonical(value['actuation']['receipt'])).hexdigest(),value['actuation']['receipt_sha256'])
        return dict(held=held,timeout=False,motor_error=error)

    def test_binding_profile_and_nonrunnable_component(self):
        self.assertEqual(342,self.binding['core_test_count'])
        for p in self.binding['source_files']:self.assertEqual(candidate.sha(ROOT/p['path']),p['raw_sha256'])
        self.assertEqual(candidate.sha(candidate.resource_path(self.profile['runtime_binding'])),self.profile['runtime_binding_sha256'])
        self.assertEqual(candidate.sha(candidate.resource_path(self.profile['extension'])),self.profile['extension_sha256'])
        with self.assertRaisesRegex(ValueError,'PROFILE_SCHEMA'):candidate.selection(candidate.reference_for_path(PROFILE))
        r=dict(schema_version='sporespore_balanced_wave_policy_profile_request_v1',descriptor=self.descriptor,policy_id=POLICY)
        status,new=self.native.call('ss_balanced_wave_policy_profile_json',r);self.assertEqual(0,status)
        status,old=self.old.call('ss_balanced_wave_policy_profile_json',dict(r,policy_id=PARENT));self.assertEqual(0,status)
        self.assertEqual(dict(old['value'],policy_id=POLICY,schema_version='sporespore_balanced_wave_recovery_support_progression_profile_v1',
            support_progression_mode_id='truthful_stance_support_bounded_phase_hold_v1'),new['value'])
        print('V43_NATIVE_PROFILE',json.dumps(new['value']),flush=True)

    def test_4800_older_outputs_and_six_recovery_fixtures_are_exact(self):
        families=['stance_latched_upright','upright_stance','absent_contact_reference','airborne_reference','wave_velocity','reference_velocity','smooth_swing','feasible_support','floor_support']
        policies=[(f'sporespore_balanced_wave_recovery_{f}_v1',f'sporespore_balanced_wave_recovery_{f}_memory_v1',True,True,i<5,i==0) for i,f in enumerate(families)]
        policies.extend([('sporespore_balanced_wave_recovery_bounded_support_v1','sporespore_balanced_wave_recovery_support_memory_v1',False,True,False,False),
            ('sporespore_balanced_wave_recovery_swing_end_recontact_v1','sporespore_balanced_wave_memory_v1',False,False,False,False),
            ('sporespore_balanced_wave_bw5r_b_v1','sporespore_balanced_wave_memory_v1',False,False,False,False)])
        counts={};refusals={}
        for policy,schema,floor,support,wave,latch in policies:
            counts[policy]=refusals[policy]=0
            for entry in self.entries:
                r=self.request(entry,entry['request']['memory']);r['policy_id']=policy;r['memory']['schema_version']=schema
                if not latch:r['memory']['support_reference'].pop('ordered_stance_latches')
                if not wave:r['memory']['support_reference'].pop('previous_wave',None)
                if not floor:
                    r['schema_version']='sporespore_balanced_wave_policy_step_request_v1';r.pop('floor_reference');r['memory'].pop('floor_reference_sha256',None)
                if not support:r['memory'].pop('support_reference')
                expected,before=self.call(r,self.old);actual,after=self.call(r)
                self.assertEqual(expected,actual);self.assertNotIn(b'"support_progression":',actual)
                counts[policy]+=1;refusals[policy]+=after['actuation']['safe_no_actuation']
        fixtures=[]
        for binding in (self.old_binding,self.binding):
            p=Path(binding['compiled_fixtures']['path']);self.assertEqual(candidate.sha(p),binding['compiled_fixtures']['raw_sha256'])
            fixtures.append([l for l in p.read_text().splitlines() if l.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')])
        self.assertEqual(6,len(fixtures[0]));self.assertEqual(*fixtures)
        print('V43_OLD_COMPATIBILITY',json.dumps(dict(exact_raw_outputs=sum(counts.values()),per_policy=counts,preserved_refusals=refusals,exact_recovery_fixtures=6)),flush=True)

    def test_all_saved_inputs_and_chained_memory_through_native_interfaces(self):
        counts=dict(one_command_inputs=0,one_command_holds=0,chained_valid_commands=0,chained_holds=0,maximum_motor_error_rad_s=0.)
        session=Session(self.native,self.descriptor);digests=[hashlib.sha256(),hashlib.sha256()]
        try:
            for entry in self.entries:
                request=self.request(entry,self.one_memory(entry));raw,value=self.call(request)
                self.assertEqual(raw,session.raw(request));digests[0].update(raw)
                checked=self.check_output(entry,request,value);self.assertFalse(checked['timeout'])
                counts['one_command_inputs']+=1;counts['one_command_holds']+=checked['held']
                counts['maximum_motor_error_rad_s']=max(counts['maximum_motor_error_rad_s'],checked['motor_error'])
        finally:session.close()
        memory=self.one_memory(self.entries[0]);session=Session(self.native,self.descriptor);refusal=None
        try:
            for entry in self.entries:
                request=self.request(entry,memory);raw,value=self.call(request)
                self.assertEqual(raw,session.raw(request));digests[1].update(raw)
                checked=self.check_output(entry,request,value)
                if checked['timeout']:
                    refusal=dict(local_step=entry['session_local_step'],request=request,native_output=value)
                    break
                counts['chained_valid_commands']+=1;counts['chained_holds']+=checked['held']
                counts['maximum_motor_error_rad_s']=max(counts['maximum_motor_error_rad_s'],checked['motor_error'])
                memory=value['next_memory']
        finally:session.close()
        self.assertEqual(400,counts['one_command_inputs']);self.assertGreater(counts['one_command_holds'],0)
        self.assertEqual(400 if refusal is None else refusal['local_step']-1,counts['chained_valid_commands'])
        print('V43_NATIVE_SAVED_INPUTS',json.dumps(dict(**counts,one_command_raw_chain_sha256='sha256:'+digests[0].hexdigest(),
            chained_raw_chain_sha256='sha256:'+digests[1].hexdigest(),first_refusal_local_step=None if refusal is None else refusal['local_step'],
            new_physical_trajectory=False,world_build_count=0,solver_step_count=0)),flush=True)
        if refusal is not None:print('V43_NATIVE_CHAIN_REFUSAL',json.dumps(refusal),flush=True)

    def test_missing_crossed_malformed_and_timeout_inputs_refuse(self):
        entry=self.entries[364];cases=[]
        for kind in ('missing','too_long','dwell','dwell_without_hold','timeout','contact','contradiction','floor','crossed'):
            r=self.request(entry,self.one_memory(entry));g=r['memory']['support_progression']
            if kind=='missing':r['memory'].pop('support_progression')
            elif kind=='too_long':g['held_steps']=121
            elif kind=='dwell':g.update(held_steps=5,clear_dwell_steps=3)
            elif kind=='dwell_without_hold':g['clear_dwell_steps']=1
            elif kind=='timeout':g['held_steps']=120
            elif kind=='contact':r['state']['ordered_contact_observations'][1]['presence']=None
            elif kind=='contradiction':r['state']['ordered_contact_observations'][1].update(presence=False,bears_support=True)
            elif kind=='floor':r['floor_reference']['source_instance_id']='crossed'
            else:r['policy_id']=PARENT;r['memory']['schema_version']=PARENT_MEMORY
            _,value=self.call(r);self.assertTrue(value['actuation']['safe_no_actuation'],kind)
            self.assertEqual(r['memory'],value['next_memory']);self.assertTrue(all(c['target_velocity_rad_s']==0 for c in value['actuation']['ordered_commands']))
            cases.append(kind)
        for invalid in (-1,1.5,'1',True):
            r=self.request(entry,self.one_memory(entry));r['memory']['support_progression']['held_steps']=invalid
            self.assertNotEqual(0,self.native.raw('ss_balanced_wave_policy_step_json',request_bytes(r))[0])
        print('V43_NATIVE_REFUSAL_CHECKS',json.dumps(dict(safe_refusals=cases,malformed_transport_refusals=4)),flush=True)


if __name__=='__main__':unittest.main()
