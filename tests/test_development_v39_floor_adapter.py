"""V39 real adapter, retention and cold reader on 200 synthetic inputs."""
import copy
import hashlib
import json
import unittest
import test_development_v34_floor_adapter as shared


class AirborneReferenceFloorAdapter(shared.FloorAdapter):
    policy_id = 'sporespore_balanced_wave_recovery_airborne_reference_v1'
    candidate_id = 'v39-airborne-reference-v1'
    fixture = 'res://tests/test_development_v39_floor_adapter.gd'
    run_label = 'V39'
    receipt_schema = 'sporespore_recovery_airborne_reference_controller_step_receipt_v1'
    reference_mode = 'contact_selected_airborne_reference_velocity_tracking_v1'
    minimum_cold_probe_phase = 0
    require_selected_stance = False

    def selected_phase(self, phase):
        return 0 <= phase <= 72

    def test_actual_constructor_adapter_and_ledger(self):
        super().test_actual_constructor_adapter_and_ledger()
        rows = self.producer['result']['report']['development_walking_entry']['rows']
        self.assertEqual(200,len(rows)); selected_count=0; selected_stance_count=0
        api=self.native_api()
        for row in rows:
            output=row['native_output']['actuation']; state=row['request']['state']
            self.assertEqual(self.receipt_schema,output['receipt']['schema_version'])
            receipt=output['receipt']['recovery_support_plane']; wave=receipt['wave_velocity']; air=receipt['airborne_reference']
            self.assertEqual(self.reference_mode,receipt['reference_velocity_mode_id'])
            rates=receipt['ordered_reference_velocity_rad_s']; full=air['ordered_full_reference_velocity_rad_s']
            self.assertEqual(8,len(rates));self.assertEqual(8,len(full));self.assertEqual(4,len(air['ordered_limbs']))
            self.assertEqual(row['request']['memory']['support_reference'].get('previous_wave'),wave['previous_wave'])
            self.assertEqual(row['native_output']['next_memory']['support_reference']['previous_wave'],wave['current_wave'])
            self.assertEqual(state['semantic_step'],air['source_semantic_step'])
            # Godot's parsed receipt can round the last decimal places. Compare
            # its timestamp under the existing canonical-number policy; the cold
            # reader separately checks the exact original native-response hash.
            self.assertEqual(api.canonical(dict(sample_time_s=state['sample_time_s'])),
                             api.canonical(dict(sample_time_s=air['source_sample_time_s'])))
            self.assertEqual(state['adapter_capability_sha256'],air['source_adapter_capability_sha256'])
            dt=receipt['reference_step_duration_s']
            for i,command in enumerate(output['ordered_commands']):
                cap=command['maximum_target_speed_rad_s'];target=command['requested_target_position_rad']
                contact=state['ordered_contact_observations'][i//2];limb=air['ordered_limbs'][i//2]
                phase=wave['current_wave']['ordered_limbs'][i//2]['scheduled_phase_step']
                self.assertEqual(contact,limb['precommand_contact']);self.assertEqual(phase,limb['scheduled_phase_step'])
                selected=wave['feedforward_active'] and dt>0 and self.selected_phase(phase) and contact['presence'] is False and contact['bears_support'] is False
                self.assertEqual(selected,limb['full_reference_rate_selected']);selected_count+=selected
                selected_stance_count+=selected and phase>72
                previous=row['request']['memory']['support_reference']['ordered_target_positions_rad'][i]
                full_rate=max(-cap,min(cap,(target-previous)/dt)) if dt>0 else 0.
                self.assertAlmostEqual(full_rate,full[i],delta=1e-13)
                fallback=max(-cap,min(cap,(target-wave['ordered_comparison_reference_rad'][i])/dt)) if dt>0 and wave['feedforward_active'] else 0.
                rate=full_rate if selected else fallback
                self.assertAlmostEqual(rate,rates[i],delta=1e-13);self.assertLessEqual(abs(rates[i]),cap)
                joint=state['ordered_joint_observations'][i]
                raw=8.*(target-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
                self.assertAlmostEqual(-max(-cap,min(cap,raw)),command['target_velocity_rad_s'],delta=1e-12)
                self.assertEqual(abs(raw)>cap,command['velocity_saturated'])
        self.assertTrue(0<selected_count<1600)
        if self.require_selected_stance: self.assertGreater(selected_stance_count,0)
        print(self.run_label+'_ADAPTER_SELECTOR_RECONSTRUCTION',json.dumps(dict(commands=200,joint_commands=1600,
            selected_joint_commands=selected_count,unselected_joint_commands=1600-selected_count,
            selected_stance_joint_commands=selected_stance_count,
            all_contact_provenance_matches=True,all_rates_and_motors_reconstructed=True,
            synthetic_inputs_only=True,world_build_count=0,solver_step_count=0)),flush=True)

    def test_cold_reader_complete_population_and_fourteen_refusals(self):
        super().test_cold_reader_complete_population_and_fourteen_refusals()
        positive=dict(report=self.producer['result']['report'],policy_id=self.policy_id)
        rows=positive['report']['development_walking_entry']['rows']
        index=next(i for i,r in enumerate(rows) if any(l['full_reference_rate_selected'] and l['scheduled_phase_step']>=self.minimum_cold_probe_phase
            for l in r['native_output']['actuation']['receipt']['recovery_support_plane']['airborne_reference']['ordered_limbs']))
        cases={'positive':positive};api=self.native_api()
        for name in ('selector','contact','source_step','source_time','full_rate','selected_rate',
                     'comparison_reference','missing_receipt','motor_velocity'):
            item=copy.deepcopy(positive);row=item['report']['development_walking_entry']['rows'][index]
            act=row['native_output']['actuation'];support=act['receipt']['recovery_support_plane'];air=support['airborne_reference']
            limb=next(l for l in air['ordered_limbs'] if l['full_reference_rate_selected'] and l['scheduled_phase_step']>=self.minimum_cold_probe_phase)
            if name=='selector': limb['full_reference_rate_selected']=False
            elif name=='contact': limb['precommand_contact']['presence']=True
            elif name=='source_step': air['source_semantic_step']+=1
            elif name=='source_time': air['source_sample_time_s']+=.01
            elif name=='full_rate': air['ordered_full_reference_velocity_rad_s'][0]+=.01
            elif name=='selected_rate': support['ordered_reference_velocity_rad_s'][0]+=.01
            elif name=='comparison_reference': support['wave_velocity']['ordered_comparison_reference_rad'][0]+=.01
            elif name=='missing_receipt': del support['airborne_reference']
            else: act['ordered_commands'][0]['target_velocity_rad_s']+=.01
            # Rehash the edited receipt. The independent reader must still
            # reject it against the native output, not trust a self-consistent hash.
            act['receipt_sha256']='sha256:'+hashlib.sha256(api.canonical(act['receipt'])).hexdigest()
            cases[name]=item
        path=self.root/'airborne_reader_inputs.json'
        with path.open('x',encoding='utf-8') as stream:
            json.dump(cases,stream,separators=(',',':'),allow_nan=False)
        run=self._run_retained(self.fixture,['--',str(path)],'airborne_cold_reader',90)
        results=shared.shared.marker(run,'V34_FLOOR_READER ')
        self.assertEqual(10,len(results));self.assertTrue(results['positive']['ok'])
        self.assertEqual(200,results['positive']['replayed_walking_steps'])
        for name,result in results.items():
            if name!='positive':
                self.assertFalse(result['ok'],(name,result))
                self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_NATIVE_OUTPUT_MISMATCH',result['failure_code'])
        # Keep console receipts compact; the complete cold-reader output is retained.
        print(self.run_label+'_AIRBORNE_COLD_READER',json.dumps(dict(positive_steps=200,refused_cases={
            name:r['failure_code'] for name,r in results.items() if name!='positive'},
            changed_receipts_rehashed=True,world_build_count=0,solver_step_count=0)),flush=True)


if __name__=='__main__':
    unittest.main()
