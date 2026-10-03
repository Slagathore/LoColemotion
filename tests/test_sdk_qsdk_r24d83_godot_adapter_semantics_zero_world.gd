extends SceneTree
# gdlint: disable=max-line-length

## Focused R83 zero-world exercise of the exact production projection and
## property-readback paths. It compiles the frozen recovery blueprint and uses
## unattached Godot nodes, but no Node enters a tree and no RID-backed model,
## world, or solver step is created.

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
const MARKER := "QSDK_R24D83_GODOT_ADAPTER_SEMANTICS_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D83_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D83_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D83_ZERO_WORLD_CONTEXT_FAILED", context)
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	if not bool(blueprint.get("ok", false)):
		return _failure("QSDK_R24D83_ZERO_WORLD_BLUEPRINT_FAILED", blueprint)
	var initializer_projection := WorldScript.native_initializer_projection_contract_v2(
		sdk, blueprint
	)
	if not bool(initializer_projection.get("ok", false)):
		return _failure(
			"QSDK_R24D83_ZERO_WORLD_INITIALIZER_PROJECTION_FAILED",
			initializer_projection,
		)
	if (
		WorldScript.CANONICAL_TO_GODOT_HOST_JOINT_SIGN
		!= RouteScript.LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN
	):
		return _failure("QSDK_R24D83_ZERO_WORLD_HOST_SIGN_DISAGREEMENT")

	var ordered_initializer_rows: Array = initializer_projection[
		"ordered_joint_projections"
	]
	var ordered_projections: Array = []
	var ordered_property_readbacks: Array = []
	var exact_property_readback_count := 0
	var outward_lower_projection_count := 0
	var outward_upper_projection_count := 0
	var canonical_interval_not_shrunk_count := 0
	for index in range(WorldScript.ORDERED_JOINT_IDS.size()):
		var joint_id := String(WorldScript.ORDERED_JOINT_IDS[index])
		var initializer_row: Dictionary = ordered_initializer_rows[index]
		var joint_spec: Dictionary = blueprint["joint_by_id"][joint_id]
		if String(initializer_row.get("joint_id", "")) != joint_id:
			return _failure(
				"QSDK_R24D83_ZERO_WORLD_INITIALIZER_ORDER_INVALID:%s" % joint_id
			)
		var projection := WorldScript.godot_initial_relative_joint_limit_projection_v1(
			joint_id,
			float(initializer_row["native_projected_joint_angle_rad"]),
			float(joint_spec["lower_limit_rad"]),
			float(joint_spec["upper_limit_rad"]),
			WorldScript.CANONICAL_TO_GODOT_HOST_JOINT_SIGN,
		)
		if not bool(projection.get("ok", false)):
			return _failure(
				"QSDK_R24D83_ZERO_WORLD_LIMIT_PROJECTION_FAILED:%s" % joint_id,
				projection,
			)
		var joint := HingeJoint3D.new()
		joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		joint.set_param(
			HingeJoint3D.PARAM_LIMIT_LOWER,
			float(projection["projected_host_lower_rad"]),
		)
		joint.set_param(
			HingeJoint3D.PARAM_LIMIT_UPPER,
			float(projection["projected_host_upper_rad"]),
		)
		var readback := WorldScript.validate_godot_initial_relative_joint_limit_readback_v1(
			projection,
			float(joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER)),
			float(joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER)),
		)
		joint.free()
		if not bool(readback.get("ok", false)):
			return _failure(
				"QSDK_R24D83_ZERO_WORLD_LIMIT_READBACK_FAILED:%s" % joint_id,
				readback,
			)
		ordered_projections.append(projection)
		ordered_property_readbacks.append(readback)
		exact_property_readback_count += int(
			bool(readback.get("exact_projected_property_readback", false))
		)
		outward_lower_projection_count += int(
			bool(projection.get("lower_projection_outward_or_exact", false))
		)
		outward_upper_projection_count += int(
			bool(projection.get("upper_projection_outward_or_exact", false))
		)
		canonical_interval_not_shrunk_count += int(
			bool(projection.get("canonical_interval_not_shrunk", false))
		)

	var first_projection: Dictionary = ordered_projections[0]
	var joint_mutations := [
		_mutation(
			"unknown_joint_id",
			WorldScript.godot_initial_relative_joint_limit_projection_v1(
				"unknown_joint",
				float(first_projection["q0_rad"]),
				float(first_projection["canonical_lower_rad"]),
				float(first_projection["canonical_upper_rad"]),
				WorldScript.CANONICAL_TO_GODOT_HOST_JOINT_SIGN,
			),
		),
		_mutation(
			"wrong_host_sign",
			WorldScript.godot_initial_relative_joint_limit_projection_v1(
				String(first_projection["joint_id"]),
				float(first_projection["q0_rad"]),
				float(first_projection["canonical_lower_rad"]),
				float(first_projection["canonical_upper_rad"]),
				1.0,
			),
		),
		_mutation(
			"nonfinite_initial_position",
			WorldScript.godot_initial_relative_joint_limit_projection_v1(
				String(first_projection["joint_id"]),
				NAN,
				float(first_projection["canonical_lower_rad"]),
				float(first_projection["canonical_upper_rad"]),
				WorldScript.CANONICAL_TO_GODOT_HOST_JOINT_SIGN,
			),
		),
		_mutation(
			"swapped_canonical_bounds",
			WorldScript.godot_initial_relative_joint_limit_projection_v1(
				String(first_projection["joint_id"]),
				float(first_projection["q0_rad"]),
				float(first_projection["canonical_upper_rad"]),
				float(first_projection["canonical_lower_rad"]),
				WorldScript.CANONICAL_TO_GODOT_HOST_JOINT_SIGN,
			),
		),
		_mutation(
			"initial_position_outside_canonical_interval",
			WorldScript.godot_initial_relative_joint_limit_projection_v1(
				String(first_projection["joint_id"]),
				float(first_projection["canonical_upper_rad"]) + 0.01,
				float(first_projection["canonical_lower_rad"]),
				float(first_projection["canonical_upper_rad"]),
				WorldScript.CANONICAL_TO_GODOT_HOST_JOINT_SIGN,
			),
		),
		_mutation(
			"omitted_initial_offset",
			_validate_projection_mutation(
				first_projection,
				{"q0_rad": 0.0},
			),
		),
		_mutation(
			"canonical_passthrough_limits",
			_validate_projection_mutation(
				first_projection,
				{
					"projected_host_lower_rad": float(
						first_projection["canonical_lower_rad"]
					),
					"projected_host_upper_rad": float(
						first_projection["canonical_upper_rad"]
					),
				},
			),
		),
		_mutation(
			"swapped_projected_host_bounds",
			_validate_projection_mutation(
				first_projection,
				{
					"projected_host_lower_rad": float(
						first_projection["projected_host_upper_rad"]
					),
					"projected_host_upper_rad": float(
						first_projection["projected_host_lower_rad"]
					),
				},
			),
		),
		_mutation(
			"host_property_readback_mismatch",
			WorldScript.validate_godot_initial_relative_joint_limit_readback_v1(
				first_projection,
				float(first_projection["projected_host_lower_rad"]) + 0.01,
				float(first_projection["projected_host_upper_rad"]),
			),
		),
	]
	var joint_mutation_rejection_count := 0
	for mutation in joint_mutations:
		joint_mutation_rejection_count += int(bool(mutation.get("rejected", false)))

	var collision_projection := WorldScript.godot_recovery_collision_filter_projection_v1()
	if not bool(collision_projection.get("ok", false)):
		return _failure(
			"QSDK_R24D83_ZERO_WORLD_COLLISION_PROJECTION_FAILED",
			collision_projection,
		)
	var floor := StaticBody3D.new()
	var first_robot := RigidBody3D.new()
	var second_robot := RigidBody3D.new()
	floor.collision_layer = WorldScript.RECOVERY_FLOOR_COLLISION_LAYER
	floor.collision_mask = WorldScript.RECOVERY_FLOOR_COLLISION_MASK
	first_robot.collision_layer = WorldScript.RECOVERY_ROBOT_COLLISION_LAYER
	first_robot.collision_mask = WorldScript.RECOVERY_ROBOT_COLLISION_MASK
	second_robot.collision_layer = WorldScript.RECOVERY_ROBOT_COLLISION_LAYER
	second_robot.collision_mask = WorldScript.RECOVERY_ROBOT_COLLISION_MASK
	var collision_readback := WorldScript.validate_godot_recovery_collision_filter_readback_v1(
		int(floor.collision_layer),
		int(floor.collision_mask),
		int(first_robot.collision_layer),
		int(first_robot.collision_mask),
		int(second_robot.collision_layer),
		int(second_robot.collision_mask),
	)
	floor.free()
	first_robot.free()
	second_robot.free()
	if not bool(collision_readback.get("ok", false)):
		return _failure(
			"QSDK_R24D83_ZERO_WORLD_COLLISION_READBACK_FAILED",
			collision_readback,
		)
	var collision_mutations := [
		_mutation(
			"legacy_same_group",
			WorldScript.validate_godot_recovery_collision_filter_readback_v1(
				1, 0, 1, 1, 1, 1
			),
		),
		_mutation(
			"robot_self_collision_enabled",
			WorldScript.validate_godot_recovery_collision_filter_readback_v1(
				1, 2, 2, 2, 2, 2
			),
		),
		_mutation(
			"floor_mask_removed",
			WorldScript.validate_godot_recovery_collision_filter_readback_v1(
				1, 0, 2, 1, 2, 1
			),
		),
	]
	var collision_mutation_rejection_count := 0
	for mutation in collision_mutations:
		collision_mutation_rejection_count += int(
			bool(mutation.get("rejected", false))
		)

	var exact := (
		ordered_projections.size() == 8
		and ordered_property_readbacks.size() == 8
		and exact_property_readback_count == 8
		and outward_lower_projection_count == 8
		and outward_upper_projection_count == 8
		and canonical_interval_not_shrunk_count == 8
		and joint_mutation_rejection_count == joint_mutations.size()
		and bool(collision_readback.get("robot_floor_collision_enabled", false))
		and not bool(collision_readback.get("robot_robot_collision_enabled", true))
		and collision_mutation_rejection_count == collision_mutations.size()
	)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d83_godot_adapter_semantics_zero_world_v1"
		),
		"gate_id": "QSDK-R24D83",
		"ok": exact,
		"failure_code": (
			"" if exact else "QSDK_R24D83_ZERO_WORLD_CONJUNCTION_INVALID"
		),
		"initializer_projection_sha256": String(initializer_projection["sha256"]),
		"ordered_joint_projections": ordered_projections,
		"ordered_property_readbacks": ordered_property_readbacks,
		"joint_projection_count": ordered_projections.size(),
		"exact_joint_property_readback_count": exact_property_readback_count,
		"outward_lower_projection_count": outward_lower_projection_count,
		"outward_upper_projection_count": outward_upper_projection_count,
		"canonical_interval_not_shrunk_count": canonical_interval_not_shrunk_count,
		"joint_mutations": joint_mutations,
		"joint_mutation_rejection_count": joint_mutation_rejection_count,
		"collision_projection": collision_projection,
		"collision_property_readback": collision_readback,
		"collision_property_readback_count": 6,
		"robot_floor_collision_enabled_count": int(
			bool(collision_readback.get("robot_floor_collision_enabled", false))
		),
		"robot_robot_collision_disabled_count": int(
			not bool(collision_readback.get("robot_robot_collision_enabled", true))
		),
		"collision_mutations": collision_mutations,
		"collision_mutation_rejection_count": collision_mutation_rejection_count,
		"unattached_godot_property_node_count": 11,
		"node_entered_scene_tree_count": 0,
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


static func _validate_projection_mutation(
	projection: Dictionary,
	changes: Dictionary,
) -> Dictionary:
	var mutated := projection.duplicate(true)
	for key in changes:
		mutated[key] = changes[key]
	return WorldScript.validate_godot_initial_relative_joint_limit_readback_v1(
		mutated,
		float(projection["projected_host_lower_rad"]),
		float(projection["projected_host_upper_rad"]),
	)


static func _mutation(mutation_id: String, result: Dictionary) -> Dictionary:
	return {
		"mutation_id": mutation_id,
		"rejected": not bool(result.get("ok", false)),
		"failure_code": result.get("failure_code"),
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d83_godot_adapter_semantics_zero_world_v1"
		),
		"gate_id": "QSDK-R24D83",
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
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
