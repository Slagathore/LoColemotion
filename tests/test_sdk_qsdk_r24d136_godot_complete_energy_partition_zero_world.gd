extends SceneTree
# gdlint: disable=max-line-length

## Compact R136 source/route gate. All positive and forced-failure cases call
## the same pure contracts used by production. No Node, RID, model, world,
## native write/readback, or solver step is created.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const ProfileScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D136_GODOT_COMPLETE_ENERGY_ZERO_WORLD "
const EXPECTED_CONSTRAINT_EXCHANGE_J := 2.481


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D136_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D136_GODOT_EXTENSION_INSTANTIATION_FAILED")

	var context := RouteScript.prepare_complete_energy_context_v1(sdk)
	if (
		not bool(context.get("ok", false))
		or not bool(context.get("complete_energy_profile_selected", false))
		or String(context.get("energy_route_id", "")) != RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
		or (
			String(context.get("energy_mapping_profile_id", ""))
			!= RouteScript.R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or (
			String((context.get("runtime_binding", {}) as Dictionary).get("runtime_profile_id", ""))
			!= ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		)
	):
		return _failure("QSDK_R24D136_COMPLETE_CONTEXT_INVALID", context)

	var gravity := Vector3(0.0, -9.81, 0.0)
	var solver_telemetry := _solver_telemetry_v1()
	var solver_receipt := (
		WorldScript
		. native_solver_energy_exchange_contract_v1(
			solver_telemetry,
			7,
			gravity,
		)
	)
	if (
		not bool(solver_receipt.get("ok", false))
		or not is_equal_approx(
			float(solver_receipt.get("step_signed_constraint_exchange_j", NAN)),
			EXPECTED_CONSTRAINT_EXCHANGE_J,
		)
		or int(solver_receipt.get("check_count", -1)) != 32
	):
		return _failure("QSDK_R24D136_SOLVER_CONTRACT_POSITIVE_INVALID", solver_receipt)

	var active_inputs := _partition_inputs_v1(false)
	var active_partition := WorldScript.complete_energy_partition_inputs_contract_v1(active_inputs)
	var zero_inputs := _partition_inputs_v1(true)
	var zero_partition := WorldScript.complete_energy_partition_inputs_contract_v1(zero_inputs)
	if (
		not bool(active_partition.get("ok", false))
		or bool(active_partition.get("no_actuation_requested", true))
		or (
			String(active_partition.get("actuator_mapping_id", ""))
			!= RouteScript.R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		)
		or not bool(zero_partition.get("ok", false))
		or not bool(zero_partition.get("no_actuation_requested", false))
		or float(zero_partition.get("step_actuator_work_j", NAN)) != 0.0
	):
		return _failure(
			"QSDK_R24D136_PARTITION_INPUT_POSITIVE_INVALID",
			{"active": active_partition, "zero": zero_partition},
		)

	var model := {"complete_energy_profile_selected": true}
	var active_control := {"no_actuation_requested": false}
	var zero_control := {"no_actuation_requested": true}
	var active_application := (
		RouteScript
		. complete_energy_application_receipt_contract_v1(
			active_control,
			model,
			_application_receipt_v1(false),
		)
	)
	var zero_application := (
		RouteScript
		. complete_energy_application_receipt_contract_v1(
			zero_control,
			model,
			_application_receipt_v1(true),
		)
	)
	if (
		not bool(active_application.get("ok", false))
		or bool(active_application.get("no_actuation_requested", true))
		or not bool(zero_application.get("ok", false))
		or not bool(zero_application.get("no_actuation_requested", false))
	):
		return _failure(
			"QSDK_R24D136_APPLICATION_CONTRACT_POSITIVE_INVALID",
			{"active": active_application, "zero": zero_application},
		)

	var complete_fixture := _complete_fixture_v1(
		sdk,
		context,
		solver_receipt,
		zero_partition,
	)
	if not bool(complete_fixture.get("ok", false)):
		return _failure("QSDK_R24D136_COMPLETE_FIXTURE_INVALID", complete_fixture)
	var bound: Dictionary = complete_fixture["bound"]
	var authority := RouteScript.complete_energy_partition_authority_v1(context, bound)
	if (
		authority.is_empty()
		or (
			String(authority.get("authority_profile_id", ""))
			!= RouteScript.R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		)
		or not bool(authority.get("component_partition_complete", false))
		or not bool(authority.get("exact_balance_safety_authority", false))
		or bool(authority.get("physical_acceptance_authority", true))
		or bool(authority.get("release_authority", true))
	):
		return _failure("QSDK_R24D136_COMPLETE_AUTHORITY_INVALID", authority)

	var initialized := (
		RouteScript
		. initialize_behavior_arm_v1(
			sdk,
			context,
			"candidate_command",
		)
	)
	if not bool(initialized.get("ok", false)):
		return _failure("QSDK_R24D136_INITIALIZATION_INVALID", initialized)
	var advanced := (
		RouteScript
		. advance_behavior_complete_energy_v1(
			sdk,
			context,
			bound,
			initialized["memory"],
			"candidate_command",
			"confirm_prone",
		)
	)
	var progression: Dictionary = advanced.get("development_progression_receipt", {})
	if (
		not bool(advanced.get("ok", false))
		or (
			String(advanced.get("schema_version", ""))
			!= "sporespore_qsdk_r24d136_godot_complete_energy_behavior_advance_v1"
		)
		or (
			String(progression.get("authority_profile_id", ""))
			!= RouteScript.R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		)
		or not bool(progression.get("component_partition_complete", false))
		or not bool(progression.get("exact_balance_safety_authority", false))
		or bool(progression.get("development_progression_permitted", true))
		or not bool(progression.get("stable_stance_completion_authorized", false))
		or bool(progression.get("prone_to_standing_claimed", true))
		or bool(progression.get("physical_acceptance_authority", true))
		or bool(progression.get("release_authority", true))
	):
		return _failure("QSDK_R24D136_COMPLETE_ADVANCE_INVALID", advanced)

	var solver_mutation_rejections := _solver_mutation_rejections_v1(
		solver_telemetry,
		gravity,
	)
	var partition_mutation_rejections := _partition_mutation_rejections_v1()
	var application_mutation_rejections := _application_mutation_rejections_v1()
	var binding_mutation_rejections := _binding_mutation_rejections_v1(
		sdk,
		context,
		complete_fixture,
	)
	var forced_failure_case_count := (
		solver_mutation_rejections
		+ partition_mutation_rejections
		+ application_mutation_rejections
		+ binding_mutation_rejections
	)
	var expected_forced_failure_case_count := 20
	var positive_case_count := 9
	var exact := (
		forced_failure_case_count == expected_forced_failure_case_count
		and int(advanced.get("model_construction_count", -1)) == 0
		and int(advanced.get("world_attempt_count", -1)) == 0
		and int(advanced.get("world_build_count", -1)) == 0
		and int(advanced.get("solver_step_count", -1)) == 0
		and not bool(advanced.get("physics_state_modified", true))
	)
	return {
		"schema_version": "sporespore_qsdk_r24d136_godot_complete_energy_partition_zero_world_v1",
		"gate_id": "QSDK-R24D136",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D136_ZERO_WORLD_CONJUNCTION_INVALID",
		"question_class": "development",
		"runtime_profile_id": ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"authority_profile_id": RouteScript.R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"energy_route_id": RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RouteScript.R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"constraint_exchange_partition_complete": true,
		"passive_dissipation_partition_complete": true,
		"component_partition_complete": true,
		"exact_balance_safety_authority": true,
		"stable_stance_completion_authorized": true,
		"solver_mutation_rejection_count": solver_mutation_rejections,
		"partition_mutation_rejection_count": partition_mutation_rejections,
		"application_mutation_rejection_count": application_mutation_rejections,
		"binding_mutation_rejection_count": binding_mutation_rejections,
		"positive_case_count": positive_case_count,
		"forced_failure_case_count": forced_failure_case_count,
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


static func _solver_telemetry_v1() -> Dictionary:
	return {
		"schema": "sporespore.godot_jolt_solver_energy_exchange_telemetry.v1",
		"profile_id": "godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v1",
		"telemetry_sequence": 7,
		"capture_space_step_sequence": 7,
		"read_space_step_sequence": 7,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"collision_step_count": 1,
		"constrained_island_count": 1,
		"velocity_measured_island_count": 1,
		"position_measured_island_count": 1,
		"joint_velocity_phase_count": 1,
		"contact_velocity_phase_count": 1,
		"position_constraint_phase_count": 1,
		"dynamic_body_observation_count": 9,
		"invalid_body_measurement_count": 0,
		"large_island_velocity_batch_count": 0,
		"large_island_position_batch_count": 0,
		"ccd_active_body_count": 0,
		"active_soft_body_count": 0,
		"update_error_bits": 0,
		"joint_velocity_constraint_exchange_j": 1.25,
		"contact_velocity_constraint_exchange_j": -0.25,
		"position_constraint_kinetic_exchange_j": 0.5,
		"position_constraint_mass_weighted_displacement_kg_m": Vector3(0.0, 0.1, 0.0),
		"complete": true,
		"source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
	}


static func _partition_inputs_v1(no_actuation_requested: bool) -> Dictionary:
	var bodies: Array = []
	for body_id_value in WorldScript.ORDERED_BODY_IDS:
		(
			bodies
			. append(
				{
					"body_id": String(body_id_value),
					"total_gravity_world_m_s2": Vector3(0.0, -9.81, 0.0),
					"linear_damp_mode": int(RigidBody3D.DAMP_MODE_REPLACE),
					"angular_damp_mode": int(RigidBody3D.DAMP_MODE_REPLACE),
					"linear_damp": 0.0,
					"angular_damp": 0.0,
					"continuous_cd": false,
				}
			)
		)
	var joints: Array = []
	for joint_id_value in WorldScript.ORDERED_JOINT_IDS:
		joints.append({"joint_id": String(joint_id_value), "motor_enabled": false})
	return {
		"semantic_step": 1,
		"ordered_body_readbacks": bodies,
		"ordered_joint_readbacks": joints,
		"no_actuation_requested": no_actuation_requested,
		"actuator_mapping_id":
		"" if no_actuation_requested else RouteScript.R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id":
		"" if no_actuation_requested else RouteScript.R136_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"step_actuator_work_j": 0.0 if no_actuation_requested else 0.25,
		"external_intervention_event_count": 0,
		"step_signed_external_work_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"step_signed_discrete_staging_exchange_j": 0.0,
	}


static func _application_receipt_v1(no_actuation_requested: bool) -> Dictionary:
	var value := {
		"schema_version":
		(
			"sporespore_qsdk_r24d65_godot_command_application_receipt_v1"
			if no_actuation_requested
			else "sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_application_receipt_v1"
		),
		"ok": true,
		"motor_enabled_count": 0,
		"solver_step_count": 0,
		"adapter_side_discrete_staging_event_count": 0,
		"physics_state_modified": not no_actuation_requested,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if no_actuation_requested:
		value["validated_command_count"] = 0
	else:
		value["actuator_mapping_id"] = RouteScript.R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		value["work_mapping_id"] = RouteScript.R136_REQUIRED_ACTIVE_WORK_MAPPING_ID
		value["hard_constraint_motor_disabled_count"] = 8
		value["joint_space_effective_inertia_population_projection_required"] = true
	return value


static func _complete_fixture_v1(
	sdk: Object,
	context: Dictionary,
	solver_receipt: Dictionary,
	partition_receipt: Dictionary,
) -> Dictionary:
	var predecessor := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(predecessor.get("ok", false)):
		return _failure("QSDK_R24D136_PREDECESSOR_FIXTURE_INVALID", predecessor)
	var observation_base: Dictionary = (predecessor["observation_v3"] as Dictionary).duplicate(true)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	var solver_sha256 := _sha256(sdk, solver_receipt)
	var partition_sha256 := _sha256(sdk, partition_receipt)
	var world_configuration_sha256 := _sha256(
		sdk,
		{
			"ordered_body_count": partition_receipt.get("ordered_body_count"),
			"ordered_joint_count": partition_receipt.get("ordered_joint_count"),
			"uniform_gravity_world_m_s2": partition_receipt.get("uniform_gravity_world_m_s2"),
			"native_joint_motor_enabled_count":
			partition_receipt.get("native_joint_motor_enabled_count"),
			"continuous_collision_detection_enabled_count":
			partition_receipt.get("continuous_collision_detection_enabled_count"),
			"nonzero_or_nonreplace_damping_body_count":
			partition_receipt.get("nonzero_or_nonreplace_damping_body_count"),
		},
	)
	if (
		solver_sha256.is_empty()
		or partition_sha256.is_empty()
		or world_configuration_sha256.is_empty()
	):
		return _failure("QSDK_R24D136_FIXTURE_DIGEST_INVALID")
	var constraint_exchange := float(solver_receipt["step_signed_constraint_exchange_j"])
	var energy_source := {
		"schema_version": "sporespore_qsdk_r24d136_godot_complete_energy_source_receipt_v1",
		"semantic_step": 1,
		"initial_mechanical_energy_j": 20.0,
		"current_mechanical_energy_j": 20.0 + constraint_exchange,
		"cumulative_applied_actuator_work_j": 0.0,
		"cumulative_signed_external_work_j": 0.0,
		"cumulative_signed_constraint_exchange_j": constraint_exchange,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"cumulative_passive_dissipation_j": 0.0,
		"step_signed_constraint_exchange_j": constraint_exchange,
		"step_position_constraint_potential_exchange_j":
		float(solver_receipt["position_constraint_potential_exchange_j"]),
		"adapter_side_discrete_staging_event_count": 0,
		"solver_energy_exchange_receipt_sha256": solver_sha256,
		"world_energy_configuration_receipt_sha256": world_configuration_sha256,
		"actuator_constraint_disjointness_receipt_sha256": partition_sha256,
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
		"schema_version": "sporespore_qsdk_r24d136_zero_world_source_components_v1",
		"semantic_step": 1,
		"solver_energy_exchange_receipt": solver_receipt.duplicate(true),
		"partition_inputs_receipt": partition_receipt.duplicate(true),
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	var bound := (
		RouteScript
		. compose_complete_energy_observations_v1(
			sdk,
			context,
			observation_base,
			energy_source,
			components,
		)
	)
	if not bool(bound.get("ok", false)):
		return _failure("QSDK_R24D136_COMPLETE_COMPOSITION_INVALID", bound)
	return {
		"ok": true,
		"bound": bound,
		"observation_base": observation_base,
		"energy_source_receipt": energy_source,
		"source_component_receipts": components,
	}


static func _solver_mutation_rejections_v1(base: Dictionary, gravity: Vector3) -> int:
	var mutations: Array = []
	var stale: Dictionary = base.duplicate(true)
	stale["capture_space_step_sequence"] = 6
	mutations.append(stale)
	var incomplete: Dictionary = base.duplicate(true)
	incomplete["complete"] = false
	mutations.append(incomplete)
	var large_island: Dictionary = base.duplicate(true)
	large_island["large_island_velocity_batch_count"] = 1
	mutations.append(large_island)
	var ccd: Dictionary = base.duplicate(true)
	ccd["ccd_active_body_count"] = 1
	mutations.append(ccd)
	var nonfinite: Dictionary = base.duplicate(true)
	nonfinite["joint_velocity_constraint_exchange_j"] = NAN
	mutations.append(nonfinite)
	var wrong_schema: Dictionary = base.duplicate(true)
	wrong_schema["schema"] = "wrong"
	mutations.append(wrong_schema)
	var rejected := 0
	for mutation in mutations:
		var receipt := (
			WorldScript
			. native_solver_energy_exchange_contract_v1(
				mutation,
				7,
				gravity,
			)
		)
		rejected += int(_zero_world_refusal_v1(receipt))
	return rejected


static func _partition_mutation_rejections_v1() -> int:
	var mutations: Array = []
	var gravity: Dictionary = _partition_inputs_v1(false)
	((gravity["ordered_body_readbacks"] as Array)[0] as Dictionary)["total_gravity_world_m_s2"] = Vector3(
		0.0, -9.7, 0.0
	)
	mutations.append(gravity)
	var damping: Dictionary = _partition_inputs_v1(false)
	((damping["ordered_body_readbacks"] as Array)[0] as Dictionary)["linear_damp"] = 0.01
	mutations.append(damping)
	var ccd: Dictionary = _partition_inputs_v1(false)
	((ccd["ordered_body_readbacks"] as Array)[0] as Dictionary)["continuous_cd"] = true
	mutations.append(ccd)
	var motor: Dictionary = _partition_inputs_v1(false)
	((motor["ordered_joint_readbacks"] as Array)[0] as Dictionary)["motor_enabled"] = true
	mutations.append(motor)
	var mapping: Dictionary = _partition_inputs_v1(false)
	mapping["actuator_mapping_id"] = "wrong"
	mutations.append(mapping)
	var zero_work: Dictionary = _partition_inputs_v1(true)
	zero_work["step_actuator_work_j"] = 0.1
	mutations.append(zero_work)
	var external: Dictionary = _partition_inputs_v1(false)
	external["external_intervention_event_count"] = 1
	mutations.append(external)
	var rejected := 0
	for mutation in mutations:
		var receipt := WorldScript.complete_energy_partition_inputs_contract_v1(mutation)
		rejected += int(_zero_world_refusal_v1(receipt))
	return rejected


static func _application_mutation_rejections_v1() -> int:
	var active_control := {"no_actuation_requested": false}
	var zero_control := {"no_actuation_requested": true}
	var model := {"complete_energy_profile_selected": true}
	var wrong_mapping := _application_receipt_v1(false)
	wrong_mapping["actuator_mapping_id"] = "wrong"
	var motor_enabled := _application_receipt_v1(false)
	motor_enabled["motor_enabled_count"] = 1
	var zero_mutation := _application_receipt_v1(true)
	zero_mutation["physics_state_modified"] = true
	var rejected := 0
	for item in [
		[active_control, model, wrong_mapping],
		[active_control, model, motor_enabled],
		[zero_control, model, zero_mutation],
		[
			active_control,
			{"complete_energy_profile_selected": false},
			_application_receipt_v1(false)
		],
	]:
		var receipt := (
			RouteScript
			. complete_energy_application_receipt_contract_v1(
				item[0],
				item[1],
				item[2],
			)
		)
		rejected += int(_zero_world_refusal_v1(receipt))
	return rejected


static func _binding_mutation_rejections_v1(
	sdk: Object,
	context: Dictionary,
	fixture: Dictionary,
) -> int:
	var rejected := 0
	var incomplete_source: Dictionary = fixture["energy_source_receipt"].duplicate(true)
	incomplete_source["constraint_exchange_partition_complete"] = false
	var incomplete_bound := (
		RouteScript
		. compose_complete_energy_observations_v1(
			sdk,
			context,
			fixture["observation_base"],
			incomplete_source,
			fixture["source_component_receipts"],
		)
	)
	rejected += int(_zero_world_refusal_v1(incomplete_bound))
	var wrong_context: Dictionary = context.duplicate(true)
	wrong_context["complete_energy_profile_selected"] = false
	var cross_bound := (
		RouteScript
		. compose_complete_energy_observations_v1(
			sdk,
			wrong_context,
			fixture["observation_base"],
			fixture["energy_source_receipt"],
			fixture["source_component_receipts"],
		)
	)
	rejected += int(_zero_world_refusal_v1(cross_bound))
	var wrong_observation: Dictionary = (
		(fixture["bound"]["observation_v3"] as Dictionary).duplicate(true)
	)
	(wrong_observation["energy_balance"] as Dictionary)["source_profile_id"] = "wrong"
	rejected += int(
		(
			RouteScript
			. complete_energy_partition_authority_for_observation_v1(
				context,
				wrong_observation,
			)
			. is_empty()
		)
	)
	return rejected


static func _zero_world_refusal_v1(value: Dictionary) -> bool:
	return (
		not bool(value.get("ok", true))
		and int(value.get("model_construction_count", -1)) == 0
		and int(value.get("world_attempt_count", -1)) == 0
		and int(value.get("world_build_count", -1)) == 0
		and int(value.get("solver_step_count", -1)) == 0
		and not bool(value.get("physics_state_modified", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _sha256(sdk: Object, value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	var digest := String(receipt.get("sha256", ""))
	return digest if digest.begins_with("sha256:") and digest.length() == 71 else ""


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d136_godot_complete_energy_partition_zero_world_v1",
		"gate_id": "QSDK-R24D136",
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
