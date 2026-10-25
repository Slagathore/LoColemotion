"""Verify safe-window native response without constructing or stepping a world."""
import argparse,hashlib,json
from collections import Counter
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import audit_dynamic_control_native_failure as parent
import dynamic_response_diagnostic_metrics as d
from force_recovery_diagnostic_metrics import vectors,join_control
from audit_gpu_batch_execution import read_jsonl
from causal_force_policy import plain
from gpu_measurement_probe import write_new
from contact_force_observer_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_dynamic_control_native_failure import inventory
from run_residual_native import verify_tests

CONTRACT=HERE/"dynamic_response_diagnostic_v1.json"
PARENT_RESULT=HERE/"dynamic_control_native_failure_result_v1.json"
PARENT_SHA="18902d8d04778f31957d438baee60396c4dae84df807a0214b0a91e9e6ebf1b5"
SOURCES=("dynamic_response_diagnostic_metrics.py","dynamic_response_diagnostic.py",
    "test_dynamic_response_diagnostic.py","run_dynamic_response_diagnostic.py")
CONTROLS=43
GATES=(("mechanics","test_force_recovery_diagnostic",14),("native-inputs","test_floating_base_dynamics_inputs",9),
    ("response","test_dynamic_response_diagnostic",20))
DENIALS=("controller_selection_authority","comparison_data_used_for_fitting","comparison_data_used_for_selection",
    "alternative_trajectory_simulated","causal_generalization","recovery_benefit_established","capability_estimated",
    "dynamic_feasibility_established","tier2_qualified","tier3_benefit_established","physical_acceptance_authority",
    "training_data_authority","release_authority","equivalence_authority")
REFERENCES={
    "integration":"https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_forward.c",
    "derivatives":"https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_derivative.c",
    "limits":"https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_core_constraint.c",
    "equations":"https://mujoco.readthedocs.io/en/stable/computation/index.html"}
def expected_contract():
    return dict(schema_version="locolemotion_dynamic_response_diagnostic_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_dynamic_response_diagnostic",question_class="development"),
        parent_result_path=PARENT_RESULT.relative_to(ROOT).as_posix(),parent_result_sha256=PARENT_SHA,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_bindings={n:sha(HERE/n) for n in ("floating_base_dynamics.py","floating_base_dynamics_inputs.py",
            "force_recovery_diagnostic_metrics.py","posture_tracking_diagnostic_metrics.py",
            "dynamic_inverse_dynamics_v2.py","dynamic_control_native_failure_trial.py","audit_dynamic_control_native_failure.py")},
        controls_required=CONTROLS,expected_trials=2,expected_commands=118,expected_internal_samples=590,
        commands_start_inclusive=60,commands_end_exclusive=119,internal_start_inclusive=301,internal_end_inclusive=595,
        window_selected_after_original_outcomes=True,earliest_original_violation_step=596,
        original_controller_rows=[1440,317],original_internal_rows=[7200,1580],
        full_retained_population_reopened=True,post_failure_states_in_diagnostic=False,
        prepared_candidate_optimizations=59,terminal_failure_is_separate=True,
        motor_absolute_tolerance_nm=1e-10,velocity_increment_absolute_tolerance=1e-10,
        generalized_equation_absolute_tolerance=1e-8,
        acceleration_basis="canonical world linear/angular and joint axes at the prepared state",
        actual_acceleration_scope="continuous reconstruction from measured forces and finite native increment in prepared basis",
        measured_force_source="retained solver readback, not controller input or a future contact predictor",
        integrator="implicitfast",native_runtime="3.11.0",timestep_s=1/600.,
        effective_inertia="M plus timestep times diagonal unsaturated velocity-motor gains; joint damping zero",
        generalized_constraint_scope="all elliptic point contacts plus zero-margin scalar hinge limits",
        acceleration_accounting=["measured_minus_planned_contact","joint_limit","measured_minus_requested_motor","implicit_integration"],
        accounting_is_not_causal_attribution=True,post_handoff_states_differ=True,
        references=REFERENCES,reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in DENIALS})
