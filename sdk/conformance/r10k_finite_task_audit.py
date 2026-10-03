"""R10K finite task measurement, downstream of native replay and launch audit.

This component never creates worlds or grants acceptance. The enclosing development auditor
must additionally validate the source-bound declaration, original launch/retention,
native replay, exact declared role population, and complete recovery invariants.
Historical reports remain historical: measuring one here does not regrade it.
"""
import hashlib
import math
from pathlib import Path

import finite_recovery_walking as walking
import qsdk_r10f_l15_collection_retention as packet
import recovery_walking_readiness as readiness

ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / 'sdk/recovery/r10k_partial_fall_finite_cycle_contract_v1.json'
TASK_SHA = '72cded74ff3f1811d7ea15a66d98d72c20a3765561cf9824b80110c4cb34d41a'
ROLES = ('matched_no_kick_continuation', 'kick_passive_recovery_resume')


def require(value, code):
    if not value:
        raise ValueError('R10K_FINITE_TASK_' + code)


def contract():
    raw = TASK.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == TASK_SHA, 'CONTRACT_DRIFT')
    return packet.parse_json(raw.decode('utf-8'))


def scalar(value, *, nonnegative=False):
    require(type(value) in (int, float) and math.isfinite(value), 'FINITE_SCALAR')
    require(not nonnegative or value >= 0, 'NONNEGATIVE_SCALAR')
    return value


def sequence_vector(value):
    require(type(value) is list and len(value) == 3, 'VECTOR_POPULATION')
    return tuple(scalar(v) for v in value)


def horizontal(value):
    length = math.hypot(value[0], value[2])
    require(length > 1e-9, 'HORIZONTAL_AXIS')
    return value[0] / length, 0., value[2] / length


def envelope(rows, initial_position, initial_forward):
    """Measure the entire post-interaction walking segment, including its stop.

    All seven bounds come from the unchanged task. Lateral and yaw excursions
    are checked at every retained completed step, so returning inside a bound
    at the final step cannot hide an earlier excursion. Native trace values
    must already be bound to the original report by the production readers.
    """
    limits = contract()['whole_walking_envelope']
    require(type(rows) is list and bool(rows), 'ENVELOPE_POPULATION')
    origin = sequence_vector(list(initial_position))
    forward = horizontal(sequence_vector(list(initial_forward)))
    lateral = (-forward[2], 0., forward[0])
    metrics = dict(maximum_absolute_lateral_drift_m=0., maximum_yaw_drift_rad=0.,
                   maximum_torso_tilt_rad=0., minimum_torso_height_m=math.inf,
                   maximum_joint_anchor_error_m=0., maximum_hinge_axis_error_rad=0.,
                   maximum_torso_contact_samples=0)
    previous = None
    for row in rows:
        step = row['global_semantic_step']
        require(type(step) is int and step > 0 and
                (previous is None or step == previous + 1), 'ENVELOPE_CLOCK')
        previous = step
        require(row['source_measurement'] is True, 'ENVELOPE_NATIVE_SOURCE')
        position = sequence_vector(row['torso_position_world_m'])
        heading = horizontal(sequence_vector(row['torso_forward_axis_world_unit']))
        yaw = math.atan2(abs(forward[0]*heading[2] - forward[2]*heading[0]),
                         forward[0]*heading[0] + forward[2]*heading[2])
        drift = abs(sum((position[i]-origin[i])*lateral[i] for i in range(3)))
        require(type(row['torso_contact']) is bool, 'ENVELOPE_CONTACT_DOMAIN')
        metrics['maximum_absolute_lateral_drift_m'] = max(metrics['maximum_absolute_lateral_drift_m'], drift)
        metrics['maximum_yaw_drift_rad'] = max(metrics['maximum_yaw_drift_rad'], yaw)
        metrics['maximum_torso_tilt_rad'] = max(metrics['maximum_torso_tilt_rad'], scalar(row['torso_tilt_rad'], nonnegative=True))
        metrics['minimum_torso_height_m'] = min(metrics['minimum_torso_height_m'], position[1])
        metrics['maximum_joint_anchor_error_m'] = max(metrics['maximum_joint_anchor_error_m'], scalar(row['maximum_anchor_error_m'], nonnegative=True))
        metrics['maximum_hinge_axis_error_rad'] = max(metrics['maximum_hinge_axis_error_rad'], scalar(row['maximum_hinge_axis_error_rad'], nonnegative=True))
        metrics['maximum_torso_contact_samples'] += int(row['torso_contact'])
    predicates = {key: (metrics[key] >= limit if key.startswith('minimum_') else metrics[key] <= limit)
                  for key, limit in limits.items() if key != 'provenance'}
    require(len(predicates) == 7, 'ENVELOPE_CONTRACT_POPULATION')
    return dict(sample_count=len(rows), metrics=metrics, predicates=predicates,
                passed=all(predicates.values()))


