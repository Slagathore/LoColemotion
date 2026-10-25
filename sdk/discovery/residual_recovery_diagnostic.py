"""Reconstruct complete recovery diagnostics without new worlds or policy selection."""
import argparse
from collections import defaultdict
from contextlib import contextmanager,ExitStack
import hashlib
import json
from pathlib import Path,PurePosixPath
from unittest.mock import patch

import mujoco
import audit_residual_recovery_training_closure as parent
from audit_residual_recovery_training_closure import ROOT,HERE,CLOSURE,read,sha,require
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,jobs
import residual_recovery_diagnostic_metrics as metrics

RECORD=HERE/"residual_recovery_diagnostic_v1.json"
PARENT_SHA="cbbeda7388375c369eca4162867c32893f2d8fa1d00cea0bb8a3448c109f5328"
SOURCES=("residual_recovery_diagnostic_metrics.py","residual_recovery_diagnostic.py",
    "test_residual_recovery_diagnostic.py","run_residual_recovery_diagnostic.py")
CONTROLS=16
TOTALS=dict(constructed_cpu_worlds=119,constructed_gpu_worlds=0,
    controller_rows=162120,internal_rows=810600,exact_paired_prefixes=93)
SCOPE=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
    authority_mode="retained_recovery_diagnostic",question_class="development")
DENIALS=(*parent.DENIALS,"training_data_authority","controller_selection_authority",
    "comparison_data_used_for_fitting","comparison_data_used_for_selection",
    "normal_contact_forces_retained","force_feasibility_established","causal_generalization")
PHYSICS=("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward")


@contextmanager
def no_physics():
    with ExitStack() as guards:
        for name in PHYSICS:
            guards.enter_context(patch.object(mujoco,name,
                side_effect=AssertionError("Recovery diagnosis cannot open or step physics")))
        yield


def fixed_header(parent_audit_sha):
    return dict(schema_version="locolemotion_residual_recovery_diagnostic_v1",
        status="complete_retained_recovery_diagnostic",synthetic=False,ledger_scope=SCOPE,
        parent_closure_path=CLOSURE.relative_to(ROOT).as_posix(),parent_closure_sha256=PARENT_SHA,
        parent_reconstruction_sha256=parent_audit_sha,
        source_bindings={str((HERE/name).relative_to(ROOT).as_posix()):sha(HERE/name) for name in SOURCES},
        controls_required=CONTROLS,reader_world_build_count=0,reader_solver_steps=0,
        ordered_actuators=metrics.ACTUATORS,ordered_feet=[leg+"_foot" for leg in metrics.LEGS],
        window_definition=dict(handoff_command=60,common_commands_inclusive=[60,79],
            common_internal_steps_inclusive=[301,400],
            common_window_chosen_after_parent_outcomes=True,
            common_window_crossing_first_failure_refused=True,
            command_prefix="prepared command i included iff 5*i < original first failure internal step",
            force_prefix="completed internal sample j included iff j < original first failure internal step",
            success_endpoint="horizon censored; no invented failure time",
            every_raw_horizon_read_and_validated=True,post_failure_statistics_excluded=True),
        measurement_definition=dict(
            resolved_correction="rate-limited correction before final target-speed projection",
            delivered_correction="final native velocity target minus deterministic baseline velocity target",
            force="retained unit-gear affine actuator and joint force before integration",
            force_reconstruction="clamp(gain*control - gain*before_qvel, force_range)",
            force_reconstruction_absolute_tolerance_nm=1e-9,
            contact_geometry="canonical reported supporting contact points projected to the horizontal plane",
            center_of_mass="retained torso-root subtree center of mass, converted to canonical coordinates",
            contact_load="unavailable values remain null; motor torque is not a foot load",
            hull_margin="signed minimum edge distance only for at least three noncollinear hull vertices",
            interpretation="descriptive exposed trajectories; no force-feasibility, independent-sample, or causal proof"),
        **{key:False for key in DENIALS})


def validate_header(record,parent_audit_sha):
    expected=fixed_header(parent_audit_sha)
    require(all(record.get(key)==value for key,value in expected.items()),
        "Recovery diagnosis identity/source/window/authority")


