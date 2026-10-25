"""Preserve three accepted routes; use bounded residual scaling only after refusal."""
import proximal_primary_fallback_component_v2 as previous
import scaled_primary_contact_component as alternate
from actuation_recovery_mechanics import require

def parameters():
    return dict(previous=previous.parameters(),alternate=alternate.parameters(),
        route="unchanged three-route predecessor, then scaled primary after explicit numerical refusal",
        maximum_routes=4,maximum_total_patterns=32,maximum_total_qp_solves=112,
        command_specific_selection=False,acceptance_tolerances_changed=False)

def solver_settings():
    return dict(previous=previous.solver_settings(),alternate=alternate.solver_settings())

def compute(base):
    first=previous.compute(base)
    if first["accepted"] or first["status"]!="bounded hierarchical search refused":
        return dict(first,scaled_primary_fallback_attempted=False,scaling_previous_refusal=None)
    second=alternate.compute(base);count=first["total_qp_solves"]+second["total_qp_solves"]
    require(second["total_qp_solves"]<=64 and count<=112,"Scaled primary bounded actual QP calls")
    return dict(second,solver_route="scaled_primary" if second["accepted"] else "scaled_primary_refused",
        fallback_attempted=True,primary_backend_fallback_attempted=True,scaled_primary_fallback_attempted=True,
        original_refusal=first["original_refusal"],previous_refusal=first["previous_refusal"],
        scaling_previous_refusal=first,total_qp_solves=count)
