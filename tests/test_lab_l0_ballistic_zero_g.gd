extends SceneTree

const L0RunnerScript := preload("res://scripts/lab/l0_runner.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0.2 ballistic zero-gravity calibration ===")
	var runner = L0RunnerScript.new()
	var contact_profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v1")
	var result: Dictionary = await runner.run_ballistic_zero_g(
		self, 90, contact_profile)
	var gravity: Array = result.get("measured_gravity_world_m_s2", [])
	_check(bool(result.get("finite", false)),
			"ballistic direct-state evidence is finite and coherent")
	_check(gravity.size() == 3 and _length(gravity) <= 1.0e-9,
			"gravity_scale=0 produces a measured zero gravity vector")
	_check(float(result.get("max_velocity_error_m_s", INF)) <= 1.0e-6,
			"isolated zero-g body preserves velocity")
	_check(float(result.get("max_position_error_m", INF)) <= 2.0e-5,
			"zero-g position matches x0 + v*t")
	_check(float(result.get(
			"max_momentum_error_kg_m_s", INF)) <= 2.0e-6,
			"isolated zero-g body preserves linear momentum")
	_check(int(result.get("total_contact_count", -1)) == 0,
			"ballistic fixture contains no unrecorded collision")
	_check(bool(result.get("observer_contacts_enabled", false))
			and int(result.get("observer_contact_cap_per_body", 0)) == 32,
			"collision claim uses the pinned full-contact observer")
	_check(int(result.get("direct_state_callback_count", 0)) >= 91,
			"all ballistic samples came through the physics callback")

	var gravity_result: Dictionary = await runner.run_ballistic_gravity(
		self, 60, contact_profile)
	var gravity_vector: Array = gravity_result.get(
		"measured_gravity_world_m_s2", [])
	_check(bool(gravity_result.get("finite", false))
			and gravity_vector.size() == 3
			and float(gravity_vector[1]) < -9.0,
			"gravity-ballistic fixture records a finite downward field")
	_check(float(gravity_result.get(
			"max_acceleration_error_m_s2", INF)) <= 0.02,
			"gravity-ballistic velocity differences reproduce gravity")
	_check(float(gravity_result.get(
			"max_velocity_error_m_s", INF)) <= 0.02,
			"gravity-ballistic velocity matches v0 + g*t")
	var gravity_position_bound := (
		0.5 * absf(float(gravity_vector[1]))
		* float(gravity_result["measured_step_s"])
		* 1.05)
	_check(float(gravity_result.get(
			"max_position_error_m", INF)) <= gravity_position_bound,
			"gravity-ballistic position stays inside its timestep envelope")
	_check(int(gravity_result.get("total_contact_count", -1)) == 0
			and bool(gravity_result.get("observer_contacts_enabled", false)),
			"gravity-ballistic flight stays collision-free under observation")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _length(value: Array) -> float:
	return Vector3(
		float(value[0]), float(value[1]), float(value[2])).length()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
