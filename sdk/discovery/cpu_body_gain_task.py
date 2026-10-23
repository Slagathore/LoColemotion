"""Prospective finite CPU body-attitude/rate factorial discovery and complete ranking."""
import json
import math
from cpu_posture_task import ROOT, HERE, FLAGS, sha, initial_arrays, declaration as parent_declaration
from adaptation_provider import body_gain_feedback_v1 as feedback

CONTRACT = HERE/"cpu_body_gain_discovery_v1.json"
require = feedback.require


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8")); model = feedback.definition()
    require(d["schema_version"] == "locolemotion_cpu_body_gain_discovery_v1"
        and d["seed"] == 104232200 and d["outer_steps"] == 480 and d["planned_cpu_worlds"] == 10
        and d["condition_id"] == "left_075" and d["candidate_count"] == 5
        and d["starts"] == [dict(id="start_002", lateral_velocity_m_s=.002),
            dict(id="start_005", lateral_velocity_m_s=.005)]
        and d["training_data_authority"] is True
        and all(d[k] is False for k in FLAGS if k != "training_data_authority"), "Body-gain discovery declaration")
    for key, path in [("feedback_model", feedback.CONTRACT),
        ("cpu_predecessor", HERE/"cpu_posture_discovery_closure_v1.json"),
        ("parent_contract", HERE/"cpu_posture_discovery_v1.json")]:
        require(d[key] == dict(path=path.relative_to(ROOT).as_posix(), sha256=sha(path)), "Body-gain lineage pin")
    require(d["factorial_axes"] == dict(attitude_gain_s_inv=[3.,6.],angular_damping=[.5,1.]), "Body-gain factorial axes")
    require(d["fixed_feedback_settings"] == dict(maximum_absolute_correction_rad_s=3.5,
        maximum_slew_per_step_rad_s=.08,posture_gain_s_inv=8.,velocity_gain_s_inv=0.)
        and d["reference_candidate"] == "feedback_kp3_kd05", "Body-gain fixed settings")
    c = parent_declaration()
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], challenge=d,
        seed=d["seed"], purpose=d["purpose"], training_scope="development_discovery_only",
        corpus="Only complete independently verified discovery may support later development fitting; no evaluation or promotion.",
        coverage=d["coverage"], not_covered=d["not_covered"], training_data_authority=True,
        maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"],
        provider=dict(kind="untrained_body_gain_feedback_v1", candidates=model["candidates"],
            envelope_selection=model["envelope_selection"]))
    return c


def d_axes(c):
    return c["challenge"]["factorial_axes"]


def trial_plan(c):
    return [dict(trial_id=start["id"]+"_"+candidate["id"], group_id=start["id"]+"_"+candidate["id"],
        partition="development_discovery", condition_id="left_075", start_id=start["id"], role=candidate["id"],
        seed=c["seed"], nworld=1, arm="scalar_direct", candidate_indices=[i], role_order=[candidate["id"]],
        initial_native_roll_rad=0., initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
        training_data_authority=not c.get("synthetic", False),
        control_axes={key:candidate[key] for key in d_axes(c)})
        for start in c["challenge"]["starts"] for i,candidate in enumerate(c["provider"]["candidates"])]


def rank(trials, c):
    plans = trial_plan(c)
    require(len(trials) == len(plans) == 10
        and all(all(t[k] == v for k,v in p.items()) for p,t in zip(plans,trials,strict=True)), "Body-gain ranking population")
    rows = []
    for i, candidate in enumerate(c["provider"]["candidates"]):
        episodes = [t["episodes"][0] for t in trials if t["candidate_indices"] == [i]]
        require(len(episodes) == 2 and all(e["action_id"] == candidate["id"]
            and e["outcome"] in ("positive", "negative") for e in episodes), "Body-gain ranking episodes")
        qualities = [e["metrics"]["quality_m_s"] for e in episodes]
        eligible = sum(e["outcome"] == "positive" for e in episodes)
        scorable = eligible == 2 and all(type(q) in (int,float) and math.isfinite(q) for q in qualities)
        rows.append(dict(candidate_index=i, candidate_id=candidate["id"], mode=candidate["mode"], control_axes={key:candidate[key] for key in d_axes(c)},
            eligible=eligible, denominator=2, outcomes=[e["outcome"] for e in episodes],
            failure_codes=[e["failure_code"] for e in episodes], qualities_m_s=qualities,
            mean_quality_m_s=sum(qualities)/2 if scorable else None, complete_eligible_pair=scorable))
    shortlist = sorted((r for r in rows if r["mode"] == "feedback" and r["complete_eligible_pair"]),
        key=lambda r: (-r["mean_quality_m_s"], r["candidate_index"]))
    return dict(candidates=rows, ranked_feedback_indices=[r["candidate_index"] for r in shortlist],
        selected_feedback_index=shortlist[0]["candidate_index"] if shortlist else None,
        selection_scope="exposed_finite_cpu_discovery", confirmation_required=True,
        physical_acceptance_authority=False, adaptation_benefit_established=False, qualification_or_release_authority=False)
