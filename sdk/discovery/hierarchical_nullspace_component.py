"""Equivalent secondary optimization in the support-preserving nullspace."""
import numpy as np
import actuation_recovery_mechanics as m
import hierarchical_contact_component as parent
import switching_contact_component as switching
from dynamic_qp_solver_v2 import solve,certificate,problem_digest

priority_problem=parent.priority_problem
solve_priority=parent.solve_priority
verify=parent.verify

def parameters():
    p=parent.parameters()
    p.update(secondary_coordinates="nullspace of dynamics and attained support equalities",
        nullspace_rank_rule="machine epsilon times maximum matrix dimension times largest singular value",
        secondary_full_duals_reconstructed=True)
    return p

def build_secondary(base,pattern,primary):
    qp=switching.build(parent.freeze_contact(base,primary["full_x"]),pattern,True)
    full=qp["full"];n=base["n"];old_transform=qp["transform"]
    support=[i for i,name in enumerate(full["row_names"]) if name.startswith("support_")]
    eq=list(range(n))+support;eq_set=set(eq);remaining=[i for i in range(len(full["lower"])) if i not in eq_set]
    c=full["A"][support] @ old_transform;ny=old_transform.shape[1]
    if support:
        _,singular,vh=np.linalg.svd(c,full_matrices=True)
        tolerance=np.finfo(float).eps*max(c.shape)*singular[0]
        rank=int(np.count_nonzero(singular>tolerance));null=vh[rank:].T
    else:singular=np.zeros(0);tolerance=0.;rank=0;null=np.eye(ny)
    transform=old_transform @ null;offset=primary["full_x"].copy()
    m.require(transform.shape[1]>0,"Nullspace nonempty secondary coordinates")
    equality=full["A"][eq]
    error=float(np.max(np.abs(equality @ transform),initial=0.))
    origin_error=float(np.max(np.abs(equality @ offset-full["lower"][eq]),initial=0.))
    m.require(error<=1e-10 and origin_error<=1e-9,"Nullspace exact original equalities")
    red=dict(P=transform.T @ full["P"] @ transform,q=transform.T @ (full["P"] @ offset+full["q"]),
        A=full["A"][remaining] @ transform,lower=full["lower"][remaining]-full["A"][remaining] @ offset,
        upper=full["upper"][remaining]-full["A"][remaining] @ offset)
    red["P"]=(red["P"]+red["P"].T)/2.
    qp.update(reduced=red,transform=transform,offset=offset,equality_indices=eq,remaining_indices=remaining,
        support_rank=rank,support_singular_values=singular,rank_tolerance=tolerance,
        maximum_nullspace_equality_error=error,maximum_origin_equality_error=origin_error)
    return qp

def solve_secondary(qp):
    f=qp["full"];red=qp["reduced"];r=solve(red["P"],red["q"],red["A"],red["lower"],red["upper"])
    result=dict(reduced=r,accepted=False,full_x=None,full_y=None,full_certificate=None,
        full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]),
        support_rank=qp["support_rank"],support_singular_values=qp["support_singular_values"],
        rank_tolerance=qp["rank_tolerance"],maximum_nullspace_equality_error=qp["maximum_nullspace_equality_error"],
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
            attempts.append(switching.document(second,secondary,"secondary_nullspace:"+origin))
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
