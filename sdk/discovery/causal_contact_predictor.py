"""Configured soft-contact forward prediction from prepared, causal inputs.

This finite model supports the retained rigid MuJoCo 3.11 XML subset, not a
portable learned model. It independently solves the convex friction-cone
problem; it does not import MuJoCo, measured forces, a native optimizer or
post-step observations. Optimizer iterations are not physical solver steps.
"""
import xml.etree.ElementTree as ET
import numpy as np
from actuation_recovery_mechanics import array,require
from floating_base_dynamics import FloatingDynamics
from floating_base_dynamics_inputs import C,native_parameters,numeric
from held_dynamics_diagnostic_v2 import state,damping,H

SETTINGS=dict(maximum_iterations=5000,primal_tolerance=1e-10,
    dual_tolerance=1e-9,complementarity_tolerance=1e-8,maximum_contacts=32)
GEOMETRY_FIELDS=("geom","distance_m","position_m","frame")


def prepared_packet(qpos,qvel,contacts,target_velocity):
    """Copy only pre-step state, geometry and the candidate command."""
    return dict(qpos=list(qpos),qvel=list(qvel),target_velocity=list(target_velocity),
        contacts=[{key:(list(c[key]) if isinstance(c[key],(list,tuple)) else c[key])
            for key in GEOMETRY_FIELDS} for c in contacts])


def impedance(distance):
    """Pinned default midpoint=.5, power=2; XML specifies endpoints and width."""
    require(np.isfinite(distance),"Contact finite distance")
    x=min(abs(distance)/.001,1.)
    y=2*x*x if x<=.5 else 1.-2*(1.-x)**2
    return .9+(.95-.9)*y


def project_cones(value,blocks):
    """Euclidean projection onto scalar nonnegative or circular Coulomb cones."""
    value=array(value,(len(value),),"Contact finite projection input");out=np.zeros_like(value);offset=0
    for dim,mu in blocks:
        if dim==1:out[offset]=max(0.,value[offset])
        else:
            require(dim==3 and np.isfinite(mu) and mu>0,"Contact projection cone domain")
            normal=value[offset];tangent=value[offset+1:offset+3];length=np.linalg.norm(tangent)
            if normal>=0 and length<=mu*normal:out[offset:offset+3]=value[offset:offset+3]
            elif normal+mu*length>0:
                normal=(normal+mu*length)/(1.+mu*mu)
                out[offset]=normal;out[offset+1:offset+3]=mu*normal*tangent/length
        offset+=dim
    require(offset==len(value) and np.isfinite(out).all(),"Contact projection population")
    return out


def certificate(matrix,linear,value,blocks):
    """Independent primal/dual cone membership and complementary slackness."""
    n=len(value);matrix=array(matrix,(n,n),"Contact certificate matrix")
    linear=array(linear,(n,),"Contact certificate vector");value=array(value,(n,),"Contact certificate force")
    gradient=matrix @ value+linear;primal=dual=comp=0.;offset=0
    for dim,mu in blocks:
        x=value[offset:offset+dim];g=gradient[offset:offset+dim]
        if dim==1:p=-x[0];d=-g[0]
        else:
            p=max(-x[0],np.linalg.norm(x[1:])-mu*x[0])
            d=max(-g[0],mu*np.linalg.norm(g[1:])-g[0])
        primal=max(primal,float(p));dual=max(dual,float(d));comp=max(comp,abs(float(x @ g)))
        offset+=dim
    require(offset==len(value),"Contact certificate population")
    return dict(accepted=primal<=SETTINGS["primal_tolerance"] and dual<=SETTINGS["dual_tolerance"]
        and comp<=SETTINGS["complementarity_tolerance"],primal_violation=primal,
        dual_violation=dual,maximum_complementarity=comp)


