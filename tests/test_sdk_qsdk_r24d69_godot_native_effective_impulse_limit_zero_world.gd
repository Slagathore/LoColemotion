extends SceneTree
# gdlint: disable=max-line-length

## Complete zero-world R69 population for the exact S169 Godot/Jolt native
## effective impulse-limit projection. It executes the production command
## surface with unparented hinges but creates no model, world, RID, or step.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_ZERO_WORLD "

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
const ORDERED_PUBLISHED_CAPS_NMS := [
	0.05362625170687301,
	0.4567500054836273,
	0.05362625170687301,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
]
const ORDERED_SELECTED_HOST_BITS := [
	0x3d5ba732,
	0x3ee9db22,
	0x3d5ba732,
	0x3ee9db22,
	0x3d66e827,
	0x3ee9db22,
	0x3d66e827,
	0x3ee9db22,
]


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D69_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D69_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D69_ZERO_WORLD_CONTEXT_FAILED", context)

	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D69_ZERO_WORLD_COMMAND_SURFACE_FAILED", surface)
	var guard_receipt: Dictionary = (
		surface.get("strict_host_cap_guard_receipt", {}) as Dictionary
	).duplicate(true)
	var route_counts := _route_projection_counts(guard_receipt)
	RouteScript.free_zero_world_command_surface_v1(surface)

	var direct_projection_count := 0
	var native_effective_safe_count := 0
	var adjacent_unsafe_count := 0
	var binary32_maximality_count := 0
	var source_algebra_identity_count := 0
	var ordered_projection_receipts: Array = []
	for index in range(8):
		var projection := WorldScript.native_effective_impulse_limit_projection_v1(
			String(ORDERED_ACTUATOR_IDS[index]),
			float(ORDERED_PUBLISHED_CAPS_NMS[index]),
		)
		var selected_bits := int(ORDERED_SELECTED_HOST_BITS[index])
		var selected_hex := "0x%08x" % selected_bits
		var next_hex := "0x%08x" % (selected_bits + 1)
		var selected_host := float(
			projection.get("configured_host_maximum_impulse_nms", NAN)
		)
		var expected_torque := _f32(selected_host / (1.0 / 120.0))
		var expected_effective := _f32(expected_torque * _f32(1.0 / 120.0))
		var next_host := float(
			projection.get("next_binary32_host_maximum_impulse_nms", NAN)
		)
		var expected_next_torque := _f32(next_host / (1.0 / 120.0))
		var expected_next_effective := _f32(
			expected_next_torque * _f32(1.0 / 120.0)
		)
		var exact := (
			bool(projection.get("ok", false))
			and int(projection.get("actuator_index", -1)) == index
			and String(projection.get("configured_host_cap_binary32_hex", ""))
			== selected_hex
			and float(projection.get("projected_native_maximum_torque_limit_nm", NAN))
			== expected_torque
			and float(projection.get("native_solver_step_s", NAN))
			== _f32(1.0 / 120.0)
			and String(projection.get("native_solver_step_binary32_hex", ""))
			== "0x3c088889"
			and float(
				projection.get("projected_native_effective_impulse_limit_nms", NAN)
			)
			== expected_effective
			and String(projection.get("next_binary32_host_cap_binary32_hex", ""))
			== next_hex
			and float(
				projection.get(
					"next_projected_native_effective_impulse_limit_nms",
					NAN,
				)
			)
			== expected_next_effective
			and int(projection.get("configured_to_next_binary32_ulp_distance", -1))
			== 1
			and _zero_world_receipt(projection)
		)
		direct_projection_count += int(exact)
		native_effective_safe_count += int(
			bool(projection.get("native_effective_limit_not_above_published", false))
			and expected_effective
			<= float(ORDERED_PUBLISHED_CAPS_NMS[index])
		)
		adjacent_unsafe_count += int(
			bool(projection.get("next_native_effective_limit_above_published", false))
			and expected_next_effective
			> float(ORDERED_PUBLISHED_CAPS_NMS[index])
		)
		binary32_maximality_count += int(
			String(projection.get("configured_host_cap_binary32_hex", "")) == selected_hex
			and String(projection.get("next_binary32_host_cap_binary32_hex", ""))
			== next_hex
		)
		source_algebra_identity_count += int(
			float(
				projection.get("projected_native_effective_impulse_limit_nms", NAN)
			)
			== expected_effective
		)
		ordered_projection_receipts.append(projection)

	var rear_cap := float(ORDERED_PUBLISHED_CAPS_NMS[4])
	var mutations := [
		WorldScript.native_effective_impulse_limit_projection_v1(
			"unknown_motor",
			rear_cap,
		),
		WorldScript.native_effective_impulse_limit_projection_v1(
			"rear_left_hip_motor",
			_rear_hip_cap_adjacent_binary64_v1(1),
		),
		WorldScript.native_effective_impulse_limit_projection_v1(
			"rear_left_hip_motor",
			NAN,
		),
		WorldScript.native_effective_impulse_limit_projection_v1(
			"rear_left_hip_motor",
			0.0,
		),
	]
	var identity_mutation_rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		identity_mutation_rejection_count += int(
			not bool(mutation.get("ok", true))
			and _zero_world_receipt(mutation)
		)

	var exact := (
		direct_projection_count == 8
		and native_effective_safe_count == 8
		and adjacent_unsafe_count == 8
		and binary32_maximality_count == 8
		and source_algebra_identity_count == 8
		and int(route_counts.get("exact_route_projection_count", -1)) == 8
		and int(route_counts.get("safe_route_readback_count", -1)) == 8
		and identity_mutation_rejection_count == 4
	)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_v1"
		),
		"gate_id": "QSDK-R24D69",
		"ok": exact,
		"failure_code": (
			""
			if exact
			else "QSDK_R24D69_NATIVE_EFFECTIVE_IMPULSE_LIMIT_ZERO_WORLD_INVALID"
		),
		"projection_control_count": direct_projection_count,
		"native_effective_safe_count": native_effective_safe_count,
		"adjacent_unsafe_count": adjacent_unsafe_count,
		"binary32_maximality_count": binary32_maximality_count,
		"source_algebra_identity_count": source_algebra_identity_count,
		"production_route_projection_count": int(
			route_counts.get("exact_route_projection_count", 0)
		),
		"production_route_safe_readback_count": int(
			route_counts.get("safe_route_readback_count", 0)
		),
		"identity_mutation_rejection_count": identity_mutation_rejection_count,
		"ordered_projection_receipts": ordered_projection_receipts,
		"production_route_guard_receipt": guard_receipt,
		"published_cap_changed": false,
		"empirical_margin_added": false,
		"raw_measurement_clamped": false,
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


