"""Reconstruct R10R route and serialized-report interface evidence, without worlds."""
import argparse
import json

from r10r_native_component import ROOT, EVIDENCE, BINDING, bind, read, write
import development_recovery_candidate as candidate
import development_passive_entry_profile as entry
import r10r_development as development
import r10r_finite_task_audit as finite

RECORD = ROOT / 'sdk/recovery/r10r_route_component_v1.json'
SOURCE = ROOT / 'sdk/recovery/r10r_v55_walking_entry_contract_v4.json'
PROFILE = ROOT / 'sdk/development/recovery_candidates/r10r-v55-upright-integrated-v3.json'
ROUTES = EVIDENCE / 'r10r-route-review-5d435d2f024b40d0acf57168513b3a5b'
REPORT = EVIDENCE / 'development-r10r-complete-report-55a98e0ddb0a4e31bc8afa2de7445c8e'
SEGMENT = EVIDENCE / 'r10r-route-review-91f486b742f8448ba25f192e8b6b8004'
REFUSALS = [EVIDENCE / name for name in [
    'r10r-route-review-a71ed63f08d84051a7b81bb3e1da3c47',
    'r10r-route-review-495cccb8bf644c9fb53b2080a8005966',
    SEGMENT.name]]


def inspect():
    source = read(SOURCE)
    for item in source['bound_source_files']:
        assert bind(ROOT / item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
    selected = candidate.selection(candidate.reference_for_path(PROFILE))
    assert selected['reader'] == 'res://sdk/trace_analysis/r10r_recovery_replay.gd'
    schedule = selected['diagnostic_schedule']
    assert candidate.walking_policy_id(schedule) == development.ROUTE
    for key in ['walking_entry_profile_id', 'walking_start_profile_id', 'walking_policy_id',
                'walking_policy_contract_sha256', 'runtime_sha256']:
        try:
            candidate.walking_policy_id(dict(schedule, **{key: 'crossed'}))
        except ValueError:
            pass
        else:
            raise AssertionError('CROSSED_SELECTION_ACCEPTED:' + key)
    for directory in [ROUTES, REPORT, SEGMENT]:
        assert (directory / 'source_before.json').read_bytes() == (directory / 'source_after.json').read_bytes()
    routes = read(ROUTES / 'routes.json')
    assert routes['ok'] is True and len(routes['checks']) == 50 and all(routes['checks'].values())
    assert read(ROUTES / 'routes.execution.json')['exit_code'] == 0
    assert (ROUTES / 'routes.stderr.log').read_bytes() == b''
    for label in ['ramp', 'hold', 'resume', 'matched']:
        value = routes['result'][label]
        assert value['start']['ok'] is True and value['ledger']['ok'] is True
        assert value['ledger']['detached_hinge_parameter_container_count'] == 8
        for key in ['world_build_count', 'scene_tree_insertion_count', 'solver_step_count']:
            assert value['ledger'][key] == 0
    segment = read(SEGMENT / 'reader.json')
    assert segment['ok'] is True and len(segment['checks']) == 21 and all(segment['checks'].values())
    assert read(SEGMENT / 'reader.execution.json')['exit_code'] == 0
    assert segment['complete_report_exercised'] is False
    assert segment['replay']['initial_global_semantic_step'] == 271
    assert segment['replay']['transition_count'] == 304
    assert segment['checks']['raise_actual_v12_owner_links'] is True
    assert segment['checks']['raise_old_v20_owner_refused'] is True
    assert segment['checks']['raise_old_q_step_source_refused'] is True

    declaration = read(REPORT / 'synthetic-declaration.json')
    population = development.validate_declaration(declaration)
    assert population['seed'] == 40946 and population['roles'] == [development.ROLES[1]]
    assert declaration['r10r_development']['stage'] == 'initial_single_diagnostic'
    assert read(REPORT / 'upright.execution.json')['exit_code'] == 0
    assert (REPORT / 'upright.stderr.log').read_bytes() == b''
    path = REPORT / 'upright-active/worker_report.json'
    report = read(path)
    assert report['synthetic_test_fixture'] is True and report['held_out_cell_access_count'] == 0
    assert report['r10r_development'] == declaration['r10r_development']
    replay = entry.consume_replay(path)
    assert replay == read(REPORT / 'upright.results.json')['active']
    assert replay['complete_report_timeline_replayed'] is True
    assert replay['initial_global_semantic_step'] == 0 and replay['transition_count'] == 575
    assert replay['entry_observation_count'] == 240 and replay['upright_observation_count'] == 63
    assert replay['partial_observation_count'] == replay['canonical_initialization_count'] == 0
    assert replay['complete_route_proven'] is False
    memory = report['r10r_upright_recovery']['final_memory']
    assert memory['phase'] == 'complete' and memory['standing_samples_observed'] == 60
    from sporespore_locomotion import LocomotionCore
    core = LocomotionCore(read(BINDING)['runtime']['path'])
    compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
    measured = finite.measure(report, compiled)
    assert measured == read(REPORT / 'upright-active/finite-task-measurement.json')
    assert measured['predicates']['recovery_completed'] is True
    assert measured['predicates']['entry_ready'] is True
    assert measured['predicates']['planned_cycles'] is False
    assert measured['finite_task_predicates_passed'] is False
    negative = REPORT / 'upright-crossed-readiness/passive_entry_replay'
    assert read(negative / 'execution.json')['returncode'] == 1
    assert (negative / 'stderr.txt').read_bytes() == b''
    lines = (negative / 'stdout.txt').read_text(encoding='utf-8').splitlines()
    rows = [json.loads(line.split(' ', 1)[1]) for line in lines
            if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
    assert len(rows) == 1 and rows[0]['failure_code'] == 'R10H_ENTRY_REPLAY_READINESS_RECOMPUTATION'
    assert rows[0]['world_build_count'] == rows[0]['solver_step_count'] == 0
    return dict(ok=True, current_interface_tests=3, current_source_key_files=len(source['bound_source_files']),
        route_checks=50, crossed_candidate_selections_refused=5,
        prior_segment_reader_checks=21, complete_synthetic_report_transitions=575,
        passive_samples=240, upright_samples=63, consecutive_synthetic_standing_samples=60,
        full_initial_single_report_publisher_and_reader_validated=True,
        readiness_tampering_refused=True, missing_walking_stays_finite_task_negative=True,
        physical_launcher_prerequisites_qualified=False, walking_startup_runtime_key_qualified=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        physical_world_count=0, solver_step_count=0, physical_acceptance_authority=False,
        release_authority=False, sdk1_score='14/20')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    observed = inspect()
    if args.create:
        write(RECORD, dict(schema_version='sporespore_r10r_route_component_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                authority_mode='synthetic_production_route_and_complete_report_interfaces', question_class='development'),
            source_contract=bind(SOURCE), candidate_profile=bind(PROFILE), runtime_binding=bind(BINDING),
            auditor=bind(__file__), observed=observed,
            retained_evidence=[bind(p) for directory in [ROUTES, REPORT, *REFUSALS]
                               for p in sorted(directory.rglob('*')) if p.is_file()],
            limitations=['Synthetic complete report contains no physical observations or walking tail.',
                'Earlier segment replay passed on v3; current route and complete report passed on v4.',
                'Launch prerequisite controls, complete safety and new-runtime startup qualification remain pending.']))
    else:
        record = read(RECORD)
        for item in [record[k] for k in ['source_contract', 'candidate_profile', 'runtime_binding', 'auditor']] + record['retained_evidence']:
            assert bind(item['path']) == item, item['path']
        assert observed == record['observed']
    print('R10R_ROUTE_COMPONENT ' + json.dumps(observed), flush=True)


if __name__ == '__main__':
    main()
