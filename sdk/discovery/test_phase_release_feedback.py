"""Independent release equations, full-cycle real ABI and corruption controls."""
import copy
from itertools import islice
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
from adaptation_provider import phase_release_feedback_v1 as model
from adaptation_provider import support_vertical_feedback_v1 as parent
from audit_gpu_batch_execution import same_bits
from audit_phase_release import validate_proposal
from cpu_phase_release_task import declaration, ROOT
from cpu_support_vertical_task import declaration as old_declaration
from phase_release_control import PhaseReleaseController
from support_vertical_control import SupportVerticalController
from portable_search_control import bridge
import test_gpu_repertoire_v2 as fixtures


class PhaseReleaseFeedbackControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass();cls.f=fixtures.RepertoireControls
        cls.model=model.definition();cls.c=declaration();cls.old=old_declaration()
        cls.cores=[bridge.LocomotionCore(Path(os.environ[k])) for k in ['QUADRUPED_TEST_CORE','PORTABLE_BATCH_BASELINE_CORE']]
        closure=json.loads((ROOT/'sdk/discovery/cpu_support_vertical_closure_v1.json').read_text())
        path=ROOT.parent/'SporeSpore_Evidence'/closure['attempt_id']/'physical/left_075_train_001_vertical_immediate/controller.jsonl'
        with path.open(encoding='utf-8') as stream:
            cls.rows=list(islice((json.loads(line) for line in stream),360))

    def setUp(self):
        for name in ['MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward']:
            guard=patch.object(mujoco,name,side_effect=AssertionError('No worlds in phase controls'))
            guard.start();self.addCleanup(guard.stop)

    def request(self,index=60):
        return copy.deepcopy(self.rows[index]['resolution_request']['provider_request'])

    def evaluate(self,request=None):
        r=self.request() if request is None else request
        return model.feedback(r['state'],r['command'],self.model['candidates'][4],self.model,
            r['deterministic_baseline'],r['controller_context'])

    def test_parent_family_and_taper_derive_from_unchanged_limits(self):
        self.assertEqual(self.model['candidates'][:4],parent.expected_candidates())
        new=self.model['candidates'][4];old=self.model['candidates'][3]
        self.assertEqual({k:v for k,v in new.items() if k not in ['id','phase_release']},
            {k:v for k,v in old.items() if k!='id'})
        self.assertEqual(math.ceil(new['maximum_absolute_correction_rad_s']/new['maximum_slew_per_step_rad_s']),44)
        self.assertFalse(self.model['phase_release_rule']['phase_modified'])
        self.assertFalse(self.model['phase_release_rule']['resolver_limits_modified'])
        for key in ['trained','training_data_authority','physical_acceptance_authority','release_authority','equivalence_authority']:
            self.assertFalse(self.model[key])

    def test_phase_boundaries_and_wrap_use_context_not_wall_clock(self):
        context=self.request()['controller_context']
        for local,weight in [(0,0.),(71,0.),(72,1.),(315,1.),(316,1.),(317,43/44),(359,1/44),(360,0.)]:
            memory=context['controller_memory']
            for i,limb in enumerate(memory['ordered_limb_memory']):limb['gait_step']=local+90*i
            actual=model.weights(context,60)
            self.assertTrue(all(p['local_phase_step']==local%360 and p['weight']==weight for p in actual.values()))

    def test_equation_matches_independent_parent_clamp_then_weight(self):
        for index in [0,46,60,71,72,89,90,179,269,359]:
            r=self.request(index);actual,detail=self.evaluate(r)
            old,_=parent.feedback(r['state'],r['command'],parent.expected_candidates()[3],parent.definition(),r['deterministic_baseline'])
            offsets={'rear_left':0,'front_left':90,'rear_right':180,'front_right':270}
            for i,leg in enumerate(detail['legs']):
                local=(index-offsets[leg['limb_id']])%360
                weight=0. if local<72 else min(1.,(360-local)/44.)
                expected=[weight*max(-3.5,min(3.5,v)) for v in old[2*i:2*i+2]] if weight else [0.,0.]
                self.assertEqual(actual[2*i:2*i+2],expected)
                self.assertTrue(all(abs(v)<=3.5*weight for v in expected))

    def test_release_envelope_reaches_zero_under_adversarial_raw_changes(self):
        # Independent resolver recurrence tests sign changes and saturation,
        # including the worst initial correction at the start of the taper.
        for initial in [-3.5,3.5]:
            applied=initial
            for local in range(316,361):
                raw=(100. if local%2 else -100.)
                weight=(360-local)/44 if local<360 else 0.
                requested=max(-3.5,min(3.5,raw))*weight
                applied=max(applied-.08,min(applied+.08,requested))
                self.assertLessEqual(abs(applied),3.5*weight+1e-12)
            self.assertAlmostEqual(applied,0.,places=12)

    def test_invalid_context_phase_order_clock_and_domain_refuse(self):
        for mutate in [lambda r:r['controller_context'].__setitem__('source_policy_id','other'),
            lambda r:r['controller_context'].__setitem__('engine_specific',True),
            lambda r:r['controller_context']['controller_memory'].__setitem__('last_semantic_step',0),
            lambda r:r['controller_context']['controller_memory'].__setitem__('phase_progression_mode','contact_gated'),
            lambda r:r['controller_context']['controller_memory']['ordered_limb_memory'].reverse(),
            lambda r:r['controller_context']['controller_memory']['ordered_limb_memory'][0].__setitem__('gait_step',True),
            lambda r:r['controller_context']['controller_memory']['ordered_limb_memory'][0].__setitem__('gait_step',-1)]:
            r=self.request();mutate(r)
            with self.assertRaises(ValueError):self.evaluate(r)

    def test_reference_provider_preserves_exact_parent_feedback(self):
        for row in self.rows[:96]:
            r=row['resolution_request']['provider_request']
            expected=parent.feedback(r['state'],r['command'],self.model['candidates'][3],parent.definition(),r['deterministic_baseline'])
            actual=model.feedback(r['state'],r['command'],self.model['candidates'][3],self.model,r['deterministic_baseline'],None)
            self.assertTrue(same_bits(actual,expected))

    def test_full_cycle_two_core_resolver_and_parent_targets_agree(self):
        controllers=[PhaseReleaseController(core,self.f.compiled,self.c,2) for core in self.cores]
        reference=PhaseReleaseController(self.cores[0],self.f.compiled,self.c,1)
        old=SupportVerticalController(self.cores[1],self.f.compiled,self.old,2)
        previous=[[0.]*8,[0.]*8];partial=zero=0
        try:
            for row in self.rows:
                args=(row['request']['state'],row['stability'],row['kinematics'])
                values=[controller.step(*args) for controller in controllers]
                self.assertTrue(same_bits(values[0],values[1]))
                for i,value in enumerate(values):
                    validate_proposal(value,self.c,2,previous[i])
                    previous[i]=[c['applied_correction_rad_s'] for c in value['resolution']['ordered_commands']]
                a,b=reference.step(*args),old.step(*args)
                self.assertTrue(same_bits(a['native_targets'],b['native_targets']))
                self.assertTrue(same_bits(a['feedback'],b['feedback']))
                for leg in values[0]['feedback']['legs']:
                    weight=leg['phase_release']['weight'];partial+=0.<weight<1.;zero+=weight==0.
                    if weight==0.:
                        i=model.parent.geometry.LEGS.index(leg['limb_id'])
                        self.assertTrue(all(abs(v)<1e-12 for v in previous[0][2*i:2*i+2]))
            self.assertEqual((partial,zero),(172,288))
            print(json.dumps(dict(real_abi_decisions=1440,independent_cores=2,full_cycle_commands=360,
                partial_release_leg_observations=partial,scheduled_swing_leg_observations=zero,world_build_count=0)))
        finally:
            for controller in controllers+[reference,old]:controller.close()

    def test_corrupt_context_withdraws_without_stale_correction(self):
        controller=PhaseReleaseController(self.cores[0],self.f.compiled,self.c,2)
        self.addCleanup(controller.close)
        row=self.rows[0];value=controller.step(row['request']['state'],row['stability'],row['kinematics'])
        r=copy.deepcopy(value['resolution_request']['provider_request'])
        r['controller_context']['controller_memory']['phase_progression_mode']='other'
        response,detail=controller.response(r)
        self.assertIsNone(response);self.assertEqual(detail['status'],'refused')
        resolved=self.cores[0].resolve_adaptation_v1(dict(schema_version='sporespore_adaptation_resolution_request_v1',
            provider_request=value['resolution_request']['provider_request'],provider_response=response))
        self.assertTrue(resolved['deterministic_baseline_fallback_used'])
        self.assertTrue(all(c['applied_correction_rad_s']==0. for c in resolved['ordered_commands']))

    def test_independent_reader_rejects_changed_weight_and_proposal(self):
        controller=PhaseReleaseController(self.cores[0],self.f.compiled,self.c,2)
        self.addCleanup(controller.close)
        previous=[0.]*8
        for row in self.rows[:61]:
            value=controller.step(row['request']['state'],row['stability'],row['kinematics'])
            if row['outer_step']==60:break
            previous=[c['applied_correction_rad_s'] for c in value['resolution']['ordered_commands']]
        for kind in ['weight','proposal','memory']:
            bad=copy.deepcopy(value)
            if kind=='weight':bad['feedback']['legs'][0]['phase_release']['weight']=1.
            elif kind=='proposal':bad['resolution_request']['provider_response']['ordered_corrections'][0]['canonical_velocity_delta_rad_s']+=.01
            else:bad['resolution_request']['provider_request']['controller_context']['controller_memory']['last_semantic_step']=59
            with self.assertRaises(ValueError):validate_proposal(bad,self.c,2,previous)

    def test_parent_rule_and_authority_corruption_refuse(self):
        original=Path.read_text
        for mutate in [lambda d:d['parent_implementation'].__setitem__('sha256','0'*64),
            lambda d:d['phase_release_rule'].__setitem__('taper_commands',43),
            lambda d:d.__setitem__('trained',True),lambda d:d.__setitem__('release_authority',True)]:
            value=json.loads(original(model.CONTRACT,encoding='utf-8'));mutate(value)
            with patch.object(Path,'read_text',autospec=True,
                side_effect=lambda p,*a,**kw:json.dumps(value) if p==model.CONTRACT else original(p,*a,**kw)):
                with self.assertRaises(ValueError):model.definition()


if __name__=='__main__':unittest.main()
