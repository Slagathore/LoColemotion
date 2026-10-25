"""Bounded contact-force least squares, including rank-deficient support.

The objective penalizes wrench error and instantaneous actuator infeasibility.
Projection guarantees the declared force cones, not realizable body motion.
"""
import numpy as np
import numbers
from actuation_recovery_mechanics import array as numeric_array, require


def array(value,shape,label):
    raw=np.asarray(value,dtype=object)
    require(all(isinstance(v,numbers.Real) and not isinstance(v,(bool,np.bool_)) for v in raw.flat),label+" numeric types")
    return numeric_array(value,shape,label)


def cross_matrix(v):
    x,y,z=array(v,(3,),"Allocator moment arm")
    return np.array([[0.,-z,y],[z,0.,-x],[-y,x,0.]])


def project_force(force,normal,friction,cap):
    """Euclidean projection onto 0 <= n.f <= cap, ||f_t|| <= mu*n.f."""
    f=array(force,(3,),"Allocator force");n=array(normal,(3,),"Allocator normal")
    require(abs(float(n @ n)-1.)<1e-12,"Allocator unit normal")
    parameters=array([friction,cap],(2,),"Allocator cone parameters")
    require((parameters>=0).all(),"Allocator nonnegative cone parameters")
    z=float(f @ n);t=f-z*n;r=float(np.linalg.norm(t))
    # Minimize (h-z)^2 + max(0, r-mu*h)^2 over h in [0, cap].
    h=z if friction==0 or friction*z>=r else (z+friction*r)/(1.+friction**2)
    h=float(np.clip(h,0.,cap))
    return h*n+(t*min(1.,friction*h/r) if r>0 else np.zeros(3))


def allocate(points,normals,origin,desired,torque_map,torque_bias,lower,upper,
             previous,weights,friction,cap,regularization,actuation_weight,iterations):
    n=len(points);j=len(torque_bias)
    p=array(points,(n,3),"Allocator contact points");normals=array(normals,(n,3),"Allocator normals")
    origin=array(origin,(3,),"Allocator origin");desired=array(desired,(6,),"Allocator desired wrench")
    b=array(torque_map,(j,3*n),"Allocator torque map");bias=array(torque_bias,(j,),"Allocator torque bias")
    lower=array(lower,(j,),"Allocator lower torque");upper=array(upper,(j,),"Allocator upper torque")
    prior=array(previous,(n,3),"Allocator force history").reshape(-1)
    weights=array(weights,(6,),"Allocator objective weights")
    parameters=array([regularization,actuation_weight],(2,),"Allocator objective parameters")
    require((weights>0).all() and regularization>0 and actuation_weight>=0
        and (lower<=upper).all() and type(iterations) is int and 1<=iterations<=1000,
        "Allocator bounds/iteration budget")
    a=np.zeros((6,3*n))
    for i,point in enumerate(p):a[:,3*i:3*i+3]=np.vstack((np.eye(3),cross_matrix(point-origin)))
    wa=weights[:,None]*a;wd=weights*desired
    def project(x):
        return np.array([project_force(f,normal,friction,cap)
            for f,normal in zip(x.reshape(n,3),normals,strict=True)]).reshape(-1)
    def objective(x):
        torque=bias+b @ x;violation=torque-np.clip(torque,lower,upper)
        error=wa @ x-wd
        return .5*float(error @ error+regularization*((x-prior) @ (x-prior))
            +actuation_weight*(violation @ violation))
    if n:
        hessian_bound=wa.T @ wa+regularization*np.eye(3*n)+actuation_weight*(b.T @ b)
        lipschitz=float(np.linalg.eigvalsh(hessian_bound)[-1]);x=project(prior)
        initial=objective(x)
        def gradient(x):
            torque=bias+b @ x
            return wa.T @ (wa @ x-wd)+regularization*(x-prior)+actuation_weight*b.T @ (torque-np.clip(torque,lower,upper))
        for _ in range(iterations):x=project(x-gradient(x)/lipschitz)
        residual=lipschitz*float(np.linalg.norm(x-project(x-gradient(x)/lipschitz)))
    else:
        # Flight retains the unsatisfied wrench and actuator residuals explicitly.
        x=np.empty(0);initial=objective(x);residual=0.;lipschitz=0.
    final=objective(x)
    require(np.isfinite(x).all() and np.isfinite(final) and final<=initial+1e-10*max(1.,initial),
        "Allocator nonfinite/nondecreasing objective")
    torque=bias+b @ x
    return dict(forces=x.reshape(n,3),requested_torque=torque,
        wrench=a @ x,wrench_error=a @ x-desired,
        torque_interval_violation=torque-np.clip(torque,lower,upper),
        initial_objective=initial,final_objective=final,iterations=iterations if n else 0,
        projected_gradient_norm=residual,lipschitz_bound=lipschitz,
        wrench_map_rank=int(np.linalg.matrix_rank(a)) if n else 0,
        dynamic_feasibility_established=False,optimality_certified=False)
