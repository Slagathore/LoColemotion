"""Generic proximal secondary QP in conditioned support-preserving coordinates."""
import numpy as np
import generic_proximal_qp_solver as proximal
import conditioned_contact_component as coordinates
import switching_contact_component as switching
import actuation_recovery_mechanics as m
from dynamic_qp_solver_v2 import certificate,problem_digest,settings as priority_settings

priority_problem=coordinates.priority_problem
solve_priority=coordinates.solve_priority
verify=coordinates.verify
condition=coordinates.condition
build_secondary=coordinates.build_secondary

def parameters():
    p=coordinates.parameters()
    p.update(secondary_backend="ProxQP 0.7.2 generic dense PrimalDualLDLT",
        closest_feasible_relaxation=False,original_full_coordinate_acceptance_unchanged=True)
    return p

def solver_settings():
    return dict(priority=priority_settings(),secondary=proximal.settings(),
        secondary_backend="generic.dense.PrimalDualLDLT",secondary_initial_guess="NO_INITIAL_GUESS",
        secondary_coordinates="conditioned nullspace of dynamics and attained support equalities")

def solve_secondary(qp):
    f=qp["full"];red=qp["reduced"];r=proximal.solve(red["P"],red["q"],red["A"],red["lower"],red["upper"])
    result=dict(reduced=r,accepted=False,full_x=None,full_y=None,full_certificate=None,
        full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]),
        support_rank=qp["support_rank"],support_singular_values=qp["support_singular_values"],
        rank_tolerance=qp["rank_tolerance"],conditioning=qp["conditioning"],maximum_nullspace_equality_error=qp["maximum_nullspace_equality_error"],
        maximum_origin_equality_error=qp["maximum_origin_equality_error"])
    if not r["accepted"]:return result
    x=qp["transform"] @ r["x"]+qp["offset"];eq=qp["equality_indices"];remaining=qp["remaining_indices"]
    gradient=f["P"] @ x+f["q"]+f["A"][remaining].T @ r["y"]
    dual,_,rank,_=np.linalg.lstsq(f["A"][eq].T,-gradient,rcond=None)
    y=np.zeros(len(f["lower"]));y[remaining]=r["y"];y[eq]=dual
    cert=certificate(f["P"],f["q"],f["A"],f["lower"],f["upper"],x,y)
    result.update(accepted=cert["accepted"],full_x=x,full_y=y,full_certificate=cert,equality_dual_rank=int(rank))
    return result

def compute(base):
    if base["domain_refusal"]:
        return dict(accepted=False,status=base["domain_refusal"],prediction=None,selected=None,attempts=[],patterns_tried=0)
    m.require(base["mode"]=="combined","Hierarchy requires combined base constraints")
    queue=switching.initial_patterns(base);seen=set();attempts=[]
    while queue and len(seen)<parameters()["maximum_patterns"]:
        origin,pattern=queue.pop(0);key=tuple(pattern.reshape(-1).tolist())
        if key in seen:continue
        seen.add(key);first=priority_problem(base,pattern);r=solve_priority(first)
        attempts.append(switching.document(first,r,"priority_strict:"+origin))
        if r["accepted"]:
            second=build_secondary(base,pattern,r);secondary=solve_secondary(second)
            attempts.append(switching.document(second,secondary,"secondary_conditioned_generic:"+origin))
            if secondary["accepted"]:
                prediction=verify(first,r,second,secondary)
                return dict(accepted=True,status="certified contact-first hierarchy",prediction=prediction,
                    selected=secondary,primary=r,selected_attempt=len(attempts)-1,
                    attempts=attempts,patterns_tried=len(seen))
        else:
            proposal=priority_problem(base,pattern,False);pr=solve_priority(proposal)
            attempts.append(switching.document(proposal,pr,"priority_proposal_only:"+origin))
            if pr["accepted"]:
                new,_=switching.clipped_prediction(base,pr["full_x"][base["n"]:])
                if tuple(new.reshape(-1).tolist()) not in seen:queue.insert(0,("proposal",new))
    return dict(accepted=False,status="bounded hierarchical search refused",prediction=None,selected=None,
        attempts=attempts,patterns_tried=len(seen))
