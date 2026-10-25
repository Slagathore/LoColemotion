"""Reopen the complete native force route without changing its launch authority."""
import argparse
from contextlib import ExitStack
import json
import math
from pathlib import Path
from unittest.mock import patch
import mujoco
import recovery_hold_native_task as task
import audit_contact_force_observer_closure as parent
from audit_contact_force_observer_closure import validate_bindings,compare_reconstruction,summarize as parent_summary
from audit_recovery_hold_native import audit_trial,expected_metadata,validate_sample,compare_prefix,handoff_summary
from audit_gpu_batch_execution import read_jsonl
from audit_residual_training_closure import verify_population
from recovery_hold_native_task import ROOT,HERE,FLAGS,read,sha,require,bridge,plans,frozen_model
from run_recovery_hold_native import inventory
from run_gpu_measurement_probe import source_identity
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new

CLOSURE=HERE/"recovery_hold_native_closure_v1.json"
CONTRACT=CLOSURE
SOURCES=("audit_recovery_hold_closure.py","test_recovery_hold_closure.py","run_recovery_hold_closure.py")
CONTROLS=12
GATES=(("closure","test_recovery_hold_closure",CONTROLS),)
SOURCE="18d08b40b40e0bbb40b4eee02ec55907e5a1bf80"
DENIALS=tuple(dict.fromkeys((*FLAGS,"tier2_complete","tier2_qualified","tier3_complete",
    "tier3_benefit_established","safe_backup_established","capability_estimated",
    "dynamic_feasibility_established","held_interval_force_guaranteed",
    "recovery_benefit_established","twelve_second_recovery_established","total_target_slew_guaranteed")))
LINKS=dict(receipt_sha256="receipt.json",declaration_sha256="declaration.json",
    gate_receipt_sha256="gate-receipt.json",consumed_sha256="consumed.json",
    worker_result_sha256="physical/worker-result.json",audit_sha256="audit.json",
    reconstruction_sha256="reconstruction.json")


def summarize(value):
    result=parent_summary(value)
    for before,after in zip(value["trials"],result["trials"],strict=True):
        after.update(handoff_transition=before["handoff_transition"],post_handoff_support=before["post_handoff_support"])
    return result



def endpoint_trend(rows):
    """Posthoc endpoint accounting on the complete original trace; no forecast."""
    require(len(rows)==600,"Hold endpoint complete denominator")
    tilts=[]
    for step,row in enumerate(rows,1):
        require(type(row["step"]) is int and row["step"]==step
            and math.isfinite(row["time_s"])
            and abs(row["time_s"]-step/600.)<=4*(2**-52)*step*step/600.,
            "Hold endpoint original clock")
        q=row["qpos"]
        require(len(q)==15 and all(math.isfinite(x) for x in q)
            and abs(sum(x*x for x in q[3:7])-1.)<=128*(2**-52),"Hold endpoint pose")
        tilts.append(math.acos(max(-1.,min(1.,1.-2*(q[4]**2+q[5]**2)))))
    chosen=(300,540,570,600)
    samples=[dict(internal_step=i,time_s=rows[i-1]["time_s"],tilt_rad=tilts[i-1],height_m=rows[i-1]["qpos"][2]) for i in chosen]
    return dict(schema_version="locolemotion_hold_endpoint_trend_v1",posthoc=True,
        sample_steps_selected_after_outcomes=True,complete_trace_rows=600,samples=samples,
        maximum_tilt_step=1+max(range(600),key=lambda i:tilts[i]),
        last_50ms_tilt_secant_rad_s=(tilts[599]-tilts[569])/(rows[599]["time_s"]-rows[569]["time_s"]),
        secant_is_not_instantaneous_angular_velocity=True,future_trajectory_extrapolated=False,
        threshold_or_outcome_changed=False,recovery_stability_established=False)


def declaration():return read(CLOSURE)


def validate_header(record):
    c=task.declaration()
    require(record["schema_version"]=="locolemotion_recovery_hold_native_closure_v1"
        and record["status"]=="native_hold_route_verified_finite_outcomes"
        and record["source_commit"]==SOURCE and record["synthetic"] is False
        and record["ledger_scope"]==c["ledger_scope"] and all(record[k] is False for k in DENIALS)
        and record["contract_path"]==task.CONTRACT.relative_to(ROOT).as_posix()
        and record["contract_sha256"]==sha(task.CONTRACT)
        and record["component_result_sha256"]==sha(task.COMPONENT_RESULT)
        and record["complete_safety_controls"]==task.EXPECTED_CONTROLS==453
        and record["closure_controls_required"]==CONTROLS
        and record["source_binding_count"]==637 and record["runtime_binding_count"]==1359
        and record["reserved_starts_opened"]==record["training_worlds_opened"]==0
        and record["closure_source_bindings"]=={n:sha(HERE/n) for n in SOURCES},
        "Force closure identity/scope/authority")
    identity=record["attempt_id"]
    require(isinstance(identity,str) and identity.startswith("sdk2-recovery-hold-native-")
        and Path(identity).name==identity and "/" not in identity and "\\" not in identity,
        "Force closure attempt boundary")
    return c


def header(record,evidence):
    validate_header(record);evidence=evidence.resolve(strict=True)
    attempt=(evidence/record["attempt_id"]).resolve(strict=True)
    require(attempt.parent==evidence,"Force closure evidence boundary")
    for key,name in LINKS.items():require(record[key]==sha(attempt/name),"Force closure evidence digest")
    return attempt


