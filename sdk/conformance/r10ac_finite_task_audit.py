"""R10AC measurement uses unchanged R10AB task thresholds and native laws.

Only the diagnostic context and result identity differ. No old report is edited
or translated, and this measurement grants no physical acceptance authority.
"""
from r10ab_finite_task_audit import (
    contract, require, TASK_SHA, ROLES, entry_measurement, recovery_measurement,
    walking, envelope,
)


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
        require(report.get('r10ac_development', {}).get('required_entry_kind') == 'partial', 'DECLARED_ENTRY_KIND')
        predicates['declared_entry_kind'] = recovery['entry_kind'] == 'partial'
    return dict(schema_version='sporespore_r10ac_finite_task_measurement_v1',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='component_measurement', question_class='development'),
                role=role, task_contract_sha256='sha256:'+TASK_SHA, predicates=predicates,
                finite_task_predicates_passed=all(predicates.values()), entry=entry, walking=measured, envelope=bounds, recovery=recovery,
                original_attempt_reclassified=False, physical_acceptance_authority=False, release_authority=False,
                world_build_count=0, solver_step_count=0)
