"""Numerical prefix matching, repeated actions and conservative score controls."""
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
import test_creature_response_probe as legacy
from test_portable_search import _fixture


class NumericalProbeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=subject.bridge.LocomotionCore(Path(os.environ['QUADRUPED_TEST_CORE']))
        cls.template=_fixture(cls.core)['provider_request']['state']
        cls.expanded=righting.expand(subject.spec(repeated=True))

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in numerical controls')))

    def rows(self,action,repeat,step=0,outer=0):
        control,native=legacy.ResponseProbeControls.matched_rows(self,action)
        control.update(outer_step=outer,binding={k:'fixed' for k in ('descriptor_sha256','model_xml_sha256','body_shape_sha256')})
        control['native_observation'].update(time_s=outer/120,contacts=[dict(geom=[0,1],distance_m=0.,
            position_m=[x,0.,0.],frame=[0.,0.,1.,1.,0.,0.,0.,1.,0.]) for x in (-.1,.1)])
        p=control['resolution']['response_probe'];p['policy'].update(schema_version=subject.NUMERICAL_SCHEMA,probe_step=step,repeat_index=repeat)
        for value in p['predictions']:
            i=value['action_index'];value.update(velocity=[0.]*3+[i*.02,0.,0.]+[0.]*8,converged=True,
                native_targets=np.asarray([i*.001]*8,np.float32).astype(float).tolist())
        control['native_targets']=list(p['predictions'][action]['native_targets']) if outer==step else [0.]*8
        native.update(step=step*5+1);native['qvel'][3]+=repeat*1e-7
        return control,native

    def group(self,step=0):
        group=subject.NumericalMatchedGroup('body',step)
        for outer in range(step+1):
            for action in range(9):
                for repeat in range(2):group.control(self.rows(action,repeat,step,outer)[0],(action,repeat))
        for action in range(9):
            for repeat in range(2):group.native(self.rows(action,repeat,step,step)[1],(action,repeat))
        return group

    def test_population_has_two_fresh_repeats_of_every_action(self):
        self.assertEqual(len(self.expanded['cells']),165)
        for body in range(3):
            rows=self.expanded['cells'][55*body:55*(body+1)]
            self.assertNotIn('response_probe',rows[0]['profile'])
            self.assertEqual([(p['profile']['response_probe']['probe_step'],p['profile']['response_probe']['action_index'],
                p['profile']['response_probe']['repeat_index']) for p in rows[1:]],
                [(s,a,r) for s in subject.STEPS for a in range(9) for r in range(2)])
        bad=subject.spec(repeated=True);bad['profiles'][2]['response_probe']['repeat_index']=0
        with self.assertRaises(ValueError):righting.expand(bad)

    def test_repeat_policy_and_frozen_declaration_refuse_drift(self):
        value=subject.spec(repeated=True)['profiles'][1]['response_probe']
        for bad in (dict(value,repeat_index=True),dict(value,repeat_index=2),{k:v for k,v in value.items() if k!='repeat_index'}):
            with self.assertRaises(ValueError):subject.policy(bad)
        c=dict(response_probe=subject.NUMERICAL_RECIPE,righting_spec=subject.spec(repeated=True),mode='development_discovery',
            capture_mode='full',outer_steps=121,seed=1061143,maximum_worlds_per_batch=55,readback=dict(mode='shared_snapshot',reference_check=False))
        subject.validate(c)
        for key,bad in (('seed',1061142),('maximum_worlds_per_batch',28),('capture_mode','compact_v1')):
            with self.assertRaises(ValueError):subject.validate(dict(c,**{key:bad}))
        bad=copy.deepcopy(c);bad['response_probe']['matching_bounds']['position_m']*=2
        with self.assertRaises(ValueError):subject.validate(bad)
        original=route.declaration(subject.ROOT/'sdk/discovery/creature_response_probe_v1.json')
        self.assertEqual(sum(v[2] for v in route.gates(original)),195)

    def test_repeated_controller_keeps_same_predictor_and_bounded_actions(self):
        for body in range(3):
            for action in range(9):
                reference=None
                for repeat in range(2):
                    cell=subject.ProbeController(self.core,self.expanded['cells'][55*body+1+2*action+repeat],seed=1061143)
                    self.addCleanup(cell.close);o,n=legacy.ResponseProbeControls.inputs(self,cell)
                    row=cell.step(subject.observe(cell,o,n));value=(row['native_targets'],row['resolution']['response_probe']['predictions'])
                    if reference is None:reference=value
                    self.assertEqual(value,reference)
                    self.assertTrue(all(abs(v)<=.2 for v in row['native_targets']))

    def test_unit_bounds_allow_small_differences_and_refuse_large_or_nonfinite(self):
        for key,index,bound in (('qpos',0,'position_m'),('qpos',3,'quaternion_component'),('qpos',7,'joint_angle_rad'),
                ('qvel',0,'linear_velocity_m_s'),('qvel',3,'angular_velocity_rad_s'),('qvel',6,'joint_velocity_rad_s')):
            for scale,accepted in ((.5,True),(2.,False),(float('nan'),False)):
                group=subject.NumericalMatchedGroup('body',0);group.control(self.rows(0,0)[0],(0,0))
                row=self.rows(0,1)[0];row['native_observation'][key][index]+=scale*subject.MATCH_BOUNDS[bound]
                if accepted:group.control(row,(0,1))
                else:
                    with self.assertRaises(ValueError):group.control(row,(0,1))

    def test_contact_matching_handles_reordering_and_ambiguous_bipartite_pairs(self):
        a=self.rows(0,0)[0]['native_observation']['contacts'];b=copy.deepcopy(a);b.reverse();b[0]['position_m'][0]+=1e-7
        self.assertEqual(len(subject.contact_pairs(a,b)),2)
        # Greedy first-edge matching would strand the second left contact.
        a[0]['position_m'][0]=.5e-6;a[1]['position_m'][0]=-.5e-6
        b[0]['position_m'][0]=0.;b[1]['position_m'][0]=1.4e-6
        self.assertEqual(len(subject.contact_pairs(a,b)),2)
        for change in (lambda x:x.pop(),lambda x:x[0].update(geom=[0,2]),
                lambda x:x[0]['position_m'].__setitem__(0,.001),lambda x:x[0].update(distance_m=float('nan')),
                lambda x:x[0]['frame'].__setitem__(0,.001)):
            bad=copy.deepcopy(a);change(bad)
            with self.assertRaises(ValueError):subject.contact_pairs(a,bad)

    def test_prefix_model_clock_and_command_changes_refuse(self):
        for change in (lambda x:x['binding'].update(model_xml_sha256='crossed'),
                lambda x:x['native_observation'].update(time_s=1.),lambda x:x['native_targets'].__setitem__(0,.001)):
            group=subject.NumericalMatchedGroup('body',60);group.control(self.rows(0,0,60)[0],(0,0))
            bad=self.rows(0,1,60)[0];change(bad)
            with self.assertRaises(ValueError):group.control(bad,(0,1))
        group=self.group(60);self.assertEqual(group.finish()['prefix_rows_verified'],61*18)

    def test_missing_duplicate_and_misassigned_actions_refuse(self):
        group=subject.NumericalMatchedGroup('body',0);group.control(self.rows(0,0)[0],(0,0))
        with self.assertRaises(ValueError):group.control(self.rows(0,0)[0],(0,0))
        with self.assertRaises(ValueError):group.finish()
        row=self.rows(0,1)[0];row['resolution']['response_probe']['applied_action']=1
        with self.assertRaises(ValueError):group.control(row,(0,1))
        group=self.group()
        with self.assertRaises(ValueError):group.native(self.rows(0,1)[1],(0,1))
        group.actual.pop((8,1))
        with self.assertRaises(ValueError):group.finish()

    def test_prediction_and_axis_bounds_and_applied_targets_refuse(self):
        for change in (lambda g:g.predictions[8,1][8]['native_targets'].__setitem__(0,.1),
                lambda g:g.predictions[8,1][8]['velocity'].__setitem__(3,.2),
                lambda g:g.axes[8,1].__setitem__(1,.001)):
            group=self.group();change(group)
            with self.assertRaises(ValueError):group.finish()
        group=subject.NumericalMatchedGroup('body',0);row=self.rows(0,0)[0];row['native_targets'][0]=.1
        with self.assertRaises(ValueError):group.control(row,(0,0))

    def test_every_repeated_action_must_remain_below_dispersion_budget(self):
        for action in range(9):
            group=self.group();group.actual[action,1]+=2e-5
            with self.assertRaisesRegex(ValueError,'repeated action dispersion'):group.finish()
        result=self.group().finish();self.assertLessEqual(result['maximum_repeat_spread_rad_s'],1.1e-7)
        self.assertEqual(len(result['measured_repeats_rad_s']),9)

    def test_intervals_preserve_every_body_criterion_and_conservative_regret(self):
        item=self.group().finish();groups=[dict(copy.deepcopy(item),body_id=str(b),probe_step=s) for b in range(3) for s in subject.STEPS]
        result=subject.summarize(groups,repeated=True)
        self.assertTrue(result['ordering_screen_passed']);self.assertEqual(result['observed_action_worlds'],162)
        self.assertGreater(result['groups'][0]['selected_regret_rad_s'],0.)
        groups[0]['predicted_scores_rad_s'].reverse();groups[0]['prediction_intervals_rad_s'].reverse()
        result=subject.summarize(groups,repeated=True)
        self.assertFalse(result['ordering_screen_passed']);self.assertFalse(result['bodies']['0']['passed'])
        groups[0]['measured_intervals_rad_s'][0][1]+=.001
        with self.assertRaises(ValueError):subject.summarize(groups,repeated=True)

    def test_ambiguous_prediction_and_measured_intervals_do_not_earn_ordering(self):
        item=self.group().finish();groups=[dict(copy.deepcopy(item),body_id=str(b),probe_step=s) for b in range(3) for s in subject.STEPS]
        for g in groups:g['predicted_scores_rad_s']=[0.]*9;g['prediction_intervals_rad_s']=[[-1e-6,1e-6] for _ in range(9)]
        result=subject.summarize(groups,repeated=True)
        self.assertTrue(all(b['correct_pairs']==0 for b in result['bodies'].values()))
        for g in groups:g['measured_scores_rad_s']=[0.]*9;g['measured_intervals_rad_s']=[[-1e-6,1e-6] for _ in range(9)]
        result=subject.summarize(groups,repeated=True)
        self.assertFalse(result['ordering_screen_passed']);self.assertTrue(all(b['distinguishable_pairs']==0 for b in result['bodies'].values()))

    def test_v1_exact_matching_and_consumed_contract_are_not_relaxed(self):
        group=subject.MatchedGroup('body',0);a,_=legacy.ResponseProbeControls.matched_rows(self,0);group.control(a,0)
        b,_=legacy.ResponseProbeControls.matched_rows(self,1);b['native_observation']['qpos'][0]=1e-12
        with self.assertRaisesRegex(ValueError,'matched prefix differs'):group.control(b,1)
        old=json.loads((subject.ROOT/'sdk/discovery/creature_response_probe_v1.json').read_bytes())
        subject.validate(old);self.assertFalse(subject.numerical(old))


if __name__=='__main__':unittest.main()
