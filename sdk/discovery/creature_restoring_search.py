"""Paired staged-trajectory discovery using the shared native owner and readers.

The restoring request is a bounded development intervention, not a verified
invariant set or stopping guarantee. Old response contracts remain immutable.
"""
import copy
import hashlib
import json
import math
from pathlib import Path

from creature_batch import require

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = 'locolemotion_restoring_trajectory_policy_v1'
DEFAULT = dict(schema_version=SCHEMA,withdrawal='zero_velocity',reserve_method='fixed',feasibility='stopping')
PREDECESSOR = dict(path='sdk/discovery/creature_response_joint_limit_result_v2.json',
    sha256='1593e1febe6b2a2588f1801612fe900c5342b24b6e151182e58b249e31e665d4')
ROUTE = 'sdk/discovery/creature_restoring_trajectory_route_v1.json'
SEARCH = 'sdk/discovery/creature_restoring_trajectory_v1.json'
RESTORE_MARGIN = .08
RESTORE_GAIN = 8.
RESTORE_SPEED = .75
RECIPE = dict(schema_version='locolemotion_restoring_trajectory_search_v1',seed=1061148,
    bodies=24,trajectories=48,assignment_offsets=[0,7],withdrawals=['zero_velocity','restore_position'],
    starts_rad=[math.pi-.05,-math.pi+.05],outer_steps=720,route_outer_steps=2,
    route_normalized_joint_positions=[.98,0.,0.,0.,0.,0.,0.,0.],
    restoration_margin_rad=RESTORE_MARGIN,restoration_gain_s_inv=RESTORE_GAIN,
    restoration_maximum_speed_rad_s=RESTORE_SPEED,
    phase_state_during_withdrawal='pause_until_a_feasible_trajectory_command',
    references=['zero_velocity_brake','timed_rock','unchanged_rollneg_fixed_stopping'],
    paired_effects='descriptive_by_body_trajectory_and_start',
    qualification_requires_fresh_twelve_second_confirmation=True)


def enabled(c):
    return c.get('response_search',{}).get('schema_version')==RECIPE['schema_version']


def policy(value):
    require(type(value) is dict and set(value)==set(DEFAULT)
        and value['schema_version']==SCHEMA and value['withdrawal'] in RECIPE['withdrawals']
        and value['reserve_method']=='fixed' and value['feasibility']=='stopping',
        'Restoring trajectory policy fields or methods')
    return copy.deepcopy(value)


def proposals():
    import creature_trajectory_search as trajectory
    import creature_righting_sequence as sequence
    # Exposed pose templates remain explicit; the new search changes measured
    # phase transitions and compares both withdrawal behaviors for every recipe.
    values=trajectory.proposals(trajectory.RECIPE)
    for i,p in enumerate(values):
        for j,phase in enumerate(p['phases']):
            phase['minimum_hold_steps']=12
            phase['maximum_hold_steps']=(72,108,144)[(i+j)%3]
            gate='pose' if j==0 else ('contact' if (i+j)%2 else 'progress')
            phase['advance_when']=gate
            phase['threshold']=.1 if gate=='pose' else 1+(i%2) if gate=='contact' else min(150.,10.+25*j)
        sequence.profile(p)
    return values


def spec(route=False):
    import creature_response_search as search
    import creature_righting as righting
    original=search.spec(protected=True)
    profiles=copy.deepcopy([original['profiles'][0],original['profiles'][1],original['profiles'][6]])
    for candidate in proposals():
        for withdrawal in RECIPE['withdrawals']:
            name='zero' if withdrawal=='zero_velocity' else 'restore'
            profiles.append(dict(copy.deepcopy(candidate),id=candidate['id']+'_'+name,
                response_search=dict(DEFAULT,withdrawal=withdrawal)))
    bodies=[0] if route else list(range(RECIPE['bodies']))
    if route:profiles=profiles[:5]
    assignments=[]
    for body in bodies:
        selected=list(range(3))
        for i in range(1 if route else RECIPE['trajectories']):
            if route or body in ((i+offset)%RECIPE['bodies'] for offset in RECIPE['assignment_offsets']):
                selected.extend((3+2*i,4+2*i))
        assignments.append(selected)
    starts=[dict(id='inverted_positive_roll',roll_rad=RECIPE['starts_rad'][0]),
            dict(id='inverted_negative_roll',roll_rad=RECIPE['starts_rad'][1])]
    if route:starts.append(dict(id='upright',roll_rad=0.))
    return dict(schema_version=righting.ASSIGNED_SCHEMA,
        descriptors=[copy.deepcopy(original['descriptors'][i]) for i in bodies],
        profiles=profiles,profiles_by_body=assignments,conditions=copy.deepcopy(original['conditions']),starts=starts)


