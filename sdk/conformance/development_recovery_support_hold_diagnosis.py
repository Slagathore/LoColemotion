"""V43 retained geometry and V44 independent reference algebra, never a rollout.

Use all 176 available precommand states. Foot-body origins are not soles;
capsule geometry is descriptive and never replaces the actual contact signal.
"""
import math
import statistics
import development_recovery_v43_invalid_checkpoint as source
import development_recovery_v28_contact_geometry as geometry
import development_recovery_upright_stance_precheck as pre


def dimensions(report):
    d=report['passive_entry']['walking_runtime_preflight']['configuration']['base_descriptor']
    upper=.35*d['upper_length_fraction']
    return upper,.35-upper,.04*d['foot_radius_scale'],d['hip_span_scale']


def command(entry, references, dims, held):
    """Current hold mode is applied to BOTH wave evaluations; no pose override."""
    s=entry['native_output']['actuation']['receipt']['recovery_support_plane']
    pose,_=pre.cold.algebra.inputs(entry)
    wave=pre.snapshot(s['wave_velocity']['current_wave']);prior=s['wave_velocity']['previous_wave']
    mask=[True]*4 if held else [l['upright_reference_selected'] for l in s['upright_stance']['ordered_limbs']]
    def goals(w):
        if held: w=dict(w,limbs=[(angle,0.,phase) for angle,_,phase in w['limbs']])
        return pre.goals(pose,w,dims,mask)[0]
    active=prior is not None and prior['active'] and wave['active'];dt=s['reference_step_duration_s']
    desired=goals(wave);comparison_goals=goals(pre.snapshot(prior)) if active else desired
    old=entry['native_output']['actuation']['ordered_commands'];caps=[c['maximum_target_speed_rad_s'] for c in old]
    targets=pre.cold.algebra.bounded_targets(desired,references,caps,dt)
    comparison=pre.cold.algebra.bounded_targets(comparison_goals,references,caps,dt) if active else targets
    commands=[]
    for i,cap in enumerate(caps):
        j=entry['request']['state']['ordered_joint_observations'][i];c=entry['request']['state']['ordered_contact_observations'][i//2]
        absent=c['presence'] is False and c['bears_support'] is False
        numerator=targets[i]-(references[i] if absent else comparison[i])
        rate=pre.cold.algebra.clamp(numerator/dt,-cap,cap) if active and dt>0 else 0.
        raw=8*(targets[i]-j['position_rad'])-.65*j['velocity_rad_s']+1.65*rate
        commands.append(dict(goal_rad=desired[i],target_rad=targets[i],reference_rate_rad_s=rate,
            motor_velocity_rad_s=-pre.cold.algebra.clamp(raw,-cap,cap),saturated=abs(raw)>cap))
    return dict(targets_rad=targets,commands=commands)


def summarize(report):
    original=source.summarize(report);dims=dimensions(report);rows=[];frame_errors=[]
    entries=report['development_walking_entry']['rows']
    native={int(r['session_local_step']):r['native_source'] for r in report['development_native_walking_contacts']['rows'] if r['segment_id']=='walking_resume'}
    source.require(set(native)==set(range(1,177)),'HOLD_GEOMETRY_POPULATION')
    for entry in entries:
        n=int(entry['session_local_step']);sample=native[n];torso=sample['observation']['state']['base_pose_world']
        trace=sample['precommand_trace'];bodies={b['body_id']:b['pose_world'] for b in entry['ordered_body_states']}
        source.require(entry['measured_global_step']==trace['global_semantic_step']==857+n,'HOLD_GEOMETRY_TIME')
        source.require(geometry.vector(torso['position_m'])==geometry.vector(bodies['torso']['position_m'])==trace['torso_position_world_m'],'HOLD_GEOMETRY_POSITION')
        for a,b in (([1,0,0],[0,0,1]),([0,1,0],[0,1,0]),([0,0,1],[-1,0,0])):
            frame_errors.append(math.dist(geometry.rotate(torso['orientation_xyzw'],a),geometry.rotate(bodies['torso']['orientation_xyzw'],b)))
        s=entry['native_output']['actuation']['receipt']['recovery_support_plane'];held=s['support_progression']['phase_progression_held']
        for i,limb in enumerate(geometry.LIMBS):
            body=bodies[limb+'_distal'];center=geometry.vector(body['position_m'])
            source.require(center==trace['foot_position_world_m_by_limb'][limb],'HOLD_GEOMETRY_DISTAL_ORIGIN')
            bottom=center[1]-abs(geometry.rotate(body['orientation_xyzw'],[0,1,0])[1])*dims[1]/2-dims[2]
            joints=[j['position_rad'] for j in entry['request']['state']['ordered_joint_observations'][2*i:2*i+2]]
            motors=entry['native_output']['actuation']['ordered_commands'][2*i:2*i+2];targets=[m['requested_target_position_rad'] for m in motors]
            p=s['ordered_limb_proposals'][i];upright=s['upright_stance']['floor_upright_reference_proposals'][i];measured=s['upright_stance']['measured_pose_baseline_proposals'][i]
            rows.append(dict(command_local=n,limb=limb,actual_contact=trace['contact_by_limb'][limb],held=held,
                torso_tilt_rad=trace['torso_tilt_rad'],nominal_measured_capsule_bottom_m=bottom,
                ideal_measured_bottom_error_m=geometry.ideal_distal(torso,limb,*joints,*dims)[1]-bottom,
                current_target_fixed_pose_bottom_m=geometry.ideal_distal(torso,limb,*targets,*dims)[1],
                measured_pose_support_only_bottom_m=geometry.ideal_distal(torso,limb,measured['projected_support_hip_rad'],measured['projected_support_knee_rad'],*dims)[1],
                proposed_upright_no_lift_fixed_pose_bottom_m=geometry.ideal_distal(torso,limb,upright['projected_support_hip_rad'],upright['projected_support_knee_rad'],*dims)[1],
                precommand_vs_current_target_maximum_joint_error_rad=max(abs(a-b) for a,b in zip(joints,targets)),
                measured_joint_rad=joints,current_target_rad=targets,
                position_or_velocity_or_slew_limited=any(m['position_saturated'] or m['velocity_saturated'] or m['slew_limited'] for m in motors),
                scheduled_knee_lift_fraction=p['walking_knee_fraction']))
    def spread(pop,key):
        values=[r[key] for r in pop]
        return dict(minimum=min(values),mean=statistics.mean(values),maximum=max(values))
    final_hold=[r for r in rows if r['limb']=='rear_right' and r['command_local']>=57]
    return dict(original_checkpoint=original,precommand_count=len(entries),limb_sample_count=len(rows),
        frame_axis_maximum_difference=max(frame_errors),ideal_measured_bottom_maximum_absolute_error_m=max(abs(r['ideal_measured_bottom_error_m']) for r in rows),
        final_rear_right_hold=dict(first_command=57,last_command=176,count=len(final_hold),
            contact_samples=sum(r['actual_contact'] for r in final_hold),
            capsule_bottom_m=spread(final_hold,'nominal_measured_capsule_bottom_m'),tilt_rad=spread(final_hold,'torso_tilt_rad')),
        last_precommand=[r for r in rows if r['command_local']==176],all_limb_samples=rows,
        limitations='All available precommand samples, not the missing failed command. Capsule bottom is nominal shape geometry, not a contact predicate. Target geometry and held-input algebra are not another physical trajectory or causal proof. Original invalid result and evaluator non-invocation remain unchanged.',
        new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        physical_outcome_predicted=False,physical_acceptance_authority=False,release_authority=False)
