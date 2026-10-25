"""Exact fixed-base capsule-height minima for the declared sagittal 2R legs.

This is a kinematic bound, not a collision-free path or dynamic recovery proof.
"""
import math
import numpy as np
import actuation_recovery_mechanics as m

LIMBS=("front_left","front_right","rear_left","rear_right")


def stationary(a,b,lower,upper):
    """All stationary angles of a*sin(q)-b*cos(q) on a bounded interval."""
    values=[lower,upper]
    if a!=0. or b!=0.:
        origin=math.atan2(-a,b)
        first=math.ceil((lower-origin)/math.pi)
        last=math.floor((upper-origin)/math.pi)
        values.extend(origin+i*math.pi for i in range(first,last+1))
    return sorted(set(values))


def capsule_minimum(hip_height,a,b,lengths,radius,bounds):
    """Global rectangle minimum: both capsule endpoints, edges and stationary points."""
    v=m.array([hip_height,a,b,*lengths,radius],(6,),"Reach finite geometry")
    limits=m.array(bounds,(2,2),"Reach joint bounds")
    m.require(all(v[i]>0 for i in (3,4,5)) and (limits[:,0]<limits[:,1]).all()
        and np.max(np.abs(limits))<=2*math.pi and a*a+b*b<=1.+1e-12,"Reach planar domain")
    l1,l2=lengths;hl,hu=limits[0];kl,ku=limits[1];candidates=[]
    def f(q):return a*math.sin(q)-b*math.cos(q)
    def add(h,k):
        if hl-1e-12<=h<=hu+1e-12 and kl-1e-12<=k<=ku+1e-12:
            h=float(np.clip(h,hl,hu));k=float(np.clip(k,kl,ku))
            knee=hip_height+l1*f(h)
            distal=knee+l2*f(h+k)
            candidates.append((min(knee,distal)-radius,h,k,"knee" if knee<distal else "distal"))
    for h in (hl,hu):
        for angle in stationary(a,b,h+kl,h+ku):add(h,angle-h)
    for k in (kl,ku):
        aa=l1*a+l2*(a*math.cos(k)+b*math.sin(k))
        bb=l1*b+l2*(b*math.cos(k)-a*math.sin(k))
        for h in stationary(aa,bb,hl,hu):add(h,k)
    for h in stationary(a,b,hl,hu):
        add(h,float(np.clip(0.,kl,ku))) # proximal capsule endpoint
        for angle in stationary(a,b,h+kl,h+ku):add(h,angle-h)
    best=min(candidates)
    lower=hip_height-(l1+l2)*math.hypot(a,b)-radius
    m.require(best[0]>=lower-1e-12,"Reach bounded minimum below universal lower bound")
    return dict(minimum_clearance_m=best[0],minimizing_joint_positions_rad=list(best[1:3]),
        lowest_capsule_endpoint=best[3],unconstrained_clearance_lower_bound_m=lower,
        candidates_evaluated=len(candidates),dynamic_feasibility_established=False)


