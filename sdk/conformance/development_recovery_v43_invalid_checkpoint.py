"""Close V43's original incomplete child; describe, never repair or regrade it.

The missing failed response cannot be reconstructed from the completed prefix.
Separate zero-world tests use an explicitly synthetic hold-counter boundary.
"""
import hashlib
import json
from datetime import datetime
from pathlib import Path

import development_rearward_fold_checkpoint as prior

ROOT = prior.entry.ROOT
ATTEMPT = 'b72c4d6447704de49bbc6c348c0f8ff0'
SOURCE = '1d56947c79501c5a712e7b1ff39d6603fc88719f'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + ATTEMPT)
RECORD = ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json')
ROLE = 'kick_passive_recovery_resume'
CHILD = 'df3366a765ea44afae192477fce7c332'
REPORT_SHA = 'sha256:c10bffdd83cb274a5d32b28dddb27d470d2e19a13647026cd45abeb30d5abd51'
TRANSPORT_ERROR = 'GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_SCHEMA_MISMATCH'
PROFILE = 'sdk/development/recovery_candidates/v43-support-progression-integrated-v1.json'


def require(condition, code):
    if not condition:
        raise ValueError('V43_INVALID_' + code)


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def read(path):
    return json.loads(Path(path).read_bytes())


def identity(path):
    path = Path(path)
    # Hash in chunks: physical reports and original stdout are large.
    with path.open('rb') as stream:
        sha = hashlib.file_digest(stream, 'sha256')
    return dict(path=path.as_posix(), byte_length=path.stat().st_size,
                raw_sha256='sha256:' + sha.hexdigest())


def population(root):
    files = [dict(identity(p), path=p.relative_to(root).as_posix())
             for p in sorted(root.rglob('*')) if p.is_file()]
    return dict(root=root.as_posix(), file_count=len(files),
        byte_length=sum(p['byte_length'] for p in files),
        inventory_sha256=digest(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()), files=files)


def report():
    path = EVIDENCE / 'children' / ROLE / 'worker_report.json'
    require(identity(path)['raw_sha256'] == REPORT_SHA, 'REPORT_BYTES')
    return read(path)


