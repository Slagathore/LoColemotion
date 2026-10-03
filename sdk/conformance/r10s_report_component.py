"""Read-only audit of R10S synthetic complete-report and refusal evidence.

Each observed source key remains archived. This component does not authorize
a world, qualify the complete launcher, or convert a synthetic task negative
into physical evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10s_report_component_v1.json'
DLL = 'sha256:7b1ce5dd546796e13a726e26a9c1f47ad4a27792768a40d0da58cd67409e9c2b'
MARKER = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
REFUSALS = {
    'ramp_alias': 'DEVELOPMENT_JOINT_ENTRY_SESSION_CROSSED',
    'hold_alias': 'DEVELOPMENT_HOLD_ENTRY_SESSION_CROSSED',
    'ramp_shutdown': 'R10H_ENTRY_REPLAY_HOLD_AFTER_RAMP',
    'hold_shutdown': 'R10H_ENTRY_REPLAY_SESSION_NOT_FRESH',
    'walking_start': 'R10H_ENTRY_REPLAY_WALKING_STARTED_WITHOUT_READY_ENTRY',
    'hold_readiness': 'R10H_ENTRY_REPLAY_READINESS_RECOMPUTATION',
    'fresh_memory': 'DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    'motor_command': 'DEVELOPMENT_WALKING_ENTRY_READER_MOTOR_COMMAND_LINK',
}


def require(value, code):
    if not value:
        raise ValueError('R10S_REPORT_COMPONENT_' + code)


def read(path):
    return json.loads(Path(path).read_bytes())


def sha(path):
    with Path(path).open('rb') as stream:
        return 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    require(sha(path) == item['raw_sha256'], 'BYTES:' + str(path))
    if 'byte_length' in item:
        require(path.stat().st_size == item['byte_length'], 'LENGTH')
    return path


def source_archive(binding, population):
    archive = read(verify(binding))
    rows = archive['files']
    require(len(rows) == population + 2 and len({v['path'] for v in rows}) == len(rows), 'ARCHIVE_POPULATION')
    by_name = {v['path']: v for v in rows}
    for item in rows:
        verify(dict(path=item['archive_path'], byte_length=item['byte_length'], raw_sha256=item['raw_sha256']))
    contract = read(by_name[archive['source_contract']]['archive_path'])
    require(len(contract['bound_source_files']) == population, 'SOURCE_POPULATION')
    require(set(by_name) == {v['path'] for v in contract['bound_source_files']} | {archive['source_contract'], '.gitattributes'}, 'ARCHIVE_MEMBERS')
    for item in contract['bound_source_files']:
        require(by_name[item['path']]['raw_sha256'] == item['raw_sha256'], 'ARCHIVE_SOURCE_KEY')
    return contract


def execution(root, count, code):
    value = read(root / 'execution.json')
    require(value['exit_code'] == code and value['source_unchanged'] is True
        and value.get('timed_out', False) is False, 'EXECUTION')
    require((root / 'source_before.json').read_bytes() == (root / 'source_after.json').read_bytes(), 'SOURCE_CHANGED')
    if count is not None:
        log = (root / 'stderr.log').read_text(encoding='utf-8')
        require(re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$', log, flags=re.M) == [str(count)], 'TEST_POPULATION')
        require(('\nOK\n' in log) if code == 0 else ('FAILED (errors=1)' in log), 'TEST_RESULT')


def replay(directory, report_binding, expected=None, refusal=None):
    run = read(directory / 'execution.json')
    require(type(run['returncode']) is int and run['returncode'] == (0 if refusal is None else 1)
        and run['timed_out'] is False and run['world_build_count'] == run['solver_step_count'] == 0, 'READER_EXECUTION')
    output = {}
    for name in ['stdout', 'stderr']:
        path = directory / (name + '.txt')
        require(run[name + '_binding'] == dict(byte_length=path.stat().st_size, raw_sha256=sha(path)), 'READER_LOG_BINDING')
        output[name] = path.read_text(encoding='utf-8')
    require('ERROR:' not in output['stdout'] + output['stderr'], 'READER_SCRIPT_ERROR')
    markers = [json.loads(line[len(MARKER):]) for line in output['stdout'].splitlines() if line.startswith(MARKER)]
    require(len(markers) == 1, 'READER_MARKER')
    value = markers[0]
    require(run['input_raw_sha256'] == report_binding['raw_sha256'] == value['input_raw_sha256'], 'READER_INPUT')
    require(value['runtime_raw_sha256'] == DLL and value['process_id'] == run['process_id']
        and value['world_build_count'] == value['solver_step_count'] == value['native_physics_read_count'] == 0
        and value['physical_acceptance_authority'] is False and value['release_authority'] is False, 'READER_IDENTITY')
    if refusal is not None:
        require(value['ok'] is False and value['failure_code'] == refusal, 'EXPECTED_REFUSAL')
    else:
        require(value['ok'] is True and value['complete_report_timeline_replayed'] is True
            and value['initial_global_semantic_step'] == 0 and value['complete_route_proven'] is False, 'COMPLETE_REPLAY')
        if expected is not None:
            published = dict(value)
            if run['ledger_scope']['authority_mode'] == 'post_exposure_retained_data_replay':
                # The Python wrapper explicitly relabels this historical replay;
                # the original Godot marker retains its process-local scope.
                require(value['ledger_scope'] == dict(subsystem='recovery',engine_scope='godot_jolt',
                    authority_mode='independent_retained_report_replay',question_class='development'), 'RAW_READER_SCOPE')
                published['ledger_scope'] = dict(value['ledger_scope'],authority_mode='post_exposure_retained_data_replay')
                require(expected.get('original_attempt_reclassified') is False, 'DIAGNOSTIC_PUBLICATION')
            require(all(expected.get(k) == v for k, v in published.items())
                and expected['process_receipt_sha256'] == sha(directory / 'execution.json'), 'READER_PUBLICATION')
    return value


def audit(current_sources=False, record=None):
    record = read(RECORD) if record is None else record
    require(record['schema_version'] == 'sporespore_r10s_report_component_v1', 'SCHEMA')
    verify(record['auditor'])
    runtime = read(verify(record['runtime_binding']))
    require(runtime['runtime']['raw_sha256'] == DLL, 'RUNTIME_BINDING')
    verify(runtime['runtime'])
    for item in record['retained_evidence']:
        verify(item)
    bindings = {str(Path(item['path']).resolve()): item for item in record['retained_evidence']}
    def bound(path):
        return bindings[str(Path(path).resolve())]
    contracts = [source_archive(item, n) for item, n in zip(record['source_archives'], [613,620,621,622], strict=True)]
    if current_sources:
        for item in contracts[-1]['bound_source_files']:
            verify(item)
    initial, branches, refused_path, refused_measurement, repaired = [Path(record[k]) for k in
        ['initial_run', 'branch_run', 'refused_diagnostic_path_run', 'refused_measurement_run', 'repaired_run']]
    for root, count, code in [(initial,7,1),(branches,18,1),(refused_path,None,1),(refused_measurement,None,1),(repaired,18,0)]:
        execution(root,count,code)
    require('R10S_FINITE_TASK_CONTRACT_DRIFT' in (initial/'stderr.log').read_text(encoding='utf-8'), 'ORIGINAL_CONTRACT_REFUSAL')
    require('maximum_v50_walking_commands' in read(refused_measurement/'wrapper-error.json')['error'], 'ORIGINAL_SCHEMA_REFUSAL')
    original_report = branches/'preparation/report/worker_report.json'
    replay(branches/'preparation/report/passive_entry_replay', bound(original_report),
           refusal='DEVELOPMENT_WALKING_ENTRY_READER_NATIVE_OUTPUT_MISMATCH')
    corrected = read(repaired/'original-report-replay.json')
    diagnostic = Path(read(repaired/'invocation.json')['diagnostic_replay'])
    replay(diagnostic,bound(original_report),expected=corrected)
    native_only = Path(read(refused_measurement/'invocation.json')['diagnostic_replay'])
    replay(native_only,bound(original_report))
    require(read(native_only/'execution.json')['source_unchanged_during_replay'] is True
        and read(diagnostic/'execution.json')['source_unchanged_during_replay'] is True, 'DIAGNOSTIC_SOURCE')
    report_counts = {}
    for name, folder, count in [('upright','upright',575),('partial','branches',575),('prone','branches',286)]:
        base = branches/folder
        result = read(base/(name+'.results.json'))['active']
        value = replay(base/(name+'-active/passive_entry_replay'),bound(base/(name+'-active/worker_report.json')),expected=result)
        require(value['transition_count'] == count, 'RECOVERY_TRANSITIONS')
        measure = read(base/(name+'-active/finite-task-measurement.json'))
        require(measure['finite_task_predicates_passed'] is False and measure['predicates']['planned_cycles'] is False
            and measure['predicates']['recovery_completed'] is (name != 'prone'), 'FINITE_TASK_NEGATIVE')
        report_counts[name] = count
    fresh = repaired/'fresh'
    result = read(fresh/'replay-result.json')
    replay(fresh/'report/passive_entry_replay',bound(fresh/'report/worker_report.json'),expected=result)
    stance = result['stance_entry_replay']
    require(result['walking_control_replay']['replayed_walking_steps'] == 2
        and result['walking_contact_validation']['validated_native_contact_steps'] == 2
        and result['walking_start_validation']['validated_resume_sessions'] == 1
        and result['finite_walking_measurement']['command_count'] == 2, 'FRESH_WALKING_SESSION')
    require(result['transition_count'] == 611
        and [stance[k] for k in ['replayed_neutral_commands','replayed_hold_commands','recomputed_readiness_samples']] == [166,171,337], 'PREPARATION_COUNTS')
    measure = read(fresh/'finite-task-measurement.json')
    require(measure['finite_task_predicates_passed'] is False and measure['predicates']['planned_cycles'] is False
        and measure['entry']['final_consecutive_hold_ready'] >= 30, 'PREPARATION_FINITE_NEGATIVE')
    require(read(fresh/'production-launch-refusal.json') == dict(failure_code='R10S_DEVELOPMENT_PREREQUISITE_BINDING',
        physical_authority=False,test_only_prerequisite_standin=True), 'SYNTHETIC_PREREQUISITE_REFUSED')
    refusals = read(fresh/'refusals.json')
    require(set(refusals) == set(REFUSALS), 'REFUSAL_POPULATION')
    for name, code in REFUSALS.items():
        require(refusals[name]['failure_code'] == code, 'REFUSAL_CODE')
        replay(fresh/name/'passive_entry_replay',bound(fresh/name/'worker_report.json'),refusal=code)
    for row in record['readiness_refusals']:
        replay(Path(row['directory']),bound(Path(row['report'])),refusal=row['failure_code'])
    require(len(record['readiness_refusals']) == 2, 'READINESS_REFUSALS')
    observed = dict(ok=True, distinct_test_cases=27, complete_synthetic_report_paths=4,
        recovery_report_transitions=report_counts, no_kick_report_transitions=611,
        neutral_commands=166, hold_commands=171, fresh_walking_commands=2,
        corrupted_report_refusals=10, observed_source_versions=4,
        world_build_count=0,solver_step_count=0,synthetic_reports_only=True,
        complete_safety_gate_qualified=False,physical_execution_authorized=False,
        physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')
    require(observed == record['observed'], 'RECORDED_OBSERVATION')
    return dict(observed,current_sources_verified=current_sources,retained_evidence_files=len(record['retained_evidence']))


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--current-sources',action='store_true')
    args=parser.parse_args()
    print('R10S_REPORT_COMPONENT '+json.dumps(audit(args.current_sources),separators=(',',':')))
