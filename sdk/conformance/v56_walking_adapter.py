"""Run or independently audit V56's finite actual-Godot adapter checks.

The runner requires the caller's locomotion operation lock. The default auditor
is read-only: it checks original retained packets and bytes, without a world or
a native call. Full R10S qualification and physical results remain separate.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

import v55_walking_adapter as prior
from development_passive_entry_profile import _source_snapshot

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/development/v56_walking_adapter_implementation_v1.json'
POLICY = 'sporespore_balanced_wave_recovery_extended_preparation_v1'
RECEIPT = 'sporespore_recovery_extended_preparation_controller_step_receipt_v1'


def read(path):
    return json.loads(Path(path).read_bytes())


def require(value, code):
    if not value:
        raise ValueError('V56_ADAPTER_' + code)


def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    require(sha(path) == item['raw_sha256'], 'FILE_BYTES:' + str(path))
    if 'byte_length' in item:
        require(path.stat().st_size == item['byte_length'], 'FILE_LENGTH')
    return path


def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def run():
    out = ROOT.parent / 'SporeSpore_Evidence' / ('v56-adapter-complete-launch-' + uuid.uuid4().hex)
    out.mkdir()
    before = _source_snapshot()
    write(out / 'source_before.json', before)
    command = [sys.executable, '-B', '-m', 'unittest', 'test_development_v56_walking_adapter',
        'test_development_v56_adapter_boundaries', '-v']
    env = dict(os.environ, PYTHONUTF8='1',
        PYTHONPATH=os.pathsep.join(str(ROOT / p) for p in ['sdk/python', 'sdk/conformance', 'tests']),
        SPORE_V56_WALKING_ADAPTER_ROOT=str(out / 'adapter'), SPORE_V56_BOUNDARY_ROOT=str(out / 'boundaries'))
    write(out / 'invocation.json', dict(command=command, world_build_count=0, solver_step_count=0))
    print('V56_ADAPTER_LAUNCH ' + out.as_posix(), flush=True)
    started = time.monotonic()
    try:
        with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr,
                timeout=300, creationflags=subprocess.CREATE_NO_WINDOW)
        write(out / 'execution.json', dict(exit_code=process.returncode,
            seconds=round(time.monotonic() - started, 3), world_build_count=0, solver_step_count=0))
    except subprocess.TimeoutExpired:
        write(out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
        raise
    finally:
        after = _source_snapshot()
        write(out / 'source_after.json', after)
        write(out / 'source-stability.json', dict(source_unchanged=before == after))
    require(before == after, 'SOURCE_DRIFT')
    print((out / 'stderr.log').read_text(encoding='utf-8')[-8000:], flush=True)
    return dict(evidence_root=out.as_posix(), exit_code=process.returncode, source_unchanged=True)


def audit_result(base, policy):
    """Reconcile the output populations and all 44 cold native response files."""
    require(read(base / 'execution.json')['exit_code'] == 0, 'OUTER_EXECUTION')
    require((base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes(), 'OUTER_SOURCE')
    counts = {}
    for name, check_count, cold_count in [('adapter', 277, 29), ('boundaries', 144, 15)]:
        path = base / name
        result = read(path / 'result.json')
        require(read(path / 'execution.json')['exit_code'] == 0
            and 'ERROR:' not in (path / 'stderr.log').read_text(encoding='utf-8'), 'GODOT_EXECUTION:' + name)
        require((path / 'source_before.json').read_bytes() == (path / 'source_after.json').read_bytes(), 'SOURCE:' + name)
        require(result['ok'] is True and len(result['checks']) == check_count
            and all(value is True for value in result['checks'].values()), 'CHECKS:' + name)
        require(result['world_build_count'] == result['solver_step_count'] == 0
            and result['physical_acceptance_authority'] is False and result['release_authority'] is False, 'CLAIMS')
        cold = read(path / 'cold-replay.json')
        require(cold['source_unchanged'] is True and len(cold['rows']) == cold_count, 'COLD_POPULATION')
        for row in cold['rows']:
            stem = row['case'] if name == 'boundaries' else f"{row['policy']}-{row['step']}"
            if name == 'boundaries':
                malformed = row['case'] in ['missing_body_frame', 'caller_limit_override']
                require(row['method'] == ('ss_balanced_wave_policy_session_step_json' if malformed
                    else 'ss_balanced_wave_policy_step_json'), 'COLD_API_IDENTITY')
                if malformed:
                    require(read(path / (stem + '.stateless-response.json'))['failure_code'] == 'SCHEMA_INVALID', 'STATELESS_ABI_REFUSAL')
            require(row['response_byte_exact'] is True
                and row['actual_response_sha256'] == row['expected_response_sha256']
                == sha(path / (stem + '.cold-response.json')), 'COLD_BYTES')
        counts[name] = check_count
    adapter = read(base / 'adapter/result.json')
    require(set(adapter['results']) == {'v56', 'v55', 'v54', 'v53', 'v52', 'v51', 'v50'}, 'POLICIES')
    for label, result in adapter['results'].items():
        require(len(result['steps']) == len(result['refusals']) == 3
            and all(r['response']['ok'] is False for r in result['refusals']), 'POLICY_POPULATION')
        require(result['start']['ok'] is True and result['facade_start']['ok'] is True
            and result['motor_ledger']['ok'] is True, 'PRODUCTION_HANDOFF')
        for index, step in enumerate(result['steps']):
            value = step['response']['value']
            require(value['actuation']['safe_no_actuation'] is False, 'SUCCESSFUL_COMMAND')
            transfer = value['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
            require(transfer.get('maximum_preparation_commands') == 360 if label == 'v56'
                else 'maximum_preparation_commands' not in transfer, 'DISTINCT_LIMIT')
            if index:
                require(step['request']['memory'] == result['steps'][index - 1]['response']['value']['next_memory'], 'MEMORY_CHAIN')
    selected = adapter['results']['v56']
    require(selected['native_profile'] == policy['native_profile']
        and selected['start']['controller_profile_sha256'] == policy['native_profile_sha256'], 'PROFILE')
    require(len(adapter['braking_results']) == 8, 'BRAKING_POPULATION')
    for row in adapter['braking_results']:
        prior.audit_motor_application(row['motor_braking'], row['response']['value']['actuation']['ordered_commands'])
    boundaries = read(base / 'boundaries/result.json')
    inputs = read(base / 'boundaries/input.json')['boundaries']
    require(len(boundaries['boundaries']) == len(inputs) == 15, 'BOUNDARY_POPULATION')
    positives = refusals = abi_refusals = 0
    for fixture, row in zip(inputs, boundaries['boundaries']):
        require(row['case'] == fixture['case'], 'BOUNDARY_IDENTITY')
        expected = json.loads(fixture['raw_response_utf8'])
        actual = read(base / 'boundaries' / (row['case'] + '.cold-response.json'))
        require(actual['ok'] == expected['ok'], 'BOUNDARY_RESULT_KIND')
        if expected['ok']:
            require(actual['value']['actuation']['ordered_commands'] == expected['value']['actuation']['ordered_commands'], 'BOUNDARY_COMMANDS')
            if expected['value']['actuation']['safe_no_actuation']:
                failure = row['response']['development_native_step_failure']
                require(row['response']['ok'] is False and failure['verified_zero_actuation_refusal'] is True
                    and failure['motor_application_permitted'] is False and 'value' not in row['response'], 'ZERO_REFUSAL')
                require(actual['value']['actuation']['receipt']['controller_error']
                    == expected['value']['actuation']['receipt']['controller_error'], 'REFUSAL_REASON')
                refusals += 1
            else:
                require(row['response']['ok'] is True
                    and actual['value']['actuation']['receipt']['schema_version'] == RECEIPT, 'BOUNDARY_SUCCESS')
                positives += 1
        else:
            require(actual['failure_code'] == expected['failure_code'] and row['response']['ok'] is False, 'ABI_REFUSAL')
            abi_refusals += 1
    require((positives, refusals, abi_refusals) == (8, 5, 2), 'BOUNDARY_KINDS')
    readers = boundaries['readers']
    for name in ['policy', 'receipt_schema', 'limit_240', 'limit_361', 'limit_missing', 'limit_string',
        'session_start_policy', 'session_profile', 'session_finalization', 'session_publication']:
        require(readers[name]['ok'] is False, 'READER_REFUSAL:' + name)
    return dict(ok=True, actual_godot_checks=sum(counts.values()), native_responses_byte_exact=44,
        stateless_response_comparisons=42, session_abi_refusal_comparisons=2,
        policy_sessions=7, boundary_cases=15, boundary_successes=8, verified_zero_refusals=5,
        typed_abi_refusals=2, world_build_count=0, solver_step_count=0,
        full_r10s_route_registered=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_v56_walking_adapter_implementation_v1', 'SCHEMA')
    require(record['status'] == 'native_policy_adapter_and_readers_verified_full_route_pending', 'STATUS')
    policy = read(verify(record['policy_contract']))
    require(policy['policy_id'] == POLICY and policy['maximum_preparation_commands'] == 360, 'POLICY')
    for item in policy['policy_binding_evidence'] + record['retained_evidence']:
        verify(item)
    runtime = read(verify(record['runtime_binding']))
    verify(runtime['runtime'])
    verify(record['native_component'])
    if current_sources:
        for item in record['source_files'] + runtime['source_files']:
            verify(item)
    result = audit_result(Path(record['evidence_root']), policy)
    require(result == record['observed'], 'OBSERVATION')
    return dict(result, current_sources_verified=current_sources,
        retained_evidence_files=len(record['retained_evidence']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    result = run() if args.run else audit(args.current_sources)
    print('V56_WALKING_ADAPTER ' + json.dumps(result, separators=(',', ':')))
    if args.run and result['exit_code']:
        raise SystemExit(result['exit_code'])
