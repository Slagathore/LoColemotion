"""Contained fresh CPU comparison of one frozen training-selected artifact."""
import argparse
from contextlib import ExitStack
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys
import time
from unittest.mock import patch

import mujoco
from actuation_measurement import named_force_samples
from audit_gpu_portable_search import validate_observation
from gpu_measurement_probe import write_new
from gpu_portable_search import observation_native,cpu_contacts
from gpu_quadruped_probe import check_capture
from motor_effectiveness_task import condition_inputs,condition_robot_view,validate_native_profile
from residual_selection_task import (ROOT,HERE,CONTRACT,FLAGS,declaration,all_plans,initial_arrays,sha,require,provider,controller_contract,bridge,load_stage,validate_launch_records,zero_policy,untrained_model,selection)
from residual_control import ResidualController
from run_gpu_measurement_probe import source_identity


def transfer_targets(row,data):
    require(row["residual"]["terminal_error"] is None,"Residual terminal provider failure")
    data.ctrl[:]=row["native_targets"]


def run_trial(directory,plan,c,core_path,core,population,artifact):
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
    # Each role constructs its own model, data and controller; none is recycled.
    native_model=mujoco.MjModel.from_xml_string(xml);population["constructed_model_count"]+=1
    profile=validate_native_profile(native_model,spec)
    require(native_model.qpos0.tolist()==spec["initial_qpos"],"Residual native default pose")
    data=mujoco.MjData(native_model);population["constructed_cpu_worlds"]+=1
    write_new(directory/"world-opened.json",dict(trial_id=plan["trial_id"],native_data_constructed=True,
        core_sha256=sha(core_path),provider_model_sha256=frozen.sha256))
    data.qpos[:],data.qvel[:]=initial_arrays(spec,plan)
    robot=condition_robot_view(core,compiled,native_model,data,spec)
    for i,(motor,joint) in enumerate(zip(spec["ordered_actuators"],spec["ordered_joints"],strict=True)):
        named_force_samples(native_model,data,motor,joint)
        require([int(native_model.sensor_adr[native_model.sensor(motor+"_force").id]),
            int(native_model.sensor_adr[native_model.sensor(joint+"_actuator_force").id])]==[2*i,2*i+1],"Residual force sensor order")
    metadata=dict(model_sha256=sha(directory/"model.xml"),inputs_sha256=sha(directory/"inputs.json"),
        compiled_sha256=sha(directory/"compiled.json"),provider_model_sha256=frozen.sha256,
        condition_id=plan["condition_id"],actuator_profile=profile,
        ordered_bodies=[native_model.body(i).name for i in range(native_model.nbody)],
        body_rootid=native_model.body_rootid.tolist(),force_ranges=native_model.actuator_forcerange.tolist(),
        observation_stage="prepared_before_control",force_stage="completed_step_before_next_prepare",
        dynamics_dtype="float64",initial_values=c["initial_values"])
    write_new(directory/"native-model.json",metadata)
    controller=ResidualController(core,compiled,controller_contract(c,frozen),frozen,plan["mode"],plan["trial_id"])
    result=dict(plan,setup_s=time.perf_counter()-tick,graph_capture_s=0.,
        outer_rows=0,internal_rows=0,completed=False,provider_model_sha256=frozen.sha256)
    try:
        with ExitStack() as outputs:
            outputs.callback(controller.close)
            streams={name:outputs.enter_context((directory/(name+".jsonl")).open("x",encoding="utf-8",newline="\n"))
                for name in ("controller","trace","timing")}
            def append(name,row):
                stream=streams[name];stream.write(json.dumps(row,allow_nan=False,separators=(",",":"))+"\n")
                require(stream.tell()<=c["maximum_trace_bytes_per_trial"],"Residual trace byte bound")
            for outer in range(c["outer_steps"]):
                whole=time.perf_counter();timing=dict(outer_step=outer,measured=True)
                tick=time.perf_counter();mujoco.mj_step1(native_model,data);timing["prepare_s"]=time.perf_counter()-tick
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
                transfer_targets(row,data)
                timing["controller_capture_and_control_transfer_s"]=time.perf_counter()-tick
                integrate=capture=0.
                for sub in range(5):
                    tick=time.perf_counter()
                    if sub:mujoco.mj_step1(native_model,data)
                    before_pos,before_vel=data.qpos.copy(),data.qvel.copy()
                    mujoco.mj_step2(native_model,data);integrate+=time.perf_counter()-tick
                    tick=time.perf_counter();forces=data.sensordata[::2].tolist();joints=data.sensordata[1::2].tolist()
                    sample=dict(backend="cpu",cell=0,step=5*outer+sub+1,
                        before_qpos=before_pos.tolist(),before_qvel=before_vel.tolist(),qpos=data.qpos.tolist(),qvel=data.qvel.tolist(),
                        ctrl=data.ctrl.tolist(),actuator_force_nm=forces,joint_force_nm=joints,
                        on_force_cap=[f<=lo or f>=hi for f,(lo,hi) in zip(forces,spec["force_ranges"],strict=True)],
                        time_s=float(data.time),contacts=cpu_contacts(data,0),batch_contacts=int(data.ncon),
                        nefc=int(data.nefc),overflow=0,warnings=[int(w.number) for w in data.warning])
                    require(sample["ctrl"]==row["native_targets"],"Residual held solver input")
                    check_capture(sample,c,spec["force_ranges"]);append("trace",sample);result["internal_rows"]+=1
                    capture+=time.perf_counter()-tick
                streams["controller"].flush();streams["trace"].flush()
                timing.update(integration_and_device_history_s=integrate,internal_readback_and_capture_s=capture,
                    outer_total_s=time.perf_counter()-whole);append("timing",timing)
            result["completed"]=True
    except BaseException as exc:
        result["error"]=f"{type(exc).__name__}: {exc}"
        raise
    finally:
        controller.close()
        result["controller_closed"]=controller.session.closed
        result["hashes"]={name:sha(directory/(name+".jsonl")) for name in ("controller","trace","timing") if (directory/(name+".jsonl")).is_file()}
        write_new(directory/"result.json",result)
    print(json.dumps(dict(trial=plan["trial_id"],completed=True,controller_rows=result["outer_rows"])),flush=True)
    return result


