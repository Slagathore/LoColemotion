"""Close the retained nullspace gate failure without changing its solver."""
import argparse,copy,json,os
from pathlib import Path
from contextlib import ExitStack
from unittest.mock import patch
from types import SimpleNamespace
import numpy as np
import mujoco
import hierarchical_nullspace_component as component
import hierarchical_contact_component_audit_v2 as failed
from hierarchical_force_policy_v2 import HierarchyRefusal
from test_hierarchical_force_policy_v2 import HierarchicalPolicyControls as Fixture
from hierarchical_hold_control_v2 import HierarchicalHoldController
from hold_horizon_task import controller_contract,frozen_model,declaration as hold_declaration
from recovery_hold_control import terminal_error
from dynamic_control_native_trial import transfer_targets
from audit_gpu_batch_execution import same_bits
from causal_force_policy import plain
from contact_force_observer_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_dynamic_control_native_failure import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new

CONTRACT=HERE/"hierarchical_nullspace_refusal_v1.json"
PARENT_RESULT=failed.CONTRACT
SOURCES=("audit_hierarchical_nullspace_refusal.py","run_hierarchical_nullspace_refusal.py")
GATES=(("nullspace","test_hierarchical_nullspace_component",12),)
CONTROLS=12
ATTEMPT="sdk2-hierarchical-contact-component-v2-07a6cdbeaf2b4dc5b38eff4f37bf9c04"
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
INPUT=EVIDENCE/"sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"/"physical"/"reach_hold_left_075_train_001"

def expected_contract():
    return dict(schema_version="locolemotion_hierarchical_nullspace_refusal_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="retained_failure_diagnosis",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_contract_sha256=sha(PARENT_RESULT),
        failed_attempt=ATTEMPT,failed_receipt_sha256=sha(EVIDENCE/ATTEMPT/"receipt.json"),
        input_bindings={n:sha(INPUT/n) for n in ("compiled.json","inputs.json","controller.jsonl")},
        controls_required=CONTROLS,complete_reader_invocations=2,core_builds=2,
        direct_refusal_requests_per_core=1,host_prefix_commands_per_core=60,host_refused_commands_per_core=1,
        original_failed_gate=dict(passed_prior_controls=171,module_tests=17,errors=6,failures=1,passed_module_tests=10),
        source_changes_or_solver_retries=False,solver_acceptance_unchanged=True,
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in failed.DENIALS})

def declaration():
    value=read(CONTRACT);require(value==expected_contract(),"Nullspace refusal exact declaration");return value

def verify_failed(evidence):
    folder=evidence/ATTEMPT;r=read(folder/"receipt.json");d=read(folder/"declaration.json")
    require(r["ok"] is False and r["controls_passed"]==171 and r["controls_planned"]==188
        and r["worlds_opened"]==r["solver_steps"]==0 and r["physical_started"] is False,"Exact stopped launch gate")
    require("hierarchical-policy-v2-controls" in r["error"],"Exact failed stage")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(d["binding"])
    require(r["contract"]==failed.declaration(),"Immutable failed component declaration")
    for name,_,count in failed.GATES[:-1]:verify_tests(folder/(name+"-controls"),count)
    log=(folder/"hierarchical-policy-v2-controls"/"stderr.log").read_text(encoding="utf-8")
    require("Ran 17 tests" in log and "FAILED (failures=1, errors=6)" in log
        and log.count(" ... ERROR")==6 and log.count(" ... FAIL")==1 and log.count(" ... ok")==10,
        "Exact failed module population")
    require(not (folder/"audit.json").exists() and not (folder/"reconstruction.json").exists(),
        "Failed gate never entered population readers")
    return dict(attempt_id=ATTEMPT,receipt_sha256=sha(folder/"receipt.json"),error=r["error"],
        completed_prior_controls=171,failed_module_passed=10,failed_module_errors=6,failed_module_failures=1,
        complete_population_readers=0,worlds_opened=0,solver_steps=0)

