class_name SporeQsdkR10fWalkingSegmentEvaluatorV1
extends RefCounted
# gdlint: disable=max-line-length

## Pure, fixed-threshold evaluator for one R10F BW5R-B walking segment.
##
## It consumes retained scalar trace rows only. It cannot inspect a Node or a
## physics world, and callers cannot supply or override thresholds. A false
## gate is a valid behavioral negative; malformed or incomplete evidence is an
## invalid evaluation.

const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const LocomotionFacade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)

const GATE_ID := "QSDK-R10F"
const EVALUATOR_ID := "sporespore_qsdk_r10f_fixed_walking_segment_evaluator_v1"
const EVALUATION_SCHEMA := "sporespore_qsdk_r10f_walking_segment_evaluation_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_walking_segment_evaluation_failure_v1"
const TRACE_ROW_SCHEMA := "sporespore_qsdk_r10f_compact_native_trace_row_v1"
const LIMB_ORDER := ["front_left", "front_right", "rear_left", "rear_right"]
const SEGMENT_IDS := ["walking_prefix", "walking_resume", "matched_continuation"]
const FIXED_SEGMENT_STEP_COUNT := 720
const MINIMUM_AIRBORNE_DWELL_STEPS := 3
const MINIMUM_FOOT_RELOCATION_M := 0.012
const MINIMUM_FORWARD_ADVANCE_M := 0.02
const MAXIMUM_ABSOLUTE_LATERAL_DRIFT_M := 0.25
const MAXIMUM_YAW_DRIFT_RAD := 0.45
const MAXIMUM_TILT_RAD := 0.60
const MINIMUM_TORSO_HEIGHT_M := 0.25
const MAXIMUM_ANCHOR_ERROR_M := 0.025
const MAXIMUM_HINGE_AXIS_ERROR_RAD := 0.20
const MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION := 0.40
const RECEIPT_KEYS := [
	"bounded_anchor_error",
	"bounded_hinge_axis_error",
	"bounded_joint_only_lateral_stride_steering",
	"bounded_lateral_drift",
	"bounded_tilt",
	"bounded_torso_height",
	"bounded_yaw_drift",
	"contact_gated_evidence_horizon_completed",
	"contact_gating_completed_without_timeout",
	"every_contact_observer_executed",
	"every_limb_completed_evidence_gait_horizon",
	"every_limb_forward_relocation",
	"every_limb_two_contact_cycles",
	"evidence_four_contact_stance",
	"explicit_sdk_controller_session_shutdown",
	"fixture_spec_compiled_before_world_creation",
	"initial_four_contact_stance",
	"initial_perturbation_within_declared_envelope",
	"minimum_evidence_forward_translation",
	"minimum_final_forward_translation",
	"native_sdk_exclusive_post_settle_actuation",
	"no_torso_force_or_impulse_or_velocity_or_transform_command",
	"no_world_reset",
	"one_continuous_world",
	"pinned_jolt_solver_settings",
	"terminal_four_contact_recovery",
	"zero_torso_contact",
]
const INPUT_KEYS := [
	"arm_id",
	"segment_id",
	"session_id",
	"expected_step_count",
	"start_receipt",
	"completion_receipt",
	"initial_contact_by_limb",
	"rows",
	"world_build_count",
	"world_reset_count",
	"body_population_rebuild_count",
	"direct_torso_force_command_count",
	"direct_torso_impulse_command_count",
	"direct_torso_velocity_command_count",
	"direct_torso_transform_command_count",
	"fixture_spec_compiled_before_world_creation",
	"initial_perturbation_application_count",
	"physics_engine",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"source_measurement",
]


