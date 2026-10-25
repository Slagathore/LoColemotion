"""Tighter OSQP convergence with unchanged original-coordinate acceptance.

The consumed v1 complementarity refusal stays immutable.
"""
import hashlib,json
import numpy as np
import osqp
from scipy import sparse
from actuation_recovery_mechanics import array,require


def settings():
    return dict(verbose=False,warm_starting=False,polishing=True,scaling=10,
        adaptive_rho=True,adaptive_rho_interval=50,adaptive_rho_tolerance=5.,
        max_iter=20000,eps_abs=1e-11,eps_rel=1e-11,eps_prim_inf=1e-8,eps_dual_inf=1e-8,
        check_termination=25,scaled_termination=False,polish_refine_iter=3)


def validate(p,q,a,lower,upper):
    q=np.asarray(q);n=len(q);require(n>0,"QP nonempty variables")
    p=array(p,(n,n),"QP Hessian");q=array(q,(n,),"QP linear objective")
    lower=np.asarray(lower,dtype=float);upper=np.asarray(upper,dtype=float);m=len(lower)
    require(lower.shape==upper.shape==(m,) and not np.isnan(lower).any() and not np.isnan(upper).any()
        and not np.isposinf(lower).any() and not np.isneginf(upper).any() and np.all(lower<=upper),"QP valid bounds")
    a=array(a,(m,n),"QP constraint matrix")
    require(np.allclose(p,p.T,atol=1e-12,rtol=1e-12),"QP symmetric Hessian")
    np.linalg.cholesky(p)
    return p,q,a,lower,upper


def problem_digest(p,q,a,lower,upper):
    document=dict(P=p.tolist(),q=q.tolist(),A=a.tolist(),
        lower=[float(v) if np.isfinite(v) else None for v in lower],
        upper=[float(v) if np.isfinite(v) else None for v in upper],
        null_lower_means_negative_infinity=True,null_upper_means_positive_infinity=True)
    return hashlib.sha256(json.dumps(document,sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest()


def certificate(p,q,a,lower,upper,x,y):
    p,q,a,lower,upper=validate(p,q,a,lower,upper)
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


def solve(p,q,a,lower,upper):
    p,q,a,lower,upper=validate(p,q,a,lower,upper)
    solver=osqp.OSQP(algebra="builtin")
    solver.setup(P=sparse.csc_matrix(np.triu(p)),q=q,A=sparse.csc_matrix(a),l=lower,u=upper,**settings())
    result=solver.solve(raise_error=False);info=result.info
    report=dict(status=info.status,status_value=int(info.status_val),iterations=int(info.iter),
        polishing_status=int(info.status_polish),problem_sha256=problem_digest(p,q,a,lower,upper),
        backend="OSQP builtin CPU",settings=settings(),accepted=False)
    # An inaccurate solve or infeasibility report is never promoted to a command.
    if info.status_val!=1:return dict(report,x=None,y=None,certificate=None)
    cert=certificate(p,q,a,lower,upper,result.x,result.y)
    return dict(report,accepted=cert["accepted"],x=np.array(result.x),y=np.array(result.y),certificate=cert)
