extends SceneTree

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const L0RunnerScript := preload("res://scripts/lab/l0_runner.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0 expanded-parameter application ===")
	var body_parameters := {
		"mass_kg": 7.25,
		"gravity_scale": 0.375,
		"initial_position_m": Vector3(3.125, 12.0, -4.5),
		"initial_velocity_m_s": Vector3(-1.75, 2.25, 0.625),
		"linear_damp_s1": 0.45,
		"angular_damp_s1": 0.85,
	}
	var fixture_parameters := {
		# This is an upper bound. The selected profile remains pinned to 32.
		"contact_cap": 48,
	}
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v1")

	print("- the rig factory applies every resolved value to the live body")
	var factory_rig: Dictionary = RigFactoryScript.build(
		&"ballistic_body_v1",
		CaptureClockScript.new(),
		profile,
		body_parameters,
		fixture_parameters)
	_check(bool(factory_rig.get("ok", false)),
			"unusual but valid configuration is accepted")
	if bool(factory_rig.get("ok", false)):
		var factory_body := factory_rig["body"] as RigidBody3D
		_check(
			is_equal_approx(factory_body.mass, 7.25)
			and is_equal_approx(factory_body.gravity_scale, 0.375)
			and factory_body.position.is_equal_approx(
				Vector3(3.125, 12.0, -4.5))
			and factory_body.linear_velocity.is_equal_approx(
				Vector3(-1.75, 2.25, 0.625))
			and is_equal_approx(factory_body.linear_damp, 0.45)
			and is_equal_approx(factory_body.angular_damp, 0.85),
			"mass, gravity, pose, velocity, and both damping values exist on RigidBody3D")
		var factory_fixture: Dictionary = factory_rig[
			"applied_fixture_parameters"]
		_check(
			int(factory_fixture["contact_cap"]) == 48
			and int(factory_fixture[
				"effective_contact_cap_per_body"]) == 32
			and bool(factory_fixture["contacts_enabled"]),
			"fixture cap is an upper bound while profile cap remains exactly 32")
		(factory_rig["world"] as Node).free()

	print("- direct-state evidence and returned configuration agree")
	var runner = L0RunnerScript.new()
	var result: Dictionary = await runner.run_ballistic_gravity(
		self,
		36,
		profile,
		null,
		null,
		body_parameters,
		fixture_parameters)
	_check(
		bool(result.get("ok", false))
		and bool(result.get("configuration_valid", false))
		and (result.get("configuration_errors", []) as Array).is_empty(),
		"runner accepts only after live-property verification succeeds")
	_check(
		_configuration_matches(
			result.get("applied_body_parameters", {}),
			body_parameters)
		and _configuration_matches(
			result.get("actual_body_parameters", {}),
			body_parameters),
		"result exposes matching applied and actual body configurations")
	var actual_fixture: Dictionary = result.get(
		"actual_fixture_parameters", {})
	_check(
		int(actual_fixture.get("contact_cap", -1)) == 48
		and bool(actual_fixture.get("contacts_enabled", false))
		and int(actual_fixture.get(
			"effective_contact_cap_per_body", -1)) == 32
		and int(result.get("observer_contact_cap_per_body", -1)) == 32,
		"result exposes the fixture upper bound and live observer cap separately")

	var frames: Array = result.get("frames", [])
	var first_sample := _only_body(frames[0] if not frames.is_empty() else {})
	var final_sample := _only_body(frames[-1] if not frames.is_empty() else {})
	var first_position := _vector(
		first_sample.get("transform", {}).get("origin", []))
	var first_velocity := _vector(first_sample.get("linear_velocity", []))
	var final_position := _vector(
		final_sample.get("transform", {}).get("origin", []))
	var final_velocity := _vector(final_sample.get("linear_velocity", []))
	var measured_gravity := _vector(
		first_sample.get("total_gravity_world", []))
	print(
		"  applied x0=", body_parameters["initial_position_m"],
		" v0=", body_parameters["initial_velocity_m_s"],
		"; first direct-state x=", first_position,
		" v=", first_velocity,
		"; configured errors=(",
		float(result.get("configured_initial_position_error_m", NAN)),
		" m, ",
		float(result.get("configured_initial_velocity_error_m_s", NAN)),
		" m/s)")
	_check(
		is_equal_approx(float(first_sample.get("mass_kg", NAN)), 7.25)
		and float(result.get("max_mass_oracle_error_kg", INF)) <= 1.0e-12,
		"direct state reports 7.25 kg on every captured frame")
	var measured_step_s := float(result.get("measured_step_s", NAN))
	var damping_factor := maxf(
		0.0,
		1.0 - float(body_parameters["linear_damp_s1"]) * measured_step_s)
	var expected_first_velocity: Vector3 = (
		body_parameters["initial_velocity_m_s"] * damping_factor
		+ measured_gravity * measured_step_s)
	var expected_first_position: Vector3 = (
		body_parameters["initial_position_m"]
		+ expected_first_velocity * measured_step_s)
	_check(
		first_position.distance_to(expected_first_position) <= 1.0e-6
		and first_velocity.distance_to(expected_first_velocity) <= 1.0e-6
		and absf(
			float(result.get(
				"configured_initial_position_error_m", INF))
			- first_position.distance_to(
				body_parameters["initial_position_m"])) <= 1.0e-9
		and absf(
			float(result.get(
				"configured_initial_velocity_error_m_s", INF))
			- first_velocity.distance_to(
				body_parameters["initial_velocity_m_s"])) <= 1.0e-9,
		"first direct-state sample is exactly one applied Jolt step from requested initial state")
	_check(
		absf(measured_gravity.y - (-9.8 * 0.375)) <= 0.01
		and absf(measured_gravity.x) <= 1.0e-8
		and absf(measured_gravity.z) <= 1.0e-8,
		"direct state measures the requested 0.375 gravity scale")
	_check(
		final_position.distance_to(first_position) > 0.25
		and final_velocity.distance_to(first_velocity) > 0.25,
		"unusual initial state follows a nontrivial measured trajectory")
	_check(
		final_position.distance_to(_vector(
			result.get("measured_final_position_m", []))) <= 1.0e-9
		and final_velocity.distance_to(_vector(
			result.get("measured_final_velocity_m_s", []))) <= 1.0e-9,
		"trajectory summary is derived from the final direct-state frame")

	var reported_final_momentum := _vector(
		result.get("measured_final_momentum_kg_m_s", []))
	_check(
		reported_final_momentum.distance_to(7.25 * final_velocity)
			<= 1.0e-8
		and reported_final_momentum.distance_to(2.0 * final_velocity)
			> 1.0,
		"reported momentum uses requested live mass, not the former 2 kg default")
	var recomputed_max_momentum_error := _recompute_max_momentum_error(
		frames,
		7.25,
		first_velocity,
		measured_gravity,
		float(result.get("measured_step_s", NAN)))
	_check(
		absf(
			recomputed_max_momentum_error
			- float(result.get("max_momentum_error_kg_m_s", NAN)))
			<= 1.0e-7
		and recomputed_max_momentum_error > 0.1,
		"momentum diagnostic is recomputable and exposes nonzero damping")
	var observer_compatibility: Dictionary = await runner.run_observer_ab(
		self,
		2,
		{},
		{"contact_cap": 32})
	_check(
		bool(observer_compatibility.get("configuration_valid", false))
		and int((observer_compatibility["minimal"] as Dictionary)[
			"actual_fixture_parameters"][
				"effective_contact_cap_per_body"]) == 0
		and int((observer_compatibility["full"] as Dictionary)[
			"actual_fixture_parameters"][
				"effective_contact_cap_per_body"]) == 0
		and int((observer_compatibility["contact"] as Dictionary)[
			"actual_fixture_parameters"][
				"effective_contact_cap_per_body"]) == 32,
		"fixture cap 32 is compatible with minimal/full cap 0 and contact cap 32")

	print("- invalid or incompatible values stop before evidence capture")
	var invalid_mass: Dictionary = await runner.run_ballistic_zero_g(
		self,
		4,
		profile,
		null,
		null,
		{"mass_kg": 0.0},
		{"contact_cap": 32})
	_check(
		not bool(invalid_mass.get("configuration_valid", true))
		and int(invalid_mass.get("sample_count", -1)) == 0
		and _has_error(
			invalid_mass, "PARAMETER_DOMAIN_ERROR",
			"/body_parameters/mass_kg"),
		"non-positive mass is deterministically rejected before a frame")
	var incompatible_cap: Dictionary = await runner.run_ballistic_zero_g(
		self,
		4,
		profile,
		null,
		null,
		{},
		{"contact_cap": 8})
	_check(
		not bool(incompatible_cap.get("configuration_valid", true))
		and int(incompatible_cap.get("sample_count", -1)) == 0
		and _has_error(
			incompatible_cap, "CONTACT_CAP_INCOMPATIBLE",
			"/fixture_parameters/contact_cap"),
		"profile cap 32 cannot silently overflow fixture cap 8")
	var unknown_parameter: Dictionary = await runner.run_ballistic_zero_g(
		self,
		4,
		profile,
		null,
		null,
		{"invented_force_n": 123.0},
		{"contact_cap": 32})
	_check(
		not bool(unknown_parameter.get("configuration_valid", true))
		and int(unknown_parameter.get("sample_count", -1)) == 0
		and _has_error(
			unknown_parameter, "UNKNOWN_PARAMETER",
			"/body_parameters/invented_force_n"),
		"unknown body fields cannot be sealed then silently ignored")

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _configuration_matches(
		actual: Dictionary,
		expected: Dictionary) -> bool:
	return (
		is_equal_approx(
			float(actual.get("mass_kg", NAN)),
			float(expected["mass_kg"]))
		and is_equal_approx(
			float(actual.get("gravity_scale", NAN)),
			float(expected["gravity_scale"]))
		and actual.get("initial_position_m", Vector3.INF).is_equal_approx(
			expected["initial_position_m"])
		and actual.get("initial_velocity_m_s", Vector3.INF).is_equal_approx(
			expected["initial_velocity_m_s"])
		and is_equal_approx(
			float(actual.get("linear_damp_s1", NAN)),
			float(expected["linear_damp_s1"]))
		and is_equal_approx(
			float(actual.get("angular_damp_s1", NAN)),
			float(expected["angular_damp_s1"])))


func _recompute_max_momentum_error(
		frames: Array,
		mass_kg: float,
		initial_velocity: Vector3,
		gravity: Vector3,
		step_s: float) -> float:
	var maximum := 0.0
	for frame_index in frames.size():
		var sample := _only_body(frames[frame_index])
		var velocity := _vector(sample.get("linear_velocity", []))
		var expected_velocity := (
			initial_velocity + gravity * float(frame_index) * step_s)
		maximum = maxf(
			maximum,
			(mass_kg * velocity).distance_to(
				mass_kg * expected_velocity))
	return maximum


func _has_error(
		result: Dictionary,
		code: String,
		path: String) -> bool:
	for raw_error in result.get("configuration_errors", []):
		var error: Dictionary = raw_error
		if (
			String(error.get("code", "")) == code
			and String(error.get("path", "")) == path
		):
			return true
	return false


func _only_body(frame: Dictionary) -> Dictionary:
	var bodies: Dictionary = frame.get("bodies", {})
	return bodies.values()[0] if bodies.size() == 1 else {}


func _vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2]))
	return Vector3.INF


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
