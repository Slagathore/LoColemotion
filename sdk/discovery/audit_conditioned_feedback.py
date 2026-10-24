"""Independent nearest-case, expert arithmetic and resolver checks for selection."""
import math
import struct

from adaptation_provider import support_vertical_feedback_v1 as vertical
from adaptation_provider import phase_release_feedback_v1 as family
from adaptation_provider.retrieval import conditioned_feedback_v2 as provider
from conditioned_feedback_dense_control import ROLES
from audit_phase_release import validate_proposal as validate_reference

require = provider.require


def predictions(model, query, condition):
    """Recompute neighbors without calling the runtime retrieval or chooser."""
    plan=model.plan(); pools=[[] for _ in range(3)]
    for action,phase,mask,vector,score,identity in model.condition_rows[["left_075","nominal"].index(condition)]:
        if list(phase)!=query["phase"] or mask!=query["contact_mask"]:continue
        distance=math.sqrt(sum(((a-b)/s)**2 for a,b,s in zip(query["vector"],vector,plan["feature_scales"],strict=True)))
        if distance<=1.5:pools[action].append((distance,identity,score))
    result={}
    for action,pool in enumerate(pools):
        nearest=sorted(pool)[:3]
        if nearest:
            weights=[1/(1e-6+d*d) for d,_,_ in nearest]
            result[action]=dict(quality_m_s=sum(w*r[2] for w,r in zip(weights,nearest,strict=True))/sum(weights),
                support_distance=max(r[0] for r in nearest),case_ids=[r[1] for r in nearest])
    return result


def raw_expert(request, candidate_index):
    raw,_=vertical.feedback(request["state"],request["command"],vertical.expected_candidates()[3],
        vertical.definition(),request["deterministic_baseline"])
    if candidate_index==3:return raw
    require(candidate_index==4,"Independent expert identity")
    order=["rear_left","front_left","rear_right","front_right"]
    limbs=request["controller_context"]["controller_memory"]["ordered_limb_memory"]
    require([m["limb_id"] for m in limbs]==order,"Independent expert phase order")
    phases={m["limb_id"]:(m["gait_step"]-90*i)%360 for i,m in enumerate(limbs)}
    result=[]
    for i,leg in enumerate(["front_left","front_right","rear_left","rear_right"]):
        local=phases[leg];weight=0. if local<72 else 1. if local<=316 else (360-local)/44.
        result.extend([weight*max(-3.5,min(3.5,v)) for v in raw[2*i:2*i+2]] if weight else [0.,0.])
    return result


