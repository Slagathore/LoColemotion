extends SceneTree

## BR2 pinned test: locks the hinge-angle sign convention and the frame
## rules of LabJointState.
##
## The convention under test (documented in joint_state.gd, rule 3):
## positive angle is a right-hand rotation of the CHILD about the current
## world axis, measured from the authored rest pose, with the decomposition
## performed in the PARENT's local frame. The gait era died on exactly this
## seam (the 0.414x hinge_angle frame bug), so this test also proves the
## negative space: a wrong-frame authored axis or a separated anchor must
## INVALIDATE the sample, not scale it.

const JointBindingScript := preload(
	"res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload(
	"res://scripts/lab/mechanics/joint_state.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR2 hinge angle sign convention ===")
	var binding := _hinge_binding(Vector3.BACK, Vector3.BACK)

	# Case 1: +0.3 rad about +Z with identity parent reads exactly +0.3.
	var plus := _sample(binding, Transform3D.IDENTITY,
		_child_rotated(Transform3D.IDENTITY, Vector3.BACK, 0.3))
	_check(bool(plus["finite"]), "plus rotation sample is valid")
	_check(absf(float(plus["wrapped_angle_rad"]) - 0.3) < 1.0e-6,
		"right-hand rotation about +Z reads +0.3 rad")

	# Case 2: the mirrored rotation reads exactly -0.3.
	var minus := _sample(binding, Transform3D.IDENTITY,
		_child_rotated(Transform3D.IDENTITY, Vector3.BACK, -0.3))
	_check(absf(float(minus["wrapped_angle_rad"]) + 0.3) < 1.0e-6,
		"left-hand rotation about +Z reads -0.3 rad")

	# Case 3: right-hand geometric witness. A +PI/2 rotation about +Z must
	# carry the child's +X basis vector onto +Y; if the reported angle is
	# positive the convention matches the right-hand rule, not just a sign
	# that happens to flip consistently.
	var quarter_transform := _child_rotated(
		Transform3D.IDENTITY, Vector3.BACK, PI / 2.0)
	var quarter := _sample(binding, Transform3D.IDENTITY, quarter_transform)
	var rotated_x: Vector3 = quarter_transform.basis.x
	_check(float(quarter["wrapped_angle_rad"]) > 0.0
		and rotated_x.distance_to(Vector3.UP) < 1.0e-6,
		"positive angle carries child +X onto +Y (right-hand about +Z)")

	# Case 4: rotating the PARENT must not change the measured joint angle.
	# The angle lives in the parent-local frame; only the world axis moves.
	var tilted_parent := Transform3D(
		Basis(Quaternion(Vector3(1, 2, 3).normalized(), 1.1)),
		Vector3(4.0, -2.0, 7.0))
	var tilted_child := _child_rotated(tilted_parent, Vector3.BACK, 0.3)
	var tilted := _sample(binding, tilted_parent, tilted_child)
	_check(bool(tilted["finite"])
		and absf(float(tilted["wrapped_angle_rad"]) - 0.3) < 1.0e-6,
		"arbitrary parent pose leaves the joint angle at +0.3")

	# Case 5: a non-identity rest pose defines the zero. With rest at
	# +0.5 rad, a child at +0.7 rad total reads +0.2 from rest.
	var rest_binding := _hinge_binding(
		Vector3.BACK, Vector3.BACK, Quaternion(Vector3.BACK, 0.5))
	var from_rest := _sample(rest_binding, Transform3D.IDENTITY,
		_child_rotated(Transform3D.IDENTITY, Vector3.BACK, 0.7))
	_check(absf(float(from_rest["wrapped_angle_rad"]) - 0.2) < 1.0e-6,
		"angle is measured from the authored rest pose")

	# Case 6: a pure hinge motion leaves no swing residual and both frame
	# recomputations of the axis agree exactly.
	_check(absf(float(plus["swing_residual_rad"])) < 1.0e-6
		and float(plus["axis_agreement_error_rad"]) < 1.0e-9,
		"pure hinge motion has zero swing and exact axis agreement")

	# Case 7 (negative): a live pose that violates a valid binding's two-sided
	# axis oracle must invalidate. Static rest-axis mistakes are rejected even
	# earlier by the builder below.
	var wrong_axis := _sample(binding, Transform3D.IDENTITY,
		_child_rotated(Transform3D.IDENTITY, Vector3.RIGHT, 0.3))
	_check(not bool(wrong_axis["finite"])
		and (wrong_axis["invalid_reasons"] as Array).has(
			"AXIS_FRAME_DISAGREEMENT"),
		"live child-axis disagreement invalidates instead of scaling the angle")

	# Case 8 (negative): separated anchors invalidate the sample rather than
	# letting the angle drift on a broken joint.
	var separated_child := _child_rotated(
		Transform3D.IDENTITY, Vector3.BACK, 0.3)
	separated_child.origin += Vector3(0.01, 0.0, 0.0)
	var separated := _sample(binding, Transform3D.IDENTITY, separated_child)
	_check(not bool(separated["finite"])
		and (separated["invalid_reasons"] as Array).has("ANCHOR_MISMATCH"),
		"separated hinge anchors invalidate the sample")

	# Case 9 (BR2.1 regression): a general rest orientation makes the same
	# physical hinge axis have DIFFERENT parent-local and child-local vectors.
	# The relative pose is
	#     R_relative(theta) = R_axis_parent(theta) * R_rest.
	# Therefore the delta expressed in the parent frame is
	#     R_relative * inverse(R_rest) = R_axis_parent(theta).
	# The old implementation used inverse(R_rest) * R_relative (a child-rest
	# delta) and then projected it onto the parent axis. Identity-rest and
	# same-axis tests commute and cannot reveal that frame mix.
	var axis_parent := Vector3.BACK
	var axis_child := Vector3.RIGHT
	var skew_rest := Quaternion(Vector3.UP, -PI / 2.0)
	_check((Basis(skew_rest) * axis_child).distance_to(axis_parent) < 1.0e-6,
		"fixture rest rotation maps child +X onto parent +Z")
	var skew_binding := _hinge_binding(
		axis_parent, axis_child, skew_rest)
	var known_angle := 0.37
	var skew_child_rotation := Quaternion(axis_parent, known_angle) * skew_rest
	var skew := _sample(
		skew_binding,
		Transform3D.IDENTITY,
		Transform3D(Basis(skew_child_rotation), Vector3.ZERO))
	_check(bool(skew["finite"]),
		"noncommuting-rest hinge sample is valid")
	_check(absf(float(skew["wrapped_angle_rad"]) - known_angle) < 1.0e-6,
		"noncommuting-rest hinge reports the known parent-frame angle")
	var transverse_child := Vector3.UP
	var rest_reference_parent := Basis(skew_rest) * transverse_child
	var live_reference_parent := Basis(skew_child_rotation) * transverse_child
	var geometric_angle := _signed_angle_about_axis(
		axis_parent, rest_reference_parent, live_reference_parent)
	_check(absf(float(skew["wrapped_angle_rad"]) - geometric_angle) < 1.0e-6,
		"quaternion observer agrees with independent transverse-vector geometry")
	_check(float(skew["axis_agreement_error_rad"]) < 1.0e-6
		and float(skew["swing_residual_rad"]) < 1.0e-6,
		"different local axes still describe one coherent physical hinge"
		+ " (axis error=%.9f rad, swing=%.9f rad)" % [
			float(skew["axis_agreement_error_rad"]),
			float(skew["swing_residual_rad"])])
	var negative_angle := -0.29
	var negative_relative := Quaternion(
		axis_parent, negative_angle) * skew_rest
	var negative_skew := _sample(
		skew_binding,
		Transform3D.IDENTITY,
		Transform3D(Basis(negative_relative), Vector3.ZERO))
	_check(bool(negative_skew["finite"])
		and absf(float(negative_skew["wrapped_angle_rad"])
			- negative_angle) < 1.0e-6,
		"noncommuting frame preserves the negative hinge-angle sign")
	var arbitrary_parent_rotation := Quaternion(
		Vector3(2.0, -1.0, 3.0).normalized(), 0.83)
	var arbitrary_parent := Transform3D(
		Basis(arbitrary_parent_rotation), Vector3(3.0, -4.0, 2.0))
	var arbitrary_child_rotation := arbitrary_parent_rotation \
		* skew_child_rotation
	var arbitrary_child := Transform3D(
		Basis(arbitrary_child_rotation), arbitrary_parent.origin)
	var posed_skew := _sample(
		skew_binding, arbitrary_parent, arbitrary_child)
	_check(bool(posed_skew["finite"])
		and absf(float(posed_skew["wrapped_angle_rad"])
			- known_angle) < 1.0e-6,
		"noncommuting hinge angle is invariant under arbitrary parent pose")

	# Cases 10-11: a sample must not inherit the binding's labels when the
	# supplied body identities or capture epoch disagree. These are observer
	# validity failures, not caller conveniences.
	var wrong_ids := JointStateScript.sample(
		binding,
		_body_sample(Transform3D.IDENTITY, "child_body", 7, 1),
		_body_sample(
			_child_rotated(Transform3D.IDENTITY, Vector3.BACK, 0.3),
			"parent_body", 7, 1))
	_check(not bool(wrong_ids["finite"])
		and (wrong_ids["invalid_reasons"] as Array).has(
			"BODY_SAMPLE_IDENTITY_MISMATCH"),
		"swapped body samples invalidate instead of inheriting binding ids")
	var mixed_epoch := JointStateScript.sample(
		binding,
		_body_sample(Transform3D.IDENTITY, "parent_body", 7, 1),
		_body_sample(
			_child_rotated(Transform3D.IDENTITY, Vector3.BACK, 0.3),
			"child_body", 7, 2))
	_check(not bool(mixed_epoch["finite"])
		and (mixed_epoch["invalid_reasons"] as Array).has(
			"BODY_SAMPLES_SPAN_EPOCHS"),
		"mixed capture epochs invalidate the joint sample")
	var parent_phase_sample := _body_sample(
		Transform3D.IDENTITY, "parent_body", 7, 1)
	var child_phase_sample := _body_sample(
		_child_rotated(Transform3D.IDENTITY, Vector3.BACK, 0.3),
		"child_body", 7, 1)
	child_phase_sample["sample_phase"] = "post_step"
	var mixed_phase := JointStateScript.sample(
		binding, parent_phase_sample, child_phase_sample)
	_check(not bool(mixed_phase["finite"])
		and (mixed_phase["invalid_reasons"] as Array).has(
			"BODY_SAMPLES_SPAN_PHASES"),
		"mixed sample phases invalidate the joint sample")

	# Cases 12-15: the binding and sampled bases are part of the measurement
	# contract. A consumer must not be allowed to disable a gate with an
	# absurd tolerance, author a rest pose whose directed axes disagree, or
	# feed scale/shear into quaternion extraction.
	var rest_axis_mismatch: Dictionary = JointBindingScript.build(
		_binding_configuration(
			Vector3.RIGHT,
			Vector3.RIGHT,
			Quaternion(Vector3.BACK, -PI / 2.0)))
	_check(not bool(rest_axis_mismatch["ok"])
		and _has_build_error(rest_axis_mismatch, "REST_AXIS_MISMATCH"),
		"binding rejects rest rotations that do not map child axis to parent")
	var loose_axis_config := _binding_configuration(
		Vector3.BACK, Vector3.BACK, Quaternion.IDENTITY)
	loose_axis_config["axis_agreement_tolerance_rad"] = 0.5
	var loose_axis: Dictionary = JointBindingScript.build(loose_axis_config)
	_check(not bool(loose_axis["ok"])
		and _has_build_error(loose_axis, "AXIS_TOLERANCE_TOO_LARGE"),
		"binding rejects an axis tolerance large enough to hide frame errors")
	var loose_anchor_config := _binding_configuration(
		Vector3.BACK, Vector3.BACK, Quaternion.IDENTITY)
	loose_anchor_config["anchor_agreement_tolerance_m"] = 0.5
	var loose_anchor: Dictionary = JointBindingScript.build(loose_anchor_config)
	_check(not bool(loose_anchor["ok"])
		and _has_build_error(loose_anchor, "ANCHOR_TOLERANCE_TOO_LARGE"),
		"binding rejects an anchor tolerance large enough to disable the gate")
	var scaled_basis := Basis.IDENTITY.scaled(Vector3(2.0, 1.0, 1.0))
	var nonrigid := _sample(
		binding,
		Transform3D(scaled_basis, Vector3.ZERO),
		Transform3D.IDENTITY)
	_check(not bool(nonrigid["finite"])
		and (nonrigid["invalid_reasons"] as Array).has(
			"PARENT_BASIS_NOT_RIGID"),
		"scaled parent basis invalidates before quaternion extraction")

	# Cases 16-18: rate projection is an independent world-space oracle, the
	# binding digest identifies the exact coordinate definition, and invalid
	# geometry never leaks nonfinite JSON payloads.
	var rate_parent := arbitrary_parent
	var rate_child := arbitrary_child
	var hinge_axis_world := (
		rate_parent.basis * axis_parent).normalized()
	var transverse_world := hinge_axis_world.cross(Vector3.UP).normalized()
	if transverse_world.length_squared() < 0.5:
		transverse_world = hinge_axis_world.cross(Vector3.RIGHT).normalized()
	var parent_rate := Vector3(0.2, -0.1, 0.4)
	var child_rate := parent_rate + 1.25 * hinge_axis_world \
		+ 0.4 * transverse_world
	var rate_state := _sample_with_rates(
		skew_binding,
		rate_parent,
		rate_child,
		parent_rate,
		child_rate)
	_check(bool(rate_state["finite"])
		and absf(float(rate_state["axis_rate_rad_s"]) - 1.25) < 1.0e-5
		and absf(float(rate_state["off_axis_rate_rad_s"]) - 0.4) < 1.0e-5,
		"arbitrary-pose rate projection preserves known on/off-axis components")
	var opposite_rest := Quaternion(
		-skew_rest.x, -skew_rest.y, -skew_rest.z, -skew_rest.w)
	var opposite_binding := _hinge_binding(
		axis_parent, axis_child, opposite_rest)
	_check(String(opposite_binding["binding_digest_sha256"])
		== String(skew_binding["binding_digest_sha256"]),
		"q and -q rest rotations canonicalize to one binding digest")
	var forged_binding := binding.duplicate(true)
	forged_binding["anchor_parent_local"] = [0.001, 0.0, 0.0]
	var forged := _sample(
		forged_binding, Transform3D.IDENTITY, Transform3D.IDENTITY)
	_check(not bool(forged["finite"])
		and (forged["invalid_reasons"] as Array).has(
			"BINDING_DIGEST_MISMATCH"),
		"semantic binding mutation is rejected by the canonical digest")
	var poisoned_transform := Transform3D(
		Basis(Vector3(INF, 0, 0), Vector3.UP, Vector3.BACK),
		Vector3.ZERO)
	var poisoned := _sample(
		binding, poisoned_transform, Transform3D.IDENTITY)
	_check(not bool(poisoned["finite"])
		and poisoned["current_axis_world"] == null
		and not _contains_nonfinite(poisoned),
		"invalid geometry emits null channels and no nonfinite payload")
	_finish()


