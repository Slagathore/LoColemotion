"""Portable instantaneous whole-body response with simultaneous ground contacts.

Generalized velocities are root translation and rotation in world coordinates,
then revolute joint rates. A finite inelastic impulse projection accounts for
all supplied contacts together. It is a development prediction model, not the
native soft-contact solver, a physical observation, or a recovery certificate.
"""
import math

import numpy as np

from actuation_recovery_mechanics import RigidTree, array, require, xyz


def cross_matrix(value):
    x,y,z=value
    return np.array([[0.,-z,y],[z,0.,-x],[-y,x,0.]])


class CoupledBody:
    def __init__(self,spec):
        self.tree=RigidTree(spec)
        self.inertia=np.asarray([xyz(b['inertia_diagonal_kg_m2']) for b in self.tree.bodies])
        self.width=6+self.tree.n

    def jacobian(self,frame,body,point):
        linear,angular=self.tree.jacobian(frame,body,point)
        lever=np.asarray(point)-frame['positions'][0]
        return (np.column_stack((np.eye(3),-cross_matrix(lever),linear)),
                np.column_stack((np.zeros((3,3)),np.eye(3),angular)))

    def prepare(self,position,quaternion,joints,velocity,gravity=(0.,-9.8,0.)):
        """Rigid-body kinetic metric, gravity, and velocity-dependent bias.

        Bias accelerations propagate with zero generalized acceleration. This
        retains centrifugal and gyroscopic terms instead of treating joint
        gravity compensation as full floating-body dynamics.
        """
        tree=self.tree;frame=tree.kinematics(position,quaternion,joints)
        velocity=array(velocity,(self.width,),'Coupled generalized velocity')
        gravity=array(gravity,(3,),'Coupled gravity')
        count=len(tree.bodies);omega=np.zeros((count,3));alpha=np.zeros_like(omega);acc=np.zeros_like(omega)
        omega[0]=velocity[3:6]
        for i,child in enumerate(tree.child):
            parent=tree.parent[i];relative=frame['axes'][i]*velocity[6+i]
            omega[child]=omega[parent]+relative
            alpha[child]=alpha[parent]+np.cross(omega[parent],relative)
            ra=frame['anchors'][i]-frame['positions'][parent]
            rc=frame['positions'][child]-frame['anchors'][i]
            anchor_acc=acc[parent]+np.cross(alpha[parent],ra)+np.cross(omega[parent],np.cross(omega[parent],ra))
            acc[child]=anchor_acc+np.cross(alpha[child],rc)+np.cross(omega[child],np.cross(omega[child],rc))
        mass=np.zeros((self.width,self.width));bias=np.zeros(self.width);weight=np.zeros(self.width)
        body_jacobians=[]
        for i,name in enumerate(tree.body_ids):
            linear,angular=self.jacobian(frame,name,frame['centers'][i]);body_jacobians.append((linear,angular))
            r=frame['rotations'][i];inertia=(r*self.inertia[i]) @ r.T
            arm=frame['centers'][i]-frame['positions'][i]
            center_acc=acc[i]+np.cross(alpha[i],arm)+np.cross(omega[i],np.cross(omega[i],arm))
            mass+=tree.mass[i]*(linear.T @ linear)+angular.T @ inertia @ angular
            bias+=linear.T @ (tree.mass[i]*center_acc)+angular.T @ (inertia @ alpha[i]+np.cross(omega[i],inertia @ omega[i]))
            weight+=linear.T @ (tree.mass[i]*gravity)
        require(np.isfinite(mass).all() and np.isfinite(bias).all(),'Coupled finite dynamics')
        np.linalg.cholesky(mass)
        return dict(frame=frame,velocity=velocity.copy(),mass=mass,bias=bias,gravity=weight,body_jacobians=body_jacobians)

    def wrench(self,prepared,body,point,force,torque=(0.,0.,0.)):
        linear,angular=self.jacobian(prepared['frame'],body,array(point,(3,),'Coupled wrench point'))
        return linear.T @ array(force,(3,),'Coupled wrench force')+angular.T @ array(torque,(3,),'Coupled wrench torque')


