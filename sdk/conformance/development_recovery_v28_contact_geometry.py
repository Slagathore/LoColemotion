"""Read-only V28 diagnosis; geometry is descriptive, never a contact predicate.

Walking body quaternions express host -Z as canonical +X. Native recovery
geometry instead uses host +X, so forward kinematics MUST use the separately
retained native torso quaternion. Both conventions preserve the capsule Y axis.
The ideal hinge calculation omits measured anchor/axis compliance and is not a
simulation or a prediction of what another command would physically produce.
"""
import math
import statistics

LIMBS = ('front_left', 'front_right', 'rear_left', 'rear_right')


def vector(value):
    return [value[k] for k in 'xyz']


def rotate(q, a):
    x, y, z, w = (q[k] for k in 'xyzw')
    norm = math.sqrt(x*x + y*y + z*z + w*w)
    x, y, z, w = (v / norm for v in (x, y, z, w))
    t = [2*(y*a[2]-z*a[1]), 2*(z*a[0]-x*a[2]), 2*(x*a[1]-y*a[0])]
    return [a[0]+w*t[0]+y*t[2]-z*t[1], a[1]+w*t[1]+z*t[0]-x*t[2],
            a[2]+w*t[2]+x*t[1]-y*t[0]]


def ideal_distal(torso, limb, hip, knee, upper, lower, radius, span):
    """Native +Z positive geometric angles; motor direction sign is irrelevant."""
    anchor = [(.2 if limb.startswith('front') else -.2)*span, 0,
              (-.18 if limb.endswith('left') else .18)*span]
    link = [upper*math.sin(hip)+lower/2*math.sin(hip+knee),
            -upper*math.cos(hip)-lower/2*math.cos(hip+knee), 0]
    offset = rotate(torso['orientation_xyzw'], [anchor[i]+link[i] for i in range(3)])
    center = [torso['position_m'][k]+offset[i] for i, k in enumerate('xyz')]
    axis = rotate(torso['orientation_xyzw'], [-math.sin(hip+knee), math.cos(hip+knee), 0])
    return center, center[1]-abs(axis[1])*lower/2-radius


def reconstruct(report):
    """Return 1600 precommand body samples, trace locals 0..399, not trace 400."""
    descriptor = report['configuration']['base_descriptor']
    upper = .35*descriptor['upper_length_fraction']
    lower = .35-upper
    radius = .04*descriptor['foot_radius_scale']
    span = descriptor['hip_span_scale']
    walking = {int(r['session_local_step']): r for r in report['development_walking_entry']['rows']}
    native = {int(r['session_local_step']): r for r in report['development_native_walking_contacts']['rows']
              if r['segment_id'] == 'walking_resume'}
    assert set(walking) == set(native) == set(range(1, 401))
    rows, frame_errors = [], []
    for local, entry in walking.items():
        source = native[local]['native_source']
        trace = source['precommand_trace']
        bodies = {b['body_id']: b['pose_world'] for b in entry['ordered_body_states']}
        torso = source['observation']['state']['base_pose_world']
        assert entry['measured_global_step'] == trace['global_semantic_step'] == 858+local-1
        assert entry['commanded_global_step'] == 858+local
        assert vector(torso['position_m']) == vector(bodies['torso']['position_m']) == trace['torso_position_world_m']
        for host, canonical in (([1, 0, 0], [0, 0, 1]), ([0, 1, 0], [0, 1, 0]), ([0, 0, 1], [-1, 0, 0])):
            frame_errors.append(math.dist(rotate(torso['orientation_xyzw'], host),
                rotate(bodies['torso']['orientation_xyzw'], canonical)))
        joints = {j['joint_id']: j for j in entry['request']['state']['ordered_joint_observations']}
        # Command n was applied before trace n. Local zero is a standing
        # control only: there is no preceding walking command to invent.
        targets = ({c['actuator_id'].removesuffix('_motor'): c['requested_target_position_rad']
                    for c in walking[local-1]['native_output']['actuation']['ordered_commands']}
                   if local > 1 else None)
        for limb in LIMBS:
            body = bodies[limb+'_distal']
            center = vector(body['position_m'])
            assert center == trace['foot_position_world_m_by_limb'][limb]
            axis = rotate(body['orientation_xyzw'], [0, 1, 0])
            bottom = center[1]-abs(axis[1])*lower/2-radius
            hip, knee = (joints[limb+'_'+joint]['position_rad'] for joint in ('hip', 'knee'))
            ideal, ideal_bottom = ideal_distal(torso, limb, hip, knee, upper, lower, radius, span)
            target_bottom = (ideal_distal(torso, limb, targets[limb+'_hip'], targets[limb+'_knee'],
                                         upper, lower, radius, span)[1] if targets is not None else None)
            raw = [c for c in source['contact_source_receipt']['ordered_contact_samples'] if c['body_id'] == limb+'_distal']
            rows.append(dict(trace_local_step=local-1, limb=limb, nominal_capsule_bottom_m=bottom,
                ideal_requested_bottom_m=target_bottom, ideal_measured_center_error_m=math.dist(center, ideal),
                ideal_measured_bottom_error_m=abs(bottom-ideal_bottom), raw_contact_count=len(raw),
                support=trace['contact_by_limb'][limb], hip_rad=hip, knee_rad=knee))
    return rows, max(frame_errors)


def interval_summary(rows, limb, start, end):
    selected = [r for r in rows if r['limb'] == limb and start <= r['trace_local_step'] < end]
    def spread(key):
        values = [r[key] for r in selected]
        return dict(minimum=min(values), mean=statistics.mean(values), maximum=max(values))
    return dict(limb=limb, start_inclusive=start, end_exclusive=end, sample_count=len(selected),
        raw_contact_sample_count=sum(r['raw_contact_count'] for r in selected),
        nominal_capsule_bottom_m=spread('nominal_capsule_bottom_m'),
        ideal_requested_bottom_m=spread('ideal_requested_bottom_m'))


def summarize(report, basis):
    rows, frame_error = reconstruct(report)
    gaps = [interval_summary(rows, limb, start, end)
            for limb, intervals in basis['selected_failed_stance_gap_trace_intervals'].items()
            for start, end in intervals]
    saturated = {limb: sum(c['position_saturated'] for r in report['development_walking_entry']['rows']
                 for c in r['native_output']['actuation']['ordered_commands'] if c['actuator_id'] == limb+'_knee_motor')
                 for limb in LIMBS}
    return dict(schema_version='sporespore_development_v28_retained_contact_geometry_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        source_report_sha256=basis['source_report_sha256'], measured_body_samples=len(rows),
        selected_failed_stance_gaps=gaps, final_front_right_gap=interval_summary(rows, 'front_right', 293, 400),
        position_saturated_knee_commands_by_limb=saturated,
        coordinate_conversion_maximum_axis_vector_difference=frame_error,
        ideal_measured_bottom_error_mean_m=statistics.mean(r['ideal_measured_bottom_error_m'] for r in rows),
        ideal_measured_bottom_error_maximum_m=max(r['ideal_measured_bottom_error_m'] for r in rows),
        ideal_measured_center_error_maximum_m=max(r['ideal_measured_center_error_m'] for r in rows),
        geometry_limit='Nominal capsule surface relative to authored floor y=0, not Jolt contact-margin or load authority. Ideal hinges omit measured compliance. Requested geometry at the measured torso is not a rollout.',
        missing_final_next_input=True, causal_attribution_proven=False, physical_outcome_predicted=False,
        model_construction_count=0, world_build_count=0, native_physics_read_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
