"""Finite retained-state acceleration accounting, including the native integrator.

Measured contact forces are retrospective inputs. They are not available to the
original controller and do not predict an alternative trajectory.
"""
import xml.etree.ElementTree as ET
import numpy as np
from actuation_recovery_mechanics import array,xyz,require,motor_torque
from floating_base_dynamics import FloatingDynamics
from floating_base_dynamics_inputs import C,native_parameters
from force_recovery_diagnostic_metrics import prepared_frame,robot_wrenches
from reach_tracking_diagnostic_metrics import safe_command_end

def close(a,b,tolerance,label):
    a=np.asarray(a,dtype=float);b=np.asarray(b,dtype=float)
    require(a.shape==b.shape and np.isfinite(a).all() and np.isfinite(b).all()
        and np.max(np.abs(a-b),initial=0.)<=tolerance,label)
    return float(np.max(np.abs(a-b),initial=0.))

def validate_window(failures,start,end):
    require(type(start) is int and type(end) is int and start==60 and end==119
        and len(failures)==2 and [f["internal_step"] for f in failures]==[695,596]
        and end==min(safe_command_end(f,1440) for f in failures),
        "Dynamic diagnosis common complete safe window")
    return dict(start=start,end_exclusive=end,commands_per_trial=end-start,
        posthoc=True,includes_first_failing_command=False)

def configured_model(xml,profile):
    spec=profile["morphology_spec"];native=native_parameters(xml,spec);doc=ET.fromstring(xml)
    require([x.tag for x in doc]==["compiler","option","worldbody","actuator","sensor"],
        "Dynamic diagnosis unsupported native model")
    option=doc.find("option")
    require(set(option.attrib)=={"timestep","gravity","integrator","solver","iterations","ls_iterations","cone"}
        and len(option)==0 and option.get("integrator")=="implicitfast"
        and option.get("cone")=="elliptic" and float(option.get("timestep"))==1/600.
        and option.get("gravity")=="0 0 -9.8","Dynamic diagnosis integration domain")
    joints=list(doc.iter("joint"));actuators=list(doc.find("actuator"))
    require(len(joints)==len(actuators)==8 and native["passive_damping_nms_per_rad"]==[0.]*8,
        "Dynamic diagnosis eight undamped joints")
    ranges=[]
    for j in joints:
        require(j.get("limited")=="true" and set(j.attrib)=={"name","type","pos","axis","limited","range","damping","armature"},
            "Dynamic diagnosis explicit zero-margin hinge limits")
        ranges.append([float(v) for v in j.get("range").split()])
    for i,a in enumerate(actuators):
        require(a.tag=="velocity" and set(a.attrib)=={"name","joint","gear","ctrllimited","kv","forcelimited","forcerange"}
            and a.get("name")==profile["ordered_actuators"][i] and a.get("joint")==joints[i].get("name")
            and a.get("gear")=="1 0 0 0 0 0" and a.get("ctrllimited")=="false"
            and a.get("forcelimited")=="true" and float(a.get("kv"))==profile["velocity_gains"][i]
            and [float(v) for v in a.get("forcerange").split()]==profile["force_ranges"][i],
            "Dynamic diagnosis affine unit-gear velocity motor")
    return FloatingDynamics(spec,native["joint_inertia_kg_m2"]),np.asarray(ranges)

def canonical_velocity(frame,qvel):
    v=array(qvel,(14,),"Dynamic diagnosis native velocity")
    return np.r_[C @ v[:3],frame["rotations"][0] @ C @ v[3:6],v[6:]]

