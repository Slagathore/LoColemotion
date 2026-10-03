extends SceneTree

## BR2.1 pinned test: whole-body angular momentum is DERIVED from sampled
## engine channels when every contribution is available, and is explicitly
## UNAVAILABLE (null value plus reason), never numeric zero, when any body
## cannot contribute.
##
## Four legs:
##
## 1. Analytic assembly: a hand-computed two-body system must reproduce the
##    exact spin+orbital angular momentum, both kinetic energies, and the
##    reference-point shift identity
##        L_about_P = L_about_com + (r_com - P) x p_total
##    against a direct summation about P. This is the BR2 gate's "whole-body
##    CoM, momentum, energy, and reference-point shift equations pass
##    analytic assemblies" clause for the rotational channels.
## 2. Frame coherence: body dictionary keys must match stable body IDs and all
##    contributors must come from one physics step, capture epoch, and sample
##    phase. Fully finite samples from adjacent callbacks are still rejected.
## 3. Negative space: singular, nonsymmetric, indefinite, ill-conditioned, or
##    missing rotational inputs make only angular momentum and rotational
##    energy unavailable. Independently valid translational channels survive.
##    The BR1-era pin (angular momentum null in frame_v1) exists precisely
##    because inventing zeros here would poison every later balance computation.
## 4. Engine leg (the gravity-off spinning body fixture), which pins an
##    ENGINE CONTRACT, not textbook mechanics: this Jolt configuration does
##    not apply the gyroscopic term (omega x I omega), so a torque-free body
##    keeps its WORLD ANGULAR VELOCITY constant rather than its angular
##    momentum. Measured consequences, both asserted below:
##    - spun about a PRINCIPAL axis, the rotating tensor leaves the spin
##      component invariant, so the derived L is constant AND matches the
##      analytic solid-box inertia; and
##    - spun OFF-principal, omega stays constant while the world-frame
##      tensor rotates with the body, so the derived L must visibly change.
##    The second case is deliberately the opposite of naive expectation; it
##    is the honest record of what the engine integrates, and it proves the
##    sampled tensor path is doing real per-tick work.

const ObservedRigidBodyScript := preload(
	"res://scripts/lab/mechanics/observed_rigid_body.gd")
const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const MechanicsBodySampleScript := preload(
	"res://scripts/lab/mechanics/mechanics_body_sample.gd")
const RotationalStateScript := preload(
	"res://scripts/lab/mechanics/whole_body_rotational_state.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR2.1 whole-body angular momentum availability ===")
	_analytic_assembly()
	_coherence_negatives()
	_unavailability_negatives()
	_tensor_validation_negatives()
	# Analytic solid-box inertia for the 0.4 x 0.6 x 0.3 box at mass 2:
	# I = m/12 * diag(h^2+d^2, w^2+d^2, w^2+h^2)
	#   = diag(0.075, 0.0416667, 0.0866667) kg m^2.
	await _spin_case(
		"principal",
		Vector3(0.0, 0.0, 2.0),
		Vector3(0.0, 0.0, 2.0 * 2.0 / 12.0 * (0.4 * 0.4 + 0.6 * 0.6)))
	await _spin_case("off_principal", Vector3(1.5, 2.0, -1.0), Vector3.ZERO)
	_finish()


