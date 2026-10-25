"""Invertible Hessian conditioning for the unchanged contact-first secondary QP."""
import copy
import numpy as np
import actuation_recovery_mechanics as m
import hierarchical_nullspace_component as parent
import switching_contact_component as switching

priority_problem=parent.priority_problem
solve_priority=parent.solve_priority
verify=parent.verify

def parameters():
    p=parent.parameters()
    p.update(secondary_conditioning="inverse transpose of the reduced Hessian Cholesky factor",
        secondary_regularization=0.,original_objective_and_bounds_preserved=True)
    return p

def condition(qp):
    q=copy.deepcopy(qp);old=q["reduced"];p=old["P"]
    # If p = L L^T, the invertible substitution z = L^-T w preserves the QP.
    factor=np.linalg.cholesky(p);change=np.linalg.solve(factor.T,np.eye(len(p)))
    reduced=dict(P=change.T @ p @ change,q=change.T @ old["q"],A=old["A"] @ change,
        lower=old["lower"].copy(),upper=old["upper"].copy())
    reduced["P"]=(reduced["P"]+reduced["P"].T)/2.
    identity_error=float(np.max(np.abs(reduced["P"]-np.eye(len(p))),initial=0.))
    inverse_error=float(np.max(np.abs(factor.T @ change-np.eye(len(p))),initial=0.))
    m.require(identity_error<=1e-7 and inverse_error<=1e-10,"Conditioning invertible objective congruence")
    transform=q["transform"] @ change
    equality_error=float(np.max(np.abs(q["full"]["A"][q["equality_indices"]] @ transform),initial=0.))
    m.require(equality_error<=1e-10,"Conditioning preserves original equalities")
    q.update(reduced=reduced,transform=transform,coordinate_change=change,
        maximum_nullspace_equality_error=equality_error,
        conditioning=dict(original_hessian_condition_number=float(np.linalg.cond(p)),
            conditioned_hessian_condition_number=float(np.linalg.cond(reduced["P"])),
            maximum_identity_error=identity_error,maximum_inverse_error=inverse_error))
    return q

def build_secondary(base,pattern,primary):
    return condition(parent.build_secondary(base,pattern,primary))

def solve_secondary(qp):
    result=parent.solve_secondary(qp)
    result["conditioning"]=qp["conditioning"]
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
            attempts.append(switching.document(second,secondary,"secondary_conditioned:"+origin))
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
