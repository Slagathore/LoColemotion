"""Fresh native CPU committed-feedback comparison in degraded and healthy conditions."""
import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import sys
import time
from unittest.mock import patch
import mujoco
import numpy as np
from cpu_committed_feedback_task import ROOT, FLAGS, declaration, trial_plan, initial_arrays, require, sha
from cpu_body_height_confirmation import preflight as parent_preflight
from motor_effectiveness_task import condition_inputs, condition_robot_view, validate_native_profile
from gpu_measurement_probe import write_new
from gpu_portable_search import observation_native, cpu_contacts
from gpu_quadruped_probe import check_capture
from portable_search_control import bridge
from committed_feedback_control import CommittedFeedbackController, provider
from audit_gpu_portable_search import validate_observation
from actuation_measurement import named_force_samples


def preflight(core_path, baseline_path):
    parent_preflight(core_path, baseline_path)
    c = declaration(); core = bridge.LocomotionCore(core_path); frozen_model = provider.ConditionedModel.load(core)
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Preflight world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Preflight data")):
        for condition in c["challenge"]["conditions"]:
            compiled,xml,spec = condition_inputs(core_path,c,condition)
            require(hashlib.sha256(xml.encode()).hexdigest() == c["condition_model_sha256"][condition], "Committed-feedback comparison XML pin")
            for plan in [p for p in trial_plan(c) if p["condition_id"] == condition]:
                controller = CommittedFeedbackController(core,compiled,c,plan["selection_role_index"],frozen_model); controller.close()
                qpos,qvel = initial_arrays(spec,plan)
                require(qpos.shape == (15,) and qvel.shape == (14,) and qpos.dtype == qvel.dtype == np.float64
                    and np.all(np.isfinite(qpos)) and np.all(np.isfinite(qvel)), "Committed-feedback comparison initialization")
    return dict(ok=True,world_build_count=0,solver_steps=0,planned_cpu_worlds=48,planned_gpu_worlds=0,
        planned_controller_rows=69120,planned_internal_rows=345600,evaluation_worlds=0)


def run_trial(directory, plan, c, core, compiled, model, spec, metadata, population, frozen_model):
    directory.mkdir(); tick = time.perf_counter()
    data = mujoco.MjData(model); population["constructed_cpu_worlds"] += 1
    data.qpos[:],data.qvel[:] = initial_arrays(spec,plan)
    robot = condition_robot_view(core,compiled,model,data,spec)
    for i,(motor,joint) in enumerate(zip(spec["ordered_actuators"],spec["ordered_joints"],strict=True)):
        named_force_samples(model,data,motor,joint)
        require([int(model.sensor_adr[model.sensor(motor+"_force").id]),
            int(model.sensor_adr[model.sensor(joint+"_actuator_force").id])] == [2*i,2*i+1], "Committed-feedback comparison force sensor order")
    write_new(directory/"plan.json",plan)
    controller = CommittedFeedbackController(core,compiled,dict(c,seed=plan["seed"]),plan["selection_role_index"],frozen_model)
    trial = dict(plan,setup_s=time.perf_counter()-tick,graph_capture_s=0.,outer_rows=0,internal_rows=0,completed=False)
    with ExitStack() as outputs:
        outputs.callback(controller.close)
        streams = {name:outputs.enter_context((directory/(name+".jsonl")).open("x",encoding="utf-8",newline="\n"))
            for name in ["controller","trace","timing"]}
        def append(name,row):
            stream=streams[name];stream.write(json.dumps(row,allow_nan=False,separators=(",",":"))+"\n")
            require(stream.tell() <= c["maximum_trace_bytes_per_trial"], "Committed-feedback comparison trace byte bound")
        for outer in range(c["outer_steps"]):
            stage = plan["trial_id"]+f"_outer_{outer}"
            if outer % 120 == 0: print(json.dumps(dict(trial=plan["trial_id"], outer_step=outer)), flush=True)
            whole = time.perf_counter(); timing = dict(outer_step=outer, measured=True)
            tick = time.perf_counter(); mujoco.mj_step1(model, data); timing["prepare_s"] = time.perf_counter()-tick
            tick = time.perf_counter()
            state = robot.state_frame(outer, bridge._mujoco_to_canonical(spec["initial_qpos"][:3]))
            stability = robot.stability_state(outer); kinematics = robot.endpoint_kinematics(stability)
            native = observation_native(data, cpu_contacts(data, 0))
            timing["observation_readback_s"] = time.perf_counter()-tick
            tick = time.perf_counter(); row = controller.step(state, stability, kinematics)
            timing["portable_control_s"] = time.perf_counter()-tick
            tick = time.perf_counter(); row.update(backend="cpu", cell=0, outer_step=outer, native_observation=native)
            validate_observation(row, metadata, compiled); append("controller", row); trial["outer_rows"] += 1
            data.ctrl[:] = row["native_targets"]
            timing["controller_capture_and_control_transfer_s"] = time.perf_counter()-tick
            integrate = capture = 0.
            for sub in range(5):
                tick = time.perf_counter()
                if sub: mujoco.mj_step1(model, data)
                before_pos, before_vel = data.qpos.copy(), data.qvel.copy()
                mujoco.mj_step2(model, data); integrate += time.perf_counter()-tick
                tick = time.perf_counter()
                forces = data.sensordata[::2].tolist(); joints = data.sensordata[1::2].tolist()
                sample = dict(backend="cpu", cell=0, step=5*outer+sub+1,
                    before_qpos=before_pos.tolist(), before_qvel=before_vel.tolist(), qpos=data.qpos.tolist(), qvel=data.qvel.tolist(),
                    ctrl=data.ctrl.tolist(), actuator_force_nm=forces, joint_force_nm=joints,
                    on_force_cap=[f <= lo or f >= hi for f,(lo,hi) in zip(forces,spec["force_ranges"],strict=True)],
                    time_s=float(data.time), contacts=cpu_contacts(data,0), batch_contacts=int(data.ncon), nefc=int(data.nefc),
                    overflow=0, warnings=[int(w.number) for w in data.warning])
                require(sample["ctrl"] == row["native_targets"], "CPU held solver input")
                check_capture(sample, c, spec["force_ranges"]); append("trace", sample); trial["internal_rows"] += 1
                capture += time.perf_counter()-tick
            streams["controller"].flush(); streams["trace"].flush()
            # Retain the inherited timing schema; this CPU integration
            # bucket contains no GPU device-history work.
            timing["integration_and_device_history_s"] = integrate
            timing["internal_readback_and_capture_s"] = capture
            timing["outer_total_s"] = time.perf_counter()-whole; append("timing", timing)

    trial.update(completed=True,hashes={name:sha(directory/(name+".jsonl")) for name in ["controller","trace","timing"]})
    write_new(directory/"result.json",trial)
    print(json.dumps(dict(trial=plan["trial_id"],complete=True,outer_rows=trial["outer_rows"])),flush=True)
    return trial