func _analytic_assembly() -> void:
	# Body A: mass 2 at (1,0,0), v (0,1,0), omega (0,0,3), I diag(2,3,4).
	# Body B: mass 3 at (-1,0,0), v (0,-1,0), omega (1,0,0), I diag(1,2,2).
	# Hand computation: r_com (-0.2,0,0); p (0,-1,0);
	# spin A (0,0,12), spin B (1,0,0);
	# orbital A 2*(1.2,0,0)x(0,1,0) = (0,0,2.4);
	# orbital B 3*(-0.8,0,0)x(0,-1,0) = (0,0,2.4);
	# L_total (1,0,16.8); KE_lin 2.5 J; KE_rot 18.5 J.
	var bodies := {
		"body_a": _body("body_a", 2.0, Vector3(1, 0, 0), Vector3(0, 1, 0),
			Vector3(0, 0, 3), Vector3(2, 3, 4)),
		"body_b": _body("body_b", 3.0, Vector3(-1, 0, 0), Vector3(0, -1, 0),
			Vector3(1, 0, 0), Vector3(1, 2, 2)),
	}
	var state: Dictionary = RotationalStateScript.from_bodies(bodies)
	_check(bool(state["angular_momentum_available"]),
		"two-body analytic assembly derives angular momentum")
	_check(String(state["schema_version"]) == "whole_body_state_v3"
		and int(state["physics_step_id"]) == 3
		and int(state["capture_epoch"]) == 1
		and String(state["sample_phase"]) == "integrate_callback",
		"v3 success carries the coherent step, epoch, and sample phase")
	var momentum := _vector3(state["angular_momentum_about_com_world_n_m_s"])
	_check(momentum.distance_to(Vector3(1.0, 0.0, 16.8)) < 1.0e-9,
		"spin+orbital total matches the hand computation (1, 0, 16.8)")
	_check(absf(float(state["linear_kinetic_energy_j"]) - 2.5) < 1.0e-9
		and absf(float(state["rotational_kinetic_energy_j"]) - 18.5) < 1.0e-9,
		"linear 2.5 J and rotational 18.5 J energies match")

	# Reference-point shift identity against a direct summation about P.
	var reference := Vector3(2.0, 1.0, -3.0)
	var direct := Vector3.ZERO
	direct += Vector3(0, 0, 12) + 2.0 * (Vector3(1, 0, 0) - reference).cross(
		Vector3(0, 1, 0))
	direct += Vector3(1, 0, 0) + 3.0 * (Vector3(-1, 0, 0) - reference).cross(
		Vector3(0, -1, 0))
	var shifted: Vector3 = RotationalStateScript.shift_reference_point(
		momentum,
		_vector3(state["center_of_mass_world_m"]),
		_vector3(state["linear_momentum_world_n_s"]),
		reference)
	_check(shifted.distance_to(direct) < 1.0e-9,
		"reference-point shift identity matches direct summation about P")


