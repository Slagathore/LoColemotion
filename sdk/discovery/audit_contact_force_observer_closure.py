"""Reopen the frozen contact observer fixture and reconstruct every retained stream."""
import argparse
from contextlib import ExitStack
import json
import math
from pathlib import Path
from unittest.mock import patch

import mujoco
import contact_force_observer_task as task
from contact_force_observer_task import ROOT,HERE,FLAGS,read,sha,require,bridge,plans,frozen_model
from audit_contact_force_observer import audit_trial,expected_metadata,validate_sample,compare_pair
from audit_gpu_batch_execution import read_jsonl
from audit_residual_training_closure import verify_population
from gpu_measurement_probe import write_new
from run_contact_force_observer import inventory
from run_gpu_measurement_probe import source_identity
from run_residual_native import verify_tests

CLOSURE=HERE/"contact_force_observer_closure_v1.json"
SOURCES=("audit_contact_force_observer_closure.py","test_contact_force_observer_closure.py",
         "run_contact_force_observer_closure.py")
NATIVE_SOURCE="e7a4e3d263cb47f4ab2a4874e62d140c3f4b5c73"
CONTROLS=14
DENIALS=tuple(dict.fromkeys((*FLAGS,"tier2_complete","tier2_qualified","tier3_complete",
    "tier3_benefit_established","safe_backup_established","controller_load_fields_changed",
    "actuation_feasibility_established","twelve_second_recovery_established")))
LINKS=dict(receipt_sha256="receipt.json",declaration_sha256="declaration.json",
    gate_receipt_sha256="gate-receipt.json",consumed_sha256="consumed.json",
    worker_result_sha256="physical/worker-result.json",audit_sha256="audit.json",
    reconstruction_sha256="reconstruction.json")


def validate_evidence_links(record,attempt):
    for key,name in LINKS.items():
        require(record[key]==sha(attempt/name),"Contact closure evidence record digest")


def header(record,evidence):
    c=task.declaration()
    require(record["schema_version"]=="locolemotion_contact_observer_closure_v1"
        and record["status"]=="complete_native_contact_observation_fixture"
        and record["synthetic"] is False and record["source_commit"]==NATIVE_SOURCE
        and record["ledger_scope"]==c["ledger_scope"]
        and all(record[k] is False for k in DENIALS)
        and record["contract_path"]==task.CONTRACT.relative_to(ROOT).as_posix()
        and record["contract_sha256"]==sha(task.CONTRACT)
        and record["model_sha256"]==sha(task.MODEL)
        and record["parent_closure_sha256"]==sha(task.PARENT_CLOSURE)
        and record["diagnosis_sha256"]==sha(task.DIAGNOSIS)
        and record["closure_controls_required"]==CONTROLS
        and record["closure_source_bindings"]=={name:sha(HERE/name) for name in SOURCES},
        "Contact closure identity/authority")
    identity=record["attempt_id"]
    require(isinstance(identity,str) and identity.startswith("sdk2-contact-observer-")
        and Path(identity).name==identity and "/" not in identity and "\\" not in identity,
        "Contact closure attempt identity")
    evidence=evidence.resolve(strict=True);attempt=(evidence/identity).resolve(strict=True)
    require(attempt.parent==evidence,"Contact closure evidence boundary")
    validate_evidence_links(record,attempt)
    return attempt