def entry_measurement(report, compiled):
    task = contract()
    role = report['arm_id']
    require(role in ROLES, 'ROLE')
    rows = report['stance_entry']['readiness_rows']
    require(type(rows) is list, 'ENTRY_POPULATION')
    counts = dict(neutral_dwell=0, hold_dwell=0, post_recovery_entry=0)
    consecutive = 0
    previous = None
    last_purpose = None
    final_ready = False
    for row in rows:
        purpose, step = row['purpose'], row['global_semantic_step']
        require(row['role'] == role and purpose in counts, 'ENTRY_ROLE_OR_PURPOSE')
        require(type(step) is int and step > 0 and
                (previous is None or step > previous), 'ENTRY_CLOCK')
        if role == ROLES[0]:
            require(purpose in ('neutral_dwell', 'hold_dwell') and
                    not (last_purpose == 'hold_dwell' and purpose == 'neutral_dwell'), 'ENTRY_PHASE_ORDER')
            require(previous is None or step == previous+1, 'ENTRY_CONTIGUITY')
        else:
            require(purpose == 'post_recovery_entry' and not counts[purpose], 'KICKED_ENTRY_POPULATION')
        source = row['source']
        observation = source['packet']['native_source']['observation']
        measured = readiness.measure(source['projection']['request'], observation['center_of_mass'],
                                     compiled, task['stance_entry'])
        require(measured['source_semantic_step'] == step and
                packet.same(measured['checks'], source['readiness']['checks']) and
                packet.same(measured['ready'], source['readiness']['ready']), 'ENTRY_RECOMPUTATION')
        counts[purpose] += 1
        if purpose == 'hold_dwell':
            consecutive = consecutive+1 if measured['ready'] else 0
        final_ready = measured['ready']
        previous, last_purpose = step, purpose
    if role == ROLES[0]:
        require(counts['neutral_dwell'] == len(report['stance_entry']['neutral_control_rows']) and
                counts['hold_dwell'] == len(report['stance_entry']['hold_control_rows']), 'ENTRY_COMMAND_POPULATION')
        require(counts['neutral_dwell'] <= task['limits']['maximum_no_kick_stance_entry_commands'] and
                counts['hold_dwell'] <= task['limits']['maximum_no_kick_hold_commands'], 'ENTRY_COMMAND_BOUND')
        passed = counts['neutral_dwell'] > 0 and consecutive >= task['stance_entry']['hold']['ready_consecutive_completed_samples']
    else:
        require(not report['stance_entry']['neutral_control_rows'] and
                not report['stance_entry'].get('hold_control_rows', []), 'KICKED_ENTRY_ROUTE')
        passed = counts['post_recovery_entry'] == 1 and final_ready
    return dict(sample_count=len(rows), counts=counts, final_consecutive_hold_ready=consecutive,
                final_ready=final_ready, passed=passed)


