"""Describe every V42 contact loss and reproduce the original cycle numbers.

No new evaluator, native call or alternate trajectory. Commands use pre-step
observations; measured losses and landings use post-step traces. Motion terms
are coordinate identities, not causal shares of a physical intervention.
"""
import argparse
import json
import math
from pathlib import Path

import development_recovery_stance_latch_precheck as sketch

ROOT = sketch.data.ROOT
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
geometry = sketch.pre.geometry
require, digest = sketch.require, sketch.digest
LIMBS = geometry.LIMBS
ATTEMPT = '6514ace221e547c6b7b69e2d6bbdebaa'
SOURCE = 'ee6d83fb8306ef0677c1e4008f23ef15cc219e3c'
CLOSURE_SHA = 'sha256:9a24db850c215026f91dced4b93622c0f21d2d4bbd580fa099ba53ea41bb7bad'
REPORT_SHA = 'sha256:5aa35dbe98a1c96894eb1cd5694cd26a91c5d6c8d53911caabb8f2ffab3084e4'
ANALYSIS_PATHS = tuple(dict.fromkeys((*sketch.ANALYSIS_PATHS,
    'sdk/conformance/development_recovery_v42_relocation_diagnosis.py',
    'tests/test_development_v42_relocation_diagnosis.py',
    'sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd')))


def subtract(a, b):
    return [x-y for x, y in zip(a, b)]


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def measured_motion(a, b, foot_a, foot_b, axis):
    """Both rotation/relative-motion orders, using measured distal origins.

    foot = torso_position + torso_rotation * body_relative_foot. Relative
    motion includes articulation and constraint compliance, not just joints.
    """
    pa, pb = (geometry.vector(p['position_m']) for p in (a, b))
    qa, qb = (p['orientation_xyzw'] for p in (a, b))
    for q in (qa, qb):
        require(all(math.isfinite(q[k]) for k in 'xyzw') and
                sum(q[k]*q[k] for k in 'xyzw') > 0, 'V42_RELOCATION_QUATERNION')
    inverse = lambda q: {k: q[k] if k == 'w' else -q[k] for k in 'xyzw'}
    ra = geometry.rotate(inverse(qa), subtract(foot_a, pa))
    rb = geometry.rotate(inverse(qb), subtract(foot_b, pb))
    translation = subtract(pb, pa)
    actual = subtract(foot_b, foot_a)
    orders = []
    for label, fixed, moving_q in (('rotation_first', ra, qb), ('relative_motion_first', rb, qa)):
        rotation = subtract(geometry.rotate(qb, fixed), geometry.rotate(qa, fixed))
        relative = geometry.rotate(moving_q, subtract(rb, ra))
        error = max(abs(actual[i]-translation[i]-rotation[i]-relative[i]) for i in range(3))
        require(error < 1e-12, 'V42_RELOCATION_DECOMPOSITION')
        orders.append(dict(order=label, torso_translation_forward_m=dot(translation, axis),
            torso_rotation_forward_m=dot(rotation, axis), body_relative_motion_forward_m=dot(relative, axis),
            maximum_vector_identity_error_m=error))
    fa, fb = (geometry.rotate(q, [1, 0, 0]) for q in (qa, qb))
    # Signed heading change in this host Y-up frame; no roll/pitch conflation.
    yaw = math.atan2(fa[2]*fb[0]-fa[0]*fb[2], fa[0]*fb[0]+fa[2]*fb[2])
    return dict(available=True, actual_forward_m=dot(actual, axis),
        signed_heading_change_rad=yaw, ordered_decompositions=orders)


def loss_intervals(initial, rows, limb):
    """Include brief/open losses. Never invent liftoff for initial absence."""
    previous = initial
    start = None
    events = []
    for n, row in enumerate(rows, 1):
        now = row['contact_by_limb'][limb]
        require(type(now) is bool, 'V42_RELOCATION_CONTACT_TYPE')
        if previous and not now:
            require(start is None, 'V42_RELOCATION_OVERLAP')
            start = n
        if start is not None and (now or n == len(rows)):
            events.append((start, n if now else None))
            start = None
        previous = now
    return events


