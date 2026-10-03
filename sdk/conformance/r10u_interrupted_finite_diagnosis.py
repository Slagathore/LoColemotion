"""Measure the interrupted pair only after separate complete native replays."""
import argparse
import gc
import json
from pathlib import Path
import sys
import development_passive_entry_profile as entry
import r10u_finite_task_audit as finite
import r10u_interrupted_pair_closure as closure
sys.path.insert(0,str(closure.ROOT/'sdk/python'))
from sporespore_locomotion import LocomotionCore

ROOT,EVIDENCE=closure.ROOT,closure.EVIDENCE
REPLAY=EVIDENCE/'r10u-interrupted-report-diagnosis-83ae2d6dfe804cc0bd46b281e70ad720'
RECORD=ROOT/'sdk/recovery/r10u_interrupted_pair_diagnostic_component_v1.json'
CLAIMS=dict(original_attempt_reclassified=False,r10u_development_chain_closed=True,
    original_full_workflow_proven=False,interruption_cause='unknown',new_world_count=0,
    new_solver_step_count=0,physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def run(directory):
    directory=Path(directory).resolve()
    assert directory.parent==EVIDENCE.resolve() and not directory.exists()
    directory.mkdir()
    before=entry._source_snapshot();closure.base.write_new(directory/'source_before.json',before)
    declaration=closure.base.read(REPLAY/'diagnostic_declaration.json')
    replay=closure.base.read(REPLAY/'result.json')
    assert replay['ok'] and replay['original_attempt_reclassified'] is False
    assert closure.base.read(REPLAY/'source_before.json')==closure.base.read(REPLAY/'source_after.json')
    lock=closure.base.read(REPLAY/'operation_lock.json')
    assert lock['acquired'] and not lock['abandoned_owner_recovered'] and not lock['test_only']
    bindings=[closure.base.bind(REPLAY/'result.json'),closure.base.bind(__file__),closure.base.bind(finite.__file__)]
    closure.base.write_new(directory/'diagnostic_declaration.json',dict(
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_finite_task_measurement',question_class='development'),
        bindings=bindings,intervention='Run the unchanged R10U finite-task component on exact retained report copies, after consuming their successful independent native replays. No final supervisor, launch audit or publication is synthesized.',**CLAIMS))
    cells=[]
    for role,source in zip(closure.ROLES,declaration['inputs']):
        path=REPLAY/role/'worker_report.json'
        closure.base.verify(source)
        assert closure.base.bind(path)['raw_sha256']==source['raw_sha256']
        validated=entry.consume_replay(path)
        assert validated==closure.base.read(REPLAY/role/'consumer.stdout.json')
        report=entry.read(path)
        chosen=entry.selection_for_report(report)
        compiled=LocomotionCore(entry.binding(chosen)['runtime']['path']).compile_bounded_quadruped(report['configuration']['base_descriptor'])
        measured=finite.measure(report,compiled)
        cell=dict(role=role,measurement=measured,replay_result=closure.base.bind(REPLAY/role/'consumer.stdout.json'))
        cells.append(cell)
        closure.base.write_new(directory/(role+'.json'),cell)
        print('FINITE_DIAGNOSIS '+json.dumps(dict(role=role,passed=measured['finite_task_predicates_passed'],predicates=measured['predicates'])),flush=True)
        del report,compiled,validated
        gc.collect()
    after=entry._source_snapshot();closure.base.write_new(directory/'source_after.json',after)
    assert before==after
    for item in bindings:closure.base.verify(item)
    result=dict(ok=True,cells=cells,source_unchanged=True,all_finite_predicates_passed=all(c['measurement']['finite_task_predicates_passed'] for c in cells),**CLAIMS)
    closure.base.write_new(directory/'result.json',result)
    return dict(ok=True,all_finite_predicates_passed=result['all_finite_predicates_passed'],**CLAIMS)


def observed(directory):
    result=closure.base.read(directory/'result.json')
    assert result['ok'] and result['source_unchanged']
    assert closure.base.read(directory/'source_before.json')==closure.base.read(directory/'source_after.json')
    for key,value in CLAIMS.items():assert result[key]==value
    lock=closure.base.read(directory/'operation_lock.json')
    assert lock['acquired'] and not lock['abandoned_owner_recovered'] and not lock['test_only']
    cells=[]
    for cell in result['cells']:
        m=cell['measurement'];w=m['walking']
        cells.append(dict(role=cell['role'],finite_task_predicates_passed=m['finite_task_predicates_passed'],
            predicates=m['predicates'],entry=m['entry'],walking_commands=w['command_count'],
            planned_cycles=len(w['planned_cycles']),stopping_commands=w['stopping_commands'],
            forward_advance_m=w['pre_first_to_post_last_body_forward_m']))
    return dict(complete_native_replays=2,transitions=[1749,2315],
        all_finite_predicates_passed=result['all_finite_predicates_passed'],cells=cells)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for item in record['bindings']+[record['manifest'],record['auditor']]:closure.base.verify(item)
    for item in closure.base.read(record['manifest']['path'])['files']:closure.base.verify(item)
    assert record['observed']==observed(Path(record['finite_diagnostic_root']))
    assert closure.audit(closure.base.read(closure.RECORD))['ok']
    return dict(ok=True,**record['observed'],**CLAIMS)


def create(directory):
    directory=Path(directory).resolve();assert directory.parent==EVIDENCE.resolve() and not RECORD.exists()
    observation=observed(directory)
    manifest=directory/'manifest.json'
    closure.base.write_new(manifest,dict(files=[closure.base.bind(p) for root in [REPLAY,directory]
        for p in sorted(root.rglob('*')) if p.is_file()]))
    record=dict(schema_version='sporespore_r10u_interrupted_pair_diagnostic_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        finite_diagnostic_root=directory.as_posix(),replay_root=REPLAY.as_posix(),
        auditor=closure.base.bind(__file__),manifest=closure.base.bind(manifest),
        bindings=[closure.base.bind(p) for p in [closure.RECORD,ROOT/'sdk/conformance/r10u_interrupted_report_diagnosis.py']],
        observed=observation,claim_boundary=CLAIMS)
    audit(record);closure.base.write_new(RECORD,record)
    return dict(ok=True,record=closure.base.bind(RECORD),**observation,**CLAIMS)


if __name__=='__main__':
    parser=argparse.ArgumentParser();mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--run');mode.add_argument('--create');args=parser.parse_args()
    print(json.dumps(run(args.run) if args.run else create(args.create) if args.create else audit(closure.base.read(RECORD))))
