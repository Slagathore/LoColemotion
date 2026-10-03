extends SceneTree
# gdlint: disable=max-line-length

## Exhaustive pure controls for the structured failure receipt returned by the
## exact telemetry predicate used in the physical sampler. No extension, Node,
## RID, model, world, solver step, or physics mutation exists.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D63_GODOT_STRUCTURED_TELEMETRY_FAILURE_ZERO_WORLD "
const ACTUATOR_ID := "front_left_hip_motor"
const CAP_NMS := 0.002
const IMPULSE_TOLERANCE_NMS := 1.0e-6
const WORK_IDENTITY_TOLERANCE_J := 1.0e-12
const STEP_S := 1.0 / 120.0
const FAILURE_SCHEMA := (
	"sporespore_qsdk_r24d63_godot_native_motor_telemetry_failure_receipt_v1"
)


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
	expected_invariant_id: String,
	telemetry: Variant,
	zero_command: bool = true,
	prior_sequence: int = -1,
	prior_step_s: float = NAN,
	expected_failure_group: String = "invalid",
) -> Dictionary:
	return {
		"id": id,
		"expected_invariant_id": expected_invariant_id,
		"telemetry": telemetry,
		"zero_command": zero_command,
		"prior_sequence": prior_sequence,
		"prior_step_s": prior_step_s,
		"expected_failure_group": expected_failure_group,
	}


static func _expected_failure_code(group: String) -> String:
	if group == "missing":
		return "QSDK_R24D57_WORLD_TELEMETRY_MISSING:%s" % ACTUATOR_ID
	if group == "zero_command":
		return "QSDK_R24D57_WORLD_ZERO_COMMAND_TELEMETRY_NONZERO:%s" % ACTUATOR_ID
	return "QSDK_R24D57_WORLD_TELEMETRY_INVALID:%s" % ACTUATOR_ID


