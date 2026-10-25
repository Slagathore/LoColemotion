"""Pinned dense ProxQP with unchanged independent physical-coordinate acceptance."""
import importlib.metadata as metadata
import numpy as np
from generic_proxqp_backend import load
proxsuite=load()
from dynamic_qp_solver_v2 import validate,certificate,problem_digest
from actuation_recovery_mechanics import require

def settings():
    return dict(verbose=False,compute_timings=False,max_iter=20000,max_iter_in=1500,
        eps_abs=1e-11,eps_rel=1e-11,check_duality_gap=True,
        eps_duality_gap_abs=1e-11,eps_duality_gap_rel=1e-11,
        eps_primal_inf=1e-8,eps_dual_inf=1e-8,primal_infeasibility_solving=False)

def solve(p,q,a,lower,upper):
    require(metadata.version("proxsuite")=="0.7.2" and metadata.version("cmeel")=="0.61.0",
        "ProxQP pinned development runtime")
    p,q,a,lower,upper=validate(p,q,a,lower,upper)
    equal=np.flatnonzero(lower==upper)
    inequality=np.flatnonzero((lower!=upper)&(np.isfinite(lower)|np.isfinite(upper)))
    solver=proxsuite.proxqp.dense.QP(len(q),len(equal),len(inequality),
        dense_backend=proxsuite.proxqp.dense.DenseBackend.PrimalDualLDLT)
    configured=settings()
    for key,value in configured.items():setattr(solver.settings,key,value)
    solver.settings.initial_guess=type(solver.settings.initial_guess).NO_INITIAL_GUESS
    solver.init(p,q,a[equal] if len(equal) else None,lower[equal] if len(equal) else None,
        a[inequality] if len(inequality) else None,lower[inequality] if len(inequality) else None,
        upper[inequality] if len(inequality) else None)
    solver.solve();r=solver.results;info=r.info
    status=info.status.name.lower().removeprefix("proxqp_").replace("_"," ")
    report=dict(status=status,status_value=info.status.value,iterations=int(info.iter),
        outer_iterations=int(info.iter_ext),problem_sha256=problem_digest(p,q,a,lower,upper),
        backend="ProxQP 0.7.2 generic dense PrimalDualLDLT",settings=configured,
        initial_guess="NO_INITIAL_GUESS",accepted=False,
        primal_residual=float(info.pri_res),dual_residual=float(info.dua_res),duality_gap=float(info.duality_gap))
    # A closest-feasible answer, exhausted solve or solver status alone cannot issue a command.
    if info.status!=type(info.status).PROXQP_SOLVED:return dict(report,x=None,y=None,certificate=None)
    x=np.array(r.x);y=np.zeros(len(lower));y[equal]=r.y;y[inequality]=r.z
    cert=certificate(p,q,a,lower,upper,x,y)
    return dict(report,accepted=cert["accepted"],x=x,y=y,certificate=cert)
