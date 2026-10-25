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
import audit_contact_posture_failure as parent
import posture_tracking_diagnostic_metrics as posture_metrics
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_contact_posture_failure import inventory
from run_residual_native import verify_tests
from audit_gpu_batch_execution import read_jsonl
from causal_force_policy import plain
from contact_force_observer_task import ROOT,HERE,read,sha,require
from gpu_measurement_probe import write_new
import actuation_recovery_mechanics as mechanics
import force_recovery_diagnostic_metrics as metrics
import reach_tracking_diagnostic_metrics as tracking
from support_reach_geometry import ReachModel
from audit_support_reach_component import native_clearances

CONTRACT=HERE/"posture_tracking_diagnostic_v1.json"
PARENT_RESULT=HERE/"contact_posture_failure_result_v1.json"
PARENT_SHA="ca6348ed7abfb102af29e4717c46b26177bb5dc9fe8ae8b6601ca88f8757e900"
SOURCES=("posture_tracking_diagnostic_metrics.py","posture_tracking_diagnostic.py",
    "test_posture_tracking_diagnostic.py","run_posture_tracking_diagnostic.py")
CONTROLS=34
GATES=(("mechanics","test_force_recovery_diagnostic",14),("tracking","test_reach_tracking_diagnostic",8),
    ("posture","test_posture_tracking_diagnostic",12))
WINDOWS={"declared_safe_prefix":(0,126),"shared_post_handoff_safe_commands":(60,126)}
DENIALS=("controller_selection_authority","comparison_data_used_for_fitting",
    "comparison_data_used_for_selection","alternative_trajectory_simulated","causal_generalization",
    "recovery_benefit_established","capability_estimated","dynamic_feasibility_established",
    "tier2_qualified","tier3_benefit_established","physical_acceptance_authority",
    "training_data_authority","release_authority","equivalence_authority")


def expected_contract():
    return dict(schema_version="locolemotion_posture_tracking_diagnostic_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_posture_tracking_diagnostic",question_class="development"),
        parent_result_path=PARENT_RESULT.relative_to(ROOT).as_posix(),parent_result_sha256=PARENT_SHA,
        implementation_bindings={name:sha(HERE/name) for name in SOURCES},
        inherited_bindings={name:sha(HERE/name) for name in
            ("force_recovery_diagnostic_metrics.py","reach_tracking_diagnostic_metrics.py","reach_tracking_diagnostic.py",
             "actuation_recovery_mechanics.py","support_reach_geometry.py","audit_support_reach_component.py")},
        controls_required=CONTROLS,expected_trials=2,expected_commands=252,expected_internal_samples=1260,
        expected_prepared_joint_entries=2016,expected_internal_motor_entries=10080,
        expected_force_policy_commands=132,expected_authority_loss_joint_entries=1056,
        windows={name:dict(commands_start_inclusive=a,commands_end_exclusive=b,
            internal_steps_start_inclusive=5*a+1,internal_steps_end_inclusive=5*b) for name,(a,b) in WINDOWS.items()},
        window_selected_after_original_outcomes=True,earliest_original_violation_step=633,
        full_retained_population_reopened=True,original_controller_rows=[1440,1231],
        original_internal_rows=[7200,6150],post_failure_states_in_diagnostic=False,
        prefix_commands_per_trial=126,common_post_handoff_commands_per_trial=66,
        terminal_failure_is_separate=True,geometry_tolerance_m=2e-10,absolute_tolerance=1e-9,
        contact_wrench_scope="signed robot contact forces/free torques about prepared whole-body COM",
        motor_scope="affine unit-gear torque at each original before_qvel",
        authority_loss_scope="telescoping absolute torque error on nested instantaneous intervals",
        authority_loss_order=list(metrics.LOSS_NAMES),
        static_balance_omissions=["inertia","Coriolis","passive","joint limits"],
        virtual_root_reference_is_actuated=False,joint_reference_has_one_step_deadline=False,
        material_point_scope="same material point from prepared supporting contact to end of original five-step command",
        posture_virtual_and_actual_displacements_have_different_semantics=True,
        post_handoff_states_differ=True,descriptive_pair_statistics_are_not_causal_attribution=True,
        force_and_moment_statistics_have_separate_units=True,reader_world_build_count=0,reader_solver_steps=0,
        **{k:False for k in DENIALS})


