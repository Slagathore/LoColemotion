"""Audit the complete v19 stage pass and its receipt-transport correction."""
import argparse
import json
from pathlib import Path
import re
import r10t_route_integration_component as b
import r10v_production_host_component as units
ROOT,EVIDENCE=b.ROOT,b.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10v_prelaunch_transport_component_v1.json'
DIRECTORY=EVIDENCE/'r10v-prelaunch-transport-component-55d6510e30a24f4f9211d1c9545fa7a7'
REGRESSION=EVIDENCE/'r10v-transport-regression-556844b1bac94ecd85ac2421fbd61678'
LAUNCHER=EVIDENCE/'development-r10v-launcher-0413b03e23f24d09b6cbd3e4d04f08cc'
CLAIMS=dict(retained_v19_safety_stages_all_passed=True,retained_v19_prelaunch_passed=False,
    current_complete_safety_gate_passed=False,receipt_integer_transport_corrected=True,
    physical_attempt_started=False,world_build_count=0,solver_step_count=0,
    controller_or_dll_changed=False,physical_limits_changed=False,
    original_attempt_reclassified=False,physical_acceptance_authority=False,
    release_authority=False,sdk1_score='14/20',full_program_score='14/25')


def observed():
    failed=b.read(DIRECTORY/'failed_gate.json')
    for name in ('host','supervisor','prehost'):b.verify(failed[name])
    value=b.read(failed['supervisor']['path']);stages=value['safety_stages']
    assert not value['ok'] and not value['physical_attempt_started']
    assert value['failure_code']=='R10V_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    assert len(stages)==66 and all(s['passed'] and s['exit_code']==0 and not s['timed_out'] for s in stages)
    assert sum(s['test_count'] for s in stages)==258
    host=b.read(failed['host']['path']);assert host['source_unchanged'] and host['owned_cleanup_complete']
    units.lifecycle(Path(failed['host']['path']).parent)
    before=b.read(DIRECTORY/'typed_transport_before.json');after=b.read(DIRECTORY/'typed_transport_after.json')
    assert not before['accepted'] and after['accepted']
    assert before['failure']==value['failure_code'] and after['failure']==''
    for row in (before,after):
        assert row['diagnostic_typed_projection'] and not row['original_reclassified']
        assert row['first_local_type']=='System.Int32' and row['world_build_count']==row['solver_step_count']==0
        assert [r['id'] for r in row['imported_types']]==['r10v_production_host','r10v_compact_retention']
        assert all(r[k]=='System.Int64' for r in row['imported_types'] for k in ('test_count','expected_test_count','exit_code'))
    stage=b.read(REGRESSION/'stage.json');execution=b.read(REGRESSION/'execution.json')
    assert execution['passed'] and execution['source_unchanged']
    assert stage['passed'] and stage['test_count']==5 and stage['exit_code']==0 and not stage['timed_out']
    for root in (REGRESSION,LAUNCHER):assert b.read(root/'source_before.json')==b.read(root/'source_after.json')
    lock=b.read(REGRESSION/'operation_lock.json');assert lock['acquired'] and not lock['test_only'] and lock['role']=='conformance'
    for stream in ('stdout','stderr'):
        assert b.bind(REGRESSION/stage[stream])['raw_sha256']=='sha256:'+stage[stream+'_sha256']
    log=(REGRESSION/stage['stderr']).read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ',log,re.M)==['5'] and log.rstrip().endswith('OK')
    cases=b.read(LAUNCHER/'prelaunch-controls.json')['cases']
    assert len(cases)==26 and [r['id'] for r in cases if r['accepted']]==['complete','serialized_prehost','serialized_all']
    assert all(r['failure']==value['failure_code'] for r in cases if not r['accepted'])
    selected=b.read(LAUNCHER/'selected-stages.json')
    assert len(selected['stages'])==66 and selected['test_count']==258
    return dict(retained_stage_passes=66,retained_test_passes=258,
        original_refusal='Int64_imported_prehost_receipts_rejected_by_Int32_only_check',
        actual_launcher_tests_passed=5,prelaunch_positive_cases=3,prelaunch_negative_cases=23,
        original_typed_projection_refused=True,corrected_typed_projection_accepted=True,source_unchanged=True)


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
    files={p for root in (REGRESSION,LAUNCHER) for p in root.rglob('*') if p.is_file()}
    files.update(DIRECTORY/name for name in ('typed_transport_before.json','typed_transport_after.json','failed_gate.json'))
    b.write_new(manifest,dict(files=[b.bind(p) for p in sorted(files)]))
    record=dict(schema_version='sporespore_r10v_prelaunch_transport_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_receipt_integer_transport_correction',question_class='development'),
        auditor=b.bind(__file__),failed_manifest=b.bind(DIRECTORY/'failed_manifest.json'),corrected_manifest=b.bind(manifest),
        source_archives=[b.read(DIRECTORY/n) for n in ('failed_source_archive.json','corrected_source_archive.json')],
        observed=observation,claim_boundary=CLAIMS,
        interpretation='All v19 stage tests passed, then the production prelaunch predicate rejected the two verified JSON-imported Int64 receipts. The corrected predicate accepts Int32 and Int64 without coercion, preserving exact values and refusing boolean, floating and textual representations. A diagnostic typed reconstruction of original receipts demonstrates the isolated fix; it does not authorize or resume the original run.',
        next='Fresh complete key, clean pushed freeze and full qualification before a new production invocation may reserve the still-unconsumed pair.')
    audit(record)
    with RECORD.open('x',encoding='utf-8',newline='\r\n') as f:json.dump(record,f,indent=2);f.write('\n')
    return audit(record)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--create',action='store_true')
    print(json.dumps(create() if p.parse_args().create else audit(b.read(RECORD))))
