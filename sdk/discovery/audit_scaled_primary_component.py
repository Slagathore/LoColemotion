"""Sequential retained-state test of a bounded semidefinite primary successor."""
import argparse
from collections import Counter
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import numpy as np
import mujoco
import scaled_primary_fallback_component as component
import audit_proximal_primary_component_v2 as ancestor
import audit_refined_fallback_component_v2 as previous
import audit_hierarchical_public_v7 as public_parent
import audit_hierarchical_native_failure_v3 as native_parent
import contact_priority_component as original
import dynamic_inverse_dynamics_v2 as dynamic
import actuation_recovery_mechanics as mechanics
from dynamic_response_diagnostic_metrics import configured_model
from floating_dynamics_oracle_math import canonical_state
from causal_force_policy import plain
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_hierarchical_native_failure_v3 import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new
from contact_force_observer_task import ROOT,HERE,read,sha,require

CONTRACT=HERE/"scaled_primary_component.json"
PARENT_RESULT=HERE/"hierarchical_native_failure_result_v3.json"
PARENT_SHA="de04e5a9439ede63cab6f1b3b1d0e5d0b7b032afe601188309ae9085a26c9f34"
SOURCES=("scaled_primary_refinement.py","scaled_primary_contact_component.py",
    "scaled_primary_fallback_component.py","test_scaled_primary_refinement.py",
    "test_scaled_primary_contact_component.py","test_scaled_primary_fallback_component.py",
    "audit_scaled_primary_component.py","test_scaled_primary_component_audit.py","run_scaled_primary_component.py")
GATES=(*ancestor.GATES,("native-failure-v3","test_hierarchical_native_failure_v3",24),
    ("scaled-refinement","test_scaled_primary_refinement",14),
    ("scaled-primary","test_scaled_primary_contact_component",16),
    ("scaled-routing","test_scaled_primary_fallback_component",8),
    ("scaled-audit","test_scaled_primary_component_audit",8))
CONTROLS=sum(n for _,_,n in GATES)
DENIALS=previous.DENIALS
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
TRIAL=previous.TRIAL
WINDOWS=((native_parent.ATTEMPT,TRIAL,60,99),*ancestor.WINDOWS)

