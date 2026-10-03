extends SceneTree

## BR2 pinned test: the unwrapped hinge-angle stream must stay continuous
## across the +/-PI seam and must FAIL CLOSED when one tick moves far enough
## that the shortest-path unwrap becomes ambiguous.
##
## The wrapped angle from a quaternion always lands in (-PI, PI]. A joint
## that keeps turning therefore jumps from near +PI to near -PI in the raw
## stream; the unwrapped stream integrates shortest-path deltas so a
## controller or metric consumer sees one continuous coordinate. The BR2
## gate wording is explicit that wrapped-angle ambiguity must invalidate the
## sample rather than drift: if a hinge really did rotate more than the
## binding's max_tick_rotation_rad in one tick, the independent engine-rate
## witness exposes that branch and the observer rejects it. Without a coherent
## rate/step witness, only the wrapped endpoint remains available.

const JointBindingScript := preload(
	"res://scripts/lab/mechanics/joint_binding.gd")
const JointStateScript := preload(
	"res://scripts/lab/mechanics/joint_state.gd")
const JointAngleStreamScript := preload(
	"res://scripts/lab/mechanics/joint_angle_stream.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR2 unwrapped angle stream continuity ===")
	var binding := _binding()

	# Case 1: a +0.3 rad/tick stream through the +PI seam stays continuous.
	# 14 ticks reach +4.2 rad total while the wrapped channel has already
	# jumped to the negative side; every unwrapped step must be +0.3.
	var previous: Dictionary = {}
	var continuous := true
	var final_unwrapped := 0.0
	for tick in range(1, 15):
		var total_angle := 0.3 * tick
		var state := _sample_at(
			binding, total_angle, tick, previous, 1, previous.is_empty(),
			-1, 0.3)
		if not bool(state["finite"]):
			continuous = false
			break
		var expected := 0.3 * tick
		if absf(float(state["unwrapped_angle_rad"]) - expected) > 1.0e-5:
			continuous = false
			break
		final_unwrapped = float(state["unwrapped_angle_rad"])
		previous = state
	_check(continuous and final_unwrapped > PI,
		"forward stream unwraps continuously through +PI (reached %.2f rad)"
			% final_unwrapped)
	_check(absf(float(previous["wrapped_angle_rad"])) <= PI + 1.0e-6,
		"wrapped channel stays inside its principal (-PI, PI] range")

	# Case 2: the mirrored stream through -PI is also continuous.
	previous = {}
	var backward_ok := true
	for tick in range(1, 15):
		var state := _sample_at(
			binding, -0.3 * tick, tick, previous, 2, previous.is_empty(),
			-1, -0.3)
		if not bool(state["finite"]) \
				or absf(float(state["unwrapped_angle_rad"]) + 0.3 * tick) \
					> 1.0e-5:
			backward_ok = false
			break
		previous = state
	_check(backward_ok,
		"backward stream unwraps continuously through -PI")

	# Case 3: a long stream accumulates multiple revolutions without drift.
	# 100 ticks at +0.2 rad/tick is 20 rad (over three revolutions); the
	# unwrapped coordinate must land within float tolerance of exactly 20.
	previous = {}
	for tick in range(1, 101):
		previous = _sample_at(
			binding, 0.2 * tick, tick, previous, 3, previous.is_empty(),
			-1, 0.2)
	_check(bool(previous["finite"])
		and absf(float(previous["unwrapped_angle_rad"]) - 20.0) < 1.0e-4,
		"100-tick stream accumulates 20.0 rad without drift")

	# Case 4 (negative): a per-tick jump beyond max_tick_rotation_rad (the
	# default ceiling is PI/2) is ambiguous and must invalidate the sample.
	previous = _sample_at(binding, 0.1, 1, {}, 4, true, -1, 2.0)
	var jump := _sample_at(
		binding, 0.1 + 2.0, 2, previous, 4, false, -1, 2.0)
	_check(bool(jump["finite"])
		and not bool(jump["complete"])
		and jump["unwrapped_angle_rad"] == null
		and (jump["invalid_reasons"] as Array).has("WRAPPED_ANGLE_AMBIGUOUS"),
		"a 2.0 rad jump removes only the ambiguous unwrapped channel")

	# Case 5: an invalid predecessor cannot silently restart a stream. The
	# caller must declare a new segment and explicitly authorize its initial
	# turn. Otherwise a dropped/invalid tick could erase whole revolutions.
	var poisoned_follow := _sample_at(binding, 0.4, 3, jump, 4)
	_check(bool(poisoned_follow["finite"])
		and not bool(poisoned_follow["unwrapped_angle_available"])
		and (poisoned_follow["invalid_reasons"] as Array).has(
			"PREVIOUS_STATE_INVALID")
		and (poisoned_follow["invalid_reasons"] as Array).has(
			"UNWRAPPED_ANGLE_STREAM_DISCONTINUITY"),
		"invalid predecessor fails closed instead of silently restarting")
	var restarted := _sample_at(binding, 0.4, 3, {}, 5, true)
	_check(bool(restarted["finite"])
		and int(restarted["unwrap_segment_id"]) == 5
		and absf(float(restarted["unwrapped_angle_rad"]) - 0.4) < 1.0e-6,
		"explicit new segment restarts with a witnessed initialization")

	# Case 6: even the very first sample fails closed unless initialization
	# is an explicit caller decision.
	var implicit_start := _sample_at(binding, 0.2, 1, {}, 6, false)
	_check(bool(implicit_start["finite"])
		and not bool(implicit_start["unwrapped_angle_available"])
		and (implicit_start["invalid_reasons"] as Array).has(
			"UNWRAP_INITIALIZATION_WITNESS_MISSING_OR_UNSUPPORTED"),
		"unwrapped stream cannot initialize without a versioned witness")
	var two_turn_binding := _binding(2)
	var two_turn_start := _sample_at(
		two_turn_binding, 0.2, 1, {}, 9, true)
	_check(bool(two_turn_start["finite"])
		and absf(float(two_turn_start["unwrapped_angle_rad"])
			- (0.2 + 2.0 * TAU)) < 1.0e-5,
		"explicit initialization honors the authored initial turn index")

	# Cases 7-10: predecessorhood includes identity and time, not merely a
	# dictionary with two angle fields. Gaps and cross-joint/segment state
	# must be diagnosed before any shortest-path integration occurs.
	var seed := _sample_at(binding, 0.1, 1, {}, 7, true, -1, 0.1)
	var wrong_joint := seed.duplicate(true)
	wrong_joint["joint_id"] = "other_hinge"
	var crossed_joint := _sample_at(
		binding, 0.2, 2, wrong_joint, 7, false, -1, 0.1)
	_check(bool(crossed_joint["finite"])
		and not bool(crossed_joint["unwrapped_angle_available"])
		and (crossed_joint["invalid_reasons"] as Array).has(
			"PREVIOUS_STATE_JOINT_MISMATCH"),
		"previous state from another joint is rejected")
	var step_gap := _sample_at(
		binding, 0.3, 3, seed, 7, false, -1, 0.1)
	_check(bool(step_gap["finite"])
		and not bool(step_gap["unwrapped_angle_available"])
		and (step_gap["invalid_reasons"] as Array).has(
			"PREVIOUS_STATE_STEP_DISCONTINUITY"),
		"missing physics step breaks unwrap continuity")
	var epoch_gap := _sample_at(
		binding, 0.2, 2, seed, 7, false, 3, 0.1)
	_check(bool(epoch_gap["finite"])
		and not bool(epoch_gap["unwrapped_angle_available"])
		and (epoch_gap["invalid_reasons"] as Array).has(
			"PREVIOUS_STATE_EPOCH_DISCONTINUITY"),
		"capture-epoch gap breaks unwrap continuity")
	var segment_cross := _sample_at(
		binding, 0.2, 2, seed, 8, false, -1, 0.1)
	_check(bool(segment_cross["finite"])
		and not bool(segment_cross["unwrapped_angle_available"])
		and (segment_cross["invalid_reasons"] as Array).has(
			"PREVIOUS_STATE_SEGMENT_MISMATCH"),
		"previous state cannot cross an unwrap segment boundary")

	# Case 11: non-finite accumulator data never reaches arithmetic.
	var poisoned_value := seed.duplicate(true)
	poisoned_value["unwrapped_angle_rad"] = INF
	var nonfinite_predecessor := _sample_at(
		binding, 0.2, 2, poisoned_value, 7, false, -1, 0.1)
	_check(bool(nonfinite_predecessor["finite"])
		and not bool(nonfinite_predecessor["unwrapped_angle_available"])
		and (nonfinite_predecessor["invalid_reasons"] as Array).has(
			"PREVIOUS_STATE_NONFINITE"),
		"non-finite predecessor angle is rejected before integration")

	# Case 12 (BR2.1 anti-alias oracle): endpoint quaternions alone cannot
	# distinguish +0.1 rad from +(TAU + 0.1) rad. The engine angular-rate
	# channel and step duration are the independent witness that selects the
	# correct turn count; the declared per-tick ceiling must then reject it.
	var full_turn_rate := TAU + 0.1
	var alias_seed := _sample_at(
		binding, 0.0, 1, {}, 10, true, -1, full_turn_rate)
	var full_turn_alias := _sample_at(
		binding, TAU + 0.1, 2, alias_seed, 10, false, -1,
		full_turn_rate)
	_check(bool(full_turn_alias["finite"])
		and not bool(full_turn_alias["unwrapped_angle_available"])
		and (full_turn_alias["invalid_reasons"] as Array).has(
			"WRAPPED_ANGLE_AMBIGUOUS"),
		"rate witness exposes a full-turn endpoint alias instead of accepting +0.1")

	# Case 13: the mirrored full-turn alias and two-turn alias are equally
	# observable through the rate witness and equally forbidden by the ceiling.
	var negative_rate := -TAU - 0.1
	var negative_seed := _sample_at(
		binding, 0.0, 1, {}, 11, true, -1, negative_rate)
	var negative_alias := _sample_at(
		binding, -TAU - 0.1, 2, negative_seed, 11, false, -1,
		negative_rate)
	_check(not bool(negative_alias["unwrapped_angle_available"])
		and (negative_alias["invalid_reasons"] as Array).has(
			"WRAPPED_ANGLE_AMBIGUOUS"),
		"rate witness exposes the mirrored negative full-turn alias")
	var two_turn_rate := 2.0 * TAU + 0.1
	var two_turn_seed := _sample_at(
		binding, 0.0, 1, {}, 12, true, -1, two_turn_rate)
	var two_turn_alias := _sample_at(
		binding, two_turn_rate, 2, two_turn_seed, 12, false, -1,
		two_turn_rate)
	_check(not bool(two_turn_alias["unwrapped_angle_available"])
		and int(two_turn_alias["endpoint_branch_turn_count"]) == 2
		and (two_turn_alias["invalid_reasons"] as Array).has(
			"WRAPPED_ANGLE_AMBIGUOUS"),
		"rate witness selects and rejects a two-turn endpoint branch")

	# Cases 14-15: disagreement and the preregistered residual boundary are
	# explicit. The endpoint stays available even when the rate integration is
	# too inconsistent to select a continuous branch.
	var mismatch_seed := _sample_at(
		binding, 0.0, 1, {}, 13, true, -1, 0.0)
	var mismatch := _sample_at(
		binding, 0.3, 2, mismatch_seed, 13, false, -1, 0.0)
	_check(bool(mismatch["finite"])
		and mismatch["wrapped_angle_rad"] != null
		and mismatch["unwrapped_angle_rad"] == null
		and (mismatch["invalid_reasons"] as Array).has(
			"UNWRAP_RATE_WITNESS_DISAGREEMENT"),
		"rate/endpoint disagreement preserves wrapped angle but removes unwrap")
	var accepted_rate := 0.119
	var boundary_seed := _sample_at(
		binding, 0.0, 1, {}, 14, true, -1, accepted_rate)
	var inside_boundary := _sample_at(
		binding, 0.1, 2, boundary_seed, 14, false, -1,
		accepted_rate)
	var rejected_rate := 0.121
	var outside_seed := _sample_at(
		binding, 0.0, 1, {}, 15, true, -1, rejected_rate)
	var outside_boundary := _sample_at(
		binding, 0.1, 2, outside_seed, 15, false, -1,
		rejected_rate)
	_check(bool(inside_boundary["unwrapped_angle_available"])
		and float(inside_boundary["rate_witness_residual_rad"]) < 0.02
		and not bool(outside_boundary["unwrapped_angle_available"])
		and float(outside_boundary["rate_witness_residual_rad"]) > 0.02,
		"rate residual envelope accepts 0.019 rad and rejects 0.021 rad")

	# Case 16: a stream cannot stitch across a new coordinate definition even
	# when joint/body labels are unchanged.
	var changed_binding := _binding(0, Quaternion(Vector3.BACK, 0.2))
	var changed_coordinate := _sample_at(
		changed_binding, 0.3, 2, seed, 7, false, -1, 0.1)
	_check(not bool(changed_coordinate["unwrapped_angle_available"])
		and (changed_coordinate["invalid_reasons"] as Array).has(
			"PREVIOUS_STATE_BINDING_MISMATCH"),
		"binding digest prevents continuity across a changed rest coordinate")

	# Case 17: the stateful stream owner supplies the lifetime fact that a pure
	# sampler cannot: an accepted segment identifier is never accepted twice.
	var owner = JointAngleStreamScript.new()
	var owner_parent := _body_sample(
		Transform3D.IDENTITY, "parent_body", 1, 1,
		Vector3.ZERO, 1.0)
	var owner_child := _body_sample(
		Transform3D.IDENTITY, "child_body", 1, 1,
		Vector3.ZERO, 1.0)
	var owner_witness := _initialization_witness(
		binding, 0.0, 1, 1, 21)
	var owner_start: Dictionary = owner.start_segment(
		binding, owner_parent, owner_child, owner_witness)
	var owner_reuse: Dictionary = owner.start_segment(
		binding, owner_parent, owner_child, owner_witness)
	_check(bool(owner_start["ok"])
		and not bool(owner_reuse["ok"])
		and String(owner_reuse["code"]) == "UNWRAP_SEGMENT_REUSE"
		and int(owner_reuse["accepted_segment_count"]) == 1,
		"stream owner accepts a segment once and rejects identifier reuse")
	_finish()


