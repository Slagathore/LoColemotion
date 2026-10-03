extends SceneTree

const L0RunnerScript := preload("res://scripts/lab/l0_runner.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0.1 free-fall calibration ===")
	var original_ticks := Engine.physics_ticks_per_second
	var contact_profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v1")
	for ticks in [30, 60, 120]:
		Engine.physics_ticks_per_second = ticks
		# Godot applies a runtime tick-rate change on the next main-loop
		# iteration. Stabilize the clock before spawning the measured body so
		# one trace never mixes the previous and requested dt.
		await process_frame
		await process_frame
		await physics_frame
		var runner = L0RunnerScript.new()
		var result: Dictionary = await runner.run_free_fall(
			self, ticks / 2, contact_profile)
		var label := "%d Hz" % ticks
		var gravity: Array = result.get("measured_gravity_world_m_s2", [])
		print("  %s dt=%.6f gravity=%s accel_err=%.6f vel_err=%.6f pos_err=%.6f" % [
			label,
			float(result.get("measured_step_s", NAN)),
			str(gravity),
			float(result.get("max_acceleration_error_m_s2", NAN)),
			float(result.get("max_velocity_error_m_s", NAN)),
			float(result.get("max_position_error_m", NAN)),
		])
		_check(bool(result.get("finite", false)),
				"%s direct-state evidence is finite and coherent" % label)
		_check(gravity.size() == 3 and float(gravity[1]) < -9.0,
				"%s observer measures configured downward gravity" % label)
		_check(float(result.get(
				"max_acceleration_error_m_s2", INF)) <= 0.02,
				"%s velocity differences reproduce measured gravity" % label)
		_check(float(result.get(
				"max_velocity_error_m_s", INF)) <= 0.02,
				"%s free-fall velocity matches v0 + g*t" % label)
		# The engine is a discrete integrator; continuous-trajectory position
		# error must shrink with dt and remain below one gravity-step here.
		var one_step_position_bound := (
			0.5 * absf(float(gravity[1]))
			* float(result["measured_step_s"])
			* 0.55)
		_check(float(result.get(
				"max_position_error_m", INF)) <= one_step_position_bound,
				"%s position stays inside the declared timestep envelope" % label)
		_check(int(result.get("total_contact_count", -1)) == 0,
				"%s isolated fall contains no collision impulse" % label)
		_check(bool(result.get("observer_contacts_enabled", false)),
				"%s zero-contact claim uses enabled contact capture" % label)
	Engine.physics_ticks_per_second = original_ticks
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
