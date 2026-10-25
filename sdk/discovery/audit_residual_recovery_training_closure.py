"""Reconstruct both recovery-learning lanes from retained native evidence."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
import re
from unittest.mock import patch

import mujoco
import residual_recovery_training_task as task
from residual_recovery_training_task import ROOT,HERE,read,sha,require,FLAGS
from run_residual_recovery_training import inventory,validate_route_attempt,verify_tests
from run_gpu_measurement_probe import source_identity
from gpu_measurement_probe import write_new
from audit_gpu_batch_execution import read_jsonl
from audit_residual_training_closure import verify_population,compare_score,summarize
from residual_recovery_metrics import transitions,paired_prefix
from audit_residual_recovery_closure import compare_recovery,compare_prefix

CLOSURE=HERE/"residual_recovery_training_closure_v1.json"
DENIALS=("physical_acceptance_authority","release_authority","equivalence_authority",
    "tier2_complete","tier3_complete","tier3_benefit_established","safe_backup_established",
    "sufficient_intervention_lead_established","threshold_has_independent_validation")


def header(record,evidence):
    c=task.declaration("pilot")
    require(record["schema_version"]=="locolemotion_residual_recovery_training_closure_v1"
        and record["status"]=="complete_native_recovery_training_development"
        and record["synthetic"] is False and all(record[k] is False for k in DENIALS)
        and record["contract_path"]==task.CONTRACT.relative_to(ROOT).as_posix()
        and record["contract_sha256"]==sha(task.CONTRACT)
        and record["predecessor_closure_sha256"]==sha(task.CLOSURE)
        and record["warm_start_model_sha256"]==c["warm_start_model_sha256"]
        and record["challenge_actor_sha256"]==c["challenge_actor_sha256"]
        and record["warm_start_recovery_actor_sha256"]==c["warm_start_recovery_actor_sha256"]
        and record["warning_model_sha256"]==c["warning_model_sha256"]
        and record["closure_reader_path"]==Path(__file__).relative_to(ROOT).as_posix()
        and record["closure_reader_sha256"]==sha(Path(__file__))
        and record["ledger_scope"]==c["ledger_scope"],"Recovery training closure identity/authority")
    require(record["complete_safety_controls"]==task.EXPECTED_CONTROLS
        and record["closure_controls_required"]==12 and record["reserved_starts_opened"]==0
        and record["route_data_initialized_pilot"] is False
        and record["comparison_data_used_for_fitting"] is False
        and record["comparison_data_used_for_selection"] is False
        and record["return_to_challenge_permitted"] is False
        and record["input_normalizer_updated"] is False,"Recovery training closure metadata scope")
    require([a["lane"] for a in record["attempts"]]==["route","pilot"],"Recovery training closure lane population")
    evidence=evidence.resolve(strict=True);attempts={}
    for item in record["attempts"]:
        identity=item["attempt_id"]
        require(isinstance(identity,str) and re.fullmatch(r"sdk2-recovery-training-[0-9a-f]{32}",identity) is not None,
            "Recovery training closure attempt identity")
        attempt=(evidence/identity).resolve(strict=True)
        require(attempt.parent==evidence,"Recovery training closure evidence boundary")
        validate_evidence_links(item,attempt);attempts[item["lane"]]=attempt
    require(len(set(attempts.values()))==2,"Recovery training closure repeated lane identity")
    return attempts


def validate_evidence_links(item,attempt):
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("gate_receipt_sha256","gate-receipt.json"),("consumed_sha256","consumed.json"),
            ("selection_sha256","training-selection.json"),("verified_selection_sha256","verified-selection.json"),
            ("selected_model_sha256","selected-model.json")):
        require(item[key]==sha(attempt/name),"Recovery training closure evidence record digest")


def validate_owner(receipt,declared,c,source):
    require(receipt["ok"] is True and receipt["synthetic"] is False and receipt["contract"]==c
        and receipt["source_commit"]==source and receipt["physical_started"] is True
        and receipt["source_runtime_unchanged"] is True and receipt["zero_world_gate_passed"] is True
        and receipt["source_status"]==[] and receipt["planned_trials"]==task.all_plans(c)
        and receipt["completed_stages"]==receipt["requested_stages"]==task.stages(c)
        and receipt["constructed_cpu_worlds"]==c["planned_cpu_worlds"] and receipt["constructed_gpu_worlds"]==0
        and len(receipt["stage_records"])==len(task.stages(c))
        and receipt["ledger_scope"]==c["ledger_scope"]
        and receipt["training_data_scope"]==c["training_data_scope"]
        and receipt["planned_worlds"]==dict(cpu=c["planned_cpu_worlds"],gpu=0)
        and receipt["physical_launch_requested"] is True
        and all(receipt[k] is (k=="training_data_authority") for k in FLAGS),
        "Recovery training closure complete owner")
    require(declared["binding"]==receipt["binding"] and declared["source_commit"]==source
        and declared["contract"]==c and declared["source_status"]==[]
        and declared["ledger_scope"]==c["ledger_scope"],"Recovery training closure original freeze")


def validate_stage(claim,worker,audit,c,source,stage):
    plans=task.trial_plans(c,stage);count=len(plans);fitting=stage!="comparison"
    require(claim["trials"]==plans and claim["source_commit"]==source and claim["stage"]==stage
        and worker["ok"] is True and worker["synthetic"] is False and worker["stage"]==stage
        and worker["status"]=="complete_native_recovery_training_stage"
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==count
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==count,
        "Recovery training closure complete native stage")
    require(audit["ok"] is True and audit["synthetic"] is False and audit["source_commit"]==source
        and audit["stage"]==stage and audit["lane"]==c["lane"]
        and audit["ledger_scope"]==worker["ledger_scope"]==c["ledger_scope"]
        and audit["training_data_scope"]==worker["training_data_scope"]==c["training_data_scope"]
        and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
        and audit["constructed_cpu_worlds"]==count and audit["constructed_gpu_worlds"]==0
        and audit["controller_rows"]==count*c["outer_steps"] and audit["internal_rows"]==count*c["outer_steps"]*5
        and len(audit["trials"])==count
        and all(audit[k] is (fitting and k=="training_data_authority")
            and worker[k] is (fitting and k=="training_data_authority") for k in FLAGS),
        "Recovery training closure independent stage/authority")
    for plan,row in zip(plans,audit["trials"],strict=True):
        require(all(row.get(k)==v for k,v in plan.items())
            and row["controller_rows"]==c["outer_steps"] and row["internal_rows"]==c["outer_steps"]*5,
            "Recovery training closure audited trial identity")
        if plan["role"]!="search":
            require(row["observations"] is None and row["training_data_authority"] is False,
                "Recovery training closure reference/comparison fitting")
    return plans


def validate_initialization(claim,c):
    require(claim["parent_model_sha256"]==c["warm_start_model_sha256"]
        and claim["previous_verified_update_sha256"] is None,
        "Recovery training closure independently initialized lane")


def summary(receipt,audits,selection):
    result=summarize(receipt,audits)
    trials=[r for a in audits for r in a["trials"]]
    result.update(development_reference_worlds=sum(r["partition"]=="development_reference" for r in trials),
        training_selection=selection["selection"],selected_source=selection["selected_source"],
        input_normalizer_updated=False,route_data_initialized_pilot=False,
        exact_paired_prefixes=sum("paired_prefix" in r for r in trials))
    for compact,row in zip(result["trials"],trials,strict=True):
        for key in ("recovery_policy_sha256","recovery_model_sha256","actor_model_sha256","warning_model_sha256",
                "recovery_objective","walking_reward_diagnostic","recovery"):
            compact[key]=row[key]
        if "paired_prefix" in row:compact["paired_prefix"]=row["paired_prefix"]
    return result


def verify_attempt(attempt,item,c,source,core,baseline):
    receipt=read(attempt/"receipt.json")
    validate_owner(receipt,read(attempt/"declaration.json"),c,source)
    observed_inventory=inventory(attempt);verify_population(receipt["artifacts"],observed_inventory)
    indexed={r["path"]:r for r in observed_inventory}
    require(item["source_binding_count"]==len(receipt["binding"]["source"])
        and item["runtime_binding_count"]==len(receipt["binding"]["runtime"]),
        "Recovery training closure binding counts")
    for name,digest in receipt["binding"]["source"].items():
        path=(ROOT/name).resolve(strict=True)
        require(path.is_relative_to(ROOT) and sha(path)==digest,"Recovery training closure original source bytes")
    for name,digest in receipt["binding"]["runtime"].items():
        require(sha(Path(name))==digest,"Recovery training closure original runtime bytes")
    counts={name:n for name,_,n in task.GATES};counts.update(provider=2,containment=1)
    require(receipt["safety_controls"]==counts and sum(counts.values())==task.EXPECTED_CONTROLS,
        "Recovery training closure complete launch gate")
    for name,count in counts.items():verify_tests(attempt/(name+"-gate"),count)
    audits=[];library=task.bridge.LocomotionCore(baseline)
    for index,stage in enumerate(task.stages(c)):
        folder=attempt/"stages"/stage;physical=folder/"physical"
        task.validate_launch_records(physical,c,source)
        claim,_,models=task.load_stage(folder,c,library)
        audit=read(folder/"audit.json");worker=read(physical/"worker-result.json")
        plans=validate_stage(claim,worker,audit,c,source,stage)
        require(sorted(p.parent.name for p in physical.glob("*/world-opened.json"))
            ==sorted(p["trial_id"] for p in plans),"Recovery training closure constructed marker population")
        stage_record=receipt["stage_records"][index]
        require(stage_record["stage"]==stage and stage_record["stage_claim_sha256"]==sha(folder/"stage.json")
            ==worker["stage_claim_sha256"]==audit["stage_claim_sha256"]
            and stage_record["audit_sha256"]==sha(folder/"audit.json")
            and all(stage_record[k]==audit[k] for k in ("constructed_cpu_worlds","controller_rows","internal_rows")),
            "Recovery training closure stage joins")
        if stage=="iteration_00":
            validate_initialization(claim,c)
        for plan,original,row in zip(plans,worker["trials"],audit["trials"],strict=True):
            trial=physical/plan["trial_id"];model=models[plan["model_key"]];result=read(trial/"result.json")
            require(result==original and result["completed"] is True and result["controller_closed"] is True
                and result["outer_rows"]==c["outer_steps"] and result["internal_rows"]==c["outer_steps"]*5
                and result["hashes"]==row["raw_hashes"] and set(result["hashes"])=={"controller","trace","timing"}
                and result["provider_model_sha256"]==model.sha256==row["provider_model_sha256"]
                and read(trial/"provider-model.json")==model.document()
                and "sha256:"+sha(trial/"provider-model.json")==model.sha256,
                "Recovery training closure artifact/trial join")
            require(read(trial/"world-opened.json")==dict(trial_id=plan["trial_id"],native_data_constructed=True,
                core_sha256=c["core_sha256"],provider_model_sha256=model.sha256),
                "Recovery training closure construction")
            for name,digest in result["hashes"].items():
                require(indexed[(trial/(name+".jsonl")).relative_to(attempt).as_posix()]["sha256"]==digest,
                    "Recovery training closure audited raw stream")
            controls=list(read_jsonl(trial/"controller.jsonl"))
            score=task.score(controls,list(read_jsonl(trial/"trace.jsonl")),c,training=plan["role"]=="search")
            compare_score(row,score)
            compare_recovery(row,transitions(controls,score["first_reward_failure"],c,model,plan["mode"]))
            require(row["actor_model_sha256"]==model.actor.sha256
                and row["recovery_model_sha256"]==model.recovery.sha256
                and row["policy_sha256"]==model.policy.sha256
                and row["recovery_policy_sha256"]==model.recovery.policy.sha256
                and row["warning_model_sha256"]==model.warning.sha256,
                "Recovery training closure actor/warning identities")
            if plan["mode"]=="early_selected":
                reference=next(p for p in plans if p["group_id"]==plan["group_id"] and p["role"]=="challenge_only")
                compare_prefix(row,paired_prefix(trial,physical/reference["trial_id"],row["recovery"],c))
            print(json.dumps(dict(lane=c["lane"],stage=stage,trial=plan["trial_id"],raw_reconstruction=True)),flush=True)
        if stage!="comparison":
            verified=task.verify_update(folder,c,library,require_verification=True)
            require(stage_record["update_sha256"]==sha(folder/"update.json")
                and stage_record["verified_update_sha256"]==sha(folder/"verified-update.json")
                and stage_record["model_sha256"]==verified["model_sha256"]
                and stage_record["recovery_policy_sha256"]==verified["recovery_policy_sha256"]
                and stage_record["normalizer_updated"] is verified["normalizer_updated"] is False,
                "Recovery training closure fixed-scaling update")
        else:
            require(audit["final_comparison"]==receipt["final_comparison"]==task.assess_comparison(audit["trials"],c),
                "Recovery training closure fixed comparison")
        audits.append(audit)
    verified=task.verify_selection(attempt,c,library,require_verification=True)
    require(receipt["selection_verification"]==verified,"Recovery training closure selected-model verification")
    result=summary(receipt,audits,read(attempt/"training-selection.json"))
    require(result==item["summary"],"Recovery training closure complete finite summary")
    return receipt,result


def verify_record(path,evidence,core,baseline):
    source_identity(False);record=read(path);attempts=header(record,evidence)
    c=task.declaration("pilot")
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],
        "Recovery training closure core identity")
    summaries={};receipts={}
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Recovery training closure opens no physics")))
        for item in record["attempts"]:
            lane=item["lane"]
            receipts[lane],summaries[lane]=verify_attempt(attempts[lane],item,task.declaration(lane),
                record["source_commit"],core,baseline)
        expected=validate_route_attempt(attempts["route"],record["source_commit"],c,receipts["pilot"]["binding"])
        require(receipts["pilot"]["execution_fixture"]==expected,"Recovery training closure exact route prerequisite")
    total=dict(constructed_cpu_worlds=sum(s["constructed_cpu_worlds"] for s in summaries.values()),
        constructed_gpu_worlds=sum(s["constructed_gpu_worlds"] for s in summaries.values()),
        controller_rows=sum(s["controller_rows"] for s in summaries.values()),
        internal_rows=sum(s["internal_rows"] for s in summaries.values()),
        exact_paired_prefixes=sum(s["exact_paired_prefixes"] for s in summaries.values()))
    require(total==record["totals"],"Recovery training closure aggregate population")
    return dict(ok=True,schema_version="locolemotion_residual_recovery_training_closure_audit_v1",
        ledger_scope=record["ledger_scope"],closure_sha256=sha(path),source_commit=record["source_commit"],
        original_counts=total,reader_world_build_count=0,reader_solver_steps=0,
        raw_rewards_moments_quality_and_comparison_recomputed=True,
        all_updates_and_training_selection_reconstructed=True,input_normalizer_updated=False,
        fresh_challenge_prefixes_recomputed=True,route_data_initialized_pilot=False,
        original_control_replay_receipts_preserved=True,control_decisions_replayed_again=False,
        summaries=summaries,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--closure",type=Path,default=CLOSURE)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    result=verify_record(args.closure,args.evidence_root,args.core,args.baseline_core)
    write_new(args.output,result)
    print(json.dumps(dict(ok=True,original_counts=result["original_counts"],reader_world_build_count=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
