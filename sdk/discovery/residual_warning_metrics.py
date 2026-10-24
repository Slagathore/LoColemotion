"""Shadow warning diagnostics; no counterfactual safety inference."""
from adaptation_provider.warning import residual_v1 as warning
import residual_warning_data as data

require=warning.require


def threshold_limits(rows,episodes,scores):
    """Fit threshold on crossfit scores; these are not held-out alarm metrics."""
    require(len(scores)==len(rows),"Warning prediction denominator")
    limits=[];without=[]
    for index,(episode,block) in enumerate(data.split_episodes(rows,episodes)):
        if episode["diagnostic_eligible"]:continue
        predictions=scores[index*warning.HORIZON:(index+1)*warning.HORIZON]
        positive=[v for row,v in zip(block,predictions,strict=True) if row["category"]=="positive"]
        require(all(warning.finite(v) for v in positive),"Warning positive-window predictions")
        if positive:limits.append(dict(trial_id=episode["trial_id"],maximum_score=max(positive),
            supported_warning_opportunities=len(positive)))
        else:without.append(episode["trial_id"])
    require(bool(limits),"Warning threshold has no supported failure opportunity")
    return min(r["maximum_score"] for r in limits),limits,without


def evaluate(rows,episodes,models):
    predictions=[];trials=[]
    for episode,block in data.split_episodes(rows,episodes):
        model=models[episode["start_id"]]
        state=warning.empty_memory(model,episode["trial_id"])
        first=episode["first_failure"]
        failed=first["internal_step"] if first else None
        total=active=negative=negative_active=positive=positive_active=0
        supported_alarms=unsupported_alarms=entries=exits=0
        first_warning=None;window_warning=False
        for row in block:
            step=row["step"];value=warning.score(model.weights,row["x"]) if row["x"] is not None else None
            previous=state.withheld
            state,decision=warning.advance_score(model,state,step,value)
            predictions.append(dict(trial_id=episode["trial_id"],step=step,model_sha256=model.sha256,
                score=value,withdraw_requested=decision["withdraw_requested"],reason=decision["reason"]))
            before=failed is None or 5*step<failed
            if not before:continue
            total+=1;active+=state.withheld;entries+=state.withheld and not previous;exits+=previous and not state.withheld
            if state.withheld and first_warning is None:first_warning=step
            if row["category"]=="negative":
                negative+=1;negative_active+=state.withheld
            if row["category"]=="positive":
                positive+=1;positive_active+=state.withheld
            supported_alarms+=decision["reason"]=="prediction_threshold"
            unsupported_alarms+=decision["reason"]=="unsupported_observation"
            if failed is not None and failed<=5*(step+warning.LOOKAHEAD) and state.withheld:window_warning=True
        trials.append(dict(trial_id=episode["trial_id"],candidate_id=episode["candidate_id"],
            start_id=episode["start_id"],condition_id=episode["condition_id"],
            diagnostic_eligible=episode["diagnostic_eligible"],first_failure=first,
            pre_failure_or_eligible_commands=total,warning_commands=active,
            warning_fraction=active/total if total else None,
            known_negative_commands=negative,known_negative_warning_commands=negative_active,
            supported_positive_commands=positive,supported_positive_warning_commands=positive_active,
            threshold_alarm_commands=supported_alarms,unsupported_alarm_commands=unsupported_alarms,
            entry_count=entries,reentry_count=exits,first_warning_step=first_warning,
            first_warning_lead_s=(failed/600-first_warning/120) if failed and first_warning is not None else None,
            warning_in_target_window=window_warning if failed else None))
    failures=[t for t in trials if not t["diagnostic_eligible"]]
    eligible=[t for t in trials if t["diagnostic_eligible"]]
    selected=[t for t in trials if t["candidate_id"]=="iteration_00/d00_plus"]
    return predictions,dict(trials=trials,failed_episodes=len(failures),eligible_episodes=len(eligible),
        failures_warned_in_target_window=sum(t["warning_in_target_window"] for t in failures),
        failures_without_target_window_warning=[t["trial_id"] for t in failures if not t["warning_in_target_window"]],
        failures_without_supported_positive_rows=[t["trial_id"] for t in failures if t["supported_positive_commands"]==0],
        eligible_episodes_with_any_warning=sum(t["warning_commands"]>0 for t in eligible),
        selected_eligible_episodes=len(selected),
        selected_episodes_with_any_warning=sum(t["warning_commands"]>0 for t in selected),
        selected_warning_commands=sum(t["warning_commands"] for t in selected),
        selected_total_commands=sum(t["pre_failure_or_eligible_commands"] for t in selected),
        known_negative_commands=sum(t["known_negative_commands"] for t in trials),
        known_negative_warning_commands=sum(t["known_negative_warning_commands"] for t in trials),
        supported_positive_commands=sum(t["supported_positive_commands"] for t in trials),
        supported_positive_warning_commands=sum(t["supported_positive_warning_commands"] for t in trials),
        pre_failure_or_eligible_commands=sum(t["pre_failure_or_eligible_commands"] for t in trials),
        warning_commands=sum(t["warning_commands"] for t in trials),
        shadow_only=True,counterfactual_physical_outcomes_known=False,
        probabilistic_coverage_guarantee=False,safe_backup_established=False)