class ReachModel:
    def __init__(self,spec):
        self.tree=m.RigidTree(spec);t=self.tree;self.legs=[]
        m.require(t.body_ids==["torso"]+[x+s for x in LIMBS for s in ("_upper","_distal")]
            and t.joint_ids==[x+s for x in LIMBS for s in ("_hip","_knee")],"Reach exact sagittal topology")
        for i,limb in enumerate(LIMBS):
            h,k=t.joints[2*i:2*i+2];upper,distal=t.bodies[2*i+1:2*i+3]
            for j in (h,k):
                m.require(np.array_equal(m.xyz(j["axis_parent_unit"]),[0.,0.,1.]),"Reach parallel sagittal axes")
            for body in (upper,distal):
                m.require(body["collision"]["kind"]=="capsule","Reach capsule bodies")
            l1=upper["collision"]["length_m"];l2=distal["collision"]["length_m"]
            m.require(np.array_equal(m.xyz(h["anchor_child_m"]),[0.,l1/2,0.])
                and np.array_equal(m.xyz(k["anchor_parent_m"]),[0.,-l1/2,0.])
                and np.array_equal(m.xyz(k["anchor_child_m"]),[0.,l2/2,0.]),"Reach centered link anchors")
            site=spec["contact_sites"][i]
            m.require(site["contact_site_id"]==limb+"_foot" and site["body_id"]==distal["body_id"]
                and np.array_equal(m.xyz(site["local_center_m"]),[0.,-l2/2,0.])
                and site["radius_m"]==distal["collision"]["radius_m"],"Reach contact/capsule binding")
            self.legs.append(dict(limb=limb,lengths=[l1,l2],radius=site["radius_m"],
                bounds=[[j["lower_limit_rad"],j["upper_limit_rad"]] for j in (h,k)]))

    def evaluate(self,position,orientation,joints):
        t=self.tree;frame=t.kinematics(position,orientation,joints);r=frame["rotations"][0];results=[]
        for i,leg in enumerate(self.legs):
            body=2*i+2;length=leg["lengths"][1]
            endpoints=np.array([[0.,length/2,0.],[0.,-length/2,0.]])
            world=frame["positions"][body]+endpoints @ frame["rotations"][body].T
            result=capsule_minimum(float(frame["anchors"][2*i,1]),float(r[1,0]),float(r[1,1]),
                leg["lengths"],leg["radius"],leg["bounds"])
            witness=list(joints);witness[2*i:2*i+2]=result["minimizing_joint_positions_rad"]
            other=t.kinematics(position,orientation,witness)
            witness_world=other["positions"][body]+endpoints @ other["rotations"][body].T
            attained=float(witness_world[:,1].min()-leg["radius"])
            m.require(abs(attained-result["minimum_clearance_m"])<=2e-12,"Reach exact minimizer forward-kinematics witness")
            result.update(contact_site_id=leg["limb"]+"_foot",current_clearance_m=float(world[:,1].min()-leg["radius"]),
                minimum_root_lowering_m=max(0.,result["minimum_clearance_m"]),
                current_joint_positions_within_bounds=all(lo<=q<=hi for q,(lo,hi) in zip(joints[2*i:2*i+2],leg["bounds"],strict=True)),
                native_world_constructed=False,body_pose_held_fixed=True)
            results.append(result)
        return results


def reference_parameters():
    return dict(maximum_com_lowering_m=.10,
        maximum_com_reference_lowering_speed_m_s=.20,touchdown_clearance_margin_m=.003,
        controller_dt_s=1./120.,automatic_height_raise=False)


def support_reference(reaches,support,root_y,com_y,nominal_com_y,previous_com_y,parameters):
    """Causal lowering-only reference; airborne legs extend within declared limits.

    A positive remaining gap is retained. Reference bounds do not bound real motion.
    """
    m.require(parameters==reference_parameters(),"Reach immutable reference parameters")
    sites=[x+"_foot" for x in LIMBS]
    m.require([r["contact_site_id"] for r in reaches]==sites and set(support)==set(sites)
        and all(type(v) is bool for v in support.values()),"Reach support identity/types")
    vals=m.array([root_y,com_y,nominal_com_y,previous_com_y],(4,),"Reach reference state")
    m.require(nominal_com_y>0 and nominal_com_y-parameters["maximum_com_lowering_m"]-1e-12<=previous_com_y<=nominal_com_y+1e-12,"Reach reference memory")
    for r in reaches:
        m.array([r["minimum_clearance_m"],*r["minimizing_joint_positions_rad"]],(3,),"Reach finite witness")
    floor=nominal_com_y-parameters["maximum_com_lowering_m"]
    airborne=[r for r in reaches if not support[r["contact_site_id"]]]
    gap=max([0.]+[r["minimum_clearance_m"]+parameters["touchdown_clearance_margin_m"] for r in airborne])
    desired=max(floor,min(nominal_com_y,com_y-gap))
    following=min(previous_com_y,max(desired,previous_com_y-parameters["maximum_com_reference_lowering_speed_m_s"]*parameters["controller_dt_s"]))
    qref=[0.]*8
    for i,r in enumerate(reaches):
        if not support[r["contact_site_id"]]:qref[2*i:2*i+2]=r["minimizing_joint_positions_rad"]
    predicted_lowering=com_y-following
    return dict(target_com_height_m=float(following),reference_joint_positions_rad=qref,
        requested_fixed_pose_lowering_m=gap,reference_floor_m=float(floor),
        remaining_fixed_pose_gap_m=max([0.]+[r["minimum_clearance_m"]-predicted_lowering for r in airborne]),
        posture_reference_is_not_issued_actuation=True,realized_body_height_bounded=False,
        collision_free_path_established=False,dynamic_feasibility_established=False)