def nonnegative_quadratic(matrix,linear,*,tolerance=1e-9,maximum_iterations=1024):
    """Active-set solve of min 0.5*x*A*x+b*x, x>=0, with a KKT receipt.

    The caller supplies a positive definite regularized contact metric. A
    bounded iteration failure is explicit and cannot silently become a score.
    """
    raw=np.asarray(linear);require(raw.ndim==1,'Coupled quadratic vector')
    b=array(raw,raw.shape,'Coupled quadratic linear term');n=len(b)
    a=array(matrix,(n,n),'Coupled quadratic metric')
    require(type(maximum_iterations) is int and 1<=maximum_iterations<=4096 and
            type(tolerance) in (int,float) and math.isfinite(tolerance) and 0<tolerance<=1e-6,'Coupled solver bounds')
    require(np.allclose(a,a.T,atol=1e-12,rtol=1e-12),'Coupled symmetric metric')
    if n:np.linalg.cholesky(a)
    x=np.zeros(n);active=np.zeros(n,dtype=bool);iterations=0
    while iterations<maximum_iterations:
        gradient=a @ x+b
        eligible=np.where(~active,gradient,np.inf)
        if not n or np.min(eligible)>=-tolerance:break
        active[int(np.argmin(eligible))]=True
        while iterations<maximum_iterations:
            iterations+=1;chosen=np.flatnonzero(active);proposal=np.zeros(n)
            proposal[chosen]=np.linalg.solve(a[np.ix_(chosen,chosen)],-b[chosen])
            if np.all(proposal[chosen]>0.):x=proposal;break
            dropping=chosen[proposal[chosen]<=0.]
            denominator=x[dropping]-proposal[dropping]
            ratios=np.divide(x[dropping],denominator,out=np.zeros(len(dropping)),where=denominator>0.)
            # A newly activated zero variable may already need to leave.
            fraction=min(1.,float(np.min(ratios)))
            x+=fraction*(proposal-x)
            leaving=active & (x<=tolerance);active[leaving]=False;x[leaving]=0.
    gradient=a @ x+b
    projected=x-np.maximum(0.,x-gradient)
    residual=float(np.max(np.abs(projected),initial=0.))
    return dict(solution=x,iterations=iterations,kkt_residual=residual,converged=residual<=tolerance*10)


def velocity_actuation(velocity,targets,gains,force_ranges,damping):
    """Clipped joint torque and its local velocity derivative, in joint order.

    A saturated motor contributes no feedback derivative, including exactly
    on either force bound. Passive joint damping still acts there. Targets
    must already use the caller's transport precision; no engine is invoked.
    """
    raw=np.asarray(velocity);require(raw.ndim==1,'Coupled actuator velocity shape')
    n=len(raw);v=array(raw,(n,),'Coupled actuator velocity')
    target=array(targets,(n,),'Coupled actuator targets');gain=array(gains,(n,),'Coupled actuator gains')
    limits=array(force_ranges,(n,2),'Coupled actuator force ranges');passive=array(damping,(n,),'Coupled actuator damping')
    require(np.all(gain>=0.) and np.all(passive>=0.) and np.all(limits[:,0]<=0.) and
            np.all(limits[:,1]>=0.),'Coupled dissipative actuator parameters')
    demand=gain*(target-v);require(np.isfinite(demand).all(),'Coupled finite actuator demand')
    motor=np.clip(demand,limits[:,0],limits[:,1])
    active=(demand>limits[:,0]) & (demand<limits[:,1])
    return dict(applied=np.r_[np.zeros(6),motor-passive*v],motor=motor,
                velocity_derivative=-passive-gain*active)


