"""Audit an incomplete R10T host-gate checkpoint; never grant launch authority."""
import argparse
import json
from pathlib import Path
import re
import uuid
import r10t_route_integration_component as base
ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
RUN=EVIDENCE/'r10t-host-stage-check-8bab296445ff4b9db37759b279dc8ce9'
KEY=ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v20.json'
RECORD=ROOT/'sdk/recovery/r10t_host_gate_pending_checkpoint_v1.json'
CLAIMS=dict(complete_targeted_host_gate_passed=False,complete_smoke_safety_gate_passed=False,
    physical_attempt_started=False,development_population_reserved=False,held_out_population_declared=False,
    original_failed_results_reclassified=False,writer_prototype_adopted=False,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False,
    sdk1_score='14/20',full_program_score='14/25')


def observed():
    execution=base.read(RUN/'execution.json');assert execution['exit_code']==1 and execution['source_unchanged']
    assert base.read(RUN/'source_before.json')==base.read(RUN/'source_after.json')
    stages=base.read(RUN/'stage_results.json')
    assert [s['id'] for s in stages]==['r10t_host_gate_discovery','r10t_host_gate_declaration','r10t_host_gate_timeouts','r10t_host_gate_prerequisites']
    assert all(s['passed'] and s['test_count']==1 for s in stages[:3])
    last=stages[-1];assert not last['passed'] and not last['timed_out'] and last['test_count']==1 and last['exit_code']==1
    for stage in stages:
        for stream in ['stdout','stderr']:assert base.bind(RUN/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
    log=(RUN/last['stderr']).read_text()
    assert 'timed out after 40 seconds' in log and '-R10TDiagnosticSeed 41146' in log
    return dict(status='incomplete_host_launcher_prerequisite_subprocess_timeout',
        passed_test_methods=3,error_test_methods=1,targeted_test_population=45,
        declared_complete_safety_stages=62,declared_complete_safety_tests=220,
        timeout_seconds=40,failed_mode='paired_library_with_wrong_seed_41146',
        source_unchanged=True,source_key=KEY.relative_to(ROOT).as_posix())


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in [record['auditor'],record['manifest'],record['safety_contract'],record['host_stage_design'],record['writer_nonadoption']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    archive=record['source_archive'];base.verify(archive['key']);base.verify(archive['snapshot'])
    for item in base.read(archive['key']['path'])['bound_source_files']:
        assert base.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert observed()==record['observed']
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    observation=observed();directory=EVIDENCE/('r10t-host-gate-pending-closure-'+uuid.uuid4().hex);directory.mkdir()
    archive=base.archive_key(directory,KEY,RUN/'source_before.json')
    roots=base.children(RUN)|{directory};files={p for folder in roots for p in folder.rglob('*') if p.is_file()}
    manifest=directory/'manifest.json';base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10t_host_gate_pending_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='retained_incomplete_zero_world_host_gate',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),source_archive=archive,
        safety_contract=base.bind(ROOT/'sdk/development/r10t_safety_stage_contract_v5.json'),
        host_stage_design=base.bind(ROOT/'sdk/recovery/r10t_host_stage_partition_design_v1.json'),
        writer_nonadoption=base.bind(ROOT/'sdk/recovery/r10t_host_utf8_writer_nonadoption_v1.json'),
        observed=observation,claim_boundary=CLAIMS,
        next_action='Run a fresh zero-world host check at the same prospective source key when host capacity permits; keep this failed attempt unchanged. The complete 62-stage gate remains required before any physical reservation.')
    audit(record);base.write_new(RECORD,record);return audit(record)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print('R10T_HOST_GATE_PENDING '+json.dumps(create() if args.create else audit(base.read(RECORD))))
