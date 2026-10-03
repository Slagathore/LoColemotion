class_name LabJointState
extends RefCounted

## BR2.1 sample-time hinge observation.
##
## Coordinate convention:
##     R_relative = inverse(R_parent_world) * R_child_world
##     R_delta_parent = R_relative * inverse(R_rest_parent)
##
## R_delta_parent and axis_parent_local are therefore expressed in the same
## parent-local frame.  Positive angle is a right-hand child rotation about the
## current world axis.
##
## Unwrap observability:
## endpoint orientations alone cannot distinguish delta from delta + k*TAU.
## A continuous branch is accepted only when the independently sampled engine
## angular velocity and step duration select one endpoint branch inside the
## binding's preregistered residual envelope.  Endpoint-only data never claims
## to prove the physical path.
##
## Availability:
## frame identity, geometry, wrapped angle, angular rate, and unwrap lineage are
## separate validity domains.  A dropped predecessor makes only the unwrapped
## coordinate unavailable; trustworthy current-tick channels remain numeric.
## Unavailable numerical channels are null, never zero, INF, or NAN.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const JointBindingScript := preload(
	"res://scripts/lab/mechanics/joint_binding.gd")

const SCHEMA_VERSION := "joint_state_v2"
const REQUIRED_BINDING_SCHEMA_VERSION := "joint_binding_v2"
const REQUIRED_BODY_SAMPLE_SCHEMA_VERSION := "mechanics_body_sample_v1"
const INITIALIZATION_WITNESS_SCHEMA_VERSION := \
	"joint_unwrap_initialization_witness_v1"
const RIGID_BASIS_TOLERANCE := 1.0e-4
const STEP_EQUALITY_TOLERANCE_S := 1.0e-12
const MAX_INITIALIZATION_POSE_RESIDUAL_RAD := 0.1
const MAX_ABS_RATE_WITNESS_TURNS := 1_000_000
const VALID_SAMPLE_PHASES := ["integrate_callback", "post_step"]
const VALID_INITIALIZATION_REASONS := [
	"fixture_scaffold",
	"known_authored_pose",
	"absolute_encoder_branch",
]


