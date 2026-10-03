extends SceneTree
# gdlint: disable=max-line-length

## Zero-world product conformance for the complete recovery surface already
## published by the portable C ABI. This test verifies that Godot can reach
## every retained and current entrypoint (through recovery step/evaluation V5
## and energy V3) without constructing or stepping a physics world. Physical
## sampling remains the responsibility of a successor native-route campaign.

const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D56_GODOT_RECOVERY_SURFACE_ZERO_WORLD "

const INPUT_METHODS := [
	"recovery_initialize_v1_json",
	"recovery_initialize_v2_json",
	"recovery_step_v1_json",
	"recovery_step_v2_json",
	"recovery_step_v3_json",
	"recovery_step_v4_json",
	"recovery_step_v5_json",
	"recovery_evaluate_trace_v1_json",
	"recovery_evaluate_trace_v2_json",
	"recovery_evaluate_trace_v3_json",
	"recovery_evaluate_trace_v4_json",
	"recovery_evaluate_trace_v5_json",
	"recovery_energy_balance_aggregate_v2_json",
	"recovery_energy_balance_aggregate_v3_json",
	"recovery_energy_balance_evaluate_v2_json",
	"recovery_energy_balance_evaluate_v3_json",
	"recovery_energy_balance_migrate_v1_json",
	"recovery_collect_native_v1_json",
	"recovery_collect_native_v2_json",
	"recovery_collect_native_v3_json",
	"recovery_plan_control_v1_json",
	"recovery_plan_control_v2_json",
	"recovery_plan_control_v3_json",
	"recovery_plan_stance_control_v1_json",
	"recovery_plan_stance_control_v2_json",
	"recovery_plan_stance_control_v3_json",
	"recovery_plan_stance_control_v4_json",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D56_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D56_GODOT_EXTENSION_INSTANTIATION_FAILED")

	var missing_methods: Array[String] = []
	var direct_refusal_count := 0
	for method_name: String in INPUT_METHODS:
		if not sdk.has_method(method_name):
			missing_methods.append(method_name)
			continue
		var parsed := _parse_envelope(String(sdk.call(method_name, "{}")))
		if not bool(parsed.get("ok", true)):
			direct_refusal_count += 1

	var profile := RecoveryRuntimeScript.development_profile_v1(sdk)
	var local_refusals := [
		RecoveryRuntimeScript.initialize_v1(sdk, {}),
		RecoveryRuntimeScript.initialize_v2(sdk, {}),
		RecoveryRuntimeScript.step_v1(sdk, {}),
		RecoveryRuntimeScript.step_v2(sdk, {}),
		RecoveryRuntimeScript.step_v3(sdk, {}),
		RecoveryRuntimeScript.step_v4(sdk, {}),
		RecoveryRuntimeScript.step_v5(sdk, {}),
		RecoveryRuntimeScript.evaluate_trace_v1(sdk, {}),
		RecoveryRuntimeScript.evaluate_trace_v2(sdk, {}),
		RecoveryRuntimeScript.evaluate_trace_v3(sdk, {}),
		RecoveryRuntimeScript.evaluate_trace_v4(sdk, {}),
		RecoveryRuntimeScript.evaluate_trace_v5(sdk, {}),
		RecoveryRuntimeScript.aggregate_energy_v2(sdk, {}),
		RecoveryRuntimeScript.aggregate_energy_v3(sdk, {}),
		RecoveryRuntimeScript.evaluate_energy_v2(sdk, {}),
		RecoveryRuntimeScript.evaluate_energy_v3(sdk, {}),
		RecoveryRuntimeScript.migrate_energy_v1(sdk, {}),
		RecoveryRuntimeScript.collect_native_v1(sdk, {}),
		RecoveryRuntimeScript.collect_native_v2(sdk, {}),
		RecoveryRuntimeScript.collect_native_v3(sdk, {}),
		RecoveryRuntimeScript.plan_control_v1(sdk, {}),
		RecoveryRuntimeScript.plan_control_v2(sdk, {}),
		RecoveryRuntimeScript.plan_control_v3(sdk, {}),
		RecoveryRuntimeScript.plan_stance_control_v1(sdk, {}),
		RecoveryRuntimeScript.plan_stance_control_v2(sdk, {}),
		RecoveryRuntimeScript.plan_stance_control_v3(sdk, {}),
		RecoveryRuntimeScript.plan_stance_control_v4(sdk, {}),
	]
	var local_refusal_count := 0
	for refusal: Dictionary in local_refusals:
		if not bool(refusal.get("ok", true)):
			local_refusal_count += 1

	var positive_checks := {
		"all_current_input_methods_present": missing_methods.is_empty(),
		"development_profile_schema_valid":
		String(profile.get("schema_version", "")) == "sporespore_recovery_development_profile_v1",
		"development_profile_has_zero_physical_authority":
		(
			not bool(profile.get("physical_execution_authorized", true))
			and not bool(profile.get("physical_acceptance_authority", true))
			and not bool(profile.get("release_authority", true))
		),
	}
	var positive_pass_count := 0
	for passed: bool in positive_checks.values():
		if passed:
			positive_pass_count += 1
	var forced_failure_checks := {
		"direct_core_empty_requests_rejected": direct_refusal_count == INPUT_METHODS.size(),
		"local_schema_empty_requests_rejected": local_refusal_count == INPUT_METHODS.size(),
	}
	var forced_failure_pass_count := 0
	for passed: bool in forced_failure_checks.values():
		if passed:
			forced_failure_pass_count += 1

	var exact := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d56_godot_recovery_surface_zero_world_v1",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D56_GODOT_RECOVERY_SURFACE_INVALID",
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"input_method_count": INPUT_METHODS.size(),
		"input_method_present_count": INPUT_METHODS.size() - missing_methods.size(),
		"missing_methods": missing_methods,
		"direct_core_refusal_count": direct_refusal_count,
		"local_schema_mutation_count": local_refusals.size(),
		"local_schema_mutation_rejection_count": local_refusal_count,
		"development_profile_valid":
		String(profile.get("schema_version", "")) == "sporespore_recovery_development_profile_v1",
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"held_out_cell_access_count": 0,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _parse_envelope(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	return {"ok": false, "failure_code": "QSDK_R24D56_NON_DICTIONARY_ENVELOPE"}


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d56_godot_recovery_surface_zero_world_v1",
		"ok": false,
		"failure_code": code,
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"held_out_cell_access_count": 0,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