func _binding(
		initial_turn_index: int = 0,
		rest_rotation: Quaternion = Quaternion.IDENTITY) -> Dictionary:
	var built: Dictionary = JointBindingScript.build({
		"joint_id": "unwrap_hinge",
		"parent_body_id": "parent_body",
		"child_body_id": "child_body",
		"axis_parent_local": Vector3.BACK,
		"axis_child_local": Vector3.BACK,
		"anchor_parent_local": Vector3.ZERO,
		"anchor_child_local": Vector3.ZERO,
		"rest_child_rotation_parent_local": rest_rotation,
		"initial_turn_index": initial_turn_index,
		"local_joint_scale_m": 1.0,
		"local_joint_scale_basis": "joint_fixture_extent_min_v1",
		"morphology_config_digest_sha256":
			"sha256:%s" % "br2-unwrap-fixture-v1".sha256_text(),
	})
	assert(bool(built["ok"]), "test binding must build")
	return built["binding"]


func _sample_at(
		binding: Dictionary,
		total_angle: float,
		step: int,
		previous: Dictionary,
		segment_id: int,
		allow_initialization: bool = false,
		capture_epoch: int = -1,
		axis_rate_rad_s: float = 0.0,
		step_s: float = 1.0) -> Dictionary:
	var child := Transform3D(
		Basis(Quaternion(Vector3.BACK, total_angle)), Vector3.ZERO)
	var epoch := step if capture_epoch < 0 else capture_epoch
	var context := {
		"unwrap_segment_id": segment_id,
	}
	if allow_initialization:
		context["initialization_witness"] = _initialization_witness(
			binding, total_angle, step, epoch, segment_id)
	return JointStateScript.sample(
		binding,
		_body_sample(
			Transform3D.IDENTITY, "parent_body", step, epoch,
			Vector3.ZERO, step_s),
		_body_sample(
			child, "child_body", step, epoch,
			Vector3.BACK * axis_rate_rad_s, step_s),
		previous,
		context)


