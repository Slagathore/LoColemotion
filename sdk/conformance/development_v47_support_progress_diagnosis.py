"""Retained V47 endpoint cycles and exhausted translation reference; no physics."""
import hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ATTEMPT="31817c647bb94a36a446a54a505a535d"
SHA="sha256:fa7fad99d2f2e680f065abcc4c8a56a03f6036a226f29c190835a0802af5450f"
LIMBS=("front_left","front_right","rear_left","rear_right")
def require(v,c):
    if not v:raise ValueError("V47_PROGRESS_"+c)
def read_source():
    p=ROOT.parent/"SporeSpore_Evidence"/("development-v47-mujoco-closed-loop-"+ATTEMPT);raw=(p/"trajectory.jsonl").read_bytes()
    require("sha256:"+hashlib.sha256(raw).hexdigest()==SHA,"SOURCE_DIGEST")
    return [json.loads(l) for l in raw.splitlines()],json.loads((p/"input.json").read_text(encoding="utf-8")),json.loads((p/"reader.json").read_text(encoding="utf-8"))
def dot(a,b):return sum(a[k]*b[k] for k in ("x","y","z"))
def minus(a,b):return {k:a[k]-b[k] for k in ("x","y","z")}
def endpoint(row,limb,lower):
    body=next(b for b in row["physics"]["post"]["bodies"] if b["body_id"]==limb+"_distal");p=body["pose_world"]["position_m"];q=body["pose_world"]["orientation_xyzw"]
    norm=sum(q[k]**2 for k in ("x","y","z","w"));x,y,z,w=[q[k] for k in ("x","y","z","w")]
    up=dict(x=2*(x*y-w*z)/norm,y=1-2*(x*x+z*z)/norm,z=2*(y*z+w*x)/norm)
    return {k:p[k]-lower*.5*up[k] for k in p}
def analyze(rows,value,reader):
    require(len(rows)==942,"POPULATION");forward=value["task_frame"]["forward_axis_world_unit"];lower=.35*(1-value["descriptor"]["upper_length_fraction"])
    cycles=[];maximum=0.;first_cap=None;cap_count=0
    for n,row in enumerate(rows,1):
        require(n==row["command"]==row["request"]["state"]["semantic_step"],"CLOCK")
        t=row["output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"];maximum=max(maximum,t["measurement"]["torso_tilt_rad"])
        if n>690 and t["next_memory"]["hip_bias_rad"]==-.25:
            cap_count+=1
            if first_cap is None:first_cap=n
    for limb,end in reader["cycle_progress"]["completed"].items():
        start=reader["cycle_progress"]["absent"][limb];release=reader["cycle_progress"]["released"][limb]
        require(release<=start<end<=len(rows) and not rows[start-1]["physics"]["last_substep_bearing"][limb] and rows[end-1]["physics"]["last_substep_bearing"][limb],"CYCLE_CONTACT")
        cycles.append(dict(limb=limb,release=release,first_absent=start,first_supported_stance=end,first_absent_to_landing_endpoint_forward_m=dot(minus(endpoint(rows[end-1],limb,lower),endpoint(rows[start-1],limb,lower)),forward)))
    first=rows[0]["output"]["next_memory"]["anchored_body_pose"];last=rows[-1]["output"]["next_memory"]["anchored_body_pose"]
    require(first["origin_world_m"]==last["origin_world_m"],"FIXED_ORIGIN")
    advance=sum(dot(minus(b["anchor_world_m"],a["anchor_world_m"]),first["forward_world_unit"]) for a,b in zip(first["ordered_feet"],last["ordered_feet"]))/4
    t=rows[-1]["output"]["actuation"]["receipt"]["recovery_support_plane"]["measured_support_transfer"]
    return dict(schema_version="sporespore_v47_retained_support_progress_diagnosis_v1",source_trajectory_sha256=SHA,command_count=len(rows),cycles=cycles,
        maximum_precommand_tilt_rad=maximum,terminal_all_four_precommand_bearing=all(c["bears_support"] for c in rows[-1]["request"]["state"]["ordered_contact_observations"]),
        first_final_preparation_bias_cap_command=first_cap,final_preparation_bias_cap_commands=cap_count,terminal_bias_rad=t["next_memory"]["hip_bias_rad"],
        terminal_remaining_triangle_margin_m=t["remaining_triangle_margin_m"],terminal_requested_additional_forward_m=t["requested_foreaft_displacement_m"],
        terminal_horizontal_com_speed_m_s=t["measurement"]["horizontal_com_speed_m_s"],terminal_tilt_rad=t["measurement"]["torso_tilt_rad"],
        fixed_origin_body_translation_limit_m=.35*.25,mean_planned_foot_anchor_advance_m=advance,
        new_world_count=0,new_solver_step_count=0,geometry_is_contact_authority=False,causal_attribution_proven=False,physical_acceptance_authority=False,release_authority=False)
