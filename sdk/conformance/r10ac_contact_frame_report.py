"""Independent full-population contact diagnostic reader; no physics or DLL calls.

This supplements, and never replaces, the complete controller/task reader.
"""
import argparse
import json
from pathlib import Path

import r10ac_development as identity
import r10ac_contact_frame_replay as capture


def require(condition, reason):
    if not condition:
        raise ValueError('R10AC_CONTACT_REPORT_' + reason)


def link_valid(link, row, step):
    observation, source = link['global_observation'], link['source_trace']
    engine = observation['engine_step_identity']
    require(link['ok'] is True and link['semantic_step'] == row['global_semantic_step'] == step, 'LINK_STEP')
    require(capture.sha(observation) == row['observation_sha256'], 'OBSERVATION_HASH')
    require(capture.sha(source) == engine['source_trace_sha256'], 'SOURCE_HASH')
    require(source['semantic_step'] == source['direct_state_callback_sequence'] == source['host_step_after'] == step
        and source['host_step_before'] == step-1 and source['source_measurement'] is True, 'SOURCE_STEP')
    require(engine['schema_version'] == 'sporespore_recovery_engine_step_identity_v1'
        and engine['semantic_step'] == engine['host_step_after'] == step and engine['host_step_before'] == step-1
        and type(engine['native_solver_substep_count']) is int and engine['native_solver_substep_count'] == 1
        and engine['post_step_observation'] is True, 'ENGINE_STEP')


def replay_report(report, declaration, identity_guard=identity):
    identity_guard.validate_report_header(report, declaration)
    count = report['solver_step_count']
    require(type(count) is int and 1 <= count <= 3752, 'STEP_BOUND')
    arm, retained, links = (report[key] for key in ('retained_arm','r10ac_contact_frames','r10ac_contact_frame_links'))
    require(retained['schema_version'] == 'sporespore_r10ac_contact_frame_retention_v1'
        and links['schema_version'] == 'sporespore_r10ac_contact_frame_observation_links_v1', 'SCHEMA')
    for item in (retained, links):
        for key in ('controller_observation_changed','physical_acceptance_authority','release_authority'):
            require(item[key] is False, 'AUTHORITY')
        require(type(item['record_count']) is int and item['record_count'] == count
            and type(item['records']) is list and len(item['records']) == count, 'RECORD_POPULATION')
    rows, model, population = (arm[key] for key in ('trace_rows','model_instance_id','body_population_instance_sha256'))
    require(type(rows) is list and len(rows) == count and type(model) is str and model
        and type(population) is str, 'ARM_POPULATION')
    identities, previous_sequence = None, None
    matched = changed = 0
    for index, (record, link, row) in enumerate(zip(retained['records'], links['records'], rows, strict=True)):
        step = index+1
        require(row['arm_id'] == identity.ROLE and row['body_population_instance_sha256'] == population, 'TRACE_IDENTITY')
        link_valid(link, row, step)
        require(record['ok'] is True, 'CAPTURE_REJECTED')
        for key in ('controller_observation_changed','physical_acceptance_authority','release_authority'):
            require(record[key] is False, 'CAPTURE_AUTHORITY')
        require(type(record['world_build_count']) is int and type(record['solver_step_count']) is int
            and record['world_build_count'] == record['solver_step_count'] == 0, 'CAPTURE_COUNTERS')
        packet = record['packet']
        require(record['packet_sha256'] == capture.sha(packet), 'PACKET_HASH')
        replay = capture.replay(packet, step, model, population)
        require(replay == record['replay'], 'PACKET_REPLAY')
        for key in ('direct_state_source_sha256','contact_source_sha256'):
            require(packet['source_component_binding'][key] == link['source_trace'][key], 'SOURCE_TRACE_HASH')
        sequence = packet['contact_source_receipt']['native_space_step_sequence']
        require(sequence == link['source_trace']['native_space_step_sequence']
            and (previous_sequence is None or sequence == previous_sequence+1), 'NATIVE_SEQUENCE')
        previous_sequence = sequence
        current = dict(floor=packet['floor_instance_id'], **{b['body_id']:b['instance_id'] for b in packet['callback_bodies']})
        require(identities is None or identities == current, 'BODY_REPLACEMENT')
        identities = current
        matched += replay['matched_source_contacts']
        changed += sum(row['membership_changed'] for row in replay['comparisons'])
    return dict(ok=True, diagnostic_steps_replayed=count, matched_source_contacts=matched,
        classification_changes=changed, original_observation_hash_chain_verified=True,
        complete_controller_report_audited=False, controller_observation_changed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('declaration', type=Path)
    args = parser.parse_args()
    read = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
    print('R10AC_CONTACT_FRAME_REPORT '+json.dumps(replay_report(read(args.report),read(args.declaration))),flush=True)
