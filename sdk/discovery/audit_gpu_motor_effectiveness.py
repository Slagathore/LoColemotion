"""Independent full-population condition replay; no fitted or release authority."""
import argparse
import json
import math
from pathlib import Path
import struct
import statistics
import numpy as np
from unittest.mock import patch
import mujoco

from motor_effectiveness_task import declaration, trial_plan, ROOT, condition_inputs, expected_actuator_arrays
from gpu_quadruped_model import FLAGS, sha, f32
from portable_search_control import bridge
from repertoire_control import ScalarRepertoireController
from audit_gpu_portable_search import require, validate_observation
from audit_gpu_batch_execution import same_bits, finite_vector, timing_summary, read_jsonl
from adaptation_provider.retrieval import flat_v2 as learner


def validate_proposal(row,c,cell,previous):
    request=row['resolution_request']['provider_request'];response=row['resolution_request']['provider_response'];resolved=row['resolution']
    require(request['deterministic_baseline']==row['composition']['canonical_actuation'],'Provider baseline join')
    require(request['state']==row['request']['state'] and request['command']==row['request']['command'],'Provider observation join')
    factor=c['provider']['candidates'][cell]['factor']; coefficients=c['provider']['candidates'][cell]['ordered_coefficients']
    require((response is None)==(factor is None),'Candidate identity')
    require(request['expected_model_id']==c['provider']['candidates'][cell]['id'],'Candidate model identity')
    require(request['expected_training_corpus_id']=='untrained_no_training_corpus','Untrained candidate relabelled')
    baseline=request['deterministic_baseline']['ordered_commands'];limits=request['safety_envelope']['ordered_actuator_limits']
    require(len(baseline)==len(limits)==len(resolved['ordered_commands'])==len(row['native_targets'])==8,'Provider population')
    for i,(base,limit,actual) in enumerate(zip(baseline,limits,resolved['ordered_commands'])):
        require(limit['previous_applied_correction_rad_s']==previous[i] and limit['maximum_absolute_correction_rad_s']==c['provider']['maximum_absolute_correction_rad_s']
            and limit['maximum_slew_per_step_rad_s']==c['provider']['maximum_slew_per_step_rad_s'],'Correction history or envelope changed')
        proposal=0. if factor is None else coefficients[i]*base['combined_canonical_target_velocity_rad_s']
        if response is not None:require(response['ordered_corrections'][i]['canonical_velocity_delta_rad_s']==proposal,'Candidate proposal changed')
        if factor is None or resolved['safe_no_actuation']:expected=0.
        else:
            cap=c['provider']['maximum_absolute_correction_rad_s'];slew=c['provider']['maximum_slew_per_step_rad_s']
            bounded=max(-cap,min(cap,proposal));expected=max(-cap,min(cap,max(previous[i]-slew,min(previous[i]+slew,bounded))))
        require(actual['applied_correction_rad_s']==expected,'Resolved correction mismatch')
        final=max(-base['maximum_target_speed_rad_s'],min(base['maximum_target_speed_rad_s'],base['combined_canonical_target_velocity_rad_s']+expected))
        require(actual['final_canonical_target_velocity_rad_s']==final and row['native_targets'][i]==final,'Canonical/native target mismatch')
        if factor is None:require(struct.pack('d',final)==struct.pack('d',base['combined_canonical_target_velocity_rad_s']),'Baseline bits changed')


