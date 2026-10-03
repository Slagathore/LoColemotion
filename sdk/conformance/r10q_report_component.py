"""Verify R10Q serialized-report evidence without rerunning native worlds."""
import json
from pathlib import Path
import r10q_route_component as route

ROOT = route.ROOT
RECORD = ROOT / 'sdk/recovery/r10q_report_component_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10Q_REPORT_COMPONENT_' + code)


def receipt(directory):
    execution = json.loads((directory / 'execution.json').read_bytes())
    stdout = (directory / 'stdout.txt').read_text(encoding='utf-8')
    require((directory / 'stderr.txt').read_bytes() == b'', 'SCRIPT_ERROR')
    rows = [json.loads(line.split(' ', 1)[1]) for line in stdout.splitlines() if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
    require(len(rows) == 1 and execution['timed_out'] is False, 'REPLAY_PROCESS')
    require(execution['returncode'] == (0 if rows[0]['ok'] else 1), 'REPLAY_EXIT')
    return rows[0]


def audit(record):
    require(record['schema_version'] == 'sporespore_r10q_report_component_v1', 'SCHEMA')
    claims = dict(world_build_count=0, solver_step_count=0, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, complete_upright_report_boundary_validated=True,
        physical_precondition_and_walking_validated=False, partial_and_prone_full_reports_validated=False,
        complete_smoke_safety_gate_passed=False, full_360_phase_startup_sweep_complete=False,
        successor_physics_observed=False, original_results_regraded=False, sdk1_score='14/20')
    require(record['claim_boundary'] == claims, 'CLAIMS')
    for item in record['source_files'] + record['retained_evidence'] + [record['auditor'], record['route_component']]:
        route.verify(item)
    route.audit(json.loads(route.RECORD.read_bytes()))
    root = Path(record['evidence_root'])
    require((root / 'source_before.json').read_bytes() == (root / 'source_after.json').read_bytes(), 'SOURCE_DRIFT')
    fixture = json.loads((root / 'upright.fixture.json').read_bytes())
    require(fixture['ok'] is True and all(value is True for value in fixture['checks'].values())
        and fixture['synthetic_measurements_only'] is True and fixture['world_build_count'] == fixture['solver_step_count'] == 0, 'PRODUCER')
    for name, steps in [('active', 575), ('baseline', 272)]:
        directory = root / ('upright-' + name)
        replay = receipt(directory / 'passive_entry_replay')
        report = fixture[name]['report']
        require(report['synthetic_test_fixture'] is True and report['solver_step_count'] == steps, 'REPORT_BOUNDARY')
        require(replay['ok'] is True and replay['complete_report_timeline_replayed'] is True
            and replay['initial_global_semantic_step'] == 0 and replay['transition_count'] == replay['final_global_semantic_step'] == steps, 'FULL_TIMELINE')
        require(replay['world_build_count'] == replay['solver_step_count'] == 0 and
            replay['physical_acceptance_authority'] is False and replay['release_authority'] is False, 'REPLAY_CLAIMS')
        measured = json.loads((directory / 'finite-task-measurement.json').read_bytes())
        require(measured['finite_task_predicates_passed'] is False and measured['predicates']['planned_cycles'] is False
            and measured['predicates']['settled_stop'] is False, 'PREMATURE_TASK_SUCCESS')
        require(report['r10q_partial_recovery']['step_packets'] == [] and replay['canonical_initialization_count'] == 0, 'CROSSED_HISTORY')
        if name == 'active':
            require(measured['predicates']['recovery_completed'] is True and measured['predicates']['entry_ready'] is True
                and replay['upright_observation_count'] == 63 and replay['entry_observation_count'] == 240, 'UPRIGHT_RECOVERY')
        else:
            require(report['r10q_upright_recovery']['step_packets'] == [] and replay['upright_observation_count'] == 0, 'NO_KICK_HISTORY')
    refusal = receipt(root / 'upright-crossed-readiness/passive_entry_replay')
    require(refusal['ok'] is False and refusal['failure_code'] == 'R10H_ENTRY_REPLAY_READINESS_RECOMPUTATION', 'CORRUPTION_REFUSAL')
    return dict(ok=True, complete_reports_replayed=2, upright_report_steps=575, no_kick_boundary_steps=272,
        readiness_corruption_refused=True, both_reports_remain_finite_task_negative=True, **claims)


if __name__ == '__main__':
    print('R10Q_REPORT_COMPONENT ' + json.dumps(audit(json.loads(RECORD.read_bytes())), separators=(',', ':')))
