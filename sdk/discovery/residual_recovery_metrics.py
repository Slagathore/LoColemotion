"""Independent single-handoff reconstruction and fresh paired-prefix checks."""
import copy
import hashlib
import json
from itertools import islice

from adaptation_provider.warning import recovery_v1 as provider

require=provider.require


def transitions(controls,first_failure,c,model,mode):
    require(len(controls)==c["outer_steps"] and mode in provider.MODES[:-1],"Recovery metrics population/mode")
    held=False;clear=0;handoff=None;previous=[0.]*8
    events=[];scheduled=[];predictions=[];unsupported=[];active_counts={k:0 for k in ("selected","challenge","baseline")}
    selected_applied=challenge_applied=baseline_count=0
    for step,row in enumerate(controls):
        detail=row["residual"]["decision"];natural=detail["warning"]["natural_decision"];score=natural["score"]
        if score is None:
            held,clear,reason=True,0,"unsupported_observation";unsupported.append(step)
        elif score>=model.warning.entry_threshold:
            held,clear,reason=True,0,"prediction_threshold";predictions.append(step)
        elif held:
            clear=clear+1 if score<model.warning.exit_threshold else 0
            held=clear<provider.warning.REENTRY
            reason="hysteresis_hold" if held else "supported_reentry"
            if not held:clear=0
        else:held,clear,reason=False,0,"supported_below_threshold"
        require(natural["step"]==step and natural["withdraw_requested"] is held
            and natural["reason"]==reason and natural["clear_commands"]==clear
            and natural["model_sha256"]==model.warning.sha256
            and natural["entry_threshold"]==model.warning.entry_threshold
            and natural["exit_threshold"]==model.warning.exit_threshold,"Recovery independent warning transition")
        early=mode.startswith("early_") and step==provider.EARLY_COMMAND
        trigger=handoff is None and (early or (mode.startswith("warning_") and held))
        if trigger:handoff=step
        if early:scheduled.append(step)
        active=("selected" if mode=="selected_only" or (handoff is not None and mode.endswith("_selected"))
            else "baseline" if mode=="baseline_only" or (handoff is not None and mode.endswith("_baseline"))
            else "challenge")
        actor=model.recovery if active=="selected" else model.actor if active=="challenge" else None
        recovery=detail["recovery"]
        require(recovery==dict(triggered_now=trigger,scheduled_request=early,
            trigger_reason=("scheduled_early" if early else reason) if trigger else None,
            handoff_command=handoff,reentry_permitted=False),"Recovery independent handoff latch")
        memory=row["resolution"]["next_memory"]["opaque_state"]
        require(memory["handoff_command"]==handoff and memory["last_step"]==step
            and memory["warning_state"]["withheld"] is held and memory["warning_state"]["clear_commands"]==clear,
            "Recovery resolved latch/warning memory")
        require(detail["active_actor"]==active and detail["actor_model_sha256"]==model.actor.sha256
            and detail["recovery_model_sha256"]==model.recovery.sha256
            and detail["active_actor_model_sha256"]==(actor.sha256 if actor is not None else None),
            "Recovery active actor provenance")
        resolution=row["resolution"];actual=[v["applied_correction_rad_s"] for v in resolution["ordered_commands"]]
        delta=max(abs(a-b) for a,b in zip(actual,previous,strict=True))
        if active=="baseline" or detail["status"] in ("unsupported","uncertain","no_proposal"):
            require(not resolution["adaptation_applied"] and actual==[0.]*8,"Recovery fallback did not reach baseline")
        elif detail["status"]=="applied":
            require(resolution["adaptation_applied"] and delta<=.08+1e-15,"Recovery actor handoff bypassed slew")
        if trigger:
            events.append(dict(command=step,time_s=row["native_observation"]["time_s"],
                reason="scheduled_early" if early else reason,destination=active,
                prediction_score=score,provider_status=detail["status"],
                adaptation_applied=resolution["adaptation_applied"],
                previous_nonzero_residual=any(v!=0. for v in previous),actual_zero_residual=actual==[0.]*8,
                maximum_actual_correction_delta_rad_s=delta,active_actor_model_sha256=detail["active_actor_model_sha256"]))
        active_counts[active]+=1
        selected_applied+=int(active=="selected" and resolution["adaptation_applied"])
        challenge_applied+=int(active=="challenge" and resolution["adaptation_applied"])
        baseline_count+=int(not resolution["adaptation_applied"]);previous=actual
    require(len(events)<=1 and scheduled==([provider.EARLY_COMMAND] if mode.startswith("early_") else []),
        "Recovery single-handoff/request population")
    event=events[0] if events else None;failure_time=first_failure["time_s"] if first_failure else None
    return dict(command_count=len(controls),handoff=event,handoff_command=handoff,
        scheduled_request_commands=scheduled,requested_actor_commands=active_counts,
        selected_applied_commands=selected_applied,challenge_applied_commands=challenge_applied,
        actual_baseline_commands=baseline_count,prediction_threshold_commands=len(predictions),
        first_prediction_command=predictions[0] if predictions else None,
        unsupported_commands=len(unsupported),first_unsupported_command=unsupported[0] if unsupported else None,
        first_failure=copy.deepcopy(first_failure),
        handoff_lead_to_own_failure_s=failure_time-event["time_s"] if event is not None and failure_time is not None else None,
        reentry_permitted=False,safe_backup_established=False,sufficient_intervention_lead_established=False,
        calibrated_probability=False)


def paired_prefix(folder,reference,summary,c):
    """Compare fresh trajectories only up to the prospectively defined handoff."""
    command=summary["handoff_command"];count=c["outer_steps"] if command is None else command
    prefix_hash=hashlib.sha256()
    with (folder/"trace.jsonl").open("rb") as a,(reference/"trace.jsonl").open("rb") as b:
        for index in range(count*5):
            x,y=a.readline(),b.readline()
            require(x and y and x==y,"Recovery native pre-handoff prefix mismatch")
            prefix_hash.update(x)
    with (folder/"controller.jsonl").open(encoding="utf-8") as a,(reference/"controller.jsonl").open(encoding="utf-8") as b:
        for step in range(count+(command is not None)):
            x,y=json.loads(next(a)),json.loads(next(b))
            require(x["native_observation"]==y["native_observation"]
                and x["request"]["state"]==y["request"]["state"]
                and x["stability"]==y["stability"] and x["kinematics"]==y["kinematics"],
                "Recovery handoff observation differs from fresh challenge")
            if step<count:
                require(x["native_targets"]==y["native_targets"]
                    and x["output"]==y["output"] and x["composition"]==y["composition"],
                    "Recovery control changed before handoff")
    return dict(reference_trial_id=reference.name,handoff_command=command,compared_commands=count,
        compared_internal_samples=count*5,prefix_trace_sha256=prefix_hash.hexdigest(),
        identical_before_handoff=True,handoff_observation_identical=True,
        no_handoff_full_horizon=command is None)
