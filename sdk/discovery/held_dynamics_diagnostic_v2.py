"""Retained-trajectory force accounting; no simulator, controller or optimizer.

All balances use native generalized coordinates. Each frozen prediction is
mapped through its command-start frame; observed dynamics use each prepared
frame. Contributions are an additive identity along the observed trajectory,
not interventions, independent causes, training targets or disturbance bounds.
"""
import numpy as np
from actuation_recovery_mechanics import array,xyz,require,quaternion_rotation
from floating_base_dynamics import FloatingDynamics
from floating_base_dynamics_inputs import C,native_parameters
from floating_dynamics_oracle_math import canonical_state

H=1/600.
TERMS=("contact_wrench","joint_limit","motor_response","passive_force",
       "bias_change","mass_change","implicit_derivative_change",
       "native_balance_residual","prediction_balance_residual")


def state(model,qpos,qvel):
    q=array(qpos,(15,),"Diagnostic position");v=array(qvel,(14,),"Diagnostic velocity")
    # Conjugating the native orientation by C also rotates its quaternion axis.
    orientation=np.r_[C @ q[4:7],q[3]]
    frame=model.tree.kinematics(C @ q[:3],orientation,q[7:])
    rotation=quaternion_rotation(np.r_[q[4:7],q[3]])
    t=np.eye(14);t[:3,:3]=C.T;t[3:6,3:6]=rotation.T @ C.T
    vc=t.T @ v
    mass=t @ model.mass_matrix(frame) @ t.T
    bias=t @ model.inverse_dynamics(frame,vc,np.zeros(14),[0.,-9.8,0.])
    return dict(frame=frame,t=t,mass=mass,bias=bias,passive=t @ model.passive_force(vc))


def damping(force,gains,ranges):
    force=array(force,(8,),"Diagnostic motor force");gains=array(gains,(8,),"Diagnostic gains")
    ranges=array(ranges,(8,2),"Diagnostic motor ranges")
    require(np.all(gains>0) and np.all(ranges[:,0]<ranges[:,1]),"Diagnostic motor domain")
    require(np.all(force>=ranges[:,0]-1e-12) and np.all(force<=ranges[:,1]+1e-12),"Diagnostic clipped force")
    return np.r_[np.zeros(6),np.where((force>ranges[:,0])&(force<ranges[:,1]),gains,0.)]


def constraint_forces(model,s,sample,limits):
    """Project each measured wrench at its actual prepared contact point.

    The only other supported constraint is a zero-margin scalar hinge limit.
    Every efc row must be covered exactly once, including zero-force rows.
    """
    n=sample["nefc"];types=sample["efc_type"];ids=sample["efc_id"];forces=sample["efc_force"]
    require(n==len(types)==len(ids)==len(forces),"Diagnostic constraint population")
    array(forces,(n,),"Diagnostic finite constraints")
    covered=set();wrenches=[];limit=np.zeros(14)
    require(sample["ncon"]==len(sample["contacts"]),"Diagnostic contact population")
    for index,c in enumerate(sample["contacts"]):
        require(c["native_index"]==index and c["dim"]==3 and c["adhesion_n"]==0.,"Diagnostic contact domain")
        address=c["efc_address"]
        require(address>=0 and address+3<=n and all(types[i]==7 and ids[i]==index for i in range(address,address+3)),
            "Diagnostic elliptic contact rows")
        require(not covered.intersection(range(address,address+3)),"Diagnostic duplicate constraint")
        covered.update(range(address,address+3))
        for side,sign in ((0,-1.),(1,1.)):
            body=c["body_names"][side]
            if body=="world":continue
            require(body in model.tree.index,"Diagnostic contact body")
            wrenches.append(dict(body_id=body,point=C @ array(c["position_m"],(3,),"Diagnostic point"),
                force=sign*array(c["force_on_geom2_canonical_n"],(3,),"Diagnostic force"),
                torque=sign*array(c["torque_on_geom2_canonical_nm"],(3,),"Diagnostic torque")))
    q=array(sample["before_qpos"],(15,),"Diagnostic constraint position")[7:]
    limits=array(limits,(8,2),"Diagnostic limits")
    for i,kind in enumerate(types):
        if i in covered:continue
        require(kind==3 and type(ids[i]) is int and 1<=ids[i]<=8,"Diagnostic unsupported constraint")
        j=ids[i]-1;lo,hi=limits[j]
        require((q[j]<lo) != (q[j]>hi),"Diagnostic limit must be active")
        require(forces[i]>=0,"Diagnostic unilateral limit force")
        limit[6+j]+=(1. if q[j]<lo else -1.)*forces[i];covered.add(i)
    require(covered==set(range(n)),"Diagnostic uncovered constraint")
    return s["t"] @ model.generalized_wrenches(s["frame"],wrenches),limit


