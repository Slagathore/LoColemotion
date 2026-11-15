"""Bounded closed-loop action proposals across the exposed creature population.

The one-step model is a search heuristic, not a qualified recovery controller.
Replanning reads fresh prepared contacts. Between decisions only an action
pattern is held; commands are rebuilt from current state and guarded again.
"""
import copy
import hashlib
import itertools
import json
import math
from pathlib import Path

import numpy as np

import creature_righting as righting
import creature_response_probe as probe
import creature_response_constraints as constraints
import creature_response_confirmation as confirmation
import creature_restoring_search as restoring
import creature_trajectory_search as trajectory
from coupled_contact_response import CoupledBody, response, velocity_actuation
from evaluate_coupled_contact_response import actuator_parameters, settings
from actuation_recovery_mechanics import xyz
from creature_batch import require

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = 'locolemotion_response_search_policy_v1'
POPULATION = dict(path='sdk/discovery/creature_torque_map_v2.json',
    sha256='06a30a7461f28f911b97ef7bb13657a9f1b7db2f01443941e2ea72bda49265b5')
PREDECESSOR = dict(path='sdk/discovery/creature_response_probe_native_result_v3.json',
    sha256='51a6ad7f3bf412f0ea82054f30b3ffb673c72041fb11ad63089fc8f383b1e826')
DEFAULT = dict(schema_version=SCHEMA, selection='model', direction=1,
    maximum_rate_rad_s=.75, replan_steps=6)
RECIPE = dict(schema_version='locolemotion_response_search_v1', seed=1061145,
    body_count=24, directions=[-1,1], maximum_rates_rad_s=[.75,2.], replan_steps=[6,24],
    assignment='omit_body_index_modulo_eight', route_body_indices=[0],
    route_profile_indices=[0,1,2,3,10], route_outer_steps=61,
    search_outer_steps=1440, tilt_gain_s_inv=2., action_patterns=probe.PATTERNS,
    score='negative_squared_root_angular_velocity_error',
    upright_withdrawal='original_stance_controller',
    nonconvergence_withdrawal='unchanged_guarded_action_until_next_replan',
    source=POPULATION, predictor=probe.ACTUATOR_COMPONENT,
    model_ordering_qualified=False, recovery_authority=False)
REASONS = dict(replanned='replans', held_pattern='holds', upright_stance='upright',
    unchanged_comparator='unchanged', model_nonconvergence='failures')

CONSTRAINED_SCHEMA = 'locolemotion_response_search_policy_v2'
CONSTRAINED_PREDECESSOR = dict(path='sdk/discovery/creature_response_joint_limit_result_v1.json',
    sha256='71fb112c68416d954e0adfa9d7d5e1dd53765743f6a56bb2a2c725771ed0b62c')
CONSTRAINED_DEFAULT = dict(DEFAULT,schema_version=CONSTRAINED_SCHEMA,reserve_method='fixed',feasibility='interval')
CONSTRAINED_RECIPE = dict(RECIPE,schema_version='locolemotion_response_search_v2',seed=1061146,
    maximum_rates_rad_s=[.75],replan_steps=[6],reserve_methods=['fixed','coupled'],
    feasibility_checks=['interval','stopping'],route_profile_indices=[0,1,2,5,12],route_outer_steps=181,
    margin_rad=constraints.MARGIN_RAD,fixed_deceleration_rad_s2=constraints.FIXED_DECELERATION,
    coupled_braking_fraction=constraints.BRAKING_FRACTION,
    coupled_deceleration_bounds_rad_s2=[1.,constraints.MAXIMUM_DECELERATION],
    low_speed_fallback_rad_s=constraints.LOW_SPEED_RAD_S,
    fresh_references=['brake','timed','unchanged','unprotected_rollneg','unprotected_rollpos'],
    upright_withdrawal='protected_stance_with_feasibility_check',
    nonconvergence_withdrawal='zero_velocity_brake_and_retry_next_interval',
    infeasibility_withdrawal='zero_velocity_brake_and_retry_next_interval',
    held_pattern_check='fresh_prediction_every_interval_replan_if_infeasible',
    stopping_guaranteed=False)
CONSTRAINT_METRICS = ('brakes','constraint_rows','constraint_guarded_rows','constraint_infeasible_rows','constraint_forced_replans')


def constrained(c):
    return restoring.enabled(c) or c.get('response_search',{}).get('schema_version')==CONSTRAINED_RECIPE['schema_version']


