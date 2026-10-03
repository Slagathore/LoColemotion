class_name SporeGodotJoltRecoveryContiguousBoundaryTransportV1
extends RefCounted
# gdlint: disable=max-line-length

## Transactional transport for source-measured, contiguous body boundaries.
##
## The transport owns one cached completed boundary. Sequence zero is sampled
## while physics is inactive; every later boundary is assembled from the nine
## callback-coherent direct-body-state snapshots for one completed step. A
## successful advance returns a pair and a successor state, but never mutates
## the caller's state. The production route therefore commits the successor
## only after the unchanged R148 observer and mapping both accept the pair.

const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")

const GATE_ID := "QSDK-R24D168"
const TRANSPORT_DESIGN_ID := "godot_jolt_r24d167_contiguous_completed_step_boundary_transport_v1"
const TRANSPORT_PROFILE_ID := "godot_jolt_r24d168_live_contiguous_completed_step_boundary_transport_v1"
const BOUNDARY_SCHEMA := "sporespore_qsdk_r24d167_completed_body_boundary_set_v1"
const STATE_SCHEMA := "sporespore_qsdk_r24d167_boundary_transport_state_v1"
const PAIR_SCHEMA := "sporespore_qsdk_r24d167_contiguous_body_boundary_pair_v1"
const INITIALIZER_SOURCE_KIND := "inactive_physics_initializer_readback_v1"
const COMPLETED_STEP_SOURCE_KIND := "completed_step_direct_state_callback_v1"

const ORDERED_BODY_IDS := [
	"torso",
	"front_left_upper",
	"front_left_distal",
	"front_right_upper",
	"front_right_distal",
	"rear_left_upper",
	"rear_left_distal",
	"rear_right_upper",
	"rear_right_distal",
]

const BOUNDARY_KEYS := [
	"schema_version",
	"transport_design_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"boundary_sequence",
	"source_event_id",
	"source_kind",
	"physics_active",
	"source_measurement",
	"ordered_body_ids",
	"ordered_bodies",
	"mechanical_energy_change_used_as_input",
	"energy_balance_residual_used_as_input",
	"acceptance_threshold_used_as_input",
	"controller_or_behavior_result_used_as_input",
	"payload_sha256",
]
const INITIALIZER_BODY_KEYS := [
	"body_id",
	"body_index",
	"boundary_sequence",
	"position_world_m",
	"linear_velocity_world_m_s",
	"mass_kg",
]
const COMPLETED_BODY_KEYS := [
	"body_id",
	"body_index",
	"boundary_sequence",
	"position_world_m",
	"linear_velocity_world_m_s",
	"mass_kg",
	"callback_sequence",
	"total_gravity_world_m_s2",
	"solver_step_s",
]
const STATE_KEYS := [
	"schema_version",
	"transport_design_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"ordered_body_ids",
	"cached_completed_boundary",
	"cached_boundary_sequence",
	"accepted_pair_count",
	"state_revision",
]
const OUTCOME_DERIVED_KEYS := [
	"acceptance_threshold",
	"behavior_result",
	"energy_balance_residual_j",
	"physical_result",
	"recovery_success",
	"stable_stance_gate",
]


static func build_initializer_boundary_v1(
	sdk: Object,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
	source_event_id: String,
	ordered_body_samples: Array,
) -> Dictionary:
	return _build_boundary_v1(
		sdk,
		attempt_id,
		arm_id,
		model_instance_id,
		0,
		source_event_id,
		INITIALIZER_SOURCE_KIND,
		false,
		ordered_body_samples,
	)


static func build_completed_step_boundary_v1(
	sdk: Object,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
	boundary_sequence: int,
	source_event_id: String,
	ordered_body_samples: Array,
) -> Dictionary:
	return _build_boundary_v1(
		sdk,
		attempt_id,
		arm_id,
		model_instance_id,
		boundary_sequence,
		source_event_id,
		COMPLETED_STEP_SOURCE_KIND,
		true,
		ordered_body_samples,
	)


