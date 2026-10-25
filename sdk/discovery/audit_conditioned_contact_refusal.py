"""Close the retained nullspace gate failure without changing its solver."""
import argparse,copy,json,os
from pathlib import Path
from contextlib import ExitStack
from unittest.mock import patch
from types import SimpleNamespace
import numpy as np
import mujoco
import conditioned_contact_component as component
import hierarchical_contact_component_audit_v3 as failed
from hierarchical_force_policy_v3 import HierarchyRefusal
from test_hierarchical_force_policy_v3 import HierarchicalPolicyControls as Fixture
from hierarchical_hold_control_v3 import HierarchicalHoldController
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

CONTRACT=HERE/"conditioned_contact_refusal_v1.json"
PARENT_RESULT=failed.CONTRACT
SOURCES=("audit_conditioned_contact_refusal.py","run_conditioned_contact_refusal.py")
GATES=(("conditioning","test_conditioned_contact_component",12),)
CONTROLS=12
ATTEMPT="sdk2-hierarchical-contact-component-v3-0fe92b31ea0349cb9fea627a07226201"
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
INPUT=EVIDENCE/"sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"/"physical"/"reach_hold_left_075_train_001"

def expected_contract():
    return dict(schema_version="locolemotion_conditioned_contact_refusal_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="retained_failure_diagnosis",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_contract_sha256=sha(PARENT_RESULT),
        failed_attempt=ATTEMPT,failed_receipt_sha256=sha(EVIDENCE/ATTEMPT/"receipt.json"),
        input_bindings={n:sha(INPUT/n) for n in ("compiled.json","inputs.json","controller.jsonl")},
        controls_required=CONTROLS,complete_reader_invocations=2,core_builds=2,
        direct_refusal_requests_per_core=1,host_prefix_commands_per_core=60,host_refused_commands_per_core=1,
        original_failed_gate=dict(passed_prior_controls=183,module_tests=17,errors=6,failures=1,passed_module_tests=10),
        source_changes_or_solver_retries=False,solver_acceptance_unchanged=True,
        diagnostic_exact_qp_repetitions_per_refused_secondary=1,unaccepted_iterates_are_diagnostic_only=True,
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in failed.DENIALS})

def declaration():
    value=read(CONTRACT);require(value==expected_contract(),"Nullspace refusal exact declaration");return value

def verify_failed(evidence):
    folder=evidence/ATTEMPT;r=read(folder/"receipt.json");d=read(folder/"declaration.json")
    require(r["ok"] is False and r["controls_passed"]==183 and r["controls_planned"]==200
        and r["worlds_opened"]==r["solver_steps"]==0 and r["physical_started"] is False,"Exact stopped launch gate")
    require("hierarchical-policy-v3-controls" in r["error"],"Exact failed stage")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(d["binding"])
    require(r["contract"]==failed.declaration(),"Immutable failed component declaration")
    for name,_,count in failed.GATES[:-1]:verify_tests(folder/(name+"-controls"),count)
    log=(folder/"hierarchical-policy-v3-controls"/"stderr.log").read_text(encoding="utf-8")
    require("Ran 17 tests" in log and "FAILED (failures=1, errors=6)" in log
        and log.count(" ... ERROR")==6 and log.count(" ... FAIL")==1 and log.count(" ... ok")==10,
        "Exact failed module population")
    require(not (folder/"audit.json").exists() and not (folder/"reconstruction.json").exists(),
        "Failed gate never entered population readers")
    return dict(attempt_id=ATTEMPT,receipt_sha256=sha(folder/"receipt.json"),error=r["error"],
        completed_prior_controls=183,failed_module_passed=10,failed_module_errors=6,failed_module_failures=1,
        complete_population_readers=0,worlds_opened=0,solver_steps=0)

def summarize(qp,result):
    import osqp
    from scipy import sparse
    from dynamic_qp_solver_v2 import settings,certificate
    red=qp["reduced"];a=red["A"];norm=np.max(np.abs(a),axis=1)
    active=np.flatnonzero((np.abs(red["lower"])<=1e-8)|(np.abs(red["upper"])<=1e-8))
    solver=osqp.OSQP(algebra="builtin")
    solver.setup(P=sparse.csc_matrix(np.triu(red["P"])),q=red["q"],A=sparse.csc_matrix(a),
        l=red["lower"],u=red["upper"],**settings())
    answer=solver.solve(raise_error=False);info=answer.info
    require(info.status==result["reduced"]["status"] and int(info.iter)==result["reduced"]["iterations"],
        "Exact diagnostic QP repetition")
    finite=bool(np.isfinite(answer.x).all() and np.isfinite(answer.y).all())
    diagnostic=None
    if finite:
        cert=certificate(red["P"],red["q"],a,red["lower"],red["upper"],answer.x,answer.y)
        values=a @ answer.x
        violation=np.maximum(np.maximum(red["lower"]-values,values-red["upper"]),0.)
        worst=np.argsort(violation)[-8:][::-1]
        diagnostic=dict(iterate=answer.x.tolist(),dual_iterate=answer.y.tolist(),certificate=cert,
            worst_bounds=[dict(index=int(i),name=qp["full"]["row_names"][qp["remaining_indices"][i]],
                violation=float(violation[i]),value=float(values[i]),
                lower=float(red["lower"][i]) if np.isfinite(red["lower"][i]) else None,
                upper=float(red["upper"][i]) if np.isfinite(red["upper"][i]) else None) for i in worst])
    return dict(support_rank=qp["support_rank"],variables=len(red["q"]),conditioning=qp["conditioning"],
        origin_active_rows_within_1e_minus8=len(active),origin_active_matrix_singular_values=np.linalg.svd(a[active],compute_uv=False).tolist(),
        near_zero_row_count=int(np.count_nonzero(norm<1e-10)),
        maximum_origin_equality_error=qp["maximum_origin_equality_error"],
        maximum_nullspace_equality_error=qp["maximum_nullspace_equality_error"],
        reduced_status=result["reduced"]["status"],reduced_accepted=result["reduced"]["accepted"],
        full_certificate=result["full_certificate"],
        repeated_solver=dict(status=info.status,iterations=int(info.iter),primal_residual=float(info.prim_res),
            dual_residual=float(info.dual_res),rho_estimate=float(info.rho_estimate),rho_updates=int(info.rho_updates)),
        unaccepted_diagnostic=diagnostic,unaccepted_iterate_can_issue_command=False)


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
    return dict(schema_version="locolemotion_conditioned_contact_refusal_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
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
