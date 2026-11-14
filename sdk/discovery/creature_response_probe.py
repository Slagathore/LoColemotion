"""Fresh-action response comparisons through the shared creature native route.

Each probe world follows the same timed prefix, then applies one declared
bounded action. Predictions see prepared contacts only. Selection is assigned
prospectively so every alternative receives its own fresh native observation.
"""
import copy
import hashlib
import json
import math
from pathlib import Path

import numpy as np

import creature_righting as righting
from creature_batch import bridge, require
from coupled_contact_response import CoupledBody, response, velocity_actuation
from actuation_recovery_mechanics import xyz
from evaluate_coupled_contact_response import settings, actuator_parameters

ROOT = Path(__file__).resolve().parents[2]
SOURCE = dict(path='sdk/discovery/creature_torque_map_route_v3.json',
              sha256='55a97076f80a5b5a9ab31bb23198729ff9224d5d3674542d7ee78dd68f8c0d18')
SCHEMA = 'locolemotion_coupled_response_probe_v1'
STEPS = (0, 60, 120)
PATTERNS = [[0.]*8]
for pattern in ([1.,0.]*4, [0.,1.]*4, [1.,1.,0.,0.,1.,1.,0.,0.], [1.,1.,-1.,-1.,-1.,-1.,1.,1.]):
    PATTERNS.extend([pattern, [-v for v in pattern]])
RECIPE = dict(schema_version=SCHEMA, source=SOURCE, seed=1061142, probe_steps=list(STEPS),
    patterns=PATTERNS, offset_in_slew_units=2., axis_body=[1.,0.,0.], native_substep=1,
    minimum_distinguishable_pairs_per_body=10, measured_tie_tolerance_rad_s=1e-4,
    minimum_ordering_accuracy_per_body=.7, maximum_selected_regret_rad_s=.01,
    all_bodies_required=True, recovery_authority=False)
NUMERICAL_SCHEMA = 'locolemotion_coupled_response_probe_v2'
MATCH_BOUNDS = dict(position_m=1e-6, quaternion_component=1e-6, joint_angle_rad=1e-6,
    linear_velocity_m_s=1e-5, angular_velocity_rad_s=1e-5, joint_velocity_rad_s=1e-5,
    command_rad_s=1e-5, contact_position_m=1e-6, contact_gap_m=1e-6,
    contact_frame_component=1e-5, axis_component=1e-6, prediction_score_rad_s=1e-5)
NUMERICAL_RECIPE = dict(RECIPE, schema_version=NUMERICAL_SCHEMA, seed=1061143,
    repeats_per_action=2, matching_bounds=MATCH_BOUNDS, maximum_repeat_spread_rad_s=1e-5,
    action_comparison='disjoint_measured_intervals_with_fixed_tie_margin',
    prediction_comparison='disjoint_prediction_intervals',
    score_axis='primary_action_zero_repeat_zero_prepared_axis',
    selection='primary_action_zero_repeat_zero_prediction',
    regret='maximum_observed_score_minus_minimum_selected_score')
ACTUATOR_SCHEMA = 'locolemotion_coupled_response_probe_v3'
ACTUATOR_COMPONENT = dict(path='sdk/discovery/coupled_contact_response_result_v2.json',
    sha256='ad6ee45268ba59a3604474d3f60074f5b29245120d822ed5c9b3b2c102b9c15d')
ACTUATOR_RECIPE = dict(NUMERICAL_RECIPE, schema_version=ACTUATOR_SCHEMA, seed=1061144,
    predictor='inelastic_coupled_friction_pyramid_actuator_v2',native_actuator_dynamics_binding=True)


def actuator_aware(c):
    return c.get('response_probe',{}).get('schema_version')==ACTUATOR_SCHEMA


def numerical(c):
    return c.get('response_probe',{}).get('schema_version') in (NUMERICAL_SCHEMA,ACTUATOR_SCHEMA)


def policy(value):
    require(type(value) is dict, 'Response probe policy')
    repeated=value.get('schema_version') in (NUMERICAL_SCHEMA,ACTUATOR_SCHEMA)
    require(set(value)=={'schema_version','probe_step','action_index'} | ({'repeat_index'} if repeated else set()) and
        value['schema_version'] in (SCHEMA,NUMERICAL_SCHEMA,ACTUATOR_SCHEMA) and type(value['probe_step']) is int and value['probe_step'] in STEPS and
        type(value['action_index']) is int and 0<=value['action_index']<len(PATTERNS), 'Response probe policy')
    if repeated:require(type(value['repeat_index']) is int and 0<=value['repeat_index']<2, 'Response repeat identity')
    return copy.deepcopy(value)


