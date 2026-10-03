extends SceneTree

## Complete synthetic identity and mutation gate for the pure R148 observer.
## No node, model, world, native callback, or solver step is created here.

const Observer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_observer_v1.gd"
)
const StagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const ProfileScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
)
const RecoveryRuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const JsonTransport := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const MARKER := "QSDK_R24D148_GODOT_DISCRETE_STAGING_ZERO_WORLD "
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const AUTHORITY_PROFILE_PATH := (
	"res://sdk/recovery/r24d148_godot_jolt_discrete_staging_energy_authority_profile_v1.json"
)
const CLASS_NAME := "SporeLocomotionSdk"
const DT := 1.0 / 120.0
const MASS_KG := 4.72
const INITIAL_Y_M := 1.25
const GRAVITY_Y_M_S2 := -9.8
const CONTROL_OPERATION_BUDGET := 64
const NATIVE_FLOAT32_EPSILON := 1.1920928955078125e-7


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransport.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var fixtures := {
		"supported_rest": _fixture_v1(0.0, GRAVITY_Y_M_S2, true),
		"free_fall": _fixture_v1(0.0, GRAVITY_Y_M_S2, false),
		"upward_free_fall": _fixture_v1(2.5, GRAVITY_Y_M_S2, false),
		"downward_free_fall": _fixture_v1(-2.5, GRAVITY_Y_M_S2, false),
		"zero_gravity": _fixture_v1(1.25, 0.0, false),
	}
	var accepted: Dictionary = {}
	for fixture_id in fixtures:
		var fixture: Dictionary = fixtures[fixture_id]
		var measured := _measure_fixture_v1(fixture)
		if not bool(measured.get("ok", false)):
			return _failure("QSDK_R24D148_CONTROL_OBSERVER_REFUSED:%s" % fixture_id, measured)
		accepted[fixture_id] = measured
	var supported: Dictionary = accepted["supported_rest"]
	var free_fall: Dictionary = accepted["free_fall"]
	var upward: Dictionary = accepted["upward_free_fall"]
	var downward: Dictionary = accepted["downward_free_fall"]
	var zero_gravity: Dictionary = accepted["zero_gravity"]
	var controls := [
		{
			"control_id": "supported_rest_gravity_kick_and_constraint_cancellation_close",
			"passed": _close(
				float(supported["signed_discrete_staging_exchange_j"])
				+ float((fixtures["supported_rest"] as Dictionary)["known_constraint_exchange_j"]),
				float((fixtures["supported_rest"] as Dictionary)["endpoint_energy_change_j"]),
			),
		},
		{
			"control_id": "free_fall_force_and_position_terms_match_endpoint_change_once",
			"passed": _close(
				float(free_fall["signed_discrete_staging_exchange_j"]),
				float((fixtures["free_fall"] as Dictionary)["endpoint_energy_change_j"]),
			),
		},
		{
			"control_id": "moving_vertical_cross_terms_cancel_to_the_same_discrete_defect",
			"passed": (
				_close(
					float(upward["signed_discrete_staging_exchange_j"]),
					float((fixtures["upward_free_fall"] as Dictionary)["endpoint_energy_change_j"]),
				)
				and _close(
					float(downward["signed_discrete_staging_exchange_j"]),
					float((fixtures["downward_free_fall"] as Dictionary)["endpoint_energy_change_j"]),
				)
				and _close(
					float(upward["signed_discrete_staging_exchange_j"]),
					float(downward["signed_discrete_staging_exchange_j"]),
				)
			),
		},
		{
			"control_id": "zero_gravity_has_zero_force_position_and_total_exchange",
			"passed": (
				float(zero_gravity["force_integration_kinetic_exchange_j"]) == 0.0
				and float(zero_gravity["position_integration_potential_exchange_j"]) == 0.0
				and float(zero_gravity["signed_discrete_staging_exchange_j"]) == 0.0
			),
		},
		{
			"control_id": "force_and_position_components_are_retained_before_signed_sum",
			"passed": _close(
				float(free_fall["force_integration_kinetic_exchange_j"])
				+ float(free_fall["position_integration_potential_exchange_j"]),
				float(free_fall["signed_discrete_staging_exchange_j"]),
			),
		},
	]
	for control in controls:
		if not bool((control as Dictionary)["passed"]):
			return _failure(
				"QSDK_R24D148_CONTROL_FAILED:%s" % String((control as Dictionary)["control_id"]),
				{"controls": controls, "accepted_fixtures": accepted},
			)
	var mutation_result := _mutation_rejections_v1(fixtures["free_fall"])
	if not bool(mutation_result.get("ok", false)):
		return mutation_result
	var route_result := _route_mapping_zero_world_v1()
	if not bool(route_result.get("ok", false)):
		return route_result
	var total_check_count := (
		controls.size()
		+ int(mutation_result["mutation_rejection_count"])
		+ int(route_result["check_count"])
	)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d148_godot_discrete_staging_observer_zero_world_v1"
		),
		"gate_id": Observer.GATE_ID,
		"ok": true,
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_discrete_staging_observer_design",
			"question_class": "development",
		},
		"question_class": "development",
		"rule_id": Observer.RULE_ID,
		"accepted_fixtures": accepted,
		"controls": controls,
		"control_count": controls.size(),
		"mutation_ids": mutation_result["mutation_ids"],
		"mutation_rejections": mutation_result["mutation_rejections"],
		"mutation_rejection_count": int(mutation_result["mutation_rejection_count"]),
		"route_mapping": route_result,
		"runtime_profile_id": ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"capability_variant_id": StagingRoute.CAPABILITY_VARIANT_ID,
		"authority_profile_id": StagingRoute.AUTHORITY_PROFILE_ID,
		"authority_source_sha256": (
			RouteScript.R148_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256
		),
		"authority_profile_source_bound": true,
		"authority_profile_byte_length": 10464,
		"energy_route_id": StagingRoute.ROUTE_ID,
		"energy_mapping_profile_id": StagingRoute.MAPPING_PROFILE_ID,
		"discrete_staging_rule_id": Observer.RULE_ID,
		"positive_case_count": controls.size() + int(route_result["control_count"]),
		"forced_failure_case_count": (
			int(mutation_result["mutation_rejection_count"])
			+ int(route_result["mutation_rejection_count"])
		),
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"check_count": total_check_count,
		"checks_passed": total_check_count,
		"native_float32_control_operation_budget": CONTROL_OPERATION_BUDGET,
		"mechanical_energy_change_used_as_observer_input": false,
		"energy_balance_residual_used_as_observer_input": false,
		"acceptance_threshold_used_as_observer_input": false,
		"constraint_exchange_used_as_staging_input": false,
		"controller_or_behavior_result_used_as_observer_input": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"physical_acceptance_authority": false,
		"prone_to_standing_claimed": false,
		"sdk1_milestone_advanced": false,
		"release_authority": false,
	}


