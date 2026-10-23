"""Fixed-candidate duration and nominal-body confirmation; no fitting or reselection."""
import json
import math
from cpu_body_height_task import ROOT, HERE, FLAGS, sha, initial_arrays, require, declaration as parent_declaration

CONTRACT = HERE / "cpu_body_height_confirmation_v1.json"
PREDECESSOR = HERE / "cpu_body_height_discovery_closure_v1.json"
PREDECESSOR_SHA = "56610a8e8b09835b873feedcdd2e36e60aa7dec75756b568c2433c721a222010"


def expected_declaration():
    return dict(schema_version="locolemotion_cpu_body_height_confirmation_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu",
            authority_mode="development_confirmation", question_class="development"),
        predecessor=dict(path="sdk/discovery/cpu_body_height_discovery_closure_v1.json", sha256=PREDECESSOR_SHA),
        selected_candidate_index=2, selected_candidate_id="feedback_height_v1",
        seed=104232200, outer_steps=1440, horizon_s=12., internal_steps_per_outer=5,
        conditions=["left_075", "nominal"],
        starts=[dict(id="start_002", lateral_velocity_m_s=.002), dict(id="start_005", lateral_velocity_m_s=.005)],
        candidate_indices=[0, 1, 2], planned_cpu_worlds=12,
        initial_values="float32_equalized_inputs_then_native_float64_cpu_dynamics",
        maximum_worker_wall_seconds=1200, maximum_reader_wall_seconds=1200,
        purpose="Confirm the already selected exact height controller over three times the discovery horizon and characterize the nominal-body cost against fresh baseline and reference.",
        comparison_scope="descriptive_fixed_candidate_no_reselection",
        quality_semantics="negative_velocity_tracking_error_not_signed_travel",
        nominal_quality_guard="Report exact candidate-minus-baseline and candidate-minus-reference differences only when both whole episodes are eligible; no statistical non-inferiority claim or tolerance.",
        failure_timing_used_for_selection=False, controller_selection_authority=False,
        population_inference=False, adaptation_benefit_established=False,
        coverage=["twelve private controller memories and fresh sequential CPU data instances",
            "exact selected controller and unchanged baseline/reference; no parameter fitting",
            "two exposed starts on left-75 and nominal actuator profiles",
            "1440 commands and 7200 internal samples per world with unchanged sampling and eligibility",
            "complete independent decision replay, native state/force/contact audit and censored pair reporting"],
        not_covered=["unopened evaluation groups", "other starts, bodies, terrain or engines",
            "GPU transfer", "learned selection or memory benefit", "population inference",
            "formal non-inferiority", "qualification or release"],
        **{key: False for key in FLAGS})


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d == expected_declaration(), "Height confirmation declaration")
    require(sha(PREDECESSOR) == PREDECESSOR_SHA, "Height confirmation predecessor binding")
    predecessor = json.loads(PREDECESSOR.read_text(encoding="utf-8"))
    require(predecessor["finite_outcomes"]["ranking"]["selected_feedback_index"] == 2,
        "Height confirmation selection provenance")
    c = parent_declaration()
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], challenge=d,
        seed=d["seed"], outer_steps=d["outer_steps"], purpose=d["purpose"],
        training_scope="development_confirmation_no_fitting", corpus="No confirmation fitting or reselection authority.",
        coverage=d["coverage"], not_covered=d["not_covered"],
        maximum_worker_wall_seconds=d["maximum_worker_wall_seconds"], **{key: False for key in FLAGS})
    require(c["provider"]["candidates"][2]["id"] == d["selected_candidate_id"]
        and c["internal_steps_per_outer"] == 5 and c["phase_mode"] == "clocked",
        "Height confirmation controller/timing identity")
    return c


def trial_plan(c):
    d = c["challenge"]
    return [dict(trial_id=condition+"_"+start["id"]+"_"+candidate["id"],
        group_id=condition+"_"+start["id"]+"_"+candidate["id"], partition="development_confirmation",
        condition_id=condition, start_id=start["id"], role=candidate["id"], seed=d["seed"],
        nworld=1, arm="scalar_direct", candidate_indices=[index], role_order=[candidate["id"]],
        initial_native_roll_rad=0., initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"],
        training_data_authority=False, control_axes=dict(height_enabled=candidate["height_enabled"]))
        for condition in d["conditions"] for start in d["starts"]
        for index, candidate in enumerate(c["provider"]["candidates"])]


def assess(trials, c):
    plans = trial_plan(c)
    require(len(trials) == len(plans) == 12
        and all(all(t.get(k) == v for k,v in p.items()) for p,t in zip(plans,trials,strict=True)),
        "Height confirmation population")
    by_key = {}
    for trial in trials:
        require(len(trial["episodes"]) == 1, "Height confirmation episode denominator")
        episode = trial["episodes"][0]; index = trial["candidate_indices"][0]
        require(episode["action_id"] == c["provider"]["candidates"][index]["id"]
            and episode["outcome"] in ("positive", "negative"), "Height confirmation episode identity")
        quality = episode["metrics"]["quality_m_s"]
        require(quality is None or (type(quality) in (float,int) and math.isfinite(quality)),
            "Height confirmation finite quality")
        require((episode["outcome"] == "positive" and episode["failure_code"] is None)
            or (episode["outcome"] == "negative" and bool(episode["failure_code"]) and quality is None),
            "Height confirmation censored outcome")
        by_key[trial["condition_id"], trial["start_id"], index] = trial
    pairs = []; conditions = []
    for condition in c["challenge"]["conditions"]:
        counts = [sum(by_key[condition,s["id"],i]["episodes"][0]["outcome"] == "positive"
            for s in c["challenge"]["starts"]) for i in range(3)]
        conditions.append(dict(condition_id=condition, baseline_eligible=counts[0], reference_eligible=counts[1],
            selected_eligible=counts[2], denominator_per_role=2, selected_passes_both=counts[2] == 2))
        for start in c["challenge"]["starts"]:
            for other in [0,1]:
                a,b = [by_key[condition,start["id"],i] for i in [other,2]]
                ea,eb = [t["episodes"][0] for t in [a,b]]
                qa,qb = [e["metrics"]["quality_m_s"] for e in [ea,eb]]
                scorable = all(e["outcome"] == "positive" for e in [ea,eb]) and qa is not None and qb is not None
                pairs.append(dict(condition_id=condition, start_id=start["id"], comparator_index=other,
                    comparator_trial=a["trial_id"], selected_trial=b["trial_id"],
                    comparator_outcome=ea["outcome"], selected_outcome=eb["outcome"],
                    eligibility_change=int(eb["outcome"] == "positive")-int(ea["outcome"] == "positive"),
                    quality_change_if_both_eligible_m_s=qb-qa if scorable else None))
    nominal = [p for p in pairs if p["condition_id"] == "nominal" and p["comparator_index"] == 0]
    nominal_changes = [p["quality_change_if_both_eligible_m_s"] for p in nominal]
    return dict(selected_candidate_index=2, selection_changed=False, conditions=conditions, pair_count=8, pairs=pairs,
        nominal_quality_at_least_baseline_on_both=(all(q >= 0 for q in nominal_changes)
            if all(q is not None for q in nominal_changes) else None),
        scope=c["challenge"]["comparison_scope"], training_data_authority=False,
        failure_timing_used_for_selection=False, population_inference=False,
        noninferiority_authority=False, adaptation_benefit_established=False, qualification_or_release_authority=False)
