"""Verify retained late-gate fixture correction without granting physics authority."""
import argparse
import json
from pathlib import Path
import re
import r10t_route_integration_component as b
import r10v_production_host_component as units
ROOT,EVIDENCE=b.ROOT,b.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10v_late_gate_component_v1.json'
DIRECTORY=EVIDENCE/'r10v-late-gate-component-5c4ade0359ca4aaf83c672703db6eba8'
REGRESSION=EVIDENCE/'r10v-late-stage-regression-e9e21b222c3749a8a6ae573361058e34'
PAIR_AUDIT=EVIDENCE/'r10v-retained-pair-audit-6b65a4932f4d42d1a97ed3ba13cc24db'
SOURCE=EVIDENCE/'r10v-complete-hold-report-64f7e8e39ed143e684fb997ed173f1ac/ready/worker_report.json'
CLAIMS=dict(test_fixture_binding_corrected=True,complete_safety_gate_passed=False,
    physical_attempt_started=False,world_build_count=0,solver_step_count=0,
    controller_or_dll_changed=False,physical_limits_changed=False,
    original_attempt_reclassified=False,physical_acceptance_authority=False,
    release_authority=False,sdk1_score='14/20',full_program_score='14/25')


def children():
    roots={REGRESSION,PAIR_AUDIT}
    for log in REGRESSION.glob('*.stdout.log'):
        for name in re.findall(r'^[A-Z0-9_]+ (C:[^\r\n]+)$',log.read_text(encoding='utf-8-sig'),re.M):
            child=Path(name);assert child.parent==EVIDENCE and child.is_dir();roots.add(child)
    return roots


def observed():
    failed=b.read(DIRECTORY/'failed_gate.json')
    for name in ('host','supervisor','prehost'): b.verify(failed[name])
    value=b.read(failed['supervisor']['path']);stages=value['safety_stages']
    assert not value['ok'] and not value['physical_attempt_started']
    assert len(stages)==62 and all(s['passed'] for s in stages[:61])
    assert sum(s['test_count'] for s in stages[:61])==221
    assert stages[-1]['id']=='r10v_hold_policy_report' and not stages[-1]['passed'] and not stages[-1]['timed_out']
    log=(Path(failed['supervisor']['path']).parent/stages[-1]['stderr']).read_text(encoding='utf-8')
    assert 'FileNotFoundError' in log and 'r10v-complete-hold-report-6b853690bba443ed99c51eeb1ee89d0c' in log
    host=b.read(failed['host']['path']);assert host['owned_cleanup_complete'] and host['source_unchanged']
    units.lifecycle(Path(failed['host']['path']).parent)
    result=b.read(REGRESSION/'execution.json');assert result['passed'] and result['source_unchanged']
    assert b.read(REGRESSION/'source_before.json')==b.read(REGRESSION/'source_after.json')
    lock=b.read(REGRESSION/'operation_lock.json');assert lock['acquired'] and not lock['test_only'] and lock['role']=='conformance'
    stages=b.read(REGRESSION/'stages.json')
    assert [(s['id'],s['test_count']) for s in stages]==[('r10v_hold_policy_report',1),('r10v_host_deadline',6),('r10v_retained_final_audit',1)]
    for stage in stages:
        assert stage['passed'] and stage['exit_code']==0 and not stage['timed_out'] and stage['seconds']<180
        for stream in ('stdout','stderr'):
            assert b.bind(REGRESSION/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
        log=(REGRESSION/stage['stderr']).read_text(encoding='utf-8')
        assert re.findall(r'^Ran (\d+) tests? in ',log,re.M)==[str(stage['test_count'])] and log.rstrip().endswith('OK')
    policy=next(r for r in children() if r.name.startswith('r10v-hold-policy-report-'))
    checks=b.read(policy/'result.json');assert checks['ok'] and len(checks['checks'])==15 and all(checks['checks'].values())
    assert b.read(policy/'input.json')['source_report']['raw_sha256']==b.bind(SOURCE)['raw_sha256']
    audit=b.read(PAIR_AUDIT/'result.json');assert audit['ok']
    assert audit['observed']['original_report_audit']['total_solver_steps']==4064
    assert b.read(PAIR_AUDIT/'source_before.json')==b.read(PAIR_AUDIT/'source_after.json')
    return dict(original_passed_stages=61,original_passed_tests=221,
        original_failure='copied_fixture_path_did_not_exist',late_stages_passed=3,late_tests_passed=8,
        native_policy_checks_passed=15,final_audit_stage_seconds=stages[-1]['seconds'],source_unchanged=True)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for key in ('auditor','failed_manifest','corrected_manifest','source_report'): b.verify(record[key])
    for key in ('failed_manifest','corrected_manifest'):
        for item in b.read(record[key]['path'])['files']: b.verify(item)
    for archive in record['source_archives']:
        b.verify(archive['key']);b.verify(archive['snapshot'])
        for item in b.read(archive['key']['path'])['bound_source_files']:
            assert b.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert record['observed']==observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    observation=observed();manifest=DIRECTORY/'corrected_manifest.json'
    files={p for root in children() for p in root.rglob('*') if p.is_file()}
    b.write_new(manifest,dict(files=[b.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10v_late_gate_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_fixture_binding_correction',question_class='development'),
        auditor=b.bind(__file__),failed_manifest=b.bind(DIRECTORY/'failed_manifest.json'),corrected_manifest=b.bind(manifest),
        source_report=b.bind(SOURCE),source_archives=[b.read(DIRECTORY/n) for n in ('failed_source_archive.json','corrected_source_archive.json')],
        observed=observation,claim_boundary=CLAIMS,
        interpretation='The v17 full invocation stopped before physics at a cloned nonexistent fixture path. The corrected test binds an actual completed v17 R10V synthetic ready-hold report. All three remaining late stages pass on v18; no original attempt or full-gate status is upgraded.',
        next='Declare fresh complete source key, clean pushed freeze, fresh prehost and complete 66-stage 258-test gate before physical reservation.')
    audit(record)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as f:json.dump(record,f,indent=2);f.write('\n')
    return audit(record)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--create',action='store_true')
    print(json.dumps(create() if p.parse_args().create else audit(b.read(RECORD))))