func _coherence_negatives() -> void:
	var key_mismatch := {
		"body_a": _body("different_body", 1.0, Vector3.ZERO, Vector3.ZERO,
			Vector3.ZERO, Vector3.ONE),
	}
	_assert_fully_unavailable(
		RotationalStateScript.from_bodies(key_mismatch),
		"BODY_ID_MISMATCH:body_a",
		"dictionary body key must equal the sampled stable body_id")

	var mixed_steps := _two_coherent_bodies()
	(mixed_steps["body_b"] as Dictionary)["physics_step_id"] = 4
	_assert_fully_unavailable(
		RotationalStateScript.from_bodies(mixed_steps),
		"BODY_SAMPLES_SPAN_STEPS",
		"finite samples from different physics steps cannot be aggregated")

	var mixed_epochs := _two_coherent_bodies()
	(mixed_epochs["body_b"] as Dictionary)["capture_epoch"] = 2
	_assert_fully_unavailable(
		RotationalStateScript.from_bodies(mixed_epochs),
		"BODY_SAMPLES_SPAN_EPOCHS",
		"finite samples from different capture epochs cannot be aggregated")

	var mixed_phases := _two_coherent_bodies()
	(mixed_phases["body_b"] as Dictionary)["sample_phase"] = "post_step"
	_assert_fully_unavailable(
		RotationalStateScript.from_bodies(mixed_phases),
		"BODY_SAMPLES_SPAN_PHASES",
		"finite samples from different sample phases cannot be aggregated")

	var mixed_runs := _two_coherent_bodies()
	(mixed_runs["body_b"] as Dictionary)["run_id"] = "other-run"
	_assert_fully_unavailable(
		RotationalStateScript.from_bodies(mixed_runs),
		"BODY_SAMPLES_SPAN_RUNS",
		"coincident step numbers from different runs cannot be aggregated")
	var mixed_profiles := _two_coherent_bodies()
	(mixed_profiles["body_b"] as Dictionary)["observer_profile_id"] = \
		"other_profile"
	_assert_fully_unavailable(
		RotationalStateScript.from_bodies(mixed_profiles),
		"BODY_SAMPLES_SPAN_OBSERVER_PROFILES",
		"different observer profiles cannot share one mechanics aggregate")
	var mixed_adapters := _two_coherent_bodies()
	(mixed_adapters["body_b"] as Dictionary)["observer_adapter_id"] = \
		"other_adapter"
	_assert_fully_unavailable(
		RotationalStateScript.from_bodies(mixed_adapters),
		"BODY_SAMPLES_SPAN_OBSERVER_ADAPTERS",
		"different observer adapters cannot share one mechanics aggregate")
	var typo_phase := _two_coherent_bodies()
	(typo_phase["body_a"] as Dictionary)["sample_phase"] = "integrate_callbak"
	var typo_phase_state: Dictionary = RotationalStateScript.from_bodies(
		typo_phase)
	_check(not bool(typo_phase_state["finite"])
		and String(typo_phase_state[
			"angular_momentum_unavailable_reason"])
			== "BODY_FRAME_IDENTITY_MISSING:body_a",
		"unregistered sample phase is rejected instead of accepted as a label")
	var invalid_key_state: Dictionary = RotationalStateScript.from_bodies({
		1: _body("1", 1.0, Vector3.ZERO, Vector3.ZERO,
			Vector3.ZERO, Vector3.ONE),
	})
	_check(not bool(invalid_key_state["finite"])
		and String(invalid_key_state[
			"angular_momentum_unavailable_reason"])
			== "BODY_KEY_NOT_STABLE_STRING",
		"non-string dictionary keys cannot alias canonical body identities")


func _unavailability_negatives() -> void:
	# A locked rotational axis arrives from the engine as a singular inverse
	# inertia tensor. Inverting it would manufacture infinite inertia, so
	# the aggregate must refuse with an exact reason and a null value.
	var singular := {
		"healthy": _body("healthy", 1.0, Vector3.ZERO, Vector3.ZERO,
			Vector3(0, 1, 0), Vector3(1, 1, 1)),
		"locked": _body("locked", 1.0, Vector3(0.5, 0, 0), Vector3.ZERO,
			Vector3(1, 0, 0), Vector3(1, 1, 1)),
	}
	(singular["locked"] as Dictionary)["inverse_inertia_tensor_world"] = {
		"x": [1.0, 0.0, 0.0],
		"y": [0.0, 0.0, 0.0],
		"z": [0.0, 0.0, 1.0],
	}
	var locked_state: Dictionary = RotationalStateScript.from_bodies(singular)
	_assert_rotationally_unavailable(
		locked_state,
		"INERTIA_NOT_INVERTIBLE:locked",
		2.0,
		"singular inverse inertia is unavailable with the exact reason")

	var missing := {
		"body_a": _body("body_a", 1.0, Vector3.ZERO, Vector3.ZERO,
			Vector3.ZERO, Vector3(1, 1, 1)),
	}
	(missing["body_a"] as Dictionary).erase("angular_velocity")
	(missing["body_a"] as Dictionary)["finite"] = false
	var missing_state: Dictionary = RotationalStateScript.from_bodies(missing)
	_assert_rotationally_unavailable(
		missing_state,
		"BODY_CHANNEL_MISSING:body_a",
		1.0,
		"real adapter-style finite=false rotational loss preserves translation")


