"""Reopen complete native-training artifacts, rewards, moments and update lineage.

The original independent readers replayed every control decision. This closure
checks those immutable audited records and recomputes rewards and updates from
their retained raw trajectories; it opens no physics and does not replay the
expensive production controller a second time.
"""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from unittest.mock import patch

import mujoco
from audit_gpu_batch_execution import read_jsonl
from gpu_measurement_probe import write_new
from residual_training_task import (ROOT,HERE,CONTRACT,FLAGS,GATES,EXPECTED_CONTROLS,read,sha,require,
    declaration,all_plans,stages,trial_plans,bridge,provider,score,assess_comparison,
    load_stage,verify_update,validate_launch_records)
from run_residual_training import inventory
from run_gpu_measurement_probe import source_identity

CLOSURE=HERE/"residual_training_closure_v1.json"
DENIALS=("physical_acceptance_authority","release_authority","equivalence_authority",
         "tier2_complete","tier3_complete","tier3_benefit_established")


def header(record,evidence):
    require(record["schema_version"]=="locolemotion_residual_training_closure_v1"
        and record["synthetic"] is False and record["contract_sha256"]==sha(CONTRACT)
        and record["closure_reader_sha256"]==sha(Path(__file__))
        and all(record[k] is False for k in DENIALS),"Residual training closure identity/authority")
    require(record["ledger_scope"]==declaration("pilot")["ledger_scope"]
        and [a["lane"] for a in record["attempts"]]==["route","pilot"],"Residual training closure lane population")
    evidence=evidence.resolve(strict=True);paths=[]
    for item in record["attempts"]:
        identity=item["attempt_id"]
        require(isinstance(identity,str) and identity.startswith("sdk2-residual-training-")
            and Path(identity).name==identity and "/" not in identity and "\\" not in identity,"Residual closure attempt identity")
        path=(evidence/identity).resolve(strict=True)
        require(path.parent==evidence,"Residual closure evidence boundary")
        require(sha(path/"receipt.json")==item["receipt_sha256"],"Residual closure retained receipt digest")
        paths.append(path)
    return paths


def verify_population(expected,observed):
    require(len({r["path"] for r in expected})==len(expected) and expected==observed,
        "Residual closure complete artifact population")


def validate_stage_documents(claim,worker,audit,c,stage,source):
    plans=trial_plans(c,stage);training=stage!="comparison";count=len(plans)
    require(claim["trials"]==plans and claim["source_commit"]==source
        and worker["ok"] is True and worker["synthetic"] is False and worker["stage"]==stage
        and worker["status"]=="complete_native_training_stage"
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==count
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==count,
        "Residual closure complete native stage")
    require(audit["ok"] is True and audit["synthetic"] is False and audit["source_commit"]==source
        and audit["stage"]==stage and audit["lane"]==c["lane"]
        and audit["training_data_scope"]==c["training_data_scope"]
        and audit["ledger_scope"]==c["ledger_scope"] and worker["ledger_scope"]==c["ledger_scope"]
        and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
        and audit["constructed_cpu_worlds"]==count and audit["constructed_gpu_worlds"]==0
        and audit["controller_rows"]==count*c["outer_steps"] and audit["internal_rows"]==count*c["outer_steps"]*5
        and len(audit["trials"])==count,"Residual closure independent audit population")
    for flag in FLAGS:
        require(worker[flag] is (training and flag=="training_data_authority")
            and audit[flag] is (training and flag=="training_data_authority"),"Residual closure stage authority")
    for plan,result in zip(plans,audit["trials"],strict=True):
        require(all(result.get(k)==v for k,v in plan.items())
            and result["controller_rows"]==c["outer_steps"] and result["internal_rows"]==c["outer_steps"]*5,
            "Residual closure audited trial identity")
    return plans


def compare_score(observed,recomputed):
    require(all(k in observed and observed[k]==v for k,v in recomputed.items()),
        "Residual closure raw reward/moment/quality reconstruction")
    require(observed["diagnostic_eligible"] is (recomputed["first_reward_failure"] is None)
        and (observed["diagnostic_eligible"] or observed["official_quality_m_s"] is None),
        "Residual closure failed official quality")