def policy(value):
    require(type(value) is dict,'Response search policy object')
    if value.get('schema_version')==restoring.SCHEMA:return restoring.policy(value)
    modern=value.get('schema_version')==CONSTRAINED_SCHEMA
    default=CONSTRAINED_DEFAULT if modern else DEFAULT
    require(set(value)==set(default) and value['schema_version']==default['schema_version'],
        'Response search policy fields')
    require(value['selection'] in ('model','unchanged') and type(value['direction']) is int and
        value['direction'] in (-1,1) and type(value['replan_steps']) is int and value['replan_steps'] in (6,24) and
        type(value['maximum_rate_rad_s']) in (int,float) and value['maximum_rate_rad_s'] in (.75,2.),
        'Response search policy bounds')
    if modern:
        require(value['selection']=='model' and value['maximum_rate_rad_s']==.75 and value['replan_steps']==6
            and value['reserve_method'] in ('fixed','coupled') and value['feasibility'] in ('interval','stopping'),
            'Response constraint methods or fixed rate/cadence')
    else:
        require(value['selection']!='unchanged' or value==dict(DEFAULT,selection='unchanged'),
            'Response unchanged comparator aliases')
    return copy.deepcopy(value)


def behavior_key(value):
    p=policy(value)
    keys=restoring.DEFAULT if p['schema_version']==restoring.SCHEMA else CONSTRAINED_DEFAULT if p['schema_version']==CONSTRAINED_SCHEMA else DEFAULT
    return tuple(p[k] for k in keys)


def source_document(pin):
    data=(ROOT/pin['path']).read_bytes()
    require(hashlib.sha256(data).hexdigest()==pin['sha256'],'Response search source binding')
    return json.loads(data)


def spec(*, route=False, protected=False):
    original=source_document(POPULATION)['righting_spec']
    profiles=copy.deepcopy(original['profiles'][:2])
    profiles.append(dict(profiles[1],id='response_unchanged',response_search=dict(DEFAULT,selection='unchanged')))
    recipe=CONSTRAINED_RECIPE if protected else RECIPE
    if protected:
        for direction in (-1,1):
            profiles.append(dict(profiles[1],id='unprotected_rollneg' if direction<0 else 'unprotected_rollpos',
                response_search=dict(DEFAULT,direction=direction)))
        for direction,reserve,feasibility in itertools.product((-1,1),recipe['reserve_methods'],recipe['feasibility_checks']):
            name=f"roll{'pos' if direction>0 else 'neg'}_{reserve}_{feasibility}"
            profiles.append(dict(profiles[1],id=name,response_search=dict(CONSTRAINED_DEFAULT,direction=direction,
                reserve_method=reserve,feasibility=feasibility)))
    else:
        for direction,rate,cadence in itertools.product(RECIPE['directions'],RECIPE['maximum_rates_rad_s'],RECIPE['replan_steps']):
            name=f"roll{'pos' if direction==1 else 'neg'}_rate{round(rate*100):03d}_every{cadence:02d}"
            profiles.append(dict(profiles[1],id=name,response_search=dict(DEFAULT,direction=direction,
                maximum_rate_rad_s=rate,replan_steps=cadence)))
    bodies=recipe['route_body_indices'] if route else list(range(recipe['body_count']))
    if route:profiles=[profiles[i] for i in recipe['route_profile_indices']]
    references=5 if protected else 3
    assignments=[list(range(len(profiles))) if route else list(range(references))+
        [references+i for i in range(8) if i!=b%8] for b in bodies]
    return dict(schema_version=righting.ASSIGNED_SCHEMA,
        descriptors=[copy.deepcopy(original['descriptors'][b]) for b in bodies],profiles=profiles,
        profiles_by_body=assignments,conditions=copy.deepcopy(original['conditions']),
        starts=copy.deepcopy(original['starts'])+([dict(id='upright',roll_rad=0.)] if route else []))


