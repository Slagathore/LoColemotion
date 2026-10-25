"""Verify exact feasibility contradictions in consumed primary and secondary inputs."""
import argparse
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
import mujoco
import audit_conditioned_generic_component as prior
import exact_constraint_feasibility as exact
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_conditioned_generic_component import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new
from contact_force_observer_task import ROOT,HERE,read,sha,require

CONTRACT=HERE/"terminal_constraint_feasibility_v1.json"
PARENT_RESULT=HERE/"conditioned_generic_component_result_v1.json"
PARENT_SHA="412e5039f372766dd60df950490945fcd39d0a68735d19765fb8f736a126cd52"
SOURCES=("exact_constraint_feasibility.py","test_exact_constraint_feasibility.py",
    "audit_terminal_constraint_feasibility.py","run_terminal_constraint_feasibility.py")
GATES=(("exact-feasibility","test_exact_constraint_feasibility",20),)
CONTROLS=20
DENIALS=tuple(dict.fromkeys((*prior.DENIALS,"controller_repair_established",
    "physical_infeasibility_proved","all_saturation_patterns_infeasible")))
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"

def expected_contract():
    return dict(schema_version="locolemotion_terminal_constraint_feasibility_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="retained_exact_constraint_diagnosis",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_result_sha256=PARENT_SHA,
        cases=["original_primary","original_secondary","conditioned_secondary"],
        original_attempt=prior.prior.ATTEMPT,original_trial=prior.TRIAL,original_command=89,
        parameters=exact.settings(),proposal_solver="SciPy1.17.1 HiGHS dual simplex",
        proposal_is_not_certificate=True,certificate_arithmetic="Fraction of decoded binary64 coefficients",
        certificate_rule="nonnegative inequality weights sum to1; free equality weights; exact coefficient sum0; strict bound sum<0",
        diagnostic_origin="original primary reduced solution; conditioned secondary origin is zero",
        candidate_scope="all equalities and inequalities with exact origin slack at most1e-6",
        incomplete_candidate_search_cannot_prove_feasibility=True,
        original_coefficients_bounds_and_acceptance_unchanged=True,
        scope="exact finite encoded constraints for one consumed clipping pattern; not physical-model impossibility",
        references=dict(certificate="https://docs.mosek.com/latest/pythonapi/prob-def-linear.html#primal-infeasible-problems",
            support_search="https://docs.scipy.org/doc/scipy/reference/optimize.linprog-highs-ds.html"),
        controls_required=CONTROLS,complete_reader_invocations=2,readers_byte_identical_required=True,
        raw_diagnostic_outputs_retained=True,synthetic=True,worlds_opened=0,solver_steps=0,
        **{k:False for k in DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Exact feasibility contract");return c

def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Exact feasibility parent identity")
    result=read(PARENT_RESULT);folder=evidence/result["attempt_id"]
    receipt=read(folder/"receipt.json");declared=read(folder/"declaration.json")
    c=prior.declaration()
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Exact feasibility parent artifact")
    a=read(folder/"audit.json")
    require(receipt["ok"] is True and receipt["component_accepted"] is False and receipt["controls_passed"]==28
        and receipt["contract"]==declared["contract"]==c and receipt["source_runtime_unchanged"] is True
        and a["ok"] is True and a["component_accepted"] is False and a["states"]==1
        and a["accepted_states"]==0 and a["status"]=="terminal_command89_refused"
        and a["rows"][0]["original_primary_identical"] is True
        and same_bits(a,read(folder/"reconstruction.json"))
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")
        and all(a[k] is False for k in prior.DENIALS),"Exact feasibility complete retained refusal")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    for name,_,count in prior.GATES:verify_tests(folder/(name+"-controls"),count)
    prior.verify_parent(evidence,core,baseline)
    return a

def audit(evidence,core,baseline,capture):
    c=declaration();parent=verify_parent(evidence,core,baseline)
    terminal=evidence/prior.prior.ATTEMPT/"physical"/prior.TRIAL/"controller.jsonl"
    rows=list(read_jsonl(terminal));require(len(rows)==90 and rows[89]["outer_step"]==89,"Exact feasibility terminal population")
    old=rows[89]["force_reference"]["decision"]["allocation"]
    new=parent["rows"][0]["result"]
    require(len(old["attempts"])==len(new["attempts"])==2 and old["accepted"] is False
        and new["accepted"] is False and old["patterns_tried"]==new["patterns_tried"]==1
        and same_bits(old["attempts"][0],new["attempts"][0]),"Exact feasibility identical original primary and pattern")
    original=old["attempts"][0]["result"]["reduced"]["x"]
    cases=[("original_primary",old["attempts"][0]["problem"],original),
        ("original_secondary",old["attempts"][1]["problem"],original),
        ("conditioned_secondary",new["attempts"][1]["problem"],[0.]*len(new["attempts"][1]["problem"]["q"]))]
    results=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Exact feasibility opens no worlds")))
        for name,problem,origin in cases:
            diagnostic=exact.diagnose(problem,origin)
            value=dict(name=name,problem=problem,origin=origin,diagnostic=diagnostic)
            write_new(capture/(name+".json"),value)
            if diagnostic["exact_infeasibility_proved"]:
                require(exact.verify(problem,diagnostic["certificate"])==diagnostic["verification"],
                    "Exact feasibility original coefficient recheck")
            results.append(dict(name=name,diagnostic=diagnostic))
    return dict(schema_version="locolemotion_terminal_constraint_feasibility_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        cases=results,cases_evaluated=3,certificates_verified=sum(r["diagnostic"]["exact_infeasibility_proved"] for r in results),
        original_primary_identical=True,synthetic=True,worlds_opened=0,solver_steps=0,
        **{k:False for k in DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    value=audit(EVIDENCE,args.core,args.baseline_core,capture);write_new(args.output,value)
    print({k:value[k] for k in ("ok","cases_evaluated","certificates_verified")})
    return 0
if __name__=="__main__":raise SystemExit(main())