def summarize(value):
    """Validate the observed incomplete boundary, not a successful route."""
    require(value['ok'] is False and value['status'] == 'invalid_or_incomplete_process_isolated_child_development', 'STATUS')
    require(value['source_commit'] == SOURCE and value['parent_attempt_id'] == ATTEMPT
            and value['child_attempt_id'] == CHILD and value['seed'] == 40200, 'IDENTITY')
    require(value['failure_code'] == 'QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID'
            and value['detail']['native_step_transport_verification']['failure_code'] == TRANSPORT_ERROR, 'FAILURE')
    require(value['scientific_outcome'] == value['role_outcome'] == 'none'
            and value['behavior_evaluator_invocation_count'] == 0, 'NO_EVALUATION')
    require(value['world_build_count'] == 1 and value['solver_step_count'] == 1034
            and value['external_kick_application_count'] == 1, 'PHYSICAL_COUNTS')
    for key in ('physical_acceptance_authority', 'release_authority', 'force_aware_recovery',
                'comparative_authority', 'baseline_reused', 'world_or_body_state_imported_from_peer'):
        require(value[key] is False, 'AUTHORITY_' + key)
    require('retained_arm' not in value, 'INCOMPLETE_NOT_COMPLETE')
    arm = value['partial_arm']
    state = arm['orchestrator_state']
    require(state['phase'] == 'fresh_selected_policy_walking_resume'
            and state['walking_resume_step_count'] == 176
            and state['total_completed_solver_step_count'] == 1034
            and arm['terminal_orchestrator_transition'] == {}, 'PARTIAL_STATE')
    for key in ('solver_reset_count', 'body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count'):
        require(arm[key] == 0, 'NO_RESET_' + key)
    trace = arm['trace_rows']
    require([r['global_semantic_step'] for r in trace] == list(range(1, 1035)), 'TRACE_POPULATION')
    rows = value['development_walking_entry']['rows']
    require(len(rows) == value['development_walking_entry']['sample_count'] == 176, 'WALKING_POPULATION')
    previous = None
    held, releases = [], []
    for index, row in enumerate(rows, 1):
        require(row['session_local_step'] == index and row['commanded_global_step'] == 858 + index
                and row['measured_global_step'] == 857 + index, 'WALKING_CLOCK')
        request, output = row['request'], row['native_output']
        require(output['actuation']['safe_no_actuation'] is False, 'COMPLETED_PREFIX_ONLY')
        if previous is not None:
            require(request['memory'] == previous['next_memory'], 'MEMORY_CHAIN')
        guard = output['actuation']['receipt']['recovery_support_plane']['support_progression']
        require(guard['incoming_memory'] == request['memory']['support_progression']
                and guard['next_memory'] == output['next_memory']['support_progression']
                and guard['maximum_held_commands'] == 120 and guard['minimum_clear_dwell_steps'] == 3, 'GUARD_BINDING')
        if guard['phase_progression_held']:
            held.append(index)
        elif guard['incoming_memory']['held_steps'] > 0:
            releases.append(index)
        previous = output
    require(len(held) == 143 and releases == [47], 'GUARD_POPULATION')
    last = rows[-1]
    guard = last['native_output']['actuation']['receipt']['recovery_support_plane']['support_progression']
    require(guard['incoming_memory'] == dict(held_steps=119, clear_dwell_steps=0)
            and guard['next_memory'] == dict(held_steps=120, clear_dwell_steps=0)
            and guard['missing_support_limb_ids'] == ['rear_right'], 'LAST_GUARD')
    contacts = value['development_native_walking_contacts']
    require(contacts['sample_count'] == len(contacts['rows']) == 206
            and contacts['rows'][-1]['commanded_global_step'] == 1034, 'CONTACT_POPULATION')
    return dict(world_build_count=1, solver_step_count=1034, external_kick_application_count=1,
        standing_transition_global_step=858, resumed_walking_completed_commands=176,
        native_walking_contact_rows=206, gait_held_command_count=143,
        hold_release_local_steps=releases, first_held_local_step=held[0],
        final_retained_guard=guard, final_retained_command_global_step=1034,
        final_retained_command_raw_response_sha256=last['raw_native_response_sha256'],
        terminal_trace={k:trace[-1][k] for k in ('global_semantic_step', 'contact_by_limb',
            'torso_contact', 'torso_tilt_rad', 'torso_position_world_m')},
        original_failure=value['detail'], failed_next_command_request_retained=False,
        failed_next_command_raw_response_retained=False, original_hidden_controller_error_proven=False,
        original_evaluator_invocation_count=0, independent_complete_route_replay_performed=False)


