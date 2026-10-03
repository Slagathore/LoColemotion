extends SceneTree
# gdlint: disable=max-line-length

## Complete zero-world gate for the R87 source-measured force-based Godot/Jolt
## joint mapping. It executes the production projection, retained-receipt
## validator, and centered-work mapping without creating a Node, RID, model,
## world, or solver step.

const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D87_GODOT_FORCE_BASED_RECOVERY_ACTUATOR_ZERO_WORLD "
const GAIN_NM_S_PER_RAD := 10.0
const STEP_S := 1.0 / 120.0
const ORDERED_ACTUATOR_IDS := [
	"front_left_hip_motor",
	"front_left_knee_motor",
	"front_right_hip_motor",
	"front_right_knee_motor",
	"rear_left_hip_motor",
	"rear_left_knee_motor",
	"rear_right_hip_motor",
	"rear_right_knee_motor",
]
const ORDERED_JOINT_IDS := [
	"front_left_hip",
	"front_left_knee",
	"front_right_hip",
	"front_right_knee",
	"rear_left_hip",
	"rear_left_knee",
	"rear_right_hip",
	"rear_right_knee",
]
const ORDERED_PARENT_BODY_IDS := [
	"torso",
	"front_left_upper",
	"torso",
	"front_right_upper",
	"torso",
	"rear_left_upper",
	"torso",
	"rear_right_upper",
]
const ORDERED_CHILD_BODY_IDS := [
	"front_left_upper",
	"front_left_distal",
	"front_right_upper",
	"front_right_distal",
	"rear_left_upper",
	"rear_left_distal",
	"rear_right_upper",
	"rear_right_distal",
]
const ORDERED_CAPS_NMS := [
	0.05362625170687301,
	0.4567500054836273,
	0.05362625170687301,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
]


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


