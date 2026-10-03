extends SceneTree
# gdlint: disable=max-line-length

## R133 exercises the actual V6 raise_body -> stance_handoff production
## dispatch without constructing a world. The sample is synthetic but carries
## the exact source-bound V2 and energy-extended V3 representations used by the
## physical route. The additive V4 stance call must bind both representations,
## the R126 authority, and its development progression receipt.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const R131Test := preload(
	"res://tests/test_sdk_qsdk_r24d131_godot_progression_dispatch_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D133_GODOT_STANCE_OBSERVATION_BINDING_ZERO_WORLD "
const SEMANTIC_STEP := 40


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var inherited := R131Test._evaluate()
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D133_EXTENSION_UNAVAILABLE", inherited)
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D133_EXTENSION_INSTANTIATION_FAILED", inherited)

	var context := RouteScript.prepare_context_v6(sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID)
	var source_bound := RouteScript.zero_world_fixture_v6(sdk, context)
	var initialized := RouteScript.initialize_behavior_arm_v1(sdk, context, "candidate_command")
	if (
		not bool(context.get("ok", false))
		or not bool(source_bound.get("ok", false))
		or not bool(initialized.get("ok", false))
	):
		return _failure(
			"QSDK_R24D133_FIXTURE_FAILED",
			{"context": context, "bound": source_bound, "initialized": initialized},
		)
	var raised_bound := _raised_body_bound_v1(sdk, context, source_bound)
	if not bool(raised_bound.get("ok", false)):
		return _failure("QSDK_R24D133_RAISED_SAMPLE_FAILED", raised_bound)
	var memory := _raise_body_memory_v1(initialized["memory"])
	var advanced := (
		BehaviorWorker
		. production_advance_dispatch_v1(
			sdk,
			context,
			raised_bound,
			memory,
			"candidate_command",
			"raise_body",
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
		)
	)
	if not bool(advanced.get("ok", false)):
		return _failure("QSDK_R24D133_PRODUCTION_HANDOFF_FAILED", advanced)

	var step: Dictionary = advanced["step_receipt"]
	var control: Dictionary = advanced["control_receipt"]
	var progression: Dictionary = advanced["development_progression_receipt"]
	var authority: Dictionary = advanced["energy_partition_authority"]
	var binding: Dictionary = advanced["stance_observation_binding_receipt"]
	var core_request := {
		"schema_version": "sporespore_recovery_stance_control_request_v4",
		"controller_id": RouteScript.STANCE_CONTROLLER_ID,
		"collection": (advanced["collection_request"] as Dictionary).duplicate(true),
		"handoff_or_stance_step": step.duplicate(true),
		"portable_step_observation_v3":
		(raised_bound["observation_v3"] as Dictionary).duplicate(true),
		"energy_partition_authority": authority.duplicate(true),
		"development_progression": progression.duplicate(true),
	}
	var core_receipt := RecoveryRuntimeScript.plan_stance_control_v4(sdk, core_request)

	var positive_checks := {
		"r131_complete_regression_passes": bool(inherited.get("ok", false)),
		"actual_first_handoff_edge_executed":
		(
			String(step.get("prior_phase", "")) == "raise_body"
			and String(step.get("next_phase", "")) == "stance_handoff"
			and bool(step.get("transitioned", false))
			and String((step["memory"] as Dictionary).get("phase", "")) == "stance_handoff"
		),
		"r126_development_authority_used":
		(
			(
				String(progression.get("authority_profile_id", ""))
				== RouteScript.R126_ENERGY_AUTHORITY_PROFILE_ID
			)
			and not bool(progression.get("legacy_safety_gate", true))
			and bool(progression.get("development_nonenergy_safety_gate", false))
			and bool(progression.get("development_stance_handoff_gate", false))
			and bool(progression.get("development_progression_used", false))
			and not bool(progression.get("physical_result_authorized", true))
		),
		"v4_core_binding_receipt_exact":
		(
			(
				String(core_receipt.get("schema_version", ""))
				== "sporespore_recovery_stance_control_receipt_v2"
			)
			and core_receipt.get("control_receipt") is Dictionary
			and core_receipt.get("observation_binding") is Dictionary
			and bool(
				(core_receipt["observation_binding"] as Dictionary).get(
					"development_handoff_authorized", false
				)
			)
		),
		"route_recomputes_complete_binding":
		(
			RouteScript
			. stance_observation_binding_receipt_valid_v1(
				sdk,
				core_receipt,
				advanced["collection_request"],
				step,
				raised_bound["observation_v3"],
				authority,
				progression,
			)
		),
		"production_consumer_accepts_bound_handoff":
		BehaviorWorker.production_advance_receipt_valid_v1(
			advanced, RouteScript.RECOVERY_CONTROLLER_V6_ID, sdk
		),
		"retained_binding_matches_planned_control":
		(
			String(control.get("owner", "")) == "stance"
			and (
				String(control.get("observation_sha256", ""))
				== String(binding.get("portable_step_observation_v3_sha256", ""))
			)
			and (
				String(step.get("observation_sha256", ""))
				== String(binding.get("portable_step_observation_v3_sha256", ""))
			)
			and bool(binding.get("source_bound_v2_collection_validated", false))
			and bool(binding.get("cross_representation_base_binding_validated", false))
			and bool(binding.get("development_progression_validated", false))
		),
	}

	var forced_failure_checks := {}
	var missing_binding := advanced.duplicate(true)
	missing_binding.erase("stance_observation_binding_receipt")
	forced_failure_checks["missing_binding_rejected"] = _consumer_rejects(sdk, missing_binding)
	for field in [
		"portable_step_observation_v3_sha256",
		"collection_observation_v2_sha256",
		"shared_observation_base_sha256",
		"observation_source_binding_sha256",
		"energy_partition_authority_sha256",
		"development_progression_receipt_sha256",
	]:
		var mutated := advanced.duplicate(true)
		(mutated["stance_observation_binding_receipt"] as Dictionary)[field] = ("sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
		forced_failure_checks["mutated_%s_rejected" % field] = _consumer_rejects(sdk, mutated)
	var mutated_development_authority := advanced.duplicate(true)
	(mutated_development_authority["stance_observation_binding_receipt"] as Dictionary)["development_handoff_authorized"] = false
	forced_failure_checks["mutated_development_authority_rejected"] = _consumer_rejects(
		sdk, mutated_development_authority
	)

	var wrong_step_digest := core_request.duplicate(true)
	(wrong_step_digest["handoff_or_stance_step"] as Dictionary)["observation_sha256"] = (String(
		binding.get("collection_observation_v2_sha256", "")
	))
	forced_failure_checks["core_wrong_step_digest_rejected"] = _core_rejects(sdk, wrong_step_digest)
	var wrong_projection := core_request.duplicate(true)
	var wrong_projection_observation: Dictionary = wrong_projection["portable_step_observation_v3"]
	wrong_projection_observation["semantic_step"] = SEMANTIC_STEP + 1
	(wrong_projection["handoff_or_stance_step"] as Dictionary)["observation_sha256"] = (
		RouteScript._sha256(sdk, wrong_projection_observation)
	)
	forced_failure_checks["core_cross_projection_rejected"] = _core_rejects(sdk, wrong_projection)
	var wrong_progression := core_request.duplicate(true)
	(wrong_progression["development_progression"] as Dictionary)["development_progression_used"] = false
	forced_failure_checks["core_progression_mutation_rejected"] = _core_rejects(
		sdk, wrong_progression
	)
	var wrong_authority := core_request.duplicate(true)
	(wrong_authority["energy_partition_authority"] as Dictionary)["authority_source_sha256"] = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	forced_failure_checks["core_authority_mutation_rejected"] = _core_rejects(sdk, wrong_authority)
	var unknown_field := core_request.duplicate(true)
	unknown_field["silent_projection_relabel"] = true
	forced_failure_checks["core_unknown_field_rejected"] = _core_rejects(sdk, unknown_field)

	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d133_godot_stance_observation_binding_zero_world_v1",
		"gate_id": "QSDK-R24D133",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "repeatable_first_handoff_binding_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D133_ZERO_WORLD_CONJUNCTION_INVALID",
		"first_handoff_prior_phase": String(step.get("prior_phase", "")),
		"first_handoff_next_phase": String(step.get("next_phase", "")),
		"development_progression_used":
		bool(progression.get("development_progression_used", false)),
		"binding_schema": String(binding.get("schema_version", "")),
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"native_runtime_observation_collection_executed": false,
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


static func _raised_body_bound_v1(
	sdk: Object,
	context: Dictionary,
	source_bound: Dictionary,
) -> Dictionary:
	var observation_base: Dictionary = (source_bound["observation_v3"] as Dictionary).duplicate(
		true
	)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	observation_base["semantic_step"] = SEMANTIC_STEP
	var state: Dictionary = observation_base["state"]
	state["semantic_step"] = SEMANTIC_STEP
	state["sample_time_s"] = float(SEMANTIC_STEP) * RouteScript.OUTER_STEP_DURATION_S
	(state["base_pose_world"] as Dictionary)["position_m"] = {"x": 0.0, "y": 0.375, "z": 0.0}
	(observation_base["center_of_mass"] as Dictionary)["position_world_m"] = {
		"x": 0.0, "y": 0.375, "z": 0.0
	}
	for foot_value in observation_base["ordered_foot_bearing_observations"]:
		var foot: Dictionary = foot_value
		foot["bearing_normal_impulse_ns"] = 0.125
	for body_value in observation_base["ordered_body_clearance_observations"]:
		var body: Dictionary = body_value
		body["nonfoot_contact_present"] = false
		body["ventral_surface_contact"] = false
		body["accumulated_nonfoot_normal_impulse_ns"] = 0.0
		body["minimum_nonfoot_clearance_m"] = 0.0625
		body["engine_contact_ids"] = []
	(observation_base["applied_actuation"] as Dictionary)["source_semantic_step"] = (SEMANTIC_STEP)
	var engine_step: Dictionary = observation_base["engine_step_identity"]
	var source_trace := {
		"schema_version": "sporespore_qsdk_r24d133_zero_world_source_trace_v1",
		"semantic_step": SEMANTIC_STEP,
		"host_step_before": SEMANTIC_STEP - 1,
		"host_step_after": SEMANTIC_STEP,
		"synthetic_zero_world_fixture": true,
	}
	engine_step["source_trace_sha256"] = RouteScript._sha256(sdk, source_trace)
	engine_step["semantic_step"] = SEMANTIC_STEP
	engine_step["host_step_before"] = SEMANTIC_STEP - 1
	engine_step["host_step_after"] = SEMANTIC_STEP
	var energy_source_receipt := {
		"schema_version": "sporespore_qsdk_r24d133_godot_energy_source_receipt_v1",
		"semantic_step": SEMANTIC_STEP,
		"initial_mechanical_energy_j": 20.0,
		"current_mechanical_energy_j": 21.0,
		"cumulative_applied_actuator_work_j": 0.0,
		"cumulative_signed_external_work_j": 0.0,
		"cumulative_signed_constraint_exchange_j": 0.0,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"cumulative_passive_dissipation_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	var component_receipts := {
		"schema_version": "sporespore_qsdk_r24d133_source_component_receipts_v1",
		"semantic_step": SEMANTIC_STEP,
		"source_trace": source_trace,
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	return RouteScript.compose_observations_v1(
		sdk, context, observation_base, energy_source_receipt, component_receipts
	)


static func _raise_body_memory_v1(initial_memory: Dictionary) -> Dictionary:
	var memory := initial_memory.duplicate(true)
	memory["phase"] = "raise_body"
	memory["ordered_completed_phases"] = ["confirm_prone", "establish_distal_support"]
	memory["start_semantic_step"] = 0
	memory["last_semantic_step"] = SEMANTIC_STEP - 1
	memory["total_steps_observed"] = SEMANTIC_STEP
	memory["phase_steps_observed"] = 0
	memory["prone_confirm_steps_observed"] = 12
	memory["stance_dwell_steps_observed"] = 0
	memory["initial_center_of_mass_height_m"] = 0.125
	memory["terminal_failure_code"] = null
	return memory


static func _consumer_rejects(sdk: Object, value: Dictionary) -> bool:
	return not BehaviorWorker.production_advance_receipt_valid_v1(
		value, RouteScript.RECOVERY_CONTROLLER_V6_ID, sdk
	)


static func _core_rejects(sdk: Object, request: Dictionary) -> bool:
	var result := RecoveryRuntimeScript.plan_stance_control_v4(sdk, request)
	return (
		not bool(result.get("ok", true))
		and int(result.get("world_build_count", 0)) == 0
		and int(result.get("solver_step_count", 0)) == 0
		and not bool(result.get("physics_state_modified", false))
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d133_godot_stance_observation_binding_zero_world_v1",
		"gate_id": "QSDK-R24D133",
		"ok": false,
		"failure_code": code,
		"detail": detail,
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
