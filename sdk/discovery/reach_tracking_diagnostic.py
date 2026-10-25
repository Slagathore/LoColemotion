"""Complete retained force-recovery diagnosis; no optimization or new worlds."""
import argparse
from collections import Counter
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import audit_support_reach_native_closure as parent
from audit_gpu_batch_execution import read_jsonl
from causal_force_policy import plain
from contact_force_observer_task import ROOT,HERE,read,sha,require
from gpu_measurement_probe import write_new
import actuation_recovery_mechanics as mechanics
import force_recovery_diagnostic_metrics as metrics
import reach_tracking_diagnostic_metrics as tracking
from support_reach_geometry import ReachModel
from audit_support_reach_component import native_clearances

CONTRACT=HERE/"reach_tracking_diagnostic_v1.json"
SOURCES=("reach_tracking_diagnostic_metrics.py","reach_tracking_diagnostic.py",
    "test_reach_tracking_diagnostic.py","run_reach_tracking_diagnostic.py")
CONTROLS=22
GATES=(("mechanics","test_force_recovery_diagnostic",14),("tracking","test_reach_tracking_diagnostic",8))
WINDOWS={"declared_diagnostic_prefix":(0,140),"post_handoff_diagnostic_prefix":(60,140),
    "shared_pre_failure_complete_commands":(60,133)}
DENIALS=("controller_selection_authority","comparison_data_used_for_fitting",
    "comparison_data_used_for_selection","alternative_trajectory_simulated","causal_generalization",
    "recovery_benefit_established","capability_estimated","dynamic_feasibility_established",
    "tier2_qualified","tier3_benefit_established","physical_acceptance_authority",
    "training_data_authority","release_authority","equivalence_authority")


def expected_contract():
    return dict(schema_version="locolemotion_reach_tracking_diagnostic_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_reach_tracking_diagnostic",question_class="development"),
        parent_closure_path=parent.CLOSURE.relative_to(ROOT).as_posix(),parent_closure_sha256=sha(parent.CLOSURE),
        implementation_bindings={name:sha(HERE/name) for name in SOURCES},controls_required=CONTROLS,
        expected_trials=4,expected_commands=560,expected_internal_samples=2800,
        expected_prepared_joint_entries=4480,expected_internal_motor_entries=22400,
        expected_force_policy_commands=320,expected_authority_loss_joint_entries=2560,
        windows={name:dict(commands_start_inclusive=a,commands_end_exclusive=b,
            internal_steps_start_inclusive=5*a+1,internal_steps_end_inclusive=5*b) for name,(a,b) in WINDOWS.items()},
        common_window_selected_after_original_outcomes=True,earliest_original_violation_step=667,
        common_window_ends_before_first_failure=True,complete_original_evidence_reopened=True,original_commands_per_trial=1440,original_internal_rows_per_trial=7200,
        diagnostic_prefix_commands_per_trial=140,diagnostic_window_selected_after_outcomes=True,geometry_tolerance_m=2e-10,
        post_failure_data_labeled_included_in_diagnostic_prefix_only=True,
        geometry_change_scope="exact fixed-morphology minimum-height identity: root translation plus orientation-dependent bounded reach",
        geometry_identity_is_not_dynamic_causal_attribution=True,
        individual_safe_windows_exclude_entire_first_failing_command=True,
        contact_wrench_scope="all signed robot contact forces and free torques about prepared whole-body COM",
        held_interval_wrench_scope="same forces additionally shifted to the original command-prepared COM",
        solver_geometry_scope="original contact geometry and qpos before integration; measured force from that solve",
        motor_scope="unit-gear affine force at each original before_qvel; no held-interval force guarantee",
        authority_loss_scope="telescoping absolute requested-torque error on nested instantaneous intervals",
        authority_loss_order=list(metrics.LOSS_NAMES),
        relaxed_bounds_scope="posthoc algebra on original states, not controller proposals or physical trials",
        static_joint_balance_scope="motor plus gravity plus contact torque; omits inertia, Coriolis, passive and limit terms",
        force_and_moment_statistics_have_separate_units=True,absolute_tolerance=1e-9,
        reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in DENIALS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Force diagnosis exact declaration")
    return c


