"""Post-hoc stance velocity composition from the complete activation population.

Projected joint velocities describe motion relative to a fixed torso. They are
neither measured contact forces nor a counterfactual trajectory. The body-motion
request excludes the baseline gait objective; its discrepancy is not the
campaign's tracking-quality score or proof of a controller bug.
"""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

from adaptation_provider import body_height_feedback_v1 as height
from adaptation_provider import stance_feedback_v1 as geometry
from audit_cpu_height_activation_closure import verify_record as verify_parent, read
from audit_gpu_batch_execution import read_jsonl, same_bits
from cpu_height_activation_task import ROOT, sha, require
from support_reach_diagnostic import geometry_inputs, frame as reach_frame

PARENT = ROOT / "sdk/discovery/cpu_height_activation_closure_v1.json"
PARENT_SHA = "654e9cab60a831e5a1afd4fe89e433050eba4b0bf5f7313c5b46b0c722f55685"
PREFIX = 120
STARTS = ["train_001", "train_003", "train_004", "train_006"]
STAGES = ["baseline", "raw_feedback", "unclamped_sum", "final_command", "observed_joint_velocity"]
SNAPSHOTS = [0, 30, 60, 90, 119]
AUTHORITY = dict(physical_acceptance_authority=False, release_authority=False,
    training_data_authority=False, selection_authority=False, causal_authority=False,
    population_inference=False, counterfactual_performance_authority=False)


def project(jacobian, velocity):
    require(len(jacobian) == 2 and all(len(v) == 2 for v in jacobian)
        and len(velocity) == 2 and all(math.isfinite(v) for row in jacobian for v in row)
        and all(math.isfinite(v) for v in velocity), "Projection shape/finite domain")
    return [sum(a*b for a, b in zip(row, velocity, strict=True)) for row in jacobian]


def describe_frame(row, model, reach_model, joints, sites):
    state = row["request"]["state"]
    step = row["outer_step"]
    require(state["semantic_step"] == step and row["activation_probe"]["activation_step"] == 0,
        "Immediate controller step/activation")
    delta, detail = height.feedback(state, row["request"]["command"], height.expected_candidates()[2], model)
    require(same_bits(detail, row["feedback"]), "Retained feedback calculation changed")
    reach = reach_frame(row, reach_model, joints, sites)
    observations = state["ordered_joint_observations"]
    require([j["joint_id"] for j in observations] == geometry.JOINTS
        and all(j["validity"]["position"] and j["validity"]["velocity"] for j in observations),
        "Composition joint observations")
    angles = [j["position_rad"] for j in observations]
    velocities = [j["velocity_rad_s"] for j in observations]
    commands = row["resolution"]["ordered_commands"]
    require([c["actuator_id"] for c in commands] == [j+"_motor" for j in geometry.JOINTS],
        "Composition command identity")
    legs = []
    for i, (leg, feedback, witness) in enumerate(zip(model["legs"], detail["legs"], reach["legs"], strict=True)):
        joint_slice = slice(2*i, 2*i+2)
        point, jacobian = geometry.foot_geometry(leg, *angles[joint_slice])
        require(same_bits(point, feedback["foot_center_body_m"]), "Composition foot geometry")
        command = commands[joint_slice]
        base = [c["baseline_canonical_target_velocity_rad_s"] for c in command]
        raw = delta[joint_slice]
        require(same_bits(raw, [c["proposed_correction_rad_s"] for c in command]),
            "Composition proposed-command join")
        requested = [a+b for a, b in zip(feedback["requested_foot_velocity_xy_m_s"],
            detail["height_control"]["requested_foot_velocity_body_m_s"][:2], strict=True)]
        joint_stages = dict(baseline=base, raw_feedback=raw,
            unclamped_sum=[a+b for a, b in zip(base, raw, strict=True)],
            final_command=[c["final_canonical_target_velocity_rad_s"] for c in command],
            observed_joint_velocity=velocities[joint_slice])
        projected = {name: project(jacobian, value) for name, value in joint_stages.items()}
        require(all(abs(projected["unclamped_sum"][j]-projected["baseline"][j]
            -projected["raw_feedback"][j]) < 1e-12 for j in range(2)), "Projection linearity")
        legs.append(dict(limb_id=leg["id"], support=feedback["support"],
            requested_body_motion_xy_m_s=requested, projected_xy_m_s=projected,
            body_motion_discrepancy_m_s={name: math.dist(value, requested) for name, value in projected.items()},
            vertical_discrepancy_m_s={name: abs(value[1]-requested[1]) for name, value in projected.items()},
            baseline_opposes_requested_vertical=projected["baseline"][1]*requested[1] < 0.,
            final_opposes_requested_vertical=projected["final_command"][1]*requested[1] < 0.,
            absolute_clamped_commands=sum(c["absolute_correction_clamped"] for c in command),
            slew_clamped_commands=sum(c["slew_clamped"] for c in command),
            final_speed_clamped_commands=sum(c["final_speed_clamped"] for c in command),
            ground_below_geometric_minimum=witness["ground_below_geometric_minimum"],
            minimum_capsule_clearance_m=witness["minimum_clearance_m"],
            normal_load_available=witness["normal_load_available"]))
    require(all(not leg["normal_load_available"] for leg in legs), "Unexpected measured normal load")
    return dict(outer_step=step, time_s=step/120, support_count=sum(l["support"] for l in legs),
        body_pose=state["base_pose_world"], body_twist=state["base_twist_world"],
        maximum_native_endpoint_error_m=reach["maximum_native_endpoint_error_m"], legs=legs)