func _tensor_validation_negatives() -> void:
	var nonsymmetric := _body(
		"body_a", 2.0, Vector3.ZERO, Vector3(1, 0, 0),
		Vector3(0, 1, 0), Vector3.ONE)
	nonsymmetric["inverse_inertia_tensor_world"] = {
		"x": [1.0, 0.0, 0.0],
		"y": [0.01, 1.0, 0.0],
		"z": [0.0, 0.0, 1.0],
	}
	_assert_rotationally_unavailable(
		RotationalStateScript.from_bodies({"body_a": nonsymmetric}),
		"INERTIA_NOT_SYMMETRIC:body_a",
		2.0,
		"nonsymmetric inverse inertia is rejected before inversion")

	var indefinite := _body(
		"body_a", 2.0, Vector3.ZERO, Vector3(1, 0, 0),
		Vector3(0, 1, 0), Vector3.ONE)
	indefinite["inverse_inertia_tensor_world"] = {
		"x": [1.0, 0.0, 0.0],
		"y": [0.0, -1.0, 0.0],
		"z": [0.0, 0.0, 1.0],
	}
	_assert_rotationally_unavailable(
		RotationalStateScript.from_bodies({"body_a": indefinite}),
		"INERTIA_NOT_POSITIVE_DEFINITE:body_a",
		2.0,
		"invertible but indefinite inverse inertia is rejected")

	# det=1e-8 stays above the singular floor, but kappa=1e8 exceeds the
	# explicit 1e6 usability cap. This distinguishes conditioning from rank.
	var ill_conditioned := _body(
		"body_a", 2.0, Vector3.ZERO, Vector3(1, 0, 0),
		Vector3(0, 1, 0), Vector3.ONE)
	ill_conditioned["inverse_inertia_tensor_world"] = {
		"x": [1.0, 0.0, 0.0],
		"y": [0.0, 1.0, 0.0],
		"z": [0.0, 0.0, 1.0e-8],
	}
	_assert_rotationally_unavailable(
		RotationalStateScript.from_bodies({"body_a": ill_conditioned}),
		"INERTIA_ILL_CONDITIONED:body_a",
		2.0,
		"positive-definite but ill-conditioned inverse inertia is rejected")

	# A tiny accepted skew is explicitly symmetrized before every downstream
	# operation. Its coupling to conditioning is bounded, and the correction is
	# reported instead of silently changing the tensor.
	var near_symmetric := _body(
		"body_a", 2.0, Vector3.ZERO, Vector3.ZERO,
		Vector3(0, 1, 0), Vector3.ONE)
	near_symmetric["inverse_inertia_tensor_world"] = {
		"x": [1.0, 0.0, 0.0],
		"y": [4.0e-7, 1.0, 0.0],
		"z": [0.0, 0.0, 1.0e-5],
	}
	var accepted_skew: Dictionary = RotationalStateScript.from_bodies(
		{"body_a": near_symmetric})
	var quality: Dictionary = accepted_skew["rotational_input_quality"][0]
	_check(bool(accepted_skew["angular_momentum_available"])
		and absf(float(quality[
			"inverse_inertia_symmetrization_correction"]) - 2.0e-7)
			< 1.0e-10
		and float(quality["inverse_inertia_condition_number"]) > 9.0e4,
		"accepted bounded skew is symmetrized once and reports its correction")
	var coupled_skew := near_symmetric.duplicate(true)
	coupled_skew["inverse_inertia_tensor_world"] = {
		"x": [1.0, 0.0, 0.0],
		"y": [8.0e-7, 1.0, 0.0],
		"z": [0.0, 0.0, 1.0e-5],
	}
	_assert_rotationally_unavailable(
		RotationalStateScript.from_bodies({"body_a": coupled_skew}),
		"INERTIA_SKEW_CONDITION_COUPLING_EXCEEDED:body_a",
		2.0,
		"near-threshold skew is rejected when conditioning amplifies it")


