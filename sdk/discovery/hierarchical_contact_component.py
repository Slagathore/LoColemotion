"""Contact-first least squares, then posture, under hard physical command limits.

The contact target may be unattainable. Its optimal attained vector is frozen
before secondary objectives are optimized, within one certified motor pattern.
"""
import copy
import numpy as np
import actuation_recovery_mechanics as m
import switching_contact_component as switching
import hierarchical_least_squares_qp as least
from dynamic_qp_solver_v2 import problem_digest

def parameters():
    p=switching.parameters()
    p.update(support_constraint="first minimize unweighted supporting-point acceleration error; then freeze attained vector",
        contact_target_is_hard=False,hard_motor_joint_force_bounds=True,
        hierarchy_scope="within selected five-step motor pattern",
        selection="first certified two-level hierarchy",objective_regularization_at_first_level=0.)
    return p

def without_contact(base):
    b=dict(base);indices=[i for i,name in enumerate(base["row_names"]) if not name.startswith("support_")]
    b.update(A=base["A"][indices],lower=base["lower"][indices],upper=base["upper"][indices],
        row_names=[base["row_names"][i] for i in indices])
    return b

def priority_problem(base,pattern,strict=True):
    m.require(base["mode"]=="combined","Hierarchy requires hard joint and motor bounds")
    qp=switching.build(without_contact(base),pattern,strict);n=base["n"];count=len(qp["full"]["q"])
    tasks=base["support"];c=np.zeros((3*len(tasks),count))
    if tasks:c[:,:n]=np.vstack([t["jacobian"] for t in tasks])
    d=np.concatenate([t["target"]-t["bias"] for t in tasks]) if tasks else np.zeros(0)
    cr=c @ qp["transform"];dr=d-c @ qp["offset"]
    qp["full"]=dict(qp["full"],P=c.T @ c,q=-c.T @ d)
    qp["reduced"]=dict(qp["reduced"],P=cr.T @ cr,q=-cr.T @ dr)
    qp.update(task_matrix=c,task_target=d,reduced_task_matrix=cr,reduced_task_target=dr)
    return qp

def solve_priority(qp):
    f=qp["full"];red=qp["reduced"]
    r=least.solve(qp["reduced_task_matrix"],qp["reduced_task_target"],red["A"],red["lower"],red["upper"])
    result=dict(reduced=r,accepted=False,full_x=None,full_y=None,full_certificate=None,
        full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]))
    if not r["accepted"]:return result
    x=qp["transform"] @ r["x"]+qp["offset"];n=qp["base"]["n"]
    gradient=f["P"] @ x+f["q"]+f["A"][n:].T @ r["y"]
    y=np.r_[np.linalg.solve(f["A"][:n,:n].T,-gradient[:n]),r["y"]]
    cert=least.certificate(qp["task_matrix"],qp["task_target"],f["A"],f["lower"],f["upper"],x,y)
    result.update(accepted=cert["accepted"],full_x=x,full_y=y,full_certificate=cert)
    return result

def freeze_contact(base,first):
    b=copy.deepcopy(base);n=base["n"]
    for task in b["support"]:
        attained=task["jacobian"] @ first[:n]
        indices=[i for i,name in enumerate(b["row_names"]) if name==task["name"]]
        m.require(len(indices)==3,"Hierarchy exact support equality rows")
        b["lower"][indices]=attained;b["upper"][indices]=attained
        task["target"]=attained+task["bias"]
    return b

def verify(first,primary,second,secondary):
    m.require(first["strict"] and primary["accepted"] and secondary["accepted"],
        "Hierarchy only accepts two strict certified stages")
    f=first["full"];c=first["task_matrix"];d=first["task_target"]
    cert=least.certificate(c,d,f["A"],f["lower"],f["upper"],primary["full_x"],primary["full_y"])
    m.require(cert==primary["full_certificate"] and cert["accepted"],"Hierarchy independent first-stage certificate")
    prediction=switching.verify(second,secondary)
    optimum=c @ primary["full_x"];attained=c @ secondary["full_x"]
    error=float(np.max(np.abs(optimum-attained),initial=0.))
    actual=c[:,:first["base"]["n"]] @ prediction["predicted_steps"][0]["acceleration"]
    transferred_error=float(np.max(np.abs(optimum-actual),initial=0.))
    m.require(error<=2e-6 and transferred_error<=2e-6,"Hierarchy secondary task worsened attained support vector")
    prediction.update(requested_support_vector=d,optimal_support_vector=optimum,attained_support_vector=actual,
        requested_support_error=actual-d,optimal_support_error=optimum-d,
        maximum_priority_preservation_error=error,maximum_transferred_priority_error=transferred_error,
        nonzero_contact_error_is_permitted=True,exact_requested_contact_target_established=False,
        optimality_scope="within selected saturation pattern")
    return prediction

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
            second=switching.build(freeze_contact(base,r["full_x"]),pattern,True)
            secondary=switching.solve_pattern(second)
            attempts.append(switching.document(second,secondary,"secondary_strict:"+origin))
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
