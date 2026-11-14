"""Closed-loop selection, withdrawal, atomicity and broad-cohort accounting."""
import copy
import hashlib
import json
from contextlib import ExitStack
import os
from pathlib import Path
import unittest
import uuid
from unittest.mock import patch

import mujoco
import numpy as np

import creature_response_search as subject
import creature_native as route
import creature_righting as righting
import creature_trajectory_search as trajectory
import test_creature_response_probe as legacy
from test_portable_search import _fixture


class ResponseSearchControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=subject.probe.bridge.LocomotionCore(Path(os.environ['QUADRUPED_TEST_CORE']))
        cls.template=_fixture(cls.core)['provider_request']['state']
        cls.expanded=righting.expand(subject.spec(route=True))

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in response search controls')))

    def cell(self,index=3):
        c=subject.SearchController(self.core,self.expanded['cells'][index],seed=subject.RECIPE['seed'])
        self.addCleanup(c.close);return c

    def inputs(self,c,step=0):
        return legacy.ResponseProbeControls.inputs(self,c,step)

    @staticmethod
    def prediction(speed,converged=True):
        return dict(velocity=np.r_[np.zeros(3),speed,0.,0.,np.zeros(8)],
            solver=dict(converged=converged,kkt_residual=0. if converged else .01))

    def test_population_is_balanced_across_twenty_four_actual_bodies(self):
        s=subject.spec();cells=righting.expand(s)['cells']
        self.assertEqual(len(cells),240);self.assertEqual(len(s['descriptors']),24)
        self.assertEqual(len({d['morphology_id'] for d in s['descriptors']}),24)
        counts=[sum(3+i in row for row in s['profiles_by_body']) for i in range(8)]
        self.assertEqual(counts,[21]*8)
        for body,row in enumerate(s['profiles_by_body']):
            self.assertEqual(row[:3],[0,1,2]);self.assertNotIn(3+body%8,row);self.assertEqual(len(row),10)
        self.assertEqual(len(self.expanded['cells']),10)
        self.assertEqual(len({righting.behavior_key(p) for p in s['profiles']}),11)

    def test_policy_refuses_aliases_unbounded_cadence_and_wrong_controller(self):
        for key,value in (('direction',True),('direction',0),('maximum_rate_rad_s',float('nan')),
                          ('maximum_rate_rad_s',3.),('replan_steps',0),('replan_steps',True),('selection','trained')):
            with self.assertRaises(ValueError):subject.policy(dict(subject.DEFAULT,**{key:value}))
        with self.assertRaises(ValueError):subject.policy(dict(subject.DEFAULT,selection='unchanged',direction=-1))
        with self.assertRaises(ValueError):righting.RightingController(self.core,self.expanded['cells'][3],seed=1)
        bad=copy.deepcopy(self.expanded['cells'][3]['profile']);bad['joint_braking']={}
        with self.assertRaises(ValueError):righting.profile(bad)

    def test_plain_comparators_preserve_original_records(self):
        for index in (0,1):
            c=self.cell(index);old=righting.RightingController(self.core,self.expanded['cells'][index],seed=subject.RECIPE['seed'])
            self.addCleanup(old.close)
            for step in range(3):
                o,n=self.inputs(c,step);self.assertEqual(c.step(subject.observe(c,o,n)),old.step(o))

    def test_unchanged_comparator_never_calls_model_and_preserves_commands(self):
        c=self.cell(2);declaration=copy.deepcopy(self.expanded['cells'][2]);del declaration['profile']['response_search']
        old=righting.RightingController(self.core,declaration,seed=subject.RECIPE['seed']);self.addCleanup(old.close)
        with patch.object(subject,'response',side_effect=AssertionError('Model on unchanged comparator')):
            for step in range(3):
                o,n=self.inputs(c,step);actual=c.step(subject.observe(c,o,n));expected=old.step(o)
                self.assertEqual(actual['native_targets'],expected['native_targets'])
                self.assertEqual(actual['resolution']['ordered_commands'],expected['resolution']['ordered_commands'])
                self.assertEqual(actual['resolution']['response_search']['selection_reason'],'unchanged_comparator')

    def test_direction_and_rate_select_the_scored_action(self):
        for index in (3,4):
            c=self.cell(index);p=c.candidate['response_search'];o,n=self.inputs(c)
            with patch.object(subject,'response',side_effect=[self.prediction(p['direction']*i*.25) for i in range(9)]):
                row=c.step(subject.observe(c,o,n))
            d=row['resolution']['response_search'];winner=3 if p['maximum_rate_rad_s']==.75 else 8
            self.assertEqual(d['applied_action'],winner);self.assertEqual(d['predictions'][winner]['score'],0.)
            self.assertEqual(np.asarray(row['native_targets'],np.float32).astype(float).tolist(),d['predictions'][winner]['native_targets'])

    def test_held_patterns_rebuild_guarded_commands_and_replan_on_schedule(self):
        c=self.cell();o,n=self.inputs(c)
        with patch.object(subject,'response',side_effect=[self.prediction(-i*.25) for i in range(9)]):
            first=c.step(subject.observe(c,o,n))
        self.assertEqual(first['resolution']['response_search']['applied_action'],3)
        for step in range(1,6):
            o,n=self.inputs(c,step)
            for j,observed in zip(c.spec['joints'],o['state']['ordered_joint_observations'],strict=True):
                observed['position_rad']=j['upper_limit_rad']-1e-6
            n['qpos'][7:]=[j['position_rad'] for j in o['state']['ordered_joint_observations']]
            with patch.object(subject,'response',side_effect=AssertionError('Replanning between declared steps')):
                row=c.step(subject.observe(c,o,n))
            self.assertEqual(row['resolution']['response_search']['selection_reason'],'held_pattern')
            self.assertEqual(row['resolution']['response_search']['applied_action'],3)
            self.assertNotEqual(row['native_targets'],first['native_targets'])
        o,n=self.inputs(c,6)
        with patch.object(subject,'response',side_effect=[self.prediction(-i*.25) for i in range(9)]) as solved:
            row=c.step(subject.observe(c,o,n))
        self.assertEqual(solved.call_count,9);self.assertEqual(row['resolution']['response_search']['selection_reason'],'replanned')

    def test_all_alternatives_obey_speed_slew_and_current_joint_guards(self):
        c=self.cell();o,n=self.inputs(c)
        for sign in (-1,1):
            for joint,observed in zip(c.spec['joints'],o['state']['ordered_joint_observations'],strict=True):
                observed['position_rad']=joint['lower_limit_rad']+1e-6 if sign<0 else joint['upper_limit_rad']-1e-6
            n['qpos'][7:]=[j['position_rad'] for j in o['state']['ordered_joint_observations']]
            row=c.plan(subject.observe(c,o,n));predictions=row['resolution']['response_search']['predictions']
            for prediction in predictions:
                for value,joint,observed in zip(prediction['native_targets'],c.spec['joints'],o['state']['ordered_joint_observations'],strict=True):
                    self.assertLessEqual(abs(value),.200001)
                    future=observed['position_rad']+value/120
                    self.assertGreaterEqual(future,joint['lower_limit_rad']-1e-9)
                    self.assertLessEqual(future,joint['upper_limit_rad']+1e-9)

    def test_upright_state_withdraws_even_between_planning_steps(self):
        c=self.cell();c.response_state=dict(action_index=8,next_replan_step=24)
        o,n=self.inputs(c);o['state']['base_pose_world']['orientation_xyzw']=dict(x=0.,y=0.,z=0.,w=1.)
        o['state']['base_pose_world']['position_m']['y']=c.creature['compiled']['geometry']['initial_torso_center_y_m']
        with patch.object(subject,'response',side_effect=AssertionError('Model while upright')):
            row=c.step(subject.observe(c,o,n))
        d=row['resolution']['response_search'];self.assertEqual(d['selection_reason'],'upright_stance')
        self.assertEqual(d['applied_action'],0);self.assertEqual(c.response_state,dict(action_index=0,next_replan_step=1))

    def test_unconverged_prediction_withdraws_without_selecting_a_winner(self):
        c=self.cell();o,n=self.inputs(c)
        predictions=[self.prediction(-i*.25,i!=3) for i in range(9)]
        with patch.object(subject,'response',side_effect=predictions):row=c.step(subject.observe(c,o,n))
        d=row['resolution']['response_search'];self.assertEqual(d['selection_reason'],'model_nonconvergence')
        self.assertEqual(d['applied_action'],0)
        o,n=self.inputs(c,1)
        with patch.object(subject,'response',side_effect=AssertionError('Retry before cadence')):
            row=c.step(subject.observe(c,o,n))
        self.assertEqual(row['resolution']['response_search']['applied_action'],0)

    def test_pure_planning_and_batch_refusal_preserve_search_memory(self):
        batch=subject.SearchBatch(self.core,self.expanded['cells'][3:5],seed=subject.RECIPE['seed']);self.addCleanup(batch.close)
        observations=[subject.observe(c,*self.inputs(c)) for c in batch.controllers];before=route.planning_states(batch)
        batch.controllers[0].plan(observations[0]);self.assertEqual(before,route.planning_states(batch))
        self.assertIn('response_state',before[0]['state'])
        observations[1]['whole_body_contacts']['state_sha256']='0'*64
        with self.assertRaises(ValueError):batch.step(observations)
        self.assertEqual(before,route.planning_states(batch))

    def test_missing_stale_or_crossed_contacts_refuse_before_commit(self):
        for field in ('missing','state_sha256','binding'):
            c=self.cell();o,n=self.inputs(c);o=subject.observe(c,o,n);before=copy.deepcopy(c.response_state)
            if field=='missing':del o['whole_body_contacts']
            elif field=='binding':o['whole_body_contacts']['binding']['candidate_id']='crossed'
            else:o['whole_body_contacts'][field]='0'*64
            with self.assertRaises(ValueError):c.step(o)
            self.assertEqual(c.response_state,before);self.assertEqual(c.step_index,0)

    def test_declarations_bind_route_cohort_model_sources_and_complete_gate(self):
        for suffix,count in (('route_v1',10),('v1',240)):
            c=route.declaration(subject.ROOT/f'sdk/discovery/creature_response_search_{suffix}.json')
            self.assertEqual(len(c['cells']),count);self.assertEqual(sum(g[2] for g in route.gates(c)),216)
            self.assertTrue(route.actuator_dynamics(c));self.assertEqual(route.controller_types(c),(subject.SearchBatch,subject.SearchController))
            for key,value in (('outer_steps',c['outer_steps']+1),('maximum_worlds_per_batch',5),('capture_mode','compact_v1')):
                bad=copy.deepcopy(c);bad[key]=value
                with self.assertRaises(ValueError):subject.validate(bad)
        for version,count in (('v1',195),('v2',207),('v3',223)):
            old=route.declaration(subject.ROOT/f'sdk/discovery/creature_response_probe_{version}.json')
            self.assertEqual(sum(g[2] for g in route.gates(old)),count)

    def test_model_withdrawal_blocks_recovery_and_progress_shortlists(self):
        c=route.declaration(subject.ROOT/'sdk/discovery/creature_response_search_route_v1.json');metrics=[];bindings=[]
        for i,meta in enumerate(c['righting_metadata']):
            m=dict(righting.initial_metrics(),**trajectory.initial_metrics(),**subject.initial_metrics())
            m.update(terminal_upright_dwell_steps=305,longest_upright_dwell_steps=305,final_up_dot=1.,final_height_ratio=1.,
                trajectory_maximum_up_dot=0. if meta['candidate_index']>=3 else -.8,
                trajectory_maximum_distal_supported_up_dot=-1.,trajectory_samples=305)
            if meta['candidate_index']>=2:m.update(response_search_rows=61,response_search_replans=61)
            if meta['candidate_index']==3:m.update(response_search_replans=60,response_search_failures=1)
            metrics.append(m);bindings.append(self.cell(i).binding)
        result=righting.assess(c,metrics,bindings)
        self.assertTrue(all('response_model_withdrawal' in r['failure_codes'] for r in result['episodes'] if r['candidate_index']==3))
        selected=trajectory.assess(c,metrics)
        self.assertTrue(all(v['candidate_index']!=3 for g in selected['groups'] for v in g['progress_leads']))
        self.assertGreater(selected['progress_lead_count'],0)
        # Improvement against only one reference cannot qualify a progress lead.
        for m,meta in zip(metrics,c['righting_metadata'],strict=True):
            if meta['candidate_index']==1:m['trajectory_maximum_up_dot']=.5
        self.assertEqual(trajectory.assess(c,metrics)['progress_lead_count'],0)

    def test_route_requires_recurring_actions_holds_withdrawal_and_exact_counts(self):
        c=route.declaration(subject.ROOT/'sdk/discovery/creature_response_search_route_v1.json');metrics=[]
        for meta in c['righting_metadata']:
            m=subject.initial_metrics();p=c['righting_spec']['profiles'][meta['candidate_index']].get('response_search')
            if p:
                m['response_search_rows']=61
                if meta['start_id']=='upright':m['response_search_upright']=61
                elif p['selection']=='unchanged':m['response_search_unchanged']=61
                else:m.update(response_search_replans=3,response_search_holds=58,response_search_nonzero_actions=3)
            metrics.append(m)
        receipt=dict(contract=c,audit=dict(ok=True,synthetic=False,controller_rows_replayed=610,native_rows_verified=3050,metrics=metrics))
        self.assertTrue(subject.verify_route(None,receipt)['complete'])
        for field,value in (('response_search_nonzero_actions',0),('response_search_holds',0),('response_search_rows',60)):
            bad=copy.deepcopy(receipt);bad['audit']['metrics'][3][field]=value
            with self.assertRaises(ValueError):subject.verify_route(None,bad)

    def test_broad_launch_refuses_missing_stale_or_corrupt_route_evidence(self):
        c=route.declaration(subject.ROOT/'sdk/discovery/creature_response_search_v1.json')
        small=route.declaration(subject.ROOT/'sdk/discovery/creature_response_search_route_v1.json')
        root=Path(os.environ['EXPLORER_TEST_OUTPUT'])/('route-binding-'+uuid.uuid4().hex);root.mkdir(parents=True)
        binding=dict(source={'fixture':'bound'},runtime={'fixture':'bound'},gpu='synthetic-control')
        r=dict(contract=small,source_commit='f'*40,source_status=[],bindings=binding,ok=True,synthetic=False,
            physical_started=True,source_runtime_unchanged=True,zero_world_gate_passed=True,
            safety_controls={n:k for n,_,k in route.gates(c)},artifacts=[])
        def write(name,value):
            p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value),encoding='utf-8',newline='\n')
            return dict(path=name,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
        # Coverage itself is tested above; here the shared archive and cleanup
        # readers exercise prerequisite identity and corruption independently.
        r['audit']=dict(reader_world_build_count=0,gpu_worlds=10)
        r['response_search_route_coverage']=dict(complete=True)
        r['artifacts'].append(write('independent-audit.json',r['audit']))
        cleanup=dict(ok=True,cleanup_seconds=10.,stable_handles=True,exact_job_membership=True,
            pid_reopened_after_job_close=False,errors=[],members=[],physical_acceptance_authority=False,release_authority=False)
        for name in [n+'-gate/cleanup.json' for n in r['safety_controls']]+['runtime-gate/cleanup.json','native/cleanup.json','reader/cleanup.json']:
            r['artifacts'].append(write(name,cleanup))
        write('receipt.json',r)
        with patch.object(subject,'verify_route',return_value=dict(complete=True)):
            self.assertTrue(subject.route_receipt(root/'receipt.json',c,'f'*40,binding,root)['coverage_complete'])
            for key,value in (('source_commit','e'*40),('physical_started',False),('source_status',['dirty']),('ok',False)):
                bad=copy.deepcopy(r);bad[key]=value;write('receipt.json',bad)
                with self.assertRaises(ValueError):subject.route_receipt(root/'receipt.json',c,'f'*40,binding,root)
            write('receipt.json',r);write('independent-audit.json',dict(reader_world_build_count=1,gpu_worlds=10))
            with self.assertRaises(ValueError):subject.route_receipt(root/'receipt.json',c,'f'*40,binding,root)
        with self.assertRaises(FileNotFoundError):subject.route_receipt(root/'missing.json',c,'f'*40,binding,root)


if __name__=='__main__':unittest.main()
