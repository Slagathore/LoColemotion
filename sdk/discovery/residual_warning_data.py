"""Reopen every hash-bound pilot training row; retain failures and censoring."""
import collections
import hashlib
import json
from pathlib import Path

import residual_selection as selection
from adaptation_provider.warning import residual_v1 as warning

ROOT,HERE=selection.ROOT,selection.HERE
read,sha,require=selection.read,selection.sha,selection.require
CATEGORIES=("already_failed","unsupported","positive","right_censored","negative")
STARTS=tuple(k for k,_ in selection.training.STARTS)


def category(step,failure,supported):
    require(type(step) is int and 0<=step<warning.HORIZON
        and (failure is None or type(failure) is int and 1<=failure<=5*warning.HORIZON)
        and type(supported) is bool,"Warning label clock")
    if failure is not None and failure<=5*step:return "already_failed"
    if not supported:return "unsupported"
    if failure is not None and failure<=5*(step+warning.LOOKAHEAD):return "positive"
    if step+warning.LOOKAHEAD>warning.HORIZON:return "right_censored"
    return "negative"


def lines(path):
    with Path(path).open(encoding="utf-8") as stream:
        for line in stream:
            require(bool(line.strip()),"Warning blank raw row")
            yield json.loads(line)


def dataset_digest(rows):
    value=hashlib.sha256()
    for row in rows:value.update((warning.encode_json(row)+"\n").encode("utf-8"))
    return "sha256:"+value.hexdigest()


def extract(evidence=None,progress=None):
    evidence=(evidence or ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    c,candidates,bindings=selection.retained_population(evidence)
    population=selection.select_population(candidates,c)
    require(population["training_trial_count"]==64 and c["outer_steps"]==warning.HORIZON,
        "Warning complete training population")
    bindings.update({selection.PILOT+"/receipt.json":selection.PILOT_RECEIPT_SHA})
    rows=[];episodes=[];mechanical=collections.Counter()
    for candidate in candidates:
        for trial in candidate["trials"]:
            directory=evidence/selection.PILOT/"stages"/candidate["stage"]/"physical"/trial["trial_id"]
            for kind in ("controller","trace","timing"):
                path=directory/(kind+".jsonl");expected=trial["raw_hashes"][kind]
                require(sha(path)==expected,"Warning raw training stream integrity")
                bindings[path.relative_to(evidence).as_posix()]=expected
            controls=[]
            for step,control in enumerate(lines(directory/"controller.jsonl")):
                require(control["outer_step"]==step==control["request"]["state"]["semantic_step"]
                    and step<warning.HORIZON,"Warning original controller chronology")
                safe=control["output"]["actuation"]["safe_no_actuation"]
                require(type(safe) is bool,"Warning safe-no-actuation shape")
                decision=control["residual"]["decision"];feature=decision["features"]
                if feature is None:
                    reason=decision["reason"]
                    require(isinstance(reason,str) and reason.startswith("unsupported_observation:"),
                        "Warning original unsupported observation")
                    vector=None;mechanical["unsupported"]+=1
                else:
                    reason=None;vector=list(warning.encode(feature,step));mechanical["supported"]+=1
                controls.append((safe,vector,reason))
            require(len(controls)==warning.HORIZON,"Warning complete controller horizon")
            failure=None;count=0
            for count,raw in enumerate(lines(directory/"trace.jsonl"),1):
                require(raw["step"]==count and count<=5*warning.HORIZON,"Warning internal chronology")
                if failure is None:
                    failure=selection.training.physical_violation(raw,c["selection"])
                    if controls[(count-1)//5][0]:
                        failure=dict(internal_step=count,time_s=raw["time_s"],
                            failure_codes=["safe_no_actuation"]+(failure["failure_codes"] if failure else []))
            require(count==5*warning.HORIZON and failure==trial["first_reward_failure"]
                and (failure is None)==trial["diagnostic_eligible"],"Warning original failure reconstruction")
            first=failure["internal_step"] if failure else None
            counts=collections.Counter()
            for step,(_,vector,reason) in enumerate(controls):
                label=category(step,first,vector is not None);counts[label]+=1
                rows.append(dict(trial_id=trial["trial_id"],step=step,category=label,
                    x=vector,unsupported_reason=reason))
            episodes.append(dict(trial_id=trial["trial_id"],candidate_id=candidate["stage"]+"/"+candidate["model_key"],
                start_id=trial["start_id"],condition_id=trial["condition_id"],
                first_failure=failure,diagnostic_eligible=trial["diagnostic_eligible"],
                counts={k:counts[k] for k in CATEGORIES},source_raw_hashes=trial["raw_hashes"]))
            if progress and len(episodes)%8==0:progress(dict(training_episodes_reopened=len(episodes)))
    require(len(rows)==92160 and len(episodes)==64
        and sum(e["diagnostic_eligible"] for e in episodes)==15
        and mechanical==dict(supported=33377,unsupported=58783),"Warning complete original denominator")
    counts={key:sum(e["counts"][key] for e in episodes) for key in CATEGORIES}
    require(sum(counts.values())==len(rows),"Warning exhaustive row classification")
    report=dict(schema_version="locolemotion_residual_warning_data_v1",
        source_closure_sha256=selection.PARENT_SHA,pilot_attempt_id=selection.PILOT,
        pilot_receipt_sha256=selection.PILOT_RECEIPT_SHA,training_bindings=bindings,
        dataset_sha256=dataset_digest(rows),episodes=episodes,training_trial_count=64,
        controller_rows=len(rows),internal_rows=64*7200,eligible_episodes=15,failed_episodes=49,
        original_mechanical_feature_rows=dict(mechanical),row_categories=counts,
        comparison_trials_used=0,route_trials_used=0,reserved_starts_opened=0,
        excluded_confirmation_trials_used=0,new_worlds=0,solver_steps=0,
        source_features="original current-state and actual-prior-action features from fully audited hash-bound streams",
        controller_replay_repeated=False,physical_acceptance_authority=False,release_authority=False)
    return rows,report


def split_episodes(rows,episodes):
    require(len(rows)==len(episodes)*warning.HORIZON
        and len({e["trial_id"] for e in episodes})==len(episodes),"Warning complete row population")
    result=[]
    for index,episode in enumerate(episodes):
        block=rows[index*warning.HORIZON:(index+1)*warning.HORIZON]
        first=episode["first_failure"]
        first=first["internal_step"] if first else None
        require(all(r["trial_id"]==episode["trial_id"] and r["step"]==step
            and r["category"]==category(step,first,r["x"] is not None)
            and ((r["x"] is None and isinstance(r["unsupported_reason"],str)) or
                (r["x"] is not None and len(r["x"])==warning.DIMENSION
                 and all(warning.finite(v) for v in r["x"]) and r["unsupported_reason"] is None))
            for step,r in enumerate(block)),"Warning dataset chronology/label/domain")
        result.append((episode,block))
    return result
