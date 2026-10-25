"""Complete retained-state, two-core verification of configured dynamic commands."""
import argparse,copy,json
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import actuation_recovery_mechanics as m
import dynamic_inverse_dynamics_v2 as dynamic
from dynamic_qp_solver_v2 import certificate,problem_digest
from floating_base_dynamics import FloatingDynamics
from floating_base_dynamics_inputs import native_parameters
from floating_dynamics_oracle_math import canonical_state
from support_reach_geometry import ReachModel,support_reference
from dynamic_force_policy_v2 import make_profile,HANDOFF
from dynamic_hold_control_v2 import DynamicHoldController
from dynamic_control_component_task_v4 import *
from hold_horizon_task import bridge,controller_contract,frozen_model,declaration as hold_declaration
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_contact_posture_component import Stream
from causal_force_control import terminal_error
from gpu_measurement_probe import write_new


def close(a,b,label,tolerance=1e-11):
    a=np.asarray(a);b=np.asarray(b)
    require(a.shape==b.shape and np.isfinite(a).all() and np.isfinite(b).all()
        and np.max(np.abs(a-b),initial=0.)<=tolerance,"Dynamic reader "+label)


def verify_row(row,original,previous,profile,model,reach,nominal):
    step=original["outer_step"]
    require(row["request"]["state"]==original["request"]["state"] and row["stability"]==original["stability"]
        and row["kinematics"]==original["kinematics"],"Dynamic original observations unchanged")
    if step<HANDOFF:
        require(all(same_bits(v,original[k]) for k,v in row.items()),"Dynamic unchanged prefix")
        return None
    require(terminal_error(row) is None,"Dynamic successful command")
    request=row["resolution_request"]["provider_request"];d=row["force_reference"]["decision"];allocation=d["allocation"]
    position,quaternion,joints,velocity,gravity=canonical_state(row)
    frame=model.tree.kinematics(position,quaternion,joints);com=frame["whole_body_com"]
    contacts=request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
    opaque=request["provider_memory"]["opaque_state"]
    target=np.array([com[0],nominal,com[2]]) if step==HANDOFF else np.array(opaque["target_com"])
    before_height=float(target[1]);reaches=reach.evaluate(position,quaternion,joints)
    reference=support_reference(reaches,{r["contact_site_id"]:r["presence"] and r["bears_support"] for r in contacts},
        float(position[1]),float(com[1]),nominal,before_height,profile["reference_parameters"])
    target[1]=reference["target_com_height_m"]
    require(reference==d["support_reference"] and reaches==d["support_reach"]
        and nominal-.10-1e-12<=target[1]<=before_height+1e-12
        and before_height-target[1]<=.20/120.+1e-12,"Dynamic reference reconstruction/rate")
    close(target,d["target_com"],"target");close(com,d["com"],"COM")
    items,active=dynamic.tasks(model,frame,velocity,quaternion,contacts,target,
        np.array(reference["reference_joint_positions_rad"])-joints,profile["parameters"]["dynamic"])
    baseline=request["deterministic_baseline"]["ordered_commands"];limits=request["safety_envelope"]["ordered_actuator_limits"]
    require(not request["deterministic_baseline"]["safe_no_actuation"] and d["projection_applies_to_transfer"] is True,
        "Dynamic active transfer domain")
    require(row["request"]["memory"]==previous["output"]["next_memory"],"Dynamic baseline memory continuity")
    require(request["history"]["ordered_entries"][-1]["semantic_step"]==step-1,"Dynamic history clock")
    for before,command,limit in zip(previous["resolution"]["ordered_commands"],row["resolution"]["ordered_commands"],limits,strict=True):
        prior=before["applied_correction_rad_s"]
        require(limit["previous_applied_correction_rad_s"]==prior and limit["maximum_absolute_correction_rad_s"]==3.5
            and limit["maximum_slew_per_step_rad_s"]==.08 and abs(command["applied_correction_rad_s"]-prior)<=.08+1e-12
            and abs(command["applied_correction_rad_s"])<=3.5 and abs(command["final_canonical_target_velocity_rad_s"])<=3.5,
            "Dynamic actual resolved bounds/history")
    envelope=m.command_envelope([r["combined_canonical_target_velocity_rad_s"] for r in baseline],
        [r["maximum_target_speed_rad_s"] for r in baseline],[r["previous_applied_correction_rad_s"] for r in limits],
        [r["maximum_absolute_correction_rad_s"] for r in limits],[r["maximum_slew_per_step_rad_s"] for r in limits])
    lower,upper=m.torque_envelope(envelope,velocity[6:],profile["velocity_gains"],profile["force_ranges"])
    qp=dynamic.problem(model,frame,velocity,gravity,items,active,lower,upper,profile["parameters"]["dynamic"])
    solver=allocation["solver"];x=np.array(solver["x"]);y=np.array(solver["y"])
    cert=certificate(qp["P"],qp["q"],qp["A"],qp["lower"],qp["upper"],x,y)
    require(cert["accepted"] and cert==solver["certificate"] and solver["accepted"] is True and solver["status_value"]==1
        and solver["problem_sha256"]==problem_digest(qp["P"],qp["q"],qp["A"],qp["lower"],qp["upper"]),
        "Dynamic independent problem and KKT certificate")
    n,k=model.size,len(active)
    close(x[:n],allocation["acceleration"],"solution acceleration")
    forces=x[n:n+3*k].reshape(k,3);torque=x[n+3*k:]
    close(forces,np.asarray(allocation["forces"]).reshape(k,3),"solution forces");close(torque,allocation["requested_torque"],"solution torque")
    require(allocation["active_contacts"]==d["active_contacts"]==[r["contact_site_id"] for r in active],
        "Dynamic exact supporting population")
    for task in items:
        name=task["name"]
        close(task["target"],allocation["task_targets"][name],"task target")
        close(task["bias"],allocation["task_biases"][name],"task bias")
        close(task["jacobian"] @ x[:n]+task["bias"]-task["target"],allocation["task_errors"][name],"task error")
    for fx,fy,fz in forces:
        require(-2e-6<=fy<=70.+2e-6 and max(abs(fx),abs(fz))<=.95/np.sqrt(2.)*fy+2e-6,"Dynamic independent force bounds")
    targets=np.array([r["final_canonical_target_velocity_rad_s"] for r in row["resolution"]["ordered_commands"]])
    close(targets,d["projection"]["target"],"exact public resolver target",0.)
    actual=m.motor_torque(targets,velocity[6:],profile["velocity_gains"],profile["force_ranges"])
    close(actual,torque,"actual motor torque",2e-6)
    wrenches=[dict(body_id=r["body_id"],point=r["point"],force=f,torque=np.zeros(3))
        for r,f in zip(active,forces,strict=True)]
    # Recursive inverse dynamics and point wrenches check the matrix-equation solve separately.
    residual=model.inverse_dynamics(frame,velocity,x[:n],gravity)-model.passive_force(velocity)
    residual-=model.generalized_wrenches(frame,wrenches)+np.r_[np.zeros(6),actual]
    require(np.max(np.abs(residual))<=4e-6,"Dynamic independent transferred equations")
    close(residual,allocation["transferred_dynamics_residual"],"reported transferred equations")
    require(allocation["contact_acceleration_is_soft_task"] is True and allocation["instantaneous_equations_satisfied"] is True
        and all(allocation[k] is False for k in ("dynamic_feasibility_established","held_contact_guaranteed","physical_acceptance_authority"))
        and d["current_solve_force_consumed"] is False and d["capability_estimated"] is False,"Dynamic bounded authority")
    return dict(maximum_equation_residual=float(np.max(np.abs(residual))),maximum_bound_violation=cert["maximum_bound_violation"],
        maximum_stationarity_error=cert["maximum_stationarity_error"],maximum_complementarity_error=cert["maximum_complementarity_error"],
        iterations=solver["iterations"],active_contacts=k)


