"""Complete native replay, fresh baseline reproduction and paired prefix joins."""
import argparse
from contextlib import ExitStack
import json
import math
from pathlib import Path
from unittest.mock import patch
import mujoco
from hierarchical_native_task_v4 import ROOT,FLAGS,read,sha,require,bridge,declaration,plans,frozen_model,launch_records,retained
from hierarchical_native_trial_audit_v4 import audit_trial
from audit_recovery_hold_native import expected_metadata,validate_sample
from audit_gpu_batch_execution import read_jsonl,same_bits
from recovery_hold_component_audit import transition
from gpu_measurement_probe import write_new


def compare_pair(reference,candidate,c):
    a=list(read_jsonl(reference/"controller.jsonl"));b=list(read_jsonl(candidate/"controller.jsonl"))
    left=list(read_jsonl(reference/"trace.jsonl"));right=list(read_jsonl(candidate/"trace.jsonl"))
    require(len(a)==len(b)==1440 and len(left)==len(right)==7200,"Force complete pair denominator")
    require(same_bits(left[:300],right[:300]),"Force fresh native prefix differs")
    for x,y in zip(a[:60],b[:60],strict=True):
        require(all(same_bits(x[k],y[k]) for k in ("native_observation","stability","kinematics","composition","output","native_targets"))
            and same_bits(x["request"]["state"],y["request"]["state"]),"Force challenge inputs or commands differ")
    require(same_bits(a[60]["native_observation"],b[60]["native_observation"]),"Force handoff initial state differs")
    return dict(prefix_controller_rows_identical=60,prefix_internal_rows_identical=300,
        handoff_prepared_state_identical=True,fresh_worlds=2,post_handoff_equality_required=False)


def compare_baseline(reference,candidate,c):
    before=list(read_jsonl(reference/"controller.jsonl"));after=list(read_jsonl(candidate/"controller.jsonl"))
    old=list(read_jsonl(reference/"trace.jsonl"));new=list(read_jsonl(candidate/"trace.jsonl"))
    require(len(before)==len(after)==1440 and len(old)==len(new)==7200,"Reach complete baseline denominator")
    require(same_bits(before,after) and same_bits(old,new),"Reach fresh baseline differs from retained hold")
    return dict(controller_rows_identical=1440,internal_rows_identical=7200,fresh_world=True,cached_physical_state_used=False)


def handoff_summary(controls):
    require(len(controls)==1440,"Horizon full controller denominator")
    changes=[transition(controls[i-1],controls[i]) for i in range(60,1440)]
    return dict(command=60,ordered_actuator_ids=[r["actuator_id"] for r in controls[60]["resolution"]["ordered_commands"]],
        at_handoff=changes[0],maximum_post_handoff_absolute_delta_rad_s={k:max(abs(x) for v in changes for x in v[k]) for k in changes[0]},
        total_target_slew_guaranteed=False)


