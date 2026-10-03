"""Read-only audit of retained V55 adapter integration; no native call or world."""
import argparse
import hashlib
import struct

from v52_extended_support_transfer import ROOT, read, require, verify

RECORD = ROOT / 'sdk/development/v55_walking_adapter_implementation_v1.json'


def run():
    """Caller owns the operation lock; retain even failures before Godot launch."""
    import json, os, subprocess, sys, time, uuid
    from development_passive_entry_profile import _source_snapshot
    out = ROOT.parent / 'SporeSpore_Evidence' / ('development-v55-walking-adapter-' + uuid.uuid4().hex)
    out.mkdir()
    def write(name, value):
        (out / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')
    before = _source_snapshot(); write('source_before.json', before)
    env = dict(os.environ, SPORE_V55_ADAPTER_ROOT=str(out / 'adapter'))
    command = [sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests',
               '-p', 'test_development_v55_walking_adapter.py', '-v']
    started = time.monotonic()
    try:
        with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=stdout,
                stderr=stderr, timeout=300, creationflags=subprocess.CREATE_NO_WINDOW)
        write('execution.json', dict(command=command, exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
    except subprocess.TimeoutExpired:
        write('execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
        raise
    finally:
        after = _source_snapshot(); write('source_after.json', after)
        write('source-stability.json', dict(source_unchanged=before == after))
    return dict(evidence_root=out.as_posix(), exit_code=process.returncode, source_unchanged=before == after)


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_v55_walking_adapter_implementation_v1', 'V55_ADAPTER_SCHEMA')
    require(record['status'] == 'native_policy_adapter_and_facade_verified_full_route_pending', 'V55_ADAPTER_STATUS')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        full_r10o_route_registered=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False,
        original_campaign_regraded=False, sdk1_score='14/20'), 'V55_ADAPTER_CLAIMS')
    native = read(verify(record['native_component']))
    verify(native['runtime'])
    verify(native['runtime_binding'])
    policy_path = verify(record['policy_contract'])
    policy = read(policy_path)
    for item in policy['policy_binding_evidence']:
        verify(item)
    evidence = set()
    for item in record['retained_evidence']:
        require(item['path'] not in evidence, 'V55_ADAPTER_DUPLICATE_EVIDENCE')
        evidence.add(item['path'])
        verify(item)
    if current_sources:
        for item in record['source_files']:
            verify(item)
    final_path = verify(record['final_result'])
    base = final_path.parent
    result = read(final_path)
    require(read(base / 'execution.json')['exit_code'] == 0
        and 'ERROR:' not in (base / 'stderr.log').read_text(encoding='utf-8'), 'V55_ADAPTER_EXECUTION')
    require((base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes()
        and read(base / 'source-stability.json')['source_unchanged'] is True, 'V55_ADAPTER_SOURCE_DRIFT')
    require(result['ok'] is True and len(result['checks']) == 231
        and all(result['checks'].values()), 'V55_ADAPTER_CHECKS')
    require(result['world_build_count'] == result['solver_step_count'] == 0
        and not result['full_route_registered'] and not result['physical_acceptance_authority']
        and not result['release_authority'], 'V55_ADAPTER_NATIVE_CLAIMS')
    inputs = read(base / 'input.json')
    require(len(inputs['fixtures']) == 3 and len(inputs['exposed_sources']) == 11 and len(inputs['braking_fixtures']) == 8, 'V55_ADAPTER_INPUTS')
    require(sum(f['request']['memory']['last_semantic_step'] is None for f in inputs['braking_fixtures']) == 2,
        'V55_ADAPTER_INITIALIZATION_POPULATION')
    for source in inputs['exposed_sources']:
        verify(source)
    for label in ['v55', 'v54', 'v53', 'v52', 'v51', 'v50']:
        retained = result['results'][label]
        require(len(retained['steps']) == len(retained['refusals']) == 3
            and all(row['response']['ok'] is False for row in retained['refusals']), 'V55_ADAPTER_REFUSALS')
        for index, step in enumerate(retained['steps'], 1):
            output = step['response']['value']
            require(step['request']['state']['semantic_step'] == index
                and step['response']['ok'] is True and len(output['actuation']['ordered_commands']) == 8
                and output['actuation']['safe_no_actuation'] is False, 'V55_ADAPTER_NATIVE_STEP')
            if index > 1:
                require(step['request']['memory'] == retained['steps'][index - 2]['response']['value']['next_memory'],
                    'V55_ADAPTER_MEMORY_CHAIN')
        ledger = retained['motor_ledger']
        require(retained['facade_start']['ok'] is True and ledger['ok'] is True
            and ledger['detached_hinge_parameter_container_count'] == 8
            and ledger['scene_tree_insertion_count'] == ledger['solver_step_count'] == ledger['world_build_count'] == 0,
            'V55_ADAPTER_PRODUCTION_LEDGER')
    for label, retained in result['results'].items():
        for step in retained['steps']:
            transfer = step['response']['value']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
            require(transfer.get('maximum_absolute_reference_bias_rad') == 0.30 if label in ('v55','v54','v53','v52')
                else 'maximum_absolute_reference_bias_rad' not in transfer, 'V55_ADAPTER_RANGE_IDENTITY')
    selected = result['results']['v55']
    require(selected['native_profile'] == policy['native_profile']
        and selected['start']['controller_profile_sha256'] == policy['native_profile_sha256']
        and selected['motor_ledger']['walking_actuation_handoff_receipt']['selected_policy_digest'] == record['policy_contract']['raw_sha256'],
        'V55_ADAPTER_EXACT_POLICY')
    require(len(result['braking_results']) == 8, 'V55_ADAPTER_CLIPPED_POPULATION')
    for step, fixture in zip(result['braking_results'], inputs['braking_fixtures']):
        response = step['response']
        component_raw = fixture['raw_component_response_utf8'].encode()
        import json
        require('sha256:' + hashlib.sha256(component_raw).hexdigest() == fixture['expected_response_sha256']
            and json.loads(component_raw)['value']['actuation']['ordered_commands'] == fixture['expected_commands'],
            'V55_ADAPTER_COMPONENT_EXPECTATION_BYTES')
        require(response['ok'] is True and response['value']['actuation']['ordered_commands']
            == fixture['expected_commands'], 'V55_ADAPTER_CLIPPED_COMMANDS')
        pose = response['value']['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']
        if fixture['request']['memory']['last_semantic_step'] is None:
            require('zero_amplitude_velocity_guard' in pose and 'zero_amplitude_motor_brake' not in pose
                and all(abs(c['target_velocity_rad_s']) <= .25 for c in fixture['expected_commands']), 'V55_ADAPTER_NATIVE_INITIALIZATION')
        else:
            guard = pose['zero_amplitude_motor_brake']
            require('zero_amplitude_velocity_guard' not in pose and guard['zero_applied_impulse_claim'] is False
                and len(guard['ordered_commands']) == 8 and all(c['held_target_velocity_rad_s'] == 0
                    for c in guard['ordered_commands']), 'V55_ADAPTER_NATIVE_BRAKE')
        audit_motor_application(step['motor_braking'], response['value']['actuation']['ordered_commands'])
    cold = read(base / 'cold-replay.json')
    require(cold['source_unchanged'] is True and len(cold['rows']) == 26, 'V55_ADAPTER_COLD_POPULATION')
    for row in cold['rows']:
        response = (base / f"{row['policy']}-{row['step']}.cold-response.json").read_bytes()
        require(row['native_status'] == 0 and row['response_byte_exact'] is True
            and row['expected_response_sha256'] == row['actual_response_sha256']
            == 'sha256:' + hashlib.sha256(response).hexdigest(), 'V55_ADAPTER_COLD_BYTES')
    return dict(ok=True, actual_godot_checks_passed=231, native_responses_byte_exact=26,
        initialized_native_commands=2, braked_native_commands=6, bounded_initialization_motor_applications=16,
        enabled_zero_velocity_motor_applications=48, actual_policy_facades=6, retained_evidence_files=len(evidence),
        current_sources_verified=current_sources, **record['claim_boundary'])


def audit_motor_application(motor, commands):
    require(motor['detached_hinge_parameter_container_count'] == 8
        and motor['scene_tree_insertion_count'] == motor['world_build_count'] == motor['solver_step_count'] == 0
        and motor['physical_acceptance_authority'] is False and motor['release_authority'] is False, 'V55_MOTOR_SCOPE')
    caps = motor['cap_binding']['selected_host_cap_by_actuator_id']
    before, sentinels, after = motor['before'], motor['sentinels'], motor['after']
    application = motor['application']
    require(motor['cap_binding']['ok'] is True and motor['configuration']['ok'] is True
        and motor['configuration']['motor_enabled'] is True
        and before['ok'] is True and sentinels['ok'] is True and after['ok'] is True
        and after['motor_enabled_count'] == 8
        and application['ok'] is True and application['applied_command_count'] == 8, 'V55_MOTOR_EXECUTION')
    rows = [before['ordered_joint_readbacks'],sentinels['ordered_joint_readbacks'],after['ordered_joint_readbacks'],application['ordered_applications'],commands]
    require(all(len(items) == 8 for items in rows), 'V55_MOTOR_POPULATION')
    for old, sentinel, held, applied, command in zip(*rows):
        actuator = old['actuator_id']
        require(actuator == sentinel['actuator_id'] == held['actuator_id'] == applied['actuator_id'] == command['actuator_id'], 'V55_MOTOR_IDENTITY')
        expected_readback = struct.unpack('<f', struct.pack('<f', command['target_velocity_rad_s']))[0]
        require(old['motor_enabled'] is sentinel['motor_enabled'] is held['motor_enabled'] is True
            and abs(sentinel['motor_target_velocity_rad_s']) == .125
            and old['motor_target_velocity_rad_s'] == 0
            and command['target_velocity_rad_s'] == applied['controller_target_velocity_rad_s']
            == applied['host_applied_target_velocity_rad_s']
            and held['motor_target_velocity_rad_s'] == applied['motor_target_velocity_readback_rad_s'] == expected_readback
            and held['motor_target_velocity_rad_s'] != sentinel['motor_target_velocity_rad_s'], 'V55_MOTOR_APPLICATION')
        require(old['motor_maximum_impulse_nms'] == sentinel['motor_maximum_impulse_nms'] == held['motor_maximum_impulse_nms']
            == applied['motor_maximum_impulse_readback_nms'] == caps[actuator] > 0
            and applied['host_additional_clamp_applied'] is False, 'V55_MOTOR_CAPS')
    require(set(motor['negative_controls']) == {'disabled_motor','zero_impulse_cap'}
        and all(row['ok'] is False and row['failure_code'].startswith('QSDK_R10F_LOCOMOTION_MOTOR_READBACK_INVALID:')
                for row in motor['negative_controls'].values()), 'V55_MOTOR_NEGATIVE_CONTROLS')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    import json
    result = run() if args.run else audit(args.current_sources)
    print('V55_WALKING_ADAPTER ' + json.dumps(result, separators=(',', ':')))
    if args.run and result['exit_code']:
        raise SystemExit(result['exit_code'])
