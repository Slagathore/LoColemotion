extends SceneTree

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const WholeBodyStateScript := preload(
	"res://scripts/lab/mechanics/whole_body_state.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab whole-body-state contract ===")
	_test_mass_weighted_aggregation_is_deterministic()
	_test_uncertified_angular_momentum_is_explicitly_unavailable()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_mass_weighted_aggregation_is_deterministic() -> void:
	print("- aggregates bodies in stable ID order")
	var body_a := _body(
		3.0,
		[0.0, 2.0, 0.0],
		[1.0, 0.0, 0.0])
	var body_z := _body(
		1.0,
		[2.0, 0.0, 0.0],
		[0.0, 1.0, 0.0])

	var reverse_insertion: Dictionary = {}
	reverse_insertion["body_z"] = body_z
	reverse_insertion["body_a"] = body_a
	var forward_insertion: Dictionary = {}
	forward_insertion["body_a"] = body_a
	forward_insertion["body_z"] = body_z

	var first: Dictionary = WholeBodyStateScript.from_frame(
		_frame(reverse_insertion))
	var second: Dictionary = WholeBodyStateScript.from_frame(
		_frame(forward_insertion))

	_check(
		first["body_ids"] == ["body_a", "body_z"],
		"body IDs are sorted independently of dictionary insertion order")
	_check(
		is_equal_approx(float(first["total_mass_kg"]), 4.0),
		"total mass is the sum of valid body masses")
	_check(
		_vec3(first["center_of_mass_world_m"])
			.is_equal_approx(Vector3(0.5, 1.5, 0.0)),
		"center of mass is mass weighted")
	_check(
		_vec3(first["linear_momentum_world_n_s"])
			.is_equal_approx(Vector3(3.0, 1.0, 0.0)),
		"linear momentum sums mass times velocity")
	_check(
		_vec3(first["center_of_mass_velocity_world_m_s"])
			.is_equal_approx(Vector3(0.75, 0.25, 0.0)),
		"center-of-mass velocity is total momentum divided by total mass")
	_check(
		first["frame_id"] == 12
			and first["physics_step_id"] == 12
			and first["capture_epoch"] == 12
			and bool(first["finite"]),
		"aggregate retains frame identity and finite status")
	_check(
		CanonicalJsonScript.sha256(first) == CanonicalJsonScript.sha256(second),
		"equivalent body maps produce identical canonical aggregate bytes")
	_check(
		first.is_read_only()
			and (first["body_ids"] as Array).is_read_only()
			and (first["availability"] as Dictionary).is_read_only(),
		"whole-body aggregate is recursively immutable")


func _test_uncertified_angular_momentum_is_explicitly_unavailable() -> void:
	print("- never fabricates an uncertified rotational channel")
	var aggregate: Dictionary = WholeBodyStateScript.from_frame(_frame({
		"body": _body(
			2.0,
			[1.0, 2.0, 3.0],
			[0.0, 0.0, 0.0]),
	}))
	var path := "/angular_momentum_about_com_world_n_m_s"
	var availability: Dictionary = aggregate["availability"]
	var entry: Dictionary = availability[path]
	_check(
		aggregate["angular_momentum_about_com_world_n_m_s"] == null,
		"uncertified angular momentum is null rather than a fabricated zero")
	_check(
		entry["status"] == "unavailable",
		"availability explicitly marks the rotational channel unavailable")
	_check(
		entry["reason"] == "BR1_INERTIA_CHANNEL_NOT_CERTIFIED",
		"availability supplies the stable BR1 certification reason")
	_check(
		entry["source"] == "whole_body_state_v1",
		"availability names the oracle that withheld the channel")
	var repeated: Dictionary = WholeBodyStateScript.from_frame(_frame({
		"body": _body(
			2.0,
			[1.0, 2.0, 3.0],
			[0.0, 0.0, 0.0]),
	}))
	_check(
		CanonicalJsonScript.sha256(aggregate)
			== CanonicalJsonScript.sha256(repeated),
		"availability and aggregate values are deterministic across repeated evaluation")


func _frame(bodies: Dictionary) -> Dictionary:
	return {
		"frame_id": 12,
		"physics_step_id": 12,
		"capture_epoch": 12,
		"bodies": bodies,
	}


func _body(
		mass_kg: float,
		center_of_mass_world: Array,
		linear_velocity: Array) -> Dictionary:
	return {
		"mass_kg": mass_kg,
		"center_of_mass_world": center_of_mass_world,
		"linear_velocity": linear_velocity,
		"finite": true,
	}


func _vec3(value: Array) -> Vector3:
	return Vector3(
		float(value[0]),
		float(value[1]),
		float(value[2]))
