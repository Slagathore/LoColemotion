"""Retained conditioned-generic gate with explicit sequential acceptance boundaries."""
import argparse
from collections import Counter
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import numpy as np
import mujoco
import conditioned_generic_contact_component as component
import audit_hierarchical_native_failure as prior
import contact_priority_component as original
import dynamic_inverse_dynamics_v2 as dynamic
import actuation_recovery_mechanics as mechanics
from dynamic_response_diagnostic_metrics import configured_model
from floating_dynamics_oracle_math import canonical_state
from causal_force_policy import plain
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_hierarchical_native_failure import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new
from contact_force_observer_task import ROOT,HERE,read,sha,require

CONTRACT=HERE/"conditioned_generic_component_v1.json"
PARENT_RESULT=HERE/"hierarchical_native_failure_result_v1.json"
PARENT_SHA="a499c5de5c93e665b0fe2c051ec5c61f373dbae8d18ae7259d5899022f108d82"
SOURCES=("conditioned_generic_contact_component.py","test_conditioned_generic_contact_component.py",
    "audit_conditioned_generic_component.py","run_conditioned_generic_component.py")
GATES=(("generic-qp","test_generic_proximal_qp_solver",16),
    ("conditioned-generic","test_conditioned_generic_contact_component",12))
CONTROLS=sum(n for _,_,n in GATES)
DENIALS=tuple(dict.fromkeys((*prior.DENIALS,*prior.task.component.DENIALS,
    "public_controller_integration_verified")))
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
TRIAL="hierarchy_hold_left_075_train_001"
WINDOWS=((prior.ATTEMPT,TRIAL,60,90),
    *((prior.task.component.ORIGINAL,t,60,119) for t in prior.task.component.TRIALS))
INPUTS=prior.task.component.INPUTS

