"""Prospective phase release across four training starts and both motor conditions."""
import json
import math
from cpu_support_vertical_task import ROOT, HERE, FLAGS, sha, initial_arrays, require, declaration as parent_declaration
from adaptation_provider import phase_release_feedback_v1 as feedback
from phase_release_control import ROLES

CONTRACT = HERE / "cpu_phase_release_v1.json"
PREDECESSOR = HERE / "phase_contact_diagnostic_v1.json"
PREDECESSOR_SHA = "aacd554c392c319ce876da241fb3b96979573127e25bef979a955adcaedaeacc"


def expected_declaration():
    parent = parent_declaration()["challenge"]
    return dict(schema_version="locolemotion_cpu_phase_release_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu",
            authority_mode="development_discovery", question_class="development"),
        predecessor=dict(path="sdk/discovery/phase_contact_diagnostic_v1.json", sha256=PREDECESSOR_SHA),
        seed=104232600, outer_steps=1440, horizon_s=12., internal_steps_per_outer=5,
        conditions=["left_075", "nominal"], roles=ROLES, planned_cpu_worlds=32,
        partitions=parent["partitions"], excluded_confirmation_starts=parent["excluded_confirmation_starts"],
        ranking="Require all eight condition/start episodes eligible and zero observed nominal quality loss against fresh baseline at every start; rank mean whole-episode quality, then role index. No statistical non-inferiority claim.",
        nominal_quality_loss_margin_m_s=0.,
        contrasts=[dict(id="reference_minus_baseline", left="vertical_immediate", right="baseline"),
                   dict(id="immediate_minus_baseline", left="phase_immediate", right="baseline"),
                   dict(id="early_minus_baseline", left="phase_after_16", right="baseline"),
                   dict(id="immediate_minus_reference", left="phase_immediate", right="vertical_immediate"),
                   dict(id="early_minus_immediate", left="phase_after_16", right="phase_immediate")],
        comparison="Fresh baseline, unchanged vertical parent, immediate phase release and delayed phase release in each degraded and healthy condition/start group. No cached baseline.",
        confirmation_fitting_permitted=False, calibration_worlds=0, evaluation_worlds=0,
        initial_values="float32_equalized_inputs_then_native_float64_cpu_dynamics",
        maximum_worker_wall_seconds=1800, maximum_reader_wall_seconds=1800,
        purpose="Test whether phase-aware release yields full-horizon control across four starts while preserving observed healthy-body baseline quality.",
        coverage=["32 fresh sequential CPU worlds and private controller memories",
            "four roles at all four training starts in both left_075 and nominal conditions",
            "actual current provider context phase and 44-command bounded release before swing",
            "truthful sixteen-command baseline history only for baseline and delayed roles",
            "unchanged parent feedback, resolver limits, physical timing and eligibility",
            "independent full controller replay, native trace joins, contrasts and finite nominal preservation"],
        not_covered=["learned choice or memory benefit", "new condition profiles", "reserved calibration or evaluation",
            "other morphology, terrain or engines", "population inference", "statistical non-inferiority",
            "qualification or release"], **{key:key == "training_data_authority" for key in FLAGS})


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d == expected_declaration(), "Phase-release declaration")
    require(sha(PREDECESSOR) == PREDECESSOR_SHA, "Phase-release predecessor bytes")
    c = parent_declaration()
    model = feedback.definition()
    c["provider"] = dict(kind="untrained_phase_release_feedback_v1", candidates=model["candidates"],
        envelope_selection=model["envelope_selection"], ground_domain=model["ground_domain"])
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], challenge=d,
        seed=d["seed"], outer_steps=d["outer_steps"], purpose=d["purpose"],
        training_scope="development_phase_release_discovery_only",
        corpus="Only complete independently verified phase-release training trials may support development fitting; confirmation and reserved groups excluded.",
        coverage=d["coverage"], not_covered=d["not_covered"],
        maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"], **{key:d[key] for key in FLAGS})
    return c


def trial_plan(c):
    d = c["challenge"]
    return [dict(trial_id=condition+"_"+start["id"]+"_"+role["id"], group_id=condition+"_"+start["id"],
        partition="training", condition_id=condition, start_id=start["id"], role=role["id"],
        activation_role_index=index, activation_step=role["activation_step"], baseline_probe_steps=role["baseline_probe_steps"],
        seed=d["seed"], nworld=1, arm="scalar_direct", candidate_indices=[role["candidate_index"]], role_order=[role["id"]],
        initial_native_roll_rad=0., initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
        training_data_authority=not c.get("synthetic", False),
        control_axes=dict(support_vertical_compensation=c["provider"]["candidates"][role["candidate_index"]].get("support_vertical_compensation", False),
            phase_release=c["provider"]["candidates"][role["candidate_index"]].get("phase_release", False)))
        for condition in d["conditions"] for start in d["partitions"]["training"] for index, role in enumerate(ROLES)]


