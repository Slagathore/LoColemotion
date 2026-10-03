"""Reconstruct the first R10K physical refusal without retrying its world.

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
ATTEMPT = '009a47a4d47640d2a88dfed3f8738c2b'
SOURCE = '765e2b1c032d5dea013b38468c0fd00c3f926ddc'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + ATTEMPT)
RECORD = ROOT / 'sdk/recovery/r10k_phase241_development_failure_v1.json'
ROLE = 'matched_no_kick_continuation'


def require(value, code):
    if not value:
        raise ValueError('R10K_DEVELOPMENT_FAILURE_' + code)


def read(path):
    return packet.parse_json(Path(path).read_text(encoding='utf-8'))


def binding(path):
    return historical.binding(path)


def frozen(resource):
    path = resource.removeprefix('res://')
    return subprocess.check_output(['git', 'show', SOURCE + ':' + path], cwd=ROOT)


def transfer_summary(report):
    rows = report['development_walking_entry']['rows']
    require(len(rows) == 839 and [r['session_local_step'] for r in rows] == list(range(1, 840)), 'WALKING_POPULATION')
    require([r['commanded_global_step'] for r in rows] == list(range(619, 1458)), 'WALKING_GLOBAL_CLOCK')
    tail = []
    for row in rows:
        transfer = row['native_output']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
        if transfer['planned_swing_limb_id'] == 'rear_left' and transfer['preparation_held']:
            tail.append(transfer)
    require(len(tail) == 240 and [t['source_semantic_step'] for t in tail] == list(range(600, 840)), 'PREPARATION_POPULATION')
    require([t['next_memory']['preparation_commands'] for t in tail] == list(range(1, 241)), 'PREPARATION_CLOCK')
    last = tail[-1]
    measured = last['measurement']
    contacts = last['inherited_guard_recommendation']['ordered_limbs']
    checks = dict(
        required_supports=all(c['precommand_contact']['presence'] is True and c['precommand_contact']['bears_support'] is True
                             for c in contacts if c['limb_id'] in last['required_support_limb_ids']),
        triangle_margin=last['remaining_triangle_margin_m'] >= .020,
        horizontal_speed=measured['horizontal_com_speed_m_s'] <= .030,
        angular_speed=measured['torso_angular_speed_rad_s'] <= .15,
        tilt=measured['torso_tilt_rad'] <= .05)
    require(checks == dict(required_supports=True, triangle_margin=False, horizontal_speed=True, angular_speed=True, tilt=True), 'TERMINAL_LIMIT')
    require(last['next_memory']['hip_bias_rad'] == -.25 and last['hip_bias_saturated'] is True
            and last['applied_hip_bias_rate_rad_s'] == 0 and last['next_memory']['ready_dwell_commands'] == 0, 'SATURATED_LIMIT')
    return dict(planned_swing_limb='rear_left', preparation_commands=240, first_walking_command=600,
        last_walking_command=839, saturated_command_count=sum(t['hip_bias_saturated'] for t in tail),
        terminal_bias_rad=last['next_memory']['hip_bias_rad'], terminal_release_checks=checks,
        terminal_triangle_margin_m=last['remaining_triangle_margin_m'], required_triangle_margin_m=.020,
        target_triangle_margin_m=.025, terminal_requested_foreaft_displacement_m=last['requested_foreaft_displacement_m'],
        terminal_horizontal_com_speed_m_s=measured['horizontal_com_speed_m_s'],
        terminal_angular_speed_rad_s=measured['torso_angular_speed_rad_s'], terminal_torso_tilt_rad=measured['torso_tilt_rad'],
        longer_timeout_success_demonstrated=False)


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
    require(declaration['attempt_id'] == ATTEMPT and declaration['seed'] == 40341
            and declaration['r10k_development']['seed']['prefix_phase'] == 241, 'DECLARATION')
    stages = declaration['safety_stages']
    require(packet.same(stages, supervisor['safety_stages']) and len(stages) == 38
            and sum(s['test_count'] for s in stages) == 186
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
        parent_attempt_id=ATTEMPT, child_attempt_id=descriptor['child_attempt_id'], arm_id=ROLE, seed=40341,
        process_id=envelope['worker_process_id'], world_build_count=1, solver_step_count=1457,
        external_kick_application_count=0, held_out=False, held_out_cell_access_count=0,
        physical_acceptance_authority=False, release_authority=False).items():
        require(packet.same(report.get(key), value), 'REPORT_' + key)
    arm = report['partial_arm']
    require(historical.verify_step_invariants(report, arm, ROLE) == 1457, 'INVARIANTS')
    state = arm['orchestrator_state']
    require(state['neutral_entry_step_count'] == 170 and state['hold_entry_step_count'] == 176
            and state['consecutive_neutral_ready'] == 30 and state['matched_continuation_step_count'] == 839, 'PHASE_COUNTS')
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
    observed = dict(schema_version='sporespore_r10k_phase241_development_failure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='consumed_development_failure_closure', question_class='development'),
        attempt_id=ATTEMPT, source_snapshot=source, evidence_root=EVIDENCE.as_posix(),
        started_utc=supervisor['started_utc'], completed_utc=supervisor['completed_utc'],
        status='invalid_no_kick_controller_refusal_kicked_child_unopened',
        safety_gate=dict(passed=True, tests=186, stages=38, seconds=sum(s['seconds'] for s in stages)),
        original_supervisor_ok=False, original_failure_code=supervisor['failure_code'],
        original_child_failure_code=report['failure_code'], native_controller_error=failure['reported_native_controller_error'],
        model_worlds=1, completed_solver_steps=1457, kicks_applied=0, kicked_child_opened=False,
        ramp_commands=170, hold_commands=176, consecutive_hold_ready=30, walking_commands=839,
        worker_reported_planned_cycles=report['finite_recovery_task']['planned_cycle_count'],
        worker_reported_stop_commands=report['finite_recovery_task']['stopping_commands'],
        complete_step_invariants_verified=1457, support_transfer=transfer_summary(report),
        original_native_refusal_reproduction=replay, descriptor_source=descriptor_binding,
        auditor=binding(Path(__file__)),
        native_runtime=runtime, supervisor=binding(EVIDENCE / 'supervisor_result.json'),
        declaration=binding(EVIDENCE / 'declaration.json'), report=binding(child / 'worker_report.json'),
        child_envelope=binding(child / 'child_envelope.json'),
        retained_evidence=[binding(p) for p in sorted(EVIDENCE.rglob('*')) if p.is_file()],
        verification_limits=['The last valid and refused controller calls are reproduced; the complete walking command history is not independently replayed here.',
            'Three cycles are the original worker boundary result; the incomplete child is not reclassified as a valid finite result.',
            'The R10K kicked recovery branches remain physically untested.'],
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
        world_count=1, completed_steps=1457, native_reproductions=2, original_attempt_reclassified=False, sdk1_score='14/20')))


if __name__ == '__main__':
    main()
