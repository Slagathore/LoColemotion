"""Prepared-contact transport, action bounds, dispatch and atomicity controls."""
import copy
from contextlib import ExitStack
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_response_probe as subject
import creature_righting as righting
import creature_native as route
from test_creature_batch import fixture, observation
from test_portable_search import _fixture


class ResponseProbeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=subject.bridge.LocomotionCore(Path(os.environ['QUADRUPED_TEST_CORE']))
        cls.template=_fixture(cls.core)['provider_request']['state']
        cls.expanded=righting.expand(subject.spec())

    def setUp(self):
        self.traps=ExitStack();self.addCleanup(self.traps.close)
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            self.traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in response-probe controls')))

    def cell(self,index=1):
        c=subject.ProbeController(self.core,self.expanded['cells'][index],seed=subject.RECIPE['seed'])
        self.addCleanup(c.close);return c

    def inputs(self,cell,step=0):
        o=observation(cell,fixture(cell.creature,self.template),step)
        o['state']['base_pose_world']['orientation_xyzw']=dict(x=1.,y=0.,z=0.,w=0.)
        joints=o['state']['ordered_joint_observations']
        native=dict(sampling_stage='prepared_before_control',time_s=step/120,
            qpos=[0.,0.,0.,1.,0.,0.,0.]+[j['position_rad'] for j in joints],qvel=[0.]*6+[j['velocity_rad_s'] for j in joints],
            contacts=[dict(geom=[0,1],position_m=[x,0.,0.],frame=[0.,0.,1.,1.,0.,0.,0.,1.,0.],distance_m=0.,world=0) for x in (-.1,.1)])
        return o,native

    def test_declared_population_has_three_bodies_and_all_assigned_alternatives(self):
        self.assertEqual(len(self.expanded['cells']),84)
        self.assertEqual(len(subject.spec()['descriptors']),3)
        for body in range(3):
            rows=self.expanded['cells'][28*body:28*(body+1)]
            self.assertNotIn('response_probe',rows[0]['profile'])
            self.assertEqual([(p['profile']['response_probe']['probe_step'],p['profile']['response_probe']['action_index']) for p in rows[1:]],
                [(s,a) for s in subject.STEPS for a in range(9)])

    def test_common_prefix_and_plain_comparator_keep_legacy_records(self):
        for index in (0,10,38,66):
            cell=self.cell(index);declaration=copy.deepcopy(self.expanded['cells'][index]);declaration['profile'].pop('response_probe',None)
            legacy=righting.RightingController(self.core,declaration,seed=subject.RECIPE['seed']);self.addCleanup(legacy.close)
            for step in range(3):
                o,n=self.inputs(cell,step);actual=cell.step(subject.observe(cell,o,n));expected=legacy.step(o)
                actual['request'].pop('whole_body_contacts',None);self.assertEqual(actual,expected)

    def test_all_actions_retain_identical_predictions_and_apply_assigned_commands(self):
        for body in range(3):
            common=None
            for action in range(9):
                c=self.cell(body*28+action+1);o,n=self.inputs(c);r=c.step(subject.observe(c,o,n));p=r['resolution']['response_probe']
                if common is None:common=p['predictions']
                self.assertEqual(common,p['predictions']);self.assertEqual(p['applied_action'],action)
                self.assertEqual(np.asarray(r['native_targets'],np.float32).astype(float).tolist(),p['predictions'][action]['native_targets'])
                self.assertTrue(all(v['converged'] for v in p['predictions']))

    def test_candidates_preserve_speed_slew_and_observed_joint_bounds(self):
        c=self.cell();o,n=self.inputs(c)
        for at_limits in (False,True):
            if at_limits:
                for i,j in enumerate(o['state']['ordered_joint_observations']):j['position_rad']=c.spec['joints'][i]['upper_limit_rad']
            base=super(subject.ProbeController,c).plan(o)
            for a in subject.candidates(c.creature,c.candidate,o['state'],c.previous,base):
                for v in a['targets']:
                    self.assertLessEqual(abs(v),.2)
                    if at_limits:self.assertLessEqual(v,0.)
            self.assertEqual(subject.candidates(c.creature,c.candidate,o['state'],c.previous,base)[0]['targets'],base['native_targets'])

    def test_contact_packet_maps_torso_and_ground_order_without_force_truth(self):
        c=self.cell();o,n=self.inputs(c);a=subject.packet(c.creature,c.binding,o['state'],n)
        self.assertEqual([v['body_id'] for v in a['contacts']],['torso','torso'])
        self.assertEqual(a['contacts'][0]['normal'],[0.,1.,0.])
        for h in n['contacts']:h['geom'].reverse();h['frame'][:3]=[-v for v in h['frame'][:3]]
        self.assertEqual(a,subject.packet(c.creature,c.binding,o['state'],n))
        self.assertFalse(any('force' in k for h in a['contacts'] for k in h))

    def test_refuses_post_step_crossed_world_invalid_body_and_clock(self):
        c=self.cell();o,n=self.inputs(c)
        changes=[lambda r:r.update(sampling_stage='after_step'),lambda r:r['contacts'][1].update(world=1),
            lambda r:r['contacts'][0].update(geom=[0,99]),lambda r:r.update(time_s=float('nan'))]
        for change in changes:
            bad=copy.deepcopy(n);change(bad)
            with self.assertRaises(ValueError):subject.packet(c.creature,c.binding,o['state'],bad)

    def test_refuses_stale_crossed_missing_contact_packets_without_advancing(self):
        c=self.cell();o,n=self.inputs(c);o=subject.observe(c,o,n)
        changes=[lambda r:r.pop('whole_body_contacts'),lambda r:r['whole_body_contacts'].update(state_sha256='0'*64),
            lambda r:r['whole_body_contacts']['binding'].update(cell_id='wrong_cell')]
        for change in changes:
            bad=copy.deepcopy(o);change(bad)
            with self.assertRaises(ValueError):c.step(bad)
            self.assertEqual(c.step_index,0);self.assertEqual(c.previous,[0.]*8)

    def test_pure_planning_and_batch_refusal_are_atomic(self):
        b=subject.ProbeBatch(self.core,self.expanded['cells'][1:3],seed=subject.RECIPE['seed']);self.addCleanup(b.close)
        obs=[subject.observe(c,*self.inputs(c)) for c in b.controllers]
        first=b.controllers[0];before=route.planning_states(b);first.plan(obs[0]);self.assertEqual(route.planning_states(b),before)
        obs[1]['whole_body_contacts']['state_sha256']='0'*64
        with self.assertRaises(ValueError):b.step(obs)
        self.assertEqual(route.planning_states(b),before)

    def test_failed_solver_is_not_a_candidate_score(self):
        c=self.cell();o,n=self.inputs(c)
        with patch.object(subject,'response',return_value=dict(solver=dict(converged=False))):
            with self.assertRaises(ValueError):c.step(subject.observe(c,o,n))
        self.assertEqual(c.step_index,0)

    def test_native_dispatch_requires_prepared_contact_controller(self):
        self.assertEqual(route.controller_types(dict(response_probe=subject.RECIPE)),(subject.ProbeBatch,subject.ProbeController))
        with self.assertRaises(ValueError):righting.RightingController(self.core,self.expanded['cells'][1],seed=subject.RECIPE['seed'])
        self.assertEqual(route.controller_types(dict(righting_spec={})),(righting.RightingBatch,righting.RightingController))

    def test_policy_and_declaration_refuse_unassigned_experiments(self):
        value=subject.spec()['profiles'][1]['response_probe']
        for key,bad in (('probe_step',1),('action_index',9),('action_index',True)):
            with self.assertRaises(ValueError):subject.policy(dict(value,**{key:bad}))
        c=dict(response_probe=subject.RECIPE,righting_spec=subject.spec(),mode='development_discovery',capture_mode='full',
            outer_steps=121,seed=subject.RECIPE['seed'],maximum_worlds_per_batch=28,readback=dict(mode='shared_snapshot',reference_check=False))
        subject.validate(c)
        for key,bad in (('outer_steps',122),('capture_mode','compact_v1'),('maximum_worlds_per_batch',9)):
            with self.assertRaises(ValueError):subject.validate(dict(c,**{key:bad}))
        del c['response_probe']
        with self.assertRaises(ValueError):subject.validate(c)

    def test_predecessor_route_and_gate_population_remain_unchanged(self):
        c=route.declaration(subject.ROOT/subject.SOURCE['path'])
        self.assertEqual(sum(v[2] for v in route.gates(c)),330)
        self.assertNotIn('response_probe',c)

    def groups(self):
        return [dict(body_id=str(b),probe_step=s,predicted_scores_rad_s=[i*.02 for i in range(9)],
            measured_scores_rad_s=[i*.02 for i in range(9)]) for b in range(3) for s in subject.STEPS]

    def test_counterfactual_ordering_screen_requires_every_body(self):
        groups=self.groups();self.assertTrue(subject.summarize(groups)['ordering_screen_passed'])
        groups[0]['predicted_scores_rad_s'].reverse()
        result=subject.summarize(groups)
        self.assertFalse(result['ordering_screen_passed']);self.assertFalse(result['bodies']['0']['passed'])
        self.assertGreater(result['groups'][0]['selected_regret_rad_s'],.01)

    def test_counterfactual_ties_missing_groups_and_nonfinite_scores(self):
        groups=self.groups()
        for g in groups:g['measured_scores_rad_s']=[0.]*9
        self.assertFalse(subject.summarize(groups)['ordering_screen_passed'])
        for bad in (self.groups()[:-1],self.groups()+[self.groups()[0]]):
            with self.assertRaises(ValueError):subject.summarize(bad)
        groups=self.groups();groups[0]['predicted_scores_rad_s'][0]=float('nan')
        with self.assertRaises(ValueError):subject.summarize(groups)

    def matched_rows(self,action):
        predictions=[dict(action_index=i,native_targets=[0.]*8,score_rad_s=i*.02) for i in range(9)]
        control=dict(outer_step=0,native_targets=[0.]*8,native_observation=dict(qpos=[0.]*3+[1.,0.,0.,0.]+[0.]*8,
            qvel=[0.]*14,contacts=[]),resolution=dict(response_probe=dict(
                policy=dict(schema_version=subject.SCHEMA,probe_step=0,action_index=action),applied_action=action,
                selection='prospectively_assigned',predictions=predictions,axis_world=[1.,0.,0.])))
        native=dict(step=1,qpos=control['native_observation']['qpos'],qvel=[0.]*3+[action*.02,0.,0.]+[0.]*8)
        return control,native

    def test_matched_group_reads_each_native_alternative_once(self):
        group=subject.MatchedGroup('body',0)
        for action in range(9):
            control,native=self.matched_rows(action);group.control(control,action);group.native(native,action)
        result=group.finish();self.assertEqual(result['prefix_rows_verified'],9)
        self.assertEqual(result['predicted_scores_rad_s'],result['measured_scores_rad_s'])
        with self.assertRaises(ValueError):group.native(self.matched_rows(8)[1],8)

    def test_matched_group_refuses_changed_prefix_assignment_and_missing_actions(self):
        for change in (lambda r:r['native_observation']['qpos'].__setitem__(0,.001),
                       lambda r:r['resolution']['response_probe'].update(applied_action=0)):
            group=subject.MatchedGroup('body',0);group.control(self.matched_rows(0)[0],0)
            bad=self.matched_rows(1)[0];change(bad)
            with self.assertRaises(ValueError):group.control(bad,1)
            with self.assertRaises(ValueError):group.finish()


if __name__=='__main__':unittest.main()
