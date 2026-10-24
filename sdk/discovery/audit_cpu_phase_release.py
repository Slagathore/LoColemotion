"""Independent replay, causal-prefix joins and full CPU training-corpus audit."""
import argparse
from contextlib import ExitStack
import hashlib
import json
import math
from pathlib import Path
from unittest.mock import patch
import mujoco
from cpu_phase_release_task import declaration, trial_plan, assess, ROOT, FLAGS, sha, require
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from portable_search_control import bridge
from gpu_quadruped_model import f32
from phase_release_control import PhaseReleaseController
PROBE_STEPS = 16
from audit_phase_release import validate_proposal
from audit_gpu_portable_search import validate_observation
from audit_gpu_batch_execution import same_bits, finite_vector, timing_summary, read_jsonl
from adaptation_provider.retrieval import flat_v2 as learner
from body_height_diagnostic import physical_violation, control_activity


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
                    safe_no_actuation_steps=0, forward_displacement_m=0., first_physical_violation=None) for _ in range(nworld)]
    controllers = []
    previous = [[0.] * 8 for _ in range(nworld)]
    try:
        controllers = [PhaseReleaseController(core, compiled, dict(c, seed=plan["seed"]), plan["activation_role_index"])]
        for index, row in enumerate(read_jsonl(folder / "controller.jsonl")):
            outer, cell = divmod(index, nworld)
            require(outer < count and (row["backend"], row["cell"], row["outer_step"]) == ("cpu", cell, outer), "Controller order/denominator")
            native = row["native_observation"]
            require("contact_compatibility_copy" not in native, "CPU observation mislabeled as GPU copy")
            validate_observation(row, metadata, compiled)
            validate_proposal(row, c, plan["activation_role_index"], previous[cell])
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
    caps = spec["force_ranges"]
    prior = [None] * nworld
    slots = []
    batch_count = None
    eps = 2**-52
    rows_read = 0
    maximum_force_error = 0.
    for index, row in enumerate(read_jsonl(folder / "trace.jsonl")):
        step, cell = divmod(index, nworld)
        step += 1
        require(step <= count * 5 and (row["backend"], row["cell"], row["step"]) == ("cpu", cell, step), "Internal order/denominator")
        for name, length in [("qpos", 15), ("before_qpos", 15), ("qvel", 14), ("before_qvel", 14),
                             ("ctrl", 8), ("actuator_force_nm", 8), ("joint_force_nm", 8)]:
            require(finite_vector(row[name], length), "Nonfinite/incomplete native vector")
        last = prior[cell]
        require(row["before_qpos"] == (last["qpos"] if last else initial_pos)
                and row["before_qvel"] == (last["qvel"] if last else initial_vel), "Native state continuity")
        control = controls[(step - 1) // 5, cell]
        require(same_bits(row["ctrl"], list(map(float, control["native_targets"]))), "Held solver input differs")
        if (step - 1) % 5 == 0:
            require(row["before_qpos"] == control["native_observation"]["qpos"]
                    and row["before_qvel"] == control["native_observation"]["qvel"], "Prepared observation clock")
            require(math.isfinite(control["native_observation"]["time_s"])
                    and abs(control["native_observation"]["time_s"] - (step - 1) * c["timestep_s"]) <= 4 * eps * step * step * c["timestep_s"], "Readback time")
        require(math.isfinite(row["time_s"]) and abs(row["time_s"] - step * c["timestep_s"]) <= 4 * eps * step * step * c["timestep_s"], "Internal clock")
        require(abs(sum(x * x for x in row["qpos"][3:7]) - 1) <= 128 * eps, "Quaternion normalization")
        require(row["warnings"] == [0]*c["cpu_warning_count"] and type(row["overflow"]) is int and row["overflow"] == 0
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
        if metric["first_physical_violation"] is None:
            metric["first_physical_violation"] = physical_violation(row, c["selection"])
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
        episodes.append(dict(episode_id=folder.parents[1].name + "_" + plan["trial_id"] + "_" + str(cell),
            group_id=plan["group_id"], action_id=c["provider"]["candidates"][plan["candidate_indices"][cell]]["id"],
            outcome="negative" if failures else "positive", failure_code=";".join(failures) if failures else None,
            raw_episode_sha256=learner.digest(core, raw), synthetic=c.get("synthetic", False),
            metrics=dict(mean_height_m=height_sums[cell] / (count*5), lateral_displacement_m=float(end[2]-initial[2]),
                         quality_m_s=sum(w["quality_m_s"] for w in windows)/len(windows) if windows else None),
            windows=windows))
    return dict(**plan, probe_features=controls[PROBE_STEPS,0]["activation_probe"]["features"] if count > PROBE_STEPS else None, metrics=metrics, episodes=episodes, raw_bindings=raw_bindings,
                pre_violation_activity=control_activity([controls[i,0] for i in range(count)], metrics[0]["first_physical_violation"]),
                timings=timings, setup_s=result["setup_s"],
                graph_capture_s=result["graph_capture_s"], internal_rows=rows_read,
                controller_rows=len(controls), maximum_force_error_nm=maximum_force_error)


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def audit(folder, core_path, baseline_path):
    declared=read(folder.parent/"declaration.json");c=declared["contract"];synthetic=declared.get("synthetic",False)
    expected=declaration()
    require(type(synthetic) is bool, "Phase-release comparison synthetic identity")
    if synthetic:
        require(type(c["outer_steps"]) is int and 1 <= c["outer_steps"] <= 1440, "Phase-release comparison synthetic horizon")
        expected.update(outer_steps=c["outer_steps"],synthetic=True,training_data_authority=False)
    require(c == expected, "Phase-release comparison prospective contract")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Phase-release comparison core identity")
    worker=read(folder/"worker-result.json")
    require(worker["ok"] is True and worker["synthetic"] is synthetic
        and worker["ledger_scope"] == c["ledger_scope"]
        and worker["status"] == "complete_native_cpu_phase_release" and worker["controller_sessions_closed"] is True
        and worker["constructed_cpu_worlds"] == 32 and worker["constructed_gpu_worlds"] == 0
        and len(worker["trials"]) == 32 and all(worker[k] is False for k in FLAGS), "Phase-release comparison worker population/authority")
    plans=trial_plan(c);conditions=c["challenge"]["conditions"]
    require({p.name for p in folder.iterdir() if p.is_dir()} == {p["trial_id"] for p in plans}|{"models"}, "Phase-release comparison trial folders")
    require({p.name for p in (folder/"models").iterdir() if p.is_dir()} == set(conditions), "Phase-release comparison condition folders")
    observed=[]
    with ExitStack() as guards:
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Reader constructs no worlds")))
        core=bridge.LocomotionCore(baseline_path);models={}
        for condition in conditions:
            directory=folder/"models"/condition
            compiled,xml,spec=condition_inputs(core_path,c,condition)
            require((directory/"model.xml").read_text() == xml and sha(directory/"model.xml") == c["condition_model_sha256"][condition],
                "Phase-release comparison condition XML binding")
            require(read(directory/"compiled.json") == compiled and read(directory/"inputs.json") == spec, "Phase-release comparison condition inputs")
            metadata=read(directory/"native-model.json")
            for name in ["model","compiled","inputs"]:
                require(metadata[name+"_sha256"] == sha(directory/(name+(".xml" if name == "model" else ".json"))), "Phase-release comparison native input digest")
            require(metadata["condition_id"] == condition and metadata["actuator_profile"] == expected_actuator_arrays(spec)
                and metadata["force_ranges"] == spec["force_ranges"] and metadata["dynamics_dtype"] == "float64"
                and metadata["initial_values"] == c["challenge"]["initial_values"]
                and metadata["observation_stage"] == "prepared_before_control"
                and metadata["force_stage"] == "completed_step_before_next_prepare", "Phase-release comparison native condition profile")
            models[condition]=(compiled,spec,metadata)
        for plan,recorded in zip(plans,worker["trials"],strict=True):
            directory=folder/plan["trial_id"]
            require(read(directory/"result.json") == recorded, "Phase-release comparison worker trial join")
            compiled,spec,metadata=models[plan["condition_id"]]
            observed.append(audit_trial(directory,plan,c,spec,compiled,metadata,core))
    groups = []
    for group_id in dict.fromkeys(p["group_id"] for p in plans):
        rows = [t for t in observed if t["group_id"] == group_id]
        require(len(rows) == 4 and [r["activation_role_index"] for r in rows] == [0,1,2,3], "Phase-release matched role group")
        require(all(rows[i]["probe_features"] is None for i in [1,2]), "Immediate feedback cannot claim a baseline prefix")
        features = [rows[i]["probe_features"] for i in [0,3]]
        require(same_bits(features[0],features[1]) and (features[0] is not None or (synthetic and c["outer_steps"] <= PROBE_STEPS)),
                "Baseline and delayed height did not observe the same causal prefix")
        groups.append(dict(group_id=group_id,condition_id=rows[0]["condition_id"],partition="training",features=features[0],
            matching_baseline_prefixes=2,immediate_roles_have_baseline_prefix=False))
    return dict(ok=True,synthetic=synthetic,ledger_scope=c["ledger_scope"],trials=observed,groups=groups,
        controller_rows=sum(t["controller_rows"] for t in observed),internal_rows=sum(t["internal_rows"] for t in observed),
        constructed_cpu_worlds=32,constructed_gpu_worlds=0,reader_world_build_count=0,
        eligible_episodes=sum(t["episodes"][0]["outcome"] == "positive" for t in observed),
        negative_episodes=sum(t["episodes"][0]["outcome"] == "negative" for t in observed),
        native_worker_wall_s=worker["total_wall_s"],training_data_scope="development_phase_release_discovery_only",
        repertoire=assess(observed,c),controller_selection_authority=not synthetic,population_inference=False,
        **{k: k == "training_data_authority" and not synthetic for k in FLAGS})


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--folder",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    a=p.parse_args();result=audit(a.folder,a.core,a.baseline_core)
    with a.output.open("x",encoding="utf-8",newline="\n") as stream:
        json.dump(result,stream,indent=2,allow_nan=False);stream.write("\n")
    print(json.dumps({k:result[k] for k in ["ok","controller_rows","internal_rows","eligible_episodes","negative_episodes","reader_world_build_count"]}))