def limit_force(sample,ranges):
    """Account for every non-contact constraint; unsupported constraint kinds refuse."""
    ranges=array(ranges,(8,2),"Dynamic diagnosis joint ranges")
    require(np.all(ranges[:,0]<ranges[:,1]),"Dynamic diagnosis ordered joint ranges")
    q=array(sample["before_qpos"],(15,),"Dynamic diagnosis limit state")[7:]
    require(sample["nefc"]==len(sample["efc_type"])==len(sample["efc_id"])==len(sample["efc_force"]),
        "Dynamic diagnosis constraint denominator")
    contact_rows=set()
    for contact in sample["contacts"]:
        address=contact["efc_address"]
        if address<0:continue
        require(contact["dim"]==3,"Dynamic diagnosis elliptic point contact")
        for i in range(address,address+3):
            require(i not in contact_rows and i<sample["nefc"] and sample["efc_type"][i]==7
                and sample["efc_id"][i]==contact["native_index"],"Dynamic diagnosis contact constraint join")
            contact_rows.add(i)
    out=np.zeros(14);seen=[]
    for i,(kind,identity,force) in enumerate(zip(sample["efc_type"],sample["efc_id"],sample["efc_force"],strict=True)):
        require(type(kind) is int and type(identity) is int and np.isfinite(force),"Dynamic diagnosis constraint types")
        if i in contact_rows:continue
        require(kind==3 and 1<=identity<=8 and force>=0,"Dynamic diagnosis unsupported noncontact constraint")
        joint=identity-1;low,high=ranges[joint]
        require(q[joint]<low or q[joint]>high,"Dynamic diagnosis inactive zero-margin limit")
        sign=1. if q[joint]<low else -1.
        require(joint not in seen,"Dynamic diagnosis duplicate limit")
        seen.append(joint);out[6+joint]+=sign*force
    expected=[i for i,(value,(low,high)) in enumerate(zip(q,ranges,strict=True)) if value<low or value>high]
    require(seen==expected,"Dynamic diagnosis complete joint-limit population")
    return out

def damping_diagonal(torque,gains,ranges):
    force=array(torque,(8,),"Dynamic diagnosis measured motor force")
    kv=array(gains,(8,),"Dynamic diagnosis velocity gains");caps=array(ranges,(8,2),"Dynamic diagnosis force caps")
    require((kv>0).all() and np.all(caps[:,0]<caps[:,1])
        and np.all(force>=caps[:,0]) and np.all(force<=caps[:,1]),"Dynamic diagnosis force/gain domain")
    # The native derivative omits saturated actuators, including equality at a cap.
    return np.r_[np.zeros(6),np.where((force>caps[:,0])&(force<caps[:,1]),kv,0.)]

def integration(mass,rhs,damping,dt):
    mass=array(mass,(14,14),"Dynamic diagnosis inertia");rhs=array(rhs,(14,),"Dynamic diagnosis net force")
    damping=array(damping,(14,),"Dynamic diagnosis damping")
    require(np.all(damping>=0) and np.isfinite(dt) and dt>0,"Dynamic diagnosis integration coefficients")
    close(mass,mass.T,1e-12,"Dynamic diagnosis symmetric inertia");np.linalg.cholesky(mass)
    continuous=np.linalg.solve(mass,rhs);effective=mass+dt*np.diag(damping)
    integrated=np.linalg.solve(effective,rhs)
    close(effective @ integrated,rhs,1e-8,"Dynamic diagnosis integration solve")
    return continuous,integrated

def internal_sample(model,ranges,profile,sample,trace,tolerance=1e-10):
    for key in ("step","before_qpos","before_qvel","qpos","qvel","ctrl"):
        require(sample[key]==trace[key],"Dynamic diagnosis internal source join")
    dt=sample["integrated_time_s"]-sample["prepared_time_s"]
    require(abs(dt-1/600.)<=1e-14,"Dynamic diagnosis native timestep")
    frame=prepared_frame(model.tree,sample["before_qpos"]);v=canonical_velocity(frame,sample["before_qvel"])
    mass=model.mass_matrix(frame);bias=model.inverse_dynamics(frame,v,np.zeros(14),[0.,-9.8,0.])
    passive=model.passive_force(v);contact=model.generalized_wrenches(frame,robot_wrenches(sample))
    limits=limit_force(sample,ranges);torque=array(trace["actuator_force_nm"],(8,),"Dynamic diagnosis native motor force")
    motor_error=close(torque,motor_torque(sample["ctrl"],sample["before_qvel"][6:],profile["velocity_gains"],profile["force_ranges"]),
        1e-10,"Dynamic diagnosis motor reconstruction")
    damping=damping_diagonal(torque,profile["velocity_gains"],profile["force_ranges"])
    rhs=contact+limits+np.r_[np.zeros(6),torque]+passive-bias
    continuous,integrated=integration(mass,rhs,damping,1/600.)
    # Transform the native increment in the prepared basis; this is not a
    # finite difference between two differently oriented world-frame twists.
    observed=canonical_velocity(frame,(np.asarray(sample["qvel"])-sample["before_qvel"])*600.)
    velocity_error=close(integrated/600.,observed/600.,tolerance,"Dynamic diagnosis retained velocity-step closure")
    equation_error=close((mass+np.diag(damping)/600.) @ observed,rhs,1e-8,"Dynamic diagnosis retained force balance")
    return dict(frame=frame,velocity=v,mass=mass,bias=bias,passive=passive,contact=contact,limits=limits,
        torque=torque,damping=damping,continuous=continuous,integrated=integrated,observed=observed,
        motor_error=motor_error,velocity_error=velocity_error,equation_error=equation_error)

