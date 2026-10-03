"""Finite diagnostics on exposed measurements; never a physical continuation.

Run under the locomotion operation lock. Synthetic startup gait phases do not
stand for the physical handoff poses produced by 360 different prefix phases.
Every original report and threshold stays immutable.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

import development_recovery_refusal as refusal
import r10n_development_failure as failure
from sporespore_locomotion import LocomotionCoreError

ROOT = failure.ROOT
DESIGN = ROOT / 'sdk/recovery/r10n_zero_world_state_sweep_design_v1.json'
RECORD = ROOT / 'sdk/recovery/r10n_zero_world_state_sweep_v1.json'
POLICY = 'sporespore_balanced_wave_recovery_zero_velocity_brake_v1'
MEMORY = 'sporespore_balanced_wave_recovery_zero_velocity_brake_memory_v1'


def require(value, code):
    if not value:
        raise ValueError('R10N_STATE_SWEEP_' + code)


def verified(item):
    require(failure.binding(item['path']) == item, 'BOUND_FILE:' + item['path'])
    return Path(item['path'])


def run(design, stream=None):
    """Regenerate the complete native-response stream with bounded inputs."""
    require(design['policy_id'] == POLICY and design['startup_gait_phases'] == list(range(360)), 'DESIGN')
    for item in design['source_files']:
        verified(item)
    core = refusal.RecordedCore(verified(design['runtime']))
    descriptor = failure.read(verified(design['descriptor_source']))['configuration']['base_descriptor']
    descriptor = refusal.integers(descriptor)
    population, total, stream_hash, stream_bytes = [], 0, hashlib.sha256(), 0

    def request(row):
        q = refusal.integers(dict(copy.deepcopy(row['request']), descriptor=descriptor))
        q['schema_version'] = 'sporespore_balanced_wave_policy_step_request_v3'
        q['policy_id'] = POLICY
        q['memory']['schema_version'] = MEMORY
        return q

    def call(identity, q, expected=None):
        nonlocal total, stream_bytes
        try:
            out = core.balanced_wave_policy_step_with_measured_body(POLICY, q)
        except LocomotionCoreError:
            # A typed ABI rejection is an observed diagnostic result; preserve
            # its exact native response and never infer a safe motor command.
            out = None
        raw = core.raw_response
        digest = refusal.digest(raw)
        if expected is not None:
            require(digest == expected, 'ORIGINAL_NATIVE_BYTES')
        if out is None:
            category = 'abi_rejection:' + str(json.loads(raw).get('failure_code'))
        else:
            actuation = out['actuation']
            if actuation['safe_no_actuation']:
                require(out['next_memory'] == q['memory'] and len(actuation['ordered_commands']) == 8
                        and all(c['target_velocity_rad_s'] == 0 for c in actuation['ordered_commands']), 'REFUSAL_SIDE_EFFECT')
                category = 'controller_refusal:' + actuation['receipt']['controller_error']
            else:
                category = 'valid_native_command'
        result = dict(identity=identity, request_sha256=refusal.digest(core._input_bytes(q)),
            category=category, raw_response_sha256=digest, raw_response_utf8=raw.decode('utf-8'))
        encoded = (json.dumps(result, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode('utf-8')
        stream_hash.update(encoded); stream_bytes += len(encoded); total += 1
        if stream is not None:
            stream.write(encoded)
        return category, out

    for source in design['populations']:
        report = failure.read(verified(source['report']))
        rows = report['development_walking_entry']['rows']
        require(len(rows) == source['walking_commands'] and rows[0]['session_local_step'] == 1
                and rows[1]['session_local_step'] == 2, 'SOURCE_POPULATION')
        original = source['id'] == 'r10n_no_kick_phase241'
        history, history_refusals, startup = {}, [], {}
        for row in rows:
            category, _ = call(dict(population=source['id'], lane='copied_recorded_input', command=row['session_local_step']),
                request(row), row['raw_native_response_sha256'] if original else None)
            history[category] = history.get(category, 0) + 1
            if category != 'valid_native_command':
                history_refusals.append(dict(command=row['session_local_step'], category=category))
        if source['includes_terminal_refusal']:
            failed = report['detail']['portable_step_receipt']['development_native_step_failure']
            q = request(dict(request=json.loads(failed['request']['utf8_text'])))
            category, _ = call(dict(population=source['id'], lane='copied_original_refusal', command=len(rows)+1),
                q, failed['response']['raw_sha256'] if original else None)
            history_refusals.append(dict(command=len(rows)+1, category=category))
        for phase in design['startup_gait_phases']:
            first = request(rows[0])
            for limb in first['memory']['ordered_limb_memory']:
                limb['gait_step'] = phase
                limb['evidence_gait_step_limit'] = phase + 1440
            category, out = call(dict(population=source['id'], lane='synthetic_startup', phase=phase, command=1), first)
            if category == 'valid_native_command':
                second = request(rows[1])
                second['memory'] = out['next_memory']
                category, _ = call(dict(population=source['id'], lane='synthetic_startup', phase=phase, command=2), second)
            startup.setdefault(category, []).append(phase)
        population.append(dict(id=source['id'], copied_history=history,
            original_refusal_and_other_nonvalid_commands=history_refusals, startup_phase_categories=startup))
        if original:
            # These synthetic memory cases describe the exact existing cutoff.
            # The measured pose is the last observed ready input, command 857.
            boundaries = []
            for prep, dwell, expected in [(239, 4, 'hold'), (240, 4, 'refuse'), (240, 5, 'release')]:
                q = request(rows[-1])
                q['memory']['measured_support_transfer'].update(preparation_commands=prep, ready_dwell_commands=dwell)
                category, out = call(dict(population=source['id'], lane='synthetic_readiness_boundary',
                    preparation_commands=prep, ready_dwell_commands=dwell), q)
                if category == 'valid_native_command':
                    transfer = out['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
                    actual = 'release' if transfer['preparation_released_this_command'] else 'hold'
                else:
                    actual = 'refuse'
                require(actual == expected and out is not None, 'READINESS_BOUNDARY')
                boundaries.append(dict(preparation_commands=prep, incoming_ready_dwell=dwell, result=actual, category=category))
        del report, rows
    return dict(native_calls=total, populations=population, readiness_boundaries=boundaries,
        response_stream_byte_length=stream_bytes, response_stream_sha256='sha256:' + stream_hash.hexdigest(),
        world_build_count=0, solver_step_count=0, held_out_cell_access_count=0,
        original_attempt_reclassified=False, physical_acceptance_authority=False, release_authority=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    design = failure.read(DESIGN)
    target = Path(design['output_root'])
    require(target.parent == ROOT.parent / 'SporeSpore_Evidence', 'EVIDENCE_ROOT')
    if args.create:
        target.mkdir(exist_ok=False)
        with (target / 'native-responses.jsonl').open('xb') as stream:
            result = run(design, stream)
        record = dict(schema_version='sporespore_r10n_zero_world_state_sweep_v1', ledger_scope=design['ledger_scope'],
            design=failure.binding(DESIGN), response_stream=failure.binding(target / 'native-responses.jsonl'), result=result)
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(record, stream, indent=2, allow_nan=False); stream.write('\n')
    else:
        record = failure.read(RECORD)
        verified(record['design']); verified(record['response_stream'])
        result = run(design)
        require(result == record['result'], 'RECONSTRUCTED_RESULT')
    require(result['response_stream_sha256'] == record['response_stream']['raw_sha256']
            and result['response_stream_byte_length'] == record['response_stream']['byte_length'], 'COMPLETE_RESPONSE_STREAM')
    print(json.dumps(dict(ok=True, native_calls=result['native_calls'], readiness_boundaries=result['readiness_boundaries'],
        populations=[dict(id=p['id'], copied_history=p['copied_history'],
            startup_categories={k:len(v) for k,v in p['startup_phase_categories'].items()}) for p in result['populations']],
        world_build_count=0, solver_step_count=0, sdk1_score='14/20')))


if __name__ == '__main__':
    main()
