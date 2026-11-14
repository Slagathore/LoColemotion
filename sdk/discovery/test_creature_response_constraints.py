"""Constraint-aware feedback, withdrawal and legacy isolation without worlds."""
import copy
import json
import os
from pathlib import Path
import unittest
from contextlib import ExitStack
from unittest.mock import patch
import mujoco
import numpy as np

import creature_response_search as search
import creature_response_constraints as subject
import creature_joint_braking as braking
import creature_native as route
import creature_righting as righting
import test_creature_response_probe as legacy
from test_portable_search import _fixture


class ResponseConstraintControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=search.probe.bridge.LocomotionCore(Path(os.environ['QUADRUPED_TEST_CORE']))
        cls.template=_fixture(cls.core)['provider_request']['state']
        cls.expanded=righting.expand(search.spec(route=True,protected=True))

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in constraint controls')))

    def cell(self,index=3):
        c=search.SearchController(self.core,self.expanded['cells'][index],seed=1061146)
        self.addCleanup(c.close);return c

    def inputs(self,c,step=0):return legacy.ResponseProbeControls.inputs(self,c,step)

    @staticmethod
    def prediction(speed=0.,joint_speed=0.,converged=True):
        return dict(velocity=np.r_[np.zeros(3),speed,0.,0.,np.full(8,joint_speed)],
            solver=dict(converged=converged,kkt_residual=0. if converged else .01))

    def selected(self,c):
        o,n=self.inputs(c)
        with patch.object(subject,'response',side_effect=[self.prediction()]+[self.prediction(-i*.25) for i in range(9)]):
            return c.step(search.observe(c,o,n))

    @staticmethod
    def joints():return [dict(lower_limit_rad=-1.1,upper_limit_rad=1.1) for _ in range(8)]

    def test_factored_population_preserves_twenty_four_bodies_and_fresh_references(self):
        s=search.spec(protected=True)
        self.assertEqual(len(righting.expand(s)['cells']),288)
        self.assertEqual(len({d['morphology_id'] for d in s['descriptors']}),24)
        self.assertEqual([sum(5+i in row for row in s['profiles_by_body']) for i in range(8)],[21]*8)
        for b,row in enumerate(s['profiles_by_body']):
            self.assertEqual(row[:5],list(range(5)));self.assertNotIn(5+b%8,row);self.assertEqual(len(row),12)
        self.assertEqual(len({righting.behavior_key(p) for p in s['profiles']}),len(s['profiles']))
        self.assertEqual(len(self.expanded['cells']),10)

    def test_policy_refuses_aliases_unknown_methods_and_hidden_rate_grid(self):
        for key,value in (('reserve_method','fit'),('feasibility','none'),('maximum_rate_rad_s',2.),
                          ('replan_steps',24),('direction',True),('selection','unchanged'),('extra',1)):
            p=dict(search.CONSTRAINED_DEFAULT);p[key]=value
            with self.assertRaises(ValueError):search.policy(p)
        p=dict(search.CONSTRAINED_DEFAULT);del p['reserve_method']
        with self.assertRaises(ValueError):search.policy(p)
        self.assertNotEqual(search.behavior_key(search.DEFAULT),search.behavior_key(search.CONSTRAINED_DEFAULT))

    def test_extracted_envelope_preserves_legacy_result(self):
        p=dict(schema_version=braking.SCHEMA,margin_rad=.04,lookahead_steps=1,braking_acceleration_rad_s2=20.)
        for q,v,u in ((0.,0.,.2),(.8,3.5,3.5),(-1.09,-3.,-3.),(1.2,1.,1.)):
            actual=braking.shape(q,v,u,3.5,-1.1,1.1,1/120,p)
            expected=braking.envelope(q,v,u,3.5,-1.1,1.1,1/120,margin_rad=.04,lookahead_steps=1,acceleration=20.)
            self.assertEqual(actual,expected)
        with self.assertRaises(ValueError):braking.policy(dict(p,braking_acceleration_rad_s2=200.))

    def test_bad_braking_inputs_refuse(self):
        for velocity,braked,dt,method in (([0.]*7,[0.]*8,1/600,'fixed'),([float('nan')]*8,[0.]*8,1/600,'fixed'),
                                         ([0.]*8,[0.]*8,0.,'fixed'),([0.]*8,[0.]*8,1/600,'unknown')):
            with self.assertRaises(ValueError):subject.decelerations(velocity,braked,dt,method)

    def test_braking_estimates_use_fallback_sign_caps_and_unsupported_state(self):
        v=[1.,-1.,.01,.1,1.,1.,1.,1.];b=[.8,-.8,.02,.2,1.,-2.,.999,0.]
        answer=subject.decelerations(np.asarray(v),np.asarray(b),1/600,'coupled')
        json.dumps(answer,allow_nan=False)
        self.assertAlmostEqual(answer['acceleration_rad_s2'][0],30.)
        self.assertAlmostEqual(answer['acceleration_rad_s2'][1],30.)
        self.assertEqual(answer['acceleration_rad_s2'][2],20.)
        self.assertTrue(answer['unsupported_braking'][3]);self.assertTrue(answer['unsupported_braking'][4])
        self.assertEqual(answer['acceleration_rad_s2'][5],200.)
        self.assertEqual(answer['acceleration_rad_s2'][6],1.)
        self.assertEqual(subject.decelerations(v,b,1/600,'fixed')['acceleration_rad_s2'],[20.]*8)

    def test_measured_motion_starts_braking_before_old_requested_travel_guard(self):
        a=braking.envelope(1.075,3.5,3.,3.5,-1.1,1.1,1/120,margin_rad=.04,lookahead_steps=1,acceleration=20.)
        self.assertEqual(a['shaped_velocity_rad_s'],0.)
        self.assertGreater((1.1-1.075)*120,2.9)
        slow=braking.envelope(.8,0.,3.5,3.5,-1.1,1.1,1/120,margin_rad=.04,lookahead_steps=1,acceleration=20.)
        fast=braking.envelope(.8,3.5,3.5,3.5,-1.1,1.1,1/120,margin_rad=.04,lookahead_steps=1,acceleration=20.)
        self.assertLess(fast['shaped_velocity_rad_s'],slow['shaped_velocity_rad_s'])

    def test_envelope_is_mirrored_and_keeps_zero_in_interval(self):
        for a in (1.,20.,200.):
            pos=braking.envelope(.97,2.,3.,3.5,-1.1,1.1,1/120,margin_rad=.04,lookahead_steps=1,acceleration=a)
            neg=braking.envelope(-.97,-2.,-3.,3.5,-1.1,1.1,1/120,margin_rad=.04,lookahead_steps=1,acceleration=a)
            self.assertEqual(pos['shaped_velocity_rad_s'],-neg['shaped_velocity_rad_s'])
            self.assertLessEqual(pos['lower_velocity_rad_s'],0.);self.assertGreaterEqual(pos['upper_velocity_rad_s'],0.)

    def test_prediction_crossing_and_stopping_reserve_change_feasibility(self):
        args=(self.joints(),[1.04]+[0.]*7,[1.]+[0.]*7,[1.]+[0.]*7,[20.]*8)
        self.assertTrue(subject.feasibility(*args,'interval',1/600)['feasible'])
        self.assertFalse(subject.feasibility(*args,'stopping',1/600)['feasible'])
        for sign in (-1,1):
            self.assertFalse(subject.feasibility(self.joints(),[sign*1.099]*8,[sign]*8,[sign]*8,[20.]*8,'interval',1/600)['feasible'])

    def test_feasibility_retains_measured_speed_when_prediction_stops(self):
        result=subject.feasibility(self.joints(),[1.05]*8,[3.5]*8,[0.]*8,[20.]*8,'interval',1/600)
        self.assertFalse(result['feasible'])
        json.dumps(subject.feasibility(self.joints(),[1.05]*8,np.full(8,3.5),[0.]*8,[20.]*8,'interval',1/600),allow_nan=False)
        for mode in ('interval','stopping'):
            with self.assertRaises(ValueError):subject.feasibility(self.joints(),[0.]*8,[0.]*8,[float('inf')]*8,[20.]*8,mode,1/600)

    def test_every_protected_action_keeps_speed_and_observed_bound_guard(self):
        c=self.cell();o,n=self.inputs(c)
        for j,observed in zip(c.spec['joints'],o['state']['ordered_joint_observations'],strict=True):
            observed['position_rad']=j['upper_limit_rad']+.01;observed['velocity_rad_s']=-3.
        base=righting.RightingController.plan(c,o)
        actions=search.probe.candidates(c.creature,c.candidate,o['state'],c.previous,base)
        guarded=subject.protect(actions,c,o['state'],[200.]*8)
        for action in guarded:
            self.assertTrue(all(-3.5<=u<=0. for u in action['targets']))
            self.assertEqual(action['targets'],[x['canonical_velocity_rad_s'] for x in action['commands']])

    def test_higher_rotation_score_cannot_choose_an_infeasible_action(self):
        c=self.cell();o,n=self.inputs(c)
        answers=[self.prediction()]+[self.prediction(-i*.25,1000. if i==3 else 0.) for i in range(9)]
        with patch.object(subject,'response',side_effect=answers):row=c.step(search.observe(c,o,n))
        d=row['resolution']['response_search']
        self.assertEqual(d['applied_action'],2);self.assertFalse(d['predictions'][3]['feasible'])
        self.assertTrue(d['predictions'][2]['feasible'])
        self.assertEqual(np.asarray(row['native_targets'],np.float32).tolist(),d['predictions'][2]['native_targets'])

    def test_no_feasible_action_withdraws_to_zero_and_retries_next_interval(self):
        c=self.cell();o,n=self.inputs(c)
        with patch.object(subject,'response',side_effect=[self.prediction()]+[self.prediction(joint_speed=1000.)]*9):
            row=c.step(search.observe(c,o,n))
        d=row['resolution']['response_search'];self.assertEqual(d['selection_reason'],'braking_withdrawal')
        self.assertEqual(d['applied_action'],9);self.assertEqual(row['native_targets'],[0.]*8)
        self.assertEqual(c.response_state,dict(action_index=0,next_replan_step=1))

    def test_unconverged_braking_prediction_withdraws_without_action_scoring(self):
        c=self.cell();o,n=self.inputs(c)
        with patch.object(subject,'response',return_value=self.prediction(converged=False)) as calls:
            row=c.step(search.observe(c,o,n))
        self.assertEqual(calls.call_count,1)
        self.assertEqual(row['resolution']['response_search']['selection_reason'],'model_nonconvergence')
        self.assertEqual(row['native_targets'],[0.]*8)

    def test_any_unconverged_action_withdraws_without_hiding_the_failure(self):
        c=self.cell();o,n=self.inputs(c)
        answers=[self.prediction()]+[self.prediction(-i*.25,converged=i!=8) for i in range(9)]
        with patch.object(subject,'response',side_effect=answers):row=c.step(search.observe(c,o,n))
        self.assertEqual(row['resolution']['response_search']['selection_reason'],'model_nonconvergence')
        self.assertEqual(row['native_targets'],[0.]*8)

    def test_held_pattern_gets_a_fresh_prediction_and_fresh_commands(self):
        c=self.cell();first=self.selected(c);o,n=self.inputs(c,1)
        with patch.object(subject,'response',side_effect=[self.prediction(),self.prediction(-.75)]) as calls:
            row=c.step(search.observe(c,o,n))
        d=row['resolution']['response_search'];self.assertEqual(calls.call_count,2)
        self.assertEqual(d['selection_reason'],'held_pattern');self.assertEqual(len(d['predictions']),1)
        self.assertEqual(d['applied_action'],3);self.assertNotEqual(row['native_targets'],first['native_targets'])

    def test_infeasible_held_pattern_replans_immediately_and_reuses_its_prediction(self):
        c=self.cell();self.selected(c);o,n=self.inputs(c,1)
        answers=[self.prediction(),self.prediction(-.75,1000.)]+[self.prediction() for _ in range(8)]
        with patch.object(subject,'response',side_effect=answers) as calls:row=c.step(search.observe(c,o,n))
        d=row['resolution']['response_search'];self.assertEqual(calls.call_count,10)
        self.assertEqual(d['constraints']['replan_trigger'],'held_became_infeasible')
        self.assertEqual(d['selection_reason'],'replanned');self.assertEqual(d['applied_action'],0)
        self.assertEqual(c.response_state['next_replan_step'],7)

    def test_upright_stance_still_receives_protection(self):
        c=self.cell();o,n=self.inputs(c)
        o['state']['base_pose_world']['orientation_xyzw']=dict(x=0.,y=0.,z=0.,w=1.)
        o['state']['base_pose_world']['position_m']['y']=c.creature['compiled']['geometry']['initial_torso_center_y_m']
        with patch.object(subject,'response',return_value=self.prediction()) as calls:row=c.step(search.observe(c,o,n))
        d=row['resolution']['response_search'];self.assertEqual(calls.call_count,2)
        self.assertEqual(d['selection_reason'],'upright_stance');self.assertIsNone(d['desired_angular_velocity_world_rad_s'])
        self.assertEqual(d['constraints']['replan_trigger'],'upright')

    def test_unsafe_upright_stance_withdraws_to_braking(self):
        c=self.cell();o,n=self.inputs(c)
        o['state']['base_pose_world']['orientation_xyzw']=dict(x=0.,y=0.,z=0.,w=1.)
        o['state']['base_pose_world']['position_m']['y']=c.creature['compiled']['geometry']['initial_torso_center_y_m']
        with patch.object(subject,'response',side_effect=[self.prediction(),self.prediction(joint_speed=1000.)]):
            row=c.step(search.observe(c,o,n))
        self.assertEqual(row['resolution']['response_search']['selection_reason'],'braking_withdrawal')
        self.assertEqual(row['native_targets'],[0.]*8)

    def test_planning_is_pure_and_batch_refusal_is_atomic(self):
        batch=search.SearchBatch(self.core,self.expanded['cells'][3:5],seed=1061146);self.addCleanup(batch.close)
        observations=[search.observe(c,*self.inputs(c)) for c in batch.controllers];before=route.planning_states(batch)
        batch.controllers[0].plan(observations[0]);self.assertEqual(before,route.planning_states(batch))
        observations[1]['whole_body_contacts']['state_sha256']='0'*64
        with self.assertRaises(ValueError):batch.step(observations)
        self.assertEqual(before,route.planning_states(batch))

    def test_constraint_metrics_separate_braking_from_model_failure(self):
        c=self.cell();o,n=self.inputs(c)
        with patch.object(subject,'response',side_effect=[self.prediction()]+[self.prediction(joint_speed=1000.)]*9):
            row=c.step(search.observe(c,o,n))
        contract=route.declaration(search.ROOT/'sdk/discovery/creature_response_search_route_v2.json')
        metric=search.initial_metrics(contract);search.measure_control(metric,row)
        self.assertEqual(metric['response_search_brakes'],1);self.assertEqual(metric['response_search_failures'],0)
        sample=dict(contract,outer_steps=1);search.validate_metrics(sample,contract['righting_metadata'][3],metric)
        metric['response_search_constraint_rows']=0
        with self.assertRaises(ValueError):search.validate_metrics(sample,contract['righting_metadata'][3],metric)

    def test_contracts_bind_new_mechanisms_and_preserve_legacy_gate(self):
        for suffix,count in (('route_v2',10),('v2',288)):
            c=route.declaration(search.ROOT/f'sdk/discovery/creature_response_search_{suffix}.json')
            self.assertEqual(len(c['cells']),count);self.assertEqual(sum(g[2] for g in route.gates(c)),248)
            self.assertEqual(c['predecessor'],search.CONSTRAINED_PREDECESSOR)
            for key,value in (('outer_steps',c['outer_steps']-1),('maximum_worlds_per_batch',5),('capture_mode','compact_v1')):
                wrong=copy.deepcopy(c);wrong[key]=value
                with self.assertRaises(ValueError):search.validate(wrong)
        old=route.declaration(search.ROOT/'sdk/discovery/creature_response_search_v1.json')
        self.assertEqual(sum(g[2] for g in route.gates(old)),216)

    def test_route_requires_native_reserve_activity_and_complete_denominators(self):
        c=route.declaration(search.ROOT/'sdk/discovery/creature_response_search_route_v2.json');metrics=[]
        for meta in c['righting_metadata']:
            m=search.initial_metrics(c);p=c['righting_spec']['profiles'][meta['candidate_index']].get('response_search')
            if p:
                m['response_search_rows']=181
                if p['schema_version']==search.CONSTRAINED_SCHEMA:
                    m['response_search_constraint_rows']=181
                    if meta['start_id']=='upright':m['response_search_upright']=181
                    else:m.update(response_search_replans=31,response_search_holds=150,response_search_nonzero_actions=180,response_search_constraint_guarded_rows=1)
                elif meta['start_id']=='upright':m['response_search_upright']=181
                else:m['response_search_unchanged']=181
            metrics.append(m)
        receipt=dict(contract=c,audit=dict(ok=True,synthetic=False,controller_rows_replayed=1810,native_rows_verified=9050,metrics=metrics))
        self.assertTrue(search.verify_route(None,receipt)['complete'])
        receipt['audit']['metrics'][3]['response_search_constraint_guarded_rows']=0
        with self.assertRaises(ValueError):search.verify_route(None,receipt)


if __name__=='__main__':unittest.main()
