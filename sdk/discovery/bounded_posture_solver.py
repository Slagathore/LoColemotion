"""Bounded hierarchical linear references; no physical-feasibility certificate."""
import numpy as np
from actuation_recovery_mechanics import array,require

RCOND=1e-10
TOL=2e-9


def matrix(value,n,label):
    v=np.asarray(value,dtype=float)
    require(v.ndim==2 and v.shape[1]==n and np.isfinite(v).all(),label)
    return v


def nullspace(a,reference_scale=0.):
    """SVD basis with a declared relative rank threshold, including empty matrices."""
    n=a.shape[1]
    if not len(a):return np.eye(n),dict(rank=0,singular_values=[],cutoff=0.)
    _,s,v=np.linalg.svd(a,full_matrices=True)
    cutoff=RCOND*max(a.shape)*max(float(s[0]),reference_scale) if len(s) else 0.
    rank=int(np.sum(s>cutoff))
    return v[rank:].T,dict(rank=rank,singular_values=s.tolist(),cutoff=cutoff)


def least_squares(a,b,reference_scale=0.):
    z,info=nullspace(a,reference_scale)
    if not len(a) or not info["rank"]:return np.zeros(a.shape[1])
    u,s,v=np.linalg.svd(a,full_matrices=False);rank=info["rank"]
    return v[:rank].T @ ((u[:,:rank].T @ b)/s[:rank])


def bounded_least_squares(a,b,e,d,lower,upper,initial,max_iterations=256):
    """Feasible active-set least squares, with equality and box KKT witnesses.

    Every active bound is independent modulo the equalities. Negative bound
    multipliers release a bound; reaching a face alone is not optimality.
    """
    initial=np.asarray(initial);n=initial.size
    x=array(initial,(n,),"Posture initial");require(n>0,"Posture nonempty variables")
    a=matrix(a,n,"Posture task matrix");e=matrix(e,n,"Posture equality matrix")
    b=array(b,(len(a),),"Posture task target");d=array(d,(len(e),),"Posture equality target")
    lower=array(lower,(n,),"Posture lower bounds");upper=array(upper,(n,),"Posture upper bounds")
    require((lower<=upper).all() and (x>=lower-TOL).all() and (x<=upper+TOL).all()
        and np.max(np.abs(e@x-d),initial=0.)<=TOL,"Posture feasible initial/reference bounds")
    require(type(max_iterations) is int and max_iterations>0,"Posture finite iteration limit")
    free,eq_rank=nullspace(e);active=[];added=released=0
    for iteration in range(1,max_iterations+1):
        g=np.array([sign*np.eye(n)[j] for j,sign in active]).reshape(-1,n)
        constraints=np.vstack((e,g));z,rank=nullspace(constraints)
        # A constrained-away task must not regain rank from SVD roundoff.
        # Compare projected singular values with the original task scale.
        task_scale=float(np.linalg.norm(a,2)) if a.size else 0.
        p=z @ least_squares(a@z,b-a@x,task_scale)
        if np.max(np.abs(p),initial=0.)>1e-11:
            alpha=1.;blocking=None
            for j in range(n):
                # A coordinate fixed by the current equality space cannot add
                # an independent box face. Ignore its SVD roundoff direction.
                if np.linalg.norm(z[j])<=RCOND*max(constraints.shape) or abs(p[j])<=1e-13:continue
                sign=1 if p[j]>0 else -1
                distance=(upper[j]-x[j]) if sign==1 else (lower[j]-x[j])
                ratio=max(0.,float(distance/p[j]))
                if ratio<alpha-1e-13 and (j,sign) not in active:alpha=ratio;blocking=(j,sign)
            x=x+alpha*p
            require(np.max(np.abs(e@x-d),initial=0.)<=TOL and (x>=lower-TOL).all()
                and (x<=upper+TOL).all(),"Posture feasible step")
            if blocking is not None:
                old_rank=rank["rank"];active.append(blocking)
                _,new_rank=nullspace(np.vstack((constraints,blocking[1]*np.eye(n)[blocking[0]])))
                require(new_rank["rank"]==old_rank+1,"Posture independent blocking bound")
                added+=1;continue
        gradient=a.T@(a@x-b)
        projected=g@free
        multipliers=least_squares(projected.T,-free.T@gradient) if active else np.zeros(0)
        stationarity=free.T@(gradient+g.T@multipliers)
        require(np.max(np.abs(stationarity),initial=0.)<=TOL*(1.+np.linalg.norm(gradient)),
            "Posture stationarity witness")
        if len(multipliers) and float(np.min(multipliers)) < -TOL:
            active.pop(int(np.argmin(multipliers)));released+=1;continue
        return dict(solution=x,task_residual=a@x-b,objective=float(np.sum((a@x-b)**2)),
            equality_residual=e@x-d,active_bounds=[dict(index=j,side="upper" if sign==1 else "lower") for j,sign in active],
            bound_multipliers=multipliers,projected_stationarity=stationarity,
            iterations=iteration,bounds_added=added,bounds_released=released,equality_rank=eq_rank,
            global_linear_box_optimum_verified=True,dynamic_feasibility_established=False)
    raise ValueError("Posture bounded solve did not converge within declared iterations")


def hierarchy(contact,tasks,lower,upper,scale):
    """Freeze each achieved task image before solving the next lower priority."""
    n=len(scale);scale=array(scale,(n,),"Posture variable scale")
    require((scale>0).all(),"Posture positive scale")
    lower=array(lower,(n,),"Posture physical lower")/scale
    upper=array(upper,(n,),"Posture physical upper")/scale
    e=matrix(contact,n,"Posture contact matrix")*scale
    d=np.zeros(len(e));x=np.zeros(n);reports=[]
    for name,jacobian,error in tasks:
        a=matrix(jacobian,n,"Posture hierarchy task")*scale
        b=array(error,(len(a),),"Posture hierarchy error")
        before=x.copy();basis,rank=nullspace(e)
        _,attainable=nullspace(a@basis,float(np.linalg.norm(a,2)) if a.size else 0.)
        result=bounded_least_squares(a,b,e,d,lower,upper,x);x=result["solution"]
        require(np.max(np.abs(e@(x-before)),initial=0.)<=TOL,"Posture earlier task changed")
        reports.append(dict(name=name,attainable_rank=attainable["rank"],**result))
        e=np.vstack((e,a));d=np.r_[d,a@x]
    return dict(delta=scale*x,tasks=reports,linear_contact_residual=matrix(contact,n,"Posture contact")@(scale*x),
        contact_rank=nullspace(matrix(contact,n,"Posture contact")*scale)[1],
        reference_only=True,nonlinear_priority_guaranteed=False,dynamic_feasibility_established=False)