def audit(core_path,baseline_path,output):
    c=declaration();verified=verify_inputs(c);output.mkdir();trials=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_fwdPosition","mj_fwdVelocity"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Dynamic reader opens no worlds")))
        for identity,count in TRIALS:
            folder=EVIDENCE/ORIGINAL/"physical"/identity
            compiled=read(folder/"compiled.json");profile=make_profile(compiled,read(folder/"inputs.json"))
            native=native_parameters((folder/"model.xml").read_text(encoding="utf-8"),profile["morphology_spec"])
            require(native["joint_inertia_kg_m2"]==profile["parameters"]["joint_inertia_kg_m2"],"Dynamic configured/native joint inertia")
            model=FloatingDynamics(profile["morphology_spec"],native["joint_inertia_kg_m2"]);reach=ReachModel(profile["morphology_spec"])
            nominal=float(model.tree.kinematics([0.,profile["reference_root_height_m"],0.],[0.,0.,0.,1.],[0.]*8)["whole_body_com"][1])
            write_new(output/(identity+"-profile.json"),profile)
            hosts=[];streams=[];previous=[None,None];summaries=[];maximum={};hist={};completed=0;checked=0
            try:
                for index,core_file in enumerate((core_path,baseline_path)):
                    core=bridge.LocomotionCore(core_file);frozen=frozen_model(core)
                    hosts.append(DynamicHoldController(core,compiled,controller_contract(hold_declaration(),frozen),frozen,identity,profile))
                    streams.append(Stream(output/(identity+"-core-"+str(index)+".jsonl"),c["maximum_stream_bytes"]))
                for step,original in enumerate(read_jsonl(folder/"controller.jsonl")):
                    require(step<count and step==original["outer_step"]==original["request"]["state"]["semantic_step"],"Dynamic full original clock")
                    rows=[]
                    for i,host in enumerate(hosts):
                        row=host.step(copy.deepcopy(original["request"]["state"]),copy.deepcopy(original["stability"]),copy.deepcopy(original["kinematics"]))
                        streams[i].append(dict(synthetic=True,alternative_actions_generated_observations=False,controller=row))
                        require(terminal_error(row) is None,f"Dynamic terminal refusal {identity} command {step}: {terminal_error(row)}")
                        report=verify_row(row,original,previous[i],profile,model,reach,nominal)
                        if report:
                            checked+=1
                            for key in ("maximum_equation_residual","maximum_bound_violation","maximum_stationarity_error","maximum_complementarity_error","iterations"):
                                maximum[key]=max(maximum.get(key,0),report[key])
                            key=str(report["active_contacts"]);hist[key]=hist.get(key,0)+1
                        rows.append(row);previous[i]=row
                    require(same_bits(rows[0],rows[1]),"Dynamic every row exact other-core identity");completed+=1
                require(completed==count and checked==2*(count-HANDOFF)
                    and all(h.next_step==count and h.force_memory["sequence"]==count-HANDOFF for h in hosts),"Dynamic full synthetic population")
            finally:
                for host in hosts:host.close()
                for stream in streams:summaries.append(stream.close())
            require(all(h.closed for h in hosts) and summaries[0]["sha256"]==summaries[1]["sha256"],"Dynamic closed complete identical streams")
            trials.append(dict(trial_id=identity,original_commands=count,post_handoff_commands=count-HANDOFF,
                synthetic_commands=2*count,checked_optimizations=checked,streams=summaries,maximum_errors=maximum,
                active_contact_count_histogram=hist,profile_sha256=sha(output/(identity+"-profile.json")),
                original_controller_sha256=sha(folder/"controller.jsonl"),original_terminal_state_included=identity.startswith("posture_")))
    return dict(schema_version="locolemotion_dynamic_control_component_audit_v4",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),verified_inputs=verified,trials=trials,commands=2671,synthetic_commands=5342,
        checked_optimizations=5102,core_reconstructions=2,unchanged_prefix_commands=120,synthetic=True,
        contact_acceleration_is_soft_task=True,world_build_count=0,solver_steps=0,**{k:False for k in FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    result=audit(a.core,a.baseline_core,a.output.with_suffix(""));write_new(a.output,result)
    print(json.dumps(dict(ok=True,commands=2671,checked_optimizations=5102,world_build_count=0,solver_steps=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
