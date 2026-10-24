"""Reopen the consumed residual route using retained bytes and its frozen source."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
import re
from unittest.mock import patch

import mujoco
from audit_residual_native import read, audit_trial, compare_native_paths, bridge
from residual_native import validate_launch_records
from residual_native_task import ROOT, CONTRACT, FLAGS, GATES, EXPECTED_CONTROLS, declaration, trial_plan, require, sha
from audit_gpu_repertoire_negative_closure import verify_frozen_sources
from gpu_measurement_probe import write_new

CLOSURE=Path(__file__).with_name("residual_native_closure_v1.json")
AUTHORITY_FLAGS=(*FLAGS,"controller_selection_authority","tier3_benefit_established")
GATE_COUNTS={**{name:count for name,_,count in GATES},"provider":2,"containment":1}


def finite_summary(observed):
    keys=("trial_id","role","condition_id","partition","seed","controller_rows","internal_rows",
          "provider_model_sha256","control_applied_commands","nonzero_correction_commands",
          "refused_commands","diagnostic_metrics","diagnostic_failure_codes","diagnostic_eligible",
          "official_quality_m_s","selection_authority")
    return dict(native_path_comparison=observed["native_path_comparison"],
        trials=[{k:t[k] for k in keys} for t in observed["trials"]],
        training_data_authority=False,controller_selection_authority=False,
        adaptation_benefit_established=False,tier3_benefit_established=False,release_authority=False)


def header(record,evidence_root):
    c=declaration()
    require(record["schema_version"]=="locolemotion_residual_native_closure_v1"
        and record["status"]=="complete_native_residual_route" and record["synthetic"] is False
        and record["ledger_scope"]==c["ledger_scope"] and all(record[k] is False for k in AUTHORITY_FLAGS),
        "Residual closure identity/authority")
    require(record["native_route_verified"] is True and record["trial_count"]==record["constructed_cpu_worlds"]==3
        and record["constructed_gpu_worlds"]==record["training_worlds"]==record["evaluation_worlds"]==0
        and record["controller_rows"]==360 and record["internal_rows"]==1800
        and record["complete_zero_world_gate"]==GATE_COUNTS and sum(GATE_COUNTS.values())==86,
        "Residual closure denominator/gate")
    root=evidence_root.resolve(strict=True)
    require(re.fullmatch(r"sdk2-residual-native-[0-9a-f]{32}",record["attempt_id"]) is not None,
        "Residual closure attempt identity")
    attempt=(root/record["attempt_id"]).resolve(strict=True)
    require(attempt.parent==root,"Residual closure attempt escaped")
    entries=record["artifacts"];paths=[]
    require(type(record["artifact_count"]) is int and record["artifact_count"]==len(entries)>0,
        "Residual closure artifact count")
    for item in entries:
        relative=Path(item["evidence_relative_path"])
        require(not relative.is_absolute() and ".." not in relative.parts,"Residual closure artifact escaped")
        path=(root/relative).resolve(strict=True)
        require(path.is_relative_to(attempt) and path.is_file(),"Residual closure artifact escaped")
        require(type(item["byte_length"]) is int and item["byte_length"]>=0
            and re.fullmatch("[0-9a-f]{64}",item["sha256"]) is not None,"Residual closure artifact binding")
        paths.append(path)
    require(len(paths)==len(set(paths)) and set(paths)=={p.resolve() for p in attempt.rglob("*") if p.is_file()},
        "Residual closure incomplete/duplicate inventory")
    require(record["artifact_bytes"]==sum(e["byte_length"] for e in entries),"Residual closure artifact bytes")
    return attempt,paths


def verify_artifacts(record,paths):
    for item,path in zip(record["artifacts"],paths,strict=True):
        require(path.stat().st_size==item["byte_length"] and sha(path)==item["sha256"],
            "Residual closure retained artifact changed")


def verify_joins(record,declared,receipt,worker,observed,gate,consumed):
    c=declaration();plans=trial_plan(c)
    require(declared["contract"]==receipt["contract"]==c
        and declared["source_commit"]==receipt["source_commit"]==gate["source_commit"]==consumed["source_commit"]==record["source_commit"]
        and declared["binding"]==receipt["binding"] and declared["source_status"]==receipt["source_status"]==[],
        "Residual closure source/declaration join")
    require(declared["synthetic"] is receipt["synthetic"] is worker["synthetic"] is observed["synthetic"] is False,
        "Residual closure synthetic identity")
    require(declared["planned_trials"]==receipt["planned_trials"]==consumed["trials"]==plans
        and declared["planned_worlds"]==receipt["planned_worlds"]==dict(cpu=3,gpu=0),
        "Residual closure prospective population")
    require(receipt["ok"] is True and receipt["zero_world_gate_passed"] is True
        and receipt["physical_launch_requested"] is receipt["physical_started"] is True
        and receipt["source_runtime_unchanged"] is True and gate["ok"] is True
        and receipt["safety_controls"]==gate["safety_controls"]==GATE_COUNTS,
        "Residual closure incomplete execution/gate")
    require(all(declared[k] is receipt[k] is worker[k] is observed[k] is False for k in FLAGS)
        and receipt["training_data_scope"] is None
        and observed["controller_selection_authority"] is observed["tier3_benefit_established"] is False,
        "Residual closure retained authority")
    require(worker["ok"] is observed["ok"] is True and worker["status"]==record["status"]
        and worker["ledger_scope"]==observed["ledger_scope"]==record["ledger_scope"]
        and worker["constructed_model_count"]==worker["constructed_cpu_worlds"]==receipt["constructed_cpu_worlds"]==observed["constructed_cpu_worlds"]==3
        and worker["constructed_gpu_worlds"]==receipt["constructed_gpu_worlds"]==observed["constructed_gpu_worlds"]==0
        and len(worker["trials"])==len(observed["trials"])==3
        and observed["controller_rows"]==360 and observed["internal_rows"]==1800
        and observed["reader_world_build_count"]==observed["reader_solver_steps"]==0
        and observed["native_route_verified"] is True,"Residual closure actual population")
    require(all(t["official_quality_m_s"] is None and t["selection_authority"] is False for t in observed["trials"])
        and finite_summary(observed)==record["finite_outcomes"],"Residual closure outcome/quality promotion")
    require(record["native_worker_wall_s"]==worker["total_wall_s"] and record["owner_wall_s"]==receipt["wall_s"],
        "Residual closure timing join")
    require(all(t["completed"] is True and t["controller_closed"] is True and t["outer_rows"]==120
        and t["internal_rows"]==600 for t in worker["trials"]),"Residual closure trial completion")


def verify_record(path,evidence_root,core,baseline):
    record=read(path);attempt,paths=header(record,evidence_root)
    # The unchanged original reader dependencies must still match their frozen
    # bytes. New files may be added; no current HEAD is substituted for the run.
    require(record["closure_reader_sha256"]==sha(Path(__file__)),"Residual closure reader changed")
    verify_artifacts(record,paths)
    declared,receipt,worker,observed,gate,consumed=[read(attempt/name) for name in
        ("declaration.json","receipt.json","physical/worker-result.json","independent-audit.json","gate-receipt.json","consumed.json")]
    verify_joins(record,declared,receipt,worker,observed,gate,consumed)
    c=declaration()
    require(sha(CONTRACT)==record["contract_sha256"] and sha(core)==record["core_sha256"]==c["core_sha256"]
        and sha(baseline)==record["baseline_core_sha256"]==c["baseline_core_sha256"],"Residual closure core/contract binding")
    for name,key in (("receipt.json","receipt_sha256"),("declaration.json","declaration_sha256"),
        ("gate-receipt.json","gate_receipt_sha256"),("consumed.json","consumed_sha256"),
        ("independent-audit.json","audit_sha256"),("physical/worker-result.json","worker_sha256")):
        require(sha(attempt/name)==record[key],"Residual closure original receipt binding")
    require(receipt["audit_sha256"]==record["audit_sha256"],"Residual closure audit receipt join")
    binding=declared["binding"]
    require(verify_frozen_sources(record["source_commit"],binding["source"])==record["source_binding_count"],
        "Residual closure frozen-source denominator")
    # This full-source check is deliberately conservative: a future changed
    # dependency needs a distinct archival reader, never a substituted replay.
    for name,digest in binding["source"].items():
        require(sha(ROOT/name)==digest,"Residual closure original replay source changed: "+name)
    require(len(binding["runtime"])==record["runtime_binding_count"],"Residual closure runtime denominator")
    for name,digest in binding["runtime"].items():
        require(sha(Path(name))==digest,"Residual closure runtime changed")
    validate_launch_records(attempt/"physical",record["source_commit"])
    for name,count in GATE_COUNTS.items():
        log=(attempt/(name+"-gate")/"stderr.log").read_text(encoding="utf-8")
        require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ",log)==[str(count)] and log.rstrip().endswith("OK"),
            "Residual closure safety terminal/count")
    preflight=read(attempt/"runtime-gate/stdout.log")
    require(preflight==receipt["preflight"]==gate["preflight"] and preflight["ok"] is True
        and preflight["world_build_count"]==preflight["solver_steps"]==0 and preflight["planned_cpu_worlds"]==3
        and preflight["planned_gpu_worlds"]==0 and preflight["planned_controller_rows"]==360
        and preflight["planned_internal_rows"]==1800,"Residual closure preflight")
    plans=trial_plan(c);physical=attempt/"physical"
    require([json.loads(line) for line in (physical/"stdout.log").read_text().splitlines()]==[
        dict(trial=p["trial_id"],completed=True,controller_rows=120) for p in plans],"Residual closure worker terminal")
    require(read(attempt/"independent-reader/stdout.log")==dict(ok=True,synthetic=False,
        controller_rows=360,internal_rows=1800,native_route_verified=True),"Residual closure reader terminal")
    require((physical/"stderr.log").read_bytes()==b"" and (attempt/"independent-reader/stderr.log").read_bytes()==b"",
        "Residual closure unexpected native/reader stderr")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual closure opens no world")))
        oracle=bridge.LocomotionCore(baseline);trials=[]
        for plan,original in zip(plans,worker["trials"],strict=True):
            folder=physical/plan["trial_id"]
            require(read(folder/"result.json")==original,"Residual closure worker/trial join")
            opened=read(folder/"world-opened.json")
            require(opened==dict(trial_id=plan["trial_id"],native_data_constructed=True,
                core_sha256=c["core_sha256"],provider_model_sha256=original["provider_model_sha256"]),
                "Residual closure construction marker")
            trials.append(audit_trial(folder,plan,c,baseline,oracle))
        require(trials==observed["trials"] and compare_native_paths(physical,trials,False)==observed["native_path_comparison"],
            "Residual closure complete original replay differs")
    return dict(ok=True,artifact_count=len(paths),artifact_bytes=record["artifact_bytes"],
        source_binding_count=record["source_binding_count"],runtime_binding_count=record["runtime_binding_count"],
        original_constructed_cpu_worlds=3,original_constructed_gpu_worlds=0,
        controller_rows=360,internal_rows=1800,reader_world_build_count=0,reader_solver_steps=0,
        native_route_verified=True,finite_outcomes=record["finite_outcomes"],
        **{k:False for k in AUTHORITY_FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--record",type=Path,default=CLOSURE)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    result=verify_record(a.record,a.evidence_root,a.core,a.baseline_core);write_new(a.output,result)
    print(json.dumps({k:v for k,v in result.items() if k!="finite_outcomes"}))
    return 0


if __name__=="__main__":raise SystemExit(main())
