"""Successor read-only contact replay with Godot configured-vector conversion.

Native measured vectors retain the predecessor's exact float32 validation.
Only authored contact-site coordinates are converted through float32, matching
Godot's _source_vec -> Vector3 path. This reader grants no campaign authority.
"""
import math
from r10ac_contact_frame_replay import (BODIES, COUNTERS, IDS, TOLERANCE,
    require, sha, f32, vec, dot, matrix, inverse, quaternion_basis)


def configured_vec(value):
    require(isinstance(value, dict) and all(k in value for k in ('x', 'y', 'z')), 'configured vector shape')
    values = [value[k] for k in ('x', 'y', 'z')]
    require(all(type(v) in (int, float) and math.isfinite(v) for v in values), 'configured vector finite')
    try:
        result = [f32(v) for v in values]
    except (OverflowError, ValueError) as error:
        raise ValueError('configured vector float32 range') from error
    require(all(math.isfinite(v) for v in result), 'configured vector float32 range')
    return result


def replay(packet, step, model, population):
    require(type(step) is int and step > 0 and model and population.startswith('sha256:') and len(population) == 71, 'expected binding')
    require(packet['schema_version'] == 'sporespore_r10ac_contact_frame_capture_v1', 'schema')
    require(packet['semantic_step'] == step and packet['model_instance_id'] == model and packet['body_population_instance_sha256'] == population, 'packet binding')
    direct, contact, binding = (packet[k] for k in ('direct_state_source','contact_source_receipt','source_component_binding'))
    require(direct['schema_version'] == 'sporespore_qsdk_r24d57_godot_direct_state_source_v1', 'direct schema')
    require(contact['schema_version'] == 'sporespore_qsdk_r24d71_godot_exact_solved_contact_source_v1', 'contact schema')
    require(direct['source_measurement'] is contact['source_measurement'] is True, 'source measurements')
    require(direct['semantic_step'] == contact['semantic_step'] == binding['semantic_step'] == step, 'source step')
    require(sha(direct) == binding['direct_state_source_sha256'] and sha(contact) == binding['contact_source_sha256'], 'source hashes')
    snapshot = packet['native_snapshot']
    require(snapshot['schema'] == 'sporespore.godot_jolt_contact_frames.v1' and snapshot['profile_id'] == 'godot_4_7_jolt_sporespore_contact_frames_v7', 'native schema')
    require(snapshot['sampling_stage'] == 'contact_detection_before_integration', 'sampling stage')
    for field in ('complete','discrete_sampling_qualified','captured_during_active_step','snapshot_is_current_space_step'):
        require(snapshot[field] is True, field)
    require(snapshot['point_limit_exceeded'] is False, 'overflow')
    require(type(contact['native_space_step_sequence']) is int, 'native sequence type')
    for field in ('capture_space_step_sequence','read_space_step_sequence'):
        require(type(snapshot[field]) is int and snapshot[field] == contact['native_space_step_sequence'] > 0, field)
    for field in COUNTERS:
        require(type(snapshot[field]) is int and snapshot[field] == 0, field)
    points = snapshot['points']
    require(isinstance(points,list) and type(snapshot['reported_point_count']) is int and len(points) == snapshot['reported_point_count'] <= 4096, 'point count')
    require(contact['solved_contact_telemetry_contract']['ok'] is True and contact['solved_contact_telemetry_contract']['exact_contact_point_count'] == len(points), 'solved count')
    callbacks = packet['callback_bodies']
    require(len(callbacks) == len(direct['ordered_body_states']) == 9, 'callback population')
    floor = packet['floor_instance_id']
    require(type(floor) is int and floor > 0, 'floor identity')
    by_instance, poses = {}, {}
    for index, body in enumerate(BODIES):
        row, original = callbacks[index], direct['ordered_body_states'][index]
        require(row['body_id'] == original['body_id'] == body, 'body identity')
        require(row['callback_sequence'] == original['callback_sequence'] == step, 'callback step')
        instance = row['instance_id']
        require(type(instance) is int and instance > 0 and instance != floor and instance not in by_instance, 'duplicate identity')
        pose = row['pose']
        require(vec(pose['origin']) == vec(original['position_world_m']), 'callback position')
        rows, expected = matrix(pose), quaternion_basis(original['orientation_xyzw'])
        # Quaternion publication projects to a unit scalar. This independent
        # orientation consistency check allows float32 projection error only;
        # contact coordinate reconstruction below must match exactly.
        require(max(abs(rows[i][j]-expected[i][j]) for i in range(3) for j in range(3)) < 1e-6, 'callback orientation')
        inverse(pose,[0.,0.,0.])
        by_instance[instance], poses[body] = body, pose
    sites = packet['contact_sites_by_body']
    require(set(sites) == {body for body in BODIES if body.endswith('_distal')}, 'foot population')
    require(all(site['contact_site_id'] == body.removesuffix('_distal')+'_foot' for body,site in sites.items()), 'foot identity')
    centers = {body:configured_vec(site['local_center_m'])[1] for body,site in sites.items()}
    source_rows, used, comparisons, seen, groups, identities = contact['ordered_contact_samples'], set(), [], set(), {}, {}
    for point in points:
        require(all(type(point[k]) is int and point[k] >= 0 for k in IDS), 'point identity types')
        require(point['body1_jolt_id'] != point['body2_jolt_id'], 'same body')
        pair = tuple(point[k] for k in ('body1_jolt_id','subshape1_id','body2_jolt_id','subshape2_id'))
        key = (*pair,point['manifold_point_index'])
        require(key not in seen, 'duplicate point'); seen.add(key)
        groups.setdefault(pair,[]).append(point['manifold_point_index'])
        for side,other in (('1','2'),('2','1')):
            instance, jolt_id = point['body'+side+'_instance_id'], point['body'+side+'_jolt_id']
            require(jolt_id not in identities or identities[jolt_id] == instance, 'body identity changed')
            identities[jolt_id] = instance
            require(instance == floor or instance in by_instance, 'unknown native body')
            world, local, normal, impulse = (vec(point[k]) for k in ('point'+side+'_world_m','point'+side+'_body_local_m','normal'+side+'_world_unit','impulse'+side+'_world_ns'))
            require(inverse(point['body'+side+'_transform_at_detection'],world) == local, 'detection local point')
            length = f32(math.sqrt(dot(normal,normal)))
            require(abs(length-1) <= 1e-6, 'normal length')
            require(normal == [-x for x in vec(point['normal'+other+'_world_unit'])], 'normal pair')
            require(impulse == [-x for x in vec(point['impulse'+other+'_world_ns'])], 'impulse pair')
            if point['body'+other+'_instance_id'] != floor or instance not in by_instance:
                continue
            load = abs(dot(impulse,[f32(x/length) for x in normal]))
            if load == 0:
                continue
            body = by_instance[instance]
            engine_id = f"{body}:{point['shape'+side+'_index']}|floor:{point['shape'+other+'_index']}"
            matches = [i for i,row in enumerate(source_rows) if row['body_id'] == body and row['engine_contact_id'] == engine_id and vec(row['position_world_m']) == world and row['normal_impulse_ns'] == load]
            require(len(matches) == 1 and matches[0] not in used, 'ambiguous or missing source contact')
            index = matches[0]; used.add(index)
            callback_local = inverse(poses[body],world)
            require(callback_local == vec(source_rows[index]['position_body_local_m']), 'callback local point')
            center = centers.get(body)
            legacy = center is not None and callback_local[1] <= center+TOLERANCE
            detection = center is not None and local[1] <= center+TOLERANCE
            require(type(source_rows[index]['classified_as_foot']) is bool and source_rows[index]['classified_as_foot'] == legacy, 'original classification')
            comparisons.append(dict(body_id=body, source_contact_index=index, engine_contact_id=engine_id,
                **{k:point[k] for k in ('body1_jolt_id','body2_jolt_id','subshape1_id','subshape2_id','manifold_point_index')},
                normal_impulse_ns=load, detection_local_y_m=local[1], callback_local_y_m=callback_local[1],
                local_y_difference_m=callback_local[1]-local[1], cap_center_y_m=center,
                original_classified_as_foot=legacy, diagnostic_detection_frame_foot=detection, membership_changed=legacy != detection))
    require(all(sorted(indices) == list(range(len(indices))) for indices in groups.values()), 'point index gap')
    require(len(used) == len(source_rows), 'unmatched original contact')
    comparisons.sort(key=lambda row:row['source_contact_index'])
    return dict(ok=True, comparisons=comparisons, matched_source_contacts=len(used), callback_body_count=9,
                classification_tolerance_m=TOLERANCE, controller_observation_changed=False,
                world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)

