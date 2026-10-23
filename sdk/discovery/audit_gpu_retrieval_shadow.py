"""Independent native baseline replay and isolated learned-provider shadow replay."""
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
from gpu_retrieval_shadow import declaration, trial_plan
from retrieval_shadow_control import learner, load_candidate
from portable_search_control import Controller, bridge
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


def verify_shadow(row, model, c, core, memories, stats):
    """Rebuild requests from verified baseline data, then replay pure decisions.

    This reader does not call the shadow host. It checks request transport,
    explicit memory, the declared operation schedule, and clamp arithmetic in
    addition to the core's response resolution.
    """
    modes = c["shadow_modes"]
    require([item["mode"] for item in row["shadow"]] == modes, "Shadow mode order/denominator")
    actual = row["resolution"]
    require(actual["adaptation_applied"] is False
        and all(r["applied_correction_rad_s"] == 0. for r in actual["ordered_commands"]), "Shadow affected physics")
    for mode, item in zip(modes, row["shadow"], strict=True):
        require(set(item) == {"mode", "operation", "provider_error", "resolution_request", "resolution",
                "commands_applied_to_physics", "outcome_credit"}
            and item["commands_applied_to_physics"] is False
            and item["outcome_credit"] == "shadow_only_not_action_effect", "Shadow authority")
        request = learner.bind_request(core, row["resolution_request"]["provider_request"], model, mode)
        request["provider_memory"] = memories[mode]
        step = request["state"]["semantic_step"]
        request["request_id"] = "retrieval_shadow_" + mode + "_step_" + str(step)
        operation = None
        if mode in c["shadow_operation_modes"]:
            operation = next((r["operation"] for r in c["shadow_operations"] if r["outer_step"] == step), None)
        require(item["operation"] == operation, "Shadow operation schedule")
        call = learner.call_provider(core, request, model, mode, operation)
        expected_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=call["provider_response"])
        require(same_bits(item["resolution_request"], expected_request)
            and same_bits(item["provider_error"], call["provider_error"]), "Shadow request/decision replay differs")
        resolved = core.resolve_adaptation_v1(expected_request)
        require(same_bits(item["resolution"], resolved), "Shadow resolution/memory replay differs")
        require(resolved["world_build_count"] == 0 and resolved["physics_state_modified"] is False
            and resolved["physical_acceptance_authority"] is False, "Shadow resolver authority")
        response = call["provider_response"]
        bases = request["deterministic_baseline"]["ordered_commands"]
        limits = request["safety_envelope"]["ordered_actuator_limits"]
        for i, (base, limit, command) in enumerate(zip(bases, limits, resolved["ordered_commands"], strict=True)):
            require(limit["previous_applied_correction_rad_s"] == 0.
                and limit["maximum_absolute_correction_rad_s"] == .25
                and limit["maximum_slew_per_step_rad_s"] == .02, "Shadow used fictitious applied history")
            if resolved["adaptation_applied"]:
                proposed = response["ordered_corrections"][i]["canonical_velocity_delta_rad_s"]
                correction = max(-.02, min(.02, max(-.25, min(.25, proposed))))
            else:
                correction = 0.
            final = max(-base["maximum_target_speed_rad_s"], min(base["maximum_target_speed_rad_s"],
                base["combined_canonical_target_velocity_rad_s"] + correction))
            require(command["applied_correction_rad_s"] == correction
                and command["final_canonical_target_velocity_rad_s"] == final, "Shadow independent clamp arithmetic")
            if not resolved["adaptation_applied"]:
                require(same_bits(final, base["combined_canonical_target_velocity_rad_s"]), "Shadow fallback changed baseline")
        summary = stats[mode]
        summary["rows"] += 1
        summary["provider_errors"] += int(call["provider_error"] is not None)
        summary["unexpected_fallbacks"] += int(resolved["fallback_reason"] not in [
            "none", "provider_no_proposal", "provider_unsupported", "provider_reset", "safe_no_actuation"])
        summary["hypothetical_nonzero_rows"] += int(any(r["applied_correction_rad_s"] != 0. for r in resolved["ordered_commands"]))
        status = "error" if response is None else response["status"]
        summary["statuses"][status] = summary["statuses"].get(status, 0) + 1
        if operation is not None:
            summary["operations"].append(dict(outer_step=step, operation=operation))
        memories[mode] = resolved["next_memory"]


