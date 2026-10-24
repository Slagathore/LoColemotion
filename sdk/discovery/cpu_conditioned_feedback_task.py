"""Prospective frozen selection with fresh baseline, disabled and shuffled controls."""
import json
import math
from cpu_phase_release_task import ROOT,HERE,FLAGS,sha,initial_arrays,require,declaration as parent_declaration
from adaptation_provider.retrieval import conditioned_feedback_v2 as provider
from conditioned_feedback_dense_control import ROLES,PROVIDER_KIND

CONTRACT=HERE/"cpu_conditioned_feedback_v1.json"
MODEL_SHA="sha256:8cc55e0017e01a1f7d188a74bcd7729acdcc0ef9e65fa2916d6a3bc96f0c1a96"


def expected_declaration():
    parent=parent_declaration()["challenge"]
    return dict(schema_version="locolemotion_cpu_conditioned_feedback_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",authority_mode="development_discovery",question_class="development"),
        source_fit=dict(path=provider.FIT_RECORD.relative_to(ROOT).as_posix(),sha256=provider.FIT_SHA),
        model_sha256=MODEL_SHA,provider_definition=provider.definition(),
        seed=104232601,outer_steps=1440,horizon_s=12.,internal_steps_per_outer=5,
        conditions=["left_075","nominal"],roles=ROLES,planned_cpu_worlds=40,
        partitions=parent["partitions"],excluded_confirmation_starts=parent["excluded_confirmation_starts"],
        ranking="Require all eight condition/start episodes eligible and zero observed nominal quality loss against fresh baseline at every start; rank mean whole-episode quality, then role index. No statistical non-inferiority claim.",
        nominal_quality_loss_margin_m_s=0.,
        contrasts=[dict(id="frozen_minus_baseline",left="frozen",right="baseline"),
            dict(id="frozen_minus_disabled",left="frozen",right="disabled"),
            dict(id="frozen_minus_shuffled",left="frozen",right="shuffled"),
            dict(id="frozen_minus_reference",left="frozen",right="phase_reference"),
            dict(id="disabled_minus_baseline",left="disabled",right="baseline")],
        comparison="Five fresh roles at every exposed training start in both motor conditions. Dynamic policies retain their actual action sequence and are never labeled as one fixed expert.",
        influence="Report supported correction opportunities, actual nonzero corrections, first influence, refusals and logical/proposed action counts separately for every role; do not assume matched influence.",
        first_context_observation_commands=1,online_outcome_updates=False,base_weights_mutated=False,
        confirmation_fitting_permitted=False,calibration_worlds=0,evaluation_worlds=0,
        initial_values="float32_equalized_inputs_then_native_float64_cpu_dynamics",
        maximum_worker_wall_seconds=2400,maximum_reader_wall_seconds=2400,
        purpose="Test whether causal frozen expert selection improves full-horizon weakened-body control while preserving the healthy baseline.",
        coverage=["40 fresh sequential CPU worlds with private controller/provider memories",
            "five roles at four exposed training starts in weakened and nominal motor conditions",
            "one actual baseline command followed by frozen context and current-state retrieval",
            "complete fixed-case provenance, actual action sequences, exact fallback and bounded resolver",
            "separate supported opportunities and actual influence for disabled/frozen/shuffled roles",
            "unchanged native timing, eligibility, force observations and healthy quality screen",
            "full independent baseline-core replay and every native trace join"],
        not_covered=["Tier 3 outcome-memory benefit","empirical recoverability guarantee","reserved calibration or evaluation",
            "new morphology, terrain or engine","population inference","statistical non-inferiority","qualification or release"],
        **{key:key=="training_data_authority" for key in FLAGS})


def declaration():
    d=json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d==expected_declaration() and sha(provider.FIT_RECORD)==provider.FIT_SHA,"Conditioned prospective declaration/fit")
    c=parent_declaration()
    c["provider"]=dict(kind=PROVIDER_KIND,model_sha256=MODEL_SHA,definition=provider.definition())
    c.update(schema_version=d["schema_version"],ledger_scope=d["ledger_scope"],challenge=d,
        seed=d["seed"],outer_steps=d["outer_steps"],purpose=d["purpose"],
        training_scope="development_conditioned_feedback_discovery_only",
        corpus="Retain complete dynamic-policy episodes and actual action sequences; no automatic single-expert fitting. Confirmation and reserved groups excluded.",
        coverage=d["coverage"],not_covered=d["not_covered"],maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"],
        **{key:d[key] for key in FLAGS})
    return c


