"""Bounded piecewise motor-hold search with full-coordinate certification.

Each QP fixes one five-step saturation pattern. Proposal QPs can suggest a new
pattern but cannot issue a command. Geometry and contact forces remain frozen.
"""
import numpy as np
import actuation_recovery_mechanics as m
import contact_priority_component as parent
from dynamic_qp_solver_v2 import solve,certificate,problem_digest

MODES=parent.MODES

def parameters():
    p=parent.parameters()
    p.update(regime_selection="bounded deterministic five-step pattern search",
        maximum_patterns=8,initial_patterns=["vertical_bias_share_midpoint","zero_contact_midpoint","fixed_interval"],
        proposal_can_issue_command=False,selection="first fully certified strict pattern",
        complete_pattern_search=False,global_optimality_established=False,
        eliminate_initial_acceleration=True,full_coordinate_certificate_required=True)
    return p

def pattern_values(pattern,steps,j):
    a=np.asarray(pattern)
    m.require(a.shape==(steps,j) and a.dtype.kind in "iu" and np.isin(a,[-1,0,1]).all(),
        "Switching exact integer saturation pattern")
    return a

def affine_steps(base,pattern):
    n,j,k=base["n"],base["j"],base["k"];ny=3*k+j;p=parameters();h=p["timestep_s"]
    pattern=pattern_values(pattern,p["hold_steps"],j)
    u=np.zeros((j,ny));u[:,3*k:]=np.eye(j)
    force=np.zeros((3*k,ny));force[:,:3*k]=np.eye(3*k)
    vmat=np.zeros((n,ny));v=base["state_velocity"].copy()
    qmat=np.zeros((j,ny));q=base["state_joints"].copy();rows=[]
    for i,regime in enumerate(pattern):
        d=np.where(regime==0,base["gains"],0.)
        sat=np.where(regime==1,base["force_ranges"][:,1],np.where(regime==-1,base["force_ranges"][:,0],0.))
        rawmat=base["gains"][:,None]*(u-vmat[6:]);raw=-base["gains"]*v[6:]
        torque_mat=d[:,None]*(u-vmat[6:]);torque=sat-d*v[6:]
        effective=base["mass"]+h*np.diag(np.r_[np.zeros(6),d])
        amat=np.linalg.solve(effective,base["contact"].T @ force+base["selector"] @ torque_mat)
        acc=np.linalg.solve(effective,base["selector"] @ torque+base["passive"]-base["bias"])
        vmat=vmat+h*amat;v=v+h*acc;qmat=qmat+h*vmat[6:];q=q+h*v[6:]
        rows.append(dict(index=i,regime=regime,damping=d,saturated=sat,effective=effective,
            raw_matrix=rawmat,raw_offset=raw,acceleration_matrix=amat,acceleration_offset=acc,
            velocity_matrix=vmat.copy(),velocity_offset=v.copy(),position_matrix=qmat.copy(),position_offset=q.copy()))
    return rows

