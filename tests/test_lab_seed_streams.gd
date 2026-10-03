extends SceneTree

const RandomStreamCapabilityScript := preload(
	"res://scripts/lab/random_stream_capability.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab named-seed stream tests ===")
	_test_repeatable_stream_and_draw_accounting()
	_test_named_streams_are_independent()
	_test_capability_exposes_no_mutation_api()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_repeatable_stream_and_draw_accounting() -> void:
	print("- repeats a named stream and counts every draw")
	var seed := RandomStreamCapabilityScript.derive_seed(42, &"disturbance")
	_check(
		seed >= 0 and seed <= 9007199254740991,
		"derived stream seed stays inside JSON's exact integer range")
	var first = RandomStreamCapabilityScript.create(&"disturbance", seed)
	var second = RandomStreamCapabilityScript.create(&"disturbance", seed)
	var first_values := [
		first.randf(),
		first.randf_range(-2.0, 3.0),
		first.randi(),
		first.randi_range(-5, 5),
		first.randfn(1.0, 0.25),
	]
	var second_values := [
		second.randf(),
		second.randf_range(-2.0, 3.0),
		second.randi(),
		second.randi_range(-5, 5),
		second.randfn(1.0, 0.25),
	]
	_check(first_values == second_values, "same root/name produces the same draw sequence")
	_check(first.draw_count == 5 and second.draw_count == 5,
		"every typed draw increments draw_count exactly once")
	var manifest: Dictionary = first.manifest_entry()
	_check(
		manifest["stream_id"] == "disturbance"
			and bool(manifest["consumed"])
			and int(manifest["draw_count"]) == 5,
		"manifest entry reports stream identity and consumption")
	_check(
		String(first.seed_sha256).begins_with("sha256:")
			and String(first.seed_sha256).length() == 71,
		"capability exposes seed provenance as a digest")


func _test_named_streams_are_independent() -> void:
	print("- unrelated draws cannot shift another named stream")
	var disturbance_seed := RandomStreamCapabilityScript.derive_seed(
		991,
		&"disturbance")
	var noise_seed := RandomStreamCapabilityScript.derive_seed(
		991,
		&"sensor_noise")
	var control = RandomStreamCapabilityScript.create(
		&"disturbance",
		disturbance_seed)
	var interleaved = RandomStreamCapabilityScript.create(
		&"disturbance",
		disturbance_seed)
	var unrelated = RandomStreamCapabilityScript.create(
		&"sensor_noise",
		noise_seed)
	var expected := [control.randf(), control.randf(), control.randf()]
	var actual: Array[float] = []
	actual.append(interleaved.randf())
	for unused_index in range(25):
		unrelated.randf()
	actual.append(interleaved.randf())
	unrelated.randi()
	actual.append(interleaved.randf())
	_check(expected == actual, "sensor-noise draws do not shift disturbance draws")
	_check(disturbance_seed != noise_seed, "different names derive different stream seeds")


func _test_capability_exposes_no_mutation_api() -> void:
	print("- public capability has draws and metadata, not generator authority")
	var capability = RandomStreamCapabilityScript.create(&"morphology", 123)
	_check(not capability.has_method("set_seed"), "no public seed setter exists")
	_check(not capability.has_method("reseed"), "no public reseed method exists")
	_check(not capability.has_method("randomize"), "no public randomize method exists")
	_check(not capability.has_method("get_generator"), "raw generator cannot be requested")
	_check(
		capability.stream_id == &"morphology" and capability.draw_count == 0,
		"read-only identity and draw-count metadata remain visible")
