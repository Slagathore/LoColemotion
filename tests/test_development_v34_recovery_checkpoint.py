"""Cold V34 closure: real floor context, bounded commands, exact walking negative."""
import json
from pathlib import Path
import unittest
from unittest import mock

import test_development_v27_recovery_checkpoint as prior

closure = prior.closure
ROOT = Path(__file__).resolve().parents[1]
ATTEMPT = 'beb9c66e4c194930b6283fd227613f44'
SOURCE = 'ef4636af0eaac60a997d43547178d575ec52b1f9'
POLICY = 'sporespore_balanced_wave_recovery_floor_support_v1'


class V34Checkpoint(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = closure.smoke.read(ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json'))
        cls.observed = closure.observe(Path(cls.record['evidence_root']), distal_body_origins=True)
        cls.report = closure.smoke.read(Path(cls.record['kicked_report']['path']))
        cls.arm = cls.report['retained_arm']
        cls.packets = {p['global_semantic_step']:p for p in cls.report['passive_entry']['canonical_packets']}
        cls.resume = next(s for s in cls.arm['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
        cls.rows = [r for r in cls.arm['trace_rows'] if r.get('walking_session_id')==cls.resume['session_id']]
        cls.entries = cls.report['development_walking_entry']['rows']

    def test_original_population_freeze_and_independent_replay(self):
        closure.smoke.validate_checkpoint(self.record,self.observed)
        self.assertEqual(SOURCE,self.record['source_snapshot']['head'])
        self.assertFalse(self.record['source_snapshot']['dirty'])
        self.assertEqual('closed_consumed_valid_development_observation',self.record['status'])
        self.assertEqual((113,1,1258),tuple(self.record[k] for k in ('safety_test_count','world_count','solver_step_count')))
        self.assertEqual((63,1065502894),tuple(self.record['retained_population'][k] for k in ('file_count','byte_length')))
        self.assertEqual('sha256:1a74cc6488922dc5534e24ddeb8abe9847caf2fa2e35a3c8d94f4cd641cf0db9',self.record['retained_population']['inventory_sha256'])
        self.assertEqual('sha256:caee59937ad3f6ba161c4eb2b0ccd8792cf8eedfd4865853109c73dcaa04e63d',self.record['kicked_report']['raw_sha256'])
        replay = self.record['children'][0]['passive_entry_replay']
        self.assertEqual((1258,467,119,1),tuple(replay[k] for k in ('transition_count','canonical_observation_count','entry_observation_count','canonical_initialization_count')))
        self.assertEqual(430,replay['walking_contact_validation']['validated_native_contact_steps'])
        self.assertEqual(400,replay['walking_control_replay']['replayed_walking_steps'])
        self.assertEqual(POLICY,replay['walking_policy_validation']['policy_id'])
        for key in ('world_build_count','solver_step_count','native_physics_read_count'):
            self.assertEqual(0,replay[key])

    def test_own_standing_commands_and_unchanged_body(self):
        prior.V27Checkpoint.test_actual_reference_ramp_and_unchanged_standing_completion(self)
        self.assertEqual((859,1258,400),(self.rows[0]['global_semantic_step'],self.rows[-1]['global_semantic_step'],len(self.rows)))
        self.assertEqual({90},set(self.resume['start_receipt']['initial_gait_steps'].values()))
        self.assertEqual(POLICY,self.resume['start_receipt']['selected_policy_id'])

    def test_all_floor_sources_and_3200_bounded_references(self):
        source = self.resume['start_receipt']['development_floor_source']
        g = source['geometry']
        self.assertEqual(self.arm['model_instance_id'],g['model_instance_id'])
        self.assertLess(int(g['shape_resource_instance_id']),0)  # Actual signed Godot resource ID.
        self.assertEqual([-10.,10.],g['x_interval_m'])
        self.assertEqual([-10.,10.],g['z_interval_m'])
        self.assertEqual(0.,g['shape_center_world_m'][1]+g['size_m'][1]/2)
        self.assertEqual(g['top_world_y_m'],source['floor_reference']['height_world_m'])
        self.assertFalse(source['native_contact_measurement'])
        commands = slew = projected = 0
        residual = 0.
        for local,row in enumerate(self.entries,1):
            request,output = row['request'],row['native_output']
            self.assertEqual(local,row['session_local_step'])
            self.assertEqual(source,row['development_floor_source'])
            self.assertEqual(source['floor_reference'],request['floor_reference'])
            receipt = output['actuation']['receipt']['recovery_support_plane']
            self.assertEqual(request['floor_reference'],receipt['floor_reference'])
            self.assertEqual('explicit_horizontal_floor_bounded_support_reference_slew_v1',receipt['mode_id'])
            # Raw native replay is exact; this displayed field has JSON decimal projection.
            self.assertAlmostEqual(request['state']['base_pose_world']['position_m']['y']-request['floor_reference']['height_world_m'],receipt['proposed_torso_height_m'],delta=1e-14)
            self.assertFalse(receipt['all_limb_contact_claim'])
            self.assertEqual('contact_gated',request['command']['phase_progression_mode'])
            t = min((local-1)/72,1)
            self.assertAlmostEqual((1.1/(.82*1.75+.4))*t*t*(3-2*t),request['command']['gait_amplitude'],places=14)
            if local>1:
                self.assertEqual(self.entries[local-2]['native_output']['next_memory'],request['memory'])
            else:
                self.assertNotIn('floor_reference_sha256',request['memory'])
                self.assertTrue(receipt['first_step_holds_neutral_reference'])
            self.assertEqual(output['next_memory']['floor_reference_sha256'],self.entries[0]['native_output']['next_memory']['floor_reference_sha256'])
            for i,c in enumerate(output['actuation']['ordered_commands']):
                lo,hi = (-.72,.72) if i%2==0 else (0.,1.1)
                target = c['requested_target_position_rad']
                self.assertLessEqual(lo,target); self.assertLessEqual(target,hi)
                self.assertEqual(target,c['clamped_target_position_rad'])
                self.assertFalse(c['position_saturated'])
                old = request['memory']['support_reference']['ordered_target_positions_rad'][i]
                # Existing pre-physics binary64 arithmetic allowance, not a behavioral threshold.
                self.assertLessEqual(abs(target-old),c['maximum_target_speed_rad_s']*receipt['reference_step_duration_s']+1e-14)
                commands += 1; slew += c['slew_limited']
            for p in receipt['ordered_limb_proposals']:
                projected += p['link_reach_projection_required']
                self.assertFalse(p['support_joint_projection_required'])
                residual = max(residual,abs(p['projected_support_nominal_plane_residual_m']))
        self.assertEqual((3200,120,778),(commands,slew,projected))
        self.assertEqual(.01419273006318073,residual)

    def test_original_walking_failures_cycles_and_native_timeout(self):
        e = self.resume['evaluation']
        self.assertFalse(e['behavior_passed'])
        self.assertEqual(['every_limb_forward_relocation','every_limb_two_contact_cycles','minimum_evidence_forward_translation','minimum_final_forward_translation'],e['false_walking_receipts'])
        self.assertEqual(.019951651740741427,e['forward_advance_m'])
        self.assertLess(e['forward_advance_m'],e['fixed_thresholds']['minimum_forward_advance_m'])
        self.assertEqual((.005492380489120929,.05241498037961852,.04179125885265478,0),tuple(e[k] for k in ('absolute_lateral_drift_m','maximum_tilt_rad','yaw_drift_rad','torso_contact_step_count')))
        self.assertTrue(e['walking_gate_receipts']['terminal_four_contact_recovery'])
        self.assertTrue(all(self.rows[-1]['contact_by_limb'].values()))
        axis = self.resume['start_receipt']['task_frame_forward_axis_world_host_real']
        for limb in self.rows[-1]['contact_by_limb']:
            bearing,release,cycles = True,None,[]
            for row in self.rows:
                current = row['contact_by_limb'][limb]
                if bearing and not current: release = row
                elif not bearing and current and release is not None:
                    if row['walking_session_local_step']-release['walking_session_local_step']>=e['fixed_thresholds']['minimum_airborne_dwell_steps']:
                        # Preserve the original distal-body-origin metric; not sole placement or force.
                        cycles.append(sum((row['foot_position_world_m_by_limb'][limb][i]-release['foot_position_world_m_by_limb'][limb][i])*axis[i] for i in range(3)))
                    release = None
                bearing = current
            self.assertEqual(len(cycles),e['contact_cycle_count_by_limb'][limb])
            self.assertEqual(min(cycles) if cycles else None,e['minimum_cycle_forward_relocation_by_limb_m'][limb])
        self.assertEqual({'front_left':4,'front_right':0,'rear_left':0,'rear_right':5},e['contact_cycle_count_by_limb'])
        self.assertEqual(1,self.record['walking_control_diagnosis']['actual_native_gate_timeout_total'])
        # Frozen evaluator's summary-derived flag is not the native timeout counter.
        self.assertTrue(e['walking_gate_receipts']['contact_gating_completed_without_timeout'])
        before = next(m for m in self.entries[195]['request']['memory']['ordered_limb_memory'] if m['limb_id']=='front_left')
        after = next(m for m in self.entries[195]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id']=='front_left')
        self.assertEqual((120,162,0),(before['current_gate_hold_steps'],before['gait_step'],before['gate_timeout_count']))
        self.assertEqual((0,163,1),(after['current_gate_hold_steps'],after['gait_step'],after['gate_timeout_count']))

    def test_frozen_contract_selector_corruptions_and_claim_promotions_refuse(self):
        schedule = json.loads(closure.prior.committed('sdk/development/recovery_schedules/v34-floor-support-integrated-v1.json',SOURCE))['schedules']['v34-floor-support-integrated-v1']
        sources = closure.walking_entry_rule_sources(schedule,SOURCE)
        self.assertIn('sdk/adapters/godot/gdscript/development_recovery_floor_source_v1.gd',[s['path'] for s in sources])
        for key,value in [('walking_entry_profile_id','wrong'),('walking_start_profile_id','wrong'),('walking_policy_id','wrong'),('walking_policy_contract_sha256','sha256:'+'0'*64),('runtime_sha256','sha256:'+'0'*64)]:
            with self.subTest(key=key),self.assertRaises(ValueError):
                closure.walking_entry_rule_sources(dict(schedule,**{key:value}),SOURCE)
        real = closure.prior.committed
        def corrupt(path,commit):
            raw = real(path,commit)
            return raw+b'\n' if path.endswith('development_recovery_floor_source_v1.gd') else raw
        with mock.patch.object(closure.prior,'committed',side_effect=corrupt),self.assertRaisesRegex(ValueError,'BOUND_SOURCE'):
            closure.walking_entry_rule_sources(schedule,SOURCE)
        for key,value in [('successful_recovery_proven',True),('complete_route_proven',True),('physical_acceptance_authority',True),('release_authority',True),('repeat_consumed_attempt_permitted',True),('status','passed'),('solver_step_count',1259)]:
            with self.subTest(key=key),self.assertRaises(ValueError):
                closure.smoke.validate_checkpoint(dict(self.record,**{key:value}),self.observed)
        for path in ('sdk/core/src/runtime.rs','sdk/core/src/recovery_support_plane.rs','sdk/core/src/recovery_floor_reference.rs','sdk/development/recovery_candidates/v34-floor-support-integrated-v1.json','sdk/development/recovery_schedules/v34-floor-support-integrated-v1.json','sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'):
            self.assertEqual(real(path,SOURCE),(ROOT/path).read_bytes())
        self.assertEqual('sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f',closure.smoke.sha(ROOT/'sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json'))

    def test_old_source_resolution_unchanged_without_requalifying_old_launch_graph(self):
        # The current launch validator intentionally refuses V33 after V34 changed its
        # dependency graph. Compare the two pure archival resolvers on V33's frozen
        # tree; do not relaunch V33 or pretend its old graph is current-qualified.
        namespace = {'__file__':str(ROOT/'sdk/conformance/development_recovery_candidate_checkpoint.py'),'__name__':'frozen_closure_reader'}
        raw = closure.prior.committed('sdk/conformance/development_recovery_candidate_checkpoint.py',SOURCE)
        exec(compile(raw,namespace['__file__'],'exec'),namespace)
        old_source = '320668509058bfadcb31d66b4e83d67fbb783202'
        old_schedule = json.loads(closure.prior.committed('sdk/development/recovery_schedules/v33-bounded-support-integrated-v1.json',old_source))['schedules']['v33-bounded-support-integrated-v1']
        self.assertEqual(namespace['walking_entry_rule_sources'](old_schedule,old_source),closure.walking_entry_rule_sources(old_schedule,old_source))
        old = ROOT/'sdk/development/recovery_attempts/4e5cacbc49e64ceab61fff2762217804.json'
        self.assertEqual('sha256:42aa3ca80ec16a8c8f7fae1a592d64375cc0e7c163ee236973c8ea2d08a52651',closure.smoke.sha(old))


if __name__=='__main__':
    unittest.main()
