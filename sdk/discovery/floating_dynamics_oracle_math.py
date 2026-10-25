"""Coordinate conversion and native-readback comparison; no native worlds."""
import numpy as np
from actuation_recovery_mechanics import array,xyz,require
from floating_base_dynamics import FloatingDynamics,skew
from floating_base_dynamics_inputs import C,verify_native_state
from floating_base_dynamics_checks import check_close


def canonical_state(row):
    s=row["request"]["state"];pose=s["base_pose_world"]
    return (xyz(pose["position_m"]),[pose["orientation_xyzw"][k] for k in "xyzw"],
        [j["position_rad"] for j in s["ordered_joint_observations"]],
        np.r_[xyz(s["base_twist_world"]["linear_velocity_m_s"]),
            xyz(s["base_twist_world"]["angular_velocity_rad_s"]),
            [j["velocity_rad_s"] for j in s["ordered_joint_observations"]]],
        xyz(s["gravity_world_m_s2"]))


def velocity_map(rotation_native,n,velocity):
    """v_native=T v_world; native free-joint angular velocity is body-local."""
    r=array(rotation_native,(3,3),"Oracle native root rotation")
    require(np.allclose(r.T @ r,np.eye(3),atol=1e-12,rtol=0) and abs(np.linalg.det(r)-1)<1e-12,
        "Oracle proper root rotation")
    v=array(velocity,(6+n,),"Oracle generalized velocity")
    t=np.eye(6+n);t[:3,:3]=C.T;t[3:6,3:6]=r.T @ C.T
    derivative=np.zeros_like(t)
    derivative[3:6,3:6]=-skew(t[3:6,3:6] @ v[3:6]) @ t[3:6,3:6]
    # Tdot*v vanishes for this free-root angular block, but is retained explicitly.
    return t,derivative @ v


def unchanged_state(data,qpos,qvel,time_s):
    require(np.array_equal(data.qpos,qpos) and np.array_equal(data.qvel,qvel)
        and data.time==time_s,"Oracle readback changed assigned state/time")


def compare(model,position,orientation,joints,velocity,gravity,acceleration,native):
    n=model.size;frame=model.tree.kinematics(position,orientation,joints)
    value=model.evaluate(position,orientation,joints,velocity,acceleration,gravity)
    r=array(native["root_rotation"],(3,3),"Oracle root rotation")
    t,offset=velocity_map(r,model.n,velocity)
    m=array(native["mass_matrix"],(n,n),"Oracle native inertia")
    bias=array(native["bias"],(n,),"Oracle native bias")
    g=array(native["gravity_bias"],(n,),"Oracle native gravity")
    passive=array(native["passive_force"],(n,),"Oracle native passive force")
    errors={}
    def check(name,a,b):
        errors[name]=check_close(a,b,1e-9,1e-9,"Oracle "+name)
    check("rotation",r,C.T @ frame["rotations"][0] @ C)
    check("velocity",native["qvel"],t @ velocity)
    check("acceleration_frame_offset",offset,np.zeros(n))
    check("symmetric_native_inertia",m,m.T)
    require(np.linalg.eigvalsh(m)[0]>0,"Oracle positive native inertia")
    canonical_mass=t.T @ m @ t
    canonical_bias=t.T @ (bias+m @ offset)
    check("mass_matrix",canonical_mass,value["mass_matrix"])
    check("gravity_bias",t.T @ g,value["gravity_force"])
    check("velocity_bias",canonical_bias-t.T @ g,value["velocity_bias"])
    check("combined_bias",canonical_bias,value["bias"])
    check("passive_force",t.T @ passive,value["passive_generalized_force"])
    check("inverse_dynamics",t.T @ (m @ (t @ acceleration+offset)+bias),value["inverse_dynamics"])
    check("kinetic_energy",[.5*np.asarray(native["qvel"]) @ m @ native["qvel"]],[value["kinetic_energy_j"]])
    return dict(maximum_errors=errors,acceleration_frame_offset=offset.tolist(),
        canonical_mass_matrix=canonical_mass.tolist(),canonical_bias=canonical_bias.tolist(),
        canonical_gravity=(t.T @ g).tolist(),canonical_passive=(t.T @ passive).tolist(),
        kinetic_energy_j=value["kinetic_energy_j"])


def compare_record(profile,original,native,acceleration):
    model=FloatingDynamics(profile["morphology_spec"],[.01]*8)
    p,q,j,v,g=canonical_state(original)
    frame=model.tree.kinematics(p,q,j)
    errors=verify_native_state(model,frame,v,native["observation"])
    result=compare(model,p,q,j,v,g,acceleration,native)
    result["native_geometry_velocity_errors"]=errors
    return result
