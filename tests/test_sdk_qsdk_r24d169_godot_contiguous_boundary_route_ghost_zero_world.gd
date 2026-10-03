extends SceneTree
# gdlint: disable=max-line-length

## R169 prospective route-ghost gate. It declares exactly one future
## non-held-out Godot/Jolt world and two completed steps, but executes only
## synthetic transport/context/portable-route checks here. No Node, RID,
## model, world, native read, body write, or solver step is created.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const TransportScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)
const StagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const R163Worker := preload(
	"res://tests/test_sdk_qsdk_r24d163_godot_rotation_aware_recovery_route_zero_world.gd"
)
const R168Worker := preload(
	"res://tests/test_sdk_qsdk_r24d168_godot_contiguous_boundary_transport_zero_world.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D169_GODOT_CONTIGUOUS_BOUNDARY_ROUTE_GHOST_ZERO_WORLD "
const GATE_ID := "QSDK-R24D169"
const ATTEMPT_ID := "r24d169-zero-world-attempt"
const ARM_ID := "route_ghost"
const MODEL_INSTANCE_ID := "r24d169-synthetic-route-ghost-model"
const SOLVER_STEP_S := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D169_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D169_SDK_INSTANTIATION_FAILED")

	var predecessor_context := RouteScript.prepare_complete_energy_context_v15(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var context := RouteScript.prepare_complete_energy_context_v16(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if (
		not bool(predecessor_context.get("ok", false))
		or not bool(context.get("ok", false))
		or not RouteScript.contiguous_boundary_transport_route_ghost_context_binding_exact_v1(
			sdk, context
		)
	):
		return _failure(
			"QSDK_R24D169_CONTEXT_INVALID",
			{"predecessor": predecessor_context, "context": context},
		)

	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	if not bool(blueprint.get("ok", false)):
		return _failure("QSDK_R24D169_BLUEPRINT_INVALID", blueprint)

	var transport := _transport_sequence_v1(sdk)
	if not bool(transport.get("ok", false)):
		return _failure("QSDK_R24D169_TRANSPORT_SEQUENCE_INVALID", transport)
	var pair_one: Dictionary = transport["pair_one"]
	var pair_two: Dictionary = transport["pair_two"]
	var observer := (
		StagingRoute
		. measure_native_step_v1(
			1,
			0,
			SOLVER_STEP_S,
			(pair_one["ordered_body_boundaries"] as Array).duplicate(true),
			Vector3.ZERO,
		)
	)
	if not bool(observer.get("ok", false)):
		return _failure("QSDK_R24D169_R148_OBSERVER_REJECTED", observer)
	var fixture := _rotation_aware_bound_fixture_v1(sdk, context, observer)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D169_BOUND_FIXTURE_INVALID", fixture)
	var bound: Dictionary = fixture["bound"]
	var route := RouteScript.collect_and_plan_v1(sdk, context, bound, "establish_distal_support", 0)
	if not bool(route.get("ok", false)):
		return _failure("QSDK_R24D169_PRODUCTION_ROUTE_INVALID", route)
	var collection: Dictionary = route["collection_receipt"]
	var control: Dictionary = route["control_receipt"]
	var mapping: Dictionary = bound["native_to_portable_staging_mapping"]

	var pair_two_predecessor_exact := true
	for index in range(TransportScript.ORDERED_BODY_IDS.size()):
		var row: Dictionary = pair_two["ordered_body_boundaries"][index]
		var post_one_body: Dictionary = transport["post_one"]["ordered_bodies"][index]
		pair_two_predecessor_exact = (
			pair_two_predecessor_exact
			and row["pre_position_world_m"] == post_one_body["position_world_m"]
			and (row["pre_linear_velocity_world_m_s"] == post_one_body["linear_velocity_world_m_s"])
		)

	var positive_checks := {
		"exact_r169_route_context":
		(
			String(context.get("physical_world_construction_gate_id", "")) == GATE_ID
			and bool(context.get("physical_world_construction_authorized", false))
			and bool(context.get("route_ghost_only", false))
			and not bool(context.get("recovery_behavior_evaluation_authorized", true))
		),
		"r168_predecessor_context_and_closure_bound":
		(
			(
				_sha256(sdk, predecessor_context)
				== String(context.get("r168_transport_context_sha256", ""))
			)
			and (
				String(context.get("r168_zero_world_closure_raw_sha256", ""))
				== RouteScript.R169_R168_ZERO_WORLD_CLOSURE_RAW_SHA256
			)
		),
		"production_blueprint_compiled_zero_world":
		(
			int(blueprint.get("model_construction_count", -1)) == 0
			and int(blueprint.get("world_attempt_count", -1)) == 0
			and int(blueprint.get("world_build_count", -1)) == 0
			and int(blueprint.get("solver_step_count", -1)) == 0
			and not bool(blueprint.get("physics_state_modified", true))
		),
		"inactive_initializer_and_two_contiguous_pairs":
		(
			int(transport["state_zero"].get("cached_boundary_sequence", -1)) == 0
			and (
				[int(pair_one.get("previous_sequence", -1)), int(pair_one.get("semantic_step", -1))]
				== [0, 1]
			)
			and (
				[int(pair_two.get("previous_sequence", -1)), int(pair_two.get("semantic_step", -1))]
				== [1, 2]
			)
		),
		"transactional_cache_reaches_revision_two":
		(
			int(transport["state_two"].get("cached_boundary_sequence", -1)) == 2
			and int(transport["state_two"].get("accepted_pair_count", -1)) == 2
			and int(transport["state_two"].get("state_revision", -1)) == 2
			and pair_two_predecessor_exact
		),
		"unchanged_r148_observer_accepts_contiguous_pair":
		(
			(
				String(observer.get("schema_version", ""))
				== "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_exchange_v1"
			)
			and int(observer.get("sequence", -1)) == 1
			and int(observer.get("previous_sequence", -1)) == 0
		),
		"rotation_aware_mapping_content_bound":
		(
			(
				String(mapping.get("schema_version", ""))
				== "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_step_mapping_v1"
			)
			and bool(mapping.get("rotation_integration_exchange_included_exactly_once", false))
			and _valid_sha256(
				String(mapping.get("rotation_aware_predecessor_energy_source_receipt_sha256", ""))
			)
			and _valid_sha256(
				String(
					mapping.get("rotation_aware_predecessor_source_component_receipts_sha256", "")
				)
			)
		),
		"production_portable_collection_and_control_exact":
		(
			String(collection.get("support_status", "")) == "supported_exact"
			and (
				String(collection.get("collector_id", ""))
				== RouteScript.R162_ROTATION_AWARE_COLLECTOR_ID
			)
			and String(control.get("support_status", "")) == "supported_exact"
			and int((control.get("ordered_commands", []) as Array).size()) == 8
			and _zero_world_receipt(route)
		),
	}

	var forced_failure_checks := {
		"wrong_gate_refused":
		_context_mutation_refused(
			sdk, context, "physical_world_construction_gate_id", "QSDK-R24D168"
		),
		"construction_authority_removed":
		_context_mutation_refused(sdk, context, "physical_world_construction_authorized", false),
		"r168_closure_digest_cross_refused":
		_context_mutation_refused(
			sdk,
			context,
			"r168_zero_world_closure_raw_sha256",
			"sha256:%s" % "0".repeat(64),
		),
		"r168_context_digest_cross_refused":
		_context_mutation_refused(
			sdk, context, "r168_transport_context_sha256", "sha256:%s" % "1".repeat(64)
		),
		"route_profile_cross_refused":
		_context_mutation_refused(
			sdk,
			context,
			"route_ghost_profile_id",
			RouteScript.R163_ROTATION_AWARE_ROUTE_GHOST_PROFILE_ID,
		),
		"route_ghost_only_removed":
		_context_mutation_refused(sdk, context, "route_ghost_only", false),
		"behavior_evaluation_authority_refused":
		_context_mutation_refused(sdk, context, "recovery_behavior_evaluation_authorized", true),
		"blocked_field_cross_refused":
		_context_mutation_refused(
			sdk, context, "physical_world_construction_blocked_by", "QSDK-R24D168_ZERO_WORLD_ONLY"
		),
		"transport_profile_cross_refused":
		_context_mutation_refused(
			sdk,
			context,
			"contiguous_boundary_transport_profile_id",
			RouteScript.R149_LIVE_BOUNDARY_TRANSPORT_ID,
		),
		"legacy_transport_selection_refused":
		_context_mutation_refused(sdk, context, "legacy_aliased_boundary_transport_selected", true),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d169_godot_contiguous_boundary_route_ghost_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D169_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_contiguous_boundary_production_route_ghost_declaration",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_smallest_contiguous_boundary_route_ghost_zero_world",
			"question_class": "development",
		},
		"question_class": "development",
		"physical_question_kind": "integration_ghost",
		"route_ghost_profile_id": RouteScript.R169_CONTIGUOUS_BOUNDARY_ROUTE_GHOST_PROFILE_ID,
		"transport_design_id": TransportScript.TRANSPORT_DESIGN_ID,
		"transport_profile_id": TransportScript.TRANSPORT_PROFILE_ID,
		"recovery_energy_ledger_profile_id":
		RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
		"world_count_if_separately_authorized": 1,
		"maximum_outer_solver_steps_if_separately_authorized": 2,
		"minimum_completed_solver_steps_for_valid_route": 2,
		"portable_collection_count_if_separately_authorized": 2,
		"portable_control_plan_count_if_separately_authorized": 2,
		"portable_command_application_count_if_separately_authorized": 1,
		"behavior_evaluator_invocation_count": 0,
		"production_collect_and_plan_invocation_count": 1,
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
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
		"physical_question_declared": true,
		"physical_question_opened": false,
		"physical_execution_authorized": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _transport_sequence_v1(sdk: Object) -> Dictionary:
	var initializer_receipt := (
		TransportScript
		. build_initializer_boundary_v1(
			sdk,
			ATTEMPT_ID,
			ARM_ID,
			MODEL_INSTANCE_ID,
			"r24d169-synthetic-initializer-0",
			R168Worker._fixture_samples(0, false),
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
			"r24d169-synthetic-completed-1",
			R168Worker._fixture_samples(1, true),
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
			"r24d169-synthetic-completed-2",
			R168Worker._fixture_samples(2, true),
		)
	)
	if (
		not bool(initializer_receipt.get("ok", false))
		or not bool(post_one_receipt.get("ok", false))
		or not bool(post_two_receipt.get("ok", false))
	):
		return {"ok": false, "failure_code": "R169_BOUNDARY_BUILD_FAILED"}
	var initialized := TransportScript.initialize_boundary_transport_state_v1(
		sdk, initializer_receipt["boundary"]
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var state_zero: Dictionary = initialized["state"]
	var advance_one := TransportScript.advance_boundary_transport_state_v1(
		sdk, state_zero, post_one_receipt["boundary"]
	)
	if not bool(advance_one.get("ok", false)):
		return advance_one
	var advance_two := TransportScript.advance_boundary_transport_state_v1(
		sdk, advance_one["state_after"], post_two_receipt["boundary"]
	)
	if not bool(advance_two.get("ok", false)):
		return advance_two
	return {
		"ok": true,
		"state_zero": state_zero,
		"post_one": post_one_receipt["boundary"],
		"post_two": post_two_receipt["boundary"],
		"pair_one": advance_one["pair"],
		"pair_two": advance_two["pair"],
		"state_two": advance_two["state_after"],
	}


static func _rotation_aware_bound_fixture_v1(
	sdk: Object,
	context: Dictionary,
	observer: Dictionary,
) -> Dictionary:
	var predecessor_fixture := RouteScript._zero_world_fixture_for_controller_v1(
		sdk, context, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if not bool(predecessor_fixture.get("ok", false)):
		return predecessor_fixture
	var sources := R163Worker._rotation_sources_v1(sdk, context, observer)
	if not bool(sources.get("ok", false)):
		return sources
	var observation_base: Dictionary = (
		(predecessor_fixture["observation_v2"] as Dictionary).duplicate(true)
	)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	observation_base["semantic_step"] = 1
	(observation_base["engine_step_identity"] as Dictionary)["semantic_step"] = 1
	(observation_base["engine_step_identity"] as Dictionary)["capability_sha256"] = String(
		context["capability_sha256"]
	)
	(observation_base["state"] as Dictionary)["adapter_capability_sha256"] = String(
		context["capability_sha256"]
	)
	var bound := (
		RouteScript
		. compose_discrete_staging_complete_energy_observations_v1(
			sdk,
			context,
			observation_base,
			sources["energy_source_receipt"],
			sources["source_component_receipts"],
			observer,
			StagingRoute.initial_accumulator_v1(),
		)
	)
	return {"ok": bool(bound.get("ok", false)), "bound": bound}


static func _context_mutation_refused(
	sdk: Object,
	context: Dictionary,
	key: String,
	value: Variant,
) -> bool:
	var mutation := context.duplicate(true)
	mutation[key] = value
	return not RouteScript.contiguous_boundary_transport_route_ghost_context_binding_exact_v1(
		sdk, mutation
	)


static func _zero_world_receipt(value: Dictionary) -> bool:
	return (
		int(value.get("model_construction_count", -1)) == 0
		and int(value.get("world_attempt_count", -1)) == 0
		and int(value.get("world_build_count", -1)) == 0
		and int(value.get("solver_step_count", -1)) == 0
		and not bool(value.get("physics_state_modified", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _sha256(sdk: Object, value: Variant) -> String:
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _valid_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version":
		"sporespore_qsdk_r24d169_godot_contiguous_boundary_route_ghost_zero_world_v1",
		"gate_id": GATE_ID,
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
		"physical_question_declared": true,
		"physical_question_opened": false,
		"physical_execution_authorized": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
