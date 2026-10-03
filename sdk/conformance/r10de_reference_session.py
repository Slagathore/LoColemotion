"""Retained zero-world Godot qualification of the V29 worker packet session."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import traceback
import zipfile
import r10dd_native_interfaces_v2 as prior

C = prior.C
SCRIPT = C.ROOT / 'tests/test_r10de_reference_session.gd'
CONTRACT = C.ROOT / 'sdk/recovery/r10de_reference_session_contract_v1.json'
RECORD = C.ROOT / 'sdk/recovery/r10de_reference_session_component_v1.json'
WRAPPER = C.ROOT / 'sdk/run_r10de_reference_session.ps1'
EARLIER = [
    ('r10de-reference-session-50b2977a2dd74951b24bc7cc99bf3ef8', False),
    ('r10de-reference-session-092a1eaeea8540908950b7a0fe116269', True),
    ('r10de-reference-session-3b6cbba2a9cb4000b08cc5365d7ea312', True),
]


def dependencies():
    found = {Path(__file__), CONTRACT, WRAPPER, prior.BINDING, prior.EXTENSION,
             prior.component.INPUTS, C.ROOT / 'sdk/development/r10ap_host_runtime_contract_v1.json'}
    pending = [SCRIPT]
    while pending:
        path = pending.pop()
        if path in found:
            continue
        found.add(path)
        pending.extend(C.ROOT / name for name in re.findall(r'"res://([^"\n]+\.gd)"', path.read_text(encoding='utf-8')))
    return sorted(found)


def run(folder):
    folder = Path(folder).resolve()
    assert folder.is_relative_to(C.EVIDENCE)
    lock = C.read(folder / 'operation-lock.json')
    assert lock['acquired'] and lock['owner_process_id'] == os.getppid()
    prior.audit()
    before = [C.bind(path) for path in dependencies()]
    C.write_new(folder / 'bindings-before.json', before)
    with zipfile.ZipFile(folder / 'source.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
        for path in dependencies():
            archive.write(path, path.relative_to(C.ROOT).as_posix())
    binding = C.read(prior.BINDING)
    inputs = C.read(prior.component.INPUTS)['fixture']
    engine = C.read(C.ROOT / 'sdk/development/r10ap_host_runtime_contract_v1.json')['images']['godot_engine']
    for bound in (binding['runtime'], binding['compiled_fixtures'], inputs, engine):
        prior.verify(bound)
    C.write_new(folder / 'declaration.json', dict(contract=C.bind(CONTRACT), runtime=binding['runtime'],
                 compiled_fixtures=binding['compiled_fixtures'], original_numeric_inputs=inputs, engine=engine))
    command = [engine['path'], '--headless', '--path', str(C.ROOT), '--script',
               'res://tests/test_r10de_reference_session.gd', '--', binding['compiled_fixtures']['path'],
               inputs['path'], str(folder / 'godot-result.json')]
    env = {k: v for k, v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_', 'SPORE_R10AG_'))}
    state = dict(ok=False)
    try:
        with (folder / 'stdout.txt').open('xb') as out, (folder / 'stderr.txt').open('xb') as err:
            with subprocess.Popen(command, cwd=C.ROOT, env=env, stdout=out, stderr=err,
                                  creationflags=subprocess.CREATE_NO_WINDOW) as process:
                try:
                    code = process.wait(timeout=180)
                    timed_out = False
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    code, timed_out = process.returncode, True
        C.write_new(folder / 'godot-execution.json', dict(command=command, return_code=code, timed_out=timed_out))
        assert code == 0 and not timed_out and (folder / 'stderr.txt').read_bytes() == b''
        result = C.read(folder / 'godot-result.json')
        assert result['ok'] and all(result['checks'].values()) and result['packet_count'] == 238
        assert len((folder / 'godot-result.json.packets.jsonl').read_text(encoding='utf-8').splitlines()) == 238
        assert result['world_build_count'] == result['solver_step_count'] == 0
        state['ok'] = True
    except BaseException:
        state['error'] = traceback.format_exc()
        raise
    finally:
        after = [C.bind(path) for path in dependencies()]
        C.write_new(folder / 'bindings-after.json', after)
        state['source_unchanged'] = before == after
        C.write_new(folder / 'execution.json', state)
    assert state['source_unchanged']
    print(json.dumps(dict(ok=True, checks=len(result['checks']), packets=result['packet_count'], execution_root=str(folder))))


def close(folder):
    folder = Path(folder).resolve()
    assert folder.is_relative_to(C.EVIDENCE)
    assert C.read(folder / 'execution.json') == dict(ok=True, source_unchanged=True)
    result = C.read(folder / 'godot-result.json')
    assert result['ok'] and result['packet_count'] == 238 and all(result['checks'].values())
    assert C.read(folder / 'host-execution.json')['exit_code'] == 0
    before = C.read(folder / 'bindings-before.json')
    assert before == C.read(folder / 'bindings-after.json') == [C.bind(p) for p in dependencies()]
    earlier = []
    for name, succeeded in EARLIER:
        attempt = C.EVIDENCE / name
        state = C.read(attempt / 'execution.json')
        assert state['ok'] is succeeded and state['source_unchanged']
        assert (C.read(attempt / 'host-execution.json')['exit_code'] == 0) is succeeded
        earlier.append(dict(execution_root=attempt.as_posix(), succeeded=succeeded,
            disposition='passing_initial_coverage_superseded_by_added_outcome_cases' if succeeded else 'test_parse_failure',
            evidence=[C.bind(p) for p in sorted(attempt.iterdir()) if p.is_file()]))
    C.write_new(RECORD, dict(schema_version='sporespore_r10de_reference_session_component_v1',
        ledger_scope=C.read(CONTRACT)['ledger_scope'], execution_root=folder.as_posix(), dependencies=before,
        earlier_attempts=earlier,
        evidence=[C.bind(p) for p in sorted(folder.iterdir()) if p.is_file()],
        observed=dict(checks_passed=len(result['checks']), retained_packet_count=238,
            command_sequence_checked=236, final_post_step_observation_checked=True,
            native_replay_checked=True, source_application_binding_checked=True,
            source_bridge_and_session_qualified=True, physical_worker_integrated=False,
            complete_safety_gate_qualified=False, world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False)))
    return audit()


def audit():
    record = C.read(RECORD)
    for binding in record['dependencies'] + record['evidence']:
        prior.verify(binding)
    for attempt in record['earlier_attempts']:
        for binding in attempt['evidence']:
            prior.verify(binding)
    folder = Path(record['execution_root'])
    result = C.read(folder / 'godot-result.json')
    assert result['ok'] and all(result['checks'].values()) and result['packet_count'] == 238
    packets = [json.loads(line) for line in (folder / 'godot-result.json.packets.jsonl').read_text(encoding='utf-8').splitlines()]
    assert len(packets) == 238
    assert all(p['ok'] and p['action'] == 'command' for p in packets[:-1])
    assert packets[-1]['action'] == 'stop' and packets[-1]['next_control'] is None
    assert packets[-1]['diagnostic_stop_reason'] == 'finite_reference_exhausted_not_recovery_completion'
    assert C.read(folder / 'execution.json') == dict(ok=True, source_unchanged=True)
    assert C.read(folder / 'host-execution.json')['exit_code'] == 0
    assert C.read(folder / 'bindings-before.json') == C.read(folder / 'bindings-after.json') == record['dependencies']
    assert record['observed']['checks_passed'] == len(result['checks'])
    return record['observed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run')
    parser.add_argument('--close')
    args = parser.parse_args()
    if args.run:
        run(args.run)
    else:
        print(json.dumps(close(args.close) if args.close else audit(), indent=2))
