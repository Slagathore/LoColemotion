"""Read-only evidence audit for R10L declaration and complete report integration."""
import argparse
import hashlib
import json
from pathlib import Path
import re

from v52_extended_support_transfer import ROOT, read, verify
from r10k_preparation_report import sources, reader, REFUSALS

RECORD = ROOT / 'sdk/recovery/r10l_development_report_integration_v1.json'


def require(ok, code):
    if not ok:
        raise ValueError('R10L_REPORT_' + code)


def stable(root):
    require((root / 'source_before.json').read_bytes() == (root / 'source_after.json').read_bytes(),
            'SOURCE_STABILITY:' + root.name)


def wrapper_matches(raw, wrapped, directory):
    extra = {'stance_entry_independent_measurement', 'finite_walking_measurement', 'process_receipt_sha256'}
    require(set(wrapped) == set(raw) | extra and all(wrapped[k] == v for k, v in raw.items()), 'WRAPPED_REPLAY')
    digest = 'sha256:' + hashlib.sha256((directory / 'execution.json').read_bytes()).hexdigest()
    require(wrapped['process_receipt_sha256'] == digest, 'WRAPPED_PROCESS_RECEIPT')
    return True


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10l_development_report_integration_v1', 'SCHEMA')
    require(record['ledger_scope'] == dict(subsystem='recovery', engine_scope='godot_jolt',
        authority_mode='development_declaration_and_complete_report_integration', question_class='development'), 'SCOPE')
    require(record['claim_boundary'] == dict(complete_serialized_recovery_reports_verified=True,
        preparation_to_walking_report_verified=True, full_safety_gate_passed_on_current_sources=False,
        complete_production_route_qualified=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, world_build_count=0,
        solver_step_count=0, original_campaign_regraded=False, sdk1_score='14/20'), 'CLAIMS')
    for key in ['auditor', 'predecessor_record', 'design', 'runtime_binding',
                'recovery_entry_contract', 'preparation_entry_contract', 'candidate_profile']:
        verify(record[key])
    verify(read(verify(record['runtime_binding']))['runtime'])
    retained = set()
    for item in record['retained_evidence']:
        require(item['path'] not in retained, 'DUPLICATE_EVIDENCE')
        retained.add(item['path'])
        verify(item)
    suite = Path(record['suite_root'])
    declaration = Path(record['declaration_root'])
    recovery = suite / 'complete-report'
    preparation = suite / 'preparation-report'
    route = suite / 'current-route/route'
    for directory in [declaration, recovery, preparation, route]:
        stable(directory)
    require((preparation / 'source_before.json').read_bytes() ==
            (preparation / 'setup_source_after.json').read_bytes(), 'PREPARATION_SETUP_STABILITY')
    observed = sources(record['recovery_entry_contract'], recovery / 'source_before.json')
    prospective = sources(record['preparation_entry_contract'], preparation / 'source_before.json', current_sources)
    require(sources(record['preparation_entry_contract'], route / 'source_before.json') == prospective, 'ROUTE_SOURCES')
    test_count = 0
    for stage in record['test_results']:
        log = verify(stage['log']).read_text(encoding='utf-8-sig')
        require(re.search(r'Ran ' + str(stage['tests']) + r' tests? in .*\n\nOK\s*$', log), 'TEST_RESULT:' + stage['name'])
        test_count += stage['tests']
    seed = read(declaration / 'godot-result.json')
    require(seed['ok'] is True and len(seed['checks']) == 29 and all(seed['checks'].values())
        and seed['sdk_instantiation_count'] == seed['world_build_count'] == seed['solver_step_count'] == 0, 'SEED_GUARD')
    require(read(declaration / 'execution.json')['exit_code'] == 0, 'SEED_GUARD_PROCESS')
    declared = read(declaration / 'synthetic-declaration.json')
    require(declared['seed'] == 40441 and declared['r10l_development']['seed']['prefix_phase'] == 241
        and declared['r10l_development']['prerequisite_pair'] is None, 'DECLARED_POPULATION')
    for branch in ['prone', 'partial']:
        process = read(recovery / (branch + '.execution.json'))
        require(process['exit_code'] == 0 and process['world_build_count'] == process['solver_step_count'] == 0
            and 'ERROR:' not in (recovery / (branch + '.stderr.log')).read_text(encoding='utf-8'), 'RECOVERY_PRODUCER')
        results = read(recovery / (branch + '.results.json'))
        for label in ['active', 'baseline']:
            directory = recovery / (branch + '-' + label)
            result = reader(directory / 'passive_entry_replay')
            require(wrapper_matches(result, results[label], directory / 'passive_entry_replay') and result['complete_report_timeline_replayed'] is True
                and result['initial_global_semantic_step'] == 0, 'RECOVERY_REPLAY')
            report = read(directory / 'worker_report.json')
            require(report['synthetic_test_fixture'] is True and report['solver_step_count'] == result['transition_count']
                and report['r10l_development'] == declared['r10l_development']
                and report['held_out'] is False and report['held_out_cell_access_count'] == 0, 'RECOVERY_PUBLICATION')
            measured = read(directory / 'finite-task-measurement.json')
            require(measured['schema_version'] == 'sporespore_r10l_finite_task_measurement_v1'
                and measured['finite_task_predicates_passed'] is False and measured['predicates']['planned_cycles'] is False,
                'RECOVERY_FINITE_NEGATIVE')
            if label == 'active':
                require(measured['predicates']['recovery_completed'] == (branch == 'partial'), 'RECOVERY_COMPLETION')
            else:
                require(result['transition_count'] == 272, 'BASELINE_BOUNDARY')
        result = results['active']
        expected = (240, 63, 0, 0) if branch == 'partial' else (1, 0, 1, 13)
        actual = tuple(result[k] for k in ['entry_observation_count', 'partial_observation_count',
                                          'canonical_initialization_count', 'canonical_observation_count'])
        require(actual == expected, 'RECOVERY_POPULATION:' + branch)
    reader(recovery / 'partial-crossed-readiness/passive_entry_replay', 'R10H_ENTRY_REPLAY_READINESS_RECOMPUTATION')
    process = read(preparation / 'execution.json')
    require(process['exit_code'] == 0 and process['world_build_count'] == process['solver_step_count'] == 0, 'PREPARATION_PRODUCER')
    produced = read(preparation / 'fixture.json')
    require(produced['ok'] is True and produced['original_policy_validation']['ok'] is True
        and produced['synthetic_measurements_only'] is True, 'PREPARATION_FIXTURE')
    report = read(preparation / 'report/worker_report.json')
    require(report == produced['report'] and report['synthetic_test_fixture'] is True, 'PREPARATION_PUBLICATION')
    sessions = report['retained_arm']['walking_sessions']
    require(len(sessions) == len({s['session_id'] for s in sessions}) == 3
        and [len(s['step_receipt_sha256s']) for s in sessions] == [173, 171, 2], 'PREPARATION_SESSIONS')
    require(all(s['completion_receipt']['adapter_shutdown_receipt']['native_controller_session_destroy_count'] == 1
        for s in sessions), 'PREPARATION_SHUTDOWN')
    result = reader(preparation / 'report/passive_entry_replay')
    require(wrapper_matches(result, read(preparation / 'replay-result.json'), preparation / 'report/passive_entry_replay') and result['complete_report_timeline_replayed'] is True
        and result['transition_count'] == 618 and result['initial_global_semantic_step'] == 0
        and result['walking_control_replay']['replayed_walking_steps'] == 2, 'PREPARATION_REPLAY')
    require(tuple(result['stance_entry_replay'][k] for k in ['replayed_neutral_commands', 'replayed_hold_commands',
        'recomputed_readiness_samples']) == (173, 171, 344), 'PREPARATION_READINESS')
    measured = read(preparation / 'finite-task-measurement.json')
    require(measured['finite_task_predicates_passed'] is False and measured['predicates']['entry_ready'] is True
        and measured['predicates']['planned_cycles'] is False and measured['predicates']['settled_stop'] is False, 'PREPARATION_FINITE_NEGATIVE')
    for name, code in REFUSALS.items():
        reader(preparation / name / 'passive_entry_replay', code)
    result = read(route / 'result.json')
    require(result['ok'] is True and len(result['checks']) == 46 and all(result['checks'].values()), 'CURRENT_ROUTE')
    launcher = suite / 'current-route/launcher-refusal'
    require(read(launcher / 'execution.json')['exit_code'] == 1 and
        'R10L_FULL_SAFETY_AND_PUBLICATION_INTEGRATION_REQUIRED' in
        (launcher / 'stderr.log').read_text(encoding='utf-8'), 'LAUNCHER_REMAINS_CLOSED')
    if current_sources:
        import development_recovery_candidate as candidate
        selected = candidate.selection(candidate.reference_for_path(verify(record['candidate_profile'])))
        require(selected['diagnostic_schedule']['walking_policy_id'] == 'r10l_v52_partial_fall_recovery_route_v1', 'CURRENT_SELECTION')
    return dict(ok=True, tests=test_count, seed_guard_checks=29, route_checks=46,
        observed_recovery_sources=observed, current_preparation_sources=prospective,
        complete_synthetic_reports=5, preparation_transitions=618, reader_refusals=9,
        finite_tasks_positive=0, retained_files=len(retained), world_build_count=0, solver_step_count=0,
        full_safety_gate_pending=True, physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print(json.dumps(audit(args.current_sources), sort_keys=True))
