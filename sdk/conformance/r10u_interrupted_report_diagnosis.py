"""Replay byte-identical diagnostic copies; never fill R10U's missing receipts."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
import development_passive_entry_profile as entry
import r10u_interrupted_pair_closure as closure

ROOT, EVIDENCE = closure.ROOT, closure.EVIDENCE


def run(directory):
    directory=Path(directory).resolve()
    assert directory.parent == EVIDENCE.resolve() and not directory.exists()
    assert directory.name.startswith('r10u-interrupted-report-diagnosis-')
    assert closure.audit(closure.base.read(closure.RECORD))['ok']
    for item in closure.base.read(closure.KEY)['bound_source_files']:
        assert closure.base.bind(ROOT/item['path'])['raw_sha256'] == item['raw_sha256']
    directory.mkdir()
    before=entry._source_snapshot()
    closure.base.write_new(directory/'source_before.json',before)
    bindings=[closure.base.bind(closure.RUN/'children'/role/'worker_report.json') for role in closure.ROLES]
    closure.base.write_new(directory/'diagnostic_declaration.json',dict(
        schema_version='sporespore_r10u_interrupted_report_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='post_exposure_retained_data_diagnosis',question_class='development'),
        closure=closure.base.bind(closure.RECORD),script=closure.base.bind(__file__),inputs=bindings,
        intervention='Byte-identical report copies in this separate diagnostic root; unchanged native reader, Python consumer, controller and finite predicates. The normal replay entrypoint writes only beside these copies. No original receipt is replaced or synthesized.',
        child_roles=list(closure.ROLES),replay_timeout_seconds=entry.REPLAY_TIMEOUT_SECONDS,
        world_build_count=0,solver_step_count=0,original_attempt_reclassified=False,
        physical_acceptance_authority=False,release_authority=False))
    cells=[]
    for role,item in zip(closure.ROLES,bindings):
        child=directory/role;child.mkdir()
        target=child/'worker_report.json'
        shutil.copyfile(item['path'],target)
        assert closure.base.bind(target)['raw_sha256'] == item['raw_sha256']
        started=time.monotonic()
        command=[sys.executable,str(Path(entry.__file__).resolve()),str(target),'--run']
        print('DIAGNOSTIC_REPLAY_START '+role,flush=True)
        with (child/'consumer.stdout.json').open('xb') as out,(child/'consumer.stderr.txt').open('xb') as err:
            process=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
        receipt=dict(command=command,exit_code=process.returncode,elapsed_seconds=time.monotonic()-started,
            input=closure.base.bind(target),original_input=item,world_build_count=0,solver_step_count=0,
            original_attempt_reclassified=False,physical_acceptance_authority=False,release_authority=False)
        closure.base.write_new(child/'consumer_execution.json',receipt)
        result=None
        if process.returncode==0:
            result=closure.base.read(child/'consumer.stdout.json')
            assert result['ok'] and result['complete_report_timeline_replayed']
            assert result['world_build_count']==result['solver_step_count']==0
            assert result['transition_count']==closure.ROLES[role][1]
        measure=result.get('finite_walking_measurement',{}) if result else {}
        cell=dict(role=role,exit_code=process.returncode,elapsed_seconds=receipt['elapsed_seconds'],
            replay_passed=result is not None,finite_predicates_passed=measure.get('finite_task_predicates_passed'),
            result_binding=closure.base.bind(child/'consumer.stdout.json'))
        cells.append(cell)
        print('DIAGNOSTIC_REPLAY_END '+json.dumps(cell),flush=True)
    after=entry._source_snapshot()
    closure.base.write_new(directory/'source_after.json',after)
    assert before==after
    for item in bindings:closure.base.verify(item)
    assert closure.audit(closure.base.read(closure.RECORD))['ok']
    result=dict(schema_version='sporespore_r10u_interrupted_report_diagnosis_result_v1',
        ok=all(x['replay_passed'] for x in cells),cells=cells,source_unchanged=True,
        world_build_count=0,solver_step_count=0,original_attempt_reclassified=False,
        r10u_development_chain_closed=True,physical_acceptance_authority=False,release_authority=False)
    closure.base.write_new(directory/'result.json',result)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('directory');args=parser.parse_args()
    print(json.dumps(run(args.directory)))
