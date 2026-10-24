"""Declared post-handoff objective and training-only candidate selection."""
import math
from adaptation_provider import bounded_residual_ars_v1 as ars
from residual_training_task import score as walking_score

require=ars.require
OBJECTIVE=dict(handoff_command=60,alive_tilt_penalty_weight=.5,failure_value=-1.,
    per_sample="-0.5*(tilt/maximum_tilt)^2 until the first original violation, then -1",
    denominator="all internal samples after command 60 through the fixed horizon",
    prefix_rewarded=False,walking_quality_is_separate=True,
    prefix_failure="retain as negative; every post-handoff sample remains failure padded",
    normalizer="warm-start moments frozen; full observed moments retained diagnostically")
SELECTION_RULE="descending eligible count, descending worst-group recovery reward, descending mean recovery reward, lexical candidate id"


def score(controls,trace,c,*,training):
    require(c["recovery_objective"]==OBJECTIVE,"Recovery objective declaration")
    value=walking_score(controls,trace,c,training=training)
    offset=OBJECTIVE["handoff_command"]*c["internal_steps_per_outer"]
    require(c["internal_steps_per_outer"]==5 and 0<offset<len(trace),"Recovery objective horizon")
    failure=value["first_reward_failure"];rewards=[];alive=0
    for row in trace[offset:]:
        if failure is not None and row["step"]>=failure["internal_step"]:
            reward=OBJECTIVE["failure_value"]
        else:
            q=row["qpos"]
            tilt=math.acos(max(-1.,min(1.,1.-2*(q[4]**2+q[5]**2))))
            reward=-OBJECTIVE["alive_tilt_penalty_weight"]*(tilt/c["selection"]["maximum_tilt_rad"])**2
            alive+=1
        require(ars.finite(reward) and -1.<=reward<=0.,"Recovery objective reward range")
        rewards.append(reward)
    walking={k:value[k] for k in ("training_reward","reward_denominator","reward_samples_sha256")}
    value.update(training_reward=math.fsum(rewards)/len(rewards),reward_denominator=len(rewards),
        reward_samples_sha256=ars.digest(rewards),walking_reward_diagnostic=walking,
        recovery_objective=dict(handoff_command=60,first_scored_internal_step=offset+1,
            scored_internal_samples=len(rewards),surviving_internal_samples=alive,
            failure_padded_samples=len(rewards)-alive,
            prefix_eligible=failure is None or failure["internal_step"]>offset,
            objective_sha256=ars.digest(OBJECTIVE)))
    return value


def select(candidates,groups,expected_ids,denominator):
    require(isinstance(groups,tuple) and len(groups)>0 and len(set(groups))==len(groups)
        and isinstance(expected_ids,tuple) and len(expected_ids)>0
        and len(set(expected_ids))==len(expected_ids),"Recovery selector declared population")
    require(len(candidates)==len(expected_ids)
        and sorted(x["candidate_id"] for x in candidates)==sorted(expected_ids),
        "Recovery selector incomplete/crossed candidates")
    ranking=[];seen_trials=set()
    for candidate in candidates:
        rows=candidate["trials"]
        identities=[r["trial_id"] for r in rows]
        require(all(isinstance(x,str) and x for x in identities)
            and len(set(identities))==len(identities) and not seen_trials.intersection(identities),
            "Recovery selector repeated/missing trial identity")
        seen_trials.update(identities)
        require(len(rows)==len(groups) and sorted(r["group_id"] for r in rows)==sorted(groups),
            "Recovery selector complete groups")
        require(all(r["partition"]=="training" and r["role"]=="search"
            and r["comparison_data_used_for_training"] is False
            and r["provider_model_sha256"]==candidate["model_sha256"]
            and r["recovery_policy_sha256"]==candidate["policy_sha256"]
            and r["reward_denominator"]==denominator
            and type(r["diagnostic_eligible"]) is bool
            and r["diagnostic_eligible"] is (r["first_reward_failure"] is None)
            and (r["diagnostic_eligible"] or r["official_quality_m_s"] is None)
            and ars.finite(r["training_reward"]) and -1.<=r["training_reward"]<=0. for r in rows),
            "Recovery selector training identity/reward/authority")
        ordered=sorted(rows,key=lambda r:groups.index(r["group_id"]))
        rewards=[r["training_reward"] for r in ordered]
        ranking.append(dict(candidate_id=candidate["candidate_id"],model_sha256=candidate["model_sha256"],
            policy_sha256=candidate["policy_sha256"],eligible_groups=sum(r["diagnostic_eligible"] for r in ordered),
            minimum_reward=min(rewards),mean_reward=math.fsum(rewards)/len(rewards),
            ordered_trial_ids=[r["trial_id"] for r in ordered]))
    ranking.sort(key=lambda r:(-r["eligible_groups"],-r["minimum_reward"],-r["mean_reward"],r["candidate_id"]))
    return dict(schema_version="locolemotion_recovery_training_selection_component_v1",
        rule=SELECTION_RULE,training_groups=list(groups),candidate_count=len(ranking),ranking=ranking,
        selected_candidate_id=ranking[0]["candidate_id"],selected_model_sha256=ranking[0]["model_sha256"],
        selected_policy_sha256=ranking[0]["policy_sha256"],comparison_data_used_for_selection=False,
        physical_acceptance_authority=False,release_authority=False)
