"""Audit retained R10AJ full-consumer fixtures without launching a process.

--close creates the immutable component only after every retained case audits.
The synthetic walking branch covers two commands, never a physical task pass.
"""
import argparse
import base64
import hashlib
import subprocess
import gc
import json
from pathlib import Path

import development_passive_entry_profile as consumer
import development_recovery_candidate as candidate
import r10aj_development as identity
import r10aj_host_runtime as host
import r10aj_native_component as native
import r10aj_report_consumer as harness
import r10aj_report_fixtures as registry

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
CATALOG = ROOT / 'sdk/development/r10aj_report_fixture_catalog_v3.json'
KEY = ROOT / 'sdk/recovery/r10aj_v56_walking_entry_contract_v6.json'
RECORD = ROOT / 'sdk/recovery/r10aj_report_consumer_component_v1.json'
CLAIMS = dict(complete_production_python_consumer_exercised=True,
    synthetic_measurements_only=True, complete_safety_gate_qualified=False,
    complete_physical_route_proven=False, physical_execution_authorized=False,
    world_build_count=0, solver_step_count=0,
    physical_acceptance_authority=False, release_authority=False)
VALID = dict(partial=(575, 0), upright=(575, 0), ready=(605, 30),
             timeout=(815, 240), walking=(607, 30))
REFUSALS = dict(
    partial_source='R10AF_CONTACT_REPORT_TRACE_LINK',
    partial_owner='R10AJ_RECOVERY_REPLAY_EVENT_INVALID',
    partial_phase='R10AJ_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',
    partial_energy='R10AJ_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',
    walking_shutdown='R10AJ_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
    walking_memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    walking_capture='R10AF_CONTACT_REPORT_RECORD_POPULATION',
    walking_missing='R10AJ_ENTRY_REPLAY_POST_HOLD_RETENTION')


def require(condition, code):
    if not condition:
        raise ValueError('R10AJ_REPORT_COMPONENT_' + code)


def equal_fields(value, expected, label):
    for name, expected_value in expected.items():
        require(consumer.packet.same(value.get(name), expected_value), label + '_' + name)


def process_receipt(report_path, chosen):
    """Authenticate process metadata even when the consumer refuses its exit code."""
    directory = report_path.parent / 'passive_entry_replay'
    process = candidate.read(directory / 'execution.json')
    plan = consumer._replay_host(report_path, chosen)
    equal_fields(process, dict(
        schema_version='sporespore_development_passive_replay_process_v1',
        command=consumer._command(report_path, chosen, plan),
        engine_image=plan['engine_image'], declaration_binding=plan['declaration_binding'],
        input_raw_sha256=identity.sha(report_path), timeout_seconds=plan['timeout_seconds'],
        timed_out=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False), 'PROCESS')
    require(type(process['process_id']) is int and process['process_id'] > 0, 'PROCESS_ID')
    require(0 <= process['elapsed_seconds'] <= process['timeout_seconds'], 'PROCESS_ELAPSED')
    output = {}
    for name in ('stdout', 'stderr'):
        raw = (directory / (name + '.txt')).read_bytes()
        equal_fields(process, {name + '_binding': dict(byte_length=len(raw),
            raw_sha256=consumer.digest(raw))}, 'OUTPUT')
        output[name] = raw.decode('utf-8')
    require(output['stderr'] == '' and 'ERROR:' not in output['stdout'], 'PROCESS_ERROR_OUTPUT')
    marker = chosen['replay_marker']
    rows = [json.loads(line[len(marker):]) for line in output['stdout'].splitlines()
            if line.startswith(marker)]
    require(len(rows) == 1, 'REPLAY_MARKER')
    equal_fields(rows[0], dict(input_raw_sha256=identity.sha(report_path),
        process_id=process['process_id'], runtime_raw_sha256=chosen['candidate']['runtime_sha256'],
        world_build_count=0, solver_step_count=0, native_physics_read_count=0,
        physical_acceptance_authority=False, release_authority=False), 'READER')
    return process, rows[0]


