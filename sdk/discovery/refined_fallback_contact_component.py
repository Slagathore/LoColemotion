"""Preserve certified generic solves; refine only explicit bounded refusals."""
import generic_proximal_contact_component as original
import refined_primary_contact_component as refined

def parameters():
    return dict(original=original.parameters(),refined=refined.parameters(),
        route="original certified generic hierarchy, then refined-primary hierarchy after bounded refusal",
        maximum_routes=2,maximum_total_patterns=16,maximum_total_qp_solves=32,
        command_specific_selection=False,acceptance_tolerances_changed=False)

def solver_settings():
    return dict(original=original.solver_settings(),refined=refined.solver_settings())

def compute(base):
    first=original.compute(base)
    if first["accepted"] or first["status"]!="bounded hierarchical search refused":
        return dict(first,solver_route="original_generic",fallback_attempted=False,
            original_refusal=None,total_qp_solves=len(first["attempts"]))
    second=refined.compute(base)
    return dict(second,solver_route="refined_primary" if second["accepted"] else "refined_primary_refused",
        fallback_attempted=True,original_refusal=first,
        total_qp_solves=len(first["attempts"])+len(second["attempts"]))