def split(m0,b0,p0,d0,f0,ap,tp,ms,bs,ps,ds,fs,limit,ao,ta):
    """E0*(a_observed-a_planned) decomposed without fitting a residual."""
    e0=m0+H*np.diag(d0);es=ms+H*np.diag(ds)
    rp=e0 @ ap-(f0+tp+p0-b0)
    rn=es @ ao-(fs+limit+ta+ps-bs)
    rhs=dict(contact_wrench=fs-f0,joint_limit=limit,motor_response=ta-tp,
        passive_force=ps-p0,bias_change=b0-bs,mass_change=(m0-ms) @ ao,
        implicit_derivative_change=H*(d0-ds)*ao,
        native_balance_residual=rn,prediction_balance_residual=-rp)
    parts={name:np.linalg.solve(e0,rhs[name]) for name in TERMS}
    require(np.max(np.abs(sum(parts.values())-(ao-ap)))<1e-8,"Diagnostic additive acceleration closure")
    return parts,rn,rp


def prepared_contacts(control):
    state=control["request"]["state"];stability=control["stability"]
    require(state["semantic_step"]==stability["semantic_step"]
        and state["gravity_world_m_s2"]==stability["gravity_world_m_s2"],"Diagnostic prepared contact clock")
    rows=stability["ordered_support_contacts"]
    fields=("contact_site_id","presence","bears_support")
    require([tuple(r[k] for k in fields) for r in rows]
        ==[tuple(r[k] for k in fields) for r in state["ordered_contact_observations"]],
        "Diagnostic prepared contact identity")
    return rows