def audit_case(name, case):
    declaration = case['declaration']
    root = EVIDENCE / ('development-recovery-smoke-' + declaration['attempt_id'])
    require(registry.registered_declaration(root / 'declaration.json'), 'REGISTERED_DECLARATION')
    require(registry.reserved_for_fixture(declaration['attempt_id']), 'FIXTURE_ID_RESERVED')
    before = candidate.read(root / 'source-before.json')
    require(before == candidate.read(root / 'source-after.json'), 'SOURCE_CHANGED')
    equal_fields(candidate.read(root / 'execution.json'),
        dict(ok=True, source_unchanged=True, **harness.CLAIMS), 'EXECUTION')
    equal_fields(candidate.read(root / 'synthetic-report-fixture.json'),
        dict(catalog=native.closure.bind(CATALOG), case=name, **harness.CLAIMS), 'FIXTURE_SELECTION')
    out = Path(declaration['children'][0]['evidence_path'])
    for child in ('frames', 'fixture'):
        execution = candidate.read(out / (child + '.execution.json'))
        equal_fields(execution, dict(returncode=0, timed_out=False, **harness.CLAIMS), 'FIXTURE_PROCESS')
        require((out / (child + '.stderr.txt')).read_bytes() == b'', 'FIXTURE_STDERR')
        require('ERROR:' not in (out / (child + '.stdout.txt')).read_text(), 'FIXTURE_STDOUT')
        command = execution['command']
        require(command[:5] == [host.expected_binding()['images']['godot_engine']['path'],
            '--headless', '--path', str(ROOT), '--script'], 'FIXTURE_HOST')
        script = ('test_r10aj_contact_report_fixture.gd' if child == 'frames' else
            'test_r10aj_complete_report_fixture.gd' if name.startswith('partial') else
            'test_r10aj_complete_phase_fixture.gd')
        require(command[5:7] == ['res://tests/' + script, '--'], 'FIXTURE_SCRIPT')
    fixture = candidate.read(out / 'fixture.json')
    equal_fields(fixture, dict(ok=True, synthetic_measurements_only=True,
        world_build_count=0, solver_step_count=0), 'FIXTURE')
    require(bool(fixture['checks']) and all(fixture['checks'].values()), 'FIXTURE_CHECKS')
    expected_report = fixture['active']['report']
    identity.validate_report_header(expected_report, declaration)
    if name in REFUSALS:
        harness.damage(expected_report, name)
    report_path = out / 'worker_report.json'
    # This proves that the retained report is exactly the original fixture plus
    # the declared corruption; no unrelated report edits can explain a refusal.
    require(consumer.digest(registry.raw(expected_report)) == identity.sha(report_path), 'EXACT_REPORT_MUTATION')
    del fixture, expected_report
    gc.collect()
    chosen = candidate.selection(identity.reference())
    process, native_result = process_receipt(report_path, chosen)
    retained = candidate.read(root / 'result.json')
    equal_fields(retained, dict(case=name, **harness.CLAIMS), 'RETAINED_RESULT')
    if name in REFUSALS:
        require(process['returncode'] == 1, 'REFUSAL_EXIT')
        equal_fields(native_result, dict(ok=False, failure_code=REFUSALS[name]), 'REFUSAL_REASON')
        try:
            consumer.consume_replay(report_path)
        except ValueError as error:
            require(str(error) == 'DEVELOPMENT_PASSIVE_PROFILE_PROCESS_FAILED', 'CONSUMER_REFUSAL')
        else:
            require(False, 'CORRUPTION_ACCEPTED')
        expected = dict(expected_refusal=True, consumer_error='DEVELOPMENT_PASSIVE_PROFILE_PROCESS_FAILED',
                        process_returncode=1, native_failure_code=REFUSALS[name])
        require(retained['result'] == expected, 'RETAINED_REFUSAL')
        observed = dict(valid_structured_refusal=True, failure_code=REFUSALS[name])
    else:
        result = consumer.consume_replay(report_path)
        require(result == retained['result'], 'CONSUMER_RESULT')
        transitions, hold = VALID[name]
        require(result['transition_count'] == transitions, 'TRANSITION_COUNT')
        require(result['stance_entry_replay']['replayed_post_recovery_hold_commands'] == hold, 'HOLD_COUNT')
        walking = result.get('walking_control_replay', {}).get('replayed_walking_steps', 0)
        require(walking == (2 if name == 'walking' else 0), 'WALKING_COUNT')
        observed = dict(valid_report_consumed=True, transition_count=transitions,
                        hold_commands=hold, walking_commands=walking)
    return root, before, observed


