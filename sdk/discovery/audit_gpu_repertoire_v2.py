"""Independent full-population native replay and raw-to-case corpus joins."""
import argparse
import json
import math
from pathlib import Path
import struct
from unittest.mock import patch
import mujoco

from gpu_repertoire_v2 import declaration, trial_plan, ROOT
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
        raw = dict(group_id=plan["group_id"], cell=cell, seed=plan["seed"], hashes=result["hashes"],
            provider_request_sha256=learner.digest(core, first["provider_request"]),
            provider_response_sha256=learner.digest(core, first["provider_response"]),
            resolution_receipt_sha256=learner.digest(core, controls[0, cell]["resolution"]),
            descriptor_sha256=c["descriptor_sha256"], expected_outer_rows=count, expected_internal_rows=count*5)
        raw_bindings.append(raw)
        end = bridge._mujoco_to_canonical(prior[cell]["qpos"][:3])
        initial = bridge._mujoco_to_canonical(spec["initial_qpos"][:3])
        episodes.append(dict(episode_id=folder.parent.parent.name + "_" + plan["group_id"] + "_" + str(cell),
            group_id=plan["group_id"], action_id=c["provider"]["candidates"][cell]["id"],
            outcome="negative" if failures else "positive", failure_code=";".join(failures) if failures else None,
            raw_episode_sha256=learner.digest(core, raw), synthetic=c.get("synthetic", False),
            metrics=dict(mean_height_m=height_sums[cell] / (count*5), lateral_displacement_m=float(end[2]-initial[2]),
                         quality_m_s=sum(w["quality_m_s"] for w in windows)/len(windows) if windows else 0.),
            windows=windows))
    return dict(**plan, metrics=metrics, episodes=episodes, raw_bindings=raw_bindings,
                timings=timings, setup_s=result["setup_s"],
                graph_capture_s=result["graph_capture_s"], internal_rows=rows_read,
                controller_rows=len(controls), maximum_force_error_nm=maximum_force_error)


def audit(folder, core_path, baseline_path):
    declared = json.loads((folder.parent / "declaration.json").read_text(encoding="utf-8"))
    c = declared["contract"]
    synthetic = declared.get("synthetic", False)
    require(type(synthetic) is bool, "Synthetic identity")
    expected = declaration()
    if synthetic:
        require(1 <= c["outer_steps"] <= 480, "Synthetic horizon")
        expected.update(outer_steps=c["outer_steps"], synthetic=True, training_data_authority=False)
    require(c == expected, "Prospective native contract changed")
    worker = json.loads((folder / "worker-result.json").read_text())
    require(worker["ok"] is True and worker["synthetic"] is synthetic
            and all(worker[k] is c[k] for k in FLAGS), "Incomplete worker or changed authority")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Core binding")
    require(sha(folder / "model.xml") == c["model_xml_sha256"], "Model binding")
    metadata = json.loads((folder / "native-model.json").read_text())
    compiled = json.loads((folder / "compiled.json").read_text())
    spec = json.loads((folder / "inputs.json").read_text())
    for name in ["model", "compiled", "inputs"]:
        require(metadata[name + "_sha256"] == sha(folder / (name + (".xml" if name == "model" else ".json"))), "Native input digest")
    require(compiled["descriptor_sha256"] == c["descriptor_sha256"] and compiled["world_build_count"] == 0, "Compiled descriptor")
    require(spec["initial_lateral_velocities"] == [], "Undeclared legacy initialization")
    require(metadata["observation_stage"] == "prepared_before_control"
            and metadata["force_stage"] == "completed_step_before_next_prepare", "Sampling stage")
    plans = trial_plan(c)
    require(len(worker["trials"]) == len(plans) == 4, "Training trial denominator")
    observed = []
    core = bridge.LocomotionCore(baseline_path)
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Audit world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Audit data")), \
            patch.object(mujoco, "mj_step", side_effect=AssertionError("Audit physics")):
        for plan, result in zip(plans, worker["trials"], strict=True):
            trial_dir = folder / plan["trial_id"]
            require(result == json.loads((trial_dir / "result.json").read_text()), "Worker trial index changed")
            observed.append(audit_trial(trial_dir, plan, c, spec, compiled, metadata, core))
    if not synthetic:
        require(all(m["ground_contact_steps"] > 0 and m["nonzero_force_steps"] > 0
                    for r in observed for m in r["metrics"]), "Native contact/force path not exercised")
    worlds = sum(p["nworld"] for p in plans)
    require(worker["constructed_gpu_worlds"] == worlds and worker["cpu_readback_views"] == worlds
            and worker["stepped_cpu_worlds"] == 0 and worker["controller_sessions_closed"] is True, "World lifecycle denominator")
    episodes = [episode for row in observed for episode in row["episodes"]]
    return dict(ok=True, synthetic=synthetic, trials=observed, constructed_gpu_worlds=worlds,
        internal_rows=worlds*c["outer_steps"]*5, controller_rows=worlds*c["outer_steps"],
        reader_world_build_count=0, eligible_episodes=sum(e["outcome"] == "positive" for e in episodes),
        retained_negative_episodes=sum(e["outcome"] == "negative" for e in episodes),
        calibration_worlds=0, evaluation_worlds=0, training_scope=c["training_scope"],
        **{key: c[key] for key in FLAGS},
        interpretation="All training outcomes retained; eligible episodes supply bounded development cases only. No held-out, physical acceptance, release or engine-equivalence claim.")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("folder", type=Path)
    p.add_argument("--core", type=Path, required=True)
    p.add_argument("--baseline-core", type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(audit(a.folder, a.core, a.baseline_core), indent=2))
