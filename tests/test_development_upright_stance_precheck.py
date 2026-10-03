"""V41 original-input and chained-reference precheck; never a native rollout."""
import copy
import json
import math
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import development_recovery_upright_stance_precheck as d


class UprightStancePrecheck(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record=json.loads((ROOT/'sdk/development/recovery_upright_stance_precheck_v1.json').read_bytes())
        cls.path=Path(cls.record['complete_precheck']['path'])
        cls.full=json.loads(cls.path.read_bytes());cls.data=cls.full['observation'];cls.rows=cls.data['all_command_comparisons']
        cls.report=json.loads(Path(cls.record['source_report']['path']).read_bytes())
        cls.entries=cls.report['development_walking_entry']['rows']
        desc=cls.report['configuration']['base_descriptor'];upper=.35*desc['upper_length_fraction']
        cls.dimensions=(upper,.35-upper,.04*desc['foot_radius_scale'],desc['hip_span_scale'])

    def test_full_reproduction_and_original_baseline(self):
        calculated=d.observe()
        # The retained contract is JSON: tuple height triples serialize as
        # arrays. Compare that representation, not Python-only container types.
        self.assertIsInstance(calculated['observation']['all_command_comparisons'][0]['baseline']['original_height_plan'],tuple)
        self.assertIsInstance(self.rows[0]['baseline']['original_height_plan'],list)
        observed=json.loads(json.dumps(calculated,allow_nan=False))
        # Keep failure output bounded for this 8.9 MB retained population.
        self.assertTrue(self.full==observed,'Complete JSON-normalized precheck differs from retained result')
        self.assertTrue(self.record==d.compact(observed,self.path),'Compact precheck differs from retained result')
        self.assertEqual((400,1600,3200),tuple(self.data[k] for k in ('command_count','limb_command_count','joint_command_count')))
        self.assertEqual(list(range(1,401)),[r['command_local'] for r in self.rows])
        self.assertTrue(all(r['measured_trace_local']==r['command_local']-1 for r in self.rows))
        self.assertEqual(85,self.data['original_saturated_joint_commands'])
        self.assertLess(self.data['baseline_target_maximum_error_rad'],1e-12)
        self.assertLess(self.data['baseline_motor_maximum_error_rad_s'],1e-10)
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'],self.data['original_walking_evaluation']['false_walking_receipts'])
        self.assertFalse(self.data['original_walking_evaluation']['behavior_passed'])

    def test_selector_truth_table_and_domain_refusals(self):
        checks=0
        for active in (False,True):
            for phase in (0,72,73,359):
                for presence,bearing in ((False,False),(True,False),(True,True)):
                    self.assertEqual(active and phase>72 and presence and bearing,d.selection(active,phase,presence,bearing));checks+=1
        self.assertEqual(24,checks)
        for args in ((None,73,True,True),(True,True,True,True),(True,72.5,True,True),(True,360,True,True),(True,math.nan,True,True),(True,73,None,False),(True,73,False,True)):
            with self.subTest(args=args),self.assertRaises(ValueError):d.selection(*args)
        pose,wave=d.cold.algebra.inputs(self.entries[250])
        for mask in ([True]*3,[True,True,True,None]):
            with self.assertRaises(ValueError):d.goals(pose,wave,self.dimensions,mask)

    def test_initialization_activation_and_same_current_mask_for_comparison(self):
        template=copy.deepcopy(self.entries[250]);refs=[0.,.2]*4
        for active in (False,True):
            for prior_active in (None,False,True):
                for phase in (0,72,73,359):
                    for dt in (0.,.01):
                        entry=copy.deepcopy(template);request=entry['request']
                        request['command']['gait_amplitude']=.3 if active else 0.
                        receipt=entry['native_output']['actuation']['receipt']['recovery_support_plane']
                        receipt['reference_step_duration_s']=dt
                        for p in receipt['ordered_limb_proposals']:
                            p['scheduled_phase_step']=phase
                            if not active:p['nominal_leg_direction_rad']=p['walking_knee_fraction']=0.
                        for c in request['state']['ordered_contact_observations']:c['presence']=c['bears_support']=True
                        if prior_active is None:receipt['wave_velocity']['previous_wave']=None
                        else:
                            receipt['wave_velocity']['previous_wave']['active']=prior_active
                            if not prior_active:
                                for p in receipt['wave_velocity']['previous_wave']['ordered_limbs']:
                                    p['nominal_leg_direction_rad']=p['walking_knee_fraction']=0.
                        result=d.step(entry,refs,self.dimensions)
                        self.assertEqual([active and phase>72]*4,result['selected'])
                        if dt==0:self.assertEqual(refs,result['targets_rad'])
                        if not active or prior_active is not True or dt==0:
                            self.assertTrue(all(m['selected_reference_rate_rad_s']==0 for m in result['motors']))
                        else:
                            pose,wave=d.cold.algebra.inputs(entry);old=d.snapshot(receipt['wave_velocity']['previous_wave'])
                            expected=d.cold.support_goals((pose[0],(0.,0.,0.,1.)) if phase>72 else pose,old,self.dimensions)[0]
                            caps=[m['cap_rad_s'] for m in result['motors']]
                            comparison=d.cold.algebra.bounded_targets(expected,refs,caps,dt)
                            self.assertEqual(comparison,[m['comparison_rad'] for m in result['motors']])
                        # The upright reference must be exactly the old pose
                        # path when the measured reference is already upright.
                        request['state']['base_pose_world']['orientation_xyzw']=dict(x=0.,y=0.,z=0.,w=1.)
                        a=d.step(entry,refs,self.dimensions);b=d.step(entry,refs,self.dimensions,False)
                        self.assertEqual(a['targets_rad'],b['targets_rad'])
                        self.assertEqual([m['velocity_rad_s'] for m in a['motors']],[m['velocity_rad_s'] for m in b['motors']])

    def test_chained_memory_bounds_and_transition_carry_are_not_hidden(self):
        self.assertEqual((1037,47),(self.data['upright_selected_limb_commands'],self.data['selector_change_count']))
        self.assertEqual((2044,83),tuple(self.data['one_command_substitution'][k] for k in ('changed_joint_commands','saturated_joint_commands')))
        self.assertTrue(self.data['one_command_substitution']['unselected_goal_and_target_and_motor_preserved_within_existing_arithmetic'])
        chained=self.data['chained_reference_replay']
        self.assertEqual((2186,168,102),tuple(chained[k] for k in ('changed_joint_commands','saturated_joint_commands','unselected_joint_commands_with_carried_reference_change')))
        previous=self.entries[0]['request']['memory']['support_reference']['ordered_target_positions_rad']
        for row in self.rows:
            result=row['chained_reference_replay'];motors=result['motors'];dt=result['reference_step_duration_s']
            self.assertEqual(previous,[m['prior_reference_rad'] for m in motors])
            for i,m in enumerate(motors):
                lo,hi=(-.72,.72) if i%2==0 else (0.,1.1)
                self.assertTrue(lo<=m['goal_rad']<=hi and lo<=m['target_rad']<=hi)
                self.assertLessEqual(abs(m['velocity_rad_s']),m['cap_rad_s'])
                self.assertLessEqual(abs(m['target_rad']-m['prior_reference_rad']),m['cap_rad_s']*dt+1e-14)
            previous=result['targets_rad']
        self.assertEqual({'0':0,'1':0,'2':131,'3':175,'4':94},{k:v['command_count'] for k,v in self.data['support_contact_count_strata'].items()})

    def test_upright_intervals_and_lift_risks_are_geometry_only(self):
        self.assertEqual(400,self.data['upright_common_height_nonempty_command_count'])
        for entry,row in zip(self.entries,self.rows):
            pose,wave=d.cold.algebra.inputs(entry)
            common=d.data.intersection(d.data.intervals((pose[0],(0.,0.,0.,1.)),wave,self.dimensions))
            heights=row['one_command_substitution']['upright_height_plan']
            self.assertAlmostEqual(common['minimum_m'],heights[0],delta=1e-12)
            self.assertAlmostEqual(common['maximum_m'],heights[1],delta=1e-12)
            self.assertTrue(common['nonempty'])
        for p in self.data['per_limb_selected_geometry']:
            self.assertGreater(p['geometry_lift_direction_command_count'],0)
            self.assertGreater(p['geometry_lower_direction_command_count'],0)
        self.assertGreater(sum(p['geometry_lift_direction_command_count'] for p in self.data['per_limb_selected_geometry']),0)
        self.assertIn('unilateral contact and load transfer are unproved',self.full['limits'])

    def test_provenance_corruption_immutable_parent_and_no_authority(self):
        with self.assertRaisesRegex(ValueError,'SOURCE_CROSSED'):d.summarize(dict(self.report,source_commit='wrong'))
        for mutation in ('floor','contact_order'):
            entry=copy.deepcopy(self.entries[200])
            if mutation=='contact_order':
                entry['request']['state']['ordered_contact_observations'][0]['contact_site_id']='rear_left_foot'
                with self.assertRaisesRegex(ValueError,'CONTACT_ORDER'):d.step(entry,[0.]*8,self.dimensions)
            else:
                entry['request']['floor_reference']['height_world_m']+=1.
                rows=list(self.entries);rows[200]=entry
                changed=dict(self.report,development_walking_entry=dict(self.report['development_walking_entry'],rows=rows))
                with self.assertRaises(AssertionError):d.summarize(changed)
        with mock.patch.object(d.data,'digest',return_value='sha256:'+'0'*64),self.assertRaisesRegex(ValueError,'CLOSURE_DRIFT'):d.observe()
        self.assertEqual(d.data.CLOSURE_SHA,d.data.digest((ROOT/self.record['source_closure']['path']).read_bytes()))
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',d.data.digest((ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json').read_bytes()))
        for k in ('native_controller_call_count','new_world_build_count','new_solver_step_count','new_native_physics_read_count'):self.assertEqual(0,self.full[k])
        for k in ('original_evaluation_changed','physical_outcome_predicted','physical_acceptance_authority','release_authority'):self.assertFalse(self.full[k])


if __name__=='__main__':unittest.main()
