"""Audit the compiled R10AB kernel checkpoint, not native or physical qualification."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import r10ab_loaded_rise_component as diagnosis

ROOT, EVIDENCE = diagnosis.ROOT, diagnosis.EVIDENCE
BASE = '3885950aac4185785c0af1271dc40af70be778b1'
RUN = EVIDENCE / 'r10ab-kernel-check-043f9aa978d04cacb6d96a642bae3494'
RECORD = ROOT / 'sdk/recovery/r10ab_downward_kernel_component_v1.json'
FIXTURE = ROOT / 'sdk/core/contracts/r10ab_retained_partial_observations_v1.json'
OWN = ('sdk/core/src/recovery_runtime/partial_downward_rise_control.rs',
       'sdk/core/src/recovery_runtime/tests/partial_downward_rise_control_tests.rs',
       'sdk/core/contracts/r10ab_retained_partial_observations_v1.json',
       'sdk/recovery/r10ab_downward_rise_kernel_contract_v1.json')
binding, read = diagnosis.binding, diagnosis.read


def observations():
    runtime = 'sdk/core/src/recovery_runtime.rs'
    original = subprocess.check_output(['git', 'show', BASE + ':' + runtime], cwd=ROOT).decode().replace('\r\n', '\n')
    expected = original.replace('pub mod partial_load_seeking_composition;\n',
        'pub mod partial_load_seeking_composition;\npub mod partial_downward_rise_control;\n')
    for stage, count, filtered in [('targeted', 8, 447), ('full', 455, 0)]:
        folder = RUN / stage
        execution = read(folder / 'execution.json')
        assert execution['exit_code'] == 0 and execution['source_unchanged'] is True
        assert execution['world_build_count'] == execution['solver_step_count'] == 0
        host = read(folder / 'host.json')
        assert host['rust_min_stack_bytes'] == 16777216 and host['test_threads'] == 2
        command = ['cargo', 'test', '--offline', '--manifest-path', 'sdk/Cargo.toml',
                   '-p', 'sporespore-locomotion-core', '--lib']
        if stage == 'targeted': command.append('partial_downward_rise_control::tests')
        assert host['command'] == command + ['--', '--nocapture', '--test-threads=2']
        assert read(folder / 'operation_lock.json')['acquired'] is True
        assert read(folder / 'source_capture.json')['base_head'] == BASE
        before = read(folder / 'source_before.json')
        assert before == read(folder / 'source_after.json')
        archive = folder / 'source_snapshot'
        for name in OWN:
            assert (ROOT / name).read_bytes() == (archive / name).read_bytes()
        assert (archive / runtime).read_text() == expected
        captured = {row['path']: row for row in before}
        for name in (*OWN[:3], runtime):
            row = captured[name]
            data = (archive / name).read_bytes()
            assert row['byte_length'] == len(data)
            assert row['raw_sha256'] == 'sha256:' + hashlib.sha256(data).hexdigest()
        # All other compiled core inputs are exactly the declared base commit.
        # Compare Git text with either checkout newline convention; archive
        # bindings retain the exact bytes used by this invocation.
        names = [row['path'] for row in before if row['path'] not in (*OWN[:3], runtime)]
        batch = subprocess.run(['git', 'cat-file', '--batch'], cwd=ROOT,
            input=''.join(BASE + ':' + name + '\n' for name in names).encode(),
            stdout=subprocess.PIPE, check=True).stdout
        offset = 0
        for name in names:
            end = batch.index(b'\n', offset)
            header = batch[offset:end].split()
            assert len(header) == 3 and header[1] == b'blob'
            length = int(header[2]); data = batch[end+1:end+1+length]
            offset = end + length + 2
            variants = {data, data.replace(b'\r\n', b'\n'), data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')}
            assert any(captured[name]['byte_length'] == len(v) and captured[name]['raw_sha256'] == 'sha256:' + hashlib.sha256(v).hexdigest() for v in variants), name
        with (folder / 'stdout.log').open(encoding='utf-8-sig') as stream:
            lines = [line.strip() for line in stream if line.startswith(('test ', 'R10AB_'))]
        assert any(line.startswith(f'test result: ok. {count} passed; 0 failed; 0 ignored; 0 measured; {filtered} filtered out;') for line in lines)
        tests = [line for line in lines if line.startswith('test recovery_runtime::partial_downward_rise_control::tests::')]
        assert len(tests) == 8 and all(line.endswith(' ... ok') for line in tests)
        assert all(marker in lines for marker in ('R10AB_COUNTERFACTUAL_PARITY 646',
            'R10AB_LOADED_ADMISSION 44', 'R10AB_UNCHANGED_PHASE_PARITY 646 602'))
    fixture = read(FIXTURE)
    closed = diagnosis.probe.closed
    assert fixture['report'] == binding(closed.CHILD / 'worker_report.json')
    assert fixture['probe'] == binding(diagnosis.RUN / 'result.json')
    model = read(diagnosis.RUN / 'result.json')
    count = 0
    for kind, packet in closed.partial_records(closed.CHILD / 'worker_report.json'):
        if kind != 'packet': continue
        raw = packet['call']['request']['utf8_text'].encode()
        assert 'sha256:' + hashlib.sha256(raw).hexdigest() == packet['call']['request']['raw_sha256']
        request = json.loads(raw)
        row = model['observations'][count]
        assert request['step']['observation'] == packet['bound_observations']['observation_v3']
        assert fixture['descriptor'] == request['collection']['descriptor']
        assert fixture['entries'][count] == dict(observation=request['step']['observation'],
            prior_phase=row['phase'], original_mode=row['original_mode'],
            expected=row['alternatives']['downward_quarter'])
        count += 1
    assert count == len(fixture['entries']) == 646
    return dict(kernel_implemented=True, core_tests=455, new_kernel_tests=8, existing_core_tests=447,
        original_v3_requests_verified=646, compiled_counterfactual_parity=646,
        loaded_admission_checks=44, unchanged_support_checks=646, unchanged_weak_raise_checks=602,
        native_composition_integrated=False, native_api_integrated=False, worker_integrated=False,
        physical_population_declared=False, physical_load_retention_proven=False,
        complete_smoke_safety_gate_passed=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def run(capture=False):
    result = observations()
    if capture:
        assert not RECORD.exists()
        files = [p for p in sorted(RUN.rglob('*')) if p.is_file()]
        value = dict(schema_version='sporespore_r10ab_downward_kernel_component_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral',
                              authority_mode='zero_world_kernel_component', question_class='development'),
            dependencies=[binding(p) for p in (Path(__file__), diagnosis.RECORD,
                ROOT / 'sdk/core/src/recovery_runtime/partial_load_seeking_control.rs',
                ROOT / 'sdk/core/src/recovery_runtime/partial_pose_geometry_control.rs',
                *(ROOT / name for name in OWN))],
            retained_evidence=[binding(p) for p in files], observed=result,
            validation_host='Two Rust test threads with 16 MiB stacks; no physical deadline or controller limit changed.',
            finite_work_bound='Loaded rise: 135 unchanged validation candidates plus 135 downward-filtered search candidates. Weak support: unchanged maximum of 195 candidates.',
            next_action='Integrate distinct V24 partial composition, profile, C ABI and Godot forwarders; validate native command forwarding before qualifying a fresh physical diagnostic.',
            predecessor_retry_permitted=False, physical_acceptance_authority=False, release_authority=False)
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, indent=2, allow_nan=False); stream.write('\n')
    else:
        value = read(RECORD)
        for row in value['dependencies'] + value['retained_evidence']:
            assert row == binding(Path(row['path']))
        assert value['observed'] == result
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    print('R10AB_DOWNWARD_KERNEL_COMPONENT ' + json.dumps(run(parser.parse_args().capture)))
