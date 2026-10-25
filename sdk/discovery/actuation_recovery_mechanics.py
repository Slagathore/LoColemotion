"""Portable rigid-tree geometry and instantaneous velocity-actuator command limits.

All inputs use one right-handed SI frame. These functions open no simulator,
estimate no capability and certify no dynamic recovery or held-interval force.
"""
import copy
import math
import numpy as np


def require(value,message):
    if not value:raise ValueError(message)


def array(value,shape,label):
    raw=np.asarray(value)
    require(raw.dtype.kind in "fiu",label+" numeric type")
    a=np.asarray(value,dtype=np.float64)
    require(a.shape==shape and np.isfinite(a).all(),label)
    return a


def xyz(value):
    require(isinstance(value,dict) and set(value)=={"x","y","z"},"Mechanics vector fields")
    return array([value[k] for k in ("x","y","z")],(3,),"Mechanics finite vector")


def rotation(axis,angle):
    axis=array(axis,(3,),"Mechanics axis")
    require(abs(float(axis @ axis)-1.)<=1e-12 and math.isfinite(angle),"Mechanics unit axis/angle")
    x,y,z=axis;skew=np.array([[0.,-z,y],[z,0.,-x],[-y,x,0.]])
    return np.eye(3)+math.sin(angle)*skew+(1.-math.cos(angle))*(skew @ skew)


