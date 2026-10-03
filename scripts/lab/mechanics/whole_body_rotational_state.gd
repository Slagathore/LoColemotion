class_name LabWholeBodyRotationalState
extends RefCounted

## BR2.1 whole-body rotational aggregation: total angular momentum, rotational
## energy, and the reference-point shift identity, derived ONLY from sampled
## engine channels.
##
## Version boundary (read this before wiring it anywhere): the sealed
## frame_v1 stream stays exactly as BR1 certified it, with
## angular_momentum_about_com_world_n_m_s pinned to null and the reason
## BR1_INERTIA_CHANNEL_NOT_CERTIFIED. frame_v1.schema.json,
## pre_event_entry_v1.schema.json, the bundle validator, the metric
## recomputer, and every published BR1 bundle depend on that pin, and the
## lab's schemas are append-only. This class is therefore a separate
## mechanics-layer aggregation. BR2 originally shipped source id
## whole_body_state_v2; the frame-coherent, tensor-hardened contract below is
## whole_body_state_v3 so historical v2 results remain unambiguous. Its values
## enter a sealed stream only when a future frame_v2 experiment family
## versions the whole chain together. BR2's gate needs the equations proven,
## not the L0 stream rewritten.
##
## Physics, with every frame named:
##
## - Each body i contributes a SPIN term I_world_i * omega_i (inertia tensor
##   in the world frame times world angular velocity) and an ORBITAL term
##   m_i * (r_i - r_com) x v_i (its linear momentum taken about the
##   assembly's center of mass).
## - Every body sample must name the dictionary key that contains it and must
##   share one physics step, capture epoch, and sample phase. Mixing adjacent
##   callbacks can produce entirely finite but physically impossible totals,
##   so temporal/identity coherence is a gate, not a diagnostic.
## - The engine publishes the INVERSE inertia tensor in world space
##   (PhysicsDirectBodyState3D.inverse_inertia_tensor), so the spin term
##   needs an inversion. Before inversion, v3 requires a finite, symmetric,
##   positive-definite, sufficiently conditioned tensor. A locked axis or a
##   malformed tensor makes the ROTATIONAL channels unavailable, with an exact
##   reason, while independently valid mass/CoM/linear channels remain usable.
##   The availability doctrine is the lab's oldest rule: unsupported channels
##   are marked unavailable with a reason, never written as numeric zero.
## - Rotational kinetic energy per body is 0.5 * omega . (I_world * omega);
##   linear kinetic energy is 0.5 * m * |v|^2. Both are reported so the BR2
##   analytic assemblies can check energy bookkeeping.
## - The reference-point shift identity
##       L_about_P = L_about_com + (r_com - P) x p_total
##   is exposed as a helper so tests can prove the identity against a direct
##   summation about P. This is the equation later balance work will use to
##   move momentum readings between frames without resampling.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SOURCE_ID := "whole_body_state_v3"
const REQUIRED_BODY_SAMPLE_SCHEMA_VERSION := "mechanics_body_sample_v1"
const VALID_SAMPLE_PHASES := ["integrate_callback", "post_step"]

## Relative determinant floor below which an inverse inertia tensor is
## treated as singular. Scaled by the tensor's own magnitude so a heavy
## body's legitimately small inverse entries are not misread as locked axes.
const SINGULARITY_RELATIVE_FLOOR := 1.0e-12

## A world-space inertia tensor is mathematically symmetric. Jolt and Godot
## publish float-backed Basis components, so v3 permits relative skew up to
## 1e-6 (roughly ten float32 epsilons plus transform accumulation), with a
## 1e-12 absolute floor near zero. Larger skew is evidence of frame/serialization
## corruption, not a tensor that should be silently symmetrized.
const SYMMETRY_RELATIVE_TOLERANCE := 1.0e-6
const SYMMETRY_ABSOLUTE_TOLERANCE := 1.0e-12

