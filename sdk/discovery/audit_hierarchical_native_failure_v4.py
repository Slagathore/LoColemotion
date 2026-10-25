"""Close an incomplete native comparison without granting the missing population."""
import argparse
from contextlib import ExitStack
import json
import math
from pathlib import Path
from unittest.mock import patch
import mujoco
from hierarchical_native_task_v6 import ROOT,FLAGS,read,sha,require,bridge,declaration,plans,frozen_model,launch_records,retained
from hierarchical_native_trial_audit_v6 import audit_trial
from hierarchical_native_failure_trial_v4 import audit_partial_trial
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from run_gpu_measurement_probe import source_identity
from run_residual_native import verify_tests
import hierarchical_native_task_v6 as task
HERE=ROOT/"sdk/discovery"
CONTRACT=HERE/"hierarchical_native_failure_v4.json"
SOURCES=("hierarchical_native_failure_trial_v4.py","audit_hierarchical_native_failure_v4.py",
    "test_hierarchical_native_failure_v4.py","run_hierarchical_native_failure_v4.py")
SOURCE="6a57ecfe5996b7c7d7132252e4944ce612a390cb"
ATTEMPT="sdk2-hierarchical-native-v6-f5072c1d2e46499498911eed68d74146"
RECEIPT_SHA="2a9f28a81b097ad03679804c3f69da7fb8965350a9b1f461bd4ef5b0d9427301"
CONTROLS=24
GATES=(("failure","test_hierarchical_native_failure_v4",CONTROLS),)
DENIALS=tuple(dict.fromkeys((*FLAGS,"tier2_qualified","tier3_benefit_established",
    "recovery_benefit_established","safe_backup_established","dynamic_feasibility_established",
    "complete_comparison_established","nominal_condition_evaluated")))
def expected_contract():
    return dict(schema_version="locolemotion_hierarchical_native_failure_contract_v4",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_incomplete_native_closure",question_class="development"),
        original_attempt=ATTEMPT,original_source_commit=SOURCE,original_receipt_sha256=RECEIPT_SHA,
        original_contract_sha256=sha(task.CONTRACT),original_source_binding_count=1020,
        original_runtime_binding_count=3582,original_controls_passed=1050,
        closure_controls_required=CONTROLS,original_worlds_opened=2,original_worlds_planned=4,
        retained_controller_rows=1560,retained_internal_rows=7795,terminal_command=119,
        terminal_error=dict(type="HierarchyRefusal",message="Hierarchical support control refused"),
        reader_world_build_count=0,reader_solver_steps=0,
        terminal_primary_witness="rear-left hip exceeds native upper bound; both QP constructors forbidden during terminal replay",
        isolated_terminal_domain_replay=True,solver_or_acceptance_changes=False,
        source_bindings={n:sha(HERE/n) for n in SOURCES},**{k:False for k in DENIALS})
def declaration():
    value=read(CONTRACT);require(value==expected_contract(),"Failure exact closure declaration");return value
