"""Contact-constrained virtual posture references for the declared 2R quadruped.

Virtual base motion is a kinematic witness, never a command to move the root.
Linear priority and bounded joint references do not certify dynamic feasibility.
"""
import math
import numpy as np
import actuation_recovery_mechanics as m
from bounded_posture_solver import hierarchy,TOL
from support_reach_geometry import ReachModel
from reach_tracking_diagnostic_metrics import orientation_vector


def parameters():
    return dict(root_reference_increment_m=.025,orientation_reference_increment_rad=.08,
        joint_reference_increment_rad=.25,nonlinear_contact_tolerance_m=.0005,
        maximum_backtracks=16,svd_relative_cutoff=1e-10,
        contact_model="one current prepared point per supporting site",
        priority=["contact","orientation","com","airborne_foot","supported_posture"],
        supported_knee_fraction=.5,unsupported_mode="previous_bounded_reference",
        out_of_bounds_mode="previous_bounded_reference")


def skew(value):
    x,y,z=m.array(value,(3,),"Posture skew")
    return np.array([[0.,-z,y],[z,0.,-x],[-y,x,0.]])


def point_jacobian(tree,frame,body,point):
    linear,_=tree.jacobian(frame,body,point)
    return np.hstack((np.eye(3),-skew(np.asarray(point)-frame["positions"][0]),linear))


def com_jacobian(tree,frame):
    return sum(tree.mass[i]*point_jacobian(tree,frame,body,frame["centers"][i])
        for i,body in enumerate(tree.body_ids))/sum(tree.mass)


def quaternion_product(a,b):
    a=m.array(a,(4,),"Posture first quaternion");b=m.array(b,(4,),"Posture second quaternion")
    return np.r_[a[3]*b[:3]+b[3]*a[:3]+np.cross(a[:3],b[:3]),a[3]*b[3]-a[:3]@b[:3]]


def retract(position,quaternion,joints,delta):
    delta=m.array(delta,(6+len(joints),),"Posture retraction delta")
    angle=float(np.linalg.norm(delta[3:6]))
    increment=np.r_[delta[3:6]*(math.sin(angle/2)/angle),math.cos(angle/2)] if angle>1e-14 else np.r_[delta[3:6]/2,1.]
    q=quaternion_product(increment,quaternion);q/=np.linalg.norm(q)
    return np.asarray(position)+delta[:3],q,np.asarray(joints)+delta[6:]


