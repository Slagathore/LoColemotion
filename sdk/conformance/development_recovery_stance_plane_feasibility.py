"""Unclipped stance-plane target proposal on V32 inputs, not another rollout.

Preserve each requested straight stance-leg direction, shorten legs to share a
horizontal endpoint plane, and choose the highest common torso height. This
geometric proposal does not preserve world foot positions, control body forces,
predict a new torso pose, or specify a complete walking controller.
"""
import json
import math
import re
import subprocess
from pathlib import Path

import development_recovery_v32_placement_diagnosis as original
from development_recovery_v28_contact_geometry import rotate

ROOT = original.ROOT


def propose(pose, directions, dimensions):
    """Native anatomical +X forward, +Y up, +Z right; no caller frame guessing.

    The endpoint is the distal capsule's lower segment endpoint, not its center.
    Its radius offsets the authored plane. Joint-limit violations are returned
    unchanged so this feasibility check cannot hide them behind a clamp.
    """
    upper, lower, radius, span = dimensions
    if (not all(math.isfinite(x) and x > 0 for x in dimensions)
            or not directions or set(directions) - set(original.LIMBS)
            or not all(math.isfinite(x) for x in directions.values())):
        raise ValueError('STANCE_PLANE_DOMAIN')
    q = pose['orientation_xyzw']
    if not all(math.isfinite(q[k]) for k in 'xyzw') or sum(q[k]**2 for k in 'xyzw') < 1e-12:
        raise ValueError('STANCE_PLANE_ORIENTATION')
    forward, up, side = (rotate(q, a) for a in ([1, 0, 0], [0, 1, 0], [0, 0, 1]))
    geometry = {}
    for limb, angle in directions.items():
        anchor_y = span*((.2 if limb.startswith('front') else -.2)*forward[1]
                        + (-.18 if limb.endswith('left') else .18)*side[1])
        downward = up[1]*math.cos(angle)-forward[1]*math.sin(angle)
        if downward <= 0:
            raise ValueError('STANCE_PLANE_NON_DOWNWARD_DIRECTION')
        geometry[limb] = (anchor_y, downward)
    height = min(radius-anchor+(upper+lower)*downward for anchor, downward in geometry.values())
    targets = []
    for limb, angle in directions.items():
        anchor_y, downward = geometry[limb]
        length = (height+anchor_y-radius)/downward
        cosine = (length*length-upper*upper-lower*lower)/(2*upper*lower)
        if length <= 0 or not -1-1e-12 <= cosine <= 1+1e-12:
            raise ValueError('STANCE_PLANE_LINK_REACH')
        # Clamp only inverse-trig roundoff, never a joint request to its bound.
        knee = math.acos(max(-1, min(1, cosine)))
        hip = angle-math.atan2(lower*math.sin(knee), upper+lower*math.cos(knee))
        end_x = upper*math.sin(hip)+lower*math.sin(hip+knee)
        end_y = -upper*math.cos(hip)-lower*math.cos(hip+knee)
        lower_axis_up = up[1]*math.cos(hip+knee)-forward[1]*math.sin(hip+knee)
        if lower_axis_up < 0:
            raise ValueError('STANCE_PLANE_INVERTED_DISTAL_CAPSULE')
        residual = height+anchor_y+forward[1]*end_x+up[1]*end_y-radius
        targets.append(dict(limb=limb, requested_leg_direction_rad=angle,
            proposed_hip_rad=hip, proposed_knee_rad=knee,
            endpoint_distance_m=length, nominal_plane_residual_m=residual))
    return dict(proposed_torso_height_m=height, proposed_targets=targets)