static func _fixture_v1(initial_velocity_y_m_s: float, gravity_y_m_s2: float, supported: bool) -> Dictionary:
	var gravity := Vector3(0.0, gravity_y_m_s2, 0.0)
	var pre_velocity := Vector3(0.0, initial_velocity_y_m_s, 0.0)
	var velocity_after_force := pre_velocity + gravity * DT
	var post_velocity := Vector3.ZERO if supported else velocity_after_force
	var pre_position := Vector3(0.0, INITIAL_Y_M, 0.0)
	var post_position := pre_position + post_velocity * DT
	var pre_energy := _kinetic_energy(MASS_KG, pre_velocity) - MASS_KG * gravity.dot(pre_position)
	var post_energy := _kinetic_energy(MASS_KG, post_velocity) - MASS_KG * gravity.dot(post_position)
	var force_exchange := (
		_kinetic_energy(MASS_KG, velocity_after_force)
		- _kinetic_energy(MASS_KG, pre_velocity)
	)
	return {
		"ordered_body_boundaries": [
			{
				"body_id": "analytic_body",
				"body_index": 0,
				"pre_boundary_sequence": 0,
				"post_boundary_sequence": 1,
				"mass_kg": MASS_KG,
				"pre_position_world_m": pre_position,
				"post_position_world_m": post_position,
				"pre_linear_velocity_world_m_s": pre_velocity,
				"post_linear_velocity_world_m_s": post_velocity,
				"total_gravity_world_m_s2": gravity,
				"pre_source_measurement": true,
				"post_source_measurement": true,
			},
		],
		"position_constraint_displacement": Vector3.ZERO,
		"force_contract": _force_contract_v1(),
		"known_constraint_exchange_j": -force_exchange if supported else 0.0,
		"endpoint_energy_change_j": post_energy - pre_energy,
	}