def validate(c):
    opted=any('response_search' in p for p in c.get('righting_spec',{}).get('profiles',[]))
    require(opted==('response_search' in c),'Response search declaration required')
    require(not confirmation.enabled(c) or opted,'Response confirmation requires response search')
    if not opted:return
    if restoring.enabled(c):
        restoring.validate(c)
        return
    route=c['mode']=='route_ghost';modern=constrained(c)
    recipe=CONSTRAINED_RECIPE if modern else RECIPE;predecessor=CONSTRAINED_PREDECESSOR if modern else PREDECESSOR
    expected_spec=spec(route=route,protected=modern)
    seed=recipe['seed'];steps=recipe['route_outer_steps' if route else 'search_outer_steps']
    if confirmation.enabled(c):
        confirmation.validate(c)
        predecessor=confirmation.SOURCE;expected_spec=confirmation.spec(route=route)
        seed=confirmation.POLICY['seed'];steps=confirmation.POLICY['route_outer_steps' if route else 'outer_steps']
    require(c['mode'] in ('route_ghost','development_discovery') and c['response_search']==recipe and
        c['righting_spec']==expected_spec and c['predecessor']==predecessor and
        c['predictor_component']==probe.ACTUATOR_COMPONENT and c['seed']==seed and c['outer_steps']==steps and
        c['capture_mode']=='full' and c['maximum_worlds_per_batch']==4 and
        c['readback']==dict(mode='shared_snapshot',reference_check=False) and c.get('retain_planning_state') is True and
        c['trajectory_screen']==trajectory.POLICY and c['trajectory_reference_by_body']==[2]*len(c['righting_spec']['descriptors']) and
        not any(k in c for k in ('compact_capture','response_probe','post_native_path_screen','contact_reactions')),
        'Response search frozen population or scope')
    source_document(predecessor)
    component=source_document(probe.ACTUATOR_COMPONENT)
    for pin in component['source_pins']:source_document_bytes(pin)


def source_document_bytes(pin):
    require(hashlib.sha256((ROOT/pin['path']).read_bytes()).hexdigest()==pin['sha256'],
        'Response predictor source binding')


def source_dependencies(c):
    if 'response_search' not in c:return []
    component=source_document(probe.ACTUATOR_COMPONENT);modern=constrained(c);version='v2' if modern else 'v1'
    predecessor=CONSTRAINED_PREDECESSOR if modern else PREDECESSOR
    return [ROOT/p['path'] for p in (POPULATION,predecessor,probe.ACTUATOR_COMPONENT,*component['source_pins'])]+[
        ROOT/'sdk/discovery/coupled_contact_response_plan_v2.json',
        ROOT/'sdk/discovery/creature_response_search.py',ROOT/'sdk/discovery/test_creature_response_search.py',
        ROOT/f'sdk/discovery/creature_response_search_route_{version}.json',ROOT/f'sdk/discovery/creature_response_search_{version}.json'] + (
        confirmation.source_dependencies() if confirmation.enabled(c) else []) + (
        restoring.source_dependencies() if restoring.enabled(c) else [])


def observe(controller,observation,native):
    if 'response_search' not in controller.candidate:return observation
    return dict(observation,whole_body_contacts=probe.packet(controller.creature,controller.binding,observation['state'],native))


