"""V40 full-population landing diagnosis; retained data only, no native call."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_landing_reach_diagnosis as d

FAILED = ROOT.parent/'SporeSpore_Evidence/development-v40-landing-diagnosis-7eb79133593c40438cff1002154220c7'


class LandingReachDiagnosis(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record=json.loads((ROOT/'sdk/development/recovery_landing_reach_diagnosis_v1.json').read_bytes())
        cls.path=Path(cls.record['complete_diagnosis']['path'])
        cls.full=json.loads(cls.path.read_bytes());cls.data=cls.full['diagnosis']
        cls.rows=cls.data['all_limb_command_timeline'];cls.plans=cls.data['all_command_height_plans']
        cls.report=json.loads(Path(cls.record['source_report']['path']).read_bytes())

    def test_complete_reproduction_population_and_exact_original_result(self):
        observed=d.observe()
        self.assertEqual(self.full,observed)
        self.assertEqual(self.record,d.compact(observed,self.path))
        self.assertEqual((400,1600,3200),tuple(self.data[k] for k in ('command_count','limb_command_count','joint_command_count')))
        self.assertEqual({(n,limb) for n in range(1,401) for limb in d.tracking.geometry.LIMBS},
                         {(r['command_local'],r['limb']) for r in self.rows})
        self.assertTrue(all(r['measured_trace_local']==r['command_local']-1 for r in self.rows))
        self.assertEqual(list(range(1,401)),[p['command_local'] for p in self.plans])
        evaluation=self.data['original_walking_evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'],evaluation['false_walking_receipts'])

    def test_every_conflict_is_front_right_minimum_rear_left_maximum(self):
        c=self.data['height_conflicts']
        self.assertEqual(103,c['count'])
        self.assertEqual([dict(first=246,last=263,count=18),dict(first=316,last=400,count=85)],c['windows'])
        self.assertEqual({'front_right / rear_left':103},c['minimum_owner_slash_maximum_owner_counts'])
        self.assertEqual(97,c['stance_only_nonempty_count'])
        self.assertEqual({'front_left':0,'front_right':103,'rear_left':103,'rear_right':0},c['resolved_by_omitting_each_limb'])
        self.assertTrue(c['all_conflicts_disable_lowering'])
        for p in self.plans:
            self.assertEqual(d.intersection(p['original_plan']['ordered_limb_intervals']),p['intersection'])
            for limb in d.tracking.geometry.LIMBS:
                self.assertEqual(d.intersection([r for r in p['original_plan']['ordered_limb_intervals'] if r['limb_id']!=limb]),p['leave_one_limb_out'][limb])
        landing=[r for r in self.rows if r['limb']=='rear_left' and r['phase']==72]
        self.assertEqual(list(range(345,401)),[r['command_local'] for r in landing])
        self.assertTrue(all(not r['pre_contact'] and not r['post_contact'] and r['raw_contact_count']==0 for r in landing))
        self.assertTrue(all(r['unrestricted_planar_reach_lower_bound_m']>0 and r['ideal_goal_bottom_m']>0 for r in landing))
        self.assertTrue(all(not m['saturated'] for r in landing for m in r['motors']))
        self.assertTrue(all(r['link_projection_at_planned_height'] for r in landing))

    def test_relaxed_lower_bound_attained_by_aligned_ideal_links(self):
        rows,entries,native,bodies,dimensions,error=d.tracking.samples(self.report)
        maximum=0.
        for row in rows:
            pose=native[row['measured_trace_local']]['observation']['state']['base_pose_world']
            forward,up=(d.tracking.geometry.rotate(pose['orientation_xyzw'],v)[1] for v in ([1,0,0],[0,1,0]))
            # Unrestricted planar angles: both links align with the downward
            # projection. This is not a new joint target or allowed joint limit.
            hip=math.atan2(-forward,up)
            bottom=d.tracking.geometry.ideal_distal(pose,row['limb'],hip,0.,*dimensions)[1]
            delta=abs(bottom-row['unrestricted_planar_reach_lower_bound_m']);maximum=max(maximum,delta)
            self.assertLess(delta,1e-12)
            for key in ('ideal_measured_bottom_m','ideal_current_reference_bottom_m','ideal_goal_bottom_m'):
                self.assertGreaterEqual(row[key]+1e-12,row['unrestricted_planar_reach_lower_bound_m'])
        self.assertEqual(1600,len(rows))
        print('LANDING_REACH_LOWER_BOUND_CHECK',dict(samples=len(rows),maximum_error_m=maximum),flush=True)

    def test_all_stance_losses_cycles_and_missing_terminal_pose_remain(self):
        timing=self.data['original_contact_timing']
        self.assertEqual((27,22),tuple(timing[k] for k in ('contact_loss_count','contact_losses_starting_in_scheduled_stance')))
        per={p['limb']:p for p in self.data['per_limb']}
        self.assertEqual([32,46,66,55],[per[l]['phases']['stance']['unsupported_command_count'] for l in d.tracking.geometry.LIMBS])
        self.assertEqual([1,11,13,1],[per[l]['phases']['stance']['unsupported_saturated_joint_commands'] for l in d.tracking.geometry.LIMBS])
        cycles=self.data['original_contact_cycles'];self.assertEqual(15,len(cycles))
        self.assertEqual(8,sum(not c['original_minimum_relocation_passed'] for c in cycles))
        for c in cycles:
            parts=c['decomposition']['forward_components_m']
            self.assertEqual(c['distal_body_origin_forward_relocation_m'],parts['actual'])
            self.assertAlmostEqual(parts['actual'],sum(v for k,v in parts.items() if k!='actual'),delta=1e-15)
        self.assertEqual(399,max(r['measured_trace_local'] for r in self.rows))
        self.assertFalse(d.tracking.decompose('rear_left',297,400,{}, {}, (), ())['available'])

    def test_crossed_provenance_corrupt_intervals_slots_and_bad_geometry_refuse(self):
        with self.assertRaisesRegex(ValueError,'SOURCE_CROSSED'):d.summarize(dict(self.report,source_commit='wrong'))
        for mutation in ('floor','time','interval','slot'):
            rows=list(self.report['development_walking_entry']['rows']);row=copy.deepcopy(rows[315]);rows[315]=row
            if mutation=='floor':row['request']['floor_reference']['height_world_m']+=1.
            elif mutation=='time':row['measured_global_step']+=1
            elif mutation=='interval':row['native_output']['actuation']['receipt']['recovery_support_plane']['feasible_support_plan']['ordered_limb_intervals'][0]['minimum_torso_height_m']+=.01
            else:row['ordered_motor_applications'][0]['motor_target_velocity_readback_rad_s']+=.01
            changed=dict(self.report,development_walking_entry=dict(self.report['development_walking_entry'],rows=rows))
            with self.subTest(mutation=mutation),self.assertRaises(AssertionError):d.summarize(changed)
        pose=(.38,(0.,0.,0.,1.));wave=dict(active=True,limbs=[(0.,0.,0.)]*4);dimensions=(.18,.17,.04,1.)
        for changed in ((math.nan,pose[1]),(.38,(0.,0.,0.,0.))):
            with self.assertRaises(ValueError):d.intervals(changed,wave,dimensions)
        for angle,fraction,phase in ((1.,0.,0.),(0.,-1.,0.),(0.,0.,72.5),(0.,0.,360)):
            with self.assertRaises(ValueError):d.intervals(pose,dict(wave,limbs=[(angle,fraction,phase)]*4),dimensions)
        with mock.patch.object(d,'digest',return_value='sha256:'+'0'*64),self.assertRaisesRegex(ValueError,'CLOSURE_DRIFT'):d.observe()

    def test_failed_exact_equality_preserved_and_no_new_authority(self):
        failed=json.loads((FAILED/'analysis.execution.json').read_bytes())
        self.assertEqual(1,failed['exit_code']);self.assertTrue(failed['source_unchanged'])
        before=FAILED/'analysis.before-lowering-check-fix.exact.py'
        source=next(b for b in failed['source_snapshot']['changed_file_bindings'] if b['path'].endswith('development_recovery_landing_reach_diagnosis.py'))
        self.assertEqual('sha256:'+source['sha256'],d.digest(before.read_bytes()))
        self.assertIn("assert plan['requested_lowering_m'] == pose[0]-plan['requested_stance_torso_height_m']",before.read_text())
        self.assertGreater(self.data['maximum_lowering_identity_error_m'],0.)
        self.assertLess(self.data['maximum_lowering_identity_error_m'],1e-12)
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',d.digest((ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()))
        self.assertEqual(d.CLOSURE_SHA,d.digest((ROOT/self.record['source_closure']['path']).read_bytes()))
        for k in ('original_evaluation_changed','physical_cause_proven','alternate_physical_outcome_predicted','physical_acceptance_authority','release_authority'):self.assertFalse(self.full[k])
        for k in ('native_controller_call_count','new_world_build_count','new_solver_step_count','new_native_physics_read_count'):self.assertEqual(0,self.full[k])


if __name__=='__main__':unittest.main()
