"""Cold geometry description, not a new native observation or contact proof.

The historical compact 'foot position' is the distal BODY ORIGIN. Reconstruct
both that origin and the distinct contact-site center from the compiled link
geometry and observed joint angles. Ideal hinges omit native anchor/axis error;
report the residual instead of treating forward kinematics as measured physics.
"""
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = 'e0f7e7838133586f5a97c89e09e1ccfeb6267989'
REPORT = ROOT.parent / ('SporeSpore_Evidence/development-recovery-smoke-'
    '2422bf09b7db4c1ebd39fa854a63593f/children/kick_passive_recovery_resume/worker_report.json')
REPORT_SHA = '27e683d793fd94441d380d17242f69181f1a71264fa2881603e37d10d899202e'
LIMBS = ('front_left', 'front_right', 'rear_left', 'rear_right')


def rotate(q, v):
    x, y, z, w = (q[k] for k in 'xyzw')
    a, b, c = v
    return [(1-2*(y*y+z*z))*a+2*(x*y-z*w)*b+2*(x*z+y*w)*c,
            2*(x*y+z*w)*a+(1-2*(x*x+z*z))*b+2*(y*z-x*w)*c,
            2*(x*z-y*w)*a+2*(y*z+x*w)*b+(1-2*(x*x+y*y))*c]


def endpoint(hip, knee, upper, distal):
    return [upper*math.sin(hip)+distal*math.sin(hip+knee),
            -upper*math.cos(hip)-distal*math.cos(hip+knee)]