def measure(report, compiled):
    """Additional task measurements only; launch validity is a separate gate."""
    task = contract()
    role = report['arm_id']
    require(role in ROLES, 'ROLE')
    require(report['ok'] is True, 'INVALID_WORKER')
    require(report['stance_entry']['task_contract_sha256'] == 'sha256:'+TASK_SHA, 'REPORT_CONTRACT')
    count = report['solver_step_count']
    bound = task['limits']['maximum_no_kick_child_solver_steps' if role == ROLES[0] else 'maximum_kicked_child_solver_steps']
    require(type(count) is int and 0 < count <= bound, 'ROLE_STEP_BOUND')
    arm = report['retained_arm']
    traces = arm['trace_rows']
    require(len(traces) == count and [r['global_semantic_step'] for r in traces] == list(range(1, count+1)), 'TRACE_POPULATION')
    require(all(r['arm_id'] == role for r in traces), 'TRACE_ROLE')
    require(report['external_kick_application_count'] == (0 if role == ROLES[0] else 1), 'KICK_POPULATION')
    entry = entry_measurement(report, compiled)
    control = report.get('development_walking_entry', {}).get('rows', [])
    measured = dict(status='walking_not_reached')
    bounds = dict(sample_count=0, passed=False)
    if control:
        measured = walking.measure(report, compiled, task)
        first, last = control[0]['commanded_global_step'], control[-1]['commanded_global_step']
        require(last == count and last-first+1 == len(control), 'WALKING_TERMINAL_BOUNDARY')
        selected = traces[first-1:last]
        session_ids = {r['walking_session_id'] for r in selected}
        require(len(session_ids) == 1 and '' not in session_ids, 'WALKING_SESSION_POPULATION')
        session_id = next(iter(session_ids))
        sessions = [s for s in arm['walking_sessions'] if s['session_id'] == session_id]
        require(len(sessions) == 1 and sessions[0]['evaluation_segment_id'] == task['fresh_roles'][ROLES.index(role)]['post_interaction_segment'], 'WALKING_SEGMENT')
        require([r['walking_session_local_step'] for r in selected] == list(range(1, len(control)+1)), 'WALKING_LOCAL_CLOCK')
        base = control[0]['request']['state']['base_pose_world']
        bounds = envelope(selected, walking.vector(base['position_m']), walking.rotate(base['orientation_xyzw'], (0., 0., 1.)))
    predicates = dict(entry_ready=entry['passed'], planned_cycles=measured.get('planned_cycle_predicate', False),
                      forward_advance=measured.get('body_forward_predicate', False),
                      settled_stop=measured.get('complete_stop_predicate', False), whole_walking_envelope=bounds['passed'])
    state = arm['orchestrator_state']
    require(state.get('schema_version') == 'sporespore_r10k_recovery_orchestrator_state_v1', 'R10K_STATE')
    if role == ROLES[1]:
        kind = state['r10k_entry_kind']
        partial = report['r10k_partial_recovery']
        canonical = report['passive_entry']['canonical_packets']
        if kind == 'partial':
            recovered = (state['partial_standing_complete'] is True and not canonical
                         and partial['final_memory'].get('phase') == 'complete'
                         and partial['final_memory'].get('standing_samples_observed') == 60
                         and state['canonical_start_global_step'] is None
                         and state['confirm_prone_step_count'] == 0)
        elif kind == 'prone':
            recovered = (bool(canonical) and canonical[-1]['memory_after']['phase'] == 'complete'
                         and state['confirm_prone_step_count'] == 12 and not partial['step_packets'])
        else:
            recovered = False
        predicates['recovery_completed'] = recovered
    return dict(schema_version='sporespore_r10k_finite_task_measurement_v1',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='component_measurement', question_class='development'),
                role=role, task_contract_sha256='sha256:'+TASK_SHA, predicates=predicates,
                finite_task_predicates_passed=all(predicates.values()), entry=entry, walking=measured, envelope=bounds,
                original_attempt_reclassified=False, physical_acceptance_authority=False, release_authority=False,
                world_build_count=0, solver_step_count=0)
