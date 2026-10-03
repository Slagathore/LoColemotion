class_name LabSdkFrictionLadderSledRig
extends RefCounted

## Isolated Godot/Jolt friction-ladder wrapper.
##
## The accepted L1.1 rig owns the sled geometry and observation boundary. This
## wrapper replaces both materials before SceneTree insertion so every P5M.1
## cell differs only in the preregistered authored friction value.

const BaseRigScript := preload("res://scripts/lab/rigs/friction_sled_rig.gd")

const FIXTURE_ID := "SDK.P5M.1.godot_jolt_friction_ladder_sled.v1"
const AUTHORED_FRICTION_VALUES := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.8]
const FLOOR_SIZE_M := Vector3(200.0, 1.0, 8.0)
const RUN_ID_PREFIX := "sdk_p5m1_godot_jolt_friction"
const CAPTURE_STREAM_PREFIX := "sdk_p5m1_friction_contact_stream"
const BW3_FIXTURE_ID := "SDK.BW3.godot_jolt_material_sled.v1"
const BW3_AUTHORED_FRICTION_VALUES := [0.0, 0.3, 0.7, 1.2]
const BW3_RUN_ID_PREFIX := "sdk_bw3_godot_jolt_friction"
const BW3_CAPTURE_STREAM_PREFIX := "sdk_bw3_friction_contact_stream"
const BW3R_FIXTURE_ID := "SDK.BW3R.godot_jolt_material_sled.v1"
const BW3R_AUTHORED_FRICTION_VALUES := [0.0, 0.25, 0.55, 1.1]
const BW3R_RUN_ID_PREFIX := "sdk_bw3r_godot_jolt_friction"
const BW3R_CAPTURE_STREAM_PREFIX := "sdk_bw3r_friction_contact_stream"
const BW4_FIXTURE_ID := "SDK.BW4.godot_jolt_material_sled.v1"
const BW4_AUTHORED_FRICTION_VALUES := [0.0, 0.15, 0.5, 0.9, 1.4]
const BW4_RUN_ID_PREFIX := "sdk_bw4_godot_jolt_friction"
const BW4_CAPTURE_STREAM_PREFIX := "sdk_bw4_friction_contact_stream"
const BW5V_FIXTURE_ID := "SDK.BW5V.godot_jolt_material_sled.v1"
const BW5V_AUTHORED_FRICTION_VALUES := [0.0, 0.05, 0.65, 1.3]
const BW5V_RUN_ID_PREFIX := "sdk_bw5v_godot_jolt_friction"
const BW5V_CAPTURE_STREAM_PREFIX := "sdk_bw5v_friction_contact_stream"
const BW5C_FIXTURE_ID := "SDK.BW5C.godot_jolt_material_sled.v1"
const BW5C_AUTHORED_FRICTION_VALUES := [0.0, 0.12, 0.48, 0.95, 1.5]
const BW5C_RUN_ID_PREFIX := "sdk_bw5c_godot_jolt_friction"
const BW5C_CAPTURE_STREAM_PREFIX := "sdk_bw5c_friction_contact_stream"
const BW20F_FIXTURE_ID := "SDK.BW20F.godot_jolt_material_sled.v1"
const BW20F_AUTHORED_FRICTION_VALUES := [0.0, 0.09, 0.37, 0.76, 1.18]
const BW20F_RUN_ID_PREFIX := "sdk_bw20f_godot_jolt_friction"
const BW20F_CAPTURE_STREAM_PREFIX := "sdk_bw20f_friction_contact_stream"


