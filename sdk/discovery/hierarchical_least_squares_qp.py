"""Convex least-squares QP, including rank-deficient tasks, with existing KKT tolerances.

The Hessian is constructed as C.T @ C. No diagonal jitter or weighted
approximation to a task hierarchy is introduced.
"""
import numpy as np
import osqp
from scipy import sparse
from actuation_recovery_mechanics import array,require
from dynamic_qp_solver_v2 import settings,problem_digest,validate as validate_bounds

def problem(c,d,a,lower,upper):
    c=np.asarray(c,dtype=float)
    require(c.ndim==2 and c.shape[1]>0,"Least-squares task matrix shape")
    c=array(c,c.shape,"Least-squares finite task")
    d=array(d,(c.shape[0],),"Least-squares finite target")
    n=c.shape[1];p=array(c.T @ c,(n,n),"Least-squares Gram Hessian");q=-c.T @ d
    _,q,a,lower,upper=validate_bounds(np.eye(n),q,a,lower,upper)
    return p,q,a,lower,upper

def certificate(c,d,a,lower,upper,x,y):
    p,q,a,lower,upper=problem(c,d,a,lower,upper)
    x=array(x,(len(q),),"QP solution");y=array(y,(len(lower),),"QP dual solution")
    value=a @ x
    violation=np.maximum(np.maximum(lower-value,value-upper),0.)
    primal=float(np.max(violation,initial=0.))
    stationarity=p @ x+q+a.T @ y
    scale=max(1.,float(np.max(np.abs(p @ x),initial=0.)),float(np.max(np.abs(q),initial=0.)),
        float(np.max(np.abs(a.T @ y),initial=0.)))
    dual=float(np.max(np.abs(stationarity),initial=0.))
    products=[];wrong=[]
    for i,dual_value in enumerate(y):
        if lower[i]==upper[i]:continue
        bound=upper[i] if dual_value>=0 else lower[i]
        if np.isfinite(bound):products.append(abs(float(dual_value*(value[i]-bound))))
        else:wrong.append(abs(float(dual_value)))
    complementarity=max(products,default=0.);unbounded_dual=max(wrong,default=0.)
    # Bounds are checked in original physical coordinates, not scaled solver coordinates.
    accepted=primal<=2e-6 and dual<=1e-6+1e-8*scale and complementarity<=2e-6+1e-8*scale and unbounded_dual<=1e-8
    return dict(accepted=bool(accepted),maximum_bound_violation=primal,maximum_stationarity_error=dual,
        stationarity_scale=scale,maximum_complementarity_error=complementarity,
        maximum_dual_on_unbounded_side=unbounded_dual,primal_absolute_tolerance=2e-6,
        stationarity_absolute_tolerance=1e-6,relative_tolerance=1e-8)


def solve(c,d,a,lower,upper):
    p,q,a,lower,upper=problem(c,d,a,lower,upper)
    solver=osqp.OSQP(algebra="builtin")
    solver.setup(P=sparse.csc_matrix(np.triu(p)),q=q,A=sparse.csc_matrix(a),l=lower,u=upper,**settings())
    result=solver.solve(raise_error=False);info=result.info
    report=dict(status=info.status,status_value=int(info.status_val),iterations=int(info.iter),
        polishing_status=int(info.status_polish),problem_sha256=problem_digest(p,q,a,lower,upper),
        backend="OSQP builtin CPU",settings=settings(),accepted=False,
        hessian_source="exact least-squares Gram matrix; no regularization")
    if info.status_val!=1:return dict(report,x=None,y=None,certificate=None)
    cert=certificate(c,d,a,lower,upper,result.x,result.y)
    return dict(report,accepted=cert["accepted"],x=np.array(result.x),y=np.array(result.y),certificate=cert)
