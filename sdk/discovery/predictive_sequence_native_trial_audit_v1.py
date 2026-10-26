"""Stream all retained native evidence, including a final untransferred refusal."""
import hashlib
import json
import math
import numpy as np
from audit_gpu_batch_execution import same_bits
from audit_gpu_portable_search import validate_observation
from body_height_diagnostic import physical_violation
from motor_effectiveness_task import condition_inputs,expected_actuator_arrays
from predictive_sequence_native_task_v1 import read,sha,require,provider,initial_arrays,profile_for,controller_for
from predictive_sequence_native_checks_v1 import outcome,native_step,refusal_join,timing_row
from hierarchical_native_trial_audit_v6 import reconstructed_kinematics
from audit_recovery_hold_native import expected_metadata,validate_sample
from recovery_hold_component_audit import transition
from causal_force_control import terminal_error
from predictive_sequence_row_audit_v3 import verify_row
from predictive_sequence_selection_audit_v2 import verify_selection
from predictive_command_selection_v2 import PredictiveSelector
from held_contact_rollout import compare_geometry

def bounded_rows(path,c):
    require(path.stat().st_size<=c["maximum_trace_bytes_per_trial"],"Predictive stream byte bound")
    with path.open("rb") as stream:
        while True:
            line=stream.readline(c["maximum_controller_row_bytes"]+1)
            if not line:return
            require(len(line)<=c["maximum_controller_row_bytes"] and line.endswith(b"\n"),"Predictive row byte bound/terminator")
            yield json.loads(line)


def selected_reference(row,reference):
    decision=row["force_reference"]["decision"];selection=decision.get("selection")
    if selection is None:return None
    request=row["resolution_request"]["provider_request"]
    return verify_selection(selection,decision["starting_packet"],
        request["provider_memory"]["opaque_state"]["plan"],reference,reference)


def applied_forecast(row):
    selection=row["force_reference"]["decision"]["selection"]
    require(selection["accepted"] is True and selection["best"]["result"]["eligible"] is True,
        "Sequence native requires an admissible selected plan")
    first=selection["best"]["result"]["rows"][0];forecast=first["forecast"]
    require(first["offset"]==0 and first["target"]==selection["selected_target"]==row["native_targets"]
        and forecast["held_target"]==row["native_targets"]
        and forecast["accepted"] is True and forecast["completed_steps"]==5 and len(forecast["rows"])==5,
        "Sequence native exact first applied interval")
    return forecast


