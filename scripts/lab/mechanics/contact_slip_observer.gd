class_name LabContactSlipObserver
extends RefCounted

## Pure L1.1 decomposition of a canonical contact patch.
##
## For contact normal n, post-step relative velocity v, and solver-reported
## impulse J:
##
##     v_t = v - (v dot n) n
##     J_n = J dot n
##     J_t = J - J_n n
##
## The relative velocity stored by raw_contact_point_v2 is captured inside
## _integrate_forces. L1.1 empirically showed that it is a pre-constraint
## candidate in this Jolt configuration: a friction-held 4 kg sled under 8 N
## reported exactly F/m * dt = 0.03333 m/s while post-step displacement and
## velocity remained zero. That channel is retained under an explicit solver-
## input diagnostic name and is forbidden from classifying slip.
##
## The accepted slip velocity is reconstructed after the physics step from
## rigid-body kinematics at the contact point:
##
##     v_point = v_com + omega cross (p - c)
##
## minus the post-step counterparty point velocity. Jolt's contact impulse is
## retained as a predicted solver estimate. Dividing it by the physics step
## produces a per-step average load estimate, never an exact continuous force
## or a material coefficient. Static breakaway is inferred only by the
## separate staged experiment analyzer.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const RESULT_SCHEMA_VERSION := "contact_slip_observation_v1"
const REQUIRED_PATCH_SCHEMA_VERSION := "contact_patch_v1"
const REQUIRED_IMPULSE_QUALITY := "jolt_predicted_estimate"
const VECTOR_EPSILON := 1.0e-8
const IMPULSE_EPSILON_N_S := 1.0e-8


