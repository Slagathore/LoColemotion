extends SceneTree

## BR3A pure support-phase oracle. State changes come only from a semantically
## qualified canonical patch, persistent load, and separation evidence.
## Position/height/target fields are injected as poison pills and must remain
## absent from every consulted-field report.

const Helper := preload("res://tests/helpers/lab_contact_test_helper.gd")
const GroundQualifierScript := preload(
	"res://scripts/lab/mechanics/ground_qualifier.gd")
const SupportStateScript := preload(
	"res://scripts/lab/mechanics/contact_support_state.gd")

var _passed := 0
var _failed := 0
var _ground_config: Dictionary
var _support_config: Dictionary


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A SEARCH/TOUCH/LOAD/BEARING support state ===")
	var ground_built: Dictionary = GroundQualifierScript.build_config({
		"allowed_roles": ["foot_support"],
		"allowed_surface_layers": [1],
		"allowed_surface_tags": ["lab_ground"],
		"up_world": Vector3.UP,
		"minimum_up_dot": 0.8,
	})
	assert(bool(ground_built["ok"]))
	_ground_config = ground_built["config"]
	var support_built: Dictionary = SupportStateScript.build_config({
		"support_id": "left_foot_support",
		"sample_phase": "integrate_callback",
		"ground_qualifier_config_digest_sha256":
			String(_ground_config["config_digest_sha256"]),
		"contact_confirm_ticks": 2,
		"bearing_confirm_ticks": 2,
		"bearing_enter_load_n": 100.0,
		"bearing_exit_load_n": 60.0,
		"unloaded_load_n": 10.0,
		"maximum_separating_speed_mps": 0.05,
	})
	_check(bool(support_built["ok"]),
		"support config preregisters dwell, hysteresis, evidence quality, and ground config")
	_support_config = support_built["config"]

	var search: Dictionary = SupportStateScript.initialize(
		_support_config, _observation(1, false, true, 0.0, true, 0.0))
	_check(String(search["support_state"]) == "SEARCH"
		and not bool(search["support_guaranteed"]),
		"absent contact initializes SEARCH even with near-ground poison geometry")
	var touch: Dictionary = SupportStateScript.advance(
		_support_config, search,
		_observation(2, true, true, 0.0, true, 0.0))
	_check(String(touch["support_state"]) == "TOUCH"
		and not bool(touch["support_guaranteed"]),
		"first qualifying contact is TOUCH, not immediate support")
	var load: Dictionary = SupportStateScript.advance(
		_support_config, touch,
		_observation(3, true, true, 120.0, true, 0.0))
	_check(String(load["support_state"]) == "LOAD"
		and not bool(load["support_guaranteed"]),
		"contact dwell enters LOAD but one force sample is not bearing")
	var bearing: Dictionary = SupportStateScript.advance(
		_support_config, load,
		_observation(4, true, true, 120.0, true, 0.0))
	_check(String(bearing["support_state"]) == "BEARING"
		and bool(bearing["support_guaranteed"])
		and int((bearing["counters"] as Dictionary)[
			"bearing_entry_count"]) == 1,
		"persistent compressive load completes TOUCH to LOAD to BEARING")
	_check((bearing["geometry_fields_consulted"] as Array).is_empty(),
		"bearing decision never consults height, target, or desired pose")

	var hysteresis_hold: Dictionary = SupportStateScript.advance(
		_support_config, bearing,
		_observation(5, true, true, 70.0, true, 0.0))
	_check(String(hysteresis_hold["support_state"]) == "BEARING",
		"load inside the 60-100 N hysteresis band holds BEARING")
	var low_load_lost: Dictionary = SupportStateScript.advance(
		_support_config, hysteresis_hold,
		_observation(6, true, true, 59.0, true, 0.0))
	_check(String(low_load_lost["support_state"]) == "LOST"
		and not bool(low_load_lost["support_guaranteed"])
		and String(low_load_lost["transition_reason"])
			== "BEARING_LOAD_BELOW_EXIT_THRESHOLD",
		"unexpected load loss leaves BEARING through explicit LOST")

	var explicit_unload: Dictionary = SupportStateScript.advance(
		_support_config, bearing,
		_observation(5, true, true, 80.0, true, 0.0),
		true)
	var released: Dictionary = SupportStateScript.advance(
		_support_config, explicit_unload,
		_observation(6, false, true, 0.0, true, 0.1))
	_check(String(explicit_unload["support_state"]) == "UNLOAD"
		and String(released["support_state"]) == "SEARCH",
		"commanded release uses BEARING to UNLOAD to SEARCH, never LOST")

	var unavailable_load: Dictionary = SupportStateScript.advance(
		_support_config, load,
		_observation(4, true, false, 0.0, true, 0.0))
	_check(String(unavailable_load["support_state"]) == "LOAD"
		and unavailable_load["normal_load_n"] == null
		and not bool(unavailable_load["support_guaranteed"]),
		"unavailable load is null and cannot promote LOAD to BEARING")
	var missing_bearing_load: Dictionary = SupportStateScript.advance(
		_support_config, bearing,
		_observation(5, true, false, 0.0, true, 0.0))
	_check(String(missing_bearing_load["support_state"]) == "LOST"
		and String(missing_bearing_load["transition_reason"])
			== "BEARING_LOAD_MEASUREMENT_UNAVAILABLE",
		"loss of the load channel while bearing fails closed")

	var changed_patch_observation := _observation(
		5, true, true, 120.0, true, 0.0,
		{"counterparty_semantic_id": "second_floor"})
	var changed_patch: Dictionary = SupportStateScript.advance(
		_support_config, bearing, changed_patch_observation)
	_check(not bool(changed_patch["finite"])
		and bool(changed_patch["requires_reinitialize"])
		and (changed_patch["invalid_reasons"] as Array).has(
			"CONTACT_PATCH_ID_CHANGED_DURING_SUPPORT"),
		"per-patch support lineage cannot jump to a different surface")

	var temporal_gap: Dictionary = SupportStateScript.advance(
		_support_config, bearing,
		_observation(6, true, true, 120.0, true, 0.0))
	_check(not bool(temporal_gap["finite"])
		and bool(temporal_gap["requires_reinitialize"])
		and (temporal_gap["invalid_reasons"] as Array).has(
			"PHYSICS_STEP_NOT_EXACT_PREDECESSOR"),
		"missing support frame requires explicit reinitialization")

	var bad_quality := _observation(5, true, true, 120.0, true, 0.0)
	bad_quality["normal_load_quality"] = "pretend_exact_force"
	var quality_rejected: Dictionary = SupportStateScript.advance(
		_support_config, bearing, bad_quality)
	_check(not bool(quality_rejected["finite"])
		and (quality_rejected["invalid_reasons"] as Array).has(
			"NORMAL_LOAD_QUALITY_INVALID"),
		"numeric load with an unregistered quality label is not evidence")
	_finish()


