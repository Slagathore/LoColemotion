"""R10AI candidate, route and reader admission; no physics or report-consumer claim.

Run --run under the native operation lock. Every run retains its exact source,
including failed runs. Complete report consumption and launch safety are separate.
"""
import argparse
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import traceback
import uuid

import development_passive_entry_profile as consumer
import development_recovery_candidate as candidate
import r10ai_development as identity
import r10ai_host_runtime as host
import r10ai_native_component as native

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ai_route_integration_component_v1.json'
TASK = ROOT / 'sdk/recovery/r10ai_concurrent_load_rise_finite_cycle_contract_v1.json'
CLAIMS = dict(candidate_admission_exercised=True, reader_compilation_exercised=True,
    complete_report_consumer_exercised=False, complete_safety_gate_qualified=False,
    physical_execution_authorized=False, world_build_count=0, solver_step_count=0,
    physical_acceptance_authority=False, release_authority=False)


def historical_components():
    results = []
    for filename, commit, evidence_keys in [
        ('r10ai_concurrent_load_rise_native_component_v1.json',
         'e55b65ca674859e684df6910b2ee0b6543a66353', ['retained_evidence']),
        ('r10ai_worker_source_component_v1.json',
         '0116f708cf787c978ae6ae1484cf055887f0888a', ['evidence', 'retained_failed_attempts'])]:
        path = ROOT / 'sdk/recovery' / filename
        record = native.closure.read(path)
        out = Path(record['evidence_root'])
        for key in evidence_keys:
            for row in record[key]: native.verify(row)
        snapshot = native.closure.read(out / 'source-before.json')
        replacements = {row['path']: row for row in snapshot['changed_files']}
        for row in record['dependencies']:
            dependency = Path(row['path'])
            if not dependency.is_absolute(): dependency = ROOT / dependency
            if dependency.is_relative_to(ROOT):
                raw = subprocess.check_output(['git', 'show', commit + ':' + dependency.relative_to(ROOT).as_posix()], cwd=ROOT)
                variants = [raw, raw.replace(b'\n', b'\r\n')] if b'\r\n' not in raw else [raw]
                current = dependency.read_bytes()
                if current.replace(b'\r\n', b'\n') == raw.replace(b'\r\n', b'\n'):
                    variants.append(current)
                replacement = replacements.get(dependency.relative_to(ROOT).as_posix())
                if replacement and replacement.get('replacement_base64'):
                    original = base64.b64decode(replacement['replacement_base64'], validate=True)
                    assert 'sha256:' + hashlib.sha256(original).hexdigest() == replacement['raw_sha256']
                    # Preserve the exact tested mixed-EOL bytes, but also prove
                    # that they correspond to the committed source text.
                    assert original.replace(b'\r\n', b'\n') == raw.replace(b'\r\n', b'\n')
                    variants.append(original)
                assert any(len(v) == row['byte_length'] and 'sha256:' + hashlib.sha256(v).hexdigest() == row['raw_sha256'] for v in variants), row['path']
            else:
                native.verify(row)
        assert native.closure.read(out / 'source-before.json') == native.closure.read(out / 'source-after.json')
        assert native.closure.read(out / 'execution.json')['ok'] is True
        results.append(dict(component=native.closure.bind(path), commit=commit,
            original_source_authenticated=True, renewed_qualification=False))
    return results


def contract_checks():
    old = candidate.read(ROOT / 'sdk/recovery/r10ag_detection_frame_load_seeking_finite_cycle_contract_v1.json')
    task, design = candidate.read(TASK), candidate.read(identity.DESIGN)
    checks = {}
    for key in ['finite_walking_observable', 'settled_tail', 'whole_walking_envelope',
                'partial_recovery', 'prone_recovery', 'upright_recovery',
                'native_interaction', 'post_recovery_hold', 'unintended_support_loss_contract']:
        checks['preserved_' + key] = task[key] == old[key]
    limits = dict(old['limits'])
    for key in ['child_wall_time_limit_seconds', 'independent_reader_wall_time_limit_seconds']:
        limits[key] = design['limits'][key]
    checks['limits_follow_design'] = task['limits'] == limits
    checks['exact_population'] = task['prospective_populations']['development']['first_probe'] == design['first_probe']
    changes = design['controlled_change']
    for key, declared in [('partial_support_raise_controller', 'to_controller'),
                          ('partial_control_composition_id', 'composition'),
                          ('partial_entry_export', 'entry_export'), ('partial_step_export', 'step_export')]:
        checks[key] = task['controller_composition'][key] == changes[declared]
    chosen = candidate.selection(identity.reference())
    checks['python_worker'] = chosen['worker_selection']['worker'].endswith('/r10ai_development_worker_v1.gd')
    checks['python_reader'] = chosen['reader'].endswith('/r10ai_recovery_replay.gd')
    checks['declaration_required'] = chosen['diagnostic_reader_requires_declaration'] is True
    checks['exact_dll'] = chosen['candidate']['runtime_sha256'] == changes['selected_runtime']['raw_sha256']
    for key in ['walking_policy_id', 'walking_entry_profile_id', 'walking_start_profile_id',
                'runtime_sha256', 'walking_policy_contract_sha256']:
        crossed = copy.deepcopy(chosen['diagnostic_schedule']); crossed[key] = 'crossed'
        try: candidate.walking_policy_id(crossed)
        except (ValueError, KeyError): checks['reject_' + key] = True
        else: checks['reject_' + key] = False
    checks['launch_closed'] = task['physical_execution_authorized'] is False and task['sdk1_m07_satisfied'] is False
    assert all(checks.values()), [k for k, v in checks.items() if not v]
    return checks