## Runs one gravity-off spin and asserts the engine-contract behavior for
## the chosen axis class. `analytic_momentum` is the expected constant L for
## a principal-axis spin, or Vector3.ZERO for the off-principal case (where
## L is expected to vary and no constant analytic value exists).
func _spin_case(
		case_name: String,
		initial_omega: Vector3,
		analytic_momentum: Vector3) -> void:
	var clock = CaptureClockScript.new()
	var profile := {
		"profile_id": "br2_spin_probe",
		"contacts_enabled": false,
		"contact_cap_per_body": 0,
		"channels": [],
	}
	var world := Node3D.new()
	world.name = "Br2SpinWorld"
	var body = ObservedRigidBodyScript.new()
	body.body_id = &"spinner_0"
	body.part_index = 0
	body.capture_clock = clock
	body.observer_profile = profile
	body.mass = 2.0
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(0.0, 2.0, 0.0)
	body.angular_velocity = initial_omega
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.6, 0.3)
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	root.add_child(world)
	# Same stabilization the L0 physics tests use: pin the tick rate and let
	# the world settle into the physics loop before opening capture epochs.
	Engine.physics_ticks_per_second = 60
	await process_frame
	await physics_frame

	var initial_momentum := Vector3.ZERO
	var max_momentum_deviation := 0.0
	var first_omega := Vector3.ZERO
	var max_omega_change := 0.0
	var available_every_tick := true
	var ticks := 60
	for tick in ticks:
		clock.open_epoch(tick, float(tick) / 60.0)
		await physics_frame
		clock.close_epoch()
		var source_sample: Dictionary = body.latest_body_sample
		if source_sample.is_empty():
			available_every_tick = false
			break
		var projection: Dictionary = MechanicsBodySampleScript.project(
			source_sample,
			"br2-spin-%s-run" % case_name,
			"br2-spin-%s-capture" % case_name)
		if not bool(projection["ok"]):
			available_every_tick = false
			break
		var sample: Dictionary = projection["sample"]
		var state: Dictionary = RotationalStateScript.from_bodies(
			{"spinner_0": sample})
		if not bool(state["angular_momentum_available"]):
			available_every_tick = false
			break
		var momentum := _vector3(
			state["angular_momentum_about_com_world_n_m_s"])
		var omega := _vector3(sample["angular_velocity"])
		if tick == 0:
			initial_momentum = momentum
			first_omega = omega
		else:
			max_momentum_deviation = maxf(
				max_momentum_deviation,
				momentum.distance_to(initial_momentum))
			max_omega_change = maxf(
				max_omega_change, omega.distance_to(first_omega))
	world.queue_free()
	await physics_frame

	_check(available_every_tick,
		"%s spin: angular momentum derivable on every sampled tick"
			% case_name)
	# The engine contract under record: no gyroscopic term, so world omega
	# is constant for torque-free motion in BOTH cases.
	_check(max_omega_change < 1.0e-4,
		"%s spin: engine held world omega constant (drift %.8f rad/s)"
			% [case_name, max_omega_change])
	var momentum_scale := maxf(initial_momentum.length(), 1.0e-6)
	var relative_deviation := max_momentum_deviation / momentum_scale
	if analytic_momentum != Vector3.ZERO:
		# Principal-axis spin: the rotating tensor leaves the spin component
		# invariant, so derived L stays constant and equals I_analytic*omega.
		_check(relative_deviation < 2.0e-3,
			"%s spin: derived L constant over %d ticks (rel dev %.8f)"
				% [case_name, ticks, relative_deviation])
		var analytic_error := initial_momentum.distance_to(
			analytic_momentum) / maxf(analytic_momentum.length(), 1.0e-9)
		_check(analytic_error < 1.0e-2,
			"%s spin: derived L matches analytic box inertia (rel err %.8f)"
				% [case_name, analytic_error])
	else:
		# Off-principal spin: constant omega through a rotating world tensor
		# means derived L MUST change; a static L here would indicate the
		# sampled tensor was frozen at construction (the stored-world-frame
		# failure BR2 exists to catch).
		_check(relative_deviation > 0.05,
			"%s spin: derived L varies with the rotating tensor (rel dev %.8f)"
				% [case_name, relative_deviation])


