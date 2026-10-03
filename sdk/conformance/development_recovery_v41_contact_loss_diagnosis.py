"""Cold V41 event diagnosis: onset, subsequent command, and measured response.

Every command and every contact loss is included, including one-step and open
losses. Fixed-input selector contrasts are algebra, not alternate trajectories.
No native controller, world, evaluator, or acceptance threshold is changed.
"""
import argparse
import json
from pathlib import Path

import development_recovery_upright_stance_observation as original
import development_recovery_upright_stance_precheck as precheck

ROOT = original.ROOT
EVIDENCE = ROOT.parent/'SporeSpore_Evidence'
ATTEMPT = 'f4a08fa3230d4276869bb865c8c25a58'
SOURCE = 'ec22a5b9923a59654ced514ab982b66153c07b2e'
CLOSURE_SHA = 'sha256:c27c8cccfcbc630eaa2daac875943f94b59fd437b3d155d53c86bce73202f0a6'
REPORT_SHA = 'sha256:05ad0d6c07494dff8e08ddd429a26ada65e03ca811415394ae19b641535f8cd2'
require, digest = original.require, original.digest
geometry = precheck.geometry
tracking = precheck.data.tracking
spread = precheck.data.spread
ANALYSIS_PATHS = tuple(dict.fromkeys((*precheck.ANALYSIS_PATHS,
    'sdk/conformance/development_recovery_upright_stance_observation.py',
    'sdk/conformance/development_recovery_v41_contact_loss_diagnosis.py',
    'tests/test_development_v41_contact_loss.py')))


def selector_contrast(previous, current):
    """Both substitution orders; the remaining term includes pose AND wave.

    Use already independently reconstructed goals. Do not divide by the net
    change: opposing components could make such a percentage misleading.
    """
    old_mask, new_mask = previous['upright_selected'], current['upright_selected']
    old_key = 'upright_goals_rad' if old_mask else 'measured_goals_rad'
    new_key = 'upright_goals_rad' if new_mask else 'measured_goals_rad'
    delta = [b-a for a,b in zip(previous['goals_rad'], current['goals_rad'])]
    at_current = [b-a for a,b in zip(current[old_key], current[new_key])]
    at_previous = [b-a for a,b in zip(previous[old_key], previous[new_key])]
    return dict(mask_changed=old_mask != new_mask, total_goal_change_rad=delta,
        selector_change_at_current_pose_and_wave_rad=at_current,
        pose_and_wave_change_with_previous_selector_rad=[d-s for d,s in zip(delta,at_current)],
        selector_change_at_previous_pose_and_wave_rad=at_previous,
        pose_and_wave_change_with_current_selector_rad=[d-s for d,s in zip(delta,at_previous)])


