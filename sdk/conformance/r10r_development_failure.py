"""Preserve R10R's consumed first single and cold-replay its completed prefix.

No physics is constructed. The caller owns the native operation lock. Exact
original publications remain incomplete; a reproduced prefix never unlocks
the prospective pair or changes the original evaluator result.
"""
import argparse
import collections
import copy
import json
from pathlib import Path
import subprocess

import development_recovery_refusal as refusal
import development_recovery_smoke as smoke
import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_l15_launch_relationship as launch
import r10j_held_out_failure as historical
import r10r_development_launch as guard
from r10r_native_component import ExactInputCore

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = 'e236daaa9a344dc4853035becffa51c7'
SOURCE = 'abe31373e7dc356af051eb11385dc4aa96833ea8'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + ATTEMPT)
OUTER = ROOT.parent / 'SporeSpore_Evidence/r10r-first-single-launch-c71559ad714b492ab758efb15c27655d'
RECORD = ROOT / 'sdk/recovery/r10r_phase246_development_failure_v1.json'
ROLE = 'kick_passive_recovery_resume'
LIMBS = ['front_left', 'front_right', 'rear_left', 'rear_right']
read, binding = historical.read, historical.binding


def require(value, code):
    if not value:
        raise ValueError('R10R_DEVELOPMENT_FAILURE_' + code)


def frozen(resource):
    return subprocess.check_output(['git', 'show', SOURCE + ':' + resource.removeprefix('res://')], cwd=ROOT)


def transport(item):
    raw = item['utf8_text'].encode('utf-8')
    require(len(raw) == item['utf8_byte_length'] and refusal.digest(raw) == item['raw_sha256'], 'RAW_TRANSPORT')
    return raw


def decoded_view(native, retained, differences):
    """Report JSON number-kind differences; require exact numeric equality.

    Native response hashes remain the byte authority. Godot's decoded view
    can serialize an integral-valued float as an integer, including zero.
    This accepts no numerical tolerance and preserves each differing kind.
    """
    observed = []
    packet.compare_legacy_value(native, retained, observed)
    require(all(float(d['native_repr']) == float(d['legacy_repr']) for d in observed), 'DECODED_NUMERIC_VALUE')
    differences.extend(observed)


def transfer_summary(rows):
    """Recompute the original five release predicates and consecutive dwell."""
    require(len(rows) == 1005 and [r['session_local_step'] for r in rows] == list(range(1, 1006)), 'WALKING_POPULATION')
    require([r['commanded_global_step'] for r in rows] == list(range(889, 1894)), 'WALKING_GLOBAL_CLOCK')
    failures = dict(required_supports=0, triangle_margin=0, horizontal_speed=0, angular_speed=0, tilt=0)
    dwell, measurements = 0, []
    for index, row in enumerate(rows[-240:], 1):
        t = row['native_output']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
        require(t['source_semantic_step'] == row['session_local_step'] == 765 + index
            and t['planned_swing_limb_id'] == 'rear_left' and t['planned_swing_start_gait_step'] == 360
            and t['preparation_held'] is True and t['preparation_released_this_command'] is False, 'PREPARATION_POPULATION')
        require(t['incoming_memory']['preparation_commands'] == index - 1
            and t['next_memory']['preparation_commands'] == index
            and t['incoming_memory']['ready_dwell_commands'] == dwell, 'PREPARATION_CLOCK')
        require(t['required_support_limb_ids'] == ['front_left', 'front_right', 'rear_right'], 'REQUIRED_SUPPORTS')
        contacts = row['request']['state']['ordered_contact_observations']
        require([c['contact_site_id'] for c in contacts] == [limb + '_foot' for limb in LIMBS], 'CONTACT_POPULATION')
        measured = t['measurement']
        checks = dict(required_supports=all(contacts[i]['presence'] is True and contacts[i]['bears_support'] is True for i in [0, 1, 3]),
            triangle_margin=t['remaining_triangle_margin_m'] >= .020,
            horizontal_speed=measured['horizontal_com_speed_m_s'] <= .030,
            angular_speed=measured['torso_angular_speed_rad_s'] <= .15, tilt=measured['torso_tilt_rad'] <= .05)
        ready = all(checks.values())
        dwell = dwell + 1 if ready else 0
        require(t['readiness_conditions_met'] is ready and t['next_memory']['ready_dwell_commands'] == dwell and dwell < 6, 'READINESS_DWELL')
        for key, value in checks.items(): failures[key] += int(not value)
        measurements.append(dict(command=row['session_local_step'], readiness=checks, dwell=dwell,
            triangle_margin_m=t['remaining_triangle_margin_m'], horizontal_speed_m_s=measured['horizontal_com_speed_m_s'],
            angular_speed_rad_s=measured['torso_angular_speed_rad_s'], tilt_rad=measured['torso_tilt_rad'],
            forward_com_speed_m_s=measured['forward_com_speed_m_s'], requested_foreaft_displacement_m=t['requested_foreaft_displacement_m'],
            hip_bias_rad=t['next_memory']['hip_bias_rad'], hip_bias_saturated=t['hip_bias_saturated']))
    return dict(planned_swing_limb='rear_left', first_command=766, last_command=1005, preparation_commands=240,
        failed_readiness_conditions=failures, maximum_ready_dwell=max(m['dwell'] for m in measurements),
        required_ready_dwell=6, terminal_ready_dwell=dwell, saturated_commands=sum(m['hip_bias_saturated'] for m in measurements),
        ready_commands=[m['command'] for m in measurements if m['dwell']], measurements=measurements,
        longer_timeout_success_demonstrated=False)


