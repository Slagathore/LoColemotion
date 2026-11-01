"""Fixed full-capture challenge of the completed population's four leads."""
import copy
import json
import math

import population_discovery_task_v2 as parent
from population_discovery_task_v1 import ROOT, HERE, FLAGS, LiveBlock, require, sha, f32
from population_discovery_task_v1 import summarize as summarize_records

CONTRACT = HERE / "population_shortlist_v1.json"
PREDECESSOR = HERE / "population_discovery_native_result_v2.json"
PREDECESSOR_SHA = "f222a36c7eb69f3a8ed2be629eb083f92feef83e1f58d754512a063fde31290f"
PARENT = parent.CONTRACT
PARENT_SHA = "295ad6a537297288895cc78819676b21e6fda40cb1527efc4348a04c55729b09"
INDICES = [0, 8, 18, 55, 27]
SELECTED = {"nominal": [8, 18], "left_075": [55, 27]}
SOURCES = ["population_shortlist_task_v1.py", "population_shortlist_v1.py",
    "audit_population_shortlist_v1.py", "run_population_shortlist_v1.py", "test_population_shortlist_v1.py"]
GATES = [*parent.GATES, ("shortlist", "test_population_shortlist_v1", 20)]


def expected_declaration():
    c = parent.declaration()
    return dict(schema_version="locolemotion_population_shortlist_v1",
        ledger_scope=dict(subsystem="discovery", engine_scope="mujoco_warp",
            authority_mode="development_shortlist_validation", question_class="development"),
        predecessor=dict(path=PREDECESSOR.relative_to(ROOT).as_posix(), sha256=PREDECESSOR_SHA),
        parent=dict(path=PARENT.relative_to(ROOT).as_posix(), sha256=PARENT_SHA),
        seed=1061102, candidate_indices=INDICES, selected_by_condition=SELECTED,
        fixed_profiles=[copy.deepcopy(c["provider"]["candidates"][i]) for i in INDICES],
        conditions=["nominal", "left_075"],
        starts=[dict(id="train_001", lateral_velocity_m_s=.001), dict(id="train_003", lateral_velocity_m_s=.003)],
        outer_steps=1440, prefix_outer_steps=240, horizon_s=12., prefix_horizon_s=2.,
        internal_steps_per_outer=5, planned_worlds=20, planned_trials=4, maximum_simultaneous_gpu_worlds=5,
        capture_mode="full", native_reads_reduced=False, device_history_reduced=False,
        full_controller_replay_required_for_every_world=True,
        purpose="Check the exact four selected profiles and fresh baseline in both actuator conditions over twelve seconds; report the fresh two-second prefix separately.",
        assessment="All fixed profiles and outcomes; positive baseline-minus-profile velocity error only for eligible pairs; no fitting, ranking, reselection or statistical claim.",
        failure_policy="Retain expected performance failures through the complete fixed horizon; invalid execution stops the operation.",
        maximum_trace_bytes_per_stream=1073741824, minimum_free_storage_bytes=34359738368,
        maximum_worker_wall_seconds=3600, maximum_reader_wall_seconds=1800,
        safety_controls=[dict(name=n, module=m, count=k) for n, m, k in GATES],
        safety_control_count=sum(k for _, _, k in GATES),
        coverage=["fresh controller memories and native state in every world", "unchanged model and correction envelopes",
            "both actuator conditions and both exposed starts for every fixed profile", "complete native substep history and all solver inputs",
            "full independent scalar decision replay and native force, contact, clock and state joins for every world",
            "separate prefix and whole-episode outcomes", "retained-handle containment and source/runtime drift checks"],
        not_covered=["unopened calibration or evaluation starts", "other morphology, terrain or engines", "policy switching or withdrawal",
            "learned selection", "online memory updates", "population inference", "real-time qualification", "release"],
        selection_changed=False, training_data_authority=False, physical_acceptance_authority=False,
        equivalence_authority=False, release_authority=False)


def declaration():
    d = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(d == expected_declaration() and sha(PREDECESSOR) == PREDECESSOR_SHA and sha(PARENT) == PARENT_SHA,
        "Shortlist declaration or predecessor changed")
    predecessor = json.loads(PREDECESSOR.read_text(encoding="utf-8"))
    require(predecessor["finite_outcomes"]["frozen_shortlist_by_condition"] == SELECTED
        and predecessor["population_audit"]["ok"] is True
        and predecessor["population_worlds"] == 256
        and all(predecessor[k] is False for k in FLAGS), "Shortlist selection provenance or authority")
    c = parent.declaration()
    c.update(schema_version=d["schema_version"], ledger_scope=d["ledger_scope"], challenge=d,
        seed=d["seed"], outer_steps=d["outer_steps"], purpose=d["purpose"],
        maximum_trace_bytes_per_trial=d["maximum_trace_bytes_per_stream"],
        training_scope="none", corpus="No fitting or reuse of reduced discovery records as full evidence",
        **{key: False for key in FLAGS})
    return c


def synthetic_contract(c, count=2):
    """Small explicit zero-world fixture, accepted only by the reader test entry."""
    require(type(count) is int and 2 <= count <= 4, "Synthetic shortlist horizon")
    c = copy.deepcopy(c)
    c.update(synthetic=True, outer_steps=count)
    c["challenge"].update(outer_steps=count, prefix_outer_steps=1,
        horizon_s=count*5*c["timestep_s"], prefix_horizon_s=5*c["timestep_s"])
    return c


