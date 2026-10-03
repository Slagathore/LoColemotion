"""Audit the prospective R10T contract; this command cannot launch physics."""
import json

from r10s_launch_component import ROOT, bind, read, verify
import r10t_hold_interface_review as interface

DESIGN = ROOT/'sdk/recovery/r10t_post_recovery_settling_design_v1.json'
DESIGN_SHA = 'sha256:45edc9efd5b815e276baaa1472875fbb2377d99dbe013d8bb332e99417869c04'


def audit():
    assert bind(DESIGN)['raw_sha256'] == DESIGN_SHA
    d = read(DESIGN)
    assert d['status'] == 'declared_before_successor_implementation'
    for reference in d['predecessor_closures'] + [d['interface_review']]: verify(reference)
    assert interface.audit()['ok']
    old = read(ROOT/'sdk/recovery/r10s_extended_preparation_finite_cycle_contract_v1.json')
    assert old['stance_entry']['maximum_horizontal_com_speed_m_s'] == .03
    route, entry, hold, limits = (d[k] for k in ['route','entry_decision','hold','limits'])
    assert not route['native_core_change'] and not route['native_dll_change']
    assert route['native_dll_sha256'] == read(ROOT/'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')['runtime']['raw_sha256']
    assert entry['fallback_entry_kind'] == 'upright' and entry['fallback_requires_recovery_phase'] == 'complete'
    assert entry['fallback_required_checks'] == dict(angular_settled=True, four_native_supports=True,
        horizontal_com_settled=False, upright=True, zero_bias_reference_path_feasible=True)
    assert not entry['recovery_terminal_memory_reopened'] and not entry['recovery_terminal_receipt_rewritten']
    assert hold['maximum_commands'] == limits['maximum_post_recovery_hold_steps'] == 240
    assert hold['ready_dwell_consecutive_samples'] == 30 and hold['physics_hz'] == 120
    assert hold['gait_amplitude'] == 0 and hold['desired_planar_velocity_task_m_s'] == dict(x=0,y=0,z=0)
    assert set(hold['initial_gait_steps'].values()) == {6} and len(hold['initial_gait_steps']) == 4
    assert limits['maximum_after_interaction_steps'] == sum(limits[k] for k in [
        'maximum_passive_descent_steps','maximum_recovery_steps','maximum_post_recovery_hold_steps','maximum_walking_commands','stopping_commands']) == 3400
    assert limits['maximum_kicked_solver_steps'] == limits['maximum_after_interaction_steps'] + sum(limits[k] for k in [
        'maximum_precondition_steps','precondition_pair_release_steps','walking_prefix_steps','interaction_steps']) == 3752
    assert limits['maximum_no_kick_solver_steps'] == 2552 and limits['per_child_wall_seconds'] == 1740
    coverage = d['development_coverage']
    first, after = coverage['first_diagnostic'], coverage['after_first_valid_positive']
    pair = after['fresh_pair']
    assert first['seed'] == pair['seed'] == 41145 and first['prefix_phase'] == pair['prefix_phase'] == 245
    assert first['required_handoff'] == 'bounded_hold' and first['required_entry_kind'] == 'upright'
    assert first['roles'] == ['kick_passive_recovery_resume'] and first['attempt_limit'] == pair['attempt_limit'] == 1
    assert pair['roles'] == ['matched_no_kick_continuation','kick_passive_recovery_resume'] and not pair['baseline_reuse']
    additional = after['only_after_valid_positive_pair']
    assert [(c['seed'],c['prefix_phase'],c['entry_kind']) for c in additional] == [
        (41146,246,'upright'),(41141,241,'partial'),(41143,243,'prone')]
    assert all(c['required_handoff']=='direct' and c['attempt_limit']==1 and c['roles']==first['roles'] for c in additional)
    assert d['claim_boundary'] == dict(held_out_population_declared=False,
        physical_attempt_authorized_by_design_alone=False, physical_acceptance_authority=False,
        release_authority=False, sdk1_score='14/20', full_program_score='14/25')
    assert d['qualification']['full_affected_safety_gate_before_physics']
    assert not d['qualification']['official_qualification_reused']
    return dict(ok=True, design=bind(DESIGN), prospective_contract_audited=True,
        implementation_qualification_granted=False, next_permitted_stage='implement_and_qualify_r10t_development_route',
        world_build_count=0, solver_step_count=0, **d['claim_boundary'])


if __name__ == '__main__':
    print('R10T_SETTLING_DESIGN '+json.dumps(audit()))
