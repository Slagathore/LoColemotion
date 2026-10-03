"""Retain the R10U host/population component checks, with explicit route gaps."""
import argparse
import base64
import json
from pathlib import Path
import re
import uuid

import development_passive_entry_profile as entry
import r10t_route_integration_component as base
import r10u_predecessor_history as history

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10u_host_population_component_v1.json'
FAILED = EVIDENCE/'r10u-population-tests-7ed5afd6d9b5404d890267893cff9ba5'
FAILED_NATIVE = EVIDENCE/'r10u-population-component-1df58b6a5dc34f14889edfae8d323d37'
PASSED = EVIDENCE/'r10u-host-population-tests-351500d5805e4aeebd9b46c7a5df8786'
POPULATION = EVIDENCE/'r10u-population-component-a1436843441e48cfbcd8d61848f5fc43'
HOST = EVIDENCE/'r10u-host-deadline-component-d1aee887d9cc442d87153287d3b45c7a'
TESTED = [
    'sdk/conformance/development_passive_entry_profile.py',
    'sdk/run_development_recovery_smoke.ps1',
    'sdk/conformance/r10u_development.py',
    'sdk/conformance/r10u_host_deadline.py',
    'sdk/adapters/godot/gdscript/r10u_development_seed_v1.gd',
    'tests/test_r10u_development_context.py',
    'tests/test_r10u_development_seed.gd',
    'tests/test_r10u_host_deadline.py',
    'tests/test_r10u_host_deadline.ps1',
]
CLAIMS = dict(component_tests_passed=13, native_population_checks_passed=45,
    launcher_fields_and_shared_auditor_component_passed=True,
    candidate_selection_injected_in_host_component=True,
    production_candidate_route_integrated=False, complete_dependency_key_declared=False,
    complete_safety_gate_passed=False, full_successor_retained_report_audit_passed=False,
    physical_attempt_started=False, held_out_population_declared=False,
    controller_changed=False, native_dll_changed=False, physical_budget_changed=False,
    physical_acceptance_authority=False, release_authority=False,
    sdk1_score='14/20', full_program_score='14/25')


def inspect_tests(root, count, failures):
    execution = base.read(root/'execution.json')
    assert execution['exit_code'] == (1 if failures else 0)
    assert execution['world_build_count'] == execution['solver_step_count'] == 0
    lock = base.read(root/'operation_lock.json')
    assert lock['acquired'] and not lock['test_only'] and lock['role'] == 'conformance'
    assert lock['mutex_name'] == 'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'
    assert not lock['abandoned_owner_recovered']
    log = (root/'tests.stderr.txt').read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ',log,flags=re.M) == [str(count)]
    assert len(re.findall(r'^FAIL:',log,flags=re.M)) == failures
    assert not re.findall(r'^ERROR:',log,flags=re.M)
    assert log.rstrip().endswith('FAILED (failures=1)' if failures else 'OK')


