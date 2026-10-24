"""Retrospective development selection over the complete exposed training population.

This selection never reads route or final-comparison outcomes. The selected
model keeps its original artifact, including its honest initial-probe origin.
A fresh comparison is required; selection cannot regrade the consumed pilot.
"""
import copy
import math
from pathlib import Path

import residual_training_task as training

ROOT,HERE=training.ROOT,training.HERE
read,sha,require=training.read,training.sha,training.require
FIT=HERE/"residual_selection_fit_v1.json"
MODEL=HERE/"residual_selection_model_v1.json"
PARENT=HERE/"residual_training_closure_v1.json"
PARENT_SHA="13ea3010c6759dc2bc18e1d126f323af2766f2b6b971a25b2ecc251873534c91"
PILOT="sdk2-residual-training-6810e4b6dce34e9ea9ad471f9f297bf1"
PILOT_RECEIPT_SHA="5289b79e1895ffc9450b9565eba06fa4f7575774b472194eb61bcd59ce1f4a90"
SCOPE=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
    authority_mode="retrospective_exposed_training_selection",question_class="development")
RULE=dict(population="all eight signed candidates from both completed pilot iterations",
    eligibility="all eight training groups physically eligible",
    rank="descending arithmetic mean of the eight original fixed-horizon training rewards",
    tie_break="ascending stage/model_key identity",no_eligible="refuse native launch",
    fit_partitions=["training"],comparison_data_may_fit=False,
    weights_may_change=False,normalization_may_change=False,
    prior_final_checkpoint_may_change=False,reserved_groups_may_open=False)
DENIALS=("physical_acceptance_authority","release_authority","equivalence_authority",
    "tier2_complete","tier3_complete","tier3_benefit_established")


def keys(c):
    return [(s,f"d{d:02d}_"+("plus" if sign==1 else "minus"))
        for s in ("iteration_00","iteration_01") for d in range(c["directions"]) for sign in (1,-1)]


def select_population(candidates,c):
    """Require complete denominators before filtering or ranking candidates."""
    require([(r["stage"],r["model_key"]) for r in candidates]==keys(c),
        "Residual selection complete candidate population")
    summaries=[]
    for candidate in candidates:
        rows=candidate["trials"];stage,key=candidate["stage"],candidate["model_key"]
        plans=[p for p in training.trial_plans(c,stage) if p["model_key"]==key]
        require(len(rows)==len(plans)==8,"Residual selection complete group population")
        for row,plan in zip(rows,plans,strict=True):
            require(all(row.get(k)==v for k,v in plan.items()) and row["partition"]=="training"
                and row["provider_model_sha256"]==candidate["provider_model_sha256"]
                and row["policy_sha256"]==candidate["policy_sha256"]
                and row["controller_rows"]==c["outer_steps"] and row["internal_rows"]==5*c["outer_steps"]
                and row["reward_denominator"]==5*c["outer_steps"]
                and type(row["diagnostic_eligible"]) is bool
                and row["diagnostic_eligible"] is (row["first_reward_failure"] is None)
                and training.ars.finite(row["training_reward"]) and -1.<=row["training_reward"]<=0.
                and (training.ars.finite(row["official_quality_m_s"]) if row["diagnostic_eligible"]
                    else row["official_quality_m_s"] is None)
                and row["comparison_data_used_for_training"] is False,
                "Residual selection training trial identity/score")
        summaries.append(dict(stage=stage,model_key=key,candidate_id=stage+"/"+key,
            provider_model_sha256=candidate["provider_model_sha256"],policy_sha256=candidate["policy_sha256"],
            eligible_groups=sum(r["diagnostic_eligible"] for r in rows),total_groups=8,
            mean_training_reward=math.fsum(r["training_reward"] for r in rows)/8,
            trials=copy.deepcopy(rows)))
    eligible=sorted((s for s in summaries if s["eligible_groups"]==8),
        key=lambda s:(-s["mean_training_reward"],s["candidate_id"]))
    return dict(rule=copy.deepcopy(RULE),candidate_count=len(summaries),
        training_trial_count=sum(len(s["trials"]) for s in summaries),candidates=summaries,
        eligible_candidate_ids=[s["candidate_id"] for s in eligible],
        selected_candidate_id=eligible[0]["candidate_id"] if eligible else None)