def observe():
    closure_path = ROOT / 'sdk/development/recovery_attempts' / (original.ATTEMPT+'.json')
    closure_raw = closure_path.read_bytes()
    closure = json.loads(closure_raw)
    report_raw = Path(closure['kicked_report']['path']).read_bytes()
    if original.digest(report_raw) != closure['kicked_report']['raw_sha256'] or closure['source_snapshot']['head'] != original.SOURCE:
        raise ValueError('STANCE_PLANE_SOURCE_DRIFT')
    source = subprocess.check_output(['git', 'show', original.SOURCE+':sdk/core/src/quadruped.rs'], cwd=ROOT)
    authority = source.decode().split('const LEGACY_JOINT_AUTHORITY:', 1)[1].split('};', 1)[0]
    limits = {name: float(re.search(name+r': (-?[0-9.]+)', authority).group(1))
              for name in ('hip_lower_limit_rad', 'hip_upper_limit_rad', 'knee_lower_limit_rad', 'knee_upper_limit_rad')}
    report = json.loads(report_raw)
    descriptor = report['configuration']['base_descriptor']
    upper = .35*descriptor['upper_length_fraction']
    dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
    native = {int(r['session_local_step']): r['native_source']['observation']['state']['base_pose_world']
              for r in report['development_native_walking_contacts']['rows'] if r['segment_id'] == 'walking_resume'}
    rows = []
    for entry in report['development_walking_entry']['rows']:
        commands = {c['actuator_id']: c['requested_target_position_rad'] for c in entry['native_output']['actuation']['ordered_commands']}
        directions = {}
        for i, memory in enumerate(entry['native_output']['next_memory']['ordered_limb_memory']):
            if (memory['gait_step']+360-i*90) % 360 >= 72:
                limb = memory['limb_id']
                if commands[limb+'_knee_motor'] != 0:
                    raise ValueError('STANCE_PLANE_NON_STRAIGHT_ORIGINAL_TARGET')
                directions[limb] = commands[limb+'_hip_motor']
        local = int(entry['session_local_step'])
        proposal = propose(native[local], directions, dimensions)
        for target in proposal['proposed_targets']:
            target['inside_original_joint_limits'] = (
                limits['hip_lower_limit_rad'] <= target['proposed_hip_rad'] <= limits['hip_upper_limit_rad']
                and limits['knee_lower_limit_rad'] <= target['proposed_knee_rad'] <= limits['knee_upper_limit_rad'])
        rows.append(dict(command_local=local, original_amplitude=entry['request']['command']['gait_amplitude'], **proposal))
    targets = [t for row in rows for t in row['proposed_targets']]
    result = dict(schema_version='sporespore_development_stance_plane_feasibility_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_geometric_proposal_feasibility', question_class='development'),
        source_commit=original.SOURCE,
        source_closure=dict(path=closure_path.relative_to(ROOT).as_posix(), raw_sha256=original.digest(closure_raw)),
        source_report=closure['kicked_report'], frozen_quadruped_source_sha256=original.digest(source),
        original_joint_limits=limits, native_frame='anatomical_x_forward_y_up_z_right_not_walking_request_quaternion',
        proposal_rule='Highest shared horizontal endpoint plane at measured torso orientation while preserving each scheduled stance leg direction. Positive knee branch, no joint clipping.',
        command_sample_count=len(rows), proposed_stance_target_count=len(targets),
        target_count_outside_original_joint_limits=sum(not t['inside_original_joint_limits'] for t in targets),
        samples_with_limit_violations=[r['command_local'] for r in rows if any(not t['inside_original_joint_limits'] for t in r['proposed_targets'])],
        maximum_proposed_knee_rad=max(t['proposed_knee_rad'] for t in targets),
        maximum_absolute_proposed_hip_rad=max(abs(t['proposed_hip_rad']) for t in targets),
        maximum_nominal_plane_residual_m=max(abs(t['nominal_plane_residual_m']) for t in targets),
        rows=rows, decision='reject_unclipped_proposal_as_ready_to_run_controller',
        interpretation_limit='Geometry is feasible with unrestricted joint angles on these inputs, but some proposed knees exceed the unchanged joint limit. Zero-amplitude input can also acquire nonzero stance targets. This proposal has no startup or transition rule, does not preserve world foot positions, and predicts no new trajectory. A complete bounded successor must address these issues explicitly.',
        registered_controller=False, physical_attempt_authorized=False, physical_outcome_predicted=False,
        world_build_count=0, solver_step_count=0, additional_native_physics_read_count=0,
        original_evaluation_changed=False, physical_acceptance_authority=False, release_authority=False)
    result['analysis_sources'] = [dict(path=p, raw_sha256=original.digest((ROOT/p).read_bytes())) for p in (
        'sdk/conformance/development_recovery_stance_plane_feasibility.py',
        'sdk/conformance/development_recovery_v32_placement_diagnosis.py',
        'sdk/conformance/development_recovery_v28_contact_geometry.py',
        'tests/test_development_stance_plane_feasibility.py')]
    return result


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
