"""Distinct development profile and retained cold-reader process boundary.

Only --run starts a read-only Godot replay process. It never starts a physical
worker. Every execution creates a new directory beside the original report;
subsequent audits only read its original stdout, stderr and process receipt.
An explicit post-exposure directory retains a separate diagnostic execution;
it never changes the original attempt's replay, classification or authority.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

import qsdk_r10f_l14_runtime_binding as runtime
import qsdk_r10f_l15_collection_retention as packet
import development_step_cost_profile as profile
import development_recovery_candidate as candidate_profile
import r10ac_replay_host
import r10ap_replay_host
import r10am_replay_host
import r10aj_replay_host
import r10ai_replay_host
import r10ag_replay_host
import r10af_replay_host
import r10ae_replay_host
import r10ad_replay_host

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
WORKER = 'res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd'
READER = 'res://sdk/trace_analysis/development_passive_entry_replay.gd'
SCHEMA = 'sporespore_development_measured_prone_smoke_child_v1'
DECLARATION = 'sporespore_development_measured_prone_smoke_declaration_v1'
WORK = 'SDK1-GODOT-MEASURED-PRONE-ENTRY-SMOKE-V1'
SCHEDULE = 'measured_prone_entry_then_canonical_recovery_v1'
MARKER = 'DEVELOPMENT_PASSIVE_ENTRY_REPLAY '
REPLAY_TIMEOUT_SECONDS = 900
CHILD_TIMEOUT_SECONDS = 1500
LIMITS = dict(maximum_precondition_steps=320, walking_prefix_steps=30, interaction_steps=1,
              maximum_passive_descent_steps=240, after_interaction_steps=480, maximum_steps_per_child=832)


def require(ok, code):
    if not ok:
        raise ValueError('DEVELOPMENT_PASSIVE_PROFILE_' + code)


def read(path):
    return packet.parse_json(path.read_text(encoding='utf-8'))


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def rearward_profile():
    return read(ROOT / 'sdk/development_rearward_fold_profile_v1.json')


def rate_limited_profile():
    return read(ROOT / 'sdk/development_rate_limited_recovery_profile_v1.json')


def selection(schedule=SCHEDULE, reference=None):
    if schedule == candidate_profile.contract()['worker_selection']['schedule']:
        return candidate_profile.selection(reference)
    for candidate in (rearward_profile(), rate_limited_profile()):
        if schedule == candidate['worker_selection']['schedule']:
            return candidate
    require(schedule == SCHEDULE, 'SCHEDULE_UNKNOWN')
    return dict(worker_selection=dict(worker=WORKER, report_schema=SCHEMA, declaration_schema=DECLARATION,
        work_id=WORK, schedule=SCHEDULE, binding='res://sdk/development_passive_entry_runtime_binding_v1.json'),
        reader=READER, replay_marker=MARKER,
        replay_receipt_schema='sporespore_development_passive_entry_replay_receipt_v1')


def selection_for_report(report):
    if report.get('schema_version') == candidate_profile.contract()['worker_selection']['report_schema']:
        return candidate_profile.selection(report.get('candidate_profile'))
    for candidate in (selection(), rearward_profile(), rate_limited_profile()):
        worker = candidate['worker_selection']
        if report.get('schema_version') == worker['report_schema'] and report.get('work_id') == worker['work_id']:
            return candidate
    require(False, 'REPORT_SCHEMA')


def binding(selected_profile=None):
    chosen = selection() if selected_profile is None else selected_profile
    return read(ROOT / chosen['worker_selection']['binding'].removeprefix('res://'))


def selected(declaration):
    return declaration.get('diagnostic_schedule_id') in (SCHEDULE,
        rearward_profile()['worker_selection']['schedule'], rate_limited_profile()['worker_selection']['schedule'],
        candidate_profile.contract()['worker_selection']['schedule'])


def selection_for_declaration(declaration):
    return selection(declaration.get('diagnostic_schedule_id'), declaration.get('candidate_profile'))


def validate_declaration(declaration):
    chosen = selection_for_declaration(declaration)
    if 'candidate_profile' in chosen:
        candidate_profile.declared_roles(declaration)
    worker = chosen['worker_selection']
    bounds = candidate_profile.limits(chosen) if 'candidate_profile' in chosen else LIMITS
    child_timeout = CHILD_TIMEOUT_SECONDS
    replay_timeout = REPLAY_TIMEOUT_SECONDS
    if r10ap_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10ap_replay_host.deadlines(chosen, declaration)
    if r10am_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10am_replay_host.deadlines(chosen, declaration)
    elif r10aj_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10aj_replay_host.deadlines(chosen, declaration)
    elif r10ai_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10ai_replay_host.deadlines(chosen, declaration)
    elif r10ag_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10ag_replay_host.deadlines(chosen, declaration)
    elif r10af_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10af_replay_host.deadlines(chosen, declaration)
    elif r10ae_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10ae_replay_host.deadlines(chosen, declaration)
    elif r10ad_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10ad_replay_host.deadlines(chosen, declaration)
    elif r10ac_replay_host.selected(chosen):
        child_timeout, replay_timeout = r10ac_replay_host.deadlines(chosen, declaration)
    elif ('r10ab_development' in declaration or
            chosen.get('diagnostic_schedule', {}).get('walking_policy_id') == 'r10ab_partial_downward_rise_route_v1'):
        import r10ab_host_deadline
        child_timeout = r10ab_host_deadline.timeout_seconds(chosen, declaration)
    if ('r10aa_development' in declaration or
            chosen.get('diagnostic_schedule', {}).get('walking_policy_id') == 'r10aa_partial_load_seeking_route_v1'):
        import r10aa_host_deadline
        child_timeout = r10aa_host_deadline.timeout_seconds(chosen, declaration)
    if ('r10z_development' in declaration or
            chosen.get('diagnostic_schedule', {}).get('walking_policy_id') == 'r10z_partial_pose_geometry_route_v1'):
        import r10z_host_deadline
        child_timeout = r10z_host_deadline.timeout_seconds(chosen, declaration)
    if ('r10y_development' in declaration or
            chosen.get('diagnostic_schedule', {}).get('walking_policy_id') == 'r10y_partial_direct_neutral_route_v1'):
        import r10y_host_deadline
        child_timeout = r10y_host_deadline.timeout_seconds(chosen, declaration)
    elif ('r10v_development' in declaration or
            chosen.get('diagnostic_schedule', {}).get('walking_policy_id') == 'r10v_v56_post_recovery_hold_route_v1'):
        import r10v_host_deadline
        child_timeout = r10v_host_deadline.timeout_seconds(chosen, declaration)
    elif ('r10u_development' in declaration or
            chosen.get('diagnostic_schedule', {}).get('walking_policy_id') == 'r10u_v56_post_recovery_hold_route_v1'):
        import r10u_host_deadline
        child_timeout = r10u_host_deadline.timeout_seconds(chosen, declaration)
    expected = dict(bounds, schema_version=worker['declaration_schema'], diagnostic_schedule_id=worker['schedule'],
                    worker_resource=worker['worker'], passive_entry_runtime=binding(chosen)['runtime'],
                    timeout_seconds_per_child=child_timeout,
                    independent_replay_timeout_seconds=replay_timeout,
                    official_qualification=False, physical_acceptance_authority=False, release_authority=False)
    for key, value in expected.items():
        require(packet.same(declaration.get(key), value), 'DECLARATION_' + key)
    require(profile.declared_context_cache(declaration, expected_worker=worker['worker']), 'CACHE_REQUIRED')
    return dict(bounds)


def _paths(report_path, diagnostic_directory=None):
    report_path = report_path.resolve()
    require(report_path.is_relative_to(EVIDENCE) and report_path.name == 'worker_report.json', 'REPORT_PATH')
    if diagnostic_directory is None:
        return report_path, report_path.parent / 'passive_entry_replay'
    directory = diagnostic_directory.resolve()
    require(directory.parent == EVIDENCE and re.fullmatch(
        r'development-passive-entry-post-exposure-replay-[0-9a-f]{32}', directory.name) is not None,
        'DIAGNOSTIC_DIRECTORY')
    require((report_path.parent / 'passive_entry_replay/execution.json').is_file(), 'ORIGINAL_REPLAY_MISSING')
    return report_path, directory


def _source_snapshot():
    """Commit plus exact replacement bytes preserves an owned dirty snapshot."""
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=ROOT, creationflags=subprocess.CREATE_NO_WINDOW)
    require(Path(git('rev-parse', '--show-toplevel').decode().strip()).resolve() == ROOT, 'SOURCE_ROOT')
    remote = git('remote', 'get-url', 'origin').decode().strip()
    require(remote == 'https://github.com/Slagathore/LoColemotion.git', 'SOURCE_REMOTE')
    paths = set(git('diff', '--name-only', 'HEAD', '-z').decode().split('\0'))
    paths.update(git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0'))
    replacements = []
    for name in sorted(paths - {''}):
        path = (ROOT / name).resolve()
        require(path.is_relative_to(ROOT), 'SOURCE_PATH_ESCAPE')
        raw = path.read_bytes() if path.is_file() else None
        replacements.append(dict(path=name, deleted=raw is None,
            raw_sha256=None if raw is None else digest(raw),
            replacement_base64=None if raw is None else base64.b64encode(raw).decode('ascii')))
    return dict(head=git('rev-parse', 'HEAD').decode().strip(), remote=remote,
                status=git('status', '--porcelain=v1', '-z').decode(), changed_files=replacements)


def _original_replay_bindings(report_path):
    directory = report_path.parent / 'passive_entry_replay'
    return [runtime.file_identity(directory / name) for name in ('execution.json', 'stdout.txt', 'stderr.txt')]


def _replay_host(report_path, chosen, report=None):
    if r10ap_replay_host.selected(chosen):
        return r10ap_replay_host.plan(report_path, chosen, report)
    if r10am_replay_host.selected(chosen):
        return r10am_replay_host.plan(report_path, chosen, report)
    if r10aj_replay_host.selected(chosen):
        return r10aj_replay_host.plan(report_path, chosen, report)
    if r10ai_replay_host.selected(chosen):
        return r10ai_replay_host.plan(report_path, chosen, report)
    if r10ag_replay_host.selected(chosen):
        return r10ag_replay_host.plan(report_path, chosen, report)
    if r10af_replay_host.selected(chosen):
        return r10af_replay_host.plan(report_path, chosen, report)
    if r10ae_replay_host.selected(chosen):
        return r10ae_replay_host.plan(report_path, chosen, report)
    if r10ad_replay_host.selected(chosen):
        return r10ad_replay_host.plan(report_path, chosen, report)
    if r10ac_replay_host.selected(chosen):
        return r10ac_replay_host.plan(report_path, chosen, report)
    require(not chosen.get('diagnostic_reader_requires_declaration'), 'UNKNOWN_DECLARATION_READER')
    return dict(engine_image=runtime.IMAGES['godot_engine'], timeout_seconds=REPLAY_TIMEOUT_SECONDS)


def _command(report_path, selected_profile=None, host=None):
    chosen = selection() if selected_profile is None else selected_profile
    host = _replay_host(report_path, chosen) if host is None else host
    command = [host['engine_image']['path'], '--headless', '--path', str(ROOT),
               '--script', chosen['reader'], '--', str(report_path)]
    if 'candidate_profile' in chosen:
        command.extend([chosen['candidate_profile']['resource'], chosen['candidate_profile']['raw_sha256']])
    if 'declaration_path' in host:
        command.append(host['declaration_path'])
    return command


def _transition_reader_selection(chosen, profile_id, diagnostic_directory):
    require(type(profile_id) is str, 'MEMORY_TRANSITION_PROFILE_KIND')
    if not profile_id:
        return chosen
    require(diagnostic_directory is not None, 'MEMORY_TRANSITION_REQUIRES_SEPARATE_DIAGNOSTIC')
    contract = read(ROOT / 'sdk/development/recovery_walking_memory_transition_contract_v1.json')
    require(profile_id == contract['profile_id']
            and chosen.get('diagnostic_schedule', {}).get('walking_entry_profile_id') == contract['walking_entry_profile_id'],
            'MEMORY_TRANSITION_SELECTION')
    require(candidate_profile.sha(ROOT / contract['adapter_resource'].removeprefix('res://')) == contract['adapter_raw_sha256'],
            'MEMORY_TRANSITION_ADAPTER_DRIFT')
    return dict(chosen, reader=contract['reader'], replay_marker=contract['replay_marker'])


def _effective_memory_transition_profile(chosen, explicit_profile):
    prospective = candidate_profile.walking_memory_transition_id(chosen.get('diagnostic_schedule', {}))
    require(not (prospective and explicit_profile), 'MEMORY_TRANSITION_AUTHORITY_CROSSED')
    return prospective or explicit_profile


def consume_replay(report_path, *, diagnostic_directory=None, memory_transition_profile=''):
    """Reconcile the retained subprocess receipt and the unchanged report bytes."""
    report_path, directory = _paths(report_path, diagnostic_directory)
    report_raw = report_path.read_bytes()
    report = packet.parse_json(report_raw.decode('utf-8'))
    chosen = _transition_reader_selection(selection_for_report(report), memory_transition_profile, diagnostic_directory)
    memory_transition_profile = _effective_memory_transition_profile(chosen, memory_transition_profile)
    execution = read(directory / 'execution.json')
    require(execution.get('memory_transition_profile_id', '') == memory_transition_profile, 'MEMORY_TRANSITION_EXECUTION_SELECTION')
    require(execution.get('schema_version') == 'sporespore_development_passive_replay_process_v1', 'PROCESS_SCHEMA')
    if diagnostic_directory is not None:
        require(execution.get('original_attempt_reclassified') is False and
                execution.get('source_unchanged_during_replay') is True and
                execution.get('ledger_scope', {}).get('authority_mode') == 'post_exposure_retained_data_replay',
                'DIAGNOSTIC_AUTHORITY_OR_SOURCE')
        require(packet.same(execution.get('source_snapshot_binding'),
                            runtime.file_identity(directory / 'source_snapshot.json')), 'DIAGNOSTIC_SOURCE_BINDING')
        require(packet.same(execution.get('original_replay_bindings'), _original_replay_bindings(report_path)),
                'ORIGINAL_REPLAY_CHANGED')
    require(execution.get('returncode') == 0 and execution.get('timed_out') is False, 'PROCESS_FAILED')
    host = _replay_host(report_path, chosen, report)
    require(packet.same(execution.get('command'), _command(report_path, chosen, host)), 'PROCESS_COMMAND')
    require(packet.same(execution.get('engine_image'), host['engine_image']), 'PROCESS_ENGINE')
    if 'declaration_binding' in host:
        require(packet.same(execution.get('declaration_binding'), host['declaration_binding']), 'PROCESS_DECLARATION')
    require(packet.same(execution.get('input_raw_sha256'), digest(report_raw)), 'PROCESS_INPUT')
    require(packet.same(execution.get('timeout_seconds'), host['timeout_seconds']), 'PROCESS_BOUND')
    output = {}
    for name in ('stdout', 'stderr'):
        raw = (directory / (name + '.txt')).read_bytes()
        require(packet.same(execution.get(name + '_binding'),
                            dict(byte_length=len(raw), raw_sha256=digest(raw))), 'PROCESS_' + name)
        output[name] = raw.decode('utf-8')
    require('ERROR:' not in output['stdout'] + output['stderr'], 'SCRIPT_ERROR')
    if 'declaration_binding' in host:
        require(output['stderr'] == '', 'R10AP_REPLAY_STDERR' if r10ap_replay_host.selected(chosen) else 'R10AM_REPLAY_STDERR' if r10am_replay_host.selected(chosen) else 'R10AJ_REPLAY_STDERR' if r10aj_replay_host.selected(chosen) else 'R10AI_REPLAY_STDERR' if r10ai_replay_host.selected(chosen) else 'R10AG_REPLAY_STDERR' if r10ag_replay_host.selected(chosen) else 'R10AF_REPLAY_STDERR' if r10af_replay_host.selected(chosen) else 'R10AE_REPLAY_STDERR' if r10ae_replay_host.selected(chosen) else 'R10AD_REPLAY_STDERR' if r10ad_replay_host.selected(chosen) else 'R10AC_REPLAY_STDERR')
    marker = chosen['replay_marker']
    rows = [packet.parse_json(line[len(marker):]) for line in output['stdout'].splitlines()
            if line.startswith(marker)]
    require(len(rows) == 1, 'MARKER_COUNT')
    result = rows[0]
    expected = dict(schema_version=chosen['replay_receipt_schema'], ok=True,
                    complete_report_timeline_replayed=True, initial_global_semantic_step=0,
                    transition_count=report['solver_step_count'], final_global_semantic_step=report['solver_step_count'],
                    final_state_sha256=report['retained_arm']['orchestrator_state']['payload_sha256'],
                    input_raw_sha256=digest(report_raw), runtime_raw_sha256=binding(chosen)['runtime']['raw_sha256'],
                    process_id=execution['process_id'], world_build_count=0, native_physics_read_count=0,
                    solver_step_count=0, complete_route_proven=False, physical_acceptance_authority=False, release_authority=False)
    for key, value in expected.items():
        require(packet.same(result.get(key), value), 'REPLAY_' + key)
    require(type(execution['process_id']) is int and execution['process_id'] > 0, 'PROCESS_ID')
    require('cases' not in result and 'synthetic_test_batch' not in result, 'TEST_BATCH_NOT_REPORT')
    if 'declaration_path' in host:
        replay_host = r10ap_replay_host if r10ap_replay_host.selected(chosen) else r10am_replay_host if r10am_replay_host.selected(chosen) else r10aj_replay_host if r10aj_replay_host.selected(chosen) else r10ai_replay_host if r10ai_replay_host.selected(chosen) else r10ag_replay_host if r10ag_replay_host.selected(chosen) else r10af_replay_host if r10af_replay_host.selected(chosen) else r10ae_replay_host if r10ae_replay_host.selected(chosen) else r10ad_replay_host if r10ad_replay_host.selected(chosen) else r10ac_replay_host
        replay_host.independent_result(report, host['declaration_path'], result)
    if memory_transition_profile:
        walking = result.get('walking_control_replay', {})
        require(walking.get('memory_transition_profile_id') == memory_transition_profile, 'MEMORY_TRANSITION_REPLAY_SELECTION')
        rows = report['development_walking_entry']['rows']
        count = sum(a['request']['command']['phase_progression_mode'] != b['request']['command']['phase_progression_mode']
                    for a, b in zip(rows, rows[1:]))
        require(walking.get('adapter_mode_transition_count') == count, 'MEMORY_TRANSITION_REPLAY_COUNT')
    from development_recovery_candidate import walking_start_id, walking_policy_id, FINITE_ROUTE_ID, STANCE_ROUTE_ID, FLEXED_ROUTE_ID, HOLD_ROUTE_ID, R10K_ROUTE_ID, R10L_ROUTE_ID, R10M_ROUTE_ID, R10N_ROUTE_ID, R10O_ROUTE_ID, R10Q_ROUTE_ID, R10R_ROUTE_ID, R10S_ROUTE_ID, R10T_ROUTE_ID
    from development_recovery_candidate import R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID
    from r10ab_development import ROUTE as R10AB_ROUTE_ID
    from r10aa_development import ROUTE as R10AA_ROUTE_ID
    from r10z_development import ROUTE as R10Z_ROUTE_ID
    from r10y_development import ROUTE as R10Y_ROUTE_ID
    from r10v_development import ROUTE as R10V_ROUTE_ID
    from r10u_development import ROUTE as R10U_ROUTE_ID
    selected_policy = walking_policy_id(chosen.get("diagnostic_schedule", {}))
    post_segments = ("walking_resume", "matched_continuation") if selected_policy in (FINITE_ROUTE_ID, STANCE_ROUTE_ID, FLEXED_ROUTE_ID, HOLD_ROUTE_ID, R10K_ROUTE_ID, R10L_ROUTE_ID, R10M_ROUTE_ID, R10N_ROUTE_ID, R10O_ROUTE_ID, R10Q_ROUTE_ID, R10R_ROUTE_ID, R10S_ROUTE_ID, R10T_ROUTE_ID, R10U_ROUTE_ID, R10V_ROUTE_ID, R10Y_ROUTE_ID, R10Z_ROUTE_ID, R10AA_ROUTE_ID, R10AB_ROUTE_ID, R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID) else ("walking_resume",)
    start_id = walking_start_id(chosen.get('diagnostic_schedule', {}))
    if start_id:
        start = result.get('walking_start_validation', {})
        count = sum(s.get('evaluation_segment_id') in post_segments for s in report['retained_arm'].get('walking_sessions', []))
        require(start.get('ok') is True and start.get('profile_id') == start_id
                and packet.same(start.get('validated_resume_sessions'), count), 'WALKING_START_REPLAY_SELECTION')
    policy_id = walking_policy_id(chosen.get('diagnostic_schedule', {}))
    if policy_id:
        policy = result.get('walking_policy_validation', {})
        count = sum(s.get('evaluation_segment_id') in post_segments for s in report['retained_arm'].get('walking_sessions', []))
        require(policy.get('ok') is True and policy.get('policy_id') == policy_id
                and packet.same(policy.get('validated_resume_sessions'), count), 'WALKING_POLICY_REPLAY_SELECTION')
    result = dict(result, process_receipt_sha256=digest((directory / 'execution.json').read_bytes()))
    if selected_policy in (FINITE_ROUTE_ID, STANCE_ROUTE_ID, FLEXED_ROUTE_ID, HOLD_ROUTE_ID, R10K_ROUTE_ID, R10L_ROUTE_ID, R10M_ROUTE_ID, R10N_ROUTE_ID, R10O_ROUTE_ID, R10Q_ROUTE_ID, R10R_ROUTE_ID, R10S_ROUTE_ID, R10T_ROUTE_ID, R10U_ROUTE_ID, R10V_ROUTE_ID, R10Y_ROUTE_ID, R10Z_ROUTE_ID, R10AA_ROUTE_ID, R10AB_ROUTE_ID, R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID):
        # Full native replay and all linked receipts were checked above. These
        # extra measurements do not replace the original diagnostic evaluation.
        require(packet.same(result.get('finite_recovery_task'), report.get('finite_recovery_task'))
                and result['finite_recovery_task']['role_and_budget_valid'] is True, 'FINITE_TASK_BOUNDARY')
        rows = report.get('development_walking_entry', {}).get('rows', [])
        if rows:
            import sys
            sys.path.insert(0, str(ROOT / 'sdk/python'))
            from sporespore_locomotion import LocomotionCore
            import finite_recovery_walking
            route = candidate_profile.read(candidate_profile.R10AP_ROUTE_POLICY_PATH if selected_policy == R10AP_ROUTE_ID else candidate_profile.R10AM_ROUTE_POLICY_PATH if selected_policy == R10AM_ROUTE_ID else candidate_profile.R10AJ_ROUTE_POLICY_PATH if selected_policy == R10AJ_ROUTE_ID else candidate_profile.R10AI_ROUTE_POLICY_PATH if selected_policy == R10AI_ROUTE_ID else candidate_profile.R10AG_ROUTE_POLICY_PATH if selected_policy == R10AG_ROUTE_ID else candidate_profile.R10AB_ROUTE_POLICY_PATH if selected_policy == R10AB_ROUTE_ID else candidate_profile.R10AA_ROUTE_POLICY_PATH if selected_policy == R10AA_ROUTE_ID else candidate_profile.R10Z_ROUTE_POLICY_PATH if selected_policy == R10Z_ROUTE_ID else candidate_profile.R10Y_ROUTE_POLICY_PATH if selected_policy == R10Y_ROUTE_ID else candidate_profile.R10V_ROUTE_POLICY_PATH if selected_policy == R10V_ROUTE_ID else candidate_profile.R10U_ROUTE_POLICY_PATH if selected_policy == R10U_ROUTE_ID else candidate_profile.R10T_ROUTE_POLICY_PATH if selected_policy == R10T_ROUTE_ID else candidate_profile.R10S_ROUTE_POLICY_PATH if selected_policy == R10S_ROUTE_ID else candidate_profile.R10R_ROUTE_POLICY_PATH if selected_policy == R10R_ROUTE_ID else candidate_profile.R10Q_ROUTE_POLICY_PATH if selected_policy == R10Q_ROUTE_ID else candidate_profile.R10O_ROUTE_POLICY_PATH if selected_policy == R10O_ROUTE_ID else candidate_profile.R10N_ROUTE_POLICY_PATH if selected_policy == R10N_ROUTE_ID else candidate_profile.R10M_ROUTE_POLICY_PATH if selected_policy == R10M_ROUTE_ID else candidate_profile.R10L_ROUTE_POLICY_PATH if selected_policy == R10L_ROUTE_ID else candidate_profile.R10K_ROUTE_POLICY_PATH if selected_policy == R10K_ROUTE_ID else candidate_profile.HOLD_ROUTE_POLICY_PATH if selected_policy == HOLD_ROUTE_ID else candidate_profile.FLEXED_ROUTE_POLICY_PATH if selected_policy == FLEXED_ROUTE_ID else candidate_profile.STANCE_ROUTE_POLICY_PATH if selected_policy == STANCE_ROUTE_ID else candidate_profile.FINITE_ROUTE_POLICY_PATH)
            core = LocomotionCore(binding(chosen)['runtime']['path'])
            compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
            result['finite_walking_measurement'] = finite_recovery_walking.measure(report, compiled, read(ROOT / route['task_contract']))
        else:
            result['finite_walking_measurement'] = dict(status='walking_not_reached', physical_acceptance_authority=False, release_authority=False)

    if selected_policy in (STANCE_ROUTE_ID, FLEXED_ROUTE_ID, HOLD_ROUTE_ID, R10K_ROUTE_ID, R10L_ROUTE_ID, R10M_ROUTE_ID, R10N_ROUTE_ID, R10O_ROUTE_ID, R10Q_ROUTE_ID, R10R_ROUTE_ID, R10S_ROUTE_ID, R10T_ROUTE_ID, R10U_ROUTE_ID, R10V_ROUTE_ID, R10Y_ROUTE_ID, R10Z_ROUTE_ID, R10AA_ROUTE_ID, R10AB_ROUTE_ID, R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID):
        stance = result.get('stance_entry_replay', {})
        retained_entry = report.get('stance_entry', {})
        readiness_rows = retained_entry.get('readiness_rows', [])
        if selected_policy in (R10T_ROUTE_ID, R10U_ROUTE_ID, R10V_ROUTE_ID, R10Y_ROUTE_ID, R10Z_ROUTE_ID, R10AA_ROUTE_ID, R10AB_ROUTE_ID, R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID):
            post = report.get('post_recovery_settling', {})
            post_rows = post.get('readiness_rows', [])
            require(stance.get('replayed_post_recovery_hold_commands') == len(post_rows) == len(post.get('control_rows', [])), 'POST_RECOVERY_HOLD_REPLAY_POPULATION')
            readiness_rows = readiness_rows + post_rows
        require(stance.get('ok') is True and stance.get('recomputed_readiness_samples') == len(readiness_rows)
                and stance.get('replayed_neutral_commands') == len(retained_entry.get('neutral_control_rows', [])), 'STANCE_ENTRY_REPLAY_POPULATION')
        if selected_policy in (HOLD_ROUTE_ID, R10K_ROUTE_ID, R10L_ROUTE_ID, R10M_ROUTE_ID, R10N_ROUTE_ID, R10O_ROUTE_ID, R10Q_ROUTE_ID, R10R_ROUTE_ID, R10S_ROUTE_ID, R10T_ROUTE_ID, R10U_ROUTE_ID, R10V_ROUTE_ID, R10Y_ROUTE_ID, R10Z_ROUTE_ID, R10AA_ROUTE_ID, R10AB_ROUTE_ID, R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID):
            require(stance.get('replayed_hold_commands') == len(retained_entry.get('hold_control_rows', [])), 'HOLD_ENTRY_REPLAY_POPULATION')
        compiled_entry = {}
        if readiness_rows:
            import sys
            sys.path.insert(0, str(ROOT / 'sdk/python'))
            from sporespore_locomotion import LocomotionCore
            compiled_entry = LocomotionCore(binding(chosen)['runtime']['path']).compile_bounded_quadruped(report['configuration']['base_descriptor'])
        task = read(ROOT / candidate_profile.read(candidate_profile.R10AP_ROUTE_POLICY_PATH if selected_policy == R10AP_ROUTE_ID else candidate_profile.R10AM_ROUTE_POLICY_PATH if selected_policy == R10AM_ROUTE_ID else candidate_profile.R10AJ_ROUTE_POLICY_PATH if selected_policy == R10AJ_ROUTE_ID else candidate_profile.R10AI_ROUTE_POLICY_PATH if selected_policy == R10AI_ROUTE_ID else candidate_profile.R10AG_ROUTE_POLICY_PATH if selected_policy == R10AG_ROUTE_ID else candidate_profile.R10AB_ROUTE_POLICY_PATH if selected_policy == R10AB_ROUTE_ID else candidate_profile.R10AA_ROUTE_POLICY_PATH if selected_policy == R10AA_ROUTE_ID else candidate_profile.R10Z_ROUTE_POLICY_PATH if selected_policy == R10Z_ROUTE_ID else candidate_profile.R10Y_ROUTE_POLICY_PATH if selected_policy == R10Y_ROUTE_ID else candidate_profile.R10V_ROUTE_POLICY_PATH if selected_policy == R10V_ROUTE_ID else candidate_profile.R10U_ROUTE_POLICY_PATH if selected_policy == R10U_ROUTE_ID else candidate_profile.R10T_ROUTE_POLICY_PATH if selected_policy == R10T_ROUTE_ID else candidate_profile.R10S_ROUTE_POLICY_PATH if selected_policy == R10S_ROUTE_ID else candidate_profile.R10R_ROUTE_POLICY_PATH if selected_policy == R10R_ROUTE_ID else candidate_profile.R10Q_ROUTE_POLICY_PATH if selected_policy == R10Q_ROUTE_ID else candidate_profile.R10O_ROUTE_POLICY_PATH if selected_policy == R10O_ROUTE_ID else candidate_profile.R10N_ROUTE_POLICY_PATH if selected_policy == R10N_ROUTE_ID else candidate_profile.R10M_ROUTE_POLICY_PATH if selected_policy == R10M_ROUTE_ID else candidate_profile.R10L_ROUTE_POLICY_PATH if selected_policy == R10L_ROUTE_ID else candidate_profile.R10K_ROUTE_POLICY_PATH if selected_policy == R10K_ROUTE_ID else candidate_profile.HOLD_ROUTE_POLICY_PATH if selected_policy == HOLD_ROUTE_ID else candidate_profile.FLEXED_ROUTE_POLICY_PATH if selected_policy == FLEXED_ROUTE_ID else candidate_profile.STANCE_ROUTE_POLICY_PATH)['task_contract'])
        result['stance_entry_independent_measurement'] = verify_entry_measurements(readiness_rows, compiled_entry, task['stance_entry'])

    if diagnostic_directory is not None:
        result['ledger_scope']['authority_mode'] = 'post_exposure_retained_data_replay'
        result.update(original_attempt_reclassified=False, diagnostic_directory=directory.as_posix())
    return result


def verify_entry_measurements(rows, compiled, limits):
    """Second calculation after cold native/source replay; no world or controller call."""
    import math
    import recovery_walking_readiness
    ready_count = 0
    for row in rows:
        source = row['source']
        actual = source['readiness']
        expected = recovery_walking_readiness.measure(source['projection']['request'],
            source['packet']['native_source']['observation']['center_of_mass'], compiled, limits)
        require(packet.same(actual.get('checks'), expected['checks'])
                and packet.same(actual.get('ready'), expected['ready'])
                and packet.same(actual.get('source_semantic_step'), row['global_semantic_step'])
                and packet.same(actual.get('source_semantic_step'), expected['source_semantic_step']), 'STANCE_ENTRY_INDEPENDENT_CHECKS')
        require(len(actual.get('ordered_legs', [])) == 4, 'STANCE_ENTRY_INDEPENDENT_LEG_POPULATION')
        for a, b in zip(actual['ordered_legs'], expected['ordered_legs']):
            require(a['limb_id'] == b['limb_id'] and packet.same(a['failed_references'], b['failed_references'])
                    and math.isclose(a['maximum_required_reach_m'], b['maximum_required_reach_m'], rel_tol=1e-11, abs_tol=1e-12)
                    and math.isclose(a['sagittal_offset_m'], b['sagittal_offset_m'], rel_tol=1e-11, abs_tol=1e-12), 'STANCE_ENTRY_INDEPENDENT_GEOMETRY')
        ready_count += int(expected['ready'])
    return dict(recomputed_samples=len(rows), ready_samples=ready_count, world_build_count=0,
                solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def run_replay(report_path, *, diagnostic_directory=None, memory_transition_profile=''):
    report_path, directory = _paths(report_path, diagnostic_directory)
    report_raw = report_path.read_bytes()
    report = packet.parse_json(report_raw.decode('utf-8'))
    chosen = _transition_reader_selection(selection_for_report(report), memory_transition_profile, diagnostic_directory)
    effective_transition_profile = _effective_memory_transition_profile(chosen, memory_transition_profile)
    host = _replay_host(report_path, chosen, report)
    image = host['engine_image']
    require(packet.same(runtime.file_identity(Path(image['path'])), image), 'ENGINE_DRIFT')
    directory.mkdir()  # Never reuse or overwrite a consumed replay execution.
    source_snapshot = None
    original_bindings = None
    if diagnostic_directory is not None:
        source_snapshot = _source_snapshot()
        original_bindings = _original_replay_bindings(report_path)
        with (directory / 'source_snapshot.json').open('xb') as stream:
            stream.write(json.dumps(source_snapshot, separators=(',', ':'), allow_nan=False).encode())
    command = _command(report_path, chosen, host)
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith('SPORESPORE_GODOT_RECOVERY_')}
    started = time.monotonic()
    timed_out = False
    with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          creationflags=subprocess.CREATE_NO_WINDOW, env=environment) as process:
        try:
            stdout, stderr = process.communicate(timeout=host['timeout_seconds'])
        except subprocess.TimeoutExpired:
            timed_out = True
            process.kill()  # This exact owned read-only engine process, not any editor/worker.
            stdout, stderr = process.communicate()
        execution = dict(schema_version='sporespore_development_passive_replay_process_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                              authority_mode='development_cold_replay_process', question_class='development'),
            command=command, engine_image=image, process_id=process.pid, returncode=process.returncode,
            timeout_seconds=host['timeout_seconds'], elapsed_seconds=time.monotonic() - started, timed_out=timed_out,
            input_raw_sha256=digest(report_raw), world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False)
    if 'declaration_binding' in host:
        execution['declaration_binding'] = host['declaration_binding']
    if diagnostic_directory is not None:
        execution['ledger_scope']['authority_mode'] = 'post_exposure_retained_data_replay'
        execution.update(original_attempt_reclassified=False, original_replay_bindings=original_bindings,
            source_snapshot_binding=runtime.file_identity(directory / 'source_snapshot.json'),
            source_unchanged_during_replay=packet.same(source_snapshot, _source_snapshot()))
    if effective_transition_profile:
        execution['memory_transition_profile_id'] = effective_transition_profile
    for name, raw in [('stdout', stdout), ('stderr', stderr)]:
        with (directory / (name + '.txt')).open('xb') as stream:
            stream.write(raw)
        execution[name + '_binding'] = dict(byte_length=len(raw), raw_sha256=digest(raw))
    with (directory / 'execution.json').open('xb') as stream:
        stream.write(json.dumps(execution, separators=(',', ':'), allow_nan=False).encode('utf-8'))
    require(report_path.read_bytes() == report_raw, 'INPUT_CHANGED_DURING_REPLAY')
    if 'declaration_binding' in host:
        require(packet.same(runtime.file_identity(Path(host['declaration_path'])),
                            host['declaration_binding']), 'DECLARATION_CHANGED_DURING_REPLAY')
    return consume_replay(report_path, diagnostic_directory=diagnostic_directory, memory_transition_profile=memory_transition_profile)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('report', type=Path)
    parser.add_argument('--run', action='store_true', help='Create one fresh read-only replay execution')
    parser.add_argument('--diagnostic-directory', type=Path,
                        help='Separate fresh post-exposure output under the durable evidence root')
    parser.add_argument('--memory-transition-profile', default='',
                        help='Explicit successor reader; requires a separate post-exposure diagnostic directory')
    args = parser.parse_args()
    try:
        action = run_replay if args.run else consume_replay
        result = action(args.report, diagnostic_directory=args.diagnostic_directory, memory_transition_profile=args.memory_transition_profile)
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), physical_acceptance_authority=False, release_authority=False)))
        return 1
    print(json.dumps(result, separators=(',', ':'), allow_nan=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