def verify_parent(evidence,core_path,baseline_path):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Posture parent result bytes")
    result=read(PARENT_RESULT);parent.declaration()
    name=result["verification_attempt"]
    require(Path(name).name==name and name.startswith("sdk2-contact-posture-failure-controls-"),
        "Posture parent verification path")
    folder=evidence/name;r=read(folder/"receipt.json");declared=read(folder/"declaration.json")
    require(result["contract_sha256"]==sha(parent.CONTRACT)
        and result["receipt_sha256"]==sha(folder/"receipt.json")
        and r["ok"] is True and r["source_runtime_unchanged"] is True
        and r["controls_passed"]==result["controls_passed"]==12
        and r["worlds_opened"]==r["solver_steps"]==0
        and result["declaration_sha256"]==r["declaration_sha256"]==sha(folder/"declaration.json")
        and r["contract"]==declared["contract"]==parent.declaration()
        and len(declared["binding"]["source"])==r["source_binding_count"]==699
        and len(declared["binding"]["runtime"])==r["runtime_binding_count"]==1359
        and all(result[k] is False for k in parent.DENIALS),"Posture parent proof/authority")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    verify_tests(folder/"failure-controls",12)
    old=read(folder/"audit.json")
    require(old==read(folder/"reconstruction.json")==result["native_evidence"]
        and sha(folder/"audit.json")==r["audit_sha256"]==result["audit_sha256"]
        and sha(folder/"reconstruction.json")==r["reconstruction_sha256"]==result["reconstruction_sha256"],
        "Posture parent reconstruction identities")
    verified=parent.audit(evidence,core_path,baseline_path)
    require(verified==old,"Posture complete original failure reconstruction")
    return verified

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Force diagnosis exact declaration")
    return c


def close(a,b,tolerance,label):
    a=np.asarray(a,dtype=float);b=np.asarray(b,dtype=float)
    require(a.shape==b.shape and np.isfinite(a).all() and np.isfinite(b).all()
        and np.all(np.abs(a-b)<=tolerance),label)
    return float(np.max(np.abs(a-b),initial=0.))


def window_summary(command_rows,internal_rows,start,end):
    from reach_tracking_diagnostic import window_summary as original_summary
    result=original_summary(command_rows,internal_rows,start,end)
    selected=[r for r in command_rows if start<=r["command"]<end and r["force_policy"] is not None]
    snapshots=[r["posture_tracking"] for r in selected]
    result["posture_tracking"]=dict(commands=len(snapshots),
        statuses=dict(sorted(Counter(r["status"] for r in snapshots).items())),
        fixed_joint_reference_distance_decreased_commands=sum(r["joint_tracking"]["distance_to_fixed_reference_decreased"] for r in snapshots),
        initial_joint_reference_error_rad=metrics.vectors([r["joint_tracking"]["initial_error_rad"] for r in snapshots]),
        actual_joint_delta_rad=metrics.vectors([r["joint_tracking"]["actual_delta_rad"] for r in snapshots]),
        posture_torque_nm=metrics.vectors([r["posture_torque_nm"] for r in snapshots]),
        actual_material_point_displacement_m=metrics.vectors([[r["maximum_actual_material_point_displacement_m"]] for r in snapshots]),
        virtual_material_point_displacement_m=metrics.vectors([[r["virtual_reference"]["maximum_contact_displacement_m"]]
            for r in snapshots if r["virtual_reference"] is not None]),
        endpoints=[dict(command=r["command"],snapshot=r["posture_tracking"]) for r in (selected[0],selected[-1])],
        virtual_root_is_actuated=False,joint_reference_has_one_step_deadline=False)
    result["wrench_targets_and_observations"]={name:metrics.vectors([r["force_policy"][name] for r in selected])
        for name in ("desired_force_n","desired_moment_nm","allocated_force_n","allocated_moment_nm",
                     "first_measured_force_n","first_measured_moment_nm")}
    return result

