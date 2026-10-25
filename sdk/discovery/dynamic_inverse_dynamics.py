"""Actuator-constrained rigid-body inverse dynamics with explicit soft tasks.

Dynamics equations, instantaneous motor torque intervals, normal-force caps
and an inscribed friction pyramid are hard constraints. Contact acceleration
is a tracking task; it is not a held-contact or contact-law certificate.
"""
import numpy as np
from actuation_recovery_mechanics import array,xyz,require,quaternion_rotation
from dynamic_qp_solver import solve,problem_digest


def parameters():
    return dict(com_kp_per_s2=[12.,25.,12.],com_kd_per_s=[7.,10.,7.],com_acceleration_limit_m_s2=[8.,10.,8.],
        orientation_kp_per_s2=[30.,12.,30.],orientation_kd_per_s=[10.,6.,10.],
        angular_acceleration_limit_rad_s2=[30.,15.,30.],joint_kp_per_s2=20.,joint_kd_per_s=8.,
        joint_acceleration_limit_rad_s2=80.,contact_velocity_gain_per_s=30.,contact_acceleration_limit_m_s2=20.,
        airborne_height_kp_per_s2=40.,airborne_velocity_kd_per_s=12.,airborne_acceleration_limit_m_s2=15.,
        com_weight=4.,orientation_weight=8.,joint_weight=.3,contact_weight=10.,airborne_weight=2.,
        acceleration_regularization=.001,force_regularization=.0001,torque_regularization=.001,
        friction_coefficient=.95,maximum_normal_force_n=70.,
        contact_acceleration_is_soft_task=True,friction_pyramid="inscribed square in flat xz tangent plane")


def point_kinematics(model,frame,motion,body,point):
    require(body in model.tree.index,"Dynamic point body identity")
    i=model.tree.index[body];r=array(point,(3,),"Dynamic material point")-frame["positions"][i]
    omega=motion["angular_velocity"][i];alpha=motion["angular_acceleration"][i]
    jac=model.jacobians(frame,body,point)[0]
    velocity=motion["origin_velocity"][i]+np.cross(omega,r)
    bias=motion["origin_acceleration"][i]+np.cross(alpha,r)+np.cross(omega,np.cross(omega,r))
    return jac,velocity,bias


def tasks(model,frame,velocity,orientation,contacts,target_com,joint_error_rad,p):
    require(p==parameters(),"Dynamic exact task parameters")
    n=model.size;v=array(velocity,(n,),"Dynamic state velocity");t=model.tree
    motion=model.motion(frame,v,np.zeros(n));items=[]
    def add(name,jac,bias,target,weight):
        m=len(target)
        items.append(dict(name=name,jacobian=array(jac,(m,n),"Dynamic task Jacobian"),
            bias=array(bias,(m,),"Dynamic task bias"),target=array(target,(m,),"Dynamic task target"),weight=weight))
    com_jac=np.zeros((3,n))
    for i,body in enumerate(t.body_ids):com_jac+=t.mass[i]*model.jacobians(frame,body,frame["centers"][i])[0]
    com_jac/=sum(t.mass);com_velocity=np.average(motion["com_velocity"],axis=0,weights=t.mass)
    com_bias=np.average(motion["com_acceleration"],axis=0,weights=t.mass)
    target=np.array(p["com_kp_per_s2"])*(array(target_com,(3,),"Dynamic COM goal")-frame["whole_body_com"])-np.array(p["com_kd_per_s"])*com_velocity
    add("com",com_jac,com_bias,np.clip(target,-np.array(p["com_acceleration_limit_m_s2"]),p["com_acceleration_limit_m_s2"]),p["com_weight"])
    q=array(orientation,(4,),"Dynamic orientation")
    require(np.allclose(quaternion_rotation(q),frame["rotations"][0],atol=1e-12,rtol=0),"Dynamic orientation/frame identity")
    q=q if q[3]>=0 else -q
    norm=float(np.linalg.norm(q[:3]));angle=q[:3]*(2.*np.arctan2(norm,q[3])/norm) if norm>1e-12 else 2.*q[:3]
    angular_goal=-np.array(p["orientation_kp_per_s2"])*angle-np.array(p["orientation_kd_per_s"])*v[3:6]
    add("orientation",np.eye(n)[3:6],np.zeros(3),np.clip(angular_goal,-np.array(p["angular_acceleration_limit_rad_s2"]),p["angular_acceleration_limit_rad_s2"]),p["orientation_weight"])
    joints=array(joint_error_rad,(t.n,),"Dynamic joint position error")
    # The goal packet supplies q_reference - q in radians.
    joint_goal=p["joint_kp_per_s2"]*joints-p["joint_kd_per_s"]*v[6:]
    add("joint_posture",np.eye(n)[6:],np.zeros(t.n),np.clip(joint_goal,-p["joint_acceleration_limit_rad_s2"],p["joint_acceleration_limit_rad_s2"]),p["joint_weight"])
    require([r["contact_site_id"] for r in contacts]==[s["contact_site_id"] for s in t.spec["contact_sites"]]
        and all(type(r["presence"]) is bool and type(r["bears_support"]) is bool
            and (r["presence"] or not r["bears_support"]) for r in contacts),"Dynamic ordered contact semantics")
    by_site={r["contact_site_id"]:r for r in contacts};active=[]
    for site in t.spec["contact_sites"]:
        row=by_site[site["contact_site_id"]]
        if row["presence"] is True and row["bears_support"] is True:
            point=xyz(row["point_world_m"]);normal=xyz(row["normal_world_unit"])
            require(np.array_equal(normal,[0.,1.,0.]),"Dynamic flat normal domain")
            jac,pv,pb=point_kinematics(model,frame,motion,site["body_id"],point)
            desired=np.clip(-p["contact_velocity_gain_per_s"]*pv,-p["contact_acceleration_limit_m_s2"],p["contact_acceleration_limit_m_s2"])
            add("support_"+site["contact_site_id"],jac,pb,desired,p["contact_weight"])
            active.append(dict(contact_site_id=site["contact_site_id"],body_id=site["body_id"],point=point,jacobian=jac))
        elif row["presence"] is False:
            i=t.index[site["body_id"]];point=frame["positions"][i]+frame["rotations"][i] @ xyz(site["local_center_m"])
            jac,pv,pb=point_kinematics(model,frame,motion,site["body_id"],point)
            desired=p["airborne_height_kp_per_s2"]*(site["radius_m"]-point[1])-p["airborne_velocity_kd_per_s"]*pv[1]
            add("airborne_"+site["contact_site_id"],jac[1:2],pb[1:2],
                [float(np.clip(desired,-p["airborne_acceleration_limit_m_s2"],p["airborne_acceleration_limit_m_s2"]))],p["airborne_weight"])
    return items,active