static func _measure_fixture_v1(fixture: Dictionary) -> Dictionary:
	return Observer.measure_v1(
		1,
		0,
		DT,
		(fixture["ordered_body_boundaries"] as Array).duplicate(true),
		fixture["position_constraint_displacement"],
		(fixture["force_contract"] as Dictionary).duplicate(true),
	)


static func _mutation_rejections_v1(fixture_value: Variant) -> Dictionary:
	if not (fixture_value is Dictionary):
		return _failure("QSDK_R24D148_MUTATION_FIXTURE_INVALID")
	var fixture: Dictionary = fixture_value
	var mutations: Array = []
	var omitted := fixture.duplicate(true)
	(omitted["ordered_body_boundaries"] as Array).clear()
	mutations.append(_reject_v1("omitted_body_boundary", omitted, "QSDK_R24D148_BODY_POPULATION_INVALID"))
	var duplicated := fixture.duplicate(true)
	var duplicate_row: Dictionary = (duplicated["ordered_body_boundaries"] as Array)[0].duplicate(true)
	(duplicated["ordered_body_boundaries"] as Array).append(duplicate_row)
	(duplicated["force_contract"] as Dictionary)["expected_body_count"] = 2
	mutations.append(_reject_v1("duplicated_body_boundary", duplicated, "QSDK_R24D148_BODY_ORDER_INVALID"))
	var reordered := fixture.duplicate(true)
	var second_row: Dictionary = (reordered["ordered_body_boundaries"] as Array)[0].duplicate(true)
	second_row["body_id"] = "analytic_body_2"
	second_row["body_index"] = 1
	(reordered["ordered_body_boundaries"] as Array).append(second_row)
	(reordered["force_contract"] as Dictionary)["expected_body_count"] = 2
	(reordered["ordered_body_boundaries"] as Array).reverse()
	mutations.append(_reject_v1("reordered_body_boundaries", reordered, "QSDK_R24D148_BODY_ORDER_INVALID"))
	var stale := fixture.duplicate(true)
	(stale["ordered_body_boundaries"] as Array)[0]["pre_boundary_sequence"] = 7
	mutations.append(_reject_v1("stale_pre_boundary", stale, "QSDK_R24D148_BODY_BOUNDARY_SEQUENCE_INVALID"))
	var nonfinite_boundary := fixture.duplicate(true)
	(nonfinite_boundary["ordered_body_boundaries"] as Array)[0]["post_position_world_m"] = Vector3(NAN, 0.0, 0.0)
	mutations.append(_reject_v1("nonfinite_body_boundary", nonfinite_boundary, "QSDK_R24D148_BODY_BOUNDARY_NONFINITE"))
	var nonfinite_displacement := fixture.duplicate(true)
	nonfinite_displacement["position_constraint_displacement"] = Vector3(INF, 0.0, 0.0)
	mutations.append(_reject_v1("nonfinite_position_constraint_displacement", nonfinite_displacement, "QSDK_R24D148_POSITION_CONSTRAINT_DISPLACEMENT_NONFINITE"))
	var not_source := fixture.duplicate(true)
	(not_source["ordered_body_boundaries"] as Array)[0]["post_source_measurement"] = false
	mutations.append(_reject_v1("boundary_not_source_measured", not_source, "QSDK_R24D148_BODY_BOUNDARY_NOT_SOURCE_MEASURED"))
	var residual_derived := fixture.duplicate(true)
	(residual_derived["force_contract"] as Dictionary)["energy_balance_residual_j"] = 123.0
	mutations.append(_reject_v1("residual_derived_input", residual_derived, "QSDK_R24D148_RESIDUAL_DERIVED_INPUT_REFUSED"))
	for mutation in mutations:
		if not bool((mutation as Dictionary).get("rejected", false)):
			return _failure("QSDK_R24D148_MUTATION_ACCEPTED_OR_WRONG_REFUSAL", {"mutations": mutations})
	var mutation_ids: Array = []
	for mutation in mutations:
		mutation_ids.append(String((mutation as Dictionary)["mutation_id"]))
	return {
		"ok": true,
		"mutation_ids": mutation_ids,
		"mutation_rejections": mutations,
		"mutation_rejection_count": mutations.size(),
	}


