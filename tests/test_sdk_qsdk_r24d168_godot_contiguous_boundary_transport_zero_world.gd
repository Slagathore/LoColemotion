extends SceneTree
# gdlint: disable=max-line-length

## R168 live-transport qualification over synthetic values only. No Node,
## RID, model, world, native property read, native write, or solver step is
## created or executed. The worker repeats the exact R167 six-property and
## seventeen-refusal matrix against the GDScript implementation, then passes
## one resulting pair through the unchanged qualified R148 observer seam.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const TransportScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)
const DiscreteStagingRouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D168_GODOT_CONTIGUOUS_BOUNDARY_TRANSPORT_ZERO_WORLD "
const ATTEMPT_ID := "r24d168-zero-world-attempt"
const ARM_ID := "candidate_arm"
const MODEL_INSTANCE_ID := "synthetic-live-transport-model"
const SOLVER_STEP_S := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D168_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D168_SDK_INSTANTIATION_FAILED")

	var context := RouteScript.prepare_complete_energy_context_v15(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if (
		not bool(context.get("ok", false))
		or not RouteScript.rotation_aware_contiguous_boundary_transport_context_binding_exact_v1(
			sdk, context
		)
		or not bool(context.get("contiguous_boundary_transport_profile_selected", false))
		or (
			String(context.get("contiguous_boundary_transport_design_id", ""))
			!= TransportScript.TRANSPORT_DESIGN_ID
		)
		or (
			String(context.get("contiguous_boundary_transport_profile_id", ""))
			!= TransportScript.TRANSPORT_PROFILE_ID
		)
		or bool(context.get("legacy_aliased_boundary_transport_selected", true))
		or bool(context.get("physical_world_construction_authorized", true))
		or (
			String(context.get("physical_world_construction_blocked_by", ""))
			!= "QSDK-R24D168_ZERO_WORLD_ONLY"
		)
		or context.has("physical_world_construction_gate_id")
	):
		return _failure("QSDK_R24D168_CONTEXT_INVALID", context)

	var legacy_context := RouteScript.prepare_complete_energy_context_v11(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if (
		not bool(legacy_context.get("ok", false))
		or legacy_context.has("contiguous_boundary_transport_profile_selected")
		or legacy_context.has("contiguous_boundary_transport_design_id")
		or legacy_context.has("contiguous_boundary_transport_profile_id")
	):
		return _failure("QSDK_R24D168_PREDECESSOR_CONTEXT_CHANGED", legacy_context)

	var initializer_receipt := (
		TransportScript
		. build_initializer_boundary_v1(
			sdk,
			ATTEMPT_ID,
			ARM_ID,
			MODEL_INSTANCE_ID,
			"synthetic-initializer-event-0",
			_fixture_samples(0, false),
		)
	)
	var post_one_receipt := (
		TransportScript
		. build_completed_step_boundary_v1(
			sdk,
			ATTEMPT_ID,
			ARM_ID,
			MODEL_INSTANCE_ID,
			1,
			"synthetic-completed-event-1",
			_fixture_samples(1, true),
		)
	)
	var post_two_receipt := (
		TransportScript
		. build_completed_step_boundary_v1(
			sdk,
			ATTEMPT_ID,
			ARM_ID,
			MODEL_INSTANCE_ID,
			2,
			"synthetic-completed-event-2",
			_fixture_samples(2, true),
		)
	)
	if (
		not bool(initializer_receipt.get("ok", false))
		or not bool(post_one_receipt.get("ok", false))
		or not bool(post_two_receipt.get("ok", false))
	):
		return _failure(
			"QSDK_R24D168_BOUNDARY_FIXTURE_BUILD_FAILED",
			{
				"initializer": initializer_receipt,
				"post_one": post_one_receipt,
				"post_two": post_two_receipt,
			},
		)
	var initializer: Dictionary = initializer_receipt["boundary"]
	var post_one: Dictionary = post_one_receipt["boundary"]
	var post_two: Dictionary = post_two_receipt["boundary"]
	var initializer_digest_before := _sha256(sdk, initializer)
	var initialized := TransportScript.initialize_boundary_transport_state_v1(sdk, initializer)
	if not bool(initialized.get("ok", false)):
		return _failure("QSDK_R24D168_STATE_INITIALIZATION_FAILED", initialized)
	var state_zero: Dictionary = initialized["state"]
	var state_zero_digest_before := _sha256(sdk, state_zero)
	var advance_one := TransportScript.advance_boundary_transport_state_v1(
		sdk, state_zero, post_one
	)
	if not bool(advance_one.get("ok", false)):
		return _failure("QSDK_R24D168_FIRST_ADVANCE_FAILED", advance_one)
	var pair_one: Dictionary = advance_one["pair"]
	var state_one: Dictionary = advance_one["state_after"]
	var advance_two := TransportScript.advance_boundary_transport_state_v1(sdk, state_one, post_two)
	if not bool(advance_two.get("ok", false)):
		return _failure("QSDK_R24D168_SECOND_ADVANCE_FAILED", advance_two)
	var pair_two: Dictionary = advance_two["pair"]
	var state_two: Dictionary = advance_two["state_after"]

	var stationary_post_one := post_one.duplicate(true)
	stationary_post_one["source_event_id"] = "synthetic-stationary-event-1"
	for index in range(TransportScript.ORDERED_BODY_IDS.size()):
		var stationary_body: Dictionary = stationary_post_one["ordered_bodies"][index]
		var initializer_body: Dictionary = initializer["ordered_bodies"][index]
		stationary_body["position_world_m"] = initializer_body["position_world_m"]
		stationary_body["linear_velocity_world_m_s"] = (initializer_body["linear_velocity_world_m_s"])
	stationary_post_one = TransportScript.rehash_boundary_v1(sdk, stationary_post_one)
	var stationary_advance := TransportScript.advance_boundary_transport_state_v1(
		sdk, state_zero, stationary_post_one
	)
	if not bool(stationary_advance.get("ok", false)):
		return _failure("QSDK_R24D168_STATIONARY_DISTINCT_EVENT_FAILED", stationary_advance)
	var stationary_pair: Dictionary = stationary_advance["pair"]

	var positive_initializer := (
		int(state_zero.get("cached_boundary_sequence", -1)) == 0
		and int(state_zero.get("accepted_pair_count", -1)) == 0
		and int(state_zero.get("state_revision", -1)) == 0
	)
	var positive_contiguity := (
		(
			[int(pair_one.get("previous_sequence", -1)), int(pair_one.get("semantic_step", -1))]
			== [0, 1]
		)
		and (
			[int(pair_two.get("previous_sequence", -1)), int(pair_two.get("semantic_step", -1))]
			== [1, 2]
		)
	)
	var positive_cache_provenance := true
	for index in range(TransportScript.ORDERED_BODY_IDS.size()):
		var pair_two_body: Dictionary = pair_two["ordered_body_boundaries"][index]
		var post_one_body: Dictionary = post_one["ordered_bodies"][index]
		positive_cache_provenance = (
			positive_cache_provenance
			and pair_two_body["pre_position_world_m"] == post_one_body["position_world_m"]
			and (
				pair_two_body["pre_linear_velocity_world_m_s"]
				== post_one_body["linear_velocity_world_m_s"]
			)
		)
	var positive_exact_once := (
		int(pair_one.get("cache_advance_count", -1)) == 1
		and int(pair_two.get("cache_advance_count", -1)) == 1
		and int(state_two.get("accepted_pair_count", -1)) == 2
		and int(state_two.get("state_revision", -1)) == 2
	)
	var positive_input_immutability := (
		_sha256(sdk, initializer) == initializer_digest_before
		and _sha256(sdk, state_zero) == state_zero_digest_before
	)
	var positive_stationary_distinct_event := true
	for row_value in stationary_pair["ordered_body_boundaries"]:
		var row: Dictionary = row_value
		positive_stationary_distinct_event = (
			positive_stationary_distinct_event
			and row["pre_position_world_m"] == row["post_position_world_m"]
			and row["pre_linear_velocity_world_m_s"] == row["post_linear_velocity_world_m_s"]
		)
	var positive_properties := [
		positive_initializer,
		positive_contiguity,
		positive_cache_provenance,
		positive_exact_once,
		positive_input_immutability,
		positive_stationary_distinct_event,
	]
	if false in positive_properties:
		return _failure(
			"QSDK_R24D168_POSITIVE_PROPERTY_FAILED",
			{"positive_properties": positive_properties},
		)

	var observer_receipt := (
		DiscreteStagingRouteScript
		. measure_native_step_v1(
			1,
			0,
			SOLVER_STEP_S,
			(pair_one["ordered_body_boundaries"] as Array).duplicate(true),
			Vector3.ZERO,
		)
	)
	if not bool(observer_receipt.get("ok", false)):
		return _failure("QSDK_R24D168_R148_OBSERVER_COMPATIBILITY_FAILED", observer_receipt)

	var mutation_control_ids: Array = []
	var wrong_initializer := initializer.duplicate(true)
	wrong_initializer["boundary_sequence"] = 1
	for body_value in wrong_initializer["ordered_bodies"]:
		(body_value as Dictionary)["boundary_sequence"] = 1
	wrong_initializer = TransportScript.rehash_boundary_v1(sdk, wrong_initializer)
	if not _expect_initializer_refusal(
		sdk,
		wrong_initializer,
		"INITIALIZER_SEQUENCE",
		mutation_control_ids,
		"initializer_nonzero_sequence"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:initializer_nonzero_sequence")
	if not _expect_initializer_refusal(
		sdk, post_one, "BOUNDARY_SOURCE_KIND", mutation_control_ids, "initializer_wrong_source_kind"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:initializer_wrong_source_kind")

	var missing_body := post_one.duplicate(true)
	(missing_body["ordered_bodies"] as Array).pop_back()
	missing_body = TransportScript.rehash_boundary_v1(sdk, missing_body)
	if not _expect_advance_refusal(
		sdk, state_zero, missing_body, "BODY_COUNT", mutation_control_ids, "missing_body"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:missing_body")
	var nonfinite := post_one.duplicate(true)
	(nonfinite["ordered_bodies"][0] as Dictionary)["position_world_m"] = Vector3(NAN, 0.4, 0.0)
	if not _expect_advance_refusal(
		sdk, state_zero, nonfinite, "BODY_POSITION:0", mutation_control_ids, "nonfinite_body_value"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:nonfinite_body_value")
	if not _expect_advance_refusal(
		sdk, state_one, post_one, "SAME_SOURCE_EVENT", mutation_control_ids, "same_source_event"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:same_source_event")
	var duplicate := post_one.duplicate(true)
	duplicate["source_event_id"] = "synthetic-replayed-event-1"
	duplicate = TransportScript.rehash_boundary_v1(sdk, duplicate)
	if not _expect_advance_refusal(
		sdk, state_one, duplicate, "DUPLICATE_BOUNDARY", mutation_control_ids, "duplicate_sequence"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:duplicate_sequence")
	var stale := post_one.duplicate(true)
	stale["source_event_id"] = "synthetic-stale-event-1"
	stale = TransportScript.rehash_boundary_v1(sdk, stale)
	if not _expect_advance_refusal(
		sdk, state_two, stale, "STALE_BOUNDARY", mutation_control_ids, "stale_sequence"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:stale_sequence")
	if not _expect_advance_refusal(
		sdk, state_zero, post_two, "SKIPPED_BOUNDARY", mutation_control_ids, "skipped_sequence"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:skipped_sequence")
	var reordered := post_one.duplicate(true)
	var reordered_ids: Array = reordered["ordered_body_ids"]
	var reordered_bodies: Array = reordered["ordered_bodies"]
	var first_id: Variant = reordered_ids[0]
	reordered_ids[0] = reordered_ids[1]
	reordered_ids[1] = first_id
	var first_body: Variant = reordered_bodies[0]
	reordered_bodies[0] = reordered_bodies[1]
	reordered_bodies[1] = first_body
	reordered = TransportScript.rehash_boundary_v1(sdk, reordered)
	if not _expect_advance_refusal(
		sdk, state_zero, reordered, "ORDERED_BODY_IDS", mutation_control_ids, "reordered_bodies"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:reordered_bodies")
	for identity_control in [
		["arm_id", "crossed_arm"],
		["attempt_id", "crossed_attempt"],
		["model_instance_id", "crossed_model"],
	]:
		var identity_key := String(identity_control[0])
		var control_id := String(identity_control[1])
		var crossed := post_one.duplicate(true)
		crossed[identity_key] = "other-%s" % identity_key
		crossed = TransportScript.rehash_boundary_v1(sdk, crossed)
		if not _expect_advance_refusal(
			sdk,
			state_zero,
			crossed,
			"CROSSED_IDENTITY:%s" % identity_key,
			mutation_control_ids,
			control_id,
		):
			return _failure("QSDK_R24D168_REFUSAL_FAILED:%s" % control_id)
	var wrong_callback := post_one.duplicate(true)
	(wrong_callback["ordered_bodies"][3] as Dictionary)["callback_sequence"] = 2
	wrong_callback = TransportScript.rehash_boundary_v1(sdk, wrong_callback)
	if not _expect_advance_refusal(
		sdk,
		state_zero,
		wrong_callback,
		"CALLBACK_SEQUENCE:3",
		mutation_control_ids,
		"callback_sequence_mismatch"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:callback_sequence_mismatch")
	var outcome_derived := post_one.duplicate(true)
	outcome_derived["recovery_success"] = true
	outcome_derived = TransportScript.rehash_boundary_v1(sdk, outcome_derived)
	if not _expect_advance_refusal(
		sdk,
		state_zero,
		outcome_derived,
		"OUTCOME_DERIVED_INPUT",
		mutation_control_ids,
		"outcome_derived_input"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:outcome_derived_input")
	var mass_drift := post_one.duplicate(true)
	(mass_drift["ordered_bodies"][4] as Dictionary)["mass_kg"] = (
		float((mass_drift["ordered_bodies"][4] as Dictionary)["mass_kg"]) + 0.01
	)
	mass_drift = TransportScript.rehash_boundary_v1(sdk, mass_drift)
	if not _expect_advance_refusal(
		sdk, state_zero, mass_drift, "MASS_CONTINUITY:4", mutation_control_ids, "mass_drift"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:mass_drift")
	var corrupt_payload := post_one.duplicate(true)
	corrupt_payload["payload_sha256"] = "sha256:%s" % "0".repeat(64)
	if not _expect_advance_refusal(
		sdk,
		state_zero,
		corrupt_payload,
		"PAYLOAD_SHA256",
		mutation_control_ids,
		"payload_digest_mismatch"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:payload_digest_mismatch")
	var wrong_source := post_one.duplicate(true)
	wrong_source["source_kind"] = TransportScript.INITIALIZER_SOURCE_KIND
	wrong_source = TransportScript.rehash_boundary_v1(sdk, wrong_source)
	if not _expect_advance_refusal(
		sdk,
		state_zero,
		wrong_source,
		"BOUNDARY_SOURCE_KIND",
		mutation_control_ids,
		"completed_boundary_wrong_source_kind"
	):
		return _failure("QSDK_R24D168_REFUSAL_FAILED:completed_boundary_wrong_source_kind")

	var exact := (
		mutation_control_ids.size() == 17
		and (
			mutation_control_ids
			== [
				"initializer_nonzero_sequence",
				"initializer_wrong_source_kind",
				"missing_body",
				"nonfinite_body_value",
				"same_source_event",
				"duplicate_sequence",
				"stale_sequence",
				"skipped_sequence",
				"reordered_bodies",
				"crossed_arm",
				"crossed_attempt",
				"crossed_model",
				"callback_sequence_mismatch",
				"outcome_derived_input",
				"mass_drift",
				"payload_digest_mismatch",
				"completed_boundary_wrong_source_kind",
			]
		)
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d168_godot_contiguous_boundary_transport_zero_world_v1",
		"gate_id": "QSDK-R24D168",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D168_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_live_contiguous_boundary_transport_implementation",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_zero_world_implementation_qualification",
			"question_class": "development",
		},
		"question_class": "development",
		"transport_design_id": TransportScript.TRANSPORT_DESIGN_ID,
		"transport_profile_id": TransportScript.TRANSPORT_PROFILE_ID,
		"boundary_schema_version": TransportScript.BOUNDARY_SCHEMA,
		"state_schema_version": TransportScript.STATE_SCHEMA,
		"pair_schema_version": TransportScript.PAIR_SCHEMA,
		"ordered_body_count": TransportScript.ORDERED_BODY_IDS.size(),
		"initializer_boundary_sequence": 0,
		"accepted_sequence_pairs": [[0, 1], [1, 2]],
		"terminal_cached_boundary_sequence": int(state_two["cached_boundary_sequence"]),
		"terminal_accepted_pair_count": int(state_two["accepted_pair_count"]),
		"terminal_state_revision": int(state_two["state_revision"]),
		"successful_mapping_cache_advance_count_each": 1,
		"initializer_source_kind": TransportScript.INITIALIZER_SOURCE_KIND,
		"completed_step_source_kind": TransportScript.COMPLETED_STEP_SOURCE_KIND,
		"sequence_zero_initializer_consumed": true,
		"pre_values_from_cached_completed_boundary": true,
		"post_values_from_callback_coherent_completed_boundary": true,
		"successful_mapping_advances_cache_exactly_once": true,
		"cache_advance_occurs_only_after_complete_mapping": true,
		"rejected_transition_preserves_state": true,
		"source_event_payloads_content_addressed": true,
		"outcome_derived_input_permitted": false,
		"same_numeric_values_permitted_for_distinct_source_event": true,
		"r148_observer_equations_changed": false,
		"r148_observer_accepts_transport_pair": true,
		"legacy_r162_context_preserved": true,
		"physical_world_construction_blocked": true,
		"mutation_control_ids": mutation_control_ids,
		"positive_case_count": 6,
		"forced_failure_case_count": mutation_control_ids.size(),
		"rejection_state_unchanged_count": mutation_control_ids.size(),
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _fixture_samples(sequence: int, completed: bool) -> Array:
	var samples: Array = []
	for index in range(TransportScript.ORDERED_BODY_IDS.size()):
		var body_id := String(TransportScript.ORDERED_BODY_IDS[index])
		var sample := {
			"body_id": body_id,
			"body_index": index,
			"boundary_sequence": sequence,
			"position_world_m":
			Vector3(
				index * 0.1 + sequence * 0.001,
				0.4 + index * 0.01 + sequence * 0.002,
				-index * 0.05 + sequence * 0.003,
			),
			"linear_velocity_world_m_s":
			Vector3(
				sequence * 0.01,
				-sequence * 0.02,
				index * 0.001,
			),
			"mass_kg": 1.2 if body_id == "torso" else 0.44,
		}
		if completed:
			sample["callback_sequence"] = sequence
			sample["total_gravity_world_m_s2"] = Vector3(0.0, -9.8, 0.0)
			sample["solver_step_s"] = SOLVER_STEP_S
		samples.append(sample)
	return samples


static func _expect_initializer_refusal(
	sdk: Object,
	boundary: Dictionary,
	expected_code: String,
	mutation_control_ids: Array,
	control_id: String,
) -> bool:
	var before := _sha256(sdk, boundary)
	var receipt := TransportScript.initialize_boundary_transport_state_v1(sdk, boundary)
	var accepted := (
		not bool(receipt.get("ok", true))
		and String(receipt.get("failure_code", "")) == expected_code
		and not bool(receipt.get("pair_emitted", true))
		and int(receipt.get("cache_advance_count", -1)) == 0
		and _sha256(sdk, boundary) == before
		and _zero_world_refusal(receipt)
	)
	if accepted:
		mutation_control_ids.append(control_id)
	return accepted


static func _expect_advance_refusal(
	sdk: Object,
	state: Dictionary,
	boundary: Dictionary,
	expected_code: String,
	mutation_control_ids: Array,
	control_id: String,
) -> bool:
	var state_before := _sha256(sdk, state)
	var boundary_before := _sha256(sdk, boundary)
	var receipt := TransportScript.advance_boundary_transport_state_v1(sdk, state, boundary)
	var accepted := (
		not bool(receipt.get("ok", true))
		and String(receipt.get("failure_code", "")) == expected_code
		and not bool(receipt.get("pair_emitted", true))
		and int(receipt.get("cache_advance_count", -1)) == 0
		and _sha256(sdk, state) == state_before
		and _sha256(sdk, boundary) == boundary_before
		and _zero_world_refusal(receipt)
	)
	if accepted:
		mutation_control_ids.append(control_id)
	return accepted


static func _zero_world_refusal(value: Dictionary) -> bool:
	return (
		int(value.get("model_construction_count", -1)) == 0
		and int(value.get("native_readback_count", -1)) == 0
		and int(value.get("world_attempt_count", -1)) == 0
		and int(value.get("world_build_count", -1)) == 0
		and int(value.get("solver_step_count", -1)) == 0
		and not bool(value.get("physics_state_modified", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _sha256(sdk: Object, value: Variant) -> String:
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version":
		"sporespore_qsdk_r24d168_godot_contiguous_boundary_transport_zero_world_v1",
		"gate_id": "QSDK-R24D168",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"positive_case_count": 0,
		"forced_failure_case_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
