"""Retained geometry and command sequencing; no model or alternate rollout."""
import hashlib
import math
import re
import subprocess
from pathlib import Path

import development_recovery_v28_contact_geometry as geometry

ROOT = Path(__file__).resolve().parents[2]
LIMBS = ('rear_left', 'front_left', 'rear_right', 'front_right')


def summarize(report, source_commit):
    source = subprocess.check_output(['git', 'show', source_commit+':sdk/core/src/runtime.rs'], cwd=ROOT)
    names = ('CYCLE_STEPS', 'SWING_STEPS', 'RECONTACT_GATE_LOCAL_STEP', 'MINIMUM_GATE_DWELL_STEPS',
             'MAXIMUM_GATE_HOLD_STEPS', 'MAXIMUM_PHASE_SKEW_STEPS')
    constants = {}
    for name in names:
        matches = re.findall(r'const '+name+r': u(?:32|64) = (\d+);', source.decode())
        if len(matches) != 1:
            raise ValueError('FROZEN_SCHEDULER_CONSTANT_MISSING:'+name)
        constants[name] = int(matches[0])
    measured, frame_error = geometry.reconstruct(report)
    index = {(x['limb'], x['trace_local_step']): x for x in measured}
    native = {int(x['session_local_step'])-1: x['native_source'] for x in report['development_native_walking_contacts']['rows'] if x['segment_id'] == 'walking_resume'}
    descriptor = report['configuration']['base_descriptor']
    upper = .35*descriptor['upper_length_fraction']
    args = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
    first = native[0]['observation']['state']['base_pose_world']
    baseline = index['front_left', 0]
    initial_ideal = geometry.ideal_distal(first, 'front_left', baseline['hip_rad'], baseline['knee_rad'], *args)[1]
    decomposition = []
    for local in (0, 41, 72, 90, 110, 147, 180, 200, 267, 291, 292):
        pose = native[local]['observation']['state']['base_pose_world']
        row = index['front_left', local]
        fixed = geometry.ideal_distal(pose, 'front_left', baseline['hip_rad'], baseline['knee_rad'], *args)[1]
        ideal = geometry.ideal_distal(pose, 'front_left', row['hip_rad'], row['knee_rad'], *args)[1]
        height = pose['position_m']['y']-first['position_m']['y']
        forward, up, side = (geometry.rotate(pose['orientation_xyzw'], a) for a in ([1, 0, 0], [0, 1, 0], [0, 0, 1]))
        relaxed = pose['position_m']['y']+args[3]*(.2*forward[1]-.18*side[1])-.35*math.hypot(forward[1], up[1])-args[2]
        decomposition.append(dict(trace_local_step=local, nominal_bottom_m=row['nominal_capsule_bottom_m'],
            torso_height_change_m=height, orientation_at_initial_joints_change_m=fixed-initial_ideal-height,
            joint_change_at_current_pose_m=ideal-fixed,
            ideal_constraint_residual_change_m=row['nominal_capsule_bottom_m']-ideal-baseline['nominal_capsule_bottom_m']+initial_ideal,
            relaxed_fixed_torso_minimum_bottom_m=relaxed, measured_hip_rad=row['hip_rad'], measured_knee_rad=row['knee_rad']))
    boundaries, held = {}, []
    for entry in report['development_walking_entry']['rows']:
        local = int(entry['session_local_step'])
        memory = {m['limb_id']: m for m in entry['native_output']['next_memory']['ordered_limb_memory']}
        phases = {limb: int((memory[limb]['gait_step']+360-i*90) % 360) for i, limb in enumerate(LIMBS)}
        contact = {c['contact_site_id'].removesuffix('_foot'): c['bears_support'] for c in entry['request']['state']['ordered_contact_observations']}
        event = dict(local_step=local, phases=phases, prior_measured_support=contact)
        if phases['front_left'] == constants['SWING_STEPS']:
            boundaries.setdefault('front_left_swing_end', event)
        if phases['rear_right'] == 0:
            boundaries.setdefault('rear_right_next_swing_start', event)
        if memory['front_left']['recontact_hold_step_count'] == 1:
            boundaries.setdefault('front_left_first_recontact_hold', event)
        if phases['rear_right'] == 66:
            command = next(c for c in entry['native_output']['actuation']['ordered_commands'] if c['actuator_id'] == 'rear_right_knee_motor')
            held.append(dict(local=local, bearing=contact['rear_right'], target=command['requested_target_position_rad']))
    target_values = sorted({x['target'] for x in held})
    amplitude = report['development_walking_entry']['rows'][199]['request']['command']['gait_amplitude']
    return dict(schema_version='sporespore_development_v31_recontact_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        frozen_runtime_source_commit=source_commit, frozen_runtime_source_sha256='sha256:'+hashlib.sha256(source).hexdigest(),
        scheduler_constants=constants, measured_body_sample_count=len(measured), coordinate_conversion_maximum_axis_difference=frame_error,
        front_left_vertical_decomposition=decomposition, sequence_boundaries=boundaries,
        front_left_long_raw_gap=geometry.interval_summary(measured, 'front_left', 41, 292),
        rear_right_phase_66=dict(first_local_step=held[0]['local'], last_local_step=held[-1]['local'], sample_count=len(held),
            support_count=sum(x['bearing'] for x in held), contact_switch_count=sum(a['bearing'] != b['bearing'] for a, b in zip(held, held[1:])),
            requested_knee_values_rad=target_values, target_jump_rad=target_values[1]-target_values[0],
            existing_contact_assist_at_selected_amplitude_rad=.4*amplitude),
        proposed_swing_end_plus_existing_skew=constants['SWING_STEPS']+constants['MAXIMUM_PHASE_SKEW_STEPS'],
        following_swing_offset=constants['CYCLE_STEPS']//4,
        interpretation_limit='Explicit-order geometric decomposition and observed scheduler/command relationships, not causal isolation or prediction. Fixed-torso reach omits compliance and future body motion. A new swing-end guard cannot retroactively remove the initial short cycle and may time out without contact.',
        physical_outcome_predicted=False, causal_attribution_proven=False, old_evaluation_changed=False,
        world_build_count=0, native_physics_read_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