static func evaluate_segment_v1(sdk: Object, evidence: Dictionary) -> Dictionary:
	if sdk == null or not _keys_exact_v1(evidence, INPUT_KEYS):
		return _failure("QSDK_R10F_WALKING_EVALUATION_INPUT_INVALID")
	var arm_id := String(evidence.get("arm_id", ""))
	var segment_id := String(evidence.get("segment_id", ""))
	var session_id := String(evidence.get("session_id", ""))
	var expected_step_count := int(evidence.get("expected_step_count", -1))
	var start_value: Variant = evidence.get("start_receipt")
	var completion_value: Variant = evidence.get("completion_receipt")
	var initial_contacts_value: Variant = evidence.get("initial_contact_by_limb")
	var rows_value: Variant = evidence.get("rows")
	if (
		arm_id.is_empty()
		or segment_id not in SEGMENT_IDS
		or session_id.is_empty()
		or expected_step_count < 1
		or (
			segment_id != "matched_continuation" and expected_step_count != FIXED_SEGMENT_STEP_COUNT
		)
		or not (start_value is Dictionary)
		or not (completion_value is Dictionary)
		or not (initial_contacts_value is Dictionary)
		or not (rows_value is Array)
		or not bool(evidence.get("source_measurement", false))
	):
		return _failure("QSDK_R10F_WALKING_EVALUATION_SHAPE_INVALID")
	var start: Dictionary = start_value
	var completion: Dictionary = completion_value
	var initial_contacts: Dictionary = initial_contacts_value
	var rows: Array = rows_value
	if rows.size() != expected_step_count:
		return _failure("QSDK_R10F_WALKING_TRACE_LENGTH_INVALID")
	var start_origin := _finite_vector_v1(start.get("task_frame_origin_world_m"))
	var start_forward := _finite_vector_v1(start.get("task_frame_forward_axis_world_host_real"))
	var start_lateral := _finite_vector_v1(start.get("task_frame_lateral_axis_world_host_real"))
	if (
		String(start.get("session_id", "")) != session_id
		or String(start.get("selected_policy_id", "")) != LocomotionFacade.SELECTED_POLICY_ID
		or not bool(start.get("task_frame_reanchored_in_controller_memory", false))
		or not bool(start.get("task_frame_frozen_for_walking_segment", false))
		or start_origin.is_empty()
		or start_forward.is_empty()
		or start_lateral.is_empty()
		or absf(_norm_v1(start_forward) - 1.0) > 2.0e-6
		or absf(_norm_v1(start_lateral) - 1.0) > 2.0e-6
		or absf(_dot_v1(start_forward, start_lateral)) > 2.0e-6
		or not _contact_map_exact_v1(initial_contacts)
	):
		return _failure("QSDK_R10F_WALKING_START_BOUNDARY_INVALID")

	var maximum_anchor_error_m := 0.0
	var maximum_hinge_axis_error_rad := 0.0
	var maximum_tilt_rad := 0.0
	var minimum_torso_height_m := INF
	var torso_contact_step_count := 0
	var contact_observer_complete := true
	var terminal_contacts: Dictionary = {}
	var terminal_position: Array = []
	var terminal_forward: Array = []
	var contact_state_by_limb := {}
	var cycle_count_by_limb := {}
	var minimum_cycle_forward_relocation_by_limb := {}
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		contact_state_by_limb[limb_id] = {
			"bearing": bool(initial_contacts[limb_id]),
			"airborne_steps": 0,
			"release_position": [],
		}
		cycle_count_by_limb[limb_id] = 0
		minimum_cycle_forward_relocation_by_limb[limb_id] = INF

	for index in range(rows.size()):
		var row_value: Variant = rows[index]
		if not (row_value is Dictionary):
			return _failure("QSDK_R10F_WALKING_TRACE_ROW_SHAPE_INVALID:%d" % index)
		var row: Dictionary = row_value
		var position := _finite_vector_v1(row.get("torso_position_world_m"))
		var forward := _finite_vector_v1(row.get("torso_forward_axis_world_unit"))
		var contacts_value: Variant = row.get("contact_by_limb")
		var feet_value: Variant = row.get("foot_position_world_m_by_limb")
		if (
			String(row.get("schema_version", "")) != TRACE_ROW_SCHEMA
			or String(row.get("arm_id", "")) != arm_id
			or String(row.get("walking_session_id", "")) != session_id
			or int(row.get("walking_session_local_step", -1)) != index + 1
			or position.is_empty()
			or forward.is_empty()
			or not (contacts_value is Dictionary)
			or not (feet_value is Dictionary)
			or not _contact_map_exact_v1(contacts_value)
			or not _foot_position_map_exact_v1(feet_value)
			or not is_finite(float(row.get("maximum_anchor_error_m", NAN)))
			or not is_finite(float(row.get("maximum_hinge_axis_error_rad", NAN)))
			or not is_finite(float(row.get("torso_tilt_rad", NAN)))
			or not _digest_valid_v1(String(row.get("observation_sha256", "")))
			or not _digest_valid_v1(String(row.get("application_intent_sha256", "")))
			or not _digest_valid_v1(String(row.get("body_population_instance_sha256", "")))
		):
			return _failure("QSDK_R10F_WALKING_TRACE_ROW_INVALID:%d" % index)
		maximum_anchor_error_m = maxf(maximum_anchor_error_m, float(row["maximum_anchor_error_m"]))
		maximum_hinge_axis_error_rad = maxf(
			maximum_hinge_axis_error_rad, float(row["maximum_hinge_axis_error_rad"])
		)
		maximum_tilt_rad = maxf(maximum_tilt_rad, float(row["torso_tilt_rad"]))
		minimum_torso_height_m = minf(minimum_torso_height_m, float(position[1]))
		torso_contact_step_count += int(bool(row.get("torso_contact", false)))
		terminal_contacts = (contacts_value as Dictionary).duplicate(true)
		terminal_position = position
		terminal_forward = forward
		for limb_id_value in LIMB_ORDER:
			var limb_id := String(limb_id_value)
			var contact_now := bool((contacts_value as Dictionary)[limb_id])
			var state: Dictionary = contact_state_by_limb[limb_id]
			var foot_position := _finite_vector_v1((feet_value as Dictionary)[limb_id])
			if foot_position.is_empty():
				return _failure("QSDK_R10F_WALKING_FOOT_POSITION_INVALID:%s" % limb_id)
			if bool(state["bearing"]) and not contact_now:
				state["bearing"] = false
				state["airborne_steps"] = 1
				state["release_position"] = foot_position
			elif not bool(state["bearing"]) and not contact_now:
				state["airborne_steps"] = int(state["airborne_steps"]) + 1
			elif not bool(state["bearing"]) and contact_now:
				if int(state["airborne_steps"]) >= MINIMUM_AIRBORNE_DWELL_STEPS:
					cycle_count_by_limb[limb_id] = int(cycle_count_by_limb[limb_id]) + 1
					var relocation := _dot_v1(
						_subtract_v1(foot_position, state["release_position"]), start_forward
					)
					minimum_cycle_forward_relocation_by_limb[limb_id] = minf(
						float(minimum_cycle_forward_relocation_by_limb[limb_id]), relocation
					)
				state["bearing"] = true
				state["airborne_steps"] = 0
				state["release_position"] = []
			contact_state_by_limb[limb_id] = state

	var displacement := _subtract_v1(terminal_position, start_origin)
	var forward_advance_m := _dot_v1(displacement, start_forward)
	var lateral_drift_m := _dot_v1(displacement, start_lateral)
	var yaw_drift_rad := _horizontal_axis_angle_v1(start_forward, terminal_forward)
	if not is_finite(yaw_drift_rad):
		return _failure("QSDK_R10F_WALKING_TERMINAL_HEADING_INVALID")
	var every_limb_two_cycles := true
	var every_limb_relocated := true
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		every_limb_two_cycles = every_limb_two_cycles and int(cycle_count_by_limb[limb_id]) >= 2
		every_limb_relocated = (
			every_limb_relocated
			and is_finite(float(minimum_cycle_forward_relocation_by_limb[limb_id]))
			and (
				float(minimum_cycle_forward_relocation_by_limb[limb_id])
				>= MINIMUM_FOOT_RELOCATION_M
			)
		)
	var summary: Dictionary = completion.get("adapter_summary", {})
	var shutdown: Dictionary = completion.get("adapter_shutdown_receipt", {})
	var direct_body_write_count := (
		int(evidence["direct_torso_force_command_count"])
		+ int(evidence["direct_torso_impulse_command_count"])
		+ int(evidence["direct_torso_velocity_command_count"])
		+ int(evidence["direct_torso_transform_command_count"])
	)
	var initial_four_contact := _all_contacts_v1(initial_contacts)
	var terminal_four_contact := _all_contacts_v1(terminal_contacts)
	var native_sdk_exact := (
		bool(summary.get("ok", false))
		and int(summary.get("step_count", -1)) == expected_step_count
		and String(summary.get("controller_policy_id", "")) == LocomotionFacade.SELECTED_POLICY_ID
		and (
			int(summary.get("validated_balanced_wave_command_count", -1))
			== expected_step_count * LocomotionFacade.JOINT_IDS.size()
		)
		and (
			int(summary.get("native_actuation_application_count", -1))
			== expected_step_count * LocomotionFacade.JOINT_IDS.size()
		)
		and int(summary.get("mismatch_count", -1)) == 0
		and int(summary.get("safe_no_actuation_count", -1)) == 0
		and int(summary.get("native_safe_disable_application_count", -1)) == 0
		and bool(summary.get("balanced_wave_shadow_valid", false))
	)
	var receipts := {
		"one_continuous_world":
		(
			int(evidence["world_build_count"]) == 1
			and int(evidence["body_population_rebuild_count"]) == 0
		),
		"no_world_reset": int(evidence["world_reset_count"]) == 0,
		"fixture_spec_compiled_before_world_creation":
		bool(evidence["fixture_spec_compiled_before_world_creation"]),
		"initial_perturbation_within_declared_envelope":
		int(evidence["initial_perturbation_application_count"]) == 0,
		"contact_gating_completed_without_timeout":
		(
			bool(summary.get("ok", false))
			and int(summary.get("step_count", -1)) == expected_step_count
		),
		"contact_gated_evidence_horizon_completed": rows.size() == expected_step_count,
		"every_limb_completed_evidence_gait_horizon": contact_observer_complete,
		"pinned_jolt_solver_settings":
		(
			String(evidence["physics_engine"]) == "Jolt Physics"
			and int(evidence["physics_hz"]) == 120
			and int(evidence["solver_velocity_steps"]) == 20
			and int(evidence["solver_position_steps"]) == 7
		),
		"no_torso_force_or_impulse_or_velocity_or_transform_command": direct_body_write_count == 0,
		"bounded_joint_only_lateral_stride_steering":
		native_sdk_exact and MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION == 0.40,
		"initial_four_contact_stance": initial_four_contact,
		"every_contact_observer_executed": contact_observer_complete,
		"every_limb_two_contact_cycles": every_limb_two_cycles,
		"every_limb_forward_relocation": every_limb_relocated,
		"minimum_evidence_forward_translation": forward_advance_m >= MINIMUM_FORWARD_ADVANCE_M,
		"minimum_final_forward_translation": forward_advance_m >= MINIMUM_FORWARD_ADVANCE_M,
		"bounded_lateral_drift": absf(lateral_drift_m) <= MAXIMUM_ABSOLUTE_LATERAL_DRIFT_M,
		"bounded_yaw_drift": yaw_drift_rad <= MAXIMUM_YAW_DRIFT_RAD,
		"bounded_tilt": maximum_tilt_rad <= MAXIMUM_TILT_RAD,
		"bounded_torso_height": minimum_torso_height_m >= MINIMUM_TORSO_HEIGHT_M,
		"zero_torso_contact": torso_contact_step_count == 0,
		"terminal_four_contact_recovery": terminal_four_contact,
		"bounded_anchor_error": maximum_anchor_error_m <= MAXIMUM_ANCHOR_ERROR_M,
		"bounded_hinge_axis_error": maximum_hinge_axis_error_rad <= MAXIMUM_HINGE_AXIS_ERROR_RAD,
		"evidence_four_contact_stance": initial_four_contact,
		"explicit_sdk_controller_session_shutdown":
		(
			bool(shutdown.get("ok", false))
			and bool(shutdown.get("explicit_shutdown_completed", false))
			and int(shutdown.get("native_controller_session_destroy_count", -1)) == 1
		),
		"native_sdk_exclusive_post_settle_actuation": native_sdk_exact,
	}
	if not _keys_exact_v1(receipts, RECEIPT_KEYS):
		return _failure("QSDK_R10F_WALKING_RECEIPT_SET_INVALID")
	var false_receipts: Array = []
	for receipt_id_value in RECEIPT_KEYS:
		var receipt_id := String(receipt_id_value)
		if not bool(receipts[receipt_id]):
			false_receipts.append(receipt_id)
	var evaluation := {
		"schema_version": EVALUATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"evaluator_id": EVALUATOR_ID,
		"arm_id": arm_id,
		"segment_id": segment_id,
		"session_id": session_id,
		"evidence_valid": true,
		"outcome_complete": true,
		"behavior_passed": false_receipts.is_empty(),
		"walking_gate_receipts": receipts,
		"walking_receipt_count": receipts.size(),
		"false_walking_receipts": false_receipts,
		"trace_row_count": rows.size(),
		"forward_advance_m": forward_advance_m,
		"absolute_lateral_drift_m": absf(lateral_drift_m),
		"yaw_drift_rad": yaw_drift_rad,
		"maximum_tilt_rad": maximum_tilt_rad,
		"minimum_torso_height_m": minimum_torso_height_m,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
		"torso_contact_step_count": torso_contact_step_count,
		"contact_cycle_count_by_limb": cycle_count_by_limb,
		"minimum_cycle_forward_relocation_by_limb_m": minimum_cycle_forward_relocation_by_limb,
		"fixed_thresholds":
		{
			"minimum_airborne_dwell_steps": MINIMUM_AIRBORNE_DWELL_STEPS,
			"minimum_foot_relocation_m": MINIMUM_FOOT_RELOCATION_M,
			"minimum_forward_advance_m": MINIMUM_FORWARD_ADVANCE_M,
			"maximum_absolute_lateral_drift_m": MAXIMUM_ABSOLUTE_LATERAL_DRIFT_M,
			"maximum_yaw_drift_rad": MAXIMUM_YAW_DRIFT_RAD,
			"maximum_tilt_rad": MAXIMUM_TILT_RAD,
			"minimum_torso_height_m": MINIMUM_TORSO_HEIGHT_M,
			"maximum_anchor_error_m": MAXIMUM_ANCHOR_ERROR_M,
			"maximum_hinge_axis_error_rad": MAXIMUM_HINGE_AXIS_ERROR_RAD,
		},
		"threshold_override_input_count": 0,
		"evaluation_world_build_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	evaluation["payload_sha256"] = _sha256_v1(sdk, evaluation)
	if not _digest_valid_v1(String(evaluation["payload_sha256"])):
		return _failure("QSDK_R10F_WALKING_EVALUATION_DIGEST_INVALID")
	return evaluation


static func _contact_map_exact_v1(value: Dictionary) -> bool:
	if value.size() != LIMB_ORDER.size():
		return false
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		if not value.has(limb_id) or typeof(value[limb_id]) != TYPE_BOOL:
			return false
	return true


static func _foot_position_map_exact_v1(value: Dictionary) -> bool:
	if value.size() != LIMB_ORDER.size():
		return false
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		if not value.has(limb_id) or _finite_vector_v1(value[limb_id]).is_empty():
			return false
	return true


static func _all_contacts_v1(value: Dictionary) -> bool:
	if not _contact_map_exact_v1(value):
		return false
	for contact in value.values():
		if not bool(contact):
			return false
	return true


static func _horizontal_axis_angle_v1(left: Array, right: Array) -> float:
	var left_horizontal := [float(left[0]), 0.0, float(left[2])]
	var right_horizontal := [float(right[0]), 0.0, float(right[2])]
	left_horizontal = _normalize_v1(left_horizontal)
	right_horizontal = _normalize_v1(right_horizontal)
	if left_horizontal.is_empty() or right_horizontal.is_empty():
		return NAN
	return acos(clampf(_dot_v1(left_horizontal, right_horizontal), -1.0, 1.0))


static func _finite_vector_v1(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		return []
	var result: Array = []
	for component_value in value:
		if typeof(component_value) not in [TYPE_FLOAT, TYPE_INT]:
			return []
		var component := float(component_value)
		if not is_finite(component):
			return []
		result.append(component)
	return result


static func _subtract_v1(left: Array, right: Array) -> Array:
	return [
		float(left[0]) - float(right[0]),
		float(left[1]) - float(right[1]),
		float(left[2]) - float(right[2]),
	]


static func _norm_v1(value: Array) -> float:
	return sqrt(_dot_v1(value, value))


static func _dot_v1(left: Array, right: Array) -> float:
	return (
		float(left[0]) * float(right[0])
		+ float(left[1]) * float(right[1])
		+ float(left[2]) * float(right[2])
	)


static func _normalize_v1(value: Array) -> Array:
	var length := _norm_v1(value)
	if not is_finite(length) or length <= 0.0:
		return []
	return [
		float(value[0]) / length,
		float(value[1]) / length,
		float(value[2]) / length,
	]


static func _sha256_v1(sdk: Object, value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	return String(receipt.get("sha256", ""))


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _digest_valid_v1(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