def validate_owner(r,declared,c):
    require(r["ok"] is False and r["synthetic"] is False and r["source_commit"]==SOURCE
        and r["contract"]==c and r["source_status"]==[] and r["binding"]==declared["binding"]
        and len(r["binding"]["source"])==1020 and len(r["binding"]["runtime"])==3582
        and r["zero_world_gate_passed"] is True and r["component_only"] is False
        and r["physical_started"] is True and r["physical_launch_requested"] is True
        and r["constructed_cpu_worlds"]==2 and r["constructed_gpu_worlds"]==0
        and r["planned_trials"]==plans(c) and r["planned_worlds"]==dict(cpu=4,gpu=0)
        and r["component_controls_passed"]==35
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
    require(len(a)==1440 and len(b)==120 and len(left)==7200 and len(right)==595,"Force complete pair denominator")
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
    require(len(controls) in (1440,119),"Failure applied controller denominator")
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
        for p in population[:2]:
            if p["role"]!="reach_hold":continue
            for filename in ("controller.jsonl","trace.jsonl"):
                relative="physical/"+p["trial_id"]+"/"+filename
                require(sha(parent_attempt/relative)==original_artifacts[relative],"Reach original baseline artifact digest")
            baselines.append(dict(group_id=p["group_id"],**compare_baseline(parent_attempt/"physical"/p["trial_id"],folder/p["trial_id"],c)))
        pairs=[dict(group_id=group,**compare_pair(folder/("reach_hold_"+group),folder/("hierarchy_hold_"+group),c)) for group in c["groups"][:1]]

    require(source_identity(False)==current,"Failure reader source drift")
    validate_bindings(receipt["binding"]);verify_population(receipt["artifacts"],inventory(attempt))
    extension=verify_extension(folder)
    firsts=[t["diagnostic_metrics"]["first_physical_violation"] for t in trials]
    require(firsts[0]["time_s"]==1.1583333333333465 and firsts[1]["internal_step"]==590 and firsts[1]["time_s"]==0.9833333333333425,"Failure retained physical onset/censoring")
    return dict(schema_version="locolemotion_hierarchical_native_failure_audit_v4",ok=True,
        ledger_scope=scope["ledger_scope"],original_source_commit=SOURCE,original_receipt_sha256=RECEIPT_SHA,
        native_result_complete=False,original_native_ok=False,constructed_cpu_worlds=2,constructed_gpu_worlds=0,
        controller_rows=1560,internal_rows=7795,contact_rows=contact_rows,
        original_safety_controls_verified=1050,source_binding_count=1020,runtime_binding_count=3582,
        artifact_count_including_receipt=len(receipt["artifacts"])+1,
        trials=trials,pairs=pairs,baseline_regressions=baselines,prior_native_extension=extension,
        unopened_trials=[p["trial_id"] for p in population[2:]],
        observed_candidate_minus_reference_violation_time_s=firsts[1]["time_s"]-firsts[0]["time_s"],
        candidate_stopped_before_physical_violation=False,candidate_last_completed_time_s=595/600.,
        candidate_horizon_censored_by_joint_domain_refusal=True,
        violation_timing_is_not_recovery_or_population_benefit=True,
        complete_retained_population_verified=True,reader_world_build_count=0,reader_solver_steps=0,
        controller_load_fields_changed=False,**{k:False for k in DENIALS})


def verify_extension(folder):
    """Join every previously applied native step, then expose the new trajectory."""
    prior=ROOT.parent/"SporeSpore_Evidence"/"sdk2-hierarchical-native-v4-e021aaff51a8459a9f1c2309c72c6a77"
    require(sha(prior/"receipt.json")=="f72aa326ed1087b2005db4a944f733d29070a49a6106c193241e63e570da67c7",
        "Failure4 prior native identity")
    receipt=read(prior/"receipt.json");artifacts={r["path"]:r["sha256"] for r in receipt["artifacts"]}
    relative="physical/hierarchy_hold_left_075_train_001"
    for name in ("controller.jsonl","trace.jsonl"):
        require(sha(prior/relative/name)==artifacts[relative+"/"+name],"Failure4 prior stream digest")
    old=list(read_jsonl(prior/relative/"controller.jsonl"));current=list(read_jsonl(folder/"hierarchy_hold_left_075_train_001/controller.jsonl"))
    before=list(read_jsonl(prior/relative/"trace.jsonl"));after=list(read_jsonl(folder/"hierarchy_hold_left_075_train_001/trace.jsonl"))
    require(len(old)==99 and len(current)==120 and len(before)==490 and len(after)==595
        and same_bits(before,after[:490]),"Failure4 complete prior applied native prefix")
    for x,y in zip(old[:98],current[:98],strict=True):
        require(all(same_bits(x[k],y[k]) for k in ("native_observation","stability","kinematics","composition","output","native_targets"))
            and same_bits(x["request"]["state"],y["request"]["state"])
            and same_bits(x["resolution"]["ordered_commands"],y["resolution"]["ordered_commands"]),
            "Failure4 prior applied public commands")
    recovered=current[98]["force_reference"]["decision"]["allocation"]
    require(same_bits(old[98]["native_observation"],current[98]["native_observation"])
        and recovered["solver_route"]=="scaled_primary" and recovered["accepted"] is True
        and same_bits(recovered["scaling_previous_refusal"],old[98]["force_reference"]["decision"]["allocation"]),
        "Failure4 causal scaled recovery joins all three old refusals")
    return dict(prior_attempt=prior.name,prior_applied_controller_commands_bitwise_identical=98,
        prior_native_steps_bitwise_identical=490,recovered_command=98,following_applied_commands=list(range(99,119)),
        terminal_command=119,additional_applied_commands=21,additional_native_steps=105,
        recovery_benefit_established=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();value=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,value);print(json.dumps(dict(ok=True,retained_worlds=2,reader_worlds=0)))
if __name__=="__main__":raise SystemExit(main())
