extends SceneTree

## BR3A pure oracle: BEGIN/PERSIST/END events follow canonical patch evidence,
## not callback indices or foot height, and a missing capture frame breaks the
## lifetime lineage rather than inventing an end time.

const Helper := preload("res://tests/helpers/lab_contact_test_helper.gd")
const LifetimeTrackerScript := preload(
	"res://scripts/lab/mechanics/contact_lifetime_tracker.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A stable contact lifetime ===")
	var tracker = LifetimeTrackerScript.new()
	var first_frame: Dictionary = Helper.canonical_frame(1, [
		Helper.raw_contact(1, 8, Vector3(-0.1, 0.0, 0.0)),
		Helper.raw_contact(1, 3, Vector3(0.1, 0.0, 0.0)),
	])
	var first: Dictionary = tracker.initialize(first_frame)
	var patch_id := String((first["patches"][0] as Dictionary)[
		"contact_patch_id"])
	_check(bool(first["ok"])
		and String((first["events"][0] as Dictionary)["event"]) == "BEGIN"
		and int((first["patches"][0] as Dictionary)["lifetime"][
			"age_ticks"]) == 1,
		"first visible canonical patch emits BEGIN at age one")

	var second_frame: Dictionary = Helper.canonical_frame(2, [
		Helper.raw_contact(2, 1, Vector3(0.11, 0.0, 0.0)),
		Helper.raw_contact(2, 9, Vector3(-0.09, 0.0, 0.0)),
	])
	var second: Dictionary = tracker.advance(second_frame)
	_check(bool(second["ok"])
		and String((second["events"][0] as Dictionary)["event"])
			== "PERSIST"
		and String((second["patches"][0] as Dictionary)[
			"contact_patch_id"]) == patch_id
		and int((second["patches"][0] as Dictionary)["lifetime"][
			"age_ticks"]) == 2,
		"next coherent frame persists the patch despite raw point reordering")

	var absent_frame: Dictionary = Helper.canonical_frame(3, [])
	var ended: Dictionary = tracker.advance(absent_frame)
	_check(bool(ended["ok"])
		and int(ended["active_patch_count"]) == 0
		and String((ended["events"][0] as Dictionary)["event"]) == "END"
		and String((ended["events"][0] as Dictionary)[
			"contact_patch_id"]) == patch_id
		and int((ended["events"][0] as Dictionary)[
			"last_present_step_id"]) == 2,
		"first coherent absent frame emits END with exact last-present step")

	var gap_frame: Dictionary = Helper.canonical_frame(5, [])
	var gap: Dictionary = tracker.advance(gap_frame)
	_check(not bool(gap["ok"])
		and bool(gap["requires_reinitialize"])
		and (gap["invalid_reasons"] as Array).has(
			"CONTACT_LIFETIME_STEP_DISCONTINUITY"),
		"missing frame breaks lineage without manufacturing contact history")
	var resumed: Dictionary = tracker.initialize(gap_frame)
	_check(bool(resumed["ok"])
		and bool(resumed["initialized_this_frame"])
		and int(resumed["active_patch_count"]) == 0,
		"explicit initialization starts a new lifetime segment after a gap")
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
