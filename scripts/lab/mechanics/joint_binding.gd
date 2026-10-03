class_name LabJointBinding
extends RefCounted

## BR2 authoring-time hinge declaration between two observed bodies.
##
## WHY THIS EXISTS (the historical failure this contract forbids):
## the gait-era controller measured hinge angles by dotting a delta quaternion
## expressed in the CHILD's rest frame against an axis stored in the PARENT's
## frame. On the splayed quad_v2 rig every hip and knee angle silently read
## 0.414x its true value, and every rest_angle was then tuned against that
## lie. Separately, several controllers cached a joint's WORLD axis at
## construction time; the moment the parent rotated, the cached axis was
## wrong. BR2's gate therefore requires that no consumer ever reads a stored
## construction-time world axis.
##
## This binding stores ONLY local-frame quantities:
##
## - the hinge axis expressed in the parent body's local frame AND the same
##   axis expressed in the child body's local frame. Neither is "the" axis by
##   itself: at sample time both are pushed through their live transforms and
##   must agree in world space, or the sample is invalid. Storing both makes
##   a wrong-frame authoring mistake detectable instead of silently absorbed.
## - the hinge anchor expressed in both local frames. At sample time the two
##   world anchors must coincide within tolerance; a mismatch invalidates the
##   sample rather than letting angle/axis values drift on a broken joint.
## - the rest relative rotation (child orientation expressed in the parent's
##   local frame at construction). It must map the directed child-local axis
##   onto the directed parent-local axis. The measured parent-frame hinge
##   angle is the twist of
##       current_relative_rotation * rest_relative_rotation.inverse()
##   about the parent-local axis, so the angle is exactly zero at the
##   authored rest pose by construction. The order is not interchangeable:
##   rest.inverse() * current is a child-rest-frame delta and would need the
##   child-rest axis instead.
##
## The binding never touches world space. Every world-frame quantity is
## recomputed per sample by LabJointState from the two live body transforms.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

## Maximum tolerated deviation of an authored axis length from unit length.
## Axes are normalized after validation, so this only rejects grossly
## non-unit authoring input rather than accumulating float error.
const AXIS_UNIT_TOLERANCE := 1.0e-4

## Per-tick rotation ceiling used by the unwrapped-angle stream. If a hinge
## rotates more than this between two consecutive samples, the shortest-path
## unwrap is ambiguous (the true motion could have gone the long way around),
## so the sample is invalidated instead of guessing. PI/2 per tick at 60 Hz
## is 15 revolutions per second, far above any calibration fixture.
const DEFAULT_MAX_TICK_ROTATION_RAD := PI / 2.0

## The endpoint quaternion cannot distinguish delta from delta + k*TAU.  The
## unwrapped stream therefore compares every endpoint branch against an
## independently sampled angular-rate integral.  This is the largest accepted
## disagreement between the selected endpoint branch and that rate witness.
## It is an angle-per-sample envelope, not an angular-velocity tolerance.
const DEFAULT_UNWRAP_RATE_WITNESS_TOLERANCE_RAD := 2.0e-2
const MAX_UNWRAP_RATE_WITNESS_TOLERANCE_RAD := 1.0e-1

## Agreement limits are measurement-safety ceilings, not tuning defaults.
## A caller may choose a stricter tolerance for a small fixture, but may not
## make the gate so loose that a visibly broken joint is declared valid.
## Anchor separation is scale-normalized so a meter-tall test animal and a
## hundred-meter weird creature share the same contract: the caller records
## a morphology-derived characteristic length and the permitted disagreement
## remains a bounded fraction of it, rather than a hidden human-scale constant.
const MAX_AXIS_AGREEMENT_TOLERANCE_RAD := 0.1
const MAX_SWING_TOLERANCE_RAD := 0.1
const MAX_ANCHOR_AGREEMENT_TOLERANCE_FRACTION := 0.05
const MAX_ABS_INITIAL_TURN_INDEX := 1_000_000

