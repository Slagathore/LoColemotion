"""Independent source-receipt validation for the prospective R10AF observation.

No controller, geometry, impulse or threshold is recomputed from a prediction.
The classification uses exact recorded native contact frames and matches every
loaded floor contact. Full report identity and observation links are a separate
required caller responsibility; this component grants no launch authority.
"""
import math

from contact_frame_replay_v2 import (BODIES, COUNTERS, IDS, TOLERANCE, require,
    f32, vec, dot, inverse, configured_vec)

PROFILE = 'godot_jolt_distal_contact_detection_frame_v1'
SOURCE_SCHEMA = 'sporespore_r10af_godot_detection_frame_contact_source_v1'
FRAME_SCHEMA = 'sporespore_r10af_contact_detection_frame_binding_v1'


def replay_source(source, callbacks, sites):
    require(source['schema_version'] == SOURCE_SCHEMA and source['source_measurement'] is True, 'source schema')
    step, sequence = source['semantic_step'], source['native_space_step_sequence']
    require(type(step) is int and step > 0 and type(sequence) is int and sequence > 0, 'source step')
    frame = source['contact_detection_frame']
    require(frame['schema_version'] == FRAME_SCHEMA and frame['profile_id'] == PROFILE and
        frame['classification_scope'] == 'distal_foot_cap_only' and frame['native_space_step_sequence'] == sequence,
        'classification frame binding')
    instances, floor = frame['body_instances'], frame['floor_instance_id']
    require(set(instances) == set(BODIES) and type(floor) is int and floor > 0, 'body population')
    require(all(type(v) is int and v > 0 and v != floor for v in instances.values()) and
        len(set(instances.values())) == 9, 'body identity')
    require(type(callbacks) is list and len(callbacks) == 9, 'callback population')
    poses = {}
    for body, row in zip(BODIES, callbacks, strict=True):
        require(row['body_id'] == body and row['instance_id'] == instances[body] and
            type(row['callback_sequence']) is int and row['callback_sequence'] == step, 'callback identity')
        inverse(row['pose'],[0.,0.,0.]); poses[body] = row['pose']
    require(set(sites) == {b for b in BODIES if b.endswith('_distal')}, 'site population')
    centers = {}
    for body, site in sites.items():
        require(site['contact_site_id'] == body.removesuffix('_distal')+'_foot', 'site identity')
        centers[body] = configured_vec(site['local_center_m'])[1]
    native = frame['native_snapshot']
    require(native['schema'] == 'sporespore.godot_jolt_contact_frames.v1' and
        native['profile_id'] == 'godot_4_7_jolt_sporespore_contact_frames_v7' and
        native['sampling_stage'] == 'contact_detection_before_integration', 'native schema')
    for key in ('complete','discrete_sampling_qualified','captured_during_active_step','snapshot_is_current_space_step'):
        require(native[key] is True, key)
    require(native['point_limit_exceeded'] is False, 'overflow')
    for key in ('capture_space_step_sequence','read_space_step_sequence'):
        require(type(native[key]) is int and native[key] == sequence, 'native sequence')
    for key in COUNTERS:
        require(type(native[key]) is int and native[key] == 0, key)
    points, samples = native['points'], source['ordered_contact_samples']
    require(type(points) is list and type(native['reported_point_count']) is int and
        len(points) == native['reported_point_count'] <= 4096, 'native point count')
    contract = source['solved_contact_telemetry_contract']
    require(contract['ok'] is True and type(contract['exact_contact_point_count']) is int and
        contract['exact_contact_point_count'] == len(points), 'solved point count')
    require(type(samples) is list, 'source samples')
    by_instance = {v:k for k,v in instances.items()}
    seen, groups, identities, used, comparisons = set(), {}, {}, set(), []
    for point_index, point in enumerate(points):
        require(all(type(point[k]) is int and point[k] >= 0 for k in IDS), 'native identity types')
        require(point['body1_jolt_id'] != point['body2_jolt_id'], 'same body')
        pair = tuple(point[k] for k in ('body1_jolt_id','subshape1_id','body2_jolt_id','subshape2_id'))
        key = (*pair,point['manifold_point_index'])
        require(key not in seen, 'duplicate native point');seen.add(key)
        groups.setdefault(pair,[]).append(point['manifold_point_index'])
        for side, other in (('1','2'),('2','1')):
            instance, jolt = point['body'+side+'_instance_id'],point['body'+side+'_jolt_id']
            require(instance == floor or instance in by_instance, 'unknown native body')
            require(jolt not in identities or identities[jolt] == instance, 'jolt body identity')
            identities[jolt] = instance
            world, local, normal, impulse = (vec(point[k]) for k in ('point'+side+'_world_m',
                'point'+side+'_body_local_m','normal'+side+'_world_unit','impulse'+side+'_world_ns'))
            require(inverse(point['body'+side+'_transform_at_detection'],world) == local, 'native detection transform')
            length = f32(math.sqrt(dot(normal,normal)))
            require(abs(length-1) <= 1e-6, 'normal length')
            require(normal == [-v for v in vec(point['normal'+other+'_world_unit'])] and
                impulse == [-v for v in vec(point['impulse'+other+'_world_ns'])], 'native pair')
            if point['body'+other+'_instance_id'] != floor or instance == floor:
                continue
            load = abs(dot(impulse,[f32(v/length) for v in normal]))
            if load == 0:
                continue
            body = by_instance[instance]
            engine_id = f"{body}:{point['shape'+side+'_index']}|floor:{point['shape'+other+'_index']}"
            matches = [i for i,r in enumerate(samples) if r['body_id'] == body and
                r['engine_contact_id'] == engine_id and vec(r['position_world_m']) == world and r['normal_impulse_ns'] == load]
            require(len(matches) == 1 and matches[0] not in used, 'ambiguous or missing source contact')
            index = matches[0];used.add(index);sample = samples[index]
            require(type(sample['native_point_index']) is int and sample['native_point_index'] == point_index and
                sample['native_side'] == side, 'native point binding')
            callback = inverse(poses[body],world)
            require(vec(sample['position_body_local_m']) == callback, 'callback local point')
            require(vec(sample['detection_position_body_local_m']) == local, 'detection local point')
            classification_point = local if body in centers else callback
            require(vec(sample['classification_position_body_local_m']) == classification_point, 'classification local point')
            foot = body in centers and local[1] <= centers[body]+TOLERANCE
            require(type(sample['classified_as_foot']) is bool and sample['classified_as_foot'] == foot, 'classification')
            comparisons.append(dict(source_contact_index=index,body_id=body,classified_as_foot=foot,
                callback_classified_as_foot=body in centers and callback[1] <= centers[body]+TOLERANCE,
                normal_impulse_ns=load))
    require(all(sorted(v) == list(range(len(v))) for v in groups.values()), 'native point index gap')
    require(len(used) == len(samples), 'unmatched source contact')
    comparisons.sort(key=lambda r:r['source_contact_index'])
    foot_impulses = {b:0.0 for b in centers};nonfoot_impulses = {b:0.0 for b in BODIES}
    for row in comparisons:
        target = foot_impulses if row['classified_as_foot'] else nonfoot_impulses
        target[row['body_id']] += row['normal_impulse_ns']
    return dict(ok=True,matched_loaded_floor_contacts=len(used),comparisons=comparisons,
        foot_impulses_by_body=foot_impulses,nonfoot_impulses_by_body=nonfoot_impulses,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