def build(base,pattern,strict=True):
    m.require(base["domain_refusal"] is None and type(strict) is bool,"Switching declared model domain")
    n,j,k=base["n"],base["j"],base["k"];ny=3*k+j;count=n+ny;p=parameters();steps=affine_steps(base,pattern)
    first=steps[0];equality=np.hstack((first["effective"],-base["contact"].T,-base["selector"] @ np.diag(first["damping"])))
    rhs=base["passive"]-base["bias"]+base["selector"] @ (first["saturated"]-first["damping"]*base["state_velocity"][6:])
    keep=[i for i,name in enumerate(base["row_names"]) if not name.startswith(("dynamics","motor_regime_","joint_position_","joint_velocity_"))]
    rows=[equality,base["A"][keep]];lower=[rhs,base["lower"][keep]];upper=[rhs,base["upper"][keep]]
    names=["dynamics"]*n+[base["row_names"][i] for i in keep]
    def add(name,coeff,lo,hi):
        rows.append(np.hstack((np.zeros((len(lo),n)),coeff)));lower.append(lo);upper.append(hi);names.extend([name]*len(lo))
    for r in steps:
        if strict:
            regime=r["regime"];caps=base["force_ranges"];eps=p["regime_force_margin_nm"]
            lo=np.where(regime==1,caps[:,1]+eps,caps[:,0]+eps)
            hi=np.where(regime==-1,caps[:,0]-eps,caps[:,1]-eps)
            lo=np.where(regime==-1,-np.inf,lo);hi=np.where(regime==1,np.inf,hi)
            add("motor_regime_"+str(r["index"]),r["raw_matrix"],lo-r["raw_offset"],hi-r["raw_offset"])
        if base["mode"] in ("joint","combined"):
            margin=p["joint_position_margin_rad"];cap=p["joint_speed_planning_cap_rad_s"]
            add("joint_position_"+str(r["index"]),r["position_matrix"],
                base["joint_ranges"][:,0]+margin-r["position_offset"],base["joint_ranges"][:,1]-margin-r["position_offset"])
            add("joint_velocity_"+str(r["index"]),r["velocity_matrix"][6:],
                -cap-r["velocity_offset"][6:],cap-r["velocity_offset"][6:])
    full=dict(P=base["P"],q=base["q"],A=np.vstack(rows),lower=np.concatenate(lower),upper=np.concatenate(upper),row_names=names)
    transform=np.vstack((first["acceleration_matrix"],np.eye(ny)))
    offset=np.r_[first["acceleration_offset"],np.zeros(ny)]
    m.require(np.max(np.abs(equality @ transform),initial=0.)<=1e-10
        and np.max(np.abs(equality @ offset-rhs),initial=0.)<=1e-10,"Switching exact dynamics elimination")
    red=dict(P=transform.T @ full["P"] @ transform,q=transform.T @ (full["P"] @ offset+full["q"]),
        A=full["A"][n:] @ transform,lower=full["lower"][n:]-full["A"][n:] @ offset,
        upper=full["upper"][n:]-full["A"][n:] @ offset)
    # Remove insignificant asymmetry from the congruence product only.
    red["P"]=(red["P"]+red["P"].T)/2.
    return dict(full=full,reduced=red,transform=transform,offset=offset,steps=steps,
        pattern=np.asarray(pattern),strict=strict,base=base)

def solve_pattern(qp):
    red=qp["reduced"];full=qp["full"];r=solve(red["P"],red["q"],red["A"],red["lower"],red["upper"])
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

def clipped_prediction(base,y):
    n,j,k=base["n"],base["j"],base["k"];p=parameters();h=p["timestep_s"]
    y=m.array(y,(3*k+j,),"Switching force and target")
    force=y[:3*k];target=y[3*k:];v=base["state_velocity"].copy();q=base["state_joints"].copy()
    rows=[];pattern=[]
    for i in range(p["hold_steps"]):
        raw=base["gains"]*(target-v[6:]);caps=base["force_ranges"]
        regime=np.where(raw>=caps[:,1],1,np.where(raw<=caps[:,0],-1,0));pattern.append(regime)
        d=np.where(regime==0,base["gains"],0.);torque=np.clip(raw,caps[:,0],caps[:,1])
        rhs=base["contact"].T @ force+base["selector"] @ torque+base["passive"]-base["bias"]
        acc=np.linalg.solve(base["mass"]+h*np.diag(np.r_[np.zeros(6),d]),rhs)
        v+=h*acc;q+=h*v[6:]
        rows.append(dict(raw_torque=raw,torque=torque,acceleration=acc,velocity=v.copy(),joint_position=q.copy()))
    return np.asarray(pattern),rows

