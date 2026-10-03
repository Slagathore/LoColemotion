"""Shared independent reader rejects rehashed hold-posture and guard corruption."""
import copy
import hashlib
import json
import unittest
import test_development_v44_floor_adapter as shared
import test_development_v43_progression_reader as guard
from test_development_passive_entry_replay import marker


class PostureReader(shared.SupportHoldPostureFloorAdapter):
    run_label='V44-posture'

    def test_hold_posture_and_progression_receipts_refuse_corruption(self):
        guard.ProgressionReader.test_progression_memory_and_rehashed_receipt_refusals(self)
        positive=dict(report=self.producer['result']['report'],policy_id=self.policy_id)
        rows=positive['report']['development_walking_entry']['rows']
        index=next(i for i,r in enumerate(rows) if i>0 and r['native_output']['actuation']['receipt']['recovery_support_plane']['support_hold_posture']['enabled'])
        names=('missing','schema','mode','source_step','enabled','effective_lift','effective_angle','effective_phase',
            'comparison_lift','comparison_phase','scheduled_memory_claim','observations_claim','authority','upright_selector')
        cases={'positive':positive};api=self.native_api()
        for name in names:
            item=copy.deepcopy(positive);row=item['report']['development_walking_entry']['rows'][index]
            act=row['native_output']['actuation'];support=act['receipt']['recovery_support_plane'];p=support['support_hold_posture']
            if name=='missing':del support['support_hold_posture']
            elif name=='schema':p['schema_version']='crossed'
            elif name=='mode':p['mode_id']='crossed'
            elif name=='source_step':p['source_semantic_step']+=1
            elif name=='enabled':p['enabled']=False
            elif name=='effective_lift':p['effective_reference_wave']['ordered_limbs'][0]['walking_knee_fraction']=.5
            elif name=='effective_angle':p['effective_reference_wave']['ordered_limbs'][0]['nominal_leg_direction_rad']+=.01
            elif name=='effective_phase':p['effective_reference_wave']['ordered_limbs'][0]['scheduled_phase_step']+=1
            elif name=='comparison_lift':p['same_mode_comparison_wave']['ordered_limbs'][0]['walking_knee_fraction']=.5
            elif name=='comparison_phase':p['same_mode_comparison_wave']['ordered_limbs'][0]['scheduled_phase_step']+=1
            elif name=='scheduled_memory_claim':p['scheduled_wave_memory_preserved']=False
            elif name=='observations_claim':p['measured_pose_and_contact_preserved']=False
            elif name=='authority':p['physical_acceptance_authority']=True
            else:support['upright_stance']['ordered_limbs'][0]['upright_reference_selected']=False
            act['receipt_sha256']='sha256:'+hashlib.sha256(api.canonical(act['receipt'])).hexdigest();cases[name]=item
        path=self.root/'hold_posture_reader_inputs.json'
        with path.open('x',encoding='utf-8') as stream:json.dump(cases,stream,separators=(',',':'),allow_nan=False)
        run=self._run_retained(self.fixture,['--',str(path)],'support_hold_posture_cold_reader',90)
        results=marker(run,'V34_FLOOR_READER ')
        self.assertEqual(15,len(results));self.assertTrue(results['positive']['ok']);self.assertEqual(200,results['positive']['replayed_walking_steps'])
        for name,result in results.items():
            if name!='positive':
                self.assertFalse(result['ok'],name);self.assertEqual('DEVELOPMENT_WALKING_ENTRY_READER_NATIVE_OUTPUT_MISMATCH',result['failure_code'])
        print('V44_POSTURE_COLD_READER',json.dumps(dict(positive_steps=200,refused_cases={k:v['failure_code'] for k,v in results.items() if k!='positive'},
            changed_receipts_rehashed=True,synthetic_inputs_only=True,world_build_count=0,solver_step_count=0)),flush=True)


def load_tests(_loader,_tests,_pattern):
    return unittest.TestSuite([PostureReader('test_hold_posture_and_progression_receipts_refuse_corruption')])


if __name__=='__main__':unittest.main()
