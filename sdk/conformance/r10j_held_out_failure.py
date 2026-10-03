"""Preserve the consumed R10J failure; never regrade or authorize its population.

This post-result auditor verifies original publication and the committed graph.
It can reproduce exposed controller calls without constructing a physics world.
The caller must hold the operation lock because retained native readers and the
two refusal reproductions load the original, immutable development DLL.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess

import development_passive_entry_profile as entry
import development_recovery_refusal as refusal
import development_recovery_smoke as smoke
import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_l15_launch_relationship as launch
import r10j_campaign_authority as authority
import r10j_finite_task_audit as finite

SOURCE = 'c7f6fc51fd6c40a219082d08f4505ba3209cc5e0'
ATTEMPT = 'f87524ed3f1e47159c59a4cd9f8b1749'
KEY = 'sha256:3a18538cc07df7e5e41928e3b526d9b1a3d56b9d1bd3dc1d654c1b4b5112f466'
ROOT = authority.CLAIM_PATH.parent
CLOSURE = authority.ROOT / 'sdk/recovery/r10j_held_out_physical_closure_v1.json'
INVALID = {50641: (1343, 725, 176), 50643: (874, 283, 153)}
EXPECTED_STEPS = [1343, 512, 1713, 512, 874, 871]


def require(value, code):
    if not value:
        raise ValueError('R10J_FAILURE_CLOSURE_' + code)


def read(path):
    return packet.parse_json(Path(path).read_text(encoding='utf-8'))


def binding(path):
    path = Path(path).resolve()
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return dict(path=path.as_posix(), byte_length=path.stat().st_size,
                raw_sha256='sha256:' + digest.hexdigest())


def bound_file(item, parent=None):
    path = Path(item['path']).resolve()
    require(parent is None or path.parent == Path(parent).resolve(), 'ARTIFACT_PATH')
    observed = binding(path)
    require(observed['byte_length'] == item['byte_length'] and
            observed['raw_sha256'] == item['raw_sha256'], 'ARTIFACT_BYTES')
    return observed


def decision(cells):
    """This closure only preserves this exact failed population."""
    expected = authority.population('held_out_finite_decision')
    require([c['cell_id'] for c in cells] == [c['cell_id'] for c in expected], 'SIX_ORDERED_CELLS')
    require(all(type(c[k]) is int for c in cells for k in
                ('solver_steps', 'world_build_count', 'retry_count', 'replacement_count')), 'COUNT_DOMAIN')
    require([c['solver_steps'] for c in cells] == EXPECTED_STEPS, 'OBSERVED_STEPS')
    require([c['outcome'] for c in cells] == [
        'invalid_controller_refusal', 'valid_finite_negative', 'valid_finite_positive',
        'valid_finite_negative', 'invalid_controller_refusal', 'valid_finite_negative'], 'OBSERVED_OUTCOMES')
    require(all(c['world_build_count'] == 1 and c['retry_count'] == c['replacement_count'] == 0
                for c in cells), 'WORLD_OR_RETRY_COUNT')
    return dict(outcome='invalid', accepted=False, all_six_cells_passed=False,
                valid_positive_cells=1, valid_negative_cells=3, invalid_cells=2,
                world_build_count=6, solver_step_count=sum(EXPECTED_STEPS),
                population_consumed=True, retry_permitted=False, replacement_permitted=False,
                q_sdk_r10_satisfied=False, sdk1_m07_satisfied=False,
                physical_acceptance_authority=False, release_authority=False)


def observed_summary(report, descriptor, measurement=None):
    seed, role = report['seed'], descriptor['role']
    invalid = role == authority.ROLES[0] and seed in INVALID
    arm = report['partial_arm' if invalid else 'retained_arm']
    state = arm['orchestrator_state']
    task = report['finite_recovery_task']
    summary = dict(cell_id=descriptor['cell_id'], seed=seed, role=role,
                   child_attempt_id=descriptor['child_attempt_id'], worker_ok=report['ok'],
                   original_status=report['status'], solver_steps=report['solver_step_count'],
                   world_build_count=report['world_build_count'],
                   planned_cycles=task['planned_cycle_count'], stopping_commands=task['stopping_commands'],
                   hold_commands=state['hold_entry_step_count'],
                   walking_commands=state['matched_continuation_step_count'] if role == authority.ROLES[0]
                   else state['walking_resume_step_count'], terminal_reason=state['terminal_reason'],
                   retry_count=0, replacement_count=0)
    if invalid:
        count, walking, hold = INVALID[seed]
        require(report['ok'] is False and report['failure_code'] == 'QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID'
                and report['solver_step_count'] == count and summary['walking_commands'] == walking
                and summary['hold_commands'] == hold, 'INVALID_OBSERVATION')
        failure = report['detail']['portable_step_receipt']['development_native_step_failure']
        require(failure['classification'] == 'verified_zero_actuation_controller_refusal'
                and failure['verified_zero_actuation_refusal'] is True
                and failure['reported_native_controller_error'] == 'FRAME_INVALID:anchored_body_pose_unreachable_endpoint'
                and failure['adapter_clock_advanced'] is False and failure['adapter_memory_advanced'] is False
                and failure['motor_application_permitted'] is False, 'NATIVE_REFUSAL')
        summary.update(outcome='invalid_controller_refusal', failure_code=report['failure_code'],
                       native_controller_error=failure['reported_native_controller_error'])
    else:
        require(report['ok'] is True and measurement is not None, 'VALID_MEASUREMENT')
        positive = seed == 50642 and role == authority.ROLES[0]
        require(measurement['finite_task_predicates_passed'] is positive, 'FINITE_PREDICATES')
        if positive:
            require(task['cycle_and_stop_boundary_reached'] is True and task['planned_cycle_count'] == 4
                    and task['stopping_commands'] == 120, 'POSITIVE_TASK')
            summary.update(outcome='valid_finite_positive', forward_advance_m=
                           measurement['walking']['pre_first_to_post_last_body_forward_m'])
        else:
            reason = 'phase_timeout:stance_dwell' if seed == 50643 else 'passive_descent_timeout'
            require(role == authority.ROLES[1] and state['terminal_reason'] == reason
                    and task['cycle_and_stop_boundary_reached'] is False
                    and summary['walking_commands'] == 0, 'NEGATIVE_TASK')
            summary.update(outcome='valid_finite_negative',
                           passive_descent_commands=state['passive_descent_step_count'],
                           canonical_observation_count=len(report['passive_entry']['canonical_packets']))
            if seed == 50643:
                memory = arm['recovery_memory']
                require(memory['phase_steps_observed'] == 240 and memory['stance_dwell_steps_observed'] == 47,
                        'STANDING_DWELL')
                summary.update(final_consecutive_standing_samples=47, required_consecutive_standing_samples=60,
                               final_classification=arm['last_recovery_classification'])
        summary['finite_task_measurement'] = measurement
    return summary


def verify_step_invariants(report, arm, role):
    """A failed peer must not prevent verification of this child's own steps."""
    count = report['solver_step_count']
    rows, invariants = arm['trace_rows'], arm['invariant_receipts']
    require(len(rows) == len(invariants) == count, 'COMPLETED_STEP_POPULATION')
    body = arm['body_population_instance_sha256']
    for step, (row, invariant) in enumerate(zip(rows, invariants), 1):
        require(row['global_semantic_step'] == invariant['global_semantic_step'] == step
                and row['arm_id'] == invariant['arm_id'] == role
                and row['body_population_instance_sha256'] == invariant['body_population_instance_sha256'] == body,
                'STEP_IDENTITY')
        require(invariant['all_in_run_physical_invariants_passed'] is True
                and type(invariant['predicates']) is dict and bool(invariant['predicates'])
                and all(value is True for value in invariant['predicates'].values()), 'STEP_INVARIANT')
    for key in ('body_population_rebuild_count', 'body_transform_write_count',
                'body_velocity_write_count', 'solver_reset_count'):
        require(packet.same(arm[key], 0), 'BODY_MUTATION_' + key)
    return count


