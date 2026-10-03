"""Real C ABI and Python SDK checks on retained measurements; zero worlds."""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'sdk/conformance'),str(ROOT/'sdk/python')]
import development_recovery_v44_support_diagnosis as source
from sporespore_locomotion import LocomotionCore, LocomotionCoreError
from test_development_v32_recontact_component import NativeApi
from test_development_v36_smooth_swing_component import request_bytes

POLICY='sporespore_balanced_wave_recovery_measured_support_transfer_v1'
MEMORY='sporespore_balanced_wave_recovery_measured_support_transfer_memory_v1'

def integer_tokens(value):
    if isinstance(value,dict):return {k:integer_tokens(v) for k,v in value.items()}
    if isinstance(value,list):return [integer_tokens(v) for v in value]
    if type(value) is float and 0<=value<2**53 and value.is_integer() and str(value)!='-0.0':return int(value)
    return value

def request_for(row,descriptor,memory=None):
    request=copy.deepcopy(dict(row['request'],descriptor=descriptor,policy_id=POLICY,
        schema_version='sporespore_balanced_wave_policy_step_request_v3'))
    if memory is None:
        request['memory']['schema_version']=MEMORY
        request['memory']['measured_support_transfer']=dict(hip_bias_rad=0.,prepared_limb_id=None,
            prepared_swing_start_gait_step=None,preparation_commands=0,ready_dwell_commands=0)
    else:request['memory']=copy.deepcopy(memory)
    state=request['state']
    request['measured_body_frame']=dict(schema_version='sporespore_measured_walking_body_frame_v1',
        semantic_step=state['semantic_step'],sample_time_s=state['sample_time_s'],
        frame_id='sporespore_state_world_y_up_metres_v1',adapter_capability_sha256=state['adapter_capability_sha256'],
        source_measurement=True,ordered_body_states=copy.deepcopy(row['ordered_body_states']))
    return integer_tokens(request)