static func sample(
		binding: Dictionary,
		parent_sample: Dictionary,
		child_sample: Dictionary,
		previous_state: Dictionary = {},
		stream_context: Dictionary = {}) -> Dictionary:
	var binding_reasons := _binding_invalid_reasons(binding)
	var identity_reasons := _frame_identity_invalid_reasons(
		binding, parent_sample, child_sample)
	var geometry_reasons: Array[String] = []

	var parent_transform := _transform_from_value(
		parent_sample.get("transform"))
	var child_transform := _transform_from_value(child_sample.get("transform"))
	var parent_transform_finite := _transform_is_finite(parent_transform)
	var child_transform_finite := _transform_is_finite(child_transform)
	if not parent_transform_finite or not child_transform_finite:
		geometry_reasons.append("BODY_TRANSFORM_NONFINITE")
	if not parent_transform_finite:
		parent_transform = Transform3D.IDENTITY
	if not child_transform_finite:
		child_transform = Transform3D.IDENTITY
	var parent_basis_is_rigid := _basis_is_rigid(parent_transform.basis)
	var child_basis_is_rigid := _basis_is_rigid(child_transform.basis)
	if not parent_basis_is_rigid:
		geometry_reasons.append("PARENT_BASIS_NOT_RIGID")
	if not child_basis_is_rigid:
		geometry_reasons.append("CHILD_BASIS_NOT_RIGID")

	var axis_parent_local := _vector3(binding.get("axis_parent_local"))
	var axis_child_local := _vector3(binding.get("axis_child_local"))
	var anchor_parent_local := _vector3(binding.get("anchor_parent_local"))
	var anchor_child_local := _vector3(binding.get("anchor_child_local"))
	var rest_rotation := _quaternion(
		binding.get("rest_child_rotation_parent_local"))
	var binding_vectors_valid := (
		axis_parent_local.is_finite()
		and axis_child_local.is_finite()
		and anchor_parent_local.is_finite()
		and anchor_child_local.is_finite()
		and rest_rotation.is_finite())
	if not binding_vectors_valid:
		geometry_reasons.append("BINDING_GEOMETRY_INVALID")
		axis_parent_local = Vector3.BACK
		axis_child_local = Vector3.BACK
		anchor_parent_local = Vector3.ZERO
		anchor_child_local = Vector3.ZERO
		rest_rotation = Quaternion.IDENTITY
	else:
		axis_parent_local = axis_parent_local.normalized()
		axis_child_local = axis_child_local.normalized()
		rest_rotation = rest_rotation.normalized()

	var axis_tolerance := float(binding.get(
		"axis_agreement_tolerance_rad", NAN))
	var anchor_tolerance := float(binding.get(
		"anchor_agreement_tolerance_m", NAN))
	var swing_tolerance := float(binding.get("swing_tolerance_rad", NAN))

	var axis_world_from_parent := Vector3.ZERO
	var axis_world_from_child := Vector3.ZERO
	var axis_agreement_rad := NAN
	var anchor_parent_world := Vector3.ZERO
	var anchor_child_world := Vector3.ZERO
	var anchor_error_m := NAN
	if binding_reasons.is_empty() and identity_reasons.is_empty() \
			and geometry_reasons.is_empty():
		axis_world_from_parent = (
			parent_transform.basis * axis_parent_local).normalized()
		axis_world_from_child = (
			child_transform.basis * axis_child_local).normalized()
		if not axis_world_from_parent.is_finite() \
				or not axis_world_from_child.is_finite():
			geometry_reasons.append("AXIS_RECOMPUTATION_NONFINITE")
		else:
			axis_agreement_rad = axis_world_from_parent.angle_to(
				axis_world_from_child)
			if not is_finite(axis_agreement_rad):
				geometry_reasons.append("AXIS_RECOMPUTATION_NONFINITE")
			elif axis_agreement_rad > axis_tolerance:
				geometry_reasons.append("AXIS_FRAME_DISAGREEMENT")

		anchor_parent_world = parent_transform * anchor_parent_local
		anchor_child_world = child_transform * anchor_child_local
		anchor_error_m = anchor_parent_world.distance_to(anchor_child_world)
		if not is_finite(anchor_error_m):
			geometry_reasons.append("ANCHOR_RECOMPUTATION_NONFINITE")
		elif anchor_error_m > anchor_tolerance:
			geometry_reasons.append("ANCHOR_MISMATCH")

	var geometry_available := binding_reasons.is_empty() \
		and identity_reasons.is_empty() and geometry_reasons.is_empty()

	var angle_reasons: Array[String] = []
	var wrapped_angle_rad := NAN
	var swing_angle_rad := NAN
	if geometry_available:
		var parent_rotation := (
			parent_transform.basis.get_rotation_quaternion())
		var child_rotation := child_transform.basis.get_rotation_quaternion()
		var relative_rotation := parent_rotation.inverse() * child_rotation
		var delta_from_rest := relative_rotation * rest_rotation.inverse()
		if delta_from_rest.w < 0.0:
			delta_from_rest = Quaternion(
				-delta_from_rest.x,
				-delta_from_rest.y,
				-delta_from_rest.z,
				-delta_from_rest.w)
		var quaternion_vector := Vector3(
			delta_from_rest.x, delta_from_rest.y, delta_from_rest.z)
		var axis_component := quaternion_vector.dot(axis_parent_local)
		wrapped_angle_rad = 2.0 * atan2(
			axis_component, delta_from_rest.w)
		var twist := Quaternion(
			axis_parent_local.x * axis_component,
			axis_parent_local.y * axis_component,
			axis_parent_local.z * axis_component,
			delta_from_rest.w)
		if twist.length() > 1.0e-9:
			var swing := delta_from_rest * twist.normalized().inverse()
			swing_angle_rad = 2.0 * acos(
				clampf(absf(swing.w), 0.0, 1.0))
		else:
			swing_angle_rad = PI
		if not is_finite(wrapped_angle_rad) \
				or not is_finite(swing_angle_rad):
			angle_reasons.append("ANGLE_DECOMPOSITION_NONFINITE")
		elif swing_angle_rad > swing_tolerance:
			angle_reasons.append("HINGE_SWING_EXCEEDED")
	else:
		angle_reasons.append("JOINT_GEOMETRY_UNAVAILABLE")
	var angle_available := geometry_available and angle_reasons.is_empty()

	var rate_reasons: Array[String] = []
	var axis_rate_rad_s := NAN
	var off_axis_rate_rad_s := NAN
	var step_s := _sample_step_s(parent_sample)
	if geometry_available:
		var parent_omega := _vector3(parent_sample.get("angular_velocity"))
		var child_omega := _vector3(child_sample.get("angular_velocity"))
		var relative_omega := child_omega - parent_omega
		if not relative_omega.is_finite():
			rate_reasons.append("ANGULAR_VELOCITY_NONFINITE")
		else:
			axis_rate_rad_s = relative_omega.dot(axis_world_from_parent)
			off_axis_rate_rad_s = (
				relative_omega
				- axis_rate_rad_s * axis_world_from_parent).length()
			if not is_finite(axis_rate_rad_s) \
					or not is_finite(off_axis_rate_rad_s):
				rate_reasons.append("ANGULAR_RATE_PROJECTION_NONFINITE")
	else:
		rate_reasons.append("JOINT_GEOMETRY_UNAVAILABLE")
	var rate_available := geometry_available and rate_reasons.is_empty()

	var requires_unwrapped_angle := bool(binding.get(
		"requires_unwrapped_angle", true))
	var segment_value: Variant = stream_context.get("unwrap_segment_id")
	var unwrap_segment_id := -1
	var stream_context_reasons: Array[String] = []
	if segment_value is int and int(segment_value) >= 0:
		unwrap_segment_id = int(segment_value)
	elif requires_unwrapped_angle:
		stream_context_reasons.append("UNWRAP_SEGMENT_ID_INVALID")

	var unwrap_reasons: Array[String] = []
	unwrap_reasons.append_array(stream_context_reasons)
	var unwrapped_angle_rad := NAN
	var unwrapped_available := false
	var initialized_this_sample := false
	var initialization_witness_digest: Variant = null
	var segment_origin_step_id := -1
	var segment_origin_capture_epoch := -1
	var rate_witness_delta_rad: Variant = null
	var rate_witness_residual_rad: Variant = null
	var endpoint_branch_turn_count: Variant = null

	if requires_unwrapped_angle:
		if not angle_available:
			unwrap_reasons.append("WRAPPED_ANGLE_UNAVAILABLE")
		elif not rate_available:
			unwrap_reasons.append("ANGULAR_RATE_UNAVAILABLE")
		elif previous_state.is_empty():
			var witness_value: Variant = stream_context.get(
				"initialization_witness")
			var witness: Dictionary = (
				witness_value if witness_value is Dictionary else {})
			var witness_result := _validate_initialization_witness(
				binding,
				parent_sample,
				witness,
				unwrap_segment_id,
				wrapped_angle_rad)
			unwrap_reasons.append_array(
				witness_result["reasons"] as Array[String])
			if unwrap_reasons.is_empty():
				var initial_turn_index := int(
					witness["authored_turn_index"])
				unwrapped_angle_rad = wrapped_angle_rad \
					+ TAU * initial_turn_index
				unwrapped_available = is_finite(unwrapped_angle_rad)
				initialized_this_sample = unwrapped_available
				initialization_witness_digest = \
					witness_result["witness_digest_sha256"]
				segment_origin_step_id = int(parent_sample["physics_step_id"])
				segment_origin_capture_epoch = int(
					parent_sample["capture_epoch"])
				if not unwrapped_available:
					unwrap_reasons.append("UNWRAPPED_ANGLE_NONFINITE")
		else:
			var predecessor_reasons := _predecessor_invalid_reasons(
				binding,
				parent_sample,
				previous_state,
				unwrap_segment_id)
			unwrap_reasons.append_array(predecessor_reasons)
			if unwrap_reasons.is_empty():
				# Carry the segment-origin witness even when this tick later
				# loses only its unwrapped channel. Diagnostics can then show
				# which accepted initialization the broken lineage came from.
				initialization_witness_digest = previous_state.get(
					"initialization_witness_digest_sha256")
				segment_origin_step_id = int(previous_state.get(
					"segment_origin_step_id", -1))
				segment_origin_capture_epoch = int(previous_state.get(
					"segment_origin_capture_epoch", -1))
				var previous_wrapped := float(
					previous_state["wrapped_angle_rad"])
				var previous_unwrapped := float(
					previous_state["unwrapped_angle_rad"])
				var previous_rate := float(
					previous_state["axis_rate_rad_s"])
				var shortest_delta := wrapf(
					wrapped_angle_rad - previous_wrapped + PI,
					0.0,
					TAU) - PI
				var integrated_rate_delta := 0.5 * (
					previous_rate + axis_rate_rad_s) * step_s
				rate_witness_delta_rad = integrated_rate_delta
				var raw_turn_selection := (
					integrated_rate_delta - shortest_delta) / TAU
				if not is_finite(raw_turn_selection) \
						or absf(raw_turn_selection) \
							> MAX_ABS_RATE_WITNESS_TURNS:
					unwrap_reasons.append(
						"UNWRAP_RATE_WITNESS_OUT_OF_DOMAIN")
				else:
					var selected_turns := roundi(raw_turn_selection)
					var witnessed_delta := shortest_delta \
						+ TAU * selected_turns
					var residual := absf(
						witnessed_delta - integrated_rate_delta)
					endpoint_branch_turn_count = selected_turns
					rate_witness_residual_rad = residual
					if residual > float(binding[
							"unwrap_rate_witness_tolerance_rad"]):
						unwrap_reasons.append(
							"UNWRAP_RATE_WITNESS_DISAGREEMENT")
					if absf(witnessed_delta) > float(
							binding["max_tick_rotation_rad"]):
						unwrap_reasons.append(
							"WRAPPED_ANGLE_AMBIGUOUS")
					if unwrap_reasons.is_empty():
						unwrapped_angle_rad = previous_unwrapped \
							+ witnessed_delta
						unwrapped_available = is_finite(
							unwrapped_angle_rad)
						if not unwrapped_available:
							unwrap_reasons.append(
								"UNWRAPPED_ANGLE_NONFINITE")
	else:
		unwrap_reasons.append("UNWRAPPED_ANGLE_NOT_REQUESTED")

	if requires_unwrapped_angle and not unwrapped_available \
			and not unwrap_reasons.has(
				"UNWRAPPED_ANGLE_STREAM_DISCONTINUITY"):
		unwrap_reasons.append("UNWRAPPED_ANGLE_STREAM_DISCONTINUITY")

	var all_reasons: Array[String] = []
	for reason_group in [
		binding_reasons,
		identity_reasons,
		geometry_reasons,
		angle_reasons,
		rate_reasons,
		unwrap_reasons,
	]:
		for reason in reason_group:
			_append_unique(all_reasons, String(reason))

	var core_finite := binding_reasons.is_empty() \
		and identity_reasons.is_empty() \
		and geometry_available and angle_available and rate_available
	var complete := core_finite \
		and (not requires_unwrapped_angle or unwrapped_available)
	var binding_digest := String(binding.get(
		"binding_digest_sha256", ""))
	var provenance := _provenance(parent_sample)
	var availability := _availability(
		binding_reasons.is_empty(),
		identity_reasons,
		geometry_available,
		geometry_reasons,
		angle_available,
		angle_reasons,
		rate_available,
		rate_reasons,
		unwrapped_available,
		unwrap_reasons)

	return FrozenValueScript.snapshot({
		"schema_version": SCHEMA_VERSION,
		"joint_id": String(binding.get("joint_id", "")),
		"parent_body_id": String(binding.get("parent_body_id", "")),
		"child_body_id": String(binding.get("child_body_id", "")),
		"binding_digest_sha256": (
			binding_digest if binding_reasons.is_empty() else null),
		"physics_step_id": _safe_nonnegative_int(
			parent_sample.get("physics_step_id")),
		"capture_epoch": _safe_nonnegative_int(
			parent_sample.get("capture_epoch")),
		"sample_phase": _safe_stable_string(
			parent_sample.get("sample_phase")),
		"step_s": step_s if identity_reasons.is_empty() else null,
		"input_provenance": (
			provenance if identity_reasons.is_empty() else null),
		"unwrap_segment_id": (
			unwrap_segment_id if unwrap_segment_id >= 0 else null),
		"segment_origin_step_id": (
			segment_origin_step_id if segment_origin_step_id >= 0 else null),
		"segment_origin_capture_epoch": (
			segment_origin_capture_epoch
			if segment_origin_capture_epoch >= 0 else null),
		"initialized_this_sample": initialized_this_sample,
		"initialization_witness_digest_sha256":
			initialization_witness_digest,
		"current_axis_world": (
			_array3(axis_world_from_parent) if geometry_available else null),
		"current_axis_world_from_child": (
			_array3(axis_world_from_child) if geometry_available else null),
		"axis_agreement_error_rad": (
			axis_agreement_rad if geometry_available else null),
		"anchor_parent_world_m": (
			_array3(anchor_parent_world) if geometry_available else null),
		"anchor_child_world_m": (
			_array3(anchor_child_world) if geometry_available else null),
		"anchor_agreement_error_m": (
			anchor_error_m if geometry_available else null),
		"wrapped_angle_rad": (
			wrapped_angle_rad if angle_available else null),
		"unwrapped_angle_rad": (
			unwrapped_angle_rad if unwrapped_available else null),
		"unwrapped_angle_available": unwrapped_available,
		"angle_is_unwrapped": requires_unwrapped_angle \
			and unwrapped_available,
		"swing_residual_rad": (
			swing_angle_rad if angle_available else null),
		"axis_rate_rad_s": (
			axis_rate_rad_s if rate_available else null),
		"off_axis_rate_rad_s": (
			off_axis_rate_rad_s if rate_available else null),
		"rate_witness_delta_rad": rate_witness_delta_rad,
		"rate_witness_residual_rad": rate_witness_residual_rad,
		"endpoint_branch_turn_count": endpoint_branch_turn_count,
		"observation_valid": core_finite,
		"complete": complete,
		# All present numerical payloads are finite.  An unavailable optional
		# unwrap channel does not poison trustworthy current-tick channels.
		"finite": core_finite,
		"invalid_reasons": all_reasons,
		"availability": availability,
	})


