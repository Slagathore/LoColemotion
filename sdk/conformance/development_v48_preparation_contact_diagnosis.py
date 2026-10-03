"""V48 retained recenter and planned-swing contact dwell diagnosis; no physics."""
import hashlib,json
from pathlib import Path
from development_v47_support_progress_diagnosis import endpoint,dot,minus,LIMBS
ROOT=Path(__file__).resolve().parents[2]
ATTEMPT="5d6f64999c45445f9177c0c59e7f3a28"
SHA="sha256:3a8c50b67909bd3f02fd351be9dfe93863c15a8718e5d5c1a55681d5b0c5592c"
def require(v,c):
    if not v:raise ValueError("V48_PREPARATION_"+c)
def read_source():
    p=ROOT.parent/"SporeSpore_Evidence"/("development-v48-mujoco-closed-loop-"+ATTEMPT);raw=(p/"trajectory.jsonl").read_bytes()
    require("sha256:"+hashlib.sha256(raw).hexdigest()==SHA,"SOURCE_DIGEST")
    return [json.loads(l) for l in raw.splitlines()],json.loads((p/"input.json").read_text(encoding="utf-8")),json.loads((p/"reader.json").read_text(encoding="utf-8"))
def analyze(rows,value,reader):
    require(len(rows)==942,"POPULATION");events=[];samples=[];cycles=[];dwell=0;first_six=None;maximum=0
    for n,row in enumerate(rows,1):
        require(n==row["command"]==row["request"]["state"]["semantic_step"],"CLOCK")
        s=row["output"]["actuation"]["receipt"]["recovery_support_plane"];a=s["anchored_body_pose"];t=s["measured_support_transfer"]
        if a.get("origin_rebase"):
            r=a["origin_rebase"];error=sum((r["body_translation_before_recenter_world_m"][k]-r["body_translation_after_recenter_world_m"][k])**2 for k in ("x","y","z"))**.5
            require(error<1e-12,"RECENTER_CONTINUITY")
            events.append(dict(command=n,limbs=r["committed_planned_stance_limb_ids"],origin_advance_m=r["origin_forward_advance_m"],reference_difference_m=error))
        if n>=703:
            require(t["planned_swing_limb_id"]=="rear_left" and not t["preparation_released_this_command"],"PLANNED_LIMB")
            m=t["measurement"];contacts=row["request"]["state"]["ordered_contact_observations"]
            metrics=t["remaining_triangle_margin_m"]>=.02 and m["horizontal_com_speed_m_s"]<=.03 and m["torso_angular_speed_rad_s"]<=.15 and m["torso_tilt_rad"]<=.05
            remaining=all(c["presence"] is True and c["bears_support"] is True for i,c in enumerate(contacts) if i!=2)
            planned=contacts[2]["presence"] is True and contacts[2]["bears_support"] is True
            require(t["readiness_conditions_met"]==(metrics and remaining and planned),"ORIGINAL_READINESS")
            eligible=metrics and remaining;dwell=dwell+1 if eligible else 0;maximum=max(maximum,dwell)
            if dwell==6 and first_six is None:first_six=n
            samples.append(dict(command=n,remaining_three_and_metrics=eligible,planned_foot_bearing=planned,original_four_contact_dwell=t["next_memory"]["ready_dwell_commands"],counterfactual_remaining_three_dwell=dwell))
    for limb,end in reader["cycle_progress"]["completed"].items():
        start=reader["cycle_progress"]["absent"][limb];require(not rows[start-1]["physics"]["last_substep_bearing"][limb] and rows[end-1]["physics"]["last_substep_bearing"][limb],"CYCLE_CONTACT")
        lower=.35*(1-value["descriptor"]["upper_length_fraction"]);f=value["task_frame"]["forward_axis_world_unit"]
        cycles.append(dict(limb=limb,first_absent=start,first_supported_stance=end,endpoint_forward_m=dot(minus(endpoint(rows[end-1],limb,lower),endpoint(rows[start-1],limb,lower)),f)))
    return dict(schema_version="sporespore_v48_retained_preparation_contact_diagnosis_v1",source_trajectory_sha256=SHA,command_count=942,recenter_events=events,cycles=cycles,
        terminal_bias_capped=t["hip_bias_saturated"],terminal_bias_rad=t["next_memory"]["hip_bias_rad"],terminal_triangle_margin_m=t["remaining_triangle_margin_m"],
        remaining_three_eligible_commands=[s["command"] for s in samples if s["remaining_three_and_metrics"]],first_counterfactual_six_command=first_six,longest_counterfactual_remaining_three_dwell=maximum,
        maximum_original_four_contact_dwell=max(s["original_four_contact_dwell"] for s in samples),all_final_preparation_samples=samples,
        counterfactual_is_behavioral_evidence=False,original_observation_regraded=False,new_world_count=0,new_solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