def run(folder,permit,core_path,baseline_path):
    sys.path.insert(0,str(ROOT/"sdk/conformance"))
    import r10v_windows_job as jobs
    require(permit.is_file() and jobs.current_in_job(), "Contained committed-feedback comparison execution required")
    preflight(core_path,baseline_path)
    c=declaration();core=bridge.LocomotionCore(core_path);frozen_model=provider.ConditionedModel.load(core)
    result=dict(ok=False,synthetic=False,ledger_scope=c["ledger_scope"],trials=[],
        constructed_cpu_worlds=0,constructed_gpu_worlds=0,**{k:False for k in FLAGS})
    started=time.perf_counter();stage="models"
    try:
        models=folder/"models";models.mkdir()
        for condition in c["challenge"]["conditions"]:
            stage=condition+"_model";directory=models/condition;directory.mkdir()
            compiled,xml,spec=condition_inputs(core_path,c,condition)
            write_new(directory/"compiled.json",compiled);write_new(directory/"inputs.json",spec)
            with (directory/"model.xml").open("x",encoding="utf-8",newline="\n") as stream:stream.write(xml)
            model=mujoco.MjModel.from_xml_string(xml);profile=validate_native_profile(model,spec)
            require(model.qpos0.tolist() == spec["initial_qpos"], "Committed-feedback comparison native initial pose")
            metadata=dict(model_sha256=sha(directory/"model.xml"),inputs_sha256=sha(directory/"inputs.json"),
                compiled_sha256=sha(directory/"compiled.json"),condition_id=condition,actuator_profile=profile,
                ordered_bodies=[model.body(i).name for i in range(model.nbody)],body_rootid=model.body_rootid.tolist(),
                force_ranges=model.actuator_forcerange.tolist(),observation_stage="prepared_before_control",
                force_stage="completed_step_before_next_prepare",dynamics_dtype="float64",initial_values=c["challenge"]["initial_values"])
            write_new(directory/"native-model.json",metadata)
            for plan in [p for p in trial_plan(c) if p["condition_id"] == condition]:
                stage=plan["trial_id"]
                result["trials"].append(run_trial(folder/stage,plan,c,core,compiled,model,spec,metadata,result,frozen_model))
        result.update(ok=True,status="complete_native_cpu_committed_feedback")
    except BaseException as exc:
        result.update(error=f"{type(exc).__name__}: {exc}",failed_stage=stage,status="incomplete_or_refused_execution")
    finally:
        result.update(total_wall_s=time.perf_counter()-started,controller_sessions_closed=True)
        write_new(folder/"worker-result.json",result)
    if not result["ok"]:raise RuntimeError(result["error"])


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--check-only",action="store_true");p.add_argument("--output",type=Path);p.add_argument("--permit",type=Path)
    a=p.parse_args()
    if a.check_only:print(json.dumps(preflight(a.core,a.baseline_core)))
    elif a.output is None or a.permit is None:p.error("Use contained supervisor")
    else:run(a.output,a.permit,a.core,a.baseline_core)