static func _reject_v1(mutation_id: String, fixture: Dictionary, expected_code: String) -> Dictionary:
	var observed := _measure_fixture_v1(fixture)
	var observed_code := String(observed.get("failure_code", ""))
	return {
		"mutation_id": mutation_id,
		"expected_code": expected_code,
		"observed_code": observed_code,
		"rejected": not bool(observed.get("ok", false)) and observed_code.begins_with(expected_code),
	}


static func _force_contract_v1() -> Dictionary:
	return {
		"schema_version": Observer.FORCE_CONTRACT_SCHEMA,
		"godot_source_commit": Observer.GODOT_SOURCE_COMMIT,
		"force_update_rule_id": "godot_total_gravity_as_accumulated_force_then_jolt_symplectic_euler_v1",
		"position_update_rule_id": "jolt_single_discrete_velocity_integration_then_position_constraints_v1",
		"expected_body_count": 1,
		"non_gravity_force_write_count": 0,
		"maximum_linear_velocity_m_s": 500.0,
		"jolt_system_gravity_zero": true,
		"godot_total_gravity_added_as_body_force": true,
		"all_bodies_dynamic": true,
		"all_translation_dofs_unlocked": true,
		"all_body_gravity_scales_one": true,
		"constant_force_zero": true,
		"constant_torque_zero": true,
		"linear_damping_zero": true,
		"angular_damping_zero": true,
		"custom_integrator_disabled": true,
		"gyroscopic_forces_disabled": true,
		"sleeping_disabled": true,
		"continuous_collision_detection_disabled": true,
		"single_discrete_collision_step": true,
		"position_constraint_displacement_source_measurement": true,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"constraint_exchange_used_as_staging_input": false,
		"controller_or_behavior_result_used_as_input": false,
	}


