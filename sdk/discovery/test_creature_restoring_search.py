"""New withdrawal, paired population and compact-state controls without physics."""
import copy
from contextlib import ExitStack
import hashlib
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import mujoco
import numpy as np

import creature_capture as capture
import creature_native as native
import creature_response_constraints as constraints
import creature_response_search as search
import creature_restoring_search as subject
import creature_righting as righting
import creature_righting_sequence as sequence
import creature_trajectory_search as trajectory
import test_creature_response_probe as legacy
from gpu_quadruped_model import f32, sha
from run_creature_native import source_paths
from test_portable_search import _fixture


class RestoringTrajectoryControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=search.probe.bridge.LocomotionCore(Path(os.environ['QUADRUPED_TEST_CORE']))
        cls.template=_fixture(cls.core)['provider_request']['state']
        cls.route=native.declaration(subject.ROOT/subject.ROUTE)
        cls.search=native.declaration(subject.ROOT/subject.SEARCH)
        cls.root=Path(os.environ['EXPLORER_TEST_OUTPUT'])/'restoring'
        cls.root.mkdir()

    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in restoring controls')))

    def cell(self,index=4):
        cell=search.SearchController(self.core,self.route['cells'][index],seed=subject.RECIPE['seed'])
        self.addCleanup(cell.close)
        return cell

    def inputs(self,cell,step=0,near=False):
        observation,native_row=legacy.ResponseProbeControls.inputs(self,cell,step)
        if near:
            joint=observation['state']['ordered_joint_observations'][0]
            joint['position_rad']=f32(.98*cell.spec['joints'][0]['upper_limit_rad'])
            native_row['qpos'][7]=joint['position_rad']
        return observation,native_row

    @staticmethod
    def prediction(converged=True):
        return dict(velocity=np.zeros(14),solver=dict(converged=converged,kkt_residual=0. if converged else .01))

    def control(self,cell,step=0,near=False,converged=True):
        o,n=self.inputs(cell,step,near)
        with patch.object(constraints,'response',return_value=self.prediction(converged)):
            return cell.step(search.observe(cell,o,n))

    def compact(self,index=4):
        cell=self.cell(index)
        c=native.batch_contract(self.route,[index]);c['outer_steps']=1
        positions,velocities=native.initial_arrays([cell.creature],c)
        o,n=self.inputs(cell,near=True)
        n.update(qpos=positions[0].tolist(),qvel=velocities[0].tolist(),contacts=[])
        roll=c['initial_roll_angles_rad'][0]
        rotation=np.asarray([[1.,0.,0.],[0.,math.cos(roll),-math.sin(roll)],[0.,math.sin(roll),math.cos(roll)]])
        o['state']['base_pose_world'].update(position_m=dict(x=0.,y=float(positions[0,2]),z=0.),
            orientation_xyzw=search.probe.bridge._quaternion_xyzw(rotation))
        for joint,q in zip(o['state']['ordered_joint_observations'],positions[0,7:],strict=True):
            joint['position_rad']=float(q);joint['velocity_rad_s']=0.
        with patch.object(constraints,'response',return_value=self.prediction()):
            control=cell.step(search.observe(cell,o,n))
        control.update(cell=0,outer_step=0,native_observation=n)
        samples=[[dict(cell=0,step=i+1,ctrl=[f32(v) for v in control['native_targets']],
            time_s=(i+1)*c['timestep_s'],qpos=positions[0].tolist(),qvel=velocities[0].tolist(),
            actuator_force_nm=[0.]*8,joint_force_nm=[0.]*8,batch_contacts=0,nefc=0,overflow=0,warnings=[],contacts=[])]
            for i in range(5)]
        rows=capture.project([control],samples)
        return c,cell,positions,velocities,control,samples,rows

    def screen(self):
        groups={}
        for meta in self.search['righting_metadata']:
            key=tuple(meta[k] for k in ('body_index','condition_index','start_index'))
            group=groups.setdefault(key,dict(zip(('body_index','condition_index','start_index'),key),
                reference_candidate_index=2,observations=[]))
            group['observations'].append(dict(meta,peak_rotation_degrees=30.,
                peak_gain_against_timed_degrees=6.,peak_gain_against_reference_degrees=6.,
                joint_limit_violation_steps=0,response_model_withdrawals=0))
        return dict(groups=list(groups.values()))

    def receipt(self):
        metrics=[]
        for meta in self.route['righting_metadata']:
            metric=search.initial_metrics(self.route)
            p=self.route['righting_spec']['profiles'][meta['candidate_index']].get('response_search')
            if p:
                metric.update(response_search_rows=2,response_search_constraint_rows=2)
                name='restores' if p.get('withdrawal')=='restore_position' else 'brakes'
                metric['response_search_'+name]=2
            metrics.append(metric)
        audit=dict(ok=True,synthetic=False,gpu_worlds=15,controller_rows_replayed=30,native_rows_verified=150,
            metrics=metrics,reader_world_build_count=0,capture=capture.report(30,True))
        return dict(contract=copy.deepcopy(self.route),audit=audit)

    def test_01_population_pairs_48_trajectories_on_24_bodies_and_both_starts(self):
        c=self.search;s=c['righting_spec']
        self.assertEqual((len(c['cells']),len(s['descriptors']),len(s['profiles'])),(528,24,99))
        self.assertEqual([len(v) for v in s['profiles_by_body']],[11]*24)
        self.assertEqual([p['roll_rad'] for p in s['starts']],subject.RECIPE['starts_rad'])
        for index in range(48):
            self.assertEqual(sum(3+2*index in row for row in s['profiles_by_body']),2)
            a,b=s['profiles'][3+2*index:5+2*index]
            self.assertEqual({a['response_search']['withdrawal'],b['response_search']['withdrawal']},
                {'zero_velocity','restore_position'})
            self.assertEqual({k:v for k,v in a.items() if k not in ('id','response_search')},
                {k:v for k,v in b.items() if k not in ('id','response_search')})

    def test_02_exposed_pose_templates_are_preserved_with_measured_phase_gates(self):
        old=trajectory.proposals(trajectory.RECIPE);new=subject.proposals()
        self.assertEqual(len({righting.behavior_key(p) for p in self.search['righting_spec']['profiles']}),99)
        self.assertEqual({phase['advance_when'] for p in new for phase in p['phases']},{'pose','contact','progress'})
        for a,b in zip(old,new,strict=True):
            self.assertEqual([p['pose'] for p in a['phases']],[p['pose'] for p in b['phases']])
            sequence.profile(b)

    def test_03_policy_refuses_aliases_and_legacy_sequence_opt_in(self):
        for key,value in (('withdrawal','learned'),('reserve_method','coupled'),('feasibility','interval'),('extra',0)):
            with self.assertRaises(ValueError):search.policy(dict(subject.DEFAULT,**{key:value}))
        for payload in (None,1,[],True):
            p=copy.deepcopy(search.spec(protected=True)['profiles'][6]);p['response_search']=payload
            with self.assertRaises(ValueError):righting.profile(p)
        p=copy.deepcopy(self.route['righting_spec']['profiles'][3])
        p['response_search']=copy.deepcopy(search.CONSTRAINED_DEFAULT)
        with self.assertRaises(ValueError):righting.profile(p)
        p=copy.deepcopy(search.spec(protected=True)['profiles'][6]);p['response_search']=subject.DEFAULT
        with self.assertRaises(ValueError):righting.profile(p)

    def test_04_macro_expansion_refuses_competing_literal_fields(self):
        raw=json.loads((subject.ROOT/subject.ROUTE).read_bytes())
        for key in ('righting_spec','trajectory_reference_by_body',*righting.EXPANDED):
            with self.assertRaises(ValueError):subject.expand(dict(raw,**{key:[]}))

    def test_05_new_contract_refuses_scope_drift_and_preserves_old_budgets(self):
        for key,value in (('outer_steps',721),('capture_mode','full'),('maximum_worlds_per_batch',5),
                          ('trajectory_screen',{}),('response_confirmation',{})):
            bad=copy.deepcopy(self.search);bad[key]=value
            with self.assertRaises(ValueError):search.validate(bad)
        for version,count,worlds in (('v1',216,240),('v2',248,288)):
            old=native.declaration(subject.ROOT/f'sdk/discovery/creature_response_search_{version}.json')
            self.assertEqual(sum(v[2] for v in native.gates(old)),count)
            self.assertEqual(len(old['cells']),worlds)
        bad=copy.deepcopy(self.search);bad['response_search']['outer_steps']=719
        with self.assertRaises(ValueError):search.validate(bad)

    def test_06_route_and_search_bind_identical_source_populations(self):
        a=source_paths(subject.ROOT/subject.ROUTE,self.route)
        b=source_paths(subject.ROOT/subject.SEARCH,self.search)
        self.assertEqual(set(a),set(b))
        self.assertTrue(all(p.is_file() for p in a))
        self.assertEqual(sum(g[2] for g in native.gates(self.route)),291)
        self.assertEqual(native.gates(self.route),native.gates(self.search))

    def test_07_initial_joint_pose_uses_actual_clearance_and_preserves_default(self):
        cell=self.cell();c=native.batch_contract(self.route,[4])
        q,v=native.initial_arrays([cell.creature],c)
        self.assertAlmostEqual(float(q[0,7]),.98*cell.spec['joints'][0]['upper_limit_rad'],places=6)
        self.assertAlmostEqual(float(q[0,2])+righting.ground_clearance(cell.creature,c['initial_roll_angles_rad'][0],
            q[0,7:].tolist()),.005,places=6)
        self.assertTrue(np.array_equal(v,np.zeros((1,14),np.float32)))
        default=dict(c,mode='development_discovery')
        old=righting.initial_arrays([cell.creature],c['initial_roll_angles_rad'])
        self.assertTrue(all(np.array_equal(a,b) for a,b in zip(native.initial_arrays([cell.creature],default),old)))
        with self.assertRaises(ValueError):righting.ground_clearance(cell.creature,0.,[math.nan]*8)

    def test_08_restoration_is_inward_bounded_and_zero_in_the_interior(self):
        cell=self.cell();o,_=self.inputs(cell)
        action=dict(commands=[dict(maximum_speed_rad_s=.2,joint_guard_applied=False,canonical_velocity_rad_s=0.) for _ in range(8)])
        for sign in (-1,0,1):
            for j,observed in zip(cell.spec['joints'],o['state']['ordered_joint_observations'],strict=True):
                observed['position_rad']=j['upper_limit_rad'] if sign>0 else j['lower_limit_rad'] if sign<0 else 0.
            answer=subject.withdrawal(action,cell,o['state'])
            self.assertTrue(all(-sign*u>0 if sign else u==0 for u in answer['targets']))
            self.assertTrue(all(abs(u)<=.2 for u in answer['targets']))
        o['state']['ordered_joint_observations'][0]['position_rad']=math.inf
        with self.assertRaises(ValueError):subject.withdrawal(action,cell,o['state'])

    def test_09_restoration_preserves_bound_guard_and_refuses_invalid_caps(self):
        cell=self.cell();o,_=self.inputs(cell)
        action=dict(commands=[dict(maximum_speed_rad_s=3.5,joint_guard_applied=False,canonical_velocity_rad_s=0.) for _ in range(8)])
        for j,observed in zip(cell.spec['joints'],o['state']['ordered_joint_observations'],strict=True):
            observed['position_rad']=j['upper_limit_rad']+.2
        answer=subject.withdrawal(action,cell,o['state'])
        self.assertEqual(answer['targets'],[-.75]*8)
        for cap in (0.,-1.,math.nan,True):
            bad=copy.deepcopy(action);bad['commands'][0]['maximum_speed_rad_s']=cap
            with self.assertRaises(ValueError):subject.withdrawal(bad,cell,o['state'])

    def test_10_feasible_trajectory_uses_one_current_action_and_advances_phase(self):
        cell=self.cell();cell.response_state['next_replan_step']=999
        row=self.control(cell);d=row['resolution']['response_search']
        self.assertEqual(d['selection_reason'],'replanned')
        self.assertEqual([p['action_index'] for p in d['predictions']],[0])
        self.assertEqual(cell.sequence_state['elapsed'],1)
        self.assertEqual(cell.response_state,dict(action_index=0,next_replan_step=1))

    def test_11_zero_withdrawal_pauses_phase_without_erasing_proposal(self):
        row=self.control(self.cell(3),near=True);d=row['resolution']['response_search'];p=row['resolution']['sequence']
        self.assertEqual(d['selection_reason'],'braking_withdrawal')
        self.assertEqual(row['native_targets'],[0.]*8)
        self.assertEqual(p['state_after'],p['state_before'])
        self.assertNotEqual(p['proposed_state_after'],p['state_after'])

    def test_12_restoring_withdrawal_forecasts_the_actual_inward_command(self):
        row=self.control(self.cell(),near=True);d=row['resolution']['response_search']
        self.assertEqual(d['selection_reason'],'position_restoration')
        self.assertLess(row['native_targets'][0],0.)
        self.assertEqual(row['native_targets'][1:],[0.]*7)
        self.assertEqual(d['constraints']['withdrawal_prediction']['native_targets'],[f32(v) for v in row['native_targets']])
        self.assertNotEqual(d['constraints']['withdrawal_prediction']['native_targets'],d['constraints']['brake_prediction']['native_targets'])

    def test_13_model_failure_still_uses_bounded_withdrawal_and_stays_disqualifying(self):
        cell=self.cell();row=self.control(cell,near=True,converged=False)
        self.assertEqual(row['resolution']['response_search']['selection_reason'],'model_nonconvergence')
        self.assertLess(row['native_targets'][0],0.)
        m=search.initial_metrics(self.route);search.measure_control(m,row)
        self.assertEqual((m['response_search_failures'],m['response_search_restores']),(1,0))

    def test_14_nonconvergent_actual_withdrawal_forecast_is_not_hidden(self):
        cell=self.cell();o,n=self.inputs(cell,near=True)
        with patch.object(constraints,'response',side_effect=[self.prediction(),self.prediction(),self.prediction(False)]):
            row=cell.step(search.observe(cell,o,n))
        self.assertEqual(row['resolution']['response_search']['selection_reason'],'model_nonconvergence')
        self.assertTrue(row['resolution']['sequence']['withdrawal_paused'])

    def test_15_phase_resumes_only_when_fresh_trajectory_is_feasible(self):
        cell=self.cell();self.control(cell,near=True);before=copy.deepcopy(cell.sequence_state)
        row=self.control(cell,step=1)
        self.assertEqual(row['resolution']['sequence']['state_before'],before)
        self.assertEqual(cell.sequence_state['elapsed'],before['elapsed']+1)
        self.assertFalse(row['resolution']['sequence']['withdrawal_paused'])

    def test_16_pure_planning_and_batch_refusal_leave_all_state_unchanged(self):
        batch=search.SearchBatch(self.core,self.route['cells'][3:5],seed=subject.RECIPE['seed'])
        self.addCleanup(batch.close)
        observations=[search.observe(c,*self.inputs(c,near=True)) for c in batch.controllers]
        before=native.planning_states(batch)
        with patch.object(constraints,'response',return_value=self.prediction()):
            batch.controllers[0].plan(observations[0]);self.assertEqual(native.planning_states(batch),before)
            observations[1]['whole_body_contacts']['state_sha256']='0'*64
            with self.assertRaises(ValueError):batch.step(observations)
        self.assertEqual(native.planning_states(batch),before)

    def test_17_metrics_separate_restoration_and_refuse_crossed_forecasts(self):
        row=self.control(self.cell(),near=True);metric=search.initial_metrics(self.route)
        search.measure_control(metric,row)
        search.validate_metrics(dict(self.route,outer_steps=1),self.route['righting_metadata'][4],metric)
        self.assertEqual((metric['response_search_restores'],metric['response_search_brakes']),(1,0))
        for key,value in (('applied_action',1),('model_ordering_qualified',True),('selection_reason','braking_withdrawal')):
            bad=copy.deepcopy(row);bad['resolution']['response_search'][key]=value
            with self.assertRaises(ValueError):search.measure_control(search.initial_metrics(self.route),bad)
        bad=copy.deepcopy(row);bad['resolution']['response_search']['constraints']['withdrawal_prediction']['native_targets']=[0.]*8
        with self.assertRaises(ValueError):search.measure_control(search.initial_metrics(self.route),bad)

    def test_18_full_projection_compares_response_and_phase_fields_independently(self):
        c,cell,q,v,control,samples,rows=self.compact()
        capture.verify_projection(rows,[control],samples)
        for kind in ('missing','decision','phase'):
            bad=copy.deepcopy(rows)
            if kind=='missing':del bad[0]['response_control']
            elif kind=='decision':bad[0]['response_control']['decision']['applied_action']=0
            else:bad[0]['response_control']['sequence']['state_after']['elapsed']+=1
            with self.assertRaises(ValueError):capture.verify_projection(bad,[control],samples)

    def test_19_compact_reader_reconstructs_new_and_reference_control_counts(self):
        for index in (2,3,4):
            c,cell,q,v,control,samples,rows=self.compact(index)
            reader=capture.Reader(c,[cell.creature],q,v);reader.consume(rows);actual=reader.finish()[0]
            expected=search.initial_metrics(c);search.measure_control(expected,control)
            self.assertEqual({k:actual[k] for k in expected},expected)
            self.assertEqual(actual['trajectory_samples'],5)

    def test_20_compact_reader_refuses_missing_decisions_paused_state_and_target_drift(self):
        c,cell,q,v,control,samples,rows=self.compact()
        for kind in ('missing','state','target','flag'):
            bad=copy.deepcopy(rows)
            if kind=='missing':del bad[0]['response_control']
            elif kind=='state':bad[0]['response_control']['sequence']['state_after']['elapsed']=1
            elif kind=='target':bad[0]['native_targets'][0]=0.
            else:bad[0]['response_control']['decision']['recovery_benefit_established']=True
            with self.assertRaises(ValueError):capture.Reader(c,[cell.creature],q,v).consume(bad)

    def test_21_pairing_requires_one_variant_to_pass_both_starts(self):
        screen=self.screen()
        for group in screen['groups']:
            for row in group['observations']:
                if row['candidate_index']>=3 and (row['candidate_index']-3)%2==group['start_index']:
                    row['joint_limit_violation_steps']=1
        report=subject.assess(self.search,screen)
        self.assertEqual((len(report['paired_starts']),len(report['paired_recipes'])),(192,96))
        self.assertEqual((report['zero_both_start_leads'],report['restore_both_start_leads']),(0,0))
        self.assertFalse(report['comparative_superiority_established'])

    def test_22_assessment_refuses_duplicate_missing_crossed_and_nonfinite_outcomes(self):
        for kind in ('duplicate','missing','crossed','nonfinite','reference'):
            screen=self.screen();group=screen['groups'][0]
            if kind=='duplicate':group['observations'].append(copy.deepcopy(group['observations'][0]))
            elif kind=='missing':group['observations'].pop()
            elif kind=='crossed':group['observations'][3]['body_id']='other'
            elif kind=='nonfinite':group['observations'][3]['peak_rotation_degrees']=math.nan
            else:group['reference_candidate_index']=1
            with self.assertRaises(ValueError):subject.assess(self.search,screen)

    def test_23_route_requires_all_paired_withdrawals_and_full_replay(self):
        receipt=self.receipt()
        self.assertEqual(subject.verify_route(receipt)['worlds'],15)
        for kind in ('missing','failure','replay','forecast_scope'):
            bad=copy.deepcopy(receipt)
            if kind=='missing':bad['audit']['metrics'][4]['response_search_restores']=1
            elif kind=='failure':bad['audit']['metrics'][4].update(response_search_restores=1,response_search_failures=1)
            elif kind=='replay':bad['audit']['controller_rows_replayed']=0
            else:bad['contract']['mode']='development_discovery'
            with self.assertRaises(ValueError):subject.verify_route(bad)

    def test_24_same_freeze_canary_requires_new_policy_coverage(self):
        folder=self.root/uuid.uuid4().hex;folder.mkdir()
        full=self.receipt();full['response_search_route_coverage']=subject.verify_route(full)
        bindings=dict(source={subject.ROUTE:sha(subject.ROOT/subject.ROUTE)},runtime={},gpu={})
        full.update(source_commit='fixture',source_status=[],synthetic=False,ok=True,
            source_runtime_unchanged=True,bindings=bindings)
        audit=folder/'independent-audit.json';audit.write_bytes(json.dumps(full['audit']).encode())
        full['artifacts']=[dict(path=audit.name,sha256=sha(audit),bytes=audit.stat().st_size)]
        path=folder/'receipt.json'
        def write(value):path.write_bytes(json.dumps(value).encode())
        write(full)
        self.assertTrue(capture.canary_receipt(path,self.search,'fixture',bindings,self.root)['within_run_projection_verified'])
        for kind in ('freeze','coverage','policy'):
            bad=copy.deepcopy(full)
            if kind=='freeze':bad['source_commit']='different'
            elif kind=='coverage':bad['response_search_route_coverage']={}
            else:bad['contract']['response_search']['restoration_margin_rad']=.09
            write(bad)
            with self.assertRaises(ValueError):capture.canary_receipt(path,self.search,'fixture',bindings,self.root)


if __name__=='__main__':
    unittest.main()
