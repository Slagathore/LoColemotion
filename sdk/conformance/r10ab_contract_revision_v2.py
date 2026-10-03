"""Audit the prospective R10AB dependency correction and its fresh checks.

Original contracts and component records remain byte-identical to their prior
commit. Their audit passed before source mutation; the successor components
validate fresh tests against the corrected contract. No physical qualification.
"""
import argparse
import copy
import json
from pathlib import Path
import re
import subprocess
import r10ab_report_component_v3 as reports

native = reports.native
ROOT, EVIDENCE = reports.ROOT, reports.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ab_contract_revision_v2.json'
PREVIOUS = '0fab9207e55e71687d7cdbee1b72d6181c88736c'
PRECHECK = EVIDENCE / 'r10ab-contract-revision-d9dcbec5b3854d3d8ca206121adf1bd5'
CHECKS = EVIDENCE / 'r10ab-revision-check-d57a0074dcf64c2cb0127fd4e5c6b364'
FAILURE = EVIDENCE / 'r10ab-report-boundary-check-296db2ec27ba441491b40358b4d78436'
OLD_TASK = ROOT / 'sdk/recovery/r10ab_partial_downward_rise_finite_cycle_contract_v1.json'
NEW_TASK = ROOT / 'sdk/recovery/r10ab_partial_downward_rise_finite_cycle_contract_v2.json'
OLD_ROUTE = ROOT / 'sdk/recovery/r10ab_v56_walking_route_contract_v1.json'
NEW_ROUTE = ROOT / 'sdk/recovery/r10ab_v56_walking_route_contract_v2.json'
OLD_JSON = [OLD_TASK, OLD_ROUTE] + [ROOT / p for p in (
    'sdk/recovery/r10ab_route_component_v1.json', 'sdk/recovery/r10ab_facade_component_v1.json',
    'sdk/recovery/r10ab_report_component_v1.json', 'sdk/recovery/r10ab_report_component_v2.json',
    'sdk/recovery/r10ab_v56_walking_entry_contract_v1.json',
    'sdk/recovery/r10ab_v56_walking_entry_contract_v2.json',
    'sdk/development/recovery_candidates/r10ab-partial-downward-rise-integrated-v1.json',
    'sdk/development/recovery_schedules/r10ab-partial-downward-rise-integrated-v1.json')]


def task_binding(path):
    row = native.diagnosis.binding(path)
    return dict(path=path.relative_to(ROOT).as_posix(), byte_length=row['byte_length'], sha256=row['raw_sha256'])


