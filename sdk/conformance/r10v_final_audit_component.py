"""Audit the retained full exposed-pair diagnostic and real consumption guards."""
import argparse
import json
from pathlib import Path
import r10t_route_integration_component as b
import r10v_production_host_component as units
import r10u_interrupted_pair_closure as closure

ROOT,EVIDENCE=b.ROOT,b.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10v_final_audit_component_v1.json'
DIRECTORY=EVIDENCE/'r10v-final-audit-component-e25af9dc2c9b4d1996968884a4b344c9'
RUN=EVIDENCE/'r10v-retained-pair-audit-bc3f6fb49cb145e2ac4fef722d8b75a0'
OUTER=EVIDENCE/'r10v-pair-audit-check-d2453b7dd67f4d24a2204f1912b4f822'
GUARD=EVIDENCE/'r10v-live-launch-guard-check-9a2cb673219e4190810584877a6a8e4d'
CLAIMS=dict(complete_exposed_pair_final_audit_passed=True,original_attempt_reclassified=False,
    original_r10u_chain_closed=True,r10v_physical_workflow_proven=False,
    complete_safety_gate_passed=False,physical_attempt_started=False,
    physical_launch_requires_full_gate_live_host_clean_pushed_freeze_and_single_use_reservation=True,
    world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def observed():
    value=b.read(RUN/'result.json');declaration=b.read(RUN/'declaration.json')
    assert value['ok'] and value['scope']==declaration['scope']
    assert value['scope']['separately_retained_diagnostic_replay_substitution'] is True
    assert value['scope']['projection_is_synthetic'] is True
    assert value['scope']['original_attempt_reclassified'] is False
    assert value['scope']['world_build_count']==value['scope']['solver_step_count']==0
    for item in declaration['bindings']:b.verify(item)
    assert b.read(RUN/'source_before.json')==b.read(RUN/'source_after.json')
    result=value['observed'];audit=result['original_report_audit']
    assert audit['ok'] and audit['total_solver_steps']==4064
    assert [x['solver_steps'] for x in audit['children']]==[1749,2315]
    finite=audit['r10u_finite_development']
    assert finite['all_tasks_positive'] and finite['branch_coverage_complete'] and len(finite['cells'])==2
    assert result['projected_declaration_validation_calls']==4
    assert [x['role'] for x in result['diagnostic_replay_substitutions']]==list(closure.ROLES)
    for row in result['diagnostic_replay_substitutions']:
        assert row['original_publication_missing'] and not row['original_attempt_reclassified']
        assert row['original_input']['raw_sha256']==row['diagnostic_input']['raw_sha256']
        for key in ('original_input','diagnostic_input','diagnostic_result','diagnostic_execution'):b.verify(row[key])
    assert all(not p.exists() for p in closure.missing_paths())
    execution=b.read(OUTER/'execution.json')
    assert execution['exit_code']==0 and not execution['timed_out'] and execution['timeout_seconds']==1800
    assert 0<result['elapsed_seconds']<execution['elapsed_seconds']<180
    history=b.read(DIRECTORY/'history.stdout.json')
    assert history['ok'] and history['archived_sources']==942 and history['original_audit']['r10u_development_chain_closed']
    assert (DIRECTORY/'history.stderr.log').stat().st_size==0
    units.unit(GUARD,8,0)
    for child in b.children(GUARD)-{GUARD}:
        assert b.read(child/'source_before.json')==b.read(child/'source_after.json')
    return dict(full_exposed_reports=2,original_solver_steps=[1749,2315],synthetic_declaration_validations=4,
        diagnostic_replay_substitutions=2,full_pair_audit_seconds=result['elapsed_seconds'],
        outer_execution_seconds=execution['elapsed_seconds'],launch_guard_tests_passed=8,
        inherited_final_audit_stage_bound_seconds=180,production_final_audit_bound_seconds=1800,
        original_missing_receipts_remain_missing=True,peak_working_set_measurement_available=False)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in (record['auditor'],record['manifest']):b.verify(item)
    for item in b.read(record['manifest']['path'])['files']:b.verify(item)
    for archive in record['source_archives']:
        b.verify(archive['key']);b.verify(archive['snapshot'])
        for item in b.read(archive['key']['path'])['bound_source_files']:
            assert b.bind(Path(archive['directory'])/item['path'])['raw_sha256']==item['raw_sha256']
    assert record['observed']==observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    observation=observed()
    roots={DIRECTORY,RUN,OUTER,GUARD,*b.children(GUARD)}
    manifest=DIRECTORY/'manifest.json'
    b.write_new(manifest,dict(files=[b.bind(p) for p in sorted({p for root in roots for p in root.rglob('*') if p.is_file()})]))
    record=dict(schema_version='sporespore_r10v_final_audit_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='exposed_pair_full_final_auditor_diagnostic',question_class='development'),
        auditor=b.bind(__file__),manifest=b.bind(manifest),source_archives=[b.read(DIRECTORY/n) for n in ('source_archive.json','guard_source_archive.json')],
        observed=observation,claim_boundary=CLAIMS,
        interpretation='The real shared final auditor processed both full original R10U reports. Only its missing replay-publication reads used explicit in-memory substitutions from separately consumed byte-identical diagnostic report copies. A synthetic R10V declaration exercised the real new validator. All original files and the incomplete classification remain unchanged. The conditional launch guard now requires live owned host context, all declared stage logs, clean pushed source and exclusive one-use reservation; eight isolated nested-namespace controls passed.',
        next='Declare a fresh complete source key, push the clean prospective freeze, then run fresh prehost qualification and the full 66-stage graph before any new physical child.')
    audit(record)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as stream:json.dump(record,stream,indent=2);stream.write('\n')
    return audit(record)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(b.read(RECORD))))