def state_digest(state):
    return hashlib.sha256(json.dumps(state,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()


def packet(creature,binding,state,native):
    require(native['sampling_stage']=='prepared_before_control', 'Response contact sampling stage')
    require(type(native['time_s']) in (int,float) and math.isfinite(native['time_s']) and native['time_s']>=0., 'Response native clock')
    joints=state['ordered_joint_observations']
    require([j['position_rad'] for j in joints]==native['qpos'][7:] and
            [j['velocity_rad_s'] for j in joints]==native['qvel'][6:], 'Response contact state join')
    friction=settings(creature)['friction'];contacts=[];worlds=set()
    for hit in native['contacts']:
        require(len(hit['geom'])==2 and hit['geom'].count(0)==1, 'Response ground contact identity')
        index=hit['geom'][1] if hit['geom'][0]==0 else hit['geom'][0]
        require(type(index) is int and 0<index<len(creature['spec']['geom_names']), 'Response contact body index')
        name=creature['spec']['geom_names'][index];require(name.endswith('_geom'), 'Response contact geometry name')
        normal=np.asarray(hit['frame'][:3])*(1 if hit['geom'][0]==0 else -1)
        contacts.append(dict(body_id=name[:-5],point=bridge._mujoco_to_canonical(hit['position_m']).tolist(),
            normal=bridge._mujoco_to_canonical(normal).tolist(),gap=hit['distance_m'],friction=friction))
        worlds.add(hit['world'])
    require(len(worlds)<=1 and len(contacts)<=64, 'Response crossed contact worlds or capacity')
    return dict(schema_version=SCHEMA,binding=copy.deepcopy(binding),state_sha256=state_digest(state),
                native_time_s=native['time_s'],contacts=contacts)


def observe(controller,observation,native):
    if 'response_probe' not in controller.candidate:return observation
    return dict(observation,whole_body_contacts=packet(controller.creature,controller.binding,observation['state'],native))


def candidates(creature,candidate,state,previous,base):
    result=[];joints=creature['compiled']['morphology']['morphology_spec']['joints']
    motors=creature['compiled']['morphology']['morphology_spec']['actuators']
    slew=candidate['maximum_slew_rad_s_per_step']
    for pattern in PATTERNS:
        commands=[];targets=[]
        for i,(joint,motor,observed) in enumerate(zip(joints,motors,state['ordered_joint_observations'],strict=True)):
            speed=min(motor['maximum_target_speed_rad_s'],candidate['maximum_speed_rad_s'])
            proposed=base['native_targets'][i]+2*slew*pattern[i]
            bounded=max(-speed,min(speed,proposed));slewed=max(previous[i]-slew,min(previous[i]+slew,bounded))
            lo,hi,actual=joint['lower_limit_rad'],joint['upper_limit_rad'],observed['position_rad']
            final=max(min(0.,(lo-actual)/bridge.CONTROLLER_DT_S),min(max(0.,(hi-actual)/bridge.CONTROLLER_DT_S),slewed))
            command=copy.deepcopy(base['resolution']['ordered_commands'][i])
            command.update(proposed_velocity_rad_s=proposed,canonical_velocity_rad_s=final,
                speed_limited=bounded!=proposed,slew_limited=slewed!=bounded,joint_guard_applied=final!=slewed)
            commands.append(command);targets.append(final)
        result.append(dict(commands=commands,targets=targets))
    require(result[0]['targets']==base['native_targets'], 'Response unchanged action zero')
    return result


class ProbeController(righting.RightingController):
    supports_response_probe=True
    def __init__(self,core,declaration,*,seed):
        super().__init__(core,declaration,seed=seed)
        self.response_model=CoupledBody(self.spec) if 'response_probe' in self.candidate else None
        self.actuator_parameters=actuator_parameters(self.creature) if actuator_aware(self.candidate) else None

    def plan(self,observation):
        if self.response_model is None:return super().plan(observation)
        require('whole_body_contacts' in observation, 'Response missing whole-body contacts')
        supplied=observation['whole_body_contacts'];state=observation['state']
        require(set(supplied)=={'schema_version','binding','state_sha256','native_time_s','contacts'} and
            supplied['schema_version']==SCHEMA and supplied['binding']==self.binding and
            supplied['state_sha256']==state_digest(state), 'Response stale or crossed contact packet')
        base=super().plan({k:v for k,v in observation.items() if k!='whole_body_contacts'})
        base['request']['whole_body_contacts']=copy.deepcopy(supplied)
        p=self.candidate['response_probe']
        if self.step_index!=p['probe_step']:return base
        model=self.response_model;pose=state['base_pose_world'];twist=state['base_twist_world'];joints=state['ordered_joint_observations']
        qd=np.asarray([j['velocity_rad_s'] for j in joints]);velocity=np.r_[xyz(twist['linear_velocity_m_s']),xyz(twist['angular_velocity_rad_s']),qd]
        prepared=model.prepare(xyz(pose['position_m']),[pose['orientation_xyzw'][k] for k in 'xyzw'],
            [j['position_rad'] for j in joints],velocity)
        axis=prepared['frame']['rotations'][0] @ np.asarray(RECIPE['axis_body'])
        config=settings(self.creature);gains=np.asarray(self.creature['spec']['velocity_gains']);bounds=np.asarray(self.creature['spec']['force_ranges'])
        damping=np.asarray([j['passive_damping_nms_per_rad'] for j in model.tree.joints])
        actions=candidates(self.creature,self.candidate,state,self.previous,base);predictions=[]
        for index,action in enumerate(actions):
            # The native transport uses binary32 targets; predict the same values.
            targets=np.asarray(action['targets'],np.float32).astype(float)
            motor=np.clip(gains*(targets-qd),bounds[:,0],bounds[:,1])
            force=np.r_[np.zeros(6),motor-damping*qd];extra={}
            if self.actuator_parameters is not None:
                a=self.actuator_parameters;actuation=velocity_actuation(qd,targets,a['gains'],a['force_ranges'],a['damping'])
                force=actuation['applied'];extra=dict(joint_armature=a['armature'],joint_velocity_derivative=actuation['velocity_derivative'])
            answer=response(model,prepared,force,supplied['contacts'],config['dt'],
                            penetration_recovery_time=config['penetration_recovery_time'],**extra)
            require(answer['solver']['converged'], 'Response candidate solver did not converge')
            predictions.append(dict(action_index=index,native_targets=targets.tolist(),velocity=answer['velocity'].tolist(),
                score_rad_s=float(axis @ answer['velocity'][3:6]),kkt_residual=answer['solver']['kkt_residual'],converged=True))
        chosen=actions[p['action_index']]
        base['native_targets']=chosen['targets'];base['resolution']['ordered_commands']=chosen['commands']
        base['resolution']['response_probe']=dict(policy=copy.deepcopy(p),axis_world=axis.tolist(),predictions=predictions,
            predicted_best_action=max(range(len(predictions)),key=lambda i:(predictions[i]['score_rad_s'],-i)),
            applied_action=p['action_index'],selection='prospectively_assigned',counterfactual_ranking_validated=False,
            recovery_benefit_established=False)
        return base


class ProbeBatch(righting.RightingBatch):
    Controller=ProbeController


def spec(*, repeated=False, actuator_aware=False):
    require(not actuator_aware or repeated,'Response actuator probe requires repeats')
    data=(ROOT/SOURCE['path']).read_bytes();require(hashlib.sha256(data).hexdigest()==SOURCE['sha256'], 'Response exposed source')
    original=json.loads(data)['righting_spec'];profiles=[copy.deepcopy(original['profiles'][0])]
    for step in STEPS:
        for index in range(len(PATTERNS)):
            for repeat in range(2 if repeated else 1):
                p=copy.deepcopy(original['profiles'][1]);p.update(id=f'response_t{step}_a{index}'+(f'_r{repeat}' if repeated else ''),
                    response_probe=dict(schema_version=ACTUATOR_SCHEMA if actuator_aware else NUMERICAL_SCHEMA if repeated else SCHEMA,
                        probe_step=step,action_index=index))
                if repeated:p['response_probe']['repeat_index']=repeat
                profiles.append(p)
    return dict(schema_version=righting.SCHEMA,descriptors=copy.deepcopy(original['descriptors']),profiles=profiles,
                conditions=copy.deepcopy(original['conditions']),starts=copy.deepcopy(original['starts']))


def validate(c):
    opted=any('response_probe' in p for p in c.get('righting_spec',{}).get('profiles',[]))
    require(opted==('response_probe' in c), 'Response probe declaration required')
    if not opted:return
    repeated=numerical(c);aware=actuator_aware(c);recipe=ACTUATOR_RECIPE if aware else NUMERICAL_RECIPE if repeated else RECIPE
    require(c['response_probe']==recipe and c['righting_spec']==spec(repeated=repeated,actuator_aware=aware) and c['mode']=='development_discovery' and
        c['capture_mode']=='full' and c['outer_steps']==max(STEPS)+1 and c['seed']==recipe['seed'] and
        c['maximum_worlds_per_batch']==(55 if repeated else 28) and c['readback']==dict(mode='shared_snapshot',reference_check=False) and
        not any(k in c for k in ('compact_capture','trajectory_screen','post_native_path_screen','contact_reactions')),
        'Response fixed native comparison population or scope')
    if aware:
        require(c.get('predictor_component')==ACTUATOR_COMPONENT,'Response actuator component identity')
        raw=(ROOT/ACTUATOR_COMPONENT['path']).read_bytes()
        require(hashlib.sha256(raw).hexdigest()==ACTUATOR_COMPONENT['sha256'],'Response actuator component digest')
        for pin in json.loads(raw)['source_pins']:
            require(hashlib.sha256((ROOT/pin['path']).read_bytes()).hexdigest()==pin['sha256'],'Response actuator component source')


def source_dependencies(c):
    if 'response_probe' not in c:return []
    version='v2' if actuator_aware(c) else 'v1'
    plan=ROOT/f'sdk/discovery/coupled_contact_response_plan_{version}.json'
    result=ROOT/f'sdk/discovery/coupled_contact_response_result_{version}.json'
    return [ROOT/SOURCE['path'],result,plan,*[ROOT/p['path'] for p in json.loads(result.read_bytes())['source_pins']],
        *([ROOT/'sdk/discovery/creature_response_probe_native_failure_v1.json'] if numerical(c) else []),
        *([ROOT/'sdk/discovery/creature_response_probe_native_result_v2.json',ROOT/'sdk/discovery/test_creature_response_actuator.py'] if actuator_aware(c) else [])]


class MatchedGroup:
    """Require common prepared states and all independently assigned actions."""
    def __init__(self,body,step):
        self.body,self.step=body,step;self.prefix={};self.visits=set();self.predictions=None;self.axis=None;self.actual={}

    def control(self,row,action):
        outer=row['outer_step']
        if outer>self.step:return
        require((outer,action) not in self.visits, 'Response duplicate prefix row');self.visits.add((outer,action))
        n=row['native_observation']
        state=dict(qpos=n['qpos'],qvel=n['qvel'],contacts=[{k:h[k] for k in ('geom','distance_m','position_m','frame')} for h in n['contacts']])
        digest=state_digest(state)
        require(self.prefix.setdefault(outer,digest)==digest, 'Response matched prefix differs')
        if outer!=self.step:return
        p=row['resolution']['response_probe']
        require(p['policy']==dict(schema_version=SCHEMA,probe_step=self.step,action_index=action) and
            p['applied_action']==action and p['selection']=='prospectively_assigned', 'Response assigned action differs')
        if self.predictions is None:self.predictions=p['predictions'];self.axis=p['axis_world']
        require(p['predictions']==self.predictions and p['axis_world']==self.axis and
            [v['action_index'] for v in p['predictions']]==list(range(9)), 'Response alternative predictions differ')
        require(np.asarray(row['native_targets'],np.float32).astype(float).tolist()==p['predictions'][action]['native_targets'], 'Response applied prediction differs')

    def native(self,row,action):
        if row['step']!=self.step*5+1:return
        from check_coupled_contact_response import native_velocity
        require(self.axis is not None and action not in self.actual, 'Response missing prediction or duplicate native action')
        self.actual[action]=math.fsum(a*v for a,v in zip(self.axis,native_velocity(row)[3:6],strict=True))

    def finish(self):
        require(self.visits=={(step,action) for step in range(self.step+1) for action in range(9)} and
            set(self.actual)==set(range(9)) and self.predictions is not None, 'Response incomplete matched alternatives')
        return dict(body_id=self.body,probe_step=self.step,prefix_rows_verified=len(self.visits),
            predicted_scores_rad_s=[v['score_rad_s'] for v in self.predictions],
            measured_scores_rad_s=[self.actual[i] for i in range(9)],
            native_targets=[v['native_targets'] for v in self.predictions])


def summarize(groups, *, repeated=False):
    require(len(groups)==9 and len({(g['body_id'],g['probe_step']) for g in groups})==9 and
        len({g['body_id'] for g in groups})==3 and all({g['probe_step'] for g in groups if g['body_id']==b}==set(STEPS)
        for b in {g['body_id'] for g in groups}), 'Response comparison group population')
    bodies={};outcomes=[]
    for g in groups:
        predicted,actual=g['predicted_scores_rad_s'],g['measured_scores_rad_s']
        require(len(predicted)==len(actual)==9 and all(math.isfinite(v) for v in predicted+actual), 'Response finite action scores')
        best=max(range(9),key=lambda i:(predicted[i],-i));regret=max(actual)-actual[best]
        pairs=[(i,j) for i in range(9) for j in range(i) if abs(actual[i]-actual[j])>RECIPE['measured_tie_tolerance_rad_s']]
        correct=sum((predicted[i]-predicted[j])*(actual[i]-actual[j])>0 for i,j in pairs)
        gain=actual[best]-actual[0]
        if repeated:
            pi,ai=g['prediction_intervals_rad_s'],g['measured_intervals_rad_s']
            for intervals,values,limit in ((pi,predicted,MATCH_BOUNDS['prediction_score_rad_s']),
                    (ai,actual,NUMERICAL_RECIPE['maximum_repeat_spread_rad_s'])):
                require(len(intervals)==9 and all(len(v)==2 and all(math.isfinite(x) for x in v) and
                    v[0]<=score<=v[1] and 0<=v[1]-v[0]<=limit for v,score in zip(intervals,values,strict=True)),
                    'Response numerical score interval or dispersion')
            margin=RECIPE['measured_tie_tolerance_rad_s']
            pairs=[(i,j) for i in range(9) for j in range(i) if ai[i][0]-ai[j][1]>margin or ai[j][0]-ai[i][1]>margin]
            correct=sum((ai[i][0]>ai[j][1] and pi[i][0]>pi[j][1]) or
                        (ai[j][0]>ai[i][1] and pi[j][0]>pi[i][1]) for i,j in pairs)
            regret=max(v[1] for v in ai)-ai[best][0];gain=ai[best][0]-ai[0][1]
        b=bodies.setdefault(g['body_id'],dict(distinguishable_pairs=0,correct_pairs=0,maximum_selected_regret_rad_s=0.))
        b['distinguishable_pairs']+=len(pairs);b['correct_pairs']+=correct;b['maximum_selected_regret_rad_s']=max(b['maximum_selected_regret_rad_s'],regret)
        outcomes.append(dict(g,predicted_best_action=best,measured_best_action=max(range(9),key=lambda i:(actual[i],-i)),
            selected_regret_rad_s=regret,selected_gain_against_unchanged_rad_s=gain))
    for b in bodies.values():
        b['ordering_accuracy']=b['correct_pairs']/b['distinguishable_pairs'] if b['distinguishable_pairs'] else None
        b['passed']=(b['distinguishable_pairs']>=RECIPE['minimum_distinguishable_pairs_per_body'] and
            b['ordering_accuracy']>=RECIPE['minimum_ordering_accuracy_per_body'] and b['maximum_selected_regret_rad_s']<=RECIPE['maximum_selected_regret_rad_s'])
    return dict(comparison_completed=True,groups=outcomes,bodies=bodies,ordering_screen_passed=all(b['passed'] for b in bodies.values()),
        observed_action_worlds=162 if repeated else 81,plain_comparator_worlds=3,recovery_benefit_established=False,controller_adopted=False,
        training_data_authority=False,physical_acceptance_authority=False,release_authority=False)


def vector_gap(a,b):
    require(len(a)==len(b) and len(a)>0 and all(type(v) in (int,float) and math.isfinite(v) for v in [*a,*b]),
            'Response finite numerical vector')
    return max(abs(x-y) for x,y in zip(a,b,strict=True))


def contact_pairs(a,b):
    """Match a contact multiset without relying on GPU contact enumeration."""
    require(len(a)==len(b)<=64, 'Response numerical contact count')
    fields=(('position_m','contact_position_m',3),('frame','contact_frame_component',9),('distance_m','contact_gap_m',1))
    def values(h,key):return [h[key]] if key=='distance_m' else h[key]
    for h in a+b:
        require(type(h['geom']) is list and len(h['geom'])==2 and h['geom'].count(0)==1 and
                all(type(i) is int and 0<=i<=9 for i in h['geom']), 'Response numerical contact identity')
        for key,_,size in fields:
            v=values(h,key);require(len(v)==size, 'Response numerical contact shape');vector_gap(v,v)
    edges=[[j for j,y in enumerate(b) if x['geom']==y['geom'] and
            all(vector_gap(values(x,key),values(y,key))<=MATCH_BOUNDS[bound] for key,bound,_ in fields)] for x in a]
    assigned={}
    def match(i,seen):
        for j in edges[i]:
            if j in seen:continue
            seen.add(j)
            if j not in assigned or match(assigned[j],seen):assigned[j]=i;return True
        return False
    require(all(match(i,set()) for i in range(len(a))), 'Response numerical contact geometry')
    return [(a[i],b[j]) for j,i in sorted(assigned.items())]


class NumericalMatchedGroup:
    """Bound prefix differences and measure every action twice, without reset."""
    def __init__(self,body,step,*,schema=NUMERICAL_SCHEMA):
        require(schema in (NUMERICAL_SCHEMA,ACTUATOR_SCHEMA),'Response numerical comparison schema')
        self.schema=schema
        self.body,self.step=body,step;self.prefix={};self.visits=set();self.predictions={};self.axes={};self.actual={};self.maximums={};self.model=None

    def check(self,a,b,field):
        gap=vector_gap(a,b);require(gap<=MATCH_BOUNDS[field], 'Response numerical '+field)
        self.maximums[field]=max(self.maximums.get(field,0.),gap)

    def control(self,row,trial):
        outer=row['outer_step']
        if outer>self.step:return
        require(type(trial) is tuple and len(trial)==2 and all(type(v) is int for v in trial) and
                0<=trial[0]<9 and 0<=trial[1]<2 and type(outer) is int and 0<=outer<=self.step,
                'Response numerical trial identity')
        require((outer,trial) not in self.visits, 'Response duplicate numerical prefix');self.visits.add((outer,trial))
        n=row['native_observation'];model=tuple(row['binding'][k] for k in ('descriptor_sha256','model_xml_sha256','body_shape_sha256'))
        if self.model is None:self.model=model
        require(model==self.model, 'Response numerical model identity')
        if outer not in self.prefix:
            require(trial==(0,0), 'Response primary prefix must arrive first');self.prefix[outer]=copy.deepcopy(row)
        ref=self.prefix[outer];rn=ref['native_observation']
        require(len(n['qpos'])==15 and len(n['qvel'])==14 and type(n['time_s']) in (int,float) and
                math.isfinite(n['time_s']) and n['time_s']==rn['time_s'], 'Response numerical native state or clock')
        for key,start,end,field in (('qpos',0,3,'position_m'),('qpos',3,7,'quaternion_component'),('qpos',7,15,'joint_angle_rad'),
                ('qvel',0,3,'linear_velocity_m_s'),('qvel',3,6,'angular_velocity_rad_s'),('qvel',6,14,'joint_velocity_rad_s')):
            self.check(n[key][start:end],rn[key][start:end],field)
        for a,b in contact_pairs(n['contacts'],rn['contacts']):
            for key,field in (('position_m','contact_position_m'),('frame','contact_frame_component')):self.check(a[key],b[key],field)
            self.check([a['distance_m']],[b['distance_m']],'contact_gap_m')
        if outer<self.step:self.check(row['native_targets'],ref['native_targets'],'command_rad_s');return
        p=row['resolution']['response_probe'];action,repeat=trial
        require(p['policy']==dict(schema_version=self.schema,probe_step=self.step,action_index=action,repeat_index=repeat) and
                p['applied_action']==action and p['selection']=='prospectively_assigned', 'Response numerical action assignment')
        require(len(p['axis_world'])==3 and abs(sum(v*v for v in p['axis_world'])-1.)<=1e-12 and
                [v['action_index'] for v in p['predictions']]==list(range(9)), 'Response numerical predictions')
        for prediction in p['predictions']:
            require(prediction['converged'] is True and len(prediction['velocity'])==14 and len(prediction['native_targets'])==8,
                    'Response numerical prediction shape or convergence')
            vector_gap(prediction['velocity'],prediction['velocity']);vector_gap(prediction['native_targets'],prediction['native_targets'])
            require(abs(prediction['score_rad_s']-math.fsum(a*v for a,v in zip(p['axis_world'],prediction['velocity'][3:6],strict=True)))<=1e-12,
                    'Response numerical score projection')
        require(np.asarray(row['native_targets'],np.float32).astype(float).tolist()==p['predictions'][action]['native_targets'],
                'Response numerical applied prediction differs')
        self.predictions[trial]=p['predictions'];self.axes[trial]=p['axis_world']

    def native(self,row,trial):
        if row['step']!=self.step*5+1:return
        from check_coupled_contact_response import native_velocity
        require(trial in self.predictions and trial not in self.actual and (0,0) in self.axes, 'Response numerical missing or duplicate action')
        self.actual[trial]=math.fsum(a*v for a,v in zip(self.axes[0,0],native_velocity(row)[3:6],strict=True))

    def finish(self):
        trials={(a,r) for a in range(9) for r in range(2)}
        require(self.visits=={(s,t) for s in range(self.step+1) for t in trials} and set(self.predictions)==set(self.actual)==trials,
                'Response incomplete numerical alternatives')
        primary=self.predictions[0,0];axis=self.axes[0,0];scores=[]
        for trial,predictions in sorted(self.predictions.items()):
            self.check(self.axes[trial],axis,'axis_component');values=[]
            for p,ref in zip(predictions,primary,strict=True):
                self.check(p['native_targets'],ref['native_targets'],'command_rad_s')
                values.append(p['score_rad_s'] if trial==(0,0) else math.fsum(a*v for a,v in zip(axis,p['velocity'][3:6],strict=True)))
            self.check(values,[p['score_rad_s'] for p in primary],'prediction_score_rad_s');scores.append(values)
        actual=[[self.actual[a,r] for r in range(2)] for a in range(9)]
        pi=[[min(v[i] for v in scores),max(v[i] for v in scores)] for i in range(9)]
        ai=[[min(v),max(v)] for v in actual]
        require(all(hi-lo<=MATCH_BOUNDS['prediction_score_rad_s'] for lo,hi in pi), 'Response prediction dispersion')
        require(all(hi-lo<=NUMERICAL_RECIPE['maximum_repeat_spread_rad_s'] for lo,hi in ai), 'Response repeated action dispersion')
        return dict(body_id=self.body,probe_step=self.step,prefix_rows_verified=len(self.visits),matching_maximums=self.maximums,
            predicted_scores_rad_s=scores[0],measured_scores_rad_s=[math.fsum(v)/2 for v in actual],
            prediction_intervals_rad_s=pi,measured_intervals_rad_s=ai,measured_repeats_rad_s=actual,
            native_targets=[v['native_targets'] for v in primary],common_axis_world=axis,
            repeats_per_action=2,maximum_repeat_spread_rad_s=max(hi-lo for lo,hi in ai))


def assess(folder,receipt):
    c=receipt['contract'];validate(c)
    repeated=numerical(c);worlds=165 if repeated else 84
    require(receipt['audit']['ok'] and receipt['audit']['controller_rows_replayed']==worlds*121 and
        receipt['audit']['native_rows_verified']==worlds*121*5, 'Response full shared replay required')
    groups={}
    for batch in receipt['worker']['groups']:
        cells=[c['cells'][i] for i in batch['cell_indices']];local={}
        for i,cell in enumerate(cells):
            if 'response_probe' not in cell['profile']:continue
            p=cell['profile']['response_probe'];key=cell['descriptor']['morphology_id'],p['probe_step']
            group=NumericalMatchedGroup(*key,schema=c['response_probe']['schema_version']) if repeated else MatchedGroup(*key)
            local[i]=(groups.setdefault(key,group),(p['action_index'],p['repeat_index']) if repeated else p['action_index'])
        for name,method in (('controller','control'),('trace','native')):
            path=Path(folder)/'native'/batch['batch_id']/(name+'.jsonl');digest=hashlib.sha256()
            with path.open('rb') as stream:
                for line in stream:
                    digest.update(line);row=json.loads(line)
                    if row['cell'] in local:
                        group,action=local[row['cell']];getattr(group,method)(row,action)
            require(digest.hexdigest()==batch['result']['stream_sha256'][name], 'Response stream binding')
    return summarize([group.finish() for _,group in sorted(groups.items())],repeated=repeated)