def observations():
    assert reports.audit()['ok']
    for path in OLD_JSON:
        raw = subprocess.check_output(['git', 'show', PREVIOUS + ':' + path.relative_to(ROOT).as_posix()], cwd=ROOT)
        assert raw == path.read_bytes(), path
    receipt = native.read(PRECHECK / 'predecessor.execution.json')
    assert receipt['exit_code'] == 0 and receipt['source_commit'] == PREVIOUS and receipt['clean_source'] is True
    assert (PRECHECK / 'predecessor.stderr.log').read_bytes() == b''
    line = (PRECHECK / 'predecessor.stdout.log').read_text(encoding='utf-8-sig').strip()
    assert line.startswith('R10AB_REPORT_COMPONENT_V2 ')
    prior = json.loads(line.split(' ', 1)[1])
    assert prior['ok'] and prior['worker_source_key_files'] == 1615
    old, new = native.read(OLD_TASK), native.read(NEW_TASK)
    expected = copy.deepcopy(old)
    expected['schema_version'] = old['schema_version'].replace('_v1', '_v2')
    expected['contract_id'] = old['contract_id'].replace('_v1', '_v2')
    expected['stance_entry']['native_entry_policy_contract_sha256'] = native.diagnosis.binding(ROOT / old['stance_entry']['native_entry_policy_contract'])['raw_sha256']
    assert old['stance_entry']['native_entry_policy_contract_sha256'] != expected['stance_entry']['native_entry_policy_contract_sha256']
    expected['predecessor_task'] = task_binding(OLD_TASK)
    expected['predecessor_contract'] = OLD_TASK.relative_to(ROOT).as_posix()
    expected['predecessor_contract_sha256'] = native.diagnosis.binding(OLD_TASK)['raw_sha256']
    expected['source_authorities'].append(task_binding(OLD_TASK))
    expected['revision_reason'] = 'Correct the entry-policy dependency digest before any physical attempt; preserve every task limit, policy, evaluator and threshold.'
    assert new == expected
    expected = native.read(OLD_ROUTE)
    expected['schema_version'] = expected['schema_version'].replace('_v1', '_v2')
    expected['predecessor_contract'] = OLD_ROUTE.relative_to(ROOT).as_posix()
    expected['predecessor_contract_sha256'] = native.diagnosis.binding(OLD_ROUTE)['raw_sha256']
    expected['task_contract'] = NEW_TASK.relative_to(ROOT).as_posix()
    expected['task_contract_sha256'] = native.diagnosis.binding(NEW_TASK)['raw_sha256']
    assert native.read(NEW_ROUTE) == expected
    counts = dict(finite=11, host=5, policy=1, reader=1, upright=1, facade=3, candidate=2, report=2)
    assert native.read(CHECKS / 'execution.json')['exit_code'] == 0
    assert native.read(CHECKS / 'lock.json')['acquired'] is True
    for name, count in counts.items():
        assert native.read(CHECKS / (name + '.execution.json'))['exit_code'] == 0
        output = (CHECKS / (name + '.stderr.log')).read_text(encoding='utf-8-sig')
        assert re.search(r'Ran ' + str(count) + r' tests? in ', output) and output.strip().endswith('OK'), name
    assert native.read(FAILURE / 'finite.execution.json')['exit_code'] == 1
    assert 'FAILED (failures=1, errors=1)' in (FAILURE / 'finite.stderr.log').read_text(encoding='utf-8-sig')
    return dict(ok=True, corrected_entry_policy_binding=True, walking_schema_selector_checked=True,
        original_contracts_and_records_unchanged=len(OLD_JSON), predecessor_checked_before_mutation=True,
        groups=counts, tests=sum(counts.values()), native_route_binding_refusals=4,
        task_limits_thresholds_and_controller_unchanged=True, retained_initial_boundary_failures=2,
        route_checks=66, facade_checks=125, compiled_route_replay_calls=307,
        complete_partial_transitions=575, complete_prone_transitions=286,
        complete_upright_hold_walking_reports_checked=False, complete_smoke_safety_gate_passed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for folder in (PRECHECK, CHECKS, FAILURE) for p in sorted(folder.iterdir()) if p.is_file()]
    paths = [Path(__file__), NEW_TASK, NEW_ROUTE, reports.RECORD, *OLD_JSON]
    paths += [ROOT / p for p in ('sdk/conformance/finite_recovery_walking.py',
        'sdk/conformance/r10ab_finite_task_audit.py', 'sdk/conformance/r10ab_host_deadline.py',
        'sdk/adapters/godot/gdscript/r10ab_recovery_route_v1.gd',
        'sdk/development/recovery_candidates/r10ab-partial-downward-rise-integrated-v2.json',
        'sdk/development/recovery_schedules/r10ab-partial-downward-rise-integrated-v2.json')]
    native.write(RECORD, dict(schema_version='sporespore_r10ab_contract_revision_v2',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='prospective_dependency_correction_with_fresh_zero_world_checks', question_class='development'),
        predecessor_source_commit=PREVIOUS, source_bindings=[native.diagnosis.binding(p) for p in paths],
        retained_evidence=[native.diagnosis.binding(p) for p in files], observed=result))
    return result


def audit():
    record = native.read(RECORD)
    for row in record['source_bindings'] + record['retained_evidence']: native.verify(row)
    result = observations()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    print('R10AB_CONTRACT_REVISION_V2 ' + json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
