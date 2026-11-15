"""Measured-motion reserves and feasible action selection for development search.

The coupled braking estimate and constant-velocity projection are heuristics.
They neither reproduce the native contact solver nor guarantee stopping.
"""
import copy
import math
import numpy as np

from creature_batch import bridge, require
from creature_joint_braking import envelope
import creature_restoring_search as restoring
from actuation_recovery_mechanics import xyz
from coupled_contact_response import response, velocity_actuation

MARGIN_RAD = .04
FIXED_DECELERATION = 20.
BRAKING_FRACTION = .25
MAXIMUM_DECELERATION = 200.
LOW_SPEED_RAD_S = .05


def decelerations(velocity, brake_velocity, dt, method):
    require(method in ('fixed','coupled') and 0<dt<=.01
        and len(velocity)==len(brake_velocity)==8
        and all(math.isfinite(v) for v in [*velocity,*brake_velocity]), 'Constraint braking inputs')
    estimates=[];unsupported=[]
    for v,braked in zip(velocity,brake_velocity,strict=True):
        v,braked=float(v),float(braked)
        measured=(abs(v)-math.copysign(1.,v)*braked)/dt
        inactive=abs(v)<LOW_SPEED_RAD_S or method=='fixed'
        unsupported.append(not inactive and measured<=0.)
        estimates.append(FIXED_DECELERATION if inactive else max(1.,min(MAXIMUM_DECELERATION,BRAKING_FRACTION*measured)))
    return dict(acceleration_rad_s2=estimates,unsupported_braking=unsupported)


def feasibility(joints, positions, velocity, predicted, acceleration, mode, dt):
    require(mode in ('interval','stopping') and 0<dt<=bridge.CONTROLLER_DT_S
        and len(joints)==len(positions)==len(velocity)==len(predicted)==len(acceleration)==8
        and all(math.isfinite(v) for v in [*positions,*velocity,*predicted,*acceleration])
        and all(1.<=a<=MAXIMUM_DECELERATION for a in acceleration), 'Constraint feasibility inputs')
    clearance=[]
    for j,q,v,next_v,a in zip(joints,positions,velocity,predicted,acceleration,strict=True):
        next_q=q+dt*next_v
        upper_speed=max(0.,v,next_v);lower_speed=max(0.,-v,-next_v)
        upper=next_q+upper_speed*(bridge.CONTROLLER_DT_S-dt)
        lower=next_q-lower_speed*(bridge.CONTROLLER_DT_S-dt)
        if mode=='stopping':
            upper+=upper_speed**2/(2*a);lower-=lower_speed**2/(2*a)
        clearance.append(min(q-j['lower_limit_rad'],j['upper_limit_rad']-q,
            lower-j['lower_limit_rad']-MARGIN_RAD,j['upper_limit_rad']-upper-MARGIN_RAD))
    minimum=float(min(clearance))
    return dict(feasible=minimum>=0.,minimum_projected_clearance_rad=minimum)


def protect(actions, controller, state, acceleration):
    joints=controller.spec['joints'];observed=state['ordered_joint_observations']
    protected=copy.deepcopy(actions)
    for action in protected:
        for i,(joint,o,command,a) in enumerate(zip(joints,observed,action['commands'],acceleration,strict=True)):
            shaped=envelope(o['position_rad'],o['velocity_rad_s'],action['targets'][i],
                command['maximum_speed_rad_s'],joint['lower_limit_rad'],joint['upper_limit_rad'],
                bridge.CONTROLLER_DT_S,margin_rad=MARGIN_RAD,lookahead_steps=1,acceleration=a)
            final=max(min(0.,(joint['lower_limit_rad']-o['position_rad'])/bridge.CONTROLLER_DT_S),
                min(max(0.,(joint['upper_limit_rad']-o['position_rad'])/bridge.CONTROLLER_DT_S),shaped['shaped_velocity_rad_s']))
            command['joint_guard_applied']=command['joint_guard_applied'] or final!=action['targets'][i]
            command['canonical_velocity_rad_s']=final
            command['response_braking_reserve']=dict(shaped,acceleration_rad_s2=a)
            action['targets'][i]=final
    return protected


