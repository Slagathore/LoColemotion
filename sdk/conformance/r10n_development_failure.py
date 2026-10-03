"""Reconstruct the first R10N physical refusal without retrying its world.

The caller owns the native operation lock. This auditor checks retained launch
and source identities, all completed invariant receipts, and the last valid and
refused native calls. It does not make an incomplete child a valid route ghost.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import development_recovery_refusal as refusal
import development_recovery_smoke as smoke
import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_l15_launch_relationship as launch
import r10j_held_out_failure as historical

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = '3192f99b45c942589c10efe45dbef093'
SOURCE = 'b65fbe7e10e132aa729361584802355d8171f999'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + ATTEMPT)
RECORD = ROOT / 'sdk/recovery/r10n_phase241_development_failure_v1.json'
ROLE = 'matched_no_kick_continuation'


def require(value, code):
    if not value:
        raise ValueError('R10N_DEVELOPMENT_FAILURE_' + code)


def read(path):
    return packet.parse_json(Path(path).read_text(encoding='utf-8'))


def binding(path):
    return historical.binding(path)


def frozen(resource):
    path = resource.removeprefix('res://')
    return subprocess.check_output(['git', 'show', SOURCE + ':' + path], cwd=ROOT)


def transfer_summary(report):
    """Recompute each readiness predicate and dwell from retained measured inputs."""
    rows = report['development_walking_entry']['rows']
    require(len(rows) == 857 and [r['session_local_step'] for r in rows] == list(range(1, 858)), 'WALKING_POPULATION')
    require([r['commanded_global_step'] for r in rows] == list(range(619, 1476)), 'WALKING_GLOBAL_CLOCK')
    tail = rows[-240:]
    failures = dict(required_supports=0, triangle_margin=0, horizontal_speed=0, angular_speed=0, tilt=0)
    ready_commands, measurements = [], []
    dwell = 0
    for index, row in enumerate(tail, 1):
        t = row['native_output']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
        require(t['source_semantic_step'] == row['session_local_step'] == 617 + index
                and t['planned_swing_limb_id'] == 'rear_left'
                and t['planned_swing_start_gait_step'] == 360
                and t['preparation_held'] is True and t['preparation_released_this_command'] is False,
                'PREPARATION_POPULATION')
        require(t['incoming_memory']['preparation_commands'] == index - 1
                and t['next_memory']['preparation_commands'] == index
                and t['incoming_memory']['ready_dwell_commands'] == dwell, 'PREPARATION_CLOCK')
        require(t['required_support_limb_ids'] == ['front_left', 'front_right', 'rear_right'], 'REQUIRED_SUPPORTS')
        contacts = row['request']['state']['ordered_contact_observations']
        require(len(contacts) == 4 and [c['contact_site_id'] for c in contacts] ==
                ['front_left_foot', 'front_right_foot', 'rear_left_foot', 'rear_right_foot'], 'CONTACT_POPULATION')
        measured = t['measurement']
        checks = dict(
            required_supports=all(contacts[i]['presence'] is True and contacts[i]['bears_support'] is True for i in [0, 1, 3]),
            triangle_margin=t['remaining_triangle_margin_m'] >= .020,
            horizontal_speed=measured['horizontal_com_speed_m_s'] <= .030,
            angular_speed=measured['torso_angular_speed_rad_s'] <= .15,
            tilt=measured['torso_tilt_rad'] <= .05)
        ready = all(checks.values())
        dwell = dwell + 1 if ready else 0
        require(t['readiness_conditions_met'] is ready and t['next_memory']['ready_dwell_commands'] == dwell
                and dwell < 6, 'READINESS_DWELL')
        for key, value in checks.items(): failures[key] += int(not value)
        if ready: ready_commands.append(row['session_local_step'])
        measurements.append(dict(command=row['session_local_step'], readiness=checks, dwell=dwell,
            triangle_margin_m=t['remaining_triangle_margin_m'], horizontal_speed_m_s=measured['horizontal_com_speed_m_s'],
            angular_speed_rad_s=measured['torso_angular_speed_rad_s'], tilt_rad=measured['torso_tilt_rad'],
            hip_bias_rad=t['next_memory']['hip_bias_rad'], hip_bias_saturated=t['hip_bias_saturated']))
    zero_rows = [r for r in rows if r['request']['command']['gait_amplitude'] == 0]
    require([r['session_local_step'] for r in zero_rows] == [1], 'BRAKE_ACTIVATION_POPULATION')
    brake = zero_rows[0]['native_output']['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['zero_amplitude_motor_brake']
    motors = zero_rows[0]['native_output']['actuation']['ordered_commands']
    require(len(brake['ordered_commands']) == len(motors) == 8
            and all(c['changed'] is True and c['held_target_velocity_rad_s'] == 0 for c in brake['ordered_commands'])
            and all(c['target_velocity_rad_s'] == 0 for c in motors), 'STARTUP_BRAKE')
    require(all('zero_amplitude_motor_brake' not in r['native_output']['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']
                for r in rows[1:]), 'NO_LATER_BRAKE')
    return dict(planned_swing_limb='rear_left', preparation_commands=240, first_walking_command=618,
        last_walking_command=857, failed_readiness_conditions=failures, ready_commands=ready_commands,
        maximum_ready_dwell=max(m['dwell'] for m in measurements), required_ready_dwell=6,
        terminal_ready_dwell=dwell, saturated_commands=sum(m['hip_bias_saturated'] for m in measurements),
        terminal_bias_rad=measurements[-1]['hip_bias_rad'], measurements=measurements,
        brake_applied_commands=[1], brake_changed_motor_commands=8, stop_reached=False,
        longer_timeout_success_demonstrated=False, startup_brake_causality_demonstrated=False)


def negative_controls(report):
    """Mutate small diagnostic copies; original evidence is never edited."""
    import copy
    # Keep the complete clock population but only the fields this auditor consumes.
    rows = report['development_walking_entry']['rows']
    compact = dict(development_walking_entry=dict(rows=[dict(session_local_step=r['session_local_step'],
        commanded_global_step=r['commanded_global_step'], request=dict(command=r['request']['command'],
            state=dict(ordered_contact_observations=r['request']['state']['ordered_contact_observations'])),
        native_output=dict(actuation=dict(ordered_commands=r['native_output']['actuation']['ordered_commands'],
            receipt=dict(recovery_support_plane=r['native_output']['actuation']['receipt']['recovery_support_plane'])))) for r in rows]))
    require(transfer_summary(compact) == transfer_summary(report), 'COMPACT_DIAGNOSIS')
    results = []
    for name in ['missing_row', 'crossed_clock', 'forged_ready', 'forged_dwell', 'forged_margin', 'crossed_contacts', 'forged_startup_motor']:
        value = copy.deepcopy(compact)
        copied = value['development_walking_entry']['rows']; last = copied[-1]
        t = last['native_output']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
        if name == 'missing_row': copied.pop()
        elif name == 'crossed_clock': last['commanded_global_step'] += 1
        elif name == 'forged_ready': t['readiness_conditions_met'] = False
        elif name == 'forged_dwell': t['next_memory']['ready_dwell_commands'] = 6
        elif name == 'forged_margin': t['remaining_triangle_margin_m'] = 0
        elif name == 'crossed_contacts': last['request']['state']['ordered_contact_observations'][0]['contact_site_id'] = 'rear_left_foot'
        else: copied[0]['native_output']['actuation']['ordered_commands'][0]['target_velocity_rad_s'] = .1
        try:
            transfer_summary(value)
        except ValueError as error:
            results.append(dict(case=name, refused=True, error=str(error)))
        else:
            raise ValueError('R10N_DEVELOPMENT_FAILURE_NEGATIVE_CONTROL_ACCEPTED:' + name)
    return results


def audit():
    declaration = read(EVIDENCE / 'declaration.json')
    supervisor = read(EVIDENCE / 'supervisor_result.json')
    require(supervisor['ok'] is False and supervisor['failure_code'] == 'SMOKE_CHILD_INVALID:' + ROLE
            and supervisor['physical_attempt_started'] is True and supervisor['independent_audit'] is None, 'ORIGINAL_SUPERVISOR')
    marker = (EVIDENCE / 'published_marker.txt').read_text(encoding='utf-8')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    require(marker.startswith(prefix) and packet.same(packet.parse_json(marker[len(prefix):]), supervisor), 'SUPERVISOR_PUBLICATION')
    source = dict(head=SOURCE, dirty=False, status=[], changed_file_bindings=[])
    require(packet.same(supervisor['source_snapshot'], source) and packet.same(declaration['source_snapshot'], source), 'CLEAN_SOURCE')
    require(declaration['attempt_id'] == ATTEMPT and declaration['seed'] == 40641
            and declaration['r10n_development']['seed']['prefix_phase'] == 241, 'DECLARATION')
    stages = declaration['safety_stages']
    require(packet.same(stages, supervisor['safety_stages']) and len(stages) == 41
            and sum(s['test_count'] for s in stages) == 201
            and all(s['passed'] is True and s['timed_out'] is False and s['exit_code'] == 0
                    and s['test_count'] == s['expected_test_count'] for s in stages), 'COMPLETE_GATE')
    require(len(supervisor['children']) == 1 and supervisor['children'][0]['role'] == ROLE
            and not (EVIDENCE / 'children/kick_passive_recovery_resume').exists(), 'OBSERVED_CHILD_POPULATION')
    child = EVIDENCE / 'children' / ROLE
    descriptor = declaration['children'][0]
    require([c['role'] for c in declaration['children']] == [ROLE, 'kick_passive_recovery_resume'], 'DECLARED_PAIR')
    envelope = read(child / 'child_envelope.json')
    report = read(child / 'worker_report.json')
    require(packet.same(binding(child / 'child_envelope.json'), supervisor['children'][0]['envelope']), 'ENVELOPE_BINDING')
    require(envelope['exit_code'] == 1 and envelope['engine_health_passed'] is True
            and envelope['termination_protocol_valid'] is True and envelope['raw_marker_valid'] is True
            and envelope['child_retry_count'] == envelope['child_replacement_count'] == 0, 'CHILD_TERMINATION')
    for item in envelope['retained_artifact_bindings'].values():
        historical.bound_file(item, child)
    original = []
    with (child / 'worker.stdout.txt').open(encoding='utf-8') as stream:
        for line in stream:
            if line.startswith(smoke.MARKER):
                original.append(line[len(smoke.MARKER):])
    require(len(original) == 1 and packet.same(packet.parse_json(original[0]), report)
            and packet.same(report, envelope['report']), 'RAW_REPORT')
    del original, envelope['report']
    for key in ('role', 'child_attempt_id', 'termination_nonce'):
        require(envelope[key] == descriptor[key], 'CHILD_IDENTITY_' + key)
    expected = dict(schema_version='sporespore_qsdk_r10f_l15_launch_context_v1', parent_attempt_id=ATTEMPT,
        child_attempt_id=descriptor['child_attempt_id'], role=ROLE, source_commit=SOURCE,
        authority_sha256=binding(EVIDENCE / 'declaration.json')['raw_sha256'], termination_nonce=descriptor['termination_nonce'],
        ready_marker_prefix='QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY ',
        root_image=declaration['runtime']['images']['godot_console'], worker_image=declaration['runtime']['images']['godot_engine'])
    launch.validate_receipt(envelope['r10f_l15_launch_relationship'], expected_context=expected,
        root_process_id=envelope['process_id'], worker_process_id=envelope['worker_process_id'],
        started_utc=envelope['started_utc'], expected_ready_receipt=envelope['termination_ready_receipt'])
    for key, value in dict(ok=False, failure_code='QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID', source_commit=SOURCE,
        parent_attempt_id=ATTEMPT, child_attempt_id=descriptor['child_attempt_id'], arm_id=ROLE, seed=40641,
        process_id=envelope['worker_process_id'], world_build_count=1, solver_step_count=1475,
        external_kick_application_count=0, held_out=False, held_out_cell_access_count=0,
        physical_acceptance_authority=False, release_authority=False).items():
        require(packet.same(report.get(key), value), 'REPORT_' + key)
    arm = report['partial_arm']
    require(historical.verify_step_invariants(report, arm, ROLE) == 1475, 'INVARIANTS')
    state = arm['orchestrator_state']
    require(state['neutral_entry_step_count'] == 170 and state['hold_entry_step_count'] == 176
            and state['consecutive_neutral_ready'] == 30 and state['matched_continuation_step_count'] == 857, 'PHASE_COUNTS')
    failure = report['detail']['portable_step_receipt']['development_native_step_failure']
    require(failure['classification'] == 'verified_zero_actuation_controller_refusal'
            and failure['reported_native_controller_error'] == 'FRAME_INVALID:measured_support_transfer_preparation_timeout'
            and failure['verified_zero_actuation_refusal'] is True
            and failure['motor_application_permitted'] is False and failure['adapter_memory_advanced'] is False
            and failure['adapter_clock_advanced'] is False, 'REFUSAL')
    profile_raw = frozen(declaration['candidate_profile']['resource'])
    require(refusal.digest(profile_raw) == declaration['candidate_profile']['raw_sha256'], 'FROZEN_PROFILE')
    profile = packet.parse_json(profile_raw.decode())
    runtime_raw = frozen(profile['runtime_binding'])
    require(refusal.digest(runtime_raw) == profile['runtime_binding_sha256'], 'FROZEN_RUNTIME')
    runtime = packet.parse_json(runtime_raw.decode())['runtime']
    historical.bound_file(runtime)
    require(runtime['raw_sha256'] == profile['runtime_sha256'], 'RUNTIME_SELECTION')
    # Only the exact morphology descriptor is borrowed from this immutable
    # historical report. The compiled morphology hash must match this child.
    historical_closure = packet.parse_json(frozen('sdk/recovery/r10j_held_out_physical_closure_v1.json').decode())
    descriptor_binding = historical_closure['cells'][2]['report']
    historical.bound_file(descriptor_binding)
    morphology = read(descriptor_binding['path'])['configuration']['base_descriptor']
    replay = historical.reproduce_refusal(report, morphology, refusal.RecordedCore(runtime['path']))
    observed = dict(schema_version='sporespore_r10n_phase241_development_failure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='consumed_development_failure_closure', question_class='development'),
        attempt_id=ATTEMPT, source_snapshot=source, evidence_root=EVIDENCE.as_posix(),
        started_utc=supervisor['started_utc'], completed_utc=supervisor['completed_utc'],
        status='invalid_no_kick_controller_refusal_kicked_child_unopened',
        safety_gate=dict(passed=True, tests=201, stages=41, seconds=sum(s['seconds'] for s in stages)),
        original_supervisor_ok=False, original_failure_code=supervisor['failure_code'],
        original_child_failure_code=report['failure_code'], native_controller_error=failure['reported_native_controller_error'],
        model_worlds=1, completed_solver_steps=1475, kicks_applied=0, kicked_child_opened=False,
        ramp_commands=170, hold_commands=176, consecutive_hold_ready=30, walking_commands=857,
        worker_reported_planned_cycles=report['finite_recovery_task']['planned_cycle_count'],
        worker_reported_stop_commands=report['finite_recovery_task']['stopping_commands'],
        complete_step_invariants_verified=1475, support_transfer=transfer_summary(report),
        diagnostic_negative_controls=negative_controls(report),
        source_helpers=[binding(ROOT / p) for p in [
            "sdk/conformance/development_recovery_refusal.py", "sdk/conformance/r10j_held_out_failure.py",
            "sdk/conformance/qsdk_r10f_l15_launch_relationship.py", "sdk/conformance/qsdk_r10f_l15_collection_retention.py"]],
        original_native_refusal_reproduction=replay, descriptor_source=descriptor_binding,
        auditor=binding(Path(__file__)),
        native_runtime=runtime, supervisor=binding(EVIDENCE / 'supervisor_result.json'),
        declaration=binding(EVIDENCE / 'declaration.json'), report=binding(child / 'worker_report.json'),
        child_envelope=binding(child / 'child_envelope.json'),
        retained_evidence=[binding(p) for p in sorted(EVIDENCE.rglob('*')) if p.is_file()],
        verification_limits=['The last valid and refused controller calls are reproduced; the complete walking command history is not independently replayed here.',
            'Three cycles are the original worker boundary result; the incomplete child is not reclassified as a valid finite result.',
            'The R10N kicked recovery branches remain physically untested.'],
        original_attempt_reclassified=False, retry_permitted=False, phase243_prerequisite_satisfied=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')
    return observed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true', help='Write the first immutable repository closure with exclusive creation')
    args = parser.parse_args()
    observed = audit()
    if args.create:
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(observed, stream, indent=2, allow_nan=False)
            stream.write('\n')
    else:
        require(packet.same(observed, read(RECORD)), 'CLOSURE_RECONSTRUCTION')
    print(json.dumps(dict(ok=True, record=RECORD.relative_to(ROOT).as_posix(), retained_files=len(observed['retained_evidence']),
        world_count=1, completed_steps=1475, native_reproductions=2, negative_controls=7, maximum_ready_dwell=5, original_attempt_reclassified=False, sdk1_score='14/20')))


if __name__ == '__main__':
    main()
