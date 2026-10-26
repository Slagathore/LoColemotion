"""Fresh paired reach/dynamic worlds with complete contact capture."""
import argparse
from contextlib import ExitStack
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys
import time
import xml.etree.ElementTree as ET
from unittest.mock import patch

import mujoco
import numpy as np
from actuation_measurement import named_force_samples
from audit_gpu_portable_search import validate_observation
from gpu_measurement_probe import write_new
from gpu_portable_search import observation_native,cpu_contacts
from gpu_quadruped_probe import check_capture
from motor_effectiveness_task import condition_inputs,condition_robot_view,validate_native_profile
from predictive_native_task_v1 import (ROOT,HERE,FLAGS,declaration,plans,initial_arrays,sha,require,
    provider,controller_contract,bridge,launch_records,frozen_model)
from predictive_native_task_v1 import controller_for
from causal_force_control import ForceController,terminal_error
from predictive_native_task_v1 import profile_for
from contact_force_measurement import ContactStepper,model_metadata
from run_gpu_measurement_probe import source_identity


def transfer_targets(row,data):
    require(terminal_error(row) is None,"Residual terminal provider failure")
    data.ctrl[:]=row["native_targets"]


def refusal_receipt(row,data,role):
    error=terminal_error(row)
    if error is None:return None
    require(role=="predictive_hold","Unexpected baseline refusal")
    before=data.ctrl.copy()
    try:transfer_targets(row,data)
    except ValueError:pass
    else:raise ValueError("Refused target reached native input")
    native=row["native_observation"]
    require(np.array_equal(before,data.ctrl) and np.array_equal(data.qpos,native["qpos"])
        and np.array_equal(data.qvel,native["qvel"]) and float(data.time)==native["time_s"],
        "Refusal changed native control/state/time")
    return dict(command=row["outer_step"],error=error,transferred=False,
        native_control=before.tolist(),qpos=data.qpos.tolist(),qvel=data.qvel.tolist(),time_s=float(data.time))