static func _route_mapping_zero_world_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D148_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D148_GODOT_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_complete_energy_context_v4(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D148_ROUTE_CONTEXT_INVALID", context)
	var capability: Dictionary = context.get("capability", {})
	var capability_validation := (
		ProfileScript.validate_discrete_staging_complete_energy_capability_v1(
			capability
		)
	)
	var observer_receipt := _route_observer_receipt_v1()
	if not bool(observer_receipt.get("ok", false)):
		return _failure("QSDK_R24D148_ROUTE_OBSERVER_INVALID", observer_receipt)
	var predecessor := _route_predecessor_v1(sdk, observer_receipt)
	var observation_base: Dictionary = predecessor["observation_base"]
	(observation_base["engine_step_identity"] as Dictionary)["capability_sha256"] = (
		String(context.get("capability_sha256", ""))
	)
	var energy_source: Dictionary = predecessor["energy_source_receipt"]
	var components: Dictionary = predecessor["source_component_receipts"]
	var accumulator := StagingRoute.initial_accumulator_v1()
	var bound := RouteScript.compose_discrete_staging_complete_energy_observations_v1(
		sdk,
		context,
		observation_base,
		energy_source,
		components,
		observer_receipt,
		accumulator,
	)
	if not bool(bound.get("ok", false)):
		return _failure("QSDK_R24D148_ROUTE_MAPPING_POSITIVE_REFUSED", bound)
	var authority_binding := _authority_profile_binding_v1()
	if not bool(authority_binding.get("ok", false)):
		return _failure("QSDK_R24D148_AUTHORITY_PROFILE_BINDING_INVALID", authority_binding)
	var authority := RouteScript.discrete_staging_complete_energy_partition_authority_v1(
		sdk, context, bound
	)
	var ledger: Dictionary = (bound["observation_v3"] as Dictionary)["energy_balance"]
	var staging_j := float(observer_receipt["signed_discrete_staging_exchange_j"])
	var residual_v3 := (
		float(ledger["current_mechanical_energy_j"])
		- float(ledger["initial_mechanical_energy_j"])
		- float(ledger["cumulative_applied_actuator_work_j"])
		- float(ledger["cumulative_signed_external_work_j"])
		- float(ledger["cumulative_signed_constraint_exchange_j"])
		- float(ledger["cumulative_signed_discrete_staging_exchange_j"])
		+ float(ledger["cumulative_passive_dissipation_j"])
	)
	var predecessor_context := RouteScript.prepare_complete_energy_context_v3(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var predecessor_observation_base := observation_base.duplicate(true)
	(predecessor_observation_base["engine_step_identity"] as Dictionary)[
		"capability_sha256"
	] = String(predecessor_context.get("capability_sha256", ""))
	var omitted := RouteScript.compose_solver_coupled_complete_energy_observations_v1(
		sdk,
		predecessor_context,
		predecessor_observation_base,
		energy_source,
		components,
	)
	if not bool(omitted.get("ok", false)):
		return _failure("QSDK_R24D148_OMISSION_CONTROL_SETUP_INVALID", omitted)
	var omitted_ledger: Dictionary = (
		(omitted["observation_v3"] as Dictionary)["energy_balance"]
	)
	var omitted_residual := (
		float(omitted_ledger["current_mechanical_energy_j"])
		- float(omitted_ledger["initial_mechanical_energy_j"])
		- float(omitted_ledger["cumulative_applied_actuator_work_j"])
		- float(omitted_ledger["cumulative_signed_external_work_j"])
		- float(omitted_ledger["cumulative_signed_constraint_exchange_j"])
		- float(omitted_ledger["cumulative_signed_discrete_staging_exchange_j"])
		+ float(omitted_ledger["cumulative_passive_dissipation_j"])
	)
	var mapped: Dictionary = bound["native_to_portable_staging_mapping"]
	var mapped_energy: Dictionary = mapped["energy_source_receipt"]
	var controls := {
		"exact_r148_context_selected": (
			String(context.get("energy_route_id", "")) == StagingRoute.ROUTE_ID
			and String(context.get("energy_mapping_profile_id", ""))
			== StagingRoute.MAPPING_PROFILE_ID
			and not bool(context.get("physical_world_construction_authorized", true))
		),
		"single_capability_channel_changed": (
			bool(capability_validation.get("ok", false))
			and int(capability_validation.get("changed_channel_count", -1)) == 1
			and capability_validation.get("changed_channel_ids", [])
			== ["energy_balance_ledger"]
		),
		"observer_mapped_once_to_signed_v3_channel": (
			int(mapped_energy.get("adapter_side_discrete_staging_event_count", -1)) == 1
			and float(mapped_energy.get("step_signed_discrete_staging_exchange_j", NAN))
			== staging_j
			and float(
				mapped_energy.get("cumulative_signed_discrete_staging_exchange_j", NAN)
			) == staging_j
			and float(ledger.get("cumulative_signed_discrete_staging_exchange_j", NAN))
			== staging_j
		),
		"portable_v3_ledger_closes_with_independent_staging": _close(residual_v3, 0.0),
		"forced_staging_omission_preserves_nonzero_residual": _close(
			omitted_residual, staging_j
		),
		"mapping_does_not_relabel_staging": (
			not bool(mapped_energy.get("staging_mapped_to_external_work", true))
			and not bool(mapped_energy.get("staging_mapped_to_passive_dissipation", true))
			and not bool(
				mapped_energy.get("mechanical_energy_change_used_as_staging_input", true)
			)
			and not bool(
				mapped_energy.get("energy_balance_residual_used_as_staging_input", true)
			)
		),
		"authority_profile_is_content_bound": bool(
			authority_binding.get("ok", false)
		),
		"prospective_authority_stays_nonphysical": (
			String(authority.get("authority_profile_id", ""))
			== StagingRoute.AUTHORITY_PROFILE_ID
			and String(authority.get("authority_source_sha256", ""))
			== RouteScript.R148_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256
			and not bool(authority.get("live_native_transport_commissioned", true))
			and not bool(authority.get("exact_balance_safety_authority", true))
			and not bool(authority.get("development_progression_permitted", true))
			and not bool(authority.get("physical_acceptance_authority", true))
			and not bool(authority.get("release_authority", true))
		),
	}


	for control_id in controls:
		if not bool(controls[control_id]):
			return _failure(
				"QSDK_R24D148_ROUTE_CONTROL_FAILED:%s" % String(control_id),
				{"controls": controls, "bound": bound},
			)
	var mutation_rejections := _route_mapping_mutations_v1(
		sdk,
		context,
		predecessor_context,
		observation_base,
		energy_source,
		components,
		observer_receipt,
		accumulator,
		mapped,
	)
	for mutation in mutation_rejections:
		if not bool((mutation as Dictionary).get("rejected", false)):
			return _failure(
				"QSDK_R24D148_ROUTE_MUTATION_ACCEPTED_OR_WRONG_REFUSAL",
				{"mutations": mutation_rejections},
			)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d148_godot_discrete_staging_route_mapping_zero_world_v1"
		),
		"ok": true,
		"route_id": StagingRoute.ROUTE_ID,
		"mapping_profile_id": StagingRoute.MAPPING_PROFILE_ID,
		"capability_variant_id": StagingRoute.CAPABILITY_VARIANT_ID,
		"controls": controls,
		"control_count": controls.size(),
		"mutation_rejections": mutation_rejections,
		"mutation_rejection_count": mutation_rejections.size(),
		"check_count": controls.size() + mutation_rejections.size(),
		"checks_passed": controls.size() + mutation_rejections.size(),
		"forced_omission_residual_j": omitted_residual,
		"mapped_staging_exchange_j": staging_j,
		"authority_profile_source_bound": true,
		"authority_profile_byte_length": int(authority_binding["byte_length"]),
		"authority_source_sha256": String(authority_binding["raw_sha256"]),
		"physical_world_construction_authorized": false,
		"physical_world_construction_next_gate": "QSDK-R24D149",
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _authority_profile_binding_v1() -> Dictionary:
	if not FileAccess.file_exists(AUTHORITY_PROFILE_PATH):
		return {"ok": false, "failure_code": "PROFILE_MISSING"}
	var raw_sha256 := (
		"sha256:%s" % FileAccess.get_sha256(AUTHORITY_PROFILE_PATH).to_lower()
	)
	var raw_bytes := FileAccess.get_file_as_bytes(AUTHORITY_PROFILE_PATH)
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(AUTHORITY_PROFILE_PATH)
	)
	if not (parsed is Dictionary):
		return {"ok": false, "failure_code": "PROFILE_JSON_INVALID"}
	var profile: Dictionary = parsed
	var identity: Dictionary = profile.get("profile_identity", {})
	var source: Dictionary = profile.get("native_source_provenance", {})
	var observer: Dictionary = profile.get("observer_definition", {})
	var force_contract: Dictionary = profile.get("force_path_capability_contract", {})
	var mapping: Dictionary = profile.get("native_to_portable_mapping", {})
	var claims: Dictionary = profile.get("authority_claims", {})
	var qualification: Dictionary = profile.get("qualification_boundary", {})
	var exact := (
		raw_sha256 == RouteScript.R148_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256
		and raw_bytes.size() == 10464
		and String(profile.get("gate_id", "")) == "QSDK-R24D148"
		and String(profile.get("question_class", "")) == "development"
		and String(identity.get("authority_profile_id", ""))
		== StagingRoute.AUTHORITY_PROFILE_ID
		and String(identity.get("capability_variant_id", ""))
		== StagingRoute.CAPABILITY_VARIANT_ID
		and String(identity.get("collector_id", "")) == StagingRoute.COLLECTOR_ID
		and String(identity.get("route_id", "")) == StagingRoute.ROUTE_ID
		and String(identity.get("energy_source_profile_id", ""))
		== StagingRoute.MAPPING_PROFILE_ID
		and String(identity.get("discrete_staging_rule_id", "")) == Observer.RULE_ID
		and String(source.get("godot_source_commit", "")) == Observer.GODOT_SOURCE_COMMIT
		and not bool(source.get("native_engine_source_changed", true))
		and not bool(source.get("native_engine_rebuild_required", true))
		and not bool(observer.get("whole_step_mechanical_energy_change_used_as_input", true))
		and not bool(observer.get("energy_balance_residual_used_as_input", true))
		and not bool(observer.get("acceptance_threshold_used_as_input", true))
		and not bool(observer.get("constraint_exchange_used_as_staging_input", true))
		and int(force_contract.get("maximum_linear_velocity_m_s", -1)) == 500
		and not bool(force_contract.get("velocity_clamp_event_directly_observed", true))
		and bool(mapping.get("one_staging_event_per_semantic_step", false))
		and bool(mapping.get("staging_mapped_to_portable_v3_signed_discrete_staging_channel", false))
		and not bool(mapping.get("staging_mapped_to_external_work", true))
		and not bool(mapping.get("staging_mapped_to_passive_dissipation", true))
		and not bool(claims.get("live_native_transport_commissioned", true))
		and not bool(claims.get("physical_acceptance_authority", true))
		and not bool(claims.get("release_authority", true))
		and not bool(qualification.get("physical_execution_authorized_by_this_profile", true))
		and int(qualification.get("world_build_count", -1)) == 0
		and int(qualification.get("solver_step_count", -1)) == 0
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "PROFILE_IDENTITY_INVALID",
		"raw_sha256": raw_sha256,
		"byte_length": raw_bytes.size(),
	}


