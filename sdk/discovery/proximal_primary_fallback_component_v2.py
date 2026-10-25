"""Preserve both certified predecessor routes; try a bounded proximal primary after refusal."""
import refined_fallback_contact_component as previous
import proximal_primary_contact_component_v2 as alternate
from actuation_recovery_mechanics import require

def parameters():
    return dict(previous=previous.parameters(),alternate=alternate.parameters(),
        route="unchanged bounded predecessor, then proximal primary only after explicit numerical refusal",
        maximum_routes=3,maximum_total_patterns=24,maximum_total_qp_solves=48,
        command_specific_selection=False,acceptance_tolerances_changed=False)

def solver_settings():
    return dict(previous=previous.solver_settings(),alternate=alternate.solver_settings())

def compute(base):
    first=previous.compute(base)
    if first["accepted"] or first["status"]!="bounded hierarchical search refused":
        return dict(first,primary_backend_fallback_attempted=False,previous_refusal=None)
    second=alternate.compute(base);count=first["total_qp_solves"]+len(second["attempts"])
    require(count<=parameters()["maximum_total_qp_solves"],"Proximal primary bounded total work")
    return dict(second,solver_route="proximal_primary" if second["accepted"] else "proximal_primary_refused",
        fallback_attempted=True,primary_backend_fallback_attempted=True,
        original_refusal=first["original_refusal"],previous_refusal=first,total_qp_solves=count)
