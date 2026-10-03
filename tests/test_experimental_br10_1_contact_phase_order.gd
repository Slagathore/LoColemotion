extends SceneTree

## BR10.1 contact phase ordering from explicit contact/load observations.

const CoordinatorScript := preload("res://scripts/lab/mechanics/catch_contact_phase_coordinator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR10.1 contact phase ordering ===")
	var coordinator = CoordinatorScript.new()
	var configured := coordinator.configure(_configuration())
	_check(bool(configured.get("ok", false)), "strict contact-phase configuration seals")
	if not bool(configured.get("ok", false)):
		printerr("  configuration_failure=", configured)
		_finish()
		return
	var target_only := coordinator.update(_observation(0, true, false, false, null, null))
	_check(
		(
			bool(target_only.get("ok", false))
			and String(target_only["result"]["phase"]) == "SEARCH"
			and not bool(target_only["result"]["target_arrival_used_for_transition"])
		),
		"target arrival without observed contact remains SEARCH"
	)
	var touch := coordinator.update(_observation(1, true, true, true, null, 0.0))
	_check(
		(
			bool(touch.get("ok", false))
			and String(touch["result"]["previous_phase"]) == "SEARCH"
			and String(touch["result"]["phase"]) == "TOUCH"
		),
		"ground-qualified contact creates TOUCH and no later phase"
	)
	var load := coordinator.update(_observation(2, true, true, true, 3.0, 0.0))
	_check(
		(
			bool(load.get("ok", false))
			and String(load["result"]["previous_phase"]) == "TOUCH"
			and String(load["result"]["phase"]) == "LOAD"
			and not bool(load["result"]["bearing_established"])
		),
		"available local normal-load witness creates LOAD without skipping to BEARING"
	)
	var bearing_1 := coordinator.update(_observation(3, true, true, true, 10.0, 0.0))
	var bearing_2 := coordinator.update(_observation(4, true, true, true, 10.0, 0.0))
	var bearing_3 := coordinator.update(_observation(5, true, true, true, 10.0, 0.0))
	_check(
		(
			String(bearing_1["result"]["phase"]) == "LOAD"
			and String(bearing_2["result"]["phase"]) == "LOAD"
			and String(bearing_3["result"]["phase"]) == "BEARING"
		),
		"BEARING requires the complete three-tick load and separation dwell"
	)
	_check(
		(
			bool(bearing_3["result"]["bearing_established"])
			and int(bearing_3["result"]["transition_count"]) == 3
			and not bool(bearing_3["result"]["local_load_is_generalized_per_foot_allocation"])
		),
		"bearing result retains phase count and rejects generalized per-foot allocation"
	)
	var lost := coordinator.update(_observation(6, true, false, false, null, null))
	_check(
		(
			String(lost["result"]["previous_phase"]) == "BEARING"
			and String(lost["result"]["phase"]) == "LOST"
			and not bool(lost["result"]["bearing_established"])
		),
		"observed contact loss immediately revokes BEARING"
	)
	var reacquire := coordinator.update(_observation(7, true, true, true, 12.0, 0.0))
	_check(
		String(reacquire["result"]["phase"]) == "TOUCH",
		"reacquisition returns through TOUCH even when load is already present"
	)
	var nonmonotonic := coordinator.update(_observation(7, true, true, true, 12.0, 0.0))
	_check(
		String(nonmonotonic.get("failure_code", "")) == "CATCH_PHASE_TICK_NOT_MONOTONIC",
		"duplicate tick fails closed without changing phase authority"
	)
	var second = CoordinatorScript.new()
	second.configure(_configuration())
	second.update(_observation(0, false, true, true, null, 0.0))
	var unavailable := second.update(_observation(1, false, true, true, null, 0.0))
	_check(
		String(unavailable["result"]["phase"]) == "TOUCH",
		"contact without an available load witness cannot advance to LOAD"
	)
	var malformed := second.update(_observation(2, false, true, true, NAN, 0.0))
	_check(
		String(malformed.get("failure_code", "")) == "CATCH_PHASE_NORMAL_LOAD_INVALID",
		"nonfinite available load witness fails closed"
	)
	var too_fast = CoordinatorScript.new()
	too_fast.configure(_configuration())
	too_fast.update(_observation(0, false, true, true, 10.0, 0.4))
	too_fast.update(_observation(1, false, true, true, 10.0, 0.4))
	too_fast.update(_observation(2, false, true, true, 10.0, 0.4))
	var fast_tail := too_fast.update(_observation(3, false, true, true, 10.0, 0.4))
	_check(
		String(fast_tail["result"]["phase"]) == "LOAD",
		"separating contact cannot become BEARING despite sufficient load magnitude"
	)
	_finish()


static func _configuration() -> Dictionary:
	return {
		"schema_version": "catch_contact_phase_configuration_v1",
		"support_id": "br10_right_catch_foot",
		"contact_confirm_ticks": 1,
		"load_confirm_ticks": 1,
		"bearing_confirm_ticks": 3,
		"load_enter_n": 2.0,
		"bearing_enter_n": 8.0,
		"maximum_separating_speed_m_s": 0.05,
	}


static func _observation(
	tick: int,
	target_arrived: bool,
	contact: bool,
	ground_qualified: bool,
	load_value: Variant,
	separation_speed: Variant
) -> Dictionary:
	return {
		"schema_version": "catch_contact_phase_observation_v1",
		"tick": tick,
		"target_arrived": target_arrived,
		"ground_contact_observed": contact,
		"ground_qualified": ground_qualified,
		"normal_load_available": load_value != null,
		"normal_load_n": load_value,
		"relative_separation_speed_available": separation_speed != null,
		"relative_separation_speed_m_s": separation_speed,
	}


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
