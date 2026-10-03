class_name ObservedRigidBody
extends RigidBody3D

## Read-only direct-state observer used by the calibration fixtures.
##
## This callback never changes transform, velocity, force, or sleep state. Its
## only side effect is replacing the latest immutable-by-convention value
## dictionaries. SensorFrameBuilder freezes those values at the recorder seam.

const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")

var body_id: StringName = &""
var creature_id: StringName = &""
var support_role: StringName = &""
var part_index := -1
var capture_clock
var observer_profile: Variant = {}
var run_id := ""
var capture_stream_id := ""
var contact_capacity: Dictionary = {}

var latest_body_sample: Dictionary = {}
var latest_contacts: Array = []
var latest_contacts_v2: Array = []
var latest_contact_v2_diagnostics: Dictionary = {}
var latest_diagnostics: Dictionary = {}
var latest_profile_projection: Dictionary = {}
var callback_sequence := 0
var untagged_callback_count := 0
var _contact_v2_peak_observed_count := 0


func _ready() -> void:
	assert(capture_clock != null, "ObservedRigidBody requires a LabCaptureClock")
	assert(not String(body_id).is_empty(), "ObservedRigidBody requires a stable body_id")
	var contacts_enabled := bool(_profile_value(&"contacts_enabled", false))
	contact_monitor = contacts_enabled
	if _uses_raw_contact_v2():
		assert(not String(creature_id).is_empty(),
			"raw contact v2 requires a stable creature_id")
		assert(not String(support_role).is_empty(),
			"raw contact v2 requires an explicit support_role")
		assert(not run_id.is_empty() and not capture_stream_id.is_empty(),
			"raw contact v2 requires run and capture-stream identity")
		assert(String(contact_capacity.get("schema_version", ""))
			== ContactCapacityScript.SCHEMA_VERSION,
			"raw contact v2 requires a derived contact-capacity contract")
		var derived_cap := int(contact_capacity.get(
			"configured_cap_per_body", 0))
		var policy_max := int(_profile_value(
			&"contact_policy_max_cap_per_body", 0))
		assert(derived_cap > 0 and policy_max > 0 \
			and derived_cap <= policy_max,
			"derived raw-contact cap must fit the observer policy")
		max_contacts_reported = derived_cap
		# Collider metadata is the semantic seam used when another observed
		# creature body becomes the counterparty. Runtime instance IDs remain
		# diagnostic only and never enter canonical contact identity.
		set_meta("lab_body_id", String(body_id))
		set_meta("lab_creature_id", String(creature_id))
		set_meta("lab_surface_tag", "creature_body")
		set_meta("lab_surface_layer", 1)
	else:
		max_contacts_reported = (
			maxi(1, int(_profile_value(&"contact_cap_per_body", 8)))
			if contacts_enabled
			else 0)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	callback_sequence += 1
	if capture_clock == null:
		untagged_callback_count += 1
		return
	var tag: Dictionary = capture_clock.call("current_tag")
	if tag.is_empty():
		untagged_callback_count += 1
		return
	latest_body_sample = _sample_body(state, tag, callback_sequence)
	latest_contacts = _sample_contacts(state, tag, callback_sequence)
	if _uses_raw_contact_v2():
		latest_contacts_v2 = _sample_contacts_v2(
			state, tag, callback_sequence)
		var capacity_observation: Dictionary = ContactCapacityScript.observe(
			contact_capacity,
			latest_contacts_v2.size(),
			_contact_v2_peak_observed_count)
		_contact_v2_peak_observed_count = int(
			capacity_observation["peak_observed_count"])
		latest_contact_v2_diagnostics = {
			"schema_version": "raw_contact_capture_diagnostics_v1",
			"capacity": contact_capacity.duplicate(true),
			"observation": capacity_observation,
		}
	else:
		latest_contacts_v2 = []
		latest_contact_v2_diagnostics = {}
	latest_profile_projection = _build_profile_projection(latest_body_sample)


func profile_id() -> String:
	return String(_profile_value(&"profile_id", "unregistered"))


func adapter_id() -> String:
	return (
		"rigid_body_integrate_forces_v2"
		if _uses_raw_contact_v2()
		else "rigid_body_integrate_forces_v1")


func profile_channel_count() -> int:
	return _profile_channels().size()


