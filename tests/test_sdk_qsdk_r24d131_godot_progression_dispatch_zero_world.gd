extends SceneTree
# gdlint: disable=max-line-length

## R131 calls the exact production advancement selector without constructing a
## world. It proves V6 selects the qualified R126 progression route, historical
## V5 retains legacy advancement, every V6 step carries a progression receipt,
## and missing or cross-version route evidence fails closed.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const R129Test := preload(
	"res://tests/test_sdk_qsdk_r24d129_godot_solver_coupled_application_mutation_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D131_PROGRESSION_DISPATCH_ZERO_WORLD "


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var inherited := R129Test._evaluate()
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D131_EXTENSION_UNAVAILABLE", inherited)
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D131_EXTENSION_INSTANTIATION_FAILED", inherited)

	var v6_context := RouteScript.prepare_context_v6(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var v6_bound := RouteScript.zero_world_fixture_v6(sdk, v6_context)
	var v6_initialized := RouteScript.initialize_behavior_arm_v1(
		sdk, v6_context, "candidate_command"
	)
	if not _fixture_ready(v6_context, v6_bound, v6_initialized):
		return _failure(
			"QSDK_R24D131_V6_FIXTURE_FAILED",
			{"context": v6_context, "bound": v6_bound, "initialized": v6_initialized},
		)
	var v6_advanced := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		v6_context,
		v6_bound,
		v6_initialized["memory"],
		"candidate_command",
		"confirm_prone",
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
	)
	if not bool(v6_advanced.get("ok", false)):
		return _failure("QSDK_R24D131_V6_DISPATCH_FAILED", v6_advanced)

	var v5_context := RouteScript.prepare_context_v5(
		sdk, RouteScript.RECOVERY_CONTROLLER_V5_ID
	)
	var v5_bound := RouteScript.zero_world_fixture_v5(sdk, v5_context)
	var v5_initialized := RouteScript.initialize_behavior_arm_v1(
		sdk, v5_context, "candidate_command"
	)
	if not _fixture_ready(v5_context, v5_bound, v5_initialized):
		return _failure(
			"QSDK_R24D131_V5_FIXTURE_FAILED",
			{"context": v5_context, "bound": v5_bound, "initialized": v5_initialized},
		)
	var v5_advanced := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		v5_context,
		v5_bound,
		v5_initialized["memory"],
		"candidate_command",
		"confirm_prone",
		RouteScript.RECOVERY_CONTROLLER_V5_ID,
	)

	var mutated_dispatch := v6_advanced.duplicate(true)
	mutated_dispatch["production_advance_dispatch_id"] = "mutated_dispatch"
	var mutated_route := v6_advanced.duplicate(true)
	mutated_route["selected_portable_advance_route"] = "legacy_recovery_v4"
	var missing_progression := v6_advanced.duplicate(true)
	missing_progression.erase("development_progression_receipt")
	var mutated_authority := v6_advanced.duplicate(true)
	(mutated_authority["development_progression_receipt"] as Dictionary)[
		"authority_profile_id"
	] = "mutated_authority"
	var mutated_used := v6_advanced.duplicate(true)
	(mutated_used["development_progression_receipt"] as Dictionary)[
		"development_progression_used"
	] = true
	var wrong_context_dispatch := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		v6_context,
		v6_bound,
		v6_initialized["memory"],
		"candidate_command",
		"confirm_prone",
		RouteScript.RECOVERY_CONTROLLER_V5_ID,
	)
	var v6_progression: Dictionary = v6_advanced["development_progression_receipt"]

	var positive_checks := {
		"r129_complete_regression_passes": bool(inherited.get("ok", false)),
		"v6_dispatch_selects_r126_progression": (
			String(v6_advanced.get("production_advance_dispatch_id", ""))
			== BehaviorWorker.R131_PRODUCTION_ADVANCE_DISPATCH_ID
			and String(v6_advanced.get("selected_portable_advance_route", ""))
			== "r126_development_progression_v5"
			and bool(v6_advanced.get("development_progression_required", false))
			and String(v6_advanced.get("schema_version", ""))
			== RouteScript.R126_DEVELOPMENT_ROUTE_ID
		),
		"production_consumer_accepts_v6_dispatch": (
			BehaviorWorker.production_advance_receipt_valid_v1(
				v6_advanced, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"v6_progression_receipt_exact": (
			BehaviorWorker.development_progression_receipt_valid_v1(
				v6_progression, v6_advanced["step_receipt"]
			)
			and not bool(v6_progression.get("development_progression_used", true))
			and not bool(v6_progression.get("physical_result_authorized", true))
		),
		"v6_progression_population_exact": (
			BehaviorWorker.development_progression_population_valid_v1(
				[v6_progression], 1, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"historical_v5_dispatch_remains_legacy": (
			bool(v5_advanced.get("ok", false))
			and String(v5_advanced.get("selected_portable_advance_route", ""))
			== "legacy_recovery_v4"
			and not bool(v5_advanced.get("development_progression_required", true))
			and BehaviorWorker.production_advance_receipt_valid_v1(
				v5_advanced, RouteScript.RECOVERY_CONTROLLER_V5_ID
			)
		),
	}
	var forced_failure_checks := {
		"wrong_controller_context_rejected": not bool(
			wrong_context_dispatch.get("ok", true)
		),
		"mutated_dispatch_identity_rejected": not (
			BehaviorWorker.production_advance_receipt_valid_v1(
				mutated_dispatch, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"mutated_route_selection_rejected": not (
			BehaviorWorker.production_advance_receipt_valid_v1(
				mutated_route, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"missing_progression_receipt_rejected": not (
			BehaviorWorker.production_advance_receipt_valid_v1(
				missing_progression, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"mutated_authority_rejected": not (
			BehaviorWorker.production_advance_receipt_valid_v1(
				mutated_authority, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"mutated_progression_use_rejected": not (
			BehaviorWorker.production_advance_receipt_valid_v1(
				mutated_used, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"missing_progression_population_rejected": not (
			BehaviorWorker.development_progression_population_valid_v1(
				[], 1, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d131_godot_progression_dispatch_zero_world_v1",
		"gate_id": "QSDK-R24D131",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_production_progression_dispatch_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D131_ZERO_WORLD_CONJUNCTION_INVALID",
		"production_advance_dispatch_id": BehaviorWorker.R131_PRODUCTION_ADVANCE_DISPATCH_ID,
		"selected_v6_portable_advance_route": String(
			v6_advanced.get("selected_portable_advance_route", "")
		),
		"progression_schema": String(v6_progression.get("schema_version", "")),
		"authority_profile_id": String(v6_progression.get("authority_profile_id", "")),
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
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


static func _fixture_ready(
	context: Dictionary,
	bound: Dictionary,
	initialized: Dictionary,
) -> bool:
	return (
		bool(context.get("ok", false))
		and bool(bound.get("ok", false))
		and bool(initialized.get("ok", false))
		and initialized.get("memory") is Dictionary
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d131_godot_progression_dispatch_zero_world_v1",
		"gate_id": "QSDK-R24D131",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 6,
		"forced_failure_case_count": 7,
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
