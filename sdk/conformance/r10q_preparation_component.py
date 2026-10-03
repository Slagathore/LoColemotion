"""Audit retained R10Q branch and preparation reviews; no native execution."""
import hashlib
import json
from pathlib import Path
import development_recovery_candidate as candidate

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10q_preparation_component_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10Q_PREPARATION_COMPONENT_' + code)


def read(path):
    return json.loads(Path(path).read_bytes())


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    require(path.stat().st_size == item['byte_length'] and digest == item['raw_sha256'], 'BINDING:' + str(path))
    return path


def replay(directory):
    execution = read(directory / 'execution.json')
    text = (directory / 'stdout.txt').read_text(encoding='utf-8')
    rows = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines()
            if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
    require(len(rows) == 1 and execution['timed_out'] is False, 'REPLAY_EXECUTION')
    require((directory / 'stderr.txt').read_bytes() == b'', 'REPLAY_SCRIPT_ERROR')
    result = rows[0]
    require(execution['returncode'] == (0 if result['ok'] else 1), 'REPLAY_EXIT')
    require(result['world_build_count'] == result['solver_step_count'] == 0
            and result['physical_acceptance_authority'] is False and result['release_authority'] is False, 'REPLAY_AUTHORITY')
    return result


def audit(record):
    require(record['schema_version'] == 'sporespore_r10q_preparation_component_v1', 'SCHEMA')
    claims = dict(world_build_count=0, solver_step_count=0, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, successor_physics_observed=False,
        complete_smoke_safety_gate_passed=False, full_360_phase_startup_sweep_complete=False,
        original_results_regraded=False, sdk1_score='14/20')
    require(record['claim_boundary'] == claims, 'CLAIMS')
    for item in record['source_files'] + record['retained_evidence'] + [record['auditor']]:
        verify(item)
    runtime = read(verify(record['runtime_binding']))
    verify(runtime['runtime'])
    for item in runtime['source_files']:
        verify(item)
    selected = candidate.selection(record['candidate_profile'])
    require(selected['diagnostic_schedule']['walking_policy_id'] == 'r10q_v55_upright_recovery_route_v1', 'ROUTE')
    roots = {key: Path(path) for key, path in record['reviews'].items()}
    for key in ['branches_passed', 'preparation_passed', 'regression_passed']:
        root = roots[key]
        require((root / 'source_before.json').read_bytes() == (root / 'source_after.json').read_bytes(), 'SOURCE_DRIFT')
    # The branch review has its own exact earlier source snapshot. It is not
    # silently promoted to a fresh complete safety gate for the current key.
    for label, count in [('walking', 7), ('finite', 9)]:
        regression = roots['regression_passed']
        execution = read(regression / (label + '.execution.json'))
        log = (regression / (label + '.stderr.log')).read_text(encoding='utf-8')
        require(execution['exit_code'] == 0 and execution['expected_test_count'] == count
                and 'Ran ' + str(count) + ' tests in ' in log and log.rstrip().endswith('OK'), 'REGRESSION:' + label)
    branch = roots['branches_passed']
    for label, count, partial, canonical in [('partial', 575, 63, 0), ('prone', 286, 0, 13)]:
        active = branch / (label + '-active')
        result = replay(active / 'passive_entry_replay')
        require(result['ok'] is True and result['complete_report_timeline_replayed'] is True
                and result['transition_count'] == result['final_global_semantic_step'] == count
                and result['initial_global_semantic_step'] == 0, 'BRANCH_TIMELINE:' + label)
        require(result['partial_observation_count'] == partial
                and result['canonical_observation_count'] == canonical
                and result['upright_observation_count'] == 0, 'BRANCH_IDENTITY:' + label)
        measured = read(active / 'finite-task-measurement.json')
        require(measured['finite_task_predicates_passed'] is False and measured['predicates']['planned_cycles'] is False,
                'BRANCH_PREMATURE_WALKING')
        baseline = replay(branch / (label + '-baseline/passive_entry_replay'))
        require(baseline['ok'] is True and baseline['transition_count'] == 272, 'BRANCH_BASELINE')
    root = roots['preparation_passed']
    fixture = read(root / 'fixture.json')
    require(fixture['ok'] is True and fixture['failure'] == {}
            and fixture['synthetic_measurements_only'] is True
            and fixture['world_build_count'] == fixture['solver_step_count'] == 0, 'PREPARATION_PRODUCER')
    report = fixture['report']
    result = replay(root / 'report/passive_entry_replay')
    require(result['ok'] is True and result['complete_report_timeline_replayed'] is True
            and result['transition_count'] == result['final_global_semantic_step'] == 611
            and result['initial_global_semantic_step'] == 0, 'PREPARATION_TIMELINE')
    stance = result['stance_entry_replay']
    require([stance[key] for key in ['replayed_neutral_commands', 'replayed_hold_commands',
            'recomputed_readiness_samples']] == [166, 171, 337], 'PREPARATION_POPULATION')
    sessions = report['retained_arm']['walking_sessions']
    require(len(sessions) == 3 and len({s['session_id'] for s in sessions}) == 3
            and [len(s['step_receipt_sha256s']) for s in sessions] == [166, 171, 2], 'FRESH_SESSIONS')
    require(all(s['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] == 1
                for s in sessions), 'SHUTDOWN')
    measured = read(root / 'finite-task-measurement.json')
    require(measured['finite_task_predicates_passed'] is False
            and measured['predicates']['planned_cycles'] is False, 'PREMATURE_TASK_SUCCESS')
    refusals = read(root / 'refusals.json')
    require(set(refusals) == set(record['expected_refusals']), 'CONTROL_POPULATION')
    for label, expected in record['expected_refusals'].items():
        refused = replay(root / label / 'passive_entry_replay')
        require(refused['ok'] is False and refused['failure_code'] == expected
                and refusals[label]['failure_code'] == expected, 'CONTROL:' + label)
    failure = read(roots['preparation_alias_refusal'] / 'fixture.json')['failure']
    require(failure['failure_code'] == 'QSDK_R10F_WALKING_EVALUATION_INVALID'
            and failure['retained_failure']['evaluator_failure_code'] == 'QSDK_R10F_WALKING_EVALUATION_SHAPE_INVALID',
            'ORIGINAL_ALIAS_REFUSAL')
    prior = roots['preparation_wrapper_refusal']
    require(read(prior / 'fixture.json')['ok'] is True and replay(prior / 'report/passive_entry_replay')['ok'] is True,
            'ORIGINAL_NATIVE_SUCCESS')
    return dict(ok=True, branch_reports_replayed=4, partial_commands=63, prone_observations=13,
        preparation_transitions=611, ramp_commands=166, hold_commands=171, fresh_walking_commands=2,
        malformed_report_controls_refused=len(refusals), original_failures_retained=True,
        current_complete_safety_requalification_pending=True, **claims)


if __name__ == '__main__':
    print('R10Q_PREPARATION_COMPONENT ' + json.dumps(audit(read(RECORD)), separators=(',', ':')))