def earlier_attempts(revision, key_version, cases):
    """Authenticate original source snapshots and outcomes without regrading them."""
    catalog_path = ROOT / f'sdk/development/r10aj_report_fixture_catalog_v{revision}.json'
    old_key = ROOT / f'sdk/recovery/r10aj_v56_walking_entry_contract_v{key_version}.json'
    catalog = candidate.read(catalog_path)
    roots, outcomes = [], {}
    for name, expected_ok in cases:
        case = catalog['cases'][name]
        root = EVIDENCE / ('development-recovery-smoke-' + case['declaration']['attempt_id'])
        require(registry.registered_declaration(root / 'declaration.json'), 'EARLIER_DECLARATION')
        before = candidate.read(root / 'source-before.json')
        require(before == candidate.read(root / 'source-after.json'), 'EARLIER_SOURCE_CHANGED')
        equal_fields(candidate.read(root / 'execution.json'),
            dict(ok=expected_ok, source_unchanged=True, **harness.CLAIMS), 'EARLIER_EXECUTION')
        replacements = {r['path']: base64.b64decode(r['replacement_base64'], validate=True)
            for r in before['changed_files'] if not r['deleted']}
        for row in candidate.read(old_key)['bound_source_files']:
            path = Path(row['path'])
            raw = replacements.get(row['path'])
            if raw is None:
                raw = (ROOT / path).read_bytes()
                if 'sha256:' + hashlib.sha256(raw).hexdigest() != row['raw_sha256']:
                    original = subprocess.check_output(['git', 'show', before['head'] + ':' + path.as_posix()], cwd=ROOT)
                    variants = [original] if b'\r\n' in original else [original, original.replace(b'\n', b'\r\n')]
                    raw = next((v for v in variants if 'sha256:' + hashlib.sha256(v).hexdigest() == row['raw_sha256']), b'')
            require(len(raw) == row['byte_length'] and
                'sha256:' + hashlib.sha256(raw).hexdigest() == row['raw_sha256'], 'EARLIER_SOURCE_BINDING:' + row['path'])
        child = Path(case['declaration']['children'][0]['evidence_path'])
        native_process = candidate.read(child / 'fixture.execution.json')
        require(native_process['timed_out'] is False and native_process['returncode'] == (1 if revision == 1 and not expected_ok else 0), 'EARLIER_NATIVE_EXIT')
        if expected_ok:
            require(candidate.read(root / 'result.json')['result']['transition_count'] == VALID[name][0], 'EARLIER_VALID_REPORT')
            outcomes[name] = dict(original_valid_report_preserved=True)
        elif revision == 2:
            execution = candidate.read(root / 'execution.json')
            require("KeyError: 'maximum_v50_walking_commands'" in execution['error'], 'EARLIER_PYTHON_REFUSAL')
            native_replay = candidate.read(child / 'passive_entry_replay/execution.json')
            require(native_replay['returncode'] == 0 and native_replay['timed_out'] is False, 'EARLIER_NATIVE_REPLAY')
            outcomes[name] = dict(original_failure_preserved=True, native_replay_passed=True,
                consumer_failure="KeyError: maximum_v50_walking_commands")
        else:
            fixture = candidate.read(child / 'fixture.json')
            failure = fixture['failure']['retained_failure']
            require(fixture['ok'] is False and not any(v is False for v in fixture['checks'].values()), 'EARLIER_FIXTURE')
            require(failure['failure_code'] == 'QSDK_R10F_WALKING_EVALUATION_INVALID' and
                failure['evaluator_failure_code'] == 'QSDK_R10F_WALKING_EVALUATION_SHAPE_INVALID', 'EARLIER_REFUSAL')
            outcomes[name] = dict(original_failure_preserved=True, failure_code=failure['failure_code'],
                evaluator_failure_code=failure['evaluator_failure_code'])
        roots.append(root)
    return dict(catalog=native.closure.bind(catalog_path), source_key=native.closure.bind(old_key),
        outcomes=outcomes, original_result_regraded=False,
        evidence=[native.closure.bind(p) for root in roots for p in sorted(root.rglob('*')) if p.is_file()])


