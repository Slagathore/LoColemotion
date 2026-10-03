"""Independent R10W production pair reader; preserves original physical checks.

Distinct from the frozen development reader because R10W owns new campaign
metadata and worker identity while preserving the R10V measurement laws.
"""
import argparse
import json
from pathlib import Path
import re

from development_recovery_smoke import (packet, context, launch, legacy, step_profile,
    entry_profile, MARKER, ROLES, SCHEMA, WORK, require, read, sha, integer, declared_roles)
import r10w_campaign_authority as authority
import r10w_campaign_profile as profile
import r10w_finite_task_audit as finite_task


def validate_header(report, descriptor, declaration, worker_pid):
    schedule = profile.validate_declaration(declaration)
    entry = True
    entry_worker = profile.selection(declaration['candidate_profile'])['worker_selection']
    campaign = authority.validate_pair_declaration(declaration)
    profile.validate_campaign_retention(report, declaration, campaign)
    profile.validate_prefix_retention(report, campaign)
    if 'candidate_profile' in declaration:
        for key in ('candidate_profile', 'development_execution_mode', 'comparative_authority', 'baseline_reused'):
            require(packet.same(report.get(key), declaration.get(key)), 'CANDIDATE_HEADER_' + key)
    require(type(report) is dict and report.get('schema_version') == (entry_worker['report_schema'] if entry else SCHEMA), 'CHILD_SCHEMA')
    require(not entry or 'synthetic_test_fixture' not in report, 'SYNTHETIC_REPORT_NOT_PHYSICAL')
    for key, expected in {
        'work_id': entry_worker['work_id'] if entry else WORK, 'source_commit': declaration['source_snapshot']['head'],
        'parent_attempt_id': declaration['attempt_id'], 'child_attempt_id': descriptor['child_attempt_id'],
        'arm_id': descriptor['role'], 'process_id': worker_pid, 'seed': campaign['seed'],
        'maximum_solver_step_count': schedule['maximum_steps_per_child'], 'model_construction_attempt_count': 1,
        'model_construction_count': 1, 'world_attempt_count': 1, 'world_build_count': 1,
        'complete_route_proven': False, 'held_out': campaign['held_out'] if campaign else False, 'physical_acceptance_authority': False,
        'release_authority': False, 'behavioral_conclusion': 'none',
        'telemetry_profile': 'unchanged_full_per_step_capture',
    }.items():
        require(packet.same(report.get(key), expected), 'HEADER_' + key)
    require(report.get('ok') is True, 'WORKER_INVALID:' + str(report.get('failure_code')))
    require(integer(report.get('solver_step_count'), 1, schedule['maximum_steps_per_child']), 'STEP_BOUND')
    require(packet.same(report.get('global_solver_frame_count'), report['solver_step_count']), 'FRAME_COUNT')
    require(integer(report.get('after_interaction_step_count'), 0, schedule['after_interaction_steps']), 'AFTER_BOUND')
    require(type(report.get('coverage_complete')) is bool, 'COVERAGE_KIND')
    expected_status = 'development_smoke_complete' if report['coverage_complete'] else 'development_smoke_coverage_incomplete'
    require(report.get('status') == expected_status, 'STATUS')
    scope = campaign['ledger_scope'] if campaign else dict(subsystem='recovery', engine_scope='godot_jolt',
        authority_mode='unofficial_physical_smoke', question_class='development')
    require(packet.same(report.get('ledger_scope'), scope), 'SCOPE')