class SearchController(righting.RightingController):
    supports_response_search=True

    def __init__(self,core,declaration,*,seed):
        super().__init__(core,declaration,seed=seed)
        active='response_search' in self.candidate
        self.response_state=dict(action_index=0,next_replan_step=0) if active else None
        self.response_model=CoupledBody(self.spec) if active else None
        self.actuators=actuator_parameters(self.creature) if active else None
        self.response_config=settings(self.creature) if active else None

    def plan(self,observation):
        if self.response_model is None:return super().plan(observation)
        require('whole_body_contacts' in observation,'Response search missing prepared contacts')
        supplied=observation['whole_body_contacts'];state=observation['state']
        require(set(supplied)=={'schema_version','binding','state_sha256','native_time_s','contacts'} and
            supplied['schema_version']==probe.SCHEMA and supplied['binding']==self.binding and
            supplied['state_sha256']==probe.state_digest(state),'Response search stale or crossed contacts')
        base=super().plan({k:v for k,v in observation.items() if k!='whole_body_contacts'})
        base['request']['whole_body_contacts']=copy.deepcopy(supplied)
        p=self.candidate['response_search'];before=copy.deepcopy(self.response_state);after=copy.deepcopy(before)
        staged=p['schema_version']==restoring.SCHEMA
        actions=[None] if staged else probe.candidates(self.creature,self.candidate,state,self.previous,base)
        actions[0]=dict(commands=copy.deepcopy(base['resolution']['ordered_commands']),targets=base['native_targets'][:])
        if staged or p['schema_version']==CONSTRAINED_SCHEMA:
            return constraints.plan(self,base,observation,supplied,actions)
        predictions=[];desired=None;selected=0
        if base['resolution']['phase']=='upright_stance':
            reason='upright_stance';after=dict(action_index=0,next_replan_step=self.step_index+1)
        elif p['selection']=='unchanged':
            reason='unchanged_comparator';after=dict(action_index=0,next_replan_step=self.step_index+1)
        elif self.step_index<before['next_replan_step']:
            selected=before['action_index'];reason='held_pattern'
        else:
            pose=state['base_pose_world'];twist=state['base_twist_world'];joints=state['ordered_joint_observations']
            qd=np.asarray([j['velocity_rad_s'] for j in joints]);velocity=np.r_[xyz(twist['linear_velocity_m_s']),xyz(twist['angular_velocity_rad_s']),qd]
            prepared=self.response_model.prepare(xyz(pose['position_m']),[pose['orientation_xyzw'][k] for k in 'xyzw'],
                [j['position_rad'] for j in joints],velocity)
            rotation=prepared['frame']['rotations'][0]
            tilt=math.acos(max(-1.,min(1.,float(rotation[1,1]))))
            rate=p['direction']*min(p['maximum_rate_rad_s'],RECIPE['tilt_gain_s_inv']*tilt)
            desired=rotation[:,0]*rate
            config=settings(self.creature);a=self.actuators
            for index,action in enumerate(actions):
                targets=np.asarray(action['targets'],np.float32).astype(float)
                motor=velocity_actuation(qd,targets,a['gains'],a['force_ranges'],a['damping'])
                answer=response(self.response_model,prepared,motor['applied'],supplied['contacts'],config['dt'],
                    penetration_recovery_time=config['penetration_recovery_time'],joint_armature=a['armature'],
                    joint_velocity_derivative=motor['velocity_derivative'])
                error=answer['velocity'][3:6]-desired;score=-float(error @ error)
                require(math.isfinite(score),'Response search finite score')
                predictions.append(dict(action_index=index,native_targets=targets.tolist(),velocity=answer['velocity'].tolist(),
                    score=score,converged=answer['solver']['converged'],kkt_residual=answer['solver']['kkt_residual']))
            if all(v['converged'] for v in predictions):
                selected=max(range(len(predictions)),key=lambda i:(predictions[i]['score'],-i));reason='replanned'
            else:
                # An unconverged solve cannot select a candidate or earn benefit.
                # The original bounded action remains in control until retry.
                selected=0;reason='model_nonconvergence'
            after=dict(action_index=selected,next_replan_step=self.step_index+p['replan_steps'])
        chosen=actions[selected]
        base['native_targets']=chosen['targets'];base['resolution']['ordered_commands']=chosen['commands']
        base['resolution']['response_search']=dict(schema_version=SCHEMA,policy=copy.deepcopy(p),
            state_before=before,state_after=after,selection_reason=reason,applied_action=selected,predictions=predictions,
            desired_angular_velocity_world_rad_s=None if desired is None else desired.tolist(),
            held_value='action_pattern_only',model_ordering_qualified=False,recovery_benefit_established=False)
        return base

    def commit(self,record):
        super().commit(record)
        if self.response_state is not None:
            self.response_state=copy.deepcopy(record['resolution']['response_search']['state_after'])


class SearchBatch(righting.RightingBatch):
    Controller=SearchController


def initial_metrics(c=None):
    names=('rows','replans','holds','upright','unchanged','failures','nonzero_actions')
    return {'response_search_'+name:0 for name in names+(CONSTRAINT_METRICS if c and constrained(c) else ())
        +(('restores',) if c and restoring.enabled(c) else ())}


def measure_control(metric,row):
    decision=row['resolution'].get('response_search')
    if decision is None:return
    staged=decision['schema_version']==restoring.SCHEMA
    modern=staged or decision['schema_version']==CONSTRAINED_SCHEMA
    reasons=dict(REASONS,braking_withdrawal='brakes') if modern else REASONS
    if staged:reasons=dict(reasons,position_restoration='restores')
    require(decision['selection_reason'] in reasons and type(decision['applied_action']) is int and
        0<=decision['applied_action']<(10 if modern else 9) and decision['model_ordering_qualified'] is False and
        decision['recovery_benefit_established'] is False,'Response search control accounting')
    metric['response_search_rows']+=1
    metric['response_search_'+reasons[decision['selection_reason']]]+=1
    metric['response_search_nonzero_actions']+=int(0<decision['applied_action']<9)
    if modern:
        protection=decision['constraints']
        require(protection['stopping_guaranteed'] is False,'Response constraint safety overclaim')
        metric['response_search_constraint_rows']+=1
        metric['response_search_constraint_guarded_rows']+=int(protection['guarded_joint_count']>0)
        metric['response_search_constraint_infeasible_rows']+=int(any(not p['feasible'] for p in decision['predictions']))
        metric['response_search_constraint_forced_replans']+=int(protection['replan_trigger']=='held_became_infeasible')
        if staged:
            restoring.validate_decision(decision,row['native_targets'])
        elif decision['applied_action']==9:
            require(row['native_targets']==[0.]*8,'Response braking withdrawal must be zero target')


