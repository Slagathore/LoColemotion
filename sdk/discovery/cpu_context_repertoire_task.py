"""Training-only delayed-control repertoire with disjoint reserved start groups."""
import json
import math
from cpu_body_height_task import ROOT, HERE, FLAGS, sha, initial_arrays, require, declaration as parent_declaration
from context_probe_control import PROBE_STEPS, FEATURE_NAMES

CONTRACT = HERE / "cpu_context_repertoire_v1.json"
PREDECESSOR = HERE / "cpu_body_height_confirmation_closure_v1.json"
PREDECESSOR_SHA = "d6a3ec7a79fc806ec64a397b1b0a6561e47f7b70db028c1b044f3903e3a1aef7"


def expected_declaration():
    return dict(schema_version="locolemotion_cpu_context_repertoire_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu",
                          authority_mode="development_discovery", question_class="development"),
        predecessor=dict(path="sdk/discovery/cpu_body_height_confirmation_closure_v1.json", sha256=PREDECESSOR_SHA),
        seed=104232300, outer_steps=1440, horizon_s=12., internal_steps_per_outer=5,
        conditions=["left_075", "nominal"], candidate_indices=[0, 1, 2], planned_cpu_worlds=24,
        partitions=dict(training=[dict(id="train_001", lateral_velocity_m_s=.001),
                                  dict(id="train_003", lateral_velocity_m_s=.003),
                                  dict(id="train_004", lateral_velocity_m_s=.004),
                                  dict(id="train_006", lateral_velocity_m_s=.006)],
                        calibration=[dict(id="cal_0015", lateral_velocity_m_s=.0015),
                                     dict(id="cal_0045", lateral_velocity_m_s=.0045)],
                        evaluation=[dict(id="eval_0025", lateral_velocity_m_s=.0025),
                                    dict(id="eval_0055", lateral_velocity_m_s=.0055)]),
        excluded_confirmation_starts=[.002, .005],
        probe=dict(baseline_commands=PROBE_STEPS, duration_s=PROBE_STEPS/120.,
                   feature_schema="locolemotion_causal_joint_response_v1", feature_names=FEATURE_NAMES,
                   decision="fixed declared role after shared baseline prefix; no learned choice in this campaign",
                   observations="canonical past state, actual issued action, current endpoint; no condition/model/force labels"),
        ranking="Per condition, require all four training starts eligible; maximize mean whole-episode tracking quality; tie by candidate index; retain all negatives.",
        confirmation_fitting_permitted=False, calibration_worlds=0, evaluation_worlds=0,
        initial_values="float32_equalized_inputs_then_native_float64_cpu_dynamics",
        maximum_worker_wall_seconds=2400, maximum_reader_wall_seconds=2400,
        purpose="Discover whether delayed fixed controllers remain useful after a shared causal baseline observation prefix, and retain authorized histories for later context fitting.",
        coverage=["24 fresh sequential CPU worlds and private controller memories",
                  "64 real no-proposal baseline commands and a 16-value causal joint-response vector",
                  "exact fixed baseline/reference/height repertoire with unchanged clamp and eligibility rules",
                  "complete independent controller replay, shared-prefix joins and native force/state/contact audit",
                  "training-only authority after full audit; calibration and evaluation starts remain unopened"],
        not_covered=["learned selection or memory benefit", "changing conditions within an episode",
                     "other morphology, terrain or engines", "GPU transfer", "population inference",
                     "formal non-inferiority", "qualification or release"],
        **{key: key == "training_data_authority" for key in FLAGS})


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d == expected_declaration(), "Context repertoire declaration")
    require(sha(PREDECESSOR) == PREDECESSOR_SHA, "Context repertoire predecessor bytes")
    c = parent_declaration()
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], challenge=d,
        seed=d["seed"], outer_steps=d["outer_steps"], purpose=d["purpose"],
        training_scope="development_context_discovery_only",
        corpus="Only complete independently verified training episodes may support development fitting; previous confirmation and reserved groups excluded.",
        coverage=d["coverage"], not_covered=d["not_covered"],
        maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"], **{key: d[key] for key in FLAGS})
    return c


def trial_plan(c):
    d = c["challenge"]
    return [dict(trial_id=condition+"_"+start["id"]+"_"+candidate["id"],
        group_id=condition+"_"+start["id"], partition="training", condition_id=condition,
        start_id=start["id"], role=candidate["id"], seed=d["seed"], nworld=1, arm="scalar_direct",
        candidate_indices=[index], role_order=[candidate["id"]], initial_native_roll_rad=0.,
        initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
        training_data_authority=not c.get("synthetic", False), baseline_probe_steps=PROBE_STEPS,
        control_axes=dict(height_enabled=candidate["height_enabled"]))
        for condition in d["conditions"] for start in d["partitions"]["training"]
        for index, candidate in enumerate(c["provider"]["candidates"])]


def assess(trials, c):
    plans = trial_plan(c)
    require(len(trials) == len(plans) == 24 and all(all(t.get(k) == v for k, v in p.items())
            for p, t in zip(plans, trials, strict=True)), "Context repertoire complete population")
    conditions = []
    for condition in c["challenge"]["conditions"]:
        candidates = []
        for index, candidate in enumerate(c["provider"]["candidates"]):
            rows = [t for t in trials if t["condition_id"] == condition and t["candidate_indices"] == [index]]
            require(len(rows) == 4 and all(len(t["episodes"]) == 1 for t in rows), "Context condition/role denominator")
            episodes = [t["episodes"][0] for t in rows]
            qualities = []
            for e in episodes:
                quality = e["metrics"]["quality_m_s"]
                require(e["action_id"] == candidate["id"] and e["outcome"] in ("positive", "negative")
                        and (quality is None or (type(quality) in (int, float) and math.isfinite(quality))),
                        "Context finite episode identity/quality")
                require((e["outcome"] == "positive" and e["failure_code"] is None)
                        or (e["outcome"] == "negative" and bool(e["failure_code"]) and quality is None),
                        "Context negative outcomes retain censored quality")
                qualities.append(quality)
            eligible = sum(e["outcome"] == "positive" for e in episodes)
            complete = eligible == 4 and all(q is not None for q in qualities)
            candidates.append(dict(candidate_index=index, candidate_id=candidate["id"], eligible=eligible,
                denominator=4, outcomes=[e["outcome"] for e in episodes],
                failure_codes=[e["failure_code"] for e in episodes], qualities_m_s=qualities,
                mean_quality_m_s=sum(qualities)/4 if complete else None, complete_eligible_group=complete))
        ranked = sorted((r for r in candidates if r["complete_eligible_group"]),
                        key=lambda r: (-r["mean_quality_m_s"], r["candidate_index"]))
        conditions.append(dict(condition_id=condition, candidates=candidates,
            ranked_candidate_indices=[r["candidate_index"] for r in ranked],
            selected_candidate_index=ranked[0]["candidate_index"] if ranked else None))
    return dict(conditions=conditions, selection_scope="exposed_training_groups_only",
        confirmation_fitting_permitted=False, calibration_worlds=0, evaluation_worlds=0,
        learned_selection=False, adaptation_benefit_established=False, population_inference=False,
        qualification_or_release_authority=False)
