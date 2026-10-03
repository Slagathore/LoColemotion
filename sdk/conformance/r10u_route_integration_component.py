"""Retain R10U interface checks and exposed-data diagnostics without physics credit."""
import argparse
import json
from pathlib import Path
import re
import uuid

import development_passive_entry_profile as entry
import r10t_route_integration_component as base
import r10u_retained_final_audit as diagnostic

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10u_route_integration_component_v1.json'
HOST = EVIDENCE/'r10u-integration-check-d8cdbd5e397e4061a2dfb19a723db77a'
FAILED = EVIDENCE/'r10u-native-route-check-237158882b9e4c90a5727294c4a4f33f'
PASSED = EVIDENCE/'r10u-native-route-check-9a5c05818b6441b4a3964471ae2c8c7d'
FIXTURE = EVIDENCE/'r10u-fixture-check-96128aa85d6243878e7d76ab828e93d9'
DIAGNOSTIC_WRAPPER = EVIDENCE/'r10u-final-audit-check-d869c6dac27c4375a469ac9acf1259c7'
RETENTIONS = [EVIDENCE/name/'retention.json' for name in [
    'r10u-route-v2-retention-abf56119cbcb426b855ab11de4f4d2e1',
    'r10u-route-v3-retention-7c955fef020b42b48f0a22b81fa5350c',
    'r10u-final-audit-v4-retention-6f5fb7f4ce73415b8c077fe034bbdfc8']]
