"""Pure retrospective wrench and nested command-authority accounting.

Removing a bound here changes only an algebraic interval on an observed state.
It does not create a realizable alternative trajectory or a causal rescue claim.
"""
import numpy as np
import actuation_recovery_mechanics as m

LOSS_NAMES=("force_cap","target_speed","absolute_residual","residual_slew")
C=np.array([[1.,0.,0.],[0.,0.,1.],[0.,-1.,0.]])


def prepared_frame(tree,qpos):
    q=m.array(qpos,(7+tree.n,),"Diagnostic prepared native position")
    return tree.kinematics(C @ q[:3],[q[4],q[6],-q[5],q[3]],q[7:])


def robot_wrenches(sample):
    wrenches=[]
    for contact in sample["contacts"]:
        point=C @ m.array(contact["position_m"],(3,),"Diagnostic contact point")
        force=m.array(contact["force_on_geom2_canonical_n"],(3,),"Diagnostic contact force")
        torque=m.array(contact["torque_on_geom2_canonical_nm"],(3,),"Diagnostic contact torque")
        for side,sign in ((0,-1.),(1,1.)):
            if contact["body_ids"][side]==0:
                m.require(contact["body_names"][side]=="world","Diagnostic ground attribution")
            else:wrenches.append(dict(body_id=contact["body_names"][side],point=point,
                force=sign*force,torque=sign*torque))
    return wrenches


def wrench_about(wrenches,origin):
    origin=m.array(origin,(3,),"Diagnostic wrench origin")
    force=np.zeros(3);moment=np.zeros(3)
    for w in wrenches:
        point=m.array(w["point"],(3,),"Diagnostic point")
        f=m.array(w["force"],(3,),"Diagnostic force");t=m.array(w["torque"],(3,),"Diagnostic torque")
        force+=f;moment+=np.cross(point-origin,f)+t
    return np.r_[force,moment]


def decompose_loss(requested,intervals,tolerance=1e-9):
    """Telescoping absolute torque error over four nested instantaneous sets."""
    n=len(requested);request=m.array(requested,(n,),"Diagnostic requested torque")
    values=m.array(intervals,(4,2,n),"Diagnostic nested torque intervals")
    m.require(n>0 and (values[:,0]<=values[:,1]+tolerance).all()
        and (values[1:,0]>=values[:-1,0]-tolerance).all()
        and (values[1:,1]<=values[:-1,1]+tolerance).all(),"Diagnostic nonnested authority sets")
    projections=np.array([np.clip(request,low,high) for low,high in values])
    errors=np.abs(projections-request)
    losses=np.diff(np.vstack((np.zeros((1,n)),errors)),axis=0)
    m.require((losses>=-tolerance).all() and np.allclose(np.sum(losses,axis=0),errors[-1],rtol=0,atol=tolerance),
        "Diagnostic loss decomposition")
    return dict(projections=projections,absolute_errors=errors,
        incremental_absolute_error={name:losses[i] for i,name in enumerate(LOSS_NAMES)},
        instantaneous_only=True,alternative_trajectory_simulated=False)


def authority_intervals(control,profile):
    request=control["resolution_request"]["provider_request"]
    limits=request["safety_envelope"]["ordered_actuator_limits"]
    commands=request["deterministic_baseline"]["ordered_commands"]
    n=len(commands);ids=[r["actuator_id"] for r in commands]
    m.require(ids==[r["actuator_id"] for r in limits]==profile["ordered_actuators"],"Diagnostic actuator order")
    baseline=[r["combined_canonical_target_velocity_rad_s"] for r in commands]
    speed=m.array([r["maximum_target_speed_rad_s"] for r in commands],(n,),"Diagnostic speed limits")
    previous=[r["previous_applied_correction_rad_s"] for r in limits]
    absolute=m.array([r["maximum_absolute_correction_rad_s"] for r in limits],(n,),"Diagnostic absolute limits")
    slew=[r["maximum_slew_per_step_rad_s"] for r in limits]
    velocity=[r["velocity_rad_s"] for r in control["request"]["state"]["ordered_joint_observations"]]
    gains=profile["velocity_gains"];ranges=m.array(profile["force_ranges"],(n,2),"Diagnostic configured force caps")
    actual=m.command_envelope(baseline,speed,previous,absolute,slew)
    absolute_only=m.command_envelope(baseline,speed,previous,absolute,2*absolute)
    return np.array([ranges.T,
        [m.motor_torque(-speed,velocity,gains,ranges),m.motor_torque(speed,velocity,gains,ranges)],
        m.torque_envelope(absolute_only,velocity,gains,ranges),m.torque_envelope(actual,velocity,gains,ranges)])


def join_control(control,sample,trace,command):
    native=control["native_observation"]
    m.require(control["outer_step"]==control["request"]["state"]["semantic_step"]==command
        and sample["step"]==trace["step"]==5*command+1
        and sample["prepared_time_s"]==native["time_s"]
        and sample["integrated_time_s"]==trace["time_s"]
        and sample["before_qpos"]==native["qpos"]==trace["before_qpos"]
        and sample["before_qvel"]==native["qvel"]==trace["before_qvel"]
        and sample["ctrl"]==trace["ctrl"]==control["native_targets"],"Diagnostic prepared clock/command join")


def vectors(values):
    if not values:return None
    x=np.asarray(values,dtype=float)
    m.require(x.ndim==2 and len(x)>0 and np.isfinite(x).all(),"Diagnostic vector population")
    return dict(count=len(x),mean=x.mean(axis=0).tolist(),mean_absolute=np.abs(x).mean(axis=0).tolist(),
        rms=np.sqrt((x*x).mean(axis=0)).tolist(),maximum_absolute=np.abs(x).max(axis=0).tolist())
