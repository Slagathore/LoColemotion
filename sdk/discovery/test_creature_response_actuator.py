"""Actuator-aware probe dispatch and native/GPU parameter binding; no worlds."""
import copy
from contextlib import ExitStack
from dataclasses import fields
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
from mujoco_warp._src import types
import numpy as np

import creature_native as route
import creature_native_model as native_model
import creature_response_probe as subject
import creature_righting as righting
import test_creature_native as native_fixture
import test_creature_response_probe as legacy
import test_creature_response_matching as numerical_fixture
from test_portable_search import _fixture


class ActuatorProbeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=subject.bridge.LocomotionCore(Path(os.environ['QUADRUPED_TEST_CORE']))
        cls.template=_fixture(cls.core)['provider_request']['state']
        cls.expanded=righting.expand(subject.spec(repeated=True,actuator_aware=True))

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in actuator route controls')))

    def cell(self,index):
        cell=subject.ProbeController(self.core,self.expanded['cells'][index],seed=1061144)
        self.addCleanup(cell.close);return cell

    def test_new_mode_changes_predictions_but_preserves_assigned_bounded_actions(self):
        for body in range(3):
            common=None
            for action in range(9):
                for repeat in range(2):
                    cell=self.cell(55*body+1+2*action+repeat);o,n=legacy.ResponseProbeControls.inputs(self,cell)
                    actual=cell.step(subject.observe(cell,o,n));p=actual['resolution']['response_probe']
                    if common is None:common=p['predictions']
                    self.assertEqual(common,p['predictions']);self.assertEqual(p['applied_action'],action)
                    self.assertEqual(p['selection'],'prospectively_assigned')
                    self.assertTrue(all(abs(v)<=.2 for v in actual['native_targets']))
                    self.assertEqual(np.asarray(actual['native_targets'],np.float32).astype(float).tolist(),p['predictions'][action]['native_targets'])
                    self.assertEqual(cell.actuator_parameters['armature'],[.01]*8)
            prior=copy.deepcopy(self.expanded['cells'][55*body+1]);prior['profile']['response_probe']['schema_version']=subject.NUMERICAL_SCHEMA
            old=subject.ProbeController(self.core,prior,seed=1061144);self.addCleanup(old.close)
            o,n=legacy.ResponseProbeControls.inputs(self,old);predicted=old.step(subject.observe(old,o,n))['resolution']['response_probe']['predictions']
            self.assertIsNone(old.actuator_parameters)
            self.assertNotEqual([p['velocity'] for p in common],[p['velocity'] for p in predicted])

    def test_native_and_gpu_armature_and_damping_readbacks_are_required(self):
        creature=self.cell(1).creature;meta=native_fixture.metadata(creature)
        snapshot=native_fixture.primary_snapshot(meta);expected=native_model.expected_native_fields(creature,actuator_dynamics=True)
        annotations={f.name:f.type for f in fields(types.Model)}
        for name in ('dof_armature','dof_damping'):
            meta['native_fields'][name]=expected[name]
            batched=annotations[name].shape[0]=='*';data=np.asarray(expected[name],np.float32)
            if batched:data=data[None]
            snapshot['$.'+name]=native_model._array_record(data,logical_shape=data.shape,batchable=batched)
        self.assertEqual(meta['native_fields']['dof_armature'],[0.]*6+[.01]*8)
        native_model.validate_model_evidence(creature,meta,snapshot,actuator_dynamics=True)
        with self.assertRaises(ValueError):native_model.validate_model_evidence(creature,meta,snapshot)
        for name in ('dof_armature','dof_damping'):
            bad=copy.deepcopy(meta);bad['native_fields'][name][6]+=.01
            with self.assertRaises(ValueError):native_model.validate_model_evidence(creature,bad,snapshot,actuator_dynamics=True)
            bad=copy.deepcopy(snapshot);record=bad['$.'+name];data=native_model.array_value(record).copy();data.flat[6]+=.01
            bad['$.'+name]=native_model._array_record(data,logical_shape=data.shape,batchable=record['batchable'])
            with self.assertRaises(ValueError):native_model.validate_model_evidence(creature,meta,bad,actuator_dynamics=True)
            bad=copy.deepcopy(meta);del bad['native_fields'][name]
            with self.assertRaises(ValueError):native_model.validate_model_evidence(creature,bad,snapshot,actuator_dynamics=True)

    def test_new_contract_and_comparison_schema_do_not_relax_old_criteria(self):
        self.assertEqual(len(self.expanded['cells']),165)
        c=route.declaration(subject.ROOT/'sdk/discovery/creature_response_probe_v3.json')
        self.assertTrue(subject.actuator_aware(c));self.assertEqual(sum(v[2] for v in route.gates(c)),223)
        for key in ('minimum_ordering_accuracy_per_body','minimum_distinguishable_pairs_per_body','maximum_selected_regret_rad_s',
                    'matching_bounds','maximum_repeat_spread_rad_s','patterns'):
            self.assertEqual(c['response_probe'][key],subject.NUMERICAL_RECIPE[key])
        for key,value in (('seed',1061143),('predictor','legacy'),('native_actuator_dynamics_binding',False)):
            bad=copy.deepcopy(c);bad['response_probe'][key]=value
            with self.assertRaises(ValueError):subject.validate(bad)
        row,_=numerical_fixture.NumericalProbeControls.rows(self,0,0)
        row['resolution']['response_probe']['policy']['schema_version']=subject.ACTUATOR_SCHEMA
        subject.NumericalMatchedGroup('body',0,schema=subject.ACTUATOR_SCHEMA).control(row,(0,0))
        with self.assertRaises(ValueError):subject.NumericalMatchedGroup('body',0).control(row,(0,0))
        for version,count in (('v1',195),('v2',207)):
            legacy_contract=route.declaration(subject.ROOT/f'sdk/discovery/creature_response_probe_{version}.json')
            self.assertEqual(sum(v[2] for v in route.gates(legacy_contract)),count)


if __name__=='__main__':unittest.main()