## Positive eigenvalues below 1e-12 of the largest eigenvalue are numerically
## indistinguishable from a locked axis for this observer. The stricter usable
## bound is the condition-number cap: at 1e6, a float32-backed input can already
## amplify relative component error to order 1e-1. Rejecting above that point
## prevents an apparently finite inverse from becoming a high-gain noise source.
const POSITIVE_EIGENVALUE_RELATIVE_FLOOR := 1.0e-12
const MAX_INVERSE_INERTIA_CONDITION_NUMBER := 1.0e6
const MAX_SYMMETRY_ERROR_CONDITION_PRODUCT := 5.0e-2

const _LINEAR_CHANNEL_PATHS := [
	"/total_mass_kg",
	"/center_of_mass_world_m",
	"/linear_momentum_world_n_s",
	"/linear_kinetic_energy_j",
]
const _ROTATIONAL_CHANNEL_PATHS := [
	"/angular_momentum_about_com_world_n_m_s",
	"/rotational_kinetic_energy_j",
]


## Aggregates the rotational channels of one coherent frame's body samples
## (the ObservedRigidBody value-dictionary shape). Returns a sealed value
## dictionary. Frame-wide identity/core-channel failures invalidate every
## aggregate. Rotational-only failures preserve valid translational channels
## and mark only angular momentum and rotational energy unavailable.
static func from_bodies(bodies: Dictionary) -> Dictionary:
	var body_keys: Array = bodies.keys()
	var canonical_keys: Dictionary = {}
	for body_key in body_keys:
		if not (body_key is String or body_key is StringName) \
				or String(body_key).is_empty():
			return _fully_unavailable(
				"BODY_KEY_NOT_STABLE_STRING", [], _empty_frame_identity())
		var canonical_key := String(body_key)
		if canonical_keys.has(canonical_key):
			return _fully_unavailable(
				"BODY_KEY_CANONICAL_COLLISION:%s" % canonical_key,
				[],
				_empty_frame_identity())
		canonical_keys[canonical_key] = true
	body_keys.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String(left) < String(right))
	var body_ids := body_keys.map(
		func(value: Variant) -> String: return String(value))
	var frame_identity := _empty_frame_identity()
	if body_keys.is_empty():
		return _fully_unavailable("NO_BODY_SAMPLES", body_ids, frame_identity)

	var coherence := _coherent_frame_identity(bodies, body_keys)
	frame_identity = coherence["identity"]
	if not bool(coherence["valid"]):
		return _fully_unavailable(
			String(coherence["reason"]), body_ids, frame_identity)

	var total_mass := 0.0
	var weighted_com := Vector3.ZERO
	var linear_momentum := Vector3.ZERO
	var linear_kinetic_energy_j := 0.0
	var per_body: Array = []
	var rotational_input_quality: Array = []
	var rotational_unavailable_reason := ""
	for body_key in body_keys:
		var body_id := String(body_key)
		var body: Dictionary = bodies[body_key]
		var mass := float(body.get("mass_kg", 0.0))
		var com := _vector3(body.get("center_of_mass_world"))
		var velocity := _vector3(body.get("linear_velocity"))
		var omega := _vector3(body.get("angular_velocity"))
		var inverse_inertia := _basis_from_value(
			body.get("inverse_inertia_tensor_world"))
		if (
			mass <= 0.0
			or not is_finite(mass)
			or not com.is_finite()
			or not velocity.is_finite()
		):
			return _fully_unavailable(
				"BODY_CHANNEL_MISSING:%s" % body_id, body_ids, frame_identity)
		total_mass += mass
		weighted_com += mass * com
		linear_momentum += mass * velocity
		linear_kinetic_energy_j += 0.5 * mass * velocity.length_squared()

		# Rotational observation is an optional, all-bodies channel. Keep
		# checking the core/translational inputs even after its first failure,
		# but retain the first sorted-body reason as deterministic provenance.
		if rotational_unavailable_reason.is_empty():
			if not omega.is_finite() or not _basis_is_finite(inverse_inertia):
				rotational_unavailable_reason = \
					"BODY_CHANNEL_MISSING:%s" % body_id
			else:
				var inertia_quality := _validated_inertia_quality(
					inverse_inertia, body_id)
				rotational_unavailable_reason = String(
					inertia_quality["reason"])
				if rotational_unavailable_reason.is_empty():
					var validated_inverse: Basis = \
						inertia_quality["symmetrized_inverse_inertia"]
					var inertia_world := validated_inverse.inverse()
					if not _basis_is_finite(inertia_world):
						rotational_unavailable_reason = \
							"INERTIA_INVERSION_NONFINITE:%s" % body_id
					else:
						per_body.append({
							"mass": mass,
							"com": com,
							"velocity": velocity,
							"omega": omega,
							"inertia_world": inertia_world,
						})
						rotational_input_quality.append({
							"body_id": body_id,
							"inverse_inertia_symmetrization_correction":
								float(inertia_quality[
									"symmetrization_correction"]),
							"inverse_inertia_condition_number":
								float(inertia_quality["condition_number"]),
							"inverse_inertia_eigenvalues":
								(inertia_quality["eigenvalues"] as Array).duplicate(),
							"quality":
								"validated_symmetrized_spd_inverse_inertia_v1",
						})

	if total_mass <= 0.0 or not is_finite(total_mass):
		return _fully_unavailable(
			"TOTAL_MASS_INVALID", body_ids, frame_identity)
	var center_of_mass := weighted_com / total_mass
	if (
		not center_of_mass.is_finite()
		or not linear_momentum.is_finite()
		or not is_finite(linear_kinetic_energy_j)
	):
		return _fully_unavailable(
			"LINEAR_AGGREGATION_NONFINITE", body_ids, frame_identity)

	if not rotational_unavailable_reason.is_empty():
		return _rotationally_unavailable(
			rotational_unavailable_reason,
			body_ids,
			frame_identity,
			total_mass,
			center_of_mass,
			linear_momentum,
			linear_kinetic_energy_j,
			rotational_input_quality)

	# Spin plus orbital summation about the assembly center of mass.
	var angular_momentum := Vector3.ZERO
	var rotational_kinetic_energy_j := 0.0
	for entry_value in per_body:
		var entry: Dictionary = entry_value
		var inertia_world: Basis = entry["inertia_world"]
		var omega: Vector3 = entry["omega"]
		var spin: Vector3 = inertia_world * omega
		var offset: Vector3 = (entry["com"] as Vector3) - center_of_mass
		var orbital: Vector3 = float(entry["mass"]) * offset.cross(
			entry["velocity"])
		angular_momentum += spin + orbital
		rotational_kinetic_energy_j += 0.5 * omega.dot(spin)
	if (
		not angular_momentum.is_finite()
		or not is_finite(rotational_kinetic_energy_j)
	):
		return _rotationally_unavailable(
			"AGGREGATION_NONFINITE",
			body_ids,
			frame_identity,
			total_mass,
			center_of_mass,
			linear_momentum,
			linear_kinetic_energy_j,
			rotational_input_quality)

	return FrozenValueScript.snapshot({
		"schema_version": SOURCE_ID,
		"physics_step_id": int(frame_identity["physics_step_id"]),
		"capture_epoch": int(frame_identity["capture_epoch"]),
		"sample_phase": String(frame_identity["sample_phase"]),
		"input_provenance": _identity_provenance(frame_identity),
		"body_ids": body_ids,
		"total_mass_kg": total_mass,
		"center_of_mass_world_m": _array3(center_of_mass),
		"linear_momentum_world_n_s": _array3(linear_momentum),
		"angular_momentum_about_com_world_n_m_s": _array3(angular_momentum),
		"linear_kinetic_energy_j": linear_kinetic_energy_j,
		"rotational_kinetic_energy_j": rotational_kinetic_energy_j,
		"angular_momentum_available": true,
		"angular_momentum_quality": "engine_inverse_inertia_validated_v2",
		"angular_momentum_unavailable_reason": null,
		"rotational_input_quality": rotational_input_quality,
		"availability": _channel_availability(true, true, ""),
		"finite": true,
	})


