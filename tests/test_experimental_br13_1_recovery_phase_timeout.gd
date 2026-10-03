extends SceneTree

## BR13.1 timeout, revocation, and handoff rejection behavior.

const SupervisorScript := preload("res://scripts/lab/mechanics/recovery_phase_supervisor.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Experimental BR13.1 recovery phase timeout ===")
	var timeout_supervisor = SupervisorScript.new()
	_check(
		bool(timeout_supervisor.configure(_configuration(2)).get("ok", false)),
		"short-timeout supervisor configures"
	)
	for tick in 3:
		var waiting: Dictionary = timeout_supervisor.observe(_input(tick, "TRANSITION"))
		_check(
			String(waiting["phase"]) == "CONFIRM_PRONE",
			"unobserved prone cannot advance before timeout at tick %d" % tick
		)
	var timed_out: Dictionary = timeout_supervisor.observe(_input(3, "TRANSITION"))
	_check(String(timed_out["phase"]) == "FAILED", "phase timeout fails closed")
	_check(
		String(timed_out["failure_code"]) == "RECOVERY_PHASE_TIMEOUT:CONFIRM_PRONE",
		"timeout names the exact failed phase"
	)
	_check(
		(
			not bool(timed_out["recovery_controller_may_be_active"])
			and not bool(timed_out["stance_controller_may_be_active"])
		),
		"failed supervisor grants no controller phase authority"
	)

	var energy_supervisor = SupervisorScript.new()
	energy_supervisor.configure(_configuration(10))
	var energy_input := _input(0, "PRONE")
	energy_input["energy_gate_passed"] = false
	var energy_failed: Dictionary = energy_supervisor.observe(energy_input)
	_check(
		String(energy_failed["failure_code"]) == "RECOVERY_ENERGY_GATE_REVOKED",
		"revoked energy gate immediately fails"
	)

	var reserve_supervisor = SupervisorScript.new()
	reserve_supervisor.configure(_configuration(10))
	var reserve_input := _input(0, "PRONE")
	reserve_input["actuator_reserve_passed"] = false
	var reserve_failed: Dictionary = reserve_supervisor.observe(reserve_input)
	_check(
		String(reserve_failed["failure_code"]) == "RECOVERY_ACTUATOR_RESERVE_REVOKED",
		"revoked actuator reserve immediately fails"
	)

	var contact_supervisor = SupervisorScript.new()
	contact_supervisor.configure(_configuration(10))
	var forbidden_input := _input(0, "PRONE")
	forbidden_input["forbidden_contact_observed"] = true
	var forbidden_failed: Dictionary = contact_supervisor.observe(forbidden_input)
	_check(
		String(forbidden_failed["failure_code"]) == "FORBIDDEN_CONTACT_OBSERVED",
		"forbidden contact immediately fails"
	)

	var duplicate_supervisor = SupervisorScript.new()
	duplicate_supervisor.configure(_configuration(10))
	_check(
		bool(duplicate_supervisor.observe(_input(0, "PRONE")).get("ok", false)),
		"first tick is accepted"
	)
	_check(
		(
			not bool(duplicate_supervisor.observe(_input(0, "PRONE")).get("ok", true))
			and (
				String(duplicate_supervisor.observe(_input(0, "PRONE")).get("failure_code", ""))
				== "RECOVERY_SUPERVISOR_TICK_INVALID"
			)
		),
		"duplicate tick fails closed"
	)

	var handoff_supervisor = SupervisorScript.new()
	var handoff_configuration := _configuration(10)
	handoff_configuration["prone_confirm_ticks"] = 1
	handoff_supervisor.configure(handoff_configuration)
	handoff_supervisor.observe(_input(0, "PRONE"))
	var contacts := _input(1, "TRANSITION")
	contacts["front_pair_bearing"] = true
	contacts["rear_pair_bearing"] = true
	contacts["recovery_controller_active"] = true
	handoff_supervisor.observe(contacts)
	var rise := contacts.duplicate(true)
	rise["tick"] = 2
	rise["height_ratio"] = 0.8
	handoff_supervisor.observe(rise)
	var bad_handoff := _input(3, "STANCE")
	bad_handoff["height_ratio"] = 0.8
	bad_handoff["front_pair_bearing"] = true
	bad_handoff["rear_pair_bearing"] = true
	bad_handoff["recovery_controller_active"] = true
	bad_handoff["stance_controller_active"] = true
	var handoff_wait: Dictionary = handoff_supervisor.observe(bad_handoff)
	_check(
		String(handoff_wait["phase"]) == "STANCE_HANDOFF",
		"stance handoff refuses overlapping recovery-controller authority"
	)
	_check(
		(
			not bool(handoff_wait["force_authority"])
			and not bool(handoff_wait["torque_authority"])
			and not bool(handoff_wait["contact_creation_authority"])
			and not bool(handoff_wait["automatic_creature_guidance_allowed"])
		),
		"all supervisor mutation and guidance channels remain closed"
	)

	var malformed := _configuration(10)
	malformed["phase_timeout_ticks"]["RAISE_BODY"] = 0
	_check(
		not bool(SupervisorScript.new().configure(malformed).get("ok", true)),
		"zero phase timeout is rejected"
	)
	var guidance := _configuration(10)
	guidance["automatic_creature_guidance_allowed"] = true
	_check(
		not bool(SupervisorScript.new().configure(guidance).get("ok", true)),
		"automatic guidance cannot enter supervisor configuration"
	)
	_finish()


static func _configuration(timeout_ticks: int) -> Dictionary:
	return {
		"schema_version": "recovery_phase_supervisor_v1",
		"supervisor_id": "br13_timeout_probe",
		"prone_confirm_ticks": 2,
		"stance_dwell_ticks": 3,
		"rise_height_ratio_min": 0.75,
		"phase_timeout_ticks":
		{
			"CONFIRM_PRONE": timeout_ticks,
			"ESTABLISH_DISTAL_CONTACT": timeout_ticks,
			"RAISE_BODY": timeout_ticks,
			"STANCE_HANDOFF": timeout_ticks,
			"STANCE_DWELL": timeout_ticks,
		},
		"automatic_creature_guidance_allowed": false,
	}


static func _input(tick: int, pose: String) -> Dictionary:
	return {
		"schema_version": "recovery_phase_observation_v1",
		"tick": tick,
		"pose_state": pose,
		"height_ratio": 0.2,
		"front_pair_bearing": false,
		"rear_pair_bearing": false,
		"energy_gate_passed": true,
		"actuator_reserve_passed": true,
		"forbidden_contact_observed": false,
		"recovery_controller_active": false,
		"stance_controller_active": false,
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