def audit_trial(folder, plan, c, spec, compiled, metadata, core):
    candidate = learner.FrozenModel.load(core, json.loads((folder.parent / "retrieval-model.json").read_text()))
    shadow_memories = {mode: learner.empty_memory(core, plan=candidate.plan()) for mode in c["shadow_modes"]}
    shadow_stats = {mode: dict(rows=0, provider_errors=0, unexpected_fallbacks=0, hypothetical_nonzero_rows=0, statuses={}, operations=[]) for mode in c["shadow_modes"]}
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
        controllers = [Controller(core, compiled, c, i) for i in plan["candidate_indices"]]
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
            validate_resolution(row, c, plan["candidate_indices"][cell], previous[cell])
            expected = controllers[cell].step(row["request"]["state"], row["stability"], row["kinematics"])
            require(all(same_bits(value, row[key]) for key, value in expected.items()), "Scalar decision/memory replay differs")
            verify_shadow(row, candidate, c, core, shadow_memories, shadow_stats)
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
        prior[cell] = row
        rows_read += 1
    require(rows_read == nworld * count * 5, "Missing internal rows")
    timings = timing_summary(list(read_jsonl(folder / "timing.jsonl")), c)
    for mode in c["shadow_modes"]:
        shadow_stats[mode]["final_memory"] = shadow_memories[mode]
    require(learner.digest(core, candidate.document()) == c["model"]["canonical_sha256"], "Base model changed")
    return dict(**plan, metrics=metrics, shadow=shadow_stats, timings=timings, setup_s=result["setup_s"],
                graph_capture_s=result["graph_capture_s"], internal_rows=rows_read,
                controller_rows=len(controls), maximum_force_error_nm=maximum_force_error)


def audit(folder, core_path, baseline_path):
    declared = json.loads((folder.parent / "declaration.json").read_text())
    c = declared["contract"]
    synthetic = declared.get("synthetic", False)
    require(type(synthetic) is bool, "Synthetic identity")
    expected = declaration()
    if synthetic:
        require(1 <= c["outer_steps"] <= 480, "Synthetic horizon")
        expected.update(outer_steps=c["outer_steps"], synthetic=True)
    require(c == expected, "Prospective shadow contract changed")
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
    states = observed[0]["shadow"]
    baseline = observed[0]["metrics"][0]
    eligible = (baseline["minimum_height_m"] >= c["selection"]["minimum_height_m"]
        and baseline["maximum_tilt_rad"] <= c["selection"]["maximum_tilt_rad"]
        and baseline["torso_contact_steps"] == baseline["safe_no_actuation_steps"] == 0)
    ready = (eligible and states["frozen"]["hypothetical_nonzero_rows"] > 0
        and all(s["provider_errors"] == s["unexpected_fallbacks"] == 0 for s in states.values()))
    return dict(ok=True, synthetic=synthetic, trials=observed,
        constructed_gpu_worlds=worlds, internal_rows=worlds * c["outer_steps"] * 5,
        controller_rows=worlds * c["outer_steps"], shadow_rows=worlds * c["outer_steps"] * len(c["shadow_modes"]),
        reader_world_build_count=0, physical_provider_influence_rows=0,
        baseline_eligible=eligible, shadow_ready_for_distinct_influence_design=ready,
        model_sha256=candidate.sha256, base_model_immutable=True,
        calibration_worlds=worlds if not synthetic else 0, evaluation_worlds=0, training_worlds=0,
        native_influence_evaluated=False, provider_promotion_authority=False,
        statistical_superiority_authority=False, **{key: False for key in FLAGS},
        interpretation="Fresh baseline-only shadow integration. Provider feedback is diagnostic, not action-effect evidence; no shadow outcomes may fit or promote a model. No learned physical influence, Tier 3 benefit or release is established.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(audit(args.folder, args.core, args.baseline_core), indent=2))
