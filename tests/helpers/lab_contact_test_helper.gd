class_name LabContactTestHelper
extends RefCounted

const CapacityScript := preload(
	"res://scripts/lab/mechanics/contact_capacity.gd")
const CanonicalizerScript := preload(
	"res://scripts/lab/mechanics/contact_canonicalizer.gd")

const BODY_ID := "foot_body"
const RUN_ID := "br3-contact-core-run"
const CAPTURE_STREAM_ID := "br3-contact-core-stream"
const PROFILE_ID := "full_contacts_v2"
const ADAPTER_ID := "rigid_body_integrate_forces_v2"


static func canonical_frame(
		step: int,
		raw_contacts: Array,
		capture_epoch: int = -1) -> Dictionary:
	var built: Dictionary = CapacityScript.derive({
		"body_id": BODY_ID,
		"expected_simultaneous_raw_points": 4,
		"safety_margin_raw_points": 4,
	})
	assert(bool(built["ok"]), "contact test capacity must build")
	var observation: Dictionary = CapacityScript.observe(
		built["capacity"], raw_contacts.size())
	return CanonicalizerScript.canonicalize(
		raw_contacts,
		observation,
		frame_context(step, capture_epoch))


static func frame_context(
		step: int,
		capture_epoch: int = -1) -> Dictionary:
	return {
		"physics_step_id": step,
		"capture_epoch": step if capture_epoch < 0 else capture_epoch,
		"sample_phase": "integrate_callback",
		"run_id": RUN_ID,
		"capture_stream_id": CAPTURE_STREAM_ID,
		"observer_profile_id": PROFILE_ID,
		"observer_adapter_id": ADAPTER_ID,
		"body_id": BODY_ID,
	}


static func raw_contact(
		step: int,
		raw_index: int,
		point_world: Vector3,
		overrides: Dictionary = {}) -> Dictionary:
	var value := {
		"schema_version": "raw_contact_point_v2",
		"raw_contact_observation_id": "%s:%d:%d" % [
			BODY_ID, step, raw_index],
		"physics_step_id": step,
		"capture_epoch": step,
		"sample_phase": "integrate_callback",
		"run_id": RUN_ID,
		"capture_stream_id": CAPTURE_STREAM_ID,
		"observer_profile_id": PROFILE_ID,
		"observer_adapter_id": ADAPTER_ID,
		"observed_body_id": BODY_ID,
		"observed_creature_id": "creature_alpha",
		"observed_role": "foot_support",
		"observed_shape_index": 0,
		"observed_shape_semantic_id": "foot_pad_shape",
		"counterparty_kind": "environment",
		"counterparty_semantic_id": "lab_floor",
		"counterparty_creature_id": null,
		"counterparty_shape_index": 0,
		"counterparty_shape_semantic_id": "lab_floor_shape",
		"surface_layer": 1,
		"surface_tag": "lab_ground",
		"point_world": point_world,
		"normal_world": Vector3.UP,
		"normal_available": true,
		"impulse_world_ns": Vector3(0.0, 10.0, 0.0),
		"impulse_quality": "jolt_predicted_estimate",
		"relative_velocity_world_mps": Vector3.ZERO,
		"finite": true,
	}
	for key in overrides:
		value[key] = overrides[key]
	return value
