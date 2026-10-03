"""V41 saved-input support-pose sketch, not native execution or a rollout.

Both one-command substitution and chained reference memory are retained. Body
states, contacts, upstream waves and gait clocks stay the ORIGINAL V40 inputs.
The current contact/phase selector is held fixed for both wave comparisons so
their difference does not mislabel a pose-selector switch as wave velocity.
"""
import argparse
import json
import math
from pathlib import Path

import development_recovery_landing_reach_diagnosis as data

ROOT, EVIDENCE, cold = data.ROOT, data.EVIDENCE, data.cold
geometry = data.tracking.geometry
ANALYSIS_PATHS = (*data.ANALYSIS_PATHS, 'sdk/conformance/development_recovery_upright_stance_precheck.py')


def selection(active, phase, presence, bearing):
    if (any(type(v) is not bool for v in (active,presence,bearing))
            or type(phase) not in (int,float) or not math.isfinite(phase)
            or phase!=int(phase) or not 0<=phase<360 or (bearing and not presence)):
        raise ValueError('UPRIGHT_STANCE_SELECTOR_DOMAIN')
    return active and phase>72 and presence and bearing


def snapshot(wave):
    return dict(active=wave['active'],limbs=[(r['nominal_leg_direction_rad'],
        r['walking_knee_fraction'],r['scheduled_phase_step']) for r in wave['ordered_limbs']])