CLAIMS = dict(production_entrypoints_implemented=True, complete_source_key_declared=True,
    complete_safety_gate_passed=False, full_r10u_physical_workflow_proven=False,
    exposed_full_audit_with_synthetic_declaration_passed=True,
    original_r10t_attempt_reclassified=False, r10t_chain_closed=True,
    world_build_count=0, solver_step_count=0, controller_changed=False,
    native_dll_changed=False, physical_budget_changed=False, baseline_reused=False,
    held_out_population_declared=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


def snapshots_and_lock(root):
    assert base.read(root/'source_before.json') == base.read(root/'source_after.json')
    lock = base.read(root/'operation_lock.json')
    assert lock['acquired'] and not lock['test_only'] and not lock['abandoned_owner_recovered']
    assert lock['role'] == 'conformance'
    assert lock['mutex_name'] == 'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'


def stages(root, counts, passed):
    snapshots_and_lock(root)
    value = base.read(root/'execution.json')
    assert value['source_unchanged'] and value['world_build_count'] == value['solver_step_count'] == 0
    rows = value['stage_results']
    assert [v['test_count'] for v in rows] == counts
    for row in rows:
        assert row['passed'] is passed and not row['timed_out']
        assert row['expected_test_count'] == row['test_count']
        assert row['exit_code'] == (0 if passed else 1)
        for stream in ['stdout','stderr']:
            assert base.bind(root/row[stream])['raw_sha256'] == 'sha256:'+row[stream+'_sha256']
        log = (root/row['stderr']).read_text(encoding='utf-8')
        assert re.findall(r'^Ran (\d+) tests? in ',log,flags=re.M) == [str(row['test_count'])]
        if passed: assert log.rstrip().endswith('OK')
    return rows


def observed():
    snapshots_and_lock(HOST)
    host = base.read(HOST/'execution.json')
    assert host['ok'] and host['source_unchanged'] and len(host['results']) == 5
    assert all(v['passed'] and v['exit_code'] == 0 and not v['timed_out'] for v in host['results'])
    stages(FAILED,[3,1,1,1],False)
    stages(PASSED,[3,1,1,1],True)
    stages(FIXTURE,[13,2,1],True)
    result = base.read(diagnostic.RESULT)
    assert result['ok'] and result['scope'] == diagnostic.SCOPE
    for item in result['bindings']: base.verify(item)
    assert base.read(diagnostic.DIRECTORY/'source_before.json') == base.read(diagnostic.DIRECTORY/'source_after.json')
    audit = result['observed']['original_report_audit']
    assert audit['ok'] and audit['r10t_finite_development']['all_tasks_positive']
    assert len(audit['children']) == 1 and result['observed']['projected_declaration_validation_calls'] == 2
    assert base.read(DIAGNOSTIC_WRAPPER/'execution.json')['exit_code'] == 0
    lock = base.read(DIAGNOSTIC_WRAPPER/'operation_lock.json')
    assert lock['acquired'] and not lock['test_only'] and not lock['abandoned_owner_recovered']
    return dict(host_tests_passed=19,native_integration_tests_passed=6,fixture_tests_passed=16,
        earlier_native_tests=6,earlier_native_tests_passed=2,earlier_native_tests_failed=4,
        worker_and_reader_syntax_checks_passed=2,complete_exposed_audits_passed=2,
        production_declaration_calls_in_latest_diagnostic=2,source_unchanged_during_checks=True)


def audit(record, current_sources=False):
    assert record['claim_boundary'] == CLAIMS
    for item in [record['auditor'],record['manifest'],record['safety_contract'],record['source_key']]: base.verify(item)
    for item in base.read(record['manifest']['path'])['files']: base.verify(item)
    for item in record['retentions']:
        base.verify(item); retention=base.read(item['path'])
        base.verify(retention['manifest'])
        for binding in base.read(retention['manifest']['path'])['files']: base.verify(binding)
        archive = retention['source_archive']
        base.verify(archive['key']); base.verify(archive['snapshot'])
        for source in base.read(archive['key']['path'])['bound_source_files']:
            assert base.bind(Path(archive['directory'])/source['path'])['raw_sha256'] == source['raw_sha256']
    if current_sources:
        assert diagnostic.exact_key() == record['source_key']
    assert record['observed'] == observed()
    contract = base.read(record['safety_contract']['path'])
    assert len(contract['stages']) == 64 and sum(s['tests'] for s in contract['stages']) == contract['total_tests'] == 228
    return dict(ok=True,current_sources_verified=current_sources,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10u_*consumption_v1.json'))
    result = observed()
    folder = EVIDENCE/('r10u-route-integration-closure-'+uuid.uuid4().hex);folder.mkdir()
    archive = base.archive_key(folder,Path(base.read(diagnostic.RESULT)['source_key']['path']),diagnostic.DIRECTORY/'source_before.json')
    roots = {diagnostic.DIRECTORY,DIAGNOSTIC_WRAPPER,FIXTURE}
    for log in FIXTURE.glob('*.stdout.log'):
        for name in re.findall(r'^[A-Z0-9_]+ (C:[^\r\n]+)$',log.read_text(encoding='utf-8'),flags=re.M):
            path=Path(name.strip());assert path.parent == EVIDENCE and path.is_dir();roots.add(path)
    # Only completed inputs are captured; never include this auditor's own output.
    manifest=folder/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for root in sorted(roots) for p in sorted(root.rglob('*')) if p.is_file()]))
    retention=folder/'retention.json'
    base.write_new(retention,dict(source_archive=archive,manifest=base.bind(manifest)))
    record=dict(schema_version='sporespore_r10u_route_integration_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='retained_zero_world_integration',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),source_key=diagnostic.exact_key(),
        safety_contract=base.bind(ROOT/'sdk/development/r10u_safety_stage_contract_v2.json'),
        retentions=[base.bind(p) for p in [*RETENTIONS,retention]],observed=result,claim_boundary=CLAIMS,
        correction_record='Retained four native test failures on key v2: one missing R10U motor-ledger fixture alias and three stale finite-task hash errors. Key v3 passed all six tests. Full exposed-data audit passed on v4 and v5 without patching the timeout global. Three copied fixture paths were corrected before their execution; all sixteen affected tests passed on v5.',
        scope='Synthetic production worker/report/replay interfaces and explicitly exposed data only. Ready and timeout hold reports remain complete-task negatives. R10T remains infrastructure-invalid; no R10U physical baseline or attempt exists.',
        remaining_work=['complete 64-stage / 228-test safety gate from clean pushed freeze','fresh phase245 development pair','three conditional branch diagnostics','fresh held-out finite decision and QSDK-R10/M07 adoption'])
    audit(record,True)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as stream: json.dump(record,stream,indent=2);stream.write('\n')
    return audit(record,True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(base.read(RECORD),args.current_sources)))
