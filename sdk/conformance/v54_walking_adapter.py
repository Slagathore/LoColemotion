"""Read-only audit of retained V54 adapter integration; no native call or world."""
import argparse
import hashlib

from v52_extended_support_transfer import ROOT, read, require, verify

RECORD = ROOT / 'sdk/development/v54_walking_adapter_implementation_v1.json'


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_v54_walking_adapter_implementation_v1', 'V54_ADAPTER_SCHEMA')
    require(record['status'] == 'native_policy_adapter_and_facade_verified_full_route_pending', 'V54_ADAPTER_STATUS')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        full_r10n_route_registered=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False,
        original_campaign_regraded=False, sdk1_score='14/20'), 'V54_ADAPTER_CLAIMS')
    native = read(verify(record['native_component']))
    verify(native['runtime'])
    verify(native['runtime_binding'])
    policy_path = verify(record['policy_contract'])
    policy = read(policy_path)
    for item in policy['policy_binding_evidence']:
        verify(item)
    evidence = set()
    for item in record['retained_evidence']:
        require(item['path'] not in evidence, 'V54_ADAPTER_DUPLICATE_EVIDENCE')
        evidence.add(item['path'])
        verify(item)
    if current_sources:
        for item in record['source_files']:
            verify(item)
    final_path = verify(record['final_result'])
    base = final_path.parent
    result = read(final_path)
    require(read(base / 'execution.json')['exit_code'] == 0
        and 'ERROR:' not in (base / 'stderr.log').read_text(encoding='utf-8'), 'V54_ADAPTER_EXECUTION')
    require((base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes()
        and read(base / 'source-stability.json')['source_unchanged'] is True, 'V54_ADAPTER_SOURCE_DRIFT')
    require(result['ok'] is True and len(result['checks']) == 206
        and all(result['checks'].values()), 'V54_ADAPTER_CHECKS')
    require(result['world_build_count'] == result['solver_step_count'] == 0
        and not result['full_route_registered'] and not result['physical_acceptance_authority']
        and not result['release_authority'], 'V54_ADAPTER_NATIVE_CLAIMS')
    inputs = read(base / 'input.json')
    require(len(inputs['fixtures']) == 3 and len(inputs['exposed_sources']) == 11 and len(inputs['braking_fixtures']) == 8, 'V54_ADAPTER_INPUTS')
    for source in inputs['exposed_sources']:
        verify(source)
    for label in ['v54', 'v53', 'v52', 'v51', 'v50']:
        retained = result['results'][label]
        require(len(retained['steps']) == len(retained['refusals']) == 3
            and all(row['response']['ok'] is False for row in retained['refusals']), 'V54_ADAPTER_REFUSALS')
        for index, step in enumerate(retained['steps'], 1):
            output = step['response']['value']
            require(step['request']['state']['semantic_step'] == index
                and step['response']['ok'] is True and len(output['actuation']['ordered_commands']) == 8
                and output['actuation']['safe_no_actuation'] is False, 'V54_ADAPTER_NATIVE_STEP')
            if index > 1:
                require(step['request']['memory'] == retained['steps'][index - 2]['response']['value']['next_memory'],
                    'V54_ADAPTER_MEMORY_CHAIN')
        ledger = retained['motor_ledger']
        require(retained['facade_start']['ok'] is True and ledger['ok'] is True
            and ledger['detached_hinge_parameter_container_count'] == 8
            and ledger['scene_tree_insertion_count'] == ledger['solver_step_count'] == ledger['world_build_count'] == 0,
            'V54_ADAPTER_PRODUCTION_LEDGER')
    for label, retained in result['results'].items():
        for step in retained['steps']:
            transfer = step['response']['value']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
            require(transfer.get('maximum_absolute_reference_bias_rad') == 0.30 if label in ('v54','v53','v52')
                else 'maximum_absolute_reference_bias_rad' not in transfer, 'V54_ADAPTER_RANGE_IDENTITY')
    selected = result['results']['v54']
    require(selected['native_profile'] == policy['native_profile']
        and selected['start']['controller_profile_sha256'] == policy['native_profile_sha256']
        and selected['motor_ledger']['walking_actuation_handoff_receipt']['selected_policy_digest'] == record['policy_contract']['raw_sha256'],
        'V54_ADAPTER_EXACT_POLICY')
    require(len(result['braking_results']) == 8, 'V54_ADAPTER_CLIPPED_POPULATION')
    for step, fixture in zip(result['braking_results'], inputs['braking_fixtures']):
        response = step['response']
        require(response['ok'] is True and response['value']['actuation']['ordered_commands']
            == fixture['expected_commands'], 'V54_ADAPTER_CLIPPED_COMMANDS')
        guard = response['value']['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['zero_amplitude_motor_brake']
        require(guard['zero_applied_impulse_claim'] is False and len(guard['ordered_commands']) == 8
            and all(c['held_target_velocity_rad_s'] == 0 for c in guard['ordered_commands']), 'V54_ADAPTER_NATIVE_BRAKE')
        audit_motor_application(step['motor_braking'], response['value']['actuation']['ordered_commands'])
    cold = read(base / 'cold-replay.json')
    require(cold['source_unchanged'] is True and len(cold['rows']) == 23, 'V54_ADAPTER_COLD_POPULATION')
    for row in cold['rows']:
        response = (base / f"{row['policy']}-{row['step']}.cold-response.json").read_bytes()
        require(row['native_status'] == 0 and row['response_byte_exact'] is True
            and row['expected_response_sha256'] == row['actual_response_sha256']
            == 'sha256:' + hashlib.sha256(response).hexdigest(), 'V54_ADAPTER_COLD_BYTES')
    return dict(ok=True, actual_godot_checks_passed=206, native_responses_byte_exact=23,
        braked_native_commands=8, enabled_zero_velocity_motor_applications=64,
        actual_policy_facades=5, retained_evidence_files=len(evidence),
        current_sources_verified=current_sources, **record['claim_boundary'])


def audit_motor_application(motor, commands):
    require(motor['detached_hinge_parameter_container_count'] == 8
        and motor['scene_tree_insertion_count'] == motor['world_build_count'] == motor['solver_step_count'] == 0
        and motor['physical_acceptance_authority'] is False and motor['release_authority'] is False, 'V54_MOTOR_SCOPE')
    caps = motor['cap_binding']['selected_host_cap_by_actuator_id']
    before, sentinels, after = motor['before'], motor['sentinels'], motor['after']
    application = motor['application']
    require(motor['cap_binding']['ok'] is True and motor['configuration']['ok'] is True
        and motor['configuration']['motor_enabled'] is True
        and before['ok'] is True and sentinels['ok'] is True and after['ok'] is True
        and after['motor_enabled_count'] == after['zero_target_velocity_count'] == 8
        and application['ok'] is True and application['applied_command_count'] == 8, 'V54_MOTOR_EXECUTION')
    rows = [before['ordered_joint_readbacks'],sentinels['ordered_joint_readbacks'],after['ordered_joint_readbacks'],application['ordered_applications'],commands]
    require(all(len(items) == 8 for items in rows), 'V54_MOTOR_POPULATION')
    for old, sentinel, held, applied, command in zip(*rows):
        actuator = old['actuator_id']
        require(actuator == sentinel['actuator_id'] == held['actuator_id'] == applied['actuator_id'] == command['actuator_id'], 'V54_MOTOR_IDENTITY')
        require(old['motor_enabled'] is sentinel['motor_enabled'] is held['motor_enabled'] is True
            and abs(sentinel['motor_target_velocity_rad_s']) == .125
            and old['motor_target_velocity_rad_s'] == held['motor_target_velocity_rad_s'] == command['target_velocity_rad_s']
            == applied['controller_target_velocity_rad_s'] == applied['host_applied_target_velocity_rad_s']
            == applied['motor_target_velocity_readback_rad_s'] == 0, 'V54_MOTOR_HOLD')
        require(old['motor_maximum_impulse_nms'] == sentinel['motor_maximum_impulse_nms'] == held['motor_maximum_impulse_nms']
            == applied['motor_maximum_impulse_readback_nms'] == caps[actuator] > 0
            and applied['host_additional_clamp_applied'] is False, 'V54_MOTOR_CAPS')
    require(set(motor['negative_controls']) == {'disabled_motor','zero_impulse_cap'}
        and all(row['ok'] is False and row['failure_code'].startswith('QSDK_R10F_LOCOMOTION_MOTOR_READBACK_INVALID:')
                for row in motor['negative_controls'].values()), 'V54_MOTOR_NEGATIVE_CONTROLS')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    import json
    print('V54_WALKING_ADAPTER ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