def audit(root, *, selected_role=None):
    root = root.resolve()
    evidence = Path(__file__).resolve().parents[3] / 'SporeSpore_Evidence'
    require(root.parent == evidence and re.fullmatch(r'development-recovery-smoke-[0-9a-f]{32}', root.name), 'ROOT')
    declaration = read(root / 'declaration.json')
    import r10w_durable_host_v1 as host
    host.declaration_context(declaration, live=False)
    roles = declared_roles(declaration)
    require(selected_role is None or selected_role in roles, 'SELECTED_ROLE')
    checked_roles = roles if selected_role is None else [selected_role]
    schedule = profile.validate_declaration(declaration)
    entry = entry_profile.selected(declaration)
    entry_worker = profile.selection(declaration['candidate_profile'])['worker_selection']
    context_cache_expected = step_profile.declared_context_cache(declaration,
        expected_worker=entry_worker['worker'] if entry else step_profile.CACHE_WORKER_RESOURCE)
    require(declaration['physical_acceptance_authority'] is False and declaration['release_authority'] is False, 'DECLARATION_AUTHORITY')
    summaries = []
    development_cells = []
    previous_completed = None
    seen = set()
    for descriptor in declaration['children']:
        if descriptor['role'] not in checked_roles:
            continue
        child = Path(descriptor['evidence_path']).resolve()
        require(child.parent == root / 'children' and child.name == descriptor['role'], 'CHILD_PATH')
        envelope = read(child / 'child_envelope.json')
        for key in ('role', 'child_attempt_id', 'termination_nonce'):
            require(packet.same(envelope[key], descriptor[key]), 'ENCLOSING_' + key)
        require(envelope['exit_code'] == 0 and envelope['termination_protocol_valid'] is True
                and envelope['engine_health_passed'] is True and envelope['raw_marker_valid'] is True, 'LAUNCH_INVALID')
        require(envelope['child_retry_count'] == 0 and envelope['child_replacement_count'] == 0, 'RETRY')
        for item in envelope['retained_artifact_bindings'].values():
            require(type(item) is dict, 'MISSING_RETAINED_FILE')
            path = Path(item['path']).resolve()
            require(path.parent == child and path.is_file(), 'RETAINED_PATH')
            require(path.stat().st_size == item['byte_length'] and sha(path) == item['raw_sha256'], 'RETAINED_BYTES')
        original = [line[len(MARKER):] for line in (child / 'worker.stdout.txt').read_text(encoding='utf-8').splitlines()
                    if line.startswith(MARKER)]
        require(len(original) == 1, 'RAW_MARKER')
        report = packet.parse_json(original[0])
        require(packet.same(report, read(child / 'worker_report.json')) and packet.same(report, envelope['report']), 'EXACT_RAW_BINDING')
        validate_header(report, descriptor, declaration, envelope['worker_process_id'])
        profile_lines = [line[len(step_profile.MARKER):] for line in
                         (child / 'worker.stdout.txt').read_text(encoding='utf-8').splitlines()
                         if line.startswith(step_profile.MARKER)]
        cost_profile = None
        if declaration.get('step_cost_profile_id') is not None:
            require(declaration['step_cost_profile_id'] == step_profile.PROFILE_ID and len(profile_lines) == 1,
                    'STEP_PROFILE_REQUIRED')
            cost_profile = step_profile.validate_profile(packet.parse_json(profile_lines[0]), report, original[0],
                                                    context_cache_expected=context_cache_expected)
        else:
            require(not profile_lines, 'UNDECLARED_STEP_PROFILE')
        require(report['diagnostic_declaration_sha256'] == sha(root / 'declaration.json'), 'DECLARATION_BINDING')
        expected_launch = dict(schema_version='sporespore_qsdk_r10f_l15_launch_context_v1',
            parent_attempt_id=declaration['attempt_id'], child_attempt_id=descriptor['child_attempt_id'],
            role=descriptor['role'], source_commit=declaration['source_snapshot']['head'],
            authority_sha256=sha(root / 'declaration.json'), termination_nonce=descriptor['termination_nonce'],
            ready_marker_prefix='QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY ',
            root_image=declaration['runtime']['images']['godot_console'],
            worker_image=declaration['runtime']['images']['godot_engine'])
        launch.validate_receipt(envelope['r10f_l15_launch_relationship'], expected_context=expected_launch,
            root_process_id=envelope['process_id'], worker_process_id=envelope['worker_process_id'],
            started_utc=envelope['started_utc'], expected_ready_receipt=envelope['termination_ready_receipt'])
        started = launch.utc_ticks(envelope['started_utc'])
        completed = launch.utc_ticks(envelope['completed_utc'])
        require(started <= completed and (previous_completed is None or previous_completed <= started), 'OVERLAP')
        previous_completed = completed
        require(descriptor['child_attempt_id'] not in seen and descriptor['termination_nonce'] not in seen, 'REUSED_ID')
        seen.update((descriptor['child_attempt_id'], descriptor['termination_nonce']))
        expectation = declaration['prepared_context_expectation']
        context.validate_worker_comparison(report['l15_prepared_context_comparison'],
            expected_raw_binding=expectation['raw_capture_binding'], expected_identity=expectation['collection_identity'],
            canonical_sha256=legacy.canonical_sha256_v1)
        arm = report['retained_arm']
        count = report['solver_step_count']
        rows, invariants = arm['trace_rows'], arm['invariant_receipts']
        require(len(rows) == len(invariants) == count, 'COMPLETE_STEP_POPULATION')
        body = arm['body_population_instance_sha256']
        require(report['terminal_same_body_identity_receipt']['body_population_instance_sha256'] == body, 'BODY_IDENTITY')
        for step, (row, invariant) in enumerate(zip(rows, invariants), 1):
            require(row['global_semantic_step'] == invariant['global_semantic_step'] == step, 'STEP_SEQUENCE')
            require(row['arm_id'] == invariant['arm_id'] == descriptor['role'], 'ROW_ROLE')
            require(invariant['body_population_instance_sha256'] == body, 'STEP_BODY_IDENTITY')
            require(invariant['all_in_run_physical_invariants_passed'] is True
                    and type(invariant['predicates']) is dict and invariant['predicates']
                    and all(value is True for value in invariant['predicates'].values()), 'STEP_INVARIANT')
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            require(packet.same(arm[key], 0), 'BODY_MUTATION_' + key)
        require(arm['active_walking_session'] == {} and arm['last_walking_evaluation_failure'] == {}, 'UNCLOSED_WALKING')
        for session in arm['walking_sessions']:
            evaluation = session['evaluation']
            require(evaluation['schema_version'] == 'sporespore_development_smoke_walking_diagnostics_v1'
                    and evaluation['ok'] is True and evaluation['development_smoke_only'] is True
                    and evaluation['behavioral_conclusion'] == 'none', 'WALKING_DIAGNOSTIC')
            require(session['completion_receipt']['adapter_shutdown_receipt']['explicit_shutdown_completed'] is True, 'SHUTDOWN')
        state = arm['orchestrator_state']
        covered = (state['walking_prefix_step_count'] == 30 and state['interaction_effect_step_count'] == 1
                   and report['after_interaction_step_count'] == schedule['after_interaction_steps']
                   and report['external_kick_application_count'] == (1 if descriptor['role'] == ROLES[1] else 0))
        require(report['coverage_complete'] is covered, 'COVERAGE')
        summaries.append(dict(role=descriptor['role'], coverage_complete=covered, solver_steps=count,
            extra_native_reads=report['explicit_worker_extra_native_readback_count'], stop_reason=report['stop_reason'],
            final_phase=state['phase'], child_envelope_sha256=sha(child / 'child_envelope.json')))
        if cost_profile is not None:
            summaries[-1]['step_cost_profile'] = cost_profile
        if entry:
            replay = entry_profile.consume_replay(child / 'worker_report.json')
            require(packet.same(replay, read(child / 'passive_entry_replay_result.json')), 'ENTRY_REPLAY_PUBLICATION')
            summaries[-1]['passive_entry_replay'] = replay
            import sys
            sys.path.insert(0, str(authority.ROOT / 'sdk/python'))
            from sporespore_locomotion import LocomotionCore
            chosen = entry_profile.selection_for_report(report)
            core = LocomotionCore(entry_profile.binding(chosen)['runtime']['path'])
            compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
            measured = finite_task.measure(report, compiled)
            development_cells.append(dict(role=descriptor['role'], child_attempt_id=descriptor['child_attempt_id'],
                seed=report['seed'], entry_kind=state['r10v_entry_kind'],
                post_recovery_handoff=measured['entry']['post_recovery']['handoff'], execution_valid=True,
                finite_task_predicates_passed=measured['finite_task_predicates_passed'],
                measurement=measured, solver_steps=count, world_build_count=report['world_build_count'],
                original_report_sha256=sha(child / 'worker_report.json'),
                envelope_sha256=sha(child / 'child_envelope.json')))
    require([row['role'] for row in summaries] == checked_roles, 'PAIR_POPULATION')
    result = dict(schema_version='sporespore_r10w_campaign_pair_audit_v1' if selected_role is None else 'sporespore_r10w_campaign_single_cell_audit_v1', ok=True,
        coverage_complete=all(row['coverage_complete'] for row in summaries), children=summaries,
        total_solver_steps=sum(row['solver_steps'] for row in summaries),
        complete_route_proven=False, behavioral_conclusion='none', physical_acceptance_authority=False, release_authority=False)
    result['finite_cells'] = development_cells
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(audit(args.root), allow_nan=False))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error))))
        raise SystemExit(1)
