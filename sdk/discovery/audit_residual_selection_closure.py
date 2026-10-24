"""Reopen the complete fixed-artifact comparison without new physics or fitting."""
import argparse
from contextlib import ExitStack
from pathlib import Path
import json
from unittest.mock import patch

import mujoco
import residual_selection_task as task
from residual_selection_task import ROOT,HERE,read,sha,require,FLAGS
from run_residual_selection import inventory
from run_gpu_measurement_probe import source_identity
from gpu_measurement_probe import write_new
from audit_gpu_batch_execution import read_jsonl
from audit_residual_training_closure import verify_population,compare_score,summarize

CLOSURE=HERE/"residual_selection_closure_v1.json"
DENIALS=("physical_acceptance_authority","release_authority","equivalence_authority",
    "tier2_complete","tier3_complete","tier3_benefit_established")


def header(record,evidence):
    require(record["schema_version"]=="locolemotion_residual_selection_closure_v1"
        and record["synthetic"] is False and all(record[k] is False for k in DENIALS)
        and record["contract_path"]==task.CONTRACT.relative_to(ROOT).as_posix()
        and record["contract_sha256"]==sha(task.CONTRACT)
        and record["selection_record_sha256"]==sha(task.selection.FIT)
        and record["selected_model_sha256"]=="sha256:"+sha(task.selection.MODEL)
        and record["closure_reader_sha256"]==sha(Path(__file__))
        and record["ledger_scope"]==task.declaration()["ledger_scope"],"Residual selection closure identity/authority")
    identity=record["attempt_id"]
    require(isinstance(identity,str) and identity.startswith("sdk2-residual-selection-")
        and Path(identity).name==identity and "/" not in identity and "\\" not in identity,
        "Residual selection closure attempt identity")
    evidence=evidence.resolve(strict=True);attempt=(evidence/identity).resolve(strict=True)
    require(attempt.parent==evidence and sha(attempt/"receipt.json")==record["receipt_sha256"],
        "Residual selection closure evidence/receipt identity")
    return attempt


def validate_documents(receipt,declared,claim,worker,audit,c,source):
    plans=task.all_plans(c);count=len(plans)
    require(receipt["ok"] is True and receipt["synthetic"] is False and receipt["contract"]==c
        and receipt["source_commit"]==source and receipt["physical_started"] is True
        and receipt["source_runtime_unchanged"] is True and receipt["zero_world_gate_passed"] is True
        and receipt["source_status"]==[] and receipt["planned_trials"]==plans
        and receipt["completed_stages"]==receipt["requested_stages"]==["comparison"]
        and receipt["constructed_cpu_worlds"]==count and receipt["constructed_gpu_worlds"]==0
        and len(receipt["stage_records"])==1 and receipt["selection_is_retrospective"] is True
        and receipt["comparison_data_used_for_fitting"] is False
        and all(receipt[k] is False for k in FLAGS),"Residual selected closure complete owner")
    require(declared["binding"]==receipt["binding"] and declared["source_commit"]==source
        and declared["contract"]==c and declared["source_status"]==[],"Residual selected closure original freeze")
    require(claim["trials"]==plans and claim["source_commit"]==source and claim["stage"]=="comparison"
        and worker["ok"] is True and worker["synthetic"] is False and worker["stage"]=="comparison"
        and worker["status"]=="complete_native_selection_comparison"
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==count
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==count,
        "Residual selected closure complete native population")
    require(audit["ok"] is True and audit["synthetic"] is False and audit["source_commit"]==source
        and audit["stage"]==audit["lane"]=="comparison" and audit["ledger_scope"]==worker["ledger_scope"]==c["ledger_scope"]
        and audit["training_data_scope"]==worker["training_data_scope"]==c["training_data_scope"]
        and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
        and audit["constructed_cpu_worlds"]==count and audit["constructed_gpu_worlds"]==0
        and audit["controller_rows"]==count*c["outer_steps"] and audit["internal_rows"]==count*c["outer_steps"]*5
        and len(audit["trials"])==count and all(audit[k] is worker[k] is False for k in FLAGS),
        "Residual selected closure independent population/authority")
    for plan,row in zip(plans,audit["trials"],strict=True):
        require(all(row.get(k)==v for k,v in plan.items())
            and row["controller_rows"]==c["outer_steps"] and row["internal_rows"]==c["outer_steps"]*5,
            "Residual selected closure audited trial identity")
    return plans