def inspect():
    catalog = dict((p.resolve(), c) for p, c in registry.catalogs())[CATALOG.resolve()]
    require(candidate.R10AJ_ROUTE_ENTRY_PATH == KEY, 'SOURCE_KEY_SELECTION')
    key = candidate.read(KEY)
    dependencies = key['bound_source_files'] + [native.closure.bind(KEY), native.closure.bind(Path(__file__))]
    for row in dependencies:
        native.builds.verify(row)
    host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],
                      host.expected_binding()['images']['powershell_host']['path'])
    roots, observed, snapshot = [], {}, None
    for name, case in catalog['cases'].items():
        root, before, result = audit_case(name, case)
        if snapshot is None:
            snapshot = before
        require(before == snapshot, 'CASE_SOURCE_CROSSED')
        roots.append(root); observed[name] = result
        print('R10AJ_REPORT_AUDIT_PASS ' + name, flush=True)
        gc.collect()
    evidence = [native.closure.bind(p) for root in roots for p in sorted(root.rglob('*')) if p.is_file()]
    return dict(dependencies=dependencies, evidence=evidence, observed=observed,
                retained_earlier_attempts=[earlier_attempts(1, 2, [('partial', True), ('upright', True), ('ready', False)]),
                    earlier_attempts(2, 4, [('ready', True), ('timeout', True), ('walking', False)])],
                source_parent_commit=snapshot['head'])


def main(close=False):
    if close:
        require(not RECORD.exists(), 'RECORD_ALREADY_EXISTS')
    else:
        record = candidate.read(RECORD)
        require(record['claim_boundary'] == CLAIMS, 'CLAIM_BOUNDARY')
        for row in record['dependencies'] + record['evidence']:
            native.builds.verify(row)
    inspected = inspect()
    if close:
        record = dict(schema_version='sporespore_r10aj_report_consumer_component_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                authority_mode='zero_world_complete_report_consumer_component', question_class='development'),
            catalog=native.closure.bind(CATALOG), source_admission_key=native.closure.bind(KEY),
            **inspected, claim_boundary=CLAIMS,
            coverage_limits=[
                'Synthetic measurements and uninserted hinges only; no solver/world execution.',
                'Walking branch has two commands and is not a four-cycle task or recovery success.',
                'Energy corruption checks initializer history binding, not an energy residual threshold.',
                'Fixture IDs and fixture declarations must be refused by future physical authority.',
                'Earlier component records remain historical; this does not renew their source keys.'],
            next_action='Integrate single-use launch ownership, fixture-ID refusal, bounded result publication and the complete affected safety graph before the one declared development diagnostic.')
        # R10AJ evidence declarations are pinned to LF in .gitattributes.
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(json.dumps(record, indent=2, allow_nan=False) + '\n')
    else:
        for name, value in inspected.items():
            require(record[name] == value, 'RECORD_' + name)
    return dict(valid_reports=len(VALID), structured_refusals=len(REFUSALS),
                retained_files=len(inspected['evidence']), **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--close', action='store_true')
    print(json.dumps(main(parser.parse_args().close), indent=2))
