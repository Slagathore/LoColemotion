"""Audit individual R10T launcher and publication stages, preserving all tests."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import unittest
import uuid
import r10t_route_integration_component as base
import r10t_publication_stage_partition as publication
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
DESIGN=ROOT/'sdk/recovery/r10t_host_stage_partition_design_v1.json'
KEY=ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v21.json'
RECORD=ROOT/'sdk/recovery/r10t_host_stage_partition_component_v1.json'
CLAIMS=dict(world_build_count=0,solver_step_count=0,native_core_changed=False,native_dll_changed=False,
    writer_prototype_adopted=False,test_assertions_changed=False,individual_host_deadlines_changed=False,
    physical_budgets_changed=False,complete_smoke_safety_gate_passed=False,physical_attempt_started=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def structure():
    design=base.read(DESIGN)
    for key in ['old_graph','new_graph','predecessor_publication_partition','failed_target_execution','failed_target_stages']:base.verify(design[key])
    old=base.read(ROOT/design['old_graph']['path']);new=base.read(ROOT/design['new_graph']['path']);expected=[]
    for stage in old['stages']:
        if stage['id']==design['old_launcher_stage_id']:expected.extend(dict(id=c['stage_id'],pattern=c['wrapper'],tests=1) for c in design['launcher_cases'])
        else:expected.append(stage)
    assert new['stages']==expected and len(expected)==62 and sum(s['tests'] for s in expected)==220
    assert new['unbound_common_stage_count']==old['unbound_common_stage_count']==20
    assert new['stage_timeout_overrides_seconds']==old['stage_timeout_overrides_seconds']
    assert new['component_coverage_reuse']==old['component_coverage_reuse']
    execution=base.read(design['failed_target_execution']['path']);assert execution['exit_code']==1 and execution['source_unchanged']
    failed=base.read(design['failed_target_stages']['path']);assert len(failed)==1 and failed[0]['timed_out'] and failed[0]['test_count']==0
    _,prefix=publication.structure()
    selected=[next(s for s in expected if s['id']==c['stage_id']) for c in design['launcher_cases']]+prefix
    assert len(selected)==19 and sum(s['tests'] for s in selected)==45
    return design,selected


def check():
    design,_=structure();publication_check=publication.check()
    item=design['original_launcher_test'];raw=(ROOT/item['path']).read_bytes()
    assert raw.count(b'r10t_safety_stage_contract_v5.json')==1
    predecessor=raw.replace(b'r10t_safety_stage_contract_v5.json',b'r10t_safety_stage_contract_v4.json')
    assert 'sha256:'+hashlib.sha256(predecessor).hexdigest()==item['raw_sha256']
    loader=unittest.TestLoader();old=publication.ids(loader.discover(str(ROOT/'tests'),pattern=Path(item['path']).name));selected=[]
    for case in design['launcher_cases']:
        found=publication.ids(loader.discover(str(ROOT/'tests'),pattern=case['wrapper']));assert found==[case['test_id']];selected.extend(found)
    assert not loader.errors and old==selected and len(selected)==5
    return dict(stages=62,tests=220,target_tests=45,identical_launcher_tests=selected,
        identical_publication_tests=publication_check['identical_publication_tests'],
        launcher_source_delta='selected graph v4 to v5 only',predecessor_writer_restored=True)


def observe(root):
    root=Path(root);assert base.read(root/'source_before.json')==base.read(root/'source_after.json')
    execution=base.read(root/'execution.json');assert execution['exit_code']==0 and execution['source_unchanged']
    lock=base.read(root/'operation_lock.json');assert lock['acquired'] and lock['role']=='conformance' and not lock['test_only']
    _,expected=structure();stages=base.read(root/'stage_results.json');assert [s['id'] for s in stages]==[s['id'] for s in expected]
    for spec,stage in zip(expected,stages,strict=True):
        assert stage['passed'] and not stage['timed_out'] and stage['exit_code']==0
        assert stage['test_count']==stage['expected_test_count']==spec['tests']
        for stream in ['stdout','stderr']:assert base.bind(root/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
        log=(root/stage['stderr']).read_text();assert re.findall(r'^Ran (\d+) tests? in ',log,re.M)==[str(spec['tests'])] and log.rstrip().endswith('OK')
    return dict(targeted_tests=45,source_unchanged=True,stages=[dict(id=s['id'],tests=s['test_count'],seconds=s['seconds']) for s in stages])


def audit(record,current_sources=False):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['design'],record['manifest']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    for archive in record['source_archives']:
        base.verify(archive['key']);base.verify(archive['snapshot'])
        for item in base.read(archive['key']['path'])['bound_source_files']:
            assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
            if current_sources and Path(archive['key']['path'])==KEY:assert base.bind(ROOT/item['path'])['raw_sha256']==item['raw_sha256'],item['path']
    assert observe(record['run_root'])==record['observed']
    if current_sources:assert check()==record['population_check']
    return dict(ok=True,current_sources_verified=current_sources,**record['observed'],**CLAIMS)


def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root=Path(root).resolve();assert root.parent==EVIDENCE.resolve();observed=observe(root);checked=check();design,_=structure()
    previous=Path(design['failed_target_execution']['path']).parent
    directory=EVIDENCE/('r10t-host-stage-closure-'+uuid.uuid4().hex);directory.mkdir()
    archives=[base.archive_key(directory,ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v19.json',previous/'source_before.json'),base.archive_key(directory,KEY,root/'source_before.json')]
    roots=base.children(root)|base.children(previous)|{directory};files={p for folder in roots for p in folder.rglob('*') if p.is_file()};manifest=directory/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10t_host_stage_partition_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='unchanged_individual_host_test_stages',question_class='development'),
        auditor=base.bind(__file__),design=base.bind(DESIGN),manifest=base.bind(manifest),source_archives=archives,
        run_root=str(root),observed=observed,population_check=checked,claim_boundary=CLAIMS)
    audit(record,True);base.write_new(RECORD,record);return audit(record,True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    result=check() if args.check else create(args.create_from) if args.create_from else audit(base.read(RECORD),args.current_sources)
    print('R10T_HOST_STAGE_PARTITION '+json.dumps(result))