def trial_plan(c):
    d=c["challenge"]
    return [dict(trial_id=condition+"_"+start["id"]+"_"+role["id"],group_id=condition+"_"+start["id"],
        partition="training",condition_id=condition,start_id=start["id"],role=role["id"],selection_role_index=index,
        fixed_candidate_index=role["fixed_candidate_index"],action_sequence_kind="fixed_reference" if role["fixed_candidate_index"] is not None else "runtime_selection",
        seed=d["seed"],nworld=1,arm="scalar_direct",role_order=[role["id"]],
        initial_native_roll_rad=0.,initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
        training_data_authority=not c.get("synthetic",False))
        for condition in d["conditions"] for start in d["partitions"]["training"] for index,role in enumerate(ROLES)]


def assess(trials,c):
    plans=trial_plan(c)
    require(len(trials)==len(plans)==40 and all(all(t.get(k)==v for k,v in p.items()) for p,t in zip(plans,trials,strict=True)),"Conditioned complete population")
    for t in trials:
        require(len(t["episodes"])==1,"Conditioned episode denominator")
        e=t["episodes"][0];q=e["metrics"]["quality_m_s"]
        require(e["schema_version"]=="locolemotion_dynamic_policy_episode_v1" and e["policy_role_id"]==t["role"]
            and "action_id" not in e and "candidate_indices" not in t
            and e["outcome"] in ["positive","negative"] and (q is None or type(q) in (int,float) and math.isfinite(q)),"Conditioned episode identity/quality")
        require((e["outcome"]=="positive" and e["failure_code"] is None)
            or (e["outcome"]=="negative" and bool(e["failure_code"]) and q is None),"Conditioned failed quality remains censored")
    roles=[]
    for index,role in enumerate(ROLES):
        rows=[t for t in trials if t["selection_role_index"]==index]
        require(len(rows)==8,"Conditioned role denominator")
        episodes=[t["episodes"][0] for t in rows];qualities=[e["metrics"]["quality_m_s"] for e in episodes]
        eligible=sum(e["outcome"]=="positive" for e in episodes);complete=eligible==8 and all(q is not None for q in qualities)
        preservation=[]
        for start in c["challenge"]["partitions"]["training"]:
            group={t["role"]:t["episodes"][0] for t in trials if t["condition_id"]=="nominal" and t["start_id"]==start["id"]}
            candidate,baseline=group[role["id"]],group["baseline"]
            cq,bq=[e["metrics"]["quality_m_s"] for e in [candidate,baseline]]
            both=candidate["outcome"]==baseline["outcome"]=="positive" and cq is not None and bq is not None
            preservation.append(dict(start_id=start["id"],both_eligible=both,quality_difference_m_s=cq-bq if both else None,
                observed_quality_preserved=bool(both and cq-bq>=-c["challenge"]["nominal_quality_loss_margin_m_s"])))
        preserved=all(p["observed_quality_preserved"] for p in preservation)
        roles.append(dict(role_index=index,role_id=role["id"],fixed_candidate_index=role["fixed_candidate_index"],eligible=eligible,denominator=8,
            outcomes=[e["outcome"] for e in episodes],failure_codes=[e["failure_code"] for e in episodes],qualities_m_s=qualities,
            mean_quality_m_s=sum(qualities)/8 if complete else None,complete_eligible_group=complete,
            nominal_preservation=preservation,nominal_observed_quality_preserved=preserved,selection_eligible=complete and preserved))
    ranked=sorted((r for r in roles if r["selection_eligible"]),key=lambda r:(-r["mean_quality_m_s"],r["role_index"]))
    contrasts=[]
    for condition in c["challenge"]["conditions"]:
        for start in c["challenge"]["partitions"]["training"]:
            rows={t["role"]:t for t in trials if t["condition_id"]==condition and t["start_id"]==start["id"]}
            for contrast in c["challenge"]["contrasts"]:
                left,right=[rows[contrast[k]]["episodes"][0] for k in ["left","right"]]
                lq,rq=[e["metrics"]["quality_m_s"] for e in [left,right]]
                contrasts.append(dict(condition_id=condition,start_id=start["id"],contrast_id=contrast["id"],
                    left_outcome=left["outcome"],right_outcome=right["outcome"],both_eligible=left["outcome"]==right["outcome"]=="positive",
                    quality_difference_m_s=lq-rq if lq is not None and rq is not None else None,
                    left_influence=rows[contrast["left"]]["influence"],right_influence=rows[contrast["right"]]["influence"]))
    return dict(roles=roles,ranked_role_indices=[r["role_index"] for r in ranked],selected_role_index=ranked[0]["role_index"] if ranked else None,
        contrasts=contrasts,selection_scope="exposed_conditioned_feedback_training_groups_only",learned_selection=True,
        matched_influence_assumed=False,adaptation_benefit_established=False,tier3_benefit_established=False,
        population_inference=False,qualification_or_release_authority=False)
