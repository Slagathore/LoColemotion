"""Independent baseline, applied-provider, native trajectory, and influence replay."""
import argparse
import json
import math
from pathlib import Path
import random
import statistics
import struct
from unittest.mock import patch

import mujoco

from gpu_quadruped_model import FLAGS, sha, f32
from gpu_retrieval_influence import declaration, trial_plan
from retrieval_shadow_control import learner, load_candidate
from portable_search_control import Controller, bridge, map_resolution
from retrieval_influence_accounting import window_quality, comparisons
from audit_gpu_portable_search import require, validate_observation, validate_resolution

SECTIONS = ["prepare_s", "observation_readback_s", "portable_control_s",
            "controller_capture_and_control_transfer_s", "integration_and_device_history_s",
            "internal_readback_and_capture_s"]


def same_bits(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, float):
        return math.isfinite(left) and struct.pack("<d", left) == struct.pack("<d", right)
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(same_bits(left[key], right[key]) for key in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(same_bits(a, b) for a, b in zip(left, right, strict=True))
    return left == right


def finite_vector(value, length):
    return (isinstance(value, list) and len(value) == length
            and all(type(x) in (int, float) and math.isfinite(x) for x in value))


def timing_summary(rows, c):
    require(len(rows) == c["outer_steps"], "Timing denominator")
    result = {part: {name: 0. for name in [*SECTIONS, "outer_total_s"]} for part in ["warmup", "measured"]}
    for index, row in enumerate(rows):
        require(set(row) == {"outer_step", "measured", *SECTIONS, "outer_total_s"}, "Timing fields")
        require(row["outer_step"] == index and row["measured"] is (index >= c["warmup_outer_steps"]), "Timing order or partition")
        values = [row[name] for name in [*SECTIONS, "outer_total_s"]]
        require(all(type(x) in (int, float) and math.isfinite(x) and x >= 0 for x in values)
                and row["outer_total_s"] > 0, "Nonfinite or invalid timing")
        require(sum(row[name] for name in SECTIONS) <= row["outer_total_s"] + 1e-9, "Sections exceed outer time")
        part = "measured" if row["measured"] else "warmup"
        for name in result[part]:
            result[part][name] += row[name]
    return result


def read_jsonl(path):
    with path.open(encoding="utf-8") as stream:
        for line in stream:
            yield json.loads(line)


def verify_influence(row, model, core, memory, previous, stats):
    """Replay separately from the host, including current-input baseline mapping."""
    mode = row["mode"]
    require(row["operation"] is None and row["commands_applied_to_physics"] is True
        and row["outcome_credit"] == "actual_applied_action_sequence", "Influence authority/operation")
    if mode == "baseline":
        require(row["provider_error"] is None and all(same_bits(row[key], row["baseline_"+key])
            for key in ["resolution_request", "resolution", "native_targets"]), "Absent baseline changed")
        response = None
        resolved = row["resolution"]
    else:
        request = learner.bind_request(core, row["baseline_resolution_request"]["provider_request"], model, mode)
        request["provider_memory"] = memory
        step = request["state"]["semantic_step"]
        request["request_id"] = "retrieval_influence_" + mode + "_step_" + str(step)
        for limit, prior in zip(request["safety_envelope"]["ordered_actuator_limits"], previous, strict=True):
            limit["previous_applied_correction_rad_s"] = prior
        call = learner.call_provider(core, request, model, mode)
        expected_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=call["provider_response"])
        require(same_bits(row["resolution_request"], expected_request)
            and same_bits(row["provider_error"], call["provider_error"]), "Influence request/decision replay differs")
        resolved = core.resolve_adaptation_v1(expected_request)
        require(same_bits(row["resolution"], resolved), "Influence resolution/memory replay differs")
        response = call["provider_response"]
        bases = request["deterministic_baseline"]["ordered_commands"]
        limits = request["safety_envelope"]["ordered_actuator_limits"]
        for i, (base, limit, command) in enumerate(zip(bases, limits, resolved["ordered_commands"], strict=True)):
            require(limit["previous_applied_correction_rad_s"] == previous[i]
                and limit["maximum_absolute_correction_rad_s"] == .25
                and limit["maximum_slew_per_step_rad_s"] == .02, "Influence correction history/bounds")
            if resolved["adaptation_applied"]:
                proposed = response["ordered_corrections"][i]["canonical_velocity_delta_rad_s"]
                bounded = max(-.25, min(.25, proposed))
                correction = max(-.25, min(.25, max(previous[i]-.02, min(previous[i]+.02, bounded))))
            else:
                correction = 0.
            final = max(-base["maximum_target_speed_rad_s"], min(base["maximum_target_speed_rad_s"],
                base["combined_canonical_target_velocity_rad_s"] + correction))
            require(command["applied_correction_rad_s"] == correction
                and command["final_canonical_target_velocity_rad_s"] == final, "Influence independent clamp arithmetic")
            if not resolved["adaptation_applied"]:
                require(same_bits(final, base["combined_canonical_target_velocity_rad_s"]), "Influence fallback changed baseline")
        # Same-observation comparison isolates a decision change due to memory;
        # it is not a claim about a hypothetical alternative trajectory.
        active = resolved["next_memory"]["opaque_state"].get("active")
        if active is not None and active["start_step"] == step:
            stats["new_action_selections"] += 1
            predictions = model.predictions(learner.cue(request, model.plan()))
            require(0 in predictions, "Selected action without baseline support")
            chosen = min(predictions, key=lambda a: (-predictions[a]["quality_m_s"], a))
            if predictions[chosen]["quality_m_s"] < predictions[0]["quality_m_s"] + model.plan()["minimum_predicted_gain_m_s"]:
                chosen = 0
            stats["same_input_choices_changed_by_memory"] += int(active["action"] != chosen)
    require(resolved["world_build_count"] == 0 and resolved["physics_state_modified"] is False
        and resolved["physical_acceptance_authority"] is False, "Influence resolver authority")
    require(same_bits(row["native_targets"], map_resolution(row["composition"]["host_mapping"], resolved)), "Native influence mapping")
    stats["rows"] += 1
    stats["provider_errors"] += int(row["provider_error"] is not None)
    stats["unexpected_fallbacks"] += int(resolved["fallback_reason"] not in [
        "none", "provider_absent" if mode == "baseline" else "provider_no_proposal", "provider_unsupported", "safe_no_actuation"])
    stats["resolved_nonzero_rows"] += int(any(r["applied_correction_rad_s"] != 0. for r in resolved["ordered_commands"]))
    status = "absent" if mode == "baseline" else ("error" if response is None else response["status"])
    stats["statuses"][status] = stats["statuses"].get(status, 0) + 1
    return resolved["next_memory"]


