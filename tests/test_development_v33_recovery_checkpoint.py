"""Cold V33 result: bounded references executed, two walking failures remain."""
import json
from pathlib import Path
import unittest

import test_development_v27_recovery_checkpoint as prior

closure = prior.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = '4e5cacbc49e64ceab61fff2762217804'
SOURCE = '320668509058bfadcb31d66b4e83d67fbb783202'
POLICY = 'sporespore_balanced_wave_recovery_bounded_support_v1'


class V33Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT+'.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']:p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r.get('walking_session_id')==cls.resume['session_id']]
        cls.entries = {r['session_local_step']:r for r in cls.report['development_walking_entry']['rows']}

    def test_complete_retained_population_original_replay_and_frozen_source(self):
        closure.smoke.validate_checkpoint(self.record, self.observed)
        self.assertEqual(SOURCE, self.record['source_snapshot']['head'])
        self.assertFalse(self.record['source_snapshot']['dirty'])
        self.assertEqual('closed_consumed_valid_development_observation', self.record['status'])
        self.assertEqual((112,1,1258), tuple(self.record[k] for k in ('safety_test_count','world_count','solver_step_count')))
        self.assertEqual((63,1059969112), tuple(self.record['retained_population'][k] for k in ('file_count','byte_length')))
        self.assertEqual('sha256:ac13b7bc8fd76049d52900e354cbf0946cab3651d43eacecda44caf94ccb5ca4', self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:5377605e4bb8ff4a516bfeb61331bb9edc9b840df70fc778b6ec8006e7893d68', self.record['kicked_report']['raw_sha256'])
        self.assertEqual(41, len(self.record['rule_sources']))
        self.assertTrue(self.record['original_attempt_and_all_independent_replays_passed'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258,467,119,1), tuple(replay[k] for k in ('transition_count','canonical_observation_count','entry_observation_count','canonical_initialization_count')))
        self.assertEqual(430, replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400, replay['walking_control_replay']['replayed_walking_steps'])
        self.assertNotIn('memory_transition_profile_id', replay['walking_control_replay'])
        self.assertNotIn('adapter_mode_transition_count', replay['walking_control_replay'])
        self.assertEqual(POLICY, replay['walking_policy_validation']['policy_id'])
        self.assertEqual('bounded_support_front_left_first_resume_v1', replay['walking_start_validation']['profile_id'])
        for key in ('world_build_count','solver_step_count','native_physics_read_count'):
            self.assertEqual(0, replay[key])

    def test_own_standing_commands_and_all_3200_bounded_references(self):
        # Reconstruct THIS run's 1,864 stance commands and measured completion.
        # The helper uses the unchanged standing rule, not another run's states.
        prior.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual((859,1258,400), (self.rows[0]['global_semantic_step'],self.rows[-1]['global_semantic_step'],len(self.rows)))
        self.assertEqual({90}, set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual(POLICY, self.resume['start_receipt']['selected_policy_id'])
        prefix = next(s for s in self.arm['walking_sessions'] if s['evaluation_segment_id']=='walking_prefix')
        self.assertEqual('sporespore_balanced_wave_bw5r_b_v1', prefix['start_receipt']['selected_policy_id'])
        self.assertEqual({240}, set(prefix['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual(list(range(1,401)), list(self.entries))
        # The 1e-14 reference arithmetic allowance was frozen BEFORE physics.
        # Native raw-response replay stays exact; this is decimal/binary64
        # inspection of retained numeric fields, not a behavioral tolerance.
        frozen = closure.prior.committed('sdk/core/src/recovery_bounded_support_tests.rs', SOURCE).decode()
        self.assertIn('receipt.reference_step_duration_s + 1e-14', frozen)
        slew = projected = commands_checked = 0
        maximum_residual = 0.
        for local,row in self.entries.items():
            request,output = row['request'],row['native_output']
            actuation = output['actuation']
            receipt = actuation['receipt']['recovery_support_plane']
            reference = request['memory']['support_reference']
            following = output['next_memory']['support_reference']
            self.assertEqual('sporespore_recovery_support_controller_step_receipt_v1', actuation['receipt']['schema_version'])
            self.assertEqual('all_limb_bounded_plane_observation_z_forward_reference_slew_v1', receipt['mode_id'])
            self.assertFalse(receipt['all_limb_contact_claim'])
            self.assertFalse(receipt['physical_acceptance_authority'])
            self.assertEqual('contact_gated', request['command']['phase_progression_mode'])
            t = min((local-1)/72,1)
            self.assertAlmostEqual((1.1/(.82*1.75+.4))*t*t*(3-2*t), request['command']['gait_amplitude'], places=14)
            if local==1:
                self.assertIsNone(reference['previous_sample_time_s'])
                self.assertEqual([0.]*8, reference['ordered_target_positions_rad'])
                self.assertTrue(receipt['first_step_holds_neutral_reference'])
                self.assertEqual(0., receipt['reference_step_duration_s'])
            else:
                self.assertEqual(self.entries[local-1]['native_output']['next_memory'], request['memory'])
                self.assertGreater(receipt['reference_step_duration_s'],0.)
            goals = [v for limb in receipt['ordered_limb_proposals'] for v in (limb['goal_hip_rad'],limb['goal_knee_rad'])]
            for index,command in enumerate(actuation['ordered_commands']):
                target = command['requested_target_position_rad']
                lo,hi = (-.72,.72) if index%2==0 else (0.,1.1)
                self.assertLessEqual(lo,target)
                self.assertLessEqual(target,hi)
                self.assertEqual(target,command['clamped_target_position_rad'])
                self.assertEqual(target,following['ordered_target_positions_rad'][index])
                self.assertFalse(command['position_saturated'])
                old = reference['ordered_target_positions_rad'][index]
                delta = command['maximum_target_speed_rad_s']*receipt['reference_step_duration_s']
                self.assertLessEqual(abs(target-old),delta+1e-14)
                expected = old+max(-delta,min(delta,goals[index]-old))
                self.assertAlmostEqual(expected,target,delta=1e-14)
                if local==1:
                    self.assertEqual(0.,target)
                slew += command['slew_limited']
                commands_checked += 1
            for limb in receipt['ordered_limb_proposals']:
                projected += limb['support_joint_projection_required']
                maximum_residual = max(maximum_residual,abs(limb['projected_support_nominal_plane_residual_m']))
        self.assertEqual((3200,259,25),(commands_checked,slew,projected))
        self.assertEqual(.02082693811940234,maximum_residual)
        print('V33_PHYSICAL_REFERENCE_AUDIT',json.dumps(dict(command_count=commands_checked,slew_limited_command_count=slew,
            projected_support_target_count=projected,maximum_nominal_plane_residual_m=maximum_residual,
            neutral_first_reference=True,existing_joint_limits_preserved=True,strict_memory_chain=True,
            raw_native_replay_exact=True,retained_numeric_reference_tolerance_rad=1e-14,
            world_build_count=0,solver_step_count=0,physical_acceptance_authority=False),separators=(',',':')),flush=True)

    def test_all_measured_cycles_and_original_walking_failures(self):
        evaluation = self.resume['evaluation']
        self.assertFalse(evaluation['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation','terminal_four_contact_recovery'], evaluation['false_walking_receipts'])
        self.assertEqual(.10150327599350759,evaluation['forward_advance_m'])
        self.assertEqual(.006525557526161074,evaluation['absolute_lateral_drift_m'])
        self.assertEqual(.12171694711843024,evaluation['maximum_tilt_rad'])
        self.assertEqual(.11009083279383085,evaluation['yaw_drift_rad'])
        self.assertEqual(0,evaluation['torso_contact_step_count'])
        self.assertEqual(0,self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        indices = {'rear_left':0,'front_left':1,'rear_right':2,'front_right':3}
        cycles,gaps = [],{}
        for name,index in indices.items():
            bearing,released = True,None
            for row in self.rows:
                contact = row['contact_by_limb'][name]
                if bearing and not contact:
                    released = row
                elif not bearing and contact and released is not None:
                    a,b = released['walking_session_local_step'],row['walking_session_local_step']
                    if b-a>=evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        forward = sum((row['foot_position_world_m_by_limb'][name][i]-released['foot_position_world_m_by_limb'][name][i])*axis[i] for i in range(3))
                        memory = next(m for m in self.entries[a]['request']['memory']['ordered_limb_memory'] if m['limb_id']==name)
                        phase = (memory['gait_step']+360-index*90)%360
                        cycles.append(dict(limb=name,release=a,touchdown=b,forward_m=forward,release_phase=phase))
                    released = None
                bearing = contact
            selected = [c for c in cycles if c['limb']==name]
            self.assertEqual(len(selected),evaluation['contact_cycle_count_by_limb'][name])
            self.assertEqual(min(c['forward_m'] for c in selected),evaluation['minimum_cycle_forward_relocation_by_limb_m'][name])
            gaps[name] = None if released is None else [released['walking_session_local_step'],401-released['walking_session_local_step']]
        self.assertEqual([('rear_left',283,333),('rear_left',348,369),('front_left',27,34),('front_left',42,105),
            ('front_left',137,186),('front_left',200,209),('front_left',273,281),('rear_right',33,45),('rear_right',55,127),
            ('rear_right',139,243),('rear_right',255,268),('rear_right',312,316),('front_right',271,309),
            ('front_right',321,355),('front_right',385,400)],[(c['limb'],c['release'],c['touchdown']) for c in cycles])
        failed = [c for c in cycles if c['forward_m']<evaluation['fixed_thresholds']['minimum_foot_relocation_m']]
        self.assertEqual(10,len(failed))
        self.assertEqual(7,sum(c['release_phase']>=72 for c in failed))
        self.assertEqual({'rear_left':[396,5],'front_left':None,'rear_right':None,'front_right':None},gaps)
        self.assertEqual({'front_left':True,'front_right':True,'rear_left':False,'rear_right':True},self.rows[-1]['contact_by_limb'])
        final = self.entries[400]['native_output']['next_memory']['ordered_limb_memory']
        self.assertEqual([396,396,396,385],[m['gait_step'] for m in final])
        self.assertTrue(all(m['gait_step']-90<360 for m in final))
        print('V33_PHYSICAL_PLACEMENT_AUDIT',json.dumps(dict(cycles=cycles,failed_cycle_count=len(failed),
            failed_cycles_starting_outside_scheduled_swing=7,terminal_open_flights=gaps,
            causal_attribution_proven=False,world_build_count=0,solver_step_count=0,
            physical_acceptance_authority=False),separators=(',',':')),flush=True)

    def test_promotion_refuses_and_old_records_are_unchanged(self):
        for key,value in [('successful_recovery_proven',True),('complete_route_proven',True),('physical_acceptance_authority',True),
                          ('release_authority',True),('repeat_consumed_attempt_permitted',True),('status','passed'),('solver_step_count',1259)]:
            with self.subTest(key=key),self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record,**{key:value}),self.observed)
        for relative in ('sdk/development/recovery_attempts/987a8848999d457a820c078eb9273dbb.json',
                         'sdk/development/recovery_swing_end_placement_diagnosis_v1.json',
                         'sdk/development/recovery_stance_plane_feasibility_v1.json',
                         'sdk/development/recovery_bounded_support_component_v1.json',
                         'sdk/development/recovery_bounded_support_route_integration_v1.json',
                         'sdk/development/recovery_candidates/v33-bounded-support-integrated-v1.json',
                         'sdk/development/recovery_schedules/v33-bounded-support-integrated-v1.json',
                         'sdk/core/src/runtime.rs','sdk/core/src/recovery_runtime.rs','sdk/core/src/recovery_support_plane.rs',
                         'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(closure.prior.committed(relative,SOURCE),(ROOT/relative).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',closure.smoke.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))


if __name__=='__main__':
    unittest.main()