def controls(rows):
    compact = [dict(session_local_step=r['session_local_step'], commanded_global_step=r['commanded_global_step'],
        request=dict(state=dict(ordered_contact_observations=r['request']['state']['ordered_contact_observations'])),
        native_output=dict(actuation=dict(receipt=dict(recovery_support_plane=dict(measured_support_transfer=
            r['native_output']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']))))) for r in rows]
    require(transfer_summary(compact) == transfer_summary(rows), 'COMPACT_DIAGNOSIS')
    results = []
    for name in ['missing_row', 'crossed_clock', 'forged_ready', 'forged_dwell', 'crossed_contacts', 'crossed_limb']:
        value = copy.deepcopy(compact)
        t = value[-1]['native_output']['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
        if name == 'missing_row': value.pop()
        elif name == 'crossed_clock': value[-1]['commanded_global_step'] += 1
        elif name == 'forged_ready': t['readiness_conditions_met'] = True
        elif name == 'forged_dwell': t['next_memory']['ready_dwell_commands'] = 6
        elif name == 'crossed_contacts': value[-1]['request']['state']['ordered_contact_observations'][0]['contact_site_id'] = 'rear_left_foot'
        else: t['planned_swing_limb_id'] = 'front_right'
        try: transfer_summary(value)
        except ValueError as error: results.append(dict(case=name, refused=True, error=str(error)))
        else: raise ValueError('R10R_DEVELOPMENT_FAILURE_NEGATIVE_ACCEPTED:' + name)
    return results


def replay_prefix(report, descriptor, core):
    populations = [('passive_entry', report['passive_entry']['entry_packets']),
                   ('upright_recovery', report['r10r_upright_recovery']['step_packets'])]
    require([len(p) for _, p in populations] == [240, 376], 'RECOVERY_POPULATION')
    for group, packets in populations:
        for p in packets:
            call = p['call']
            require(call['ok'] is True and call['compiled_call_count'] == 1, 'NATIVE_CALL')
            actual = core._call_json_input('ss_' + call['method'], transport(call['request']))
            require(core.raw_response == transport(call['response']) and packet.same(actual, p['native_receipt'])
                and packet.same(actual, call['value']), 'RECOVERY_NATIVE_BYTES')
        print('R10R_FAILURE_REPLAY', group, len(packets), flush=True)
    upright = populations[1][1]
    require([p['source_application']['semantic_step'] for p in upright] == list(range(513, 889)), 'UPRIGHT_CLOCK')
    for previous, current in zip(upright, upright[1:]):
        require(packet.same(previous['native_receipt']['step']['memory'], current['prior_memory']), 'UPRIGHT_MEMORY_CHAIN')
    final = report['r10r_upright_recovery']['final_memory']
    require(packet.same(final, upright[-1]['native_receipt']['step']['memory']) and final['phase'] == 'complete'
        and final['standing_samples_observed'] == 60 and final['total_steps_observed'] == 376, 'UPRIGHT_COMPLETION')
    for p in upright[-60:]:
        c = p['native_receipt']['step']['classification']
        require(c['stable_stance_gate'] is True and c['safety_gate'] is True and c['no_cheat_gate'] is True
            and c['joint_limits_respected'] is True and c['actuator_budget_respected'] is True
            and c['all_four_distal_sites_bearing'] is True and c['any_nonfoot_contact'] is False, 'STANDING_DWELL')
    rows = report['development_walking_entry']['rows']
    failure = report['detail']['portable_step_receipt']['development_native_step_failure']
    previous, decoded_differences = None, []
    for index, row in enumerate(rows, 1):
        if previous is not None: decoded_view(previous, row['request']['memory'], decoded_differences)
        request = refusal.integers(dict(copy.deepcopy(row['request']), descriptor=descriptor))
        output = core.balanced_wave_policy_step_with_measured_body(failure['expected_policy_id'], request)
        require(refusal.digest(core.raw_response) == row['raw_native_response_sha256'], 'WALKING_NATIVE_BYTES_' + str(index))
        decoded_view(output, row['native_output'], decoded_differences)
        require(output['actuation']['safe_no_actuation'] is False, 'WALKING_COMPLETED_COMMAND_' + str(index))
        previous = output['next_memory']
        if index % 250 == 0: print('R10R_FAILURE_REPLAY walking', index, flush=True)
    refused_request = packet.parse_json(failure['request']['utf8_text'])
    decoded_view(previous, refused_request['memory'], decoded_differences)
    reproduction = historical.reproduce_refusal(report, descriptor, core)
    return dict(passive_entry_calls=240, upright_recovery_calls=376, walking_calls=1005,
        refusal_verification_calls=2, total_native_calls=1623, exact_response_bytes_verified=True,
        standing_consecutive_samples=60, standing_global_step=888,
        upright_phase_commands=dict(collections.Counter(p['source_application']['phase'] for p in upright)),
        terminal_standing_classification=upright[-1]['native_receipt']['step']['classification'],
        decoded_numeric_kind_differences=len(decoded_differences),
        representative_decoded_differences=decoded_differences[:20],
        refusal=reproduction, complete_route_replay_performed=False)


def audit():
    declaration, supervisor = read(EVIDENCE / 'declaration.json'), read(EVIDENCE / 'supervisor_result.json')
    launch_record = guard.verify(EVIDENCE / 'declaration.json')
    require(launch_record['stage'] == 'initial_single_diagnostic', 'INITIAL_STAGE')
    require(supervisor['ok'] is False and supervisor['failure_code'] == 'SMOKE_CHILD_INVALID:' + ROLE
        and supervisor['physical_attempt_started'] is True and supervisor['independent_audit'] is None, 'ORIGINAL_SUPERVISOR')
    marker = (EVIDENCE / 'published_marker.txt').read_text(encoding='utf-8')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    require(marker.startswith(prefix) and packet.same(packet.parse_json(marker[len(prefix):]), supervisor), 'SUPERVISOR_PUBLICATION')
    source = dict(head=SOURCE, dirty=False, status=[], changed_file_bindings=[])
    require(packet.same(supervisor['source_snapshot'], source) and packet.same(declaration['source_snapshot'], source), 'CLEAN_SOURCE')
    require(declaration['attempt_id'] == ATTEMPT and declaration['seed'] == 40946
        and declaration['r10r_development']['seed']['prefix_phase'] == 246, 'DECLARATION')
    stages = declaration['safety_stages']
    require(packet.same(stages, supervisor['safety_stages']) and len(stages) == 40
        and sum(s['test_count'] for s in stages) == 190, 'COMPLETE_GATE')
    require(len(supervisor['children']) == len(declaration['children']) == 1
        and supervisor['children'][0]['role'] == ROLE
        and not (EVIDENCE / 'children/matched_no_kick_continuation').exists(), 'SINGLE_POPULATION')
    child, descriptor = EVIDENCE / 'children' / ROLE, declaration['children'][0]
    envelope, report = read(child / 'child_envelope.json'), read(child / 'worker_report.json')
    require(packet.same(binding(child / 'child_envelope.json'), supervisor['children'][0]['envelope']), 'ENVELOPE_BINDING')
    require(envelope['exit_code'] == 1 and envelope['engine_health_passed'] is True
        and envelope['termination_protocol_valid'] is True and envelope['raw_marker_valid'] is True
        and envelope['child_retry_count'] == envelope['child_replacement_count'] == 0, 'CHILD_TERMINATION')
    for item in envelope['retained_artifact_bindings'].values(): historical.bound_file(item, child)
    original = []
    with (child / 'worker.stdout.txt').open(encoding='utf-8') as stream:
        for line in stream:
            if line.startswith(smoke.MARKER): original.append(line[len(smoke.MARKER):])
    require(len(original) == 1 and packet.same(packet.parse_json(original[0]), report)
        and packet.same(report, envelope['report']), 'RAW_REPORT')
    del original, envelope['report']
    for key in ('role', 'child_attempt_id', 'termination_nonce'): require(envelope[key] == descriptor[key], 'CHILD_' + key)
    expected = dict(schema_version='sporespore_qsdk_r10f_l15_launch_context_v1', parent_attempt_id=ATTEMPT,
        child_attempt_id=descriptor['child_attempt_id'], role=ROLE, source_commit=SOURCE,
        authority_sha256=binding(EVIDENCE / 'declaration.json')['raw_sha256'], termination_nonce=descriptor['termination_nonce'],
        ready_marker_prefix='QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY ',
        root_image=declaration['runtime']['images']['godot_console'], worker_image=declaration['runtime']['images']['godot_engine'])
    launch.validate_receipt(envelope['r10f_l15_launch_relationship'], expected_context=expected,
        root_process_id=envelope['process_id'], worker_process_id=envelope['worker_process_id'],
        started_utc=envelope['started_utc'], expected_ready_receipt=envelope['termination_ready_receipt'])
    for key, value in dict(ok=False, failure_code='QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID', source_commit=SOURCE,
        parent_attempt_id=ATTEMPT, child_attempt_id=descriptor['child_attempt_id'], arm_id=ROLE, seed=40946,
        process_id=envelope['worker_process_id'], world_build_count=1, solver_step_count=1893,
        external_kick_application_count=1, held_out=False, held_out_cell_access_count=0, measurement_complete=False,
        physical_acceptance_authority=False, release_authority=False, baseline_reused=False, comparative_authority=False).items():
        require(packet.same(report.get(key), value), 'REPORT_' + key)
    require(historical.verify_step_invariants(report, report['partial_arm'], ROLE) == 1893, 'INVARIANTS')
    state = report['partial_arm']['orchestrator_state']
    require(state['upright_stabilization_complete'] is True and state['upright_recovery_step_count'] == 376
        and state['walking_resume_step_count'] == 1005 and state['passive_descent_step_count'] == 240, 'PHASE_COUNTS')
    failure = report['detail']['portable_step_receipt']['development_native_step_failure']
    require(failure['classification'] == 'verified_zero_actuation_controller_refusal'
        and failure['reported_native_controller_error'] == 'FRAME_INVALID:measured_support_transfer_preparation_timeout'
        and failure['verified_zero_actuation_refusal'] is True and failure['motor_application_permitted'] is False
        and failure['adapter_memory_advanced'] is False and failure['adapter_clock_advanced'] is False, 'REFUSAL')
    profile_raw = frozen(declaration['candidate_profile']['resource'])
    require(refusal.digest(profile_raw) == declaration['candidate_profile']['raw_sha256'], 'PROFILE')
    profile = packet.parse_json(profile_raw.decode())
    runtime_raw = frozen(profile['runtime_binding'])
    require(refusal.digest(runtime_raw) == profile['runtime_binding_sha256'], 'RUNTIME')
    runtime = packet.parse_json(runtime_raw.decode())['runtime']
    historical.bound_file(runtime)
    require(runtime['raw_sha256'] == profile['runtime_sha256'], 'DLL')
    old = packet.parse_json(frozen('sdk/recovery/r10j_held_out_physical_closure_v1.json').decode())
    descriptor_binding = old['cells'][2]['report']
    historical.bound_file(descriptor_binding)
    morphology = read(descriptor_binding['path'])['configuration']['base_descriptor']
    native = replay_prefix(report, morphology, ExactInputCore(runtime['path']))
    rows = report['development_walking_entry']['rows']
    task = report['finite_recovery_task']
    require(task['planned_cycle_count'] == 3 and task['stopping_commands'] == 0
        and task['cycle_and_stop_boundary_reached'] is False, 'INCOMPLETE_TASK')
    return dict(schema_version='sporespore_r10r_phase246_development_failure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='consumed_development_failure_closure', question_class='development'),
        status='invalid_single_kick_walking_controller_refusal_after_upright_standing', attempt_id=ATTEMPT,
        source_snapshot=source, evidence_root=EVIDENCE.as_posix(), launch_record=launch_record,
        safety_gate=dict(passed=True, tests=190, stages=40, seconds=sum(s['seconds'] for s in stages)),
        started_utc=supervisor['started_utc'], completed_utc=supervisor['completed_utc'],
        original_supervisor_ok=False, original_failure_code=supervisor['failure_code'],
        original_child_failure_code=report['failure_code'], native_controller_error=failure['reported_native_controller_error'],
        model_worlds=1, completed_solver_steps=1893, kicks_applied=1, complete_step_invariants_verified=1893,
        cold_native_replay=native, support_transfer=transfer_summary(rows), diagnostic_negative_controls=controls(rows),
        worker_reported_planned_cycles=3, worker_reported_stop_commands=0, descriptor_source=descriptor_binding,
        native_runtime=runtime, auditor=binding(Path(__file__)),
        source_helpers=[binding(ROOT / p) for p in ['sdk/conformance/development_recovery_refusal.py',
            'sdk/conformance/r10j_held_out_failure.py', 'sdk/conformance/r10r_native_component.py',
            'sdk/conformance/r10r_development_launch.py', 'sdk/conformance/qsdk_r10f_l15_launch_relationship.py']],
        retained_evidence=[binding(p) for p in sorted(EVIDENCE.rglob('*')) if p.is_file()],
        outer_invocation=[binding(p) for p in sorted(OUTER.iterdir()) if p.is_file()],
        verification_limits=['All retained passive entry, upright and walking native calls are reproduced against the original DLL; the full Godot orchestration and motor-application reader is not run on this incomplete report.',
            'Three cycles remain the original worker boundary measurement, not an independently accepted finite result.',
            'Standing is a retained and cold-reproduced component observation; the single-kick finite task remains incomplete.'],
        first_single_consumed=True, original_attempt_reclassified=False, retry_permitted=False,
        r10r_pair_permitted=False, r10r_additional_cells_permitted=False, r10r_held_out_permitted=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    observed = audit()
    if args.create:
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(observed, stream, indent=2, allow_nan=False)
            stream.write('\n')
    else: require(packet.same(observed, read(RECORD)), 'CLOSURE_RECONSTRUCTION')
    print(json.dumps(dict(ok=True, record=RECORD.relative_to(ROOT).as_posix(), native_calls=1623,
        standing_samples=60, walking_commands=1005, solver_steps=1893, negative_controls=6,
        support_failures=observed['support_transfer']['failed_readiness_conditions'],
        maximum_ready_dwell=observed['support_transfer']['maximum_ready_dwell'], sdk1_score='14/20')), flush=True)


if __name__ == '__main__': main()
