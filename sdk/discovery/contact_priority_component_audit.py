"""Bounded retained-state feasibility of strict contact and joint constraints."""
import argparse,json
from pathlib import Path
from contextlib import ExitStack
from unittest.mock import patch
from collections import Counter
import mujoco
import numpy as np
import actuation_recovery_mechanics as m
import dynamic_inverse_dynamics_v2 as old
import dynamic_response_diagnostic as parent
import contact_priority_component as component
from dynamic_qp_solver_v2 import settings
from dynamic_response_diagnostic_metrics import configured_model
from floating_dynamics_oracle_math import canonical_state
from audit_gpu_batch_execution import read_jsonl
from causal_force_policy import plain
from contact_force_observer_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_dynamic_control_native_failure import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new

CONTRACT=HERE/"contact_priority_component_v1.json"
PARENT_RESULT=HERE/"dynamic_response_diagnostic_result_v1.json"
PARENT_SHA="49a1c2d01f23c8b9a64e00f3e4b072dba2ee78bc769a462cec23aa00ccd73fe7"
SOURCES=("contact_priority_component.py","test_contact_priority_component.py","contact_priority_component_audit.py","run_contact_priority_component.py")
GATES=(("mechanics","test_actuation_recovery_mechanics",25),("dynamics","test_floating_base_dynamics",22),
    ("native-inputs","test_floating_base_dynamics_inputs",9),("qp","test_dynamic_qp_solver_v2",12),
    ("inverse","test_dynamic_inverse_dynamics_v2",14),("priority","test_contact_priority_component",20))
CONTROLS=sum(n for _,_,n in GATES)
DENIALS=("alternative_actions_generated_observations","recovery_benefit_established","capability_estimated",
    "dynamic_feasibility_established","tier2_qualified","tier3_benefit_established","physical_acceptance_authority",
    "training_data_authority","release_authority","equivalence_authority","physical_launch_authority",
    "recursive_feasibility_established","held_contact_guaranteed","complete_saturation_regime_search")
TRIALS=("reach_hold_left_075_train_001","dynamic_hold_left_075_train_001")
ORIGINAL="sdk2-dynamic-control-native-9beec4b5fe564f4bb985cce8fb8c5e1b"
INPUTS=("controller.jsonl","force-profile.json","model.xml")
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"