def validate_documents(receipt,declared,gate,claim,worker,audit,c,source):
    population=plans(c);counts={**{n:k for n,_,k in task.GATES},"provider":2,"containment":1}
    require(receipt["schema_version"]=="locolemotion_contact_observer_owner_v1"
        and receipt["ok"] is True and receipt["synthetic"] is False
        and receipt["source_commit"]==source and receipt["contract"]==c
        and receipt["ledger_scope"]==c["ledger_scope"] and receipt["source_status"]==[]
        and receipt["source_runtime_unchanged"] is True and receipt["zero_world_gate_passed"] is True
        and receipt["component_only"] is False and receipt["physical_launch_requested"] is True
        and receipt["physical_started"] is True and receipt["planned_trials"]==population
        and receipt["planned_worlds"]==dict(cpu=4,gpu=0)
        and receipt["constructed_cpu_worlds"]==4 and receipt["constructed_gpu_worlds"]==0
        and receipt["safety_controls"]==counts and receipt["component_controls_passed"]==36
        and all(receipt[k] is False for k in FLAGS),"Contact closure complete owner")
    require(declared["source_commit"]==source and declared["contract"]==c
        and declared["binding"]==receipt["binding"] and declared["source_status"]==[]
        and declared["planned_trials"]==population and declared["component_only"] is False
        and declared["physical_started"] is False and declared["physical_launch_requested"] is False
        and declared["ok"] is False and declared["synthetic"] is False
        and all(declared[k] is False for k in FLAGS),"Contact closure original freeze")
    require(gate["ok"] is True and gate["source_commit"]==source
        and gate["safety_controls"]==counts and sum(counts.values())==task.EXPECTED_CONTROLS
        and gate["preflight"]==receipt["preflight"] and gate["preflight"]["ok"] is True
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0
        and claim["source_commit"]==source and claim["trials"]==population,
        "Contact closure complete launch gate")
    require(worker["ok"] is True and worker["synthetic"] is False
        and worker["status"]=="complete_contact_observer_fixture"
        and worker["ledger_scope"]==c["ledger_scope"]
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==4
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==4
        and all(worker[k] is False for k in FLAGS),"Contact closure complete native population")
    require(audit["schema_version"]=="locolemotion_contact_observer_audit_v1"
        and audit["ok"] is True and audit["synthetic"] is False and audit["source_commit"]==source
        and audit["ledger_scope"]==c["ledger_scope"] and audit["constructed_cpu_worlds"]==4
        and audit["constructed_gpu_worlds"]==audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
        and audit["controller_rows"]==480 and audit["internal_rows"]==2400 and audit["contact_rows"]==1200
        and audit["controller_load_fields_changed"] is False and audit["tier2_qualified"] is False
        and audit["tier3_benefit_established"] is False and all(audit[k] is False for k in FLAGS)
        and len(audit["trials"])==4 and audit["pairs"]==[
            dict(group_id=g,exact_native_trace_match=True,controller_inputs_and_commands_match=True,
                 controller_rows=120,internal_rows=600,fresh_worlds=2) for g in c["groups"]],
        "Contact closure independent population/authority")
    for plan,row,native in zip(population,audit["trials"],worker["trials"],strict=True):
        require(all(native.get(k)==v for k,v in plan.items())
            and native["completed"] is True and native["controller_closed"] is True
            and native["outer_rows"]==120 and native["internal_rows"]==600,
            "Contact closure native trial identity")
        require(all(row.get(k)==v for k,v in plan.items()) and row["controller_rows"]==120
            and row["internal_rows"]==600 and row["official_quality_m_s"] is None
            and row["selection_authority"] is False,"Contact closure audited trial identity")


def validate_bindings(binding):
    require(set(binding)=={"source","runtime","gpu"} and binding["source"] and binding["runtime"],
        "Contact closure binding population")
    for name,digest in binding["source"].items():
        path=(ROOT/name).resolve(strict=True)
        require(path.is_relative_to(ROOT) and sha(path)==digest,"Contact closure original source bytes")
    for name,digest in binding["runtime"].items():
        require(sha(Path(name))==digest,"Contact closure original runtime bytes")


def compare_reconstruction(original,recomputed):
    require(original==recomputed,"Contact closure complete raw reconstruction")


def summarize(value):
    keys=("trial_id","group_id","role","controller_rows","internal_rows","diagnostic_metrics",
          "diagnostic_failure_codes","diagnostic_eligible","official_quality_m_s","timing")
    return dict(constructed_cpu_worlds=value["constructed_cpu_worlds"],constructed_gpu_worlds=0,
        controller_rows=value["controller_rows"],internal_rows=value["internal_rows"],
        contact_rows=value["contact_rows"],pairs=value["pairs"],
        trials=[dict({k:row[k] for k in keys},**({"contact_capture":row["contact_capture"]}
                    if "contact_capture" in row else {})) for row in value["trials"]])