def plan(controller, base, observation, supplied, actions):
    p=controller.candidate['response_search'];state=observation['state']
    staged=p['schema_version']==restoring.SCHEMA
    before=copy.deepcopy(controller.response_state);after=copy.deepcopy(before)
    pose=state['base_pose_world'];twist=state['base_twist_world'];joints=state['ordered_joint_observations']
    positions=[j['position_rad'] for j in joints];qd=np.asarray([j['velocity_rad_s'] for j in joints])
    velocity=np.r_[xyz(twist['linear_velocity_m_s']),xyz(twist['angular_velocity_rad_s']),qd]
    prepared=controller.response_model.prepare(xyz(pose['position_m']),[pose['orientation_xyzw'][k] for k in 'xyzw'],positions,velocity)
    rotation=prepared['frame']['rotations'][0];config=controller.response_config;a=controller.actuators
    tilt=math.acos(max(-1.,min(1.,float(rotation[1,1]))))
    desired=np.zeros(3) if staged else rotation[:,0]*(p['direction']*min(p['maximum_rate_rad_s'],2.*tilt))

    def predict(targets):
        targets=np.asarray(targets,np.float32).astype(float)
        motor=velocity_actuation(qd,targets,a['gains'],a['force_ranges'],a['damping'])
        answer=response(controller.response_model,prepared,motor['applied'],supplied['contacts'],config['dt'],
            penetration_recovery_time=config['penetration_recovery_time'],joint_armature=a['armature'],
            joint_velocity_derivative=motor['velocity_derivative'])
        require(np.isfinite(answer['velocity']).all(),'Constraint nonfinite prediction')
        error=answer['velocity'][3:6]-desired
        return dict(native_targets=targets.tolist(),velocity=answer['velocity'].tolist(),score=-float(error @ error),
            converged=answer['solver']['converged'],kkt_residual=answer['solver']['kkt_residual'])

    brake=predict([0.]*8);estimates=decelerations(qd,brake['velocity'][6:],config['dt'],p['reserve_method'])
    actions=protect(actions,controller,state,estimates['acceleration_rad_s2'])
    predictions={}
    def evaluate(index):
        if index not in predictions:
            answer=predict(actions[index]['targets'])
            answer.update(action_index=index,**feasibility(controller.spec['joints'],positions,qd,
                answer['velocity'][6:],estimates['acceleration_rad_s2'],p['feasibility'],config['dt']))
            # A coupled estimate predicting no deceleration at nontrivial speed
            # cannot authorize a rotating action on the strength of its floor.
            answer['feasible']=answer['feasible'] and not any(estimates['unsupported_braking'])
            predictions[index]=answer
        return predictions[index]

    upright=base['resolution']['phase']=='upright_stance';trigger='upright' if upright else 'scheduled'
    holding=not staged and not upright and controller.step_index<before['next_replan_step']
    indices=[0] if staged or upright else [before['action_index']] if holding else list(range(9))
    if staged:trigger='trajectory_current_state'
    if brake['converged']:
        for index in indices:evaluate(index)
        if holding and predictions[indices[0]]['converged'] and not predictions[indices[0]]['feasible']:
            indices=list(range(9));trigger='held_became_infeasible'
            for index in indices:evaluate(index)
        elif holding:trigger='held_check'
    converged=brake['converged'] and all(v['converged'] for v in predictions.values())
    feasible=[i for i in indices if i in predictions and predictions[i]['feasible']] if converged else []
    withdrawal_prediction=None
    if feasible:
        selected=max(feasible,key=lambda i:(predictions[i]['score'],-i));chosen=actions[selected]
        reason='upright_stance' if upright else 'held_pattern' if trigger=='held_check' else 'replanned'
        if reason!='held_pattern':after=dict(action_index=selected,next_replan_step=controller.step_index+(1 if staged or upright else p['replan_steps']))
    else:
        selected=9
        if staged and p['withdrawal']=='restore_position':
            chosen=restoring.withdrawal(actions[0],controller,state)
            withdrawal_prediction=predict(chosen['targets'])
            converged=converged and withdrawal_prediction['converged']
            reason='position_restoration' if converged else 'model_nonconvergence'
        else:
            chosen=copy.deepcopy(actions[0]);chosen['targets']=[0.]*8
            for command in chosen['commands']:
                command['joint_guard_applied']=command['joint_guard_applied'] or command['canonical_velocity_rad_s']!=0.
                command['canonical_velocity_rad_s']=0.;command['response_braking_withdrawal']=True
            withdrawal_prediction=brake
            reason='braking_withdrawal' if converged else 'model_nonconvergence'
        after=dict(action_index=0,next_replan_step=controller.step_index+1)
    if staged:
        sequence=base['resolution']['sequence']
        sequence['proposed_state_after']=copy.deepcopy(sequence['state_after'])
        sequence['withdrawal_paused']=selected==9
        if selected==9:sequence['state_after']=copy.deepcopy(sequence['state_before'])
    base['native_targets']=chosen['targets'];base['resolution']['ordered_commands']=chosen['commands']
    base['resolution']['response_search']=dict(schema_version=p['schema_version'],policy=copy.deepcopy(p),
        state_before=before,state_after=after,selection_reason=reason,applied_action=selected,
        predictions=[predictions[i] for i in sorted(predictions)],desired_angular_velocity_world_rad_s=None if upright else desired.tolist(),
        held_value='action_pattern_only',model_ordering_qualified=False,recovery_benefit_established=False,
        constraints=dict(reserve_method=p['reserve_method'],feasibility=p['feasibility'],margin_rad=MARGIN_RAD,
            brake_prediction=brake,**estimates,replan_trigger=trigger,
            guarded_joint_count=sum(c['joint_guard_applied'] for c in chosen['commands']),
            stopping_guaranteed=False))
    if staged:
        base['resolution']['response_search']['constraints']['withdrawal_prediction']=withdrawal_prediction
        base['resolution']['response_search']['held_value']='none_current_trajectory_each_interval'
    return base