## Reference-point shift: moves an angular momentum reading from the center
## of mass to an arbitrary world point P without resampling:
##     L_about_P = L_about_com + (r_com - P) x p_total
## Tests prove this equals the direct summation about P; later support and
## balance work uses it to express momentum about a contact point.
static func shift_reference_point(
		angular_momentum_about_com: Vector3,
		center_of_mass_world: Vector3,
		linear_momentum_world: Vector3,
		reference_point_world: Vector3) -> Vector3:
	return angular_momentum_about_com \
		+ (center_of_mass_world - reference_point_world).cross(
			linear_momentum_world)


static func _fully_unavailable(
		reason: String,
		body_ids: Array,
		frame_identity: Dictionary) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": SOURCE_ID,
		"physics_step_id": int(frame_identity.get("physics_step_id", -1)),
		"capture_epoch": int(frame_identity.get("capture_epoch", -1)),
		"sample_phase": String(frame_identity.get("sample_phase", "")),
		"input_provenance": _identity_provenance(frame_identity),
		"body_ids": body_ids,
		"total_mass_kg": null,
		"center_of_mass_world_m": null,
		"linear_momentum_world_n_s": null,
		"angular_momentum_about_com_world_n_m_s": null,
		"linear_kinetic_energy_j": null,
		"rotational_kinetic_energy_j": null,
		"angular_momentum_available": false,
		"angular_momentum_quality": "unavailable",
		"angular_momentum_unavailable_reason": reason,
		"rotational_input_quality": [],
		"availability": _channel_availability(false, false, reason),
		"finite": false,
	})