func _sample_body(
		state: PhysicsDirectBodyState3D,
		tag: Dictionary,
		sequence: int) -> Dictionary:
	var transform_world := state.transform
	var center_of_mass_world := (
		transform_world.origin + state.center_of_mass)
	var center_of_mass_from_local := (
		transform_world * state.center_of_mass_local)
	var inverse_inertia_world := state.inverse_inertia_tensor
	var com_oracle_error_m := center_of_mass_world.distance_to(
		center_of_mass_from_local)
	var sample_finite := (
		_transform_is_finite(transform_world)
		and center_of_mass_world.is_finite()
		and center_of_mass_from_local.is_finite()
		and state.linear_velocity.is_finite()
		and state.angular_velocity.is_finite()
		and _basis_is_finite(inverse_inertia_world)
		and state.total_gravity.is_finite()
		and is_finite(state.step)
		and state.step > 0.0
		and is_finite(mass)
		and mass > 0.0
		and is_finite(com_oracle_error_m))
	latest_diagnostics = {
		"com_frame_oracle_error_m": com_oracle_error_m,
		"observer_profile_id": profile_id(),
		"observer_adapter_id": adapter_id(),
	}

	return {
		"physics_step_id": int(tag["physics_step_id"]),
		"body_callback_sequence": sequence,
		"capture_epoch": int(tag["capture_epoch"]),
		"sample_phase": String(tag["sample_phase"]),
		"body_id": String(body_id),
		"part_index": part_index,
		"transform": _transform_to_value(transform_world),
		"center_of_mass_world": _vector_to_value(center_of_mass_world),
		"linear_velocity": _vector_to_value(state.linear_velocity),
		"angular_velocity": _vector_to_value(state.angular_velocity),
		"mass_kg": mass,
		"inverse_inertia_tensor_world": _basis_to_value(inverse_inertia_world),
		"sleeping": state.sleeping,
		"finite": sample_finite,
		"step_s": state.step,
		"total_gravity_world": _vector_to_value(state.total_gravity),
		"com_frame_oracle_error_m": com_oracle_error_m,
		"observer_profile_id": profile_id(),
		"observer_adapter_id": adapter_id(),
	}


func _sample_contacts(
		state: PhysicsDirectBodyState3D,
		tag: Dictionary,
		sequence: int) -> Array:
	if not bool(_profile_value(&"contacts_enabled", false)):
		return []
	var contacts: Array = []
	var normal_epsilon_squared := float(
		_profile_value(&"normal_epsilon_squared", 1.0e-12))
	for contact_index in state.get_contact_count():
		var point_world := state.get_contact_local_position(contact_index)
		var reported_normal := state.get_contact_local_normal(contact_index)
		var normal_available := (
			reported_normal.is_finite()
			and reported_normal.length_squared() > normal_epsilon_squared)
		var normal_world := (
			reported_normal.normalized()
			if normal_available
			else Vector3.ZERO)
		var local_velocity := state.get_contact_local_velocity_at_position(
			contact_index)
		var other_velocity := state.get_contact_collider_velocity_at_position(
			contact_index)
		var relative_velocity := local_velocity - other_velocity
		var tangential_velocity := relative_velocity
		if normal_available:
			tangential_velocity -= (
				relative_velocity.dot(normal_world) * normal_world)
		var impulse_world := state.get_contact_impulse(contact_index)
		var contact_finite := (
			point_world.is_finite()
			and reported_normal.is_finite()
			and relative_velocity.is_finite()
			and tangential_velocity.is_finite()
			and impulse_world.is_finite())
		contacts.append({
			"contact_key": "%s:%d:%d" % [
				String(body_id), sequence, contact_index],
			"physics_step_id": int(tag["physics_step_id"]),
			"capture_epoch": int(tag["capture_epoch"]),
			"body_callback_sequence": sequence,
			"sample_phase": String(tag["sample_phase"]),
			"body_id": String(body_id),
			"contact_index": contact_index,
			"collider_instance_id": state.get_contact_collider_id(contact_index),
			"point_world": _vector_to_value(point_world),
			"point_body_local": _vector_to_value(
				state.transform.affine_inverse() * point_world),
			"other_point_world": _vector_to_value(
				state.get_contact_collider_position(contact_index)),
			"normal_world": _vector_to_value(normal_world),
			"normal_available": normal_available,
			"normal_frame_source": "jolt_world_backend",
			"normal_quality": (
				"backend_pinned"
				if normal_available
				else "invalid_zero_or_nonfinite"),
			"relative_velocity_world": _vector_to_value(relative_velocity),
			"tangential_velocity_world": _vector_to_value(
				tangential_velocity),
			"tangential_velocity_available": normal_available,
			"impulse_world_ns": _vector_to_value(impulse_world),
			"impulse_quality": "jolt_predicted_estimate",
			"finite": contact_finite,
		})
	return contacts


