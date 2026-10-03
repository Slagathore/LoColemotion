"""Retain the prospective host writer change and its complete interface checks."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import uuid
import r10t_route_integration_component as base
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
DESIGN=ROOT/'sdk/recovery/r10t_host_utf8_writer_design_v1.json'
KEY=ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v17.json'
RECORD=ROOT/'sdk/recovery/r10t_host_utf8_writer_component_v1.json'
CLAIMS=dict(world_build_count=0,solver_step_count=0,native_core_changed=False,native_dll_changed=False,
    test_assertions_changed=False,test_timeouts_changed=False,physical_budgets_changed=False,
    complete_development_interfaces_passed=True,complete_smoke_safety_gate_passed=False,
    physical_attempt_started=False,physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')
EXPECTED=[('exact_runtime_binding',11),('host_runtime_successor',3),('shared_interface_definitions',4),
    ('exact_publication',5),('production_publication',8),('owned_process_relationship',7),('godot_rust_owner_contract',2)]


def design_check():
    design=base.read(DESIGN)
    for key in ['failed_gate','timing_diagnostic_execution','timing_diagnostic_phases']:base.verify(design[key])
    for item in design['original_sources']:
        raw=subprocess.check_output(['git','show',item['source_commit']+':'+item['path']],cwd=ROOT)
        assert 'sha256:'+hashlib.sha256(raw).hexdigest()==item['git_blob_sha256']
    failed=base.read(design['failed_gate']['path'])
    assert not failed['physical_attempt_started'] and failed['failure_code']=='SMOKE_SAFETY_GATE_FAILED:exact_publication'
    stage=failed['safety_stages'][-1]
    assert not stage['passed'] and stage['test_count']==5 and stage['exit_code']==1
    old=base.read(design['timing_diagnostic_execution']['path'])
    assert old['exit_code']==0 and old['source_unchanged'] and old['exact_original_stdout_preserved']
    return design


def observe(root):
    root=Path(root);before=base.read(root/'source_before.json');after=base.read(root/'source_after.json')
    assert before==after
    execution=base.read(root/'execution.json');assert execution['exit_code']==0 and execution['source_unchanged']
    lines=(root/'interfaces.stdout.txt').read_text().splitlines()
    completed=[json.loads(line.split(' ',1)[1]) for line in lines if line.startswith('DEVELOPMENT_INTERFACES_COMPLETE ')]
    assert len(completed)==1
    receipt=completed[0];assert receipt['passed'] and not receipt['physical_smoke_executed']
    run=Path(receipt['output_root']);assert run.parent.resolve()==EVIDENCE.resolve()
    assert base.read(run/'receipt.json')==receipt
    assert [(s['id'],s['expected_test_count']) for s in receipt['stages']]==EXPECTED
    for (name,count),stage in zip(EXPECTED,receipt['stages'],strict=True):
        assert stage['passed'] and not stage['timed_out'] and stage['exit_code']==0 and stage['test_count']==count
        for stream in ['stdout','stderr']:
            assert base.bind(run/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
        log=(run/stage['stderr']).read_text()
        assert re.findall(r'^Ran (\d+) tests in ',log,re.M)==[str(count)] and log.rstrip().endswith('OK')
    timing=base.read(root/'timing/execution.json')
    assert timing['exit_code']==0 and timing['exact_original_stdout_preserved'] and timing['source_unchanged']
    phases=base.read(root/'timing/stdout.json')
    assert {p['phase'] for p in phases['phases']}=={'load_serializer','extract_production_functions',
        'read_original_182mb_stdout','serialize','utf8_file_write_flush','production_writer_total'}
    return dict(interface_stages=7,interface_tests=40,interface_root=str(run),source_unchanged=True,
        interface_stage_seconds={s['id']:s['seconds'] for s in receipt['stages']},
        publication_timing=phases,performance_comparison_is_unpaired_diagnostic=True,
        exact_original_stdout_bytes=182106256)


def audit(record,current_sources=False):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['design'],record['manifest']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    archive=record['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
        if current_sources:assert base.bind(ROOT/item['path'])['raw_sha256']==item['raw_sha256'],item['path']
    design_check();assert observe(record['run_root'])==record['observed']
    return dict(ok=True,current_sources_verified=current_sources,**record['observed'],**CLAIMS)


def create(root):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    root=Path(root).resolve();assert root.parent==EVIDENCE.resolve()
    observed=observe(root);design=design_check()
    directory=EVIDENCE/('r10t-host-utf8-writer-closure-'+uuid.uuid4().hex);directory.mkdir()
    archive=base.archive_key(directory,KEY,root/'source_before.json')
    roots={root,directory,Path(observed['interface_root']),Path(design['failed_gate']['path']).parent,
        Path(design['timing_diagnostic_execution']['path']).parent,
        EVIDENCE/'r10t-budgeted-gate-invocation-2f8d55eb4f144fb08933f494511fbaf6'}
    manifest=directory/'manifest.json';files={p for folder in roots for p in folder.rglob('*') if p.is_file()}
    base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10t_host_utf8_writer_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='actual_host_publication_interface_closure',question_class='development'),
        auditor=base.bind(__file__),design=base.bind(DESIGN),manifest=base.bind(manifest),source_archive=archive,
        run_root=str(root),observed=observed,claim_boundary=CLAIMS)
    audit(record,True);base.write_new(RECORD,record);return audit(record,True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    print('R10T_HOST_UTF8_WRITER '+json.dumps(create(args.create_from) if args.create_from else audit(base.read(RECORD),args.current_sources)))
