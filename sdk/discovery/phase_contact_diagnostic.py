"""Post-hoc phase/contact and command-response diagnosis of all sixteen trials.

The common interval was chosen after observing outcomes. Scheduled stance is
controller intent, not evidence of support. End-of-command velocity is measured
after all five held-control substeps; it is not a counterfactual response.
"""
import argparse
from collections import Counter
from itertools import islice
import json
import math
from pathlib import Path

from adaptation_provider import support_vertical_feedback_v1 as feedback
from adaptation_provider import stance_feedback_v1 as geometry
from audit_cpu_support_vertical_closure import verify_record as verify_parent, read
from audit_gpu_batch_execution import read_jsonl, same_bits
from cpu_support_vertical_task import ROOT, sha, require
from support_vertical_control import ROLES
from support_reach_diagnostic import geometry_inputs, frame as reach_frame
from height_composition_diagnostic import project

PARENT = ROOT / "sdk/discovery/cpu_support_vertical_closure_v1.json"
PARENT_SHA = "e094dfadc2178da94c17b69696a6ac776871cbe48900f4d7edd93bc4eb2253db"
PREFIX = 96
STARTS = ["train_001", "train_003", "train_004", "train_006"]
PHASE_ORDER = ["rear_left", "front_left", "rear_right", "front_right"]
CYCLE, SWING = 360, 72
STRATA = ["stance_support", "stance_missing", "swing_support", "swing_missing"]
SNAPSHOTS = [0, 16, 48, 71, 72, 90, 95]
AUTHORITY = dict(physical_acceptance_authority=False, release_authority=False,
    training_data_authority=False, selection_authority=False, causal_authority=False,
    population_inference=False, counterfactual_performance_authority=False)


