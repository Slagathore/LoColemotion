"""Exact posthoc reach/reference accounting on retained observations."""
import math
import numpy as np
from actuation_recovery_mechanics import array,require
from force_recovery_diagnostic_metrics import vectors


def safe_command_end(failure,limit=140):
    """Exclude the entire five-step command that contains the first violation."""
    require(type(limit) is int and limit>0,"Tracking diagnostic limit")
    if failure is None:return limit
    step=failure["internal_step"]
    require(type(step) is int and step>0,"Tracking first failure clock")
    return min(limit,(step-1)//5)


def geometry_change(root_y,minimum,current,anchor_root_y,anchor_minimum,within_bounds):
    values=array([root_y,minimum,current,anchor_root_y,anchor_minimum],(5,),"Tracking finite geometry")
    require(type(within_bounds) is bool,"Tracking bound flag")
    slack=current-minimum
    require(not within_bounds or slack>=-2e-10,"Tracking current geometry below bounded minimum")
    translation=root_y-anchor_root_y
    orientation=(minimum-root_y)-(anchor_minimum-anchor_root_y)
    return dict(minimum_clearance_change_m=float(minimum-anchor_minimum),
        root_translation_contribution_m=float(translation),
        orientation_and_bounded_reach_contribution_m=float(orientation),
        remaining_joint_extension_clearance_m=float(slack),
        fixed_geometry_identity=True,causal_dynamic_effect_established=False)


def orientation_vector(quaternion):
    q=array(quaternion,(4,),"Tracking finite quaternion")
    require(abs(float(q@q)-1.)<1e-10,"Tracking unit quaternion")
    if q[3]<0:q=-q
    norm=float(np.linalg.norm(q[:3]))
    return (q[:3]*(2.*math.atan2(norm,float(q[3]))/norm) if norm>1e-12 else 2.*q[:3]).tolist()


def tracking_summary(rows,start,end):
    require(type(start) is int and type(end) is int and 60<=start<end<=140,"Tracking exact window")
    chosen=[r for r in rows if start<=r["command"]<end]
    require([r["command"] for r in chosen]==list(range(start,end)),"Tracking complete ordered window")
    stats=lambda key:vectors([[r["reach_tracking"][key]] for r in chosen])
    sites=["front_left_foot","front_right_foot","rear_left_foot","rear_right_foot"]
    for r in chosen:
        require([x["contact_site_id"] for x in r["reach_tracking"]["feet"]]==sites,"Tracking foot population")
    result=dict(commands=end-start,command_start_inclusive=start,command_end_exclusive=end,
        root_height_m=stats("root_height_m"),com_height_m=stats("com_height_m"),
        target_com_height_m=stats("target_com_height_m"),com_height_error_m=stats("com_height_error_m"),
        root_orientation_vector_rad=vectors([r["reach_tracking"]["orientation_vector_rad"] for r in chosen]),
        feet={site:dict(
            minimum_clearance_m=vectors([[r["reach_tracking"]["feet"][i]["minimum_clearance_m"]] for r in chosen]),
            remaining_joint_extension_clearance_m=vectors([[r["reach_tracking"]["feet"][i]["change_from_handoff"]["remaining_joint_extension_clearance_m"]] for r in chosen]),
            positive_minimum_clearance_commands=sum(r["reach_tracking"]["feet"][i]["minimum_clearance_m"]>1e-9 for r in chosen))
            for i,site in enumerate(sites)},
        endpoints=[dict(command=r["command"],prepared_time_s=r["prepared_time_s"],geometry=r["reach_tracking"]) for r in (chosen[0],chosen[-1])])
    references=[r["reach_tracking"]["candidate_reference"] for r in chosen]
    require(all(v is None for v in references) or all(v is not None for v in references),"Tracking crossed candidate role")
    result["candidate_reference"]=None if references[0] is None else dict(
        commands=len(references),floor_reached_commands=sum(v["floor_reached"] for v in references),
        positive_remaining_fixed_pose_gap_commands=sum(v["remaining_fixed_pose_gap_m"]>1e-9 for v in references),
        requested_fixed_pose_lowering_m=vectors([[v["requested_fixed_pose_lowering_m"]] for v in references]),
        remaining_fixed_pose_gap_m=vectors([[v["remaining_fixed_pose_gap_m"]] for v in references]))
    return result