const SCHEMA_VERSION := "joint_binding_v2"
const DIGEST_SCHEMA_VERSION := "joint_binding_digest_v1"


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var joint_id := StringName(String(configuration.get("joint_id", "")))
	var parent_body_id := StringName(
		String(configuration.get("parent_body_id", "")))
	var child_body_id := StringName(
		String(configuration.get("child_body_id", "")))
	if String(joint_id).is_empty():
		_add_error(errors, "JOINT_ID_EMPTY", "/joint_id",
			"A joint binding requires a stable joint_id")
	if String(parent_body_id).is_empty() or String(child_body_id).is_empty():
		_add_error(errors, "BODY_ID_EMPTY", "/parent_body_id",
			"A joint binding requires parent and child body ids")
	if parent_body_id == child_body_id:
		_add_error(errors, "BODY_ID_SELF_JOINT", "/child_body_id",
			"A joint cannot bind a body to itself")

	var axis_parent_local := _unit_vector(
		configuration.get("axis_parent_local"),
		"/axis_parent_local", errors)
	var axis_child_local := _unit_vector(
		configuration.get("axis_child_local"),
		"/axis_child_local", errors)
	var anchor_parent_local := _finite_vector(
		configuration.get("anchor_parent_local"),
		"/anchor_parent_local", errors)
	var anchor_child_local := _finite_vector(
		configuration.get("anchor_child_local"),
		"/anchor_child_local", errors)

	var rest_value: Variant = configuration.get(
		"rest_child_rotation_parent_local", Quaternion.IDENTITY)
	var rest_rotation := Quaternion.IDENTITY
	if rest_value is Quaternion:
		rest_rotation = (rest_value as Quaternion)
	else:
		_add_error(errors, "REST_ROTATION_TYPE", "/rest_child_rotation_parent_local",
			"Rest rotation must be a Quaternion")
	if not rest_rotation.is_finite() \
			or absf(rest_rotation.length() - 1.0) > AXIS_UNIT_TOLERANCE:
		_add_error(errors, "REST_ROTATION_NOT_UNIT",
			"/rest_child_rotation_parent_local",
			"Rest rotation must be a finite unit quaternion")
	elif rest_rotation.length() > 0.0:
		rest_rotation = _canonicalize_quaternion(rest_rotation.normalized())

	var max_tick_rotation := float(configuration.get(
		"max_tick_rotation_rad", DEFAULT_MAX_TICK_ROTATION_RAD))
	if not is_finite(max_tick_rotation) \
			or max_tick_rotation <= 0.0 or max_tick_rotation >= PI:
		_add_error(errors, "MAX_TICK_ROTATION_DOMAIN", "/max_tick_rotation_rad",
			"Per-tick rotation ceiling must be finite, positive, and below PI")
	var unwrap_rate_witness_tolerance := float(configuration.get(
		"unwrap_rate_witness_tolerance_rad",
		DEFAULT_UNWRAP_RATE_WITNESS_TOLERANCE_RAD))
	if not is_finite(unwrap_rate_witness_tolerance) \
			or unwrap_rate_witness_tolerance <= 0.0 \
			or unwrap_rate_witness_tolerance \
				> MAX_UNWRAP_RATE_WITNESS_TOLERANCE_RAD \
			or unwrap_rate_witness_tolerance >= max_tick_rotation:
		_add_error(errors, "UNWRAP_RATE_WITNESS_TOLERANCE_DOMAIN",
			"/unwrap_rate_witness_tolerance_rad",
			"Rate-witness residual tolerance must be positive, at most %.3f rad, and below the tick ceiling"
				% MAX_UNWRAP_RATE_WITNESS_TOLERANCE_RAD)

	var anchor_tolerance := float(configuration.get(
		"anchor_agreement_tolerance_m", 1.0e-4))
	var local_joint_scale_m := float(configuration.get(
		"local_joint_scale_m", 1.0))
	var morphology_config_digest := String(configuration.get(
		"morphology_config_digest_sha256", ""))
	var local_scale_basis := String(configuration.get(
		"local_joint_scale_basis", ""))
	var axis_tolerance := float(configuration.get(
		"axis_agreement_tolerance_rad", 1.0e-3))
	var swing_tolerance := float(configuration.get(
		"swing_tolerance_rad", axis_tolerance))
	if not is_finite(local_joint_scale_m) or local_joint_scale_m <= 0.0:
		_add_error(errors, "LOCAL_JOINT_SCALE_DOMAIN",
			"/local_joint_scale_m",
			"Local joint scale must be finite and positive")
		local_joint_scale_m = 1.0
	if not _is_sha256_digest(morphology_config_digest):
		_add_error(errors, "MORPHOLOGY_CONFIG_DIGEST_INVALID",
			"/morphology_config_digest_sha256",
			"Local scale and tolerances must be bound to a canonical morphology configuration digest")
	if local_scale_basis not in ["adjacent_part_extent_min_v1",
			"joint_fixture_extent_min_v1"]:
		_add_error(errors, "LOCAL_JOINT_SCALE_BASIS_INVALID",
			"/local_joint_scale_basis",
			"Local scale must name a registered derivation from adjacent immutable geometry")
	if not is_finite(anchor_tolerance) or anchor_tolerance <= 0.0:
		_add_error(errors, "TOLERANCE_DOMAIN",
			"/anchor_agreement_tolerance_m",
			"Anchor agreement tolerance must be finite and positive")
	elif anchor_tolerance / local_joint_scale_m \
			> MAX_ANCHOR_AGREEMENT_TOLERANCE_FRACTION:
		_add_error(errors, "ANCHOR_TOLERANCE_TOO_LARGE",
			"/anchor_agreement_tolerance_m",
			"Anchor tolerance may not exceed %.1f%% of characteristic length"
				% (100.0 * MAX_ANCHOR_AGREEMENT_TOLERANCE_FRACTION))
	if not is_finite(axis_tolerance) or axis_tolerance <= 0.0:
		_add_error(errors, "TOLERANCE_DOMAIN",
			"/axis_agreement_tolerance_rad",
			"Axis agreement tolerance must be finite and positive")
	elif axis_tolerance > MAX_AXIS_AGREEMENT_TOLERANCE_RAD:
		_add_error(errors, "AXIS_TOLERANCE_TOO_LARGE",
			"/axis_agreement_tolerance_rad",
			"Axis tolerance may not exceed %.3f rad"
				% MAX_AXIS_AGREEMENT_TOLERANCE_RAD)
	if not is_finite(swing_tolerance) or swing_tolerance <= 0.0:
		_add_error(errors, "TOLERANCE_DOMAIN", "/swing_tolerance_rad",
			"Swing tolerance must be finite and positive")
	elif swing_tolerance > MAX_SWING_TOLERANCE_RAD:
		_add_error(errors, "SWING_TOLERANCE_TOO_LARGE",
			"/swing_tolerance_rad",
			"Swing tolerance may not exceed %.3f rad"
				% MAX_SWING_TOLERANCE_RAD)

	# Static frame oracle: at the rest pose both authored axis vectors must
	# name the SAME DIRECTED physical axis. Using abs(dot) here would accept
	# an inverted child axis and make the angle sign morphology-dependent.
	if axis_parent_local.is_finite() and axis_child_local.is_finite() \
			and rest_rotation.is_finite():
		var child_axis_in_parent := (
			Basis(rest_rotation) * axis_child_local).normalized()
		var rest_axis_error := axis_parent_local.normalized().angle_to(
			child_axis_in_parent)
		if not is_finite(rest_axis_error) \
				or rest_axis_error > minf(
					axis_tolerance, MAX_AXIS_AGREEMENT_TOLERANCE_RAD):
			_add_error(errors, "REST_AXIS_MISMATCH",
				"/rest_child_rotation_parent_local",
				"Rest rotation must map the directed child axis onto the parent axis")

	var requires_unwrapped_angle_value: Variant = configuration.get(
		"requires_unwrapped_angle", true)
	var requires_unwrapped_angle := true
	if requires_unwrapped_angle_value is bool:
		requires_unwrapped_angle = bool(requires_unwrapped_angle_value)
	else:
		_add_error(errors, "UNWRAP_FLAG_TYPE", "/requires_unwrapped_angle",
			"requires_unwrapped_angle must be a bool")
	var initial_turn_value: Variant = configuration.get("initial_turn_index", 0)
	var initial_turn_index := 0
	if initial_turn_value is int:
		initial_turn_index = int(initial_turn_value)
		if absi(initial_turn_index) > MAX_ABS_INITIAL_TURN_INDEX:
			_add_error(errors, "INITIAL_TURN_INDEX_DOMAIN",
				"/initial_turn_index",
				"initial_turn_index exceeds the finite precision safety bound")
	else:
		_add_error(errors, "INITIAL_TURN_INDEX_TYPE", "/initial_turn_index",
			"initial_turn_index must be an integer")

	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"joint_id": String(joint_id),
		"joint_kind": "hinge",
		"parent_body_id": String(parent_body_id),
		"child_body_id": String(child_body_id),
		# Local-frame authoring only. World axes and world anchors are
		# recomputed from live transforms on every sample; nothing here may be
		# interpreted as a world-space value.
		"axis_parent_local": _array3(axis_parent_local.normalized()),
		"axis_child_local": _array3(axis_child_local.normalized()),
		"anchor_parent_local": _array3(anchor_parent_local),
		"anchor_child_local": _array3(anchor_child_local),
		"rest_child_rotation_parent_local": _array4(rest_rotation),
		"max_tick_rotation_rad": max_tick_rotation,
		"unwrap_rate_witness_tolerance_rad":
			unwrap_rate_witness_tolerance,
		"requires_unwrapped_angle": requires_unwrapped_angle,
		"initial_turn_index": initial_turn_index,
		"anchor_agreement_tolerance_m": anchor_tolerance,
		"local_joint_scale_m": local_joint_scale_m,
		"local_joint_scale_basis": local_scale_basis,
		"morphology_config_digest_sha256": morphology_config_digest,
		"anchor_agreement_tolerance_fraction": (
			anchor_tolerance / local_joint_scale_m),
		"axis_agreement_tolerance_rad": axis_tolerance,
		"swing_tolerance_rad": swing_tolerance,
	}
	var digest := CanonicalJsonScript.sha256({
		"digest_schema_version": DIGEST_SCHEMA_VERSION,
		"binding": payload,
	})
	payload["binding_digest_sha256"] = digest
	return {
		"ok": true,
		"errors": [],
		"binding": FrozenValueScript.snapshot(payload),
	}


