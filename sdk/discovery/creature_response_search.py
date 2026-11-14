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


def policy(value):
    require(type(value) is dict and set(value)==set(DEFAULT) and value['schema_version']==SCHEMA,
        'Response search policy fields')
    require(value['selection'] in ('model','unchanged') and type(value['direction']) is int and
        value['direction'] in (-1,1) and type(value['replan_steps']) is int and value['replan_steps'] in (6,24) and
        type(value['maximum_rate_rad_s']) in (int,float) and value['maximum_rate_rad_s'] in (.75,2.),
        'Response search policy bounds')
    require(value['selection']!='unchanged' or value==dict(DEFAULT,selection='unchanged'),
        'Response unchanged comparator aliases')
    return copy.deepcopy(value)


def behavior_key(value):
    return tuple(policy(value)[k] for k in DEFAULT)


def source_document(pin):
    data=(ROOT/pin['path']).read_bytes()
    require(hashlib.sha256(data).hexdigest()==pin['sha256'],'Response search source binding')
    return json.loads(data)


def spec(*, route=False):
    original=source_document(POPULATION)['righting_spec']
    profiles=copy.deepcopy(original['profiles'][:2])
    profiles.append(dict(profiles[1],id='response_unchanged',response_search=dict(DEFAULT,selection='unchanged')))
    for direction,rate,cadence in itertools.product(RECIPE['directions'],RECIPE['maximum_rates_rad_s'],RECIPE['replan_steps']):
        name=f"roll{'pos' if direction==1 else 'neg'}_rate{round(rate*100):03d}_every{cadence:02d}"
        profiles.append(dict(profiles[1],id=name,response_search=dict(DEFAULT,direction=direction,
            maximum_rate_rad_s=rate,replan_steps=cadence)))
    bodies=RECIPE['route_body_indices'] if route else list(range(RECIPE['body_count']))
    if route:profiles=[profiles[i] for i in RECIPE['route_profile_indices']]
    assignments=[list(range(len(profiles))) if route else [0,1,2]+[3+i for i in range(8) if i!=b%8] for b in bodies]
    return dict(schema_version=righting.ASSIGNED_SCHEMA,
        descriptors=[copy.deepcopy(original['descriptors'][b]) for b in bodies],profiles=profiles,
        profiles_by_body=assignments,conditions=copy.deepcopy(original['conditions']),
        starts=copy.deepcopy(original['starts'])+([dict(id='upright',roll_rad=0.)] if route else []))


def validate(c):
    opted=any('response_search' in p for p in c.get('righting_spec',{}).get('profiles',[]))
    require(opted==('response_search' in c),'Response search declaration required')
    if not opted:return
    route=c['mode']=='route_ghost'
    require(c['mode'] in ('route_ghost','development_discovery') and c['response_search']==RECIPE and
        c['righting_spec']==spec(route=route) and c['predecessor']==PREDECESSOR and
        c['predictor_component']==probe.ACTUATOR_COMPONENT and c['seed']==RECIPE['seed'] and
        c['outer_steps']==RECIPE['route_outer_steps' if route else 'search_outer_steps'] and
        c['capture_mode']=='full' and c['maximum_worlds_per_batch']==4 and
        c['readback']==dict(mode='shared_snapshot',reference_check=False) and c.get('retain_planning_state') is True and
        c['trajectory_screen']==trajectory.POLICY and c['trajectory_reference_by_body']==[2]*len(c['righting_spec']['descriptors']) and
        not any(k in c for k in ('compact_capture','response_probe','post_native_path_screen','contact_reactions')),
        'Response search frozen population or scope')
    source_document(PREDECESSOR)
    component=source_document(probe.ACTUATOR_COMPONENT)
    for pin in component['source_pins']:source_document_bytes(pin)


def source_document_bytes(pin):
    require(hashlib.sha256((ROOT/pin['path']).read_bytes()).hexdigest()==pin['sha256'],
        'Response predictor source binding')