static func _route_observer_receipt_v1() -> Dictionary:
	var rows: Array = []
	var gravity := Vector3(0.0, GRAVITY_Y_M_S2, 0.0)
	for index in range(StagingRoute.EXPECTED_BODY_COUNT):
		var pre_position := Vector3(float(index) * 0.1, INITIAL_Y_M, 0.0)
		var pre_velocity := Vector3.ZERO
		var post_velocity := pre_velocity + gravity * DT
		rows.append(
			{
				"body_id": "route_body_%d" % index,
				"body_index": index,
				"pre_boundary_sequence": 0,
				"post_boundary_sequence": 1,
				"mass_kg": MASS_KG,
				"pre_position_world_m": pre_position,
				"post_position_world_m": pre_position + post_velocity * DT,
				"pre_linear_velocity_world_m_s": pre_velocity,
				"post_linear_velocity_world_m_s": post_velocity,
				"total_gravity_world_m_s2": gravity,
				"pre_source_measurement": true,
				"post_source_measurement": true,
			}
		)
	return Observer.measure_v1(
		1,
		0,
		DT,
		rows,
		Vector3.ZERO,
		StagingRoute.force_contract_v1(),
	)


static func _route_predecessor_v1(sdk: Object, observer_receipt: Dictionary) -> Dictionary:
	var digest_a := _sha256(sdk, {"source": "solver"})
	var digest_b := _sha256(sdk, {"source": "partition"})
	var digest_c := _sha256(sdk, {"source": "world"})
	var staging_j := float(observer_receipt["signed_discrete_staging_exchange_j"])
	var energy_source := {
		"schema_version": StagingRoute.PREDECESSOR_SOURCE_RECEIPT_SCHEMA,
		"semantic_step": 1,
		"initial_mechanical_energy_j": 20.0,
		"current_mechanical_energy_j": 20.0 + staging_j,
		"cumulative_applied_actuator_work_j": 0.0,
		"cumulative_signed_external_work_j": 0.0,
		"step_signed_constraint_exchange_j": 0.0,
		"step_position_constraint_potential_exchange_j": 0.0,
		"cumulative_signed_constraint_exchange_j": 0.0,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"cumulative_passive_dissipation_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"solver_energy_exchange_receipt_sha256": digest_a,
		"solver_coupled_partition_receipt_sha256": digest_b,
		"world_energy_configuration_receipt_sha256": digest_c,
		"actuator_constraint_disjointness_receipt_sha256": digest_b,
		"partition_rule_id": StagingRoute.PREDECESSOR_PARTITION_RULE_ID,
		"raw_step_signed_solver_exchange_j": 0.0,
		"step_actuator_work_j": 0.0,
		"native_motor_work_subtracted_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"constraint_exchange_partition_complete": true,
		"passive_dissipation_partition_complete": true,
		"component_partition_complete": true,
		"exact_balance_safety_authority": true,
		"unclosed_energy_residual_preserved": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"residual_balancing_permitted": false,
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	var components := {
		"schema_version": StagingRoute.PREDECESSOR_SOURCE_COMPONENT_RECEIPTS_SCHEMA,
		"semantic_step": 1,
		"channel_count": 10,
		"component_partition_complete": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	return {
		"observation_base": {
			"semantic_step": 1,
			"engine_step_identity": {
				"schema_version": "sporespore_recovery_engine_step_identity_v1",
				"adapter_id": RouteScript.ADAPTER_ID,
				"engine": RouteScript.ENGINE_ID,
				"capability_sha256": "",
				"semantic_step": 1,
				"source_measurement": true,
			},
		},
		"energy_source_receipt": energy_source,
		"source_component_receipts": components,
	}


static func _route_mapping_mutations_v1(
	sdk: Object,
	context: Dictionary,
	predecessor_context: Dictionary,
	observation_base: Dictionary,
	energy_source: Dictionary,
	components: Dictionary,
	observer_receipt: Dictionary,
	accumulator: Dictionary,
	mapped: Dictionary,
) -> Array:
	var mutations: Array = []
	var wrong_observer := observer_receipt.duplicate(true)
	wrong_observer["rule_id"] = "wrong"
	mutations.append(
		_route_reject_v1(
			"observer_rule_relabel",
			RouteScript.compose_discrete_staging_complete_energy_observations_v1(
				sdk, context, observation_base, energy_source, components,
				wrong_observer, accumulator
			),
			"QSDK_R24D148_OBSERVER_RECEIPT_INVALID",
		)
	)
	var stale_accumulator := accumulator.duplicate(true)
	stale_accumulator["sequence"] = 1
	stale_accumulator["event_count"] = 1
	stale_accumulator["last_observer_receipt_sha256"] = _sha256(sdk, {"x": 1})
	stale_accumulator["previous_accumulator_sha256"] = _sha256(sdk, {"x": 0})
	mutations.append(
		_route_reject_v1(
			"stale_accumulator",
			RouteScript.compose_discrete_staging_complete_energy_observations_v1(
				sdk, context, observation_base, energy_source, components,
				observer_receipt, stale_accumulator
			),
			"QSDK_R24D148_SOURCE_SEQUENCE_OR_PARTITION_MISMATCH",
		)
	)
	var position_mismatch := energy_source.duplicate(true)
	position_mismatch["step_position_constraint_potential_exchange_j"] = 1.0
	mutations.append(
		_route_reject_v1(
			"position_constraint_partition_mismatch",
			RouteScript.compose_discrete_staging_complete_energy_observations_v1(
				sdk, context, observation_base, position_mismatch, components,
				observer_receipt, accumulator
			),
			"QSDK_R24D148_SOURCE_SEQUENCE_OR_PARTITION_MISMATCH",
		)
	)
	var nonzero_predecessor_staging := energy_source.duplicate(true)
	nonzero_predecessor_staging["cumulative_signed_discrete_staging_exchange_j"] = 1.0
	mutations.append(
		_route_reject_v1(
			"predecessor_staging_not_structural_zero",
			RouteScript.compose_discrete_staging_complete_energy_observations_v1(
				sdk, context, observation_base, nonzero_predecessor_staging, components,
				observer_receipt, accumulator
			),
			"QSDK_R24D148_PREDECESSOR_ENERGY_SOURCE_INVALID",
		)
	)
	var unmeasured_components := components.duplicate(true)
	unmeasured_components["source_measurement"] = false
	mutations.append(
		_route_reject_v1(
			"component_source_not_measured",
			RouteScript.compose_discrete_staging_complete_energy_observations_v1(
				sdk, context, observation_base, energy_source, unmeasured_components,
				observer_receipt, accumulator
			),
			"QSDK_R24D148_PREDECESSOR_COMPONENT_SOURCE_INVALID",
		)
	)
	mutations.append(
		_route_reject_v1(
			"cross_profile_context",
			RouteScript.compose_discrete_staging_complete_energy_observations_v1(
				sdk, predecessor_context, observation_base, energy_source, components,
				observer_receipt, accumulator
			),
			"QSDK_R24D148_COMPLETE_ENERGY_CONTEXT_REQUIRED",
		)
	)
	var mapped_energy: Dictionary = mapped["energy_source_receipt"]
	var mapped_components: Dictionary = mapped["source_component_receipts"]
	mutations.append(
		_route_reject_v1(
			"measured_staging_presented_to_r144_route",
			RouteScript.compose_solver_coupled_complete_energy_observations_v1(
				sdk, predecessor_context, observation_base,
				mapped_energy, mapped_components
			),
			"QSDK_R24D144_ENERGY_SOURCE_INCOMPLETE",
		)
	)
	return mutations


static func _route_reject_v1(
	mutation_id: String,
	observed: Dictionary,
	expected_code: String,
) -> Dictionary:
	var observed_code := String(observed.get("failure_code", ""))
	return {
		"mutation_id": mutation_id,
		"expected_code": expected_code,
		"observed_code": observed_code,
		"rejected": (
			not bool(observed.get("ok", false))
			and observed_code.begins_with(expected_code)
		),
	}


static func _sha256(sdk: Object, value: Variant) -> String:
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _kinetic_energy(mass_kg: float, velocity: Vector3) -> float:
	return 0.5 * mass_kg * velocity.length_squared()


static func _close(left: float, right: float) -> bool:
	var scale := maxf(absf(left), maxf(absf(right), 1.0))
	return (
		absf(left - right)
		<= float(CONTROL_OPERATION_BUDGET) * NATIVE_FLOAT32_EPSILON * scale
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d148_godot_discrete_staging_observer_zero_world_v1"
		),
		"gate_id": Observer.GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
