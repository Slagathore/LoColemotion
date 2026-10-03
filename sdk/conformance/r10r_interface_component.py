"""Audit archived R10R interface reviews without new native calls or worlds."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
RECORD = ROOT / 'sdk/recovery/r10r_interface_component_v1.json'
REVIEWS = {
    'interfaces': 'r10r-safety-interfaces-cdf4e5edc4994a1fbd9dc5aaa010ce5b',
    'reports': 'r10r-report-interfaces-db88789615c94392b1cdca1bd8daeaf2',
    'branches': 'development-r10r-branch-report-5b8d1d6862544b14bc1548e1be83179e',
    'preparation': 'development-r10r-preparation-report-825827d2b5894a2d885391bb14de3a41',
    'declaration': 'development-r10r-declaration-79db4e04d4ba466e8b79bfefc5289635',
    'declaration_refusal': 'development-r10r-declaration-9a97ca8d843e46adaedeccf8e7e5dd22',
    'archive': 'r10r-interface-source-45b4f07e73c1409188367ff6de2a6fc7',
}
REFUSALS = dict(ramp_alias='DEVELOPMENT_JOINT_ENTRY_SESSION_CROSSED',
    hold_alias='DEVELOPMENT_HOLD_ENTRY_SESSION_CROSSED',
    ramp_shutdown='R10H_ENTRY_REPLAY_HOLD_AFTER_RAMP',
    hold_shutdown='R10H_ENTRY_REPLAY_SESSION_NOT_FRESH',
    walking_start='R10H_ENTRY_REPLAY_WALKING_STARTED_WITHOUT_READY_ENTRY',
    hold_readiness='R10H_ENTRY_REPLAY_READINESS_RECOMPUTATION',
    fresh_memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    motor_command='DEVELOPMENT_WALKING_ENTRY_READER_MOTOR_COMMAND_LINK')
CLAIMS = dict(world_build_count=0, solver_step_count=0, complete_smoke_safety_gate_passed=False,
    production_launcher_qualified=False, physical_execution_authorized=False,
    physical_acceptance_authority=False, release_authority=False, original_results_regraded=False,
    sdk1_score='14/20')


def read(path):
    return json.loads(Path(path).read_bytes())


def bind(path):
    path = Path(path)
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=digest)


def verify(item):
    actual = bind(item['path'])
    assert all(actual[key] == item[key] for key in actual), item['path']
    return Path(item['path'])


def replay(directory):
    run = read(directory/'execution.json')
    rows = [json.loads(line.partition(' ')[2]) for line in (directory/'stdout.txt').read_text(encoding='utf-8').splitlines()
        if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
    assert len(rows) == 1 and run['timed_out'] is False
    assert (directory/'stderr.txt').read_bytes() == b''
    value = rows[0]
    assert run['returncode'] == (0 if value['ok'] else 1)
    assert value['world_build_count'] == value['solver_step_count'] == 0
    assert value['physical_acceptance_authority'] is value['release_authority'] is False
    return value


def audit(record):
    assert record['schema_version'] == 'sporespore_r10r_interface_component_v1'
    assert record['claim_boundary'] == CLAIMS
    for item in record['retained_evidence'] + [record['auditor']]: verify(item)
    roots = {key: EVIDENCE/name for key, name in REVIEWS.items()}
    assert record['reviews'] == {key:path.as_posix() for key,path in roots.items()}
    archive = read(roots['archive']/'source-archive.json')
    sources = {row['source_path']:row for row in archive['source_files']}
    for row in sources.values(): verify(row)
    key = read(sources[archive['source_key']]['path'])
    assert len(key['bound_source_files']) == 459
    for row in key['bound_source_files']:
        assert sources[row['path']]['raw_sha256'] == row['raw_sha256']
    for name in ['declaration', 'branches', 'preparation']:
        assert (roots[name]/'source_before.json').read_bytes() == (roots[name]/'source_after.json').read_bytes()
    for name, count, code in [('interfaces', 61, 1), ('reports', 8, 0)]:
        run = read(roots[name]/'execution.json')
        log = (roots[name]/'stderr.log').read_text(encoding='utf-8')
        assert run['exit_code'] == code and run['world_build_count'] == run['solver_step_count'] == 0
        assert re.findall(r'^Ran (\d+) tests in ', log, flags=re.M) == [str(count)]
        assert log.rstrip().endswith('OK' if code == 0 else 'FAILED (failures=1)')
    assert read(roots['interfaces']/'refusal.json')['failed_check'] == 'unchanged_or_explicit_successor'
    assert read(roots['declaration_refusal']/'refusal.json')['status'] == 'synthetic_fixture_exclusive_write_refusal'
    guard = read(roots['declaration']/'godot-result.json')
    assert guard['ok'] is True and len(guard['checks']) == 38 and all(guard['checks'].values())
    assert guard['sdk_instantiation_count'] == guard['world_build_count'] == guard['solver_step_count'] == 0
    for label, transitions, partial, canonical in [('partial',575,63,0), ('prone',286,0,13)]:
        base = roots['branches']/(label+'-active')
        value = replay(base/'passive_entry_replay')
        assert value['ok'] is value['complete_report_timeline_replayed'] is True
        assert value['initial_global_semantic_step'] == 0 and value['transition_count'] == transitions
        assert (value['partial_observation_count'],value['canonical_observation_count'],value['upright_observation_count']) == (partial,canonical,0)
        assert read(base/'finite-task-measurement.json')['finite_task_predicates_passed'] is False
    crossed = replay(roots['branches']/'partial-crossed-readiness/passive_entry_replay')
    assert crossed['ok'] is False and crossed['failure_code'] == REFUSALS['hold_readiness']
    prep = roots['preparation']
    fixture = read(prep/'fixture.json')
    assert fixture['ok'] is True and fixture['failure'] == {}
    report = fixture['report']
    assert report['synthetic_test_fixture'] is report['synthetic_launch_prerequisite_standin'] is True
    refusal = read(prep/'production-launch-refusal.json')
    assert refusal['failure_code'] == 'R10R_DEVELOPMENT_PREREQUISITE_BINDING'
    value = replay(prep/'report/passive_entry_replay')
    assert value['ok'] is value['complete_report_timeline_replayed'] is True
    assert value['transition_count'] == 611 and value['initial_global_semantic_step'] == 0
    stance = value['stance_entry_replay']
    assert [stance[k] for k in ['replayed_neutral_commands','replayed_hold_commands','recomputed_readiness_samples']] == [166,171,337]
    sessions = report['retained_arm']['walking_sessions']
    assert len({s['session_id'] for s in sessions}) == 3
    assert [len(s['step_receipt_sha256s']) for s in sessions] == [166,171,2]
    assert all(s['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] == 1 for s in sessions)
    assert read(prep/'finite-task-measurement.json')['finite_task_predicates_passed'] is False
    for label, expected in REFUSALS.items():
        value = replay(prep/label/'passive_entry_replay')
        assert value['ok'] is False and value['failure_code'] == expected, label
    return dict(ok=True, reconciled_interface_tests=65, worker_guard_checks=38,
        branch_reports=2, preparation_transitions=611, readiness_samples=337,
        malformed_preparation_reports_refused=8, source_key_files=459,
        archived_source_files=len(sources), **CLAIMS)


def create():
    roots = {EVIDENCE/name for name in REVIEWS.values()}
    # Include each child review emitted by the two retained unittest invocations.
    for key in ['interfaces','reports']:
        for line in (EVIDENCE/REVIEWS[key]/'stdout.log').read_text(encoding='utf-8').splitlines():
            _, separator, suffix = line.partition(' ')
            path = Path(suffix)
            if separator and path.is_dir() and path.parent.resolve() == EVIDENCE.resolve(): roots.add(path)
    files = sorted({path for root in roots for path in root.rglob('*') if path.is_file()})
    record = dict(schema_version='sporespore_r10r_interface_component_v1',
        status='adapter_branch_preparation_interfaces_passed_production_launcher_pending',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='archived_zero_world_production_interfaces',question_class='development'),
        auditor=bind(__file__), reviews={key:(EVIDENCE/name).as_posix() for key,name in REVIEWS.items()},
        retained_evidence=[bind(path) for path in files], claim_boundary=CLAIMS)
    observed = audit(record)
    record['observed'] = observed
    with RECORD.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(record,stream,indent=2); stream.write('\n')
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--create',action='store_true')
    args = parser.parse_args()
    print('R10R_INTERFACE_COMPONENT '+json.dumps(create() if args.create else audit(read(RECORD))))
