"""Independent R10AF packet replay; source validation precedes comparisons."""
import copy

import detection_frame_contact_source_v1 as source_reader
from contact_frame_replay_v2 import (BODIES, require, sha, vec, matrix,
    quaternion_basis, configured_vec, TOLERANCE)


def packed_source_snapshot(snapshot):
    """Normalize only the declared vector encoding, without changing values."""
    result=copy.deepcopy(snapshot)
    def packed(value):
        return dict(zip(('x','y','z'),vec(value),strict=True))
    for point in result['points']:
        for side in ['1','2']:
            pose=point['body'+side+'_transform_at_detection']
            pose['origin']=packed(pose['origin'])
            pose['basis_columns']=[packed(v) for v in pose['basis_columns']]
            for field in ['point'+side+'_world_m','point'+side+'_body_local_m',
                    'normal'+side+'_world_unit','impulse'+side+'_world_ns']:
                point[field]=packed(point[field])
    return result


def replay(packet, step, model, population):
    require(type(step) is int and step > 0 and type(model) is str and model and
        type(population) is str and population.startswith('sha256:') and len(population)==71,'expected binding')
    require(packet['schema_version']=='sporespore_r10af_contact_frame_capture_v1' and
        packet['semantic_step']==step and packet['model_instance_id']==model and
        packet['body_population_instance_sha256']==population,'packet binding')
    direct,contact,binding=(packet[k] for k in ['direct_state_source','contact_source_receipt','source_component_binding'])
    require(direct['schema_version']=='sporespore_qsdk_r24d57_godot_direct_state_source_v1' and
        direct['source_measurement'] is True and contact['source_measurement'] is True,'source schema')
    require(direct['semantic_step']==contact['semantic_step']==binding['semantic_step']==step,'source step')
    require(sha(direct)==binding['direct_state_source_sha256'] and sha(contact)==binding['contact_source_sha256'],'source hashes')
    callbacks=packet['callback_bodies'];states=direct['ordered_body_states']
    require(type(callbacks) is list and type(states) is list and len(callbacks)==len(states)==9,'direct population')
    for body,callback,original in zip(BODIES,callbacks,states,strict=True):
        require(callback['body_id']==original['body_id']==body and
            callback['callback_sequence']==original['callback_sequence']==step,'direct body identity')
        require(vec(callback['pose']['origin'])==vec(original['position_world_m']),'direct position')
        actual,expected=matrix(callback['pose']),quaternion_basis(original['orientation_xyzw'])
        require(max(abs(actual[i][j]-expected[i][j]) for i in range(3) for j in range(3))<1e-6,'direct orientation')
    frame=contact['contact_detection_frame']
    require(type(packet['floor_instance_id']) is int and frame['floor_instance_id']==packet['floor_instance_id'],'floor binding')
    require(frame['native_snapshot']==packed_source_snapshot(packet['native_snapshot']),'native snapshot binding')
    validated=source_reader.replay_source(contact,callbacks,packet['contact_sites_by_body'])
    comparisons=[]
    for checked in validated['comparisons']:
        index=checked['source_contact_index'];sample=contact['ordered_contact_samples'][index]
        point=packet['native_snapshot']['points'][sample['native_point_index']]
        callback_y=vec(sample['position_body_local_m'])[1]
        detection_y=vec(sample['detection_position_body_local_m'])[1]
        site=packet['contact_sites_by_body'].get(sample['body_id'])
        center=None if site is None else configured_vec(site['local_center_m'])[1]
        comparisons.append(dict(body_id=sample['body_id'],source_contact_index=index,
            engine_contact_id=sample['engine_contact_id'],
            **{k:point[k] for k in ['body1_jolt_id','body2_jolt_id','subshape1_id','subshape2_id','manifold_point_index']},
            normal_impulse_ns=checked['normal_impulse_ns'],detection_local_y_m=detection_y,
            callback_local_y_m=callback_y,local_y_difference_m=callback_y-detection_y,cap_center_y_m=center,
            callback_frame_classified_as_foot=checked['callback_classified_as_foot'],
            classified_as_foot=checked['classified_as_foot'],
            membership_changed=checked['callback_classified_as_foot'] != checked['classified_as_foot']))
    return dict(ok=True,comparisons=comparisons,matched_source_contacts=len(comparisons),
        callback_body_count=9,classification_tolerance_m=TOLERANCE,controller_observation_changed=True,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
