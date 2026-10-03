extends SceneTree

## BR3A pure oracle: callback-local manifold indices collapse into one stable
## semantic shape-pair patch, while saturation and incoherent metadata fail
## closed before support logic sees the record.

const Helper := preload("res://tests/helpers/lab_contact_test_helper.gd")
const CapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")
const CanonicalizerScript := preload(
	"res://scripts/lab/mechanics/contact_canonicalizer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A canonical external-contact dedup ===")
	var raw := [
		Helper.raw_contact(1, 7, Vector3(-0.1, 0.0, 0.0)),
		Helper.raw_contact(1, 2, Vector3(0.1, 0.0, 0.0)),
	]
	var frame: Dictionary = Helper.canonical_frame(1, raw)
	_check(bool(frame["ok"])
		and int(frame["raw_contact_count"]) == 2
		and int(frame["canonical_patch_count"]) == 1,
		"two raw points on one shape pair canonicalize to one patch")
	var patch: Dictionary = frame["patches"][0]
	_check(int(patch["raw_point_count"]) == 2
		and (patch["point_world"] as Vector3).distance_to(Vector3.ZERO)
			< 1.0e-9
		and absf(float(patch["normal_impulse_ns"]) - 20.0) < 1.0e-9,
		"patch reports centroid and summed impulse without dropping points")
	_check(String(patch["ownership"]) == "creature_environment"
		and not bool(patch["same_creature_contact"])
		and bool(patch["canonical_pair_side"]),
		"external ownership is explicit and oriented to the observed creature")

	var reordered := [
		Helper.raw_contact(2, 99, Vector3(0.11, 0.0, 0.0)),
		Helper.raw_contact(2, 4, Vector3(-0.09, 0.0, 0.0)),
	]
	var reordered_frame: Dictionary = Helper.canonical_frame(2, reordered)
	_check(String((reordered_frame["patches"][0] as Dictionary)[
		"contact_patch_id"]) == String(patch["contact_patch_id"]),
		"patch identity survives raw-index reorder and small point motion")

	var built: Dictionary = CapacityScript.derive({
		"body_id": Helper.BODY_ID,
		"expected_simultaneous_raw_points": 1,
		"safety_margin_raw_points": 1,
	})
	var saturated: Dictionary = CapacityScript.observe(
		built["capacity"], 2)
	var blocked: Dictionary = CanonicalizerScript.canonicalize(
		raw, saturated, Helper.frame_context(1))
	_check(not bool(blocked["ok"])
		and (blocked["invalid_reasons"] as Array).has(
			"CONTACT_CAPACITY_OBSERVATION_INVALID"),
		"saturated raw evidence cannot produce an apparently complete patch")

	var incoherent := raw.duplicate(true)
	(incoherent[1] as Dictionary)["surface_tag"] = "different_surface"
	var incoherent_frame: Dictionary = Helper.canonical_frame(1, incoherent)
	_check(not bool(incoherent_frame["ok"])
		and (incoherent_frame["invalid_reasons"] as Array).has(
			"CONTACT_PATCH_METADATA_INCOHERENT:surface_tag"),
		"one shape-pair patch cannot silently merge conflicting semantics")
	_finish()


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