def reconstruct(folder,c,source,baseline_path):
    """Recompute the original complete audit from retained streams, with no worlds.

    The caller binds source to the original clean freeze. This retained reader
    does not replace the native owner's live-source launch check.
    """
    worker=read(folder/"worker-result.json");population=plans(c)
    require(worker["ok"] is True and worker["synthetic"] is False
        and worker["status"]=="complete_contact_observer_fixture"
        and worker["ledger_scope"]==c["ledger_scope"] and all(worker[k] is False for k in FLAGS)
        and worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==4
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==4,"Observer worker population/authority")
    trials=[];contact_rows=0
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Observer reader opens no world")))
        core=bridge.LocomotionCore(baseline_path);model=frozen_model(core)
        for plan,observed in zip(population,worker["trials"],strict=True):
            path=folder/plan["trial_id"];result=read(path/"result.json")
            require(result==observed and read(path/"world-opened.json")==dict(trial_id=plan["trial_id"],
                native_data_constructed=True,core_sha256=c["core_sha256"],provider_model_sha256=model.sha256),
                "Observer result/construction join")
            trial=audit_trial(path,plan,c,baseline_path,core,model.document())
            controls=list(read_jsonl(path/"controller.jsonl"))
            # The provider continues to receive null loads throughout this fixture.
            loads=[site["normal_load_n"] for control in controls
                   for site in control["request"]["state"]["ordered_contact_observations"]]
            require(all(load is None for load in loads),"Observer fed loads to controller")
            if plan["role"]=="observer_on":
                metadata=expected_metadata(read(path/"compiled.json"),read(path/"inputs.json"),c)
                require(read(path/"contact-metadata.json")==metadata
                    and sha(path/"contact-metadata.json")==result["contact_metadata_sha256"],"Observer metadata")
                for name in ("contact-force","contact-timing"):
                    require(sha(path/(name+".jsonl"))==result["contact_hashes"][name],"Observer raw stream digest")
                samples=list(read_jsonl(path/"contact-force.jsonl"));trace=list(read_jsonl(path/"trace.jsonl"))
                timings=list(read_jsonl(path/"contact-timing.jsonl"))
                require(len(samples)==len(trace)==len(timings)==600,"Observer full capture denominator")
                total_contacts=inactive=other_count=0;total_load=0.;timing_totals={}
                for sample,raw,timing in zip(samples,trace,timings,strict=True):
                    validate_sample(sample,raw,metadata,c);contact_rows+=1
                    require(timing["step"]==sample["step"] and set(timing)=={"step","native_prepare_s",
                        "prepare_capture_s","native_complete_s","complete_guard_s","force_capture_s","serialization_s"},
                        "Observer capture timing identity")
                    for key,value in timing.items():
                        if key=="step":continue
                        require(type(value) in (float,int) and math.isfinite(value) and value>=0,"Observer finite timing")
                        timing_totals[key]=timing_totals.get(key,0.)+value
                    total_contacts+=sample["ncon"]
                    inactive+=sum(x["efc_address"]<0 for x in sample["contacts"])
                    other_count+=len(sample["other_contact_indices"])
                    total_load+=sum(x["normal_load_n"] for x in sample["mapped_distal_ground_loads"])
                trial["contact_capture"]=dict(rows=600,contacts=total_contacts,inactive_contacts=inactive,
                    other_contacts=other_count,mean_total_distal_normal_load_n=total_load/600,
                    timing_s=timing_totals,force_reconstruction_verified=True)
            else:
                require(not any((path/name).exists() for name in
                    ("contact-force.jsonl","contact-timing.jsonl","contact-metadata.json")),
                    "Observer-off role captured contact force")
            trials.append(trial)
        pairs=[dict(group_id=group,**compare_pair(folder/("observer_off_"+group),
                    folder/("observer_on_"+group),c)) for group in c["groups"]]
    return dict(schema_version="locolemotion_contact_observer_audit_v1",ok=True,synthetic=False,
        ledger_scope=c["ledger_scope"],source_commit=source,constructed_cpu_worlds=4,constructed_gpu_worlds=0,
        controller_rows=480,internal_rows=2400,contact_rows=contact_rows,trials=trials,pairs=pairs,
        reader_world_build_count=0,reader_solver_steps=0,controller_load_fields_changed=False,
        tier2_qualified=False,tier3_benefit_established=False,**{k:False for k in FLAGS})

def verify_record(path,evidence,core,baseline):
    source_identity(False);record=read(path);attempt=header(record,evidence);c=task.declaration()
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],
            "Contact closure core identity")
    receipt=read(attempt/"receipt.json");source=record["source_commit"]
    require(record["complete_safety_controls"]==task.EXPECTED_CONTROLS
        and record["source_binding_count"]==len(receipt["binding"]["source"])
        and record["runtime_binding_count"]==len(receipt["binding"]["runtime"])
        and record["reserved_starts_opened"]==record["training_worlds_opened"]==0,
        "Contact closure metadata scope")
    verify_population(receipt["artifacts"],inventory(attempt));validate_bindings(receipt["binding"])
    # Reopen the actual original launch gate; do not impersonate its old HEAD.
    task.launch_records(attempt/"physical",c,source)
    original=read(attempt/"audit.json")
    validate_documents(receipt,read(attempt/"declaration.json"),read(attempt/"gate-receipt.json"),
        read(attempt/"consumed.json"),read(attempt/"physical/worker-result.json"),original,c,source)
    require(receipt["audit_sha256"]==record["audit_sha256"]
        and receipt["reconstruction_sha256"]==record["reconstruction_sha256"],
        "Contact closure owner reader joins")
    compare_reconstruction(original,read(attempt/"reconstruction.json"))
    for name,_,count in task.GATES:
        verify_tests(attempt/(name+"-gate"),count)
    verify_tests(attempt/"provider-gate",2);verify_tests(attempt/"containment-gate",1)
    recomputed=reconstruct(attempt/"physical",c,source,baseline)
    compare_reconstruction(original,recomputed);summary=summarize(recomputed)
    require(record["summary"]==summary,"Contact closure finite summary")
    return dict(schema_version="locolemotion_contact_observer_closure_audit_v1",ok=True,
        ledger_scope=record["ledger_scope"],closure_sha256=sha(path),source_commit=source,
        original_constructed_cpu_worlds=4,original_controller_rows=480,original_internal_rows=2400,
        original_contact_rows=1200,reader_world_build_count=0,reader_solver_steps=0,
        complete_artifact_population_verified=True,all_contact_forces_reconstructed=True,
        capture_stage_geometry_and_state_rejoined=True,complete_off_on_pairs_recompared=True,
        control_decisions_replayed_again=True,summary=summary,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--closure",type=Path,default=CLOSURE)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    result=verify_record(args.closure,args.evidence_root,args.core,args.baseline_core)
    write_new(args.output,result)
    print(json.dumps({k:result[k] for k in ("ok","original_contact_rows","reader_world_build_count")}))
    return 0


if __name__=="__main__":raise SystemExit(main())