static func _failure_exact(result: Dictionary, case: Dictionary) -> bool:
	var detail_value: Variant = result.get("detail")
	if not (detail_value is Dictionary):
		return false
	var detail: Dictionary = detail_value
	var expected_id := String(case["expected_invariant_id"])
	var failed_ids_value: Variant = detail.get("failed_invariant_ids")
	var invariants_value: Variant = detail.get("invariant_results")
	return (
		not bool(result.get("ok", true))
		and String(result.get("failure_code", ""))
		== _expected_failure_code(String(case["expected_failure_group"]))
		and String(detail.get("schema_version", "")) == FAILURE_SCHEMA
		and String(detail.get("legacy_failure_code", ""))
		== String(result.get("failure_code", ""))
		and String(detail.get("actuator_id", "")) == ACTUATOR_ID
		and String(detail.get("first_failed_invariant_id", "")) == expected_id
		and failed_ids_value is Array
		and expected_id in (failed_ids_value as Array)
		and invariants_value is Dictionary
		and not bool((invariants_value as Dictionary).get(expected_id, true))
		and int(detail.get("failed_invariant_count", 0)) >= 1
		and int(detail.get("model_construction_count", -1)) == 0
		and int(detail.get("world_attempt_count", -1)) == 0
		and int(detail.get("world_build_count", -1)) == 0
		and int(detail.get("solver_step_count", -1)) == 0
		and not bool(detail.get("physics_state_modified", true))
		and not bool(detail.get("physical_acceptance_authority", true))
		and not bool(detail.get("release_authority", true))
	)


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
	var cap_boundary := _base_telemetry()
	cap_boundary["signed_motor_impulse_nms"] = CAP_NMS + IMPULSE_TOLERANCE_NMS
	var cap_boundary_positive := WorldScript.native_motor_telemetry_contract_v1(
		cap_boundary, ACTUATOR_ID, CAP_NMS, false, -1, NAN
	)
	var work_boundary := _base_telemetry()
	work_boundary["net_motor_work_j"] = WORK_IDENTITY_TOLERANCE_J
	var work_boundary_positive := WorldScript.native_motor_telemetry_contract_v1(
		work_boundary, ACTUATOR_ID, CAP_NMS, false, -1, NAN
	)

	var cases: Array = []
	cases.append(_case("missing_telemetry", "telemetry_dictionary", null, true, -1, NAN, "missing"))
	var value := _base_telemetry()
	value.erase("schema")
	cases.append(_case("missing_schema", "telemetry_schema_exact", value))
	value = _base_telemetry()
	value["schema"] = "sporespore.godot_jolt_hinge_motor_telemetry.v1"
	cases.append(_case("wrong_schema", "telemetry_schema_exact", value))
	value = _base_telemetry()
	value["captured_during_active_step"] = false
	cases.append(_case("inactive_capture", "captured_during_active_step", value))
	value = _base_telemetry()
	value["snapshot_is_current_space_step"] = false
	cases.append(_case("stale_snapshot", "snapshot_is_current_space_step", value))
	value = _base_telemetry()
	value["read_space_step_sequence"] = 0
	value["capture_space_step_sequence"] = 0
	cases.append(_case("nonpositive_read_sequence", "read_space_step_sequence_positive", value))
	value = _base_telemetry()
	value["capture_space_step_sequence"] = 2
	cases.append(_case("capture_read_mismatch", "capture_matches_read_space_step_sequence", value))
	cases.append(_case("population_sequence_mismatch", "actuator_population_space_step_sequence_consistent", _base_telemetry(), true, 2))
	value = _base_telemetry()
	value["solver_step_s"] = NAN
	cases.append(_case("nonfinite_solver_step", "solver_step_finite", value))
	value = _base_telemetry()
	value["solver_step_s"] = 0.0
	cases.append(_case("nonpositive_solver_step", "solver_step_positive", value))
	cases.append(_case("population_solver_step_mismatch", "actuator_population_solver_step_consistent", _base_telemetry(), true, -1, 0.01))
	value = _base_telemetry()
	value["signed_motor_impulse_nms"] = NAN
	cases.append(_case("nonfinite_impulse", "signed_motor_impulse_finite", value))
	value = _base_telemetry()
	value["positive_motor_work_j"] = NAN
	cases.append(_case("nonfinite_positive_work", "positive_motor_work_finite", value))
	value = _base_telemetry()
	value["absorbed_motor_work_j"] = NAN
	cases.append(_case("nonfinite_absorbed_work", "absorbed_motor_work_finite", value))
	value = _base_telemetry()
	value["net_motor_work_j"] = NAN
	cases.append(_case("nonfinite_net_work", "net_motor_work_finite", value))
	value = _base_telemetry()
	value["positive_motor_work_j"] = -0.0001
	value["net_motor_work_j"] = -0.0001
	cases.append(_case("negative_positive_work", "positive_motor_work_nonnegative", value))
	value = _base_telemetry()
	value["absorbed_motor_work_j"] = -0.0001
	value["net_motor_work_j"] = 0.0001
	cases.append(_case("negative_absorbed_work", "absorbed_motor_work_nonnegative", value))
	value = _base_telemetry()
	value["net_motor_work_j"] = WORK_IDENTITY_TOLERANCE_J * 2.0
	cases.append(_case("work_identity_above_tolerance", "net_motor_work_identity", value))
	value = _base_telemetry()
	value["signed_motor_impulse_nms"] = CAP_NMS + IMPULSE_TOLERANCE_NMS * 2.0
	cases.append(_case("impulse_above_cap_and_tolerance", "signed_motor_impulse_within_outer_step_cap", value, false))
	value = _base_telemetry()
	value["signed_motor_impulse_nms"] = 0.001
	cases.append(_case("zero_command_impulse_nonzero", "zero_command_signed_motor_impulse_zero", value, true, -1, NAN, "zero_command"))
	value = _base_telemetry()
	value["positive_motor_work_j"] = 0.0001
	value["net_motor_work_j"] = 0.0001
	cases.append(_case("zero_command_positive_work_nonzero", "zero_command_positive_motor_work_zero", value, true, -1, NAN, "zero_command"))
	value = _base_telemetry()
	value["absorbed_motor_work_j"] = 0.0001
	value["net_motor_work_j"] = -0.0001
	cases.append(_case("zero_command_absorbed_work_nonzero", "zero_command_absorbed_motor_work_zero", value, true, -1, NAN, "zero_command"))

	var mutation_ids: Array = []
	var exact_failure_receipt_count := 0
	var cap_failure_detail: Dictionary = {}
	var nonfinite_failure_detail: Dictionary = {}
	for case_value in cases:
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
		exact_failure_receipt_count += int(_failure_exact(result, case))
		if String(case["id"]) == "impulse_above_cap_and_tolerance":
			cap_failure_detail = (result.get("detail", {}) as Dictionary).duplicate(true)
		if String(case["id"]) == "nonfinite_impulse":
			nonfinite_failure_detail = (result.get("detail", {}) as Dictionary).duplicate(true)

	var positive_receipts := [
		zero_positive, active_positive, cap_boundary_positive, work_boundary_positive
	]
	var positive_control_count := 0
	var success_schema_unchanged_count := 0
	for receipt_value in positive_receipts:
		var receipt: Dictionary = receipt_value
		positive_control_count += int(bool(receipt.get("ok", false)))
		success_schema_unchanged_count += int(
			String(receipt.get("schema_version", ""))
			== "sporespore_qsdk_r24d60_godot_native_motor_telemetry_contract_v1"
		)
	var cap_inputs: Dictionary = cap_failure_detail.get("validation_inputs", {})
	var cap_telemetry: Dictionary = cap_failure_detail.get("telemetry", {})
	var cap_invariants: Dictionary = cap_failure_detail.get("invariant_results", {})
	var cap_evidence_exact := (
		float(cap_inputs.get("maximum_outer_step_impulse_nms", NAN)) == CAP_NMS
		and float(cap_inputs.get("telemetry_impulse_tolerance_nms", NAN))
		== IMPULSE_TOLERANCE_NMS
		and float(cap_inputs.get("net_work_identity_tolerance_j", NAN))
		== WORK_IDENTITY_TOLERANCE_J
		and float(cap_telemetry.get("signed_motor_impulse_nms", NAN))
		== CAP_NMS + IMPULSE_TOLERANCE_NMS * 2.0
		and not bool(cap_invariants.get("signed_motor_impulse_within_outer_step_cap", true))
	)
	var nonfinite_telemetry: Dictionary = nonfinite_failure_detail.get("telemetry", {})
	var nonfinite_impulse_value: Variant = nonfinite_telemetry.get("signed_motor_impulse_nms")
	var nonfinite_evidence_exact := (
		nonfinite_impulse_value is Dictionary
		and String((nonfinite_impulse_value as Dictionary).get("classification", "")) == "nan"
	)
	var exact := (
		positive_control_count == positive_receipts.size()
		and success_schema_unchanged_count == positive_receipts.size()
		and exact_failure_receipt_count == cases.size()
		and cap_evidence_exact
		and nonfinite_evidence_exact
	)
	return {
		"schema_version": "sporespore_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_zero_world_v1",
		"gate_id": "QSDK-R24D63",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D63_STRUCTURED_TELEMETRY_RECEIPT_INVALID",
		"positive_control_count": positive_control_count,
		"success_schema_unchanged_count": success_schema_unchanged_count,
		"exact_failure_receipt_count": exact_failure_receipt_count,
		"mutation_count": cases.size(),
		"mutation_ids": mutation_ids,
		"cap_boundary_acceptance_count": int(bool(cap_boundary_positive.get("ok", false))),
		"work_identity_boundary_acceptance_count": int(bool(work_boundary_positive.get("ok", false))),
		"cap_evidence_exact": cap_evidence_exact,
		"nonfinite_evidence_exact": nonfinite_evidence_exact,
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
