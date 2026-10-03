extends SceneTree

## BR3A ground truth is semantic contact evidence, never proximity. This locks
## external ownership, same-creature exclusion, role/layer/tag allowlists, and
## the upward-normal cone before the support state machine can consume them.

const Helper := preload("res://tests/helpers/lab_contact_test_helper.gd")
const GroundQualifierScript := preload(
	"res://scripts/lab/mechanics/ground_qualifier.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A self-contact exclusion and ground qualification ===")
	var built: Dictionary = GroundQualifierScript.build_config({
		"allowed_roles": ["foot_support", "hand_support"],
		"allowed_surface_layers": [1],
		"allowed_surface_tags": ["lab_ground"],
		"up_world": Vector3.UP,
		"minimum_up_dot": 0.8,
	})
	_check(bool(built["ok"]),
		"ground qualifier config builds with explicit semantic allowlists")
	var config: Dictionary = built["config"]
	var external_patch := _only_patch(Helper.canonical_frame(1, [
		Helper.raw_contact(1, 0, Vector3.ZERO),
	]))
	var external: Dictionary = GroundQualifierScript.qualify(
		external_patch, config)
	_check(bool(external["observation_valid"])
		and bool(external["qualifies_as_ground"])
		and (external["geometry_fields_consulted"] as Array).is_empty(),
		"allowed external upward contact qualifies without geometry hints")

	var absent_near_ground := external_patch.duplicate(true)
	absent_near_ground["contact_present"] = false
	absent_near_ground["point_world"] = Vector3(0.0, 1.0e-6, 0.0)
	var absent: Dictionary = GroundQualifierScript.qualify(
		absent_near_ground, config)
	_check(not bool(absent["qualifies_as_ground"])
		and (absent["rejection_reasons"] as Array).has(
			"CONTACT_NOT_PRESENT"),
		"near-ground geometry cannot manufacture contact or support")

	var self_patch := _only_patch(Helper.canonical_frame(2, [
		Helper.raw_contact(2, 0, Vector3.ZERO, {
			"counterparty_kind": "creature",
			"counterparty_semantic_id": "torso_body",
			"counterparty_creature_id": "creature_alpha",
		}),
	]))
	var self_result: Dictionary = GroundQualifierScript.qualify(
		self_patch, config)
	_check(bool(self_result["observation_valid"])
		and not bool(self_result["qualifies_as_ground"])
		and (self_result["rejection_reasons"] as Array).has(
			"SAME_CREATURE_CONTACT_EXCLUDED")
		and (self_result["rejection_reasons"] as Array).has(
			"CONTACT_OWNERSHIP_NOT_EXTERNAL"),
		"foot pressing its own creature is contact but never ground support")

	var other_creature_patch := _only_patch(Helper.canonical_frame(3, [
		Helper.raw_contact(3, 0, Vector3.ZERO, {
			"counterparty_kind": "creature",
			"counterparty_semantic_id": "other_creature_body",
			"counterparty_creature_id": "creature_beta",
		}),
	]))
	var other_creature: Dictionary = GroundQualifierScript.qualify(
		other_creature_patch, config)
	_check(not bool(other_creature["qualifies_as_ground"])
		and (other_creature["rejection_reasons"] as Array).has(
			"CONTACT_OWNERSHIP_NOT_EXTERNAL"),
		"another creature is an external collision, not an allowed ground surface")

	var wall_patch := external_patch.duplicate(true)
	wall_patch["normal_world"] = Vector3.RIGHT
	var wall: Dictionary = GroundQualifierScript.qualify(wall_patch, config)
	_check(not bool(wall["qualifies_as_ground"])
		and (wall["rejection_reasons"] as Array).has(
			"CONTACT_NORMAL_OUTSIDE_SUPPORT_CONE"),
		"wall contact outside the upward cone is not ground support")
	var wrong_tag_patch := external_patch.duplicate(true)
	wrong_tag_patch["surface_tag"] = "hazard_surface"
	var wrong_tag: Dictionary = GroundQualifierScript.qualify(
		wrong_tag_patch, config)
	_check(not bool(wrong_tag["qualifies_as_ground"])
		and (wrong_tag["rejection_reasons"] as Array).has(
			"CONTACT_SURFACE_TAG_NOT_ALLOWED"),
		"unregistered surface tag fails semantic ground qualification")

	var tampered_config := config.duplicate(true)
	tampered_config["minimum_up_dot"] = 0.0
	var tampered: Dictionary = GroundQualifierScript.qualify(
		external_patch, tampered_config)
	_check(not bool(tampered["observation_valid"])
		and (tampered["validation_reasons"] as Array).has(
			"GROUND_QUALIFIER_CONFIG_INVALID"),
		"config digest exposes post-registration threshold changes")
	_finish()


func _only_patch(frame: Dictionary) -> Dictionary:
	assert(bool(frame["ok"]) and int(frame["canonical_patch_count"]) == 1)
	return frame["patches"][0]


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
