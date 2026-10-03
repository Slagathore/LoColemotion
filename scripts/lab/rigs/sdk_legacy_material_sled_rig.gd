class_name LabSdkLegacyMaterialSledRig
extends RefCounted

## Isolated SDK characterization wrapper for Candidate 35's legacy material.
##
## L1.1 intentionally rejects friction outside Godot's documented [0, 1]
## range. This wrapper preserves that released L1.1 contract: it builds the
## known contact-observation sled at an admissible seed value, then replaces
## both materials before the world enters the SceneTree. The result is an
## operational characterization of the accepted-but-out-of-documentation
## legacy value, not a change to the general lab fixture's valid domain.

const BaseRigScript := preload("res://scripts/lab/rigs/friction_sled_rig.gd")

const FIXTURE_ID := "SDK.P5M.godot_jolt_legacy_material_sled.v1"
const LEGACY_FRICTION := 1.8
const FRICTIONLESS_CONTROL := 0.0
const FLOOR_SIZE_M := Vector3(200.0, 1.0, 8.0)
const RUN_ID := "sdk_p5m_godot_jolt_legacy_material"
const CAPTURE_STREAM_ID := "sdk_p5m_legacy_material_contact_stream"


static func build(
		capture_clock,
		observer_profile: Dictionary,
		friction: float) -> Dictionary:
	if (
		not is_finite(friction)
		or (
			not is_equal_approx(friction, LEGACY_FRICTION)
			and not is_equal_approx(friction, FRICTIONLESS_CONTROL)
		)
	):
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors":
			[
				{
					"code": "SDK_LEGACY_FRICTION_PROFILE_INVALID",
					"path": "/friction",
					"message": "Only the frozen 1.8 legacy pair and 0.0 A/B control are valid",
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
	world.name = "SdkP5MLegacyMaterialSled"
	body.set("run_id", RUN_ID)
	body.set("capture_stream_id", CAPTURE_STREAM_ID)
	body.name = "SdkP5MObservedSled"
	floor.name = "SdkP5MLegacyMaterialFloor"

	var floor_collision := floor.get_child(0) as CollisionShape3D
	if floor_collision == null or not floor_collision.shape is BoxShape3D:
		return {
			"ok": false,
			"configuration_valid": false,
			"fixture_id": FIXTURE_ID,
			"configuration_errors":
			[
				{
					"code": "SDK_LEGACY_FLOOR_SHAPE_INVALID",
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

	rig["fixture_id"] = FIXTURE_ID
	rig["run_id"] = RUN_ID
	rig["capture_stream_id"] = CAPTURE_STREAM_ID
	rig["floor_size_m"] = FLOOR_SIZE_M
	rig["material_contract"] = {
		"body":
		{
			"friction": body_material.friction,
			"rough": body_material.rough,
			"bounce": body_material.bounce,
			"absorbent": body_material.absorbent,
		},
		"floor":
		{
			"friction": floor_material.friction,
			"rough": floor_material.rough,
			"bounce": floor_material.bounce,
			"absorbent": floor_material.absorbent,
		},
		"godot_pair_rule": "highest_friction_both_rough_v1",
		"legacy_value_outside_documented_range": friction > 1.0,
		"portable_material_coefficient": false,
	}
	return rig


static func _material(friction: float) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.rough = true
	material.bounce = 0.0
	material.absorbent = true
	return material