def summarize(receipt,audits):
    trials=[r for a in audits for r in a["trials"]]
    training=[r for r in trials if r["partition"]=="training"]
    comparison=[r for r in trials if r["partition"]=="development_comparison"]
    return dict(source_commit=receipt["source_commit"],lane=receipt["contract"]["lane"],
        constructed_cpu_worlds=receipt["constructed_cpu_worlds"],constructed_gpu_worlds=receipt["constructed_gpu_worlds"],
        training_worlds=len(training),comparison_worlds=len(comparison),
        controller_rows=sum(r["controller_rows"] for r in trials),internal_rows=sum(r["internal_rows"] for r in trials),
        eligible_trials=sum(r["diagnostic_eligible"] for r in trials),
        negative_trials=sum(not r["diagnostic_eligible"] for r in trials),
        training_supported_features=sum(r["supported_feature_rows"] for r in training),
        training_unsupported_features=sum(sum(r["unsupported_feature_rows"].values()) for r in training),
        completed_stages=receipt["completed_stages"],stage_records=receipt["stage_records"],
        final_comparison=receipt["final_comparison"],owner_wall_s=receipt["wall_s"],
        artifact_count=len(receipt["artifacts"])+1,
        trials=[{k:r[k] for k in ("trial_id","stage","group_id","condition_id","role","direction","sign",
            "partition","provider_model_sha256","policy_sha256","diagnostic_eligible","diagnostic_failure_codes",
            "training_reward","reward_denominator","first_reward_failure","failure_padded_samples",
            "official_quality_m_s","supported_feature_rows","unsupported_feature_rows","nonzero_correction_commands",
            "refused_commands")} for r in trials])


