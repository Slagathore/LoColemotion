"""Five-step causal forecast with independent rigid contact detection.

The caller supplies only one starting pose/velocity and one held command.
Contact geometry is regenerated from predicted poses at every internal step.
The configured plane/capsule/box subset has isotropic tangential friction, so
a fixed orthonormal tangent basis represents the same circular friction cone.
No native dynamics, collision or quaternion API is called.
"""
import xml.etree.ElementTree as ET
import numpy as np
from actuation_recovery_mechanics import array,require
from floating_base_dynamics_inputs import C,numeric
from causal_contact_predictor import ContactPredictor,H,prepared_packet

STEPS=5
FRAME=[0.,0.,1.,1.,0.,0.,0.,1.,0.]


def integrate_position(qpos,post_velocity):
    """Semi-implicit translation/hinges and a body-local quaternion increment."""
    q=array(qpos,(15,),"Rollout starting position").copy()
    v=array(post_velocity,(14,),"Rollout integrated velocity")
    norm=np.linalg.norm(q[3:7]);require(abs(norm-1.)<1e-10,"Rollout unit root quaternion")
    a=q[3:7]/norm;speed=np.linalg.norm(v[3:6]);angle=.5*H*speed
    axis_factor=np.sin(angle)/speed if speed else .5*H
    b=np.r_[np.cos(angle),axis_factor*v[3:6]]
    q[3:7]=np.r_[a[0]*b[0]-a[1:] @ b[1:],a[0]*b[1:]+b[0]*a[1:]+np.cross(a[1:],b[1:])]
    q[:3]+=H*v[:3];q[7:]+=H*v[6:]
    require(np.isfinite(q).all(),"Rollout finite integrated pose")
    return q


def contact(geom,point,distance):
    return dict(geom=[0,geom],distance_m=float(distance),position_m=np.asarray(point).tolist(),frame=FRAME.copy())


def capsule_contacts(geom,endpoints,radius):
    ends=array(endpoints,(2,3),"Rollout capsule endpoints")
    require(type(radius) in (int,float) and np.isfinite(radius) and radius>0,"Rollout capsule radius")
    result=[]
    for center in ends:
        distance=center[2]-radius
        if distance<=0:
            point=center.copy();point[2]=distance/2.
            result.append(contact(geom,point,distance))
    return result


def box_contacts(geom,position,rotation,halfsize):
    p=array(position,(3,),"Rollout box position");r=array(rotation,(3,3),"Rollout box rotation")
    size=array(halfsize,(3,),"Rollout box size")
    require(np.all(size>0) and np.allclose(r.T @ r,np.eye(3),atol=1e-12,rtol=0)
        and abs(np.linalg.det(r)-1.)<1e-12,"Rollout proper box geometry")
    result=[]
    # Increasing corner bits match the configured native corner enumeration.
    for bits in range(8):
        offset=r @ (size*np.array([1. if bits&(1<<axis) else -1. for axis in range(3)]))
        distance=p[2]+offset[2]
        if distance<=0 and offset[2]<=0:
            point=p+offset;point[2]-=distance/2.
            result.append(contact(geom,point,distance))
            if len(result)==4:break
    return result