func _observation(
		step: int,
		contact_present: bool,
		load_available: bool,
		load_n: float,
		separation_available: bool,
		separation_mps: float,
		raw_overrides: Dictionary = {}) -> Dictionary:
	var patch: Dictionary = _patch(step, raw_overrides)
	patch["contact_present"] = contact_present
	var qualification: Dictionary = GroundQualifierScript.qualify(
		patch, _ground_config)
	return {
		"physics_step_id": step,
		"capture_epoch": step,
		"sample_phase": "integrate_callback",
		"run_id": Helper.RUN_ID,
		"capture_stream_id": Helper.CAPTURE_STREAM_ID,
		"observer_profile_id": Helper.PROFILE_ID,
		"observer_adapter_id": Helper.ADAPTER_ID,
		"ground_qualification": qualification,
		"normal_load_available": load_available,
		"normal_load_n": load_n,
		"normal_load_quality": (
			"jolt_predicted_average_v1"
			if load_available else "unavailable"),
		"relative_separation_velocity_available": separation_available,
		"relative_separation_velocity_mps": separation_mps,
		"relative_separation_velocity_quality": (
			"canonical_patch_relative_velocity_v1"
			if separation_available else "unavailable"),
		# Deliberate poison pills. The state machine must never inspect these.
		"foot_height_m": -1000.0 if contact_present else 0.0,
		"target_arrived": true,
		"desired_support": true,
	}


func _patch(step: int, overrides: Dictionary) -> Dictionary:
	var frame: Dictionary = Helper.canonical_frame(step, [
		Helper.raw_contact(step, 0, Vector3.ZERO, overrides),
	])
	assert(bool(frame["ok"]))
	return (frame["patches"][0] as Dictionary).duplicate(true)


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