static func _rotationally_unavailable(
		reason: String,
		body_ids: Array,
		frame_identity: Dictionary,
		total_mass: float,
		center_of_mass: Vector3,
		linear_momentum: Vector3,
		linear_kinetic_energy_j: float,
		rotational_input_quality: Array = []) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": SOURCE_ID,
		"physics_step_id": int(frame_identity["physics_step_id"]),
		"capture_epoch": int(frame_identity["capture_epoch"]),
		"sample_phase": String(frame_identity["sample_phase"]),
		"input_provenance": _identity_provenance(frame_identity),
		"body_ids": body_ids,
		"total_mass_kg": total_mass,
		"center_of_mass_world_m": _array3(center_of_mass),
		"linear_momentum_world_n_s": _array3(linear_momentum),
		"angular_momentum_about_com_world_n_m_s": null,
		"linear_kinetic_energy_j": linear_kinetic_energy_j,
		"rotational_kinetic_energy_j": null,
		"angular_momentum_available": false,
		"angular_momentum_quality": "unavailable",
		"angular_momentum_unavailable_reason": reason,
		"rotational_input_quality": rotational_input_quality,
		"availability": _channel_availability(true, false, reason),
		# `finite` describes the values that are present. Null rotational
		# channels are unavailable, not non-finite placeholders.
		"finite": true,
	})


static func _channel_availability(
		linear_available: bool,
		rotational_available: bool,
		reason: String) -> Dictionary:
	var availability := {}
	for path in _LINEAR_CHANNEL_PATHS:
		availability[path] = {
			"status": "derived" if linear_available else "unavailable",
			"reason": null if linear_available else reason,
			"source": SOURCE_ID,
		}
	for path in _ROTATIONAL_CHANNEL_PATHS:
		availability[path] = {
			"status": "derived" if rotational_available else "unavailable",
			"reason": null if rotational_available else reason,
			"source": SOURCE_ID,
		}
	return availability