func _sample_contacts_v2(
		state: PhysicsDirectBodyState3D,
		tag: Dictionary,
		sequence: int) -> Array:
	var contacts: Array = []
	var normal_epsilon_squared := float(
		_profile_value(&"normal_epsilon_squared", 1.0e-12))
	for contact_index in state.get_contact_count():
		var point_world := state.get_contact_local_position(contact_index)
		var other_point_world := state.get_contact_collider_position(
			contact_index)
		var reported_normal := state.get_contact_local_normal(contact_index)
		var normal_available := (
			reported_normal.is_finite()
			and reported_normal.length_squared() > normal_epsilon_squared)
		var normal_world := (
			reported_normal.normalized()
			if normal_available
			else Vector3.ZERO)
		var local_velocity := state.get_contact_local_velocity_at_position(
			contact_index)
		var other_velocity := state.get_contact_collider_velocity_at_position(
			contact_index)
		var relative_velocity := local_velocity - other_velocity
		var impulse_world := state.get_contact_impulse(contact_index)
		var observed_shape_index := state.get_contact_local_shape(contact_index)
		var counterparty_shape_index := state.get_contact_collider_shape(
			contact_index)
		var collider := state.get_contact_collider_object(contact_index)
		var counterparty := _counterparty_semantics(
			collider, counterparty_shape_index)
		var observed_shape_id := _shape_semantic_id(
			self, observed_shape_index)
		var semantics_finite := (
			observed_shape_index >= 0
			and counterparty_shape_index >= 0
			and not observed_shape_id.is_empty()
			and bool(counterparty["finite"]))
		var contact_finite := (
			point_world.is_finite()
			and other_point_world.is_finite()
			and reported_normal.is_finite()
			and relative_velocity.is_finite()
			and impulse_world.is_finite()
			and normal_available
			and semantics_finite)
		contacts.append({
			"schema_version": "raw_contact_point_v2",
			# Observation identity may contain callback-local coordinates. The
			# canonical patch identity deliberately does not.
			"raw_contact_observation_id": "%s:%s:%s:%d:%d" % [
				run_id,
				capture_stream_id,
				String(body_id),
				sequence,
				contact_index,
			],
			"physics_step_id": int(tag["physics_step_id"]),
			"capture_epoch": int(tag["capture_epoch"]),
			"sample_phase": String(tag["sample_phase"]),
			"run_id": run_id,
			"capture_stream_id": capture_stream_id,
			"observer_profile_id": profile_id(),
			"observer_adapter_id": adapter_id(),
			"observed_body_id": String(body_id),
			"observed_creature_id": String(creature_id),
			"observed_role": String(support_role),
			"observed_shape_index": observed_shape_index,
			"observed_shape_semantic_id": observed_shape_id,
			"counterparty_kind": counterparty["counterparty_kind"],
			"counterparty_semantic_id":
				counterparty["counterparty_semantic_id"],
			"counterparty_creature_id":
				counterparty["counterparty_creature_id"],
			"counterparty_shape_index": counterparty_shape_index,
			"counterparty_shape_semantic_id":
				counterparty["counterparty_shape_semantic_id"],
			"counterparty_runtime_instance_id": (
				collider.get_instance_id() if collider != null else 0),
			"surface_layer": counterparty["surface_layer"],
			"surface_tag": counterparty["surface_tag"],
			"point_world": point_world,
			"point_body_local": state.transform.affine_inverse() * point_world,
			"other_point_world": other_point_world,
			"normal_world": normal_world,
			"normal_available": normal_available,
			"normal_frame_source": "jolt_world_backend",
			"impulse_world_ns": impulse_world,
			"impulse_quality": "jolt_predicted_estimate",
			"relative_velocity_world_mps": relative_velocity,
			"finite": contact_finite,
		})
	return contacts


