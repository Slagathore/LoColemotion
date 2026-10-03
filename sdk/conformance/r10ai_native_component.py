"""Retain and audit R10AI native composition interfaces, with zero worlds.

Run --run under the native-operation lock. This component verifies a separately
built DLL, not a physical worker, candidate admission, or complete safety gate.
The historical kernel proof stays bound to its original source commit.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import traceback
import uuid

import r10ag_replay_invalid_closure as closure
import r10ag_native_interface as prior_interface
import r10ai_kernel_component as kernel
import r10aa_native_component as build_audit
import development_passive_entry_profile as source
from development_recovery_refusal import RecordedCore
from sporespore_locomotion import LocomotionCoreError

ROOT, EVIDENCE = closure.ROOT, closure.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10ai_concurrent_load_rise_native_component_v1.json'
BINDING = ROOT/'sdk/development/recovery_candidates/r10ai-concurrent-load-rise-core-v1.runtime.json'
EXTENSION = ROOT/'sdk/adapters/godot/development_candidate_runtimes/r10ai-concurrent-load-rise-core-v1.gdextension'
SCRIPT = ROOT/'tests/test_r10ai_native_api.gd'
KERNEL_HEAD = '15d03e67b3f4929e654c9e3020cf4634eb427509'
IDS = ['partial_entry', 'partial_step_1', 'partial_step_2', 'partial_step_3', 'partial_step_63', 'weak_raise', 'raise_timeout']
CLAIMS = dict(native_controller_composition_integrated=True, physical_worker_integrated=False,
    positive_hold_walking_consumer_coverage_complete=False, complete_safety_gate_qualified=False,
    new_physical_population_declared=False, original_attempt_reclassified=False,
    world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def verify(item):
    return build_audit.verify(item)


def fixtures(binding, marker):
    parsed = []
    for line in verify(binding['compiled_fixtures']).read_text(encoding='utf-8').splitlines():
        _, found, payload = line.partition(marker)
        if found:
            parsed.append(json.loads(payload))
    assert all(row['physical_source'] is False for row in parsed)
    return parsed


def historical_kernel():
    """Authenticate old evidence without renewing its changed live-source key."""
    record = closure.read(kernel.RECORD)
    for item in record['files'] + record['retained_failed_fixture_attempt'] + record['retained_failed_parser_attempt']:
        verify(item)
    out = Path(record['evidence_root'])
    assert closure.read(out/'source-before.json') == closure.read(out/'source-after.json')
    bindings = closure.read(out/'bindings-before.json')
    assert bindings == closure.read(out/'bindings-after.json')
    for item in bindings:
        path = Path(item['path'])
        if path.is_relative_to(ROOT):
            raw = subprocess.check_output(['git', 'show', KERNEL_HEAD+':'+path.relative_to(ROOT).as_posix()], cwd=ROOT)
            variants = (raw, raw.replace(b'\n', b'\r\n')) if b'\r\n' not in raw else (raw,)
            assert any(len(v) == item['byte_length'] and 'sha256:'+hashlib.sha256(v).hexdigest() == item['raw_sha256'] for v in variants), item['path']
        else:
            verify(item)
    assert closure.read(out/'execution.json')['ok'] is True
    assert closure.read(out/'execution.json')['source_unchanged'] is True
    for label in ('build', 'tests'):
        execution = closure.read(out/(label+'.execution.json'))
        assert execution['returncode'] == 0 and execution['timed_out'] is False
    assert record['observed'] == closure.read(out/'measurements.json')
    return dict(commit=KERNEL_HEAD, component=closure.bind(kernel.RECORD), original_bindings_authenticated=True)


def inputs():
    binding = closure.read(BINDING)
    build_audit.verify_frozen_build(binding)
    assert binding['core_test_count'] == 474
    for item in binding['source_files'] + binding['build_evidence_files'] + [binding['runtime'], binding['compiled_fixtures']]:
        verify(item)
    assert closure.bind(ROOT/binding['local_build_path'])['raw_sha256'] == binding['runtime']['raw_sha256']
    current = fixtures(binding, 'R10AI_PARTIAL_FIXTURE ')
    assert [row['id'] for row in current] == IDS
    text = verify(binding['compiled_fixtures']).read_text()
    assert '13 passed; 0 failed' in text
    old_binding = closure.read(prior_interface.FIXTURE_BINDING)
    old = fixtures(old_binding, 'R10AA_PARTIAL_FIXTURE ')
    assert [row['id'] for row in old] == IDS[:5]
    verify(old_binding['runtime'])
    engine = closure.read(ROOT/'sdk/development/r10ag_host_runtime_contract_v1.json')['images']['godot_engine']
    verify(engine)
    return binding, current, old_binding, old, engine


def cases(current, old):
    for transport in ('abi', 'python'):
        for row in current:
            yield dict(id=transport+'_'+row['id'], transport=transport, runtime='new', method=row['method'], request=row['request'], expected=row['expected'])
        # Reuse the declared crossed schema/source/owner/clock/energy/morphology
        # mutations; only this successor's API name changes.
        for name, symbol, request, expected in prior_interface.cases(current):
            if expected is None:
                yield dict(id=transport+'_'+name, transport=transport, runtime='new',
                    method=symbol.removeprefix('ss_').removesuffix('_json').replace('r10aa', 'r10ai'), request=request, expected=None)
    for runtime in ('new', 'old'):
        for row in old:
            yield dict(id='compatibility_'+runtime+'_'+row['id'], transport='abi', runtime=runtime,
                method=row['method'], request=row['request'], expected=row['expected'])
    for row, code in zip(current[:2], ('R10AI_ENTRY_RUNTIME_UNAVAILABLE', 'R10AI_STEP_RUNTIME_UNAVAILABLE')):
        yield dict(id='old_missing_'+row['id'], transport='python', runtime='old', method=row['method'],
            request=row['request'], expected=None, failure_code=code)


def validate_rows(rows, current, old):
    expected = list(cases(current, old))
    assert len(rows) == len(expected) == 60
    for row, case in zip(rows, expected):
        assert row['case'] == case
        if case['expected'] is None:
            assert row['result'] is None and row['failure_code'], case['id']
            if 'failure_code' in case:
                assert row['failure_code'] == case['failure_code'] and row['response_raw_utf8'] is None
            else:
                raw = json.loads(row['response_raw_utf8'])
                assert raw['ok'] is False
        else:
            assert row['failure_code'] is None and row['result'] == case['expected'], case['id']
            raw = json.loads(row['response_raw_utf8'])
            assert raw['ok'] is True and raw['value'] == row['result']
    return dict(native_successes=24, native_refusals=36, new_fixture_count=7,
        python_public_fixture_successes=7, python_public_crossed_refusals=17,
        old_api_compatibility_calls=10, old_runtime_unavailable_refusals=2)


def run_native(out, binding, current, old_binding, old):
    cores = dict(new=RecordedCore(binding['runtime']['path']), old=RecordedCore(old_binding['runtime']['path']))
    rows = []
    with (out/'native-calls.jsonl').open('x', encoding='utf-8', newline='\n') as trace:
        for case in cases(current, old):
            core = cores[case['runtime']]
            core.raw_response = None
            result = failure = None
            try:
                if case['transport'] == 'python':
                    result = getattr(core, case['method'])(case['request'])
                else:
                    result = core._call_json_input('ss_'+case['method']+'_json', case['request'])
            except LocomotionCoreError as error:
                failure = error.failure_code
            row = dict(case=case, result=result, failure_code=failure,
                response_raw_utf8=core.raw_response.decode('utf-8') if core.raw_response is not None else None)
            trace.write(json.dumps(row, separators=(',', ':'), allow_nan=False)+'\n')
            trace.flush()
            rows.append(row)
    return validate_rows(rows, current, old)


def run_godot(out, binding, engine):
    # A SceneTree script calls the extension directly. No physics model, worker,
    # campaign declaration, historical seed or world permission is selected.
    command = [engine['path'], '--headless', '--path', str(ROOT), '--script', 'res://tests/test_r10ai_native_api.gd',
        '--', binding['compiled_fixtures']['path'], str(out/'godot-result.json')]
    environment = {k:v for k,v in os.environ.items() if not k.startswith(('SPORESPORE_GODOT_RECOVERY_', 'SPORE_R10AG_'))}
    with (out/'godot.stdout.txt').open('xb') as stdout, (out/'godot.stderr.txt').open('xb') as stderr:
        with subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr, env=environment,
                creationflags=subprocess.CREATE_NO_WINDOW) as process:
            try:
                code = process.wait(timeout=180)
                timed_out = False
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(); code = process.returncode; timed_out = True
            closure.write_new(out/'godot.execution.json', dict(command=command, process_id=process.pid,
                returncode=code, timed_out=timed_out, timeout_seconds=180, **CLAIMS))
    assert code == 0 and not timed_out, (code, (out/'godot.stderr.txt').read_text())
    assert (out/'godot.stderr.txt').read_bytes() == b''
    return godot_result(out)


def godot_result(out):
    value = closure.read(out/'godot-result.json')
    assert value['ok'] and value['checks'] and all(value['checks'].values())
    for identity in IDS:
        for suffix in ('method', 'native_success', 'exact_value', 'crossed_schema_refused'):
            assert value['checks'][identity+'_'+suffix] is True
    assert value['new_fixture_calls'] == value['negative_calls'] == 7
    assert value['world_build_count'] == value['solver_step_count'] == 0
    assert not value['physical_acceptance_authority'] and not value['release_authority']
    receipt = closure.read(out/'godot.execution.json')
    assert receipt['returncode'] == 0 and receipt['timed_out'] is False
    return value


def dependencies():
    return [Path(__file__), BINDING, EXTENSION, SCRIPT, kernel.RECORD, Path(kernel.__file__),
        Path(kernel.oracle.__file__), Path(kernel.oracle.geometry.__file__), Path(build_audit.__file__),
        Path(prior_interface.__file__), ROOT/'sdk/python/sporespore_locomotion.py',
        ROOT/'sdk/include/sporespore_locomotion.h', ROOT/'sdk/conformance/development_recovery_refusal.py',
        ROOT/'sdk/conformance/development_passive_entry_profile.py',
        ROOT/'sdk/development/r10ag_host_runtime_contract_v1.json', prior_interface.FIXTURE_BINDING]


def run():
    assert not RECORD.exists(), 'R10AI_NATIVE_COMPONENT_ALREADY_RETAINED'
    out = EVIDENCE/('r10ai-native-component-'+uuid.uuid4().hex); out.mkdir()
    print('R10AI_NATIVE_ROOT '+out.as_posix(), flush=True)
    before = source._source_snapshot()
    bindings = [closure.bind(p) for p in dependencies()]
    closure.write_new(out/'source-before.json', before)
    closure.write_new(out/'bindings-before.json', bindings)
    execution = dict(ok=False, **CLAIMS)
    try:
        binding, current, old_binding, old, engine = inputs()
        history = historical_kernel()
        closure.write_new(out/'declaration.json', dict(runtime=binding['runtime'], engine=engine,
            expected_fixture_ids=IDS, historical_kernel=history,
            covered='Original selector, source ownership, energy and clock validation, weak-load raise, 600-step raise timeout, 60-sample synthetic standing completion, actual C ABI/Python/Godot transport and old API compatibility.',
            not_covered='Physical worker schedule, complete positive hold/walking report consumer, native stepping, closed-loop dynamics, full safety graph or release acceptance.', **CLAIMS))
        observed = run_native(out, binding, current, old_binding, old)
        print('R10AI_NATIVE_CALLS_PASS '+json.dumps(observed), flush=True)
        godot = run_godot(out, binding, engine)
        # The builder retained the fresh release-mode geometry fixtures with
        # the composition fixtures. Reconstruct all 601 outputs independently.
        shutil.copyfile(verify(binding['compiled_fixtures']), out/'tests.stdout.txt')
        geometry = kernel.measurements(out)
        closure.write_new(out/'geometry.json', geometry)
        observed.update(core_tests_passed=474, composition_tests_passed=7, kernel_tests_passed=6,
            godot_fixture_calls=godot['new_fixture_calls'], godot_crossed_schema_refusals=godot['negative_calls'],
            independent_geometry_reconstructions=geometry['independent_geometry_reconstructions'],
            historical_kernel_commit=KERNEL_HEAD, **CLAIMS)
        closure.write_new(out/'result.json', observed)
        execution['ok'] = True
    except BaseException:
        execution['error'] = traceback.format_exc()
        raise
    finally:
        after = source._source_snapshot()
        closure.write_new(out/'source-after.json', after)
        ending = [closure.bind(p) for p in dependencies()]
        closure.write_new(out/'bindings-after.json', ending)
        execution['source_unchanged'] = before == after and bindings == ending
        closure.write_new(out/'execution.json', execution)
    assert execution['source_unchanged']
    record = dict(schema_version='sporespore_r10ai_concurrent_load_rise_native_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='core_godot_c_abi_python',
            authority_mode='zero_world_native_composition_component', question_class='development'),
        evidence_root=out.as_posix(), dependencies=bindings,
        retained_evidence=[closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()], observed=observed,
        historical_kernel=history, claim_boundary=CLAIMS,
        next_action='Declare a distinct candidate/worker schedule and exact runtime key. Exercise the full production report consumer on complete positive hold/walking reports and negative controls before the complete applicable safety gate and one fresh declared diagnostic. Fresh paired commissioning, official qualification, held-out acceptance and M07 adoption remain before 15/20.')
    closure.write_new(RECORD, record)
    return observed


def audit():
    record = closure.read(RECORD)
    assert record['claim_boundary'] == CLAIMS
    for item in record['dependencies'] + record['retained_evidence']:
        verify(item)
    binding, current, old_binding, old, engine = inputs()
    assert historical_kernel() == record['historical_kernel']
    out = Path(record['evidence_root'])
    assert closure.read(out/'source-before.json') == closure.read(out/'source-after.json')
    assert closure.read(out/'bindings-before.json') == closure.read(out/'bindings-after.json') == record['dependencies']
    assert closure.read(out/'execution.json')['ok'] is True and closure.read(out/'execution.json')['source_unchanged'] is True
    rows = [json.loads(line) for line in (out/'native-calls.jsonl').read_text().splitlines()]
    counts = validate_rows(rows, current, old)
    observed = closure.read(out/'result.json')
    assert observed == record['observed'] and all(observed[k] == v for k,v in counts.items())
    assert all(observed[k] == v for k,v in CLAIMS.items())
    assert closure.bind(out/'tests.stdout.txt')['raw_sha256'] == binding['compiled_fixtures']['raw_sha256']
    assert kernel.measurements(out) == closure.read(out/'geometry.json')
    godot_result(out)
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(), indent=2))