class HeldContactRollout:
    def __init__(self,profile,xml):
        self.contact_model=ContactPredictor(profile,xml);self.model=self.contact_model.model
        doc=ET.fromstring(xml);ground=doc.find("worldbody/geom")
        require(ground.get("type")=="plane" and ground.get("contype")=="1"
            and ground.get("conaffinity")=="2" and not any(k in ground.attrib for k in ("pos","quat","euler")),
            "Rollout fixed zero-height native ground")
        self.geometry=[]
        for index,body in enumerate(doc.iter("body")):
            geom=body.find("geom")
            require(geom.get("name")==body.get("name")+"_geom" and geom.get("contype")=="2"
                and geom.get("conaffinity")=="1" and not any(k in geom.attrib for k in ("pos","quat","euler")),
                "Rollout configured geom/body collision join")
            if index==0:
                require(geom.get("type")=="box" and "fromto" not in geom.attrib,"Rollout torso box")
                shape=dict(kind="box",size=numeric(geom.get("size"),3,"Rollout box halfsize"))
            else:
                require(geom.get("type")=="capsule","Rollout limb capsule")
                ends=numeric(geom.get("fromto"),6,"Rollout capsule segment").reshape(2,3)
                require(np.all(ends[:,:2]==0) and ends[0,2]<0 and ends[1,2]==-ends[0,2],
                    "Rollout symmetric local z capsule")
                shape=dict(kind="capsule",radius=float(numeric(geom.get("size"),1,"Rollout capsule radius")[0]),
                    endpoints=ends[::-1].copy())
            self.geometry.append(dict(shape,geom_id=index+1,body_id=body.get("name")))
        require(len(self.geometry)==9,"Rollout complete collider population")

    def detect(self,qpos):
        q=array(qpos,(15,),"Rollout collision position")
        frame=self.model.tree.kinematics(C @ q[:3],np.r_[C @ q[4:7],q[3]],q[7:])
        contacts=[]
        for i,shape in enumerate(self.geometry):
            position=C.T @ frame["positions"][i];rotation=C.T @ frame["rotations"][i] @ C
            if shape["kind"]=="box":contacts.extend(box_contacts(shape["geom_id"],position,rotation,shape["size"]))
            else:
                endpoints=shape["endpoints"] @ rotation.T+position
                contacts.extend(capsule_contacts(shape["geom_id"],endpoints,shape["radius"]))
        return contacts

    def predict(self,start):
        require(set(start)=={"qpos","qvel","target_velocity"},"Rollout only initial state and held command")
        q=array(start["qpos"],(15,),"Rollout initial position").copy()
        v=array(start["qvel"],(14,),"Rollout initial velocity").copy()
        target=array(start["target_velocity"],(8,),"Rollout fixed command")
        rows=[]
        output=dict(accepted=False,rows=rows,planned_steps=STEPS,held_target=target.tolist(),
            initial_state_only=True,intermediate_native_observations_used=False,measured_contact_geometry_used=False,
            measured_forces_used=False,worlds_opened=0,native_physics_steps=0,
            controller_changed=False,trained=False,tier2_qualified=False,tier3_benefit_established=False,
            physical_acceptance_authority=False,release_authority=False)
        for step in range(STEPS):
            geometry=self.detect(q);packet=prepared_packet(q,v,geometry,target)
            prediction=self.contact_model.predict(packet)
            row=dict(step=step,before_qpos=q.tolist(),before_qvel=v.tolist(),contacts=geometry,prediction=prediction)
            rows.append(row)
            if not prediction["accepted"]:
                output.update(refused_at_step=step,completed_steps=step);return output
            v=np.array(prediction["post_velocity"]);q=integrate_position(q,v)
            require(np.array_equal(q[7:],prediction["post_joint_position"]),"Rollout shared joint integration")
            row.update(qpos=q.tolist(),qvel=v.tolist())
        output.update(accepted=True,completed_steps=STEPS,final_qpos=q.tolist(),final_qvel=v.tolist())
        return output


def compare_geometry(predicted,observed):
    """Match all positions/depths/normals, allowing isotropic tangent rotation."""
    require(len(predicted)==len(observed),"Rollout contact count mismatch")
    maximum=0.;remaining=list(observed)
    for p in predicted:
        candidates=[(i,max(abs(p["distance_m"]-r["distance_m"]),
            float(np.max(np.abs(np.array(p["position_m"])-r["position_m"]))),
            float(np.max(np.abs(np.array(p["frame"][:3])-r["frame"][:3])))))
            for i,r in enumerate(remaining) if r["geom"]==p["geom"]]
        require(candidates,"Rollout missing geometry identity")
        index,error=min(candidates,key=lambda value:value[1]);remaining.pop(index);maximum=max(maximum,error)
    require(not remaining and maximum<=1e-10,"Rollout geometry exceeds declared roundoff tolerance")
    return maximum