def observed():
    inspect_tests(FAILED,7,1); inspect_tests(PASSED,13,0)
    for root in [FAILED_NATIVE,POPULATION,HOST]:
        assert base.read(root/'source_before.json') == base.read(root/'source_after.json')
    assert base.read(POPULATION/'source_before.json') == base.read(HOST/'source_before.json')
    first = base.read(FAILED_NATIVE/'native-result.json')
    assert first['ok'] is False
    assert sorted(k for k,v in first['checks'].items() if not v) == [
        'pair_role_kick_passive_recovery_resume','pair_role_matched_no_kick_continuation']
    native = base.read(POPULATION/'native-result.json')
    assert native['ok'] is True and len(native['checks']) == 45 and all(v is True for v in native['checks'].values())
    assert native['world_build_count'] == native['solver_step_count'] == native['sdk_instantiation_count'] == 0
    assert base.read(POPULATION/'native-execution.json')['exit_code'] == 0
    assert base.read(HOST/'launcher-execution.json')['exit_code'] == 0
    declaration = base.read(HOST/'launcher-declaration.json')
    assert declaration['timeout_seconds_per_child'] == 1740
    assert declaration['r10u_development']['stage'] == 'paired_commissioning'
    assert [c['role'] for c in declaration['children']] == ['matched_no_kick_continuation','kick_passive_recovery_resume']
    return dict(prior_tests=7,prior_failures=1,prior_failure_kind='synthetic_seed_float_spelling',
        component_tests=13,component_failures=0,native_population_checks=45,
        actual_launcher_child_wall_seconds=1740,source_unchanged_during_each_check=True,
        candidate_selection_injected=True,world_build_count=0,solver_step_count=0)


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for binding in [record['auditor'],record['manifest'],record['design'],record['history_result'],
                    record['history_source_before'],record['history_source_after']]:
        base.verify(binding)
    for binding in base.read(record['manifest']['path'])['files']: base.verify(binding)
    assert observed() == record['observed']
    historical = base.read(record['history_result']['path'])
    assert historical['ok'] and historical['archived_sources'] == 819
    assert historical['original_audit']['original_attempt_classification'] == 'consumed_infrastructure_invalid'
    assert not historical['original_audit']['original_attempt_reclassified']
    before = base.read(record['history_source_before']['path'])
    assert before == base.read(record['history_source_after']['path'])
    test_snapshot = base.read(POPULATION/'source_before.json')
    tested_bytes = {x['path']:base64.b64decode(x['replacement_base64']) for x in test_snapshot['changed_files'] if not x['deleted']}
    history_bytes = {x['path']:base64.b64decode(x['replacement_base64']) for x in before['changed_files'] if not x['deleted']}
    current = True
    for source in record['archived_sources']:
        base.verify(source['retained'])
        name = source['relative_path']; raw = Path(source['retained']['path']).read_bytes()
        assert raw == (tested_bytes[name] if name in TESTED else history_bytes[name])
        current = current and (ROOT/name).read_bytes() == raw
    assert {x['relative_path'] for x in record['archived_sources']} == set(TESTED+['sdk/conformance/r10u_predecessor_history.py'])
    return dict(ok=True,**record['observed'],**CLAIMS,current_component_sources_match=current)


def create():
    assert not RECORD.exists()
    result = observed()
    directory = EVIDENCE/('r10u-host-population-closure-'+uuid.uuid4().hex);directory.mkdir()
    before = entry._source_snapshot(); base.write_new(directory/'history-source-before.json',before)
    historical = history.audit(); base.write_new(directory/'history-result.json',historical)
    after = entry._source_snapshot(); base.write_new(directory/'history-source-after.json',after)
    assert before == after
    tested = base.read(POPULATION/'source_before.json')
    replacements = {x['path']:base64.b64decode(x['replacement_base64']) for x in tested['changed_files'] if not x['deleted']}
    sources = []
    for name in TESTED+['sdk/conformance/r10u_predecessor_history.py']:
        raw = (ROOT/name).read_bytes()
        if name in TESTED: assert raw == replacements[name]
        path = directory/'sources'/name;path.parent.mkdir(parents=True,exist_ok=True)
        with path.open('xb') as stream:stream.write(raw)
        sources.append(dict(relative_path=name,retained=base.bind(path)))
    # Capture only quiescent inputs. Our own stdout is never in the manifest.
    manifest = directory/'manifest.json'
    roots = [FAILED,FAILED_NATIVE,PASSED,POPULATION,HOST]
    base.write_new(manifest,dict(files=[base.bind(p) for root in roots for p in sorted(root.rglob('*')) if p.is_file()]))
    record = dict(schema_version='sporespore_r10u_host_population_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_component_evidence',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),
        design=base.bind(ROOT/'sdk/recovery/r10u_audit_handoff_design_v1.json'),
        history_result=base.bind(directory/'history-result.json'),
        history_source_before=base.bind(directory/'history-source-before.json'),
        history_source_after=base.bind(directory/'history-source-after.json'),
        archived_sources=sources,observed=result,claim_boundary=CLAIMS,
        remaining_work=['production route/worker/reader and launcher integration','complete successor source key',
            'complete retained-data final-auditor diagnostic','complete applicable safety gate and fresh pair',
            'three declared branch diagnostics','fresh held-out finite decision and QSDK-R10/M07 adoption'])
    audit(record);base.write_new(RECORD,record)
    return audit(record)


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(base.read(RECORD))))