class PostureReference:
    def __init__(self,spec):
        self.reach=ReachModel(spec);self.tree=self.reach.tree;t=self.tree
        m.require(t.n==8,"Posture declared eight-actuator body")
        self.bounds=np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in t.joints])
        m.require((self.bounds[:,0]<=0).all() and (self.bounds[:,1]>=0).all(),"Posture neutral reference within bounds")
        self.sites={s["contact_site_id"]:s for s in t.spec["contact_sites"]}
        self.nominal=np.zeros(8)
        for i,leg in enumerate(self.reach.legs):
            knee=parameters()["supported_knee_fraction"]*max(0.,leg["bounds"][1][1])
            l1,l2=leg["lengths"]
            hip=-math.atan2(l2*math.sin(knee),l1+l2*math.cos(knee))
            self.nominal[2*i:2*i+2]=np.clip([hip,knee],self.bounds[2*i:2*i+2,0],self.bounds[2*i:2*i+2,1])

    def compute(self,position,quaternion,joints,contacts,target_com,fallback_reference):
        p=parameters();t=self.tree;n=6+t.n
        position=m.array(position,(3,),"Posture root");q=m.array(joints,(t.n,),"Posture joints")
        target_com=m.array(target_com,(3,),"Posture COM target")
        fallback=m.array(fallback_reference,(t.n,),"Posture fallback")
        m.require((fallback>=self.bounds[:,0]).all() and (fallback<=self.bounds[:,1]).all(),"Posture bounded fallback")
        frame=t.kinematics(position,quaternion,q)
        m.require([r["contact_site_id"] for r in contacts]==list(self.sites),"Posture complete contact order")
        active=[]
        for r in contacts:
            m.require(type(r["presence"]) is bool and type(r["bears_support"]) is bool
                and (not r["bears_support"] or r["presence"]),"Posture contact flags")
            if r["bears_support"]:
                point=m.xyz(r["point_world_m"]);normal=m.xyz(r["normal_world_unit"])
                m.require(np.array_equal(normal,[0.,1.,0.]),"Posture declared flat contact")
                body=self.sites[r["contact_site_id"]]["body_id"];i=t.index[body]
                active.append(dict(site=r["contact_site_id"],body=body,point=point,
                    local=frame["rotations"][i].T@(point-frame["positions"][i])))
        outside=np.where((q<self.bounds[:,0])|(q>self.bounds[:,1]))[0].tolist()
        common=dict(reference_only=True,root_motion_issued=False,dynamic_feasibility_established=False,
            collision_free_path_established=False,held_interval_contact_guaranteed=False,
            observed_out_of_bounds_joint_indices=outside,active_sites=[r["site"] for r in active])
        if outside or not active:
            return dict(status="observed_joint_limit_violation" if outside else "unsupported",
                reference_joint_positions_rad=fallback.tolist(),legacy_bounded_reference_used=True,
                linear_contact_verified=False,nonlinear_contact_verified=False,**common)
        contact=np.vstack([point_jacobian(t,frame,r["body"],r["point"]) for r in active])
        orientation=np.zeros((3,n));orientation[:,3:6]=np.eye(3)
        tasks=[("orientation",orientation,-np.array(orientation_vector(quaternion))),
            ("com",com_jacobian(t,frame),target_com-frame["whole_body_com"])]
        airborne=[];errors=[];posture=[];posture_error=[]
        active_ids={r["site"] for r in active}
        for i,(site,definition) in enumerate(self.sites.items()):
            body=definition["body_id"];body_index=t.index[body]
            point=frame["positions"][body_index]+frame["rotations"][body_index]@m.xyz(definition["local_center_m"])
            if site not in active_ids:
                airborne.append(point_jacobian(t,frame,body,point))
                errors.extend([0.,definition["radius_m"]-point[1],0.])
            else:
                for j in (2*i,2*i+1):
                    row=np.zeros(n);row[6+j]=1.;posture.append(row);posture_error.append(self.nominal[j]-q[j])
        tasks.extend([("airborne_foot",np.vstack(airborne) if airborne else np.empty((0,n)),errors),
            ("supported_posture",np.array(posture).reshape(-1,n),posture_error)])
        scale=np.r_[[p["root_reference_increment_m"]]*3,[p["orientation_reference_increment_rad"]]*3,
            [p["joint_reference_increment_rad"]]*t.n]
        lower=-scale;upper=scale.copy()
        lower[6:]=np.maximum(lower[6:],self.bounds[:,0]-q)
        upper[6:]=np.minimum(upper[6:],self.bounds[:,1]-q)
        solved=hierarchy(contact,tasks,lower,upper,scale)
        delta=solved["delta"];witness=None
        for backtrack in range(p["maximum_backtracks"]+1):
            fraction=2.**(-backtrack)
            pos,ori,jref=retract(position,quaternion,q,fraction*delta);after=t.kinematics(pos,ori,jref)
            displacements=[]
            for r in active:
                i=t.index[r["body"]];point=after["positions"][i]+after["rotations"][i]@r["local"]
                displacements.append(point-r["point"])
            drift=float(np.max(np.linalg.norm(displacements,axis=1),initial=0.))
            if drift<=p["nonlinear_contact_tolerance_m"]:
                witness=dict(fraction=fraction,backtracks=backtrack,virtual_root_position_m=pos,
                    virtual_root_orientation_xyzw=ori,maximum_contact_displacement_m=drift,
                    contact_displacements_m=displacements);break
        m.require(witness is not None,"Posture nonlinear contact witness exhausted")
        m.require((jref>=self.bounds[:,0]-TOL).all() and (jref<=self.bounds[:,1]+TOL).all()
            and np.max(np.abs(contact@(fraction*delta)),initial=0.)<=TOL,"Posture final reference/linear contact bounds")
        # Numerical roundoff may sit just beyond a bound, so keep the recorded
        # reference exact and label tolerance; do not clip and break the witness.
        residuals=[dict(name=name,linear_requested_error=error,
            linear_scaled_residual=jac@(fraction*delta)-np.array(error)) for name,jac,error in tasks]
        nonlinear_orientation=np.array(orientation_vector(ori))
        return dict(status="solved",reference_joint_positions_rad=jref,
            legacy_bounded_reference_used=False,linear_contact_verified=True,nonlinear_contact_verified=True,
            reference_bound_tolerance_rad=TOL,linear_solution=solved,nonlinear_witness=witness,
            scaled_task_residuals=residuals,nonlinear_orientation_error_rad=nonlinear_orientation,
            nonlinear_com_error_m=after["whole_body_com"]-target_com,
            nonlinear_priority_guaranteed=False,virtual_base_is_not_actuated=True,**common)