def observe():
    import hashlib
    raw = REPORT.read_bytes()
    if hashlib.sha256(raw).hexdigest() != REPORT_SHA:
        raise ValueError('LEG_GEOMETRY_REPORT_DRIFT')
    source_paths = ('sdk/core/src/quadruped.rs', 'sdk/core/src/recovery_morphology.rs',
                    'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd',
                    'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd')
    sources = []
    for path in source_paths:
        data = subprocess.check_output(['git', 'show', SOURCE_COMMIT + ':' + path], cwd=ROOT)
        sources.append(dict(path=path, source_commit=SOURCE_COMMIT,
                            raw_sha256='sha256:' + hashlib.sha256(data).hexdigest()))
        if path == source_paths[-1]:
            body = data.decode().split('func _foot_position_map_v1(', 1)[1].split('\nfunc ', 1)[0]
            if 'result[limb_id] = _vector3_array_v1(body.global_position)' not in body:
                raise ValueError('LEG_GEOMETRY_HISTORICAL_POINT_SOURCE')
    report = json.loads(raw)
    rows = []
    for packet in report['passive_entry']['canonical_packets']:
        step = packet['global_semantic_step']
        request = json.loads(packet['collection_transport']['request']['utf8_text'])
        observation = request['observation']
        descriptor = request['descriptor']
        upper = .35 * descriptor['upper_length_fraction']
        distal = .35 * (1 - descriptor['upper_length_fraction'])
        state = observation['state']
        pose = state['base_pose_world']
        position = [pose['position_m'][k] for k in 'xyz']
        angles = [joint['position_rad'] for joint in state['ordered_joint_observations']]
        trace = report['retained_arm']['trace_rows'][step-1]
        feet = []
        for i, limb in enumerate(LIMBS):
            hip, knee = angles[2*i:2*i+2]
            hip_x = (.2 if i < 2 else -.2) * descriptor['hip_span_scale']
            hip_z = (-.18 if i % 2 == 0 else .18) * descriptor['hip_span_scale']
            def world(length):
                x, y = endpoint(hip, knee, upper, length)
                rotated = rotate(pose['orientation_xyzw'], [hip_x+x, y, hip_z])
                return [a+b for a, b in zip(position, rotated)]
            midpoint = world(distal/2)
            site = world(distal)
            recorded = trace['foot_position_world_m_by_limb'][limb]
            feet.append(dict(limb=limb, hip_rad=hip, knee_rad=knee,
                recorded_distal_body_origin_world_m=recorded,
                ideal_hinge_distal_body_origin_world_m=midpoint,
                body_origin_residual_m=math.dist(recorded, midpoint),
                ideal_hinge_contact_site_center_world_m=site,
                ideal_contact_site_y_relative_to_hip_m=endpoint(hip, knee, upper, distal)[1]))
        rows.append(dict(global_step=step, torso_position_world_m=position,
                         torso_up_dot=packet['step_receipt']['classification']['torso_up_dot'], feet=feet))
    selected = (386, 387, 407, 427, 443, 463, 483, 493, 626)
    return dict(schema_version='sporespore_development_recovery_leg_geometry_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt_retained',
                          authority_mode='cold_ideal_hinge_geometry_description', question_class='development'),
        report=dict(path=REPORT.as_posix(), raw_sha256='sha256:' + REPORT_SHA), sources=sources,
        complete_observation_count=len(rows), reconstructed_body_origin_count=4*len(rows),
        maximum_body_origin_residual_m=max(f['body_origin_residual_m'] for r in rows for f in r['feet']),
        historical_field_semantics='foot_position_world_m_by_limb contains distal body origins, not contact-site centers',
        samples=[r for r in rows if r['global_step'] in selected],
        limitation='Ideal hinge reconstruction ignores measured anchor separation and out-of-plane axis error; site positions are calculations, not additional native reads or clearance/load proof.',
        next_question='Can matching lagging leg extension before common lift establish four-foot support after a kick?',
        original_results_reclassified=False, causal_attribution_proven=False,
        world_build_count=0, native_physics_read_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def stance_contact_points(observation, source):
    """Join retained raw contact IDs through their actual portable mapping."""
    from development_recovery_candidate import require
    samples = [p for p in source['ordered_contact_samples'] if p['classified_as_foot']]
    projections = {p['bucket_id']: p['projection'] for p in source['ordered_contact_identity_projections']
                   if p['bucket_kind'] == 'foot_site'}
    claimed_raw_ids = set()
    for bearing, contact in zip(observation['ordered_foot_bearing_observations'], observation['state']['ordered_contact_observations']):
        site = bearing['contact_site_id']
        require(site == contact['contact_site_id'], 'STANCE_GEOMETRY_CONTACT_ORDER')
        projection = projections[site]
        pairs = projection['raw_to_portable_identity_pairs']
        for pair in pairs:
            require(pair['portable_engine_contact_id'] == 'godot_contact_' + pair['raw_engine_contact_id'].encode().hex(),
                    'STANCE_GEOMETRY_CONTACT_IDENTITY')
        require([p['portable_engine_contact_id'] for p in pairs] == contact['provenance']['engine_contact_ids'],
                'STANCE_GEOMETRY_PORTABLE_CONTACTS')
        ids = {p['raw_engine_contact_id'] for p in pairs}
        require(not ids & claimed_raw_ids, 'STANCE_GEOMETRY_CONTACT_ALIAS')
        claimed_raw_ids.update(ids)
        total = sum(p['normal_impulse_ns'] for p in samples if p['engine_contact_id'] in ids)
        require(total == bearing['bearing_normal_impulse_ns'], 'STANCE_GEOMETRY_LOAD_RECOMPUTATION')
    require(all(p['engine_contact_id'] in claimed_raw_ids for p in samples), 'STANCE_GEOMETRY_UNOWNED_POINT')
    return samples