def reproduce_refusal(report, descriptor, core):
    """Reproduce the last valid command and failed command, not a physics retry."""
    failure = report['detail']['portable_step_receipt']['development_native_step_failure']
    for key in ('request', 'response'):
        raw = failure[key]['utf8_text'].encode('utf-8')
        require(len(raw) == failure[key]['utf8_byte_length'] and
                refusal.digest(raw) == failure[key]['raw_sha256'], 'REFUSAL_TRANSPORT')
    compiled = core.compile_bounded_quadruped(descriptor)
    require(core.canonicalize_json(compiled['morphology']['morphology_spec'])['sha256'] ==
            failure['compiled_morphology_spec_sha256'], 'REFUSAL_MORPHOLOGY')
    previous = report['development_walking_entry']['rows'][-1]
    request = packet.parse_json(failure['request']['utf8_text'])
    require(request['state']['semantic_step'] == previous['session_local_step'] + 1, 'REFUSAL_CLOCK')
    calls = []
    for q, expected in ((previous['request'], previous['raw_native_response_sha256']),
                        (request, failure['response']['raw_sha256'])):
        # The public C ABI includes the descriptor and integral JSON clocks.
        # Only this new request copy is normalized; all retained bytes stay exact.
        copied = refusal.integers(dict(copy.deepcopy(q), descriptor=descriptor))
        output = core.balanced_wave_policy_step_with_measured_body(failure['expected_policy_id'], copied)
        require(refusal.digest(core.raw_response) == expected, 'REFUSAL_NATIVE_BYTES')
        calls.append(dict(semantic_step=q['state']['semantic_step'], raw_response_sha256=expected,
                          safe_no_actuation=output['actuation']['safe_no_actuation']))
    require(calls[0]['safe_no_actuation'] is False and calls[1]['safe_no_actuation'] is True,
            'REFUSAL_ORDER')
    commands = output['actuation']['ordered_commands']
    require(len(commands) == 8 and all(c['target_velocity_rad_s'] == 0 for c in commands)
            and output['next_memory'] == refusal.integers(request['memory']), 'REFUSAL_SIDE_EFFECTS')
    return dict(native_calls=calls, world_build_count=0, solver_step_count=0,
                physical_attempt_retried=False, original_result_regraded=False)