def audit_trial(folder,plan,c,core_path,core,expected_model=None):
    require(read(folder/"plan.json")==plan,"Predictive audit plan")
    result=read(folder/"result.json")
    require(all(result.get(k)==v for k,v in plan.items()),"Predictive crossed trial")
    outer_count,inner_count=outcome(result,c,plan["role"])
    for key in ("setup_s","graph_capture_s"):
        require(provider.ars.finite(result[key]) and result[key]>=0.,"Residual setup timing")
    require(result["graph_capture_s"]==0.,"Residual CPU graph identity")
    for name in ("controller","trace","timing"):
        require(sha(folder/(name+".jsonl"))==result["hashes"][name],"Residual raw digest")
    expected,xml,spec=condition_inputs(core_path,dict(c,core_sha256=sha(core_path)),plan["condition_id"])
    compiled=read(folder/"compiled.json");metadata=read(folder/"native-model.json")
    require(compiled==expected and read(folder/"inputs.json")==spec
        and (folder/"model.xml").read_text(encoding="utf-8")==xml,"Residual model/compiler inputs")
    for name,key in (("model.xml","model_sha256"),("inputs.json","inputs_sha256"),("compiled.json","compiled_sha256")):
        require(sha(folder/name)==metadata[key],"Residual native metadata digest")
    require(metadata["condition_id"]==plan["condition_id"]
        and metadata["actuator_profile"]==expected_actuator_arrays(spec)
        and metadata["force_ranges"]==spec["force_ranges"]
        and metadata["ordered_bodies"]==["world"]+compiled["morphology"]["ordered_body_ids"]
        and metadata["body_rootid"]==[0]+[1]*9
        and metadata["observation_stage"]=="prepared_before_control"
        and metadata["force_stage"]=="completed_step_before_next_prepare"
        and metadata["dynamics_dtype"]=="float64" and metadata["initial_values"]==c["initial_values"],
        "Residual native topology/profile/stages")
    artifact=read(folder/"provider-model.json")
    require(expected_model is not None and artifact==expected_model,"Recovery crossed frozen artifact")
    model=provider.FrozenModel.load(core,artifact)
    require("sha256:"+sha(folder/"provider-model.json")==model.sha256
        ==metadata["provider_model_sha256"]==result["provider_model_sha256"],"Residual model byte identity")
    profile=profile_for(plan["role"],compiled,spec,xml)
    require(read(folder/"force-profile.json")==profile
        and metadata["force_profile_sha256"]==sha(folder/"force-profile.json"),"Force exact configured profile")
    controller=controller_for(plan["role"],core,compiled,c,model,plan["trial_id"],profile)
    candidate=plan["role"]=="predictive_hold"
    base_profile=profile["nominal_profile"] if candidate else profile
    reference=PredictiveSelector(base_profile,xml) if candidate else None
    initial=initial_arrays(spec,plan);last=previous=None
    metric=dict(minimum_height_m=math.inf,maximum_tilt_rad=0.,torso_contact_steps=0,
        ground_contact_steps=0,nonzero_force_steps=0,safe_no_actuation_steps=0,first_physical_violation=None)
    positions=hashlib.sha256();outer=inner=applied=nonzero=refused=selected_count=non_nominal=0
    evaluations=nominal_refusals=fallback_applied=0;search_reasons={}
    motor_error=geometry_error=prediction_position_error=prediction_velocity_error=0.
    reference_stats={};timing_totals={};contact_totals={};total_contacts=inactive=other_count=0;total_load=0.
    handoff=None;maximum_delta={};support={};safe_support={};support_count=safe_support_count=0
    contact_metadata=expected_metadata(compiled,spec,c)
    require(read(folder/"contact-metadata.json")==contact_metadata
        and sha(folder/"contact-metadata.json")==result["contact_metadata_sha256"],"Predictive contact metadata")
    for name in ("contact-force","contact-timing"):
        require(sha(folder/(name+".jsonl"))==result["contact_hashes"][name],"Predictive contact stream digest")
    iterators={name:bounded_rows(folder/(name+".jsonl"),c) for name in ("trace","timing","contact-force","contact-timing")}
    try:
        for step,row in enumerate(bounded_rows(folder/"controller.jsonl",c)):
            require(step<outer_count and (row["backend"],row["cell"],row["outer_step"])==("cpu",0,step),"Predictive controller order")
            validate_observation(row,metadata,compiled)
            require(same_bits(reconstructed_kinematics(row,compiled,metadata),row["kinematics"]),"Predictive endpoint/native join")
            expected=controller.step(row["request"]["state"],row["stability"],row["kinematics"])
            require(all(key in row and same_bits(value,row[key]) for key,value in expected.items()),"Predictive other-core whole-host replay")
            error=terminal_error(row);transferred=error is None
            require(transferred or (step==outer_count-1 and not result["completed"]),"Predictive terminal refusal placement")
            if candidate:
                verify_row(core,row,previous,row,profile,controller.force_policy.selector)
                if step>=60:
                    native=row["native_observation"]
                    geometry_error=max(geometry_error,compare_geometry(reference.rollout.detect(native["qpos"]),native["contacts"]))
                    verified=selected_reference(row,reference)
                    if verified is not None:
                        selected_count+=1
                        for key,value in verified.items():
                            reference_stats[key]=(reference_stats.get(key,0)+value if key=="changed_iteration_counts"
                                else max(reference_stats.get(key,0),value))
                    selection=row["force_reference"]["decision"].get("selection")
                    decision=row["force_reference"]["decision"]
                    fallback=decision.get("proposal",{}).get("nominal_allocation_available") is False
                    nominal_refusals+=int(fallback);fallback_applied+=int(fallback and transferred)
                    if selection is not None:
                        evaluations+=selection["evaluated_candidates"]
                        reason=selection["reason"];search_reasons[reason]=search_reasons.get(reason,0)+1
                    if transferred:
                        non_nominal+=int(selection["selected_correction"]!=decision["proposal"]["projection"]["proposal"])
            resolution=row["resolution"];commands=resolution["ordered_commands"]
            require(resolution["world_build_count"]==0 and resolution["physics_state_modified"] is False
                and resolution["physical_acceptance_authority"] is False,"Predictive resolver authority")
            applied+=int(resolution["adaptation_applied"]);nonzero+=int(any(x["applied_correction_rad_s"]!=0. for x in commands))
            refused+=int(not transferred);metric["safe_no_actuation_steps"]+=int(row["output"]["actuation"]["safe_no_actuation"])
            require(all(s["normal_load_n"] is None for s in row["request"]["state"]["ordered_contact_observations"]),
                "Predictive controller unexpectedly received force loads")
            if step>=60:
                change=transition(previous,row)
                if handoff is None:handoff=change
                for key,values in change.items():maximum_delta[key]=max(maximum_delta.get(key,0),*(abs(x) for x in values))
                support_count+=1;safe_now=metric["first_physical_violation"] is None
                safe_support_count+=int(safe_now)
                for site in row["request"]["state"]["ordered_contact_observations"]:
                    key=site["contact_site_id"];support[key]=support.get(key,0)+int(site["bears_support"])
                    safe_support[key]=safe_support.get(key,0)+int(safe_now and site["bears_support"])
            timing=next(iterators["timing"],None);require(timing is not None,"Predictive missing control timing")
            timing_row(timing,step,transferred)
            for key,value in timing.items():
                if key not in ("outer_step","measured","transfer_performed"):timing_totals[key]=timing_totals.get(key,0.)+value
            if not transferred:
                refusal_join(result,row,last,initial,previous["native_targets"] if previous else [0.]*8)
            else:
                forecast=None
                if candidate and step>=60:
                    selection=row["force_reference"]["decision"]["selection"]
                    forecast=applied_forecast(row)
                for sub in range(5):
                    raw=next(iterators["trace"],None);sample=next(iterators["contact-force"],None)
                    capture=next(iterators["contact-timing"],None)
                    require(raw is not None and sample is not None and capture is not None,"Predictive missing native/capture tail")
                    motor_error=max(motor_error,native_step(raw,inner+1,row,last,initial,spec,c,base_profile))
                    validate_sample(sample,raw,contact_metadata,c)
                    require(capture["step"]==sample["step"] and set(capture)=={"step","native_prepare_s",
                        "prepare_capture_s","native_complete_s","complete_guard_s","force_capture_s","serialization_s"},
                        "Predictive contact timing identity")
                    for key,value in capture.items():
                        if key=="step":continue
                        require(type(value) in (float,int) and math.isfinite(value) and value>=0,"Predictive finite capture timing")
                        contact_totals[key]=contact_totals.get(key,0.)+value
                    total_contacts+=sample["ncon"];inactive+=sum(x["efc_address"]<0 for x in sample["contacts"])
                    other_count+=len(sample["other_contact_indices"])
                    total_load+=sum(x["normal_load_n"] for x in sample["mapped_distal_ground_loads"])
                    metric["minimum_height_m"]=min(metric["minimum_height_m"],raw["qpos"][2])
                    tilt=math.acos(max(-1.,min(1.,1.-2*(raw["qpos"][4]**2+raw["qpos"][5]**2))))
                    metric["maximum_tilt_rad"]=max(metric["maximum_tilt_rad"],tilt)
                    metric["torso_contact_steps"]+=int(any(1 in contact["geom"] for contact in raw["contacts"]))
                    metric["ground_contact_steps"]+=int(bool(raw["contacts"]))
                    metric["nonzero_force_steps"]+=int(any(f!=0. for f in raw["actuator_force_nm"]))
                    if metric["first_physical_violation"] is None:metric["first_physical_violation"]=physical_violation(raw,c["selection"])
                    positions.update(json.dumps(raw["qpos"],separators=(",",":"),allow_nan=False).encode("utf-8")+b"\n")
                    if forecast:
                        predicted=forecast["rows"][sub]
                        prediction_position_error=max(prediction_position_error,float(np.max(np.abs(np.array(predicted["qpos"])-raw["qpos"]))))
                        prediction_velocity_error=max(prediction_velocity_error,float(np.max(np.abs(np.array(predicted["qvel"])-raw["qvel"]))))
                    last=raw;inner+=1
            previous=row;outer+=1
        require(outer==outer_count and inner==inner_count,"Predictive exact complete available denominator")
        for name,iterator in iterators.items():require(next(iterator,None) is None,"Predictive extra "+name+" rows")
    finally:
        controller.close()
        for iterator in iterators.values():iterator.close()
    metric["forward_displacement_m"]=(last["qpos"][0] if last else initial[0][0])-spec["initial_qpos"][0]
    if last is None:metric["minimum_height_m"]=None
    failures=[]
    for name,bad in (("incomplete_comparison",not result["completed"]),
        ("height",last is not None and metric["minimum_height_m"]<c["selection"]["minimum_height_m"]),
        ("tilt",metric["maximum_tilt_rad"]>c["selection"]["maximum_tilt_rad"]),
        ("torso_contact",metric["torso_contact_steps"]>0),("safe_no_actuation",bool(metric["safe_no_actuation_steps"]))):
        if bad:failures.append(name)
    return dict(plan,completed=result["completed"],status=result["status"],terminal_refusal=result["terminal_refusal"],
        controller_rows=outer,transferred_commands=inner//5,internal_rows=inner,
        control_applied_commands=applied,nonzero_correction_commands=nonzero,refused_commands=refused,
        diagnostic_metrics=metric,diagnostic_failure_codes=failures,diagnostic_eligible=not failures,
        selection_authority=False,official_quality_m_s=None,raw_hashes=result["hashes"],positions_sha256=positions.hexdigest(),
        provider_model_sha256=model.sha256,timing=timing_totals,
        native_motor_validation=dict(internal_samples=inner,maximum_model_error_nm=motor_error),
        prediction_validation=dict(best_sequence_reference_commands=selected_count,commands_differing_from_seed=non_nominal,
            evaluated_sequences=evaluations,search_reasons=search_reasons,
            nominal_refusal_commands=nominal_refusals,applied_fallback_commands=fallback_applied,
            native_comparison_scope="first applied five internal steps only; later sequence intervals remain forecasts",
            reference_comparison=reference_stats,maximum_native_geometry_error_m=geometry_error,
            maximum_forecast_native_position_component_error=prediction_position_error,
            maximum_forecast_native_velocity_component_error=prediction_velocity_error,
            errors_are_diagnostic_only=True,all_candidate_guards_and_costs_reconstructed=True),
        contact_capture=dict(rows=inner,contacts=total_contacts,inactive_contacts=inactive,other_contacts=other_count,
            mean_total_distal_normal_load_n=total_load/inner if inner else None,timing_s=contact_totals,force_reconstruction_verified=True),
        handoff_transition=dict(command=60,at_handoff=handoff,maximum_post_handoff_absolute_delta_rad_s=maximum_delta,
            total_target_slew_guaranteed=False),
        post_handoff_support=dict(prepared_commands=support_count,by_site=support,may_include_post_failure_states=True),
        pre_failure_post_handoff_support=dict(prepared_commands=safe_support_count,by_site=safe_support))
