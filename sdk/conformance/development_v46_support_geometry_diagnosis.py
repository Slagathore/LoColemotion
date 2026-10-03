"""Check V46 retained target reach and body-height conflicts without physics."""
import hashlib
import json
from pathlib import Path
from development_v45_support_geometry_diagnosis import bottom, rotate_y_projections
ROOT=Path(__file__).resolve().parents[2]
ATTEMPT="d614b1b8b41e4787baa1dd0a77ffec75"
TRAJECTORY_SHA="sha256:aca5a2efdda32975030317f096bfd6b040b9220f4fd39714b508401b9b08084b"
LIMBS=("front_left","front_right","rear_left","rear_right")
def require(v,c):
    if not v: raise ValueError("V46_GEOMETRY_"+c)
def read_source():
    root=ROOT.parent/"SporeSpore_Evidence"/("development-v46-mujoco-closed-loop-"+ATTEMPT)
    raw=(root/"trajectory.jsonl").read_bytes()
    require("sha256:"+hashlib.sha256(raw).hexdigest()==TRAJECTORY_SHA,"SOURCE_DIGEST")
    rows=[json.loads(line) for line in raw.splitlines()];require(len(rows)==241,"POPULATION")
    return rows,json.loads((root/"input.json").read_text(encoding="utf-8"))
def analyze(rows,value):
    d=value["descriptor"]; samples=[]; commands=[]; maximum=0.
    for n,r in enumerate(rows,1):
        state=r["request"]["state"];require(r["command"]==n==state["semantic_step"],"CLOCK")
        s=r["output"]["actuation"]["receipt"]["recovery_support_plane"];t=s["measured_support_transfer"];p=s["feasible_support_plan"]
        require(t["effective_selected_phases"]==[0,180,90,270] and not t["preparation_released_this_command"],"PREPARATION")
        commands.append(dict(command=n,measured_height_m=p["measured_torso_height_m"],tilt_rad=t["measurement"]["torso_tilt_rad"],
            requested_lowering_m=p["requested_lowering_m"],common_interval_nonempty=p["common_height_interval_nonempty"],
            common_minimum_m=p["common_minimum_torso_height_m"],common_maximum_m=p["common_maximum_torso_height_m"]))
        bodies={b["body_id"]:b for b in r["request"]["measured_body_frame"]["ordered_body_states"]}
        for i,limb in enumerate(LIMBS):
            b=bodies[limb+"_distal"];up=rotate_y_projections(b["pose_world"]["orientation_xyzw"])[1]
            native_bottom=b["pose_world"]["position_m"]["y"]-abs(up)*.35*(1-d["upper_length_fraction"])/2-.04*d["foot_radius_scale"]
            h,k=state["ordered_joint_observations"][2*i:2*i+2]
            require(h["joint_id"]==limb+"_hip" and k["joint_id"]==limb+"_knee","JOINT_ORDER")
            error=abs(bottom(state,d,limb,h["position_rad"],k["position_rad"])-native_bottom)
            maximum=max(maximum,error);require(error<1e-12,"NATIVE_FK_CROSSCHECK")
            a=s["ordered_limb_proposals"][i];require(a["limb_id"]==limb,"LIMB_ORDER")
            target=bottom(state,d,limb,a["goal_hip_rad"],a["goal_knee_rad"])
            require(abs(target-a["projected_support_nominal_plane_residual_m"])<1e-12 or n==1,"RECEIPT_RESIDUAL")
            samples.append(dict(command=n,limb=limb,precommand_bearing=state["ordered_contact_observations"][i]["bears_support"],
                measured_bottom_m=native_bottom,target_bottom_m=target,link_reach_projection=a["link_reach_projection_required"],
                joint_projection=a["support_joint_projection_required"],common_lowering_m=p["requested_lowering_m"],
                lowering_participant=limb in p["ordered_lowering_participant_limb_ids"],
                hip_position_error_rad=a["goal_hip_rad"]-h["position_rad"],knee_position_error_rad=a["goal_knee_rad"]-k["position_rad"],
                speed_clipped=any(c["velocity_saturated"] for c in r["output"]["actuation"]["ordered_commands"][2*i:2*i+2])))
    return dict(schema_version="sporespore_v46_retained_support_geometry_diagnosis_v1",source_trajectory_sha256=TRAJECTORY_SHA,
        command_count=len(rows),limb_samples=len(samples),maximum_native_fk_bottom_error_m=maximum,
        lowering_commands=sum(c["requested_lowering_m"]>0 for c in commands),
        first_lowering_command=next((c["command"] for c in commands if c["requested_lowering_m"]>0),None),
        empty_common_interval_commands=sum(not c["common_interval_nonempty"] for c in commands),
        first_empty_common_interval_command=next((c["command"] for c in commands if not c["common_interval_nonempty"]),None),
        missing_preparation_contact_samples={limb:sum(s["limb"]==limb and not s["precommand_bearing"] for s in samples) for limb in LIMBS},
        maximum_tilt_rad=max(c["tilt_rad"] for c in commands),
        maximum_target_gap_m=max(s["target_bottom_m"] for s in samples),
        all_commands=commands,all_samples=samples,new_world_count=0,new_solver_step_count=0,
        geometry_is_contact_authority=False,causal_attribution_proven=False,physical_acceptance_authority=False,release_authority=False)
