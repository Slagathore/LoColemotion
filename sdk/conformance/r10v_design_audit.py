"""Audit R10V's prospective workflow-only boundary; no execution authority."""
import json
import r10t_route_integration_component as base

DESIGN=base.ROOT/'sdk/recovery/r10v_durable_workflow_design_v1.json'


def audit():
    design=base.read(DESIGN)
    for name in ['predecessor_closure','predecessor_design','retained_data_diagnosis']:
        base.verify(design[name])
    closure=base.read(design['predecessor_closure']['path'])
    prior=base.read(design['predecessor_design']['path'])
    diagnosis=base.read(design['retained_data_diagnosis']['path'])
    assert closure['claim_boundary']['r10u_development_chain_closed'] is True
    assert closure['claim_boundary']['original_attempt_classification']=='consumed_infrastructure_incomplete'
    assert diagnosis['observed']['complete_native_replays']==2
    assert diagnosis['observed']['all_finite_predicates_passed'] is True
    assert diagnosis['claim_boundary']['original_attempt_reclassified'] is False
    assert design['limits']==prior['limits'] and design['conditional_hold_rule']==prior['conditional_hold_rule']
    assert design['implementation_status']=='design_only'
    for name in ['controller_change_authorized','native_dll_change_authorized','readiness_threshold_change_authorized','physical_budget_change_authorized']:
        assert design[name] is False
    coverage=design['development_coverage'];pair=coverage['first_fresh_pair']
    assert (pair['seed'],pair['prefix_phase'],pair['attempt_limit'])==(41345,245,1)
    assert pair['roles']==['matched_no_kick_continuation','kick_passive_recovery_resume']
    assert pair['baseline_reuse'] is False and pair['required_kicked_handoff']=='bounded_hold'
    later=coverage['only_after_valid_positive_pair']
    assert [(x['seed'],x['prefix_phase'],x['entry_kind']) for x in later]==[(41346,246,'upright'),(41341,241,'partial'),(41343,243,'prone')]
    assert all(x['attempt_limit']==1 and x['required_handoff']=='direct' and x['roles']==['kick_passive_recovery_resume'] for x in later)
    assert len(design['allowed_changes'])==5 and len(design['qualification_requirements'])==7
    for name,value in design['claim_boundary'].items():
        assert value==('14/20' if name=='sdk1_score' else '14/25' if name=='full_program_score' else False)
    return dict(ok=True,design=base.bind(DESIGN),implementation_status='design_only',
        controller_or_physical_budget_changed=False,declared_development_cells=5,
        complete_safety_gate_passed=False,physical_execution_authorized=False,
        physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


if __name__=='__main__':print(json.dumps(audit()))
