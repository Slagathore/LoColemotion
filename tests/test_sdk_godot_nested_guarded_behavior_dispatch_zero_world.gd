extends SceneTree
# gdlint: disable=max-line-length

## R98 pure-data coverage for the production behavior worker's actuator-mode
## dispatch receipt. It calls the same validation seam used during a behavior
## world, but creates no Node, RID, model, world, native write, or solver step.

const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const NativeWorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "SPORESPORE_GODOT_NESTED_GUARDED_BEHAVIOR_DISPATCH_ZERO_WORLD "


func _initialize() -> void:
	var result := _run()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var nested := _nested_active_receipt()
	var zero := _no_actuation_receipt()
	var legacy := _legacy_active_receipt()
	var force_based := _force_based_active_receipt()
	var positives := [
		BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
			nested,
			false,
		),
		BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
			zero,
			true,
		),
		BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED,
			force_based,
			false,
		),
		BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_LEGACY,
			legacy,
			false,
		),
	]
	if positives.has(false):
		return _failure("POSITIVE_RECEIPT_REJECTED", {"positive_results": positives})
	if (
		BehaviorWorker.actuator_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED
		)
		!= NativeWorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		or BehaviorWorker.work_mapping_id_for_mode_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED
		)
		!= NativeWorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
	):
		return _failure("NESTED_MAPPING_SELECTION_INVALID")

	var mutations: Array = []
	var wrong_mapping := nested.duplicate(true)
	wrong_mapping["actuator_mapping_id"] = "mutated"
	mutations.append(wrong_mapping)
	var missing_nested_flag := nested.duplicate(true)
	missing_nested_flag["native_angular_velocity_nested_projection_required"] = false
	mutations.append(missing_nested_flag)
	var unseparated_target := nested.duplicate(true)
	unseparated_target["projection_target_separated_from_native_readback_guard"] = false
	mutations.append(unseparated_target)
	var outside_guard := nested.duplicate(true)
	outside_guard["all_immediate_native_readbacks_inside_guard"] = false
	mutations.append(outside_guard)
	var short_readback := nested.duplicate(true)
	short_readback["native_angular_velocity_total_readback_count"] = 24
	mutations.append(short_readback)
	var invalid_scale := nested.duplicate(true)
	invalid_scale["native_angular_velocity_guard_minimum_applied_scale"] = 1.01
	mutations.append(invalid_scale)
	var zero_with_impulse := zero.duplicate(true)
	zero_with_impulse["body_impulse_write_count"] = 1
	if BehaviorWorker.behavior_application_receipt_valid_v2(
		BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
		zero_with_impulse,
		true,
	):
		return _failure("NO_ACTUATION_MUTATION_ACCEPTED")
	for index in mutations.size():
		if BehaviorWorker.behavior_application_receipt_valid_v2(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
			mutations[index],
			false,
		):
			return _failure("ACTIVE_MUTATION_ACCEPTED:%d" % index)

	return {
		"schema_version": "sporespore_godot_nested_guarded_behavior_dispatch_zero_world_v1",
		"gate_id": "QSDK-R24D98",
		"ok": true,
		"positive_case_count": 4,
		"forced_failure_case_count": 7,
		"nested_active_positive_count": 1,
		"nested_no_actuation_positive_count": 1,
		"legacy_compatibility_positive_count": 2,
		"production_validation_seam_invoked": true,
		"nested_mapping_selection_verified": true,
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


static func _nested_active_receipt() -> Dictionary:
	return {
		"actuator_mapping_id": NativeWorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": NativeWorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID,
		"validated_command_count": 8,
		"host_write_count": 16,
		"host_readback_count": 8,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"body_impulse_write_count": 16,
		"native_angular_velocity_guard_required": true,
		"native_angular_velocity_nested_projection_required": true,
		"projection_target_separated_from_native_readback_guard": true,
		"all_immediate_native_readbacks_inside_guard": true,
		"native_angular_velocity_guard_limit_projection": {"ok": true},
		"native_angular_velocity_inner_projection_target": {"ok": true},
		"native_angular_velocity_initial_readback_count": 9,
		"native_angular_velocity_post_application_readback_count": 16,
		"native_angular_velocity_total_readback_count": 25,
		"native_angular_velocity_guard_engagement_count": 4,
		"native_angular_velocity_guard_minimum_applied_scale": 0.5,
		"physics_state_modified": true,
	}


static func _no_actuation_receipt() -> Dictionary:
	return {
		"actuator_mapping_id": "",
		"work_mapping_id": "",
		"host_write_count": 8,
		"host_readback_count": 8,
		"motor_enabled_count": 0,
		"body_impulse_write_count": 0,
	}


static func _force_based_active_receipt() -> Dictionary:
	return {
		"actuator_mapping_id": NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": NativeWorldScript.FORCE_BASED_WORK_MAPPING_ID,
		"host_write_count": 16,
		"host_readback_count": 8,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"body_impulse_write_count": 16,
		"physics_state_modified": true,
	}


static func _legacy_active_receipt() -> Dictionary:
	return {
		"actuator_mapping_id": "",
		"host_write_count": 8,
		"host_readback_count": 8,
		"motor_enabled_count": 8,
		"body_impulse_write_count": 0,
		"physics_state_modified": true,
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_godot_nested_guarded_behavior_dispatch_zero_world_failure_v1",
		"gate_id": "QSDK-R24D98",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
