"""Read configured inertia from the exact retained native XML subset."""
import xml.etree.ElementTree as ET
import numpy as np
from actuation_recovery_mechanics import array,xyz,require

C=np.array([[1.,0.,0.],[0.,0.,1.],[0.,-1.,0.]])


def numeric(text,n,label):
    require(isinstance(text,str),label+" missing")
    return array([float(v) for v in text.split()],(n,),label)


def native_parameters(xml,spec):
    doc=ET.fromstring(xml);bodies=list(doc.iter("body"));joints=list(doc.iter("joint"))
    require(not list(doc.iter("default")) and doc.find("compiler").get("inertiafromgeom")=="false",
        "Dynamics explicit native inertial model")
    require([b.get("name") for b in bodies]==[b["body_id"] for b in spec["bodies"]]
        and [j.get("name") for j in joints]==[j["joint_id"] for j in spec["joints"]],
        "Dynamics native body/joint order")
    require(len(list(doc.iter("freejoint")))==1 and bodies[0].find("freejoint") is not None
        and set(bodies[0].find("freejoint").attrib)=={"name"},"Dynamics unactuated native root")
    for body,source in zip(bodies,spec["bodies"],strict=True):
        require(set(body.attrib)<= {"name","pos"},"Dynamics undeclared body rotation")
        inertial=body.find("inertial")
        require(inertial is not None and set(inertial.attrib)=={"pos","mass","diaginertia"},
            "Dynamics declared diagonal body inertia frame")
        require(abs(float(inertial.get("mass"))-source["mass_kg"])<=1e-12
            and np.allclose(numeric(inertial.get("pos"),3,"Dynamics native COM"),C.T @ xyz(source["center_of_mass_local_m"]),rtol=0,atol=1e-12)
            and np.allclose(np.diag(numeric(inertial.get("diaginertia"),3,"Dynamics native inertia")),
                C.T @ np.diag(xyz(source["inertia_diagonal_kg_m2"])) @ C,rtol=0,atol=1e-12),
            "Dynamics native/portable mass COM inertia join")
    inertia=[];damping=[]
    for j,source in zip(joints,spec["joints"],strict=True):
        require(set(j.attrib)<= {"name","type","pos","axis","limited","range","damping","armature"}
            and j.get("type")=="hinge","Dynamics native joint subset")
        arm=numeric(j.get("armature"),1,"Dynamics explicit native joint inertia")[0]
        damp=numeric(j.get("damping"),1,"Dynamics explicit native damping")[0]
        require(arm>=0 and damp==source["passive_damping_nms_per_rad"]
            and np.allclose(numeric(j.get("axis"),3,"Dynamics native axis"),C.T @ xyz(source["axis_parent_unit"]),rtol=0,atol=1e-12)
            and np.allclose(numeric(j.get("pos"),3,"Dynamics native anchor"),C.T @ xyz(source["anchor_child_m"]),rtol=0,atol=1e-12),
            "Dynamics native joint coefficient/geometry join")
        inertia.append(float(arm));damping.append(float(damp))
    return dict(ordered_joints=[j["joint_id"] for j in spec["joints"]],
        joint_inertia_kg_m2=inertia,passive_damping_nms_per_rad=damping,
        coefficient_source="explicit retained native XML; configured, not estimated",
        native_dynamics_equivalence_established=False)


def verify_native_state(model,frame,velocity,observation):
    """Join retained COM-based native spatial velocity to each body COM."""
    from floating_base_dynamics_checks import check_close
    nbody=model.n+1
    pos=array(observation["xpos"],(nbody+1,3),"Dynamics native body positions")
    centers=array(observation["xipos"],(nbody+1,3),"Dynamics native centers")
    subtree=array(observation["subtree_com"],(nbody+1,3),"Dynamics native subtree centers")
    rotations=array(observation["xmat"],(nbody+1,9),"Dynamics native body rotations").reshape(-1,3,3)
    spatial=array(observation["cvel"],(nbody+1,6),"Dynamics native COM-based velocities")
    qvel=array(observation["qvel"],(model.size,),"Dynamics native generalized velocity")
    v=array(velocity,(model.size,),"Dynamics canonical generalized velocity")
    motion=model.motion(frame,v,np.zeros(model.size))
    # Native cvel is world-aligned but centered at this tree's subtree COM.
    angular=spatial[1:,:3] @ C.T
    com_velocity=(spatial[1:,3:]+np.cross(spatial[1:,:3],centers[1:]-subtree[1])) @ C.T
    native_basis=np.r_[C @ qvel[:3],C @ rotations[1] @ qvel[3:6],qvel[6:]]
    expected_rotations=np.array([C @ r @ C.T for r in rotations[1:]])
    pairs=dict(body_position_m=(frame["positions"],pos[1:] @ C.T),
        body_center_m=(frame["centers"],centers[1:] @ C.T),
        body_rotation=(frame["rotations"],expected_rotations),
        whole_com_m=(frame["whole_body_com"],C @ subtree[1]),
        generalized_velocity=(v,native_basis),
        body_angular_velocity_rad_s=(motion["angular_velocity"],angular),
        body_com_velocity_m_s=(motion["com_velocity"],com_velocity))
    return {name:check_close(a,b,1e-9,1e-9,"Dynamics native "+name) for name,(a,b) in pairs.items()}
