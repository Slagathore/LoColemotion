"""V46 real exported interfaces and V45 byte regression; no native world."""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'sdk/python'),str(ROOT/'sdk/conformance')]
from sporespore_locomotion import LocomotionCore,LocomotionCoreError
from test_development_v32_recontact_component import NativeApi
import development_v45_support_geometry_diagnosis as geometry

POLICY='sporespore_balanced_wave_recovery_measured_pose_support_v1'
MEMORY='sporespore_balanced_wave_recovery_measured_pose_support_memory_v1'

class MeasuredPoseSupport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dll=Path(os.environ['SPORE_V46_DLL']);cls.core=LocomotionCore(cls.dll);cls.native=NativeApi(str(cls.dll))
        cls.rows,cls.input=geometry.read_source();cls.descriptor=cls.input['descriptor']
        cls.root=ROOT.parent/'SporeSpore_Evidence'/('development-v45-mujoco-closed-loop-'+geometry.ATTEMPT)
    def request(self,row,memory=None):
        r=copy.deepcopy(row['request']);r['policy_id']=POLICY
        if memory is not None:r['memory']=copy.deepcopy(memory)
        else:
            r['memory']['schema_version']=MEMORY
            r['memory']['support_reference'].pop('ordered_stance_latches',None)
        return r
    def call(self,r):
        # These are exact MuJoCo/Python requests, including negative zero.
        # The historical Godot integer-normalization helper is not this route.
        status,raw=self.native.raw('ss_balanced_wave_policy_step_json',self.core._input_bytes(r))
        self.assertEqual(0,status);return raw,json.loads(raw)['value']
    def test_all_399_v45_outputs_and_original_refusal_are_byte_exact(self):
        for row in self.rows:
            raw,out=self.call(row['request'])
            self.assertEqual(row['raw_response_sha256'],'sha256:'+hashlib.sha256(raw).hexdigest());self.assertEqual(row['output'],out)
        refused=json.loads((self.root/'controller-refusal.json').read_text(encoding='utf-8'))
        raw,out=self.call(refused['request']);self.assertEqual(refused['output'],out)
        self.assertEqual((self.root/'calls/0400.response.json').read_bytes(),raw)
    def check_geometry(self,r,out):
        s=out['actuation']['receipt']['recovery_support_plane'];t=s['measured_support_transfer'];count=0
        self.assertNotIn('upright_stance',s);self.assertNotIn('stance_latch',s)
        self.assertNotIn('ordered_stance_latches',out['next_memory']['support_reference'])
        self.assertEqual('finite_hold_measured_pose_support_without_swing_lift_v1',s['support_hold_posture']['mode_id'])
        if r['command']['gait_amplitude']==0:
            self.assertTrue(all(p['goal_hip_rad']==0 and p['goal_knee_rad']==0 for p in s['ordered_limb_proposals']))
            return 0
        for i,p in enumerate(s['ordered_limb_proposals']):
            if t['effective_phase_progression_held'] or t['effective_selected_phases'][i]>72:
                gap=geometry.bottom(r['state'],self.descriptor,p['limb_id'],p['goal_hip_rad'],p['goal_knee_rad'])
                self.assertAlmostEqual(gap,p['projected_support_nominal_plane_residual_m'],places=12)
                self.assertEqual(0.,p['walking_knee_fraction'])
                if not p['link_reach_projection_required'] and not p['support_joint_projection_required'] and s['feasible_support_plan']['requested_lowering_m']==0:
                    self.assertLess(abs(gap),1e-12);count+=1
        return count
    def test_actual_stateless_cached_and_full_retained_geometry_population(self):
        checked=0
        with self.core.create_balanced_wave_policy_session(POLICY,self.descriptor) as session:
            for row in self.rows:
                r=self.request(row);_,out=self.call(r);self.assertFalse(out['actuation']['safe_no_actuation'])
                self.assertEqual(out,self.core.balanced_wave_policy_step_with_measured_body(POLICY,r))
                self.assertEqual(out,session.step_with_measured_body({k:v for k,v in r.items() if k not in ('descriptor','policy_id')}))
                checked+=self.check_geometry(r,out)
                self.assertEqual(row['output']['next_memory']['ordered_limb_memory'],out['next_memory']['ordered_limb_memory'])
                self.assertEqual(row['output']['next_memory']['support_progression'],out['next_memory']['support_progression'])
                self.assertEqual(row['output']['next_memory']['measured_support_transfer'],out['next_memory']['measured_support_transfer'])
        # Derive the eligible population independently from V45's retained
        # measured-pose baseline, rather than guessing a minimum sample count.
        expected=0
        for row in self.rows:
            if row['request']['command']['gait_amplitude']==0:continue
            old=row['output']['actuation']['receipt']['recovery_support_plane'];t=old['measured_support_transfer'];u=old['upright_stance']
            for i,p in enumerate(u['measured_pose_baseline_proposals']):
                expected+=bool((t['effective_phase_progression_held'] or t['effective_selected_phases'][i]>72)
                    and not p['link_reach_projection_required'] and not p['support_joint_projection_required']
                    and u['measured_pose_baseline_plan']['requested_lowering_m']==0)
        self.assertEqual(expected,checked);self.assertEqual(975,expected)
        print('V46_ACTUAL_ABI',json.dumps(dict(inputs=399,reachable_support_targets_at_actual_floor=checked,world_build_count=0)),flush=True)
    def test_chained_reference_memory_retains_gate_and_stops_at_same_timeout(self):
        memory=None;count=0
        for row in self.rows:
            r=self.request(row,memory);_,out=self.call(r);self.assertFalse(out['actuation']['safe_no_actuation'])
            self.check_geometry(r,out);memory=out['next_memory'];count+=1
        refused=json.loads((self.root/'controller-refusal.json').read_text(encoding='utf-8'))
        r=self.request(refused,memory);_,out=self.call(r);self.assertTrue(out['actuation']['safe_no_actuation'])
        self.assertEqual(memory,out['next_memory']);self.assertIn('support_progression_hold_timeout',out['actuation']['receipt']['controller_error'])
        print('V46_CHAINED_RETAINED_INPUTS',json.dumps(dict(stepped_policy_inputs=count,refusal_call=400,new_physical_trajectory=False)),flush=True)
    def test_missing_crossed_frame_and_memory_refuse(self):
        original=self.request(self.rows[159])
        for defect in ('clock','body','latch','schema','memory','timeout'):
            r=copy.deepcopy(original)
            if defect=='clock':r['measured_body_frame']['semantic_step']+=1
            elif defect=='body':r['measured_body_frame']['ordered_body_states'][0]['pose_world']['position_m']['x']+=1.
            elif defect=='latch':r['memory']['support_reference']['ordered_stance_latches']=self.rows[159]['request']['memory']['support_reference']['ordered_stance_latches']
            elif defect=='schema':r['memory']['schema_version']='sporespore_balanced_wave_recovery_measured_support_transfer_memory_v1'
            elif defect=='memory':r['memory'].pop('measured_support_transfer')
            else:r['memory']['support_progression']['held_steps']=120
            _,out=self.call(r);self.assertTrue(out['actuation']['safe_no_actuation'],defect);self.assertEqual(r['memory'],out['next_memory'])
            self.assertTrue(all(c['target_velocity_rad_s']==0 for c in out['actuation']['ordered_commands']))
        for body in (None,'absent'):
            r=copy.deepcopy(original)
            if body is None:r['measured_body_frame']=None
            else:r.pop('measured_body_frame')
            with self.assertRaises(LocomotionCoreError):self.core.balanced_wave_policy_step_with_measured_body(POLICY,r)

if __name__=='__main__':unittest.main(verbosity=2)