def response(model,prepared,applied,contacts,dt,*,penetration_recovery_time=.02,regularization=1e-8,tolerance=1e-9,
             joint_armature=None,joint_velocity_derivative=None):
    """Predict one interval, including unilateral torso/limb reactions.

    Contact point, normal, gap, and friction are explicit prepared inputs.
    Four nonnegative rays make an L1 friction pyramid. Positive gaps require
    closing motion before an impulse; penetrations request separation over the
    explicit recovery time instead of being corrected in one short step. This
    finite projection does not imitate native contact softness. Supplying both
    actuator terms opts into M + armature - dt*d(force)/d(velocity), including
    that metric in the contact impulse solve. Omitting both preserves v1.
    Neither mode claims equivalence with a native soft-contact integrator.
    """
    require(type(dt) in (int,float) and math.isfinite(dt) and 0<dt<=1/30,'Coupled interval')
    require(type(penetration_recovery_time) in (int,float) and math.isfinite(penetration_recovery_time)
            and dt<=penetration_recovery_time<=1.,'Coupled penetration recovery time')
    require(type(regularization) in (int,float) and math.isfinite(regularization) and 0<regularization<=1e-4,'Coupled regularization')
    applied=array(applied,(model.width,),'Coupled applied generalized force')
    actuator_aware=joint_armature is not None
    require(actuator_aware==(joint_velocity_derivative is not None),'Coupled complete actuator dynamics')
    mass=prepared['mass']
    if actuator_aware:
        armature=array(joint_armature,(model.tree.n,),'Coupled joint armature')
        derivative=array(joint_velocity_derivative,(model.tree.n,),'Coupled joint velocity derivative')
        require(np.all(armature>=0.) and np.all(derivative<=0.),'Coupled passive actuator metric')
        mass=mass+np.diag(np.r_[np.zeros(6),armature-dt*derivative])
    require(type(contacts) is list and len(contacts)<=64,'Coupled contact population')
    rows=[];offset=[];slices=[];rays=[]
    for contact in contacts:
        require(type(contact) is dict and set(contact)=={'body_id','point','normal','gap','friction'},'Coupled contact fields')
        point=array(contact['point'],(3,),'Coupled contact point');normal=array(contact['normal'],(3,),'Coupled contact normal')
        require(abs(float(normal @ normal)-1.)<=1e-10,'Coupled contact unit normal')
        gap,mu=contact['gap'],contact['friction']
        require(all(type(v) in (int,float) and math.isfinite(v) for v in (gap,mu)) and abs(gap)<=.05 and 0<=mu<=2.,'Coupled contact gap or friction')
        basis=np.eye(3)[int(np.argmin(np.abs(normal)))];tangent=np.cross(normal,basis);tangent/=np.linalg.norm(tangent)
        other=np.cross(normal,tangent)
        directions=np.asarray([normal] if mu==0 else [normal+mu*tangent,normal-mu*tangent,normal+mu*other,normal-mu*other])
        linear,_=model.jacobian(prepared['frame'],contact['body_id'],point)
        speed_offset=max(0.,gap)/dt+min(0.,gap)/penetration_recovery_time
        start=len(rows);rows.extend(directions @ linear);offset.extend([speed_offset]*len(directions))
        slices.append(slice(start,len(rows)));rays.append(directions)
    free=prepared['velocity']+dt*np.linalg.solve(mass,applied+prepared['gravity']-prepared['bias'])
    jacobian=np.asarray(rows).reshape(-1,model.width)
    inverse=np.linalg.solve(mass,jacobian.T)
    metric=jacobian @ inverse+regularization*np.eye(len(rows))
    solved=nonnegative_quadratic(metric,jacobian @ free+np.asarray(offset),tolerance=tolerance)
    impulse=jacobian.T @ solved['solution'];after=free+inverse @ solved['solution']
    contact_impulses=[directions.T @ solved['solution'][indices] for directions,indices in zip(rays,slices,strict=True)]
    residual=mass @ (after-prepared['velocity'])-dt*(applied+prepared['gravity']-prepared['bias'])-impulse
    require(np.isfinite(after).all() and np.max(np.abs(residual),initial=0.)<=1e-8,'Coupled impulse balance')
    return dict(velocity=after,free_velocity=free,generalized_contact_impulse=impulse,contact_impulses=contact_impulses,
        solver=solved,balance_residual=residual,
        model='inelastic_coupled_friction_pyramid_actuator_v2' if actuator_aware else 'inelastic_coupled_friction_pyramid_v1',
        native_solver_equivalence=False,physical_observation=False,dynamic_recovery_qualified=False)
