"""Check the prospective R10U boundary; this does not qualify execution."""
import json
import r10t_route_integration_component as base

DESIGN = base.ROOT/'sdk/recovery/r10u_audit_handoff_design_v1.json'


def audit():
    design = base.read(DESIGN)
    base.verify(design['predecessor_closure']); base.verify(design['predecessor_design'])
    closure = base.read(design['predecessor_closure']['path'])
    prior = base.read(design['predecessor_design']['path'])
    assert closure['claim_boundary']['r10t_development_chain_closed']
    assert closure['claim_boundary']['original_attempt_classification'] == 'consumed_infrastructure_invalid'
    assert closure['observed']['diagnostic_all_finite_predicates_passed']
    assert design['limits'] == prior['limits']
    assert design['implementation_status'] == 'design_only'
    for key in ['controller_change_authorized', 'native_dll_change_authorized',
                'readiness_threshold_change_authorized', 'physical_budget_change_authorized']:
        assert design[key] is False
    coverage = design['development_coverage']; pair = coverage['first_fresh_pair']
    assert pair['seed'] == 41245 and pair['prefix_phase'] == 245 and pair['attempt_limit'] == 1
    assert pair['roles'] == ['matched_no_kick_continuation', 'kick_passive_recovery_resume']
    assert pair['baseline_reuse'] is False and pair['required_kicked_handoff'] == 'bounded_hold'
    later = coverage['only_after_valid_positive_pair']
    assert [(x['seed'], x['prefix_phase'], x['entry_kind']) for x in later] == [
        (41246, 246, 'upright'), (41241, 241, 'partial'), (41243, 243, 'prone')]
    assert all(x['attempt_limit'] == 1 and x['required_handoff'] == 'direct'
        and x['roles'] == ['kick_passive_recovery_resume'] for x in later)
    for key, value in design['claim_boundary'].items():
        assert value == ('14/20' if key == 'sdk1_score' else '14/25' if key == 'full_program_score' else False)
    return dict(ok=True, design=base.bind(DESIGN), implementation_status='design_only',
        declared_development_cells=5, controller_or_physical_budget_changed=False,
        complete_safety_gate_passed=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


if __name__ == '__main__':
    print(json.dumps(audit()))
