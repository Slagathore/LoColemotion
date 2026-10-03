"""Read-only retained audit of R10K preparation, native sessions and launch checks."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/recovery/r10k_preparation_report_integration_v1.json'
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


def sources(contract_binding, snapshot_path, current=False):
    contract = read(verify(contract_binding))
    snapshot = read(snapshot_path)
    changed = {r['path']: r['raw_sha256'] for r in snapshot['changed_files']}
    for item in contract['bound_source_files']:
        name = item['path']
        digest = changed.get(name)
        if digest is None:
            digest = 'sha256:' + hashlib.sha256(subprocess.check_output(
                ['git', 'show', snapshot['head'] + ':' + name], cwd=ROOT)).hexdigest()
        require(digest == item['raw_sha256'], 'PREPARATION_OBSERVED_SOURCE:' + name)
        if current:
            require('sha256:' + hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest,
                    'PREPARATION_CURRENT_SOURCE:' + name)
    return len(contract['bound_source_files'])


def reader(directory, expected=None):
    execution = read(directory / 'execution.json')
    raw = (directory.parent / 'worker_report.json').read_bytes()
    require(execution['input_raw_sha256'] == 'sha256:' + hashlib.sha256(raw).hexdigest()
            and execution['returncode'] == (0 if expected is None else 1)
            and execution['timed_out'] is False, 'PREPARATION_READER_EXECUTION')
    require('ERROR:' not in (directory / 'stderr.txt').read_text(encoding='utf-8'), 'PREPARATION_READER_SCRIPT_ERROR')
    values = [json.loads(line.split(' ', 1)[1]) for line in
              (directory / 'stdout.txt').read_text(encoding='utf-8').splitlines()
              if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
    require(len(values) == 1, 'PREPARATION_READER_MARKER')
    value = values[0]
    require(value['ok'] is (expected is None) and value.get('failure_code') == expected,
            'PREPARATION_READER_RESULT')
    require(value['world_build_count'] == value['solver_step_count'] == 0
            and value['physical_acceptance_authority'] is False and value['release_authority'] is False,
            'PREPARATION_READER_AUTHORITY')
    return value


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_preparation_report_integration_v1', 'PREPARATION_SCHEMA')
    require(record['claim_boundary'] == dict(preparation_to_walking_report_verified=True,
        full_safety_gate_passed_on_current_sources=False, complete_production_route_qualified=False,
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
        world_build_count=0, solver_step_count=0, sdk1_score='14/20'), 'PREPARATION_CLAIMS')
    for key in ['auditor', 'predecessor_record', 'observed_entry_contract', 'prospective_entry_contract',
                'prospective_candidate_profile', 'runtime_binding', 'consumed_r10j_closure']:
        verify(record[key])
    verify(read(verify(record['runtime_binding']))['runtime'])
    names = set()
    for item in record['retained_evidence']:
        require(item['path'] not in names, 'PREPARATION_DUPLICATE_EVIDENCE')
        names.add(item['path'])
        verify(item)
    root = Path(record['preparation_root'])
    require((root / 'source_before.json').read_bytes() == (root / 'source_after.json').read_bytes()
            == (root / 'setup_source_after.json').read_bytes(), 'PREPARATION_SOURCE_STABILITY')
    observed_count = sources(record['observed_entry_contract'], root / 'source_before.json')
    original = read(root / 'input.json')['source_report']
    verify(original)
    produced = read(root / 'fixture.json')
    require(produced['ok'] is True and produced['original_policy_validation']['ok'] is True
            and produced['synthetic_measurements_only'] is True
            and produced['world_build_count'] == produced['solver_step_count'] == 0, 'PREPARATION_PRODUCER')
    report = produced['report']
    require(report == read(root / 'report/worker_report.json') and report['synthetic_test_fixture'] is True,
            'PREPARATION_SERIALIZATION')
    sessions = report['retained_arm']['walking_sessions']
    require(len(sessions) == len({s['session_id'] for s in sessions}) == 3
            and [len(s['step_receipt_sha256s']) for s in sessions] == [173, 171, 2], 'PREPARATION_SESSIONS')
    for session in sessions:
        require(session['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] == 1,
                'PREPARATION_SESSION_SHUTDOWN')
    positive = reader(root / 'report/passive_entry_replay')
    require(positive['complete_report_timeline_replayed'] is True and positive['transition_count'] == 618
            and positive['initial_global_semantic_step'] == 0
            and positive['walking_control_replay']['replayed_walking_steps'] == 2, 'PREPARATION_TIMELINE')
    stance = positive['stance_entry_replay']
    require(tuple(stance[k] for k in ['replayed_neutral_commands','replayed_hold_commands','recomputed_readiness_samples'])
            == (173,171,344), 'PREPARATION_COMMAND_POPULATION')
    measured = read(root / 'finite-task-measurement.json')
    require(measured['finite_task_predicates_passed'] is False and measured['predicates']['entry_ready'] is True
            and measured['predicates']['planned_cycles'] is False and measured['predicates']['settled_stop'] is False,
            'PREPARATION_FINITE_NEGATIVE')
    for name, expected in REFUSALS.items():
        reader(root / name / 'passive_entry_replay', expected)
    launcher = Path(record['launcher_root'])
    require((launcher / 'source_before.json').read_bytes() == (launcher / 'source_after.json').read_bytes(),
            'PREPARATION_LAUNCHER_SOURCE_STABILITY')
    prospective_count = sources(record['prospective_entry_contract'], launcher / 'source_before.json', current_sources)
    selected = read(launcher / 'selected-stages.json')
    require(selected['test_count'] == 186 and len(selected['stages']) == 38, 'PREPARATION_SELECTED_STAGE_COUNTS')
    preparation = [s for s in selected['stages'] if s['id'] == 'r10k_preparation_report']
    require(len(preparation) == 1 and preparation[0]['tests'] == 2 and preparation[0]['timeout_seconds'] == 600,
            'PREPARATION_SELECTED_STAGE')
    for name in ['complete','missing','wrong_count','false_pass','untyped_pass','timeout','missing_preparation']:
        execution = read(launcher / ('prelaunch-' + name + '.execution.json'))
        require(execution['returncode'] == (0 if name == 'complete' else 1), 'PREPARATION_PRELAUNCH_CONTROL')
        if name != 'complete':
            require('R10K_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING' in
                    (launcher / ('prelaunch-' + name + '.stderr.txt')).read_text(encoding='utf-8'), 'PREPARATION_PRELAUNCH_REFUSAL')
        require('-Library' in execution['command'][-1] and '-RunSmoke' not in execution['command'][-1],
                'PREPARATION_LIBRARY_ONLY')
    return dict(ok=True, observed_bound_sources=observed_count, prospective_bound_sources=prospective_count,
        retained_files=len(names), preparation_commands=344, fresh_v51_commands=2, independently_replayed_transitions=618,
        reader_refusals=8, selected_tests=186, selected_stages=38, full_current_gate_pending=True,
        world_build_count=0, solver_step_count=0, sdk1_score='14/20', physical_acceptance_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    print(json.dumps(audit(parser.parse_args().current_sources), sort_keys=True))
