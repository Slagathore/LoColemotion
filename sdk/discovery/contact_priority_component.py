"""Contact-priority feasibility with a declared frozen five-step motor model.

This is a conditional component, not a deployed policy. The contact force,
inertia, bias and Jacobian are held fixed in predictions. Saturation regimes
must remain valid throughout the command; no measured future forces are used.
"""
import numpy as np
import actuation_recovery_mechanics as m
import dynamic_inverse_dynamics_v2 as old
from dynamic_qp_solver_v2 import solve,certificate

MODES=("motor","joint","contact","combined")

def parameters():
    return dict(timestep_s=1/600.,hold_steps=5,joint_speed_planning_cap_rad_s=3.5,
        joint_position_margin_rad=3.5/600.,regime_force_margin_nm=1e-5,
        support_constraint="initial integrated material-point acceleration equals existing damped target",
        regime_selection="fixed saturated if entire reachable interval is saturated, otherwise unsaturated",
        frozen_coefficients=True,constant_contact_force=True,
        future_contact_force_measured=False,recursive_feasibility_established=False,
        physical_acceptance_authority=False)

def held_maps(mass,damping,h,steps):
    n=len(damping);mass=m.array(mass,(n,n),"Priority inertia")
    damping=m.array(damping,(n,),"Priority motor derivative")
    m.require(n>=6 and np.all(damping>=0) and np.all(damping[:6]==0)
        and np.isfinite(h) and h>0 and type(steps) is int and steps>0,"Priority integration domain")
    m.require(np.allclose(mass,mass.T,atol=1e-12,rtol=0),"Priority symmetric inertia")
    np.linalg.cholesky(mass)
    effective=mass+h*np.diag(damping)
    recurrence=np.eye(n)-h*np.linalg.solve(effective,np.diag(damping))
    acceleration=np.eye(n);velocity=np.zeros((n,n));position=np.zeros((n,n));rows=[]
    for i in range(steps):
        before=velocity.copy();velocity+=h*acceleration;position+=h*velocity
        rows.append(dict(index=i,acceleration=acceleration.copy(),velocity_before=before,
            velocity_after=velocity.copy(),position=position.copy()))
        acceleration=recurrence @ acceleration
    return effective,rows

def motor_regimes(envelope,velocity,gains,ranges):
    gains=np.asarray(gains);j=len(gains)
    v=m.array(velocity,(j,),"Priority joint velocity")
    g=m.array(gains,(j,),"Priority gains");caps=m.array(ranges,(j,2),"Priority force caps")
    m.require(np.all(g>0) and np.all(caps[:,0]<0) and np.all(caps[:,1]>0),"Priority actuator domain")
    lo=m.array(envelope["lower_target"],(j,),"Priority reachable lower target")
    hi=m.array(envelope["upper_target"],(j,),"Priority reachable upper target")
    m.require(np.all(lo<=hi),"Priority ordered targets")
    raw_low=g*(lo-v);raw_high=g*(hi-v)
    regime=np.where(raw_low>=caps[:,1],1,np.where(raw_high<=caps[:,0],-1,0))
    damping=np.where(regime==0,g,0.)
    saturated=np.where(regime==1,caps[:,1],np.where(regime==-1,caps[:,0],0.))
    return regime,damping,saturated

