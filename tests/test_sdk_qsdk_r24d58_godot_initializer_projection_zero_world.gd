extends SceneTree
# gdlint: disable=max-line-length

## Pure R58 native-representation qualification. This test loads the exact
## Godot SDK and compiles the existing blueprint, but it creates no Node, RID,
## model, world, or solver step.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D58_GODOT_INITIALIZER_PROJECTION_ZERO_WORLD "
const NEIGHBOR_PROBE_DELTA_RAD := 2.0e-7


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D58_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D58_GODOT_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D58_CONTEXT_FAILED", context)
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	if not bool(blueprint.get("ok", false)):
		return _failure("QSDK_R24D58_BLUEPRINT_FAILED", blueprint)
	var projection := WorldScript.native_initializer_projection_contract_v2(
		sdk, blueprint
	)
	var repeat := WorldScript.native_initializer_projection_contract_v2(
		sdk, blueprint
	)
	if not bool(projection.get("ok", false)) or not bool(repeat.get("ok", false)):
		return _failure("QSDK_R24D58_PROJECTION_FAILED", projection)

	var parent := Basis(Vector3.BACK, 0.37).orthonormalized()
	var lower := WorldScript.native_initializer_scalar_projection_v1(
		parent, 1.55 - NEIGHBOR_PROBE_DELTA_RAD
	)
	var nominal := WorldScript.native_initializer_scalar_projection_v1(parent, 1.55)
	var upper := WorldScript.native_initializer_scalar_projection_v1(
		parent, 1.55 + NEIGHBOR_PROBE_DELTA_RAD
	)
	var negative := WorldScript.native_initializer_scalar_projection_v1(parent, -1.55)
	var zero := WorldScript.native_initializer_scalar_projection_v1(parent, 0.0)
	var nonfinite := WorldScript.native_initializer_scalar_projection_v1(parent, NAN)
	var scalar_controls := [lower, nominal, upper, negative, zero]
	for scalar_value in scalar_controls:
		if not bool((scalar_value as Dictionary).get("ok", false)):
			return _failure("QSDK_R24D58_SCALAR_CONTROL_FAILED", scalar_value)

	var changed_manifest := blueprint.duplicate(true)
	(changed_manifest["initializer_manifest"] as Dictionary)[
		"ordered_joint_positions_rad"
	][0] = 1.54
	var swapped_order := blueprint.duplicate(true)
	var swapped_ids: Array = (
		(swapped_order["initializer_manifest"] as Dictionary)["ordered_joint_ids"]
	)
	var first_id: Variant = swapped_ids[0]
	swapped_ids[0] = swapped_ids[1]
	swapped_ids[1] = first_id
	var missing_basis := blueprint.duplicate(true)
	(missing_basis["bases"] as Dictionary).erase("front_left_upper")
	var wrong_digest := blueprint.duplicate(true)
	wrong_digest["initializer_manifest_sha256"] = "sha256:" + "0".repeat(64)
	var mutation_results := {
		"changed_manifest_without_digest_rebind": not bool(
			WorldScript.native_initializer_projection_contract_v2(
				sdk, changed_manifest
			).get("ok", false)
		),
		"swapped_joint_order": not bool(
			WorldScript.native_initializer_projection_contract_v2(
				sdk, swapped_order
			).get("ok", false)
		),
		"missing_native_basis": not bool(
			WorldScript.native_initializer_projection_contract_v2(
				sdk, missing_basis
			).get("ok", false)
		),
		"wrong_initializer_digest": not bool(
			WorldScript.native_initializer_projection_contract_v2(
				sdk, wrong_digest
			).get("ok", false)
		),
	}
	var mutation_rejection_count := 0
	for rejected in mutation_results.values():
		mutation_rejection_count += int(bool(rejected))

	var ordered_projections: Array = projection["ordered_joint_projections"]
	var maximum_authored_projection_delta_rad := 0.0
	var sign_preservation_count := 0
	for row_value in ordered_projections:
		var row: Dictionary = row_value
		var authored := float(row["authored_joint_angle_rad"])
		var projected := float(row["native_projected_joint_angle_rad"])
		maximum_authored_projection_delta_rad = maxf(
			maximum_authored_projection_delta_rad,
			absf(float(row["authored_to_native_projection_delta_rad"])),
		)
		sign_preservation_count += int(signf(authored) == signf(projected))
	var lower_projected := float(lower["native_projected_joint_angle_rad"])
	var nominal_projected := float(nominal["native_projected_joint_angle_rad"])
	var upper_projected := float(upper["native_projected_joint_angle_rad"])
	var exact := (
		String(projection.get("projection_profile_id", ""))
		== WorldScript.INITIALIZER_NATIVE_PROJECTION_PROFILE_ID
		and String(projection.get("sha256", "")) == String(repeat.get("sha256", ""))
		and int(projection.get("projection_count", -1)) == 8
		and float(projection.get("readback_tolerance_rad", NAN)) == 1.0e-8
		and not bool(projection.get("readback_tolerance_changed_from_r24d57", true))
		and not bool(projection.get("authored_initializer_changed", true))
		and sign_preservation_count == 8
		and lower_projected < nominal_projected
		and nominal_projected < upper_projected
		and float(negative["native_projected_joint_angle_rad"]) < 0.0
		and float(zero["native_projected_joint_angle_rad"]) == 0.0
		and not bool(nonfinite.get("ok", false))
		and mutation_rejection_count == mutation_results.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d58_godot_initializer_projection_zero_world_v1",
		"gate_id": "QSDK-R24D58",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D58_ZERO_WORLD_CONJUNCTION_INVALID",
		"projection_receipt": projection,
		"projection_profile_id": String(projection.get("projection_profile_id", "")),
		"projection_count": int(projection.get("projection_count", -1)),
		"projection_repeat_digest_match_count": int(
			String(projection.get("sha256", "")) == String(repeat.get("sha256", ""))
		),
		"sign_preservation_count": sign_preservation_count,
		"neighbor_probe_delta_rad": NEIGHBOR_PROBE_DELTA_RAD,
		"neighbor_ordering_control_count": int(
			lower_projected < nominal_projected and nominal_projected < upper_projected
		),
		"negative_sign_control_count": int(
			float(negative["native_projected_joint_angle_rad"]) < 0.0
		),
		"zero_control_count": int(
			float(zero["native_projected_joint_angle_rad"]) == 0.0
		),
		"nonfinite_refusal_count": int(not bool(nonfinite.get("ok", false))),
		"mutation_ids": mutation_results.keys(),
		"mutation_rejection_count": mutation_rejection_count,
		"maximum_authored_projection_delta_rad": maximum_authored_projection_delta_rad,
		"readback_tolerance_rad": float(
			projection.get("readback_tolerance_rad", NAN)
		),
		"readback_tolerance_changed_from_r24d57": bool(
			projection.get("readback_tolerance_changed_from_r24d57", true)
		),
		"authored_initializer_changed": bool(
			projection.get("authored_initializer_changed", true)
		),
		"forced_failure_projection_control_count": 1,
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


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d58_godot_initializer_projection_zero_world_v1",
		"gate_id": "QSDK-R24D58",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
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
