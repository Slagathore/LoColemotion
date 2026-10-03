extends SceneTree
# gdlint: disable=max-line-length

## R140 executes the exact production context call that R139 only parsed. It
## instantiates the SDK extension but creates no model, Node, RID, world, or
## solver step. Local mutations prove the retained projection fails closed.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const ProfileScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D140_GODOT_JOLT_V5_PROFILE_POSITION_SOLVER_ROUTE_ZERO_WORLD "
const RUNTIME_BINARY_PROFILE_ID := (
	"godot_4_7_jolt_sporespore_solver_energy_position_velocity_read_access_v5"
)
const ROUTE_PROFILE_ID := (
	"godot_jolt_r24d140_v5_complete_energy_position_solver_two_step_route_v1"
)
const EXPECTED_CONSOLE_RAW_SHA256 := (
	"8e07937dcbccf5f71356df5ac487616eb1f66025d37d73d770f82ffa47a578a0"
)
const EXPECTED_ENGINE_RAW_SHA256 := (
	"fc8f7d0bece7c1d90d16ceb28d6f4ee8b3cd43facafa3494d51c8753a3bdd72b"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D140_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D140_SDK_INSTANTIATION_FAILED")

	var context := RouteScript.prepare_complete_energy_context_v2(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D140_COMPLETE_ENERGY_CONTEXT_FAILED", context)

	var positive_checks := {
		"actual_complete_energy_context_call": bool(context.get("ok", false)),
		"exact_v5_binary_binding": _runtime_projection_valid_v1(context),
		"complete_energy_context_projection": _context_projection_valid_v1(context),
		"zero_physics_boundary": _zero_physics_projection_valid_v1(context),
	}

	var wrong_controller := RouteScript.prepare_complete_energy_context_v2(
		sdk, RouteScript.RECOVERY_CONTROLLER_V5_ID
	)
	var hash_mutation := context.duplicate(true)
	var hash_receipt: Dictionary = hash_mutation["runtime_profile_receipt"]
	var hash_runtime: Dictionary = hash_receipt["runtime_identity"]
	var hash_console: Dictionary = hash_runtime["console_binary"]
	hash_console["raw_sha256"] = "mutated"
	var route_mutation := context.duplicate(true)
	route_mutation["energy_route_id"] = "mutated"
	var world_mutation := context.duplicate(true)
	world_mutation["world_build_count"] = 1
	var selection_mutation := context.duplicate(true)
	var selection_receipt: Dictionary = selection_mutation["runtime_profile_receipt"]
	selection_receipt["instrumented_profile_selected"] = false

	var forced_failure_checks := {
		"wrong_controller_refused": (
			not bool(wrong_controller.get("ok", true))
			and String(wrong_controller.get("failure_code", ""))
			== "QSDK_R24D137_CONTROLLER_ID_INVALID"
		),
		"mutated_console_hash_refused": not _context_projection_valid_v1(hash_mutation),
		"mutated_energy_route_refused": not _context_projection_valid_v1(route_mutation),
		"nonzero_world_count_refused": not _context_projection_valid_v1(world_mutation),
		"deselected_profile_refused": not _context_projection_valid_v1(selection_mutation),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	var receipt: Dictionary = context["runtime_profile_receipt"]
	var runtime: Dictionary = receipt["runtime_identity"]
	return {
		"schema_version": "sporespore_qsdk_r24d140_godot_jolt_v5_profile_position_solver_route_zero_world_v1",
		"gate_id": "QSDK-R24D140",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_v5_context_and_two_step_route_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D140_ZERO_WORLD_CONJUNCTION_INVALID",
		"question_class": "development",
		"runtime_binary_profile_id": RUNTIME_BINARY_PROFILE_ID,
		"telemetry_profile_id": ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"route_profile_id": ROUTE_PROFILE_ID,
		"inner_console_raw_sha256": runtime["console_binary"]["raw_sha256"],
		"inner_engine_raw_sha256": runtime["engine_binary"]["raw_sha256"],
		"context_construction_passed": positive_checks["actual_complete_energy_context_call"],
		"exact_v5_binary_binding_passed": positive_checks["exact_v5_binary_binding"],
		"complete_energy_context_projection_passed": positive_checks[
			"complete_energy_context_projection"
		],
		"zero_physics_boundary_passed": positive_checks["zero_physics_boundary"],
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"sdk_instance_count": 1,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _runtime_projection_valid_v1(context: Dictionary) -> bool:
	var receipt: Dictionary = context.get("runtime_profile_receipt", {})
	var runtime: Dictionary = receipt.get("runtime_identity", {})
	var console: Dictionary = runtime.get("console_binary", {})
	var engine: Dictionary = runtime.get("engine_binary", {})
	var validation: Dictionary = receipt.get("validation", {})
	return (
		bool(receipt.get("instrumented_profile_selected", false))
		and String(receipt.get("profile_id", ""))
		== ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		and bool(runtime.get("exact_binary_pair_match", false))
		and bool(runtime.get("instrumented_profile_selected", false))
		and bool(runtime.get("complete_energy_profile_selected", false))
		and bool(runtime.get("motor_telemetry_method_registered", false))
		and bool(runtime.get("solved_contact_telemetry_method_registered", false))
		and bool(runtime.get("solver_energy_exchange_telemetry_method_registered", false))
		and String(runtime.get("selected_profile_id", ""))
		== ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		and String(console.get("raw_sha256", "")) == EXPECTED_CONSOLE_RAW_SHA256
		and int(console.get("byte_length", -1)) == 293376
		and String(engine.get("raw_sha256", "")) == EXPECTED_ENGINE_RAW_SHA256
		and int(engine.get("byte_length", -1)) == 188854272
		and bool(validation.get("ok", false))
		and bool(validation.get("complete_energy_profile_selected", false))
		and int(validation.get("supported_channel_count", -1)) == 10
	)


static func _context_projection_valid_v1(context: Dictionary) -> bool:
	var compiled: Dictionary = context.get("compiled_recovery_morphology", {})
	var realization: Dictionary = context.get("actuation_realization", {})
	return (
		bool(context.get("ok", false))
		and String(context.get("schema_version", ""))
		== "sporespore_qsdk_r24d137_godot_complete_energy_recovery_route_context_v2"
		and String(context.get("recovery_controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V6_ID
		and bool(context.get("complete_energy_profile_selected", false))
		and String(context.get("energy_route_id", ""))
		== RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
		and String(context.get("energy_mapping_profile_id", ""))
		== RouteScript.R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(context.get("required_active_actuator_mapping_id", ""))
		== RouteScript.R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		and String(context.get("required_active_work_mapping_id", ""))
		== RouteScript.R136_REQUIRED_ACTIVE_WORK_MAPPING_ID
		and bool(context.get("native_joint_motors_must_be_disabled", false))
		and not bool(context.get("continuous_collision_detection_permitted", true))
		and bool(context.get("body_damping_must_be_replace_mode_zero", false))
		and String(compiled.get("support_status", "")) == "supported_exact"
		and not bool(context.get("portable_controller_changed", true))
		and String(realization.get("actuation_realization_id", ""))
		== RouteScript.R137_COMPLETE_ENERGY_ACTUATION_REALIZATION_ID
		and bool(realization.get("native_joint_motors_disabled", false))
		and bool(realization.get("pre_solver_direct_body_impulse_realization", false))
		and _runtime_projection_valid_v1(context)
		and _zero_physics_projection_valid_v1(context)
	)


static func _zero_physics_projection_valid_v1(context: Dictionary) -> bool:
	var receipt: Dictionary = context.get("runtime_profile_receipt", {})
	var runtime: Dictionary = receipt.get("runtime_identity", {})
	for value in [context, receipt, runtime]:
		if (
			int(value.get("model_construction_count", -1)) != 0
			or int(value.get("world_attempt_count", -1)) != 0
			or int(value.get("world_build_count", -1)) != 0
			or int(value.get("solver_step_count", -1)) != 0
			or bool(value.get("physics_state_modified", true))
		):
			return false
	return (
		not bool(context.get("physical_acceptance_authority", true))
		and not bool(context.get("release_authority", true))
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d140_godot_jolt_v5_profile_position_solver_route_zero_world_v1",
		"gate_id": "QSDK-R24D140",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 4,
		"forced_failure_case_count": 5,
		"sdk_instance_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