def validate_parent(record,reconstruction):
    require(sha(CLOSURE)==PARENT_SHA and record["totals"]==TOTALS,
        "Recovery diagnosis exact parent closure")
    require(reconstruction["ok"] is True and reconstruction["closure_sha256"]==PARENT_SHA
        and reconstruction["source_commit"]==record["source_commit"]
        and reconstruction["original_counts"]==TOTALS
        and reconstruction["reader_world_build_count"]==reconstruction["reader_solver_steps"]==0
        and reconstruction["raw_rewards_moments_quality_and_comparison_recomputed"] is True
        and reconstruction["all_updates_and_training_selection_reconstructed"] is True
        and reconstruction["fresh_challenge_prefixes_recomputed"] is True
        and all(reconstruction[key] is False for key in parent.DENIALS)
        and reconstruction["summaries"]=={a["lane"]:a["summary"] for a in record["attempts"]},
        "Recovery diagnosis complete parent reconstruction")


def artifact_index(receipt):
    rows=receipt["artifacts"];keys=[row["path"] for row in rows]
    require(len(keys)==len(set(keys)) and all(
        isinstance(key,str) and "\\" not in key and not PurePosixPath(key).is_absolute()
        and ".." not in PurePosixPath(key).parts for key in keys),"Recovery diagnosis artifact paths")
    return {row["path"]:row for row in rows}


def bound_path(attempt,key,index):
    require(key in index,"Recovery diagnosis missing retained artifact")
    path=(attempt/key).resolve(strict=True)
    require(path.is_file() and path.is_relative_to(attempt.resolve(strict=True)),
        "Recovery diagnosis artifact boundary")
    return path


def read_bound(attempt,key,index):
    path=bound_path(attempt,key,index);raw=path.read_bytes();bound=index[key]
    require(len(raw)==bound["byte_length"] and hashlib.sha256(raw).hexdigest()==bound["sha256"],
        "Recovery diagnosis artifact digest")
    return json.loads(raw)


def bound_jsonl(attempt,key,index):
    path=bound_path(attempt,key,index);digest=hashlib.sha256();size=0
    with path.open("rb") as stream:
        for raw in stream:
            digest.update(raw);size+=len(raw);yield json.loads(raw)
    require(size==index[key]["byte_length"] and digest.hexdigest()==index[key]["sha256"],
        "Recovery diagnosis raw stream digest")


def validate_population(rows,plans,outer):
    require([row["trial_id"] for row in rows]==[plan["trial_id"] for plan in plans]
        and len(set(row["trial_id"] for row in rows))==len(rows)
        and all(row["controller_rows"]==outer and row["internal_rows"]==outer*5 for row in rows),
        "Recovery diagnosis complete ordered trial population")


def cohort_summary(trials):
    groups=defaultdict(list)
    for row in trials:groups[(row["stage"],row["role"],row["condition_id"])].append(row)
    result=[]
    for (stage,role,condition),rows in sorted(groups.items()):
        commands=[r["control"]["windows"]["common_handoff_window"] for r in rows]
        forces=[r["force"]["windows"]["common_handoff_window"] for r in rows]
        def fraction(key):
            return metrics.numeric([sum(c[key])/c["actuator_commands"] for c in commands])
        result.append(dict(stage=stage,role=role,condition_id=condition,trial_count=len(rows),
            trial_ids=[r["trial_id"] for r in rows],eligible_trials=sum(r["original_outcome"]["diagnostic_eligible"] for r in rows),
            first_failure_time_s=metrics.numeric([r["original_outcome"]["first_reward_failure"]["time_s"] for r in rows
                if r["original_outcome"]["first_reward_failure"] is not None]),
            horizon_censored_trials=sum(r["control"]["terminal_is_horizon_censored"] for r in rows),
            common_window=dict(command_rows_per_trial=20,internal_samples_per_trial=100,
                slew_clamp_fraction_per_trial=metrics.numeric([sum(c["clamp_counts"]["slew_clamped"])/c["actuator_commands"] for c in commands]),
                final_speed_clamp_fraction_per_trial=metrics.numeric([sum(c["clamp_counts"]["final_speed_clamped"])/c["actuator_commands"] for c in commands]),
                opposed_delivered_fraction_per_trial=fraction("opposed_delivered_to_proposed_commands"),
                mean_tilt_per_trial_rad=metrics.numeric([c["tilt_rad"]["mean"] for c in commands]),
                mean_support_count_per_trial=metrics.numeric([sum(int(k)*v for k,v in c["support_count_histogram"].items())/c["controller_rows"] for c in commands]),
                motor_force_cap_fraction_per_trial=[metrics.numeric([f["force_cap_fraction"][i] for f in forces]) for i in range(8)])))
    return result