def expand(c):
    """Derive the prospective population once; never accept a competing literal."""
    import creature_righting as righting
    require(enabled(c) and 'righting_spec' not in c and 'trajectory_reference_by_body' not in c
        and not any(k in c for k in righting.EXPANDED),'Restoring recipe expansion scope')
    c['righting_spec']=spec(c['mode']=='route_ghost')
    c['trajectory_reference_by_body']=[2]*len(c['righting_spec']['descriptors'])


def validate(c):
    import creature_capture as capture
    import creature_response_probe as probe
    import creature_response_search as search
    import creature_trajectory_search as trajectory
    route=c['mode']=='route_ghost'
    require(enabled(c) and c['response_search']==RECIPE and c['mode'] in ('route_ghost','development_discovery')
        and c['righting_spec']==spec(route) and c['predecessor']==PREDECESSOR
        and c['predictor_component']==probe.ACTUATOR_COMPONENT and c['seed']==RECIPE['seed']
        and c['outer_steps']==RECIPE['route_outer_steps' if route else 'outer_steps']
        and c['capture_mode']==('full' if route else 'compact_v1') and c['compact_capture']==capture.POLICY
        and c['trajectory_screen']==trajectory.POLICY
        and c['trajectory_reference_by_body']==[2]*len(c['righting_spec']['descriptors'])
        and c['maximum_worlds_per_batch']==4 and c['readback']==dict(mode='shared_snapshot',reference_check=False)
        and c.get('retain_planning_state') is True
        and not any(k in c for k in ('response_probe','response_confirmation','post_native_path_screen','contact_reactions')),
        'Restoring trajectory frozen population or scope')
    require(len(c['cells'])==(15 if route else 528),'Restoring trajectory population count')
    if route:require('capture_reference' not in c,'Restoring route cannot borrow a canary')
    else:
        require(c['capture_reference']==dict(path=ROUTE,sha256=hashlib.sha256((ROOT/ROUTE).read_bytes()).hexdigest()),
            'Restoring search full-canary declaration')
    search.source_document(PREDECESSOR)
    for pin in search.source_document(probe.ACTUATOR_COMPONENT)['source_pins']:search.source_document_bytes(pin)


def source_dependencies():
    return [ROOT/p for p in (ROUTE,SEARCH,'sdk/discovery/creature_restoring_search.py',
        'sdk/discovery/test_creature_restoring_search.py',PREDECESSOR['path'])]


def initial_arrays(creatures,c):
    import numpy as np
    import creature_righting as righting
    if c['mode']!='route_ghost':return righting.initial_arrays(creatures,c['initial_roll_angles_rad'])
    positions=[]
    for creature,roll in zip(creatures,c['initial_roll_angles_rad'],strict=True):
        joints=creature['compiled']['morphology']['morphology_spec']['joints']
        pose=[v*(j['upper_limit_rad'] if v>=0 else -j['lower_limit_rad'])
              for v,j in zip(RECIPE['route_normalized_joint_positions'],joints,strict=True)]
        height=.005-righting.ground_clearance(creature,roll,pose)
        positions.append([0.,0.,height,math.cos(roll/2),math.sin(roll/2),0.,0.]+pose)
    return np.asarray(positions,np.float32),np.zeros((len(creatures),14),np.float32)


def withdrawal(action,controller,state):
    """Request inward motion only outside the declared interior position band."""
    result=copy.deepcopy(action);targets=[]
    for joint,motor,observed,command in zip(controller.spec['joints'],controller.spec['actuators'],
            state['ordered_joint_observations'],result['commands'],strict=True):
        q=observed['position_rad'];lower=joint['lower_limit_rad'];upper=joint['upper_limit_rad']
        require(all(type(v) in (int,float) and math.isfinite(v) for v in (q,lower,upper))
            and lower+RESTORE_MARGIN<upper-RESTORE_MARGIN,'Restoring joint interior')
        target=max(lower+RESTORE_MARGIN,min(upper-RESTORE_MARGIN,q))
        caps=(motor['maximum_target_speed_rad_s'],command['maximum_speed_rad_s'])
        require(all(type(v) in (int,float) and math.isfinite(v) and v>0 for v in caps),'Restoring speed caps')
        speed=min(RESTORE_SPEED,*caps)
        requested=RESTORE_GAIN*(target-q);applied=max(-speed,min(speed,requested))
        require(math.isfinite(applied) and applied*(target-q)>=0.,'Restoring command direction')
        command['joint_guard_applied']=command['joint_guard_applied'] or applied!=command['canonical_velocity_rad_s']
        command['canonical_velocity_rad_s']=applied
        command['response_position_restoration']=dict(position_target_rad=target,requested_velocity_rad_s=requested,
            bounded_velocity_rad_s=applied,margin_rad=RESTORE_MARGIN,position_gain_s_inv=RESTORE_GAIN,
            maximum_speed_rad_s=speed,stopping_guaranteed=False)
        targets.append(applied)
    result['targets']=targets
    return result