def audit(folder,core_path,baseline_path):
    from run_hierarchical_native_v4 import bindings
    from run_gpu_measurement_probe import source_identity
    c=declaration();source=source_identity(True);owner=launch_records(folder,c,source)
    require(bindings(core_path,baseline_path)==owner["binding"],"Force route audit source/runtime binding")
    worker=read(folder/"worker-result.json");population=plans(c)
    require(worker["ok"] is True and worker["synthetic"] is False
        and worker["status"]=="complete_hierarchical_native_v4_fixture"
        and worker["ledger_scope"]==c["ledger_scope"] and all(worker[k] is False for k in FLAGS)
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==4
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==4,"Force route worker population/authority")
    trials=[];contact_rows=0
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Force route reader opens no world")))
        core=bridge.LocomotionCore(baseline_path);model=frozen_model(core)
        for plan,observed in zip(population,worker["trials"],strict=True):
            path=folder/plan["trial_id"];result=read(path/"result.json")
            require(result==observed and read(path/"world-opened.json")==dict(trial_id=plan["trial_id"],
                native_data_constructed=True,core_sha256=c["core_sha256"],provider_model_sha256=model.sha256,
                force_profile_sha256=sha(path/"force-profile.json")),
                "Force route result/construction join")
            trial=audit_trial(path,plan,c,baseline_path,core,model.document())
            controls=list(read_jsonl(path/"controller.jsonl"))
            # The provider continues to receive null loads throughout this fixture.
            loads=[site["normal_load_n"] for control in controls
                   for site in control["request"]["state"]["ordered_contact_observations"]]
            require(all(load is None for load in loads),"Force route fed loads to controller")
            metadata=expected_metadata(read(path/"compiled.json"),read(path/"inputs.json"),c)
            require(read(path/"contact-metadata.json")==metadata
                and sha(path/"contact-metadata.json")==result["contact_metadata_sha256"],"Force route metadata")
            for name in ("contact-force","contact-timing"):
                require(sha(path/(name+".jsonl"))==result["contact_hashes"][name],"Force route raw stream digest")
            samples=list(read_jsonl(path/"contact-force.jsonl"));trace=list(read_jsonl(path/"trace.jsonl"))
            timings=list(read_jsonl(path/"contact-timing.jsonl"))
            require(len(samples)==len(trace)==len(timings)==7200,"Force route full capture denominator")
            total_contacts=inactive=other_count=0;total_load=0.;timing_totals={}
            for sample,raw,timing in zip(samples,trace,timings,strict=True):
                validate_sample(sample,raw,metadata,c);contact_rows+=1
                require(timing["step"]==sample["step"] and set(timing)=={"step","native_prepare_s",
                    "prepare_capture_s","native_complete_s","complete_guard_s","force_capture_s","serialization_s"},
                    "Force route capture timing identity")
                for key,value in timing.items():
                    if key=="step":continue
                    require(type(value) in (float,int) and math.isfinite(value) and value>=0,"Force route finite timing")
                    timing_totals[key]=timing_totals.get(key,0.)+value
                total_contacts+=sample["ncon"]
                inactive+=sum(x["efc_address"]<0 for x in sample["contacts"])
                other_count+=len(sample["other_contact_indices"])
                total_load+=sum(x["normal_load_n"] for x in sample["mapped_distal_ground_loads"])
            trial["contact_capture"]=dict(rows=7200,contacts=total_contacts,inactive_contacts=inactive,
                other_contacts=other_count,mean_total_distal_normal_load_n=total_load/7200,
                timing_s=timing_totals,force_reconstruction_verified=True)
            trial["handoff_transition"]=handoff_summary(controls)
            support=controls[60:]
            trial["post_handoff_support"]=dict(prepared_commands=1380,window="commands_60_through_1439",
                may_include_post_failure_states=True,
                by_site={x["contact_site_id"]:sum(int(next(y for y in row["request"]["state"]["ordered_contact_observations"]
                    if y["contact_site_id"]==x["contact_site_id"])["bears_support"]) for row in support)
                    for x in support[0]["request"]["state"]["ordered_contact_observations"]})
            first=trial["diagnostic_metrics"]["first_physical_violation"]
            safe_support=[row for row in support if first is None or 5*row["outer_step"]<first["internal_step"]]
            trial["pre_failure_post_handoff_support"]=dict(prepared_commands=len(safe_support),
                window="post-handoff prepared commands strictly before first native violation",
                by_site={site["contact_site_id"]:sum(int(next(x for x in row["request"]["state"]["ordered_contact_observations"]
                    if x["contact_site_id"]==site["contact_site_id"])["bears_support"]) for row in safe_support)
                    for site in support[0]["request"]["state"]["ordered_contact_observations"]})
            trials.append(trial)
        parent_attempt=retained.header(read(retained.CLOSURE),ROOT.parent/"SporeSpore_Evidence")
        original_artifacts={r["path"]:r["sha256"] for r in read(parent_attempt/"receipt.json")["artifacts"]}
        baselines=[]
        for p in population:
            if p["role"]!="reach_hold":continue
            for filename in ("controller.jsonl","trace.jsonl"):
                relative="physical/"+p["trial_id"]+"/"+filename
                require(sha(parent_attempt/relative)==original_artifacts[relative],"Reach original baseline artifact digest")
            baselines.append(dict(group_id=p["group_id"],**compare_baseline(parent_attempt/"physical"/p["trial_id"],folder/p["trial_id"],c)))
        pairs=[dict(group_id=group,**compare_pair(folder/("reach_hold_"+group),folder/("hierarchy_hold_"+group),c)) for group in c["groups"]]
    require(source_identity(True)==source and bindings(core_path,baseline_path)==owner["binding"],
            "Force route audit source/runtime drift")
    return dict(schema_version="locolemotion_hierarchical_native_audit_v4",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],source_commit=source,constructed_cpu_worlds=4,constructed_gpu_worlds=0,
        controller_rows=5760,internal_rows=28800,contact_rows=contact_rows,trials=trials,pairs=pairs,baseline_regressions=baselines,
        reader_world_build_count=0,reader_solver_steps=0,controller_load_fields_changed=False,
        tier2_qualified=False,tier3_benefit_established=False,**{k:False for k in FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--folder",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    value=audit(args.folder,args.core,args.baseline_core);write_new(args.output,value)
    print(json.dumps(dict(ok=True,contact_rows=value["contact_rows"],world_build_count=0,solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