static func _coherent_frame_identity(
		bodies: Dictionary,
		body_keys: Array) -> Dictionary:
	var identity := _empty_frame_identity()
	for index in body_keys.size():
		var body_key: Variant = body_keys[index]
		var key_id := String(body_key)
		var body_value: Variant = bodies[body_key]
		if not body_value is Dictionary:
			return _coherence_failure(
				"BODY_CHANNEL_MISSING:%s" % key_id, identity)
		var body: Dictionary = body_value
		var sample_phase_value: Variant = body.get("sample_phase")
		var schema_version_value: Variant = body.get("schema_version")
		var run_id_value: Variant = body.get("run_id")
		var capture_stream_value: Variant = body.get("capture_stream_id")
		var profile_value: Variant = body.get("observer_profile_id")
		var adapter_value: Variant = body.get("observer_adapter_id")
		if typeof(body.get("physics_step_id")) != TYPE_INT \
				or int(body["physics_step_id"]) < 0 \
				or typeof(body.get("capture_epoch")) != TYPE_INT \
				or int(body["capture_epoch"]) < 0 \
				or not (sample_phase_value is String \
					or sample_phase_value is StringName) \
				or String(sample_phase_value) not in VALID_SAMPLE_PHASES \
				or not _stable_identity_value(schema_version_value) \
				or String(schema_version_value) \
					!= REQUIRED_BODY_SAMPLE_SCHEMA_VERSION \
				or not _stable_identity_value(run_id_value) \
				or not _stable_identity_value(capture_stream_value) \
				or not _stable_identity_value(profile_value) \
				or not _stable_identity_value(adapter_value):
			return _coherence_failure(
				"BODY_FRAME_IDENTITY_MISSING:%s" % key_id, identity)
		var physics_step_id := int(body["physics_step_id"])
		var capture_epoch := int(body["capture_epoch"])
		var sample_phase := String(body["sample_phase"])
		if index == 0:
			identity = {
				"physics_step_id": physics_step_id,
				"capture_epoch": capture_epoch,
				"sample_phase": sample_phase,
				"body_sample_schema_version":
					String(schema_version_value),
				"run_id": String(run_id_value),
				"capture_stream_id": String(capture_stream_value),
				"observer_profile_id": String(profile_value),
				"observer_adapter_id": String(adapter_value),
			}
		if String(body.get("body_id", "")) != key_id:
			return _coherence_failure("BODY_ID_MISMATCH:%s" % key_id, identity)
		if index == 0:
			continue
		if physics_step_id != int(identity["physics_step_id"]):
			return _coherence_failure("BODY_SAMPLES_SPAN_STEPS", identity)
		if capture_epoch != int(identity["capture_epoch"]):
			return _coherence_failure("BODY_SAMPLES_SPAN_EPOCHS", identity)
		if sample_phase != String(identity["sample_phase"]):
			return _coherence_failure("BODY_SAMPLES_SPAN_PHASES", identity)
		if String(schema_version_value) \
				!= String(identity["body_sample_schema_version"]):
			return _coherence_failure(
				"BODY_SAMPLES_SPAN_SCHEMAS", identity)
		if String(run_id_value) != String(identity["run_id"]):
			return _coherence_failure("BODY_SAMPLES_SPAN_RUNS", identity)
		if String(capture_stream_value) \
				!= String(identity["capture_stream_id"]):
			return _coherence_failure(
				"BODY_SAMPLES_SPAN_CAPTURE_STREAMS", identity)
		if String(profile_value) \
				!= String(identity["observer_profile_id"]):
			return _coherence_failure(
				"BODY_SAMPLES_SPAN_OBSERVER_PROFILES", identity)
		if String(adapter_value) \
				!= String(identity["observer_adapter_id"]):
			return _coherence_failure(
				"BODY_SAMPLES_SPAN_OBSERVER_ADAPTERS", identity)
	return {
		"valid": true,
		"reason": "",
		"identity": identity,
	}


static func _coherence_failure(
		reason: String,
		identity: Dictionary) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"identity": identity,
	}


static func _empty_frame_identity() -> Dictionary:
	return {
		"physics_step_id": -1,
		"capture_epoch": -1,
		"sample_phase": "",
		"body_sample_schema_version": "",
		"run_id": "",
		"capture_stream_id": "",
		"observer_profile_id": "",
		"observer_adapter_id": "",
	}


