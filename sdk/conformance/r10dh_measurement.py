"""R10DH prospective prone predicate over unchanged mechanical measurements."""
import r10dh_contract as C
from r10dh_dependency_manifest import D
import r10ap_finite_task_audit as T

def measure(report,compiled):
    # Unchanged mechanical helpers, with the distinct prospective prone-only
    # predicate. No historical task result is loaded and then reclassified.
    task=T.contract();role=report['arm_id'];count=report['solver_step_count']
    T.require(role in T.ROLES and report['ok'] is True,'PANEL_ROLE')
    bound=task['limits']['maximum_no_kick_child_solver_steps' if role==T.ROLES[0] else 'maximum_kicked_child_solver_steps']
    T.require(type(count) is int and 0<count<=bound,'PANEL_BOUND')
    rows=report['retained_arm']['trace_rows']
    T.require(len(rows)==count and [r['global_semantic_step'] for r in rows]==list(range(1,count+1)) and all(r['arm_id']==role for r in rows),'PANEL_TRACE')
    T.require(report['external_kick_application_count']==int(role==T.ROLES[1]),'PANEL_KICK')
    T.require(report['stance_entry']['task_contract_sha256']=='sha256:'+T.TASK_SHA,'PANEL_TASK')
    entry=T.entry_measurement(report,compiled);recovery=T.recovery_measurement(report)
    control=report.get('development_walking_entry',{}).get('rows',[])
    measured=dict(status='walking_not_reached');bounds=dict(sample_count=0,passed=False)
    if control:
        measured=T.walking.measure(report,compiled,task)
        first,last=control[0]['commanded_global_step'],control[-1]['commanded_global_step']
        T.require(last==count and last-first+1==len(control),'PANEL_WALKING_BOUND')
        selected=rows[first-1:last];ids={r['walking_session_id'] for r in selected}
        T.require(len(ids)==1 and '' not in ids,'PANEL_WALKING_SESSION')
        sessions=[s for s in report['retained_arm']['walking_sessions'] if s['session_id']==next(iter(ids))]
        T.require(len(sessions)==1 and sessions[0]['evaluation_segment_id']==task['fresh_roles'][T.ROLES.index(role)]['post_interaction_segment'],'PANEL_SEGMENT')
        T.require([r['walking_session_local_step'] for r in selected]==list(range(1,len(control)+1)),'PANEL_LOCAL_CLOCK')
        base=control[0]['request']['state']['base_pose_world']
        bounds=T.envelope(selected,T.walking.vector(base['position_m']),T.walking.rotate(base['orientation_xyzw'],(0.,0.,1.)))
    predicates=dict(entry_ready=entry['passed'],planned_cycles=measured.get('planned_cycle_predicate',False),
                    forward_advance=measured.get('body_forward_predicate',False),settled_stop=measured.get('complete_stop_predicate',False),whole_walking_envelope=bounds['passed'])
    if role==T.ROLES[1]:
        predicates.update(recovery_completed=recovery['passed'],declared_entry_kind=recovery['entry_kind'] == 'prone')
    return dict(predicates=predicates,finite_task_predicates_passed=all(predicates.values()),
                required_entry_kind='prone',
                entry=entry,recovery=recovery,walking=measured,envelope=bounds,
                task_contract_sha256=D.binding(C.TASK)['raw_sha256'], inherited_mechanical_contract_sha256='sha256:'+T.TASK_SHA,physical_acceptance_authority=False,release_authority=False)