def solve_cones(matrix,linear,blocks):
    """Cold-start accelerated projected gradient for a strictly convex QP."""
    n=len(linear);q=array(linear,(n,),"Contact objective vector");m=array(matrix,(n,n),"Contact objective matrix")
    require(np.allclose(m,m.T,rtol=0,atol=1e-12),"Contact symmetric objective")
    if not n:return dict(accepted=True,force=[],iterations=0,certificate=certificate(m,q,np.zeros(0),blocks))
    eigen=np.linalg.eigvalsh(m);require(eigen[0]>0,"Contact strictly convex objective")
    lipschitz=float(eigen[-1]);beta=(np.sqrt(lipschitz)-np.sqrt(eigen[0]))/(np.sqrt(lipschitz)+np.sqrt(eigen[0]))
    x=np.zeros(n);y=x.copy()
    for iteration in range(1,SETTINGS["maximum_iterations"]+1):
        new=project_cones(y-(m @ y+q)/lipschitz,blocks)
        y=new+beta*(new-x);x=new
        if iteration==1 or iteration%8==0:
            checked=certificate(m,q,x,blocks)
            if checked["accepted"]:break
    checked=certificate(m,q,x,blocks)
    return dict(accepted=checked["accepted"],force=x.tolist(),iterations=iteration,
        certificate=checked,minimum_eigenvalue=float(eigen[0]),maximum_eigenvalue=lipschitz,
        objective=float(.5*x @ m @ x+q @ x))