def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Dynamic response exact declaration");return c

def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Dynamic response parent bytes")
    result=read(PARENT_RESULT);parent.declaration();name=result["verification_attempt"]
    require(name=="sdk2-dynamic-native-failure-controls-4ba5321a0a384ed3ba48a36cda18ecf2","Dynamic response parent identity")
    folder=evidence/name;r=read(folder/"receipt.json");declared=read(folder/"declaration.json")
    require(r["ok"] is True and r["source_runtime_unchanged"] is True and r["controls_passed"]==16
        and r["worlds_opened"]==r["solver_steps"]==0 and r["contract"]==declared["contract"]==parent.declaration()
        and len(declared["binding"]["source"])==r["source_binding_count"]==780
        and len(declared["binding"]["runtime"])==r["runtime_binding_count"]==3430
        and result["contract_sha256"]==sha(parent.CONTRACT)
        and all(result[k] is False for k in parent.DENIALS),"Dynamic response parent scope")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
                     ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Dynamic response parent proof digest")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    verify_tests(folder/"failure-controls",16)
    old=read(folder/"audit.json")
    require(old==read(folder/"reconstruction.json")==result["native_evidence"],"Dynamic response original reader identity")
    verified=parent.audit(evidence,core,baseline)
    require(verified==old,"Dynamic response complete original reconstruction")
    return verified

def acceleration_summary(rows):
    """Keep linear, angular and joint acceleration units separate."""
    a=np.asarray(rows)
    require(a.ndim==2 and a.shape[1]==14,"Dynamic response acceleration population")
    return dict(root_linear_m_s2=vectors(a[:,:3].tolist()),root_angular_rad_s2=vectors(a[:,3:6].tolist()),
        joint_rad_s2=vectors(a[:,6:].tolist()))

def summarize(commands,internals):
    candidate=[r for r in commands if r["dynamic"] is not None]
    result=dict(commands=len(commands),internal_samples=len(internals),
        prepared_motor_error_nm=vectors([r["torque_difference_from_command_request_nm"] for r in internals if r["offset"]==0]),
        held_motor_error_nm=vectors([r["torque_difference_from_command_request_nm"] for r in internals]),
        measured_contact_force_n=vectors([r["contact_generalized_force"][:3] for r in internals]),
        joint_limit_samples=sum(bool(np.any(r["joint_limit_generalized_force"])) for r in internals),
        joint_limit_torque_nm=vectors([r["joint_limit_generalized_force"][6:] for r in internals]),
        continuous_acceleration=acceleration_summary([r["continuous_acceleration"] for r in internals]),
        integrated_acceleration=acceleration_summary([r["integrated_acceleration"] for r in internals]),
        supporting_command_counts={site:sum(site in r["supporting_sites"] for r in commands) for site in
            ("front_left_foot","front_right_foot","rear_left_foot","rear_right_foot")},
        maximum_reconstruction_errors={key:max(r[key] for r in internals) for key in ("motor_error","velocity_error","equation_error")},
        max_held_torque_difference_nm=max(max(abs(x) for x in r["torque_difference_from_command_request_nm"]) for r in internals),
        full_window_endpoints=[commands[0],commands[-1]])
    if candidate:
        snapshots=[r["dynamic"] for r in candidate];points=[p for r in snapshots for p in r["points"]]
        result["dynamic"]=dict(commands=len(candidate),contact_observations=len(points),
            discrepancy=acceleration_summary([r["accounting"]["discrepancy"] for r in snapshots]),
            contributions={k:acceleration_summary([r["accounting"]["contributions"][k] for r in snapshots])
                for k in ("contact","joint_limit","motor","integrator")},
            maximum_accounting_error=max(r["accounting"]["maximum_identity_error"] for r in snapshots),
            predicted_contact_normal_force_n=vectors([[p["planned_force_n"][1]] for p in points]),
            predicted_contact_normal_acceleration_m_s2=vectors([[p["predicted_acceleration_m_s2"][1]] for p in points]),
            positive_planned_normal_force_and_upward_acceleration=sum(p["planned_force_n"][1]>1e-9
                and p["predicted_acceleration_m_s2"][1]>1e-9 for p in points),
            actual_continuous_contact_normal_acceleration_m_s2=vectors([[p["actual_continuous_acceleration_m_s2"][1]] for p in points]),
            material_point_motion_m=vectors([p["material_displacement_over_command_m"] for p in points]),
            commanded_contact_maintenance_guaranteed=False,accounting_is_not_causal_attribution=True)
    return result