def summarize(report):
    require(report['source_commit'] == SOURCE, 'V42_RELOCATION_SOURCE')
    entries = report['development_walking_entry']['rows']
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    traces = [r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id') == session['session_id']]
    native = [r for r in report['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume']
    require(len(entries) == len(traces) == len(native) == 400, 'V42_RELOCATION_POPULATION')
    for rows, key in ((entries, 'session_local_step'), (traces, 'walking_session_local_step'), (native, 'session_local_step')):
        require([r[key] for r in rows] == list(range(1, 401)), 'V42_RELOCATION_ORDER')
    sources = [n['native_source'] for n in native]
    initial = sources[0]['precommand_trace']['contact_by_limb']
    require(all(initial[l] is True for l in LIMBS), 'V42_RELOCATION_INITIAL_CONTACT')
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    evaluation = session['evaluation']
    require(evaluation['fixed_thresholds']['minimum_airborne_dwell_steps'] == 3 and
            evaluation['fixed_thresholds']['minimum_foot_relocation_m'] == .012, 'V42_RELOCATION_ORIGINAL_THRESHOLDS')
    d = report['configuration']['base_descriptor']
    upper = .35*d['upper_length_fraction']
    dims = upper, .35-upper, .04*d['foot_radius_scale'], d['hip_span_scale']
    timeline, indexed = [], {}
    maximum_motor_error = 0.
    for n, (entry, trace, source) in enumerate(zip(entries, traces, sources), 1):
        pretrace = source['precommand_trace']
        state = entry['request']['state']
        actuation = entry['native_output']['actuation']
        support = actuation['receipt']['recovery_support_plane']
        wave = support['wave_velocity']['current_wave']
        prior = support['wave_velocity']['previous_wave']
        memory = entry['request']['memory']['support_reference']
        require(entry['measured_global_step'] == pretrace['global_semantic_step'] == 857+n and
                entry['commanded_global_step'] == trace['global_semantic_step'] == 858+n,
                'V42_RELOCATION_GLOBAL_ALIGNMENT')
        if n > 1:
            require(entry['request']['memory'] == entries[n-2]['native_output']['next_memory'], 'V42_RELOCATION_MEMORY_LINK')
            for key in ('contact_by_limb', 'foot_position_world_m_by_limb', 'torso_position_world_m', 'torso_forward_axis_world_unit'):
                require(pretrace[key] == traces[n-2][key], 'V42_RELOCATION_PRE_POST_ALIGNMENT')
        mask = [r['next_upright_reference_latched'] for r in support['stance_latch']['ordered_limbs']]
        calculated = sketch.command(entry, memory['ordered_target_positions_rad'], dims, mask)
        for j, (computed, command) in enumerate(zip(calculated['motors'], actuation['ordered_commands'])):
            error = abs(computed['host_motor_velocity_rad_s']-command['target_velocity_rad_s'])
            maximum_motor_error = max(maximum_motor_error, error)
            require(error < 1e-10 and abs(computed['target_rad']-command['requested_target_position_rad']) < 1e-12 and
                    abs(computed['reference_rate_rad_s']-support['ordered_reference_velocity_rad_s'][j]) < 1e-10,
                    'V42_RELOCATION_COMMAND_RECONSTRUCTION')
            require(computed['saturated'] == command['velocity_saturated'], 'V42_RELOCATION_CLIPPING')
        for i, limb in enumerate(LIMBS):
            contact = state['ordered_contact_observations'][i]
            phase = wave['ordered_limbs'][i]['scheduled_phase_step']
            latch = support['stance_latch']['ordered_limbs'][i]
            require(latch['limb_id'] == limb and latch['current_scheduled_phase_step'] == phase and
                    latch['precommand_contact'] == contact and contact['presence'] == contact['bears_support'] == pretrace['contact_by_limb'][limb],
                    'V42_RELOCATION_CONTACT_PHASE_BINDING')
            expected = sketch.select(wave['active'], phase, contact['presence'], contact['bears_support'],
                prior['active'] if prior else False, prior['ordered_limbs'][i]['scheduled_phase_step'] if prior else None,
                memory['ordered_stance_latches'][i]['upright_reference_latched'])
            require(mask[i] == expected, 'V42_RELOCATION_LATCH')
            commands = actuation['ordered_commands'][2*i:2*i+2]
            joints = state['ordered_joint_observations'][2*i:2*i+2]
            row = dict(command_local=n, pre_trace_local=n-1, post_trace_local=n, limb=limb,
                scheduled_phase_step=phase, wave_active=wave['active'],
                scheduled_stance=wave['active'] and phase > 72,
                pre_contact=contact['presence'], post_contact=trace['contact_by_limb'][limb],
                upright_reference_latched=mask[i],
                reference_rate_input='full_reference_change' if not contact['presence'] else 'same_current_mask_wave_change',
                goals_rad=support['upright_stance']['ordered_selected_goals_rad'][2*i:2*i+2],
                targets_rad=[c['requested_target_position_rad'] for c in commands],
                measured_joint_rad=[j['position_rad'] for j in joints],
                reference_rates_rad_s=support['ordered_reference_velocity_rad_s'][2*i:2*i+2],
                host_motor_rates_rad_s=[c['target_velocity_rad_s'] for c in commands],
                speed_clamped_joint_count=sum(c['velocity_saturated'] for c in commands))
            timeline.append(row)
            indexed[limb, n] = row
    events, per_limb = [], []
    for limb in LIMBS:
        limb_events = []
        for start, end in loss_intervals(initial[limb], traces, limb):
            stop = end or 400
            commands = [indexed[limb, n] for n in range(start, stop+1)]
            a, b = traces[start-1], traces[stop-1]
            foot_a, foot_b = (t['foot_position_world_m_by_limb'][limb] for t in (a, b))
            displacement = dot(subtract(foot_b, foot_a), axis)
            # Trace 400 has no next precommand native torso orientation.
            motion = (measured_motion(sources[start]['observation']['state']['base_pose_world'],
                sources[stop]['observation']['state']['base_pose_world'], foot_a, foot_b, axis)
                if stop < 400 else dict(available=False, reason='No retained next-command torso pose at trace 400.'))
            absent = end-start if end is not None else 401-start
            event = dict(limb=limb, loss_trace_local=start, recontact_trace_local=end,
                loss_global_step=858+start, recontact_global_step=None if end is None else 858+end,
                observed_absent_trace_count=absent, original_evaluator_counted_cycle=end is not None and absent >= 3,
                forward_displacement_to_recontact_or_endpoint_m=displacement,
                onset_scheduled_phase_step=commands[0]['scheduled_phase_step'],
                end_scheduled_phase_step=commands[-1]['scheduled_phase_step'],
                onset_scheduled_stance=commands[0]['scheduled_stance'],
                all_interval_commands_scheduled_stance=all(c['scheduled_stance'] for c in commands),
                onset_speed_clamped_joints=commands[0]['speed_clamped_joint_count'],
                interval_speed_clamped_joint_commands=sum(c['speed_clamped_joint_count'] for c in commands),
                interval_latched_absent_inputs=sum(c['upright_reference_latched'] and not c['pre_contact'] for c in commands),
                interval_command_count=len(commands), measured_motion=motion)
            limb_events.append(event)
        completed = [e for e in limb_events if e['original_evaluator_counted_cycle']]
        minimum = min(e['forward_displacement_to_recontact_or_endpoint_m'] for e in completed)
        require(len(completed) == evaluation['contact_cycle_count_by_limb'][limb] and
                abs(minimum-evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb]) < 1e-12 and
                any(e['recontact_trace_local'] is None for e in limb_events) == evaluation['observed_flight_open_at_end_by_limb'][limb],
                'V42_RELOCATION_ORIGINAL_CYCLE_RECONSTRUCTION')
        per_limb.append(dict(limb=limb, all_contact_losses=len(limb_events), counted_cycles=len(completed),
            counted_backward_cycles=sum(e['forward_displacement_to_recontact_or_endpoint_m'] < 0 for e in completed),
            counted_cycles_below_original_minimum=sum(e['forward_displacement_to_recontact_or_endpoint_m'] < .012 for e in completed),
            minimum_counted_forward_relocation_m=minimum))
        events.extend(limb_events)
    return dict(command_count=400, limb_command_count=len(timeline), joint_command_count=3200,
        original_walking_evaluation=evaluation, maximum_motor_reconstruction_error_rad_s=maximum_motor_error,
        contact_loss_count=len(events), stance_onset_loss_count=sum(e['onset_scheduled_stance'] for e in events),
        counted_cycle_count=sum(e['original_evaluator_counted_cycle'] for e in events),
        per_limb=per_limb, all_contact_losses=events, all_limb_command_timeline=timeline,
        terminal_precommand=[indexed[l,400] for l in LIMBS],
        terminal_postcommand_contacts=traces[-1]['contact_by_limb'])


def observe():
    path = ROOT/'sdk/development/recovery_attempts'/(ATTEMPT+'.json')
    raw = path.read_bytes()
    require(digest(raw) == CLOSURE_SHA, 'V42_RELOCATION_CLOSURE_DRIFT')
    closure = json.loads(raw)
    identity = closure['kicked_report']
    report_raw = Path(identity['path']).read_bytes()
    require(digest(report_raw) == identity['raw_sha256'] == REPORT_SHA and
            len(report_raw) == identity['byte_length'], 'V42_RELOCATION_REPORT_DRIFT')
    require(closure['original_attempt_and_all_independent_replays_passed'] is True and
            closure['candidate_id'] == 'v42-stance-latch-integrated-v1', 'V42_RELOCATION_CLOSURE')
    return dict(schema_version='sporespore_development_v42_relocation_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        source_closure=dict(path=path.relative_to(ROOT).as_posix(), raw_sha256=digest(raw)), source_report=identity,
        analysis_sources=[dict(path=p, raw_sha256=digest((ROOT/p).read_bytes())) for p in ANALYSIS_PATHS],
        diagnosis=summarize(json.loads(report_raw)),
        selection_rule='All 400 commands, 1600 limb inputs and all observed contact losses, including brief and open losses. Original counted cycles require at least three absent post-step samples followed by recontact.',
        limits='Distal-body origins are not ground contact points. Release position is the original first absent post-step sample, not the last supported position. Motion decomposition uses measured torso rotation and body-relative distal position in both orders; it is not a causal intervention or ideal-joint model. An open flight has endpoint displacement, not a completed relocation. Trace 400 has no next-command native torso pose. Original evaluation, thresholds and failures are unchanged.',
        original_evaluation_changed=False, physical_cause_proven=False, physical_outcome_predicted=False,
        native_controller_call_count=0, new_world_build_count=0, new_solver_step_count=0, new_native_physics_read_count=0,
        physical_acceptance_authority=False, release_authority=False)


def compact(full, output):
    raw = output.read_bytes()
    return dict(full, diagnosis={k:v for k,v in full['diagnosis'].items() if k != 'all_limb_command_timeline'},
        complete_diagnosis=dict(path=output.as_posix(), byte_length=len(raw), raw_sha256=digest(raw)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    output = parser.parse_args().output.resolve()
    require(output.is_relative_to(EVIDENCE.resolve()), 'V42_RELOCATION_DURABLE_OUTPUT')
    full = observe()
    with output.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(full, stream, indent=2, allow_nan=False)
        stream.write('\n')
    print(json.dumps(compact(full, output), indent=2, allow_nan=False))