def close(a,b,tolerance,label):
    a=np.asarray(a,dtype=float);b=np.asarray(b,dtype=float)
    require(a.shape==b.shape and np.isfinite(a).all() and np.isfinite(b).all()
        and np.all(np.abs(a-b)<=tolerance),label)
    return float(np.max(np.abs(a-b),initial=0.))


def window_summary(command_rows,internal_rows,start,end):
    commands=[r for r in command_rows if start<=r["command"]<end]
    samples=[r for r in internal_rows if 5*start<r["internal_step"]<=5*end]
    force=[r for r in commands if r["force_policy"] is not None]
    require(len(commands)==end-start and len(samples)==5*(end-start),"Force diagnosis complete window")
    stats=lambda name:metrics.vectors([r[name] for r in commands])
    force_stats=lambda name:metrics.vectors([r["force_policy"][name] for r in force])
    result=dict(commands=len(commands),internal_samples=len(samples),force_policy_commands=len(force),
        observed_support_counts=dict(sorted(Counter(str(len(r["support_contacts"])) for r in commands).items())),
        support_presence_commands={site:sum(site in r["support_contacts"] for r in commands)
            for site in ("front_left_foot","front_right_foot","rear_left_foot","rear_right_foot")},
        baseline_velocity_rad_s=stats("baseline_velocity_rad_s"),target_velocity_rad_s=stats("target_velocity_rad_s"),
        applied_residual_rad_s=stats("applied_residual_rad_s"),joint_position_rad=stats("joint_position_rad"),
        prepared_motor_torque_nm=stats("prepared_motor_torque_nm"),
        measured_contact_force_n=metrics.vectors([r["wrench_about_prepared_com"][:3] for r in samples]),
        measured_contact_moment_nm=metrics.vectors([r["wrench_about_prepared_com"][3:] for r in samples]),
        force_cap_samples=np.sum([r["on_force_cap"] for r in samples],axis=0).tolist(),
        original_provider_status_counts=dict(sorted(Counter(r["provider_status"] for r in commands).items())))
    result["force_policy"]=None if not force else dict(
        requested_torque_nm=force_stats("requested_torque_nm"),
        projected_torque_error_nm=force_stats("projected_torque_error_nm"),
        planned_force_error_n=force_stats("planned_force_error_n"),planned_moment_error_nm=force_stats("planned_moment_error_nm"),
        measured_minus_allocated_force_n=force_stats("measured_minus_allocated_force_n"),
        measured_minus_allocated_moment_nm=force_stats("measured_minus_allocated_moment_nm"),
        measured_minus_desired_force_n=force_stats("measured_minus_desired_force_n"),
        measured_minus_desired_moment_nm=force_stats("measured_minus_desired_moment_nm"),
        measured_static_joint_balance_nm=force_stats("measured_static_joint_balance_nm"),
        incremental_absolute_torque_error_nm={name:metrics.vectors([r["force_policy"]["authority_loss"]["incremental_absolute_error"][name]
            for r in force]) for name in metrics.LOSS_NAMES},
        instantaneous_requested_torque_reachable_commands_by_joint={name:np.sum([
            np.array(r["force_policy"]["authority_loss"]["absolute_errors"])[i]<=1e-9 for r in force],axis=0).tolist()
            for i,name in enumerate(metrics.LOSS_NAMES)})
    return result


