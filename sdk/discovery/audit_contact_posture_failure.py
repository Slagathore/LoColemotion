"""Close an incomplete native comparison without granting the missing population."""
import argparse
from contextlib import ExitStack
import json
import math
from pathlib import Path
from unittest.mock import patch
import mujoco
from contact_posture_native_task import ROOT,FLAGS,read,sha,require,bridge,declaration,plans,frozen_model,launch_records,retained
from contact_posture_native_trial_audit import audit_trial
from contact_posture_failure_trial import audit_partial_trial
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_contact_posture_native import inventory
from run_gpu_measurement_probe import source_identity
from run_residual_native import verify_tests
import contact_posture_native_task as task
HERE=ROOT/"sdk/discovery"
CONTRACT=HERE/"contact_posture_failure_v1.json"
SOURCES=("contact_posture_failure_trial.py","audit_contact_posture_failure.py",
    "test_contact_posture_failure.py","run_contact_posture_failure.py")
SOURCE="1cbcf85ef7dbeb22c9b3dcaa11c705bc1a68a11c"
ATTEMPT="sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"
RECEIPT_SHA="f9de90017d78ace6aff8498b0b2da23df89484405f44152e623528219ae00ac3"
CONTROLS=12
GATES=(("failure","test_contact_posture_failure",CONTROLS),)
DENIALS=tuple(dict.fromkeys((*FLAGS,"tier2_qualified","tier3_benefit_established",
    "recovery_benefit_established","safe_backup_established","dynamic_feasibility_established",
    "complete_comparison_established","nominal_condition_evaluated")))
def expected_contract():
    return dict(schema_version="locolemotion_contact_posture_failure_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_incomplete_native_closure",question_class="development"),
        original_attempt=ATTEMPT,original_source_commit=SOURCE,original_receipt_sha256=RECEIPT_SHA,
        original_contract_sha256=sha(task.CONTRACT),original_source_binding_count=694,
        original_runtime_binding_count=1359,original_controls_passed=556,
        closure_controls_required=CONTROLS,original_worlds_opened=2,original_worlds_planned=4,
        retained_controller_rows=2671,retained_internal_rows=13350,terminal_command=1230,
        terminal_error=dict(type="ValueError",message="Posture independent blocking bound"),
        reader_world_build_count=0,reader_solver_steps=0,
        source_bindings={n:sha(HERE/n) for n in SOURCES},**{k:False for k in DENIALS})
def declaration():
    value=read(CONTRACT);require(value==expected_contract(),"Failure exact closure declaration");return value
def validate_owner(r,declared,c):
    require(r["ok"] is False and r["synthetic"] is False and r["source_commit"]==SOURCE
        and r["contract"]==c and r["source_status"]==[] and r["binding"]==declared["binding"]
        and len(r["binding"]["source"])==694 and len(r["binding"]["runtime"])==1359
        and r["zero_world_gate_passed"] is True and r["component_only"] is False
        and r["physical_started"] is True and r["physical_launch_requested"] is True
        and r["constructed_cpu_worlds"]==2 and r["constructed_gpu_worlds"]==0
        and r["planned_trials"]==plans(c) and r["planned_worlds"]==dict(cpu=4,gpu=0)
        and r["component_controls_passed"]==17
        and r["safety_controls"]=={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1}
        and all(r[k] is False for k in FLAGS)
        and r["error"]=="RuntimeError: Contained stage failed (1): "+str(ROOT.parent/"SporeSpore_Evidence"/ATTEMPT/"physical"),
        "Failure exact native owner population/scope")
def validate_worker(w,c):
    require(w["ok"] is False and w["synthetic"] is False and w["ledger_scope"]==c["ledger_scope"]
        and w["status"]=="incomplete_or_refused_execution"
        and w["constructed_cpu_worlds"]==w["constructed_model_count"]==2
        and w["constructed_gpu_worlds"]==0 and len(w["trials"])==1
        and w["error"]=="ValueError: Residual terminal provider failure"
        and all(w[k] is False for k in FLAGS),"Failure exact worker population/scope")

from audit_recovery_hold_native import expected_metadata,validate_sample
from audit_gpu_batch_execution import read_jsonl,same_bits
from recovery_hold_component_audit import transition
from gpu_measurement_probe import write_new


def compare_pair(reference,candidate,c):
    a=list(read_jsonl(reference/"controller.jsonl"));b=list(read_jsonl(candidate/"controller.jsonl"))
    left=list(read_jsonl(reference/"trace.jsonl"));right=list(read_jsonl(candidate/"trace.jsonl"))
    require(len(a)==1440 and len(b)==1231 and len(left)==7200 and len(right)==6150,"Force complete pair denominator")
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
    require(len(controls) in (1440,1230),"Failure applied controller denominator")
    changes=[transition(controls[i-1],controls[i]) for i in range(60,len(controls))]
    return dict(command=60,ordered_actuator_ids=[r["actuator_id"] for r in controls[60]["resolution"]["ordered_commands"]],
        at_handoff=changes[0],maximum_post_handoff_absolute_delta_rad_s={k:max(abs(x) for v in changes for x in v[k]) for k in changes[0]},
        total_target_slew_guaranteed=False)