def expected_contract():
    return dict(schema_version="locolemotion_conditioned_generic_component_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="conditional_retained_component",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_result_sha256=PARENT_SHA,
        inherited_bindings={n:sha(HERE/n) for n in ("conditioned_contact_component.py",
            "hierarchical_nullspace_component.py","generic_proximal_qp_solver.py","generic_proxqp_backend.py")},
        windows=[dict(attempt_id=a,trial_id=t,start=s,end_exclusive=e,
            input_bindings={n:sha(EVIDENCE/a/"physical"/t/n) for n in INPUTS}) for a,t,s,e in WINDOWS],
        evaluation_order="terminal command89, then remaining29 new native states, then earlier118 states",
        terminal_acceptance_required_before_new_native_window=True,
        all30_new_native_states_required_before_earlier118=True,
        maximum_states_per_reader=148,early_stop_is_retained_negative_not_component_acceptance=True,
        parameters=component.parameters(),solver_settings=component.solver_settings(),
        objective_regularization=0.,output_rounding=False,acceptance_tolerances_changed=False,
        secondary_support_equalities_eliminated=True,secondary_hessian_conditioned_by_invertible_coordinates=True,
        original_full_duals_and_certificates_required=True,primary_problem_unchanged=True,
        original_native_primary_reconstruction_required=True,controls_required=CONTROLS,
        complete_reader_invocations=2,readers_byte_identical_required=True,
        intermediate_state_outputs_before_acceptance=True,
        task_reference_source="original command reference and original applied correction history",
        original_observations_generated_by_alternative_actions=False,
        model_scope="frozen M, bias, contact J and forces over five implicit motor steps; no native prediction",
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Conditioned generic exact contract");return c

def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Conditioned generic parent identity")
    result=read(PARENT_RESULT);folder=evidence/result["attempt_id"]
    receipt=read(folder/"receipt.json");declared=read(folder/"declaration.json")
    c=prior.declaration()
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Conditioned generic parent artifact digest")
    a=read(folder/"audit.json")
    require(receipt["ok"] is True and receipt["controls_passed"]==18
        and receipt["contract"]==declared["contract"]==c
        and receipt["source_runtime_unchanged"] is True and a["ok"] is True
        and a["complete_retained_population_verified"] is True
        and a["controller_rows"]==1530 and a["internal_rows"]==7645
        and same_bits(a,read(folder/"reconstruction.json"))
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")
        and all(a[k] is False for k in prior.DENIALS),"Conditioned generic complete parent closure")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    for name,_,count in prior.GATES:verify_tests(folder/(name+"-controls"),count)
    native=evidence/prior.ATTEMPT;native_c=prior.task.declaration()
    require(sha(core)==native_c["core_sha256"] and sha(baseline)==native_c["baseline_core_sha256"],
        "Conditioned generic exact cores")
    require(sha(native/"receipt.json")==prior.RECEIPT_SHA,"Conditioned generic native receipt")
    r=read(native/"receipt.json");owner=prior.launch_records(native/"physical",native_c,prior.SOURCE)
    prior.validate_owner(r,owner,native_c)
    prior.validate_worker(read(native/"physical/worker-result.json"),native_c)
    verify_population(r["artifacts"],inventory(native));validate_bindings(r["binding"])
    for name,_,count in prior.task.GATES:verify_tests(native/(name+"-gate"),count)
    verify_tests(native/"provider-gate",2);verify_tests(native/"containment-gate",1)
    prior.task.verify_component(evidence)
    return dict(parent_complete_population_verified=True,original_controls_verified=799,
        prior_component_controls_verified=287,parent_closure_controls_verified=18)

def calculate(folder,step,originals,profile,model,ranges):
    row=originals[step];require(row["outer_step"]==step,"Conditioned generic retained command clock")
    position,orientation,joints,velocity,gravity=canonical_state(row)
    frame=model.tree.kinematics(position,orientation,joints)
    request=row["resolution_request"]["provider_request"];decision=row["force_reference"]["decision"]
    contacts=request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
    items,active=dynamic.tasks(model,frame,velocity,orientation,contacts,decision["target_com"],
        np.array(decision["support_reference"]["reference_joint_positions_rad"])-joints,dynamic.parameters())
    baseline=request["deterministic_baseline"]["ordered_commands"]
    limits=request["safety_envelope"]["ordered_actuator_limits"]
    require([x["actuator_id"] for x in baseline]==[x["actuator_id"] for x in limits]==profile["ordered_actuators"]
        and all(x["maximum_absolute_correction_rad_s"]==3.5 and x["maximum_slew_per_step_rad_s"]==.08 for x in limits),
        "Conditioned generic original public limits")
    envelope=mechanics.command_envelope([x["combined_canonical_target_velocity_rad_s"] for x in baseline],
        [x["maximum_target_speed_rad_s"] for x in baseline],
        [x["previous_applied_correction_rad_s"] for x in limits],[3.5]*8,[.08]*8)
    base=original.build(model,frame,velocity,gravity,joints,ranges,items,active,envelope,
        profile["velocity_gains"],profile["force_ranges"],"combined")
    result=plain(component.compute(base))
    primary_match=None
    if folder.name==TRIAL:
        primary_match=same_bits(result["attempts"][0],decision["allocation"]["attempts"][0])
        require(primary_match,"Conditioned generic unchanged original primary solve")
    return dict(trial_id=folder.name,command=step,supporting_sites=[r["contact_site_id"] for r in active],
        original_primary_identical=primary_match,result=result)

def audit(evidence,core,baseline,capture):
    c=declaration();parents=verify_parent(evidence,core,baseline);rows=[];trials=[]
    stopped=None
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Component opens no worlds")))
        for index,(attempt,trial,start,end) in enumerate(WINDOWS):
            folder=evidence/attempt/"physical"/trial;profile=read(folder/"force-profile.json")
            model,ranges=configured_model((folder/"model.xml").read_text(),profile)
            require(np.array_equal(ranges,[[j["lower_limit_rad"],j["upper_limit_rad"]]
                for j in model.tree.spec["joints"]]),"Conditioned generic native joint ranges")
            if index==0:require(profile["parameters"]["dynamic"]==dynamic.parameters(),"Conditioned generic original tasks")
            originals=list(read_jsonl(folder/"controller.jsonl"))
            order=[89,*range(60,89)] if index==0 else list(range(start,end))
            selected=[]
            for step in order:
                value=calculate(folder,step,originals,profile,model,ranges)
                write_new(capture/(trial+"-"+str(step)+".json"),value)
                selected.append(value);rows.append(value)
                if index==0 and step==89 and not value["result"]["accepted"]:
                    stopped="terminal_command89_refused";break
            counts=Counter(r["result"]["status"] for r in selected)
            trials.append(dict(trial_id=trial,planned_states=end-start,states=len(selected),
                accepted_states=sum(r["result"]["accepted"] for r in selected),status_counts=dict(counts)))
            if stopped:break
            if index==0 and not all(r["result"]["accepted"] for r in selected):
                stopped="new_native_window_contains_refusal";break
    accepted=stopped is None
    require(len(rows)==148 if accepted else len(rows) in (1,30),"Conditioned generic sequential population")
    return dict(schema_version="locolemotion_conditioned_generic_component_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        parent_verification=parents,component_accepted=accepted,
        status=stopped or "complete_conditioned_generic_retained_component",
        states=len(rows),accepted_states=sum(r["result"]["accepted"] for r in rows),trials=trials,rows=rows,
        public_hosts=0,synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    value=audit(EVIDENCE,args.core,args.baseline_core,capture);write_new(args.output,value)
    print({k:value[k] for k in ("ok","component_accepted","status","states","accepted_states")})
    return 0
if __name__=="__main__":raise SystemExit(main())
