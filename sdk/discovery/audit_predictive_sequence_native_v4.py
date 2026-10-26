"""Audit complete or validly refused native comparisons without opening worlds."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
from predictive_sequence_native_task_v4 import ROOT,FLAGS,read,sha,require,bridge,declaration,plans,frozen_model,launch_records,retained
from predictive_sequence_native_trial_audit_v4 import audit_trial
from predictive_sequence_native_checks_v4 import worker_population,compare_pair,compare_baseline
from gpu_measurement_probe import write_new
from predictive_sequence_native_capture_v4 import STREAMS


def audit(folder,core_path,baseline_path):
    from run_predictive_sequence_native_v4 import bindings
    from run_gpu_measurement_probe import source_identity
    c=declaration();source=source_identity(True);owner=launch_records(folder,c,source)
    require(bindings(core_path,baseline_path)==owner["binding"],"Predictive audit source/runtime binding")
    worker=read(folder/"worker-result.json");population=plans(c)
    require(worker["ledger_scope"]==c["ledger_scope"],"Predictive worker scope")
    count=worker_population(worker,population,FLAGS);trials=[];pairs=[];baselines=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward","mj_collision"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Predictive reader opens no world")))
        core=bridge.LocomotionCore(baseline_path);model=frozen_model(core)
        for plan,observed in zip(population[:count],worker["trials"],strict=True):
            path=folder/plan["trial_id"];result=read(path/"result.json")
            require(result==observed and read(path/"world-opened.json")==dict(trial_id=plan["trial_id"],
                native_data_constructed=True,core_sha256=c["core_sha256"],provider_model_sha256=model.sha256,
                force_profile_sha256=sha(path/"force-profile.json")),"Predictive result/construction join")
            trials.append(audit_trial(path,plan,c,baseline_path,core,model.document()))
        parent_attempt=retained.header(read(retained.CLOSURE),ROOT.parent/"SporeSpore_Evidence")
        original_artifacts={r["path"]:r["sha256"] for r in read(parent_attempt/"receipt.json")["artifacts"]}
        opened={p["trial_id"] for p in population[:count]}
        require({p.name for p in folder.iterdir() if p.is_dir()}==opened,"Predictive unexpected world directory")
        for p in population[:count]:
            if p["role"]!="reach_hold":continue
            for filename in ("controller.jsonl","trace.jsonl"):
                relative="physical/"+p["trial_id"]+"/"+filename
                require(sha(parent_attempt/relative)==original_artifacts[relative],"Predictive original baseline digest")
            baselines.append(dict(group_id=p["group_id"],
                **compare_baseline(parent_attempt/"physical"/p["trial_id"],folder/p["trial_id"],c)))
        for group in c["groups"]:
            candidate="predictive_hold_"+group
            if candidate in opened:
                pairs.append(dict(group_id=group,**compare_pair(folder/("reach_hold_"+group),folder/candidate,c)))
    stream_bytes=sum((folder/p["trial_id"]/(name+".jsonl")).stat().st_size
        for p in population[:count] for name in STREAMS)
    require(type(worker["retained_stream_bytes"]) is int and worker["retained_stream_bytes"]==stream_bytes
        and stream_bytes<=c["maximum_attempt_stream_bytes"],"Sequence complete aggregate retained stream bytes")
    require(source_identity(True)==source and bindings(core_path,baseline_path)==owner["binding"],"Predictive audit source/runtime drift")
    return dict(schema_version="locolemotion_predictive_sequence_native_audit_v4",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],source_commit=source,execution_complete=worker["execution_complete"],
        status=worker["status"],constructed_cpu_worlds=count,constructed_gpu_worlds=0,
        planned_cpu_worlds=4,unopened_trials=worker["unopened_trials"],
        retained_stream_bytes=stream_bytes,
        controller_rows=sum(r["controller_rows"] for r in trials),internal_rows=sum(r["internal_rows"] for r in trials),
        contact_rows=sum(r["contact_capture"]["rows"] for r in trials),
        trials=trials,pairs=pairs,baseline_regressions=baselines,reader_world_build_count=0,reader_solver_steps=0,
        controller_load_fields_changed=False,reader_storage="streamed; adjacent controllers and bounded summaries",
        tier2_qualified=False,tier3_benefit_established=False,recovery_benefit_established=False,**{k:False for k in FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--folder",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    value=audit(args.folder,args.core,args.baseline_core);write_new(args.output,value)
    print(json.dumps(dict(ok=True,status=value["status"],execution_complete=value["execution_complete"],
        contact_rows=value["contact_rows"],world_build_count=0,solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