def expected_contract():
    return dict(schema_version="locolemotion_scaled_primary_component_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="conditional_retained_component",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_result_sha256=PARENT_SHA,
        inherited_bindings={n:sha(HERE/n) for n in ("hierarchical_contact_component.py",
            "hierarchical_least_squares_qp.py","primary_active_refinement.py",
            "refined_fallback_contact_component.py","refined_primary_contact_component.py",
            "conditioned_contact_component.py","hierarchical_nullspace_component.py",
            "generic_proximal_qp_solver.py","generic_proxqp_backend.py","generic_proximal_least_squares.py",
            "proximal_primary_contact_component_v2.py","proximal_primary_fallback_component_v2.py")},
        windows=[dict(attempt_id=a,trial_id=t,start=s,end_exclusive=e,
            input_bindings={n:sha(EVIDENCE/a/"physical"/t/n) for n in previous.INPUTS}) for a,t,s,e in WINDOWS],
        evaluation_order="latest native terminal98, then38 applied native states, then complete prior180",
        latest39_required_before_prior180=True,maximum_states_per_reader=219,
        original_component_reconstruction_required=True,accepted_previous_outputs_bitwise_preserved=True,
        all_previous_results_compared_with_retained_native_or_component_population=True,
        early_stop_is_retained_negative_not_component_acceptance=True,
        parameters=component.parameters(),solver_settings=component.solver_settings(),
        mandatory_refinement_predecessor_result="sdk/discovery/proximal_primary_component_result_v1.json",
        mandatory_refinement_predecessor_sha256="177cbd08cd0ed4c38ba63a0c2892e57f506d08b1eb5cdfe1f427de33de9a1de1",
        certified_strict_primary_seed_preserved=True,
        primary_hessian="exact least-squares Gram matrix; semidefinite permitted",
        objective_regularization=0.,output_rounding=False,acceptance_tolerances_changed=False,
        strict_primary_refinement_guard_unchanged=True,original_full_duals_and_certificates_required=True,
        physical_limits_unchanged=True,controls_required=CONTROLS,complete_reader_invocations=2,
        readers_byte_identical_required=True,intermediate_outputs_before_comparison=True,
        task_reference_source="original command reference and original applied correction history",
        original_observations_generated_by_alternative_actions=False,
        upstream_primary_reference="https://arxiv.org/abs/1803.07178",
        arithmetic="float64",arbitrary_precision_established=False,
        correction_scales_are_affine_variable_changes=True,maximum_actual_qp_solves=112,
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Scaled primary exact contract");return c

def validate_parent_scope(result,a,r,c):
    require(result["schema_version"]=="locolemotion_hierarchical_native_failure_result_v3"
        and result["status"]=="complete_retained_incomplete_native_comparison_closure"
        and result["ledger_scope"]==a["ledger_scope"]==c["ledger_scope"]
        and result["controls_passed"]==r["controls_passed"]==24
        and result["complete_reader_invocations"]==2 and result["readers_byte_identical"] is True
        and r["ok"] is True and r["source_runtime_unchanged"] is True and a["ok"] is True
        and result["original_attempt"]==native_parent.ATTEMPT
        and result["original_source_commit"]==native_parent.SOURCE
        and result["original_receipt_sha256"]==native_parent.RECEIPT_SHA
        and result["original_safety_controls_verified"]==a["original_safety_controls_verified"]==984
        and result["retained_controller_rows"]==a["controller_rows"]==1539
        and result["retained_internal_rows"]==a["internal_rows"]==a["contact_rows"]==7690
        and result["original_worlds_opened"]==a["constructed_cpu_worlds"]==2
        and result["original_worlds_planned"]==4 and result["original_native_ok"] is False
        and result["terminal_command"]==98 and result["terminal_transferred"] is False
        and result["complete_retained_population_verified"] is True
        and a["complete_retained_population_verified"] is True
        and result["worlds_opened"]==result["solver_steps"]==r["worlds_opened"]==r["solver_steps"]==0
        and a["reader_world_build_count"]==a["reader_solver_steps"]==0
        and all(result[k] is False and a[k] is False for k in native_parent.DENIALS),
        "Scaled primary parent exact scope and authority")

def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Scaled primary parent identity")
    result=read(PARENT_RESULT);folder=evidence/result["attempt_id"]
    r=read(folder/"receipt.json");d=read(folder/"declaration.json");a=read(folder/"audit.json")
    c=native_parent.declaration();validate_parent_scope(result,a,r,c)
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
        ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Scaled primary closure artifact")
    require(r["contract"]==d["contract"]==c and r["source_commit"]==d["source_commit"]==result["source_commit"]
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")
        and same_bits(a,read(folder/"reconstruction.json")),"Scaled primary parent complete readers")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(d["binding"])
    verify_tests(folder/"failure-controls",24)
    native=evidence/native_parent.ATTEMPT
    require(sha(native/"receipt.json")==native_parent.RECEIPT_SHA,"Scaled primary native receipt")
    nr=read(native/"receipt.json");nd=read(native/"declaration.json")
    native_parent.validate_owner(nr,nd,native_parent.task.declaration())
    native_parent.validate_worker(read(native/"physical/worker-result.json"),native_parent.task.declaration())
    verify_population(nr["artifacts"],inventory(native));validate_bindings(nr["binding"])
    return public_parent.verify_parent(evidence,core,baseline)

def previous_result(value):
    require(type(value["scaled_primary_fallback_attempted"]) is bool,"Scaled primary route type")
    if value["scaled_primary_fallback_attempted"]:
        before=value["scaling_previous_refusal"]
        count=sum(x["result"].get("qp_solves",1) for x in value["attempts"])
        require(before["accepted"] is False and before["status"]=="bounded hierarchical search refused"
            and value["solver_route"] in ("scaled_primary","scaled_primary_refused")
            and type(value["total_qp_solves"]) is int and count<=64
            and value["total_qp_solves"]==before["total_qp_solves"]+count<=112,
            "Scaled primary fallback identity and actual inner work")
        return before
    require(value["scaling_previous_refusal"] is None,"Scaled primary no invented predecessor")
    return {k:v for k,v in value.items() if k not in ("scaled_primary_fallback_attempted","scaling_previous_refusal")}

def calculate(folder,step,originals,profile,model,ranges,capture,window,retained):
    row=originals[step];require(row["outer_step"]==step,"Scaled primary original clock")
    position,orientation,joints,velocity,gravity=canonical_state(row)
    frame=model.tree.kinematics(position,orientation,joints)
    request=row["resolution_request"]["provider_request"];decision=row["force_reference"]["decision"]
    contacts=request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
    items,active=dynamic.tasks(model,frame,velocity,orientation,contacts,decision["target_com"],
        np.array(decision["support_reference"]["reference_joint_positions_rad"])-joints,dynamic.parameters())
    baseline=request["deterministic_baseline"]["ordered_commands"];limits=request["safety_envelope"]["ordered_actuator_limits"]
    require([x["actuator_id"] for x in baseline]==[x["actuator_id"] for x in limits]==profile["ordered_actuators"]
        and all(x["maximum_absolute_correction_rad_s"]==3.5 and x["maximum_slew_per_step_rad_s"]==.08 for x in limits),
        "Scaled primary unchanged public limits")
    envelope=mechanics.command_envelope([x["combined_canonical_target_velocity_rad_s"] for x in baseline],
        [x["maximum_target_speed_rad_s"] for x in baseline],
        [x["previous_applied_correction_rad_s"] for x in limits],[3.5]*8,[.08]*8)
    base=original.build(model,frame,velocity,gravity,joints,ranges,items,active,envelope,
        profile["velocity_gains"],profile["force_ranges"],"combined")
    value=plain(component.compute(base));before=previous_result(value)
    require(type(value["total_qp_solves"]) is int and 0<=value["total_qp_solves"]<=112,"Scaled primary bounded work")
    reconstructed=previous.native_allocation(before,base) if window==0 else before
    expected=decision["allocation"] if window==0 else retained[(WINDOWS[window][0],folder.name,step)]
    report=dict(window=window,attempt_id=WINDOWS[window][0],trial_id=folder.name,command=step,
        supporting_sites=[x["contact_site_id"] for x in active],previous_accepted=before["accepted"],
        original_component_reproduced=same_bits(reconstructed,expected),result=value)
    write_new(capture/(str(window)+"-"+folder.name+"-"+str(step)+"-precomparison.json"),
        dict(report,reconstructed_previous=reconstructed))
    require(report["original_component_reproduced"],"Scaled primary predecessor exact retained reconstruction")
    if before["accepted"]:
        require(value["accepted"] is True and value["scaled_primary_fallback_attempted"] is False,
            "Scaled primary cannot replace accepted predecessor")
    return report

def audit(evidence,core,baseline,capture):
    c=declaration();retained=verify_parent(evidence,core,baseline);rows=[];trials=[];stopped=None
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Scaled primary component opens no world")))
        for index,(attempt,trial,start,end) in enumerate(WINDOWS):
            folder=evidence/attempt/"physical"/trial;profile=read(folder/"force-profile.json")
            model,ranges=configured_model((folder/"model.xml").read_text(),profile)
            require(np.array_equal(ranges,[[j["lower_limit_rad"],j["upper_limit_rad"]] for j in model.tree.spec["joints"]]),
                "Scaled primary exact native joint ranges")
            originals=list(read_jsonl(folder/"controller.jsonl"));selected=[]
            order=[98,*range(60,98)] if index==0 else list(range(start,end))
            for step in order:
                value=calculate(folder,step,originals,profile,model,ranges,capture,index,retained)
                write_new(capture/(str(index)+"-"+trial+"-"+str(step)+".json"),value)
                rows.append(value);selected.append(value)
                if index==0 and step==98 and not value["result"]["accepted"]:
                    stopped="terminal_command98_refused";break
            trials.append(dict(attempt_id=attempt,trial_id=trial,planned_states=end-start,states=len(selected),
                accepted_states=sum(r["result"]["accepted"] for r in selected),
                status_counts=dict(Counter(r["result"]["status"] for r in selected))))
            if stopped:break
            if index==0 and not all(r["result"]["accepted"] for r in selected):
                stopped="latest_native_window_contains_refusal";break
    accepted=stopped is None
    require(len(rows)==219 if accepted else len(rows) in (1,39),"Scaled primary exact sequential population")
    return dict(schema_version="locolemotion_scaled_primary_component_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,component_accepted=accepted,
        status=stopped or "complete_scaled_primary_retained_component",states=len(rows),
        accepted_states=sum(r["result"]["accepted"] for r in rows),trials=trials,rows=rows,
        previous_accepted_preserved=sum(r["previous_accepted"] for r in rows),
        newly_accepted_states=sum(r["result"]["accepted"] and not r["previous_accepted"] for r in rows),
        public_hosts=0,synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    value=audit(EVIDENCE,args.core,args.baseline_core,capture);write_new(args.output,value)
    print({k:value[k] for k in ("ok","component_accepted","status","states","accepted_states")});return 0
if __name__=="__main__":raise SystemExit(main())