def audit_trial(folder, plan, c, spec, compiled, metadata, core):
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
        controllers = [ScalarRepertoireController(core, compiled, dict(c, seed=plan["seed"]), i) for i in plan["candidate_indices"]]
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
            validate_proposal(row, c, plan["candidate_indices"][cell], previous[cell])
            expected = controllers[cell].step(row["request"]["state"], row["stability"], row["kinematics"])
            require(all(same_bits(value, row[key]) for key, value in expected.items()), "Scalar decision/memory replay differs")
            previous[cell] = [r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
            metrics[cell]["safe_no_actuation_steps"] += int(row["output"]["actuation"]["safe_no_actuation"])
            controls[outer, cell] = row
    finally:
        for controller in controllers:
            controller.close()
    require(len(controls) == count * nworld, "Missing controller row")
    initial_vel = [0., f32(plan["initial_native_lateral_velocity_m_s"])] + [0.] * 12
    initial_pos = list(map(f32, spec["initial_qpos"]))
    half = plan["initial_native_roll_rad"] / 2
    initial_pos[3:7] = list(map(f32, [math.cos(half), math.sin(half), 0., 0.]))
    height_sums = [0.] * nworld
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
        height_sums[cell] += row["qpos"][2]
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
    episodes = []
    raw_bindings = []
    lp = learner.contract()
    for cell, metric in enumerate(metrics):
        failures = []
        if metric["minimum_height_m"] < c["selection"]["minimum_height_m"]: failures.append("height")
        if metric["maximum_tilt_rad"] > c["selection"]["maximum_tilt_rad"]: failures.append("tilt")
        if metric["torso_contact_steps"] > c["selection"]["maximum_torso_contact_steps"]: failures.append("torso_contact")
        if metric["safe_no_actuation_steps"]: failures.append("safe_no_actuation")
        windows = []
        if not failures:
            for start in range(0, count - lp["decision_window_steps"] + 1, lp["decision_window_steps"]):
                stop = start + lp["decision_window_steps"]
                start_state = controls[start, cell]["request"]["state"]["base_pose_world"]["position_m"]
                start_position = [start_state["x"], start_state["z"]]
                if stop == count:
                    end_native = prior[cell]["qpos"][:3]
                    end_canonical = bridge._mujoco_to_canonical(end_native)
                    end_position = [float(end_canonical[0]), float(end_canonical[2])]
                else:
                    end_state = controls[stop, cell]["request"]["state"]["base_pose_world"]["position_m"]
                    end_position = [end_state["x"], end_state["z"]]
                query = learner.cue(controls[start, cell]["resolution_request"]["provider_request"], lp)
                windows.append(dict(start_step=start, cue=query, start_position_xz_m=start_position,
                    end_position_xz_m=end_position, quality_m_s=learner.quality(start_position, end_position,
                        lp["decision_window_steps"] * lp["controller_dt_s"], lp)))
        first = controls[0, cell]["resolution_request"]
        # The raw binding includes the shared streams and exact cell selection;
        # no trial is replaced by its elite or by a digest without retained bytes.
        raw = dict(group_id=plan["group_id"], condition_id=plan["condition_id"], partition=plan["partition"], action_index=plan["candidate_indices"][cell], cell=cell, seed=plan["seed"], hashes=result["hashes"],
            provider_request_sha256=learner.digest(core, first["provider_request"]),
            provider_response_sha256=learner.digest(core, first["provider_response"]),
            resolution_receipt_sha256=learner.digest(core, controls[0, cell]["resolution"]),
            descriptor_sha256=c["descriptor_sha256"], expected_outer_rows=count, expected_internal_rows=count*5)
        raw_bindings.append(raw)
        end = bridge._mujoco_to_canonical(prior[cell]["qpos"][:3])
        initial = bridge._mujoco_to_canonical(spec["initial_qpos"][:3])
        episodes.append(dict(episode_id=folder.parents[3].name + "_" + plan["group_id"] + "_" + str(cell),
            group_id=plan["group_id"], action_id=c["provider"]["candidates"][plan["candidate_indices"][cell]]["id"],
            outcome="negative" if failures else "positive", failure_code=";".join(failures) if failures else None,
            raw_episode_sha256=learner.digest(core, raw), synthetic=c.get("synthetic", False),
            metrics=dict(mean_height_m=height_sums[cell] / (count*5), lateral_displacement_m=float(end[2]-initial[2]),
                         quality_m_s=sum(w["quality_m_s"] for w in windows)/len(windows) if windows else 0.),
            windows=windows))
    return dict(**plan, metrics=metrics, episodes=episodes, raw_bindings=raw_bindings,
                timings=timings, setup_s=result["setup_s"],
                graph_capture_s=result["graph_capture_s"], internal_rows=rows_read,
                controller_rows=len(controls), maximum_force_error_nm=maximum_force_error)


def audit_phase(folder, core_path, baseline_path, phase, selection=None):
    declared = json.loads((folder.parent.parent/"declaration.json").read_text())
    c = declared["contract"]
    synthetic = declared.get("synthetic", False)
    expected = declaration()
    require(type(synthetic) is bool, "Synthetic identity")
    if synthetic:
        require(1 <= c["outer_steps"] <= 480, "Synthetic horizon")
        expected.update(outer_steps=c["outer_steps"], synthetic=True, training_data_authority=False)
    require(c == expected, "Prospective motor contract changed")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Core identity")
    plans = trial_plan(c, phase, selection)
    conditions = [r["condition_id"] for r in c["conditions"]]
    require(set(p.name for p in folder.iterdir() if p.is_dir()) == set(conditions), "Condition folder population")
    observed, workers = [], []
    core = bridge.LocomotionCore(baseline_path)
    phase_contract = dict(c, training_data_authority=phase == "discovery" and not synthetic)
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Audit world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Audit data")), \
            patch.object(mujoco, "mj_step", side_effect=AssertionError("Audit physics")):
        for cid in conditions:
            directory = folder/cid
            worker = json.loads((directory/"worker-result.json").read_text())
            require(worker["ok"] is True and worker["synthetic"] is synthetic
                and worker["phase"] == phase and worker["condition_id"] == cid
                and worker["status"] == "complete_motor_effectiveness_condition"
                and worker["controller_sessions_closed"] is True
                and type(worker["total_wall_s"]) in (int, float) and math.isfinite(worker["total_wall_s"])
                and worker["total_wall_s"] >= 0
                and all(worker[k] is phase_contract[k] for k in FLAGS), "Incomplete/crossed condition worker")
            expected_compiled, xml, expected_spec = condition_inputs(core_path, c, cid)
            require((directory/"model.xml").read_text() == xml
                and sha(directory/"model.xml") == c["condition_model_sha256"][cid], "Condition XML binding")
            compiled = json.loads((directory/"compiled.json").read_text())
            spec = json.loads((directory/"inputs.json").read_text())
            require(compiled == expected_compiled and spec == expected_spec, "Condition compiler/input binding")
            metadata = json.loads((directory/"native-model.json").read_text())
            for name in ["model", "compiled", "inputs"]:
                require(metadata[name+"_sha256"] == sha(directory/(name+(".xml" if name == "model" else ".json"))), "Native input digest")
            require(metadata["condition_id"] == cid and metadata["actuator_profile"] == expected_actuator_arrays(spec)
                and metadata["force_ranges"] == spec["force_ranges"]
                and metadata["observation_stage"] == "prepared_before_control"
                and metadata["force_stage"] == "completed_step_before_next_prepare", "Condition native profile/sampling")
            gpu = json.loads((directory/"gpu-actuator-profile.json").read_text())
            expected_gpu = {k: [np.asarray(expected_actuator_arrays(spec)[k], np.float32).tolist()]
                for k in ["gainprm", "biasprm", "forcerange"]}
            require(same_bits(gpu, expected_gpu), "Condition GPU profile binding")
            condition_plans = [p for p in plans if p["condition_id"] == cid]
            require(len(worker["trials"]) == len(condition_plans) == 2
                and worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == sum(p["nworld"] for p in condition_plans)
                and worker["stepped_cpu_worlds"] == 0, "Condition world population")
            for plan, recorded in zip(condition_plans, worker["trials"], strict=True):
                require(json.loads((directory/plan["trial_id"]/"result.json").read_text()) == recorded, "Worker trial index")
                observed.append(audit_trial(directory/plan["trial_id"], plan, phase_contract, spec, compiled, metadata, core))
            workers.append(dict(condition_id=cid, total_wall_s=worker["total_wall_s"],
                worker_result_sha256=sha(directory/"worker-result.json")))
    require([r["trial_id"] for r in observed] == [p["trial_id"] for p in plans], "Full phase trial order")
    return dict(ok=True, phase=phase, synthetic=synthetic, ledger_scope=c["ledger_scope"], trials=observed,
        workers=workers, controller_rows=sum(r["controller_rows"] for r in observed),
        internal_rows=sum(r["internal_rows"] for r in observed),
        constructed_gpu_worlds=sum(p["nworld"] for p in plans), stepped_cpu_worlds=0, reader_world_build_count=0,
        eligible_episodes=sum(e["outcome"] == "positive" for r in observed for e in r["episodes"]),
        negative_episodes=sum(e["outcome"] == "negative" for r in observed for e in r["episodes"]),
        training_data_scope="development_discovery_only", **{k: phase_contract[k] for k in FLAGS})


def compare_confirmation(confirmation, selection, c):
    require(confirmation["ok"] is True and confirmation["phase"] == "confirmation"
        and confirmation["reader_world_build_count"] == 0
        and confirmation["training_data_authority"] is False
        and confirmation["synthetic"] is selection["synthetic"], "Confirmation authority/phase")
    plans = trial_plan(c, "confirmation", selection)
    require(len(confirmation["trials"]) == len(plans), "Confirmation population")
    rows = []
    floor, loss = c["comparison"]["minimum_gain_m_s"], c["comparison"]["maximum_individual_loss_m_s"]
    for plan, result in zip(plans, confirmation["trials"], strict=True):
        require(all(result[k] == v for k, v in plan.items()) and len(result["episodes"]) == 3, "Confirmation plan binding")
        roles = {}
        for role, index, episode in zip(plan["role_order"], plan["candidate_indices"], result["episodes"], strict=True):
            require(episode["action_id"] == c["provider"]["candidates"][index]["id"]
                and episode["group_id"] == plan["group_id"] and episode["synthetic"] is confirmation["synthetic"]
                and episode["outcome"] in ("positive", "negative")
                and learner.finite(episode["metrics"]["quality_m_s"]), "Confirmation action/outcome identity")
            roles[role] = dict(action_index=index, eligible=episode["outcome"] == "positive",
                quality_m_s=episode["metrics"]["quality_m_s"] if episode["outcome"] == "positive" else None)
        oracle, baseline, shared = [roles[k] for k in ["condition_known", "baseline", "shared_profile"]]
        delta_baseline = oracle["quality_m_s"]-baseline["quality_m_s"] if oracle["eligible"] and baseline["eligible"] else None
        delta_shared = oracle["quality_m_s"]-shared["quality_m_s"] if oracle["eligible"] and shared["eligible"] else None
        available = selection["conditions"][plan["condition_id"]]["selected_action_index"] is not None
        rows.append(dict(group_id=plan["group_id"], condition_id=plan["condition_id"], roles=roles,
            oracle_selected=available, shared_selected=selection["shared"]["selected_action_index"] is not None,
            oracle_minus_baseline_m_s=delta_baseline, oracle_minus_shared_m_s=delta_shared,
            changed_profile=oracle["action_index"] != shared["action_index"],
            oracle_gain_over_baseline=available and delta_baseline is not None and delta_baseline >= floor))
    degraded = [r for r in rows if r["condition_id"] != "nominal"]
    healthy = [r for r in rows if r["condition_id"] == "nominal"]
    require(len(degraded) == 8 and len(healthy) == 2, "Confirmation condition denominator")
    valid = all(r["oracle_selected"] and r["shared_selected"] and all(role["eligible"] for role in r["roles"].values()) for r in rows)
    mean_delta = statistics.mean(r["oracle_minus_shared_m_s"] for r in degraded) if valid else None
    healthy_guard = all(r["oracle_minus_baseline_m_s"] is not None and r["oracle_minus_baseline_m_s"] >= -loss
        and r["oracle_minus_shared_m_s"] is not None and r["oracle_minus_shared_m_s"] >= -loss for r in healthy)
    value = (valid and healthy_guard and any(r["changed_profile"] for r in degraded) and mean_delta >= floor
        and all(r["oracle_minus_shared_m_s"] >= -loss for r in degraded))
    return dict(schema_version="locolemotion_motor_effectiveness_comparison_v1", ledger_scope=c["ledger_scope"],
        synthetic=confirmation["synthetic"], groups=rows, degraded_group_denominator=8, healthy_group_denominator=2,
        oracle_baseline_gain_groups=sum(r["oracle_gain_over_baseline"] for r in degraded),
        all_roles_eligible_and_selected=valid, healthy_guard_passed=healthy_guard,
        mean_degraded_oracle_minus_shared_m_s=mean_delta, finite_conditioning_value=value,
        oracle_scope="nine_constant_bounded_residual_profiles_only", causal_history_inference=False,
        adaptive_provider_benefit=False, physical_acceptance_authority=False, release_authority=False,
        statistical_superiority_authority=False, noninferiority_authority=False,
        interpretation="Fresh finite confirmation of a discovery-selected condition-known profile versus baseline and one discovery-selected shared profile. No outcome changes the frozen selection. These profiles do not bound the performance of all possible residual controllers.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", type=Path, required=True)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--phase", choices=["discovery", "confirmation"], required=True)
    parser.add_argument("--selection", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    selection = None
    if args.phase == "confirmation":
        from gpu_motor_effectiveness import load_selection
        selection = load_selection(args.selection, declaration())
    else:
        require(args.selection is None, "Discovery reader cannot consume selection")
    result = audit_phase(args.folder, args.core, args.baseline_core, args.phase, selection)
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({k: result[k] for k in ["ok", "phase", "controller_rows", "internal_rows", "eligible_episodes", "negative_episodes", "reader_world_build_count"]}))


