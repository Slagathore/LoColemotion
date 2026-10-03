"""Verify compact-retention controls and all real shared-interface regressions."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import uuid
import r10t_route_integration_component as base

ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
RUN=EVIDENCE/'r10v-retention-check-68c9a01def4e4d0793ddb2b14043bf5e'
INTERFACES=EVIDENCE/'r10v-retention-interfaces-3e7455fb68d64b1eaa2921ed8b40c2a9'
RECORD=ROOT/'sdk/recovery/r10v_compact_retention_component_v1.json'
EXPECTED=[('exact_runtime_binding',11),('host_runtime_successor',3),('shared_interface_definitions',4),
    ('exact_publication',5),('production_publication',8),('owned_process_relationship',7),('godot_rust_owner_contract',2)]
CLAIMS=dict(compact_retention_implemented=True,actual_child_launcher_component_integrated=True,
    complete_r10v_production_workflow_integrated=False,complete_safety_gate_passed=False,
    physical_attempt_started=False,world_build_count=0,solver_step_count=0,
    original_attempt_reclassified=False,physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def snapshot(root):
    before=base.read(root/'source_before.json');assert before==base.read(root/'source_after.json')
    assert before['head']=='6d6606aa1a36f5412ff25d85542bb71b416c5b13'
    for item in before['changed_files']:
        assert not item['deleted']
        raw=base64.b64decode(item['replacement_base64'],validate=True)
        assert 'sha256:'+hashlib.sha256(raw).hexdigest()==item['raw_sha256']
    execution=base.read(root/'execution.json')
    assert execution['exit_code']==0 and execution['source_unchanged']
    return before


def interface_receipt():
    records=[json.loads(line.split(' ',1)[1]) for line in (INTERFACES/'interfaces.stdout.txt').read_text().splitlines()
        if line.startswith('DEVELOPMENT_INTERFACES_COMPLETE ')]
    assert len(records)==1
    receipt=records[0]
    assert receipt['passed'] and not receipt['physical_smoke_executed']
    assert not receipt['physical_execution_authorized'] and not receipt['official_qualification_passed']
    assert [(s['id'],s['test_count']) for s in receipt['stages']]==EXPECTED
    assert all(s['passed'] and s['exit_code']==0 and not s['timed_out'] for s in receipt['stages'])
    root=Path(receipt['output_root']);assert root.parent==EVIDENCE
    for stage in receipt['stages']:
        for kind in ('stdout','stderr'):
            assert base.bind(root/stage[kind])['raw_sha256']=='sha256:'+stage[kind+'_sha256']
    assert (INTERFACES/'interfaces.stderr.txt').stat().st_size==0
    return receipt


def observed():
    assert snapshot(RUN)==snapshot(INTERFACES)
    lock=base.read(RUN/'operation_lock.json')
    assert lock['acquired'] and not lock['abandoned_owner_recovered'] and not lock['test_only']
    result=base.read(RUN/'result.json');assert result['ok'] and len(result['cases'])==8
    cases={c['case']:c for c in result['cases']};assert all(c['passed'] for c in cases.values())
    prefixes=dict(corrupt_artifact='R10V_RETENTION_ARTIFACT_worker_report',missing_artifact='RETAINED_FILE_MISSING:',
        crossed_launch='QSDK_R10F_L15_LAUNCH_ENCLOSING_CHILD_child_attempt_id',
        invalid_health='R10V_RETENTION_INVALID_engine_health_passed',wrong_route='R10V_COMPACT_ROUTE_REQUIRED')
    for name,prefix in prefixes.items():
        assert cases[name]['expected_refusal'] and cases[name]['failure_code'].startswith(prefix)
        assert not (RUN/name/'payload_release_receipt.json').exists()
    assert 'already exists' in cases['duplicate_envelope']['failure_code']
    assert (RUN/'duplicate_envelope/child_envelope.json').read_text()=='original duplicate-control marker'
    assert not (RUN/'duplicate_envelope/payload_release_receipt.json').exists()
    assert cases['wrong_route']['native_executor_calls']==0
    assert cases['integrated_child']['native_executor_calls']==1 # explicitly synthetic executor seam
    sizes=[]
    for name in ('compact_large','integrated_child'):
        assert not cases[name]['expected_refusal'] and not cases[name]['failure_code']
        release=base.read(RUN/name/'payload_release_receipt.json')
        compact=base.read(RUN/name/'compact_result.json')
        assert 'report' not in compact and release['report_payload_in_compact_metadata'] is False
        assert release['launch_relationship_valid'] and release['original_evidence_rewritten'] is False
        base.verify(release['retained_envelope'])
        assert compact['retained_envelope_binding']==release['retained_envelope']
        for item in release['verified_artifacts'].values():base.verify(item)
        assert 0<release['compact_metadata_byte_length']<=65536
        sizes.append(dict(case=name,full_envelope_bytes=release['retained_envelope']['byte_length'],compact_metadata_bytes=release['compact_metadata_byte_length']))
    assert sizes[0]['full_envelope_bytes']>16*1024*1024 and sizes[1]['full_envelope_bytes']>4*1024*1024
    receipt=interface_receipt()
    return dict(retention_controls_passed=8,shared_interface_stages=7,shared_interface_tests_passed=40,
        wrong_route_refused_before_executor=True,actual_child_function_with_synthetic_executor_passed=True,
        unchanged_source_during_controls=True,retained_sizes=sizes,interface_root=receipt['output_root'])


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in record['bindings']+[record['manifest'],record['auditor']]:base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:base.verify(item)
    base.verify(base.read(RUN/'fixture.json')['original_envelope'])
    assert record['observed']==observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists();observation=observed()
    directory=EVIDENCE/('r10v-retention-component-'+uuid.uuid4().hex);directory.mkdir()
    roots={RUN,INTERFACES,Path(observation['interface_root'])}
    for root in list(roots):roots.update(base.children(root))
    manifest=directory/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for root in sorted(roots) for p in sorted(root.rglob('*')) if p.is_file()]))
    record=dict(schema_version='sporespore_r10v_compact_retention_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_verified_payload_retention_component',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),observed=observation,claim_boundary=CLAIMS,
        bindings=[base.bind(ROOT/name) for name in ['sdk/r10v_compact_child_retention.ps1',
            'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1','tests/test_r10v_compact_child_retention.ps1',
            'sdk/conformance/r10v_retention_check.py','sdk/recovery/r10v_durable_workflow_design_v1.json']],
        coverage='Eight controlled synthetic payload cases retain exposed R10U launch metadata solely as a validator fixture. The actual Invoke-L9ChildProcess function executes in the integrated case with only its physical executor replaced by a synthetic report source. Complete real shared interfaces then pass 40 tests across seven stages. No new physical population or original R10U record is changed.',
        remaining='R10V production selection, durable-host production integration, original progress and final-auditor path, complete source key and safety graph, fresh qualification and physical freeze remain required.')
    audit(record);base.write_new(RECORD,record)
    return dict(ok=True,record=base.bind(RECORD),**observation,**CLAIMS)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(base.read(RECORD))))