def source_dependencies(c):
    if 'response_search' not in c:return []
    component=source_document(probe.ACTUATOR_COMPONENT)
    return [ROOT/p['path'] for p in (POPULATION,PREDECESSOR,probe.ACTUATOR_COMPONENT,*component['source_pins'])]+[
        ROOT/'sdk/discovery/coupled_contact_response_plan_v2.json',
        ROOT/'sdk/discovery/creature_response_search.py',ROOT/'sdk/discovery/test_creature_response_search.py',
        ROOT/'sdk/discovery/creature_response_search_route_v1.json',ROOT/'sdk/discovery/creature_response_search_v1.json']


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
        actions=probe.candidates(self.creature,self.candidate,state,self.previous,base)
        actions[0]=dict(commands=copy.deepcopy(base['resolution']['ordered_commands']),targets=base['native_targets'][:])
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


def initial_metrics():
    return {'response_search_'+name:0 for name in ('rows','replans','holds','upright','unchanged','failures','nonzero_actions')}


def measure_control(metric,row):
    decision=row['resolution'].get('response_search')
    if decision is None:return
    require(decision['selection_reason'] in REASONS and type(decision['applied_action']) is int and
        0<=decision['applied_action']<9 and decision['model_ordering_qualified'] is False and
        decision['recovery_benefit_established'] is False,'Response search control accounting')
    metric['response_search_rows']+=1
    metric['response_search_'+REASONS[decision['selection_reason']]]+=1
    metric['response_search_nonzero_actions']+=int(decision['applied_action']!=0)


def validate_metrics(c,meta,metric):
    require(all(type(metric[k]) is int and 0<=metric[k]<=c['outer_steps'] for k in initial_metrics()),
        'Response search finite control counts')
    active='response_search' in c['righting_spec']['profiles'][meta['candidate_index']]
    require(metric['response_search_rows']==(c['outer_steps'] if active else 0) and
        sum(metric['response_search_'+k] for k in REASONS.values())==metric['response_search_rows'] and
        metric['response_search_nonzero_actions']<=metric['response_search_rows'], 'Response search control denominator')


def verify_route(folder,receipt):
    c=receipt['contract'];audit=receipt['audit']
    require(c['mode']=='route_ghost' and audit['ok'] and not audit['synthetic'] and
        audit['controller_rows_replayed']==610 and audit['native_rows_verified']==3050,'Response search route replay')
    rows=[]
    for meta,metric in zip(c['righting_metadata'],audit['metrics'],strict=True):
        validate_metrics(c,meta,metric)
        p=c['righting_spec']['profiles'][meta['candidate_index']].get('response_search')
        if p is None:continue
        require(metric['response_search_failures']==0,'Response search route model withdrawal')
        if meta['start_id']=='upright':require(metric['response_search_upright']>0,'Response search stance withdrawal missing')
        elif p['selection']=='unchanged':require(metric['response_search_unchanged']==61,'Response search unchanged route missing')
        else:require(metric['response_search_replans']>=3 and metric['response_search_holds']>0 and
            metric['response_search_nonzero_actions']>0,'Response search recurring native action coverage')
        rows.append(dict(cell_id=meta['cell_id'],**{k:metric[k] for k in initial_metrics()}))
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
    require(c['mode']=='development_discovery' and receipt['contract']==declaration(ROOT/'sdk/discovery/creature_response_search_route_v1.json') and
        receipt['source_commit']==source_commit and receipt['source_status']==[] and receipt['bindings']==bindings and
        receipt['ok'] is True and receipt['synthetic'] is False and receipt['physical_started'] is True and
        receipt['source_runtime_unchanged'] is True and receipt['zero_world_gate_passed'] is True and
        receipt['safety_controls']=={n:k for n,_,k in gates(c)},'Response completed same-freeze route required')
    archive=Archive(path.parent,receipt)
    for name in archive.inventory:
        for _ in archive.lines(name):pass
    require(archive.document('independent-audit.json')==receipt['audit'] and
        receipt['audit']['reader_world_build_count']==0 and receipt['audit']['gpu_worlds']==10,
        'Response route audit binding')
    for name in [n+'-gate/cleanup.json' for n in receipt['safety_controls']]+['runtime-gate/cleanup.json','native/cleanup.json','reader/cleanup.json']:
        validate_cleanup(archive.document(name))
    coverage=verify_route(path.parent,receipt)
    require(receipt.get('response_search_route_coverage')==coverage,'Response route coverage differs')
    return dict(archive_relative_path=path.parent.relative_to(evidence_root).as_posix(),
        receipt_sha256=hashlib.sha256(raw).hexdigest(),source_commit=source_commit,
        artifacts_verified=len(archive.verified),route_worlds=10,coverage_complete=True,recovery_benefit_established=False)
