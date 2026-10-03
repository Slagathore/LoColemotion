class_name SporeGodotJoltRecoveryEpochBoundaryTransportV1
extends RefCounted
# gdlint: disable=max-line-length

## Offset-aware successor to the qualified R168 completed-boundary transport.
##
## R168 correctly owns a world-start sequence whose initializer is boundary
## zero. R10F begins a second, recovery-local ledger after the completed kick
## effect step E. This module consumes that already-measured R168 boundary
## without relabelling or rebuilding it, preserves every global callback
## sequence, and counts only pairs observed after E.

const QualifiedTransport := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")

const GATE_ID := "QSDK-R10F"
const EPOCH_CONTRACT_ID := "godot_jolt_r10f_completed_boundary_recovery_epoch_v1"
const TRANSPORT_DESIGN_ID := "godot_jolt_r10f_offset_completed_boundary_transport_v1"
const TRANSPORT_PROFILE_ID := "godot_jolt_r10f_live_offset_completed_boundary_transport_v1"
const STATE_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_boundary_transport_state_v1"
const PAIR_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_contiguous_body_boundary_pair_v1"
const INITIALIZATION_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_boundary_transport_initialization_v1"
const ADVANCE_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_boundary_transport_advance_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_boundary_transport_failure_v1"

const ORDERED_BODY_IDS := QualifiedTransport.ORDERED_BODY_IDS
const STATE_KEYS := [
	"schema_version",
	"epoch_contract_id",
	"transport_design_id",
	"transport_profile_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"ordered_body_ids",
	"epoch_start_global_step",
	"cached_global_boundary_step",
	"cached_completed_boundary",
	"cached_completed_boundary_sha256",
	"accepted_epoch_pair_count",
	"state_revision",
	"kick_interaction_receipt_sha256",
	"global_callback_sequence_preserved",
	"global_sequence_rewrite_permitted",
	"payload_sha256",
]
const OUTCOME_DERIVED_KEYS := [
	"acceptance_threshold",
	"behavior_result",
	"energy_balance_residual_j",
	"physical_result",
	"recovery_success",
	"stable_stance_gate",
]