def quaternion_rotation(value):
    q=array(value,(4,),"Mechanics quaternion")
    require(abs(float(q @ q)-1.)<=1e-10,"Mechanics unit quaternion")
    x,y,z,w=q/np.linalg.norm(q)
    return np.array([[1.-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                     [2*(x*y+z*w),1.-2*(x*x+z*z),2*(y*z-x*w)],
                     [2*(x*z-y*w),2*(y*z+x*w),1.-2*(x*x+y*y)]])


class RigidTree:
    """Model-bound revolute tree; each child shares its parent's zero-angle frame."""
    def __init__(self,spec):
        self.spec=copy.deepcopy(spec)
        require(spec["schema_version"]=="sporespore_morphology_spec_v1"
            and spec["coordinate_frame_id"]=="right_handed_x_forward_y_up_z_right_si_v1",
            "Mechanics morphology frame/schema")
        self.bodies=self.spec["bodies"];self.joints=self.spec["joints"]
        self.body_ids=[b["body_id"] for b in self.bodies]
        self.joint_ids=[j["joint_id"] for j in self.joints]
        self.n=len(self.joints)
        require(len(self.bodies)==self.n+1 and len(set(self.body_ids))==self.n+1
            and len(set(self.joint_ids))==self.n and self.bodies[0]["parent_body_id"] is None,
            "Mechanics tree population/root")
        self.index={name:i for i,name in enumerate(self.body_ids)}
        self.parent=[];self.ancestors=[[] for _ in self.bodies];self.child=[]
        self.mass=[];self.local_com=[]
        for body in self.bodies:
            mass=body["mass_kg"]
            require(type(mass) in (int,float) and math.isfinite(mass) and mass>0,"Mechanics positive mass")
            self.mass.append(mass);self.local_com.append(xyz(body["center_of_mass_local_m"]))
            inertia=xyz(body["inertia_diagonal_kg_m2"])
            require((inertia>0).all() and 2*max(inertia)<=sum(inertia)+1e-12,"Mechanics physical inertia")
        for i,joint in enumerate(self.joints):
            require(joint["joint_type"]=="revolute","Mechanics revolute-only model")
            parent=self.index[joint["parent_body_id"]];child=self.index[joint["child_body_id"]]
            require(child==i+1 and parent<child and self.bodies[child]["parent_body_id"]==self.body_ids[parent],
                "Mechanics ordered connected tree")
            axis=xyz(joint["axis_parent_unit"]);rotation(axis,0.)
            xyz(joint["anchor_parent_m"]);xyz(joint["anchor_child_m"])
            bounds=array([joint["lower_limit_rad"],joint["upper_limit_rad"]],(2,),"Mechanics joint limits")
            require(bounds[0]<bounds[1] and math.isfinite(joint["passive_damping_nms_per_rad"])
                and joint["passive_damping_nms_per_rad"]>=0,"Mechanics joint limits/damping")
            self.parent.append(parent);self.child.append(child)
            self.ancestors[child]=[*self.ancestors[parent],i]
        self.mass=np.array(self.mass);self.local_com=np.array(self.local_com)

    def kinematics(self,position,orientation_xyzw,joints):
        position=array(position,(3,),"Mechanics root position")
        q=array(joints,(self.n,),"Mechanics joint positions")
        positions=[position];rotations=[quaternion_rotation(orientation_xyzw)]
        anchors=[];axes=[]
        for i,joint in enumerate(self.joints):
            parent=self.parent[i];r=rotations[parent]
            axis=xyz(joint["axis_parent_unit"])
            anchor=positions[parent]+r @ xyz(joint["anchor_parent_m"])
            child_rotation=r @ rotation(axis,float(q[i]))
            positions.append(anchor-child_rotation @ xyz(joint["anchor_child_m"]))
            rotations.append(child_rotation);anchors.append(anchor);axes.append(r @ axis)
        positions=np.array(positions);rotations=np.array(rotations)
        centers=positions+np.einsum("bij,bj->bi",rotations,self.local_com)
        return dict(positions=positions,rotations=rotations,centers=centers,
            anchors=np.array(anchors).reshape(self.n,3),axes=np.array(axes).reshape(self.n,3),
            whole_body_com=np.average(centers,axis=0,weights=self.mass))

    def jacobian(self,frame,body_id,point):
        require(body_id in self.index,"Mechanics unknown contact body")
        point=array(point,(3,),"Mechanics contact point");body=self.index[body_id]
        anchors=array(frame["anchors"],(self.n,3),"Mechanics anchors")
        axes=array(frame["axes"],(self.n,3),"Mechanics axes")
        linear=np.zeros((3,self.n));angular=np.zeros((3,self.n))
        for i in self.ancestors[body]:
            linear[:,i]=np.cross(axes[i],point-anchors[i]);angular[:,i]=axes[i]
        return linear,angular

    def wrench_torques(self,frame,wrenches):
        result=np.zeros(self.n)
        for wrench in wrenches:
            linear,angular=self.jacobian(frame,wrench["body_id"],wrench["point"])
            force=array(wrench["force"],(3,),"Mechanics contact force")
            torque=array(wrench["torque"],(3,),"Mechanics contact torque")
            result+=linear.T @ force+angular.T @ torque
        return result

    def gravity_torques(self,frame,gravity):
        gravity=array(gravity,(3,),"Mechanics gravity");centers=frame["centers"]
        return self.wrench_torques(frame,[dict(body_id=name,point=centers[i],
            force=self.mass[i]*gravity,torque=[0.,0.,0.]) for i,name in enumerate(self.body_ids)])

    def gravity_wrench(self,frame,gravity,origin):
        gravity=array(gravity,(3,),"Mechanics gravity");origin=array(origin,(3,),"Mechanics wrench origin")
        forces=self.mass[:,None]*gravity
        return np.r_[np.sum(forces,axis=0),np.sum(np.cross(frame["centers"]-origin,forces),axis=0)]


def command_envelope(baseline,speeds,previous,absolute,slew):
    baseline=np.asarray(baseline);n=baseline.size
    baseline=array(baseline,(n,),"Mechanics baseline")
    speeds=array(speeds,(n,),"Mechanics target speed");previous=array(previous,(n,),"Mechanics previous correction")
    absolute=array(absolute,(n,),"Mechanics correction bound");slew=array(slew,(n,),"Mechanics slew bound")
    require(n>0 and (speeds>0).all() and (absolute>=0).all() and (slew>=0).all()
        and (np.abs(previous)<=absolute).all(),"Mechanics valid command bounds/history")
    lower=np.maximum(-absolute,previous-slew);upper=np.minimum(absolute,previous+slew)
    return dict(baseline=baseline,speeds=speeds,lower_correction=lower,upper_correction=upper,
        lower_target=np.clip(baseline+lower,-speeds,speeds),
        upper_target=np.clip(baseline+upper,-speeds,speeds))


def resolve_correction(envelope,proposal):
    n=len(envelope["baseline"]);proposal=array(proposal,(n,),"Mechanics proposal")
    correction=np.clip(proposal,envelope["lower_correction"],envelope["upper_correction"])
    target=np.clip(envelope["baseline"]+correction,-envelope["speeds"],envelope["speeds"])
    return correction,target


def motor_torque(target,velocity,gains,ranges):
    n=len(target);require(n>0,"Mechanics nonempty motor population")
    target=array(target,(n,),"Mechanics motor target")
    velocity=array(velocity,(n,),"Mechanics motor velocity");gains=array(gains,(n,),"Mechanics velocity gain")
    ranges=array(ranges,(n,2),"Mechanics force ranges")
    require((gains>0).all() and (ranges[:,0]<=0).all() and (ranges[:,1]>=0).all()
        and (ranges[:,0]<ranges[:,1]).all(),"Mechanics velocity actuator capability")
    return np.clip(gains*(target-velocity),ranges[:,0],ranges[:,1])


def torque_envelope(envelope,velocity,gains,ranges):
    return (motor_torque(envelope["lower_target"],velocity,gains,ranges),
            motor_torque(envelope["upper_target"],velocity,gains,ranges))


def command_for_torque(envelope,velocity,gains,ranges,requested):
    lower,upper=torque_envelope(envelope,velocity,gains,ranges)
    requested=array(requested,lower.shape,"Mechanics requested torque")
    desired=np.clip(requested,lower,upper)
    ideal_target=np.asarray(velocity)+desired/np.asarray(gains)
    correction,target=resolve_correction(envelope,ideal_target-envelope["baseline"])
    actual=motor_torque(target,velocity,gains,ranges)
    require(np.all(actual>=lower-1e-12) and np.all(actual<=upper+1e-12),"Mechanics reachable torque projection")
    return dict(proposal=correction,target=target,requested_torque=requested,predicted_torque=actual,
        lower_torque=lower,upper_torque=upper,torque_error=actual-requested,
        scope="instantaneous_at_prepared_velocity",held_interval_force_guaranteed=False)


def command_for_static_wrenches(model,frame,wrenches,gravity,envelope,velocity,gains,ranges):
    """Project gravity/contact compensation into the real command envelope.

    Inertial, Coriolis, passive and joint-limit forces are not included.
    The residual is reported; a clipped proposal is never a feasibility certificate.
    """
    gravity_torque=model.gravity_torques(frame,gravity)
    contact_torque=model.wrench_torques(frame,wrenches)
    result=command_for_torque(envelope,velocity,gains,ranges,-gravity_torque-contact_torque)
    result.update(gravity_torque=gravity_torque,contact_torque=contact_torque,
        static_joint_balance_residual=result["predicted_torque"]+gravity_torque+contact_torque,
        dynamic_feasibility_established=False,capability_estimated=False)
    return result