def verify_attempt(item,attempt,core,baseline):
    c=declaration(item["lane"]);receipt=read(attempt/"receipt.json");declared=read(attempt/"declaration.json")
    source=receipt["source_commit"]
    require(receipt["ok"] is True and receipt["synthetic"] is False and receipt["contract"]==c
        and receipt["physical_started"] is True and receipt["source_runtime_unchanged"] is True
        and receipt["zero_world_gate_passed"] is True and receipt["source_status"]==[]
        and receipt["constructed_cpu_worlds"]==c["planned_cpu_worlds"] and receipt["constructed_gpu_worlds"]==0
        and receipt["completed_stages"]==receipt["requested_stages"]==stages(c)
        and receipt["planned_trials"]==all_plans(c) and len(receipt["stage_records"])==len(stages(c)),
        "Residual closure owner completion/population")
    require(declared["binding"]==receipt["binding"] and declared["source_commit"]==source,
        "Residual closure original freeze join")
    verify_population(receipt["artifacts"],inventory(attempt))
    for name,digest in receipt["binding"]["source"].items():
        path=(ROOT/name).resolve(strict=True)
        require(path.is_relative_to(ROOT) and sha(path)==digest,"Residual closure original source bytes")
    for name,digest in receipt["binding"]["runtime"].items():
        require(sha(Path(name))==digest,"Residual closure original runtime bytes")
    counts={name:count for name,_,count in GATES};counts.update(provider=2,containment=1)
    require(receipt["safety_controls"]==counts and sum(counts.values())==EXPECTED_CONTROLS,
        "Residual closure complete safety gate")
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],"Residual closure core identities")
    library=bridge.LocomotionCore(baseline);audits=[]
    for stage,record in zip(stages(c),receipt["stage_records"],strict=True):
        folder=attempt/"stages"/stage;physical=folder/"physical"
        validate_launch_records(physical,c,source)
        claim,_,models=load_stage(folder,c,library);worker=read(physical/"worker-result.json");audit=read(folder/"audit.json")
        plans=validate_stage_documents(claim,worker,audit,c,stage,source)
        require(record["stage"]==stage and record["stage_claim_sha256"]==sha(folder/"stage.json")
            ==worker["stage_claim_sha256"]==audit["stage_claim_sha256"]
            and record["audit_sha256"]==sha(folder/"audit.json")
            and all(record[k]==audit[k] for k in ("constructed_cpu_worlds","controller_rows","internal_rows")),
            "Residual closure stage receipt joins")
        for plan,worker_trial,observed in zip(plans,worker["trials"],audit["trials"],strict=True):
            trial=physical/plan["trial_id"];model=models[plan["model_key"]];result=read(trial/"result.json")
            require(result==worker_trial and result["completed"] is True and result["controller_closed"] is True
                and result["hashes"]==observed["raw_hashes"] and result["provider_model_sha256"]==model.sha256
                ==observed["provider_model_sha256"] and observed["policy_sha256"]==model.policy.sha256
                and read(trial/"provider-model.json")==model.document(),"Residual closure trial/model joins")
            require(read(trial/"world-opened.json")==dict(trial_id=plan["trial_id"],native_data_constructed=True,
                core_sha256=c["core_sha256"],provider_model_sha256=model.sha256),"Residual closure native construction")
            for name,digest in result["hashes"].items():
                require(name in ("controller","trace","timing") and sha(trial/(name+".jsonl"))==digest,
                    "Residual closure audited raw stream")
            controls=list(read_jsonl(trial/"controller.jsonl"));trace=list(read_jsonl(trial/"trace.jsonl"))
            compare_score(observed,score(controls,trace,c,training=stage!="comparison"))
        if stage!="comparison":
            verified=verify_update(folder,c,library,require_verification=True)
            require(record["update_sha256"]==sha(folder/"update.json")
                and record["verified_update_sha256"]==sha(folder/"verified-update.json")
                and record["model_sha256"]==verified["model_sha256"]
                and record["normalizer_sample_count"]==verified["normalizer_sample_count"],
                "Residual closure audited optimizer lineage")
        else:
            require(audit["final_comparison"]==assess_comparison(audit["trials"],c)==receipt["final_comparison"],
                "Residual closure final fixed comparison")
        audits.append(audit)
    summary=summarize(receipt,audits)
    require(summary==item["summary"],"Residual closure finite summary")
    return summary


def verify_record(path,evidence,core,baseline):
    source_identity(False)
    record=read(path);attempts=header(record,evidence);summaries=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Training closure opens no worlds")))
        for item,attempt in zip(record["attempts"],attempts,strict=True):
            summaries.append(verify_attempt(item,attempt,core,baseline))
        route,pilot=[read(p/"receipt.json") for p in attempts]
        require(pilot["source_commit"]==route["source_commit"]==record["source_commit"]
            and pilot["execution_fixture"]==dict(attempt_id=attempts[0].name,receipt_sha256=sha(attempts[0]/"receipt.json"),
                use="execution_path_gate_only",training_initialization=False),"Residual closure isolated execution-fixture prerequisite")
    return dict(ok=True,schema_version="locolemotion_residual_training_closure_audit_v1",
        ledger_scope=record["ledger_scope"],closure_sha256=sha(path),source_commit=record["source_commit"],
        original_constructed_cpu_worlds=sum(s["constructed_cpu_worlds"] for s in summaries),
        original_controller_rows=sum(s["controller_rows"] for s in summaries),
        original_internal_rows=sum(s["internal_rows"] for s in summaries),
        reader_world_build_count=0,reader_solver_steps=0,rewards_moments_updates_recomputed=True,
        original_control_replay_receipts_preserved=True,control_decisions_replayed_again=False,
        summaries=summaries,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--closure",type=Path,default=CLOSURE)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    result=verify_record(args.closure,args.evidence_root,args.core,args.baseline_core);write_new(args.output,result)
    print(json.dumps({k:result[k] for k in ("ok","original_constructed_cpu_worlds","original_controller_rows","reader_world_build_count")}))
    return 0


if __name__=="__main__":raise SystemExit(main())