## Recomputes the digest from the exact v2 semantic fields.  Consumers call
## this before trusting a dictionary that merely claims to be a built binding.
static func recompute_digest(binding: Dictionary) -> String:
	var payload := binding.duplicate(true)
	payload.erase("binding_digest_sha256")
	return CanonicalJsonScript.sha256({
		"digest_schema_version": DIGEST_SCHEMA_VERSION,
		"binding": payload,
	})


static func digest_is_valid(binding: Dictionary) -> bool:
	var recorded := String(binding.get("binding_digest_sha256", ""))
	return _is_sha256_digest(recorded) and recorded == recompute_digest(binding)


static func _unit_vector(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> Vector3:
	var vector := _finite_vector(value, path, errors)
	if vector.is_finite() and absf(vector.length() - 1.0) > AXIS_UNIT_TOLERANCE:
		_add_error(errors, "AXIS_NOT_UNIT", path,
			"Axis must be authored as a unit vector")
	return vector


static func _finite_vector(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> Vector3:
	if value is Vector3 and (value as Vector3).is_finite():
		return value
	_add_error(errors, "VECTOR_INVALID", path,
		"Expected a finite Vector3")
	return Vector3(INF, INF, INF)


static func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _array4(value: Quaternion) -> Array:
	return [value.x, value.y, value.z, value.w]


## q and -q encode the same rotation.  Resolve the double cover before the
## binding is hashed so physically identical authored rest poses have one
## byte identity.  The lexicographic tie-break handles exact 180-degree
## quaternions where w is zero.
static func _canonicalize_quaternion(value: Quaternion) -> Quaternion:
	var negate := value.w < 0.0 \
		or (value.w == 0.0 and value.x < 0.0) \
		or (value.w == 0.0 and value.x == 0.0 and value.y < 0.0) \
		or (value.w == 0.0 and value.x == 0.0 and value.y == 0.0 \
			and value.z < 0.0)
	if not negate:
		return value
	return Quaternion(-value.x, -value.y, -value.z, -value.w)


static func _is_sha256_digest(value: String) -> bool:
	if value.length() != 71 or not value.begins_with("sha256:"):
		return false
	for index in range(7, value.length()):
		var character := value.substr(index, 1)
		if character not in "0123456789abcdef":
			return false
	return true


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
