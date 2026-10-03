extends SceneTree
# gdlint: disable=max-line-length

## Compact R134 check of the real production evaluator selector. Shared worker
## mechanics create the smallest paired route fixture that constructs, replays,
## finalizes, and validates both arms without opening a world or solver step.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D134_EVALUATOR_DISPATCH_ZERO_WORLD "


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D134_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D134_EXTENSION_INSTANTIATION_FAILED")

	var v6 := _route_fixture(sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID)
	var v5 := _route_fixture(sdk, RouteScript.RECOVERY_CONTROLLER_V5_ID)
	if not bool(v6.get("ok", false)) or not bool(v5.get("ok", false)):
		return _failure("QSDK_R24D134_ROUTE_FIXTURE_FAILED", {"v6": v6, "v5": v5})
	var v6_evaluated := BehaviorWorker.production_evaluation_dispatch_v1(
		sdk,
		v6["context"],
		v6["candidate_trace"],
		v6["matched_zero_trace"],
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
	)
	var v5_evaluated := BehaviorWorker.production_evaluation_dispatch_v1(
		sdk,
		v5["context"],
		v5["candidate_trace"],
		v5["matched_zero_trace"],
		RouteScript.RECOVERY_CONTROLLER_V5_ID,
	)
	if not bool(v6_evaluated.get("ok", false)) or not bool(v5_evaluated.get("ok", false)):
		return _failure(
			"QSDK_R24D134_EVALUATION_DISPATCH_FAILED",
			{"v6": v6_evaluated, "v5": v5_evaluated},
		)

	var receipt: Dictionary = v6_evaluated["evaluation_receipt"]
	var candidate: Dictionary = receipt.get("candidate_trace", {})
	var zero: Dictionary = receipt.get("matched_zero_command_trace", {})
	var positive_checks := {
		"v6_selects_authority_bound_v5": (
			BehaviorWorker.production_evaluation_receipt_valid_v1(
				v6_evaluated, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
			and String(v6_evaluated.get("selected_portable_evaluation_route", ""))
			== "r134_development_authority_evaluation_v5"
			and _valid_sha256(
				String(v6_evaluated.get("energy_partition_authority_sha256", ""))
			)
		),
		"paired_v5_replay_is_valid_incomplete_evidence": (
			String(receipt.get("support_status", "")) == "supported_exact"
			and String(receipt.get("verdict", "")) == "physical_development_incomplete"
			and bool(receipt.get("physical_development_trace_valid", false))
			and int(candidate.get("accepted_observation_count", -1)) == 1
			and int(zero.get("accepted_observation_count", -1)) == 1
			and not bool(receipt.get("physical_result", true))
		),
		"historical_v5_controller_retains_v4": (
			BehaviorWorker.production_evaluation_receipt_valid_v1(
				v5_evaluated, RouteScript.RECOVERY_CONTROLLER_V5_ID
			)
			and String(v5_evaluated.get("selected_portable_evaluation_route", ""))
			== "legacy_recovery_evaluation_v4"
		),
		"zero_world_and_zero_authority_budget": (
			int(v6_evaluated.get("model_construction_count", -1)) == 0
			and int(v6_evaluated.get("world_attempt_count", -1)) == 0
			and int(v6_evaluated.get("world_build_count", -1)) == 0
			and int(v6_evaluated.get("solver_step_count", -1)) == 0
			and not bool(v6_evaluated.get("physics_state_modified", true))
			and not bool(v6_evaluated.get("physical_acceptance_authority", true))
			and not bool(v6_evaluated.get("release_authority", true))
		),
	}

	var wrong_context := BehaviorWorker.production_evaluation_dispatch_v1(
		sdk,
		v6["context"],
		v6["candidate_trace"],
		v6["matched_zero_trace"],
		RouteScript.RECOVERY_CONTROLLER_V5_ID,
	)
	var empty_candidate: Dictionary = (v6["candidate_trace"] as Dictionary).duplicate(true)
	empty_candidate["observations"] = []
	var empty_trace := BehaviorWorker.production_evaluation_dispatch_v1(
		sdk,
		v6["context"],
		empty_candidate,
		v6["matched_zero_trace"],
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
	)
	var mutated_dispatch := v6_evaluated.duplicate(true)
	mutated_dispatch["production_evaluation_dispatch_id"] = "mutated_dispatch"
	var missing_authority_digest := v6_evaluated.duplicate(true)
	missing_authority_digest.erase("energy_partition_authority_sha256")
	var legacy_authority_injection := v5_evaluated.duplicate(true)
	legacy_authority_injection["energy_partition_authority_sha256"] = (
		"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	)
	var forced_failure_checks := {
		"wrong_controller_context_rejected": not bool(wrong_context.get("ok", true)),
		"empty_candidate_trace_rejected": not bool(empty_trace.get("ok", true)),
		"mutated_dispatch_identity_rejected": not (
			BehaviorWorker.production_evaluation_receipt_valid_v1(
				mutated_dispatch, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"missing_v5_authority_digest_rejected": not (
			BehaviorWorker.production_evaluation_receipt_valid_v1(
				missing_authority_digest, RouteScript.RECOVERY_CONTROLLER_V6_ID
			)
		),
		"legacy_authority_injection_rejected": not (
			BehaviorWorker.production_evaluation_receipt_valid_v1(
				legacy_authority_injection, RouteScript.RECOVERY_CONTROLLER_V5_ID
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
		"schema_version": "sporespore_qsdk_r24d134_godot_evaluator_dispatch_zero_world_v1",
		"gate_id": "QSDK-R24D134",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_production_evaluator_dispatch_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D134_ZERO_WORLD_CONJUNCTION_INVALID",
		"production_evaluation_dispatch_id": (
			BehaviorWorker.R134_PRODUCTION_EVALUATION_DISPATCH_ID
		),
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


static func _route_fixture(sdk: Object, controller_id: String) -> Dictionary:
	var context := (
		RouteScript.prepare_context_v6(sdk, controller_id)
		if controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
		else RouteScript.prepare_context_v5(sdk, controller_id)
	)
	var bound := (
		RouteScript.zero_world_fixture_v6(sdk, context)
		if controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
		else RouteScript.zero_world_fixture_v5(sdk, context)
	)
	if not bool(context.get("ok", false)) or not bool(bound.get("ok", false)):
		return {"ok": false, "context": context, "bound": bound}
	var traces := BehaviorWorker.paired_zero_world_evaluation_traces_v1(sdk, bound)
	if not bool(traces.get("ok", false)):
		return traces
	traces["context"] = context
	return traces


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _valid_sha256(value: String) -> bool:
	return (
		value.length() == 71
		and value.begins_with("sha256:")
		and value.substr(7).is_valid_hex_number(false)
	)


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d134_godot_evaluator_dispatch_zero_world_v1",
		"gate_id": "QSDK-R24D134",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 4,
		"forced_failure_case_count": 5,
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
