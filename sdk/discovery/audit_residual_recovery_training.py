"""Other-core raw replay and zero-world update/selection verification."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from unittest.mock import patch

import mujoco
from audit_residual_recovery import audit_trial
from audit_gpu_batch_execution import read_jsonl
from residual_recovery_metrics import transitions,paired_prefix
from residual_recovery_training_task import (ROOT,FLAGS,declaration,require,sha,provider,bridge,read,
    load_stage,score,assess_comparison,verify_update,verify_selection,validate_launch_records)
from gpu_measurement_probe import write_new


def audit(folder,core_path,baseline_path,lane):
    c=declaration(lane);stage=folder.parent.name;training=stage!="comparison"
    from run_residual_recovery_training import bindings
    from run_gpu_measurement_probe import source_identity
    source=source_identity(True);owner=validate_launch_records(folder,c,source)
    require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"]
        and bindings(core_path,baseline_path)==owner["binding"],"Residual training independent source/runtime freeze")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual training audit opens no world")))
        core=bridge.LocomotionCore(baseline_path)
        claim,_,models=load_stage(folder.parent,c,core);worker=read(folder/"worker-result.json");plans=claim["trials"]
        require(worker["ok"] is True and worker["synthetic"] is False and worker["stage"]==stage
            and worker["status"]=="complete_native_recovery_training_stage" and worker["ledger_scope"]==c["ledger_scope"]
            and worker["training_data_scope"]==c["training_data_scope"]
            and worker["stage_claim_sha256"]==sha(folder.parent/"stage.json")
            and all(worker[k] is (training and k=="training_data_authority") for k in FLAGS),
            "Residual training worker completion/authority")
        require(worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==len(plans)
            and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==len(plans),"Residual training stage denominator")
        trials=[]
        for plan,observed in zip(plans,worker["trials"],strict=True):
            trial=folder/plan["trial_id"];model=models[plan["model_key"]]
            require(observed==read(trial/"result.json"),"Residual training worker/trial join")
            require(read(trial/"world-opened.json")==dict(trial_id=plan["trial_id"],native_data_constructed=True,
                core_sha256=c["core_sha256"],provider_model_sha256=model.sha256),"Residual training construction marker")
            result=audit_trial(trial,plan,c,baseline_path,core,model.document())
            controls=list(read_jsonl(trial/"controller.jsonl"));trace=list(read_jsonl(trial/"trace.jsonl"))
            scored=score(controls,trace,c,training=plan["role"]=="search")
            require(result["diagnostic_eligible"] is (scored["first_reward_failure"] is None),"Residual score/physical eligibility join")
            result.update(scored,policy_sha256=model.policy.sha256,recovery_policy_sha256=model.recovery.policy.sha256,
                actor_model_sha256=model.actor.sha256,recovery_model_sha256=model.recovery.sha256,
                warning_model_sha256=model.warning.sha256,
                recovery=transitions(controls,scored["first_reward_failure"],c,model,plan["mode"]))
            trials.append(result)
            print(json.dumps(dict(audited_trial=plan["trial_id"],eligible=result["diagnostic_eligible"],
                reward=result["training_reward"],official_quality=result["official_quality_m_s"])),flush=True)
        for result in trials:
            if result["mode"].startswith(("early_","warning_")):
                reference=next(r for r in trials if r["group_id"]==result["group_id"] and r["role"]=="challenge_only")
                result["paired_prefix"]=paired_prefix(folder/result["trial_id"],folder/reference["trial_id"],result["recovery"],c)
        comparison=assess_comparison(trials,c) if not training else None
    require(source_identity(True)==source and bindings(core_path,baseline_path)==owner["binding"],
        "Residual training audit source/runtime drift")
    return dict(schema_version="locolemotion_residual_recovery_training_audit_v1",ok=True,synthetic=False,
        source_commit=source,stage=stage,lane=lane,stage_claim_sha256=sha(folder.parent/"stage.json"),
        ledger_scope=c["ledger_scope"],training_data_scope=c["training_data_scope"],trials=trials,
        reader_world_build_count=0,reader_solver_steps=0,constructed_cpu_worlds=len(plans),constructed_gpu_worlds=0,
        controller_rows=len(plans)*c["outer_steps"],internal_rows=len(plans)*c["outer_steps"]*5,
        final_comparison=comparison,controller_selection_authority=False,tier3_benefit_established=False,
        **{k:training and k=="training_data_authority" for k in FLAGS})


def verify_artifact(folder,core_path,baseline_path,lane,selection=False):
    from run_residual_recovery_training import bindings
    from run_gpu_measurement_probe import source_identity
    c=declaration(lane);source=source_identity(True)
    physical=(folder/"stages/iteration_00/physical") if selection else folder/"physical"
    owner=validate_launch_records(physical,c,source)
    require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"]
        and bindings(core_path,baseline_path)==owner["binding"],"Recovery artifact source/runtime freeze")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Recovery artifact verification opens no world")))
        core=bridge.LocomotionCore(baseline_path)
        result=verify_selection(folder,c,core) if selection else verify_update(folder,c,core)
    require(source_identity(True)==source and bindings(core_path,baseline_path)==owner["binding"],
        "Recovery artifact source/runtime drift")
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--folder",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--lane",choices=("route","pilot"),required=True);p.add_argument("--output",type=Path,required=True)
    choices=p.add_mutually_exclusive_group()
    choices.add_argument("--verify-update",action="store_true");choices.add_argument("--verify-selection",action="store_true")
    args=p.parse_args()
    if args.verify_update or args.verify_selection:
        result=verify_artifact(args.folder,args.core,args.baseline_core,args.lane,args.verify_selection)
    else:result=audit(args.folder,args.core,args.baseline_core,args.lane)
    write_new(args.output,result);print(json.dumps(dict(ok=result["ok"],output=str(args.output))),flush=True)
    return 0


if __name__=="__main__":raise SystemExit(main())
