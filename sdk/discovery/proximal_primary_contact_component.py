"""Distinct proximal primary with strict refinement and unchanged conditioned secondary."""
import numpy as np
import generic_proximal_least_squares as primary_solver
import generic_proximal_qp_solver as proximal
import conditioned_contact_component as coordinates
import primary_active_refinement as refinement
import hierarchical_least_squares_qp as least
import switching_contact_component as switching
import actuation_recovery_mechanics as m
from dynamic_qp_solver_v2 import certificate,problem_digest,settings as priority_settings

priority_problem=coordinates.priority_problem
def initial_priority(qp):
    f=qp["full"];red=qp["reduced"]
    r=primary_solver.solve(qp["reduced_task_matrix"],qp["reduced_task_target"],red["A"],red["lower"],red["upper"])
    result=dict(reduced=r,accepted=False,full_x=None,full_y=None,full_certificate=None,
        full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]))
    if not r["accepted"]:return result
    x=qp["transform"] @ r["x"]+qp["offset"];n=qp["base"]["n"]
    gradient=f["P"] @ x+f["q"]+f["A"][n:].T @ r["y"]
    y=np.r_[np.linalg.solve(f["A"][:n,:n].T,-gradient[:n]),r["y"]]
    cert=least.certificate(qp["task_matrix"],qp["task_target"],f["A"],f["lower"],f["upper"],x,y)
    result.update(accepted=cert["accepted"],full_x=x,full_y=y,full_certificate=cert)
    return result

def solve_priority(qp):
    initial=initial_priority(qp);f=qp["full"];red=qp["reduced"]
    result=dict(initial,accepted=False,full_x=None,full_y=None,full_certificate=None,initial_primary=initial)
    if not initial["accepted"]:
        result["primary_refinement"]=dict(accepted=False,status="initial full primary refused",x=None,y=None,certificate=None)
        return result
    refined=refinement.refine(qp["reduced_task_matrix"],qp["reduced_task_target"],
        red["A"],red["lower"],red["upper"],initial["reduced"])
    result["primary_refinement"]=refined
    if not refined["accepted"]:return result
    x=qp["transform"] @ refined["x"]+qp["offset"];n=qp["base"]["n"]
    gradient=f["P"] @ x+f["q"]+f["A"][n:].T @ refined["y"]
    y=np.r_[np.linalg.solve(f["A"][:n,:n].T,-gradient[:n]),refined["y"]]
    cert=least.certificate(qp["task_matrix"],qp["task_target"],f["A"],f["lower"],f["upper"],x,y)
    accepted=bool(cert["accepted"] and cert["maximum_bound_violation"]<=refinement.parameters()["primary_feasibility_absolute_guard"])
    result.update(accepted=accepted,full_x=x if accepted else None,full_y=y if accepted else None,
        full_certificate=cert,reduced=dict(initial["reduced"],accepted=accepted,
            x=refined["x"] if accepted else None,y=refined["y"] if accepted else None,
            certificate=refined["certificate"]))
    return result
verify=coordinates.verify
condition=coordinates.condition
build_secondary=coordinates.build_secondary

def parameters():
    p=coordinates.parameters()
    p.update(primary_backend="ProxQP 0.7.2 generic dense PrimalDualLDLT",primary_objective_regularization=0.,secondary_backend="ProxQP 0.7.2 generic dense PrimalDualLDLT",
        closest_feasible_relaxation=False,original_full_coordinate_acceptance_unchanged=True,primary_refinement=refinement.parameters())
    return p

def solver_settings():
    return dict(priority=primary_solver.settings(),primary_refinement=refinement.parameters(),secondary=proximal.settings(),
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
            attempts.append(switching.document(second,secondary,"secondary_proximal_primary:"+origin))
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