func _counterparty_semantics(
		collider: Object,
		shape_index: int) -> Dictionary:
	if collider == null:
		return _invalid_counterparty_semantics()
	var counterparty_creature_id := _meta_string(
		collider, &"lab_creature_id")
	var counterparty_kind := (
		"creature" if not counterparty_creature_id.is_empty()
		else "environment")
	var semantic_id := (
		_meta_string(collider, &"lab_body_id")
		if counterparty_kind == "creature"
		else _meta_string(collider, &"lab_surface_id"))
	var surface_tag := _meta_string(collider, &"lab_surface_tag")
	var surface_layer_value: Variant = collider.get_meta(
		"lab_surface_layer", null)
	var surface_layer := (
		int(surface_layer_value) if surface_layer_value is int else 0)
	var shape_semantic_id := _shape_semantic_id(collider, shape_index)
	return {
		"finite": (
			shape_index >= 0
			and not semantic_id.is_empty()
			and not shape_semantic_id.is_empty()
			and not surface_tag.is_empty()
			and surface_layer > 0),
		"counterparty_kind": counterparty_kind,
		"counterparty_semantic_id": semantic_id,
		"counterparty_creature_id": (
			counterparty_creature_id
			if counterparty_kind == "creature"
			else null),
		"counterparty_shape_semantic_id": shape_semantic_id,
		"surface_layer": surface_layer,
		"surface_tag": surface_tag,
	}


func _invalid_counterparty_semantics() -> Dictionary:
	return {
		"finite": false,
		"counterparty_kind": "environment",
		"counterparty_semantic_id": "",
		"counterparty_creature_id": null,
		"counterparty_shape_semantic_id": "",
		"surface_layer": 0,
		"surface_tag": "",
	}


func _shape_semantic_id(
		collision_object: Object,
		shape_index: int) -> String:
	if collision_object == null \
			or not collision_object is CollisionObject3D \
			or shape_index < 0:
		return ""
	var owner_id := (collision_object as CollisionObject3D).shape_find_owner(
		shape_index)
	if owner_id < 0:
		return ""
	var owner := (collision_object as CollisionObject3D).shape_owner_get_owner(
		owner_id)
	return _meta_string(owner, &"lab_shape_id")


static func _meta_string(value: Object, key: StringName) -> String:
	if value == null or not value.has_meta(key):
		return ""
	var metadata: Variant = value.get_meta(key)
	return (
		String(metadata)
		if metadata is String or metadata is StringName
		else "")


func _profile_value(property_name: StringName, fallback: Variant) -> Variant:
	if observer_profile is Dictionary:
		return (observer_profile as Dictionary).get(String(property_name), fallback)
	if observer_profile == null or not observer_profile is Object:
		return fallback
	for description in (observer_profile as Object).get_property_list():
		if StringName(description.get("name", "")) == property_name:
			return (observer_profile as Object).get(property_name)
	return fallback


func _profile_channels() -> Array:
	var value: Variant = _profile_value(&"channels", [])
	return (value as Array).duplicate() if value is Array else []


func _uses_raw_contact_v2() -> bool:
	return _profile_channels().has("raw_contacts_v2")


func _build_profile_projection(sample: Dictionary) -> Dictionary:
	var projection: Dictionary = {}
	for channel_value in _profile_channels():
		var channel := String(channel_value)
		match channel:
			"body_transform":
				projection[channel] = sample["transform"]
			"center_of_mass_world":
				projection[channel] = sample["center_of_mass_world"]
			"linear_velocity":
				projection[channel] = sample["linear_velocity"]
			"angular_velocity":
				projection[channel] = sample["angular_velocity"]
			"sleeping":
				projection[channel] = sample["sleeping"]
			"mass":
				projection[channel] = sample["mass_kg"]
			"inverse_inertia_tensor_world":
				projection[channel] = sample["inverse_inertia_tensor_world"]
			"contacts":
				projection[channel] = latest_contacts
			"raw_contacts_v2":
				projection[channel] = latest_contacts_v2
			"contact_capacity_v1":
				projection[channel] = latest_contact_v2_diagnostics
			"callback_sequence":
				projection[channel] = sample["body_callback_sequence"]
			"capture_epoch":
				projection[channel] = sample["capture_epoch"]
			_:
				# Whole-body/energy channels are assembled above this one-body
				# adapter. Their registration is still part of the profile
				# identity, but no false local substitute is manufactured.
				pass
	return projection


static func _vector_to_value(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _basis_to_value(value: Basis) -> Dictionary:
	return {
		"x": _vector_to_value(value.x),
		"y": _vector_to_value(value.y),
		"z": _vector_to_value(value.z),
	}


static func _transform_to_value(value: Transform3D) -> Dictionary:
	return {
		"basis": [
			_vector_to_value(value.basis.x),
			_vector_to_value(value.basis.y),
			_vector_to_value(value.basis.z),
		],
		"origin": _vector_to_value(value.origin),
	}


static func _basis_is_finite(value: Basis) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()


static func _transform_is_finite(value: Transform3D) -> bool:
	return _basis_is_finite(value.basis) and value.origin.is_finite()
