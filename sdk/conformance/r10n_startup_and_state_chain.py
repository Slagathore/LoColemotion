"""Retained startup comparison and native-owned memory on exposed histories.

No changed commands are applied to a body. The old measured trajectories are
input fixtures, not predictions of the current controller's physical response.
The caller holds the native operation lock.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

import r10n_zero_world_state_sweep as sweep

ROOT = sweep.ROOT
DESIGN = ROOT / 'sdk/recovery/r10n_startup_and_state_chain_design_v1.json'
RECORD = ROOT / 'sdk/recovery/r10n_startup_and_state_chain_v1.json'


def differences(a, b, path=''):
    if isinstance(a, dict) and isinstance(b, dict):
        return [p for key in sorted(set(a) | set(b)) for p in differences(a.get(key), b.get(key), path+'/'+key)]
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return [path + '/length']
        return [p for i, (x, y) in enumerate(zip(a, b)) for p in differences(x, y, path+'/'+str(i))]
    return [] if a == b else [path]


def startup_comparison(design):
    starts = []
    for source in design['startup_reports']:
        report = sweep.failure.read(sweep.verified(source))
        starts.append(report['development_walking_entry']['rows'][:2])
        del report
    old, new = starts
    paths = differences(old[0]['request'], new[0]['request'])
    sweep.require(paths == ['/floor_reference/geometry_source_sha256', '/floor_reference/source_instance_id',
        '/measured_body_frame/adapter_capability_sha256', '/memory/schema_version', '/state/adapter_capability_sha256'], 'STARTUP_IDENTITY_DIFFERENCES')
    sweep.require(old[0]['ordered_body_states'] == new[0]['ordered_body_states'], 'STARTUP_BODY_STATES')
    motors = []
    for a, b in zip(old[0]['ordered_motor_applications'], new[0]['ordered_motor_applications']):
        sweep.require(a['actuator_id'] == b['actuator_id']
            and a['declared_maximum_impulse_nms'] == b['declared_maximum_impulse_nms']
            and a['requested_target_position_rad'] == b['requested_target_position_rad']
            and a['clamped_target_position_rad'] == b['clamped_target_position_rad'], 'STARTUP_REFERENCE_AND_CAPS')
        sweep.require(a['controller_target_velocity_rad_s'] == a['motor_target_velocity_readback_rad_s']
            and abs(a['controller_target_velocity_rad_s']) == .25
            and b['controller_target_velocity_rad_s'] == b['motor_target_velocity_readback_rad_s'] == 0, 'STARTUP_MOTOR_READBACK')
        motors.append(dict(actuator_id=a['actuator_id'], r10m_velocity_rad_s=a['controller_target_velocity_rad_s'],
            r10n_velocity_rad_s=b['controller_target_velocity_rad_s'], unchanged_impulse_cap_nms=a['declared_maximum_impulse_nms']))
    sweep.require(len(motors) == 8 and old[1]['ordered_body_states'] != new[1]['ordered_body_states'], 'FIRST_PHYSICAL_DIVERGENCE')
    return dict(first_request_different_paths=paths, first_measured_body_states_equal=True,
        first_numeric_request_values_equal=True, first_motor_applications=motors,
        second_request_different_paths=differences(old[1]['request'], new[1]['request']),
        second_measured_body_states_equal=False, later_timeout_causality_proven=False,
        hidden_solver_state_equivalence_proven=False)


def run(design, stream=None):
    for item in design['source_files']:
        sweep.verified(item)
    startup = startup_comparison(design)
    core = sweep.refusal.RecordedCore(sweep.verified(design['runtime']))
    descriptor = sweep.failure.read(sweep.verified(design['descriptor_source']))['configuration']['base_descriptor']
    descriptor = sweep.refusal.integers(descriptor)
    populations, count, raw_length, digest = [], 0, 0, hashlib.sha256()
    for population in design['chain_reports']:
        report = sweep.failure.read(sweep.verified(population['report']))
        rows = report['development_walking_entry']['rows']
        sweep.require(len(rows) == population['walking_commands'], 'EXPOSED_HISTORY_LENGTH')
        failure = report['detail']['portable_step_receipt']['development_native_step_failure']
        original_refusal = json.loads(failure['request']['utf8_text'])
        memory = core.balanced_wave_policy_initial_memory(sweep.POLICY, descriptor)
        for limb in memory['ordered_limb_memory']:
            limb['gait_step'] = 90
            limb['evidence_gait_step_limit'] = 1530
        valid, refused, measurements_consumed = 0, None, 0
        for i in range(len(rows) + 1):
            original = rows[i]['request'] if i < len(rows) else original_refusal
            q = sweep.refusal.integers(dict(copy.deepcopy(original), descriptor=descriptor))
            q.update(schema_version='sporespore_balanced_wave_policy_step_request_v3', policy_id=sweep.POLICY, memory=memory)
            sweep.require(q['state']['semantic_step'] == i + 1, 'MEASURED_CLOCK')
            out = core.balanced_wave_policy_step_with_measured_body(sweep.POLICY, q)
            raw = core.raw_response
            item = dict(population=population['id'], command=i+1,
                request_sha256=sweep.refusal.digest(core._input_bytes(q)),
                raw_response_sha256=sweep.refusal.digest(raw), raw_response_utf8=raw.decode('utf-8'))
            encoded = (json.dumps(item, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode('utf-8')
            if stream is not None:
                stream.write(encoded)
            digest.update(encoded); raw_length += len(encoded); count += 1; measurements_consumed += 1
            if out['actuation']['safe_no_actuation']:
                sweep.require(out['next_memory'] == memory and len(out['actuation']['ordered_commands']) == 8
                    and all(c['target_velocity_rad_s'] == 0 for c in out['actuation']['ordered_commands']), 'REFUSAL_SIDE_EFFECT')
                refused = dict(command=i+1, error=out['actuation']['receipt']['controller_error'])
                break
            valid += 1
            memory = out['next_memory']
        populations.append(dict(id=population['id'], available_measured_inputs=len(rows)+1,
            consumed_measured_inputs=measurements_consumed, valid_commands=valid, first_refusal=refused,
            original_refusal_input_consumed=measurements_consumed == len(rows)+1,
            final_memory=memory, physical_response_to_new_outputs_observed=False))
        del report, rows
    return dict(startup_comparison=startup, populations=populations, native_step_calls=count,
        response_stream_bytes=raw_length, response_stream_sha256='sha256:'+digest.hexdigest(),
        world_build_count=0, solver_step_count=0, held_out_cell_access_count=0,
        original_attempt_reclassified=False, physical_acceptance_authority=False, release_authority=False)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    design = sweep.failure.read(DESIGN)
    target = Path(design['output_root'])
    sweep.require(target.parent == ROOT.parent / 'SporeSpore_Evidence', 'EVIDENCE_ROOT')
    if args.create:
        target.mkdir(exist_ok=False)
        with (target / 'native-responses.jsonl').open('xb') as stream:
            result = run(design, stream)
        record = dict(schema_version='sporespore_r10n_startup_and_state_chain_v1', ledger_scope=design['ledger_scope'],
            design=sweep.failure.binding(DESIGN), response_stream=sweep.failure.binding(target / 'native-responses.jsonl'), result=result)
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(record, stream, indent=2, allow_nan=False); stream.write('\n')
    else:
        record = sweep.failure.read(RECORD)
        sweep.verified(record['design']); sweep.verified(record['response_stream'])
        result = run(design)
        sweep.require(result == record['result'], 'COLD_RECONSTRUCTION')
    sweep.require(record['response_stream']['raw_sha256'] == result['response_stream_sha256']
        and record['response_stream']['byte_length'] == result['response_stream_bytes'], 'RESPONSE_STREAM')
    print(json.dumps(dict(ok=True, first_numeric_inputs_equal=True, first_changed_motors=8,
        native_step_calls=result['native_step_calls'], populations=[{k:v for k,v in p.items() if k != 'final_memory'} for p in result['populations']],
        world_build_count=0, solver_step_count=0, sdk1_score='14/20')))


if __name__ == '__main__':
    main()