def goals(pose, wave, dimensions, selected):
    if len(selected)!=4 or any(type(v) is not bool for v in selected):
        raise ValueError('UPRIGHT_STANCE_MASK_DOMAIN')
    # This is a reference pose only. No measured quaternion is modified.
    # On the explicitly horizontal floor, every upright yaw has identical
    # vertical projections; identity is its yaw-independent representative.
    measured, old_height = cold.support_goals(pose,wave,dimensions)
    upright, upright_height = cold.support_goals((pose[0],(0.,0.,0.,1.)),wave,dimensions)
    return [upright[i] if selected[i//2] else measured[i] for i in range(8)], measured, upright, old_height, upright_height


def step(entry, references, dimensions, enable_upright=True):
    request=entry['request']; output=entry['native_output']; state=request['state']
    receipt=output['actuation']['receipt']['recovery_support_plane']
    pose,wave=cold.algebra.inputs(entry)
    contacts=state['ordered_contact_observations']
    if len(contacts)!=4: raise ValueError('UPRIGHT_STANCE_CONTACT_COUNT')
    selected=[]
    for limb,w,c in zip(geometry.LIMBS,wave['limbs'],contacts):
        if c['contact_site_id']!=limb+'_foot': raise ValueError('UPRIGHT_STANCE_CONTACT_ORDER')
        chosen=selection(wave['active'],w[2],c['presence'],c['bears_support'])
        selected.append(chosen and enable_upright)
    goal,old_goal,upright_goal,old_height,upright_height=goals(pose,wave,dimensions,selected)
    prior=receipt['wave_velocity']['previous_wave']
    active=prior is not None and prior['active'] and wave['active']
    comparison_goal=goals(pose,snapshot(prior),dimensions,selected)[0] if active else goal
    dt=receipt['reference_step_duration_s']
    commands=output['actuation']['ordered_commands'];caps=[c['maximum_target_speed_rad_s'] for c in commands]
    target=cold.algebra.bounded_targets(goal,references,caps,dt)
    comparison=cold.algebra.bounded_targets(comparison_goal,references,caps,dt) if active else target
    motors=[]
    for i,command in enumerate(commands):
        joint=state['ordered_joint_observations'][i];cap=caps[i];contact=contacts[i//2]
        full=cold.algebra.clamp((target[i]-references[i])/dt,-cap,cap) if dt>0 else 0.
        absent=active and dt>0 and not contact['presence'] and not contact['bears_support']
        rate=full if absent else cold.algebra.clamp((target[i]-comparison[i])/dt,-cap,cap) if active and dt>0 else 0.
        raw=8.*(target[i]-joint['position_rad'])-.65*joint['velocity_rad_s']+1.65*rate
        bound=(-.72,.72) if i%2==0 else (0.,1.1)
        assert bound[0]<=goal[i]<=bound[1] and bound[0]<=target[i]<=bound[1]
        assert abs(target[i]-references[i])<=cap*dt+1e-14
        motors.append(dict(actuator_id=command['actuator_id'],upright_selected=selected[i//2],
            prior_reference_rad=references[i],goal_rad=goal[i],target_rad=target[i],comparison_rad=comparison[i],
            full_reference_rate_rad_s=full,selected_reference_rate_rad_s=rate,
            velocity_rad_s=-cold.algebra.clamp(raw,-cap,cap),saturated=abs(raw)>cap,
            slew_limited=target[i]!=goal[i],cap_rad_s=cap))
    return dict(selected=selected,reference_step_duration_s=dt,original_goals_rad=old_goal,
        upright_goals_rad=upright_goal,original_height_plan=old_height,upright_height_plan=upright_height,
        selected_goals_rad=goal,targets_rad=target,motors=motors)


def summarize(report):
    if report['source_commit']!=data.SOURCE: raise ValueError('UPRIGHT_STANCE_SOURCE_CROSSED')
    baseline_audit=cold.command_audit(report)
    samples,entries,native,bodies,dimensions,frame_error=data.tracking.samples(report)
    session=next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_resume')
    assert session['start_receipt']['development_floor_source']['floor_reference']['height_world_m']==0.
    lookup={(r['command_local'],r['limb']):r for r in samples}
    chain=None;prior_mask=None;timeline=[];changes=[]
    baseline_target_error=baseline_motor_error=0.
    for n,entry in entries.items():
        references=entry['request']['memory']['support_reference']['ordered_target_positions_rad']
        original=entry['native_output']['actuation']['ordered_commands']
        baseline=step(entry,references,dimensions,False)
        for a,b in zip(baseline['motors'],original):
            baseline_target_error=max(baseline_target_error,abs(a['target_rad']-b['requested_target_position_rad']))
            baseline_motor_error=max(baseline_motor_error,abs(a['velocity_rad_s']-b['target_velocity_rad_s']))
            assert abs(a['target_rad']-b['requested_target_position_rad'])<1e-12
            assert abs(a['velocity_rad_s']-b['target_velocity_rad_s'])<1e-10
            assert a['saturated']==b['velocity_saturated']
        one=step(entry,references,dimensions)
        chained=step(entry,references if chain is None else chain,dimensions)
        chain=chained['targets_rad']
        torso=native[n-1]['observation']['state']['base_pose_world']
        contacts=entry['request']['state']['ordered_contact_observations']
        count=sum(c['presence'] and c['bears_support'] for c in contacts)
        geometry_rows=[]
        for i,limb in enumerate(geometry.LIMBS):
            row=lookup[n,limb];q=slice(2*i,2*i+2)
            old=geometry.ideal_distal(torso,limb,*one['original_goals_rad'][q],*dimensions)[1]
            chosen=geometry.ideal_distal(torso,limb,*one['selected_goals_rad'][q],*dimensions)[1]
            reference=geometry.ideal_distal(torso,limb,*chained['targets_rad'][q],*dimensions)[1]
            geometry_rows.append(dict(limb=limb,phase=row['command_phase'],pre_contact=row['native_contact'],
                raw_contact_count=row['raw_contact_count'],upright_selected=one['selected'][i],
                original_goal_bottom_m=old,proposed_goal_bottom_at_original_pose_m=chosen,
                proposed_minus_original_goal_bottom_m=chosen-old,
                chained_reference_bottom_at_original_pose_m=reference,
                nominal_original_measured_bottom_m=row['nominal_actual_bottom_m']))
            if prior_mask is not None and prior_mask[i]!=one['selected'][i]:
                changes.append(dict(command_local=n,limb=limb,phase=row['command_phase'],
                    previous_selected=prior_mask[i],current_selected=one['selected'][i],pre_contact=row['native_contact'],
                    chained_motor_commands=chained['motors'][q]))
        prior_mask=one['selected']
        timeline.append(dict(command_local=n,measured_trace_local=n-1,support_contact_count=count,
            baseline=baseline,one_command_substitution=one,chained_reference_replay=chained,geometry=geometry_rows))
    all_motors=lambda name:[m for r in timeline for m in r[name]['motors']]
    original=all_motors('baseline');one=all_motors('one_command_substitution');chained=all_motors('chained_reference_replay')
    selected_geometry=[g for r in timeline for g in r['geometry'] if g['upright_selected']]
    strata={str(count):dict(command_count=sum(r['support_contact_count']==count for r in timeline),
        selected_limb_commands=sum(sum(r['one_command_substitution']['selected']) for r in timeline if r['support_contact_count']==count)) for count in range(5)}
    per=[]
    for limb in geometry.LIMBS:
        rows=[g for g in selected_geometry if g['limb']==limb]
        per.append(dict(limb=limb,selected_command_count=len(rows),
            proposed_minus_original_goal_bottom_m=data.spread(r['proposed_minus_original_goal_bottom_m'] for r in rows),
            proposed_goal_bottom_at_original_pose_m=data.spread(r['proposed_goal_bottom_at_original_pose_m'] for r in rows),
            geometry_lift_direction_command_count=sum(r['proposed_minus_original_goal_bottom_m']>1e-12 for r in rows),
            geometry_lower_direction_command_count=sum(r['proposed_minus_original_goal_bottom_m'] < -1e-12 for r in rows)))
    return dict(command_count=len(timeline),limb_command_count=4*len(timeline),joint_command_count=len(original),
        original_command_audit=baseline_audit,original_walking_evaluation=session['evaluation'],
        baseline_target_maximum_error_rad=baseline_target_error,baseline_motor_maximum_error_rad_s=baseline_motor_error,
        original_saturated_joint_commands=sum(m['saturated'] for m in original),
        upright_selected_limb_commands=len(selected_geometry),support_contact_count_strata=strata,
        upright_common_height_nonempty_command_count=sum(r['one_command_substitution']['upright_height_plan'][0]<=r['one_command_substitution']['upright_height_plan'][1] for r in timeline),
        one_command_substitution=dict(changed_joint_commands=sum(abs(a['velocity_rad_s']-b['velocity_rad_s'])>1e-10 for a,b in zip(original,one)),
            saturated_joint_commands=sum(m['saturated'] for m in one),
            unselected_goal_and_target_and_motor_preserved_within_existing_arithmetic=all(
                abs(a['goal_rad']-b['goal_rad'])<1e-12 and abs(a['target_rad']-b['target_rad'])<1e-12 and abs(a['velocity_rad_s']-b['velocity_rad_s'])<1e-10
                for a,b in zip(original,one) if not b['upright_selected'])),
        chained_reference_replay=dict(changed_joint_commands=sum(abs(a['velocity_rad_s']-b['velocity_rad_s'])>1e-10 for a,b in zip(original,chained)),
            saturated_joint_commands=sum(m['saturated'] for m in chained),
            unselected_joint_commands_with_carried_reference_change=sum(not b['upright_selected'] and abs(a['target_rad']-b['target_rad'])>1e-12 for a,b in zip(original,chained)),
            all_goal_target_velocity_and_slew_bounds_preserved=True,
            maximum_absolute_step_reference_change_rad=max(abs(m['target_rad']-m['prior_reference_rad']) for m in chained)),
        selector_change_count=len(changes),selector_changes=changes,per_limb_selected_geometry=per,
        all_command_comparisons=timeline)


def observe():
    path=ROOT/'sdk/development/recovery_attempts'/(data.ATTEMPT+'.json');raw=path.read_bytes()
    if data.digest(raw)!=data.CLOSURE_SHA: raise ValueError('UPRIGHT_STANCE_CLOSURE_DRIFT')
    closure=json.loads(raw);report_raw=Path(closure['kicked_report']['path']).read_bytes()
    if data.digest(report_raw)!=data.REPORT_SHA or closure['source_snapshot']['head']!=data.SOURCE: raise ValueError('UPRIGHT_STANCE_REPORT_DRIFT')
    return dict(schema_version='sporespore_development_upright_stance_precheck_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt_retained_inputs',authority_mode='non_native_controller_precheck',question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=data.digest(raw)),source_report=closure['kicked_report'],
        analysis_sources=[dict(path=p,raw_sha256=data.digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        proposal_rule='For active wave inputs, select only current phase 73..359 with explicit presence=true and bears_support=true. Replace selected goals with the same all-four-leg support geometry at a floor-upright reference orientation and the measured floor-relative torso height. Preserve original goals for all other limbs. Hold the current selection mask fixed for the current and prior-wave goal evaluations; retain V40 full-reference selection only for absent contacts. Preserve slew, gains and all caps.',
        observation=summarize(json.loads(report_raw)),
        limits='One-command substitution uses the original incoming reference memory. Chained replay carries only proposed reference positions; all physical states, contacts and upstream wave/gait inputs remain V40 observations. Neither replay predicts another trajectory. A foot goal rising at a fixed body pose can imply desired body lowering if that foot remains anchored, but unilateral contact and load transfer are unproved. Original foot contact and outcome are never replaced by ideal geometry. No force-aware policy, acceptance or equivalence claim.',
        native_controller_call_count=0,new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        original_evaluation_changed=False,physical_outcome_predicted=False,physical_acceptance_authority=False,release_authority=False)


def compact(full,output):
    raw=output.read_bytes()
    return dict(full,observation={k:v for k,v in full['observation'].items() if k!='all_command_comparisons'},
        complete_precheck=dict(path=output.as_posix(),byte_length=len(raw),raw_sha256=data.digest(raw)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True)
    output=parser.parse_args().output.resolve()
    if not output.is_relative_to(EVIDENCE.resolve()): raise ValueError('UPRIGHT_STANCE_DURABLE_OUTPUT_REQUIRED')
    full=observe()
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(full,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps(compact(full,output),indent=2,allow_nan=False))
