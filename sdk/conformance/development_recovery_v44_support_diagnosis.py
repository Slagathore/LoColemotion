"""Describe V44's completed support holds and contact losses from retained data.

No native calls, new trajectory, contact redefinition, or evaluator replacement.
The original evaluator measures relocation from the FIRST ABSENT post-step row.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics

import development_recovery_support_hold_diagnosis as algebra
import development_recovery_v42_relocation_diagnosis as events

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = 'b308b58a36144525866e2f96b2abe0be'
SOURCE = '50c7679041ca1d239af06b99e6ac308b3bc6dee5'
REPORT_SHA = 'sha256:287d1b26e7ed6162141b1a69c2e8c012c26f228affaa6d2450155a791327da70'
CLOSURE_SHA = 'sha256:0b1f0745dcad674de7a494fc14c8cbf2b803594fccba188058cc85045e4e5864'
RECORD = ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json')
LIMBS = events.LIMBS
geometry = algebra.geometry


def require(condition, code):
    if not condition:
        raise ValueError('V44_SUPPORT_' + code)


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def report():
    raw = RECORD.read_bytes()
    require(digest(raw) == CLOSURE_SHA, 'CLOSURE_BINDING')
    closure = json.loads(raw)
    require(closure['original_attempt_and_all_independent_replays_passed'] is True,
            'ORIGINAL_REPLAYS')
    identity = closure['kicked_report']
    raw = Path(identity['path']).read_bytes()
    require(digest(raw) == identity['raw_sha256'] == REPORT_SHA
            and len(raw) == identity['byte_length'], 'REPORT_BINDING')
    return json.loads(raw)


def summarize(value):
    require(value['ok'] is True and value['status'] == 'development_smoke_complete'
            and value['source_commit'] == SOURCE and value['parent_attempt_id'] == ATTEMPT
            and value['solver_step_count'] == 1258 and value['world_build_count'] == 1,
            'COMPLETE_IDENTITY')
    arm = value['retained_arm']
    session = next(s for s in arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    evaluation = session['evaluation']
    require(evaluation['evidence_valid'] is True and evaluation['behavior_passed'] is False
            and evaluation['false_walking_receipts'] == ['every_limb_forward_relocation', 'terminal_four_contact_recovery']
            and evaluation['fixed_thresholds']['minimum_foot_relocation_m'] == .012
            and evaluation['fixed_thresholds']['minimum_airborne_dwell_steps'] == 3, 'ORIGINAL_EVALUATION')
    entries = value['development_walking_entry']['rows']
    native = [r for r in value['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume']
    traces = [r for r in arm['trace_rows'] if r.get('walking_session_id') == session['session_id']]
    require(len(entries) == len(native) == len(traces) == 400, 'POPULATION')
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    dims = algebra.dimensions(value)
    timeline, windows = [], []
    first_hold = None
    maximum_motor_error = maximum_frame_error = 0.
    initial = native[0]['native_source']['precommand_trace']['contact_by_limb']
    indexed = {}
    for n, (entry, contact_row, post) in enumerate(zip(entries, native, traces), 1):
        source = contact_row['native_source']
        pre = source['precommand_trace']
        state = entry['request']['state']
        output = entry['native_output']
        support = output['actuation']['receipt']['recovery_support_plane']
        guard = support['support_progression']
        held = guard['phase_progression_held']
        require(entry['session_local_step'] == contact_row['session_local_step'] == post['walking_session_local_step'] == n
                and entry['measured_global_step'] == pre['global_semantic_step'] == 857+n
                and entry['commanded_global_step'] == post['global_semantic_step'] == 858+n, 'CLOCK')
        if n > 1:
            require(entry['request']['memory'] == entries[n-2]['native_output']['next_memory'], 'MEMORY')
            for key in ('contact_by_limb', 'foot_position_world_m_by_limb', 'torso_position_world_m'):
                require(pre[key] == traces[n-2][key], 'PRE_POST_LINK')
        require(guard['incoming_memory'] == entry['request']['memory']['support_progression']
                and guard['next_memory'] == output['next_memory']['support_progression']
                and guard['maximum_held_commands'] == 120 and guard['minimum_clear_dwell_steps'] == 3,
                'GUARD_MEMORY')
        posture = support['support_hold_posture']
        require(posture['enabled'] is held and posture['scheduled_wave_memory_preserved'] is True
                and posture['measured_pose_and_contact_preserved'] is True, 'POSTURE_MODE')
        if held and first_hold is None:
            first_hold = n
        if first_hold is not None and (not held or n == 400):
            end = n-1 if not held else n
            windows.append(dict(first_command=first_hold, last_held_command=end,
                held_command_count=end-first_hold+1, released=not held,
                release_command=n if not held else None))
            first_hold = None
        reference = entry['request']['memory']['support_reference']['ordered_target_positions_rad']
        computed = algebra.command(entry, reference, dims, held)
        commands = output['actuation']['ordered_commands']
        for index, (a, b) in enumerate(zip(computed['commands'], commands)):
            error = abs(a['motor_velocity_rad_s'] - b['target_velocity_rad_s'])
            maximum_motor_error = max(maximum_motor_error, error)
            require(error < 1e-10 and abs(a['target_rad']-b['requested_target_position_rad']) < 1e-12
                    and abs(a['reference_rate_rad_s']-support['ordered_reference_velocity_rad_s'][index]) < 1e-10
                    and a['saturated'] == b['velocity_saturated'], 'MOTOR_RECONSTRUCTION')
            application = entry['ordered_motor_applications'][index]
            require(application['actuator_id'] == b['actuator_id']
                    and application['host_applied_target_velocity_rad_s'] == b['target_velocity_rad_s']
                    and application['host_additional_clamp_applied'] is False, 'APPLIED_COMMAND')
        torso = source['observation']['state']['base_pose_world']
        bodies = {b['body_id']: b['pose_world'] for b in entry['ordered_body_states']}
        require(geometry.vector(torso['position_m']) == geometry.vector(bodies['torso']['position_m']) == pre['torso_position_world_m'], 'TORSO_POSITION')
        for a, b in (([1,0,0],[0,0,1]), ([0,1,0],[0,1,0]), ([0,0,1],[-1,0,0])):
            error = math.dist(geometry.rotate(torso['orientation_xyzw'],a), geometry.rotate(bodies['torso']['orientation_xyzw'],b))
            maximum_frame_error = max(maximum_frame_error,error)
            # Engineering frame-conversion guard: accumulated binary32 rounding,
            # not a physical alignment threshold or a contact tolerance.
            require(error < 16*2**-23, 'TORSO_FRAME')
        require(support['upright_stance']['source_floor_reference']['height_world_m'] == 0., 'FLOOR')
        wave = support['wave_velocity']['current_wave']
        for i, limb in enumerate(LIMBS):
            c = state['ordered_contact_observations'][i]
            phase = wave['ordered_limbs'][i]['scheduled_phase_step']
            require(c == contact_row['controller_contacts'][i]
                    and c['presence'] == c['bears_support'] == pre['contact_by_limb'][limb], 'CONTACT_LINK')
            body = bodies[limb+'_distal']
            require(geometry.vector(body['position_m']) == pre['foot_position_world_m_by_limb'][limb], 'DISTAL_ORIGIN')
            bottom = body['position_m']['y'] - abs(geometry.rotate(body['orientation_xyzw'],[0,1,0])[1])*dims[1]/2-dims[2]
            joints = [j['position_rad'] for j in state['ordered_joint_observations'][2*i:2*i+2]]
            targets = [m['requested_target_position_rad'] for m in commands[2*i:2*i+2]]
            raw = [c for c in source['contact_source_receipt']['ordered_contact_samples'] if c['body_id'] == limb+'_distal']
            row = dict(command_local=n, limb=limb, held=held, scheduled_phase_step=phase,
                scheduled_stance=wave['active'] and phase>72, pre_contact=c['bears_support'], post_contact=post['contact_by_limb'][limb],
                nominal_measured_capsule_bottom_m=bottom,
                nominal_joint_geometry_bottom_error_m=geometry.ideal_distal(torso,limb,*joints,*dims)[1]-bottom,
                current_target_fixed_pose_bottom_m=geometry.ideal_distal(torso,limb,*targets,*dims)[1],
                target_error_rad=max(abs(x-y) for x,y in zip(joints,targets)),
                speed_clipped_joint_count=sum(m['velocity_saturated'] for m in commands[2*i:2*i+2]),
                raw_contact_sample_count=len(raw), raw_foot_contact_sample_count=sum(c['classified_as_foot'] for c in raw),
                bearing_normal_impulse_ns=source['observation']['ordered_foot_bearing_observations'][i]['bearing_normal_impulse_ns'])
            timeline.append(row); indexed[limb,n] = row
    losses, per_limb = [], []
    for limb in LIMBS:
        population = [r for r in timeline if r['limb'] == limb]
        absent = [r for r in population if r['scheduled_stance'] and not r['pre_contact']]
        limb_losses = []
        for first, last in events.loss_intervals(initial[limb],traces,limb):
            stop = last or 400
            commands = [indexed[limb,n] for n in range(first,stop+1)]
            a,b = traces[first-1],traces[stop-1]
            distance = events.dot(events.subtract(b['foot_position_world_m_by_limb'][limb],a['foot_position_world_m_by_limb'][limb]),axis)
            count = last-first if last is not None else 401-first
            limb_losses.append(dict(limb=limb, loss_trace_local=first, recontact_trace_local=last,
                absent_post_step_count=count, onset_scheduled_stance=commands[0]['scheduled_stance'],
                original_evaluator_counted_cycle=last is not None and count>=3,
                forward_displacement_to_recontact_or_endpoint_m=distance,
                held_command_count=sum(c['held'] for c in commands),
                speed_clipped_joint_commands=sum(c['speed_clipped_joint_count'] for c in commands)))
        counted = [r for r in limb_losses if r['original_evaluator_counted_cycle']]
        minimum = min(r['forward_displacement_to_recontact_or_endpoint_m'] for r in counted)
        require(len(counted) == evaluation['contact_cycle_count_by_limb'][limb]
                and abs(minimum-evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb]) < 1e-12
                and any(r['recontact_trace_local'] is None for r in limb_losses) == evaluation['observed_flight_open_at_end_by_limb'][limb], 'ORIGINAL_CYCLES')
        per_limb.append(dict(limb=limb, supported_precommand_count=sum(r['pre_contact'] for r in population),
            absent_scheduled_stance_precommand_count=len(absent),
            absent_stance_nominal_bottom_m=dict(minimum=min(r['nominal_measured_capsule_bottom_m'] for r in absent),
                maximum=max(r['nominal_measured_capsule_bottom_m'] for r in absent),
                mean=statistics.mean(r['nominal_measured_capsule_bottom_m'] for r in absent)),
            absent_stance_with_raw_contacts=sum(r['raw_contact_sample_count']>0 for r in absent),
            counted_cycles=len(counted), backward_cycles=sum(r['forward_displacement_to_recontact_or_endpoint_m']<0 for r in counted),
            cycles_below_original_12mm_minimum=sum(r['forward_displacement_to_recontact_or_endpoint_m']<.012 for r in counted),
            minimum_original_cycle_forward_relocation_m=minimum))
        losses.extend(limb_losses)
    return dict(command_count=400, limb_sample_count=len(timeline), joint_command_count=3200,
        held_command_count=sum(w['held_command_count'] for w in windows), released_hold_count=sum(w['released'] for w in windows),
        maximum_held_window_commands=max(w['held_command_count'] for w in windows), hold_windows=windows,
        maximum_motor_reconstruction_error_rad_s=maximum_motor_error, maximum_frame_axis_error=maximum_frame_error,
        maximum_absolute_nominal_joint_geometry_bottom_error_m=max(abs(r['nominal_joint_geometry_bottom_error_m']) for r in timeline),
        original_walking_evaluation=evaluation, per_limb=per_limb, all_contact_losses=losses,
        contact_loss_count=len(losses), stance_onset_loss_count=sum(r['onset_scheduled_stance'] for r in losses),
        terminal_postcommand_contacts=traces[-1]['contact_by_limb'], all_limb_samples=timeline)


def observe():
    value = report()
    return dict(schema_version='sporespore_development_v44_support_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        source_closure=dict(path=RECORD.relative_to(ROOT).as_posix(),raw_sha256=CLOSURE_SHA),
        source_report=json.loads(RECORD.read_bytes())['kicked_report'], diagnosis=summarize(value),
        analysis_sources=[dict(path=p,raw_sha256=digest((ROOT/p).read_bytes())) for p in dict.fromkeys((*events.ANALYSIS_PATHS,*algebra.pre.ANALYSIS_PATHS,'sdk/conformance/development_recovery_support_hold_diagnosis.py','sdk/conformance/development_recovery_v28_contact_geometry.py','sdk/conformance/development_recovery_v44_support_diagnosis.py','tests/test_development_v44_support_diagnosis.py'))],
        limitations='All 400 completed commands and all contact losses, including brief and open losses. Original cycle relocation starts at the first absent post-step sample. Capsule geometry is nominal and does not replace contact. Fixed-pose target geometry is not a second trajectory. The observed hold releases are not a matched controller effect or successful walking claim. Native command values precede host binary32 readback rounding.',
        next_question='Bound and run one MuJoCo replay of the retained canonical command sequence with explicit recovery-model, material, initial-state projection, actuator and contact correspondence. Diagnose discrepancies before another controller variant; no engine-equivalence or Jolt-defect inference from this screen alone.',
        original_evaluation_changed=False, causal_attribution_proven=False,
        new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,native_controller_call_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    output=parser.parse_args().output.resolve()
    require(output.is_relative_to((ROOT.parent/'SporeSpore_Evidence').resolve()),'DURABLE_OUTPUT')
    full=observe()
    with output.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(full,stream,indent=2,allow_nan=False);stream.write('\n')
    compact=dict(full,diagnosis={k:v for k,v in full['diagnosis'].items() if k!='all_limb_samples'},
        complete_diagnosis=dict(path=output.as_posix(),byte_length=output.stat().st_size,raw_sha256=digest(output.read_bytes())))
    print(json.dumps(compact,indent=2,allow_nan=False))
