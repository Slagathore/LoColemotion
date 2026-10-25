"""Bounded active-constraint refinement of an accepted least-squares primary."""
import numpy as np
import hierarchical_least_squares_qp as least
from actuation_recovery_mechanics import require

def parameters():
    return dict(active_dual_threshold=1e-8,primary_feasibility_absolute_guard=1e-12,
        active_equality_absolute_guard=1e-12,dual_sign_absolute_guard=1e-12,refinement_passes=1,
        objective_regularization=0.,active_selection="equalities, nonzero duals, and violated bounds",
        rank_rule="machine epsilon times maximum matrix dimension times largest singular value")

def refine(c,d,a,lower,upper,initial):
    p=parameters()
    if not initial["accepted"]:return dict(accepted=False,status="initial primary refused",x=None,y=None,certificate=None)
    x0=np.array(initial["x"],dtype=float);y0=np.array(initial["y"],dtype=float);value=a @ x0
    active=[];bounds=[];sides=[]
    for i,(lo,hi,dual) in enumerate(zip(lower,upper,y0,strict=True)):
        if lo==hi:active.append(i);bounds.append(lo);sides.append("equal")
        elif dual>p["active_dual_threshold"] or value[i]>hi:
            require(np.isfinite(hi),"Refinement upper bound");active.append(i);bounds.append(hi);sides.append("upper")
        elif dual<-p["active_dual_threshold"] or value[i]<lo:
            require(np.isfinite(lo),"Refinement lower bound");active.append(i);bounds.append(lo);sides.append("lower")
    n=len(x0);e=a[active];b=np.asarray(bounds)
    if active:
        _,singular,vh=np.linalg.svd(e,full_matrices=True)
        tolerance=np.finfo(float).eps*max(e.shape)*singular[0] if singular.size and singular[0] else 0.
        rank=int(np.count_nonzero(singular>tolerance));null=vh[rank:].T
        origin=x0+np.linalg.lstsq(e,b-e @ x0,rcond=None)[0]
    else:
        rank=0;tolerance=0.;singular=np.zeros(0);null=np.eye(n);origin=x0.copy()
    if null.shape[1]:
        delta,_,task_rank,_=np.linalg.lstsq(c @ null,d-c @ origin,rcond=None)
        x=origin+null @ delta
    else:x=origin;task_rank=0
    gradient=c.T @ (c @ x-d)
    y=np.zeros(len(lower))
    if active:y[active]=np.linalg.lstsq(e.T,-gradient,rcond=None)[0]
    cert=least.certificate(c,d,a,lower,upper,x,y)
    error=float(np.max(np.abs(e @ x-b),initial=0.))
    signs=all(side=="equal" or (dual>=-p["dual_sign_absolute_guard"] if side=="upper" else dual<=p["dual_sign_absolute_guard"])
        for side,dual in zip(sides,y[active],strict=True))
    accepted=bool(cert["accepted"] and signs and error<=p["active_equality_absolute_guard"]
        and cert["maximum_bound_violation"]<=p["primary_feasibility_absolute_guard"])
    return dict(accepted=accepted,status="refined primary certified" if accepted else "primary refinement refused",
        x=x if accepted else None,y=y if accepted else None,certificate=cert if accepted else None,
        diagnostic=dict(active_rows=active,active_sides=sides,rank=rank,rank_tolerance=tolerance,
            singular_values=singular,remaining_task_rank=int(task_rank),active_equality_error=error,
            multiplier_signs_valid=signs,maximum_change=float(np.max(np.abs(x-x0),initial=0.)),
            original_task_cost=float(np.linalg.norm(c @ x0-d)**2),
            refined_task_cost=float(np.linalg.norm(c @ x-d)**2),
            candidate_x=x,candidate_y=y,candidate_certificate=cert))
