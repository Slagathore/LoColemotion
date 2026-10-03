"""Audit the R10U shared-reader repairs and retain every failed predecessor check."""
import argparse
import json
from pathlib import Path
import re
import uuid

import r10t_route_integration_component as base
import r10u_route_integration_component as prior
import r10u_retained_final_audit as diagnostic

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10u_shared_reader_component_v1.json'
GATE = EVIDENCE/'development-recovery-smoke-279e75a2802a4b7b8cb5f82efaccaa62'
SWEEP = EVIDENCE/'r10u-remaining-stage-check-b96339109e2947deb267a1a80e8cb6d3'
HEADER = EVIDENCE/'r10u-final-integration-check-d6f401d6cedb468b877e995bdcc33399'
READER = EVIDENCE/'r10u-shared-reader-check-5a4d42c7f89e408b9d50a0e6c51b61f2'
FINAL = EVIDENCE/'r10u-final-integration-check-a59d45416c4b4da0ad90eefc34380ed5'
RETENTIONS = [EVIDENCE/name/'retention.json' for name in [
    'r10u-first-gate-retention-cb91f4f16abe4386a73ed2cc4ed8110f',
    'r10u-remaining-v7-retention-924bda629d1547a781c763e2031c9fa5',
    'r10u-preparation-v8-retention-a615a63cccf94bb58c02ef93dbc1c2e5',
    'r10u-preparation-v10-retention-777978be20294734a38c1dbe2701b2f4']]
