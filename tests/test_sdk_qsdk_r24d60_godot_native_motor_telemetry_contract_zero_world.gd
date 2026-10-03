extends SceneTree
# gdlint: disable=max-line-length

## Pure R60 check of the exact telemetry validator used by the physical sampler.
## No extension object, Node, RID, model, world, or solver step is created.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D60_GODOT_NATIVE_MOTOR_TELEMETRY_ZERO_WORLD "
const ACTUATOR_ID := "front_left_hip_motor"
const CAP_NMS := 0.002
const STEP_S := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _base_telemetry() -> Dictionary:
	return {
		"schema": "sporespore.godot_jolt_hinge_motor_telemetry.v2",
		"telemetry_sequence": 1,
		"capture_space_step_sequence": 1,
		"read_space_step_sequence": 1,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"solver_step_s": STEP_S,
		"motor_state": "off",
		"target_angular_velocity_rad_s": 0.0,
		"min_torque_limit_nm": 0.0,
		"max_torque_limit_nm": 0.0,
		"signed_motor_impulse_nms": 0.0,
		"positive_motor_work_j": 0.0,
		"absorbed_motor_work_j": 0.0,
		"net_motor_work_j": 0.0,
	}


static func _case(
	id: String,
	telemetry: Variant,
	zero_command: bool = true,
	prior_sequence: int = -1,
	prior_step_s: float = NAN,
) -> Dictionary:
	return {
		"id": id,
		"telemetry": telemetry,
		"zero_command": zero_command,
		"prior_sequence": prior_sequence,
		"prior_step_s": prior_step_s,
	}


static func _evaluate() -> Dictionary:
	var zero_positive := WorldScript.native_motor_telemetry_contract_v1(
		_base_telemetry(), ACTUATOR_ID, CAP_NMS, true, -1, NAN
	)
	var active := _base_telemetry()
	active["motor_state"] = "velocity"
	active["signed_motor_impulse_nms"] = 0.001
	active["positive_motor_work_j"] = 0.0001
	active["absorbed_motor_work_j"] = 0.00002
	active["net_motor_work_j"] = 0.00008
	var active_positive := WorldScript.native_motor_telemetry_contract_v1(
		active, ACTUATOR_ID, CAP_NMS, false, -1, NAN
	)

	var mutations: Array = []
	mutations.append(_case("missing_telemetry", null))
	var value := _base_telemetry()
	value.erase("schema")
	mutations.append(_case("missing_schema", value))
	value = _base_telemetry()
	value.erase("schema")
	value["schema_version"] = "sporespore.godot_jolt_hinge_motor_telemetry.v2"
	mutations.append(_case("legacy_schema_version_only", value))
	value = _base_telemetry()
	value["schema"] = "sporespore.godot_jolt_hinge_motor_telemetry.v1"
	mutations.append(_case("wrong_schema_value", value))
	value = _base_telemetry()
	value["captured_during_active_step"] = false
	mutations.append(_case("not_captured_during_active_step", value))
	value = _base_telemetry()
	value["snapshot_is_current_space_step"] = false
	mutations.append(_case("stale_snapshot", value))
	value = _base_telemetry()
	value["capture_space_step_sequence"] = 2
	mutations.append(_case("capture_read_sequence_mismatch", value))
	value = _base_telemetry()
	value["signed_motor_impulse_nms"] = NAN
	mutations.append(_case("nonfinite_impulse", value))
	value = _base_telemetry()
	value["net_motor_work_j"] = 0.001
	mutations.append(_case("work_identity_mismatch", value))
	value = _base_telemetry()
	value["signed_motor_impulse_nms"] = 0.003
	mutations.append(_case("impulse_above_cap", value, false))
	value = _base_telemetry()
	value["signed_motor_impulse_nms"] = 0.001
	mutations.append(_case("zero_command_nonzero", value))
	mutations.append(_case("prior_actuator_sequence_mismatch", _base_telemetry(), true, 2))
	mutations.append(_case("prior_solver_step_mismatch", _base_telemetry(), true, -1, 0.01))

	var mutation_ids: Array = []
	var mutation_rejection_count := 0
	for case_value in mutations:
		var case: Dictionary = case_value
		var result := WorldScript.native_motor_telemetry_contract_v1(
			case["telemetry"],
			ACTUATOR_ID,
			CAP_NMS,
			bool(case["zero_command"]),
			int(case["prior_sequence"]),
			float(case["prior_step_s"]),
		)
		mutation_ids.append(String(case["id"]))
		mutation_rejection_count += int(not bool(result.get("ok", false)))

	var positive_control_count := int(bool(zero_positive.get("ok", false)))
	positive_control_count += int(bool(active_positive.get("ok", false)))
	var exact := (
		positive_control_count == 2
		and String(zero_positive.get("schema_version", ""))
		== "sporespore_qsdk_r24d60_godot_native_motor_telemetry_contract_v1"
		and String((zero_positive.get("telemetry", {}) as Dictionary).get("schema", ""))
		== "sporespore.godot_jolt_hinge_motor_telemetry.v2"
		and mutation_rejection_count == mutations.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d60_godot_native_motor_telemetry_zero_world_v1",
		"gate_id": "QSDK-R24D60",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D60_TELEMETRY_CONJUNCTION_INVALID",
		"positive_control_count": positive_control_count,
		"binding_schema_key_acceptance_count": int(bool(zero_positive.get("ok", false))),
		"legacy_schema_version_key_refusal_count": 1,
		"mutation_ids": mutation_ids,
		"mutation_rejection_count": mutation_rejection_count,
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