def observe_stance_v15():
    """Native points/load history plus explicitly ideal candidate geometry."""
    import hashlib
    import statistics
    import development_passive_entry_profile as entry
    path = entry.EVIDENCE / ('development-recovery-smoke-e890db0576d94a2e9380186b56ac732b/'
                            'children/kick_passive_recovery_resume/worker_report.json')
    raw = path.read_bytes()
    expected = '00e0c39491e97def5cf6dc5c2bc84d4608c3e724262b0f5653b8ce1cd85f0468'
    if hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError('STANCE_GEOMETRY_REPORT_DRIFT')
    report = entry.packet.parse_json(raw.decode())
    rows, late_offsets = [], []
    point_count = 0
    foot_counts = {limb + '_foot': 0 for limb in LIMBS}
    record = entry.read(ROOT / 'sdk/development/recovery_attempts/e890db0576d94a2e9380186b56ac732b.json')
    minimum = record['metrics']['existing_per_foot_bearing_requirement_ns']
    for packet in report['passive_entry']['canonical_packets']:
        if packet['step_receipt']['prior_phase'] != 'stance_dwell':
            continue
        step = packet['global_semantic_step']
        request = entry.packet.parse_json(packet['collection_transport']['request']['utf8_text'])
        observation = request['observation']
        bound = entry.packet.parse_json(packet['collection_transport']['source_links']['bound_observation']['utf8_text'])
        source = bound['source_component_receipts']['rotation_aware_source_component_receipts']['contact_source_receipt']
        samples = stance_contact_points(observation, source)
        point_count += len(samples)
        loads = {f['contact_site_id']: f['bearing_normal_impulse_ns'] for f in observation['ordered_foot_bearing_observations']}
        for foot, load in loads.items():
            foot_counts[foot] += int(load >= minimum)
        total = sum(p['normal_impulse_ns'] for p in samples)
        offset = None
        if total > 0:
            center = [sum(p['normal_impulse_ns']*p['position_world_m'][k] for p in samples)/total for k in 'xyz']
            com = observation['center_of_mass']['position_world_m']
            q = observation['state']['base_pose_world']['orientation_xyzw']
            inverse = dict(q, **{k: -q[k] for k in 'xyz'})
            offset = rotate(inverse, [center[i]-com[k] for i,k in enumerate('xyz')])
            if step >= 800:
                late_offsets.append(offset[0])
        rows.append(dict(step=step, loaded_feet=loads, normal_impulse_centroid_relative_com_body_frame_m=offset,
                         actual_contact_samples=samples))
    fraction = request['descriptor']['upper_length_fraction']
    upper, lower = .35*fraction, .35*(1-fraction)
    knee = -.25
    hip = -math.atan2(lower*math.sin(knee), upper+lower*math.cos(knee))
    x, y = endpoint(hip,knee,upper,lower)
    return dict(schema_version='sporespore_development_v15_stance_geometry_description_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt_retained',
            authority_mode='descriptive_post_exposure_geometry',question_class='development'),
        source_report=dict(path=path.as_posix(),raw_sha256='sha256:'+expected),
        observed_stance_steps=len(rows), retained_foot_contact_point_count=point_count,
        raw_to_portable_contact_identity_join_checked=True, all_native_foot_load_sums_exact=True,
        qualifying_load_counts_by_foot=foot_counts, existing_per_foot_requirement_ns=minimum,
        late_window_steps=[800,868], late_centroid_sample_count=len(late_offsets),
        late_front_rear_centroid_offset_mean_m=statistics.mean(late_offsets),
        late_front_rear_centroid_offset_min_m=min(late_offsets), late_front_rear_centroid_offset_max_m=max(late_offsets),
        late_positive_front_rear_offset_count=sum(x > 0 for x in late_offsets),
        selected_samples=[row for row in rows if row['step'] in (750,799,821,826,845,868)],
        ideal_candidate_geometry=dict(upper_length_m=upper,lower_length_m=lower,hip_goal_rad=hip,knee_goal_rad=knee,
            foot_offset_from_hip_x_m=x,foot_offset_from_hip_y_m=y,leg_shortening_m=.35+y,
            knee_to_foot_height_derivative_m_per_rad=lower*math.sin(hip+knee),
            zero_pose_hip_and_knee_height_derivatives_m_per_rad=[0.0,0.0]),
        interpretation='Retained loads alternate fore/aft; the final rear unloading is not evidence of a persistent forward bias. A flexed-under-hip target restores first-order knee-to-height sensitivity and is a prospective hypothesis, not a measured solution.',
        limitations='Impulse-weighted contact centroid is descriptive, not a static-equilibrium or stability proof. Candidate geometry assumes ideal hinges; it does not predict native clearance, load, damping, stability, or walking.',
        original_results_reclassified=False,causal_attribution_proven=False,
        world_build_count=0,native_physics_read_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