static func build(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	return _build_campaign(
		capture_clock,
		observer_profile,
		friction,
		AUTHORED_FRICTION_VALUES,
		FIXTURE_ID,
		RUN_ID_PREFIX,
		CAPTURE_STREAM_PREFIX,
		"seven preregistered P5M.1 cells",
	)


static func build_bw3(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	return _build_campaign(
		capture_clock,
		observer_profile,
		friction,
		BW3_AUTHORED_FRICTION_VALUES,
		BW3_FIXTURE_ID,
		BW3_RUN_ID_PREFIX,
		BW3_CAPTURE_STREAM_PREFIX,
		"four preregistered BW3 characterization cells",
	)


static func build_bw3r(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	return _build_campaign(
		capture_clock,
		observer_profile,
		friction,
		BW3R_AUTHORED_FRICTION_VALUES,
		BW3R_FIXTURE_ID,
		BW3R_RUN_ID_PREFIX,
		BW3R_CAPTURE_STREAM_PREFIX,
		"four preregistered BW3R characterization cells",
	)


static func build_bw4(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	return _build_campaign(
		capture_clock,
		observer_profile,
		friction,
		BW4_AUTHORED_FRICTION_VALUES,
		BW4_FIXTURE_ID,
		BW4_RUN_ID_PREFIX,
		BW4_CAPTURE_STREAM_PREFIX,
		"five preregistered BW4 characterization cells",
	)


static func build_bw5v(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	return _build_campaign(
		capture_clock,
		observer_profile,
		friction,
		BW5V_AUTHORED_FRICTION_VALUES,
		BW5V_FIXTURE_ID,
		BW5V_RUN_ID_PREFIX,
		BW5V_CAPTURE_STREAM_PREFIX,
		"four preregistered BW5V characterization cells",
	)


static func build_bw5c(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	return _build_campaign(
		capture_clock,
		observer_profile,
		friction,
		BW5C_AUTHORED_FRICTION_VALUES,
		BW5C_FIXTURE_ID,
		BW5C_RUN_ID_PREFIX,
		BW5C_CAPTURE_STREAM_PREFIX,
		"five preregistered BW5C characterization cells",
	)


static func build_bw20f(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	return _build_campaign(
		capture_clock,
		observer_profile,
		friction,
		BW20F_AUTHORED_FRICTION_VALUES,
		BW20F_FIXTURE_ID,
		BW20F_RUN_ID_PREFIX,
		BW20F_CAPTURE_STREAM_PREFIX,
		"five preregistered BW20F characterization cells",
	)


static func _build_campaign(
		capture_clock,
		observer_profile: Dictionary,
		friction: float,
		allowed_friction_values: Array,
		fixture_id: String,
		run_id_prefix: String,
		capture_stream_prefix: String,
		allowed_value_description: String) -> Dictionary:
	if (
		not is_finite(friction)
		or not _is_allowed_friction(friction, allowed_friction_values)
	):
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": fixture_id,
			"configuration_errors":
			[
				{
					"code": "SDK_FRICTION_LADDER_VALUE_INVALID",
					"path": "/friction",
					"message":
					"Friction must be one of the %s" % allowed_value_description,
				}
			],
		}
	var seed_friction := clampf(friction, 0.0, 1.0)
	var rig: Dictionary = BaseRigScript.build(
		capture_clock,
		observer_profile,
		{},
		{"friction": seed_friction},
	)
	if not bool(rig.get("ok", false)):
		return rig

	var world: Node3D = rig["world"]
	var body: RigidBody3D = rig["body"]
	var floor: StaticBody3D = rig["floor"]
	var token := _friction_token(friction)
	var run_id := "%s_%s" % [run_id_prefix, token]
	var capture_stream_id := "%s_%s" % [capture_stream_prefix, token]
	var node_prefix := "SdkP5M1"
	if fixture_id == BW3_FIXTURE_ID:
		node_prefix = "SdkBW3"
	elif fixture_id == BW3R_FIXTURE_ID:
		node_prefix = "SdkBW3R"
	elif fixture_id == BW4_FIXTURE_ID:
		node_prefix = "SdkBW4"
	elif fixture_id == BW5V_FIXTURE_ID:
		node_prefix = "SdkBW5V"
	elif fixture_id == BW5C_FIXTURE_ID:
		node_prefix = "SdkBW5C"
	elif fixture_id == BW20F_FIXTURE_ID:
		node_prefix = "SdkBW20F"
	world.name = "%sFrictionLadderSled%s" % [node_prefix, token]
	body.set("run_id", run_id)
	body.set("capture_stream_id", capture_stream_id)
	body.name = "%sObservedSled%s" % [node_prefix, token]
	floor.name = "%sFrictionFloor%s" % [node_prefix, token]

	var floor_collision := floor.get_child(0) as CollisionShape3D
	if floor_collision == null or not floor_collision.shape is BoxShape3D:
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": fixture_id,
			"configuration_errors":
			[
				{
					"code": "SDK_FRICTION_LADDER_FLOOR_SHAPE_INVALID",
					"path": "/floor",
					"message": "Expected the inherited isolated box floor",
				}
			],
		}
	(floor_collision.shape as BoxShape3D).size = FLOOR_SIZE_M
	floor.position.y = -0.5 * FLOOR_SIZE_M.y

	var body_material := _material(friction)
	var floor_material := _material(friction)
	body.physics_material_override = body_material
	floor.physics_material_override = floor_material

	rig["fixture_id"] = fixture_id
	rig["run_id"] = run_id
	rig["capture_stream_id"] = capture_stream_id
	rig["floor_size_m"] = FLOOR_SIZE_M
	rig["material_contract"] = {
		"body": _material_receipt(body_material),
		"floor": _material_receipt(floor_material),
		"godot_pair_rule": "highest_friction_both_rough_v1",
		"authored_friction_cell": friction,
		"authored_value_outside_documented_range": friction > 1.0,
		"portable_material_coefficient": false,
		"locomotion_robustness": false,
	}
	return rig


static func _is_allowed_friction(
		friction: float,
		allowed_friction_values: Array) -> bool:
	for value in allowed_friction_values:
		if absf(friction - float(value)) <= 1.0e-9:
			return true
	return false


static func _friction_token(friction: float) -> String:
	return "%03d" % int(round(friction * 100.0))


static func _material(friction: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.rough = true
	material.bounce = 0.0
	material.absorbent = true
	return material


static func _material_receipt(material: PhysicsMaterial) -> Dictionary:
	return {
		"friction": material.friction,
		"rough": material.rough,
		"bounce": material.bounce,
		"absorbent": material.absorbent,
	}
