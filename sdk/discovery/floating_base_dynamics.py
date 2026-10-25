"""Floating-base rigid-body dynamics in canonical world coordinates.

Generalized velocity/acceleration order is root linear, root angular, joints.
The base coordinates are unactuated. Joint inertia is an explicit configured
diagonal coefficient, not inferred from body mass or silently defaulted.
"""
import numpy as np
from actuation_recovery_mechanics import RigidTree,array,xyz,require


def skew(value):
    x,y,z=array(value,(3,),"Dynamics cross-product vector")
    return np.array([[0.,-z,y],[z,0.,-x],[-y,x,0.]])


class FloatingDynamics:
    def __init__(self,spec,joint_inertia_kg_m2):
        self.tree=RigidTree(spec);self.n=self.tree.n;self.size=6+self.n
        self.joint_inertia=array(joint_inertia_kg_m2,(self.n,),"Dynamics explicit joint inertia").copy()
        require((self.joint_inertia>=0).all(),"Dynamics nonnegative joint inertia")
        self.local_inertia=np.array([np.diag(xyz(b["inertia_diagonal_kg_m2"])) for b in self.tree.bodies])
        self.damping=np.array([j["passive_damping_nms_per_rad"] for j in self.tree.joints])

    def jacobians(self,frame,body,point):
        """Full world-frame point/angular Jacobians, including unactuated base."""
        linear,angular=self.tree.jacobian(frame,body,point)
        offset=np.asarray(point)-frame["positions"][0]
        return (np.hstack((np.eye(3),-skew(offset),linear)),
                np.hstack((np.zeros((3,3)),np.eye(3),angular)))

    def motion(self,frame,velocity,acceleration):
        """Forward Newton-Euler kinematics; no equations of motion are solved."""
        t=self.tree;v=array(velocity,(self.size,),"Dynamics generalized velocity")
        a=array(acceleration,(self.size,),"Dynamics generalized acceleration")
        linear=[v[:3]];angular=[v[3:6]];linear_acc=[a[:3]];angular_acc=[a[3:6]]
        for j,joint in enumerate(t.joints):
            parent=t.parent[j];child=t.child[j];axis=frame["axes"][j]
            wp=angular[parent];ap=angular_acc[parent]
            wc=wp+axis*v[6+j]
            ac=ap+axis*a[6+j]+np.cross(wp,axis)*v[6+j]
            rp=frame["anchors"][j]-frame["positions"][parent]
            va=linear[parent]+np.cross(wp,rp)
            aa=linear_acc[parent]+np.cross(ap,rp)+np.cross(wp,np.cross(wp,rp))
            rc=frame["positions"][child]-frame["anchors"][j]
            linear.append(va+np.cross(wc,rc));angular.append(wc)
            linear_acc.append(aa+np.cross(ac,rc)+np.cross(wc,np.cross(wc,rc)));angular_acc.append(ac)
        linear=np.asarray(linear);angular=np.asarray(angular)
        linear_acc=np.asarray(linear_acc);angular_acc=np.asarray(angular_acc)
        offset=frame["centers"]-frame["positions"]
        com_velocity=linear+np.cross(angular,offset)
        com_acceleration=linear_acc+np.cross(angular_acc,offset)+np.cross(angular,np.cross(angular,offset))
        return dict(origin_velocity=linear,angular_velocity=angular,origin_acceleration=linear_acc,
            angular_acceleration=angular_acc,com_velocity=com_velocity,com_acceleration=com_acceleration)

    def inertias(self,frame):
        return np.array([r @ inertia @ r.T for r,inertia in zip(frame["rotations"],self.local_inertia,strict=True)])

    def mass_matrix(self,frame):
        result=np.zeros((self.size,self.size));inertias=self.inertias(frame)
        for i,body in enumerate(self.tree.body_ids):
            linear,angular=self.jacobians(frame,body,frame["centers"][i])
            result+=self.tree.mass[i]*(linear.T @ linear)+angular.T @ inertias[i] @ angular
        result[6:,6:]+=np.diag(self.joint_inertia)
        require(np.isfinite(result).all(),"Dynamics finite inertia")
        return result

    def inverse_dynamics(self,frame,velocity,acceleration,gravity):
        """Required generalized force before external wrenches/passive damping.

        The first six entries are required base force/moment, not motor commands.
        """
        g=array(gravity,(3,),"Dynamics gravity")
        a=array(acceleration,(self.size,),"Dynamics generalized acceleration")
        motion=self.motion(frame,velocity,a);inertias=self.inertias(frame)
        result=np.zeros(self.size)
        for i,body in enumerate(self.tree.body_ids):
            linear,angular=self.jacobians(frame,body,frame["centers"][i])
            force=self.tree.mass[i]*(motion["com_acceleration"][i]-g)
            omega=motion["angular_velocity"][i]
            moment=inertias[i] @ motion["angular_acceleration"][i]+np.cross(omega,inertias[i] @ omega)
            result+=linear.T @ force+angular.T @ moment
        result[6:]+=self.joint_inertia*a[6:]
        require(np.isfinite(result).all(),"Dynamics finite inverse dynamics")
        return result

    def kinetic_energy(self,frame,velocity):
        v=array(velocity,(self.size,),"Dynamics energy velocity")
        motion=self.motion(frame,v,np.zeros(self.size));inertias=self.inertias(frame)
        energy=.5*float(np.sum(self.tree.mass[:,None]*motion["com_velocity"]**2))
        energy+=.5*sum(float(w @ inertia @ w) for w,inertia in zip(motion["angular_velocity"],inertias,strict=True))
        return energy+.5*float(np.sum(self.joint_inertia*v[6:]**2))

    def potential_energy(self,frame,gravity):
        g=array(gravity,(3,),"Dynamics potential gravity")
        return -float(np.sum(self.tree.mass[:,None]*frame["centers"]*g))

    def generalized_wrenches(self,frame,wrenches):
        result=np.zeros(self.size)
        for w in wrenches:
            point=array(w["point"],(3,),"Dynamics wrench point")
            force=array(w["force"],(3,),"Dynamics wrench force");moment=array(w["torque"],(3,),"Dynamics wrench moment")
            linear,angular=self.jacobians(frame,w["body_id"],point)
            result+=linear.T @ force+angular.T @ moment
        require(np.isfinite(result).all(),"Dynamics finite generalized wrench")
        return result

    def passive_force(self,velocity):
        v=array(velocity,(self.size,),"Dynamics damping velocity")
        return np.r_[np.zeros(6),-self.damping*v[6:]]

    def evaluate(self,position,orientation_xyzw,joints,velocity,acceleration,gravity,wrenches=()):
        frame=self.tree.kinematics(position,orientation_xyzw,joints)
        v=array(velocity,(self.size,),"Dynamics evaluation velocity")
        a=array(acceleration,(self.size,),"Dynamics evaluation acceleration");zero=np.zeros(self.size)
        mass=self.mass_matrix(frame)
        gravity_force=self.inverse_dynamics(frame,zero,zero,gravity)
        velocity_bias=self.inverse_dynamics(frame,v,zero,[0.,0.,0.])
        direct=self.inverse_dynamics(frame,v,a,gravity);external=self.generalized_wrenches(frame,wrenches)
        passive=self.passive_force(v)
        return dict(mass_matrix=mass,gravity_force=gravity_force,velocity_bias=velocity_bias,
            bias=gravity_force+velocity_bias,inverse_dynamics=direct,external_generalized_force=external,
            passive_generalized_force=passive,required_generalized_input=direct-external-passive,
            kinetic_energy_j=self.kinetic_energy(frame,v),potential_energy_j=self.potential_energy(frame,gravity),
            generalized_velocity_units=["m/s"]*3+["rad/s"]*(3+self.n),
            generalized_force_units=["N"]*3+["N m"]*(3+self.n),
            base_is_actuated=False,controller_changed=False,world_build_count=0,solver_steps=0,
            native_dynamics_equivalence_established=False,dynamic_feasibility_established=False,
            held_contact_guaranteed=False,recovery_benefit_established=False)
