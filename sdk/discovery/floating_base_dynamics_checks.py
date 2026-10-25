"""Independent kinematic, energy, gravity and virtual-work identities."""
import numpy as np
from actuation_recovery_mechanics import require,array
from contact_posture_reference import retract


def check_close(actual,expected,absolute,relative,label):
    a=np.asarray(actual,dtype=float);b=np.asarray(expected,dtype=float)
    require(a.shape==b.shape and np.isfinite(a).all() and np.isfinite(b).all()
        and np.all(np.abs(a-b)<=absolute+relative*np.maximum(np.abs(a),np.abs(b))),label)
    return float(np.max(np.abs(a-b),initial=0.))


def verify_state(model,position,orientation,joints,velocity,acceleration,gravity,wrenches,step=1e-6):
    """Finite differences perturb only analytic kinematics, never a simulator."""
    require(type(step) in (int,float) and 0<step<=1e-4,"Dynamics finite difference step")
    t=model.tree;n=model.size;v=array(velocity,(n,),"Dynamics check velocity")
    frame=t.kinematics(position,orientation,joints)
    value=model.evaluate(position,orientation,joints,v,acceleration,gravity,wrenches)
    mass=value["mass_matrix"];zero=np.zeros(n);motion=model.motion(frame,v,zero)
    exact=lambda a,b,name:check_close(a,b,1e-9,1e-9,name)
    derivative=lambda a,b,name:check_close(a,b,2e-7,2e-7,name)
    errors={}
    errors["symmetric_inertia"]=exact(mass,mass.T,"Dynamics symmetric inertia")
    eigenvalues=np.linalg.eigvalsh(mass);require(float(eigenvalues[0])>0.,"Dynamics positive energy form")
    columns=np.column_stack([model.inverse_dynamics(frame,zero,np.eye(n)[i],[0.,0.,0.]) for i in range(n)])
    errors["inertia_inverse_dynamics"]=exact(mass,columns,"Dynamics independent inertia columns")
    errors["affine_acceleration"]=exact(value["inverse_dynamics"],mass @ acceleration+value["bias"],"Dynamics affine acceleration identity")
    errors["kinetic_energy_j"]=exact([value["kinetic_energy_j"]],[.5*v @ mass @ v],"Dynamics kinetic energy identity")
    errors["joint_gravity"]=exact(value["gravity_force"][6:],-t.gravity_torques(frame,gravity),"Dynamics original joint gravity")
    root_gravity=t.gravity_wrench(frame,gravity,frame["positions"][0])
    errors["base_gravity"]=exact(value["gravity_force"][:6],-root_gravity,"Dynamics unactuated-base gravity")
    joint_contact=t.wrench_torques(frame,wrenches)
    errors["joint_wrench"]=exact(value["external_generalized_force"][6:],joint_contact,"Dynamics original joint wrench")

    # Hold declared world generalized velocity fixed while perturbing configuration.
    frames=[t.kinematics(*retract(position,orientation,joints,sign*step*v)) for sign in (-1,1)]
    motions=[model.motion(f,v,zero) for f in frames]
    errors["com_velocity_m_s"]=derivative((frames[1]["centers"]-frames[0]["centers"])/(2*step),motion["com_velocity"],"Dynamics COM velocity derivative")
    errors["com_bias_acceleration_m_s2"]=derivative((motions[1]["com_velocity"]-motions[0]["com_velocity"])/(2*step),motion["com_acceleration"],"Dynamics COM acceleration derivative")
    errors["angular_bias_acceleration_rad_s2"]=derivative((motions[1]["angular_velocity"]-motions[0]["angular_velocity"])/(2*step),motion["angular_acceleration"],"Dynamics angular acceleration derivative")
    rotational_velocity=[]
    for i,r in enumerate(frame["rotations"]):
        omega=((frames[1]["rotations"][i]-frames[0]["rotations"][i])/(2*step)) @ r.T
        rotational_velocity.append([omega[2,1],omega[0,2],omega[1,0]])
    errors["angular_velocity_rad_s"]=derivative(rotational_velocity,motion["angular_velocity"],"Dynamics rotation derivative")
    rate=(model.kinetic_energy(frames[1],v)-model.kinetic_energy(frames[0],v))/(2*step)
    errors["kinetic_power_w"]=derivative([rate],[v @ value["velocity_bias"]],"Dynamics kinetic power identity")
    gradient=[]
    for i in range(n):
        configs=[t.kinematics(*retract(position,orientation,joints,sign*step*np.eye(n)[i])) for sign in (-1,1)]
        gradient.append((model.potential_energy(configs[1],gravity)-model.potential_energy(configs[0],gravity))/(2*step))
    errors["potential_gradient"]=derivative(gradient,value["gravity_force"],"Dynamics potential gradient")
    power=0.
    for w in wrenches:
        i=t.index[w["body_id"]];omega=motion["angular_velocity"][i]
        velocity_at_point=motion["origin_velocity"][i]+np.cross(omega,np.asarray(w["point"])-frame["positions"][i])
        power+=float(np.asarray(w["force"]) @ velocity_at_point+np.asarray(w["torque"]) @ omega)
    errors["external_virtual_power_w"]=exact([power],[v @ value["external_generalized_force"]],"Dynamics external virtual power")
    require(float(v @ value["passive_generalized_force"])<=1e-12,"Dynamics damping must dissipate")
    return dict(maximum_errors=errors,numerical_inertia_eigenvalue_min_in_declared_si_coordinates=float(eigenvalues[0]),
        kinetic_energy_j=value["kinetic_energy_j"],potential_energy_j=value["potential_energy_j"],
        gravity_force=value["gravity_force"],velocity_bias=value["velocity_bias"],
        external_generalized_force=value["external_generalized_force"],
        passive_generalized_force=value["passive_generalized_force"],
        native_dynamics_equivalence_established=False,world_build_count=0,solver_steps=0)
