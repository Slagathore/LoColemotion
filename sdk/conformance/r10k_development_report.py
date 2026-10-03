"""Read-only audit of R10K declaration/publication and synthetic complete reports."""
import argparse
import hashlib
import re
import subprocess
from pathlib import Path

from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/recovery/r10k_development_report_integration_v1.json'


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_development_report_integration_v1', 'REPORT_SCHEMA')
    claims = record['claim_boundary']
    require(claims == dict(world_build_count=0, solver_step_count=0, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False,
        complete_serialized_recovery_reports_verified=True, preparation_to_walking_report_verified=False,
        complete_production_route_qualified=False, sdk1_score='14/20'), 'REPORT_CLAIMS')
    for key in ('predecessor_record', 'candidate_profile', 'entry_contract', 'runtime_binding', 'auditor'):
        verify(record[key])
    entry = read(verify(record['entry_contract']))
    verify(read(verify(record['runtime_binding']))['runtime'])
    seen = set()
    for item in record['retained_evidence']:
        require(item['path'] not in seen, 'REPORT_DUPLICATE_EVIDENCE')
        seen.add(item['path'])
        verify(item)
    snapshot_path = verify(record['final_source_snapshot'])
    snapshot = read(snapshot_path)
    require(snapshot['head'] == record['source_parent_commit'], 'REPORT_SOURCE_PARENT')
    changed = {row['path']: row for row in snapshot['changed_files']}
    for item in entry['bound_source_files'] + record['test_and_integration_sources']:
        path = item['path']
        raw_sha = changed[path]['raw_sha256'] if path in changed else 'sha256:' + hashlib.sha256(
            subprocess.check_output(['git', 'show', snapshot['head'] + ':' + path], cwd=ROOT)).hexdigest()
        require(raw_sha == item['raw_sha256'], 'REPORT_OBSERVED_SOURCE:' + path)
        if current_sources:
            require('sha256:' + hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == raw_sha, 'REPORT_CURRENT_SOURCE:' + path)
    tests = 0
    for stage in record['passed_stages']:
        base = Path(stage['root'])
        pattern = stage['pattern']
        execution = read(base / (pattern + '.execution.json'))
        require(execution['returncode'] == 0, 'REPORT_STAGE_EXIT:' + pattern)
        require(execution.get('candidate_profile') == record['candidate_profile']['path']
            and execution.get('environment_key') == 'SPORESPORE_DEVELOPMENT_TEST_CANDIDATE', 'REPORT_STAGE_SELECTION:' + pattern)
        stderr = (base / (pattern + '.stderr.log')).read_text(encoding='utf-8')
        require(re.search(r'Ran ' + str(stage['tests']) + r' tests? in .*\n\nOK\s*$', stderr) is not None,
                'REPORT_STAGE_RESULT:' + pattern)
        tests += stage['tests']
    for directory in record['stable_test_roots']:
        base = Path(directory)
        require((base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes(),
                'REPORT_TEST_SOURCE_DRIFT:' + base.name)
    launcher = Path(record['launcher_root'])
    paired = read(launcher / 'paired-declaration.json')
    require(paired['seed'] == 40341 and paired['r10k_development']['required_entry_kind'] == 'partial'
        and paired['r10k_development']['prerequisite_pair'] is None, 'REPORT_LAUNCH_DECLARATION')
    require(read(launcher / 'paired.execution.json')['returncode'] == 0, 'REPORT_LAUNCH_LIBRARY')
    for label, code in [('single-without-pair', 'SINGLE_REQUIRES_POSITIVE_PAIR'), ('physical-gate-refusal', 'R10K_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING')]:
        require(read(launcher / (label + '.execution.json'))['returncode'] != 0
            and code in (launcher / (label + '.stderr.txt')).read_text(encoding='utf-8'), 'REPORT_LAUNCH_REFUSAL')
    seed = read(verify(record['seed_guard_result']))
    require(seed['ok'] is True and len(seed['checks']) == 28 and all(seed['checks'].values())
        and seed['sdk_instantiation_count'] == seed['world_build_count'] == seed['solver_step_count'] == 0, 'REPORT_SEED_GUARD')
    route = read(verify(record['route_result']))
    require(route['ok'] is True and len(route['checks']) == 45 and all(route['checks'].values()), 'REPORT_ROUTE')
    base = Path(record['report_root'])
    for branch in ('prone', 'partial'):
        execution = read(base / (branch + '.execution.json'))
        require(execution['exit_code'] == 0 and execution['world_build_count'] == execution['solver_step_count'] == 0
            and 'ERROR:' not in (base / (branch + '.stderr.log')).read_text(encoding='utf-8'), 'REPORT_PRODUCER:' + branch)
        results = read(base / (branch + '.results.json'))
        for label in ('active', 'baseline'):
            replay = results[label]
            require(replay['ok'] is True and replay['complete_report_timeline_replayed'] is True
                and replay['initial_global_semantic_step'] == 0 and replay['world_build_count'] == replay['solver_step_count'] == 0
                and replay['physical_acceptance_authority'] is False and replay['release_authority'] is False, 'REPORT_REPLAY')
            directory = base / (branch + '-' + label)
            process = read(directory / 'passive_entry_replay/execution.json')
            require(process['returncode'] == 0 and process['timed_out'] is False
                and process['input_raw_sha256'] == 'sha256:' + hashlib.sha256((directory / 'worker_report.json').read_bytes()).hexdigest(),
                'REPORT_PROCESS_BINDING')
            measured = read(directory / 'finite-task-measurement.json')
            require(measured['finite_task_predicates_passed'] is False and measured['predicates']['planned_cycles'] is False
                and measured['physical_acceptance_authority'] is False and measured['release_authority'] is False, 'REPORT_FINITE_NEGATIVE')
            if label == 'active':
                require(measured['predicates']['recovery_completed'] == (branch == 'partial'), 'REPORT_RECOVERY_COMPLETION')
            else:
                require(replay['transition_count'] == 272, 'REPORT_BASELINE_BOUNDARY')
        active = results['active']
        if branch == 'partial':
            require((active['entry_observation_count'], active['partial_observation_count'], active['canonical_initialization_count']) == (240,63,0)
                and active['stance_entry_replay']['recomputed_readiness_samples'] == 1, 'REPORT_PARTIAL_POPULATION')
        else:
            require((active['canonical_initialization_count'], active['canonical_observation_count'], active['partial_observation_count']) == (1,13,0), 'REPORT_PRONE_POPULATION')
    refusal = base / 'partial-crossed-readiness/passive_entry_replay'
    require((refusal / 'execution.json').is_file(), 'REPORT_REFUSAL_PROCESS')
    stdout = (refusal / 'stdout.txt').read_text(encoding='utf-8')
    require('R10H_ENTRY_REPLAY_READINESS_RECOMPUTATION' in stdout, 'REPORT_READINESS_REFUSAL')
    if current_sources:
        import development_recovery_candidate as candidate
        chosen = candidate.selection(candidate.reference_for_path(verify(record['candidate_profile'])))
        require(chosen['diagnostic_schedule']['walking_policy_id'] == 'r10k_v51_partial_fall_recovery_route_v1', 'REPORT_SELECTION')
    return dict(ok=True, passed_tests=tests, seed_guard_godot_checks=28, route_godot_checks=45,
        complete_synthetic_reports=4, cold_readiness_refusals=1, finite_tasks_positive=0,
        bound_sources=len(entry['bound_source_files']), retained_evidence_files=len(seen),
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


if __name__ == '__main__':
    import json
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print(json.dumps(audit(args.current_sources), sort_keys=True))