def build(model,frame,velocity,gravity,joints,joint_ranges,items,active,envelope,gains,force_ranges,mode):
    m.require(mode in MODES,"Priority declared mode")
    p=parameters();n=model.size;j=model.n;k=len(active);count=n+3*k+j
    v=m.array(velocity,(n,),"Priority velocity");q=m.array(joints,(j,),"Priority joint positions")
    limits=m.array(joint_ranges,(j,2),"Priority joint ranges")
    m.require(np.all(limits[:,0]<limits[:,1]),"Priority ordered joint ranges")
    if np.any(q<limits[:,0]) or np.any(q>limits[:,1]):
        return dict(domain_refusal="native joint limit already active",mode=mode)
    mass=model.mass_matrix(frame);bias=model.inverse_dynamics(frame,v,np.zeros(n),gravity)
    passive=model.passive_force(v);regime,dj,saturated=motor_regimes(envelope,v[6:],gains,force_ranges)
    damping=np.r_[np.zeros(6),dj];effective,maps=held_maps(mass,damping,p["timestep_s"],p["hold_steps"])
    selector=np.vstack((np.zeros((6,j)),np.eye(j)))
    contact=np.vstack([r["jacobian"] for r in active]) if k else np.zeros((0,n))
    pmat=np.diag(np.r_[np.full(n,.001),np.full(3*k,.0001),np.full(j,.001)])
    linear=np.zeros(count);rows=[];lower=[];upper=[];names=[]
    def add(name,a,lo,hi):
        a=np.asarray(a);lo=np.broadcast_to(lo,(a.shape[0],)).copy();hi=np.broadcast_to(hi,(a.shape[0],)).copy()
        rows.append(a);lower.append(lo);upper.append(hi);names.extend([name]*len(lo))
    for t in items:
        # The supporting tasks become hard only in the two explicitly named modes.
        if t["name"].startswith("support_") and mode in ("contact","combined"):continue
        jac=t["jacobian"];weight=t["weight"]**2;target=t["target"]-t["bias"]
        pmat[:n,:n]+=weight*jac.T @ jac;linear[:n]-=weight*jac.T @ target
    rhs=passive-bias+selector @ (saturated-dj*v[6:])
    add("dynamics",np.hstack((effective,-contact.T,-selector @ np.diag(dj))),rhs,rhs)
    target=np.zeros((j,count));target[:,n+3*k:]=np.eye(j)
    add("command",target,envelope["lower_target"],envelope["upper_target"])
    mu=old.parameters()["friction_coefficient"]/np.sqrt(2.)
    for i in range(k):
        cone=np.zeros((5,count));cone[:,n+3*i:n+3*i+3]=[[0,1,0],[1,-mu,0],[-1,-mu,0],[0,-mu,1],[0,-mu,-1]]
        add("friction",cone,[0,-np.inf,-np.inf,-np.inf,-np.inf],[70,0,0,0,0])
    gains=np.asarray(gains);caps=np.asarray(force_ranges);eps=p["regime_force_margin_nm"]
    for r in maps:
        raw=target*gains[:,None];raw[:,:n]-=gains[:,None]*r["velocity_before"][6:]
        low=np.where(regime==1,caps[:,1]+eps,caps[:,0]+eps)
        high=np.where(regime==-1,caps[:,0]-eps,caps[:,1]-eps)
        low=np.where(regime==-1,-np.inf,low);high=np.where(regime==1,np.inf,high)
        add("motor_regime_"+str(r["index"]),raw,low+gains*v[6:],high+gains*v[6:])
        if mode in ("joint","combined"):
            a=np.zeros((j,count));a[:,:n]=r["position"][6:]
            origin=q+(r["index"]+1)*p["timestep_s"]*v[6:]
            margin=p["joint_position_margin_rad"]
            add("joint_position_"+str(r["index"]),a,limits[:,0]+margin-origin,limits[:,1]-margin-origin)
            a=np.zeros((j,count));a[:,:n]=r["velocity_after"][6:]
            cap=p["joint_speed_planning_cap_rad_s"]
            add("joint_velocity_"+str(r["index"]),a,-cap-v[6:],cap-v[6:])
    support=[t for t in items if t["name"].startswith("support_")]
    m.require([t["name"] for t in support]==["support_"+r["contact_site_id"] for r in active],
        "Priority exact supporting task population")
    if mode in ("contact","combined"):
        for t in support:
            a=np.zeros((3,count));a[:,:n]=t["jacobian"];desired=t["target"]-t["bias"]
            add(t["name"],a,desired,desired)
    return dict(P=pmat,q=linear,A=np.vstack(rows),lower=np.concatenate(lower),upper=np.concatenate(upper),
        row_names=names,mass=mass,effective=effective,bias=bias,passive=passive,selector=selector,
        contact=contact,damping=damping,maps=maps,regimes=regime,mode=mode,n=n,j=j,k=k,
        state_velocity=v,state_joints=q,joint_ranges=limits,gains=gains,force_ranges=caps,
        envelope=envelope,support=support,domain_refusal=None)

