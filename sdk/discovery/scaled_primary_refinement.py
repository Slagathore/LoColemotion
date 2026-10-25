"""Bounded affine residual correction; original-coordinate certificates decide acceptance.

Inspired by scaled QP refinement (Weber, Sager and Gleixner, 2019).
This float64 variant has no rational-arithmetic or arbitrary-precision claim.
"""
import numpy as np
import generic_proximal_least_squares as solver
import proximal_primary_contact_component_v2 as previous
import hierarchical_least_squares_qp as least
from dynamic_qp_solver_v2 import problem_digest
from actuation_recovery_mechanics import require

def parameters():
    return dict(scale_exponents=[20,30,40],maximum_corrections=3,maximum_primary_qp_solves=4,
        primary_feasibility_absolute_guard=1e-12,objective_regularization=0.,
        correction="z = scale * (x - origin); original dual = correction dual / scale",
        arithmetic="float64",arbitrary_precision_established=False,
        initial_seed_requires_original_certificates=True,acceptance_tolerances_changed=False)

def correction_problem(qp,origin,exponent):
    require(type(exponent) is int and exponent in parameters()["scale_exponents"],"Scaled primary declared exponent")
    red=qp["reduced"];scale=float(2**exponent);origin=np.asarray(origin,dtype=float)
    require(origin.shape==red["q"].shape and np.isfinite(origin).all(),"Scaled primary finite origin")
    c=qp["reduced_task_matrix"];d=scale*(qp["reduced_task_target"]-c @ origin)
    lower=scale*(red["lower"]-red["A"] @ origin);upper=scale*(red["upper"]-red["A"] @ origin)
    p,q,a,lo,hi=least.problem(c,d,red["A"],lower,upper)
    return dict(scale=scale,origin=origin.copy(),task_matrix=c,task_target=d,
        P=p,q=q,A=a,lower=lo,upper=hi,problem_sha256=problem_digest(p,q,a,lo,hi))

def encode_problem(value):
    return dict(scale=value["scale"],origin=value["origin"].tolist(),task_matrix=value["task_matrix"].tolist(),
        task_target=value["task_target"].tolist(),P=value["P"].tolist(),q=value["q"].tolist(),A=value["A"].tolist(),
        lower=[float(v) if np.isfinite(v) else None for v in value["lower"]],
        upper=[float(v) if np.isfinite(v) else None for v in value["upper"]],
        null_lower_means_negative_infinity=True,null_upper_means_positive_infinity=True,
        problem_sha256=value["problem_sha256"])

def mapped_solution(qp,correction,result):
    red=qp["reduced"];full=qp["full"]
    require(result["accepted"] is True and result["status"]=="solved"
        and result["problem_sha256"]==correction["problem_sha256"],"Scaled primary accepted correction identity")
    # A scaled solver certificate is necessary; it never replaces the original one.
    scaled=least.certificate(correction["task_matrix"],correction["task_target"],correction["A"],
        correction["lower"],correction["upper"],result["x"],result["y"])
    require(scaled==result["certificate"] and scaled["accepted"],"Scaled primary correction certificate")
    x=correction["origin"]+np.asarray(result["x"])/correction["scale"]
    y=np.asarray(result["y"])/correction["scale"]
    reduced=least.certificate(qp["reduced_task_matrix"],qp["reduced_task_target"],red["A"],red["lower"],red["upper"],x,y)
    fx=qp["transform"] @ x+qp["offset"];n=qp["base"]["n"]
    gradient=full["P"] @ fx+full["q"]+full["A"][n:].T @ y
    fy=np.r_[np.linalg.solve(full["A"][:n,:n].T,-gradient[:n]),y]
    cert=least.certificate(qp["task_matrix"],qp["task_target"],full["A"],full["lower"],full["upper"],fx,fy)
    return dict(accepted=bool(reduced["accepted"] and cert["accepted"]),full_x=fx,full_y=fy,full_certificate=cert,
        full_problem_sha256=problem_digest(full["P"],full["q"],full["A"],full["lower"],full["upper"]),
        reduced=dict(result,x=x,y=y,certificate=reduced,accepted=reduced["accepted"],
            problem_sha256=problem_digest(red["P"],red["q"],red["A"],red["lower"],red["upper"]),
            solution_origin="mapped affine scaled correction",correction_problem_sha256=result["problem_sha256"]))

def strict(value):
    guard=parameters()["primary_feasibility_absolute_guard"]
    return bool(value["accepted"] and value["reduced"]["certificate"]["maximum_bound_violation"]<=guard
        and value["full_certificate"]["maximum_bound_violation"]<=guard)

def solve_priority(qp):
    initial=previous.initial_priority(qp);corrections=[]
    if strict(initial):
        return dict(initial,initial_primary=initial,primary_selection_mode="certified_seed",
            scaled_corrections=corrections,qp_solves=1)
    result=dict(initial,accepted=False,full_x=None,full_y=None,full_certificate=None,
        initial_primary=initial,primary_selection_mode="refused",scaled_corrections=corrections,qp_solves=1)
    if not initial["accepted"]:return result
    current=initial
    for exponent in parameters()["scale_exponents"]:
        correction=correction_problem(qp,current["reduced"]["x"],exponent)
        solved=solver.solve(correction["task_matrix"],correction["task_target"],correction["A"],correction["lower"],correction["upper"])
        report=dict(exponent=exponent,problem=encode_problem(correction),solver=solved,mapped=None,strict_guard_passed=False)
        corrections.append(report);result["qp_solves"]=1+len(corrections)
        if not solved["accepted"]:continue
        mapped=mapped_solution(qp,correction,solved);report["mapped"]=mapped
        report["strict_guard_passed"]=strict(mapped)
        if report["strict_guard_passed"]:
            return dict(mapped,initial_primary=initial,primary_selection_mode="scaled_correction",
                scaled_corrections=corrections,qp_solves=1+len(corrections))
        if mapped["accepted"]:current=mapped
    return result