def validate_decision(decision,targets):
    """Compact accounting keeps the selected withdrawal and its actual forecast."""
    from gpu_quadruped_model import f32
    p=policy(decision['policy']);action=decision['applied_action'];reason=decision['selection_reason']
    require(action in (0,9) and reason in ('replanned','upright_stance','braking_withdrawal',
        'position_restoration','model_nonconvergence') and len(targets)==8
        and all(type(v) in (int,float) and math.isfinite(v) for v in targets),
        'Restoring selected action or targets')
    forecast=decision['constraints']['withdrawal_prediction']
    if action==0:
        require(reason in ('replanned','upright_stance') and forecast is None,
            'Restoring active trajectory accounting')
    else:
        expected='braking_withdrawal' if p['withdrawal']=='zero_velocity' else 'position_restoration'
        require(reason in (expected,'model_nonconvergence') and type(forecast) is dict
            and forecast['native_targets']==[f32(v) for v in targets],
            'Restoring applied withdrawal forecast')
        if p['withdrawal']=='zero_velocity':require(targets==[0.]*8,'Restoring zero comparator targets')
        else:require(all(abs(v)<=RESTORE_SPEED for v in targets),'Restoring withdrawal speed')
    require(decision['held_value']=='none_current_trajectory_each_interval',
        'Restoring cannot hold a stale action')

def validate_capture(row,candidate,spec,previous):
    """Check retained phase continuity and the bounded measured-state withdrawal."""
    import creature_righting_sequence as sequence
    from gpu_quadruped_model import f32
    control=row['response_control'];decision=control['decision'];phase=control['sequence']
    require(type(phase) is dict,'Restoring compact phase state')
    before=previous if previous is not None else dict(phase=0,elapsed=0,cycle=0,
        held_pose=sequence.normalized_pose(spec,row['prepared_qpos'][7:]))
    paused=decision['applied_action']==9
    require(phase['state_before']==before and phase['withdrawal_paused'] is paused
        and phase['state_after']==(before if paused else phase['proposed_state_after']),
        'Restoring withdrawal phase continuity')
    for state in (phase['state_before'],phase['state_after'],phase['proposed_state_after']):
        require(type(state) is dict and set(state)=={'phase','elapsed','cycle','held_pose'}
            and type(state['phase']) is int and 0<=state['phase']<len(candidate['phases'])
            and type(state['elapsed']) is int and 0<=state['elapsed']<=240
            and type(state['cycle']) is int and 0<=state['cycle']<=row['outer_step']+1
            and type(state['held_pose']) is list and len(state['held_pose'])==8
            and all(type(v) in (int,float) and math.isfinite(v) and -.9<=v<=.9 for v in state['held_pose']),
            'Restoring compact phase bounds')
    if paused and candidate['response_search']['withdrawal']=='restore_position':
        expected=[]
        for q,j,m in zip(row['prepared_qpos'][7:],spec['joints'],spec['actuators'],strict=True):
            interior=max(j['lower_limit_rad']+RESTORE_MARGIN,min(j['upper_limit_rad']-RESTORE_MARGIN,q))
            speed=min(RESTORE_SPEED,m['maximum_target_speed_rad_s'],candidate['maximum_speed_rad_s'])
            expected.append(f32(max(-speed,min(speed,RESTORE_GAIN*(interior-q)))))
        require(row['native_targets']==expected,'Restoring compact inward request')
    return copy.deepcopy(phase['state_after'])