func _initialization_witness(
		binding: Dictionary,
		total_angle: float,
		step: int,
		capture_epoch: int,
		segment_id: int) -> Dictionary:
	return {
		"schema_version": "joint_unwrap_initialization_witness_v1",
		"unwrap_segment_id": segment_id,
		"physics_step_id": step,
		"capture_epoch": capture_epoch,
		"sample_phase": "integrate_callback",
		"joint_id": String(binding["joint_id"]),
		"binding_digest_sha256": String(binding["binding_digest_sha256"]),
		"run_id": "br2-unwrap-run",
		"capture_stream_id": "br2-unwrap-stream",
		"authored_turn_index": int(binding["initial_turn_index"]),
		"fixture_configuration_digest_sha256":
			"sha256:%s" % "br2-unwrap-fixture-v1".sha256_text(),
		"expected_wrapped_angle_rad": wrapf(
			total_angle + PI, 0.0, TAU) - PI,
		"maximum_pose_residual_rad": 1.0e-5,
		"initialization_reason": "fixture_scaffold",
	}


func _body_sample(
		transform: Transform3D,
		body_id: String,
		step: int,
		capture_epoch: int,
		angular_velocity: Vector3,
		step_s: float) -> Dictionary:
	return {
		"schema_version": "mechanics_body_sample_v1",
		"physics_step_id": step,
		"capture_epoch": capture_epoch,
		"sample_phase": "integrate_callback",
		"body_id": body_id,
		"transform": transform,
		"angular_velocity": angular_velocity,
		"step_s": step_s,
		"run_id": "br2-unwrap-run",
		"capture_stream_id": "br2-unwrap-stream",
		"observer_profile_id": "br2_joint_state_v2",
		"observer_adapter_id": "analytic_joint_fixture_v1",
		"finite": true,
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
