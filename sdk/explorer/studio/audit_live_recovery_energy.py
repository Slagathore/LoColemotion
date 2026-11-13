"""Reconstruct fresh-epoch measured work and replay the portable energy calls.

The native body-energy mapping is retained, not independently reimplemented
here. This reader independently reconstructs work, staging, accumulation and
ABI results. It opens no physics world and establishes no recovery success.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from audit_live_recovery_epoch import (LocomotionCore, audit as audit_epoch,
    audit_rows as audit_epoch_rows, bound, digest, dot, f32, require, sha, vec)

CHANNELS = ('applied_actuator_work_j', 'signed_external_work_j',
    'signed_constraint_exchange_j', 'signed_discrete_staging_exchange_j', 'passive_dissipation_j')
JOINTS = [f'{side}_{joint}' for side in ('front_left', 'front_right', 'rear_left', 'rear_right')
    for joint in ('hip', 'knee')]
CAPS = [0.05362625170687301, 0.4567500054836273] * 2 + [0.05637374829312699, 0.4567500054836273] * 2
PROFILE = 'godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_mapping_v1'
LEDGER_PROFILE = 'godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1'
ACTUATOR_MAPPING = 'godot_jolt_r24d144_solver_coupled_native_constraint_motor_mapping_v1'
WORK_MAPPING = 'godot_jolt_r24d144_current_step_native_hinge_motor_work_mapping_v1'
CONTEXT = dict(rotation_aware_energy_ledger_profile_selected=True,
    recovery_energy_ledger_profile_id=LEDGER_PROFILE,
    capability_variant_id='godot_jolt_r24d162_rotation_aware_discrete_staging_complete_energy_capability_v1',
    adapter_energy_mapping_profile_id=LEDGER_PROFILE,
    solver_energy_consumer_contract_schema_version='sporespore_qsdk_r24d157_godot_solver_energy_exchange_contract_v2',
    solver_energy_telemetry_schema_version='sporespore.godot_jolt_solver_energy_exchange_telemetry.v2',
    solver_energy_telemetry_profile_id='godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v6',
    r24d161_diagnosis_raw_sha256='sha256:1f163c137f04b180ebbddbd4774641d54ac145e46bd302a607ea551d6a61984e',
    partition_rule_id='godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1',
    complete_energy_profile_selected=True, solver_coupled_complete_energy_profile_selected=True,
    discrete_staging_complete_energy_profile_selected=True)


def finite(value):
    require(type(value) in (int, float) and math.isfinite(value), 'Nonfinite energy source')
    return value


def no_authority(value):
    for key in ('physics_state_modified', 'physical_acceptance_authority', 'release_authority'):
        require(value[key] is False, 'Energy overclaim')


def audit_sources(core, frame, source):
    bound(core, source)
    require(source['schema_version'] == 'sporespore_live_recovery_energy_sources_v1' and source['ok'] is True, 'Energy source schema')
    require(source['context'] == CONTEXT and source['frame_sha256'] == frame['payload_sha256'], 'Energy source context or frame')
    step, native = frame['completed_boundary']['boundary_sequence'], frame['native_space_step_sequence']
    require(source['global_step'] == step and source['native_step'] == native, 'Energy source clocks')
    no_authority(source)
    raw = source['raw']; passive = raw['no_actuation_requested']
    require(type(passive) is bool and raw['external_events'] == [], 'Unmeasured external work')
    require(len(raw['ordered_body_readbacks']) == 9, 'Body readback population')
    for readback, body in zip(raw['ordered_body_readbacks'], frame['ordered_body_sources'], strict=True):
        require(readback['body_id'] == body['body_id'] and vec(readback['total_gravity_world_m_s2']) == vec(body['total_gravity_world_m_s2']), 'Body source join')
        require(readback['linear_damp_mode'] == readback['angular_damp_mode'] == 1 and
            readback['linear_damp'] == readback['angular_damp'] == 0 and readback['continuous_cd'] is False, 'Unmeasured passive work')
    motors, joints, receipts = raw['ordered_motor_sources'], raw['ordered_joint_readbacks'], source['motor_receipts']
    require(len(motors) == len(joints) == len(receipts) == 8, 'Motor population')
    instances = []; work = 0.0; dt = None
    for index, (motor, joint, receipt) in enumerate(zip(motors, joints, receipts, strict=True)):
        actuator = JOINTS[index] + '_motor'
        require(motor['joint_id'] == joint['joint_id'] == receipt['joint_id'] == JOINTS[index] and
            motor['actuator_id'] == receipt['actuator_id'] == actuator, 'Motor source identity')
        require(type(motor['joint_instance_id']) is int and motor['joint_instance_id'] > 0, 'Motor instance')
        instances.append(motor['joint_instance_id'])
        require(joint['motor_enabled'] is (not passive), 'Motor enable policy')
        require(motor['published_cap_nms'] == CAPS[index] and 0 <= finite(motor['maximum_impulse_readback_nms']) <= CAPS[index], 'Motor cap')
        finite(motor['target_velocity_readback_rad_s'])
        telemetry = motor['telemetry']
        require(telemetry['schema'] == 'sporespore.godot_jolt_hinge_motor_telemetry.v2' and
            telemetry['captured_during_active_step'] is True and telemetry['snapshot_is_current_space_step'] is True, 'Motor source freshness')
        for key in ('capture_space_step_sequence', 'read_space_step_sequence'):
            require(telemetry[key] == receipt[key] == native, 'Motor source clock')
        current_dt = finite(telemetry['solver_step_s'])
        require(abs(current_dt - 1 / 120) <= 1e-9 and receipt['solver_step_s'] == current_dt and
            (dt is None or dt == current_dt), 'Motor solver time')
        dt = current_dt
        positive, absorbed = finite(telemetry['positive_motor_work_j']), finite(telemetry['absorbed_motor_work_j'])
        impulse = finite(telemetry['signed_motor_impulse_nms'])
        require(positive >= 0 and absorbed >= 0 and abs(impulse) <= CAPS[index], 'Motor source budget')
        net = positive - absorbed
        require(telemetry['net_motor_work_j'] == f32(net), 'Native motor work projection')
        if passive: require(positive == absorbed == impulse == 0, 'Nonzero passive motor work')
        for key, expected in dict(signed_motor_impulse_nms=impulse, positive_motor_work_j=positive,
            absorbed_motor_work_j=absorbed, net_motor_work_j=net, native_net_motor_work_j=f32(net),
            actuator_mapping_id=ACTUATOR_MAPPING, work_mapping_id=WORK_MAPPING,
            source_measurement=True, mechanical_energy_residual_used_as_work_source=False).items():
            require(receipt[key] == expected, 'Motor projection changed: ' + key)
        work += net
    require(len(set(instances)) == 8 and source['joint_instances'] == instances, 'Distinct motor instances')
    solver = raw['solver_telemetry']; projected = source['solver_receipt']
    require(solver['schema'] == CONTEXT['solver_energy_telemetry_schema_version'] and
        solver['profile_id'] == CONTEXT['solver_energy_telemetry_profile_id'], 'Solver source profile')
    for key in ('captured_during_active_step', 'snapshot_is_current_space_step', 'complete', 'source_measurement'):
        require(solver[key] is True, 'Incomplete solver source')
    require(solver['mechanical_energy_residual_used_as_work_source'] is False, 'Residual used as source')
    for key in ('capture_space_step_sequence', 'read_space_step_sequence'):
        require(solver[key] == projected[key] == native, 'Solver source clock')
    require(solver['telemetry_sequence'] > 0 and solver['collision_step_count'] == 1 and
        solver['velocity_measured_island_count'] == solver['position_measured_island_count'] == solver['constrained_island_count'] > 0,
        'Incomplete solver island coverage')
    require(solver['joint_velocity_phase_count'] > 0 and solver['position_constraint_phase_count'] > 0 and
        solver['contact_velocity_phase_count'] >= 0 and solver['dynamic_body_observation_count'] > 0, 'Solver phase coverage')
    require(0 < solver['rotation_integration_dynamic_body_count'] <= solver['rotation_integration_observed_active_body_count'] ==
        solver['rotation_integration_expected_active_body_count'], 'Incomplete rotation coverage')
    for key in ('rotation_integration_invalid_body_measurement_count', 'invalid_body_measurement_count',
        'large_island_velocity_batch_count', 'large_island_position_batch_count', 'ccd_active_body_count', 'active_soft_body_count', 'update_error_bits'):
        require(solver[key] == 0, 'Unsupported solver source')
    for key, value in frame['solver_energy_source'].items():
        require(projected[key] == value, 'Solver boundary source join')
    components = [finite(solver[k]) for k in ('joint_velocity_constraint_exchange_j', 'contact_velocity_constraint_exchange_j',
        'rotation_integration_kinetic_exchange_j', 'position_constraint_kinetic_exchange_j')]
    potential = -dot(vec(frame['ordered_body_sources'][0]['total_gravity_world_m_s2']),
        vec(solver['position_constraint_mass_weighted_displacement_kg_m']))
    require(projected['position_constraint_potential_exchange_j'] == potential, 'Solver potential projection')
    for key, value in zip(('joint_velocity_constraint_exchange_j', 'contact_velocity_constraint_exchange_j',
        'rotation_integration_kinetic_exchange_j', 'position_constraint_kinetic_exchange_j'), components, strict=True):
        require(projected[key] == value, 'Solver component projection')
    require(projected['step_signed_constraint_exchange_j'] == sum(components) + potential, 'Raw solver reconstruction')
    constraint = components[0] - work
    for component in components[1:]: constraint += component
    constraint += potential
    partition = source['constraint_partition']; inputs = source['partition_inputs']
    require(partition['ok'] is True and partition['step_actuator_work_j'] == work and
        partition['step_signed_constraint_exchange_j'] == constraint and partition['nonmotor_joint_constraint_exchange_j'] == components[0] - work,
        'Actuator and constraint partition')
    require(partition['native_motor_work_subtracted_exactly_once'] is True and
        partition['rotation_integration_exchange_included_exactly_once'] is True and
        partition['motor_work_also_counted_as_constraint_exchange'] is False, 'Partition overlap')
    require(inputs['ok'] is True and inputs['semantic_step'] == step and inputs['step_actuator_work_j'] == work and
        inputs['no_actuation_requested'] is passive, 'Input partition join')
    for key in ('step_signed_external_work_j', 'step_passive_dissipation_j', 'step_signed_discrete_staging_exchange_j',
        'external_intervention_event_count', 'adapter_side_discrete_staging_event_count'):
        require(inputs[key] == 0, 'Unexpected input partition work')
    return work, constraint


def transport_value(retained):
    raw = retained['utf8_text'].encode('utf-8')
    require(len(raw) == retained['utf8_byte_length'] and 'sha256:' + hashlib.sha256(raw).hexdigest() == retained['raw_sha256'], 'ABI transport binding')
    return json.loads(raw)


def audit_rows(core, epoch_rows, rows, start=300, expected_count=3):
    epoch_audit = audit_epoch_rows(core, epoch_rows, start=start, expected_count=expected_count)
    require(type(rows) is list and len(rows) == expected_count, 'Energy needs its declared origin and increments')
    previous = rows[0]['begin']['state']; bound(core, previous)
    origin = epoch_rows[0]['capture']; origin_epoch = epoch_rows[0]['transition']['state']
    initial = origin['mechanical_energy_j']; start = origin['completed_boundary']['boundary_sequence']
    require(rows[0]['begin']['ok'] is True and previous['epoch_state_sha256'] == origin_epoch['payload_sha256'] and
        previous['joint_instances'] == [] and previous['ledger']['source_values_sha256'] == origin['payload_sha256'], 'Fresh energy origin')
    accumulated = dict.fromkeys(CHANNELS, 0.0); increments = []
    for index, row in enumerate(rows):
        state = previous if index == 0 else row['transition']['state_after']; bound(core, state)
        require(state['schema_version'] == 'sporespore_live_recovery_energy_state_v1' and state['epoch_id'] == origin_epoch['epoch_id'] and
            state['context_sha256'] == digest(core, CONTEXT) and state['origin_global_step'] == start and
            state['increment_count'] == index and state['last_global_step'] == start + index, 'Energy state identity or clock')
        for key in ('unobserved_history_claimed', 'physical_acceptance_authority', 'release_authority'):
            require(state[key] is False, 'Energy state overclaim')
        ledger = state['ledger']; frame = epoch_rows[index]['capture']
        require(ledger['source_profile_id'] == PROFILE and ledger['source_measurement'] is True and
            ledger['initial_mechanical_energy_j'] == initial and ledger['current_mechanical_energy_j'] == frame['mechanical_energy_j'], 'Energy boundary join')
        if index:
            source, transition, epoch_transition = row['sources'], row['transition'], epoch_rows[index]['transition']
            work, constraint = audit_sources(core, frame, source)
            bound(core, transition); no_authority(transition)
            require(transition['ok'] is True and transition['schema_version'] == 'sporespore_live_recovery_energy_transition_v1' and
                transition['complete_measured_energy_partition'] is True and transition['controller_command_emitted'] is False and
                transition['world_build_count'] == transition['solver_step_count'] == 0, 'Energy transition scope')
            require(transition['state_before_sha256'] == previous['payload_sha256'] and
                state['epoch_state_sha256'] == epoch_transition['state_after']['payload_sha256'] and
                transition['measured_sources_sha256'] == source['payload_sha256'], 'Energy transition source join')
            require(state['joint_instances'] == source['joint_instances'] and (index == 1 or state['joint_instances'] == previous['joint_instances']), 'Joint replacement')
            increment = dict(sequence_index=index, semantic_step=start + index, applied_actuator_work_j=work,
                signed_constraint_exchange_j=constraint, signed_discrete_staging_exchange_j=epoch_transition['staging_observer_receipt']['signed_discrete_staging_exchange_j'],
                signed_external_work_j=0.0, passive_dissipation_j=0.0, source_measurement=True)
            require(transition['energy_increment'] == increment, 'Measured increment reconstruction')
            increments.append(increment)
            for channel in CHANNELS: accumulated[channel] += increment[channel]
            chain = dict(previous_source_values_sha256=previous['ledger']['source_values_sha256'],
                epoch_transition_sha256=epoch_transition['payload_sha256'], measured_sources_sha256=source['payload_sha256'],
                energy_increment=increment, current_mechanical_energy_j=frame['mechanical_energy_j'])
            require(transition['source_chain'] == chain and ledger['source_values_sha256'] == digest(core, chain), 'Energy provenance chain')
            call = transition['portable_evaluation_call']
            require(call['ok'] is True and call['compiled_call_count'] == 1 and call['method'] == 'recovery_energy_balance_evaluate_v3_json', 'Portable call identity')
            request = transport_value(call['request']); response = transport_value(call['response'])
            require(request == dict(schema_version='sporespore_recovery_energy_balance_evaluation_request_v3', ledger=ledger), 'Portable request join')
            require(response['ok'] is True and response['value'] == call['value'] == core.recovery_energy_balance_evaluate_v3(request) and
                call['value']['support_status'] == 'supported_exact', 'Portable evaluation replay')
        for channel in CHANNELS:
            require(ledger['cumulative_' + channel] == accumulated[channel], 'Energy accumulator: ' + channel)
        previous = state
    batch = core.recovery_energy_balance_aggregate_v3(dict(schema_version='sporespore_recovery_energy_balance_aggregation_request_v3',
        source_profile_id=PROFILE, initial_mechanical_energy_j=initial, current_mechanical_energy_j=previous['ledger']['current_mechanical_energy_j'],
        ordered_increments=increments))['ledger']
    for channel in CHANNELS: require(batch['cumulative_' + channel] == accumulated[channel], 'Portable batch accumulation')
    return dict(ok=True, increments=len(rows)-1, motor_source_observations=8*(len(rows)-1), independently_reconstructed_channels=5,
        portable_evaluations_replayed=len(rows)-1, portable_batch_accumulation_verified=True, boundary_audit=epoch_audit,
        mechanical_energy_mapping_independently_reimplemented=False, complete_recovery_handoff=False,
        reader_world_build_count=0, physical_acceptance_authority=False, release_authority=False)


def controls(core, fixture):
    audit_rows(core, fixture['epoch_rows'], fixture['energy_rows'])
    refused = 0
    source_mutations = [lambda s: s['raw']['ordered_motor_sources'].pop(),
        lambda s: s['raw']['ordered_motor_sources'][0]['telemetry'].__setitem__('net_motor_work_j', 1.0),
        lambda s: s['raw']['ordered_motor_sources'][0]['telemetry'].__setitem__('read_space_step_sequence', 1),
        lambda s: s['raw']['ordered_body_readbacks'][0].__setitem__('linear_damp', 0.2),
        lambda s: s['raw']['external_events'].append({'apply_at_frame': 301}),
        lambda s: s['raw']['solver_telemetry'].__setitem__('complete', False),
        lambda s: s['raw']['solver_telemetry'].__setitem__('rotation_integration_kinetic_exchange_j', 0),
        lambda s: s['constraint_partition'].__setitem__('step_signed_constraint_exchange_j', 0),
        lambda s: s['partition_inputs'].__setitem__('step_signed_external_work_j', 1),
        lambda s: s['raw'].__setitem__('no_actuation_requested', True)]
    for mutate in source_mutations:
        source = copy.deepcopy(fixture['energy_rows'][1]['sources']); mutate(source)
        source['payload_sha256'] = digest(core, source)
        try: audit_sources(core, fixture['epoch_rows'][1]['capture'], source)
        except (ValueError, KeyError, TypeError): refused += 1
        else: raise ValueError('Energy source reader accepted a corruption control')
    def reseal(value):
        if isinstance(value, dict):
            for child in value.values(): reseal(child)
            if 'payload_sha256' in value: value['payload_sha256'] = digest(core, value)
        elif isinstance(value, list):
            for child in value: reseal(child)
    mutations = [lambda x: x.pop(), lambda x: x.reverse(),
        lambda x: x[1]['transition']['energy_increment'].__setitem__('signed_discrete_staging_exchange_j', 1),
        lambda x: x[1]['transition']['state_after']['ledger'].__setitem__('initial_mechanical_energy_j', 0),
        lambda x: x[1]['transition']['state_after']['ledger'].__setitem__('cumulative_applied_actuator_work_j', 1),
        lambda x: x[1]['transition']['state_after'].__setitem__('unobserved_history_claimed', True),
        lambda x: x[1]['transition']['state_after'].__setitem__('increment_count', 2),
        lambda x: x[1]['transition']['portable_evaluation_call']['response'].__setitem__('utf8_text', '{}')]
    for mutate in mutations:
        changed = copy.deepcopy(fixture['energy_rows']); mutate(changed); reseal(changed)
        try: audit_rows(core, fixture['epoch_rows'], changed)
        except (ValueError, KeyError, TypeError): refused += 1
        else: raise ValueError('Energy reader accepted a corruption control')
    return dict(ok=True, controls=1 + refused, negative_controls=refused, world_build_count=0, solver_step_count=0)


def audit(folder, core_path):
    epoch = audit_epoch(folder, core_path)
    receipt = json.loads((folder / 'receipt.json').read_text())
    summary = receipt['physical']['completed']['summary']
    def retained(key):
        record = summary[key]['retained']; path = Path(record['path']).resolve()
        require(path.is_relative_to((folder / 'physical').resolve()) and sha(path) == record['sha256'], 'Energy retention binding')
        return json.loads(path.read_text())
    result = audit_rows(LocomotionCore(core_path), retained('live_recovery_epoch'), retained('live_recovery_energy'))
    require(summary['live_recovery_energy']['increment_count'] == 2 and summary['live_recovery_energy']['zero_world']['ok'] is True, 'Native energy gate')
    return dict(result, epoch_and_walking=epoch, core_sha256=sha(core_path))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path); parser.add_argument('--core', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(audit(args.folder, args.core), indent=2))