func _body(
		body_id: String,
		mass: float,
		com: Vector3,
		velocity: Vector3,
		omega: Vector3,
		inertia_diagonal: Vector3) -> Dictionary:
	return {
		"schema_version": "mechanics_body_sample_v1",
		"body_id": body_id,
		"physics_step_id": 3,
		"capture_epoch": 1,
		"sample_phase": "integrate_callback",
		"mass_kg": mass,
		"center_of_mass_world": [com.x, com.y, com.z],
		"linear_velocity": [velocity.x, velocity.y, velocity.z],
		"angular_velocity": [omega.x, omega.y, omega.z],
		"inverse_inertia_tensor_world": {
			"x": [1.0 / inertia_diagonal.x, 0.0, 0.0],
			"y": [0.0, 1.0 / inertia_diagonal.y, 0.0],
			"z": [0.0, 0.0, 1.0 / inertia_diagonal.z],
		},
		"run_id": "br2-rotational-analytic-run",
		"capture_stream_id": "br2-rotational-analytic-stream",
		"observer_profile_id": "br2_rotational_state_v3",
		"observer_adapter_id": "analytic_rotational_fixture_v1",
		"finite": true,
	}


func _two_coherent_bodies() -> Dictionary:
	return {
		"body_a": _body(
			"body_a", 1.0, Vector3.ZERO, Vector3.ZERO,
			Vector3.ZERO, Vector3.ONE),
		"body_b": _body(
			"body_b", 1.0, Vector3.RIGHT, Vector3.ZERO,
			Vector3.ZERO, Vector3.ONE),
	}


func _assert_fully_unavailable(
		state: Dictionary,
		expected_reason: String,
		label: String) -> void:
	var availability: Dictionary = state["availability"]
	_check(
		not bool(state["angular_momentum_available"])
		and not bool(state["finite"])
		and String(state["schema_version"]) == "whole_body_state_v3"
		and int(state["physics_step_id"]) == 3
		and int(state["capture_epoch"]) == 1
		and String(state["sample_phase"]) == "integrate_callback"
		and state["total_mass_kg"] == null
		and state["linear_momentum_world_n_s"] == null
		and state["angular_momentum_about_com_world_n_m_s"] == null
		and String(state["angular_momentum_unavailable_reason"])
			== expected_reason
		and String((availability["/linear_momentum_world_n_s"] as Dictionary)[
			"status"]) == "unavailable"
		and String((availability[
			"/angular_momentum_about_com_world_n_m_s"] as Dictionary)[
			"reason"]) == expected_reason,
		label)


func _assert_rotationally_unavailable(
		state: Dictionary,
		expected_reason: String,
		expected_total_mass: float,
		label: String) -> void:
	var availability: Dictionary = state["availability"]
	_check(
		not bool(state["angular_momentum_available"])
		and bool(state["finite"])
		and absf(float(state["total_mass_kg"]) - expected_total_mass) < 1.0e-9
		and state["linear_momentum_world_n_s"] != null
		and state["linear_kinetic_energy_j"] != null
		and state["angular_momentum_about_com_world_n_m_s"] == null
		and state["rotational_kinetic_energy_j"] == null
		and int(state["physics_step_id"]) == 3
		and int(state["capture_epoch"]) == 1
		and String(state["sample_phase"]) == "integrate_callback"
		and String(state["angular_momentum_unavailable_reason"])
			== expected_reason
		and String((availability["/linear_momentum_world_n_s"] as Dictionary)[
			"status"]) == "derived"
		and (availability["/linear_momentum_world_n_s"] as Dictionary)[
			"reason"] == null
		and String((availability[
			"/angular_momentum_about_com_world_n_m_s"] as Dictionary)[
			"status"]) == "unavailable"
		and String((availability["/rotational_kinetic_energy_j"] as Dictionary)[
			"reason"]) == expected_reason,
		label)


func _vector3(value: Variant) -> Vector3:
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


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
