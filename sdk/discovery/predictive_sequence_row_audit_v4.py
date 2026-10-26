"""Reconstruct public commands, history and candidate selection from retained rows."""
import copy
import numpy as np
from actuation_recovery_mechanics import require
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import same_bits
from audit_predictive_numeric_backend import compare
from predictive_sequence_policy_v4 import PROVIDER,VERSION,CORPUS,HANDOFF,digest
from prepared_predictive_model import canonical_packet
from predictive_sequence_refinement_audit_v1 import verify_selection
from predictive_sequence_online_v2 import next_plan
import hierarchical_force_policy_v8 as nominal
from predictive_history_seed_v1 import prepare as history_seed


def verify_row(core,row,previous,original,profile,selector,reference=None):
    step=row["request"]["state"]["semantic_step"]
    require(row["request"]["state"]==original["request"]["state"],"Predictive audit retained observation")
    require(same_bits(row["output"],original["output"]),"Predictive audit unchanged core baseline")
    request=row["resolution_request"]["provider_request"];response=row["resolution_request"]["provider_response"]
    resolved=row["resolution"];core_result=core.resolve_adaptation_v1(row["resolution_request"])
    require(same_bits(resolved,core_result),"Predictive audit independent public resolution")
    if previous is not None:
        expected,boundary=history.append_resolved(core,previous["resolution_request"]["provider_request"],previous["resolution"])
        require(boundary is None,"Predictive audit preceding history boundary")
        expected["ordered_entries"]=expected["ordered_entries"][-1:]
        require(same_bits(request["history"],expected),"Predictive audit exact actual history")
        require([r["previous_applied_correction_rad_s"] for r in request["safety_envelope"]["ordered_actuator_limits"]]
            ==[r["applied_correction_rad_s"] for r in previous["resolution"]["ordered_commands"]],
            "Predictive audit actual preceding corrections")
    if step<HANDOFF:
        require(same_bits(row["native_targets"],original["native_targets"]),"Predictive audit unchanged prefix")
        return dict(step=step,prefix=True,applied=resolved["provider_status"]=="applied")
    sha=digest(core,profile);d=row["force_reference"]["decision"];marker=row["predictive_sequence"]
    require(request["provider_id"]==PROVIDER and request["expected_provider_version"]==VERSION
        and request["expected_model_sha256"]==sha and d["profile_sha256"]==sha
        and d["request_sha256"]==digest(core,request)
        and d["prepared_model_sha256"]==digest(core,profile["prepared_model"]),
        "Predictive audit model/request binding")
    require(d["nominal_prediction_applies_to_transfer"] is False
        and marker["nominal_prediction_applies_to_transfer"] is False,"Predictive audit distinct prediction meanings")
    if step>HANDOFF:
        require(request["provider_memory"]==previous["resolution"]["next_memory"],"Predictive audit public memory continuation")
        opaque=request["provider_memory"]["opaque_state"];prior=previous["resolution"]["request_sha256"]
        require(opaque["previous_binding"]==opaque["nominal_memory"]["opaque_state"]["previous_binding"]==prior,
            "Predictive audit memory actual binding")
    selection=d.get("selection");measured=None;expected_inner=None
    if d["stage"] in ("selection","selection_error"):
        seed=d["proposal"];base=request["deterministic_baseline"]["ordered_commands"]
        limits=request["safety_envelope"]["ordered_actuator_limits"]
        commands=dict(command=step,baseline=[r["combined_canonical_target_velocity_rad_s"] for r in base],
            speeds=[r["maximum_target_speed_rad_s"] for r in base],
            previous_correction=[r["previous_applied_correction_rad_s"] for r in limits],
            nominal_correction=seed["projection"]["proposal"],target_com=seed["target_com"],
            reference_joints=seed["support_reference"]["reference_joint_positions_rad"])
        starting=canonical_packet(request["state"],commands,[j["joint_id"] for j in profile["prepared_model"]["morphology_spec"]["joints"]])
        require(same_bits(starting,d["starting_packet"]),"Predictive audit causal starting packet")
        # Independently reconstruct the un-applied internal nominal request.
        inner=copy.deepcopy(request);n=profile["nominal_profile"];nsha=digest(core,n)
        inner.update(request_id="force_"+request["provider_memory"]["opaque_state"]["episode_id"]+"_"+str(step),
            provider_id=nominal.PROVIDER,expected_provider_version=nominal.VERSION,
            expected_model_id="configured_hierarchy_"+nsha[-24:],expected_model_sha256=nsha,
            expected_training_corpus_id="untrained_configured_force_reference",
            expected_training_corpus_sha256=digest(core,nominal.CORPUS),
            provider_memory=copy.deepcopy(request["provider_memory"]["opaque_state"]["nominal_memory"]))
        context=inner["controller_context"];host=context["controller_memory"]["nominal_context"]
        context.update(controller_memory_schema_version=nominal.CONTEXT,controller_memory=host,
            controller_memory_sha256=digest(core,host))
        require(digest(core,inner)==d["nominal_request_sha256"],"Predictive audit nominal diagnostic identity")
        raw=d["nominal"]
        if seed["nominal_allocation_available"] is False:
            expected_seed,expected_inner=history_seed(nominal.Policy(core,n),inner,raw)
        else:
            require(seed["nominal_allocation_available"] is True and raw["allocation"]["accepted"] is True,
                "Sequence accepted nominal allocation identity")
            expected_seed=dict(kind="nominal_proposal",nominal_allocation_available=True,
                projection=dict(proposal=raw["projection"]["proposal"],target=raw["projection"]["target"]),
                target_com=raw["target_com"],support_reference=raw["support_reference"],
                force_certificate_for_selected_sequence=False)
            expected_inner=copy.deepcopy(inner["provider_memory"])
            io=expected_inner["opaque_state"]
            io.update(last_step=step,target_com=raw["target_com"],
                previous_forces={name:force for name,force in zip(raw["active_contacts"],raw["allocation"]["forces"],strict=True)},
                previous_binding=digest(core,inner))
            expected_inner.update(sequence=step-HANDOFF+1,opaque_state_sha256=digest(core,io))
        require(same_bits(seed,expected_seed),"Sequence independently reconstructed proposal")

        if selection is not None:
            plan=request["provider_memory"]["opaque_state"]["plan"]
            require(plan is None or plan["request_sha256"]==request["provider_memory"]["opaque_state"]["previous_binding"],
                "Sequence audit prior plan actual binding")
            measured=verify_selection(selection,starting,plan,selector,reference)
    error=row["force_reference"]["terminal_error"]
    if error is not None:
        require(response is None and not resolved["adaptation_applied"]
            and all(x["applied_correction_rad_s"]==0. for x in resolved["ordered_commands"])
            and marker["selected_prediction_matches_final_public_command"] is False
            and marker["actual_resolved_history_continues"] is False,
            "Predictive audit fail-closed refusal")
        require(d["stage"] in ("nominal_refusal","selection_error","safe_no_actuation")
            or (selection is not None and not selection["accepted"]),"Predictive audit retained refusal cause")
        return dict(step=step,prefix=False,applied=False,stage=d["stage"],comparison=measured)
    require(response is not None and response["status"]==resolved["provider_status"]=="applied"
        and marker["selected_prediction_matches_final_public_command"] is True
        and marker["actual_resolved_history_continues"] is True
        and all(response["provenance"][key] is False for key in ("engine_specific_logic_used",
            "direct_world_access_used","weights_mutated","physical_acceptance_authority")),
        "Predictive audit public applied provenance")
    require([x["canonical_velocity_delta_rad_s"] for x in response["ordered_corrections"]]
        ==[x["applied_correction_rad_s"] for x in resolved["ordered_commands"]]==selection["selected_correction"]
        and [x["final_canonical_target_velocity_rad_s"] for x in resolved["ordered_commands"]]
        ==selection["selected_target"]==row["native_targets"],"Predictive audit actual selected transfer")
    memory=resolved["next_memory"];opaque=memory["opaque_state"]
    require(memory==response["next_memory"] and memory["sequence"]==step-HANDOFF+1
        and opaque["previous_binding"]==opaque["nominal_memory"]["opaque_state"]["previous_binding"]==resolved["request_sha256"]
        and memory["opaque_state_sha256"]==digest(core,opaque)
        and opaque["nominal_memory"]["opaque_state_sha256"]==digest(core,opaque["nominal_memory"]["opaque_state"]),
        "Predictive audit next memory and nominal diagnostic binding")
    expected_inner["opaque_state"]["previous_binding"]=digest(core,request)
    expected_inner["opaque_state_sha256"]=digest(core,expected_inner["opaque_state"])
    require(same_bits(opaque["nominal_memory"],expected_inner)
        and opaque["last_nominal_allocation_accepted"]==d["proposal"]["nominal_allocation_available"],
        "Sequence truthful exact nominal compatibility memory")
    require(opaque["plan"]==next_plan(d["starting_packet"],selection,digest(core,request)),
        "Sequence audit exact next projected plan")
    return dict(step=step,prefix=False,applied=True,reason=selection["reason"],
        evaluated_candidates=selection["evaluated_candidates"],
        differs_from_seed=selection["selected_correction"]!=d["proposal"]["projection"]["proposal"],
        nominal_allocation_available=d["proposal"]["nominal_allocation_available"],comparison=measured)