def validate_proposal(row,c,role_index,previous,model):
    role=ROLES[role_index];selection=row["selection"]
    require(selection["role"]==role,"Conditioned role receipt")
    if role["id"]=="phase_reference":
        require(selection==dict(role=role,decision=None,provider_error=None,history_boundary=None,learned_selection=False),
            "Conditioned reference metadata")
        validate_reference(row,dict(c,provider=family.definition()),2,previous)
        return
    request=row["resolution_request"]["provider_request"];response=row["resolution_request"]["provider_response"]
    resolved=row["resolution"];step=request["state"]["semantic_step"]
    require(request["state"]==row["request"]["state"] and request["command"]==row["request"]["command"]
        and request["deterministic_baseline"]==row["composition"]["canonical_actuation"]
        and request["controller_context"]["controller_memory"]==row["output"]["next_memory"],"Conditioned observation/context join")
    require(c["provider"]["model_sha256"]==request["expected_model_sha256"]==model.sha256
        and request["expected_model_id"]==model.model_id and request["expected_training_corpus_sha256"]==model.corpus_sha256,
        "Conditioned model/corpus identity")
    require(len(request["history"]["ordered_entries"])==(1 if step==1 else 0),"Conditioned causal history length")
    require(selection["learned_selection"]==(role["mode"]!="baseline" and step>0),"Conditioned selection onset")
    detail=selection["decision"]
    if role["mode"]=="baseline":
        require(detail is None and response is not None and response["status"]=="no_proposal", "Conditioned baseline role")
    elif response is None:
        require(selection["provider_error"] is not None and detail is None,"Conditioned absent-provider receipt")
    else:
        require(selection["provider_error"] is None and detail["mode"]==role["mode"] and detail["step"]==step
            and detail["status"]==response["status"],"Conditioned provider receipt")
        if step==0:
            require(detail["context"] is None and detail["logical_action_index"] is None
                and response["status"]=="no_proposal","Conditioned baseline observation")
        else:
            saved=response["next_memory"]["opaque_state"]["context"]
            require(detail["context"]==saved["decision"]==model.infer(saved["feature"]),"Conditioned inferred context")
            if step==1:require(saved["feature"]==provider.context.features(request),"Conditioned actual first response")
            label=detail["context"]["condition_id"]
            if detail["query"] is not None:
                # Rejoin the public cue independently of the runtime cue helper.
                state=request["state"];q=state["base_pose_world"]["orientation_xyzw"]
                x,y,z,w=[q[k] for k in "xyzw"];v=state["base_twist_world"]["linear_velocity_m_s"]
                limbs={r["limb_id"]:r["gait_step"] for r in request["controller_context"]["controller_memory"]["ordered_limb_memory"]}
                query=dict(vector=[state["base_pose_world"]["position_m"]["y"],2*(x*y-z*w),2*(y*z+x*w),v["x"],v["z"],state["base_twist_world"]["angular_velocity_rad_s"]["y"]],
                    phase=[limbs[l]%360//30 for l in model.plan()["ordered_limb_ids"]],
                    contact_mask=sum(2**i for i,r in enumerate(state["ordered_contact_observations"]) if r["bears_support"]))
                require(detail["query"]==query,"Conditioned current cue join")
                values=predictions(model,query,label)
                require(detail["predictions"]==[dict(action_index=a,**p) for a,p in sorted(values.items())],"Conditioned independent nearest cases")
                old=request["provider_memory"]["opaque_state"]["previous_action"]
                chosen=0 if label=="nominal" else min(values,key=lambda a:(-values[a]["quality_m_s"],a)) if values else None
                if label!="nominal" and old in values and values[chosen]["quality_m_s"]<values[old]["quality_m_s"]+.001:chosen=old
                require(detail["logical_action_index"]==chosen,"Conditioned independent action selection")
                if chosen is not None:
                    actual=[0,2,1][chosen] if role["mode"]=="shuffled" else chosen
                    require(detail["proposed_action_index"]==actual and detail["candidate_index"]==[0,3,4][actual],"Conditioned shuffled association")
                    if detail["feedback"] is not None:
                        raw=raw_expert(request,detail["candidate_index"])
                        require([v for leg in detail["feedback"]["legs"] for v in leg["raw_combined_rad_s"]]==raw,"Conditioned independent feedback")
                        if response["status"]=="applied":
                            require([r["canonical_velocity_delta_rad_s"] for r in response["ordered_corrections"]]==raw,"Conditioned expert proposal")
            if label is None:require(response["status"]=="unsupported","Conditioned unsupported context")
        if role["mode"]=="disabled":require(response["status"]!="applied","Disabled provider influence")
    active=response is not None and response["status"]=="applied" and not resolved["safe_no_actuation"]
    for i,(base,limit,actual) in enumerate(zip(request["deterministic_baseline"]["ordered_commands"],request["safety_envelope"]["ordered_actuator_limits"],resolved["ordered_commands"],strict=True)):
        require(limit["previous_applied_correction_rad_s"]==previous[i]
            and limit["maximum_absolute_correction_rad_s"]==3.5 and limit["maximum_slew_per_step_rad_s"]==.08,"Conditioned resolver envelope")
        raw=response["ordered_corrections"][i]["canonical_velocity_delta_rad_s"] if active else 0.
        bounded=max(-3.5,min(3.5,raw))
        delta=max(-3.5,min(3.5,max(previous[i]-.08,min(previous[i]+.08,bounded)))) if active else 0.
        require(actual["applied_correction_rad_s"]==delta,"Conditioned resolved correction")
        final=max(-base["maximum_target_speed_rad_s"],min(base["maximum_target_speed_rad_s"],base["combined_canonical_target_velocity_rad_s"]+delta))
        require(actual["final_canonical_target_velocity_rad_s"]==row["native_targets"][i]==final,"Conditioned final native target")
        if not active:require(struct.pack("d",final)==struct.pack("d",base["combined_canonical_target_velocity_rad_s"]),"Conditioned fallback bits")


def influence(rows):
    counts=dict(decisions=len(rows),selection_opportunities=0,applied_receipts=0,nonzero_correction_steps=0,
        first_nonzero_step=None,provider_errors=0,logical_actions={},proposed_actions={},statuses={},reasons={})
    for row in rows:
        selection=row["selection"];detail=selection["decision"]
        counts["provider_errors"]+=selection["provider_error"] is not None
        counts["applied_receipts"]+=row["resolution"]["adaptation_applied"]
        nonzero=any(r["applied_correction_rad_s"]!=0. for r in row["resolution"]["ordered_commands"])
        counts["nonzero_correction_steps"]+=nonzero
        if nonzero and counts["first_nonzero_step"] is None:counts["first_nonzero_step"]=row["request"]["state"]["semantic_step"]
        if detail is not None:
            counts["selection_opportunities"]+=detail["logical_action_index"] in [1,2] and detail["feedback"] is not None
            for key,value in [("logical_actions",detail["logical_action_index"]),("proposed_actions",detail["proposed_action_index"]),("statuses",detail["status"]),("reasons",detail["selection_reason"])]:
                label=str(value);counts[key][label]=counts[key].get(label,0)+1
    return counts