func _hinge_binding(
		axis_parent: Vector3,
		axis_child: Vector3,
		rest := Quaternion.IDENTITY) -> Dictionary:
	var built: Dictionary = JointBindingScript.build(
		_binding_configuration(axis_parent, axis_child, rest))
	assert(bool(built["ok"]), "test binding must build")
	return built["binding"]


func _binding_configuration(
		axis_parent: Vector3,
		axis_child: Vector3,
		rest: Quaternion) -> Dictionary:
	return {
		"joint_id": "hinge_under_test",
		"parent_body_id": "parent_body",
		"child_body_id": "child_body",
		"axis_parent_local": axis_parent,
		"axis_child_local": axis_child,
		"anchor_parent_local": Vector3.ZERO,
		"anchor_child_local": Vector3.ZERO,
		"rest_child_rotation_parent_local": rest,
		"requires_unwrapped_angle": false,
		"local_joint_scale_m": 1.0,
		"local_joint_scale_basis": "joint_fixture_extent_min_v1",
		"morphology_config_digest_sha256":
			"sha256:%s" % "br2-angle-test-morphology-v1".sha256_text(),
	}


func _has_build_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


func _signed_angle_about_axis(
		axis: Vector3,
		from_vector: Vector3,
		to_vector: Vector3) -> float:
	var unit_axis := axis.normalized()
	var from_projected := (
		from_vector - unit_axis * from_vector.dot(unit_axis)).normalized()
	var to_projected := (
		to_vector - unit_axis * to_vector.dot(unit_axis)).normalized()
	return atan2(
		unit_axis.dot(from_projected.cross(to_projected)),
		from_projected.dot(to_projected))


