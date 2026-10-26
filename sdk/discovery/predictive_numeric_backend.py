"""Compiled numerical backend; public candidate and guard logic remains inherited."""
import ctypes
import hashlib
from pathlib import Path
import numpy as np
from actuation_recovery_mechanics import array,require,xyz,RigidTree
from floating_base_dynamics import FloatingDynamics
from causal_contact_predictor import ContactPredictor,certificate,SETTINGS,damping,H
from held_contact_rollout import HeldContactRollout
from predictive_command_selection_v2 import PredictiveSelector

PTR=ctypes.POINTER(ctypes.c_double)
SIZE=ctypes.c_size_t


class Kernels:
    def __init__(self,path,digest):
        path=Path(path).resolve(strict=True)
        require(hashlib.sha256(path.read_bytes()).hexdigest()==digest,"Kernel exact executable")
        self.dll=ctypes.CDLL(str(path))
        self.dll.lc_kin.argtypes=[PTR,SIZE,PTR,SIZE,PTR,SIZE]
        self.dll.lc_eval.argtypes=[PTR,SIZE,PTR,SIZE,PTR,PTR,PTR,ctypes.c_int,PTR,SIZE]
        self.dll.lc_jac.argtypes=[PTR,SIZE,PTR,SIZE,SIZE,PTR,PTR,SIZE]
        self.dll.lc_cones.argtypes=[PTR,SIZE,PTR,SIZE,PTR,SIZE,ctypes.c_double,ctypes.c_double,PTR,SIZE]
        for name in ("lc_kin","lc_eval","lc_jac","lc_cones"):getattr(self.dll,name).restype=ctypes.c_int

    @staticmethod
    def pointer(value):return value.ctypes.data_as(PTR)

    def kin(self,parameters,position,orientation,joints):
        q=np.ascontiguousarray(np.r_[position,orientation,joints],dtype=np.float64);out=np.empty(186)
        code=self.dll.lc_kin(self.pointer(parameters),151,self.pointer(q),15,self.pointer(out),186)
        require(code==0,"Kernel kinematics domain/output")
        return dict(positions=out[:27].reshape(9,3),rotations=out[27:108].reshape(9,3,3),
            centers=out[108:135].reshape(9,3),anchors=out[135:159].reshape(8,3),
            axes=out[159:183].reshape(8,3),whole_body_com=out[183:186])

    @staticmethod
    def frame(frame):
        return np.ascontiguousarray(np.concatenate([np.asarray(frame[k]).reshape(-1)
            for k in ("positions","rotations","centers","anchors","axes","whole_body_com")]),dtype=np.float64)

    def evaluate(self,parameters,frame,velocity,acceleration,gravity,mode):
        f=self.frame(frame);require(f.shape==(186,) and np.isfinite(f).all(),"Kernel frame")
        v=np.ascontiguousarray(array(velocity,(14,),"Kernel velocity"))
        a=np.ascontiguousarray(array(acceleration,(14,),"Kernel acceleration"))
        g=np.ascontiguousarray(array(gravity,(3,),"Kernel gravity"))
        length=(196,162,14)[mode];out=np.empty(length)
        code=self.dll.lc_eval(self.pointer(parameters),151,self.pointer(f),186,self.pointer(v),
            self.pointer(a),self.pointer(g),mode,self.pointer(out),length)
        require(code==0,"Kernel dynamics domain/output")
        return out

    def jacobians(self,parameters,frame,body,point):
        f=self.frame(frame);point=np.ascontiguousarray(array(point,(3,),"Kernel point"));out=np.empty(84)
        code=self.dll.lc_jac(self.pointer(parameters),151,self.pointer(f),186,body,
            self.pointer(point),self.pointer(out),84)
        require(code==0,"Kernel Jacobian domain/output")
        return out[:42].reshape(3,14),out[42:].reshape(3,14)

    def solve(self,matrix,linear,blocks):
        n=len(linear);q=np.ascontiguousarray(array(linear,(n,),"Kernel cone linear"))
        m=np.ascontiguousarray(array(matrix,(n,n),"Kernel cone matrix"))
        require(np.allclose(m,m.T,rtol=0,atol=1e-12),"Kernel symmetric cone matrix")
        if not n:return dict(accepted=True,force=[],iterations=0,certificate=certificate(m,q,np.zeros(0),blocks))
        require(SETTINGS==dict(maximum_iterations=5000,primal_tolerance=1e-10,
            dual_tolerance=1e-9,complementarity_tolerance=1e-8,maximum_contacts=32),"Kernel immutable solver tolerances")
        eigen=np.linalg.eigvalsh(m);require(eigen[0]>0,"Kernel strictly convex cone matrix")
        lipschitz=float(eigen[-1]);beta=(np.sqrt(lipschitz)-np.sqrt(eigen[0]))/(np.sqrt(lipschitz)+np.sqrt(eigen[0]))
        b=np.ascontiguousarray(np.array(blocks,dtype=np.float64).reshape(-1));out=np.empty(n+5)
        code=self.dll.lc_cones(self.pointer(m),n*n,self.pointer(q),n,self.pointer(b),len(b),
            lipschitz,float(beta),self.pointer(out),len(out))
        require(code==0,"Kernel cone domain/output")
        x=out[:n];checked=certificate(m,q,x,blocks)
        # The original Python certificate remains the acceptance authority.
        return dict(accepted=checked["accepted"],force=x.tolist(),iterations=int(out[n]),certificate=checked,
            minimum_eigenvalue=float(eigen[0]),maximum_eigenvalue=lipschitz,
            objective=float(.5*x @ m @ x+q @ x))


