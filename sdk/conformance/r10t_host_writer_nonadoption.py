"""Retain the unadopted UTF-8 writer prototype without promoting its timings."""
import argparse
import json
from pathlib import Path
import uuid
import r10t_route_integration_component as base
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10t_host_utf8_writer_nonadoption_v1.json'
KEY=ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v17.json'
RUN=EVIDENCE/'r10t-host-utf8-writer-check-e723dabfa1a74be08eac7e9a7b72fea2'
INTERFACES=EVIDENCE/'development-interfaces-c6face066f22441c8823e31897f4fd30'
OLD=EVIDENCE/'r10t-publication-cost-diagnostic-f31d54fe1df14c4bb251cf326b0d100c'
NEW=EVIDENCE/'r10t-host-writer-cost-v17-bcb575e4ec324155aad8721749281249'
BOUNDARY=EVIDENCE/'r10t-host-writer-boundary-diagnostic-f5c0bcb59c8a44919e78284a072634f4'
CLAIMS=dict(prototype_adopted=False,performance_benefit_established=False,
    performance_comparisons_unpaired=True,original_results_reclassified=False,
    complete_interface_gate_passed=False,complete_smoke_safety_gate_passed=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,
    release_authority=False,sdk1_score='14/20')


def observed():
    for root in [RUN,OLD,NEW,BOUNDARY]:
        assert base.read(root/'source_before.json')==base.read(root/'source_after.json')
        assert base.read(root/'execution.json')['source_unchanged']
    assert base.read(RUN/'execution.json')['exit_code']==1
    receipt=base.read(INTERFACES/'receipt.json')
    assert not receipt['passed'] and receipt['failure_code']=='DEVELOPMENT_STAGE_FAILED:production_publication'
    stages=receipt['stages'];assert len(stages)==5 and all(s['passed'] for s in stages[:4])
    assert sum(s['test_count'] for s in stages[:4])==23
    assert stages[-1]['timed_out'] and stages[-1]['test_count']==0 and stages[-1]['expected_test_count']==8
    for stage in stages:
        for stream in ['stdout','stderr']:
            assert base.bind(INTERFACES/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
    for root in [OLD,NEW]:
        execution=base.read(root/'execution.json')
        assert execution['exit_code']==0 and execution['exact_original_stdout_preserved']
    boundary=base.read(BOUNDARY/'execution.json')
    assert boundary['exit_code']==0 and boundary['outputs_byte_identical']
    def phases(root):return {p['phase']:p['seconds'] for p in base.read(root/'stdout.json')['phases']}
    return dict(original_timing_seconds=phases(OLD),prototype_timing_seconds=phases(NEW),
        direct_boundary_timing=base.read(BOUNDARY/'stdout.json'),passed_interface_tests=23,
        next_action='Restore predecessor writer under a distinct successor source key; retain explicit host dependency bindings.')


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['manifest'],record['design']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    archive=record['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert observed()==record['observed']
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    observation=observed();directory=EVIDENCE/('r10t-host-writer-nonadoption-'+uuid.uuid4().hex);directory.mkdir()
    archive=base.archive_key(directory,KEY,RUN/'source_before.json')
    files={p for folder in [directory,RUN,INTERFACES,OLD,NEW,BOUNDARY] for p in folder.rglob('*') if p.is_file()}
    manifest=directory/'manifest.json';base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10t_host_utf8_writer_nonadoption_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='retained_unadopted_host_writer_diagnostic',question_class='development'),
        auditor=base.bind(__file__),design=base.bind(ROOT/'sdk/recovery/r10t_host_utf8_writer_design_v1.json'),
        manifest=base.bind(manifest),source_archive=archive,observed=observation,claim_boundary=CLAIMS)
    audit(record);base.write_new(RECORD,record);return audit(record)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print('R10T_WRITER_NONADOPTION '+json.dumps(create() if args.create else audit(base.read(RECORD))))