def audit(evidence,core_path,baseline_path):
    c=declaration();verified=parent.verify_record(parent.CLOSURE,evidence,core_path,baseline_path)
    closure=read(parent.CLOSURE);attempt=parent.header(closure,evidence)
    original=read(attempt/"audit.json");trials=[];rows=[];internal=[]
    first=min(t["diagnostic_metrics"]["first_physical_violation"]["internal_step"] for t in original["trials"]
        if t["diagnostic_metrics"]["first_physical_violation"] is not None)
    require(first==c["earliest_original_violation_step"] and 5*WINDOWS["shared_pre_failure_complete_commands"][1]<first,
        "Force diagnosis common window includes failed state")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Force diagnosis opens no world")))
        for original_trial in original["trials"]:
            identity=original_trial["trial_id"];folder=attempt/"physical"/identity
            controls=list(read_jsonl(folder/"controller.jsonl"));samples=list(read_jsonl(folder/"contact-force.jsonl"))
            traces=list(read_jsonl(folder/"trace.jsonl"));profile=read(folder/"force-profile.json")
            require(len(controls)==1440 and len(samples)==len(traces)==7200,"Tracking complete original denominator")
            controls=controls[:140];samples=samples[:700];traces=traces[:700]
            tree=mechanics.RigidTree(profile["morphology_spec"]);reach=ReachModel(profile["morphology_spec"])
            metadata=read(folder/"native-model.json");anchor=None
            command_rows=[];sample_rows=[];transitions=[]
            errors=dict(motor_force_nm=0.,prepared_com_m=0.,allocated_wrench=0.,requested_torque_nm=0.,projected_torque_nm=0.,native_capsule_geometry_m=0.,geometry_decomposition_m=0.)
            command_frames=[];command_wrenches=[]
            for command,row in enumerate(controls):
                sample=samples[5*command];trace=traces[5*command];metrics.join_control(row,sample,trace,command)
                frame=metrics.prepared_frame(tree,sample["before_qpos"]);command_frames.append(frame)
                expected_com=metrics.C @ np.array(row["native_observation"]["subtree_com"][1])
                errors["prepared_com_m"]=max(errors["prepared_com_m"],close(frame["whole_body_com"],expected_com,c["absolute_tolerance"],"Force diagnostic native COM"))
                wrenches=metrics.robot_wrenches(sample);wrench=metrics.wrench_about(wrenches,frame["whole_body_com"])
                command_wrenches.append(wrench)
                state=row["request"]["state"];resolved=row["resolution"];commands=resolved["ordered_commands"]
                contacts=[x["contact_site_id"] for x in state["ordered_contact_observations"] if x["presence"] and x["bears_support"]]
                if not command_rows or command_rows[-1]["support_contacts"]!=contacts:
                    transitions.append(dict(command=command,time_s=row["native_observation"]["time_s"],support_contacts=contacts))
                value=dict(trial_id=identity,command=command,prepared_time_s=sample["prepared_time_s"],
                    first_solve_completed_time_s=sample["integrated_time_s"],support_contacts=contacts,
                    baseline_velocity_rad_s=[x["baseline_canonical_target_velocity_rad_s"] for x in commands],
                    target_velocity_rad_s=row["native_targets"],applied_residual_rad_s=[x["applied_correction_rad_s"] for x in commands],
                    joint_position_rad=[x["position_rad"] for x in state["ordered_joint_observations"]],
                    prepared_motor_torque_nm=trace["actuator_force_nm"],provider_status=resolved["provider_status"],force_policy=None)
                if "force_reference" in row:
                    d=row["force_reference"]["decision"];projection=d["projection"]
                    require(command>=60 and resolved["provider_status"]=="applied","Force diagnosis original candidate status")
                    close(d["com"],frame["whole_body_com"],c["absolute_tolerance"],"Force diagnosis planner origin")
                    sites={s["contact_site_id"]:s["body_id"] for s in tree.spec["contact_sites"]}
                    packet=row["resolution_request"]["provider_request"]["controller_context"]["controller_memory"]["contact_packet"]
                    active=[r for r in packet["ordered_contacts"] if r["presence"] and r["bears_support"]]
                    require([r["contact_site_id"] for r in active]==d["active_contacts"],"Force diagnosis allocated contact order")
                    allocated=[dict(body_id=sites[r["contact_site_id"]],point=mechanics.xyz(r["point_world_m"]),force=f,torque=[0.,0.,0.])
                        for r,f in zip(active,d["allocation"]["forces"],strict=True)]
                    planned=metrics.wrench_about(allocated,frame["whole_body_com"])
                    errors["allocated_wrench"]=max(errors["allocated_wrench"],close(planned,d["allocation"]["wrench"],c["absolute_tolerance"],"Force diagnosis allocated wrench"))
                    gravity=tree.gravity_torques(frame,[0.,-9.8,0.])
                    request=-gravity+np.array(d["posture_torque"])-tree.wrench_torques(frame,allocated)
                    errors["requested_torque_nm"]=max(errors["requested_torque_nm"],close(request,projection["requested_torque"],c["absolute_tolerance"],"Force diagnosis requested torque"))
                    loss=metrics.decompose_loss(request,metrics.authority_intervals(row,profile))
                    errors["projected_torque_nm"]=max(errors["projected_torque_nm"],close(loss["projections"][-1],trace["actuator_force_nm"],c["absolute_tolerance"],"Force diagnosis projected/native torque"))
                    desired=np.array(d["desired_wrench"])
                    value["force_policy"]=plain(dict(requested_torque_nm=request,authority_loss=loss,
                        projected_torque_error_nm=np.array(trace["actuator_force_nm"])-request,
                        planned_force_error_n=(planned-desired)[:3],planned_moment_error_nm=(planned-desired)[3:],
                        measured_minus_allocated_force_n=(wrench-planned)[:3],measured_minus_allocated_moment_nm=(wrench-planned)[3:],
                        measured_minus_desired_force_n=(wrench-desired)[:3],measured_minus_desired_moment_nm=(wrench-desired)[3:],
                        measured_static_joint_balance_nm=np.array(trace["actuator_force_nm"])+gravity+tree.wrench_torques(frame,wrenches)))
                pose=state["base_pose_world"];position=mechanics.xyz(pose["position_m"])
                quaternion=[pose["orientation_xyzw"][k] for k in "xyzw"]
                reach_values=reach.evaluate(position,quaternion,value["joint_position_rad"])
                measured=native_clearances(metadata,row,reach)
                for foot,height in zip(reach_values,measured,strict=True):
                    errors["native_capsule_geometry_m"]=max(errors["native_capsule_geometry_m"],
                        close([foot["current_clearance_m"]],[height],c["geometry_tolerance_m"],"Tracking native capsule join"))
                if command==60:anchor=(float(position[1]),[r["minimum_clearance_m"] for r in reach_values])
                candidate=None
                if command>=60:
                    d=row["force_reference"]["decision"]
                    for i,foot in enumerate(reach_values):
                        change=tracking.geometry_change(float(position[1]),foot["minimum_clearance_m"],
                            foot["current_clearance_m"],anchor[0],anchor[1][i],foot["current_joint_positions_within_bounds"])
                        errors["geometry_decomposition_m"]=max(errors["geometry_decomposition_m"],close(
                            [change["minimum_clearance_change_m"]],[change["root_translation_contribution_m"]+
                            change["orientation_and_bounded_reach_contribution_m"]],c["geometry_tolerance_m"],"Tracking exact geometric identity"))
                        foot["change_from_handoff"]=change
                    if original_trial["role"]=="reach_hold":
                        require(d["support_reach"]==[{k:v for k,v in x.items() if k!="change_from_handoff"} for x in reach_values],
                            "Tracking actual candidate geometry")
                        reference=d["support_reference"]
                        close([reference["target_com_height_m"]],[d["target_com"][1]],c["absolute_tolerance"],"Tracking reference/target join")
                        candidate=dict(reference,floor_reached=abs(reference["target_com_height_m"]-reference["reference_floor_m"])<=1e-12)
                    else:require(original_trial["role"]=="force_hold" and "support_reference" not in d,"Tracking original role boundary")
                    value["reach_tracking"]=dict(root_height_m=float(position[1]),com_height_m=float(frame["whole_body_com"][1]),
                        target_com_height_m=d["target_com"][1],com_height_error_m=float(frame["whole_body_com"][1]-d["target_com"][1]),
                        orientation_vector_rad=tracking.orientation_vector(quaternion),feet=reach_values,candidate_reference=candidate)
                else:
                    value["reach_tracking"]=dict(root_height_m=float(position[1]),com_height_m=float(frame["whole_body_com"][1]),
                        orientation_vector_rad=tracking.orientation_vector(quaternion),feet=reach_values,
                        target_com_height_m=None,com_height_error_m=None,candidate_reference=None)
                command_rows.append(value)
            for index,(sample,trace) in enumerate(zip(samples,traces,strict=True)):
                command=index//5;frame=metrics.prepared_frame(tree,sample["before_qpos"])
                require(sample["step"]==trace["step"]==index+1 and sample["before_qpos"]==trace["before_qpos"]
                    and sample["before_qvel"]==trace["before_qvel"] and sample["ctrl"]==trace["ctrl"]==controls[command]["native_targets"],
                    "Force diagnosis complete internal state/input join")
                predicted=mechanics.motor_torque(trace["ctrl"],sample["before_qvel"][6:],profile["velocity_gains"],profile["force_ranges"])
                errors["motor_force_nm"]=max(errors["motor_force_nm"],close(predicted,trace["actuator_force_nm"],c["absolute_tolerance"],"Force diagnosis original motor force"))
                wrenches=metrics.robot_wrenches(sample)
                sample_rows.append(plain(dict(trial_id=identity,internal_step=index+1,command=command,
                    prepared_time_s=sample["prepared_time_s"],integrated_time_s=sample["integrated_time_s"],
                    wrench_about_prepared_com=metrics.wrench_about(wrenches,frame["whole_body_com"]),
                    wrench_about_command_com=metrics.wrench_about(wrenches,command_frames[command]["whole_body_com"]),
                    measured_motor_torque_nm=trace["actuator_force_nm"],on_force_cap=trace["on_force_cap"])))
            failure=original_trial["diagnostic_metrics"]["first_physical_violation"]
            own_end=tracking.safe_command_end(failure)
            require(own_end>=133,"Tracking original safe interval")
            windows={name:dict(window_summary(command_rows,sample_rows,a,b),
                command_start_inclusive=a,command_end_exclusive=b,
                includes_original_failure=failure is not None and 5*b>=failure["internal_step"],
                reach_tracking=None if a<60 else tracking.tracking_summary(command_rows,a,b)) for name,(a,b) in WINDOWS.items()}
            windows["individual_pre_failure_complete_commands"]=dict(window_summary(command_rows,sample_rows,60,own_end),
                command_start_inclusive=60,command_end_exclusive=own_end,includes_original_failure=False,
                censored_at_diagnostic_prefix=failure is None,
                reach_tracking=tracking.tracking_summary(command_rows,60,own_end))
            trials.append(dict(trial_id=identity,ordered_actuators=profile["ordered_actuators"],
                original_failure=original_trial["diagnostic_metrics"]["first_physical_violation"],
                original_diagnostic_failure_codes=original_trial["diagnostic_failure_codes"],
                source_controller_sha256=sha(folder/"controller.jsonl"),source_contact_sha256=sha(folder/"contact-force.jsonl"),
                source_trace_sha256=sha(folder/"trace.jsonl"),force_profile_sha256=sha(folder/"force-profile.json"),
                maximum_reconstruction_errors=errors,support_transitions=transitions,windows=windows))
            rows.extend(command_rows);internal.extend(sample_rows)
    require(len(rows)==560 and len(internal)==2800 and sum(r["force_policy"] is not None for r in rows)==320,
        "Force diagnosis final population")
    return dict(schema_version="locolemotion_reach_tracking_diagnostic_audit_v1",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_closure_sha256=sha(parent.CLOSURE),
        parent_reconstruction_verified=verified["ok"],parent_reconstruction_sha256=hashlib.sha256(json.dumps(verified,
            sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",trials=trials,command_rows=rows,internal_rows=internal,
        controller_rows=560,internal_samples=2800,prepared_joint_entries=4480,internal_motor_entries=22400,
        force_policy_commands=320,authority_loss_joint_entries=2560,
        reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();value=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,value);print(json.dumps(dict(ok=True,controller_rows=560,internal_samples=2800,worlds_opened=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