def diagnose(controls,trace,contacts,profile,xml):
    require(len(controls)==120 and len(trace)==len(contacts)==595,"Diagnostic exact retained denominator")
    spec=profile["morphology_spec"];native=native_parameters(xml,spec)
    require(native["joint_inertia_kg_m2"]==profile["parameters"]["joint_inertia_kg_m2"],"Diagnostic explicit armature")
    model=FloatingDynamics(spec,native["joint_inertia_kg_m2"])
    require(np.all(model.damping==0),"Diagnostic unsupported passive derivative")
    limits=[[j["lower_limit_rad"],j["upper_limit_rad"]] for j in model.tree.joints]
    gains=profile["velocity_gains"];ranges=profile["force_ranges"]
    sites={x["contact_site_id"]:x for x in spec["contact_sites"]}
    rows=[];maxima={k:0. for k in ("native_force_balance","prediction_force_balance","position_identity",
        "velocity_sum","position_sum","prepared_frame_join")}
    for command in range(60,119):
        control=controls[command];ob=control["native_observation"]
        s0=state(model,ob["qpos"],ob["qvel"])
        position,orientation,joints,velocity,gravity=canonical_state(control)
        maxima["prepared_frame_join"]=max(maxima["prepared_frame_join"],float(np.max(np.abs(s0["t"] @ velocity-ob["qvel"]))))
        require(np.max(np.abs(C @ np.array(ob["qpos"][:3])-position))<1e-12
            and np.max(np.abs(s0["frame"]["rotations"][0]-quaternion_rotation(orientation)))<1e-12,
            "Diagnostic canonical prepared pose")
        decision=control["force_reference"]["decision"];prediction=decision["allocation"]["prediction"]
        active=decision["active_contacts"];predicted=prediction["predicted_steps"]
        require(len(predicted)==5 and len(prediction["predicted_forces"])==len(active),"Diagnostic prediction denominator")
        packet=prepared_contacts(control)
        by_site={r["contact_site_id"]:r for r in packet}
        planned=[]
        for name,force in zip(active,prediction["predicted_forces"],strict=True):
            planned.append(dict(body_id=sites[name]["body_id"],point=xyz(by_site[name]["point_world_m"]),force=force,torque=[0.,0.,0.]))
        f0=s0["t"] @ model.generalized_wrenches(s0["frame"],planned)
        dv={name:np.zeros(14) for name in TERMS};dq={name:np.zeros(8) for name in TERMS}
        for hold,pred in enumerate(predicted):
            idx=command*5+hold;r=trace[idx];c=contacts[idx]
            require(r["step"]==c["step"]==idx+1 and all(r[k]==c[k] for k in ("before_qpos","before_qvel","qpos","qvel","ctrl","nefc")),
                "Diagnostic force/trajectory step join")
            require(r["ctrl"]==control["native_targets"],"Diagnostic held command")
            # The consumed switching predictor has a declared regime for each substep.
            d0=damping(pred["torque"],gains,ranges)
            s=state(model,r["before_qpos"],r["before_qvel"])
            fs,limit=constraint_forces(model,s,c,limits)
            ao=(np.array(r["qvel"])-r["before_qvel"])/H;ap=s0["t"] @ np.array(pred["acceleration"])
            ta=np.r_[np.zeros(6),r["actuator_force_nm"]];tp=np.r_[np.zeros(6),pred["torque"]]
            ds=damping(r["actuator_force_nm"],gains,ranges)
            parts,rn,rp=split(s0["mass"],s0["bias"],s0["passive"],d0,f0,ap,tp,
                s["mass"],s["bias"],s["passive"],ds,fs,limit,ao,ta)
            for name in TERMS:dv[name]+=H*parts[name];dq[name]+=H*dv[name][6:]
            ve=np.array(r["qvel"])-s0["t"] @ np.array(pred["velocity"])
            qe=np.array(r["qpos"][7:])-pred["joint_position"]
            maxima["native_force_balance"]=max(maxima["native_force_balance"],float(np.max(np.abs(rn))))
            maxima["prediction_force_balance"]=max(maxima["prediction_force_balance"],float(np.max(np.abs(rp))))
            maxima["position_identity"]=max(maxima["position_identity"],float(np.max(np.abs(np.array(r["qpos"][7:])-r["before_qpos"][7:]-H*np.array(r["qvel"][6:])))))
            maxima["velocity_sum"]=max(maxima["velocity_sum"],float(np.max(np.abs(sum(dv.values())-ve))))
            maxima["position_sum"]=max(maxima["position_sum"],float(np.max(np.abs(sum(dq.values())-qe))))
            rows.append(dict(command=command,hold_index=hold,internal_step=idx+1,
                actual_joint_position=r["qpos"][7:],predicted_joint_position=pred["joint_position"],
                joint_position_error_rad=qe.tolist(),joint_velocity_error_rad_s=ve[6:].tolist(),
                position_contributions_rad={k:v.tolist() for k,v in dq.items()},
                velocity_contributions_rad_s={k:v[6:].tolist() for k,v in dv.items()},
                acceleration_contributions={k:v.tolist() for k,v in parts.items()},
                native_force_balance_residual=rn.tolist(),prediction_force_balance_residual=rp.tolist(),
                planned_contact_generalized_force=f0.tolist(),measured_contact_generalized_force=fs.tolist(),
                joint_limit_generalized_force=limit.tolist(),actual_motor_derivative=ds.tolist(),
                planned_motor_derivative=d0.tolist(),contact_bodies=[c["body_names"] for c in c["contacts"]]))
    require(maxima["native_force_balance"]<1e-8 and maxima["prediction_force_balance"]<1e-8,
        "Diagnostic force equation does not close")
    require(all(maxima[k]<1e-10 for k in ("position_identity","velocity_sum","position_sum","prepared_frame_join")),
        "Diagnostic trajectory identity does not close")
    return dict(rows=rows,maximum_absolute_residuals=maxima,commands=59,internal_steps=295,
        joint_comparisons=2360,ordered_joints=model.tree.joint_ids,
        attribution="additive accounting on observed path; not counterfactual or independent causal effects",
        world_build_count=0,solver_steps=0,controller_changed=False,
        disturbance_bound_established=False,training_data_authority=False,
        dynamic_feasibility_established=False,recovery_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)
