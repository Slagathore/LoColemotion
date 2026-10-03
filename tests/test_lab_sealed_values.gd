extends SceneTree

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ExpandedExperimentScript := preload("res://scripts/lab/expanded_experiment.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab sealed-value tests ===")
	_test_snapshot_detaches_and_freezes_recursively()
	_test_packed_arrays_cross_as_frozen_arrays()
	_test_expanded_experiment_seals_hash_identity()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_snapshot_detaches_and_freezes_recursively() -> void:
	print("- recursively detaches mutable source values")
	var source := {
		"frame": {
			"tick": 1,
			"position_m": [0.0, 1.0, 0.0],
		},
		"events": ["released"],
	}
	var sealed: Dictionary = FrozenValueScript.snapshot(source)
	var before := CanonicalJsonScript.stringify(sealed)
	source["frame"]["tick"] = 99
	source["frame"]["position_m"][1] = -100.0
	source["events"].append("mutated_after_seal")
	var after := CanonicalJsonScript.stringify(sealed)
	_check(sealed.is_read_only(), "root dictionary is read-only")
	_check(
		(sealed["frame"] as Dictionary).is_read_only(),
		"nested dictionary is read-only")
	_check(
		(sealed["frame"]["position_m"] as Array).is_read_only(),
		"nested array is read-only")
	_check(before == after, "source mutation cannot change sealed bytes")
	_check(int(sealed["frame"]["tick"]) == 1, "sealed scalar retains pre-mutation value")


func _test_packed_arrays_cross_as_frozen_arrays() -> void:
	print("- converts mutable packed arrays at the seal boundary")
	var source := PackedVector3Array([
		Vector3(1.0, 2.0, 3.0),
		Vector3(4.0, 5.0, 6.0),
	])
	var sealed: Variant = FrozenValueScript.snapshot(source)
	source[0] = Vector3.ZERO
	_check(typeof(sealed) == TYPE_ARRAY, "packed array becomes an ordinary Array")
	_check((sealed as Array).is_read_only(), "converted Array is read-only")
	_check(
		(sealed as Array)[0] == Vector3(1.0, 2.0, 3.0),
		"converted values are detached from the source")


func _test_expanded_experiment_seals_hash_identity() -> void:
	print("- seals compiled value, override history, text, and hash")
	var source := {
		"schema": "sporespore.lab.experiment.v1",
		"experiment_id": "L0_0_STATIONARY_GRAVITY_OFF",
	}
	var overrides := [{
		"source": "cli_override",
		"path": "/root_seed",
		"old_value": 0,
		"new_value": 42,
	}]
	var expanded = ExpandedExperimentScript.new(source, overrides)
	var digest_before := expanded.expanded_spec_sha256()
	source["experiment_id"] = "MUTATED"
	overrides[0]["new_value"] = 999
	_check(expanded.value().is_read_only(), "expanded scientific spec is read-only")
	_check(expanded.applied_overrides().is_read_only(), "override history is read-only")
	_check(expanded.assert_integrity(), "sealed bytes still match the sealed digest")
	_check(
		digest_before == expanded.expanded_spec_sha256(),
		"caller mutation cannot change expanded-spec identity")
