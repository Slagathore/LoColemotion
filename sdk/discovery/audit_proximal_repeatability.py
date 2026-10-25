"""Retain every dense-solver replay and exact difference without granting qualification."""
import argparse,copy,json
from pathlib import Path
from contextlib import ExitStack
import mujoco
from unittest.mock import patch
import hierarchical_contact_component_audit_v4 as failed
from hierarchical_force_policy_v4 import make_profile
from hierarchical_hold_control_v4 import HierarchicalHoldController
from hold_horizon_task import bridge,controller_contract,frozen_model,declaration as hold_declaration
from recovery_hold_control import terminal_error
from audit_gpu_batch_execution import read_jsonl,same_bits
from contact_force_observer_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_hierarchical_contact_component_v4 import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new

CONTRACT=HERE/"proximal_repeatability_diagnostic_v1.json"
PARENT_RESULT=failed.CONTRACT
SOURCES=("audit_proximal_repeatability.py","run_proximal_repeatability.py","test_proximal_repeatability.py")
GATES=(("proximal-qp","test_proximal_qp_solver",14),("public-policy","test_hierarchical_force_policy_v4",17),
    ("difference","test_proximal_repeatability",5))
CONTROLS=36
ATTEMPT="sdk2-hierarchical-contact-component-v4-adc1b97ff48449bc9174be6de224bbb7"
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"