class MeasuredSupportTransfer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dll=Path(os.environ['SPORE_V45_DLL']);cls.core=LocomotionCore(cls.dll);cls.native=NativeApi(str(cls.dll))
        cls.report=source.report();cls.rows=cls.report['development_walking_entry']['rows']
        cls.descriptor=integer_tokens(cls.report['configuration']['base_descriptor'])

    def call(self,request):
        status,raw=self.native.raw('ss_balanced_wave_policy_step_json',request_bytes(request))
        self.assertEqual(0,status);return raw,json.loads(raw)['value']

    def test_all_400_parent_outputs_remain_byte_exact(self):
        for row in self.rows:
            request=integer_tokens(dict(row['request'],descriptor=self.descriptor,
                policy_id='sporespore_balanced_wave_recovery_support_hold_posture_v1',
                schema_version='sporespore_balanced_wave_policy_step_request_v2'))
            raw,_=self.call(request)
            self.assertEqual(row['raw_native_response_sha256'],'sha256:'+hashlib.sha256(raw).hexdigest())

    def test_real_stateless_cached_interfaces_and_measured_inputs(self):
        counts=dict(inputs=0,safe_refusals=0,preparation_holds=0)
        with self.core.create_balanced_wave_policy_session(POLICY,self.descriptor) as session:
            for row in self.rows:
                request=request_for(row,self.descriptor);_,out=self.call(request)
                self.assertEqual(out,self.core.balanced_wave_policy_step_with_measured_body(POLICY,request))
                cached={k:v for k,v in request.items() if k not in ('descriptor','policy_id')}
                self.assertEqual(out,session.step_with_measured_body(cached));counts['inputs']+=1
                if out['actuation']['safe_no_actuation']:
                    counts['safe_refusals']+=1;self.assertEqual(request['memory'],out['next_memory'])
                    self.assertTrue(all(c['target_velocity_rad_s']==0 for c in out['actuation']['ordered_commands']))
                    continue
                r=out['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
                counts['preparation_holds']+=r['preparation_held']
                self.assertFalse(r['measurement']['geometry_is_contact_authority'])
                self.assertFalse(r['physical_acceptance_authority'])
                self.assertAlmostEqual(4.72,r['measurement']['whole_mass_kg'],places=12)
                phases={l['limb_id']:(l['gait_step']+360-i*90)%360 for i,l in enumerate(out['next_memory']['ordered_limb_memory'])}
                self.assertEqual([phases[l] for l in source.LIMBS],r['effective_selected_phases'])
        self.assertEqual(400,counts['inputs']);print('V45_ACTUAL_ABI',json.dumps(counts),flush=True)

    def test_chained_input_prefix_preserves_wave_bias_and_stops_at_first_refusal(self):
        memory=None;count=0;refusal=None;nonzero_bias=0
        for row in self.rows:
            request=request_for(row,self.descriptor,memory);_,out=self.call(request);count+=1
            if out['actuation']['safe_no_actuation']:
                refusal=out['actuation']['receipt']['controller_error'];self.assertEqual(request['memory'],out['next_memory']);break
            r=out['actuation']['receipt']['recovery_support_plane'];t=r['measured_support_transfer']
            nonzero_bias+=t['next_memory']['hip_bias_rad']!=0
            self.assertTrue(t['reference_comparison_uses_current_bias'])
            self.assertLessEqual(abs(t['applied_hip_bias_rate_rad_s']),.60+1e-13)
            # Scheduled wave values remain raw; a common bias is a support
            # reference change and may not be accumulated into wave memory.
            wave=out['next_memory']['support_reference']['previous_wave']
            self.assertEqual(wave,r['wave_velocity']['current_wave'])
            if t['effective_phase_progression_held']:
                self.assertEqual(request['memory']['ordered_limb_memory'],out['next_memory']['ordered_limb_memory'])
            memory=out['next_memory']
        self.assertGreater(count,1);self.assertGreater(nonzero_bias,0)
        print('V45_RETAINED_INPUT_CHAIN',json.dumps(dict(calls=count,first_refusal=refusal,
            world_build_count=0,solver_step_count=0,new_trajectory=False)),flush=True)

    def test_missing_null_crossed_and_invalid_measurements_refuse(self):
        original=request_for(self.rows[1],self.descriptor)
        for kind in ('clock','time','capability','order','torso','source','bias','timeout','missing'):
            request=copy.deepcopy(original);frame=request['measured_body_frame']
            if kind=='clock':frame['semantic_step']+=1
            elif kind=='time':frame['sample_time_s']+=.001
            elif kind=='capability':frame['adapter_capability_sha256']='sha256:'+'2'*64
            elif kind=='order':frame['ordered_body_states'][1:3]=reversed(frame['ordered_body_states'][1:3])
            elif kind=='torso':frame['ordered_body_states'][0]['pose_world']['position_m']['x']+=.01
            elif kind=='source':frame['source_measurement']=False
            elif kind=='bias':request['memory']['measured_support_transfer']['hip_bias_rad']=.251
            elif kind=='timeout':request['memory']['measured_support_transfer']['preparation_commands']=240
            else:request['memory'].pop('measured_support_transfer')
            _,out=self.call(request);self.assertTrue(out['actuation']['safe_no_actuation'],kind)
            self.assertEqual(request['memory'],out['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in out['actuation']['ordered_commands']))
        for kind in ('absent','null','nan','old_helper'):
            request=copy.deepcopy(original)
            if kind=='absent':request.pop('measured_body_frame')
            elif kind=='null':request['measured_body_frame']=None
            elif kind=='nan':request['measured_body_frame']['ordered_body_states'][1]['twist_world']['linear_velocity_m_s']['x']=float('nan')
            with self.assertRaises((LocomotionCoreError,ValueError)):
                if kind=='old_helper':self.core.balanced_wave_policy_step(POLICY,request)
                else:self.core.balanced_wave_policy_step_with_measured_body(POLICY,request)

if __name__=='__main__':unittest.main()
