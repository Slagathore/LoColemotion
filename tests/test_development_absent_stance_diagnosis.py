"""Saved V39 stance coverage and bounded V40 sketch, with no native execution."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_absent_stance_diagnosis as d


class AbsentStanceDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record=json.loads((ROOT/'sdk/development/recovery_absent_stance_diagnosis_v1.json').read_bytes())
        cls.path=Path(cls.record['complete_diagnosis']['path'])
        cls.full=json.loads(cls.path.read_bytes());cls.data=cls.full['diagnosis']
        cls.timeline=cls.data['all_limb_command_timeline']
        cls.report=json.loads(Path(cls.record['source_report']['path']).read_bytes())

    def test_complete_reproduction_original_outcome_and_population(self):
        observed=d.observe()
        self.assertEqual(self.full,observed)
        self.assertEqual(self.record,d.compact(observed,self.path))
        self.assertEqual((400,1600,3200),tuple(self.data[k] for k in ('command_count','limb_command_count','joint_command_count')))
        self.assertEqual({(n,limb) for n in range(1,401) for limb in d.tracking.geometry.LIMBS},
                         {(r['command_local'],r['limb']) for r in self.timeline})
        self.assertTrue(all(r['measured_trace_local']==r['command_local']-1 for r in self.timeline))
        self.assertEqual(399,max(r['measured_trace_local'] for r in self.timeline))
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'],self.data['original_walking_evaluation']['false_walking_receipts'])
        self.assertFalse(self.data['original_walking_evaluation']['behavior_passed'])
        self.assertEqual(19,len(self.data['original_contact_cycles']))
        self.assertEqual(24,self.data['original_contact_timing']['contact_loss_count'])
        for cycle in self.data['original_contact_cycles']:
            parts=cycle['decomposition']['forward_components_m']
            self.assertEqual(cycle['distal_body_origin_forward_relocation_m'],parts['actual'])
            self.assertAlmostEqual(parts['actual'],sum(v for k,v in parts.items() if k!='actual'),delta=1e-15)

    def test_all_unsupported_stance_samples_and_terminal_reach_conflict(self):
        per={r['limb']:r for r in self.data['per_limb']}
        self.assertEqual({'front_left':(287,43),'front_right':(323,40),'rear_left':(323,30),'rear_right':(321,95)},
                         {k:(v['stance_command_count'],v['unsupported_stance_command_count']) for k,v in per.items()})
        self.assertEqual(208,sum(v['unsupported_stance_command_count'] for v in per.values()))
        self.assertTrue(all(v['unsupported_stance_saturated_joint_commands']==0 for v in per.values()))
        self.assertTrue(all(v['unsupported_stance_no_raw_contact_count']==v['unsupported_stance_command_count'] for v in per.values()))
        rr={r['command_local']:r for r in self.timeline if r['limb']=='rear_right'}
        self.assertTrue(rr[376]['pre_contact']);self.assertFalse(rr[376]['post_contact'])
        self.assertTrue(all(not rr[n]['pre_contact'] and rr[n]['raw_contact_count']==0 for n in range(377,401)))
        self.assertLess(abs(rr[376]['ideal_goal_bottom_m']),1e-8)
        self.assertGreater(rr[390]['unrestricted_planar_reach_lower_bound_m'],0.)
        self.assertGreater(rr[390]['ideal_goal_bottom_m'],.004)
        # The plan is feasible at a LOWER torso, not at the current torso.
        for n in range(380,401):
            self.assertGreater(rr[n]['requested_body_lowering_m'],0.)
            self.assertAlmostEqual(rr[n]['ideal_goal_bottom_m'],rr[n]['requested_body_lowering_m'],delta=1e-8)
        self.assertFalse(rr[390]['link_projection_at_planned_height'])
        self.assertEqual([0,0,0,13],[per[l]['stance_link_projection_at_planned_height_count'] for l in d.tracking.geometry.LIMBS])

    def test_sketch_only_changes_absent_stance_and_keeps_all_caps(self):
        sketch=self.data['proposed_stance_rate_sketch']
        self.assertEqual((208,416,278,133,51),tuple(sketch[k] for k in ('new_limb_selections','new_joint_selections',
            'changed_joint_commands','proposed_saturated_joint_commands','selected_stance_proposed_saturated_joint_commands')))
        self.assertTrue(sketch['all_unselected_velocities_exact'])
        self.assertTrue(sketch['all_proposed_velocities_inside_existing_caps'])
        self.assertLess(sketch['fixed_pose_ideal_vertical_rate_change']['minimum'],0.)
        self.assertGreater(sketch['fixed_pose_ideal_vertical_rate_change']['maximum'],0.)
        for row in self.timeline:
            for motor in row['motors']:
                if motor['new_stance_selection']:
                    self.assertGreater(row['phase'],72);self.assertFalse(row['pre_contact'])
                else:self.assertEqual(motor['original_velocity_rad_s'],motor['proposed_velocity_rad_s'])
        for active in (False,True):
            for phase in (0,72,73,359):
                for presence,bearing in ((False,False),(True,False),(True,True)):
                    for dt in (0.,.01):
                        selected=active and phase>72 and not presence and not bearing and dt>0
                        self.assertEqual((selected,1. if selected else .2),d.proposed_rate(active,phase,presence,bearing,dt,3.5,1.,.2))

    def test_fixed_pose_derivative_matches_independent_finite_difference(self):
        rows,entries,native,bodies,dimensions,error=d.tracking.samples(self.report)
        maximum=0.;checks=0;eps=1e-6
        for row in self.timeline:
            torso=native[row['measured_trace_local']]['observation']['state']['base_pose_world']
            q=row['measured_joint_rad']
            for i,actual in enumerate(row['ideal_bottom_joint_derivatives_m_per_rad']):
                before=list(q);after=list(q);before[i]-=eps;after[i]+=eps
                a=d.tracking.geometry.ideal_distal(torso,row['limb'],*before,*dimensions)[1]
                b=d.tracking.geometry.ideal_distal(torso,row['limb'],*after,*dimensions)[1]
                difference=abs((b-a)/(2*eps)-actual);maximum=max(maximum,difference)
                # Differentiation check only; not a new physics/contact tolerance.
                self.assertLess(difference,1e-8);checks+=1
        self.assertEqual(3200,checks)
        print('ABSENT_STANCE_DERIVATIVE_CHECK',dict(checks=checks,maximum_error=maximum),flush=True)

    def test_crossed_context_corrupt_targets_and_invalid_sketch_refuse(self):
        with self.assertRaisesRegex(ValueError,'SOURCE_CROSSED'):d.summarize(dict(self.report,source_commit='wrong'))
        for mutation in ('floor','time','contact','motor_slot'):
            rows=list(self.report['development_walking_entry']['rows']);row=copy.deepcopy(rows[20]);rows[20]=row
            if mutation=='floor':row['request']['floor_reference']['height_world_m']+=1.
            elif mutation=='time':row['measured_global_step']+=1
            elif mutation=='contact':row['request']['state']['ordered_contact_observations'][0]['presence']=None
            else:row['ordered_motor_applications'][0]['motor_target_velocity_readback_rad_s']+=.01
            changed=dict(self.report,development_walking_entry=dict(self.report['development_walking_entry'],rows=rows))
            with self.subTest(mutation=mutation),self.assertRaises(AssertionError):d.summarize(changed)
        valid=[True,73,False,False,.01,3.5,1.,.2]
        for i,value in ((0,None),(1,True),(1,72.5),(1,360),(2,None),(3,True),(4,-.01),(5,0.),(6,math.nan),(7,4.)):
            changed=list(valid);changed[i]=value
            with self.subTest(index=i),self.assertRaises(ValueError):d.proposed_rate(*changed)
        with mock.patch.object(d,'digest',return_value='sha256:'+'0'*64),self.assertRaisesRegex(ValueError,'CLOSURE_DRIFT'):d.observe()

    def test_contract_and_immutable_no_native_scope(self):
        contract=json.loads((ROOT/'sdk/development/recovery_absent_contact_reference_contract_v1.json').read_bytes())
        self.assertEqual('V40',contract['component_id'])
        self.assertEqual(d.cold.POLICY,contract['parent_policy_id'])
        self.assertEqual(d.REPORT_SHA,contract['source_report_sha256'])
        for k in ('native_component_implemented','route_integrated','physical_attempt_selected','physical_outcome_predicted','physical_acceptance_authority','release_authority'):
            self.assertFalse(contract[k])
        self.assertEqual(d.CLOSURE_SHA,d.digest((ROOT/contract['source_attempt']).read_bytes()))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',
            d.digest((ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()))
        for k in ('original_evaluation_changed','physical_cause_proven','alternate_physical_outcome_predicted','physical_acceptance_authority','release_authority'):
            self.assertFalse(self.full[k])
        for k in ('native_controller_call_count','new_world_build_count','new_solver_step_count','new_native_physics_read_count'):
            self.assertEqual(0,self.full[k])


if __name__=='__main__':unittest.main()