class ContactPredictor:
    def __init__(self,profile,xml):
        spec=profile["morphology_spec"];native=native_parameters(xml,spec)
        self.model=FloatingDynamics(spec,native["joint_inertia_kg_m2"])
        require(np.all(self.model.damping==0),"Contact unsupported passive damping")
        doc=ET.fromstring(xml);option=doc.find("option")
        require(option.attrib==dict(timestep=str(H),gravity="0 0 -9.8",integrator="implicitfast",
            solver="Newton",iterations="20",ls_iterations="7",cone="elliptic"),"Contact exact configured solver subset")
        require(not any(list(doc.iter(x)) for x in ("default","pair","equality","tendon","flex","plugin")),
            "Contact unsupported native model feature")
        self.body_names=["world"]+self.model.tree.body_ids
        geoms=list(doc.iter("geom"));self.geom_bodies=["world"]
        require(geoms[0].get("name")=="ground" and geoms[0].get("type")=="plane","Contact ground identity")
        for body in doc.iter("body"):
            require(len(body.findall("geom"))==1,"Contact one geometry per body")
            self.geom_bodies.append(body.get("name"))
        require(len(geoms)==10 and len(self.geom_bodies)==10,"Contact geometry population")
        for geom in geoms:
            require(geom.get("solref")==".02 1" and geom.get("solimp")==".9 .95 .001"
                and np.array_equal(numeric(geom.get("friction"),3,"Contact friction"),[.95,.005,.0001])
                and not any(k in geom.attrib for k in ("margin","gap","condim","priority","solmix")),
                "Contact uniform configured surface and pinned defaults")
        self.gains=array(profile["velocity_gains"],(8,),"Contact motor gains")
        self.ranges=array(profile["force_ranges"],(8,2),"Contact motor caps")
        actuators=list(doc.find("actuator"))
        require(len(actuators)==8 and all(a.tag=="velocity" for a in actuators),"Contact direct velocity actuators")
        for i,a in enumerate(actuators):
            require(set(a.attrib)=={"name","joint","gear","ctrllimited","kv","forcelimited","forcerange"}
                and a.get("joint")==self.model.tree.joint_ids[i] and float(a.get("kv"))==self.gains[i]
                and np.array_equal(numeric(a.get("forcerange"),2,"Contact force range"),self.ranges[i])
                and a.get("forcelimited")=="true" and a.get("gear")=="1 0 0 0 0 0"
                and a.get("ctrllimited")=="false" and not any(k in a.attrib for k in ("biasprm","actrange")),
                "Contact configured actuator join")
        self.limits=np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in self.model.tree.joints])
        # MuJoCo's constant inverse-weight approximation is evaluated at qpos0.
        root=numeric(doc.find("worldbody/body").get("pos"),3,"Contact reference root")
        zero=state(self.model,np.r_[root,1.,0.,0.,0.,np.zeros(8)],np.zeros(14))
        inverse=np.linalg.inv(zero["mass"]);self.dof_weight=np.diag(inverse)[6:]
        self.body_weight={"world":0.}
        for index,body in enumerate(self.model.tree.body_ids):
            jac=self.model.jacobians(zero["frame"],body,zero["frame"]["centers"][index])[0] @ zero["t"].T
            self.body_weight[body]=float(np.trace(jac @ inverse @ jac.T)/3.)

    def problem(self,packet):
        require(set(packet)=={"qpos","qvel","target_velocity","contacts"},"Contact causal packet fields")
        q=array(packet["qpos"],(15,),"Contact prepared position");v=array(packet["qvel"],(14,),"Contact prepared velocity")
        target=array(packet["target_velocity"],(8,),"Contact candidate command")
        require(np.all(np.abs(target)<=3.5+1e-12),"Contact command range")
        s=state(self.model,q,v);jacobians=[];regularizer=[];reference=[];blocks=[];identities=[]
        k=1./(.95*.95*.02*.02);b=2./(.95*.02)
        for j,(lo,hi) in enumerate(self.limits):
            if lo<=q[7+j]<=hi:continue
            sign=1. if q[7+j]<lo else -1.;distance=q[7+j]-lo if sign>0 else hi-q[7+j]
            jac=np.zeros(14);jac[6+j]=sign;imp=impedance(distance)
            jacobians.append(jac);regularizer.append((1.-imp)*self.dof_weight[j]/imp)
            reference.append(-b*(jac @ v)-k*imp*distance);blocks.append((1,0.))
            identities.append(dict(kind="joint_limit",joint_id=self.model.tree.joint_ids[j]))
        require(isinstance(packet["contacts"],list) and len(packet["contacts"])<=SETTINGS["maximum_contacts"],"Contact bounded geometry population")
        for index,c in enumerate(packet["contacts"]):
            require(set(c)==set(GEOMETRY_FIELDS),"Contact geometry contains future force or unsupported fields")
            geom=c["geom"];require(len(geom)==2 and all(type(g) is int and 0<=g<10 for g in geom)
                and geom[0]==0 and geom[1]!=0,"Contact ground-to-body geometry")
            distance=c["distance_m"];require(type(distance) in (int,float) and np.isfinite(distance),"Contact finite penetration")
            # Zero contact margin: positive separation contributes no constraint.
            if distance>=0:continue
            frame=array(c["frame"],(9,),"Contact frame").reshape(3,3)
            require(np.allclose(frame @ frame.T,np.eye(3),atol=1e-12,rtol=0)
                and abs(np.linalg.det(frame)-1.)<1e-12,"Contact orthonormal proper frame")
            body=self.geom_bodies[geom[1]];point=C @ array(c["position_m"],(3,),"Contact application point")
            jac=frame @ C.T @ self.model.jacobians(s["frame"],body,point)[0] @ s["t"].T
            imp=impedance(distance);r=(1.-imp)*self.body_weight[body]/imp
            aref=-b*(jac @ v);aref[0]-=k*imp*distance
            jacobians.extend(jac);regularizer.extend([r]*3);reference.extend(aref)
            blocks.append((3,.95));identities.append(dict(kind="contact",native_index=index,body_id=body))
        jac=np.array(jacobians).reshape(-1,14);r=np.array(regularizer);aref=np.array(reference)
        force=np.clip(self.gains*(target-v[6:]),self.ranges[:,0],self.ranges[:,1])
        applied=np.r_[np.zeros(6),force]+s["passive"]-s["bias"]
        unconstrained=np.linalg.solve(s["mass"],applied)
        matrix=jac @ np.linalg.solve(s["mass"],jac.T)+np.diag(r);matrix=(matrix+matrix.T)/2.
        linear=jac @ unconstrained-aref
        return dict(matrix=matrix,linear=linear,blocks=blocks,identities=identities,jacobian=jac,
            regularizer=r,reference_acceleration=aref,mass=s["mass"],applied=applied,
            actuator_force=force,qpos=q,qvel=v)

    def predict(self,packet):
        problem=self.problem(packet);solution=solve_cones(problem["matrix"],problem["linear"],problem["blocks"])
        output=dict(accepted=solution["accepted"],solution=solution,constraints=problem["identities"],
            future_measured_forces_used=False,world_build_count=0,physics_solver_steps=0,
            controller_changed=False,trained=False,physical_acceptance_authority=False,
            tier2_qualified=False,tier3_benefit_established=False)
        if not solution["accepted"]:return output
        force=np.array(solution["force"]);generalized=problem["jacobian"].T @ force
        effective=problem["mass"]+H*np.diag(damping(problem["actuator_force"],self.gains,self.ranges))
        acceleration=np.linalg.solve(effective,problem["applied"]+generalized)
        velocity=problem["qvel"]+H*acceleration
        output.update(contact_generalized_force=generalized.tolist(),actuator_force=problem["actuator_force"].tolist(),
            integrated_acceleration=acceleration.tolist(),post_velocity=velocity.tolist(),
            post_joint_position=(problem["qpos"][7:]+H*velocity[6:]).tolist(),
            minimum_regularizer=float(np.min(problem["regularizer"])) if len(force) else None)
        return output
