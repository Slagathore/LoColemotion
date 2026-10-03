"""R10Y finite task measurement, downstream of native replay and launch audit.

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
TASK = ROOT / 'sdk/recovery/r10y_partial_direct_neutral_finite_cycle_contract_v1.json'
TASK_SHA = '3d78684470f51379955306c9bf717b5132711577c39422b8c04abe35d452f40c'
ROLES = ('matched_no_kick_continuation', 'kick_passive_recovery_resume')


def require(value, code):
    if not value:
        raise ValueError('R10Y_FINITE_TASK_' + code)


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
    initial_ready = final_ready
    post = post_recovery_measurement(report, compiled, initial_ready)
    if role == ROLES[1] and post['handoff'] == 'bounded_hold':
        passed = post['passed']
        final_ready = post['final_ready']
    return dict(sample_count=len(rows), counts=counts, final_consecutive_hold_ready=consecutive,
                initial_recovery_ready=initial_ready, final_ready=final_ready, passed=passed,
                post_recovery=post)


def post_recovery_measurement(report, compiled, initial_ready):
    """Recompute hold samples without replacing the initial failed readiness."""
    task = contract()
    retained = report['post_recovery_settling']
    state = report['retained_arm']['orchestrator_state']
    require(retained.get('schema_version') == 'sporespore_r10v_post_recovery_settling_retention_v1'
            and retained.get('task_contract_sha256') == 'sha256:'+TASK_SHA, 'POST_HOLD_IDENTITY')
    require(all(retained.get(k) is False for k in ['energy_epoch_reset','physical_acceptance_authority','release_authority']), 'POST_HOLD_AUTHORITY')
    rows, controls = retained['readiness_rows'], retained['control_rows']
    memory = retained['final_memory']
    require(type(rows) is list and type(controls) is list and type(memory) is dict
            and packet.same(memory, state['post_recovery_settling']), 'POST_HOLD_MEMORY')
    if not memory:
        require(not rows and not controls and not retained['entry_source'], 'POST_HOLD_UNSELECTED')
        return dict(handoff='direct' if initial_ready else 'not_reached', commands=0,
                    final_ready=initial_ready, passed=initial_ready)
    require(report['arm_id'] == ROLES[1] and state['r10v_entry_kind'] == 'upright'
            and state['upright_phase'] == 'complete', 'POST_HOLD_RECOVERY_KIND')
    require(len(rows) == len(controls) == memory['commands'] and 0 <= len(rows) <= 240, 'POST_HOLD_POPULATION')
    previous, consecutive, final_ready = memory['entry_source_step'], 0, initial_ready
    for row in rows:
        require(row.get('role') == ROLES[1] and row.get('purpose') == 'post_recovery_hold_dwell'
                and row.get('global_semantic_step') == previous+1, 'POST_HOLD_CLOCK')
        source = row['source']
        observed = source['packet']['native_source']['observation']
        measured = readiness.measure(source['projection']['request'], observed['center_of_mass'], compiled, task['stance_entry'])
        require(measured['source_semantic_step'] == previous+1
                and packet.same(measured['checks'], source['readiness']['checks'])
                and packet.same(measured['ready'], source['readiness']['ready']), 'POST_HOLD_RECOMPUTATION')
        final_ready = measured['ready']
        consecutive = consecutive+1 if final_ready else 0
        previous += 1
        require(consecutive < 30 or row is rows[-1], 'POST_HOLD_STEPPED_AFTER_READY')
    require(previous == memory['last_source_step'] and consecutive == memory['consecutive_ready'], 'POST_HOLD_COUNTERS')
    outcome = memory['outcome']
    require(outcome in ('direct','ready','timeout','entry_refused'), 'POST_HOLD_INCOMPLETE')
    if outcome == 'direct': require(initial_ready and not rows, 'POST_HOLD_FALSE_BYPASS')
    if outcome == 'ready': require(len(rows) >= 30 and consecutive == 30 and not initial_ready, 'POST_HOLD_FALSE_READY')
    if outcome == 'timeout': require(len(rows) == 240 and consecutive < 30, 'POST_HOLD_FALSE_TIMEOUT')
    if outcome == 'entry_refused': require(not rows and not initial_ready, 'POST_HOLD_FALSE_REFUSAL')
    handoff = 'bounded_hold' if outcome == 'ready' else outcome
    return dict(handoff=handoff, commands=len(rows), consecutive_ready=consecutive,
                initial_ready=initial_ready, final_ready=final_ready, passed=outcome in ('direct','ready'))



def recovery_measurement(report):
    """Keep task completion identities distinct after the full native replay.

    The native supervisors establish geometry, limits, energy and dwell truth.
    This measurement reconciles their retained terminal records and the route's
    counters; it cannot replace that replay or create a recovery claim.
    """
    state = report['retained_arm']['orchestrator_state']
    require(state.get('schema_version') == 'sporespore_r10y_recovery_orchestrator_state_v1', 'R10Y_STATE')
    kind = state['r10v_entry_kind']
    require(kind in ('unselected', 'waiting', 'timeout', 'partial', 'upright', 'prone'), 'ENTRY_KIND')
    partial, upright = report['r10y_partial_recovery'], report['r10v_upright_recovery']
    canonical = report['passive_entry']['canonical_packets']
    require(type(canonical) is list, 'CANONICAL_PACKET_POPULATION')
    for name, retained in [('partial', partial), ('upright', upright)]:
        require(type(retained) is dict and retained.get('schema_version') == ('sporespore_r10y_' if name == 'partial' else 'sporespore_r10v_') + name + '_recovery_retention_v1'
                and retained.get('entry_kind') == kind, 'RECOVERY_RETENTION_IDENTITY')
        if name == 'partial':
            require(retained.get('control_composition_id') ==
                'sporespore_r10y_partial_direct_neutral_v21_v7_composition_v1', 'PARTIAL_COMPOSITION')
        for flag in ['canonical_supervisor_synthesized', 'source_observation_rewritten', 'energy_epoch_reset',
                     'physical_acceptance_authority', 'release_authority'] + (['partial_supervisor_synthesized'] if name == 'upright' else []):
            require(retained.get(flag) is False, 'RECOVERY_FORBIDDEN_' + flag)
        require(type(retained.get('step_packets')) is list and type(retained.get('final_memory')) is dict, 'RECOVERY_RETENTION_POPULATION')
        require(type(state[name + '_recovery_step_count']) is int and
                state[name + '_recovery_step_count'] == len(retained['step_packets']), 'RECOVERY_STEP_POPULATION')
        if kind != name:
            require(not retained['step_packets'] and not retained['final_memory'] and
                    state[name + '_start_global_step'] is None and
                    state['partial_standing_complete' if name == 'partial' else 'upright_stabilization_complete'] is False,
                    'CROSSED_TASK_HISTORY')
    if kind != 'prone':
        require(not canonical and state['canonical_start_global_step'] is None and
                state['confirm_prone_step_count'] == 0 and state['consecutive_prone_sample_count'] == 0, 'CROSSED_CANONICAL_HISTORY')
    passed = False
    if kind in ('partial', 'upright'):
        retained = partial if kind == 'partial' else upright
        memory = retained['final_memory']
        passed = (state['partial_standing_complete' if kind == 'partial' else 'upright_stabilization_complete'] is True
                  and memory.get('phase') == 'complete' and memory.get('standing_samples_observed') == 60
                  and 0 < state[kind + '_recovery_step_count'] <= 1200)
    elif kind == 'prone':
        # The declaration requires twelve consecutive samples, after any earlier
        # failed confirmations. The route retains both total and streak counters.
        passed = (bool(canonical) and canonical[-1]['memory_after']['phase'] == 'complete'
                  and state['consecutive_prone_sample_count'] == 12 and state['confirm_prone_step_count'] >= 12)
    return dict(entry_kind=kind, passed=passed, native_replay_required=True,
                physical_acceptance_authority=False, release_authority=False)


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
    recovery = recovery_measurement(report)
    if role == ROLES[1]:
        predicates['recovery_completed'] = recovery['passed']
        require(report.get('r10y_development', {}).get('required_entry_kind') == 'partial', 'DECLARED_ENTRY_KIND')
        predicates['declared_entry_kind'] = recovery['entry_kind'] == 'partial'
    return dict(schema_version='sporespore_r10y_finite_task_measurement_v1',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='component_measurement', question_class='development'),
                role=role, task_contract_sha256='sha256:'+TASK_SHA, predicates=predicates,
                finite_task_predicates_passed=all(predicates.values()), entry=entry, walking=measured, envelope=bounds, recovery=recovery,
                original_attempt_reclassified=False, physical_acceptance_authority=False, release_authority=False,
                world_build_count=0, solver_step_count=0)