def decompose(mass,predicted,actual_continuous,actual_integrated,planned_contact,actual_contact,
              limits,requested_torque,measured_torque):
    predicted=array(predicted,(14,),"Dynamic diagnosis planned acceleration")
    parts=dict(contact=np.linalg.solve(mass,actual_contact-planned_contact),
        joint_limit=np.linalg.solve(mass,limits),
        motor=np.linalg.solve(mass,np.r_[np.zeros(6),measured_torque-requested_torque]),
        integrator=actual_integrated-actual_continuous)
    discrepancy=actual_integrated-predicted
    error=close(sum(parts.values()),discrepancy,1e-8,"Dynamic diagnosis additive acceleration accounting")
    return dict(discrepancy=discrepancy,contributions=parts,maximum_identity_error=error,
        accounting_is_not_causal_attribution=True)

def planned_wrenches(row,model):
    decision=row["force_reference"]["decision"]
    contacts=row["resolution_request"]["provider_request"]["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
    sites={x["contact_site_id"]:x["body_id"] for x in model.tree.spec["contact_sites"]}
    active=[x for x in contacts if x["presence"] and x["bears_support"]]
    require([x["contact_site_id"] for x in active]==decision["active_contacts"],"Dynamic diagnosis planned contact identity")
    forces=array(np.asarray(decision["allocation"]["forces"]).reshape(len(active),3),(len(active),3),"Dynamic diagnosis planned force")
    return [dict(body_id=sites[x["contact_site_id"]],point=xyz(x["point_world_m"]),force=force,torque=np.zeros(3))
        for x,force in zip(active,forces,strict=True)],active

def command_snapshot(row,last_trace,first,model):
    from dynamic_inverse_dynamics_v2 import point_kinematics
    from posture_tracking_diagnostic_metrics import material_point_motion
    decision=row["force_reference"]["decision"];plan=decision["allocation"]
    require(row["request"]["state"]["semantic_step"]==row["outer_step"],"Dynamic diagnosis command clock")
    predicted=array(plan["acceleration"],(14,),"Dynamic diagnosis planned acceleration")
    requested=array(plan["requested_torque"],(8,),"Dynamic diagnosis planned torque")
    wrenches,active=planned_wrenches(row,model);generalized=model.generalized_wrenches(first["frame"],wrenches)
    close(first["mass"] @ predicted+first["bias"]-first["passive"],
        generalized+np.r_[np.zeros(6),requested],2e-6,"Dynamic diagnosis original predicted dynamics")
    accounting=decompose(first["mass"],predicted,first["continuous"],first["integrated"],
        generalized,first["contact"],first["limits"],requested,first["torque"])
    frame=first["frame"];motion=model.motion(frame,first["velocity"],np.zeros(14))
    after=prepared_frame(model.tree,last_trace["qpos"]);points=[]
    for contact,wrench in zip(active,wrenches,strict=True):
        body=wrench["body_id"];point=wrench["point"];jac,pv,pb=point_kinematics(model,frame,motion,body,point)
        identity=contact["contact_site_id"];name="support_"+identity;i=model.tree.index[body]
        calculated=jac @ predicted+pb
        close(calculated,np.array(plan["task_targets"][name])+plan["task_errors"][name],1e-8,
            "Dynamic diagnosis contact task reconstruction")
        points.append(dict(site=identity,planned_force_n=wrench["force"],prepared_material_velocity_m_s=pv,
            task_target_m_s2=plan["task_targets"][name],predicted_acceleration_m_s2=calculated,
            actual_continuous_acceleration_m_s2=jac @ first["continuous"]+pb,
            actual_integrated_acceleration_m_s2=jac @ first["integrated"]+pb,
            material_displacement_over_command_m=material_point_motion(frame["positions"][i],frame["rotations"][i],
                after["positions"][i],after["rotations"][i],point)))
    return dict(command=row["outer_step"],predicted_acceleration=predicted,actual_continuous_acceleration=first["continuous"],
        actual_integrated_acceleration=first["integrated"],requested_torque_nm=requested,
        predicted_contact_generalized_force=generalized,measured_contact_generalized_force=first["contact"],
        measured_joint_limit_generalized_force=first["limits"],accounting=accounting,points=points)
