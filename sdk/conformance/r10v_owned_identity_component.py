"""Audit retained exact owned-process liveness checks; preserve the old ambiguity."""
import argparse
import json
from pathlib import Path
import re
import r10t_route_integration_component as b
import r10v_production_host_component as units
ROOT,EVIDENCE=b.ROOT,b.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10v_owned_identity_component_v1.json'
DIRECTORY=EVIDENCE/'r10v-owned-identity-component-03281e77b8bd446ca0a7d286fae1aa4e'
REGRESSION=EVIDENCE/'r10v-owned-identity-regression-34c63b7b9bcc48caa71c91fc3f2f9a56'
FIXTURE=EVIDENCE/'l15-owned-process-identity-00e21933bd49439b8bfdc31578971220'
CLAIMS=dict(exact_process_identity_test_implemented=True,original_failure_cause_unresolved=True,
    original_attempt_reclassified=False,production_launcher_changed=False,
    complete_safety_gate_passed=False,physical_attempt_started=False,world_build_count=0,
    solver_step_count=0,controller_or_dll_changed=False,physical_limits_changed=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20',full_program_score='14/25')


def observed():
    failed=b.read(DIRECTORY/'failed_gate.json')
    for key in ('host','supervisor','prehost'):b.verify(failed[key])
    v=b.read(failed['supervisor']['path']);stages=v['safety_stages']
    assert not v['ok'] and not v['physical_attempt_started'] and len(stages)==13
    assert all(s['passed'] for s in stages[:12]) and sum(s['test_count'] for s in stages[:12])==31
    assert stages[-1]['id']=='owned_process_relationship' and stages[-1]['test_count']==7 and not stages[-1]['passed']
    log=(Path(failed['supervisor']['path']).parent/stages[-1]['stderr']).read_text(encoding='utf-8')
    assert 'OWNED_HELPER_STILL_RUNNING:329548' in log and 'FAILED (failures=1)' in log
    assert failed['original_process_creation_identity_not_retained'] and failed['original_failure_cause_unresolved']
    host=b.read(failed['host']['path']);assert host['owned_cleanup_complete'] and host['source_unchanged']
    units.lifecycle(Path(failed['host']['path']).parent)
    stage=b.read(REGRESSION/'stage.json');execution=b.read(REGRESSION/'execution.json')
    assert execution['passed'] and execution['source_unchanged']
    assert stage['passed'] and stage['test_count']==7 and stage['exit_code']==0 and not stage['timed_out']
    for root in (REGRESSION,FIXTURE):assert b.read(root/'source_before.json')==b.read(root/'source_after.json')
    lock=b.read(REGRESSION/'operation_lock.json');assert lock['acquired'] and not lock['test_only'] and lock['role']=='conformance'
    for stream in ('stdout','stderr'):
        assert b.bind(REGRESSION/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
    log=(REGRESSION/stage['stderr']).read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ',log,re.M)==['7'] and log.rstrip().endswith('OK')
    live=b.read(FIXTURE/'live.json');assert not live['legacy_contains_l15_field']
    assert all(r['run']['exit_code']==0 and r['validation_error']=='' for r in live['runs'])
    assert live['legacy_run']['exit_code']==0 and live['world_build_count']==live['solver_step_count']==0
    identities=b.read(FIXTURE/'owned-identities.json');assert len(identities)==4
    assert all(type(r['pid']) is int and type(r['creation_filetime']) is int and not units.win.alive(r) for r in identities)
    joined=b.read(FIXTURE/'joined.stdout.log')
    assert joined==dict(owned_identities_joined=True,crossed_creation_identity_ignored=True,
        live_identity_refused=True,world_build_count=0,owned_count=4)
    assert b.read(FIXTURE/'joined-execution.json')['exit_code']==b.read(FIXTURE/'live-execution.json')['exit_code']==0
    assert not (FIXTURE/'joined.stderr.log').read_bytes() and not (FIXTURE/'live.stderr.log').read_bytes()
    return dict(original_passed_stages=12,original_passed_tests=31,
        original_owned_process_tests_passed=6,original_owned_process_tests_failed=1,
        corrected_relationship_tests_passed=7,retained_exact_owned_identities=4,
        live_identity_refused=True,crossed_creation_identity_ignored=True,source_unchanged=True)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for name in ('auditor','failed_manifest','corrected_manifest'):b.verify(record[name])
    for name in ('failed_manifest','corrected_manifest'):
        for item in b.read(record[name]['path'])['files']:b.verify(item)
    for archive in record['source_archives']:
        b.verify(archive['key']);b.verify(archive['snapshot'])
        for item in b.read(archive['key']['path'])['bound_source_files']:
            assert b.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert record['observed']==observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    observation=observed();manifest=DIRECTORY/'corrected_manifest.json'
    files={p for root in (REGRESSION,FIXTURE) for p in root.rglob('*') if p.is_file()}
    files.add(DIRECTORY/'failed_gate.json')
    b.write_new(manifest,dict(files=[b.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10v_owned_identity_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_exact_owned_identity_test',question_class='development'),
        auditor=b.bind(__file__),failed_manifest=b.bind(DIRECTORY/'failed_manifest.json'),corrected_manifest=b.bind(manifest),
        source_archives=[b.read(DIRECTORY/n) for n in ('failed_source_archive.json','corrected_source_archive.json')],
        observed=observation,claim_boundary=CLAIMS,
        interpretation='The original v21 PID-presence check failed without retaining a creation identity. Its cause remains unresolved: these records do not prove PID reuse, an exited process object or an actual surviving helper. The successor fixture retains original process outputs and exact creation times; the checker requires the same live process and includes live and crossed-identity controls. Production launcher and physical contracts are unchanged.',
        next='Fresh complete source key and clean pushed freeze, then fresh prehost and complete qualification before any physical reservation.')
    audit(record)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as f:json.dump(record,f,indent=2);f.write('\n')
    return audit(record)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--create',action='store_true')
    print(json.dumps(create() if p.parse_args().create else audit(b.read(RECORD))))
