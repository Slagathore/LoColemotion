extends SceneTree

## BR11.1 observation-authoritative FALL_ARREST/FALLEN phase contract.

const SupervisorScript := preload("res://scripts/lab/mechanics/fall_arrest_supervisor.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR11.1 fall-arrest supervisor ===")
	var supervisor = SupervisorScript.new()
	var configured := supervisor.configure(_configuration())
	_check(bool(configured.get("ok", false)), "strict supervisor configuration seals")
	if not bool(configured.get("ok", false)):
		_finish()
		return
	var safe := supervisor.observe(_input(1, true, false, true, false))
	_check(
		String(safe.get("phase", "")) == "MONITOR",
		"feasible upright recovery does not enter FALL_ARREST"
	)
	var arrest := supervisor.observe(_input(2, false, true, true, false))
	_check(
		(
			String(arrest.get("phase", "")) == "FALL_ARREST"
			and String(arrest.get("reason", "")) == "RECOVERY_INFEASIBLE_IMPACT_IMMINENT"
		),
		"infeasible recovery plus imminent impact and capacity enters FALL_ARREST"
	)
	_check(
		(
			not bool(arrest.get("force_authority", true))
			and not bool(arrest.get("torque_authority", true))
			and not bool(arrest.get("automatic_creature_guidance_allowed", true))
		),
		"supervisor transition grants no force, torque, or guidance authority"
	)
	var fallen_1 := supervisor.observe(_input(3, false, false, true, true))
	var interrupted := supervisor.observe(_input(4, false, false, true, false))
	var fallen_2 := supervisor.observe(_input(5, false, false, true, true))
	var fallen_3 := supervisor.observe(_input(6, false, false, true, true))
	var fallen_4 := supervisor.observe(_input(7, false, false, true, true))
	_check(
		String(fallen_1["phase"]) == "FALL_ARREST" and int(fallen_1["fallen_dwell_ticks"]) == 1,
		"one stable sample cannot create FALLEN"
	)
	_check(
		(
			String(interrupted["phase"]) == "FALL_ARREST"
			and int(interrupted["fallen_dwell_ticks"]) == 0
		),
		"unstable sample resets the fallen dwell"
	)
	_check(
		(
			String(fallen_2["phase"]) == "FALL_ARREST"
			and String(fallen_3["phase"]) == "FALL_ARREST"
			and String(fallen_4["phase"]) == "FALLEN"
		),
		"only three consecutive stable samples create FALLEN"
	)
	var duplicate := supervisor.observe(_input(7, false, false, true, true))
	_check(
		not bool(duplicate.get("ok", true)),
		"duplicate or nonmonotonic supervisor tick fails closed"
	)

	var insufficient = SupervisorScript.new()
	insufficient.configure(_configuration())
	var refused := insufficient.observe(_input(1, false, true, false, false))
	_check(
		(
			String(refused["phase"]) == "MONITOR"
			and String(refused["reason"]) == "INSUFFICIENT_PROTECTIVE_CAPACITY"
		),
		"missing protective capacity receives a named refusal instead of fake arrest"
	)
	var stable_without_capacity_1 := insufficient.observe(_input(2, false, false, false, true))
	var stable_without_capacity_2 := insufficient.observe(_input(3, false, false, false, true))
	var stable_without_capacity_3 := insufficient.observe(_input(4, false, false, false, true))
	_check(
		(
			String(stable_without_capacity_1["phase"]) == "MONITOR"
			and String(stable_without_capacity_2["phase"]) == "MONITOR"
			and String(stable_without_capacity_3["phase"]) == "FALLEN"
		),
		"a zero-capacity control may become observably fallen without an arrest claim"
	)
	var guidance := _configuration()
	guidance["automatic_creature_guidance_allowed"] = true
	var rejected = SupervisorScript.new()
	_check(
		not bool(rejected.configure(guidance).get("ok", true)),
		"supervisor configuration cannot enable automatic guidance"
	)
	_finish()


static func _configuration() -> Dictionary:
	return {
		"schema_version": "fall_arrest_supervisor_configuration_v1",
		"supervisor_id": "br11_test_supervisor",
		"fallen_confirm_ticks": 3,
		"automatic_creature_guidance_allowed": false,
	}


static func _input(
	tick: int, recovery_feasible: bool, impact_imminent: bool, capacity: bool, stable_fallen: bool
) -> Dictionary:
	return {
		"schema_version": "fall_arrest_supervisor_input_v1",
		"tick": tick,
		"upright_recovery_feasible": recovery_feasible,
		"impact_imminent": impact_imminent,
		"protective_capacity_available": capacity,
		"stable_fallen_observed": stable_fallen,
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