static func initialize_boundary_transport_state_v1(
	sdk: Object,
	initializer_boundary: Dictionary,
) -> Dictionary:
	var failure_code := _validate_boundary_v1(sdk, initializer_boundary, INITIALIZER_SOURCE_KIND)
	if not failure_code.is_empty():
		return _failure(failure_code)
	if int(initializer_boundary.get("boundary_sequence", -1)) != 0:
		return _failure("INITIALIZER_SEQUENCE")
	var state := {
		"schema_version": STATE_SCHEMA,
		"transport_design_id": TRANSPORT_DESIGN_ID,
		"attempt_id": String(initializer_boundary["attempt_id"]),
		"arm_id": String(initializer_boundary["arm_id"]),
		"model_instance_id": String(initializer_boundary["model_instance_id"]),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"cached_completed_boundary": initializer_boundary.duplicate(true),
		"cached_boundary_sequence": 0,
		"accepted_pair_count": 0,
		"state_revision": 0,
	}
	failure_code = _validate_state_v1(sdk, state)
	if not failure_code.is_empty():
		return _failure(failure_code)
	return {
		"schema_version": "sporespore_qsdk_r24d168_boundary_transport_initialization_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"state": state,
		"state_revision": 0,
		"cache_advance_count": 0,
		"source_measurement": true,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func advance_boundary_transport_state_v1(
	sdk: Object,
	state: Dictionary,
	completed_step_boundary: Dictionary,
) -> Dictionary:
	var failure_code := _validate_state_v1(sdk, state)
	if not failure_code.is_empty():
		return _failure(failure_code)
	failure_code = _validate_boundary_v1(sdk, completed_step_boundary, COMPLETED_STEP_SOURCE_KIND)
	if not failure_code.is_empty():
		return _failure(failure_code)
	for identity_key in ["attempt_id", "arm_id", "model_instance_id"]:
		if state.get(identity_key) != completed_step_boundary.get(identity_key):
			return _failure("CROSSED_IDENTITY:%s" % identity_key)

	var cached: Dictionary = state["cached_completed_boundary"]
	if String(completed_step_boundary["source_event_id"]) == String(cached["source_event_id"]):
		return _failure("SAME_SOURCE_EVENT")
	var cached_sequence := int(state["cached_boundary_sequence"])
	var current_sequence := int(completed_step_boundary["boundary_sequence"])
	if current_sequence == cached_sequence:
		return _failure("DUPLICATE_BOUNDARY")
	if current_sequence < cached_sequence:
		return _failure("STALE_BOUNDARY")
	if current_sequence > cached_sequence + 1:
		return _failure("SKIPPED_BOUNDARY")
	if current_sequence != cached_sequence + 1:
		return _failure("NONCONTIGUOUS_BOUNDARY")

	var cached_bodies: Array = cached["ordered_bodies"]
	var completed_bodies: Array = completed_step_boundary["ordered_bodies"]
	var paired_bodies: Array = []
	for index in range(ORDERED_BODY_IDS.size()):
		var before: Dictionary = cached_bodies[index]
		var after: Dictionary = completed_bodies[index]
		if before.get("body_id") != after.get("body_id"):
			return _failure("CROSSED_BODY:%d" % index)
		if float(before.get("mass_kg", NAN)) != float(after.get("mass_kg", NAN)):
			return _failure("MASS_CONTINUITY:%d" % index)
		(
			paired_bodies
			. append(
				{
					"body_id": String(before["body_id"]),
					"body_index": index,
					"pre_boundary_sequence": cached_sequence,
					"post_boundary_sequence": current_sequence,
					"pre_source_event_id": String(cached["source_event_id"]),
					"post_source_event_id": String(completed_step_boundary["source_event_id"]),
					"mass_kg": float(before["mass_kg"]),
					"pre_position_world_m": before["position_world_m"],
					"post_position_world_m": after["position_world_m"],
					"pre_linear_velocity_world_m_s": before["linear_velocity_world_m_s"],
					"post_linear_velocity_world_m_s": after["linear_velocity_world_m_s"],
					"total_gravity_world_m_s2": after["total_gravity_world_m_s2"],
					"solver_step_s": float(after["solver_step_s"]),
					"pre_source_measurement": true,
					"post_source_measurement": true,
				}
			)
		)

	var pair := {
		"schema_version": PAIR_SCHEMA,
		"transport_design_id": TRANSPORT_DESIGN_ID,
		"transport_profile_id": TRANSPORT_PROFILE_ID,
		"attempt_id": String(state["attempt_id"]),
		"arm_id": String(state["arm_id"]),
		"model_instance_id": String(state["model_instance_id"]),
		"semantic_step": current_sequence,
		"previous_sequence": cached_sequence,
		"pre_source_kind": String(cached["source_kind"]),
		"post_source_kind": String(completed_step_boundary["source_kind"]),
		"pre_source_event_id": String(cached["source_event_id"]),
		"post_source_event_id": String(completed_step_boundary["source_event_id"]),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"ordered_body_boundaries": paired_bodies,
		"cache_advance_count": 1,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"controller_or_behavior_result_used_as_input": false,
	}
	var successor_state := {
		"schema_version": STATE_SCHEMA,
		"transport_design_id": TRANSPORT_DESIGN_ID,
		"attempt_id": String(state["attempt_id"]),
		"arm_id": String(state["arm_id"]),
		"model_instance_id": String(state["model_instance_id"]),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"cached_completed_boundary": completed_step_boundary.duplicate(true),
		"cached_boundary_sequence": current_sequence,
		"accepted_pair_count": int(state["accepted_pair_count"]) + 1,
		"state_revision": int(state["state_revision"]) + 1,
	}
	failure_code = _validate_state_v1(sdk, successor_state)
	if not failure_code.is_empty():
		return _failure(failure_code)
	return {
		"schema_version": "sporespore_qsdk_r24d168_boundary_transport_advance_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"pair": pair,
		"state_after": successor_state,
		"cache_advance_count": 1,
		"pair_emitted": true,
		"input_state_mutated": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func rehash_boundary_v1(sdk: Object, boundary: Dictionary) -> Dictionary:
	var value := boundary.duplicate(true)
	value["payload_sha256"] = _payload_sha256_v1(sdk, value)
	return value


static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	return _validate_state_v1(sdk, state).is_empty()


static func boundary_valid_v1(
	sdk: Object,
	boundary: Dictionary,
	expected_source_kind: String,
) -> bool:
	return _validate_boundary_v1(sdk, boundary, expected_source_kind).is_empty()


static func _build_boundary_v1(
	sdk: Object,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
	boundary_sequence: int,
	source_event_id: String,
	source_kind: String,
	physics_active: bool,
	ordered_body_samples: Array,
) -> Dictionary:
	if sdk == null:
		return _failure("SDK_MISSING")
	var boundary := {
		"schema_version": BOUNDARY_SCHEMA,
		"transport_design_id": TRANSPORT_DESIGN_ID,
		"attempt_id": attempt_id,
		"arm_id": arm_id,
		"model_instance_id": model_instance_id,
		"boundary_sequence": boundary_sequence,
		"source_event_id": source_event_id,
		"source_kind": source_kind,
		"physics_active": physics_active,
		"source_measurement": true,
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"ordered_bodies": ordered_body_samples.duplicate(true),
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"controller_or_behavior_result_used_as_input": false,
		"payload_sha256": "",
	}
	boundary["payload_sha256"] = _payload_sha256_v1(sdk, boundary)
	var failure_code := _validate_boundary_v1(sdk, boundary, source_kind)
	if not failure_code.is_empty():
		return _failure(failure_code)
	return {
		"schema_version": "sporespore_qsdk_r24d168_boundary_build_receipt_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"boundary": boundary,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _validate_boundary_v1(
	sdk: Object,
	boundary: Dictionary,
	expected_source_kind: String,
) -> String:
	if sdk == null:
		return "SDK_MISSING"
	for key in OUTCOME_DERIVED_KEYS:
		if boundary.has(key):
			return "OUTCOME_DERIVED_INPUT"
	if not _keys_exact_v1(boundary, BOUNDARY_KEYS):
		return "BOUNDARY_KEYS"
	if String(boundary.get("schema_version", "")) != BOUNDARY_SCHEMA:
		return "BOUNDARY_SCHEMA"
	if String(boundary.get("transport_design_id", "")) != TRANSPORT_DESIGN_ID:
		return "TRANSPORT_DESIGN_ID"
	for key in ["attempt_id", "arm_id", "model_instance_id", "source_event_id"]:
		if typeof(boundary.get(key)) != TYPE_STRING or String(boundary.get(key)).is_empty():
			return "IDENTITY:%s" % key
	if typeof(boundary.get("boundary_sequence")) != TYPE_INT:
		return "BOUNDARY_SEQUENCE_TYPE"
	var sequence := int(boundary["boundary_sequence"])
	if sequence < 0:
		return "BOUNDARY_SEQUENCE_TYPE"
	if String(boundary.get("source_kind", "")) != expected_source_kind:
		return "BOUNDARY_SOURCE_KIND"
	if boundary.get("source_measurement") != true:
		return "SOURCE_MEASUREMENT"
	var expected_physics_active := expected_source_kind == COMPLETED_STEP_SOURCE_KIND
	if boundary.get("physics_active") != expected_physics_active:
		return "BOUNDARY_PHYSICS_ACTIVE"
	for key in [
		"mechanical_energy_change_used_as_input",
		"energy_balance_residual_used_as_input",
		"acceptance_threshold_used_as_input",
		"controller_or_behavior_result_used_as_input",
	]:
		if boundary.get(key) != false:
			return "OUTCOME_INDEPENDENCE:%s" % key
	if boundary.get("ordered_body_ids") != ORDERED_BODY_IDS:
		return "ORDERED_BODY_IDS"
	var bodies_value: Variant = boundary.get("ordered_bodies")
	if not (bodies_value is Array) or (bodies_value as Array).size() != ORDERED_BODY_IDS.size():
		return "BODY_COUNT"
	var bodies: Array = bodies_value
	var expected_body_keys := (
		INITIALIZER_BODY_KEYS
		if expected_source_kind == INITIALIZER_SOURCE_KIND
		else COMPLETED_BODY_KEYS
	)
	for index in range(ORDERED_BODY_IDS.size()):
		var body_value: Variant = bodies[index]
		if not (body_value is Dictionary):
			return "BODY_SHAPE:%d" % index
		var body: Dictionary = body_value
		for key in OUTCOME_DERIVED_KEYS:
			if body.has(key):
				return "OUTCOME_DERIVED_BODY_INPUT:%d" % index
		if not _keys_exact_v1(body, expected_body_keys):
			return "BODY_KEYS:%d" % index
		if String(body.get("body_id", "")) != String(ORDERED_BODY_IDS[index]):
			return "BODY_ID:%d" % index
		if typeof(body.get("body_index")) != TYPE_INT or int(body["body_index"]) != index:
			return "BODY_INDEX:%d" % index
		if (
			typeof(body.get("boundary_sequence")) != TYPE_INT
			or int(body["boundary_sequence"]) != sequence
		):
			return "BODY_SEQUENCE:%d" % index
		var position_value: Variant = body.get("position_world_m")
		var velocity_value: Variant = body.get("linear_velocity_world_m_s")
		if not (position_value is Vector3) or not (position_value as Vector3).is_finite():
			return "BODY_POSITION:%d" % index
		if not (velocity_value is Vector3) or not (velocity_value as Vector3).is_finite():
			return "BODY_VELOCITY:%d" % index
		if typeof(body.get("mass_kg")) not in [TYPE_FLOAT, TYPE_INT]:
			return "BODY_MASS:%d" % index
		var mass_kg := float(body["mass_kg"])
		if not is_finite(mass_kg) or mass_kg <= 0.0:
			return "BODY_MASS:%d" % index
		if expected_source_kind == COMPLETED_STEP_SOURCE_KIND:
			if (
				typeof(body.get("callback_sequence")) != TYPE_INT
				or int(body["callback_sequence"]) != sequence
			):
				return "CALLBACK_SEQUENCE:%d" % index
			var gravity_value: Variant = body.get("total_gravity_world_m_s2")
			if not (gravity_value is Vector3) or not (gravity_value as Vector3).is_finite():
				return "BODY_GRAVITY:%d" % index
			if typeof(body.get("solver_step_s")) not in [TYPE_FLOAT, TYPE_INT]:
				return "SOLVER_STEP:%d" % index
			var solver_step_s := float(body["solver_step_s"])
			if not is_finite(solver_step_s) or solver_step_s <= 0.0:
				return "SOLVER_STEP:%d" % index
	if String(boundary.get("payload_sha256", "")) != _payload_sha256_v1(sdk, boundary):
		return "PAYLOAD_SHA256"
	return ""


static func _validate_state_v1(sdk: Object, state: Dictionary) -> String:
	if not _keys_exact_v1(state, STATE_KEYS):
		return "STATE_KEYS"
	if String(state.get("schema_version", "")) != STATE_SCHEMA:
		return "STATE_SCHEMA"
	if String(state.get("transport_design_id", "")) != TRANSPORT_DESIGN_ID:
		return "STATE_DESIGN_ID"
	if state.get("ordered_body_ids") != ORDERED_BODY_IDS:
		return "STATE_BODY_IDS"
	if typeof(state.get("cached_boundary_sequence")) != TYPE_INT:
		return "STATE_SEQUENCE"
	var sequence := int(state["cached_boundary_sequence"])
	if sequence < 0:
		return "STATE_SEQUENCE"
	if (
		typeof(state.get("accepted_pair_count")) != TYPE_INT
		or int(state["accepted_pair_count"]) != sequence
	):
		return "STATE_PAIR_COUNT"
	if typeof(state.get("state_revision")) != TYPE_INT or int(state["state_revision"]) != sequence:
		return "STATE_REVISION"
	var cached_value: Variant = state.get("cached_completed_boundary")
	if not (cached_value is Dictionary):
		return "STATE_CACHED_BOUNDARY"
	var expected_kind := INITIALIZER_SOURCE_KIND if sequence == 0 else COMPLETED_STEP_SOURCE_KIND
	var failure_code := _validate_boundary_v1(sdk, cached_value, expected_kind)
	if not failure_code.is_empty():
		return failure_code
	var cached: Dictionary = cached_value
	if int(cached.get("boundary_sequence", -1)) != sequence:
		return "STATE_CACHED_SEQUENCE"
	for key in ["attempt_id", "arm_id", "model_instance_id"]:
		if state.get(key) != cached.get(key):
			return "STATE_CACHED_IDENTITY:%s" % key
	return ""


static func _payload_sha256_v1(sdk: Object, boundary: Dictionary) -> String:
	if sdk == null:
		return ""
	var payload := boundary.duplicate(true)
	payload.erase("payload_sha256")
	var bodies_value: Variant = payload.get("ordered_bodies")
	if bodies_value is Array:
		for body_value in bodies_value:
			if not (body_value is Dictionary):
				continue
			var body: Dictionary = body_value
			for vector_key in [
				"position_world_m",
				"linear_velocity_world_m_s",
				"total_gravity_world_m_s2",
			]:
				var vector_value: Variant = body.get(vector_key)
				if vector_value is Vector3:
					var vector: Vector3 = vector_value
					body[vector_key] = [vector.x, vector.y, vector.z]
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, payload)
	var digest := String(receipt.get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _digest_valid_v1(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d168_boundary_transport_failure_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"pair_emitted": false,
		"cache_advance_count": 0,
		"input_state_mutated": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