## Builds the child transform for a hinge angle: child shares the parent's
## anchor (both local anchors are the origin here) and is rotated by
## `angle` about the parent-local `axis`, on top of the parent pose.
func _child_rotated(
		parent: Transform3D,
		axis: Vector3,
		angle: float) -> Transform3D:
	var rotation := parent.basis.get_rotation_quaternion() \
		* Quaternion(axis, angle)
	return Transform3D(Basis(rotation), parent.origin)


func _sample(
		binding: Dictionary,
		parent: Transform3D,
		child: Transform3D) -> Dictionary:
	return _sample_with_rates(
		binding, parent, child, Vector3.ZERO, Vector3.ZERO)


func _sample_with_rates(
		binding: Dictionary,
		parent: Transform3D,
		child: Transform3D,
		parent_rate: Vector3,
		child_rate: Vector3) -> Dictionary:
	return JointStateScript.sample(
		binding,
		_body_sample(parent, "parent_body", 7, 1, parent_rate),
		_body_sample(child, "child_body", 7, 1, child_rate))


func _body_sample(
		transform: Transform3D,
		body_id: String,
		physics_step_id: int,
		capture_epoch: int,
		angular_velocity: Vector3 = Vector3.ZERO) -> Dictionary:
	return {
		"schema_version": "mechanics_body_sample_v1",
		"physics_step_id": physics_step_id,
		"capture_epoch": capture_epoch,
		"sample_phase": "integrate_callback",
		"body_id": body_id,
		"transform": transform,
		"angular_velocity": angular_velocity,
		"step_s": 1.0 / 60.0,
		"run_id": "br2-angle-sign-run",
		"capture_stream_id": "br2-angle-sign-stream",
		"observer_profile_id": "br2_joint_state_v2",
		"observer_adapter_id": "analytic_joint_fixture_v1",
		"finite": true,
	}


func _contains_nonfinite(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return not is_finite(float(value))
		TYPE_ARRAY:
			for item in value as Array:
				if _contains_nonfinite(item):
					return true
		TYPE_DICTIONARY:
			for item in (value as Dictionary).values():
				if _contains_nonfinite(item):
					return true
	return false


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