static func _binding_invalid_reasons(
		binding: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if String(binding.get("schema_version", "")) \
			!= REQUIRED_BINDING_SCHEMA_VERSION:
		reasons.append("BINDING_SCHEMA_UNSUPPORTED")
	if String(binding.get("joint_id", "")).is_empty() \
			or String(binding.get("parent_body_id", "")).is_empty() \
			or String(binding.get("child_body_id", "")).is_empty():
		reasons.append("BINDING_ID_INVALID")
	var axis_parent := _vector3(binding.get("axis_parent_local"))
	var axis_child := _vector3(binding.get("axis_child_local"))
	var anchor_parent := _vector3(binding.get("anchor_parent_local"))
	var anchor_child := _vector3(binding.get("anchor_child_local"))
	var rest := _quaternion(binding.get(
		"rest_child_rotation_parent_local"))
	if not axis_parent.is_finite() \
			or absf(axis_parent.length() - 1.0) > 1.0e-4 \
			or not axis_child.is_finite() \
			or absf(axis_child.length() - 1.0) > 1.0e-4:
		reasons.append("BINDING_AXIS_INVALID")
	if not anchor_parent.is_finite() or not anchor_child.is_finite():
		reasons.append("BINDING_ANCHOR_INVALID")
	if not rest.is_finite() or absf(rest.length() - 1.0) > 1.0e-4:
		reasons.append("BINDING_REST_ROTATION_INVALID")
	var axis_tolerance := float(binding.get(
		"axis_agreement_tolerance_rad", NAN))
	var anchor_tolerance := float(binding.get(
		"anchor_agreement_tolerance_m", NAN))
	var local_scale := float(binding.get("local_joint_scale_m", NAN))
	var swing_tolerance := float(binding.get("swing_tolerance_rad", NAN))
	var rate_tolerance := float(binding.get(
		"unwrap_rate_witness_tolerance_rad", NAN))
	var max_tick := float(binding.get("max_tick_rotation_rad", NAN))
	if not is_finite(axis_tolerance) or axis_tolerance <= 0.0 \
			or axis_tolerance > JointBindingScript.MAX_AXIS_AGREEMENT_TOLERANCE_RAD \
			or not is_finite(anchor_tolerance) or anchor_tolerance <= 0.0 \
			or not is_finite(local_scale) or local_scale <= 0.0 \
			or anchor_tolerance / local_scale \
				> JointBindingScript.MAX_ANCHOR_AGREEMENT_TOLERANCE_FRACTION \
			or not is_finite(swing_tolerance) or swing_tolerance <= 0.0 \
			or swing_tolerance > JointBindingScript.MAX_SWING_TOLERANCE_RAD \
			or not is_finite(max_tick) or max_tick <= 0.0 or max_tick >= PI \
			or not is_finite(rate_tolerance) or rate_tolerance <= 0.0 \
			or rate_tolerance \
				> JointBindingScript.MAX_UNWRAP_RATE_WITNESS_TOLERANCE_RAD \
			or rate_tolerance >= max_tick:
		reasons.append("BINDING_TOLERANCE_INVALID")
	if not _is_sha256_digest(String(binding.get(
			"morphology_config_digest_sha256", ""))) \
			or String(binding.get("local_joint_scale_basis", "")) not in [
				"adjacent_part_extent_min_v1",
				"joint_fixture_extent_min_v1",
			]:
		reasons.append("BINDING_SCALE_PROVENANCE_INVALID")
	if axis_parent.is_finite() and axis_child.is_finite() and rest.is_finite():
		var rest_axis_error := axis_parent.angle_to(
			Basis(rest.normalized()) * axis_child)
		if not is_finite(rest_axis_error) \
				or rest_axis_error > minf(
					axis_tolerance,
					JointBindingScript.MAX_AXIS_AGREEMENT_TOLERANCE_RAD):
			reasons.append("BINDING_REST_AXIS_MISMATCH")
	if reasons.is_empty() and not JointBindingScript.digest_is_valid(binding):
		reasons.append("BINDING_DIGEST_MISMATCH")
	return reasons


static func _frame_identity_invalid_reasons(
		binding: Dictionary,
		parent: Dictionary,
		child: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	for sample_value in [parent, child]:
		var body: Dictionary = sample_value
		if String(body.get("schema_version", "")) \
				!= REQUIRED_BODY_SAMPLE_SCHEMA_VERSION:
			_append_unique(reasons, "BODY_SAMPLE_SCHEMA_UNSUPPORTED")
		if typeof(body.get("physics_step_id")) != TYPE_INT \
				or int(body.get("physics_step_id", -1)) < 0:
			_append_unique(reasons, "BODY_SAMPLE_STEP_INVALID")
		if typeof(body.get("capture_epoch")) != TYPE_INT \
				or int(body.get("capture_epoch", -1)) < 0:
			_append_unique(reasons, "BODY_SAMPLE_EPOCH_INVALID")
		var phase: Variant = body.get("sample_phase")
		if not (phase is String or phase is StringName) \
				or String(phase) not in VALID_SAMPLE_PHASES:
			_append_unique(reasons, "BODY_SAMPLE_PHASE_INVALID")
		var step_value: Variant = body.get("step_s")
		if not (step_value is float or step_value is int) \
				or not is_finite(float(step_value)) \
				or float(step_value) <= 0.0:
			_append_unique(reasons, "BODY_SAMPLE_STEP_DURATION_INVALID")
		for field in [
			"body_id",
			"run_id",
			"capture_stream_id",
			"observer_profile_id",
			"observer_adapter_id",
		]:
			var value: Variant = body.get(field)
			if not (value is String or value is StringName) \
					or String(value).is_empty():
				_append_unique(
					reasons,
					"BODY_SAMPLE_%s_INVALID" % field.to_upper())
		if not bool(body.get("finite", false)):
			_append_unique(reasons, "BODY_SAMPLE_NOT_FINITE")

	if String(parent.get("body_id", "")) \
			!= String(binding.get("parent_body_id", "")) \
			or String(child.get("body_id", "")) \
				!= String(binding.get("child_body_id", "")):
		reasons.append("BODY_SAMPLE_IDENTITY_MISMATCH")
	if typeof(parent.get("physics_step_id")) == TYPE_INT \
			and typeof(child.get("physics_step_id")) == TYPE_INT \
			and int(parent["physics_step_id"]) \
				!= int(child["physics_step_id"]):
		reasons.append("BODY_SAMPLES_SPAN_STEPS")
	if typeof(parent.get("capture_epoch")) == TYPE_INT \
			and typeof(child.get("capture_epoch")) == TYPE_INT \
			and int(parent["capture_epoch"]) != int(child["capture_epoch"]):
		reasons.append("BODY_SAMPLES_SPAN_EPOCHS")
	if String(parent.get("sample_phase", "")) \
			!= String(child.get("sample_phase", "__missing__")):
		reasons.append("BODY_SAMPLES_SPAN_PHASES")
	if _valid_positive_step(parent.get("step_s")) \
			and _valid_positive_step(child.get("step_s")) \
			and absf(float(parent["step_s"]) - float(child["step_s"])) \
				> STEP_EQUALITY_TOLERANCE_S:
		reasons.append("BODY_SAMPLES_SPAN_STEP_DURATIONS")
	for field in [
		"run_id",
		"capture_stream_id",
		"observer_profile_id",
		"observer_adapter_id",
		"schema_version",
	]:
		if String(parent.get(field, "")) != String(child.get(field, "")):
			reasons.append("BODY_SAMPLES_SPAN_%s" % field.to_upper())
	return reasons


static func _validate_initialization_witness(
		binding: Dictionary,
		current_sample: Dictionary,
		witness: Dictionary,
		unwrap_segment_id: int,
		wrapped_angle_rad: float) -> Dictionary:
	var reasons: Array[String] = []
	if String(witness.get("schema_version", "")) \
			!= INITIALIZATION_WITNESS_SCHEMA_VERSION:
		reasons.append("UNWRAP_INITIALIZATION_WITNESS_MISSING_OR_UNSUPPORTED")
	if int(witness.get("unwrap_segment_id", -1)) != unwrap_segment_id:
		reasons.append("UNWRAP_INITIALIZATION_SEGMENT_MISMATCH")
	if String(witness.get("joint_id", "")) \
			!= String(binding.get("joint_id", "")) \
			or String(witness.get("binding_digest_sha256", "")) \
				!= String(binding.get("binding_digest_sha256", "")):
		reasons.append("UNWRAP_INITIALIZATION_BINDING_MISMATCH")
	if typeof(witness.get("physics_step_id")) != TYPE_INT \
			or int(witness.get("physics_step_id", -1)) \
				!= int(current_sample.get("physics_step_id", -2)) \
			or typeof(witness.get("capture_epoch")) != TYPE_INT \
			or int(witness.get("capture_epoch", -1)) \
				!= int(current_sample.get("capture_epoch", -2)) \
			or String(witness.get("sample_phase", "")) \
				!= String(current_sample.get("sample_phase", "")):
		reasons.append("UNWRAP_INITIALIZATION_FRAME_IDENTITY_MISMATCH")
	if String(witness.get("run_id", "")) \
			!= String(current_sample.get("run_id", "")) \
			or String(witness.get("capture_stream_id", "")) \
				!= String(current_sample.get("capture_stream_id", "")):
		reasons.append("UNWRAP_INITIALIZATION_CAPTURE_IDENTITY_MISMATCH")
	if typeof(witness.get("authored_turn_index")) != TYPE_INT \
			or int(witness.get("authored_turn_index", 0)) \
				!= int(binding.get("initial_turn_index", 0)):
		reasons.append("UNWRAP_INITIALIZATION_TURN_INDEX_MISMATCH")
	if not _is_sha256_digest(String(witness.get(
			"fixture_configuration_digest_sha256", ""))):
		reasons.append("UNWRAP_INITIALIZATION_FIXTURE_DIGEST_INVALID")
	var expected_value: Variant = witness.get("expected_wrapped_angle_rad")
	var maximum_value: Variant = witness.get("maximum_pose_residual_rad")
	if not (expected_value is float or expected_value is int) \
			or not is_finite(float(expected_value)) \
			or not (maximum_value is float or maximum_value is int) \
			or not is_finite(float(maximum_value)) \
			or float(maximum_value) <= 0.0 \
			or float(maximum_value) > MAX_INITIALIZATION_POSE_RESIDUAL_RAD:
		reasons.append("UNWRAP_INITIALIZATION_POSE_ENVELOPE_INVALID")
	else:
		var pose_residual := absf(wrapf(
			wrapped_angle_rad - float(expected_value) + PI,
			0.0,
			TAU) - PI)
		if pose_residual > float(maximum_value):
			reasons.append("UNWRAP_INITIALIZATION_POSE_MISMATCH")
	if String(witness.get("initialization_reason", "")) \
			not in VALID_INITIALIZATION_REASONS:
		reasons.append("UNWRAP_INITIALIZATION_REASON_INVALID")
	var digest: Variant = null
	if reasons.is_empty():
		digest = CanonicalJsonScript.sha256(witness)
	return {
		"reasons": reasons,
		"witness_digest_sha256": digest,
	}


static func _predecessor_invalid_reasons(
		binding: Dictionary,
		current_sample: Dictionary,
		previous_state: Dictionary,
		unwrap_segment_id: int) -> Array[String]:
	var reasons: Array[String] = []
	if String(previous_state.get("schema_version", "")) != SCHEMA_VERSION:
		reasons.append("PREVIOUS_STATE_SCHEMA_MISMATCH")
	if not bool(previous_state.get("finite", false)) \
			or not bool(previous_state.get(
				"unwrapped_angle_available", false)):
		reasons.append("PREVIOUS_STATE_INVALID")
	if not bool(previous_state.get("unwrapped_angle_available", false)):
		reasons.append("PREVIOUS_STATE_UNWRAPPED_UNAVAILABLE")
	if String(previous_state.get("binding_digest_sha256", "")) \
			!= String(binding.get("binding_digest_sha256", "")):
		reasons.append("PREVIOUS_STATE_BINDING_MISMATCH")
	if String(previous_state.get("joint_id", "")) \
			!= String(binding.get("joint_id", "")):
		reasons.append("PREVIOUS_STATE_JOINT_MISMATCH")
	if String(previous_state.get("parent_body_id", "")) \
			!= String(binding.get("parent_body_id", "")) \
			or String(previous_state.get("child_body_id", "")) \
				!= String(binding.get("child_body_id", "")):
		reasons.append("PREVIOUS_STATE_BODY_ID_MISMATCH")
	if int(previous_state.get("physics_step_id", -2)) + 1 \
			!= int(current_sample.get("physics_step_id", -1)):
		reasons.append("PREVIOUS_STATE_STEP_DISCONTINUITY")
	if int(previous_state.get("capture_epoch", -2)) + 1 \
			!= int(current_sample.get("capture_epoch", -1)):
		reasons.append("PREVIOUS_STATE_EPOCH_DISCONTINUITY")
	if String(previous_state.get("sample_phase", "")) \
			!= String(current_sample.get("sample_phase", "")):
		reasons.append("PREVIOUS_STATE_PHASE_MISMATCH")
	if int(previous_state.get("unwrap_segment_id", -1)) \
			!= unwrap_segment_id:
		reasons.append("PREVIOUS_STATE_SEGMENT_MISMATCH")
	var previous_provenance_value: Variant = previous_state.get(
		"input_provenance")
	if not previous_provenance_value is Dictionary:
		reasons.append("PREVIOUS_STATE_PROVENANCE_MISSING")
	else:
		var previous_provenance: Dictionary = previous_provenance_value
		var current_provenance := _provenance(current_sample)
		for field in [
			"run_id",
			"capture_stream_id",
			"observer_profile_id",
			"observer_adapter_id",
			"body_sample_schema_version",
		]:
			if _stable_identity_text(previous_provenance.get(field)) \
					!= _stable_identity_text(
						current_provenance.get(field)):
				reasons.append(
					"PREVIOUS_STATE_%s_MISMATCH" % field.to_upper())
	var previous_wrapped: Variant = previous_state.get("wrapped_angle_rad")
	var previous_unwrapped: Variant = previous_state.get(
		"unwrapped_angle_rad")
	var previous_rate: Variant = previous_state.get("axis_rate_rad_s")
	var previous_step: Variant = previous_state.get("step_s")
	if not _finite_number(previous_wrapped) \
			or not _finite_number(previous_unwrapped) \
			or not _finite_number(previous_rate) \
			or not _valid_positive_step(previous_step):
		reasons.append("PREVIOUS_STATE_NONFINITE")
	var witness_digest_value: Variant = previous_state.get(
		"initialization_witness_digest_sha256")
	var origin_step_value: Variant = previous_state.get(
		"segment_origin_step_id")
	var origin_epoch_value: Variant = previous_state.get(
		"segment_origin_capture_epoch")
	if not _is_sha256_digest(_stable_identity_text(witness_digest_value)) \
			or typeof(origin_step_value) != TYPE_INT \
			or int(origin_step_value) < 0 \
			or typeof(origin_epoch_value) != TYPE_INT \
			or int(origin_epoch_value) < 0:
		reasons.append("PREVIOUS_STATE_INITIALIZATION_PROVENANCE_INVALID")
	return reasons


static func _availability(
		binding_available: bool,
		identity_reasons: Array[String],
		geometry_available: bool,
		geometry_reasons: Array[String],
		angle_available: bool,
		angle_reasons: Array[String],
		rate_available: bool,
		rate_reasons: Array[String],
		unwrap_available: bool,
		unwrap_reasons: Array[String]) -> Dictionary:
	var result := {}
	result["/binding_digest_sha256"] = _availability_entry(
		binding_available,
		"derived",
		[] if binding_available else ["BINDING_INVALID"])
	var identity_available := identity_reasons.is_empty()
	for path in [
		"/physics_step_id",
		"/capture_epoch",
		"/sample_phase",
		"/step_s",
		"/input_provenance",
	]:
		result[path] = _availability_entry(
			identity_available, "measured", identity_reasons)
	for path in [
		"/current_axis_world",
		"/current_axis_world_from_child",
		"/axis_agreement_error_rad",
		"/anchor_parent_world_m",
		"/anchor_child_world_m",
		"/anchor_agreement_error_m",
	]:
		result[path] = _availability_entry(
			geometry_available, "derived", geometry_reasons)
	for path in ["/wrapped_angle_rad", "/swing_residual_rad"]:
		result[path] = _availability_entry(
			angle_available, "derived", angle_reasons)
	for path in ["/axis_rate_rad_s", "/off_axis_rate_rad_s"]:
		result[path] = _availability_entry(
			rate_available, "derived", rate_reasons)
	for path in [
		"/unwrapped_angle_rad",
		"/rate_witness_delta_rad",
		"/rate_witness_residual_rad",
		"/endpoint_branch_turn_count",
		"/initialization_witness_digest_sha256",
	]:
		result[path] = _availability_entry(
			unwrap_available, "derived", unwrap_reasons)
	return result


static func _availability_entry(
		available: bool,
		available_status: String,
		reasons: Array) -> Dictionary:
	return {
		"status": available_status if available else "unavailable",
		"reason": null if available else _reason_text(reasons),
		"source": SCHEMA_VERSION,
	}


static func _reason_text(reasons: Array) -> String:
	if reasons.is_empty():
		return "UNAVAILABLE"
	var values: Array[String] = []
	for reason in reasons:
		_append_unique(values, String(reason))
	return "; ".join(values)


static func _provenance(sample: Dictionary) -> Dictionary:
	return {
		"run_id": String(sample.get("run_id", "")),
		"capture_stream_id": String(sample.get("capture_stream_id", "")),
		"observer_profile_id": String(
			sample.get("observer_profile_id", "")),
		"observer_adapter_id": String(
			sample.get("observer_adapter_id", "")),
		"body_sample_schema_version": String(
			sample.get("schema_version", "")),
	}


static func _sample_step_s(sample: Dictionary) -> float:
	return float(sample.get("step_s", NAN))


static func _valid_positive_step(value: Variant) -> bool:
	return (value is float or value is int) \
		and is_finite(float(value)) and float(value) > 0.0


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _safe_nonnegative_int(value: Variant) -> Variant:
	return int(value) if typeof(value) == TYPE_INT and int(value) >= 0 \
		else null


static func _safe_stable_string(value: Variant) -> Variant:
	return String(value) if (value is String or value is StringName) \
		and not String(value).is_empty() else null


static func _stable_identity_text(value: Variant) -> String:
	return String(value) if value is String or value is StringName else ""


static func _is_sha256_digest(value: String) -> bool:
	if value.length() != 71 or not value.begins_with("sha256:"):
		return false
	for index in range(7, value.length()):
		if value.substr(index, 1) not in "0123456789abcdef":
			return false
	return true


static func _append_unique(values: Array[String], value: String) -> void:
	if not values.has(value):
		values.append(value)


static func _transform_from_value(value: Variant) -> Transform3D:
	if value is Transform3D:
		return value
	if value is Dictionary:
		var dictionary: Dictionary = value
		var basis_rows: Variant = dictionary.get("basis")
		var origin := _vector3(dictionary.get("origin"))
		if basis_rows is Array and (basis_rows as Array).size() == 3:
			var rows: Array = basis_rows
			return Transform3D(
				Basis(
					_vector3(rows[0]),
					_vector3(rows[1]),
					_vector3(rows[2])),
				origin)
	return Transform3D(
		Basis(
			Vector3(INF, INF, INF),
			Vector3(INF, INF, INF),
			Vector3(INF, INF, INF)),
		Vector3(INF, INF, INF))


static func _quaternion(value: Variant) -> Quaternion:
	if value is Quaternion:
		return value
	if value is Array and (value as Array).size() == 4:
		var raw: Array = value
		return Quaternion(
			float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
	return Quaternion(INF, INF, INF, INF)


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _transform_is_finite(value: Transform3D) -> bool:
	return value.basis.x.is_finite() \
		and value.basis.y.is_finite() \
		and value.basis.z.is_finite() \
		and value.origin.is_finite()


static func _basis_is_rigid(value: Basis) -> bool:
	if not value.x.is_finite() \
			or not value.y.is_finite() \
			or not value.z.is_finite():
		return false
	return absf(value.x.length() - 1.0) <= RIGID_BASIS_TOLERANCE \
		and absf(value.y.length() - 1.0) <= RIGID_BASIS_TOLERANCE \
		and absf(value.z.length() - 1.0) <= RIGID_BASIS_TOLERANCE \
		and absf(value.x.dot(value.y)) <= RIGID_BASIS_TOLERANCE \
		and absf(value.x.dot(value.z)) <= RIGID_BASIS_TOLERANCE \
		and absf(value.y.dot(value.z)) <= RIGID_BASIS_TOLERANCE \
		and absf(value.determinant() - 1.0) <= RIGID_BASIS_TOLERANCE