def phase(gait_step, limb):
    require(type(gait_step) is int and gait_step >= 0 and limb in PHASE_ORDER,
        "Phase input domain")
    local = (gait_step + CYCLE - PHASE_ORDER.index(limb)*(CYCLE//4)) % CYCLE
    return local, "swing" if local < SWING else "stance"


def check_trials(parent):
    outcomes = parent["finite_outcomes"]
    trials = outcomes["trials"]
    expected = [(s, r["id"]) for s in STARTS for r in ROLES]
    require((outcomes["eligible"], outcomes["negative"], outcomes["denominator"]) == (2, 14, 16)
        and [(t["start_id"], t["role"]) for t in trials] == expected
        and outcomes["repertoire"]["ranked_role_indices"] == [], "Phase complete source population")
    for i, trial in enumerate(trials):
        require(trial["trial_id"] == "left_075_"+trial["start_id"]+"_"+trial["role"]
            and trial["outcome"] == ("positive" if i in (1, 2) else "negative"),
            "Phase source identity/outcome")
        first = trial["native_metrics"]["first_physical_violation"]
        require(first is None or first["internal_step"] > PREFIX*5,
            "Phase prefix crosses first violation")
    return trials


def describe_frame(row, samples, model, reach_model, joints, sites):
    step, state = row["outer_step"], row["request"]["state"]
    require(type(step) is int and 0 <= step < PREFIX and state["semantic_step"] == step,
        "Phase controller clock")
    require(len(samples) == 5 and [t["step"] for t in samples] == list(range(step*5+1, step*5+6)),
        "Phase five-substep order")
    native = row["native_observation"]
    require(native["sampling_stage"] == "prepared_before_control"
        and samples[0]["before_qvel"] == native["qvel"]
        and samples[0]["before_qpos"] == native["qpos"], "Phase prepared observation join")
    for i, sample in enumerate(samples):
        require(same_bits(sample["ctrl"], row["native_targets"]), "Phase held command join")
        require(len(sample["qvel"]) == 14 and all(math.isfinite(x) for x in sample["qvel"])
            and len(sample["on_force_cap"]) == 8 and all(type(v) is bool for v in sample["on_force_cap"]),
            "Phase native response domain")
        if i:
            require(sample["before_qvel"] == samples[i-1]["qvel"]
                and sample["before_qpos"] == samples[i-1]["qpos"], "Phase substep continuity")
    provider = row["resolution_request"]["provider_request"]
    memory = row["output"]["next_memory"]
    require(provider["controller_context"]["controller_memory"] == memory
        and memory["phase_progression_mode"] == "clocked" and memory["last_semantic_step"] == step
        and [l["limb_id"] for l in memory["ordered_limb_memory"]] == PHASE_ORDER,
        "Phase actual provider memory join")
    receipt = row["output"]["actuation"]["receipt"]
    require(receipt["policy_id"] == "sporespore_balanced_wave_bw15f_b_v1"
        and receipt["semantic_step"] == step, "Phase actual policy/clock")
    measured_phase = receipt["forward_velocity_foot_placement"]["ordered_limb_corrections"]
    require([p["limb_id"] for p in measured_phase] == geometry.LEGS, "Phase receipt order")
    gait_steps = {m["limb_id"]: m["gait_step"] for m in memory["ordered_limb_memory"]}
    observations = state["ordered_joint_observations"]
    contacts = state["ordered_contact_observations"]
    commands = row["resolution"]["ordered_commands"]
    require([j["joint_id"] for j in observations] == geometry.JOINTS
        and all(j["validity"]["position"] and j["validity"]["velocity"] for j in observations)
        and [c["actuator_id"] for c in commands] == [j+"_motor" for j in geometry.JOINTS]
        and [c["contact_site_id"] for c in contacts] == [l+"_foot" for l in geometry.LEGS],
        "Phase joint/contact/command order")
    before = [j["velocity_rad_s"] for j in observations]
    final = [c["final_canonical_target_velocity_rad_s"] for c in commands]
    require(same_bits(before, native["qvel"][6:]) and same_bits(final, row["native_targets"])
        and row["composition"]["host_mapping"]["canonical_to_host_velocity_sign"] == 1.,
        "Phase canonical/native velocity join")
    require(all(c["normal_load_n"] is None for c in contacts), "Phase unavailable contact load")
    candidate = model["candidates"][row["activation_probe"]["candidate_index"]]
    if row["feedback"]["status"] == "supported":
        delta, detail = feedback.feedback(state, row["request"]["command"], candidate, model,
            provider["deterministic_baseline"])
        require(same_bits(detail, row["feedback"]), "Phase feedback replay differs")
    else:
        require(row["feedback"] == {"status": "baseline"}, "Phase unexpected feedback refusal")
        delta, detail = [0.]*8, None
    require(same_bits(delta, [c["proposed_correction_rad_s"] for c in commands]),
        "Phase raw correction join")
    reach = reach_frame(row, reach_model, joints, sites)
    legs = []
    for i, (leg, contact, phase_receipt, witness) in enumerate(zip(model["legs"], contacts,
            measured_phase, reach["legs"], strict=True)):
        local, scheduled = phase(gait_steps[leg["id"]], leg["id"])
        require(gait_steps[leg["id"]] == step and local == phase_receipt["local_phase_step"],
            "Phase receipt/memory mismatch")
        require(type(contact["presence"]) is bool and type(contact["bears_support"]) is bool,
            "Phase contact domain")
        supported = contact["presence"] and contact["bears_support"]
        sl = slice(2*i, 2*i+2)
        cs = commands[sl]
        angles = [j["position_rad"] for j in observations[sl]]
        _, jacobian = geometry.foot_geometry(leg, *angles)
        raw, applied = delta[sl], [c["applied_correction_rad_s"] for c in cs]
        velocity_stages = dict(baseline=[c["baseline_canonical_target_velocity_rad_s"] for c in cs],
            raw_correction=raw, applied_correction=applied, final_command=final[sl],
            observed_before=before[sl], observed_after=samples[-1]["qvel"][6+2*i:8+2*i])
        error = [v-u for v, u in zip(velocity_stages["observed_after"], final[sl], strict=True)]
        projected = {k: project(jacobian, v) for k, v in velocity_stages.items()}
        compensation = detail["legs"][i].get("vertical_compensation_delta_rad_s") if detail else None
        legs.append(dict(limb_id=leg["id"], local_phase_step=local, scheduled_phase=scheduled,
            contact_presence=contact["presence"], observed_support=supported,
            stratum=scheduled+("_support" if supported else "_missing"),
            ground_below_geometric_minimum=witness["ground_below_geometric_minimum"],
            minimum_capsule_clearance_m=witness["minimum_clearance_m"],
            actual_capsule_clearance_m=witness["actual_capsule_clearance_m"],
            joint_velocity_rad_s=velocity_stages, end_of_command_error_rad_s=error,
            projected_at_start_jacobian_xy_m_s=projected,
            vertical_compensation_active=compensation is not None and any(v != 0. for v in compensation),
            no_support_nonzero_applied=(not supported and any(v != 0. for v in applied)),
            raw_applied_opposing_commands=sum(a*b < 0. for a, b in zip(raw, applied)),
            absolute_clamped_commands=sum(c["absolute_correction_clamped"] for c in cs),
            slew_clamped_commands=sum(c["slew_clamped"] for c in cs),
            final_speed_clamped_commands=sum(c["final_speed_clamped"] for c in cs),
            force_cap_samples=[sum(t["on_force_cap"][j] for t in samples) for j in range(2*i, 2*i+2)]))
    return dict(outer_step=step, time_s=step/120., legs=legs,
        scheduled_transfer_active=row["composition"]["scheduled_load_transfer"]["active"],
        scheduled_transfer_outcome=row["composition"]["scheduled_load_transfer"]["planning_outcome_code"],
        maximum_native_endpoint_error_m=reach["maximum_native_endpoint_error_m"])


def longest_missing_stance(rows):
    longest = current = 0
    for row in rows:
        current = current+1 if row["stratum"] == "stance_missing" else 0
        longest = max(longest, current)
    return longest


def aggregate(rows):
    n = len(rows)
    return dict(leg_observations=n, joint_commands=2*n, internal_joint_samples=10*n,
        mean_absolute_end_error_rad_s=(sum(abs(v) for r in rows for v in r["end_of_command_error_rad_s"])/(2*n) if n else None),
        rms_end_error_rad_s=(math.sqrt(sum(v*v for r in rows for v in r["end_of_command_error_rad_s"])/(2*n)) if n else None),
        force_cap_samples=sum(sum(r["force_cap_samples"]) for r in rows),
        ground_below_geometric_minimum=sum(r["ground_below_geometric_minimum"] for r in rows),
        vertical_compensation_active=sum(r["vertical_compensation_active"] for r in rows),
        no_support_nonzero_applied=sum(r["no_support_nonzero_applied"] for r in rows),
        **{k: sum(r[k] for r in rows) for k in ["raw_applied_opposing_commands", "absolute_clamped_commands",
            "slew_clamped_commands", "final_speed_clamped_commands"]})


def summarize(frames):
    rows = [r for f in frames for r in f["legs"]]
    return dict(**aggregate(rows),
        by_phase_contact={s: aggregate([r for r in rows if r["stratum"] == s]) for s in STRATA},
        by_limb=[dict(limb_id=name,
            phase_contact_counts={s: sum(r["stratum"] == s for r in rows if r["limb_id"] == name) for s in STRATA},
            longest_missing_stance_commands=longest_missing_stance([r for r in rows if r["limb_id"] == name]),
            **aggregate([r for r in rows if r["limb_id"] == name])) for name in geometry.LEGS],
        scheduled_transfer_active_commands=sum(f["scheduled_transfer_active"] for f in frames),
        scheduled_transfer_outcomes=dict(sorted(Counter(f["scheduled_transfer_outcome"] for f in frames).items())),
        maximum_native_endpoint_error_m=max(f["maximum_native_endpoint_error_m"] for f in frames))


def analyze(evidence_root):
    require(sha(PARENT) == PARENT_SHA, "Phase parent closure changed")
    parent = read(PARENT)
    selected = check_trials(parent)
    physical = evidence_root/parent["attempt_id"]/"physical"
    model_root = physical/"models/left_075"
    artifacts = {a["evidence_relative_path"]: a for a in parent["artifacts"]}
    paths = [model_root/name for name in ["compiled.json", "model.xml", "inputs.json", "native-model.json"]]
    paths += [physical/t["trial_id"]/name for t in selected for name in ["controller.jsonl", "trace.jsonl"]]
    bindings = []
    for path in paths:
        rel = path.relative_to(evidence_root).as_posix()
        entry = dict(evidence_relative_path=rel, byte_length=path.stat().st_size, sha256=sha(path))
        require(entry == artifacts[rel], "Phase original input changed")
        bindings.append(entry)
    model = feedback.definition()
    feedback.validate_geometry(read(model_root/"compiled.json"), model)
    reach_geometry = geometry_inputs(model_root)
    trials = []
    for trial in selected:
        folder = physical/trial["trial_id"]
        rows = list(islice(read_jsonl(folder/"controller.jsonl"), PREFIX))
        trace = list(islice(read_jsonl(folder/"trace.jsonl"), PREFIX*5))
        require(len(rows) == PREFIX and len(trace) == PREFIX*5
            and [r["outer_step"] for r in rows] == list(range(PREFIX))
            and [t["step"] for t in trace] == list(range(1, PREFIX*5+1)), "Phase raw prefix order/count")
        frames = [describe_frame(row, trace[i*5:i*5+5], model, *reach_geometry) for i, row in enumerate(rows)]
        trials.append(dict(trial_id=trial["trial_id"], start_id=trial["start_id"], role=trial["role"],
            original_outcome=trial["outcome"], first_physical_violation=trial["native_metrics"]["first_physical_violation"],
            **summarize(frames), snapshots=[frames[i] for i in SNAPSHOTS]))
    implementation = [Path(__file__), ROOT/"sdk/core/src/runtime.rs", ROOT/"sdk/discovery/support_reach_diagnostic.py",
        ROOT/"sdk/discovery/height_composition_diagnostic.py", ROOT/"sdk/adaptation_provider/support_vertical_feedback_v1.py",
        ROOT/"sdk/adaptation_provider/support_vertical_feedback_v1.json", ROOT/"sdk/adaptation_provider/stance_feedback_v1.py"]
    return dict(schema_version="locolemotion_phase_contact_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu", authority_mode="retained_evidence_diagnostic",
            question_class="development"),
        parent_closure=dict(path=PARENT.relative_to(ROOT).as_posix(), sha256=PARENT_SHA),
        original_source_commit=parent["source_commit"], source_attempt=parent["attempt_id"],
        implementation_bindings=[dict(path=p.relative_to(ROOT).as_posix(), sha256=sha(p)) for p in implementation],
        post_hoc=True, prefix_chosen_after_outcome=True, source_trial_count=16, analyzed_trial_count=16,
        source_eligible=2, source_negative=14, common_prefix_outer_rows=PREFIX, common_prefix_duration_s=.8,
        controller_rows_analyzed=16*PREFIX, completed_internal_samples_analyzed=16*PREFIX*5,
        leg_evaluations=16*PREFIX*4, joint_command_response_pairs=16*PREFIX*8,
        all_sampled_before_first_physical_violation=True, roles_or_starts_excluded=False,
        phase_source="actual_actuation_receipt_joined_to_output_and_provider_context_memory",
        phase_rule=dict(cycle_steps=CYCLE, swing_steps=SWING, ordered_limb_ids=PHASE_ORDER),
        contact_observation_stage="prepared_before_control", response_observation_stage="after_five_held_control_substeps",
        projected_after_velocity_uses_start_jacobian=True, scheduled_stance_is_measured_support=False,
        joint_response_error_is_campaign_tracking_quality=False, normal_contact_forces_retained=False,
        actuator_force_caps_are_ground_reaction_forces=False,
        world_build_count=0, solver_steps=0, original_repertoire=parent["finite_outcomes"]["repertoire"],
        trials=trials, source_artifacts=bindings, **AUTHORITY)


def verify_record(path, evidence_root, core, baseline):
    verify_parent(PARENT, evidence_root, core, baseline)
    computed = analyze(evidence_root)
    require(read(path) == json.loads(json.dumps(computed, allow_nan=False)), "Phase diagnostic record changed")
    return dict(ok=True, world_build_count=0, solver_steps=0, source_trial_count=16,
        controller_rows=1536, internal_samples=7680, leg_evaluations=6144, joint_command_response_pairs=12288,
        **AUTHORITY)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, default=Path(__file__).with_name("phase_contact_diagnostic_v1.json"))
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