def run_hold_trial(directory,plan,c,core_path,core,population,artifact):
    directory.mkdir();tick=time.perf_counter()
    write_new(directory/"plan.json",plan)
    compiled,xml,spec=condition_inputs(core_path,c,plan["condition_id"])
    require(hashlib.sha256(xml.encode("utf-8")).hexdigest()==c["condition_model_sha256"][plan["condition_id"]],"Residual native XML")
    write_new(directory/"compiled.json",compiled);write_new(directory/"inputs.json",spec)
    with (directory/"model.xml").open("x",encoding="utf-8",newline="\n") as f:f.write(xml)
    frozen=provider.FrozenModel.load(core,artifact)
    with (directory/"provider-model.json").open("x",encoding="utf-8",newline="\n") as f:f.write(frozen.serialized)
    require(sha(directory/"provider-model.json")=="".join(frozen.sha256.split(":")[1:]),"Residual artifact file/model digest")
    restored=provider.FrozenModel.load(core,json.loads((directory/"provider-model.json").read_text(encoding="utf-8")))
    require(restored==frozen,"Residual native artifact reload")
    force_profile=profile_for(plan["role"],compiled,spec,xml)
    write_new(directory/"force-profile.json",force_profile)
    # Each role constructs its own model, data and controller; none is recycled.
    native_model=mujoco.MjModel.from_xml_string(xml);population["constructed_model_count"]+=1
    profile=validate_native_profile(native_model,spec)
    require(native_model.qpos0.tolist()==spec["initial_qpos"],"Residual native default pose")
    data=mujoco.MjData(native_model);population["constructed_cpu_worlds"]+=1
    write_new(directory/"world-opened.json",dict(trial_id=plan["trial_id"],native_data_constructed=True,
        core_sha256=sha(core_path),provider_model_sha256=frozen.sha256,force_profile_sha256=sha(directory/"force-profile.json")))
    data.qpos[:],data.qvel[:]=initial_arrays(spec,plan)
    robot=condition_robot_view(core,compiled,native_model,data,spec)
    for i,(motor,joint) in enumerate(zip(spec["ordered_actuators"],spec["ordered_joints"],strict=True)):
        named_force_samples(native_model,data,motor,joint)
        require([int(native_model.sensor_adr[native_model.sensor(motor+"_force").id]),
            int(native_model.sensor_adr[native_model.sensor(joint+"_actuator_force").id])]==[2*i,2*i+1],"Residual force sensor order")
    metadata=dict(model_sha256=sha(directory/"model.xml"),inputs_sha256=sha(directory/"inputs.json"),
        compiled_sha256=sha(directory/"compiled.json"),provider_model_sha256=frozen.sha256,
        condition_id=plan["condition_id"],actuator_profile=profile,force_profile_sha256=sha(directory/"force-profile.json"),
        ordered_bodies=[native_model.body(i).name for i in range(native_model.nbody)],
        body_rootid=native_model.body_rootid.tolist(),force_ranges=native_model.actuator_forcerange.tolist(),
        observation_stage="prepared_before_control",force_stage="completed_step_before_next_prepare",
        dynamics_dtype="float64",initial_values=c["initial_values"])
    write_new(directory/"native-model.json",metadata)
    observer_metadata=model_metadata(native_model,compiled,spec)
    write_new(directory/"contact-metadata.json",observer_metadata)
    observer=ContactStepper(mujoco,native_model,data,observer_metadata)
    controller=controller_for(plan["role"],core,compiled,c,frozen,plan["trial_id"],force_profile)
    result=dict(plan,setup_s=time.perf_counter()-tick,graph_capture_s=0.,
        outer_rows=0,internal_rows=0,completed=False,status="running",terminal_refusal=None,provider_model_sha256=frozen.sha256)
    try:
        with ExitStack() as outputs:
            outputs.callback(controller.close)
            streams={name:outputs.enter_context((directory/(name+".jsonl")).open("x",encoding="utf-8",newline="\n"))
                for name in ("controller","trace","timing","contact-force","contact-timing")}
            def append(name,row):
                stream=streams[name];serialized=json.dumps(row,allow_nan=False,separators=(",",":"))+"\n"
                if name=="controller":require(len(serialized.encode("utf-8"))<=c["maximum_controller_row_bytes"],"Predictive controller row byte bound")
                stream.write(serialized)
                require(stream.tell()<=c["maximum_trace_bytes_per_trial"],"Residual trace byte bound")
            for outer in range(c["outer_steps"]):
                whole=time.perf_counter();timing=dict(outer_step=outer,measured=True)
                tick=time.perf_counter();observer.prepare(5*outer+1);timing["prepare_s"]=time.perf_counter()-tick
                tick=time.perf_counter()
                state=robot.state_frame(outer,bridge._mujoco_to_canonical(spec["initial_qpos"][:3]))
                stability=robot.stability_state(outer);kinematics=robot.endpoint_kinematics(stability)
                native=observation_native(data,cpu_contacts(data,0));timing["observation_readback_s"]=time.perf_counter()-tick
                tick=time.perf_counter();row=controller.step(state,stability,kinematics);timing["portable_control_s"]=time.perf_counter()-tick
                tick=time.perf_counter()
                row.update(backend="cpu",cell=0,outer_step=outer,native_observation=native)
                validate_observation(row,metadata,compiled);append("controller",row);result["outer_rows"]+=1
                # Retain the original fallback receipt, but never step a failed
                # provider/host instance. This check precedes control transfer.
                refused=refusal_receipt(row,data,plan["role"])
                if refused is not None:
                    result.update(status="controller_refusal",terminal_refusal=refused)
                    timing.update(controller_capture_and_control_transfer_s=time.perf_counter()-tick,
                        integration_and_device_history_s=0.,internal_readback_and_capture_s=0.,
                        outer_total_s=time.perf_counter()-whole,transfer_performed=False)
                    append("timing",timing)
                    break
                transfer_targets(row,data)
                timing["transfer_performed"]=True
                timing["controller_capture_and_control_transfer_s"]=time.perf_counter()-tick
                integrate=capture=0.
                for sub in range(5):
                    tick=time.perf_counter()
                    if sub:observer.prepare(5*outer+sub+1)
                    before_pos,before_vel=data.qpos.copy(),data.qvel.copy()
                    contact_sample,contact_timing=observer.complete(5*outer+sub+1);integrate+=time.perf_counter()-tick
                    tick=time.perf_counter();forces=data.sensordata[::2].tolist();joints=data.sensordata[1::2].tolist()
                    sample=dict(backend="cpu",cell=0,step=5*outer+sub+1,
                        before_qpos=before_pos.tolist(),before_qvel=before_vel.tolist(),qpos=data.qpos.tolist(),qvel=data.qvel.tolist(),
                        ctrl=data.ctrl.tolist(),actuator_force_nm=forces,joint_force_nm=joints,
                        on_force_cap=[f<=lo or f>=hi for f,(lo,hi) in zip(forces,spec["force_ranges"],strict=True)],
                        time_s=float(data.time),contacts=cpu_contacts(data,0),batch_contacts=int(data.ncon),
                        nefc=int(data.nefc),overflow=0,warnings=[int(w.number) for w in data.warning])
                    require(sample["ctrl"]==row["native_targets"],"Residual held solver input")
                    check_capture(sample,c,spec["force_ranges"]);append("trace",sample);result["internal_rows"]+=1
                    serialize=time.perf_counter();append("contact-force",contact_sample)
                    contact_timing["serialization_s"]=time.perf_counter()-serialize
                    append("contact-timing",contact_timing)
                    capture+=time.perf_counter()-tick
                streams["controller"].flush();streams["trace"].flush()
                timing.update(integration_and_device_history_s=integrate,internal_readback_and_capture_s=capture,
                    outer_total_s=time.perf_counter()-whole);append("timing",timing)
            if result["terminal_refusal"] is None:
                require(result["outer_rows"]==c["outer_steps"],"Predictive complete trial denominator")
                result.update(completed=True,status="complete")
    except BaseException as exc:
        result["error"]=f"{type(exc).__name__}: {exc}"
        raise
    finally:
        controller.close()
        result["controller_closed"]=controller.session.closed
        result["hashes"]={name:sha(directory/(name+".jsonl")) for name in ("controller","trace","timing") if (directory/(name+".jsonl")).is_file()}
        result["contact_hashes"]={name:sha(directory/(name+".jsonl")) for name in ("contact-force","contact-timing") if (directory/(name+".jsonl")).is_file()}
        result["contact_metadata_sha256"]=sha(directory/"contact-metadata.json")
        write_new(directory/"result.json",result)
    print(json.dumps(dict(trial=plan["trial_id"],completed=result["completed"],status=result["status"],controller_rows=result["outer_rows"])),flush=True)
    return result