def assess(trials, c):
    plans = trial_plan(c)
    require(len(trials) == len(plans) == 32 and all(all(t.get(k) == v for k, v in p.items())
        for p, t in zip(plans, trials, strict=True)), "Phase-release complete population")
    for trial in trials:
        require(len(trial["episodes"]) == 1, "Phase-release episode denominator")
        episode = trial["episodes"][0]
        quality = episode["metrics"]["quality_m_s"]
        require(episode["action_id"] == c["provider"]["candidates"][trial["candidate_indices"][0]]["id"]
            and episode["outcome"] in ("positive", "negative")
            and (quality is None or (type(quality) in (int, float) and math.isfinite(quality))),
            "Phase-release episode identity/quality")
        require((episode["outcome"] == "positive" and episode["failure_code"] is None)
            or (episode["outcome"] == "negative" and bool(episode["failure_code"]) and quality is None),
            "Phase-release failed quality remains censored")
    roles = []
    for index, role in enumerate(ROLES):
        rows = [t for t in trials if t["activation_role_index"] == index]
        require(len(rows) == 8, "Phase-release role denominator")
        episodes = [t["episodes"][0] for t in rows]
        qualities = [e["metrics"]["quality_m_s"] for e in episodes]
        eligible = sum(e["outcome"] == "positive" for e in episodes)
        complete = eligible == 8 and all(q is not None for q in qualities)
        preservation = []
        for start in c["challenge"]["partitions"]["training"]:
            group = {t["role"]: t["episodes"][0] for t in trials if t["condition_id"] == "nominal" and t["start_id"] == start["id"]}
            candidate, baseline = group[role["id"]], group["baseline"]
            cq, bq = [e["metrics"]["quality_m_s"] for e in [candidate, baseline]]
            both = candidate["outcome"] == baseline["outcome"] == "positive" and cq is not None and bq is not None
            preservation.append(dict(start_id=start["id"], both_eligible=both,
                quality_difference_m_s=cq-bq if both else None,
                observed_quality_preserved=bool(both and cq-bq >= -c["challenge"]["nominal_quality_loss_margin_m_s"])))
        preserved = all(p["observed_quality_preserved"] for p in preservation)
        roles.append(dict(role_index=index, role_id=role["id"], candidate_index=role["candidate_index"],
            activation_step=role["activation_step"], eligible=eligible, denominator=8,
            outcomes=[e["outcome"] for e in episodes], failure_codes=[e["failure_code"] for e in episodes],
            qualities_m_s=qualities, mean_quality_m_s=sum(qualities)/8 if complete else None,
            complete_eligible_group=complete, nominal_preservation=preservation,
            nominal_observed_quality_preserved=preserved, selection_eligible=complete and preserved))
    ranked = sorted((r for r in roles if r["selection_eligible"]), key=lambda r:(-r["mean_quality_m_s"], r["role_index"]))
    contrasts = []
    for condition in c["challenge"]["conditions"]:
        for start in c["challenge"]["partitions"]["training"]:
            rows = {t["role"]:t for t in trials if t["condition_id"] == condition and t["start_id"] == start["id"]}
            for contrast in c["challenge"]["contrasts"]:
                left, right = [rows[contrast[k]]["episodes"][0] for k in ["left", "right"]]
                lq, rq = [e["metrics"]["quality_m_s"] for e in [left, right]]
                contrasts.append(dict(condition_id=condition, start_id=start["id"], contrast_id=contrast["id"],
                    left_outcome=left["outcome"], right_outcome=right["outcome"],
                    both_eligible=left["outcome"] == right["outcome"] == "positive",
                    quality_difference_m_s=lq-rq if lq is not None and rq is not None else None))
    return dict(roles=roles, ranked_role_indices=[r["role_index"] for r in ranked],
        selected_role_index=ranked[0]["role_index"] if ranked else None, contrasts=contrasts,
        selection_scope="exposed_phase_release_training_groups_only", learned_selection=False,
        adaptation_benefit_established=False, population_inference=False, qualification_or_release_authority=False)