def run_child(out, name, script, args):
    command = [host.expected_binding()['images']['godot_engine']['path'], '--headless',
        '--path', str(ROOT), '--script', 'res://tests/' + script, '--', *map(str, args)]
    environment = {k: v for k, v in os.environ.items() if not k.startswith(('SPORE_R10', 'SPORESPORE_GODOT_RECOVERY_'))}
    with (out / (name + '.stdout.txt')).open('xb') as stdout, (out / (name + '.stderr.txt')).open('xb') as stderr:
        with subprocess.Popen(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                              creationflags=subprocess.CREATE_NO_WINDOW) as process:
            try: code = process.wait(timeout=180); timed_out = False
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(); code = process.returncode; timed_out = True
            native.closure.write_new(out / (name + '.execution.json'), dict(command=command,
                process_id=process.pid, returncode=code, timed_out=timed_out, timeout_seconds=180))
    assert code == 0 and not timed_out, (name, code, (out / (name + '.stderr.txt')).read_text()[-5000:])
    return validate_child(out, name)


def validate_child(out, name):
    execution = native.closure.read(out / (name + '.execution.json'))
    assert execution['returncode'] == 0 and execution['timed_out'] is False
    assert 'ERROR:' not in (out / (name + '.stderr.txt')).read_text()
    result = native.closure.read(out / (name + '.json'))
    assert result['ok'] is True and result['checks'] and all(result['checks'].values()), result
    assert result['world_build_count'] == result['solver_step_count'] == 0
    assert result['physical_acceptance_authority'] is result['release_authority'] is False
    return len(result['checks'])


def run():
    assert not RECORD.exists()
    out = EVIDENCE / ('r10ai-route-integration-' + uuid.uuid4().hex); out.mkdir()
    print('R10AI_ROUTE_ROOT ' + out.as_posix(), flush=True)
    before = consumer._source_snapshot()
    native.closure.write_new(out / 'source-before.json', before)
    key = candidate.read(candidate.R10AI_ROUTE_ENTRY_PATH)
    bindings = key['bound_source_files'] + [native.closure.bind(candidate.R10AI_ROUTE_ENTRY_PATH)]
    native.closure.write_new(out / 'bindings-before.json', bindings)
    execution = dict(ok=False, **CLAIMS)
    try:
        checks = contract_checks()
        history = historical_components()
        sys.path.insert(0, str(ROOT / 'tests'))
        import r10ai_preflight_fixture
        declaration = r10ai_preflight_fixture.fixture(before['head'])
        native.closure.write_new(out / 'synthetic-declaration.json', declaration)
        native.closure.write_new(out / 'contract-checks.json', checks)
        native.closure.write_new(out / 'historical-components.json', history)
        host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],
                          host.expected_binding()['images']['powershell_host']['path'])
        original = candidate.read(ROOT / 'sdk/recovery/r10v_v56_walking_route_contract_v2.json')
        fixture = native.verify(next(row for row in original['policy_binding_evidence'] if row['path'].endswith('/profile.request.json')))
        observed = dict(contract_checks=len(checks))
        observed['native_route_checks'] = run_child(out, 'route', 'test_development_r10ai_route_bindings.gd', [fixture, out / 'route.json'])
        print('R10AI_ROUTE_PASS ' + str(observed['native_route_checks']), flush=True)
        observed['candidate_checks'] = run_child(out, 'admission', 'test_r10ai_candidate_admission.gd', [out / 'synthetic-declaration.json', out / 'admission.json'])
        native.closure.write_new(out / 'result.json', observed)
        execution['ok'] = True
    except BaseException:
        execution['error'] = traceback.format_exc(); raise
    finally:
        after = consumer._source_snapshot()
        native.closure.write_new(out / 'source-after.json', after)
        execution['source_unchanged'] = before == after
        native.closure.write_new(out / 'execution.json', execution)
    assert execution['source_unchanged']
    for row in bindings: native.verify(row)
    native.closure.write_new(RECORD, dict(schema_version='sporespore_r10ai_route_integration_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_candidate_and_route_component', question_class='development'),
        evidence_root=out.as_posix(), dependencies=bindings,
        evidence=[native.closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],
        retained_failed_attempts=[native.closure.bind(p)
            for directory in sorted(EVIDENCE.glob('r10ai-route-integration-*'))
            if directory != out and (directory / 'execution.json').is_file()
            and candidate.read(directory / 'execution.json')['ok'] is False
            for p in sorted(directory.iterdir()) if p.is_file()],
        observed=observed, historical_components=history, claim_boundary=CLAIMS,
        next_action='Exercise the full Python report consumer on fresh synthetic partial/upright, ready/timeout hold and walking reports; then complete launch ownership and the affected safety graph.'))
    return observed


def audit():
    record = candidate.read(RECORD)
    assert record['claim_boundary'] == CLAIMS
    for row in record['dependencies'] + record['evidence'] + record['retained_failed_attempts']: native.verify(row)
    out = Path(record['evidence_root'])
    assert candidate.read(out / 'execution.json')['source_unchanged'] is True
    assert candidate.read(out / 'execution.json')['ok'] is True
    observed = dict(contract_checks=len(contract_checks()), native_route_checks=validate_child(out, 'route'),
                    candidate_checks=validate_child(out, 'admission'))
    assert observed == record['observed'] == candidate.read(out / 'result.json')
    assert historical_components() == record['historical_components']
    return dict(observed=observed, **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--run', action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(), indent=2))