def validate_owner(receipt,declared,record,c):
    require(receipt["ok"] is True and receipt["synthetic"] is False
        and receipt["source_commit"]==SOURCE and receipt["contract"]==c
        and receipt["source_status"]==[] and receipt["source_runtime_unchanged"] is True
        and receipt["zero_world_gate_passed"] is True and receipt["component_only"] is False
        and receipt["physical_launch_requested"] is True and receipt["physical_started"] is True
        and receipt["constructed_cpu_worlds"]==4 and receipt["constructed_gpu_worlds"]==0
        and receipt["planned_trials"]==plans(c) and receipt["planned_worlds"]==dict(cpu=4,gpu=0)
        and receipt["safety_controls"]=={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1}
        and receipt["component_controls_passed"]==12 and all(receipt[k] is False for k in FLAGS)
        and receipt["binding"]==declared["binding"]
        and len(receipt["binding"]["source"])==record["source_binding_count"]
        and len(receipt["binding"]["runtime"])==record["runtime_binding_count"]
        and receipt["audit_sha256"]==record["audit_sha256"]
        and receipt["reconstruction_sha256"]==record["reconstruction_sha256"],"Force closure complete owner")


def reconstruct(folder,c,source,baseline_path):
    worker=read(folder/"worker-result.json");population=plans(c)
    require(worker["ok"] is True and worker["synthetic"] is False
        and worker["status"]=="complete_recovery_hold_route_fixture"
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
            require(len(samples)==len(trace)==len(timings)==600,"Force route full capture denominator")
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
            trial["contact_capture"]=dict(rows=600,contacts=total_contacts,inactive_contacts=inactive,
                other_contacts=other_count,mean_total_distal_normal_load_n=total_load/600,
                timing_s=timing_totals,force_reconstruction_verified=True)
            trial["handoff_transition"]=handoff_summary(controls)
            support=controls[60:]
            trial["post_handoff_support"]=dict(prepared_commands=60,window="commands_60_through_119",
                may_include_post_failure_states=True,
                by_site={x["contact_site_id"]:sum(int(next(y for y in row["request"]["state"]["ordered_contact_observations"]
                    if y["contact_site_id"]==x["contact_site_id"])["bears_support"]) for row in support)
                    for x in support[0]["request"]["state"]["ordered_contact_observations"]})
            trials.append(trial)
        pairs=[dict(group_id=group,**compare_prefix(folder/("force_walk_"+group),
                    folder/("force_hold_"+group),c)) for group in c["groups"]]
    return dict(schema_version="locolemotion_recovery_hold_native_audit_v1",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],source_commit=source,constructed_cpu_worlds=4,constructed_gpu_worlds=0,
        controller_rows=480,internal_rows=2400,contact_rows=contact_rows,trials=trials,pairs=pairs,
        reader_world_build_count=0,reader_solver_steps=0,controller_load_fields_changed=False,
        tier2_qualified=False,tier3_benefit_established=False,**{k:False for k in FLAGS})


def verify_record(path,evidence,core,baseline):
    source_identity(False);record=read(path);attempt=header(record,evidence);c=task.declaration()
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],"Force closure core identities")
    receipt=read(attempt/"receipt.json");declared=task.launch_records(attempt/"physical",c,SOURCE)
    validate_owner(receipt,declared,record,c)
    require(record["artifact_count_including_receipt"]==len(receipt["artifacts"])+1
        and record["owner_wall_s"]==receipt["wall_s"]
        and record["force_profiles"]=={p["trial_id"]:sha(attempt/"physical"/p["trial_id"]/"force-profile.json")
            for p in plans(c)},"Force closure profile/population joins")
    verify_population(receipt["artifacts"],inventory(attempt));validate_bindings(receipt["binding"])
    for name,_,count in task.GATES:verify_tests(attempt/(name+"-gate"),count)
    verify_tests(attempt/"provider-gate",2);verify_tests(attempt/"containment-gate",1)
    original=read(attempt/"audit.json");compare_reconstruction(original,read(attempt/"reconstruction.json"))
    recomputed=reconstruct(attempt/"physical",c,SOURCE,baseline)
    compare_reconstruction(original,recomputed)
    require(record["summary"]==summarize(recomputed),"Force closure exact finite summary")
    endpoints={p["trial_id"]:endpoint_trend(list(read_jsonl(attempt/"physical"/p["trial_id"]/"trace.jsonl"))) for p in plans(c)}
    require(record["endpoint_trends"]==endpoints,"Hold closure endpoint trend reconstruction")
    return dict(schema_version="locolemotion_recovery_hold_closure_audit_v1",ok=True,
        ledger_scope=record["ledger_scope"],closure_sha256=sha(path),source_commit=SOURCE,
        original_constructed_cpu_worlds=4,original_controller_rows=480,original_internal_rows=2400,
        original_contact_rows=2400,reader_world_build_count=0,reader_solver_steps=0,
        complete_artifact_population_verified=True,all_contact_forces_reconstructed=True,
        capture_stage_geometry_and_state_rejoined=True,complete_prefix_pairs_recompared=True,
        control_decisions_replayed_again=True,summary=summarize(recomputed),endpoint_trends=endpoints,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();result=verify_record(CLOSURE,ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,result);print(json.dumps(dict(ok=True,reader_world_build_count=0,reader_solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