def problem(model,frame,velocity,gravity,items,active,lower_torque,upper_torque,p):
    require(p==parameters(),"Dynamic exact optimization parameters")
    n=model.size;j=model.n;k=len(active);count=n+3*k+j
    lower_torque=array(lower_torque,(j,),"Dynamic lower torque");upper_torque=array(upper_torque,(j,),"Dynamic upper torque")
    require(np.all(lower_torque<=upper_torque),"Dynamic ordered motor intervals")
    mass=model.mass_matrix(frame);bias=model.inverse_dynamics(frame,velocity,np.zeros(n),gravity)
    passive=model.passive_force(velocity)
    pmat=np.diag(np.r_[np.full(n,p["acceleration_regularization"]),np.full(3*k,p["force_regularization"]),np.full(j,p["torque_regularization"])])
    linear=np.zeros(count)
    for task in items:
        jac=task["jacobian"];weight=task["weight"];desired=task["target"]-task["bias"]
        require(np.isfinite(weight) and weight>0,"Dynamic positive task weight")
        pmat[:n,:n]+=weight**2*(jac.T @ jac);linear[:n]-=weight**2*jac.T @ desired
    contact=np.vstack([r["jacobian"] for r in active]) if k else np.zeros((0,n))
    selector=np.vstack((np.zeros((6,j)),np.eye(j)))
    dynamics=np.hstack((mass,-contact.T,-selector))
    rows=[dynamics];lower=[-bias+passive];upper=[-bias+passive]
    motor=np.zeros((j,count));motor[:,n+3*k:]=np.eye(j);rows.append(motor);lower.append(lower_torque);upper.append(upper_torque)
    mu=p["friction_coefficient"]/np.sqrt(2.)
    for i in range(k):
        cone=np.zeros((5,count))
        cone[:,n+3*i:n+3*i+3]=[[0.,1.,0.],[1.,-mu,0.],[-1.,-mu,0.],[0.,-mu,1.],[0.,-mu,-1.]]
        rows.append(cone);lower.append(np.array([0.,-np.inf,-np.inf,-np.inf,-np.inf]))
        upper.append(np.array([p["maximum_normal_force_n"],0.,0.,0.,0.]))
    return dict(P=pmat,q=linear,A=np.vstack(rows),lower=np.concatenate(lower),upper=np.concatenate(upper),
        mass=mass,bias=bias,passive=passive,contact_jacobian=contact,selector=selector,n=n,j=j,k=k)


def compute(model,frame,velocity,gravity,items,active,lower_torque,upper_torque,p):
    qp=problem(model,frame,velocity,gravity,items,active,lower_torque,upper_torque,p)
    result=solve(qp["P"],qp["q"],qp["A"],qp["lower"],qp["upper"])
    require(result["accepted"],"Dynamic QP refused: "+result["status"])
    n,j,k=qp["n"],qp["j"],qp["k"];x=result["x"];acc=x[:n];forces=x[n:n+3*k].reshape(k,3);torque=x[n+3*k:]
    residual=qp["mass"] @ acc+qp["bias"]-qp["passive"]-qp["contact_jacobian"].T @ forces.reshape(-1)-qp["selector"] @ torque
    require(np.max(np.abs(residual),initial=0.)<=2e-6,"Dynamic original-coordinate equations")
    return dict(acceleration=acc,forces=forces,requested_torque=torque,solver=result,
        dynamics_residual=residual,unactuated_base_residual=residual[:6],
        task_errors={t["name"]:t["jacobian"] @ acc+t["bias"]-t["target"] for t in items},
        task_targets={t["name"]:t["target"] for t in items},task_biases={t["name"]:t["bias"] for t in items},
        active_contacts=[r["contact_site_id"] for r in active],instantaneous_equations_satisfied=True,
        contact_acceleration_is_soft_task=True,dynamic_feasibility_established=False,
        held_contact_guaranteed=False,physical_acceptance_authority=False)