def verify(qp,result):
    m.require(qp["strict"] and result["accepted"],"Switching proposal or refusal cannot issue a command")
    base=qp["base"];full=qp["full"];n,j,k=base["n"],base["j"],base["k"];x=result["full_x"]
    cert=certificate(full["P"],full["q"],full["A"],full["lower"],full["upper"],x,result["full_y"])
    m.require(cert==result["full_certificate"] and cert["accepted"],"Switching independent full certificate")
    target=x[n+3*k:];correction,transferred=m.resolve_correction(base["envelope"],target-base["envelope"]["baseline"])
    m.require(np.max(np.abs(transferred-target),initial=0.)<=2e-6,"Switching unchanged resolver")
    y=np.r_[x[n:n+3*k],transferred];pattern,actual=clipped_prediction(base,y)
    m.require(np.array_equal(pattern,qp["pattern"]),"Switching all predicted saturation regimes")
    errors=dict(acceleration=0.,velocity=0.,joint_position=0.)
    for r,row in zip(qp["steps"],actual,strict=True):
        for key,matrix,offset in (("acceleration","acceleration_matrix","acceleration_offset"),
                ("velocity","velocity_matrix","velocity_offset"),("joint_position","position_matrix","position_offset")):
            errors[key]=max(errors[key],float(np.max(np.abs(row[key]-r[matrix] @ y-r[offset]),initial=0.)))
        if base["mode"] in ("joint","combined"):
            margin=parameters()["joint_position_margin_rad"];cap=parameters()["joint_speed_planning_cap_rad_s"]
            m.require(np.all(row["joint_position"]>=base["joint_ranges"][:,0]+margin-2e-6)
                and np.all(row["joint_position"]<=base["joint_ranges"][:,1]-margin+2e-6)
                and np.all(np.abs(row["velocity"][6:])<=cap+2e-6),"Switching independently bounded held joints")
    m.require(errors["acceleration"]<=4e-6 and errors["velocity"]<=1e-8 and errors["joint_position"]<=1e-8,
        "Switching independently reconstructed held motor behavior")
    m.require(np.max(np.abs(actual[0]["acceleration"]-x[:n]),initial=0.)<=4e-6,"Switching transferred initial equations")
    support_errors={t["name"]:t["jacobian"] @ actual[0]["acceleration"]+t["bias"]-t["target"] for t in base["support"]}
    if base["mode"] in ("contact","combined"):
        m.require(all(np.max(np.abs(v),initial=0.)<=2e-6 for v in support_errors.values()),"Switching strict support constraint")
    return dict(predicted_steps=actual,pattern=pattern,maximum_errors=errors,target=transferred,correction=correction,
        predicted_forces=x[n:n+3*k].reshape(k,3),support_errors=support_errors,
        transitions=int(np.count_nonzero(pattern[1:]!=pattern[:-1])),
        model_only=True,contact_persistence_established=False,physical_acceptance_authority=False)

def document(qp,result,kind):
    red=qp["reduced"]
    return dict(kind=kind,pattern=qp["pattern"],problem=dict(P=red["P"],q=red["q"],A=red["A"],
        lower=[float(v) if np.isfinite(v) else None for v in red["lower"]],
        upper=[float(v) if np.isfinite(v) else None for v in red["upper"]],
        null_lower_means_negative_infinity=True,null_upper_means_positive_infinity=True),result=result)

def initial_patterns(base):
    k,j=base["k"],base["j"];env=base["envelope"];mid=(env["lower_target"]+env["upper_target"])/2.
    force=np.zeros((k,3))
    if k:force[:,1]=min(70.,max(0.,float(base["bias"][1]))/k)
    gravity,_=clipped_prediction(base,np.r_[force.reshape(-1),mid])
    zero,_=clipped_prediction(base,np.r_[np.zeros(3*k),mid])
    fixed=np.tile(base["regimes"],(parameters()["hold_steps"],1))
    return [("vertical_bias_share_midpoint",gravity),("zero_contact_midpoint",zero),("fixed_interval",fixed)]

def compute(base):
    if base["domain_refusal"]:
        return dict(accepted=False,status=base["domain_refusal"],prediction=None,selected=None,attempts=[],patterns_tried=0)
    queue=initial_patterns(base);seen=set();attempts=[];max_patterns=parameters()["maximum_patterns"]
    while queue and len(seen)<max_patterns:
        origin,pattern=queue.pop(0);key=tuple(pattern.reshape(-1).tolist())
        if key in seen:continue
        seen.add(key);qp=build(base,pattern,True);r=solve_pattern(qp)
        attempts.append(document(qp,r,"strict:"+origin))
        if r["accepted"]:
            prediction=verify(qp,r)
            return dict(accepted=True,status="certified strict pattern",prediction=prediction,selected=r,
                selected_attempt=len(attempts)-1,attempts=attempts,patterns_tried=len(seen))
        # A relaxed solve is only a deterministic pattern generator. Its command
        # is never returned, even when its own QP is solved accurately.
        proposal=build(base,pattern,False);pr=solve_pattern(proposal)
        attempts.append(document(proposal,pr,"proposal_only:"+origin))
        if pr["accepted"]:
            new,_=clipped_prediction(base,pr["full_x"][base["n"]:])
            if tuple(new.reshape(-1).tolist()) not in seen:queue.insert(0,("proposal",new))
    return dict(accepted=False,status="bounded pattern search refused",prediction=None,selected=None,
        attempts=attempts,patterns_tried=len(seen))
