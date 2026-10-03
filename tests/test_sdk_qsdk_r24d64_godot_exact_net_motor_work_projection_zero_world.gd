extends SceneTree
# gdlint: disable=max-line-length

## Pure controls for the R64 native-float32 to public-binary64 net-work
## projection. No extension object, Node, RID, model, world, or solver step is
## created; the exact production projection and unchanged R63 validator run.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D64_GODOT_EXACT_NET_WORK_PROJECTION_ZERO_WORLD "
const ACTUATOR_ID := "front_left_hip_motor"
const CAP_NMS := 0.01
const R63_POSITIVE_WORK_J := 0.0034130068961530924
const R63_ABSORBED_WORK_J := 0.000029909930162830278
const PROJECTION_SCHEMA := (
	"sporespore_qsdk_r24d64_godot_native_net_motor_work_projection_v1"
)
const PROJECTION_FAILURE_SCHEMA := (
	"sporespore_qsdk_r24d64_godot_native_net_motor_work_projection_failure_v1"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _f32_subtract(left: float, right: float) -> float:
	var operands := PackedFloat32Array([left, right])
	var result := PackedFloat32Array([float(operands[0]) - float(operands[1])])
	return float(result[0])


static func _telemetry(positive_work: float, absorbed_work: float, native_net: float) -> Dictionary:
	return {
		"schema": "sporespore.godot_jolt_hinge_motor_telemetry.v2",
		"telemetry_sequence": 2,
		"capture_space_step_sequence": 2,
		"read_space_step_sequence": 2,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"solver_step_s": 1.0 / 120.0,
		"motor_state": "velocity",
		"target_angular_velocity_rad_s": -1.0,
		"min_torque_limit_nm": -6.0,
		"max_torque_limit_nm": 6.0,
		"signed_motor_impulse_nms": -0.004,
		"positive_motor_work_j": positive_work,
		"absorbed_motor_work_j": absorbed_work,
		"net_motor_work_j": native_net,
	}


static func _projection_exact(telemetry: Dictionary) -> Dictionary:
	var projection := WorldScript.native_motor_work_projection_v1(
		telemetry,
		ACTUATOR_ID,
	)
	var projected_value: Variant = projection.get("telemetry")
	var projected: Dictionary = projected_value if projected_value is Dictionary else {}
	var positive := float(telemetry["positive_motor_work_j"])
	var absorbed := float(telemetry["absorbed_motor_work_j"])
	var native_net := float(telemetry["net_motor_work_j"])
	var expected_native := _f32_subtract(positive, absorbed)
	var expected_projected := positive - absorbed
	var contract := WorldScript.native_motor_telemetry_contract_v1(
		projected,
		ACTUATOR_ID,
		CAP_NMS,
		false,
		-1,
		NAN,
	)
	return {
		"ok": (
			bool(projection.get("ok", false))
			and String(projection.get("schema_version", "")) == PROJECTION_SCHEMA
			and bool(projection.get("projection_applied", false))
			and bool(projection.get("source_float32_identity_checked", false))
			and float(projection.get("native_net_motor_work_j", NAN)) == native_net
			and float(projection.get("expected_native_float32_net_motor_work_j", NAN))
			== expected_native
			and float(projection.get("projected_binary64_net_motor_work_j", NAN))
			== expected_projected
			and float(projected.get("native_net_motor_work_j", NAN)) == native_net
			and float(projected.get("net_motor_work_j", NAN)) == expected_projected
			and float(projected.get("net_motor_work_projection_delta_j", NAN))
			== native_net - expected_projected
			and String(projected.get("net_motor_work_projection_schema", ""))
			== "sporespore_qsdk_r24d64_native_float32_to_binary64_net_work_projection_v1"
			and bool(contract.get("ok", false))
			and String(contract.get("schema_version", ""))
			== "sporespore_qsdk_r24d60_godot_native_motor_telemetry_contract_v1"
			and float(contract.get("net_motor_work_j", NAN)) == expected_projected
		),
		"projection": projection,
		"contract": contract,
	}


static func _source_mismatch_rejected(telemetry: Dictionary) -> bool:
	var projection := WorldScript.native_motor_work_projection_v1(
		telemetry,
		ACTUATOR_ID,
	)
	var detail_value: Variant = projection.get("detail")
	if not (detail_value is Dictionary):
		return false
	var detail: Dictionary = detail_value
	return (
		not bool(projection.get("ok", true))
		and String(projection.get("failure_code", ""))
		== "QSDK_R24D64_WORLD_NATIVE_NET_WORK_FLOAT32_IDENTITY_INVALID:%s" % ACTUATOR_ID
		and String(detail.get("schema_version", "")) == PROJECTION_FAILURE_SCHEMA
		and String(detail.get("actuator_id", "")) == ACTUATOR_ID
		and float(detail.get("native_net_motor_work_j", NAN))
		== float(telemetry["net_motor_work_j"])
		and float(detail.get("expected_native_float32_net_motor_work_j", NAN))
		== _f32_subtract(
			float(telemetry["positive_motor_work_j"]),
			float(telemetry["absorbed_motor_work_j"]),
		)
		and int(detail.get("model_construction_count", -1)) == 0
		and int(detail.get("world_attempt_count", -1)) == 0
		and int(detail.get("world_build_count", -1)) == 0
		and int(detail.get("solver_step_count", -1)) == 0
		and not bool(detail.get("physics_state_modified", true))
	)


static func _passthrough_preserves_validator_failure(
	telemetry: Variant,
	expected_invariant: String,
) -> bool:
	var projection := WorldScript.native_motor_work_projection_v1(
		telemetry,
		ACTUATOR_ID,
	)
	var contract := WorldScript.native_motor_telemetry_contract_v1(
		projection.get("telemetry"),
		ACTUATOR_ID,
		CAP_NMS,
		false,
		-1,
		NAN,
	)
	var detail_value: Variant = contract.get("detail")
	return (
		bool(projection.get("ok", false))
		and not bool(projection.get("projection_applied", true))
		and not bool(projection.get("source_float32_identity_checked", true))
		and not bool(contract.get("ok", true))
		and detail_value is Dictionary
		and String((detail_value as Dictionary).get("first_failed_invariant_id", ""))
		== expected_invariant
	)


static func _evaluate() -> Dictionary:
	var r63_components := PackedFloat32Array([
		R63_POSITIVE_WORK_J,
		R63_ABSORBED_WORK_J,
	])
	var r63_positive := float(r63_components[0])
	var r63_absorbed := float(r63_components[1])
	var r63_native_net := _f32_subtract(r63_positive, r63_absorbed)
	var r63_projected_net := r63_positive - r63_absorbed
	var r63_projection_delta := r63_native_net - r63_projected_net
	var r63_replay := _telemetry(
		r63_positive,
		r63_absorbed,
		r63_native_net,
	)
	var positive_only := float(PackedFloat32Array([0.0001])[0])
	var absorbed_only := float(PackedFloat32Array([0.0001])[0])
	var controls := [
		r63_replay,
		_telemetry(0.0, 0.0, 0.0),
		_telemetry(positive_only, 0.0, _f32_subtract(positive_only, 0.0)),
		_telemetry(0.0, absorbed_only, _f32_subtract(0.0, absorbed_only)),
	]
	var positive_control_count := 0
	var binary64_identity_count := 0
	var control_diagnostics: Array = []
	for telemetry_value in controls:
		var result := _projection_exact(telemetry_value)
		positive_control_count += int(bool(result.get("ok", false)))
		var projection: Dictionary = result.get("projection", {})
		var projection_detail: Dictionary = projection.get("detail", {})
		var contract: Dictionary = result.get("contract", {})
		var detail: Dictionary = contract.get("detail", {})
		control_diagnostics.append(
			{
				"result_ok": bool(result.get("ok", false)),
				"projection_ok": bool(projection.get("ok", false)),
				"projection_failure_code": String(projection.get("failure_code", "")),
				"native_net_motor_work_j": projection.get(
					"native_net_motor_work_j",
					projection_detail.get("native_net_motor_work_j"),
				),
				"expected_native_float32_net_motor_work_j": projection.get(
					"expected_native_float32_net_motor_work_j",
					projection_detail.get("expected_native_float32_net_motor_work_j"),
				),
				"projected_binary64_net_motor_work_j": projection.get(
					"projected_binary64_net_motor_work_j",
					projection_detail.get("projected_binary64_net_motor_work_j"),
				),
				"contract_ok": bool(contract.get("ok", false)),
				"contract_failure_code": String(contract.get("failure_code", "")),
				"contract_first_failed_invariant_id": String(
					detail.get("first_failed_invariant_id", "")
				),
			}
		)
		binary64_identity_count += int(
			bool(contract.get("ok", false))
			and float(contract.get("net_motor_work_j", NAN))
			== float(contract.get("positive_motor_work_j", NAN))
			- float(contract.get("absorbed_motor_work_j", NAN))
		)

	var mismatch_above := r63_replay.duplicate(true)
	mismatch_above["net_motor_work_j"] = r63_native_net + 1.0e-9
	var mismatch_below := r63_replay.duplicate(true)
	mismatch_below["net_motor_work_j"] = r63_native_net - 1.0e-9
	var mismatch_mutation_rejection_count := int(_source_mismatch_rejected(mismatch_above))
	mismatch_mutation_rejection_count += int(_source_mismatch_rejected(mismatch_below))

	var nonfinite := r63_replay.duplicate(true)
	nonfinite["positive_motor_work_j"] = NAN
	var missing_net := r63_replay.duplicate(true)
	missing_net.erase("net_motor_work_j")
	var passthrough_control_count := int(
		_passthrough_preserves_validator_failure(null, "telemetry_dictionary")
	)
	passthrough_control_count += int(
		_passthrough_preserves_validator_failure(nonfinite, "positive_motor_work_finite")
	)
	passthrough_control_count += int(
		_passthrough_preserves_validator_failure(missing_net, "net_motor_work_finite")
	)

	var r63_result := _projection_exact(r63_replay)
	var r63_projection: Dictionary = r63_result.get("projection", {})
	var r63_replay_exact := (
		bool(r63_result.get("ok", false))
		and float(r63_projection.get("native_net_motor_work_j", NAN))
		== r63_native_net
		and float(r63_projection.get("projected_binary64_net_motor_work_j", NAN))
		== r63_projected_net
		and float(r63_projection.get("net_motor_work_projection_delta_j", NAN))
		== r63_projection_delta
	)
	var exact := (
		positive_control_count == controls.size()
		and binary64_identity_count == controls.size()
		and mismatch_mutation_rejection_count == 2
		and passthrough_control_count == 3
		and r63_replay_exact
	)
	return {
		"schema_version": "sporespore_qsdk_r24d64_godot_exact_net_motor_work_projection_zero_world_v1",
		"gate_id": "QSDK-R24D64",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D64_EXACT_NET_WORK_PROJECTION_INVALID",
		"positive_control_count": positive_control_count,
		"control_diagnostics": [] if exact else control_diagnostics,
		"binary64_identity_count": binary64_identity_count,
		"mismatch_mutation_count": 2,
		"mismatch_mutation_rejection_count": mismatch_mutation_rejection_count,
		"passthrough_control_count": passthrough_control_count,
		"r63_replay_count": 1,
		"r63_replay_exact": r63_replay_exact,
		"r63_native_net_motor_work_j": r63_native_net,
		"r63_projected_net_motor_work_j": r63_projected_net,
		"r63_projection_delta_j": r63_projection_delta,
		"net_work_identity_tolerance_j": 1.0e-12,
		"threshold_changed": false,
		"native_positive_or_absorbed_measurement_changed": false,
		"native_physics_changed": false,
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