static func observe(
		patch: Dictionary,
		step_s: float,
		applied_force_world_n: Vector3,
		post_step_kinematics: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	if String(patch.get("schema_version", "")) \
			!= REQUIRED_PATCH_SCHEMA_VERSION:
		reasons.append("CONTACT_PATCH_SCHEMA_UNSUPPORTED")
	if patch.get("contact_present") != true:
		reasons.append("CONTACT_NOT_PRESENT")
	if patch.get("finite") != true:
		reasons.append("CONTACT_PATCH_NOT_FINITE")
	if not is_finite(step_s) or step_s <= 0.0:
		reasons.append("PHYSICS_STEP_INVALID")
	if not applied_force_world_n.is_finite():
		reasons.append("APPLIED_FORCE_NONFINITE")

	var normal := _vector3(patch.get("normal_world"))
	if patch.get("normal_available") != true \
			or not normal.is_finite() \
			or normal.length_squared() <= VECTOR_EPSILON:
		reasons.append("CONTACT_NORMAL_INVALID")
	else:
		normal = normal.normalized()
	var solver_input_relative_velocity := _vector3(
		patch.get("relative_velocity_world_mps"))
	if not solver_input_relative_velocity.is_finite():
		reasons.append("SOLVER_INPUT_RELATIVE_VELOCITY_NONFINITE")
	var impulse := _vector3(patch.get("impulse_world_ns"))
	if not impulse.is_finite():
		reasons.append("CONTACT_IMPULSE_NONFINITE")
	if String(patch.get("impulse_quality", "")) \
			!= REQUIRED_IMPULSE_QUALITY:
		reasons.append("CONTACT_IMPULSE_QUALITY_UNSUPPORTED")
	var post_step := _post_step_velocity(
		patch, post_step_kinematics, reasons)

	var normal_impulse_ns := 0.0
	if reasons.is_empty():
		normal_impulse_ns = impulse.dot(normal)
		if normal_impulse_ns < -IMPULSE_EPSILON_N_S:
			reasons.append("CONTACT_NORMAL_IMPULSE_NEGATIVE")
		var stored_normal := float(patch.get("normal_impulse_ns", NAN))
		var consistency_tolerance := maxf(
			1.0e-7, absf(normal_impulse_ns) * 1.0e-5)
		if not is_finite(stored_normal) \
				or absf(stored_normal - normal_impulse_ns) \
					> consistency_tolerance:
			reasons.append("CONTACT_NORMAL_IMPULSE_INCONSISTENT")

	if not reasons.is_empty():
		return FrozenValueScript.snapshot({
			"schema_version": RESULT_SCHEMA_VERSION,
			"observation_valid": false,
			"invalid_reasons": reasons,
			"physics_step_id": int(patch.get("physics_step_id", -1)),
			"capture_epoch": int(patch.get("capture_epoch", -1)),
			"contact_patch_id": String(patch.get("contact_patch_id", "")),
		})

	var relative_velocity: Vector3 = post_step["relative_velocity_world_mps"]
	var relative_separation_speed_mps := relative_velocity.dot(normal)
	var tangential_velocity := (
		relative_velocity - relative_separation_speed_mps * normal)
	var solver_input_separation_speed := (
		solver_input_relative_velocity.dot(normal))
	var solver_input_tangential_velocity := (
		solver_input_relative_velocity
		- solver_input_separation_speed * normal)
	var tangential_impulse := impulse - normal_impulse_ns * normal
	var applied_normal_force_n := applied_force_world_n.dot(normal)
	var applied_tangential_force := (
		applied_force_world_n - applied_normal_force_n * normal)
	var predicted_normal_load_n := maxf(normal_impulse_ns / step_s, 0.0)
	var predicted_tangential_load := tangential_impulse / step_s
	var normal_load_available := normal_impulse_ns > IMPULSE_EPSILON_N_S
	var solver_friction_ratio: Variant = null
	var applied_to_normal_ratio: Variant = null
	if normal_load_available:
		solver_friction_ratio = (
			tangential_impulse.length() / normal_impulse_ns)
		applied_to_normal_ratio = (
			applied_tangential_force.length() / predicted_normal_load_n)
	var opposition_cosine: Variant = null
	if tangential_impulse.length_squared() > VECTOR_EPSILON \
			and applied_tangential_force.length_squared() > VECTOR_EPSILON:
		opposition_cosine = -tangential_impulse.normalized().dot(
			applied_tangential_force.normalized())

	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"observation_valid": true,
		"invalid_reasons": [],
		"physics_step_id": int(patch.get("physics_step_id", -1)),
		"capture_epoch": int(patch.get("capture_epoch", -1)),
		"sample_phase": String(patch.get("sample_phase", "")),
		"contact_patch_id": String(patch.get("contact_patch_id", "")),
		"input_provenance": {
			"run_id": String(patch.get("run_id", "")),
			"capture_stream_id": String(
				patch.get("capture_stream_id", "")),
			"observer_profile_id": String(
				patch.get("observer_profile_id", "")),
			"observer_adapter_id": String(
				patch.get("observer_adapter_id", "")),
			"impulse_quality": REQUIRED_IMPULSE_QUALITY,
			"contact_sample_phase": String(patch.get("sample_phase", "")),
			"kinematic_sample_phase": "post_step",
		},
		"step_s": step_s,
		"normal_world": normal,
		"solver_input_relative_velocity_world_mps":
			solver_input_relative_velocity,
		"solver_input_relative_separation_speed_mps":
			solver_input_separation_speed,
		"solver_input_tangential_velocity_world_mps":
			solver_input_tangential_velocity,
		"solver_input_slip_speed_mps":
			solver_input_tangential_velocity.length(),
		"solver_input_velocity_quality":
			"integrate_callback_pre_constraint_candidate_v1",
		"solver_input_velocity_accepted_for_slip": false,
		"relative_velocity_world_mps": relative_velocity,
		"relative_separation_speed_mps": relative_separation_speed_mps,
		"tangential_velocity_world_mps": tangential_velocity,
		"slip_speed_mps": tangential_velocity.length(),
		"slip_velocity_quality": "post_step_rigid_kinematics_v1",
		"post_step_kinematics": post_step,
		"impulse_world_ns": impulse,
		"normal_impulse_ns": normal_impulse_ns,
		"tangential_impulse_world_ns": tangential_impulse,
		"tangential_impulse_ns": tangential_impulse.length(),
		"predicted_normal_load_n": predicted_normal_load_n,
		"predicted_tangential_load_world_n": predicted_tangential_load,
		"predicted_tangential_load_n": predicted_tangential_load.length(),
		"normal_load_available": normal_load_available,
		"solver_friction_ratio": solver_friction_ratio,
		"applied_force_world_n": applied_force_world_n,
		"applied_normal_force_n": applied_normal_force_n,
		"applied_tangential_force_world_n": applied_tangential_force,
		"applied_shear_force_n": applied_tangential_force.length(),
		"applied_to_predicted_normal_ratio": applied_to_normal_ratio,
		"contact_opposes_applied_shear_cosine": opposition_cosine,
		"predicted_tangential_force_balance_residual_world_n": (
			applied_tangential_force + predicted_tangential_load),
		"force_interpretation": "jolt_predicted_step_average_v1",
		"static_or_sliding_classification": "not_decided_by_single_sample",
	})