def observe_stance_motion_v16():
    """Resolve retained torso motion into anatomical axes; no causal replay."""
    import hashlib
    import statistics
    import development_passive_entry_profile as entry
    path = entry.EVIDENCE / ('development-recovery-smoke-16d22c82f50247f3be4fd349e76407a7/'
                            'children/kick_passive_recovery_resume/worker_report.json')
    raw = path.read_bytes()
    expected = 'fadc72a4bc33f2a489f5f31fe24370acdf7fbe2fa2ed924a58c7d6b3e7c3cfdf'
    if hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError('STANCE_MOTION_REPORT_DRIFT')
    report = entry.packet.parse_json(raw.decode())
    rows = []
    for packet in report['passive_entry']['canonical_packets']:
        if packet['step_receipt']['prior_phase'] != 'stance_dwell':
            continue
        o = entry.packet.parse_json(packet['collection_transport']['request']['utf8_text'])['observation']
        q = o['state']['base_pose_world']['orientation_xyzw']
        velocity = o['state']['base_twist_world']['linear_velocity_m_s']
        local = rotate(dict(q, **{k: -q[k] for k in 'xyz'}), [velocity[k] for k in 'xyz'])
        measured_speed = packet['step_receipt']['classification']['terminal_linear_speed_m_s']
        if not math.isclose(sum(v*v for v in local)**.5, measured_speed, rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError('STANCE_MOTION_SPEED_RECOMPUTATION')
        joints = o['state']['ordered_joint_observations']
        if len(joints) != 8 or any(not j['validity']['velocity'] or not math.isfinite(j['velocity_rad_s']) for j in joints):
            raise ValueError('STANCE_MOTION_JOINT_VELOCITY')
        rows.append(dict(step=packet['global_semantic_step'], body_velocity_m_s=local,
            world_vertical_velocity_m_s=velocity['y'], joint_velocity_rad_s=[j['velocity_rad_s'] for j in joints],
            foot_loads_ns=[f['bearing_normal_impulse_ns'] for f in o['ordered_foot_bearing_observations']]))
    windows = []
    for first in (629, 689, 749, 809):
        group = [r for r in rows if first <= r['step'] < first + 60]
        if len(group) != 60:
            raise ValueError('STANCE_MOTION_WINDOW_POPULATION')
        pairs = [(r['body_velocity_m_s'][0], statistics.mean(r['joint_velocity_rad_s'][::2])) for r in group]
        mean_x, mean_y = (statistics.mean(p[k] for p in pairs) for k in (0, 1))
        correlation = sum((x-mean_x)*(y-mean_y) for x,y in pairs) / (
            sum((x-mean_x)**2 for x,y in pairs)*sum((y-mean_y)**2 for x,y in pairs))**.5
        total = sum(sum(v*v for v in r['body_velocity_m_s']) for r in group)
        windows.append(dict(first_step=first, last_step=first+59, sample_count=len(group),
            body_axis_rms_m_s=[(sum(r['body_velocity_m_s'][k]**2 for r in group)/len(group))**.5 for k in range(3)],
            world_vertical_rms_m_s=(sum(r['world_vertical_velocity_m_s']**2 for r in group)/len(group))**.5,
            hip_axis_squared_speed_fraction=sum(r['body_velocity_m_s'][0]**2 for r in group)/total,
            hip_axis_velocity_mean_hip_joint_velocity_correlation=correlation))
    return dict(schema_version='sporespore_development_v16_stance_motion_description_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt_retained',
            authority_mode='descriptive_post_exposure_motion', question_class='development'),
        source_report=dict(path=path.as_posix(), raw_sha256='sha256:'+expected),
        observed_stance_steps=len(rows), complete_speed_recomputation=True,
        body_axes=['front_rear_hip_axis_x', 'torso_up_axis_y', 'left_right_axis_z'],
        ordered_windows=windows, selected_samples=[r for r in rows if r['step'] in (750,760,780,800,820,840,860,868)],
        interpretation='Late excess speed is mainly back-and-forth along the body hip axis, with covarying hip velocity, rather than vertical bounce. This motivates a prospective opposing measured-joint-velocity term, not a proven damping mechanism or optimum.',
        limitations='These are correlated samples of one development trajectory. Axis x is the anatomical front/rear hip axis, not the walking policy forward axis. RMS and correlation do not prove a contact mechanism, causal effect, recovery, or cross-engine behavior.',
        causal_attribution_proven=False, original_results_reclassified=False,
        world_build_count=0, native_physics_read_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
