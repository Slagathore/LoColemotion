"""Independent transition accounting over audited, actually issued commands."""
import copy

from adaptation_provider.warning import control_v1 as provider

require=provider.require


def transitions(controls,first_failure,c,model,mode):
    require(len(controls)==c["outer_steps"] and mode in ("shadow","frozen","forced_route"),
        "Withdrawal metrics population/mode")
    held=False;clear=0;previous=[0.]*8
    entries=[];reentries=[];forced=[];predictions=[];unsupported=[]
    withheld_count=withdrawal_count=baseline_count=0
    for step,row in enumerate(controls):
        detail=row["residual"]["decision"];warning=detail["warning"];natural=warning["natural_decision"]
        score=natural["score"]
        prior_held=held
        if score is None:
            held,clear,reason=True,0,"unsupported_observation";unsupported.append(step)
        elif score>=model.warning.entry_threshold:
            held,clear,reason=True,0,"prediction_threshold";predictions.append(step)
        elif held:
            clear=clear+1 if score<model.warning.exit_threshold else 0
            held=clear<provider.warning.REENTRY
            reason="hysteresis_hold" if held else "supported_reentry"
            if not held:clear=0
        else:
            held,clear,reason=False,0,"supported_below_threshold"
        expected=bool(mode=="forced_route" and step==provider.FORCED_COMMAND)
        require(natural["step"]==step and natural["withdraw_requested"] is held
            and natural["reason"]==reason and natural["clear_commands"]==clear
            and natural["model_sha256"]==model.warning.sha256
            and natural["entry_threshold"]==model.warning.entry_threshold
            and natural["exit_threshold"]==model.warning.exit_threshold
            and warning["forced_route_request"] is expected,"Withdrawal independent natural transition")
        if expected:
            held,clear=True,0;forced.append(step)
        require(warning["withheld"] is held and warning["clear_commands"]==clear
            and warning["withdrawal_requested_for_mode"] is (held and mode!="shadow"),
            "Withdrawal independent forced transition")
        memory=row["resolution"]["next_memory"]["opaque_state"]["warning_state"]
        require(memory["withheld"] is held and memory["clear_commands"]==clear
            and memory["last_step"]==step,"Withdrawal resolved warning memory")
        actual=[v["applied_correction_rad_s"] for v in row["resolution"]["ordered_commands"]]
        withdrawal=detail["status"]=="uncertain" and detail["reason"] in (
            "declared_route_withdrawal","warning_withdrawal")
        require(warning["withdrawal_applied_to_proposal"] is withdrawal,"Withdrawal actual status accounting")
        if withdrawal:
            require(mode!="shadow" and held and row["resolution"]["fallback_reason"]=="provider_uncertain"
                and not row["resolution"]["adaptation_applied"] and actual==[0.]*8,
                "Withdrawal did not immediately reach baseline")
        if held and not prior_held:
            entries.append(dict(command=step,time_s=row["native_observation"]["time_s"],
                reason="explicit_route_request" if expected else reason,
                requested_for_mode=mode!="shadow",warning_applied_to_proposal=withdrawal,
                previous_nonzero_residual=any(x!=0. for x in previous),actual_zero_residual=actual==[0.]*8))
        if prior_held and not held:
            if mode!="shadow" and detail["status"]=="applied":
                require(previous==[0.]*8 and max(abs(x) for x in actual)<=.08,
                    "Withdrawal reentry must slew from actual zero residual")
            reentries.append(dict(command=step,time_s=row["native_observation"]["time_s"],
                clear_commands_required=provider.warning.REENTRY,actor_applied=detail["status"]=="applied",
                maximum_actual_correction_rad_s=max(abs(x) for x in actual)))
        withheld_count+=int(held);withdrawal_count+=int(withdrawal)
        baseline_count+=int(not row["resolution"]["adaptation_applied"]);previous=actual
    require(forced==([provider.FORCED_COMMAND] if mode=="forced_route" else []),
        "Withdrawal forced request population")
    first_prediction=predictions[0] if predictions else None
    actual_entries=[r for r in entries if r["warning_applied_to_proposal"]]
    first_actual=actual_entries[0] if actual_entries else None
    prediction_time=controls[first_prediction]["native_observation"]["time_s"] if first_prediction is not None else None
    failure_time=first_failure["time_s"] if first_failure is not None else None
    return dict(command_count=len(controls),monitor_withheld_commands=withheld_count,
        warning_withdrawal_commands=withdrawal_count,baseline_fallback_commands=baseline_count,
        prediction_threshold_commands=len(predictions),unsupported_commands=len(unsupported),
        first_prediction_command=first_prediction,first_prediction_time_s=prediction_time,
        first_unsupported_command=unsupported[0] if unsupported else None,
        forced_request_commands=forced,entries=entries,reentries=reentries,
        first_actual_withdrawal=copy.deepcopy(first_actual),first_failure=copy.deepcopy(first_failure),
        prediction_lead_to_own_failure_s=(failure_time-prediction_time
            if failure_time is not None and prediction_time is not None else None),
        actual_withdrawal_lead_to_own_failure_s=(failure_time-first_actual["time_s"]
            if failure_time is not None and first_actual is not None else None),
        sufficient_intervention_lead_established=False,safe_backup_established=False,
        calibrated_probability=False)