class KernelTree(RigidTree):
    def __init__(self,spec,joint_inertia,kernels):
        super().__init__(spec);require(self.n==8,"Kernel eight-joint model")
        self.kernels=kernels
        self.parameters=np.ascontiguousarray(np.r_[self.mass,self.local_com.reshape(-1),
            np.array([xyz(b["inertia_diagonal_kg_m2"]) for b in self.bodies]).reshape(-1),self.parent,
            np.array([xyz(j["axis_parent_unit"]) for j in self.joints]).reshape(-1),
            np.array([xyz(j["anchor_parent_m"]) for j in self.joints]).reshape(-1),
            np.array([xyz(j["anchor_child_m"]) for j in self.joints]).reshape(-1),joint_inertia])
        require(self.parameters.shape==(151,),"Kernel parameter layout")
    def kinematics(self,position,orientation_xyzw,joints):
        p=array(position,(3,),"Kernel root position");o=array(orientation_xyzw,(4,),"Kernel orientation")
        q=array(joints,(8,),"Kernel joints")
        return self.kernels.kin(self.parameters,p,o,q)


class KernelDynamics(FloatingDynamics):
    def __init__(self,spec,inertia,kernels):
        super().__init__(spec,inertia)
        self.kernels=kernels;self.tree=KernelTree(spec,self.joint_inertia,kernels);self.parameters=self.tree.parameters
    def jacobians(self,frame,body,point):
        require(body in self.tree.index,"Kernel body identity")
        return self.kernels.jacobians(self.parameters,frame,self.tree.index[body],point)
    def mass_matrix(self,frame):
        return self.kernels.evaluate(self.parameters,frame,np.zeros(14),np.zeros(14),np.zeros(3),0).reshape(14,14)
    def motion(self,frame,velocity,acceleration):
        result=self.kernels.evaluate(self.parameters,frame,velocity,acceleration,np.zeros(3),1).reshape(6,9,3)
        return dict(zip(("origin_velocity","angular_velocity","origin_acceleration","angular_acceleration",
            "com_velocity","com_acceleration"),result,strict=True))
    def inverse_dynamics(self,frame,velocity,acceleration,gravity):
        return self.kernels.evaluate(self.parameters,frame,velocity,acceleration,gravity,2)


class KernelContactPredictor(ContactPredictor):
    def __init__(self,profile,xml,kernels):
        super().__init__(profile,xml);self.kernels=kernels
        self.model=KernelDynamics(profile["morphology_spec"],self.model.joint_inertia,kernels)
    def predict(self,packet):
        problem=self.problem(packet);solution=self.kernels.solve(problem["matrix"],problem["linear"],problem["blocks"])
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


class KernelRollout(HeldContactRollout):
    def __init__(self,profile,xml,kernels):
        super().__init__(profile,xml)
        self.contact_model=KernelContactPredictor(profile,xml,kernels);self.model=self.contact_model.model


class KernelSelector(PredictiveSelector):
    def __init__(self,profile,xml,path,digest):
        super().__init__(profile,xml)
        self.kernels=Kernels(path,digest);self.rollout=KernelRollout(profile,xml,self.kernels)
        self.model=self.rollout.contact_model.model;self.limits=self.rollout.contact_model.limits