def verify_record(path,evidence,core,baseline):
    source_identity(False);record=read(path);attempt=header(record,evidence);c=task.declaration()
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],"Residual selected closure core identity")
    receipt=read(attempt/"receipt.json");source=record["source_commit"]
    observed_inventory=inventory(attempt);verify_population(receipt["artifacts"],observed_inventory)
    indexed={r["path"]:r for r in observed_inventory}
    for name,digest in receipt["binding"]["source"].items():
        p=(ROOT/name).resolve(strict=True)
        require(p.is_relative_to(ROOT) and sha(p)==digest,"Residual selected closure original source bytes")
    for name,digest in receipt["binding"]["runtime"].items():
        require(sha(Path(name))==digest,"Residual selected closure original runtime bytes")
    counts={name:n for name,_,n in task.GATES};counts.update(provider=2,containment=1)
    require(receipt["safety_controls"]==counts and sum(counts.values())==task.EXPECTED_CONTROLS,
        "Residual selected closure complete launch gate")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Selection closure opens no physics")))
        folder=attempt/"stages/comparison";physical=folder/"physical"
        task.validate_launch_records(physical,c,source)
        library=task.bridge.LocomotionCore(baseline);claim,_,models=task.load_stage(folder,c,library)
        audit=read(folder/"audit.json");worker=read(physical/"worker-result.json")
        plans=validate_documents(receipt,read(attempt/"declaration.json"),claim,worker,audit,c,source)
        stage=receipt["stage_records"][0]
        require(stage["stage"]=="comparison" and stage["stage_claim_sha256"]==sha(folder/"stage.json")
            ==worker["stage_claim_sha256"]==audit["stage_claim_sha256"]
            and stage["audit_sha256"]==sha(folder/"audit.json")
            and all(stage[k]==audit[k] for k in ("constructed_cpu_worlds","controller_rows","internal_rows")),
            "Residual selected closure stage joins")
        for plan,original,row in zip(plans,worker["trials"],audit["trials"],strict=True):
            trial=physical/plan["trial_id"];model=models[plan["model_key"]];result=read(trial/"result.json")
            require(result==original and result["completed"] is True and result["controller_closed"] is True
                and result["hashes"]==row["raw_hashes"] and result["provider_model_sha256"]==model.sha256
                ==row["provider_model_sha256"] and row["policy_sha256"]==model.policy.sha256
                and read(trial/"provider-model.json")==model.document(),"Residual selected closure artifact/trial join")
            require(read(trial/"world-opened.json")==dict(trial_id=plan["trial_id"],native_data_constructed=True,
                core_sha256=c["core_sha256"],provider_model_sha256=model.sha256),"Residual selected closure construction")
            for name,digest in result["hashes"].items():
                require(name in ("controller","trace","timing") and
                    indexed[(trial/(name+".jsonl")).relative_to(attempt).as_posix()]["sha256"]==digest,
                    "Residual selected closure audited raw stream")
            score=task.score(list(read_jsonl(trial/"controller.jsonl")),list(read_jsonl(trial/"trace.jsonl")),c,training=False)
            compare_score(row,score)
        comparison=task.assess_comparison(audit["trials"],c)
        require(audit["final_comparison"]==receipt["final_comparison"]==comparison,
            "Residual selected closure fixed comparison")
    summary=summarize(receipt,[audit])
    require(summary==record["summary"],"Residual selected closure complete finite summary")
    return dict(ok=True,schema_version="locolemotion_residual_selection_closure_audit_v1",
        ledger_scope=record["ledger_scope"],closure_sha256=sha(path),source_commit=source,
        original_constructed_cpu_worlds=summary["constructed_cpu_worlds"],
        original_controller_rows=summary["controller_rows"],original_internal_rows=summary["internal_rows"],
        reader_world_build_count=0,reader_solver_steps=0,raw_rewards_quality_and_comparison_recomputed=True,
        frozen_training_selection_reconstructed=True,original_control_replay_receipt_preserved=True,
        control_decisions_replayed_again=False,summary=summary,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--closure",type=Path,default=CLOSURE)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    result=verify_record(args.closure,args.evidence_root,args.core,args.baseline_core);write_new(args.output,result)
    print(json.dumps({k:result[k] for k in ("ok","original_constructed_cpu_worlds","original_controller_rows","reader_world_build_count")}))
    return 0


if __name__=="__main__":raise SystemExit(main())