def observe():
    supervisor = read(EVIDENCE / 'supervisor_result.json')
    declaration = read(EVIDENCE / 'declaration.json')
    require(supervisor['ok'] is False and supervisor['physical_attempt_started'] is True
        and supervisor['failure_code'] == 'SMOKE_CHILD_INVALID:' + ROLE
        and supervisor['independent_audit'] is None, 'SUPERVISOR')
    expected_source = dict(head=SOURCE, dirty=False, status=[], changed_file_bindings=[])
    require(supervisor['source_snapshot'] == declaration['source_snapshot'] == expected_source, 'CLEAN_SOURCE')
    require(declaration['attempt_id'] == ATTEMPT and declaration['seed'] == 40200
        and declaration['development_execution_mode'] == 'single_kick_controller_diagnostic_v1'
        and declaration['baseline_reused'] is False and declaration['comparative_authority'] is False, 'DECLARATION')
    require(len(supervisor['children']) == len(declaration['children']) == 1, 'SINGLE_CHILD')
    stages = supervisor['safety_stages']
    require(sum(s['test_count'] for s in stages) == 114, 'SAFETY_COUNT')
    for stage in stages:
        require(stage['passed'] is True and stage['exit_code'] == 0 and stage['timed_out'] is False
            and stage['test_count'] == stage['expected_test_count'], 'SAFETY_STAGE')
        for stream in ('stdout', 'stderr'):
            require(identity(EVIDENCE / stage[stream])['raw_sha256'] == 'sha256:' + stage[stream + '_sha256'], 'SAFETY_LOG')
    child_path = EVIDENCE / 'children' / ROLE
    child = supervisor['children'][0]
    require(child['child_attempt_id'] == CHILD and child['exit_code'] == 1
        and identity(child_path / 'child_envelope.json') == child['envelope'], 'CHILD_BINDING')
    envelope = read(child_path / 'child_envelope.json')
    require(envelope['child_attempt_id'] == CHILD and envelope['exit_code'] == 1
        and envelope['termination_protocol_valid'] is True and envelope['engine_health_passed'] is True
        and envelope['raw_marker_valid'] is True
        and envelope['child_retry_count'] == envelope['child_replacement_count'] == 0, 'CHILD_PUBLICATION')
    for binding in envelope['retained_artifact_bindings'].values():
        require(identity(binding['path']) == binding, 'CHILD_ARTIFACT')
    value = report()
    require(envelope['report'] == value, 'PUBLISHED_REPORT')
    observation = summarize(value)
    source_files = [PROFILE, 'sdk/core/src/runtime.rs', 'sdk/adapters/godot/src/lib.rs',
        'scripts/lab/gait/sdk_godot_jolt_adapter.gd',
        'sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd',
        'sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd',
        'sdk/development/recovery_support_progression_contract_v1.json']
    profile = json.loads(prior.committed(PROFILE, SOURCE))
    require(declaration['candidate_profile'] == dict(resource='res://' + PROFILE,
        raw_sha256=digest(prior.committed(PROFILE, SOURCE))), 'PROFILE')
    runtime_path = profile['runtime_binding'].removeprefix('res://')
    runtime_raw = prior.committed(runtime_path, SOURCE)
    require(digest(runtime_raw) == profile['runtime_binding_sha256'], 'RUNTIME_BINDING')
    runtime = json.loads(runtime_raw)
    require(identity(runtime['runtime']['path'])['raw_sha256'] == profile['runtime_sha256'], 'DLL')
    source_files.extend((runtime_path, profile['extension'].removeprefix('res://'),
        'sdk/development/recovery_schedules/v43-support-progression-integrated-v1.json'))
    sources = []
    for path in source_files:
        raw = prior.committed(path, SOURCE)
        sources.append(dict(path=path, source_commit=SOURCE, byte_length=len(raw), raw_sha256=digest(raw)))
    def elapsed(start, end):
        return (datetime.fromisoformat(end) - datetime.fromisoformat(start)).total_seconds()
    return dict(schema_version='sporespore_development_recovery_v43_incomplete_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='retained_development_physical_invalid', question_class='development'),
        status='closed_consumed_invalid_incomplete_physical_child', attempt_id=ATTEMPT,
        child_attempt_id=CHILD, evidence_root=EVIDENCE.as_posix(), source_snapshot=expected_source,
        candidate_profile=declaration['candidate_profile'], runtime=runtime['runtime'],
        safety_test_count=114, safety_stages=stages,
        elapsed_seconds=dict(total=elapsed(supervisor['started_utc'], supervisor['completed_utc']),
            safety_gate=sum(s['seconds'] for s in stages),
            child=elapsed(envelope['started_utc'], envelope['completed_utc'])),
        kicked_report=identity(child_path / 'worker_report.json'),
        child_envelope=child['envelope'], retained_population=population(EVIDENCE),
        frozen_sources=sources, observation=observation,
        diagnosis_limit='The last retained command reaches the hold limit and the next response is schema-rejected. Its request and raw response were not retained; a synthetic boundary reproduction cannot prove the original hidden error.',
        next_work='Reproduce safe-stop transport on an explicit test-local counter boundary; then preserve and type-check refusals prospectively before diagnosing unsupported-foot control. Do not extend the hold limit or rerun this identity.',
        original_attempt_reclassified=False, original_evaluation_replaced=False,
        complete_route_proven=False, successful_recovery_proven=False, comparative_authority=False,
        physical_acceptance_authority=False, release_authority=False, repeat_consumed_attempt_permitted=False,
        new_world_build_count=0, new_native_physics_read_count=0, new_solver_step_count=0)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