def summarize_frames(frames):
    supported = [leg for frame in frames for leg in frame["legs"] if leg["support"]]
    require(bool(supported), "No supported observations in composition prefix")
    count = len(supported)
    return dict(supported_leg_observations=count,
        baseline_opposes_requested_vertical=sum(l["baseline_opposes_requested_vertical"] for l in supported),
        final_opposes_requested_vertical=sum(l["final_opposes_requested_vertical"] for l in supported),
        mean_requested_body_motion_xy_m_s=[sum(l["requested_body_motion_xy_m_s"][i] for l in supported)/count for i in range(2)],
        mean_projected_xy_m_s={stage: [sum(l["projected_xy_m_s"][stage][i] for l in supported)/count
            for i in range(2)] for stage in STAGES},
        mean_body_motion_discrepancy_m_s={stage: sum(l["body_motion_discrepancy_m_s"][stage] for l in supported)/count
            for stage in STAGES},
        mean_vertical_discrepancy_m_s={stage: sum(l["vertical_discrepancy_m_s"][stage] for l in supported)/count
            for stage in STAGES},
        support_count_histogram=dict(sorted(Counter(f["support_count"] for f in frames).items())),
        ground_below_geometric_minimum_rows={name: sum(l["ground_below_geometric_minimum"]
            for f in frames for l in f["legs"] if l["limb_id"] == name) for name in geometry.LEGS},
        supported_command_clamps={name: sum(l[name] for l in supported)
            for name in ["absolute_clamped_commands", "slew_clamped_commands", "final_speed_clamped_commands"]},
        maximum_native_endpoint_error_m=max(f["maximum_native_endpoint_error_m"] for f in frames))


def check_trials(parent):
    outcomes = parent["finite_outcomes"]
    require((outcomes["eligible"], outcomes["negative"], outcomes["denominator"]) == (1, 11, 12)
        and len(outcomes["trials"]) == 12 and outcomes["repertoire"]["ranked_role_indices"] == [],
        "Composition complete source population")
    selected = [t for t in outcomes["trials"] if t["role"] == "height_immediate"]
    require([t["start_id"] for t in selected] == STARTS
        and [t["outcome"] for t in selected] == ["positive", "negative", "negative", "negative"],
        "Composition complete immediate population")
    for trial in selected:
        first = trial["native_metrics"]["first_physical_violation"]
        require(first is None or first["internal_step"] > PREFIX*5, "Composition prefix crosses first violation")
    return selected