def reconstruct(evidence,parent_audit):
    source_identity(False)
    original=read(CLOSURE);validate_parent(original,read(parent_audit))
    attempts=parent.header(original,evidence);lanes=[]
    with no_physics():
        for item in original["attempts"]:
            lane=item["lane"];attempt=attempts[lane];receipt=read(attempt/"receipt.json")
            index=artifact_index(receipt);c=parent.task.declaration(lane)
            summarized={r["trial_id"]:r for r in item["summary"]["trials"]}
            trials=[];used={};stage_bindings=[]
            for stage in parent.task.stages(c):
                prefix="stages/"+stage
                audit=read_bound(attempt,prefix+"/audit.json",index)
                plans=parent.task.trial_plans(c,stage);validate_population(audit["trials"],plans,c["outer_steps"])
                stage_bindings.append(index[prefix+"/audit.json"])
                references={}
                for plan,row in zip(plans,audit["trials"],strict=True):
                    key=prefix+"/physical/"+plan["trial_id"];links={}
                    for name in ("plan.json","result.json","inputs.json","native-model.json","compiled.json","model.xml","provider-model.json","controller.jsonl","trace.jsonl"):
                        links[name]=index[key+"/"+name];used[key+"/"+name]=links[name]
                    require(read_bound(attempt,key+"/plan.json",index)==plan
                        and all(row.get(k)==v for k,v in plan.items()),"Recovery diagnosis plan join")
                    native=read_bound(attempt,key+"/native-model.json",index)
                    spec=read_bound(attempt,key+"/inputs.json",index)
                    result=read_bound(attempt,key+"/result.json",index)
                    require(native["condition_id"]==plan["condition_id"]
                        and spec["motor_condition"]["condition_id"]==plan["condition_id"]
                        and native["ordered_bodies"]==["world","torso"]+[leg+part for leg in metrics.LEGS for part in ("_upper","_distal")]
                        and native["inputs_sha256"]==links["inputs.json"]["sha256"]
                        and native["compiled_sha256"]==links["compiled.json"]["sha256"]
                        and native["model_sha256"]==links["model.xml"]["sha256"]
                        and native["provider_model_sha256"]==row["provider_model_sha256"]=="sha256:"+links["provider-model.json"]["sha256"]
                        and result["completed"] is True and result["controller_closed"] is True
                        and result["outer_rows"]==c["outer_steps"] and result["internal_rows"]==c["outer_steps"]*5
                        and all(result["hashes"][name]==row["raw_hashes"][name]==links[name+".jsonl"]["sha256"] for name in ("controller","trace")),
                        "Recovery diagnosis native input/output bindings")
                    outcome=summarized[plan["trial_id"]]
                    outcome={k:outcome[k] for k in ("diagnostic_eligible","diagnostic_failure_codes","first_reward_failure","training_reward","official_quality_m_s")}
                    require(all(row[k]==value for k,value in outcome.items()),"Recovery diagnosis original outcome preserved")
                    frames=[];previous=None
                    for i,raw in enumerate(bound_jsonl(attempt,key+"/controller.jsonl",index)):
                        previous=metrics.frame(raw,previous,i);frames.append(previous)
                    require(len(frames)==c["outer_steps"],"Recovery diagnosis controller horizon")
                    gains,caps=metrics.motor_profile(native,spec)
                    control=metrics.summarize_frames(frames,outcome["first_reward_failure"])
                    require(control["entire_horizon_measured_normal_load_values"]==0,
                        "Recovery diagnosis contact-load availability changed")
                    force=metrics.trace_measurements(bound_jsonl(attempt,key+"/trace.jsonl",index),frames,
                        outcome["first_reward_failure"],c["selection"],gains,caps)
                    pair=None
                    if plan["role"]=="challenge_only":references[plan["group_id"]]=(frames,plan)
                    else:
                        require(plan["group_id"] in references,"Recovery diagnosis fresh reference order")
                        ref,ref_plan=references[plan["group_id"]]
                        pair=metrics.paired_frames(frames,ref,plan,ref_plan)
                    trials.append(dict(plan,controller_rows=len(frames),internal_rows=force["internal_samples"],
                        original_outcome=outcome,artifact_bindings=links,native_velocity_gains=gains,native_force_ranges=caps,
                        control=control,force=force,fresh_reference_comparison=pair))
                    print(json.dumps(dict(lane=lane,stage=stage,trial=plan["trial_id"],retained_diagnostic=True)),flush=True)
                require(set(references)==set(c["groups"]),"Recovery diagnosis stage reference coverage")
            validate_population(trials,parent.task.all_plans(c),c["outer_steps"])
            lanes.append(dict(lane=lane,attempt_id=item["attempt_id"],receipt_sha256=item["receipt_sha256"],
                original_source_commit=original["source_commit"],original_worlds=c["planned_cpu_worlds"],
                stage_bindings=stage_bindings,diagnostic_artifacts_bound=len(used),
                controller_rows=sum(r["controller_rows"] for r in trials),internal_rows=sum(r["internal_rows"] for r in trials),
                exact_paired_prefixes=sum(r["fresh_reference_comparison"] is not None for r in trials),
                cohorts=cohort_summary(trials),trials=trials))
    totals=dict(constructed_cpu_worlds=sum(l["original_worlds"] for l in lanes),constructed_gpu_worlds=0,
        controller_rows=sum(l["controller_rows"] for l in lanes),internal_rows=sum(l["internal_rows"] for l in lanes),
        exact_paired_prefixes=sum(l["exact_paired_prefixes"] for l in lanes))
    require(totals==TOTALS,"Recovery diagnosis total population")
    return dict(fixed_header(sha(parent_audit)),original_totals=totals,attempts=lanes)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--mode",choices=("produce","verify"),required=True)
    p.add_argument("--output-dir",type=Path,required=True);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    source_identity(False);require(jobs.current_in_job(),"Recovery diagnosis requires contained owner")
    evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True);out=args.output_dir.resolve(strict=True)
    require(out.parent.parent==evidence and out.parent.name.startswith("sdk2-recovery-diagnosis-")
        and out.name=="artifacts","Recovery diagnosis fresh output boundary")
    parent_audit=out/"parent-reconstruction.json";record_path=out/"diagnostic.json"
    with no_physics():
        if args.mode=="produce":
            require(not record_path.exists() and not parent_audit.exists(),"Recovery diagnosis already consumed")
            write_new(parent_audit,parent.verify_record(CLOSURE,evidence,args.core,args.baseline_core))
            write_new(record_path,reconstruct(evidence,parent_audit))
        else:
            expected=read(record_path);validate_header(expected,sha(parent_audit))
            actual=reconstruct(evidence,parent_audit)
            require(actual==expected,"Recovery diagnosis complete raw reconstruction differs")
            write_new(out/"complete-reconstruction.json",dict(ok=True,ledger_scope=SCOPE,
                record_sha256=sha(record_path),parent_reconstruction_sha256=sha(parent_audit),
                original_totals=TOTALS,reader_world_build_count=0,reader_solver_steps=0,
                all_original_outcomes_preserved=True,**{key:False for key in DENIALS}))
    print(json.dumps(dict(ok=True,mode=args.mode,record_sha256=sha(record_path),original_totals=TOTALS)),flush=True)
    return 0


if __name__=="__main__":raise SystemExit(main())