static func _identity_provenance(identity: Dictionary) -> Dictionary:
	return {
		"body_sample_schema_version": String(
			identity.get("body_sample_schema_version", "")),
		"run_id": String(identity.get("run_id", "")),
		"capture_stream_id": String(
			identity.get("capture_stream_id", "")),
		"observer_profile_id": String(
			identity.get("observer_profile_id", "")),
		"observer_adapter_id": String(
			identity.get("observer_adapter_id", "")),
	}


static func _stable_identity_value(value: Variant) -> bool:
	return (value is String or value is StringName) \
		and not String(value).is_empty()


## Returns an exact reason or an empty string. All checks happen before the
## call site invokes Basis.inverse(). Condition number is the eigenvalue ratio
## of the symmetric positive-definite inverse tensor; inversion has the same
## condition number, so this bounds the downstream inertia tensor too.
static func _inertia_validation_error(
		inverse_inertia: Basis,
		body_id: String) -> String:
	var component_scale := _basis_max_abs_component(inverse_inertia)
	var symmetry_error := maxf(
		absf(inverse_inertia.x.y - inverse_inertia.y.x),
		maxf(
			absf(inverse_inertia.x.z - inverse_inertia.z.x),
			absf(inverse_inertia.y.z - inverse_inertia.z.y)))
	var symmetry_tolerance := maxf(
		SYMMETRY_ABSOLUTE_TOLERANCE,
		SYMMETRY_RELATIVE_TOLERANCE * component_scale)
	if symmetry_error > symmetry_tolerance:
		return "INERTIA_NOT_SYMMETRIC:%s" % body_id

	# The accepted contract is the exact symmetric tensor below.  Validation,
	# inversion, momentum, and energy all use this same matrix; the observer
	# never validates a symmetric approximation and then inverts a different
	# slightly skew matrix.
	var symmetric_inverse := _symmetrize_basis(inverse_inertia)
	var determinant := symmetric_inverse.determinant()
	var scale_reference := _basis_magnitude(symmetric_inverse)
	if (
		not is_finite(determinant)
		or absf(determinant)
			<= SINGULARITY_RELATIVE_FLOOR
				* maxf(scale_reference * scale_reference
					* scale_reference, 1.0e-30)
	):
		return "INERTIA_NOT_INVERTIBLE:%s" % body_id

	var eigenvalues := _symmetric_eigenvalues(symmetric_inverse)
	var minimum_eigenvalue := float(eigenvalues[0])
	var maximum_eigenvalue := float(eigenvalues[2])
	var positive_floor := maxf(
		1.0e-30,
		POSITIVE_EIGENVALUE_RELATIVE_FLOOR * absf(maximum_eigenvalue))
	if (
		not is_finite(minimum_eigenvalue)
		or not is_finite(maximum_eigenvalue)
		or minimum_eigenvalue <= positive_floor
		or maximum_eigenvalue <= positive_floor
	):
		return "INERTIA_NOT_POSITIVE_DEFINITE:%s" % body_id
	var condition_number := maximum_eigenvalue / minimum_eigenvalue
	if (
		not is_finite(condition_number)
		or condition_number > MAX_INVERSE_INERTIA_CONDITION_NUMBER
	):
		return "INERTIA_ILL_CONDITIONED:%s" % body_id
	if symmetry_error * condition_number \
			> MAX_SYMMETRY_ERROR_CONDITION_PRODUCT:
		return "INERTIA_SKEW_CONDITION_COUPLING_EXCEEDED:%s" % body_id
	return ""


static func _validated_inertia_quality(
		inverse_inertia: Basis,
		body_id: String) -> Dictionary:
	var reason := _inertia_validation_error(inverse_inertia, body_id)
	var symmetric_inverse := _symmetrize_basis(inverse_inertia)
	if not reason.is_empty():
		return {
			"reason": reason,
			"symmetrized_inverse_inertia": symmetric_inverse,
			"symmetrization_correction": NAN,
			"condition_number": NAN,
			"eigenvalues": [],
		}
	var eigenvalues := _symmetric_eigenvalues(symmetric_inverse)
	var condition_number := float(eigenvalues[2]) / float(eigenvalues[0])
	return {
		"reason": "",
		"symmetrized_inverse_inertia": symmetric_inverse,
		"symmetrization_correction":
			_basis_max_abs_difference(inverse_inertia, symmetric_inverse),
		"condition_number": condition_number,
		"eigenvalues": eigenvalues,
	}