def audit(evidence,core_path,baseline_path):
    c=declaration();verified=verify_parent(evidence,core_path,baseline_path)
    failures=[t["diagnostic_metrics"]["first_physical_violation"] for t in verified["trials"]]
    window=d.validate_window(failures,60,119);trials=[];command_rows=[];internal_rows=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Dynamic response opens no world")))
        for original in verified["trials"]:
            identity=original["trial_id"];folder=evidence/parent.ATTEMPT/"physical"/identity
            controls=list(read_jsonl(folder/"controller.jsonl"));traces=list(read_jsonl(folder/"trace.jsonl"))
            samples=list(read_jsonl(folder/"contact-force.jsonl"));profile=read(folder/"force-profile.json")
            require(len(controls)==original["controller_rows"] and len(samples)==len(traces)==original["internal_rows"],
                "Dynamic response complete retained denominator")
            model,ranges=d.configured_model((folder/"model.xml").read_text(),profile)
            commands=[];internals=[]
            for command in range(60,119):
                row=controls[command];join_control(row,samples[5*command],traces[5*command],command)
                decision=row["force_reference"]["decision"];requested=np.asarray(decision["allocation"]["requested_torque"])
                first=None
                for offset in range(5):
                    index=5*command+offset;sample=samples[index];trace=traces[index]
                    require(sample["step"]==index+1 and sample["ctrl"]==row["native_targets"],"Dynamic response held command/order")
                    value=d.internal_sample(model,ranges,profile,sample,trace)
                    if first is None:first=value
                    internals.append(plain(dict(trial_id=identity,command=command,offset=offset,internal_step=index+1,
                        motor_error=value["motor_error"],velocity_error=value["velocity_error"],equation_error=value["equation_error"],
                        contact_generalized_force=value["contact"],joint_limit_generalized_force=value["limits"],
                        measured_torque_nm=value["torque"],implicit_damping_diagonal=value["damping"],
                        torque_difference_from_command_request_nm=value["torque"]-requested,
                        continuous_acceleration=value["continuous"],integrated_acceleration=value["integrated"],
                        observed_increment_acceleration=value["observed"])))
                dynamic=d.command_snapshot(row,traces[5*command+4],first,model) if original["role"]=="dynamic_hold" else None
                commands.append(plain(dict(trial_id=identity,command=command,
                    root_height_m=row["request"]["state"]["base_pose_world"]["position_m"]["y"],
                    supporting_sites=[x["contact_site_id"] for x in row["request"]["state"]["ordered_contact_observations"] if x["bears_support"]],
                    dynamic=dynamic)))
            trials.append(dict(trial_id=identity,role=original["role"],original_failure=original["diagnostic_metrics"]["first_physical_violation"],
                source_controller_sha256=sha(folder/"controller.jsonl"),source_trace_sha256=sha(folder/"trace.jsonl"),
                source_contact_sha256=sha(folder/"contact-force.jsonl"),summary=summarize(commands,internals)))
            command_rows.extend(commands);internal_rows.extend(internals)
    require(len(command_rows)==118 and len(internal_rows)==590,"Dynamic response final population")
    return dict(schema_version="locolemotion_dynamic_response_diagnostic_audit_v1",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        parent_reconstruction_verified=True,parent_reconstruction_sha256=hashlib.sha256(json.dumps(verified,
            sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",window=window,trials=trials,
        command_rows=command_rows,internal_rows=internal_rows,controller_rows=118,internal_samples=590,
        reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();value=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,value);print(json.dumps(dict(ok=True,controller_rows=118,internal_samples=590,worlds_opened=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
