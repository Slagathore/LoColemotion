"""Prospective exact consumer patch tested on immutable post-exposure evidence.

Execute the complete consumer with the proposed source loaded in memory while
the original frozen dependency bytes remain on disk. No validation is mocked:
the original report, declaration, native receipt, engine identity, hashes,
contact replay and finite-task measurements all pass through production code.
This grants no qualification and never upgrades or rewrites the failed attempt.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import types
import uuid

import r10ag_replay_invalid_closure as closed
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

SOURCE = ROOT / 'sdk/conformance/development_passive_entry_profile.py'
RECORD = ROOT / 'sdk/recovery/r10ag_consumer_repair_component_v1.json'
OLD_IMPORT = 'from r10ag_development import ROUTE as R10AG_ROUTE_ID'
NEW_IMPORT = 'from development_recovery_candidate import R10AG_ROUTE_ID'
OLD_TASK = 'candidate_profile.read(candidate_profile.R10AB_ROUTE_POLICY_PATH if selected_policy == R10AB_ROUTE_ID'
NEW_TASK = 'candidate_profile.read(candidate_profile.R10AG_ROUTE_POLICY_PATH if selected_policy == R10AG_ROUTE_ID else candidate_profile.R10AB_ROUTE_POLICY_PATH if selected_policy == R10AB_ROUTE_ID'


def proposed_source():
    original = subprocess.check_output(['git', 'show', closed.HEAD + ':' + SOURCE.relative_to(ROOT).as_posix()], cwd=ROOT)
    text = original.decode('utf-8')
    assert text.count(OLD_IMPORT) == text.count(OLD_TASK) == 1
    return text.replace(OLD_IMPORT, NEW_IMPORT).replace(OLD_TASK, NEW_TASK).encode('utf-8')


def check_result(result):
    assert result['ok'] is True and result['controller_and_diagnostic_replay_passed'] is True
    assert result['transition_count'] == 1113 and result['partial_observation_count'] == 601
    assert result['finite_walking_measurement']['status'] == 'walking_not_reached'
    assert result['stance_entry_independent_measurement']['recomputed_samples'] == 0
    assert result['physical_acceptance_authority'] is False and result['release_authority'] is False
    assert result['complete_route_proven'] is False
    assert result['process_receipt_sha256'] == bind(closed.CHILD/'passive_entry_replay/execution.json')['raw_sha256']


def run():
    assert not RECORD.exists()
    closed.audit(read(closed.RECORD))
    # Keep every consumed key dependency at its original bytes during this test.
    for row in read(closed.KEY)['bound_source_files']:
        assert bind(ROOT/row['path'])['raw_sha256'] == row['raw_sha256'], row['path']
    out = EVIDENCE / ('r10ag-consumer-repair-' + uuid.uuid4().hex)
    out.mkdir(); print('R10AG_CONSUMER_REPAIR_ROOT ' + str(out), flush=True)
    patched = proposed_source()
    (out/'prospective_consumer.py').write_bytes(patched)
    before = {p.as_posix():bind(p) for p in (SOURCE, closed.RECORD, closed.CHILD/'worker_report.json',
        closed.CHILD/'passive_entry_replay_result.json', closed.CHILD/'passive_entry_replay/execution.json',
        closed.CHILD/'passive_entry_replay/stdout.txt', closed.CHILD/'passive_entry_replay/stderr.txt')}
    write_new(out/'bindings_before.json',before)
    module = types.ModuleType('r10ag_prospective_production_consumer')
    module.__file__ = str(SOURCE)
    sys.modules[module.__name__] = module
    exec(compile(patched, str(out/'prospective_consumer.py'), 'exec'), module.__dict__)
    # Full real consumer; existing process receipt is read, never regenerated.
    result = module.consume_replay(closed.CHILD/'worker_report.json')
    check_result(result)
    after = {p:bind(p) for p in before}
    assert after == before
    write_new(out/'bindings_after.json',after)
    write_new(out/'result.json',dict(schema_version='sporespore_r10ag_post_exposure_consumer_result_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_consumer_repair',question_class='development'),
        ok=True, full_production_consumer_exercised=True, validation_doubles_used=False,
        original_attempt_reclassified=False, new_native_processes=0, new_worlds=0, new_solver_steps=0,
        prospective_source=bind(out/'prospective_consumer.py'), original_closure=bind(closed.RECORD),
        result=result, complete_safety_gate_qualified=False, physical_acceptance_authority=False, release_authority=False))
    return dict(ok=True,evidence_root=out.as_posix(),full_production_consumer_exercised=True,
        original_attempt_reclassified=False,production_patch_applied=False)


def adopt(out):
    out=Path(out).resolve(); assert out.parent==EVIDENCE.resolve() and out.name.startswith('r10ag-consumer-repair-')
    assert not RECORD.exists()
    value=read(out/'result.json'); check_result(value['result'])
    assert value['ok'] is True and value['validation_doubles_used'] is False
    assert read(out/'bindings_before.json') == read(out/'bindings_after.json')
    for path,item in read(out/'bindings_before.json').items(): assert bind(path)==item
    patched=proposed_source(); assert (out/'prospective_consumer.py').read_bytes()==patched
    SOURCE.write_bytes(patched)
    record=dict(schema_version='sporespore_r10ag_consumer_repair_component_v1',
        ledger_scope=value['ledger_scope'],auditor=bind(__file__),production_source=bind(SOURCE),
        original_closure=bind(closed.RECORD),evidence_root=out.as_posix(),
        bindings=[bind(p) for p in sorted(out.rglob('*')) if p.is_file()],
        full_production_consumer_exercised=True,validation_doubles_used=False,
        original_attempt_reclassified=False,complete_safety_gate_qualified=False,
        physical_acceptance_authority=False,release_authority=False,
        coverage_limit='Post-exposure consumption of one retained physical negative with zero walking/hold rows. A successor complete gate must also exercise the full consumer on reachable positive hold and walking reports; this is not renewed AG admission or execution authority.')
    write_new(RECORD,record)
    return audit(record)


def audit(record):
    for item in [record['auditor'],record['production_source'],record['original_closure'],*record['bindings']]:assert bind(item['path'])==item,item['path']
    assert SOURCE.read_bytes()==proposed_source()
    value=read(Path(record['evidence_root'])/'result.json');check_result(value['result'])
    assert value['original_attempt_reclassified'] is False and record['complete_safety_gate_qualified'] is False
    assert read(closed.RECORD)['claim_boundary']==closed.CLAIMS
    return dict(ok=True,full_production_consumer_exercised=True,validation_doubles_used=False,
        production_patch_applied=True,original_attempt_reclassified=False,
        complete_safety_gate_qualified=False,physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true');parser.add_argument('--adopt',type=Path)
    args=parser.parse_args()
    print(json.dumps(run() if args.run else adopt(args.adopt) if args.adopt else audit(read(RECORD))))