def verify(qp,result):
    """Recompute frozen steps using clipped motors, independently of the affine maps."""
    m.require(result["accepted"] is True,"Priority accepts no refused solution")
    cert=certificate(qp["P"],qp["q"],qp["A"],qp["lower"],qp["upper"],result["x"],result["y"])
    m.require(cert["accepted"] and cert==result["certificate"],"Priority independent original-coordinate certificate")
    p=parameters();h=p["timestep_s"];n,j,k=qp["n"],qp["j"],qp["k"];x=result["x"]
    acc=x[:n];force=x[n:n+3*k];target=x[n+3*k:]
    v=qp["state_velocity"].copy();q=qp["state_joints"].copy();steps=[];max_error=0.
    correction,transferred=m.resolve_correction(qp["envelope"],target-qp["envelope"]["baseline"])
    m.require(np.max(np.abs(transferred-target),initial=0.)<=2e-6,"Priority unchanged command resolver")
    for r in qp["maps"]:
        raw=qp["gains"]*(transferred-v[6:]);caps=qp["force_ranges"]
        torque=np.clip(raw,caps[:,0],caps[:,1])
        dj=np.where((raw>caps[:,0])&(raw<caps[:,1]),qp["gains"],0.)
        m.require(np.array_equal(np.r_[np.zeros(6),dj],qp["damping"]),"Priority predicted regime consistency")
        rhs=qp["contact"].T @ force+qp["selector"] @ torque+qp["passive"]-qp["bias"]
        actual=np.linalg.solve(qp["mass"]+h*np.diag(np.r_[np.zeros(6),dj]),rhs)
        err=float(np.max(np.abs(actual-r["acceleration"] @ acc),initial=0.))
        max_error=max(max_error,err);m.require(err<=4e-6,"Priority independent held-motor prediction")
        v+=h*actual;q+=h*v[6:]
        if qp["mode"] in ("joint","combined"):
            margin=p["joint_position_margin_rad"];cap=p["joint_speed_planning_cap_rad_s"]
            m.require(np.all(q>=qp["joint_ranges"][:,0]+margin-2e-6)
                and np.all(q<=qp["joint_ranges"][:,1]-margin+2e-6)
                and np.all(np.abs(v[6:])<=cap+2e-6),"Priority independently bounded predicted joints")
        steps.append(dict(torque=torque,joint_position=q.copy(),joint_velocity=v[6:].copy(),acceleration=actual))
    support_errors={t["name"]:t["jacobian"] @ acc+t["bias"]-t["target"] for t in qp["support"]}
    if qp["mode"] in ("contact","combined"):
        m.require(all(np.max(np.abs(e),initial=0.)<=2e-6 for e in support_errors.values()),
            "Priority hard initial support acceleration")
    return dict(predicted_steps=steps,maximum_recurrence_error=max_error,support_errors=support_errors,
        target=target,correction=correction,predicted_forces=force.reshape(k,3),
        model_only=True,contact_persistence_established=False,physical_acceptance_authority=False)

def compute(qp):
    if qp["domain_refusal"]:
        return dict(accepted=False,status=qp["domain_refusal"],solver=None,prediction=None)
    r=solve(qp["P"],qp["q"],qp["A"],qp["lower"],qp["upper"])
    return dict(accepted=r["accepted"],status=r["status"],solver=r,
        prediction=verify(qp,r) if r["accepted"] else None)
