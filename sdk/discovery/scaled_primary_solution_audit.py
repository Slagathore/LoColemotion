"""Reconstruct affine correction evidence without invoking the producer or a QP solver."""
import copy
import numpy as np
import hierarchical_least_squares_qp as least
from dynamic_qp_solver_v2 import problem_digest
from causal_force_policy import plain
from audit_gpu_batch_execution import same_bits
from actuation_recovery_mechanics import require


def solver_record(c,d,a,lower,upper,r,settings):
    p,q,a,lower,upper=least.problem(c,d,a,lower,upper)
    require(type(r["accepted"]) is bool and r["backend"]=="ProxQP 0.7.2 generic dense PrimalDualLDLT"
        and r["settings"]==settings and r["initial_guess"]=="NO_INITIAL_GUESS"
        and r["hessian_source"]=="exact least-squares Gram matrix; no regularization"
        and r["problem_sha256"]==problem_digest(p,q,a,lower,upper)
        and type(r["iterations"]) is int and 0<=r["iterations"]<=settings["max_iter"],
        "Scaled reader solver identity and work")
    if r["status"]=="solved":
        cert=least.certificate(c,d,a,lower,upper,r["x"],r["y"])
        require(cert==r["certificate"] and r["accepted"] is cert["accepted"],"Scaled reader solver certificate")
    else:
        require(r["accepted"] is False and all(r[k] is None for k in ("x","y","certificate")),
            "Scaled reader non-solved refusal")


def full_solution(qp,reduced):
    f=qp["full"];n=qp["base"]["n"]
    x=qp["transform"] @ np.asarray(reduced["x"])+qp["offset"]
    gradient=f["P"] @ x+f["q"]+f["A"][n:].T @ np.asarray(reduced["y"])
    y=np.r_[np.linalg.solve(f["A"][:n,:n].T,-gradient[:n]),reduced["y"]]
    cert=least.certificate(qp["task_matrix"],qp["task_target"],f["A"],f["lower"],f["upper"],x,y)
    return dict(reduced=reduced,accepted=bool(reduced["accepted"] and cert["accepted"]),
        full_x=x,full_y=y,full_certificate=cert,
        full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]))


def initial_record(qp,record,settings):
    r=record["reduced"];b=qp["reduced"];f=qp["full"]
    solver_record(qp["reduced_task_matrix"],qp["reduced_task_target"],b["A"],b["lower"],b["upper"],r,settings)
    expected=full_solution(qp,r) if r["accepted"] else dict(reduced=r,accepted=False,full_x=None,full_y=None,
        full_certificate=None,full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]))
    require(same_bits(plain(expected),plain(record)),"Scaled reader initial full reconstruction")
    return expected


def strict(value):
    return bool(value["accepted"] and value["reduced"]["certificate"]["maximum_bound_violation"]<=1e-12
        and value["full_certificate"]["maximum_bound_violation"]<=1e-12)


def verify_primary(qp,record,settings):
    p=settings["primary_refinement"]
    require(p["scale_exponents"]==[20,30,40] and p["maximum_corrections"]==3
        and p["maximum_primary_qp_solves"]==4 and p["primary_feasibility_absolute_guard"]==1e-12
        and p["objective_regularization"]==0. and p["arithmetic"]=="float64"
        and p["arbitrary_precision_established"] is False and p["acceptance_tolerances_changed"] is False
        and p["initial_seed_requires_original_certificates"] is True,"Scaled reader immutable correction domain")
    initial=initial_record(qp,record["initial_primary"],settings["priority"])
    corrections=record["scaled_corrections"]
    require(type(record["qp_solves"]) is int and record["qp_solves"]==1+len(corrections)<=4,
        "Scaled reader complete inner work count")
    expected=dict(initial,accepted=False,full_x=None,full_y=None,full_certificate=None,
        initial_primary=initial,primary_selection_mode="refused",scaled_corrections=corrections,qp_solves=1+len(corrections))
    if strict(initial):
        require(not corrections,"Scaled reader strict seed has no correction")
        expected=dict(initial,initial_primary=initial,primary_selection_mode="certified_seed",scaled_corrections=[],qp_solves=1)
    elif not initial["accepted"]:
        require(not corrections,"Scaled reader refused initial cannot start correction")
    else:
        current=initial;finished=False;red=qp["reduced"];c=qp["reduced_task_matrix"]
        for index,item in enumerate(corrections):
            require(not finished and type(item["exponent"]) is int and item["exponent"]==[20,30,40][index],
                "Scaled reader exact correction sequence")
            scale=float(2**item["exponent"]);origin=np.asarray(current["reduced"]["x"])
            target=scale*(qp["reduced_task_target"]-c @ origin)
            lower=scale*(red["lower"]-red["A"] @ origin);upper=scale*(red["upper"]-red["A"] @ origin)
            h,g,a,lo,hi=least.problem(c,target,red["A"],lower,upper)
            encoded=dict(scale=scale,origin=origin,task_matrix=c,task_target=target,P=h,q=g,A=a,
                lower=[float(x) if np.isfinite(x) else None for x in lo],
                upper=[float(x) if np.isfinite(x) else None for x in hi],
                null_lower_means_negative_infinity=True,null_upper_means_positive_infinity=True,
                problem_sha256=problem_digest(h,g,a,lo,hi))
            require(same_bits(plain(encoded),item["problem"]),"Scaled reader independent affine problem")
            solved=item["solver"];solver_record(c,target,a,lo,hi,solved,settings["priority"])
            if not solved["accepted"]:
                require(item["mapped"] is None and item["strict_guard_passed"] is False,"Scaled reader correction refusal")
                continue
            x=origin+np.asarray(solved["x"])/scale;y=np.asarray(solved["y"])/scale
            cert=least.certificate(c,qp["reduced_task_target"],red["A"],red["lower"],red["upper"],x,y)
            reduced=dict(solved,x=x,y=y,certificate=cert,accepted=cert["accepted"],
                problem_sha256=problem_digest(red["P"],red["q"],red["A"],red["lower"],red["upper"]),
                solution_origin="mapped affine scaled correction",correction_problem_sha256=solved["problem_sha256"])
            mapped=full_solution(qp,reduced)
            require(same_bits(plain(mapped),item["mapped"]) and item["strict_guard_passed"] is strict(mapped),
                "Scaled reader original primal dual mapping and strict guards")
            if strict(mapped):
                finished=True
                expected=dict(mapped,initial_primary=initial,primary_selection_mode="scaled_correction",
                    scaled_corrections=corrections,qp_solves=1+len(corrections))
            elif mapped["accepted"]:current=mapped
        require(finished or len(corrections)==3,"Scaled reader complete refused correction budget")
    require(same_bits(plain(expected),plain(record)),"Scaled reader exact primary selection")
    return record["qp_solves"]