def plans(c, phase="challenge"):
    require(phase == "challenge", "Unknown shortlist phase")
    d = c["challenge"]
    return [dict(trial_id=condition+"_"+start["id"]+"_full", group_id=condition+"_"+start["id"],
        phase=phase, partition="development_shortlist_validation", condition_id=condition, start_id=start["id"],
        seed=d["seed"], arm="batch_graph", capture_mode="full", nworld=len(d["candidate_indices"]),
        candidate_indices=list(d["candidate_indices"]), initial_native_roll_rad=0.,
        initial_native_lateral_velocity_m_s=start["lateral_velocity_m_s"], outer_steps=c["outer_steps"])
        for condition in d["conditions"] for start in d["starts"]]


def summarize(rows, c, plan, spec):
    episodes = summarize_records(rows, c, plan, spec)
    for episode in episodes:
        episode["capture_scope"] = "full_capture_development"
        episode.pop("qualification_requires_fresh_full_capture")
        episode["qualification_requires_new_contract"] = True
    return episodes


def assess(trials, c):
    expected = plans(c)
    require(len(trials) == len(expected) and all(t["plan"] == p for t, p in zip(trials, expected, strict=True)),
        "Shortlist complete fixed trial population")
    episodes = {}
    for trial, plan in zip(trials, expected, strict=True):
        replay = trial.get("full_replay", {})
        require(replay.get("projection_verified") is True
            and replay.get("controller_rows") == plan["nworld"]*plan["outer_steps"]
            and replay.get("internal_rows") == 5*plan["nworld"]*plan["outer_steps"], "Shortlist complete full replay")
        require(len(trial["episodes"]) == len(trial["prefix_episodes"]) == plan["nworld"], "Shortlist episode denominator")
        for cell, (whole, prefix) in enumerate(zip(trial["episodes"], trial["prefix_episodes"], strict=True)):
            index = plan["candidate_indices"][cell]
            for e in (whole, prefix):
                require((e["candidate_index"], e["candidate_id"], e["cell"], e["condition_id"], e["start_id"], e["seed"]) ==
                    (index, c["provider"]["candidates"][index]["id"], cell, plan["condition_id"], plan["start_id"], plan["seed"]),
                    "Shortlist candidate/start identity")
                error = e["velocity_error_m_s"]
                require(type(e["eligible"]) is bool and e["eligible"] == (not e["failure_codes"])
                    and ((e["eligible"] and type(error) in (int, float) and math.isfinite(error) and error >= 0)
                    or (not e["eligible"] and error is None)), "Shortlist failure quality censoring")
            a, b = prefix["metrics"], whole["metrics"]
            require(b["minimum_height_m"] <= a["minimum_height_m"] and b["maximum_tilt_rad"] >= a["maximum_tilt_rad"]
                and all(b[k] >= a[k] for k in ("torso_contact_steps", "ground_contact_steps", "nonzero_force_steps", "safe_no_actuation_steps"))
                and (prefix["first_failure_native_step"] is None or whole["first_failure_native_step"] == prefix["first_failure_native_step"]),
                "Shortlist prefix failure or cumulative metrics erased")
            episodes[plan["condition_id"], plan["start_id"], index] = dict(prefix=prefix, whole=whole)
    conditions = []
    for condition in c["challenge"]["conditions"]:
        profiles, pairs = [], []
        starts = c["challenge"]["starts"]
        for index in c["challenge"]["candidate_indices"]:
            rows = [episodes[condition, s["id"], index] for s in starts]
            summary = dict(candidate_index=index, candidate_id=c["provider"]["candidates"][index]["id"],
                selected_for_condition=index in c["challenge"]["selected_by_condition"][condition])
            for window in ("prefix", "whole"):
                eligible = sum(r[window]["eligible"] for r in rows)
                summary[window] = dict(eligible_starts=eligible, start_count=len(starts), both_starts_eligible=eligible == len(starts),
                    mean_velocity_error_m_s=sum(r[window]["velocity_error_m_s"] for r in rows)/len(rows) if eligible == len(starts) else None,
                    failure_codes=[r[window]["failure_codes"] for r in rows],
                    first_failure_native_steps=[r[window]["first_failure_native_step"] for r in rows])
            profiles.append(summary)
            if index == 0:
                continue
            for start, row in zip(starts, rows, strict=True):
                baseline = episodes[condition, start["id"], 0]
                pair = dict(start_id=start["id"], candidate_index=index)
                for window in ("prefix", "whole"):
                    a, b = baseline[window], row[window]
                    pair[window] = dict(baseline_eligible=a["eligible"], candidate_eligible=b["eligible"],
                        eligibility_change=int(b["eligible"])-int(a["eligible"]),
                        baseline_minus_candidate_error_m_s=a["velocity_error_m_s"]-b["velocity_error_m_s"]
                            if a["eligible"] and b["eligible"] else None)
                pairs.append(pair)
        conditions.append(dict(condition_id=condition, profiles=profiles, pairs=pairs))
    return dict(conditions=conditions, prefix_horizon_s=c["challenge"]["prefix_horizon_s"],
        whole_horizon_s=c["challenge"]["horizon_s"], fixed_candidate_indices=c["challenge"]["candidate_indices"],
        selection_changed=False, population_inference=False, failure_timing_used_for_selection=False,
        trained_provider=False, calibration_worlds=0, evaluation_worlds=0,
        **{key: False for key in FLAGS})