def assess(c,screen):
    """Retain every paired start; useful six-second leads still need confirmation."""
    if c['mode']=='route_ghost':
        return dict(route_only=True,qualification_requires_fresh_twelve_second_confirmation=True)
    expected={(m['body_index'],m['condition_index'],m['start_index'],m['candidate_index']):m
              for m in c['righting_metadata']}
    groups=set();seen=set();pairs=[]
    for group in screen['groups']:
        key=tuple(group[k] for k in ('body_index','condition_index','start_index'))
        require(key not in groups and group.get('reference_candidate_index')==2,
            'Restoring duplicate group or crossed reference')
        groups.add(key);observations={}
        for row in group['observations']:
            identity=tuple(row[k] for k in ('body_index','condition_index','start_index','candidate_index'))
            require(identity[:3]==key and identity in expected and identity not in seen
                and all(row[k]==v for k,v in expected[identity].items()),'Restoring crossed or duplicate episode')
            require(all(type(row[k]) in (int,float) and math.isfinite(row[k]) for k in (
                'peak_rotation_degrees','peak_gain_against_timed_degrees','peak_gain_against_reference_degrees'))
                and all(type(row[k]) is int and row[k]>=0 for k in (
                'joint_limit_violation_steps','response_model_withdrawals')),'Restoring finite paired outcome')
            seen.add(identity);observations[row['candidate_index']]=row
        require(set(observations)==set(c['righting_spec']['profiles_by_body'][key[0]]),
            'Restoring missing paired role or reference')
        for index in c['righting_spec']['profiles_by_body'][group['body_index']]:
            if index<3 or (index-3)%2:continue
            zero,restore=observations[index],observations[index+1]
            def passes(x):
                return x['joint_limit_violation_steps']==x['response_model_withdrawals']==0 and min(
                    x['peak_gain_against_timed_degrees'],x['peak_gain_against_reference_degrees'])>=5.
            pairs.append(dict(body_index=group['body_index'],start_index=group['start_index'],
                trajectory_index=(index-3)//2,zero=zero,restore=restore,
                zero_passes=passes(zero),restore_passes=passes(restore),
                peak_rotation_change_degrees=restore['peak_rotation_degrees']-zero['peak_rotation_degrees'],
                joint_violation_sample_change=restore['joint_limit_violation_steps']-zero['joint_limit_violation_steps']))
    require(seen==set(expected) and len(pairs)==192,'Restoring paired start denominator')
    decisions=[]
    for body in range(RECIPE['bodies']):
        for index in sorted({p['trajectory_index'] for p in pairs if p['body_index']==body}):
            starts=[p for p in pairs if p['body_index']==body and p['trajectory_index']==index]
            require({p['start_index'] for p in starts}=={0,1} and len(starts)==2,'Restoring crossed or missing start')
            zero=all(p['zero_passes'] for p in starts);restore=all(p['restore_passes'] for p in starts)
            decisions.append(dict(body_index=body,trajectory_index=index,zero_passes_both=zero,
                restore_passes_both=restore,classification='both' if zero and restore else
                    'restore_only' if restore else 'zero_only' if zero else 'neither'))
    require(len(decisions)==96,'Restoring paired recipe denominator')
    return dict(paired_starts=pairs,paired_recipes=decisions,
        zero_both_start_leads=sum(p['zero_passes_both'] for p in decisions),
        restore_both_start_leads=sum(p['restore_passes_both'] for p in decisions),
        comparative_superiority_established=False,qualification_requires_fresh_twelve_second_confirmation=True,
        recovery_benefit_established=False,training_data_authority=False,release_authority=False)


def verify_route(receipt):
    import creature_response_search as search
    c=receipt['contract'];audit=receipt['audit'];rows=[]
    require(enabled(c) and c['mode']=='route_ghost' and audit['ok'] and not audit['synthetic']
        and audit['gpu_worlds']==15 and audit['controller_rows_replayed']==30
        and audit['native_rows_verified']==150,'Restoring route execution and full replay')
    for meta,metric in zip(c['righting_metadata'],audit['metrics'],strict=True):
        search.validate_metrics(c,meta,metric)
        require(metric['response_search_failures']==0,'Restoring route model withdrawal')
        p=c['righting_spec']['profiles'][meta['candidate_index']].get('response_search')
        if p and p['schema_version']==SCHEMA:
            counter='brakes' if p['withdrawal']=='zero_velocity' else 'restores'
            require(metric['response_search_'+counter]==2,'Restoring route withdrawal coverage')
            rows.append(dict(cell_id=meta['cell_id'],withdrawal=p['withdrawal'],intervals=2))
    require(len(rows)==6,'Restoring route paired roles')
    return dict(complete=True,worlds=15,cells=rows,fresh_near_limit_initialization=True,
        full_horizon_confirmation=False,recovery_benefit_established=False,physical_acceptance_authority=False)