def expected_contract():
    return dict(schema_version="locolemotion_contact_priority_component_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="conditional_retained_feasibility",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_result_sha256=PARENT_SHA,
        inherited_bindings={n:sha(HERE/n) for n in ("dynamic_inverse_dynamics_v2.py","dynamic_qp_solver_v2.py",
            "floating_base_dynamics.py","actuation_recovery_mechanics.py","dynamic_response_diagnostic_metrics.py")},
        input_bindings={t:{n:sha(EVIDENCE/ORIGINAL/"physical"/t/n) for n in INPUTS} for t in TRIALS},
        original_attempt=ORIGINAL,trials=list(TRIALS),start_command=60,end_command_exclusive=119,
        states=118,modes=list(component.MODES),state_mode_evaluations=472,parameters=component.parameters(),
        solver_settings=settings(),controls_required=CONTROLS,complete_reader_invocations=2,
        contact_target_source="existing fixed damped support task; no retuning",
        task_reference_source="original command reference; each state conditions on its original applied correction",
        joint_speed_cap_is_new_planning_constraint_not_motor_speed_guarantee=True,
        joint_margin_basis="one native step at planning speed cap",
        infeasibility_handling="return no command; solver status is not a complete impossibility proof",
        model_scope="frozen M, bias, contact J and forces over five implicit motor steps; no native prediction",
        outside_native_joint_range="refuse because the model has no joint-limit reaction",
        regime_scope="one conservatively constrained regime per motor; other regimes not searched",
        observation_source="shared complete pre-failure retained states selected after the original outcomes",
        initial_contact_acceleration_is_hard_in_contact_modes=True,
        endpoint_joint_constraints_apply_to_all_five_predicted_steps=True,
        sources=dict(contact_priority="https://arxiv.org/html/1909.06586v1",
            task_constraints="https://www.frontiersin.org/journals/robotics-and-ai/articles/10.3389/frobt.2018.00024/full",
            joint_viability_limits="https://iris.unitn.it/retrieve/handle/11572/402854/744191/2023_IROS___Robust_joint_bounds.pdf"),
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Priority exact declaration");return c

def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Priority diagnosis result identity")
    result=read(PARENT_RESULT);folder=evidence/result["attempt_id"];receipt=read(folder/"receipt.json");decl=read(folder/"declaration.json")
    require(receipt["ok"] is True and receipt["controls_passed"]==43
        and receipt["worlds_opened"]==receipt["solver_steps"]==0,"Priority completed diagnosis")
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Priority retained diagnosis digest")
    require(read(folder/"audit.json")==read(folder/"reconstruction.json"),"Priority diagnosis reader agreement")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(decl["binding"])
    for name,_,count in parent.GATES:verify_tests(folder/(name+"-controls"),count)
    verified=parent.verify_parent(evidence,core,baseline)
    require([x["trial_id"] for x in verified["trials"]]==list(TRIALS),"Priority original population")
    require(result["window"]==dict(start=60,end_exclusive=119,commands_per_trial=59,posthoc=True,
        includes_first_failing_command=False),"Priority fixed shared window")
    return result

def qp_document(qp):
    if qp["domain_refusal"]:return qp
    return plain(dict(P=qp["P"],q=qp["q"],A=qp["A"],row_names=qp["row_names"],regimes=qp["regimes"],
        lower=[float(v) if np.isfinite(v) else None for v in qp["lower"]],
        upper=[float(v) if np.isfinite(v) else None for v in qp["upper"]],
        null_lower_means_negative_infinity=True,null_upper_means_positive_infinity=True))

def audit(evidence,core,baseline):
    c=declaration();verify_parent(evidence,core,baseline);rows=[];trials=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Priority component opens no worlds")))
        for trial in TRIALS:
            folder=evidence/ORIGINAL/"physical"/trial
            profile=read(folder/"force-profile.json")
            model,ranges=configured_model((folder/"model.xml").read_text(),profile)
            declared=np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in model.tree.spec["joints"]])
            require(np.array_equal(ranges,declared),"Priority native and morphology joint ranges")
            originals=list(read_jsonl(folder/"controller.jsonl"));summaries={mode:Counter() for mode in component.MODES}
            handoff={};max_error=0.;max_bound=0.;solves=0;accepted=0
            for step in range(60,119):
                row=originals[step];require(row["outer_step"]==step,"Priority retained command clock")
                position,orientation,joints,velocity,gravity=canonical_state(row)
                frame=model.tree.kinematics(position,orientation,joints)
                request=row["resolution_request"]["provider_request"];decision=row["force_reference"]["decision"]
                contacts=request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
                items,active=old.tasks(model,frame,velocity,orientation,contacts,decision["target_com"],
                    np.array(decision["support_reference"]["reference_joint_positions_rad"])-joints,old.parameters())
                baseline_commands=request["deterministic_baseline"]["ordered_commands"]
                limits=request["safety_envelope"]["ordered_actuator_limits"]
                require([x["actuator_id"] for x in baseline_commands]==[x["actuator_id"] for x in limits]==profile["ordered_actuators"]
                    and all(x["maximum_absolute_correction_rad_s"]==3.5 and x["maximum_slew_per_step_rad_s"]==.08 for x in limits),
                    "Priority unchanged public limits")
                envelope=m.command_envelope([x["combined_canonical_target_velocity_rad_s"] for x in baseline_commands],
                    [x["maximum_target_speed_rad_s"] for x in baseline_commands],
                    [x["previous_applied_correction_rad_s"] for x in limits],[3.5]*8,[.08]*8)
                results={}
                for mode in component.MODES:
                    qp=component.build(model,frame,velocity,gravity,joints,ranges,items,active,envelope,
                        profile["velocity_gains"],profile["force_ranges"],mode)
                    result=component.compute(qp);summaries[mode][result["status"]]+=1
                    if result["solver"] is not None:solves+=1
                    if result["accepted"]:
                        accepted+=1;max_error=max(max_error,result["prediction"]["maximum_recurrence_error"])
                        max_bound=max(max_bound,result["solver"]["certificate"]["maximum_bound_violation"])
                    results[mode]=dict(problem=qp_document(qp),result=plain(result))
                if step==60:handoff={mode:dict(accepted=r["result"]["accepted"],status=r["result"]["status"])
                    for mode,r in results.items()}
                rows.append(dict(trial_id=trial,command=step,supporting_sites=[r["contact_site_id"] for r in active],evaluations=results))
            trials.append(dict(trial_id=trial,states=59,status_counts={k:dict(v) for k,v in summaries.items()},
                handoff=handoff,qp_solves=solves,accepted_model_solutions=accepted,
                maximum_recurrence_error=max_error,maximum_bound_violation=max_bound))
    require(len(rows)==118,"Priority complete state population")
    return dict(schema_version="locolemotion_contact_priority_component_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        parent_complete_native_reconstruction_verified=True,states=118,state_mode_evaluations=472,trials=trials,rows=rows,
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();value=audit(EVIDENCE,args.core,args.baseline_core)
    write_new(args.output,value);print(json.dumps(dict(ok=True,states=118,evaluations=472,worlds_opened=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
