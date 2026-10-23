"""Matched activation-time development discovery on four exposed degraded starts."""
import json
import math
from cpu_context_repertoire_task import ROOT, HERE, FLAGS, sha, initial_arrays, require, declaration as parent_declaration
from height_activation_control import ROLES

CONTRACT = HERE / "cpu_height_activation_v1.json"
PREDECESSOR = HERE / "early_context_feasibility_closure_v1.json"
PREDECESSOR_SHA = "56fc4ec807c734eab1e4b6d0e5bbc178d9f0cbbc699bd94d53a90128ac7d6c19"


def expected_declaration():
    parent=parent_declaration()["challenge"]
    return dict(schema_version="locolemotion_cpu_height_activation_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="development_discovery",question_class="development"),
        predecessor=dict(path="sdk/discovery/early_context_feasibility_closure_v1.json",sha256=PREDECESSOR_SHA),
        seed=104232400,outer_steps=1440,horizon_s=12.,internal_steps_per_outer=5,
        conditions=["left_075"],roles=ROLES,planned_cpu_worlds=12,
        partitions=parent["partitions"],excluded_confirmation_starts=parent["excluded_confirmation_starts"],
        ranking="Require all four starts eligible per activation role; rank mean whole-episode tracking quality, then role index. Preserve failures and censored quality.",
        contrasts=[dict(id="immediate_minus_baseline",left="height_immediate",right="baseline"),
                   dict(id="early_minus_baseline",left="height_after_16",right="baseline"),
                   dict(id="early_minus_immediate",left="height_after_16",right="height_immediate")],
        comparison="Fresh paired starts, fixed body/model/control equations; only declared onset differs between height roles. No cached physical baseline.",
        confirmation_fitting_permitted=False,calibration_worlds=0,evaluation_worlds=0,
        initial_values="float32_equalized_inputs_then_native_float64_cpu_dynamics",
        maximum_worker_wall_seconds=1800,maximum_reader_wall_seconds=1800,
        purpose="Determine whether unchanged height feedback remains useful after sixteen baseline commands at the same exposed degraded-body starts as immediate feedback.",
        coverage=["12 fresh sequential CPU worlds and private controller memories",
                  "baseline, immediate height and sixteen-command delayed height at four matched training starts",
                  "truthful baseline prefix only for baseline and delayed roles; no inferred action choice",
                  "unchanged height equations, safety clamps, native timing and full-horizon eligibility",
                  "complete independent controller/native replay and matched prefix/contrast joins"],
        not_covered=["nominal preservation", "learned choice or memory benefit", "new condition profiles",
                     "reserved calibration or evaluation", "other morphology, terrain or engines",
                     "population inference", "non-inferiority", "qualification or release"],
        **{key:key=="training_data_authority" for key in FLAGS})


def declaration():
    d=json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d==expected_declaration(),"Activation declaration")
    require(sha(PREDECESSOR)==PREDECESSOR_SHA,"Activation predecessor bytes")
    c=parent_declaration()
    c.update(schema_version=d["schema_version"],ledger_scope=d["ledger_scope"],challenge=d,
        seed=d["seed"],outer_steps=d["outer_steps"],purpose=d["purpose"],
        training_scope="development_activation_discovery_only",
        corpus="Only complete independently verified activation training trials may support development fitting; confirmation and reserved groups excluded.",
        coverage=d["coverage"],not_covered=d["not_covered"],
        maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"],**{key:d[key] for key in FLAGS})
    return c


def trial_plan(c):
    d=c["challenge"]
    return [dict(trial_id="left_075_"+start["id"]+"_"+role["id"],group_id="left_075_"+start["id"],
        partition="training",condition_id="left_075",start_id=start["id"],role=role["id"],
        activation_role_index=index,activation_step=role["activation_step"],baseline_probe_steps=role["baseline_probe_steps"],
        seed=d["seed"],nworld=1,arm="scalar_direct",candidate_indices=[role["candidate_index"]],role_order=[role["id"]],
        initial_native_roll_rad=0.,initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
        training_data_authority=not c.get("synthetic",False),
        control_axes=dict(height_enabled=c["provider"]["candidates"][role["candidate_index"]]["height_enabled"]))
        for start in d["partitions"]["training"] for index,role in enumerate(ROLES)]


def assess(trials,c):
    plans=trial_plan(c)
    require(len(trials)==len(plans)==12 and all(all(t.get(k)==v for k,v in p.items())
            for p,t in zip(plans,trials,strict=True)),"Activation complete population")
    roles=[]
    for index,role in enumerate(ROLES):
        rows=[t for t in trials if t["activation_role_index"]==index]
        require(len(rows)==4 and all(len(t["episodes"])==1 for t in rows),"Activation role denominator")
        episodes=[t["episodes"][0] for t in rows];qualities=[]
        for episode in episodes:
            quality=episode["metrics"]["quality_m_s"]
            require(episode["action_id"]==c["provider"]["candidates"][role["candidate_index"]]["id"]
                    and episode["outcome"] in ("positive","negative")
                    and (quality is None or (type(quality) in (int,float) and math.isfinite(quality))),"Activation episode identity/quality")
            require((episode["outcome"]=="positive" and episode["failure_code"] is None)
                    or (episode["outcome"]=="negative" and bool(episode["failure_code"]) and quality is None),
                    "Activation failed quality remains censored")
            qualities.append(quality)
        eligible=sum(e["outcome"]=="positive" for e in episodes)
        complete=eligible==4 and all(q is not None for q in qualities)
        roles.append(dict(role_index=index,role_id=role["id"],candidate_index=role["candidate_index"],
            activation_step=role["activation_step"],eligible=eligible,denominator=4,
            outcomes=[e["outcome"] for e in episodes],failure_codes=[e["failure_code"] for e in episodes],
            qualities_m_s=qualities,mean_quality_m_s=sum(qualities)/4 if complete else None,complete_eligible_group=complete))
    ranked=sorted((r for r in roles if r["complete_eligible_group"]),key=lambda r:(-r["mean_quality_m_s"],r["role_index"]))
    contrasts=[]
    for start in c["challenge"]["partitions"]["training"]:
        rows={t["role"]:t for t in trials if t["start_id"]==start["id"]}
        for contrast in c["challenge"]["contrasts"]:
            left,right=[rows[contrast[k]]["episodes"][0] for k in ["left","right"]]
            lq,rq=[e["metrics"]["quality_m_s"] for e in [left,right]]
            contrasts.append(dict(start_id=start["id"],contrast_id=contrast["id"],
                left_outcome=left["outcome"],right_outcome=right["outcome"],
                both_eligible=left["outcome"]==right["outcome"]=="positive",
                quality_difference_m_s=lq-rq if lq is not None and rq is not None else None))
    return dict(roles=roles,ranked_role_indices=[r["role_index"] for r in ranked],
        selected_role_index=ranked[0]["role_index"] if ranked else None,contrasts=contrasts,
        selection_scope="exposed_activation_training_groups_only",learned_selection=False,
        adaptation_benefit_established=False,population_inference=False,qualification_or_release_authority=False)
