extends SceneTree

## BR3A live adapter/pipeline oracle.
##
## This is the bridge between the pure semantic contracts and Jolt. One real
## falling box is observed through raw_contact_point_v2, capacity-checked,
## canonicalized, lifetime-tracked, ground-qualified, support-classified, and
## evaluated geometrically. Legacy contact-v1 records remain available in
## parallel and are not reinterpreted as the v2 stream.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const ContactCapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")
const CanonicalizerScript := preload(
	"res://scripts/lab/mechanics/contact_canonicalizer.gd")
const LifetimeTrackerScript := preload(
	"res://scripts/lab/mechanics/contact_lifetime_tracker.gd")
const GroundQualifierScript := preload(
	"res://scripts/lab/mechanics/ground_qualifier.gd")
const SupportStateScript := preload(
	"res://scripts/lab/mechanics/contact_support_state.gd")
const SupportGeometryScript := preload(
	"res://scripts/lab/mechanics/support_geometry.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const CAPTURE_FRAME_COUNT := 75
const POINT_TOLERANCE_M := 0.05
const RECONSTRUCTION_TOLERANCE_M := 1.0e-6

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== BR3A live raw-contact v2 to support pipeline ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var clock = CaptureClockScript.new()
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile["executable"])
		and String(profile["contact_cap_mode"]) == "fixture_derived_v1"
		and int(profile["contact_cap_per_body"]) == 0,
		"append-only v2 profile requires fixture-derived capacity")

	var rig: Dictionary = RigFactoryScript.build(
		&"box_drop_contact_v1", clock, profile)
	_check(bool(rig.get("ok", false))
		and int(rig.get("contact_cap_per_body", 0)) == 8,
		"box fixture derives a preregistered 4 + 4 raw-point capacity")
	if not bool(rig.get("ok", false)):
		printerr(rig)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return

	var world := rig["world"] as Node3D
	var body = rig["body"]
	var floor := rig["floor"] as StaticBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var canonical_frames: Array[Dictionary] = []
	var raw_frames: Array = []
	var body_frames: Array[Dictionary] = []
	var lifetime_frames: Array[Dictionary] = []
	var tracker = LifetimeTrackerScript.new()
	var all_frames_canonical := true
	var all_capacity_complete := true
	var legacy_parallel_count_match := true
	var peak_raw_count := 0
	for frame_id in CAPTURE_FRAME_COUNT:
		clock.open_epoch(
			frame_id,
			float(frame_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		var raw_contacts: Array = body.latest_contacts_v2
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var observation: Dictionary = diagnostics.get("observation", {})
		var context := {
			"physics_step_id": frame_id,
			"capture_epoch": frame_id,
			"sample_phase": "integrate_callback",
			"run_id": String(rig["run_id"]),
			"capture_stream_id": String(rig["capture_stream_id"]),
			"observer_profile_id": "full_contacts_v2",
			"observer_adapter_id": "rigid_body_integrate_forces_v2",
			"body_id": String(rig["body_id"]),
		}
		var canonical: Dictionary = CanonicalizerScript.canonicalize(
			raw_contacts, observation, context)
		all_frames_canonical = bool(canonical.get("ok", false)) \
			and all_frames_canonical
		all_capacity_complete = (
			bool(observation.get("finite", false))
			and not bool(observation.get("saturated_ever", true))
			and all_capacity_complete)
		legacy_parallel_count_match = (
			(body.latest_contacts as Array).size() == raw_contacts.size()
			and legacy_parallel_count_match)
		peak_raw_count = maxi(peak_raw_count, raw_contacts.size())
		raw_frames.append(raw_contacts.duplicate(true))
		body_frames.append(body.latest_body_sample.duplicate(true))
		canonical_frames.append(canonical)
		var lifetime: Dictionary = (
			tracker.initialize(canonical)
			if frame_id == 0
			else tracker.advance(canonical))
		lifetime_frames.append(lifetime)

	_check(all_frames_canonical,
		"every real callback frame capacity-checks and canonicalizes")
	_check(all_capacity_complete
		and peak_raw_count > 0
		and peak_raw_count < int(rig["contact_cap_per_body"]),
		"run-wide raw evidence stays below the derived truncation boundary "
			+ "(peak %d, cap %d)" % [
				peak_raw_count, int(rig["contact_cap_per_body"])])
	_check(legacy_parallel_count_match,
		"v2 is append-only beside the unchanged legacy contact-v1 projection")

	var first_contact_frame := _first_contact_frame(canonical_frames)
	_check(first_contact_frame >= 0,
		"the live v2 stream observes the real box-floor impact")
	if first_contact_frame < 0:
		world.queue_free()
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return

	var precontact_is_empty := true
	for frame_id in first_contact_frame:
		precontact_is_empty = (
			(raw_frames[frame_id] as Array).is_empty()
			and int(canonical_frames[frame_id]["canonical_patch_count"]) == 0
			and precontact_is_empty)
	_check(precontact_is_empty,
		"airborne and near-ground frames never manufacture semantic contact")

	var first_raw: Array = raw_frames[first_contact_frame]
	var semantic_identity_valid := not first_raw.is_empty()
	var position_frame_valid := not first_raw.is_empty()
	var body_transform := _value_to_transform(
		body_frames[first_contact_frame].get("transform", {}))
	for raw_value in first_raw:
		var raw: Dictionary = raw_value
		semantic_identity_valid = (
			String(raw.get("observed_creature_id", ""))
				== String(rig["creature_id"])
			and String(raw.get("observed_shape_semantic_id", ""))
				== "drop_box_shape"
			and String(raw.get("counterparty_semantic_id", ""))
				== String(rig["floor_id"])
			and String(raw.get(
				"counterparty_shape_semantic_id", ""))
				== "lab_floor_shape"
			and int(raw.get("counterparty_runtime_instance_id", -1))
				== floor.get_instance_id()
			and semantic_identity_valid)
		var point_world: Vector3 = raw.get("point_world", Vector3.INF)
		var point_local: Vector3 = raw.get(
			"point_body_local", Vector3.INF)
		var other_point: Vector3 = raw.get(
			"other_point_world", Vector3.INF)
		position_frame_valid = (
			point_world.is_finite()
			and point_local.is_finite()
			and other_point.is_finite()
			and absf(point_world.y - float(rig["floor_top_y_m"]))
				<= POINT_TOLERANCE_M
			and absf(other_point.y - float(rig["floor_top_y_m"]))
				<= POINT_TOLERANCE_M
			and (body_transform * point_local).distance_to(point_world)
				<= RECONSTRUCTION_TOLERANCE_M
			and position_frame_valid)
	_check(semantic_identity_valid,
		"runtime collider IDs are diagnostics while authored body/shape IDs are stable")
	_check(position_frame_valid,
		"raw v2 world, collider, and body-local contact points share the declared frames")

	var first_patch: Dictionary = canonical_frames[
		first_contact_frame]["patches"][0]
	var first_patch_id := String(first_patch["contact_patch_id"])
	var consecutive_patch_ids_stable := true
	var persistent_contact_frames := 0
	for frame_id in range(
			first_contact_frame, canonical_frames.size()):
		var patches: Array = canonical_frames[frame_id]["patches"]
		if patches.is_empty():
			break
		persistent_contact_frames += 1
		consecutive_patch_ids_stable = (
			patches.size() == 1
			and String((patches[0] as Dictionary)["contact_patch_id"])
				== first_patch_id
			and consecutive_patch_ids_stable)
	_check(consecutive_patch_ids_stable and persistent_contact_frames >= 4,
		"semantic patch identity persists across Jolt manifold callback rebuilds")

	var first_lifetime_events: Array = lifetime_frames[
		first_contact_frame]["events"]
	var next_lifetime_events: Array = lifetime_frames[
		first_contact_frame + 1]["events"]
	_check(_has_event(first_lifetime_events, first_patch_id, "BEGIN")
		and _has_event(next_lifetime_events, first_patch_id, "PERSIST"),
		"lifetime begins on the first real contact frame and persists exactly once per tick")

	var runtime_id_tamper_raw: Array = first_raw.duplicate(true)
	for raw_value in runtime_id_tamper_raw:
		(raw_value as Dictionary)["counterparty_runtime_instance_id"] = 999999
	# Use a matching first-frame capacity observation: the last-frame diagnostic
	# carries a different observed count, so recompute from the frozen capacity.
	var first_capacity: Dictionary = ContactCapacityScript.observe(
		rig["contact_capacity"], first_raw.size())
	var runtime_id_tamper: Dictionary = CanonicalizerScript.canonicalize(
		runtime_id_tamper_raw,
		first_capacity,
		{
			"physics_step_id": first_contact_frame,
			"capture_epoch": first_contact_frame,
			"sample_phase": "integrate_callback",
			"run_id": String(rig["run_id"]),
			"capture_stream_id": String(rig["capture_stream_id"]),
			"observer_profile_id": "full_contacts_v2",
			"observer_adapter_id": "rigid_body_integrate_forces_v2",
			"body_id": String(rig["body_id"]),
		})
	_check(bool(runtime_id_tamper["ok"])
		and String(runtime_id_tamper["patches"][0]["contact_patch_id"])
			== first_patch_id,
		"runtime instance ID cannot contaminate canonical patch identity")

	var ground_built: Dictionary = GroundQualifierScript.build_config({
		"allowed_roles": [String(rig["support_role"])],
		"allowed_surface_layers": [1],
		"allowed_surface_tags": ["lab_ground"],
		"up_world": Vector3.UP,
		"minimum_up_dot": 0.8,
	})
	var ground_config: Dictionary = ground_built["config"]
	var support_built: Dictionary = SupportStateScript.build_config({
		"support_id": "drop_box_support",
		"sample_phase": "integrate_callback",
		"ground_qualifier_config_digest_sha256": String(
			ground_config["config_digest_sha256"]),
		"contact_confirm_ticks": 2,
		"bearing_confirm_ticks": 2,
		"bearing_enter_load_n": 15.0,
		"bearing_exit_load_n": 8.0,
		"unloaded_load_n": 2.0,
		"maximum_separating_speed_mps": 0.5,
	})
	var support_config: Dictionary = support_built["config"]
	var support_states: Array[String] = []
	var support_finite := true
	var support_result: Dictionary = {}
	for frame_id in range(
			first_contact_frame,
			mini(first_contact_frame + 8, canonical_frames.size())):
		var patches: Array = canonical_frames[frame_id]["patches"]
		if patches.is_empty():
			break
		var patch: Dictionary = patches[0]
		var observation := _support_observation(
			patch, ground_config, step_s)
		support_result = (
			SupportStateScript.initialize(support_config, observation)
			if support_states.is_empty()
			else SupportStateScript.advance(
				support_config, support_result, observation))
		support_states.append(String(support_result["support_state"]))
		support_finite = bool(support_result["finite"]) and support_finite
	_check(support_finite
		and not support_states.is_empty()
		and support_states[0] == "TOUCH"
		and support_states.has("LOAD")
		and support_states.has("BEARING"),
		"real predicted impulse and separation evidence produce TOUCH -> LOAD -> BEARING "
			+ str(support_states))

	var raw_points: Array = []
	for raw_value in first_raw:
		# Use the counterparty-side point for the declared floor plane. The
		# observed-body point legitimately carries solver penetration depth.
		raw_points.append((raw_value as Dictionary)["other_point_world"])
	var support_geometry: Dictionary = SupportGeometryScript.analyze(
		raw_points,
		Vector3(0.0, float(rig["floor_top_y_m"]), 0.0),
		Vector3.UP,
		Vector3.ZERO)
	print("  live_support_geometry kind=%s unique=%s hull=%s area=%s inside=%s reasons=%s" % [
		str(support_geometry.get("support_kind")),
		str(support_geometry.get("unique_point_count")),
		str(support_geometry.get("hull_point_count")),
		str(support_geometry.get("support_area_m2")),
		str(support_geometry.get("query_inside_support")),
		str(support_geometry.get("invalid_reasons")),
	])
	_check(bool(support_geometry["finite"])
		and int(support_geometry["support_dimension"]) == 2
		and bool(support_geometry["query_inside_support"])
		and float(support_geometry["support_area_m2"]) > 0.1,
		"the live four-point box manifold becomes a finite support polygon")

	world.queue_free()
	Engine.physics_ticks_per_second = original_ticks
	_finish()


static func _first_contact_frame(frames: Array[Dictionary]) -> int:
	for frame_id in frames.size():
		if int(frames[frame_id].get("canonical_patch_count", 0)) > 0:
			return frame_id
	return -1


static func _has_event(
		events: Array,
		patch_id: String,
		event_name: String) -> bool:
	for event_value in events:
		var event: Dictionary = event_value
		if String(event.get("contact_patch_id", "")) == patch_id \
				and String(event.get("event", "")) == event_name:
			return true
	return false


static func _support_observation(
		patch: Dictionary,
		ground_config: Dictionary,
		step_s: float) -> Dictionary:
	var qualification: Dictionary = GroundQualifierScript.qualify(
		patch, ground_config)
	return {
		"physics_step_id": int(patch["physics_step_id"]),
		"capture_epoch": int(patch["capture_epoch"]),
		"sample_phase": String(patch["sample_phase"]),
		"run_id": String(patch["run_id"]),
		"capture_stream_id": String(patch["capture_stream_id"]),
		"observer_profile_id": String(patch["observer_profile_id"]),
		"observer_adapter_id": String(patch["observer_adapter_id"]),
		"ground_qualification": qualification,
		"normal_load_available": true,
		"normal_load_n": maxf(
			float(patch["normal_impulse_ns"]) / step_s, 0.0),
		"normal_load_quality": "jolt_predicted_average_v1",
		"relative_separation_velocity_available": true,
		"relative_separation_velocity_mps": float(
			patch["relative_separation_velocity_mps"]),
		"relative_separation_velocity_quality":
			"canonical_patch_relative_velocity_v1",
	}


static func _value_to_transform(value: Variant) -> Transform3D:
	if not value is Dictionary:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	var transform_value: Dictionary = value
	var basis_value: Variant = transform_value.get("basis", [])
	if not basis_value is Array or basis_value.size() != 3:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	return Transform3D(
		Basis(
			_value_to_vector(basis_value[0]),
			_value_to_vector(basis_value[1]),
			_value_to_vector(basis_value[2])),
		_value_to_vector(transform_value.get("origin", [])))


static func _value_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.INF


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