def summarize(report):
    observed = original.summarize(report)
    require(report['source_commit'] == SOURCE, 'V41_LOSS_SOURCE')
    entries = report['development_walking_entry']['rows']
    session = next(s for s in report['retained_arm']['walking_sessions']
                   if s['evaluation_segment_id'] == 'walking_resume')
    trace = [r for r in report['retained_arm']['trace_rows']
             if r.get('walking_session_id') == session['session_id']]
    native_rows = [r for r in report['development_native_walking_contacts']['rows']
                   if r['segment_id'] == 'walking_resume']
    require(len(entries) == len(trace) == len(native_rows) == 400, 'V41_LOSS_POPULATION')
    require([r['walking_session_local_step'] for r in trace] == list(range(1,401))
            and [r['session_local_step'] for r in native_rows] == list(range(1,401)), 'V41_LOSS_ORDER')
    native = {r['session_local_step']-1:r['native_source'] for r in native_rows}
    measured, frame_error = geometry.reconstruct(report)
    bodies = {(r['limb'],r['trace_local_step']):r for r in measured}
    d = report['configuration']['base_descriptor']; upper = .35*d['upper_length_fraction']
    dimensions = (upper,.35-upper,.04*d['foot_radius_scale'],d['hip_span_scale'])
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    require(session['start_receipt']['development_floor_source']['floor_reference']['height_world_m'] == 0., 'V41_LOSS_FLOOR')
    timeline, indexed = [], {}
    errors = dict(goal_rad=0., target_rad=0., motor_rad_s=0., reference_rate_rad_s=0.)
    for n,entry in enumerate(entries,1):
        references = entry['request']['memory']['support_reference']['ordered_target_positions_rad']
        calculated = precheck.step(entry,references,dimensions)
        act = entry['native_output']['actuation']; support = act['receipt']['recovery_support_plane']
        for j,(a,b) in enumerate(zip(calculated['motors'],act['ordered_commands'])):
            for key,x,y,limit in (
                ('goal_rad',a['goal_rad'],support['upright_stance']['ordered_selected_goals_rad'][j],1e-12),
                ('target_rad',a['target_rad'],b['requested_target_position_rad'],1e-12),
                ('motor_rad_s',a['velocity_rad_s'],b['target_velocity_rad_s'],1e-10),
                ('reference_rate_rad_s',a['selected_reference_rate_rad_s'],support['ordered_reference_velocity_rad_s'][j],1e-10)):
                errors[key] = max(errors[key],abs(x-y))
                require(abs(x-y)<limit, 'V41_LOSS_COMMAND_RECONSTRUCTION_'+key)
            require(a['saturated'] == b['velocity_saturated'], 'V41_LOSS_SATURATION')
        for i,limb in enumerate(geometry.LIMBS):
            sl = slice(2*i,2*i+2); b = bodies[limb,n-1]
            contact = entry['request']['state']['ordered_contact_observations'][i]
            preceding = native[n-1]['precommand_trace']
            require(contact['presence'] == contact['bears_support'] == b['support'], 'V41_LOSS_CONTACT_BINDING')
            require(n==1 or b['support'] == trace[n-2]['contact_by_limb'][limb], 'V41_LOSS_PRE_POST_ALIGNMENT')
            require(n==400 or trace[n-1]['contact_by_limb'][limb] == bodies[limb,n]['support'], 'V41_LOSS_POST_PRE_ALIGNMENT')
            require(n==400 or trace[n-1]['foot_position_world_m_by_limb'][limb] ==
                    native[n]['precommand_trace']['foot_position_world_m_by_limb'][limb], 'V41_LOSS_POSITION_ALIGNMENT')
            delta = [v-u for u,v in zip(preceding['foot_position_world_m_by_limb'][limb],trace[n-1]['foot_position_world_m_by_limb'][limb])]
            joints = entry['request']['state']['ordered_joint_observations'][sl]
            commands = act['ordered_commands'][sl]
            row = dict(command_local=n,measured_trace_local=n-1,limb=limb,
                scheduled_phase_step=support['ordered_limb_proposals'][i]['scheduled_phase_step'],
                pre_contact=b['support'],post_contact=trace[n-1]['contact_by_limb'][limb],
                precommand_raw_contact_count=b['raw_contact_count'],upright_selected=calculated['selected'][i],
                measured_joint_rad=[j['position_rad'] for j in joints],
                measured_joint_rate_rad_s=[j['velocity_rad_s'] for j in joints],
                goals_rad=calculated['selected_goals_rad'][sl],
                measured_goals_rad=calculated['original_goals_rad'][sl],upright_goals_rad=calculated['upright_goals_rad'][sl],
                preceding_reference_rad=references[sl],targets_rad=calculated['targets_rad'][sl],
                selected_reference_rate_rad_s=support['ordered_reference_velocity_rad_s'][sl],
                geometric_requested_motor_rate_rad_s=[-c['target_velocity_rad_s'] for c in commands],
                speed_clamped_joint_count=sum(c['velocity_saturated'] for c in commands),
                precommand_nominal_capsule_bottom_m=b['nominal_capsule_bottom_m'],
                postcommand_nominal_capsule_bottom_m=bodies[limb,n]['nominal_capsule_bottom_m'] if n<400 else None,
                measured_distal_body_origin_displacement_world_m=delta,
                measured_distal_body_origin_forward_displacement_m=sum(a*v for a,v in zip(axis,delta)),
                measured_response_decomposition=tracking.decompose(limb,n-1,n,native,bodies,dimensions,axis))
            row['goal_transition'] = selector_contrast(indexed[limb,n-1],row) if n>1 else None
            indexed[limb,n] = row; timeline.append(row)
    losses=[]
    for limb in geometry.LIMBS:
        start=None
        for n in range(1,401):
            row=indexed[limb,n]
            if row['pre_contact'] and not row['post_contact']:
                require(start is None, 'V41_LOSS_OVERLAP'); start=n
            if start is not None and (row['post_contact'] or n==400):
                onset=indexed[limb,start]; after=indexed.get((limb,start+1))
                end=n if row['post_contact'] else None
                losses.append(dict(limb=limb,loss_trace_local=start,recontact_trace_local=end,
                    observed_absent_trace_count=(end-start if end is not None else 401-start),
                    onset_phase=onset['scheduled_phase_step'],onset_scheduled_stance=onset['scheduled_phase_step']>72,
                    onset_clamped_joints=onset['speed_clamped_joint_count'],
                    first_following_command_clamped_joints=None if after is None else after['speed_clamped_joint_count'],
                    first_following_command_goal_transition=None if after is None else after['goal_transition'],
                    measured_onset_response=onset['measured_response_decomposition'],
                    loss_to_recontact_motion=tracking.decompose(limb,start,end if end is not None else 400,native,bodies,dimensions,axis)))
                start=None
    stance=[r for r in losses if r['onset_scheduled_stance']]
    transitions=[r for r in timeline if r['goal_transition'] and r['goal_transition']['mask_changed']]
    per_limb=[]
    for limb in geometry.LIMBS:
        ls=[r for r in losses if r['limb']==limb]; ss=[r for r in ls if r['onset_scheduled_stance']]
        per_limb.append(dict(limb=limb,contact_losses=len(ls),stance_onsets=len(ss),
            stance_onsets_without_clipping=sum(r['onset_clamped_joints']==0 for r in ss),
            stance_losses_followed_by_clipping=sum((r['first_following_command_clamped_joints'] or 0)>0 for r in ss),
            one_step_losses=sum(r['recontact_trace_local']==r['loss_trace_local']+1 for r in ls),
            open_losses=[r['loss_trace_local'] for r in ls if r['recontact_trace_local'] is None]))
    return dict(command_count=len(entries),limb_command_count=len(timeline),joint_command_count=8*len(entries),
        original_walking_evaluation=observed['original_walking_evaluation'],
        reconstruction_maximum_errors=errors,coordinate_conversion_maximum_axis_difference=frame_error,
        contact_loss_count=len(losses),stance_loss_count=len(stance),
        stance_onsets_without_clipping=sum(r['onset_clamped_joints']==0 for r in stance),
        stance_losses_followed_by_clipping=sum((r['first_following_command_clamped_joints'] or 0)>0 for r in stance),
        selector_limb_transition_count=len(transitions),
        selector_only_goal_change_at_current_input_rad={joint:spread(r['goal_transition']['selector_change_at_current_pose_and_wave_rad'][i] for r in transitions) for i,joint in enumerate(('hip','knee'))},
        per_limb=per_limb,all_contact_losses=losses,all_limb_command_timeline=timeline)