def validate_metrics(c,meta,metric):
    require(all(type(metric[k]) is int and 0<=metric[k]<=c['outer_steps'] for k in initial_metrics(c)),
        'Response search finite control counts')
    p=c['righting_spec']['profiles'][meta['candidate_index']].get('response_search')
    reasons=list(REASONS.values())+(['brakes'] if constrained(c) else [])+(['restores'] if restoring.enabled(c) else [])
    require(metric['response_search_rows']==(c['outer_steps'] if p else 0) and
        sum(metric['response_search_'+k] for k in reasons)==metric['response_search_rows'] and
        metric['response_search_nonzero_actions']<=metric['response_search_rows'], 'Response search control denominator')
    if constrained(c):
        modern=p is not None and p['schema_version'] in (CONSTRAINED_SCHEMA,restoring.SCHEMA)
        require(metric['response_search_constraint_rows']==(c['outer_steps'] if modern else 0)
            and all(metric['response_search_'+k]<=metric['response_search_constraint_rows'] for k in CONSTRAINT_METRICS),
            'Response constraint denominator')


def verify_route(folder,receipt):
    if restoring.enabled(receipt['contract']):return restoring.verify_route(receipt)
    if confirmation.enabled(receipt['contract']):return confirmation.verify_route(receipt)
    c=receipt['contract'];audit=receipt['audit']
    modern=constrained(c);steps=181 if modern else 61;total=10*steps
    require(c['mode']=='route_ghost' and audit['ok'] and not audit['synthetic'] and
        audit['controller_rows_replayed']==total and audit['native_rows_verified']==5*total,'Response search route replay')
    rows=[]
    for meta,metric in zip(c['righting_metadata'],audit['metrics'],strict=True):
        validate_metrics(c,meta,metric)
        p=c['righting_spec']['profiles'][meta['candidate_index']].get('response_search')
        if p is None:continue
        require(metric['response_search_failures']==0,'Response search route model withdrawal')
        if meta['start_id']=='upright':require(metric['response_search_upright']>0,'Response search stance withdrawal missing')
        elif p['selection']=='unchanged':require(metric['response_search_unchanged']==steps,'Response search unchanged route missing')
        else:require(metric['response_search_replans']>=3 and metric['response_search_holds']>0 and
            metric['response_search_nonzero_actions']>0,'Response search recurring native action coverage')
        if modern and meta['start_id']=='inverted' and p['schema_version']==CONSTRAINED_SCHEMA:
            require(metric['response_search_constraint_guarded_rows']>0,'Response native braking reserve coverage missing')
        rows.append(dict(cell_id=meta['cell_id'],**{k:metric[k] for k in initial_metrics(c)}))
    require(len(rows)==6,'Response search route population')
    return dict(complete=True,cells=rows,worlds=10,recovery_benefit_established=False,physical_acceptance_authority=False)


def route_receipt(path,c,source_commit,bindings,evidence_root):
    """Require a completed same-freeze route before the broader native search."""
    from creature_native import declaration, gates
    from creature_trajectory_diagnosis import Archive
    from run_contact_sequence_native_v2 import validate_cleanup
    path=Path(path).resolve(strict=True);evidence_root=Path(evidence_root).resolve(strict=True)
    require(path.is_relative_to(evidence_root) and path.name=='receipt.json','Response route evidence boundary')
    raw=path.read_bytes();receipt=json.loads(raw)
    route_worlds=15 if restoring.enabled(c) else 10
    route_path=restoring.ROUTE if restoring.enabled(c) else confirmation.ROUTE_DECLARATION if confirmation.enabled(c) else (
        'sdk/discovery/creature_response_search_route_v2.json' if constrained(c) else 'sdk/discovery/creature_response_search_route_v1.json')
    require(c['mode']=='development_discovery' and receipt['contract']==declaration(ROOT/route_path) and
        receipt['source_commit']==source_commit and receipt['source_status']==[] and receipt['bindings']==bindings and
        receipt['ok'] is True and receipt['synthetic'] is False and receipt['physical_started'] is True and
        receipt['source_runtime_unchanged'] is True and receipt['zero_world_gate_passed'] is True and
        receipt['safety_controls']=={n:k for n,_,k in gates(c)},'Response completed same-freeze route required')
    archive=Archive(path.parent,receipt)
    for name in archive.inventory:
        for _ in archive.lines(name):pass
    require(archive.document('independent-audit.json')==receipt['audit'] and
        receipt['audit']['reader_world_build_count']==0 and receipt['audit']['gpu_worlds']==route_worlds,
        'Response route audit binding')
    for name in [n+'-gate/cleanup.json' for n in receipt['safety_controls']]+['runtime-gate/cleanup.json','native/cleanup.json','reader/cleanup.json']:
        validate_cleanup(archive.document(name))
    coverage=verify_route(path.parent,receipt)
    require(receipt.get('response_search_route_coverage')==coverage,'Response route coverage differs')
    return dict(archive_relative_path=path.parent.relative_to(evidence_root).as_posix(),
        receipt_sha256=hashlib.sha256(raw).hexdigest(),source_commit=source_commit,
        artifacts_verified=len(archive.verified),route_worlds=route_worlds,coverage_complete=True,recovery_benefit_established=False)