def summarize(qp,result):
    red=qp["reduced"];a=red["A"];norm=np.max(np.abs(a),axis=1)
    near=np.flatnonzero(norm<1e-10)
    rows=[]
    for index in near:
        rows.append(dict(index=int(index),name=qp["full"]["row_names"][qp["remaining_indices"][index]],
            maximum_coefficient=float(norm[index]),
            lower=float(red["lower"][index]) if np.isfinite(red["lower"][index]) else None,
            upper=float(red["upper"][index]) if np.isfinite(red["upper"][index]) else None))
    return dict(support_rank=qp["support_rank"],variables=len(red["q"]),
        hessian_condition_number=float(np.linalg.cond(red["P"])),near_zero_rows=rows,
        maximum_origin_equality_error=qp["maximum_origin_equality_error"],
        maximum_nullspace_equality_error=qp["maximum_nullspace_equality_error"],
        reduced_status=result["reduced"]["status"],reduced_accepted=result["reduced"]["accepted"],
        full_certificate=result["full_certificate"])

def audit(evidence,core,baseline):
    c=declaration();previous=verify_failed(evidence)
    # Reopen the successful hierarchy and the original complete native population.
    failed.verify_parent(evidence,core,baseline)
    outputs=[];original_solve=component.solve_secondary
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Retained refusal opens no worlds")))
        for core_file in (core,baseline):
            os.environ["QUADRUPED_TEST_CORE"]=str(core_file);Fixture.setUpClass()
            fixture=Fixture();fixture.setUp();diagnostics=[]
            def capture(qp):
                result=original_solve(qp);diagnostics.append(summarize(qp,result));return result
            with patch.object(component,"solve_secondary",side_effect=capture):
                try:fixture.policy.respond(fixture.request)
                except HierarchyRefusal as exc:decision=exc.decision
                else:raise AssertionError("Consumed direct refusal did not reproduce")
            require(decision["allocation"]["accepted"] is False,"No accepted direct command")
            model=frozen_model(fixture.core)
            host=HierarchicalHoldController(fixture.core,fixture.compiled,controller_contract(hold_declaration(),model),
                model,"synthetic_dynamic_host",fixture.profile)
            rows=[];host_diagnostics=[]
            def capture_host(qp):
                result=original_solve(qp);host_diagnostics.append(summarize(qp,result));return result
            try:
                with patch.object(component,"solve_secondary",side_effect=capture_host):
                    for index,old in enumerate(fixture.rows[:61]):
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                        if index<60:
                            require(terminal_error(row) is None and row["native_targets"]==old["native_targets"],"Unchanged host prefix")
                        else:
                            require(terminal_error(row)["type"]=="HierarchyRefusal" and host.closed,"Real refused host closed")
                            dummy=SimpleNamespace(ctrl=np.zeros(8))
                            try:transfer_targets(row,dummy)
                            except ValueError:pass
                            else:raise AssertionError("Refused target transferred")
                            require(np.array_equal(dummy.ctrl,np.zeros(8)),"Refusal wrote no native targets")
                        rows.append(row)
            finally:host.close()
            outputs.append(plain(dict(direct_request=fixture.request,direct_decision=decision,
                direct_secondary_diagnostics=diagnostics,host_secondary_diagnostics=host_diagnostics,host_rows=rows)))
    require(same_bits(outputs[0],outputs[1]),"Two-core failure and diagnostic identity")
    return dict(schema_version="locolemotion_hierarchical_nullspace_refusal_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        failed_attempt=previous,core_sha256s=[sha(core),sha(baseline)],two_core_results_identical=True,
        diagnostic=outputs[0],direct_refusals_per_reader=2,host_refusals_per_reader=2,host_commands_per_reader=122,
        host_refusal_not_transferred=True,synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in failed.DENIALS})

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core",type=Path,required=True);parser.add_argument("--baseline-core",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True);args=parser.parse_args()
    value=audit(EVIDENCE,args.core,args.baseline_core);write_new(args.output,value)
    print(json.dumps(dict(ok=True,direct_refusals=2,host_refusals=2,worlds_opened=0)));return 0
if __name__=="__main__":raise SystemExit(main())