static func _post_step_velocity(
		patch: Dictionary,
		kinematics: Dictionary,
		reasons: Array[String]) -> Dictionary:
	if typeof(kinematics.get("physics_step_id")) != TYPE_INT \
			or int(kinematics.get("physics_step_id", -1)) \
				!= int(patch.get("physics_step_id", -2)):
		reasons.append("POST_STEP_PHYSICS_STEP_MISMATCH")
	if typeof(kinematics.get("capture_epoch")) != TYPE_INT \
			or int(kinematics.get("capture_epoch", -1)) \
				!= int(patch.get("capture_epoch", -2)):
		reasons.append("POST_STEP_CAPTURE_EPOCH_MISMATCH")
	if String(kinematics.get("sample_phase", "")) != "post_step":
		reasons.append("POST_STEP_SAMPLE_PHASE_INVALID")
	var linear_velocity := _vector3(
		kinematics.get("body_linear_velocity_world_mps"))
	var angular_velocity := _vector3(
		kinematics.get("body_angular_velocity_world_rad_s"))
	var center_of_mass := _vector3(
		kinematics.get("body_center_of_mass_world_m"))
	var counterparty_velocity := _vector3(
		kinematics.get("counterparty_velocity_world_mps"))
	var point_world := _vector3(patch.get("point_world"))
	for pair in [
		["BODY_LINEAR_VELOCITY", linear_velocity],
		["BODY_ANGULAR_VELOCITY", angular_velocity],
		["BODY_CENTER_OF_MASS", center_of_mass],
		["COUNTERPARTY_VELOCITY", counterparty_velocity],
		["CONTACT_POINT", point_world],
	]:
		if not (pair[1] as Vector3).is_finite():
			reasons.append("POST_STEP_%s_NONFINITE" % String(pair[0]))
	var point_velocity := Vector3.ZERO
	var relative_velocity := Vector3.ZERO
	if linear_velocity.is_finite() \
			and angular_velocity.is_finite() \
			and center_of_mass.is_finite() \
			and counterparty_velocity.is_finite() \
			and point_world.is_finite():
		point_velocity = linear_velocity + angular_velocity.cross(
			point_world - center_of_mass)
		relative_velocity = point_velocity - counterparty_velocity
	return {
		"schema_version": "post_step_contact_kinematics_v1",
		"physics_step_id": int(kinematics.get("physics_step_id", -1)),
		"capture_epoch": int(kinematics.get("capture_epoch", -1)),
		"sample_phase": String(kinematics.get("sample_phase", "")),
		"body_linear_velocity_world_mps": linear_velocity,
		"body_angular_velocity_world_rad_s": angular_velocity,
		"body_center_of_mass_world_m": center_of_mass,
		"contact_point_world_m": point_world,
		"body_contact_point_velocity_world_mps": point_velocity,
		"counterparty_velocity_world_mps": counterparty_velocity,
		"relative_velocity_world_mps": relative_velocity,
	}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)