def analyze(evidence_root):
    require(sha(PARENT) == PARENT_SHA, "Composition parent closure changed")
    parent = read(PARENT)
    selected = check_trials(parent)
    physical = evidence_root / parent["attempt_id"] / "physical"
    model_root = physical / "models/left_075"
    model = height.definition()
    height.validate_geometry(read(model_root/"compiled.json"), model)
    reach_model, joints, sites = geometry_inputs(model_root)
    artifacts = {a["evidence_relative_path"]: a for a in parent["artifacts"]}
    paths = [model_root/name for name in ["compiled.json", "model.xml", "inputs.json", "native-model.json"]]
    trials = []
    for trial in selected:
        folder = physical / trial["trial_id"]
        paths.extend([folder/"controller.jsonl", folder/"trace.jsonl"])
        rows = list(read_jsonl(folder/"controller.jsonl"))
        trace = list(read_jsonl(folder/"trace.jsonl"))
        require(len(rows) == 1440 and len(trace) == 7200
            and [r["outer_step"] for r in rows] == list(range(1440))
            and [r["step"] for r in trace] == list(range(1, 7201)), "Composition raw population/order")
        frames = [describe_frame(row, model, reach_model, joints, sites) for row in rows[:PREFIX]]
        prefix_trace = trace[:PREFIX*5]
        require(all(len(t["actuator_force_nm"]) == len(t["on_force_cap"]) == 8 for t in prefix_trace),
            "Composition actuator denominator")
        trials.append(dict(trial_id=trial["trial_id"], start_id=trial["start_id"],
            original_outcome=trial["outcome"], first_physical_violation=trial["native_metrics"]["first_physical_violation"],
            **summarize_frames(frames),
            actuator_torques=dict(measurement_stage="completed_substep", sample_count=PREFIX*5,
                mean_absolute_nm=[sum(abs(t["actuator_force_nm"][i]) for t in prefix_trace)/(PREFIX*5) for i in range(8)],
                force_cap_samples=[sum(t["on_force_cap"][i] for t in prefix_trace) for i in range(8)]),
            snapshots=[frames[i] for i in SNAPSHOTS]))
    bindings = []
    for path in paths:
        rel = path.relative_to(evidence_root).as_posix()
        entry = dict(evidence_relative_path=rel, byte_length=path.stat().st_size, sha256=sha(path))
        require(entry == artifacts[rel], "Composition original input changed")
        bindings.append(entry)
    implementation = [Path(__file__), ROOT/"sdk/discovery/support_reach_diagnostic.py",
        ROOT/"sdk/adaptation_provider/body_height_feedback_v1.py", ROOT/"sdk/adaptation_provider/stance_feedback_v1.py"]
    return dict(schema_version="locolemotion_height_composition_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu", authority_mode="retained_evidence_diagnostic",
            question_class="development"),
        parent_closure=dict(path=PARENT.relative_to(ROOT).as_posix(), sha256=PARENT_SHA),
        original_source_commit=parent["source_commit"], source_attempt=parent["attempt_id"],
        implementation_bindings=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p)) for p in implementation],
        post_hoc=True, prefix_chosen_after_outcome=True, source_trial_count=12, analyzed_immediate_trial_count=4,
        source_eligible=1, source_negative=11, common_prefix_outer_rows=PREFIX, common_prefix_duration_s=1.,
        controller_rows_analyzed=4*PREFIX, completed_internal_samples_analyzed=4*PREFIX*5,
        leg_evaluations=4*PREFIX*4, all_sampled_before_first_physical_violation=True,
        baseline_and_delayed_roles_excluded_from_common_prefix=True,
        projected_velocity_frame="foot_center_relative_to_fixed_torso_canonical_xy",
        requested_motion_excludes_baseline_gait_objective=True,
        discrepancy_is_campaign_tracking_quality=False, normal_contact_forces_retained=False,
        actuator_torques_are_contact_forces=False, vertical_opposition_zero_tolerance=0.,
        world_build_count=0, solver_steps=0, original_repertoire=parent["finite_outcomes"]["repertoire"],
        trials=trials, source_artifacts=bindings, **AUTHORITY)


def verify_record(path, evidence_root, core, baseline):
    verify_parent(PARENT, evidence_root, core, baseline)
    computed = analyze(evidence_root)
    require(read(path) == json.loads(json.dumps(computed, allow_nan=False)), "Composition diagnostic record changed")
    return dict(ok=True, world_build_count=0, solver_steps=0, controller_rows=480, internal_samples=2400,
        leg_evaluations=1920, source_trial_count=12,
        supported_leg_observations=[t["supported_leg_observations"] for t in computed["trials"]], **AUTHORITY)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, default=Path(__file__).with_name("height_composition_diagnostic_v1.json"))
    parser.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.write:
        verify_parent(PARENT, args.evidence_root, args.core, args.baseline_core)
        result = analyze(args.evidence_root)
        with args.record.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(result, stream, indent=2, allow_nan=False)
            stream.write("\n")
        print(json.dumps(dict(ok=True, record=str(args.record), world_build_count=0, leg_evaluations=result["leg_evaluations"])))
    else:
        print(json.dumps(verify_record(args.record, args.evidence_root, args.core, args.baseline_core)))
