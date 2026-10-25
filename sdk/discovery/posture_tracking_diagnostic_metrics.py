"""Fixed-reference and material-point observations; no one-step tracking promise."""
import numpy as np
from actuation_recovery_mechanics import array,require
from reach_tracking_diagnostic_metrics import safe_command_end


def joint_tracking(reference,before,after):
    n=len(reference);require(n>0,"Posture tracking nonempty joints")
    r=array(reference,(n,),"Posture tracking reference")
    a=array(before,(n,),"Posture tracking before");b=array(after,(n,),"Posture tracking after")
    error=r-a;motion=b-a
    return dict(reference_rad=r,initial_error_rad=error,actual_delta_rad=motion,
        final_error_rad=r-b,initial_error_norm_rad=float(np.linalg.norm(error)),
        final_error_norm_rad=float(np.linalg.norm(r-b)),
        distance_to_fixed_reference_decreased=bool(np.linalg.norm(r-b)<np.linalg.norm(error)-1e-12),
        reference_is_not_one_step_deadline=True,physical_feasibility_established=False)


def material_point_motion(position_before,rotation_before,position_after,rotation_after,point):
    p0=array(position_before,(3,),"Posture point body before");p1=array(position_after,(3,),"Posture point body after")
    r0=array(rotation_before,(3,3),"Posture point rotation before");r1=array(rotation_after,(3,3),"Posture point rotation after")
    point=array(point,(3,),"Posture prepared material point")
    require(all(np.allclose(r.T @ r,np.eye(3),atol=1e-10,rtol=0)
        and abs(np.linalg.det(r)-1.)<=1e-10 for r in (r0,r1)),"Posture proper rotations")
    return p1+r1 @ (r0.T @ (point-p0))-point


def validate_window(failures,start,end):
    require(type(start) is int and type(end) is int and start==60 and end==126
        and len(failures)==2 and all(f is not None for f in failures)
        and min(f["internal_step"] for f in failures)==633
        and end==min(safe_command_end(f,1440) for f in failures),
        "Posture common complete safe window")
    return dict(start=start,end_exclusive=end,commands_per_trial=end-start,posthoc=True,
        includes_first_failing_command=False)


def posture_snapshot(row,last_trace,tree,profile):
    from force_recovery_diagnostic_metrics import prepared_frame
    from reach_tracking_diagnostic_metrics import orientation_vector
    d=row["force_reference"]["decision"];state=row["request"]["state"]
    before=prepared_frame(tree,row["native_observation"]["qpos"]);after=prepared_frame(tree,last_trace["qpos"])
    q0=np.array([x["position_rad"] for x in state["ordered_joint_observations"]])
    q1=np.array(last_trace["qpos"][7:]);qd=np.array([x["velocity_rad_s"] for x in state["ordered_joint_observations"]])
    posture=d.get("posture_reference")
    reference=(posture if posture is not None else d["support_reference"])["reference_joint_positions_rad"]
    track=joint_tracking(reference,q0,q1);p=profile["parameters"]
    expected=p["joint_position_gain_nm_rad"]*(np.array(reference)-q0)-p["joint_velocity_gain_nms_rad"]*qd
    require(np.allclose(expected,d["posture_torque"],atol=1e-9,rtol=0),"Posture exact joint reference/torque join")
    packet=row["resolution_request"]["provider_request"]["controller_context"]["controller_memory"]["contact_packet"]
    sites={x["contact_site_id"]:x["body_id"] for x in tree.spec["contact_sites"]}
    motion={}
    for contact in packet["ordered_contacts"]:
        if not contact["bears_support"]:continue
        i=tree.index[sites[contact["contact_site_id"]]]
        point=[contact["point_world_m"][k] for k in ("x","y","z")]
        motion[contact["contact_site_id"]]=material_point_motion(before["positions"][i],before["rotations"][i],
            after["positions"][i],after["rotations"][i],point)
    pose=state["base_pose_world"];q=[pose["orientation_xyzw"][k] for k in "xyzw"]
    end=last_trace["qpos"];endq=[end[4],end[6],-end[5],end[3]]
    virtual=None
    if posture is not None and posture["status"]=="solved":
        witness=posture["nonlinear_witness"]
        virtual=dict(root_position_m=witness["virtual_root_position_m"],
            root_orientation_vector_rad=orientation_vector(witness["virtual_root_orientation_xyzw"]),
            maximum_contact_displacement_m=witness["maximum_contact_displacement_m"],
            root_motion_issued=False,physical_tracking_deadline_declared=False)
    return dict(status=posture["status"] if posture is not None else "legacy_reach_reference",
        joint_tracking=track,posture_torque_nm=expected,
        root_before_m=before["positions"][0],root_after_m=after["positions"][0],
        orientation_before_rad=orientation_vector(q),orientation_after_rad=orientation_vector(endq),
        com_before_m=before["whole_body_com"],com_after_m=after["whole_body_com"],
        target_com_m=d["target_com"],virtual_reference=virtual,
        actual_material_point_displacements_m=motion,
        maximum_actual_material_point_displacement_m=max((float(np.linalg.norm(v)) for v in motion.values()),default=0.),
        observed_interval_s=last_trace["time_s"]-row["native_observation"]["time_s"],
        held_contact_guaranteed=False,causal_dynamic_explanation_established=False)