def audit(evidence,core_path,baseline_path):
    c=declaration();verified=verify_parent(evidence,core_path,baseline_path)
    attempt=evidence/parent.ATTEMPT;original=verified;trials=[];rows=[];internal=[]
    posture_metrics.validate_window([t["diagnostic_metrics"]["first_physical_violation"] for t in original["trials"]],60,126)
    first=min(t["diagnostic_metrics"]["first_physical_violation"]["internal_step"] for t in original["trials"]
        if t["diagnostic_metrics"]["first_physical_violation"] is not None)
    require(first==c["earliest_original_violation_step"] and 5*WINDOWS["shared_post_handoff_safe_commands"][1]<first,
        "Force diagnosis common window includes failed state")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Force diagnosis opens no world")))
        for original_trial in original["trials"]:
            identity=original_trial["trial_id"];folder=attempt/"physical"/identity
            controls=list(read_jsonl(folder/"controller.jsonl"));samples=list(read_jsonl(folder/"contact-force.jsonl"))
            traces=list(read_jsonl(folder/"trace.jsonl"));profile=read(folder/"force-profile.json")
            require(len(controls)==original_trial["controller_rows"] and len(samples)==len(traces)==original_trial["internal_rows"],"Tracking complete original denominator")
            controls=controls[:126];samples=samples[:630];traces=traces[:630]
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
                    value["posture_tracking"]=plain(posture_metrics.posture_snapshot(row,traces[5*command+4],tree,profile))
                    value["force_policy"]=plain(dict(requested_torque_nm=request,authority_loss=loss,
                        desired_force_n=desired[:3],desired_moment_nm=desired[3:],
                        allocated_force_n=planned[:3],allocated_moment_nm=planned[3:],
                        first_measured_force_n=wrench[:3],first_measured_moment_nm=wrench[3:],
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
                    if original_trial["role"] in ("reach_hold","posture_hold"):
                        require(d["support_reach"]==[{k:v for k,v in x.items() if k!="change_from_handoff"} for x in reach_values],
                            "Tracking actual candidate geometry")
                        reference=d["support_reference"]
                        close([reference["target_com_height_m"]],[d["target_com"][1]],c["absolute_tolerance"],"Tracking reference/target join")
                        candidate=dict(reference,floor_reached=abs(reference["target_com_height_m"]-reference["reference_floor_m"])<=1e-12)
                    else:raise ValueError("Posture diagnostic role boundary")
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
            require(tracking.safe_command_end(failure)>=126,"Posture original safe interval")
            windows={name:dict(window_summary(command_rows,sample_rows,a,b),
                command_start_inclusive=a,command_end_exclusive=b,
                includes_original_failure=failure is not None and 5*b>=failure["internal_step"],
                reach_tracking=None if a<60 else tracking.tracking_summary(command_rows,a,b)) for name,(a,b) in WINDOWS.items()}
            trials.append(dict(trial_id=identity,ordered_actuators=profile["ordered_actuators"],
                original_failure=original_trial["diagnostic_metrics"]["first_physical_violation"],
                original_diagnostic_failure_codes=original_trial["diagnostic_failure_codes"],
                source_controller_sha256=sha(folder/"controller.jsonl"),source_contact_sha256=sha(folder/"contact-force.jsonl"),
                source_trace_sha256=sha(folder/"trace.jsonl"),force_profile_sha256=sha(folder/"force-profile.json"),
                maximum_reconstruction_errors=errors,support_transitions=transitions,windows=windows))
            rows.extend(command_rows);internal.extend(sample_rows)
    require(len(rows)==252 and len(internal)==1260 and sum(r["force_policy"] is not None for r in rows)==132,
        "Force diagnosis final population")
    return dict(schema_version="locolemotion_posture_tracking_diagnostic_audit_v1",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=sha(PARENT_RESULT),
        parent_reconstruction_verified=verified["ok"],parent_reconstruction_sha256=hashlib.sha256(json.dumps(verified,
            sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",trials=trials,command_rows=rows,internal_rows=internal,
        controller_rows=252,internal_samples=1260,prepared_joint_entries=2016,internal_motor_entries=10080,
        force_policy_commands=132,authority_loss_joint_entries=1056,
        reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();value=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,value);print(json.dumps(dict(ok=True,controller_rows=252,internal_samples=1260,worlds_opened=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