def audit_trial(folder, plan, c, spec, compiled, metadata, core):
    candidate = learner.FrozenModel.load(core, json.loads((folder.parent / "retrieval-model.json").read_text()))
    memories = [learner.empty_memory(core, plan=candidate.plan()) for _ in plan["mode_order"]]
    provider_stats = {mode: dict(rows=0, provider_errors=0, unexpected_fallbacks=0, resolved_nonzero_rows=0, statuses={}, new_action_selections=0, same_input_choices_changed_by_memory=0) for mode in plan["mode_order"]}
    nworld = plan["nworld"]
    count = c["outer_steps"]
    result = json.loads((folder / "result.json").read_text())
    require(json.loads((folder / "plan.json").read_text()) == plan, "Trial plan changed")
    require(all(result[key] == value for key, value in plan.items()) and result["completed"] is True, "Incomplete/crossed trial")
    for name in ["controller", "trace", "timing"]:
        require(sha(folder / (name + ".jsonl")) == result["hashes"][name], "Trial raw digest")
    require(result["outer_rows"] == nworld * count and result["internal_rows"] == nworld * count * 5, "Worker trial denominator")
    require(all(type(result[k]) in (int, float) and math.isfinite(result[k]) and result[k] >= 0 for k in ["setup_s", "graph_capture_s"]), "Trial setup timing")
    require((result["graph_capture_s"] == 0) == (plan["arm"] == "scalar_direct"), "Graph mode timing")
    controls = {}
    metrics = [dict(minimum_height_m=math.inf, maximum_tilt_rad=0., torso_contact_steps=0,
                    ground_contact_steps=0, nonzero_force_steps=0,
                    safe_no_actuation_steps=0, forward_displacement_m=0.) for _ in range(nworld)]
    controllers = []
    previous = [[0.] * 8 for _ in range(nworld)]
    try:
        controllers = [Controller(core, compiled, dict(c, seed=plan["seed"]), i) for i in plan["candidate_indices"]]
        for index, row in enumerate(read_jsonl(folder / "controller.jsonl")):
            outer, cell = divmod(index, nworld)
            require(outer < count and (row["backend"], row["cell"], row["outer_step"]) == ("gpu", cell, outer), "Controller order/denominator")
            native = row["native_observation"]
            copy = native["contact_compatibility_copy"]
            require(copy["schema_version"] == "locolemotion_gpu_contact_compatibility_copy_v1"
                    and copy["unstepped_host_copy_only"] is True
                    and copy["legacy_geometry_after"] == copy["native_geometry"] == [r["geom"] for r in native["contacts"]]
                    and len(copy["legacy_geometry_before"]) == len(native["contacts"]), "Contact compatibility copy")
            validate_observation(row, metadata, compiled)
            expected = controllers[cell].step(row["request"]["state"], row["stability"], row["kinematics"])
            require(all(same_bits(value, row["baseline_"+key] if key in ["resolution_request", "resolution", "native_targets"] else row[key])
                for key, value in expected.items()), "Scalar baseline decision/memory replay differs")
            baseline_row = dict(row, **{key: row["baseline_"+key] for key in ["resolution_request", "resolution", "native_targets"]})
            validate_resolution(baseline_row, dict(c, seed=plan["seed"]), 0, [0.]*8)
            mode = plan["mode_order"][cell]
            require(row["mode"] == mode, "Influence mode order")
            memories[cell] = verify_influence(row, candidate, core, memories[cell], previous[cell], provider_stats[mode])
            previous[cell] = [r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
            metrics[cell]["safe_no_actuation_steps"] += int(row["output"]["actuation"]["safe_no_actuation"])
            controls[outer, cell] = row
    finally:
        for controller in controllers:
            controller.close()
    require(len(controls) == count * nworld, "Missing controller row")
    initial_velocity = f32(plan["initial_native_lateral_velocity_m_s"])
    initial_vel = [0., initial_velocity] + [0.] * 12
    initial_pos = list(map(f32, spec["initial_qpos"]))
    caps = [[f32(x) for x in pair] for pair in spec["force_ranges"]]
    prior = [None] * nworld
    positions = [[[f32(spec["initial_qpos"][0]), -f32(spec["initial_qpos"][1])]] for _ in range(nworld)]
    slots = []
    batch_count = None
    eps = 2**-23
    rows_read = 0
    maximum_force_error = 0.
    for index, row in enumerate(read_jsonl(folder / "trace.jsonl")):
        step, cell = divmod(index, nworld)
        step += 1
        require(step <= count * 5 and (row["backend"], row["cell"], row["step"]) == ("gpu", cell, step), "Internal order/denominator")
        for name, length in [("qpos", 15), ("before_qpos", 15), ("qvel", 14), ("before_qvel", 14),
                             ("ctrl", 8), ("actuator_force_nm", 8), ("joint_force_nm", 8)]:
            require(finite_vector(row[name], length), "Nonfinite/incomplete native vector")
        last = prior[cell]
        require(row["before_qpos"] == (last["qpos"] if last else initial_pos)
                and row["before_qvel"] == (last["qvel"] if last else initial_vel), "Native state continuity")
        control = controls[(step - 1) // 5, cell]
        require(same_bits(row["ctrl"], list(map(f32, control["native_targets"]))), "Held solver input differs")
        if (step - 1) % 5 == 0:
            require(row["before_qpos"] == control["native_observation"]["qpos"]
                    and row["before_qvel"] == control["native_observation"]["qvel"], "Prepared observation clock")
            require(math.isfinite(control["native_observation"]["time_s"])
                    and abs(control["native_observation"]["time_s"] - (step - 1) * c["timestep_s"]) <= 4 * eps * step * step * c["timestep_s"], "Readback time")
        require(math.isfinite(row["time_s"]) and abs(row["time_s"] - step * c["timestep_s"]) <= 4 * eps * step * step * c["timestep_s"], "Internal clock")
        require(abs(sum(x * x for x in row["qpos"][3:7]) - 1) <= 128 * eps, "Quaternion normalization")
        require(row["warnings"] == [] and type(row["overflow"]) is int and row["overflow"] == 0
                and type(row["nefc"]) is int and 0 <= row["nefc"] <= c["njmax"], "Native capacity/warning")
        require(row["on_force_cap"] == [f <= lo or f >= hi for f, (lo, hi) in zip(row["actuator_force_nm"], caps, strict=True)], "Force clamp label")
        for force, joint, (lo, hi) in zip(row["actuator_force_nm"], row["joint_force_nm"], caps, strict=True):
            require(lo - 32 * eps * abs(lo) <= force <= hi + 32 * eps * abs(hi)
                    and abs(force - joint) <= 32 * eps * max(abs(lo), abs(hi)), "Force cap/named sensor mismatch")
            maximum_force_error = max(maximum_force_error, abs(force - joint))
        require(type(row["batch_contacts"]) is int and 0 <= row["batch_contacts"] <= nworld * c["naconmax_per_world"], "Global contact capacity")
        if cell == 0:
            slots = []
            batch_count = row["batch_contacts"]
        require(row["batch_contacts"] == batch_count, "Crossed contact counters")
        for contact in row["contacts"]:
            require(type(contact["world"]) is int and contact["world"] == cell
                    and type(contact["native_index"]) is int and 0 <= contact["native_index"] < batch_count, "Contact attribution")
            pair = contact["geom"]
            require(len(pair) == 2 and 0 in pair and pair[0] != pair[1]
                    and all(type(g) is int and 0 <= g < 10 for g in pair), "Contact geometry")
            require(finite_vector(contact["position_m"], 3) and finite_vector(contact["frame"], 9)
                    and math.isfinite(contact["distance_m"]), "Nonfinite contact")
            slots.append(contact["native_index"])
        if cell == nworld - 1:
            require(sorted(slots) == list(range(batch_count)), "Contact global denominator")
        metric = metrics[cell]
        metric["minimum_height_m"] = min(metric["minimum_height_m"], row["qpos"][2])
        tilt = math.acos(max(-1., min(1., 1 - 2 * (row["qpos"][4]**2 + row["qpos"][5]**2))))
        metric["maximum_tilt_rad"] = max(metric["maximum_tilt_rad"], tilt)
        metric["torso_contact_steps"] += int(any(1 in r["geom"] for r in row["contacts"]))
        metric["ground_contact_steps"] += int(bool(row["contacts"]))
        metric["nonzero_force_steps"] += int(any(force != 0. for force in row["actuator_force_nm"]))
        metric["forward_displacement_m"] = row["qpos"][0] - spec["initial_qpos"][0]
        if step % 5 == 0:
            positions[cell].append([row["qpos"][0], -row["qpos"][1]])
        prior[cell] = row
        rows_read += 1
    require(rows_read == nworld * count * 5, "Missing internal rows")
    timings = timing_summary(list(read_jsonl(folder / "timing.jsonl")), c)
    for cell, mode in enumerate(plan["mode_order"]):
        provider_stats[mode]["final_memory"] = memories[cell]
        provider_stats[mode]["completed_feedback_updates"] = memories[cell]["opaque_state"].get("updates", 0)
        provider_stats[mode]["uncredited_active_window"] = memories[cell]["opaque_state"].get("active")
        qualities = window_quality(positions[cell], candidate.plan())
        metrics[cell].update(window_quality_m_s=qualities, mean_window_quality_m_s=math.fsum(qualities)/len(qualities),
            lateral_displacement_m=positions[cell][-1][1]-positions[cell][0][1])
    comparison = comparisons(dict(zip(plan["mode_order"], metrics, strict=True)), provider_stats,
        {mode:[controls[outer,cell] for outer in range(count)] for cell,mode in enumerate(plan["mode_order"])}, c)
    require(learner.digest(core, candidate.document()) == c["model"]["canonical_sha256"], "Base model changed")
    return dict(**plan, metrics=metrics, providers=provider_stats, comparison=comparison, timings=timings, setup_s=result["setup_s"],
                graph_capture_s=result["graph_capture_s"], internal_rows=rows_read,
                controller_rows=len(controls), maximum_force_error_nm=maximum_force_error)


def audit(folder, core_path, baseline_path):
    declared = json.loads((folder.parent / "declaration.json").read_text())
    c = declared["contract"]
    synthetic = declared.get("synthetic", False)
    require(type(synthetic) is bool, "Synthetic identity")
    expected = declaration()
    if synthetic:
        require(30 <= c["outer_steps"] <= 480 and c["outer_steps"] % 30 == 0, "Synthetic horizon")
        expected.update(outer_steps=c["outer_steps"], synthetic=True)
    require(c == expected, "Prospective influence contract changed")
    worker = json.loads((folder / "worker-result.json").read_text())
    require(worker["ok"] is True and worker["synthetic"] is synthetic
            and all(c[k] is False and worker[k] is False for k in FLAGS), "Incomplete worker or changed authority")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Core binding")
    require(sha(folder / "model.xml") == c["model_xml_sha256"], "Model binding")
    metadata = json.loads((folder / "native-model.json").read_text())
    compiled = json.loads((folder / "compiled.json").read_text())
    spec = json.loads((folder / "inputs.json").read_text())
    for name in ["model", "compiled", "inputs"]:
        require(metadata[name + "_sha256"] == sha(folder / (name + (".xml" if name == "model" else ".json"))), "Native input digest")
    require(compiled["descriptor_sha256"] == c["descriptor_sha256"] and compiled["world_build_count"] == 0, "Compiled descriptor")
    require(spec["initial_lateral_velocities"] == [], "Initial condition plan")
    require(metadata["observation_stage"] == "prepared_before_control"
            and metadata["force_stage"] == "completed_step_before_next_prepare", "Sampling stage")
    plans = trial_plan(c)
    require(len(worker["trials"]) == len(plans), "Trial denominator")
    observed = []
    core = bridge.LocomotionCore(baseline_path)
    candidate = load_candidate(core, c)
    require(sha(folder / "retrieval-model.json") == c["model"]["artifact_sha256"]
        and learner.digest(core, json.loads((folder / "retrieval-model.json").read_text())) == candidate.sha256, "Retained model binding")
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Audit world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Audit data")), \
            patch.object(mujoco, "mj_step", side_effect=AssertionError("Audit physics")):
        for plan, result in zip(plans, worker["trials"], strict=True):
            trial_dir = folder / plan["trial_id"]
            require(result == json.loads((trial_dir / "result.json").read_text()), "Worker trial index changed")
            observed.append(audit_trial(trial_dir, plan, c, spec, compiled, metadata, core))
    if not synthetic:
        require(all(metric["ground_contact_steps"] > 0 and metric["nonzero_force_steps"] > 0
                    for row in observed for metric in row["metrics"]), "Native contact/force path not exercised")
    worlds = sum(p["nworld"] for p in plans)
    require(worker["constructed_gpu_worlds"] == worlds and worker["cpu_readback_views"] == worlds
            and worker["stepped_cpu_worlds"] == 0 and worker["controller_sessions_closed"] is True, "World lifecycle denominator")
    groups = [dict(group_id=r["group_id"], **r["comparison"]) for r in observed]
    nonzero = sum(s["resolved_nonzero_rows"] for r in observed for s in r["providers"].values())
    solver_nonzero = sum(len(arm["exposure"]["solver"]["nonzero_outer_steps"])
        for r in observed for arm in r["comparison"]["arms"].values())
    return dict(ok=True, synthetic=synthetic, trials=observed, group_comparisons=groups,
        constructed_gpu_worlds=worlds, internal_rows=worlds * c["outer_steps"] * 5,
        controller_rows=worlds * c["outer_steps"], reader_world_build_count=0,
        resolved_nonzero_rows=nonzero, solver_nonzero_rows=solver_nonzero,
        physical_provider_influence_rows=0 if synthetic else solver_nonzero,
        model_sha256=candidate.sha256, base_model_immutable=True,
        calibration_worlds=worlds if not synthetic else 0, evaluation_worlds=0, training_worlds=0,
        native_influence_evaluated=not synthetic, provider_promotion_authority=False,
        statistical_superiority_authority=False, noninferiority_authority=False,
        **{key: False for key in FLAGS},
        interpretation="Prospective finite native influence comparison. Episode feedback follows actual applied trajectories, with immutable base model. Unequal measured influence withholds matched-influence memory benefit. No held-out generalization, statistical superiority, noninferiority, recoverability or release is established.")



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(audit(args.folder, args.core, args.baseline_core), indent=2))
