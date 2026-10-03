"""Retained V30 contact/geometry diagnosis, not a dynamics or acceptance model.

The support triangles use actual raw point contacts projected onto authored
horizontal ground. Signed distance is descriptive; it is not a new margin
requirement and omits momentum, contact patches, compliance and later motion.
"""
import math

import development_recovery_v28_contact_geometry as geometry

LIMBS = ('rear_left', 'front_left', 'rear_right', 'front_right')


def require(condition, code):
    if not condition:
        raise ValueError(code)


def xz(value):
    values = [value['x'], value['z']] if isinstance(value, dict) else [value[0], value[2]]
    require(all(type(v) in (int, float) and math.isfinite(v) for v in values), 'STARTUP_POINT_FINITE')
    return values


def cross(a, b):
    return a[0]*b[1]-a[1]*b[0]


def triangle_margin(points, point):
    require(len(points) == 3 and len({tuple(p) for p in points}) == 3, 'STARTUP_TRIANGLE_POPULATION')
    require(all(len(p) == 2 and all(type(v) in (int, float) and math.isfinite(v) for v in p) for p in [*points, point]), 'STARTUP_POINT_FINITE')
    center = [sum(p[i] for p in points)/3 for i in range(2)]
    ordered = sorted(points, key=lambda p: math.atan2(p[1]-center[1], p[0]-center[0]))
    area = sum(cross(a, b) for a, b in zip(ordered, ordered[1:]+ordered[:1]))
    require(area > 0, 'STARTUP_TRIANGLE_DEGENERATE')
    distances = []
    for a, b in zip(ordered, ordered[1:]+ordered[:1]):
        edge = [b[i]-a[i] for i in range(2)]
        distances.append(cross(edge, [point[i]-a[i] for i in range(2)])/math.hypot(*edge))
    return min(distances)


def startup_triangles(source):
    com = source['observation']['center_of_mass']
    require(com['source_measurement'] is True, 'STARTUP_COM_SOURCE')
    point = xz(com['position_world_m'])
    contacts = {}
    for contact in source['contact_source_receipt']['ordered_contact_samples']:
        body = contact['body_id']
        if body not in {limb+'_distal' for limb in LIMBS}:
            continue
        limb = body.removesuffix('_distal')
        require(limb not in contacts and contact['normal_impulse_ns'] > 0, 'STARTUP_CONTACT_POPULATION')
        contacts[limb] = xz(contact['position_world_m'])
    require(set(contacts) == set(LIMBS), 'STARTUP_CONTACT_POPULATION')
    return {limb: triangle_margin([p for name, p in contacts.items() if name != limb], point) for limb in LIMBS}


def summarize(report):
    rows, frame_error = geometry.reconstruct(report)
    native = {int(e['session_local_step'])-1: e['native_source']
              for e in report['development_native_walking_contacts']['rows'] if e['segment_id'] == 'walking_resume'}
    descriptor = report['configuration']['base_descriptor']
    upper = .35*descriptor['upper_length_fraction']
    args = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
    first = native[0]['observation']['state']['base_pose_world']
    indexed = {(r['limb'], r['trace_local_step']): r for r in rows}
    baseline = indexed['front_right', 0]
    first_ideal = geometry.ideal_distal(first, 'front_right', baseline['hip_rad'], baseline['knee_rad'], *args)[1]
    decomposition = []
    for local in (0, 32, 33, 34, 35, 55, 80, 113, 114):
        torso = native[local]['observation']['state']['base_pose_world']
        measured = indexed['front_right', local]
        fixed_joints = geometry.ideal_distal(torso, 'front_right', baseline['hip_rad'], baseline['knee_rad'], *args)[1]
        ideal = geometry.ideal_distal(torso, 'front_right', measured['hip_rad'], measured['knee_rad'], *args)[1]
        height = torso['position_m']['y']-first['position_m']['y']
        orientation = fixed_joints-first_ideal-height
        joints = ideal-fixed_joints
        residual = measured['nominal_capsule_bottom_m']-ideal-baseline['nominal_capsule_bottom_m']+first_ideal
        forward = geometry.rotate(torso['orientation_xyzw'], [1, 0, 0])
        up = geometry.rotate(torso['orientation_xyzw'], [0, 1, 0])
        side = geometry.rotate(torso['orientation_xyzw'], [0, 0, 1])
        hip_y = torso['position_m']['y']+args[3]*(.2*forward[1]+.18*side[1])
        minimum_bottom = hip_y-.35*math.hypot(forward[1], up[1])-args[2]
        decomposition.append(dict(trace_local_step=local, nominal_capsule_bottom_m=measured['nominal_capsule_bottom_m'],
            raw_contact_count=measured['raw_contact_count'], torso_height_change_m=height,
            orientation_change_at_initial_joints_m=orientation, joint_change_at_current_pose_m=joints,
            ideal_constraint_residual_change_m=residual, relaxed_minimum_ideal_bottom_at_measured_torso_m=minimum_bottom))
    margins = startup_triangles(native[0])
    selected = max(LIMBS, key=lambda limb: margins[limb])
    return dict(schema_version='sporespore_development_v30_startup_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        first_front_right_flight=geometry.interval_summary(rows, 'front_right', 34, 114),
        front_right_vertical_change_decomposition=decomposition,
        startup_raw_contact_triangle_margins_m=margins,
        largest_startup_static_margin_limb=selected,
        corresponding_policy_phase_index=LIMBS.index(selected), corresponding_initial_gait_step=LIMBS.index(selected)*90,
        startup_measured_com_velocity_world_m_s=native[0]['observation']['center_of_mass']['linear_velocity_world_m_s'],
        coordinate_conversion_maximum_axis_vector_difference=frame_error,
        interpretation_limit='Fixed-pose ideal geometry and instantaneous raw-contact triangles, not a dynamics rollout, support threshold, load prediction or causal proof. The decomposition uses an explicit order of substitutions. The relaxed reach bound allows all planar angles and omits joint compliance; the physical body is free to move.',
        online_foot_selection=False, minimum_support_margin_required=None,
        physical_outcome_predicted=False, causal_attribution_proven=False,
        world_build_count=0, native_physics_read_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