def audit(evidence,core_path,baseline_path):
    scope=declaration();current=source_identity(False);c=task.declaration()
    attempt=evidence/ATTEMPT;folder=attempt/"physical"
    require(attempt.resolve().parent==evidence.resolve() and sha(attempt/"receipt.json")==RECEIPT_SHA,
        "Failure exact retained attempt")
    require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"],"Failure core identities")
    receipt=read(attempt/"receipt.json");owner=launch_records(folder,c,SOURCE)
    validate_owner(receipt,owner,c);verify_population(receipt["artifacts"],inventory(attempt));validate_bindings(receipt["binding"])
    for name,_,count in task.GATES:verify_tests(attempt/(name+"-gate"),count)
    verify_tests(attempt/"provider-gate",2);verify_tests(attempt/"containment-gate",1)
    worker=read(folder/"worker-result.json");validate_worker(worker,c);population=plans(c)
    require({p.name for p in folder.iterdir() if p.is_dir()}=={p["trial_id"] for p in population[:2]}
        and not (attempt/"audit.json").exists() and not (attempt/"reconstruction.json").exists(),
        "Failure unopened worlds/original incomplete audit boundary")
    trials=[];contact_rows=0
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Failure reader opens no world")))
        core=bridge.LocomotionCore(baseline_path);model=frozen_model(core)
        for index,plan in enumerate(population[:2]):
            path=folder/plan["trial_id"];result=read(path/"result.json")
            require(read(path/"world-opened.json")==dict(trial_id=plan["trial_id"],
                native_data_constructed=True,core_sha256=c["core_sha256"],provider_model_sha256=model.sha256,
                force_profile_sha256=sha(path/"force-profile.json")),"Failure construction join")
            if index==0:
                require(result==worker["trials"][0],"Failure completed baseline worker join")
                trial=audit_trial(path,plan,c,baseline_path,core,model.document())
                trial["native_horizon_completed"]=True
            else:trial=audit_partial_trial(path,plan,c,baseline_path,core,model.document())
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
            require(len(samples)==len(trace)==len(timings)==result["internal_rows"],"Force route full capture denominator")
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
            trial["contact_capture"]=dict(rows=result["internal_rows"],contacts=total_contacts,inactive_contacts=inactive,
                other_contacts=other_count,mean_total_distal_normal_load_n=total_load/result["internal_rows"],
                timing_s=timing_totals,force_reconstruction_verified=True)
            trial["handoff_transition"]=handoff_summary(controls[:result["internal_rows"]//5])
            support=controls[60:]
            trial["post_handoff_support"]=dict(prepared_commands=len(support),window="all_retained_prepared_commands_from_60",
                may_include_post_failure_states=True,
                by_site={x["contact_site_id"]:sum(int(next(y for y in row["request"]["state"]["ordered_contact_observations"]
                    if y["contact_site_id"]==x["contact_site_id"])["bears_support"]) for row in support)
                    for x in support[0]["request"]["state"]["ordered_contact_observations"]})
            trials.append(trial)
        parent_attempt=retained.header(read(retained.CLOSURE),ROOT.parent/"SporeSpore_Evidence")
        original_artifacts={r["path"]:r["sha256"] for r in read(parent_attempt/"receipt.json")["artifacts"]}
        baselines=[]
        for p in population[:2]:
            if p["role"]!="reach_hold":continue
            for filename in ("controller.jsonl","trace.jsonl"):
                relative="physical/"+p["trial_id"]+"/"+filename
                require(sha(parent_attempt/relative)==original_artifacts[relative],"Reach original baseline artifact digest")
            baselines.append(dict(group_id=p["group_id"],**compare_baseline(parent_attempt/"physical"/p["trial_id"],folder/p["trial_id"],c)))
        pairs=[dict(group_id=group,**compare_pair(folder/("reach_hold_"+group),folder/("posture_hold_"+group),c)) for group in c["groups"][:1]]

    require(source_identity(False)==current,"Failure reader source drift")
    validate_bindings(receipt["binding"]);verify_population(receipt["artifacts"],inventory(attempt))
    times=[t["diagnostic_metrics"]["first_physical_violation"]["time_s"] for t in trials]
    require(times==[1.1583333333333465,1.0550000000000108],"Failure retained physical onset")
    return dict(schema_version="locolemotion_contact_posture_failure_audit_v1",ok=True,
        ledger_scope=scope["ledger_scope"],original_source_commit=SOURCE,original_receipt_sha256=RECEIPT_SHA,
        native_result_complete=False,original_native_ok=False,constructed_cpu_worlds=2,constructed_gpu_worlds=0,
        controller_rows=2671,internal_rows=13350,contact_rows=contact_rows,
        original_safety_controls_verified=556,source_binding_count=694,runtime_binding_count=1359,
        artifact_count_including_receipt=len(receipt["artifacts"])+1,
        trials=trials,pairs=pairs,baseline_regressions=baselines,
        unopened_trials=[p["trial_id"] for p in population[2:]],
        observed_candidate_minus_reference_violation_time_s=times[1]-times[0],
        violation_timing_is_not_recovery_or_population_benefit=True,
        complete_retained_population_verified=True,reader_world_build_count=0,reader_solver_steps=0,
        controller_load_fields_changed=False,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();value=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,value);print(json.dumps(dict(ok=True,retained_worlds=2,reader_worlds=0)))
if __name__=="__main__":raise SystemExit(main())