def retained_population(evidence=None):
    """Read only hash-bound training audits and immutable candidate artifacts."""
    require(sha(PARENT)==PARENT_SHA,"Residual selection parent closure")
    parent=read(PARENT);require(parent["source_commit"]=="b29ea283f333be81e041a45648b156f74112e2a0"
        and all(parent[k] is False for k in DENIALS),"Residual selection parent authority")
    pilot=next(a for a in parent["attempts"] if a["lane"]=="pilot")
    require(pilot["attempt_id"]==PILOT and pilot["receipt_sha256"]==PILOT_RECEIPT_SHA,
        "Residual selection pilot identity")
    evidence=(evidence or ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    folder=(evidence/PILOT).resolve(strict=True)
    require(folder.parent==evidence and sha(folder/"receipt.json")==PILOT_RECEIPT_SHA,
        "Residual selection pilot receipt")
    c=training.declaration("pilot")
    records={r["stage"]:r for r in pilot["summary"]["stage_records"]}
    candidates=[];bindings={}
    for stage in ("iteration_00","iteration_01"):
        directory=folder/"stages"/stage;path=directory/"audit.json"
        require(sha(path)==records[stage]["audit_sha256"],"Residual selection audited training source")
        bindings[path.relative_to(evidence).as_posix()]=sha(path)
        audit=read(path);plans=training.trial_plans(c,stage)
        require(audit["ok"] is True and audit["synthetic"] is False and audit["stage"]==stage
            and audit["source_commit"]==parent["source_commit"] and audit["training_data_authority"] is True
            and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
            and len(audit["trials"])==len(plans)==32
            and all(all(r.get(k)==v for k,v in p.items()) for r,p in zip(audit["trials"],plans,strict=True)),
            "Residual selection complete audited training stage")
        require(sha(directory/"stage.json")==records[stage]["stage_claim_sha256"],"Residual selection stage claim")
        claim=read(directory/"stage.json")
        for _,key in (k for k in keys(c) if k[0]==stage):
            model=directory/"models"/(key+".json");artifact=read(model)
            digest="sha256:"+sha(model)
            fields=set(plans[0])|{"provider_model_sha256","policy_sha256","controller_rows","internal_rows",
                "reward_denominator","diagnostic_eligible","first_reward_failure","training_reward",
                "official_quality_m_s","comparison_data_used_for_training","raw_hashes","diagnostic_failure_codes"}
            rows=[{k:copy.deepcopy(r[k]) for k in sorted(fields)} for r in audit["trials"] if r["model_key"]==key]
            require(digest==claim["models"][key] and all(r["provider_model_sha256"]==digest for r in rows),
                "Residual selection immutable training artifact")
            policy_sha=training.ars.digest(artifact["policy"])
            require(all(r["policy_sha256"]==policy_sha for r in rows),"Residual selection policy identity")
            bindings[model.relative_to(evidence).as_posix()]=sha(model)
            candidates.append(dict(stage=stage,model_key=key,provider_model_sha256=digest,
                policy_sha256=policy_sha,trials=rows,model_path=model))
    return c,candidates,bindings


def expected_fit(evidence=None):
    c,candidates,bindings=retained_population(evidence)
    decision=select_population(candidates,c)
    require(decision["selected_candidate_id"] is not None,"Residual selection no complete eligible candidate")
    selected=next(r for r in candidates if r["stage"]+"/"+r["model_key"]==decision["selected_candidate_id"])
    artifact=read(selected["model_path"])
    result=dict(schema_version="locolemotion_residual_training_selection_v1",ledger_scope=SCOPE,
        selection_is_retrospective=True,selection_data_scope="complete exposed pilot training population only",
        source_closure_sha256=PARENT_SHA,pilot_attempt_id=PILOT,pilot_receipt_sha256=PILOT_RECEIPT_SHA,
        selector_sha256=sha(Path(__file__)),training_bindings=bindings,decision=decision,
        selected_model_path=MODEL.relative_to(ROOT).as_posix(),
        selected_model_sha256=selected["provider_model_sha256"],selected_policy_sha256=selected["policy_sha256"],
        original_model_corpus=artifact["corpus"],selected_artifact_preserved_byte_for_byte=True,
        original_training_worlds=64,worlds_opened=0,solver_steps=0,
        comparison_trials_used_for_selection=0,route_trials_used_for_selection=0,
        fresh_baseline_comparison_complete=False,promotion_authority=False,**{k:False for k in DENIALS})
    return result,selected["model_path"]


def validate_frozen(expected,record,encoded,original,core):
    require(record==expected and encoded==original,"Residual frozen training selection/model")
    import json
    model=training.provider.FrozenModel.load(core,json.loads(encoded))
    require(model.sha256==expected["selected_model_sha256"]
        and model.policy.sha256==expected["selected_policy_sha256"],"Residual selected provider round trip")
    return model


def verify_fit(core):
    expected,path=expected_fit()
    model=validate_frozen(expected,read(FIT),MODEL.read_bytes(),path.read_bytes(),core)
    require("sha256:"+sha(MODEL)==model.sha256,"Residual frozen model byte digest")
    return expected,model
