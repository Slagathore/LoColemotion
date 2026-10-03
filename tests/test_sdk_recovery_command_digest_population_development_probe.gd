extends SceneTree
# gdlint: disable=max-line-length

## Repeatable zero-world development probe for the finite active recovery
## command population. This is transport conformance, not physical
## qualification: every command must retain its core digest through the actual
## Godot extension/JSON/application route, and no physical authority opens.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const RuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_RECOVERY_COMMAND_DIGEST_POPULATION_DEVELOPMENT_PROBE "
const RAISE_BODY_MAXIMUM_PHASE_STEP := 600
const MAXIMUM_RETAINED_MISMATCH_DETAILS := 1


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("COMMAND_DIGEST_PROBE_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("COMMAND_DIGEST_PROBE_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("COMMAND_DIGEST_PROBE_CONTEXT_FAILED", context)
	var fixture := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(fixture.get("ok", false)):
		return _failure("COMMAND_DIGEST_PROBE_FIXTURE_FAILED", fixture)
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("COMMAND_DIGEST_PROBE_SURFACE_FAILED", surface)

	var cell_specs: Array = [
		{
			"controller_owner": "recovery",
			"phase": "establish_distal_support",
			"phase_step": 0,
		},
	]
	for phase_step in range(RAISE_BODY_MAXIMUM_PHASE_STEP + 1):
		cell_specs.append(
			{
				"controller_owner": "recovery",
				"phase": "raise_body",
				"phase_step": phase_step,
			}
		)
	cell_specs.append(
		{
			"controller_owner": "stance",
			"phase": "stance_handoff",
			"phase_step": 0,
		}
	)

	var rows: Array = []
	var mismatch_cells: Array = []
	var retained_mismatches: Array = []
	var mismatch_count := 0
	var application_pass_count := 0
	var validated_command_count := 0
	var host_write_count := 0
	var host_readback_count := 0
	var expected_digest_set := {}
	var recomputed_digest_set := {}
	for cell_index in range(cell_specs.size()):
		var spec: Dictionary = cell_specs[cell_index]
		var planned := (
			_collect_and_plan_stance_handoff_v1(sdk, context, fixture)
			if String(spec["controller_owner"]) == "stance"
			else RouteScript.collect_and_plan_v1(
				sdk,
				context,
				fixture,
				String(spec["phase"]),
				int(spec["phase_step"]),
			)
		)
		if not bool(planned.get("ok", false)):
			RouteScript.free_zero_world_command_surface_v1(surface)
			return _failure("COMMAND_DIGEST_PROBE_PLANNING_FAILED", planned)
		var control: Dictionary = planned["control_receipt"]
		var expected_sha256 := String(control.get("command_sha256", ""))
		var recomputed_receipt := RuntimeScript.canonicalize(
			sdk, control.get("ordered_commands")
		)
		var recomputed_sha256 := String(recomputed_receipt.get("sha256", ""))
		expected_digest_set[expected_sha256] = true
		recomputed_digest_set[recomputed_sha256] = true
		var application := RouteScript.apply_behavior_control_v1(
			sdk,
			control,
			surface["joint_by_actuator_id"],
			surface["position_by_joint_id"],
			true,
		)
		var digest_matches := expected_sha256 == recomputed_sha256
		rows.append(
			{
				"cell_index": cell_index,
				"controller_id": String(control.get("controller_id", "")),
				"controller_owner": String(control.get("owner", "")),
				"phase": String(control.get("phase", "")),
				"phase_step": int(control.get("phase_step", -1)),
				"semantic_step": int(control.get("semantic_step", -1)),
				"expected_command_sha256": expected_sha256,
				"recomputed_command_sha256": recomputed_sha256,
				"digest_matches": digest_matches,
				"application_ok": bool(application.get("ok", false)),
				"application_failure_code": application.get("failure_code"),
			}
		)
		if digest_matches:
			if not bool(application.get("ok", false)):
				RouteScript.free_zero_world_command_surface_v1(surface)
				return _failure("COMMAND_DIGEST_PROBE_NON_DIGEST_APPLICATION_FAILED", application)
			if (
				int(application.get("validated_command_count", -1)) != 8
				or int(application.get("host_write_count", -1)) != 8
				or int(application.get("host_readback_count", -1)) != 8
				or not bool(application.get("zero_world_host_surface", false))
				or int(application.get("world_build_count", -1)) != 0
				or int(application.get("solver_step_count", -1)) != 0
				or bool(application.get("physics_state_modified", true))
			):
				RouteScript.free_zero_world_command_surface_v1(surface)
				return _failure("COMMAND_DIGEST_PROBE_APPLICATION_RECEIPT_INVALID", application)
			application_pass_count += 1
			validated_command_count += int(application["validated_command_count"])
			host_write_count += int(application["host_write_count"])
			host_readback_count += int(application["host_readback_count"])
		else:
			if (
				bool(application.get("ok", false))
				or String(application.get("failure_code", ""))
				!= "QSDK_R24D57_COMMAND_DIGEST_INVALID"
			):
				RouteScript.free_zero_world_command_surface_v1(surface)
				return _failure("COMMAND_DIGEST_PROBE_MISMATCH_NOT_REJECTED", application)
			mismatch_count += 1
			mismatch_cells.append(rows[-1].duplicate(true))
			if retained_mismatches.size() < MAXIMUM_RETAINED_MISMATCH_DETAILS:
				retained_mismatches.append(
					{
						"cell": rows[-1].duplicate(true),
						"application_detail": (
							application.get("detail", {}) as Dictionary
						).duplicate(true),
					}
				)

	var population_receipt := RuntimeScript.canonicalize(sdk, rows)
	var forced_control_route := RouteScript.collect_and_plan_v1(
		sdk, context, fixture, "establish_distal_support", 0
	)
	var forced_control: Dictionary = (
		forced_control_route.get("control_receipt", {}) as Dictionary
	).duplicate(true)
	forced_control["command_sha256"] = (
		"sha256:0000000000000000000000000000000000000000000000000000000000000000"
	)
	var forced_failure := RouteScript.apply_behavior_control_v1(
		sdk,
		forced_control,
		surface["joint_by_actuator_id"],
		surface["position_by_joint_id"],
		true,
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	var forced_failure_rejected := (
		not bool(forced_failure.get("ok", false))
		and String(forced_failure.get("failure_code", ""))
		== "QSDK_R24D57_COMMAND_DIGEST_INVALID"
		and String((forced_failure.get("detail", {}) as Dictionary).get(
			"expected_command_sha256", ""
		)) == String(forced_control["command_sha256"])
	)
	var forced_failure_detail: Dictionary = forced_failure.get("detail", {}) as Dictionary
	var compact_forced_failure := {
		"failure_code": String(forced_failure.get("failure_code", "")),
		"expected_command_sha256": String(
			forced_failure_detail.get("expected_command_sha256", "")
		),
		"recomputed_command_sha256": String(
			forced_failure_detail.get("recomputed_command_sha256", "")
		),
		"host_write_count": int(forced_failure_detail.get("host_write_count", -1)),
		"world_build_count": int(forced_failure_detail.get("world_build_count", -1)),
		"solver_step_count": int(forced_failure_detail.get("solver_step_count", -1)),
		"physics_state_modified": bool(
			forced_failure_detail.get("physics_state_modified", true)
		),
	}
	var ok := (
		cell_specs.size() == 603
		and application_pass_count == cell_specs.size()
		and validated_command_count == 4824
		and host_write_count == 4824
		and host_readback_count == 4824
		and mismatch_count == 0
		and retained_mismatches.is_empty()
		and expected_digest_set.size() == 362
		and recomputed_digest_set.size() == 362
		and String(population_receipt.get("sha256", "")).begins_with("sha256:")
		and forced_failure_rejected
	)
	return {
		"schema_version": "sporespore_recovery_command_digest_population_development_probe_v3",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot",
			"authority_mode": "repeatable_zero_world_development",
			"question_class": "development",
		},
		"ok": ok,
		"status": "transport_stable" if mismatch_count == 0 else "digest_mismatch_observed",
		"active_command_cell_count": cell_specs.size(),
		"recovery_active_command_cell_count": 602,
		"stance_command_shape_cell_count": 1,
		"synthetic_stance_handoff_fixture_count": 1,
		"application_pass_count": application_pass_count,
		"validated_command_count": validated_command_count,
		"host_write_count": host_write_count,
		"host_readback_count": host_readback_count,
		"digest_mismatch_count": mismatch_count,
		"retained_mismatch_detail_count": retained_mismatches.size(),
		"maximum_retained_mismatch_details": MAXIMUM_RETAINED_MISMATCH_DETAILS,
		"unique_expected_digest_count": expected_digest_set.size(),
		"unique_recomputed_digest_count": recomputed_digest_set.size(),
		"population_sha256": String(population_receipt.get("sha256", "")),
		"mismatch_cells": mismatch_cells,
		"retained_mismatches": retained_mismatches,
		"forced_digest_failure_rejected": forced_failure_rejected,
		"forced_digest_failure_detail": compact_forced_failure,
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Exercise the actual portable stance planner and production application
## route without claiming a supervisor transition. The input step begins from
## the complete production StepV4 receipt shape, then projects only the
## transport-required handoff edge and gates as an explicit synthetic fixture.
static func _collect_and_plan_stance_handoff_v1(
	sdk: Object,
	context: Dictionary,
	fixture: Dictionary,
) -> Dictionary:
	var raise_route := RouteScript.collect_and_plan_v1(
		sdk,
		context,
		fixture,
		"raise_body",
		RAISE_BODY_MAXIMUM_PHASE_STEP,
	)
	if not bool(raise_route.get("ok", false)):
		return _failure("COMMAND_DIGEST_PROBE_STANCE_COLLECTION_FAILED", raise_route)
	var step_route := RouteScript.initialize_and_step_v4(sdk, context, fixture)
	if not bool(step_route.get("ok", false)):
		return _failure("COMMAND_DIGEST_PROBE_STANCE_STEP_SHAPE_FAILED", step_route)
	var step: Dictionary = (step_route["step_receipt"] as Dictionary).duplicate(true)
	var collection_receipt: Dictionary = raise_route["collection_receipt"]
	step["observation_sha256"] = String(collection_receipt.get("observation_sha256", ""))
	step["prior_phase"] = "raise_body"
	step["next_phase"] = "stance_handoff"
	step["transitioned"] = true
	var classification: Dictionary = step.get("classification", {}) as Dictionary
	classification["raised_body_gate"] = true
	classification["safety_gate"] = true
	step["classification"] = classification
	var memory: Dictionary = step.get("memory", {}) as Dictionary
	memory["phase"] = "stance_handoff"
	memory["ordered_completed_phases"] = [
		"confirm_prone",
		"establish_distal_support",
		"raise_body",
	]
	memory["phase_steps_observed"] = 0
	memory["terminal_failure_code"] = null
	step["memory"] = memory
	var control := RuntimeScript.plan_stance_control_v3(
		sdk,
		{
			"schema_version": "sporespore_recovery_stance_control_request_v3",
			"controller_id": RouteScript.STANCE_CONTROLLER_ID,
			"collection": raise_route["collection_request"],
			"handoff_or_stance_step": step,
		}
	)
	if (
		String(control.get("support_status", "")) != "supported_exact"
		or String(control.get("owner", "")) != "stance"
		or String(control.get("phase", "")) != "stance_handoff"
		or not bool(control.get("stance_handoff_requested", false))
	):
		return _failure("COMMAND_DIGEST_PROBE_STANCE_CONTROL_FAILED", control)
	return {
		"schema_version": "sporespore_recovery_command_stance_transport_fixture_v1",
		"ok": true,
		"collection_request": raise_route["collection_request"],
		"collection_receipt": collection_receipt,
		"synthetic_handoff_step_fixture": step,
		"control_receipt": control,
		"supervisor_transition_claimed": false,
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_recovery_command_digest_population_development_probe_v3",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot",
			"authority_mode": "repeatable_zero_world_development",
			"question_class": "development",
		},
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
