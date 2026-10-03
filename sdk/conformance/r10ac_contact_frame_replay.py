"""Independently replay recorded contact-frame comparisons; no native calls.

Godot's float32 matrix/point arithmetic is implemented explicitly to check the
two local-coordinate measurements exactly. Classification uses the retained
coordinates and unchanged cap rule, never a predicted physical response.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

from content_addressed_zero_world_closure import core_canonical_bytes

BODIES = ('torso', 'front_left_upper', 'front_left_distal', 'front_right_upper',
          'front_right_distal', 'rear_left_upper', 'rear_left_distal', 'rear_right_upper', 'rear_right_distal')
COUNTERS = ('missing_manifold_count', 'ccd_only_manifold_count', 'point_count_mismatch_count',
            'nonfinite_impulse_count', 'missing_frame_count', 'duplicate_callback_count', 'invalid_frame_count')
IDS = ('body1_jolt_id', 'body2_jolt_id', 'body1_instance_id', 'body2_instance_id',
       'subshape1_id', 'subshape2_id', 'shape1_index', 'shape2_index', 'manifold_point_index')
TOLERANCE = 1e-6


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def sha(value):
    return 'sha256:' + hashlib.sha256(core_canonical_bytes(value)).hexdigest()


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def vec(value):
    if isinstance(value, dict):
        value = [value[k] for k in ('x', 'y', 'z')]
    require(isinstance(value, list) and len(value) == 3, 'vector shape')
    require(all(type(x) in (int, float) and math.isfinite(x) for x in value), 'vector finite')
    result = [f32(x) for x in value]
    require(all(math.isfinite(x) for x in result) and result == value, 'exact float32 vector')
    return result


def dot(a, b):
    return f32(f32(f32(a[0]*b[0]) + f32(a[1]*b[1])) + f32(a[2]*b[2]))


def matrix(pose):
    columns = [vec(column) for column in pose['basis_columns']]
    require(len(columns) == 3, 'basis shape')
    return [[columns[j][i] for j in range(3)] for i in range(3)]


def inverse(pose, world):
    rows, origin = matrix(pose), vec(pose['origin'])
    def cofac(r1, c1, r2, c2):
        return f32(f32(rows[r1][c1]*rows[r2][c2])-f32(rows[r1][c2]*rows[r2][c1]))
    co = [cofac(1,1,2,2), cofac(1,2,2,0), cofac(1,0,2,1)]
    determinant = dot(rows[0], co)
    require(math.isfinite(determinant) and abs(determinant) > 1e-5, 'singular basis')
    scale = f32(1.0/determinant)
    inverted = [[co[0],cofac(0,2,2,1),cofac(0,1,1,2)],
                [co[1],cofac(0,0,2,2),cofac(0,2,1,0)],
                [co[2],cofac(0,1,2,0),cofac(0,0,1,1)]]
    inverted = [[f32(x*scale) for x in row] for row in inverted]
    shifted = [dot(row,[-x for x in origin]) for row in inverted]
    return [f32(dot(row,world)+shifted[i]) for i,row in enumerate(inverted)]


def quaternion_basis(q):
    x,y,z,w = (q[k] for k in ('x','y','z','w'))
    require(all(type(v) in (float,int) and math.isfinite(v) for v in (x,y,z,w)), 'quaternion finite')
    require(abs(x*x+y*y+z*z+w*w-1) < 1e-6, 'quaternion unit')
    return [[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
            [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
            [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]


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
    centers = {body:vec(site['local_center_m'])[1] for body,site in sites.items()}
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


def check_fixture_result(path):
    data = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    require(data['ok'] is True, 'Godot result failed')
    for fixture in data['fixtures']:
        p = fixture['packet']
        require(sha(p) == fixture['packet_sha256'], 'packet digest')
        result = replay(p,7,'r10ac-synthetic-no-world','sha256:'+'a'*64)
        require(result == fixture['replay'], 'independent comparison differs')
    refused = 0
    for mutation in data['negative_packets']:
        try:
            replay(mutation,7,'r10ac-synthetic-no-world','sha256:'+'a'*64)
        except (ValueError,KeyError,TypeError,IndexError,OverflowError):
            refused += 1
    require(refused == len(data['negative_packets']) == 29, 'mutation accepted')
    return dict(ok=True, independent_positive_replays=len(data['fixtures']), independent_negative_refusals=refused,
        exact_float32_contact_coordinates=True, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture_result')
    args = parser.parse_args()
    print('R10AC_CONTACT_FRAME_REPLAY '+json.dumps(check_fixture_result(args.fixture_result)), flush=True)