static func _symmetrize_basis(value: Basis) -> Basis:
	var xy := 0.5 * (value.x.y + value.y.x)
	var xz := 0.5 * (value.x.z + value.z.x)
	var yz := 0.5 * (value.y.z + value.z.y)
	return Basis(
		Vector3(value.x.x, xy, xz),
		Vector3(xy, value.y.y, yz),
		Vector3(xz, yz, value.z.z))


## Closed-form trigonometric eigenvalues for a real symmetric 3x3 matrix. The
## returned array is ascending. The diagonal branch
## avoids a 0/0 normalization for already principal-axis-aligned tensors.
static func _symmetric_eigenvalues(value: Basis) -> Array:
	var a00 := value.x.x
	var a01 := value.y.x
	var a02 := value.z.x
	var a11 := value.y.y
	var a12 := value.z.y
	var a22 := value.z.z
	var off_diagonal_square := a01 * a01 + a02 * a02 + a12 * a12
	var eigenvalues: Array
	if off_diagonal_square <= 0.0:
		eigenvalues = [a00, a11, a22]
		eigenvalues.sort()
		return eigenvalues

	var mean := (a00 + a11 + a22) / 3.0
	var spread_square := (
		(a00 - mean) * (a00 - mean)
		+ (a11 - mean) * (a11 - mean)
		+ (a22 - mean) * (a22 - mean)
		+ 2.0 * off_diagonal_square)
	var spread := sqrt(maxf(spread_square / 6.0, 0.0))
	if spread <= 0.0 or not is_finite(spread):
		return [mean, mean, mean]

	var b00 := (a00 - mean) / spread
	var b01 := a01 / spread
	var b02 := a02 / spread
	var b11 := (a11 - mean) / spread
	var b12 := a12 / spread
	var b22 := (a22 - mean) / spread
	var normalized_determinant := (
		b00 * (b11 * b22 - b12 * b12)
		- b01 * (b01 * b22 - b12 * b02)
		+ b02 * (b01 * b12 - b11 * b02))
	var phase := acos(clampf(normalized_determinant * 0.5, -1.0, 1.0)) / 3.0
	var largest := mean + 2.0 * spread * cos(phase)
	var smallest := mean + 2.0 * spread * cos(phase + 2.0 * PI / 3.0)
	var middle := 3.0 * mean - largest - smallest
	eigenvalues = [smallest, middle, largest]
	eigenvalues.sort()
	return eigenvalues


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _basis_from_value(value: Variant) -> Basis:
	if value is Basis:
		return value
	if value is Dictionary:
		var rows: Dictionary = value
		return Basis(
			_vector3(rows.get("x")),
			_vector3(rows.get("y")),
			_vector3(rows.get("z")))
	return Basis(
		Vector3(INF, INF, INF),
		Vector3(INF, INF, INF),
		Vector3(INF, INF, INF))


static func _basis_is_finite(value: Basis) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()


static func _basis_magnitude(value: Basis) -> float:
	return maxf(
		value.x.length(), maxf(value.y.length(), value.z.length()))


static func _basis_max_abs_component(value: Basis) -> float:
	return maxf(
		maxf(absf(value.x.x), maxf(absf(value.x.y), absf(value.x.z))),
		maxf(
			maxf(absf(value.y.x), maxf(absf(value.y.y), absf(value.y.z))),
			maxf(absf(value.z.x), maxf(absf(value.z.y), absf(value.z.z)))))


static func _basis_max_abs_difference(left: Basis, right: Basis) -> float:
	return _basis_max_abs_component(Basis(
		left.x - right.x,
		left.y - right.y,
		left.z - right.z))


static func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