class JointLimitTrace:
    """Join command, native motion and one-step forecast at the first crossing.

    This adds a retained physical observable, not a new acceptance criterion.
    Held action patterns never turn an old one-step prediction into a forecast
    for the current frame. Native outcomes remain those of the existing reader.
    """
    def __init__(self, creature, binding, cell, outer_steps):
        from collections import deque
        self.joints = creature['compiled']['morphology']['morphology_spec']['joints']
        self.binding, self.cell, self.outer_steps = binding, cell, outer_steps
        self.distal = {creature['spec']['geom_names'].index(s['body_id']+'_geom')
                       for s in creature['compiled']['morphology']['morphology_spec']['contact_sites']}
        require(len(self.joints)==8, 'Joint diagnosis requires eight ordered joints')
        self.controls, self.samples, self.violations = 0, 0, 0
        self.guard_commands, self.outward_beyond_bound = 0, 0
        self.maximum_excess = [0.]*8
        self.joint_violations, self.runs, self.longest_runs = [0]*8, [0]*8, [0]*8
        self.first = self.current = self.previous_native = self.last_selection = None
        self.history = deque(maxlen=3)
        self.prediction_count, self.prediction_error_sum, self.prediction_error_max = 0, 0., 0.

    def control(self, row):
        from creature_trajectory_diagnosis import f32
        require(self.controls<self.outer_steps and self.samples==5*self.controls and row['outer_step']==self.controls
                and row['cell']==self.cell and row['binding']==self.binding,
                'Joint diagnosis crossed control or incomplete interval')
        prepared = row['native_observation']
        observed = row['request']['state']['ordered_joint_observations']
        require(prepared['sampling_stage']=='prepared_before_control'
                and [v['position_rad'] for v in observed]==prepared['qpos'][7:]
                and [v['velocity_rad_s'] for v in observed]==prepared['qvel'][6:],
                'Joint diagnosis prepared state join')
        if self.previous_native is not None:
            require(prepared['qpos'][7:]==self.previous_native['qpos'][7:]
                    and prepared['qvel'][6:]==self.previous_native['qvel'][6:],
                    'Joint diagnosis prepared state continuity')
        commands = row['resolution']['ordered_commands']
        require([v['joint_id'] for v in commands]==[j['joint_id'] for j in self.joints]
                and len(row['native_targets'])==8
                and all(math.isfinite(v) for v in prepared['qpos']+prepared['qvel']+row['native_targets'])
                and [f32(v['canonical_velocity_rad_s']) for v in commands]==[f32(v) for v in row['native_targets']],
                'Joint diagnosis command order or values')
        self.guard_commands += sum(v['joint_guard_applied'] for v in commands)
        self.outward_beyond_bound += sum((q>=j['upper_limit_rad'] and u>0) or
            (q<=j['lower_limit_rad'] and u<0) for q,j,u in zip(prepared['qpos'][7:],self.joints,row['native_targets'],strict=True))
        decision = row['resolution'].get('response_search')
        if decision and decision['selection_reason']=='replanned':
            selected = next(v for v in decision['predictions'] if v['action_index']==decision['applied_action'])
            require(len(decision['predictions'])==9 and {v['action_index'] for v in decision['predictions']}==set(range(9))
                    and all(math.isfinite(v) for v in selected['velocity']+[selected['score']])
                    and selected['converged'] and selected['native_targets']==[f32(v) for v in row['native_targets']]
                    and len(selected['velocity'])==14, 'Joint diagnosis selected prediction binding')
            self.last_selection = dict(outer_step=row['outer_step'],predicted_native_step=5*row['outer_step']+1,
                action_index=decision['applied_action'],prepared_joint_positions_rad=prepared['qpos'][7:],
                predicted_joint_velocities_rad_s=selected['velocity'][6:],score=selected['score'],
                predicted_native_targets=selected['native_targets'])
        self.current = row
        self.history.append(dict(outer_step=row['outer_step'],prepared_joint_positions_rad=prepared['qpos'][7:],
            prepared_joint_velocities_rad_s=prepared['qvel'][6:],native_targets=row['native_targets'],
            joint_guards=[v['joint_guard_applied'] for v in commands],
            selection_reason=None if decision is None else decision['selection_reason'],
            action_index=None if decision is None else decision['applied_action']))
        self.controls += 1

    def native(self, row):
        from creature_trajectory_diagnosis import f32
        require(self.current is not None and row['cell']==self.cell and row['step']==self.samples+1
                and (row['step']-1)//5==self.current['outer_step'], 'Joint diagnosis native order')
        before = self.current['native_observation'] if self.samples%5==0 else self.previous_native
        require(row['before_qpos'][7:]==before['qpos'][7:] and row['before_qvel'][6:]==before['qvel'][6:]
                and row['ctrl']==[f32(v) for v in self.current['native_targets']]
                and len(row['qpos'])==15 and len(row['qvel'])==14 and len(row['actuator_force_nm'])==8
                and all(math.isfinite(v) for v in row['qpos']+row['qvel']+row['actuator_force_nm']),
                'Joint diagnosis native state or motor join')
        excess = [max(j['lower_limit_rad']-q,q-j['upper_limit_rad'],0.)
                  for j,q in zip(self.joints,row['qpos'][7:],strict=True)]
        for i, value in enumerate(excess):
            self.maximum_excess[i] = max(self.maximum_excess[i],value)
            self.joint_violations[i] += int(value>0)
            self.runs[i] = self.runs[i]+1 if value>0 else 0
            self.longest_runs[i] = max(self.longest_runs[i],self.runs[i])
        self.violations += int(any(excess))
        if self.last_selection and row['step']==self.last_selection['predicted_native_step']:
            errors = [abs(p-v) for p,v in zip(self.last_selection['predicted_joint_velocities_rad_s'],row['qvel'][6:],strict=True)]
            self.prediction_count += 1;self.prediction_error_sum += sum(errors)/8
            self.prediction_error_max = max(self.prediction_error_max,max(errors))
            self.last_selection.update(observed_next_joint_velocities_rad_s=row['qvel'][6:],
                maximum_one_step_joint_velocity_error_rad_s=max(errors))
        if any(excess) and self.first is None:
            prepared = self.current['native_observation']
            crossed = []
            for i, value in enumerate(excess):
                if not value:continue
                joint=self.joints[i];q=row['qpos'][7+i];v=row['qvel'][6+i]
                direction=1 if q>joint['upper_limit_rad'] else -1
                bound=joint['upper_limit_rad' if direction>0 else 'lower_limit_rad']
                distance=(bound-prepared['qpos'][7+i])*direction
                speed=prepared['qvel'][6+i]*direction;force=row['actuator_force_nm'][i]
                command=self.current['resolution']['ordered_commands'][i]
                crossed.append(dict(joint_index=i,joint_id=joint['joint_id'],bound_rad=bound,direction=direction,
                    prepared_position_rad=prepared['qpos'][7+i],prepared_velocity_rad_s=prepared['qvel'][6+i],
                    before_position_rad=row['before_qpos'][7+i],before_velocity_rad_s=row['before_qvel'][6+i],
                    position_rad=q,velocity_rad_s=v,excess_rad=value,prepared_distance_to_bound_rad=distance,
                    required_constant_deceleration_rad_s2=(max(speed,0.)**2/(2*distance) if distance>0 else None),
                    native_command_velocity_rad_s=row['ctrl'][i],command_points_outward=row['ctrl'][i]*direction>0,
                    velocity_points_outward=v*direction>0,joint_guard_applied=command['joint_guard_applied'],
                    actuator_force_nm=force,actuator_opposes_motion=force*v<0,force_at_cap=row['on_force_cap'][i]))
            contacts=row['contacts']
            self.first=dict(native_step=row['step'],outer_step=self.current['outer_step'],substep=(row['step']-1)%5,
                nominal_time_s=row['step']/600.,native_time_s=row['time_s'],joints=crossed,
                torso_contact=any(set(h['geom'])=={0,1} for h in contacts),
                distal_contact=any(0 in h['geom'] and any(g in self.distal for g in h['geom']) for h in contacts),
                contact_geoms=[h['geom'] for h in contacts],recent_controls=copy.deepcopy(list(self.history)),
                last_selection=copy.deepcopy(self.last_selection),
                selection_age_intervals=None if self.last_selection is None else self.current['outer_step']-self.last_selection['outer_step'])
        self.samples += 1
        self.previous_native = row

    def finish(self, expected):
        require(self.controls==self.outer_steps and self.samples==5*self.outer_steps
                and self.violations==expected['joint_limit_violation_steps'], 'Joint diagnosis population or retained count')
        return dict(binding=self.binding,controller_rows=self.controls,native_samples=self.samples,
            joint_limit_violation_samples=self.violations,maximum_excess_rad=max(self.maximum_excess),
            joint_violation_samples=self.joint_violations,joint_maximum_excess_rad=self.maximum_excess,
            joint_longest_violation_seconds=[v/600. for v in self.longest_runs],joint_guard_commands=self.guard_commands,
            outward_commands_at_or_beyond_bound=self.outward_beyond_bound,first_crossing=self.first,
            selected_one_step_predictions_compared=self.prediction_count,
            mean_selected_joint_velocity_error_rad_s=self.prediction_error_sum/self.prediction_count if self.prediction_count else None,
            maximum_selected_joint_velocity_error_rad_s=self.prediction_error_max)


def diagnose_limits(folder, receipt_sha256):
    from creature_body_moment_diagnosis import bound_archive
    archive, receipt = bound_archive(Path(folder),receipt_sha256)
    c=receipt['contract'];audit=receipt['audit']
    require(c['capture_mode']=='full' and 'response_search' in c and audit['ok']
            and audit['controller_rows_replayed']==len(c['cells'])*c['outer_steps']
            and audit['native_rows_verified']==len(c['cells'])*c['outer_steps']*5
            and audit['reader_world_build_count']==0, 'Joint diagnosis needs complete full response capture')
    outcomes=[None]*len(c['cells'])
    for group in receipt['worker']['groups']:
        prefix='native/'+group['batch_id'];indices=group['cell_indices']
        traces=[JointLimitTrace(archive.document(prefix+f'/cell_{local}/creature.json'),
            receipt['preflight']['bindings'][index],local,c['outer_steps']) for local,index in enumerate(indices)]
        controls=iter(archive.lines(prefix+'/controller.jsonl'));native=iter(archive.lines(prefix+'/trace.jsonl'))
        for outer in range(c['outer_steps']):
            for trace in traces:trace.control(json.loads(next(controls)))
            for _ in range(5):
                for trace in traces:trace.native(json.loads(next(native)))
        require(next(controls,None) is None and next(native,None) is None,'Joint diagnosis extra retained rows')
        for index,trace in zip(indices,traces,strict=True):
            outcomes[index]=dict(c['righting_metadata'][index],**trace.finish(audit['metrics'][index]))
        print(json.dumps(dict(batch=group['batch_id'],worlds_read=sum(v is not None for v in outcomes))),flush=True)
    require(all(v is not None for v in outcomes),'Joint diagnosis missing episode')
    return dict(schema_version='locolemotion_response_joint_limit_diagnosis_v1',
        ledger_scope=dict(subsystem='discovery',engine_scope='mujoco_warp',authority_mode='retained_motion_diagnostic',question_class='development'),
        ok=True,source_commit=receipt['source_commit'],source_receipt_sha256=receipt_sha256,
        input_files=list(archive.verified.values()),worlds_read=len(outcomes),
        controller_rows=sum(v['controller_rows'] for v in outcomes),native_samples=sum(v['native_samples'] for v in outcomes),
        outcomes=outcomes,world_build_count=0,solver_steps=0,eligibility_changed=False,full_controller_replay=False,
        causal_intervention=False,physical_acceptance_authority=False,training_data_authority=False,release_authority=False,
        scope='Retained prepared-command/native-sample joins, first crossings, excursions, duration and correctly timed selected one-step forecasts. Required constant deceleration is a descriptive kinematic calculation, not an actuator capability or a stopping guarantee.')


if __name__=='__main__':
    import argparse
    from contextlib import ExitStack
    from unittest.mock import patch
    import mujoco
    parser=argparse.ArgumentParser(description='Diagnose retained response-search joint limits without opening worlds.')
    parser.add_argument('--archive',type=Path,required=True)
    parser.add_argument('--receipt-sha256',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    require(not args.output.exists(),'Joint diagnosis output already exists')
    with ExitStack() as traps:
        for name in ('MjModel','MjData','mj_step','mj_step1','mj_step2','mj_forward'):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError('Physics in retained joint diagnosis')))
        result=diagnose_limits(args.archive,args.receipt_sha256)
    with args.output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(result,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps(dict(ok=True,worlds_read=result['worlds_read'],world_build_count=0,output=str(args.output))))