def expected_contract():
    return dict(schema_version="locolemotion_proximal_repeatability_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="retained_repeatability_diagnosis",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},failed_contract_sha256=sha(failed.CONTRACT),
        failed_attempt=ATTEMPT,failed_receipt_sha256=sha(EVIDENCE/ATTEMPT/"receipt.json"),
        controls_required=CONTROLS,complete_reader_invocations=2,
        retained_state_warmup=118,trials=list(failed.TRIALS),repeats_per_core=2,core_builds=2,
        public_hosts_per_reader=8,commands_per_host=62,commands_per_reader=496,
        independent_reader_agreement="exact declared input population only; all numeric output differences retained as observations",
        failed_reader_hook="replace only the final ghost comparison with complete capture and exact-difference reporting",
        full_original_acceptance_not_granted=True,source_or_solver_change=False,
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in failed.DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Repeatability exact prospective declaration");return c

def differences(left,right,path=""):
    if same_bits(left,right):return []
    if isinstance(left,dict) and isinstance(right,dict) and left.keys()==right.keys():
        return [v for k in left for v in differences(left[k],right[k],path+"/"+str(k))]
    if isinstance(left,list) and isinstance(right,list) and len(left)==len(right):
        return [v for i,(a,b) in enumerate(zip(left,right)) for v in differences(a,b,path+"/"+str(i))]
    return [dict(path=path,left=left,right=right)]

def verify_failed(evidence):
    folder=evidence/ATTEMPT;r=read(folder/"receipt.json");d=read(folder/"declaration.json")
    require(r["ok"] is False and r["controls_passed"]==r["controls_planned"]==234
        and r["worlds_opened"]==r["solver_steps"]==0,"Exact dense reader failure after complete gate")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(d["binding"])
    require(r["contract"]==failed.declaration(),"Immutable dense component source")
    for name,_,count in failed.GATES:verify_tests(folder/(name+"-controls"),count)
    log=(folder/"audit-reader/stderr.log").read_text(encoding="utf-8")
    require("Hierarchy identical two-core public commands" in log and not (folder/"audit.json").exists()
        and not (folder/"reconstruction.json").exists(),"Exact uncompleted dense reader")
    return dict(attempt_id=ATTEMPT,receipt_sha256=sha(folder/"receipt.json"),controls_passed=234,
        failed_stage="audit-reader",failed_check="Hierarchy identical two-core public commands",
        complete_readers=0,worlds_opened=0,solver_steps=0)

def capture_handoffs(evidence,core_path,baseline_path,capture):
    summaries=[]
    for trial in failed.TRIALS:
        folder=evidence/failed.ORIGINAL/"physical"/trial
        compiled=read(folder/"compiled.json");profile=make_profile(compiled,read(folder/"inputs.json"))
        originals=list(read_jsonl(folder/"controller.jsonl"))[:62];outputs=[];artifacts=[]
        for repeat in range(2):
            for core_index,core_file in enumerate((core_path,baseline_path)):
                core=bridge.LocomotionCore(core_file);model=frozen_model(core)
                host=HierarchicalHoldController(core,compiled,controller_contract(hold_declaration(),model),model,trial,profile)
                rows=[]
                try:
                    for index,old in enumerate(originals):
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                        # Persist the completed host even if a later comparison detects differences.
                        rows.append(row)
                        require(terminal_error(row) is None,"Repeatability unexpected host refusal")
                        if index<60:require(all(same_bits(v,old[k]) for k,v in row.items()),"Repeatability unchanged prefix")
                        else:
                            allocation=row["force_reference"]["decision"]["allocation"]
                            require(row["resolution"]["provider_status"]=="applied" and allocation["accepted"]
                                and allocation["primary"]["full_certificate"]["accepted"]
                                and allocation["selected"]["full_certificate"]["accepted"],"Repeatability original acceptance")
                finally:
                    host.close()
                    path=capture/(trial+"-repeat"+str(repeat)+"-core"+str(core_index)+".json")
                    write_new(path,dict(trial_id=trial,repeat=repeat,core_sha256=sha(core_file),profile=profile,rows=rows))
                    artifacts.append(dict(path=path.name,sha256=sha(path)))
                require(len(rows)==62 and host.closed,"Repeatability complete host")
                outputs.append(rows)
        comparisons=[]
        for index in range(1,4):
            diff=differences(outputs[0],outputs[index])
            commands=differences([r["native_targets"] for r in outputs[0]],[r["native_targets"] for r in outputs[index]])
            comparisons.append(dict(reference=0,other=index,whole_rows_bitwise_equal=not diff,
                native_targets_bitwise_equal=not commands,difference_count=len(diff),differences=diff,
                native_target_differences=commands))
        summaries.append(dict(trial_id=trial,hosts=4,commands_per_host=62,artifacts=artifacts,comparisons=comparisons))
    return summaries

def audit(output,evidence,core,baseline):
    c=declaration();previous=verify_failed(evidence)
    capture=output.parent/(output.stem+"-hosts");capture.mkdir()
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Repeatability opens no worlds")))
        with patch.object(failed,"verify_public_handoffs",side_effect=lambda e,a,b:capture_handoffs(e,a,b,capture)):
            observed=failed.audit(evidence,core,baseline)
    observed.pop("ok")
    observed["schema_version"]="locolemotion_proximal_repeatability_computation_v1"
    observed["calculation_complete"]=True
    observed["original_gate_replaced_by_diagnostic"]=True
    return dict(schema_version="locolemotion_proximal_repeatability_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),failed_attempt=previous,
        declared_inputs=dict(contract_sha256=sha(CONTRACT),input_bindings=failed.declaration()["input_bindings"],
            core_sha256s=[sha(core),sha(baseline)],states=118,hosts=8,commands=496),
        retained_computation=observed,
        all_replays_bitwise_identical=all(p["whole_rows_bitwise_equal"] for t in observed["public_ghosts"] for p in t["comparisons"]),
        native_targets_bitwise_identical=all(p["native_targets_bitwise_equal"] for t in observed["public_ghosts"] for p in t["comparisons"]),
        original_component_acceptance_granted=False,diagnostic_only=True,
        worlds_opened=0,solver_steps=0,**{k:False for k in failed.DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();value=audit(args.output,EVIDENCE,args.core,args.baseline_core);write_new(args.output,value)
    print(json.dumps(dict(ok=True,all_replays_bitwise_identical=value["all_replays_bitwise_identical"],
        native_targets_bitwise_identical=value["native_targets_bitwise_identical"],worlds_opened=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