static func _route_projection_counts(guard_receipt: Dictionary) -> Dictionary:
	var values: Variant = guard_receipt.get("ordered_bindings")
	if not values is Array or (values as Array).size() != 8:
		return {}
	var exact_route_projection_count := 0
	var safe_route_readback_count := 0
	for index in range(8):
		var value: Dictionary = (values as Array)[index]
		var projection := WorldScript.native_effective_impulse_limit_projection_v1(
			String(ORDERED_ACTUATOR_IDS[index]),
			float(ORDERED_PUBLISHED_CAPS_NMS[index]),
		)
		exact_route_projection_count += int(
			bool(projection.get("ok", false))
			and value == projection.merged(
				{
					"legacy_profile_binding_readback_nms": value.get(
						"legacy_profile_binding_readback_nms"
					),
					"guarded_host_readback_nms": value.get(
						"guarded_host_readback_nms"
					),
				},
				true,
			)
		)
		safe_route_readback_count += int(
			float(value.get("guarded_host_readback_nms", INF))
			== float(projection.get("configured_host_maximum_impulse_nms", NAN))
			and bool(value.get("native_effective_limit_not_above_published", false))
		)
	return {
		"exact_route_projection_count": exact_route_projection_count,
		"safe_route_readback_count": safe_route_readback_count,
	}


static func _f32(value: float) -> float:
	return float(PackedFloat32Array([value])[0])


## Decode the exact upper IEEE-754 binary64 neighbor without relying on decimal
## literal parsing.
static func _rear_hip_cap_adjacent_binary64_v1(direction: int) -> float:
	if direction == 1:
		return PackedByteArray(
			[0x9c, 0x38, 0x8b, 0x1a, 0x05, 0xdd, 0xac, 0x3f]
		).decode_double(0)
	return NAN


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


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_zero_world_v1"
		),
		"gate_id": "QSDK-R24D69",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