CLAIMS = dict(complete_safety_gate_passed=False,physical_attempt_started=False,
    original_results_reclassified=False,world_build_count=0,solver_step_count=0,
    native_controller_changed=False,native_dll_changed=False,physical_budget_changed=False,
    held_out_population_declared=False,baseline_reused=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20',full_program_score='14/25')


def observed():
    gate=base.read(GATE/'supervisor_result.json')
    assert not gate['ok'] and gate['failure_code']=='SMOKE_SAFETY_GATE_FAILED:r10u_prone_report'
    assert not gate['physical_attempt_started'] and gate['children']==[]
    assert len(gate['safety_stages'])==36 and all(s['passed'] for s in gate['safety_stages'][:-1])
    assert sum(s['test_count'] for s in gate['safety_stages'][:-1])==113
    prior.snapshots_and_lock(SWEEP)
    sweep=base.read(SWEEP/'execution.json');assert sweep['source_unchanged']
    assert len(sweep['stage_results'])==29
    assert [s['id'] for s in sweep['stage_results'] if not s['passed']]==['r10u_preparation_refusals','r10u_preparation_positive']
    assert sum(s['test_count'] for s in sweep['stage_results'] if s['passed'])==113
    for path,failure in [(RETENTIONS[2],'WALKING_START_REPLAY_SELECTION'),(RETENTIONS[3],'maximum_v50_walking_commands')]:
        root=Path(base.read(path)['run_root']);prior.snapshots_and_lock(root)
        rows=base.read(root/'execution.json')['stage_results']
        assert len(rows)==2 and all(not v['passed'] and v['test_count']==0 and not v['timed_out'] for v in rows)
        for row in rows:assert failure in (root/row['stderr']).read_text(encoding='utf-8')
    prior.snapshots_and_lock(HEADER)
    header=base.read(HEADER/'execution.json')
    assert header['failure_code']=='DEVELOPMENT_STAGE_TIMEOUT_INVALID' and header['passed_tests']==7
    text=(HEADER/'r10u_declaration.stderr.log').read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ',text,flags=re.M)==['7'] and text.rstrip().endswith('OK')
    declaration=base.read(READER/'declaration.json');reader=base.read(READER/'result.json')
    prior.snapshots_and_lock(READER)
    assert reader['ok'] and reader['source_unchanged'] and not reader['original_reports_reclassified']
    assert len(reader['reports'])==6 and all(r['ok'] for r in reader['reports'])
    for item in declaration['inputs']:base.verify(item)
    assert sorted(r['transitions'] for r in reader['reports'])==[286,575,605,611,611,815]
    prior.stages(FINAL,[2,1],True)
    preparation=next(Path(v.strip()) for v in re.findall(r'^R10U_PREPARATION_REPORT_EVIDENCE (C:[^\r\n]+)$',
        (FINAL/'r10u_preparation_report.stdout.log').read_text(encoding='utf-8'),flags=re.M))
    assert len(base.read(preparation/'refusals.json'))==8
    replay=base.read(preparation/'replay-result.json')
    assert replay['ok'] and replay['transition_count']==611
    assert replay['stance_entry_independent_measurement']['recomputed_samples']==337
    assert not base.read(preparation/'finite-task-measurement.json')['finite_task_predicates_passed']
    return dict(first_gate_passed_stages=35,first_gate_passed_tests=113,first_gate_physical_children=0,
        remaining_sweep_passed_stages=27,remaining_sweep_passed_tests=113,remaining_sweep_setup_failures=2,
        original_reader_refusals_retained=4,final_header_tests_passed=7,retained_consumer_reports_passed=6,
        fresh_preparation_tests_passed=2,preparation_corruption_controls_passed=8,preparation_transitions=611,
        independent_preparation_readiness_samples=337,full_final_auditor_test_passed=True,
        preparation_complete_task_positive=False,diagnostic_wrapper_refusal_retained=True)


def audit(record,current_sources=False):
    assert record['claim_boundary']==CLAIMS
    for key in ['auditor','manifest','source_key','safety_contract']:base.verify(record[key])
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    for binding in record['retentions']:
        base.verify(binding);retention=base.read(binding['path'])
        base.verify(retention['manifest'])
        for item in base.read(retention['manifest']['path'])['files']:base.verify(item)
        archive=retention['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
        for item in base.read(archive['key']['path'])['bound_source_files']:
            assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert observed()==record['observed']
    contract=base.read(record['safety_contract']['path'])
    assert len(contract['stages'])==64 and sum(s['tests'] for s in contract['stages'])==contract['total_tests']==229
    if current_sources:assert diagnostic.exact_key()==record['source_key']
    return dict(ok=True,current_sources_verified=current_sources,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10u_*consumption_v1.json'))
    value=observed();folder=EVIDENCE/('r10u-shared-reader-closure-'+uuid.uuid4().hex);folder.mkdir()
    archive=base.archive_key(folder,ROOT/'sdk/recovery/r10u_v56_walking_entry_contract_v11.json',FINAL/'source_before.json')
    roots={HEADER,READER,FINAL}
    for root in [HEADER,FINAL]:
        for log in root.glob('*.stdout.log'):
            for name in re.findall(r'^[A-Z0-9_]+ (C:[^\r\n]+)$',log.read_text(encoding='utf-8'),flags=re.M):
                path=Path(name.strip())
                if path.parent==EVIDENCE and path.is_dir():roots.add(path)
    manifest=folder/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for root in sorted(roots) for p in sorted(root.rglob('*')) if p.is_file()]))
    retention=folder/'retention.json';base.write_new(retention,dict(source_archive=archive,manifest=base.bind(manifest)))
    record=dict(schema_version='sporespore_r10u_shared_reader_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_shared_reader_repair',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),source_key=diagnostic.exact_key(),
        safety_contract=base.bind(ROOT/'sdk/development/r10u_safety_stage_contract_v3.json'),
        retentions=[base.bind(p) for p in [*RETENTIONS,retention]],observed=value,claim_boundary=CLAIMS,
        correction_record='Preserve the first gate population refusal, two obsolete-prerequisite setup failures, two shared walking-start reader refusals, two legacy-horizon dispatch failures and one diagnostic wrapper timeout-ID refusal. Correct the test expectations and use real R10U native context attachment. Add R10U to shared replay session counting, independent stance/hold measurements, finite walking horizon selection and final-header seed selection. No controller, DLL, threshold or physical budget changes.',
        coverage_limit='These checks cover synthetic interfaces and labeled exposed reports. The two physical roles and five declared development cells remain unobserved; no prior report is a baseline or prerequisite. A fresh complete gate is required before the pair.')
    audit(record,True)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as stream:json.dump(record,stream,indent=2);stream.write('\n')
    return audit(record,True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(base.read(RECORD),args.current_sources)))