static func initialize_epoch_transport_v1(
	sdk: Object,
	completed_epoch_boundary: Dictionary,
	kick_interaction_receipt_sha256: String,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_EPOCH_TRANSPORT_SDK_MISSING")
	if not (
		QualifiedTransport
		. boundary_valid_v1(
			sdk,
			completed_epoch_boundary,
			QualifiedTransport.COMPLETED_STEP_SOURCE_KIND,
		)
	):
		return _failure("QSDK_R10F_EPOCH_INITIAL_BOUNDARY_INVALID")
	var epoch_start_global_step := int(completed_epoch_boundary.get("boundary_sequence", -1))
	if epoch_start_global_step <= 0:
		return _failure("QSDK_R10F_EPOCH_START_GLOBAL_STEP_INVALID")
	if not _digest_valid_v1(kick_interaction_receipt_sha256):
		return _failure("QSDK_R10F_EPOCH_KICK_RECEIPT_DIGEST_INVALID")
	var state := {
		"schema_version": STATE_SCHEMA,
		"epoch_contract_id": EPOCH_CONTRACT_ID,
		"transport_design_id": TRANSPORT_DESIGN_ID,
		"transport_profile_id": TRANSPORT_PROFILE_ID,
		"attempt_id": String(completed_epoch_boundary["attempt_id"]),
		"arm_id": String(completed_epoch_boundary["arm_id"]),
		"model_instance_id": String(completed_epoch_boundary["model_instance_id"]),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"epoch_start_global_step": epoch_start_global_step,
		"cached_global_boundary_step": epoch_start_global_step,
		"cached_completed_boundary": completed_epoch_boundary.duplicate(true),
		"cached_completed_boundary_sha256": String(completed_epoch_boundary["payload_sha256"]),
		"accepted_epoch_pair_count": 0,
		"state_revision": 0,
		"kick_interaction_receipt_sha256": kick_interaction_receipt_sha256,
		"global_callback_sequence_preserved": true,
		"global_sequence_rewrite_permitted": false,
		"payload_sha256": "",
	}
	state["payload_sha256"] = _payload_sha256_v1(sdk, state)
	var failure_code := _validate_state_v1(sdk, state)
	if not failure_code.is_empty():
		return _failure(failure_code)
	return {
		"schema_version": INITIALIZATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"state": state,
		"epoch_start_global_step": epoch_start_global_step,
		"epoch_local_step": 0,
		"accepted_epoch_pair_count": 0,
		"state_revision": 0,
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


static func advance_epoch_transport_v1(
	sdk: Object,
	state: Dictionary,
	completed_step_boundary: Dictionary,
) -> Dictionary:
	var failure_code := _validate_state_v1(sdk, state)
	if not failure_code.is_empty():
		return _failure(failure_code)
	if not (
		QualifiedTransport
		. boundary_valid_v1(
			sdk,
			completed_step_boundary,
			QualifiedTransport.COMPLETED_STEP_SOURCE_KIND,
		)
	):
		return _failure("QSDK_R10F_EPOCH_COMPLETED_BOUNDARY_INVALID")
	for identity_key in ["attempt_id", "arm_id", "model_instance_id"]:
		if state.get(identity_key) != completed_step_boundary.get(identity_key):
			return _failure("QSDK_R10F_EPOCH_CROSSED_IDENTITY:%s" % identity_key)

	var cached: Dictionary = state["cached_completed_boundary"]
	if String(completed_step_boundary["source_event_id"]) == String(cached["source_event_id"]):
		return _failure("QSDK_R10F_EPOCH_SAME_SOURCE_EVENT")
	var cached_global_step := int(state["cached_global_boundary_step"])
	var current_global_step := int(completed_step_boundary["boundary_sequence"])
	if current_global_step == cached_global_step:
		return _failure("QSDK_R10F_EPOCH_DUPLICATE_GLOBAL_BOUNDARY")
	if current_global_step < cached_global_step:
		return _failure("QSDK_R10F_EPOCH_STALE_GLOBAL_BOUNDARY")
	if current_global_step > cached_global_step + 1:
		return _failure("QSDK_R10F_EPOCH_SKIPPED_GLOBAL_BOUNDARY")
	if current_global_step != cached_global_step + 1:
		return _failure("QSDK_R10F_EPOCH_NONCONTIGUOUS_GLOBAL_BOUNDARY")

	var epoch_start_global_step := int(state["epoch_start_global_step"])
	var previous_epoch_local_step := cached_global_step - epoch_start_global_step
	var current_epoch_local_step := current_global_step - epoch_start_global_step
	if (
		previous_epoch_local_step != int(state["accepted_epoch_pair_count"])
		or current_epoch_local_step != previous_epoch_local_step + 1
	):
		return _failure("QSDK_R10F_EPOCH_LOCAL_OFFSET_INVALID")

	var cached_bodies: Array = cached["ordered_bodies"]
	var completed_bodies: Array = completed_step_boundary["ordered_bodies"]
	var paired_bodies: Array = []
	for index in range(ORDERED_BODY_IDS.size()):
		var before: Dictionary = cached_bodies[index]
		var after: Dictionary = completed_bodies[index]
		if before.get("body_id") != after.get("body_id"):
			return _failure("QSDK_R10F_EPOCH_CROSSED_BODY:%d" % index)
		if float(before.get("mass_kg", NAN)) != float(after.get("mass_kg", NAN)):
			return _failure("QSDK_R10F_EPOCH_BODY_MASS_CONTINUITY:%d" % index)
		(
			paired_bodies
			. append(
				{
					"body_id": String(before["body_id"]),
					"body_index": index,
					"epoch_start_global_step": epoch_start_global_step,
					"pre_global_boundary_step": cached_global_step,
					"post_global_boundary_step": current_global_step,
					"pre_epoch_local_step": previous_epoch_local_step,
					"post_epoch_local_step": current_epoch_local_step,
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
		"epoch_contract_id": EPOCH_CONTRACT_ID,
		"transport_design_id": TRANSPORT_DESIGN_ID,
		"transport_profile_id": TRANSPORT_PROFILE_ID,
		"attempt_id": String(state["attempt_id"]),
		"arm_id": String(state["arm_id"]),
		"model_instance_id": String(state["model_instance_id"]),
		"epoch_start_global_step": epoch_start_global_step,
		"global_semantic_step": current_global_step,
		"previous_global_semantic_step": cached_global_step,
		"epoch_local_step": current_epoch_local_step,
		"previous_epoch_local_step": previous_epoch_local_step,
		"pre_source_kind": String(cached["source_kind"]),
		"post_source_kind": String(completed_step_boundary["source_kind"]),
		"pre_source_event_id": String(cached["source_event_id"]),
		"post_source_event_id": String(completed_step_boundary["source_event_id"]),
		"ordered_body_ids": ORDERED_BODY_IDS.duplicate(),
		"ordered_body_boundaries": paired_bodies,
		"kick_interaction_receipt_sha256": String(state["kick_interaction_receipt_sha256"]),
		"source_measurement": true,
		"global_callback_sequence_preserved": true,
		"global_sequence_rewrite_permitted": false,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"controller_or_behavior_result_used_as_input": false,
		"payload_sha256": "",
	}
	pair["payload_sha256"] = _payload_sha256_v1(sdk, pair)
	if not pair_valid_v1(sdk, pair):
		return _failure("QSDK_R10F_EPOCH_PAIR_INVALID")

	var successor_state := state.duplicate(true)
	successor_state["cached_global_boundary_step"] = current_global_step
	successor_state["cached_completed_boundary"] = completed_step_boundary.duplicate(true)
	successor_state["cached_completed_boundary_sha256"] = String(
		completed_step_boundary["payload_sha256"]
	)
	successor_state["accepted_epoch_pair_count"] = current_epoch_local_step
	successor_state["state_revision"] = current_epoch_local_step
	successor_state["payload_sha256"] = ""
	successor_state["payload_sha256"] = _payload_sha256_v1(sdk, successor_state)
	failure_code = _validate_state_v1(sdk, successor_state)
	if not failure_code.is_empty():
		return _failure(failure_code)
	return {
		"schema_version": ADVANCE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"pair": pair,
		"state_after": successor_state,
		"epoch_start_global_step": epoch_start_global_step,
		"global_semantic_step": current_global_step,
		"epoch_local_step": current_epoch_local_step,
		"pair_emitted": true,
		"cache_advance_count": 1,
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


static func state_valid_v1(sdk: Object, state: Dictionary) -> bool:
	return _validate_state_v1(sdk, state).is_empty()


static func pair_valid_v1(sdk: Object, pair: Dictionary) -> bool:
	if sdk == null or String(pair.get("schema_version", "")) != PAIR_SCHEMA:
		return false
	for key in OUTCOME_DERIVED_KEYS:
		if pair.has(key):
			return false
	var epoch_start := int(pair.get("epoch_start_global_step", -1))
	var global_step := int(pair.get("global_semantic_step", -1))
	var previous_global := int(pair.get("previous_global_semantic_step", -1))
	var local_step := int(pair.get("epoch_local_step", -1))
	var previous_local := int(pair.get("previous_epoch_local_step", -1))
	var bodies_value: Variant = pair.get("ordered_body_boundaries")
	if (
		String(pair.get("epoch_contract_id", "")) != EPOCH_CONTRACT_ID
		or String(pair.get("transport_design_id", "")) != TRANSPORT_DESIGN_ID
		or String(pair.get("transport_profile_id", "")) != TRANSPORT_PROFILE_ID
		or epoch_start <= 0
		or global_step != previous_global + 1
		or local_step != global_step - epoch_start
		or previous_local != previous_global - epoch_start
		or local_step != previous_local + 1
		or local_step <= 0
		or pair.get("ordered_body_ids") != ORDERED_BODY_IDS
		or not (bodies_value is Array)
		or (bodies_value as Array).size() != ORDERED_BODY_IDS.size()
		or not _digest_valid_v1(String(pair.get("kick_interaction_receipt_sha256", "")))
		or not bool(pair.get("source_measurement", false))
		or not bool(pair.get("global_callback_sequence_preserved", false))
		or bool(pair.get("global_sequence_rewrite_permitted", true))
	):
		return false
	for key in [
		"mechanical_energy_change_used_as_input",
		"energy_balance_residual_used_as_input",
		"acceptance_threshold_used_as_input",
		"controller_or_behavior_result_used_as_input",
	]:
		if bool(pair.get(key, true)):
			return false
	var bodies: Array = bodies_value
	for index in range(ORDERED_BODY_IDS.size()):
		var row_value: Variant = bodies[index]
		if not (row_value is Dictionary):
			return false
		var row: Dictionary = row_value
		if (
			String(row.get("body_id", "")) != String(ORDERED_BODY_IDS[index])
			or int(row.get("body_index", -1)) != index
			or int(row.get("epoch_start_global_step", -1)) != epoch_start
			or int(row.get("pre_global_boundary_step", -1)) != previous_global
			or int(row.get("post_global_boundary_step", -1)) != global_step
			or int(row.get("pre_epoch_local_step", -1)) != previous_local
			or int(row.get("post_epoch_local_step", -1)) != local_step
			or not bool(row.get("pre_source_measurement", false))
			or not bool(row.get("post_source_measurement", false))
		):
			return false
	return String(pair.get("payload_sha256", "")) == _payload_sha256_v1(sdk, pair)


static func _validate_state_v1(sdk: Object, state: Dictionary) -> String:
	if sdk == null:
		return "QSDK_R10F_EPOCH_TRANSPORT_SDK_MISSING"
	if not _keys_exact_v1(state, STATE_KEYS):
		return "QSDK_R10F_EPOCH_STATE_KEYS"
	if (
		String(state.get("schema_version", "")) != STATE_SCHEMA
		or String(state.get("epoch_contract_id", "")) != EPOCH_CONTRACT_ID
		or String(state.get("transport_design_id", "")) != TRANSPORT_DESIGN_ID
		or String(state.get("transport_profile_id", "")) != TRANSPORT_PROFILE_ID
		or state.get("ordered_body_ids") != ORDERED_BODY_IDS
	):
		return "QSDK_R10F_EPOCH_STATE_IDENTITY"
	for identity_key in ["attempt_id", "arm_id", "model_instance_id"]:
		if typeof(state.get(identity_key)) != TYPE_STRING or String(state[identity_key]).is_empty():
			return "QSDK_R10F_EPOCH_STATE_IDENTITY:%s" % identity_key
	var epoch_start := int(state.get("epoch_start_global_step", -1))
	var cached_global := int(state.get("cached_global_boundary_step", -1))
	var local_count := cached_global - epoch_start
	if (
		epoch_start <= 0
		or cached_global < epoch_start
		or int(state.get("accepted_epoch_pair_count", -1)) != local_count
		or int(state.get("state_revision", -1)) != local_count
	):
		return "QSDK_R10F_EPOCH_STATE_OFFSET"
	if (
		not _digest_valid_v1(String(state.get("kick_interaction_receipt_sha256", "")))
		or not bool(state.get("global_callback_sequence_preserved", false))
		or bool(state.get("global_sequence_rewrite_permitted", true))
	):
		return "QSDK_R10F_EPOCH_STATE_SEQUENCE_AUTHORITY"
	var cached_value: Variant = state.get("cached_completed_boundary")
	if not (cached_value is Dictionary):
		return "QSDK_R10F_EPOCH_STATE_CACHED_BOUNDARY"
	var cached: Dictionary = cached_value
	if not (
		QualifiedTransport
		. boundary_valid_v1(
			sdk,
			cached,
			QualifiedTransport.COMPLETED_STEP_SOURCE_KIND,
		)
	):
		return "QSDK_R10F_EPOCH_STATE_CACHED_BOUNDARY_INVALID"
	if (
		int(cached.get("boundary_sequence", -1)) != cached_global
		or (
			String(cached.get("payload_sha256", ""))
			!= String(state.get("cached_completed_boundary_sha256", ""))
		)
	):
		return "QSDK_R10F_EPOCH_STATE_CACHED_BOUNDARY_BINDING"
	for identity_key in ["attempt_id", "arm_id", "model_instance_id"]:
		if state.get(identity_key) != cached.get(identity_key):
			return "QSDK_R10F_EPOCH_STATE_CACHED_IDENTITY:%s" % identity_key
	if String(state.get("payload_sha256", "")) != _payload_sha256_v1(sdk, state):
		return "QSDK_R10F_EPOCH_STATE_PAYLOAD_SHA256"
	return ""


static func _payload_sha256_v1(sdk: Object, value: Dictionary) -> String:
	if sdk == null:
		return ""
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, _json_safe_v1(payload))
	var digest := String(receipt.get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _json_safe_v1(value: Variant) -> Variant:
	if value is Vector3:
		var vector: Vector3 = value
		return [vector.x, vector.y, vector.z]
	if value is Dictionary:
		var mapped: Dictionary = {}
		for key in (value as Dictionary).keys():
			mapped[key] = _json_safe_v1((value as Dictionary)[key])
		return mapped
	if value is Array:
		var mapped_array: Array = []
		for item in value:
			mapped_array.append(_json_safe_v1(item))
		return mapped_array
	return value


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
		"schema_version": FAILURE_SCHEMA,
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
