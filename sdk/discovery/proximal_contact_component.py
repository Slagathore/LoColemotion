"""Contact-first hierarchy with a pinned dense secondary optimizer."""
import numpy as np
import actuation_recovery_mechanics as m
import hierarchical_contact_component as parent
import switching_contact_component as switching
import proximal_qp_solver as proximal
from dynamic_qp_solver_v2 import certificate,problem_digest,settings as priority_settings

priority_problem=parent.priority_problem
solve_priority=parent.solve_priority
freeze_contact=parent.freeze_contact
verify=parent.verify

def parameters():
    p=parent.parameters()
    p.update(secondary_backend="ProxQP 0.7.2 dense PrimalDualLDLT",
        secondary_coordinates="initial dynamics eliminated; attained support equalities retained",
        closest_feasible_relaxation=False,original_full_coordinate_acceptance_unchanged=True)
    return p

def solver_settings():
    return dict(priority=priority_settings(),secondary=proximal.settings(),
        secondary_backend="dense.PrimalDualLDLT",secondary_initial_guess="NO_INITIAL_GUESS")

def solve_secondary(qp):
    red=qp["reduced"];full=qp["full"];r=proximal.solve(red["P"],red["q"],red["A"],red["lower"],red["upper"])
    result=dict(reduced=r,accepted=False,full_x=None,full_y=None,full_certificate=None,
        full_problem_sha256=problem_digest(full["P"],full["q"],full["A"],full["lower"],full["upper"]))
    if not r["accepted"]:return result
    x=qp["transform"] @ r["x"]+qp["offset"];n=qp["base"]["n"]
    gradient=full["P"] @ x+full["q"]+full["A"][n:].T @ r["y"]
    dual_equality=np.linalg.solve(full["A"][:n,:n].T,-gradient[:n])
    y=np.r_[dual_equality,r["y"]]
    cert=certificate(full["P"],full["q"],full["A"],full["lower"],full["upper"],x,y)
    result.update(accepted=cert["accepted"],full_x=x,full_y=y,full_certificate=cert)
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
            second=switching.build(freeze_contact(base,r["full_x"]),pattern,True)
            secondary=solve_secondary(second)
            attempts.append(switching.document(second,secondary,"secondary_proximal:"+origin))
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
