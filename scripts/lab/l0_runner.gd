class_name LabL0Runner
extends RefCounted

## Executable Level-0 physics calibration runner.
##
## Each fixture is a real RigidBody3D in the project's configured Jolt space.
## The returned frames originate in direct-state callbacks; analytic metrics are
## calculated only after those measurements have been frozen.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const SensorFrameBuilderScript := preload(
	"res://scripts/lab/mechanics/sensor_frame_builder.gd")
const StationaryRigScript := preload(
	"res://scripts/lab/rigs/stationary_body_rig.gd")
const FreeFallRigScript := preload(
	"res://scripts/lab/rigs/free_fall_rig.gd")
const BallisticRigScript := preload(
	"res://scripts/lab/rigs/ballistic_rig.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")


func run_stationary(
		tree: SceneTree,
		interval_count := 60,
		profile: Dictionary = {},
		trace_store = null,
		pre_event_buffer = null,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var selected_profile := _resolved_profile(profile, &"full_state_v1")
	var clock = CaptureClockScript.new()
	var rig: Dictionary = StationaryRigScript.build(
		clock,
		selected_profile,
		body_parameters,
		fixture_parameters)
	return await _run_fixture(
		tree, clock, rig, interval_count, &"stationary", trace_store,
		pre_event_buffer)


func run_free_fall(
		tree: SceneTree,
		interval_count := 60,
		profile: Dictionary = {},
		trace_store = null,
		pre_event_buffer = null,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var selected_profile := _resolved_profile(profile, &"full_state_v1")
	var clock = CaptureClockScript.new()
	var rig: Dictionary = FreeFallRigScript.build(
		clock,
		selected_profile,
		body_parameters,
		fixture_parameters)
	return await _run_fixture(
		tree, clock, rig, interval_count, &"free_fall", trace_store,
		pre_event_buffer)


func run_ballistic_zero_g(
		tree: SceneTree,
		interval_count := 60,
		profile: Dictionary = {},
		trace_store = null,
		pre_event_buffer = null,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var selected_profile := _resolved_profile(profile, &"full_state_v1")
	var clock = CaptureClockScript.new()
	var rig: Dictionary = BallisticRigScript.build(
		clock,
		selected_profile,
		body_parameters,
		fixture_parameters)
	return await _run_fixture(
		tree, clock, rig, interval_count, &"ballistic_zero_g", trace_store,
		pre_event_buffer)


func run_ballistic_gravity(
		tree: SceneTree,
		interval_count := 60,
		profile: Dictionary = {},
		trace_store = null,
		pre_event_buffer = null,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var selected_profile := _resolved_profile(profile, &"full_state_v1")
	var clock = CaptureClockScript.new()
	var rig: Dictionary = BallisticRigScript.build_with_gravity(
		clock,
		selected_profile,
		body_parameters,
		fixture_parameters)
	return await _run_fixture(
		tree, clock, rig, interval_count, &"ballistic_gravity", trace_store,
		pre_event_buffer)


func run_observer_ab(
		tree: SceneTree,
		interval_count := 60,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	var minimal_profile: Dictionary = ObserverProfileScript.resolve(
		&"minimal_state_v1")
	var full_profile: Dictionary = ObserverProfileScript.resolve(
		&"full_state_v1")
	var contact_profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v1")
	var minimal: Dictionary = await run_ballistic_zero_g(
		tree,
		interval_count,
		minimal_profile,
		null,
		null,
		body_parameters,
		fixture_parameters)
	var full: Dictionary = await run_ballistic_zero_g(
		tree,
		interval_count,
		full_profile,
		null,
		null,
		body_parameters,
		fixture_parameters)
	var contact: Dictionary = await run_ballistic_zero_g(
		tree,
		interval_count,
		contact_profile,
		null,
		null,
		body_parameters,
		fixture_parameters)
	var state_parity := _compare_trajectories(minimal, full)
	var contact_parity := _compare_trajectories(full, contact)
	return {
		"fixture_id": "L0.3.observer_ab.v1",
		"adapter_id": "rigid_body_integrate_forces_v1",
		"minimal_profile_id": minimal_profile["profile_id"],
		"full_profile_id": full_profile["profile_id"],
		"minimal_channel_set_sha256":
			minimal_profile["channel_set_sha256"],
		"full_channel_set_sha256": full_profile["channel_set_sha256"],
		"minimal_channel_count": minimal_profile["channels"].size(),
		"full_channel_count": full_profile["channels"].size(),
		"minimal_contacts_enabled": minimal_profile["contacts_enabled"],
		"full_contacts_enabled": full_profile["contacts_enabled"],
		"contact_profile_id": contact_profile["profile_id"],
		"contact_channel_set_sha256":
			contact_profile["channel_set_sha256"],
		"contact_channel_count": contact_profile["channels"].size(),
		"contact_profile_contacts_enabled":
			contact_profile["contacts_enabled"],
		"contact_profile_cap_per_body":
			contact_profile["contact_cap_per_body"],
		"compared_frame_count": state_parity["compared_frame_count"],
		"structural_identity": state_parity["structural_identity"],
		"max_position_delta_m":
			state_parity["max_position_delta_m"],
		"max_velocity_delta_m_s":
			state_parity["max_velocity_delta_m_s"],
		"contact_compared_frame_count":
			contact_parity["compared_frame_count"],
		"contact_structural_identity":
			contact_parity["structural_identity"],
		"max_contact_profile_position_delta_m":
			contact_parity["max_position_delta_m"],
		"max_contact_profile_velocity_delta_m_s":
			contact_parity["max_velocity_delta_m_s"],
		"minimal": minimal,
		"full": full,
		"contact": contact,
		"configuration_valid": (
			bool(minimal.get("configuration_valid", false))
			and bool(full.get("configuration_valid", false))
			and bool(contact.get("configuration_valid", false))),
		"configuration_errors": (
			_collect_arm_configuration_errors({
				"minimal": minimal,
				"full": full,
				"contact": contact,
			})),
		"finite": (
			bool(minimal.get("finite", false))
			and bool(full.get("finite", false))
			and bool(contact.get("finite", false))
			and bool(state_parity["structural_identity"])
			and bool(contact_parity["structural_identity"])
			and bool(state_parity["finite"])
			and bool(contact_parity["finite"])),
	}


func _run_fixture(
		tree: SceneTree,
		clock,
		rig: Dictionary,
		interval_count: int,
		experiment_kind: StringName,
		trace_store = null,
		pre_event_buffer = null) -> Dictionary:
	assert(tree != null)
	assert(interval_count > 0)
	if not bool(rig.get("ok", false)):
		return _configuration_failure(rig, experiment_kind, trace_store)
	var world := rig["world"] as Node3D
	var body = rig["body"]
	tree.root.add_child(world)
	var actual_body_parameters := _actual_body_parameters(body)
	var actual_fixture_parameters := _actual_fixture_parameters(
		body,
		rig.get("applied_fixture_parameters", {}))
	var configuration_errors := _configuration_mismatches(
		rig.get("resolved_body_parameters", {}),
		actual_body_parameters,
		rig.get("applied_fixture_parameters", {}),
		actual_fixture_parameters)
	if not configuration_errors.is_empty():
		world.queue_free()
		await tree.physics_frame
		var rejected := {
			"fixture_id": rig.get("fixture_id", ""),
			"configuration_errors": configuration_errors,
			"requested_body_parameters":
				rig.get("requested_body_parameters", {}).duplicate(true),
			"requested_fixture_parameters":
				rig.get("requested_fixture_parameters", {}).duplicate(true),
			"applied_body_parameters":
				rig.get("resolved_body_parameters", {}).duplicate(true),
			"applied_fixture_parameters":
				rig.get("applied_fixture_parameters", {}).duplicate(true),
			"actual_body_parameters": actual_body_parameters,
			"actual_fixture_parameters": actual_fixture_parameters,
		}
		return _configuration_failure(
			rejected, experiment_kind, trace_store)

	var nominal_step_s := 1.0 / float(Engine.physics_ticks_per_second)
	var frames: Array = []
	var timing_errors: Array[String] = []
	var recording_results: Array = []
	var recording_ok := true
	for frame_index in range(interval_count + 1):
		clock.call(
			"open_epoch",
			frame_index,
			float(frame_index) * nominal_step_s,
			&"integrate_callback")
		await tree.physics_frame
		var sample: Dictionary = body.latest_body_sample
		var contacts: Array = body.latest_contacts
		if sample.is_empty():
			timing_errors.append(
				"no direct-state sample for frame %d" % frame_index)
		var builder = SensorFrameBuilderScript.new()
		builder.begin(
			frame_index,
			float(frame_index) * nominal_step_s,
			&"integrate_callback",
			&"MEASURE",
			0,
			[StationaryRigScript.BODY_ID])
		builder.add_body_sample(sample)
		builder.add_contacts(contacts)
		var frame: Dictionary = builder.seal()
		frames.append(frame)
		if pre_event_buffer != null:
			var ring_result: Dictionary = pre_event_buffer.call(
				"append", frame_index, frame)
			recording_results.append({
				"sink": "pre_event_ring",
				"result": ring_result,
			})
			if not bool(ring_result.get("ok", false)):
				recording_ok = false
		if trace_store != null:
			var append_result: Dictionary = trace_store.call(
				"append_frame", frame)
			recording_results.append({
				"sink": "trace_store",
				"result": append_result.duplicate(true),
			})
			if not bool(append_result.get("ok", false)):
				recording_ok = false
		clock.call("close_epoch")

	var callback_count := int(body.callback_sequence)
	var untagged_callback_count := int(body.untagged_callback_count)
	var profile_id := String(body.call("profile_id"))
	var adapter_id := String(body.call("adapter_id"))
	var profile_channel_count := int(body.call("profile_channel_count"))
	var projected_channel_count := (
		body.latest_profile_projection as Dictionary).size()
	var channel_availability := _profile_channel_availability(
		frames[0] if not frames.is_empty() else {},
		body.observer_profile)
	var available_channel_count := 0
	var observer_contract_satisfied := true
	for channel_id in channel_availability:
		var channel_status := String(
			channel_availability[channel_id].get("status", "unavailable"))
		if channel_status in ["measured", "derived", "engine_estimate"]:
			available_channel_count += 1
		else:
			observer_contract_satisfied = false
	var contacts_enabled := bool(body.contact_monitor)
	var contact_cap_per_body := int(body.max_contacts_reported)
	# Scientific conclusions must be calculated from the exact numeric
	# representation that crosses the evidence boundary. Canonical JSON
	# intentionally quantizes floats to a stable 14-significant-digit form;
	# calculating from the pre-serialization values can otherwise manufacture
	# sub-micro residual differences between the runner-authored summary and
	# the independent verifier reading the sealed stream.
	frames = CanonicalJsonScript.normalize(frames) as Array
	var metrics := _calculate_metrics(
		frames,
		rig["initial_position_m"],
		rig["initial_velocity_m_s"],
		float(actual_body_parameters["mass_kg"]),
		experiment_kind)
	var result := {
		"fixture_id": String(rig["fixture_id"]),
		"experiment_kind": String(experiment_kind),
		"observer_profile_id": profile_id,
		"observer_adapter_id": adapter_id,
		"observer_profile_channel_count": profile_channel_count,
		"observer_projected_channel_count": projected_channel_count,
		"observer_available_channel_count": available_channel_count,
		"observer_channel_availability": channel_availability,
		"observer_contract_satisfied": observer_contract_satisfied,
		"observer_contacts_enabled": contacts_enabled,
		"observer_contact_cap_per_body": contact_cap_per_body,
		"physics_backend": String(ProjectSettings.get_setting(
			"physics/3d/physics_engine", "unknown")),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"nominal_step_s": nominal_step_s,
		"interval_count": interval_count,
		"sample_count": frames.size(),
		"direct_state_callback_count": callback_count,
		"untagged_callback_count": untagged_callback_count,
		"frames": frames,
		"timing_errors": timing_errors,
		"recording_requested": trace_store != null,
		"recording_ok": recording_ok,
		"recording_results": recording_results,
		"configuration_valid": true,
		"configuration_errors": [],
		"requested_body_parameters":
			rig["requested_body_parameters"].duplicate(true),
		"requested_fixture_parameters":
			rig["requested_fixture_parameters"].duplicate(true),
		"applied_body_parameters":
			rig["resolved_body_parameters"].duplicate(true),
		"applied_fixture_parameters":
			rig["applied_fixture_parameters"].duplicate(true),
		"actual_body_parameters": actual_body_parameters,
		"actual_fixture_parameters": actual_fixture_parameters,
		"finite": (
			bool(metrics["finite"])
			and timing_errors.is_empty()
			and callback_count >= frames.size()
			and observer_contract_satisfied),
	}
	for key in metrics:
		result[key] = metrics[key]
	result["ok"] = bool(result["finite"]) and recording_ok

	world.queue_free()
	await tree.physics_frame
	return result


func _calculate_metrics(
		frames: Array,
		configured_initial_position: Vector3,
		configured_initial_velocity: Vector3,
		mass_kg: float,
		experiment_kind: StringName) -> Dictionary:
	if frames.is_empty():
		return {"finite": false}
	var first_sample: Dictionary = _only_body(frames[0])
	var final_sample: Dictionary = _only_body(frames[-1])
	var measured_initial_position := _value_to_vector(
		first_sample["transform"]["origin"])
	var measured_initial_velocity := _value_to_vector(
		first_sample["linear_velocity"])
	var measured_final_position := _value_to_vector(
		final_sample["transform"]["origin"])
	var measured_final_velocity := _value_to_vector(
		final_sample["linear_velocity"])
	var measured_initial_mass_kg := float(first_sample["mass_kg"])
	var measured_final_mass_kg := float(final_sample["mass_kg"])
	var gravity_world := _value_to_vector(
		first_sample["total_gravity_world"])
	var step_s := float(first_sample["step_s"])
	var max_position_error_m := 0.0
	var max_velocity_error_m_s := 0.0
	var max_acceleration_error_m_s2 := 0.0
	var max_momentum_error_kg_m_s := 0.0
	var max_mass_oracle_error_kg := 0.0
	var max_kinetic_energy_j := 0.0
	var total_contact_count := 0
	var coherent_ids := true
	var all_finite := (
		measured_initial_position.is_finite()
		and measured_initial_velocity.is_finite()
		and gravity_world.is_finite()
		and is_finite(step_s)
		and step_s > 0.0)
	var previous_velocity := measured_initial_velocity

	for frame_index in frames.size():
		var frame: Dictionary = frames[frame_index]
		var sample: Dictionary = _only_body(frame)
		var position := _value_to_vector(sample["transform"]["origin"])
		var velocity := _value_to_vector(sample["linear_velocity"])
		var sample_mass_kg := float(sample["mass_kg"])
		var t := float(frame_index) * step_s
		var expected_position := measured_initial_position
		var expected_velocity := measured_initial_velocity
		match experiment_kind:
			&"free_fall", &"ballistic_gravity":
				expected_position += (
					measured_initial_velocity * t
					+ 0.5 * gravity_world * t * t)
				expected_velocity += gravity_world * t
			&"ballistic_zero_g":
				expected_position += measured_initial_velocity * t
			&"stationary":
				pass
			_:
				all_finite = false

		max_position_error_m = maxf(
			max_position_error_m, position.distance_to(expected_position))
		max_velocity_error_m_s = maxf(
			max_velocity_error_m_s, velocity.distance_to(expected_velocity))
		max_momentum_error_kg_m_s = maxf(
			max_momentum_error_kg_m_s,
			(mass_kg * velocity).distance_to(
				mass_kg * expected_velocity))
		max_mass_oracle_error_kg = maxf(
			max_mass_oracle_error_kg,
			absf(sample_mass_kg - mass_kg))
		max_kinetic_energy_j = maxf(
			max_kinetic_energy_j,
			0.5 * mass_kg * velocity.length_squared())
		total_contact_count += (frame["contacts"] as Array).size()
		coherent_ids = (
			coherent_ids
			and int(frame["frame_id"]) == frame_index
			and int(frame["physics_step_id"]) == frame_index
			and int(frame["capture_epoch"]) == frame_index
			and int(sample["physics_step_id"]) == frame_index
			and int(sample["capture_epoch"]) == frame_index
			and String(frame["sample_phase"]) == "integrate_callback"
			and String(sample["sample_phase"]) == "integrate_callback")
		all_finite = (
			all_finite
			and bool(frame["finite"])
			and bool(sample["finite"])
			and position.is_finite()
			and velocity.is_finite())
		if frame_index > 0:
			var measured_acceleration := (
				velocity - previous_velocity) / step_s
			max_acceleration_error_m_s2 = maxf(
				max_acceleration_error_m_s2,
				measured_acceleration.distance_to(gravity_world))
		previous_velocity = velocity

	return {
		"configured_initial_position_error_m":
			measured_initial_position.distance_to(configured_initial_position),
		"configured_initial_velocity_error_m_s":
			measured_initial_velocity.distance_to(configured_initial_velocity),
		"measured_initial_position_m":
			_vector_to_value(measured_initial_position),
		"measured_initial_velocity_m_s":
			_vector_to_value(measured_initial_velocity),
		"measured_final_position_m":
			_vector_to_value(measured_final_position),
		"measured_final_velocity_m_s":
			_vector_to_value(measured_final_velocity),
		"measured_initial_mass_kg": measured_initial_mass_kg,
		"measured_final_mass_kg": measured_final_mass_kg,
		"max_mass_oracle_error_kg": max_mass_oracle_error_kg,
		"measured_initial_momentum_kg_m_s": _vector_to_value(
			measured_initial_mass_kg * measured_initial_velocity),
		"measured_final_momentum_kg_m_s": _vector_to_value(
			measured_final_mass_kg * measured_final_velocity),
		"measured_momentum_delta_kg_m_s": _vector_to_value(
			measured_final_mass_kg * measured_final_velocity
			- measured_initial_mass_kg * measured_initial_velocity),
		"measured_gravity_world_m_s2": _vector_to_value(gravity_world),
		"measured_step_s": step_s,
		"max_position_error_m": max_position_error_m,
		"max_velocity_error_m_s": max_velocity_error_m_s,
		"max_acceleration_error_m_s2": max_acceleration_error_m_s2,
		"max_momentum_error_kg_m_s": max_momentum_error_kg_m_s,
		"max_kinetic_energy_j": max_kinetic_energy_j,
		"total_contact_count": total_contact_count,
		"coherent_frame_identity": coherent_ids,
		"finite": (
			all_finite
			and coherent_ids
			and measured_initial_position.is_finite()
			and measured_initial_velocity.is_finite()
			and measured_final_position.is_finite()
			and measured_final_velocity.is_finite()
			and is_finite(measured_initial_mass_kg)
			and measured_initial_mass_kg > 0.0
			and is_finite(measured_final_mass_kg)
			and measured_final_mass_kg > 0.0
			and is_finite(max_mass_oracle_error_kg)),
	}


static func _only_body(frame: Dictionary) -> Dictionary:
	var bodies: Dictionary = frame.get("bodies", {})
	if bodies.size() != 1:
		return {}
	return bodies.values()[0]


static func _actual_body_parameters(body: RigidBody3D) -> Dictionary:
	return {
		"mass_kg": body.mass,
		"gravity_scale": body.gravity_scale,
		"initial_position_m": body.position,
		"initial_velocity_m_s": body.linear_velocity,
		"linear_damp_s1": body.linear_damp,
		"angular_damp_s1": body.angular_damp,
	}


static func _profile_channel_availability(
		frame: Dictionary,
		profile: Dictionary) -> Dictionary:
	var bodies: Dictionary = frame.get("bodies", {})
	var body: Dictionary = bodies.values()[0] if bodies.size() == 1 else {}
	var whole_body: Dictionary = frame.get("whole_body", {})
	var contacts: Variant = frame.get("contacts")
	var result: Dictionary = {}
	for channel_value in profile.get("channels", []):
		var channel := String(channel_value)
		var available := false
		var source := "rigid_body_integrate_forces_v1"
		var status := "measured"
		match channel:
			"body_transform":
				available = body.has("transform")
			"center_of_mass_world":
				available = body.has("center_of_mass_world")
			"linear_velocity":
				available = body.has("linear_velocity")
			"angular_velocity":
				available = body.has("angular_velocity")
			"sleeping":
				available = body.has("sleeping")
			"mass":
				available = body.has("mass_kg")
			"inverse_inertia_tensor_world":
				available = body.has("inverse_inertia_tensor_world")
			"whole_body_momentum":
				available = whole_body.has("linear_momentum_world_n_s")
				source = "whole_body_state_v1"
				status = "derived"
			"contacts", "contact_impulses":
				available = (
					contacts is Array
					and bool(profile.get("contacts_enabled", false)))
			"callback_sequence":
				available = body.has("body_callback_sequence")
			"capture_epoch":
				available = body.has("capture_epoch")
			_:
				available = false
		result[channel] = {
			"status": status if available else "unavailable",
			"reason": null if available else "CHANNEL_PROVIDER_NOT_CERTIFIED",
			"source": source if available else null,
		}
	return result


static func _actual_fixture_parameters(
		body: RigidBody3D,
		applied_fixture: Dictionary) -> Dictionary:
	return {
		"contact_cap": int(applied_fixture.get("contact_cap", -1)),
		"contacts_enabled": body.contact_monitor,
		"effective_contact_cap_per_body": body.max_contacts_reported,
	}


static func _configuration_mismatches(
		expected_body: Dictionary,
		actual_body: Dictionary,
		expected_fixture: Dictionary,
		actual_fixture: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for key in [
		"mass_kg",
		"gravity_scale",
		"linear_damp_s1",
		"angular_damp_s1",
	]:
		if (
			not expected_body.has(key)
			or not actual_body.has(key)
			or not is_equal_approx(
				float(expected_body.get(key, NAN)),
				float(actual_body.get(key, NAN)))
		):
			errors.append({
				"code": "BODY_CONFIGURATION_MISMATCH",
				"path": "/body_parameters/%s" % key,
				"message": "Live RigidBody3D property does not match the resolved parameter",
				"expected": expected_body.get(key),
				"actual": actual_body.get(key),
			})
	for key in ["initial_position_m", "initial_velocity_m_s"]:
		var expected_value: Variant = expected_body.get(key)
		var actual_value: Variant = actual_body.get(key)
		var vectors_match := (
			typeof(expected_value) != TYPE_VECTOR3
			or typeof(actual_value) != TYPE_VECTOR3)
		if not vectors_match:
			var expected_vector: Vector3 = expected_value
			var actual_vector: Vector3 = actual_value
			vectors_match = expected_vector.is_equal_approx(actual_vector)
		else:
			vectors_match = false
		if not vectors_match:
			errors.append({
				"code": "BODY_CONFIGURATION_MISMATCH",
				"path": "/body_parameters/%s" % key,
				"message": "Live RigidBody3D vector does not match the resolved parameter",
				"expected": expected_value,
				"actual": actual_value,
			})
	if (
		int(expected_fixture.get("contact_cap", -1))
		!= int(actual_fixture.get("contact_cap", -2))
	):
		errors.append({
			"code": "FIXTURE_CONFIGURATION_MISMATCH",
			"path": "/fixture_parameters/contact_cap",
			"message": "Fixture contact-cap upper bound changed during application",
			"expected": expected_fixture.get("contact_cap"),
			"actual": actual_fixture.get("contact_cap"),
		})
	if (
		bool(expected_fixture.get("contacts_enabled", false))
		!= bool(actual_fixture.get("contacts_enabled", false))
	):
		errors.append({
			"code": "FIXTURE_CONFIGURATION_MISMATCH",
			"path": "/observer_profile/contacts_enabled",
			"message": "Live contact monitor does not match the observer profile",
			"expected": expected_fixture.get("contacts_enabled"),
			"actual": actual_fixture.get("contacts_enabled"),
		})
	if (
		int(expected_fixture.get("effective_contact_cap_per_body", -1))
		!= int(actual_fixture.get("effective_contact_cap_per_body", -2))
	):
		errors.append({
			"code": "FIXTURE_CONFIGURATION_MISMATCH",
			"path": "/observer_profile/contact_cap_per_body",
			"message": "Live contact cap does not match the compatible observer cap",
			"expected":
				expected_fixture.get("effective_contact_cap_per_body"),
			"actual":
				actual_fixture.get("effective_contact_cap_per_body"),
		})
	return errors


static func _configuration_failure(
		rig: Dictionary,
		experiment_kind: StringName,
		trace_store = null) -> Dictionary:
	return {
		"ok": false,
		"finite": false,
		"configuration_valid": false,
		"fixture_id": String(rig.get("fixture_id", "")),
		"experiment_kind": String(experiment_kind),
		"configuration_errors":
			rig.get("configuration_errors", []).duplicate(true),
		"requested_body_parameters":
			rig.get("requested_body_parameters", {}).duplicate(true),
		"requested_fixture_parameters":
			rig.get("requested_fixture_parameters", {}).duplicate(true),
		"applied_body_parameters":
			rig.get("applied_body_parameters", {}).duplicate(true),
		"applied_fixture_parameters":
			rig.get("applied_fixture_parameters", {}).duplicate(true),
		"actual_body_parameters":
			rig.get("actual_body_parameters", {}).duplicate(true),
		"actual_fixture_parameters":
			rig.get("actual_fixture_parameters", {}).duplicate(true),
		"sample_count": 0,
		"frames": [],
		"timing_errors": [],
		"recording_requested": trace_store != null,
		"recording_ok": false,
		"recording_results": [],
	}


static func _collect_arm_configuration_errors(
		arms: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	for arm_name in arms.keys():
		var arm: Dictionary = arms[arm_name]
		for raw_error in arm.get("configuration_errors", []):
			var error: Dictionary = raw_error.duplicate(true)
			error["observer_arm"] = String(arm_name)
			errors.append(error)
	return errors


static func _compare_trajectories(
		first: Dictionary,
		second: Dictionary) -> Dictionary:
	var first_frames: Array = first.get("frames", [])
	var second_frames: Array = second.get("frames", [])
	var count := mini(first_frames.size(), second_frames.size())
	var max_position_delta_m := 0.0
	var max_velocity_delta_m_s := 0.0
	var structural_identity := first_frames.size() == second_frames.size()
	for frame_index in count:
		var a: Dictionary = _only_body(first_frames[frame_index])
		var b: Dictionary = _only_body(second_frames[frame_index])
		max_position_delta_m = maxf(
			max_position_delta_m,
			_value_to_vector(a["transform"]["origin"]).distance_to(
				_value_to_vector(b["transform"]["origin"])))
		max_velocity_delta_m_s = maxf(
			max_velocity_delta_m_s,
			_value_to_vector(a["linear_velocity"]).distance_to(
				_value_to_vector(b["linear_velocity"])))
		structural_identity = (
			structural_identity
			and int(a["physics_step_id"]) == int(b["physics_step_id"])
			and int(a["capture_epoch"]) == int(b["capture_epoch"])
			and int(a["body_callback_sequence"])
				== int(b["body_callback_sequence"]))
	return {
		"compared_frame_count": count,
		"structural_identity": structural_identity,
		"max_position_delta_m": max_position_delta_m,
		"max_velocity_delta_m_s": max_velocity_delta_m_s,
		"finite": (
			is_finite(max_position_delta_m)
			and is_finite(max_velocity_delta_m_s)),
	}


static func _value_to_vector(value: Variant) -> Vector3:
	var coordinates: Array = value
	return Vector3(
		float(coordinates[0]),
		float(coordinates[1]),
		float(coordinates[2]))


static func _vector_to_value(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _resolved_profile(
		profile: Dictionary,
		default_profile_id: StringName) -> Dictionary:
	if profile.is_empty():
		return ObserverProfileScript.resolve(default_profile_id).duplicate(true)
	return profile.duplicate(true)