def observe():
    path=ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json');raw=path.read_bytes()
    require(digest(raw)==CLOSURE_SHA, 'V41_LOSS_CLOSURE_DRIFT')
    closure=json.loads(raw); identity=closure['kicked_report']; report_raw=Path(identity['path']).read_bytes()
    require(digest(report_raw)==identity['raw_sha256']==REPORT_SHA and len(report_raw)==identity['byte_length'], 'V41_LOSS_REPORT_DRIFT')
    require(closure['original_attempt_and_all_independent_replays_passed'] is True
            and closure['candidate_id']=='v41-upright-stance-integrated-v2', 'V41_LOSS_VALIDATED_CLOSURE')
    return dict(schema_version='sporespore_development_v41_contact_loss_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(),raw_sha256=digest(raw)),source_report=identity,
        analysis_sources=[dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        diagnosis=summarize(json.loads(report_raw)),
        selection_rule='All 400 commands, all 1600 limb inputs, and every loss of original contact including one-step and open losses. Stance is the existing scheduled phase >72; no new contact threshold or selected control window.',
        limits='Command n consumes trace n-1. Foot positions are distal-body origins, not contact points. Nominal capsule bottoms and ideal-hinge decompositions are not contact predicates, measured contact force, or causal interventions. Selector contrasts hold saved pose and wave fixed and use both substitution orders; they do not predict a different physical trajectory. Speed clipping is a command observation, not delivered impulse adequacy. Trace 400 has no next body/joint input. Original evaluation and all failures remain unchanged.',
        original_evaluation_changed=False,physical_cause_proven=False,alternate_physical_outcome_predicted=False,
        native_controller_call_count=0,new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        physical_acceptance_authority=False,release_authority=False)


def compact(full,output):
    raw=output.read_bytes()
    return dict(full,diagnosis={k:v for k,v in full['diagnosis'].items() if k not in ('all_limb_command_timeline','all_contact_losses')},
        complete_diagnosis=dict(path=output.as_posix(),byte_length=len(raw),raw_sha256=digest(raw)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,required=True)
    output=parser.parse_args().output.resolve()
    require(output.is_relative_to(EVIDENCE.resolve()), 'V41_LOSS_DURABLE_OUTPUT_REQUIRED')
    full=observe()
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(full,stream,indent=2,allow_nan=False);stream.write('\n')
    print(json.dumps(compact(full,output),indent=2,allow_nan=False))