def preflight(core_path,baseline_path,lane):
    c=declaration(lane);plans=all_plans(c)
    require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"],"Residual training core images")
    require({k:importlib.metadata.version(k) for k in c["runtime"]}==c["runtime"],"Residual training runtime")
    prepared={}
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual training preflight opens no world")))
        for path in (core_path,baseline_path):
            core=bridge.LocomotionCore(path)
            for condition in sorted({p["condition_id"] for p in plans}):
                compiled,xml,spec=condition_inputs(path,dict(c,core_sha256=sha(path)),condition)
                require(hashlib.sha256(xml.encode("utf-8")).hexdigest()==c["condition_model_sha256"][condition]
                    and compiled["descriptor_sha256"]==c["descriptor_sha256"],"Residual training model identity")
                value=(compiled,xml,spec)
                require(condition not in prepared or prepared[condition]==value,"Residual training core compilation")
                prepared[condition]=value
                model=selection.verify_fit(core)[1]
                require(provider.FrozenModel.load(core,model.document())==model,"Residual training model round trip")
                for mode in provider.MODES:
                    controller=ResidualController(core,compiled,controller_contract(c,model),model,mode,"preflight_"+condition+"_"+mode)
                    controller.close();require(controller.session.closed,"Residual training preflight leaked session")
            for plan in plans:
                qpos,qvel=initial_arrays(prepared[plan["condition_id"]][2],plan)
                require(len(qpos)==15 and len(qvel)==14 and all(provider.ars.finite(x) for x in qpos+qvel),
                    "Residual training initial state")
    return dict(ok=True,lane=lane,world_build_count=0,solver_steps=0,planned_cpu_worlds=len(plans),planned_gpu_worlds=0,
        planned_controller_rows=len(plans)*c["outer_steps"],planned_internal_rows=len(plans)*c["outer_steps"]*5,
        runtime=c["runtime"],physical_acceptance_authority=False,training_data_authority=False)


def run(folder,permit,core_path,baseline_path,lane):
    sys.path.insert(0,str(ROOT/"sdk/conformance"));import r10v_windows_job as jobs
    require(permit.is_file() and jobs.current_in_job(),"Residual training execution requires containment")
    source=source_identity(True);c=declaration(lane)
    require(permit.resolve(strict=True)==folder.resolve(strict=True)/"contained.permit","Residual training permit path")
    validate_launch_records(folder,c,source);preflight(core_path,baseline_path,lane)
    core=bridge.LocomotionCore(core_path);claim,_,models=load_stage(folder.parent,c,core)
    training=folder.parent.name!="comparison"
    result=dict(schema_version="locolemotion_residual_selection_worker_v1",ok=False,synthetic=False,
        stage=folder.parent.name,stage_claim_sha256=sha(folder.parent/"stage.json"),ledger_scope=c["ledger_scope"],
        training_data_scope=c["training_data_scope"],trials=[],constructed_model_count=0,constructed_cpu_worlds=0,
        constructed_gpu_worlds=0,**{k:training and k=="training_data_authority" for k in FLAGS})
    started=time.perf_counter();stage="setup"
    try:
        for plan in claim["trials"]:
            stage=plan["trial_id"]
            result["trials"].append(run_trial(folder/stage,plan,c,core_path,core,result,models[plan["model_key"]].document()))
        result.update(ok=True,status="complete_native_selection_comparison")
    except BaseException as exc:
        result.update(error=f"{type(exc).__name__}: {exc}",failed_stage=stage,status="incomplete_or_refused_execution")
    finally:
        result["total_wall_s"]=time.perf_counter()-started
        write_new(folder/"worker-result.json",result)
    if not result["ok"]:raise RuntimeError(result["error"])
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--lane",choices=("comparison",),required=True)
    p.add_argument("--check-only",action="store_true");p.add_argument("--output",type=Path);p.add_argument("--permit",type=Path)
    args=p.parse_args()
    if args.check_only:print(json.dumps(preflight(args.core,args.baseline_core,args.lane)))
    else:
        require(args.output is not None and args.permit is not None,"Residual training output/permit required")
        run(args.output,args.permit,args.core,args.baseline_core,args.lane)
    return 0


if __name__=="__main__":raise SystemExit(main())