def graph():
    def blob(commit, path):
        return subprocess.check_output(['git', '-C', str(authority.ROOT), 'show', f'{commit}:{path}'],
                                       cwd=authority.ROOT)
    auth = read(authority.ROOT / authority.AUTHORITY_PATH)
    result = authority.validate_graph(auth, read(authority.ROOT / authority.QUALIFICATION_PATH),
        read(authority.ROOT / authority.GHOST_PATH), head=SOURCE,
        parents=lambda commit: authority.git('show', '-s', '--format=%P', commit).split(),
        changes=lambda commit: authority.git('diff-tree', '--no-commit-id', '--name-only', '-r', commit).splitlines(),
        blob=blob)
    require(authority.git('rev-parse', f"{auth['qualification_commit']}:{authority.QUALIFICATION_PATH}") ==
            auth['qualification_closure_git_blob_oid'], 'QUALIFICATION_BLOB')
    return result


def build(closure_root):
    closure_root = Path(closure_root).resolve()
    require(closure_root.parent == authority.EVIDENCE.resolve() and
            closure_root.name.startswith('r10j-held-out-failure-closure-'), 'CLOSURE_ROOT')
    supervisor = read(ROOT / 'supervisor_result.json')
    claim = read(ROOT / 'campaign_claim.json')
    require(supervisor['ok'] is False and supervisor['independent_audit'] is None
            and supervisor['attempt_id'] == claim['attempt_id'] == ATTEMPT
            and supervisor['source_snapshot']['head'] == claim['source_commit'] == SOURCE
            and supervisor['production_route_key'] == claim['production_route_key'] == KEY
            and packet.same(supervisor['pairs'], claim['pairs']), 'ORIGINAL_FAILURE')
    marker = (ROOT / 'published_marker.txt').read_text(encoding='utf-8').splitlines()
    prefix = 'R10J_CAMPAIGN_COMPLETE '
    require(len(marker) == 1 and marker[0].startswith(prefix) and
            packet.same(packet.parse_json(marker[0][len(prefix):]), supervisor), 'SUPERVISOR_PUBLICATION')
    authority.validate_population(claim['cells'], 'held_out_finite_decision')
    require(packet.same(claim['children'], [c for p in claim['pairs'] for c in p['children']]), 'CHILD_POPULATION')
    require(len({c['child_attempt_id'] for c in claim['children']}) == 6 and
            len({c['termination_nonce'] for c in claim['children']}) == 6, 'CHILD_REUSE')
    require(packet.same(read(closure_root / 'source_after.json'), supervisor['source_snapshot']) and
            packet.same(read(closure_root / 'source_manifest_after.json'), read(ROOT / 'source_manifest.json')),
            'SOURCE_CHANGED_DURING_CAMPAIGN')
    checks_path = closure_root / 'validation-v2/component_checks.json'
    checks = read(checks_path)
    require(checks['passed'] is True and checks['source_unchanged'] is True
            and sum(s['test_count'] for s in checks['stages']) == 9
            and all(s['passed'] is True for s in checks['stages']), 'COMPONENT_CHECKS')
    committed_graph = graph()
    cells, original_roots, previous_end = [], [ROOT], None
    descriptor_source = Path(claim['pairs'][1]['children'][0]['evidence_path']) / 'worker_report.json'
    descriptor = read(descriptor_source)['configuration']['base_descriptor']
    for pair in claim['pairs']:
        pair_root = Path(pair['root']).resolve()
        require(pair_root.parent == authority.EVIDENCE.resolve() and
                pair_root.name == 'development-recovery-smoke-' + pair['attempt_id'], 'PAIR_PATH')
        original_roots.append(pair_root)
        declaration = read(pair_root / 'declaration.json')
        campaign = authority.validate_pair_declaration(declaration)
        require(packet.same(declaration['children'], pair['children']), 'DECLARED_CHILDREN')
        original_audit = read(pair_root / 'independent_audit.stdout.json')
        if campaign['seed'] == 50642:
            require(original_audit['ok'] is True, 'ORIGINAL_VALID_PAIR')
        else:
            require(original_audit == dict(ok=False, failure_code='DEVELOPMENT_SMOKE_LAUNCH_INVALID',
                    physical_acceptance_authority=False, release_authority=False), 'ORIGINAL_PAIR_REFUSAL')
        for child in pair['children']:
            path = Path(child['evidence_path']).resolve()
            require(path.parent == pair_root / 'children' and path.name == child['role'], 'CHILD_PATH')
            envelope = read(path / 'child_envelope.json')
            report = read(path / 'worker_report.json')
            for key in ('role', 'child_attempt_id', 'termination_nonce'):
                require(packet.same(envelope[key], child[key]), 'ENVELOPE_' + key)
            require(envelope['termination_protocol_valid'] is True and envelope['engine_health_passed'] is True
                    and envelope['raw_marker_valid'] is True and envelope['child_retry_count'] == 0
                    and envelope['child_replacement_count'] == 0, 'CHILD_CLOSE')
            for item in envelope['retained_artifact_bindings'].values():
                bound_file(item, path)
            originals = []
            with (path / 'worker.stdout.txt').open(encoding='utf-8') as stream:
                for line in stream:
                    if line.startswith(smoke.MARKER):
                        originals.append(line[len(smoke.MARKER):])
            require(len(originals) == 1 and packet.same(packet.parse_json(originals[0]), report)
                    and packet.same(envelope['report'], report), 'ORIGINAL_REPORT_PUBLICATION')
            del originals
            smoke.validate_campaign_retention(report, declaration, campaign)
            for key, expected in dict(source_commit=SOURCE, parent_attempt_id=pair['attempt_id'],
                child_attempt_id=child['child_attempt_id'], arm_id=child['role'], seed=campaign['seed'],
                process_id=envelope['worker_process_id'], held_out=True,
                world_build_count=1, physical_acceptance_authority=False, release_authority=False).items():
                require(packet.same(report.get(key), expected), 'REPORT_' + key)
            launch_context = dict(schema_version='sporespore_qsdk_r10f_l15_launch_context_v1',
                parent_attempt_id=pair['attempt_id'], child_attempt_id=child['child_attempt_id'], role=child['role'],
                source_commit=SOURCE, authority_sha256=binding(pair_root / 'declaration.json')['raw_sha256'],
                termination_nonce=child['termination_nonce'], ready_marker_prefix='QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY ',
                root_image=declaration['runtime']['images']['godot_console'],
                worker_image=declaration['runtime']['images']['godot_engine'])
            launch.validate_receipt(envelope['r10f_l15_launch_relationship'], expected_context=launch_context,
                root_process_id=envelope['process_id'], worker_process_id=envelope['worker_process_id'],
                started_utc=envelope['started_utc'], expected_ready_receipt=envelope['termination_ready_receipt'])
            start, end = launch.utc_ticks(envelope['started_utc']), launch.utc_ticks(envelope['completed_utc'])
            require(start <= end and (previous_end is None or previous_end <= start), 'SERIAL_EXECUTION')
            previous_end = end
            # Invalid L9 reports use the failure schema, not the successful
            # candidate-report schema. Bind the DLL through the original
            # declaration instead of pretending that the failed report passed.
            selected = entry.selection_for_declaration(declaration)
            runtime = entry.binding(selected)['runtime']
            bound_file(runtime)
            core = refusal.RecordedCore(runtime['path'])
            verified_steps = verify_step_invariants(report,
                report['partial_arm' if report['ok'] is False else 'retained_arm'], child['role'])
            if report['ok'] is False:
                require(envelope['exit_code'] == 1 and read(path / 'campaign_launch_failure.json') ==
                        dict(failure='R10J_CHILD_INVALID'), 'INVALID_LAUNCH_RESULT')
                cell = observed_summary(report, child)
                cell['post_result_native_refusal_reproduction'] = reproduce_refusal(report, descriptor, core)
            else:
                require(envelope['exit_code'] == 0 and not (path / 'campaign_launch_failure.json').exists(),
                        'VALID_LAUNCH_RESULT')
                smoke.validate_header(report, child, declaration, envelope['worker_process_id'])
                replay = entry.consume_replay(path / 'worker_report.json')
                require(packet.same(replay, read(path / 'passive_entry_replay_result.json')) and replay['ok'] is True,
                        'ORIGINAL_REPLAY')
                measured = finite.measure(report, core.compile_bounded_quadruped(descriptor))
                cell = observed_summary(report, child, measured)
                cell['original_native_replay'] = binding(path / 'passive_entry_replay_result.json')
            cell.update(report=binding(path / 'worker_report.json'), envelope=binding(path / 'child_envelope.json'),
                        started_utc=envelope['started_utc'], completed_utc=envelope['completed_utc'],
                        complete_invariant_steps_verified=verified_steps)
            cells.append(cell)
            del report, envelope, core
    result = decision(cells)
    inventory = [binding(path) for root in original_roots for path in sorted(root.rglob('*')) if path.is_file()]
    return dict(schema_version='sporespore_r10j_held_out_failure_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                          authority_mode='immutable_post_result_failure_closure', question_class='finite decision'),
        source_commit=SOURCE, campaign_attempt_id=ATTEMPT, production_route_key=KEY,
        original_supervisor=binding(ROOT / 'supervisor_result.json'),
        original_failure_code=supervisor['failure_code'], original_independent_audit=None,
        original_cell_failures=supervisor['cell_failures'], committed_graph=committed_graph,
        auditor=authority.file_binding('sdk/conformance/r10j_held_out_failure.py'),
        auditor_tests=authority.file_binding('tests/test_r10j_held_out_failure.py'),
        component_checks=binding(checks_path),
        source_after=[binding(closure_root / name) for name in
                      ('source_after.json', 'source_manifest_after.json', 'repository_after.json')],
        cells=cells, decision=result, retained_evidence=dict(file_count=len(inventory),
            byte_length=sum(v['byte_length'] for v in inventory), files=inventory),
        started_utc=supervisor['started_utc'], completed_utc=supervisor['completed_utc'],
        audit_world_build_count=0, audit_solver_step_count=0, original_outcome_regraded=False,
        production_route_recommissioned=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('closure_root', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(dict(ok=True, result=build(args.closure_root)), allow_nan=False))
    except (ValueError, KeyError, TypeError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), physical_acceptance_authority=False,
                              release_authority=False)))
        raise SystemExit(1)