static func _run() -> Dictionary:
	var projection_control_count := 0
	var retained_receipt_validation_count := 0
	var equal_and_opposite_count := 0
	var published_cap_respected_count := 0
	var positive_sign_count := 0
	var negative_sign_count := 0
	var saturation_count := 0
	var representation_projection_count := 0
	var centered_work_control_count := 0
	var positive_work_count := 0
	var absorbed_work_count := 0
	var ordered_projection_receipts: Array = []
	var ordered_work_receipts: Array = []
	for index in range(8):
		var target_velocity := 2.0 if index % 2 == 0 else -2.0
		var pre_velocity := 0.0
		var axis_world := _axis(index)
		var projection := _projection(
			index,
			target_velocity,
			pre_velocity,
			axis_world,
		)
		var validation := WorldScript.validate_force_based_joint_impulse_projection_v1(projection)
		var cap := float(ORDERED_CAPS_NMS[index])
		var requested := GAIN_NM_S_PER_RAD * (target_velocity - pre_velocity) * STEP_S
		var expected_clamped := clampf(requested, -cap, cap)
		var applied_input := float(projection.get("applied_input_signed_impulse_nms", NAN))
		var child := _vec3(projection.get("child_angular_impulse_world_nms"))
		var parent := _vec3(projection.get("parent_angular_impulse_world_nms"))
		var applied := float(projection.get("applied_signed_joint_impulse_nms", NAN))
		var expected_child := axis_world * applied_input
		var expected_applied := (
			-expected_child.length() if applied_input < 0.0 else expected_child.length()
		)
		var projection_exact := (
			bool(projection.get("ok", false))
			and int(projection.get("actuator_index", -1)) == index
			and String(projection.get("actuator_id", "")) == String(ORDERED_ACTUATOR_IDS[index])
			and String(projection.get("joint_id", "")) == String(ORDERED_JOINT_IDS[index])
			and (
				String(projection.get("parent_body_id", ""))
				== String(ORDERED_PARENT_BODY_IDS[index])
			)
			and String(projection.get("child_body_id", "")) == String(ORDERED_CHILD_BODY_IDS[index])
			and float(projection.get("velocity_error_gain_nm_s_per_rad", NAN)) == GAIN_NM_S_PER_RAD
			and float(projection.get("outer_step_duration_s", NAN)) == STEP_S
			and float(projection.get("requested_signed_impulse_nms", NAN)) == requested
			and float(projection.get("clamped_signed_impulse_nms", NAN)) == expected_clamped
			and applied == expected_applied
			and child == expected_child
			and parent == -child
			and _zero_world_receipt(projection)
		)
		projection_control_count += int(projection_exact)
		retained_receipt_validation_count += int(
			bool(validation.get("ok", false)) and _zero_world_receipt(validation)
		)
		equal_and_opposite_count += int(
			(
				child.is_finite()
				and parent.is_finite()
				and child + parent == Vector3.ZERO
				and bool(projection.get("equal_and_opposite_pair", false))
			)
		)
		published_cap_respected_count += int(absf(applied) <= cap)
		positive_sign_count += int(applied > 0.0)
		negative_sign_count += int(applied < 0.0)
		saturation_count += int(bool(projection.get("impulse_saturated", false)))
		representation_projection_count += int(
			bool(projection.get("representation_projection_applied", false))
		)

		var post_velocity := -target_velocity if index < 2 else target_velocity
		var work := (
			WorldScript
			. force_based_joint_work_projection_v1(
				projection,
				2,
				true,
				Vector3.BACK,
				post_velocity,
			)
		)
		var expected_centered := 0.5 * (pre_velocity + post_velocity)
		var expected_net_work := applied * expected_centered
		var work_exact := (
			bool(work.get("ok", false))
			and (
				String(work.get("actuator_mapping_id", ""))
				== WorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID
			)
			and String(work.get("work_mapping_id", "")) == WorldScript.FORCE_BASED_WORK_MAPPING_ID
			and float(work.get("pre_relative_velocity_rad_s", NAN)) == pre_velocity
			and float(work.get("post_relative_velocity_rad_s", NAN)) == post_velocity
			and float(work.get("centered_relative_velocity_rad_s", NAN)) == expected_centered
			and float(work.get("net_motor_work_j", NAN)) == expected_net_work
			and float(work.get("positive_motor_work_j", NAN)) == maxf(expected_net_work, 0.0)
			and float(work.get("absorbed_motor_work_j", NAN)) == maxf(-expected_net_work, 0.0)
			and not bool(work.get("mechanical_energy_residual_used_as_work_source", true))
			and _zero_world_receipt(work)
		)
		centered_work_control_count += int(work_exact)
		positive_work_count += int(expected_net_work > 0.0 and work_exact)
		absorbed_work_count += int(expected_net_work < 0.0 and work_exact)
		ordered_projection_receipts.append(projection)
		ordered_work_receipts.append(work)

	var zero_error_projection := _projection(0, 0.75, 0.75, Vector3.RIGHT)
	var zero_error_control := (
		bool(zero_error_projection.get("ok", false))
		and float(zero_error_projection.get("applied_signed_joint_impulse_nms", NAN)) == 0.0
		and not bool(zero_error_projection.get("impulse_saturated", true))
	)

	var invalid_projection_mutations := [
		_projection(0, 1.0, 0.0, Vector3.RIGHT, 0, "unknown_motor"),
		_projection(0, 1.0, NAN, Vector3.RIGHT),
		_projection(0, 1.0, 0.0, Vector3.RIGHT, -1),
		WorldScript.force_based_joint_impulse_projection_v1(
			0,
			ORDERED_ACTUATOR_IDS[0],
			ORDERED_JOINT_IDS[0],
			ORDERED_PARENT_BODY_IDS[0],
			ORDERED_CHILD_BODY_IDS[0],
			1,
			true,
			Vector3.RIGHT,
			Vector3.RIGHT,
			1.0,
			4.0,
			0.0,
			ORDERED_CAPS_NMS[0]
		),
		WorldScript.force_based_joint_impulse_projection_v1(
			0,
			ORDERED_ACTUATOR_IDS[1],
			ORDERED_JOINT_IDS[0],
			ORDERED_PARENT_BODY_IDS[0],
			ORDERED_CHILD_BODY_IDS[0],
			1,
			true,
			Vector3.BACK,
			Vector3.RIGHT,
			1.0,
			4.0,
			0.0,
			ORDERED_CAPS_NMS[0]
		),
		WorldScript.force_based_joint_impulse_projection_v1(
			0,
			ORDERED_ACTUATOR_IDS[0],
			ORDERED_JOINT_IDS[0],
			ORDERED_PARENT_BODY_IDS[0],
			ORDERED_CHILD_BODY_IDS[0],
			1,
			true,
			Vector3.BACK,
			Vector3.RIGHT,
			1.0,
			4.0,
			0.0,
			ORDERED_CAPS_NMS[1]
		),
		WorldScript.force_based_joint_impulse_projection_v1(
			0,
			ORDERED_ACTUATOR_IDS[0],
			ORDERED_JOINT_IDS[0],
			ORDERED_PARENT_BODY_IDS[0],
			ORDERED_CHILD_BODY_IDS[0],
			1,
			false,
			Vector3.BACK,
			Vector3.RIGHT,
			1.0,
			4.0,
			0.0,
			ORDERED_CAPS_NMS[0]
		),
		WorldScript.force_based_joint_impulse_projection_v1(
			0,
			ORDERED_ACTUATOR_IDS[0],
			ORDERED_JOINT_IDS[0],
			ORDERED_PARENT_BODY_IDS[0],
			ORDERED_CHILD_BODY_IDS[0],
			1,
			true,
			Vector3.BACK,
			Vector3(2.0, 0.0, 0.0),
			1.0,
			4.0,
			0.0,
			ORDERED_CAPS_NMS[0]
		),
	]
	var invalid_projection_rejection_count := 0
	for mutation_value in invalid_projection_mutations:
		var mutation: Dictionary = mutation_value
		invalid_projection_rejection_count += int(
			not bool(mutation.get("ok", true)) and _zero_world_receipt(mutation)
		)

	var reference_projection := _projection(0, 1.0, 0.0, Vector3.RIGHT)
	var receipt_mutations: Array = []
	var one_sided := reference_projection.duplicate(true)
	(one_sided["child_angular_impulse_world_nms"] as Dictionary)["x"] = 0.001
	receipt_mutations.append(one_sided)
	var scalar_tamper := reference_projection.duplicate(true)
	scalar_tamper["requested_signed_impulse_nms"] = 0.0
	receipt_mutations.append(scalar_tamper)
	var mapping_tamper := reference_projection.duplicate(true)
	mapping_tamper["actuator_mapping_id"] = "tampered"
	receipt_mutations.append(mapping_tamper)
	var extra_field := reference_projection.duplicate(true)
	extra_field["undeclared"] = true
	receipt_mutations.append(extra_field)
	var retained_receipt_mutation_rejection_count := 0
	for mutation_value in receipt_mutations:
		var validation := WorldScript.validate_force_based_joint_impulse_projection_v1(
			mutation_value
		)
		retained_receipt_mutation_rejection_count += int(
			not bool(validation.get("ok", true)) and _zero_world_receipt(validation)
		)

	var residual_tamper := reference_projection.duplicate(true)
	residual_tamper["mechanical_energy_residual_used_as_work_source"] = true
	var invalid_work_mutations := [
		WorldScript.force_based_joint_work_projection_v1(
			reference_projection, 3, true, Vector3.BACK, 1.0
		),
		WorldScript.force_based_joint_work_projection_v1(
			reference_projection, 2, false, Vector3.BACK, 1.0
		),
		WorldScript.force_based_joint_work_projection_v1(
			reference_projection, 2, true, Vector3.RIGHT, 1.0
		),
		WorldScript.force_based_joint_work_projection_v1(
			reference_projection, 2, true, Vector3.BACK, NAN
		),
		WorldScript.force_based_joint_work_projection_v1(
			residual_tamper, 2, true, Vector3.BACK, 1.0
		),
	]
	var invalid_work_rejection_count := 0
	for mutation_value in invalid_work_mutations:
		var mutation: Dictionary = mutation_value
		invalid_work_rejection_count += int(
			not bool(mutation.get("ok", true)) and _zero_world_receipt(mutation)
		)

	var exact := (
		projection_control_count == 8
		and retained_receipt_validation_count == 8
		and equal_and_opposite_count == 8
		and published_cap_respected_count == 8
		and positive_sign_count == 4
		and negative_sign_count == 4
		and saturation_count == 4
		and representation_projection_count == 2
		and centered_work_control_count == 8
		and positive_work_count == 6
		and absorbed_work_count == 2
		and zero_error_control
		and invalid_projection_rejection_count == 8
		and retained_receipt_mutation_rejection_count == 4
		and invalid_work_rejection_count == 5
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d87_godot_force_based_recovery_actuator_zero_world_v1",
		"gate_id": "QSDK-R24D87",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D87_FORCE_BASED_ZERO_WORLD_INVALID",
		"actuator_mapping_id": WorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": WorldScript.FORCE_BASED_WORK_MAPPING_ID,
		"projection_control_count": projection_control_count,
		"retained_receipt_validation_count": retained_receipt_validation_count,
		"equal_and_opposite_count": equal_and_opposite_count,
		"published_cap_respected_count": published_cap_respected_count,
		"positive_sign_count": positive_sign_count,
		"negative_sign_count": negative_sign_count,
		"saturation_count": saturation_count,
		"representation_projection_count": representation_projection_count,
		"centered_work_control_count": centered_work_control_count,
		"positive_work_count": positive_work_count,
		"absorbed_work_count": absorbed_work_count,
		"zero_error_control": zero_error_control,
		"invalid_projection_rejection_count": invalid_projection_rejection_count,
		"retained_receipt_mutation_rejection_count": retained_receipt_mutation_rejection_count,
		"invalid_work_rejection_count": invalid_work_rejection_count,
		"ordered_projection_receipts": ordered_projection_receipts,
		"ordered_work_receipts": ordered_work_receipts,
		"retained_rapier_velocity_error_gain_nm_s_per_rad": GAIN_NM_S_PER_RAD,
		"published_cap_changed": false,
		"canonical_target_changed": false,
		"work_uses_centered_source_measured_relative_velocity": true,
		"mechanical_energy_residual_used_as_work_source": false,
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


static func _projection(
	index: int,
	target_velocity_rad_s: float,
	measured_velocity_rad_s: float,
	axis_world: Vector3,
	source_semantic_step: int = 1,
	actuator_id_override: String = "",
) -> Dictionary:
	var actuator_id := (
		actuator_id_override
		if not actuator_id_override.is_empty()
		else String(ORDERED_ACTUATOR_IDS[index])
	)
	return (
		WorldScript
		. force_based_joint_impulse_projection_v1(
			index,
			actuator_id,
			String(ORDERED_JOINT_IDS[index]),
			String(ORDERED_PARENT_BODY_IDS[index]),
			String(ORDERED_CHILD_BODY_IDS[index]),
			source_semantic_step,
			true,
			Vector3.BACK,
			axis_world,
			target_velocity_rad_s,
			4.0,
			measured_velocity_rad_s,
			float(ORDERED_CAPS_NMS[index]),
		)
	)


static func _axis(index: int) -> Vector3:
	var axes := [
		Vector3.RIGHT,
		Vector3(-1.0, 1.0, 0.0).normalized(),
		Vector3.UP,
		Vector3(0.0, -1.0, 1.0).normalized(),
		Vector3.BACK,
		Vector3(1.0, 0.0, -1.0).normalized(),
		Vector3.RIGHT,
		Vector3(-1.0, -1.0, -1.0).normalized(),
	]
	return axes[index]


static func _vec3(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var source: Dictionary = value
	return Vector3(
		float(source.get("x", NAN)),
		float(source.get("y", NAN)),
		float(source.get("z", NAN)),
	)


static func _zero_world_receipt(receipt: Dictionary) -> bool:
	return (
		int(receipt.get("model_construction_count", -1)) == 0
		and int(receipt.get("world_attempt_count", -1)) == 0
		and int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("solver_step_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(receipt.get("release_authority", true))
	)
