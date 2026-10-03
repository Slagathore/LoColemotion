extends SceneTree
# gdlint: disable=max-line-length

## Compact R144 source/route gate. Every positive and forced-failure case calls
## the same pure contracts used by production. It creates no Node, RID, model,
## world, native write/readback, or solver step.

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
const AUTHORITY_PROFILE_PATH := (
	"res://sdk/recovery/r24d144_godot_jolt_solver_coupled_complete_energy_partition_authority_profile_v1.json"
)
const V4_PATCH_PATH := (
	"res://sdk/adapters/godot/engine_patches/godot_4_7_jolt_solver_energy_exchange_telemetry_v4.patch"
)
const V5_PATCH_PATH := (
	"res://sdk/adapters/godot/engine_patches/godot_4_7_jolt_solver_energy_position_velocity_read_access_v5.patch"
)
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D144_GODOT_SOLVER_COUPLED_COMPLETE_ENERGY_ZERO_WORLD "
const SPACE_STEP_SEQUENCE := 7
const ACTIVE_STEP_MOTOR_WORK_J := 0.5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D144_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D144_GODOT_EXTENSION_INSTANTIATION_FAILED")

	var context := RouteScript.prepare_complete_energy_context_v3(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if not _context_exact_v1(context):
		return _failure("QSDK_R24D144_COMPLETE_CONTEXT_INVALID", context)
	var profile_binding := _authority_profile_binding_v1()
	if not bool(profile_binding.get("ok", false)):
		return _failure("QSDK_R24D144_AUTHORITY_PROFILE_BINDING_INVALID", profile_binding)
	var declaration := WorldScript.solver_coupled_complete_energy_partition_declaration_v1()
	if (
		String(declaration.get("partition_rule_id", "")) != RouteScript.R144_PARTITION_RULE_ID
		or not bool(declaration.get("subtract_native_motor_work_exactly_once", false))
		or bool(declaration.get("motor_work_also_counted_as_constraint_exchange", true))
		or int(declaration.get("numerical_term_count", -1)) != 13
	):
		return _failure("QSDK_R24D144_PARTITION_DECLARATION_POSITIVE_INVALID", declaration)

	var gravity := Vector3(0.0, -9.81, 0.0)
	var solver_telemetry := _solver_telemetry_v1()
	var solver_receipt := WorldScript.native_solver_energy_exchange_contract_v1(
		solver_telemetry, SPACE_STEP_SEQUENCE, gravity
	)
	if not bool(solver_receipt.get("ok", false)):
		return _failure("QSDK_R24D144_SOLVER_CONTRACT_POSITIVE_INVALID", solver_receipt)

	var active_inputs := _partition_inputs_v1(false)
	var active_inputs_receipt := (
		WorldScript.solver_coupled_complete_energy_partition_inputs_contract_v1(
			active_inputs
		)
	)
	var zero_inputs := _partition_inputs_v1(true)
	var zero_inputs_receipt := (
		WorldScript.solver_coupled_complete_energy_partition_inputs_contract_v1(
			zero_inputs
		)
	)
	if (
		not bool(active_inputs_receipt.get("ok", false))
		or int(active_inputs_receipt.get("native_joint_motor_enabled_count", -1)) != 8
		or float(active_inputs_receipt.get("step_actuator_work_j", NAN))
		!= ACTIVE_STEP_MOTOR_WORK_J
		or not bool(zero_inputs_receipt.get("ok", false))
		or int(zero_inputs_receipt.get("native_joint_motor_enabled_count", -1)) != 0
		or float(zero_inputs_receipt.get("step_actuator_work_j", NAN)) != 0.0
	):
		return _failure(
			"QSDK_R24D144_PARTITION_INPUT_POSITIVE_INVALID",
			{"active": active_inputs_receipt, "zero": zero_inputs_receipt},
		)

	var active_motor_receipts := _motor_receipts_v1(false)
	var zero_motor_receipts := _motor_receipts_v1(true)
	var active_partition := WorldScript.solver_coupled_complete_energy_partition_contract_v1(
		solver_receipt,
		active_motor_receipts,
		ACTIVE_STEP_MOTOR_WORK_J,
		SPACE_STEP_SEQUENCE,
		declaration,
	)
	var zero_partition := WorldScript.solver_coupled_complete_energy_partition_contract_v1(
		solver_receipt,
		zero_motor_receipts,
		0.0,
		SPACE_STEP_SEQUENCE,
		declaration,
	)
	var cancelling_motor_receipts := _cancelling_motor_receipts_v1()
	var cancelling_partition := (
		WorldScript.solver_coupled_complete_energy_partition_contract_v1(
			solver_receipt,
			cancelling_motor_receipts,
			ACTIVE_STEP_MOTOR_WORK_J,
			SPACE_STEP_SEQUENCE,
			declaration,
		)
	)
	if (
		not bool(active_partition.get("ok", false))
		or float(active_partition.get("nonmotor_joint_constraint_exchange_j", NAN)) != 0.75
		or not bool(active_partition.get("native_motor_work_subtracted_exactly_once", false))
		or bool(active_partition.get("motor_work_also_counted_as_constraint_exchange", true))
		or absf(float(active_partition.get("partition_reconstruction_delta_j", NAN)))
		> float(active_partition.get("numerical_consistency_bound_j", NAN))
		or not bool(zero_partition.get("ok", false))
		or float(zero_partition.get("step_actuator_work_j", NAN)) != 0.0
		or not bool(cancelling_partition.get("ok", false))
		or float(cancelling_partition.get("step_actuator_work_j", NAN))
		!= ACTIVE_STEP_MOTOR_WORK_J
		or float(cancelling_partition.get("motor_absolute_work_sum_j", NAN)) != 369.5
		or float(cancelling_partition.get("numerical_consistency_bound_j", NAN))
		<= float(active_partition.get("numerical_consistency_bound_j", NAN))
	):
		return _failure(
			"QSDK_R24D144_PARTITION_POSITIVE_INVALID",
			{
				"active": active_partition,
				"zero": zero_partition,
				"cancellation": cancelling_partition,
			},
		)

	var model := {
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
	}
	var active_application := (
		RouteScript.solver_coupled_complete_energy_application_receipt_contract_v1(
			{"no_actuation_requested": false}, model, _application_receipt_v1(false)
		)
	)
	var zero_application := (
		RouteScript.solver_coupled_complete_energy_application_receipt_contract_v1(
			{"no_actuation_requested": true}, model, _application_receipt_v1(true)
		)
	)
	if (
		not bool(active_application.get("ok", false))
		or int(active_application.get("native_joint_motor_enabled_count", -1)) != 8
		or not bool(zero_application.get("ok", false))
		or int(zero_application.get("native_joint_motor_enabled_count", -1)) != 0
	):
		return _failure(
			"QSDK_R24D144_APPLICATION_CONTRACT_POSITIVE_INVALID",
			{"active": active_application, "zero": zero_application},
		)

	var complete_fixture := _complete_fixture_v1(
		sdk,
		context,
		solver_receipt,
		active_inputs_receipt,
		active_partition,
	)
	if not bool(complete_fixture.get("ok", false)):
		return _failure("QSDK_R24D144_COMPLETE_FIXTURE_INVALID", complete_fixture)
	var bound: Dictionary = complete_fixture["bound"]
	var authority := RouteScript.solver_coupled_complete_energy_partition_authority_v1(
		context, bound
	)
	if (
		authority.is_empty()
		or String(authority.get("authority_profile_id", ""))
		!= RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		or String(authority.get("authority_source_sha256", ""))
		!= RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256
		or not bool(authority.get("component_partition_complete", false))
		or not bool(authority.get("exact_balance_safety_authority", false))
		or bool(authority.get("physical_acceptance_authority", true))
		or bool(authority.get("release_authority", true))
	):
		return _failure("QSDK_R24D144_COMPLETE_AUTHORITY_INVALID", authority)

	var initialized := RouteScript.initialize_behavior_arm_v1(
		sdk, context, "candidate_command"
	)
	if not bool(initialized.get("ok", false)):
		return _failure("QSDK_R24D144_INITIALIZATION_INVALID", initialized)
	var advanced := RouteScript.advance_behavior_solver_coupled_complete_energy_v1(
		sdk,
		context,
		bound,
		initialized["memory"],
		"candidate_command",
		"confirm_prone",
	)
	var progression: Dictionary = advanced.get("development_progression_receipt", {})
	if (
		not bool(advanced.get("ok", false))
		or String(advanced.get("schema_version", ""))
		!= "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_behavior_advance_v1"
		or String(progression.get("authority_profile_id", ""))
		!= RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		or not bool(progression.get("component_partition_complete", false))
		or not bool(progression.get("exact_balance_safety_authority", false))
		or bool(progression.get("development_progression_permitted", true))
		or not bool(progression.get("stable_stance_completion_authorized", false))
		or bool(progression.get("prone_to_standing_claimed", true))
		or bool(progression.get("physical_acceptance_authority", true))
		or bool(progression.get("release_authority", true))
	):
		return _failure("QSDK_R24D144_COMPLETE_ADVANCE_INVALID", advanced)

	var solver_mutation_rejections := _solver_mutation_rejections_v1(
		solver_telemetry, gravity
	)
	var input_mutation_rejections := _input_mutation_rejections_v1()
	var partition_mutation_rejections := _partition_mutation_rejections_v1(
		solver_receipt, active_motor_receipts, declaration
	)
	var application_mutation_rejections := _application_mutation_rejections_v1()
	var binding_mutation_rejections := _binding_mutation_rejections_v1(
		sdk, context, complete_fixture
	)
	var forced_failure_case_count := (
		solver_mutation_rejections
		+ input_mutation_rejections
		+ partition_mutation_rejections
		+ application_mutation_rejections
		+ binding_mutation_rejections
	)
	var expected_forced_failure_case_count := 27
	var positive_case_count := 14
	var exact: bool = (
		forced_failure_case_count == expected_forced_failure_case_count
		and int(advanced.get("model_construction_count", -1)) == 0
		and int(advanced.get("world_attempt_count", -1)) == 0
		and int(advanced.get("world_build_count", -1)) == 0
		and int(advanced.get("solver_step_count", -1)) == 0
		and not bool(advanced.get("physics_state_modified", true))
	)
	return {
		"schema_version": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_zero_world_v1",
		"gate_id": "QSDK-R24D144",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D144_ZERO_WORLD_CONJUNCTION_INVALID",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_zero_world_implementation_qualification",
			"question_class": "development",
		},
		"question_class": "development",
		"runtime_profile_id": ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"capability_variant_id": (
			ProfileScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		),
		"authority_profile_id": RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"authority_source_sha256": RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256,
		"authority_profile_source_bound": true,
		"authority_profile_byte_length": int(profile_binding["byte_length"]),
		"energy_route_id": RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"actuation_realization_id": RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"actuator_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": RouteScript.R144_PARTITION_RULE_ID,
		"native_motor_work_subtracted_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"constraint_exchange_partition_complete": true,
		"passive_dissipation_partition_complete": true,
		"component_partition_complete": true,
		"exact_balance_safety_authority": true,
		"stable_stance_completion_authorized": true,
		"solver_mutation_rejection_count": solver_mutation_rejections,
		"input_mutation_rejection_count": input_mutation_rejections,
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


static func _authority_profile_binding_v1() -> Dictionary:
	if not FileAccess.file_exists(AUTHORITY_PROFILE_PATH):
		return {"ok": false, "failure_code": "PROFILE_MISSING"}
	var raw_sha256 := "sha256:%s" % FileAccess.get_sha256(AUTHORITY_PROFILE_PATH).to_lower()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTHORITY_PROFILE_PATH))
	if not (parsed is Dictionary):
		return {"ok": false, "failure_code": "PROFILE_JSON_INVALID"}
	var profile: Dictionary = parsed
	var identity: Dictionary = profile.get("profile_identity", {})
	var source: Dictionary = profile.get("native_source_provenance", {})
	var energy_capability: Dictionary = profile.get("energy_capability_mapping", {})
	var numerical: Dictionary = profile.get("numerical_adequacy", {})
	var claims: Dictionary = profile.get("authority_claims", {})
	var qualification: Dictionary = profile.get("qualification_boundary", {})
	var exact: bool = (
		raw_sha256 == RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256
		and FileAccess.file_exists(V4_PATCH_PATH)
		and FileAccess.file_exists(V5_PATCH_PATH)
		and String(profile.get("gate_id", "")) == "QSDK-R24D144"
		and String(profile.get("question_class", "")) == "development"
		and String(identity.get("authority_profile_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		and String(identity.get("runtime_profile_id", ""))
		== "godot_4_7_jolt_sporespore_solver_energy_position_velocity_read_access_v5"
		and String(identity.get("telemetry_profile_id", ""))
		== ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		and String(identity.get("capability_variant_id", ""))
		== ProfileScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		and String(identity.get("collector_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_COLLECTOR_ID
		and String(identity.get("route_id", "")) == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
		and String(identity.get("energy_source_profile_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(identity.get("actuation_realization_id", ""))
		== RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		and String(identity.get("actuator_mapping_id", ""))
		== RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		and String(identity.get("work_mapping_id", ""))
		== RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
		and String(identity.get("partition_rule_id", "")) == RouteScript.R144_PARTITION_RULE_ID
		and String(source.get("console_binary_raw_sha256", ""))
		== "sha256:8e07937dcbccf5f71356df5ac487616eb1f66025d37d73d770f82ffa47a578a0"
		and String(source.get("engine_binary_raw_sha256", ""))
		== "sha256:fc8f7d0bece7c1d90d16ceb28d6f4ee8b3cd43facafa3494d51c8753a3bdd72b"
		and String(source.get("cumulative_patch_raw_sha256", ""))
		== "sha256:%s" % FileAccess.get_sha256(V4_PATCH_PATH).to_lower()
		and String(source.get("position_velocity_read_access_patch_raw_sha256", ""))
		== "sha256:%s" % FileAccess.get_sha256(V5_PATCH_PATH).to_lower()
		and String(source.get("motor_schema", ""))
		== "sporespore.godot_jolt_hinge_motor_telemetry.v2"
		and String(source.get("solver_schema", ""))
		== "sporespore.godot_jolt_solver_energy_exchange_telemetry.v1"
		and String(energy_capability.get("changed_channel", "")) == "energy_balance_ledger"
		and int(energy_capability.get("changed_channel_count", -1)) == 1
		and String(energy_capability.get("mapping_id", ""))
		== ProfileScript.SOLVER_COUPLED_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and energy_capability.get("host_source_ids", [])
		== ProfileScript.SOLVER_COUPLED_COMPLETE_ENERGY_BALANCE_SOURCE_RECORD["sources"]
		and bool(energy_capability.get("all_non_energy_channels_preserved_exactly", false))
		and not bool(energy_capability.get("runtime_binary_pair_changed", true))
		and not bool(energy_capability.get("telemetry_profile_changed", true))
		and String(numerical.get("bound_kind", ""))
		== "deterministic_ieee754_binary32_forward_error_bound"
		and float(numerical.get("epsilon", NAN)) == WorldScript.NATIVE_FLOAT32_EPSILON
		and int(numerical.get("term_count", -1))
		== WorldScript.R144_PARTITION_NUMERICAL_TERM_COUNT
		and String(numerical.get("absolute_term_sum_basis", "")).contains(
			"cancellation_in_the_motor_work_aggregate_cannot_reduce_the_bound"
		)
		and not bool(numerical.get("empirical_threshold_selected", true))
		and not bool(numerical.get("existing_energy_balance_residual_threshold_changed", true))
		and bool(claims.get("component_partition_complete", false))
		and bool(claims.get("exact_balance_safety_authority", false))
		and not bool(claims.get("residual_balancing_permitted", true))
		and not bool(claims.get("physical_acceptance_authority", true))
		and not bool(claims.get("release_authority", true))
		and bool(qualification.get("zero_world_source_and_route_qualification_required_before_physics", false))
		and not bool(qualification.get("physical_execution_authorized_by_this_profile", true))
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "PROFILE_SEMANTICS_INVALID",
		"path": AUTHORITY_PROFILE_PATH,
		"raw_sha256": raw_sha256,
		"byte_length": FileAccess.get_file_as_bytes(AUTHORITY_PROFILE_PATH).size(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _context_exact_v1(context: Dictionary) -> bool:
	var runtime_binding: Dictionary = context.get("runtime_binding", {})
	var profile_receipt: Dictionary = context.get("runtime_profile_receipt", {})
	var validation: Dictionary = profile_receipt.get("validation", {})
	var capability: Dictionary = context.get("capability", {})
	return (
		bool(context.get("ok", false))
		and bool(context.get("complete_energy_profile_selected", false))
		and bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		and String(context.get("energy_route_id", "")) == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
		and String(context.get("energy_mapping_profile_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(context.get("partition_rule_id", "")) == RouteScript.R144_PARTITION_RULE_ID
		and String(context.get("capability_variant_id", ""))
		== ProfileScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		and String(context.get("adapter_energy_mapping_profile_id", ""))
		== ProfileScript.SOLVER_COUPLED_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and capability == ProfileScript.solver_coupled_complete_energy_capability_v1()
		and profile_receipt.get("capability", {}) == capability
		and bool(validation.get("ok", false))
		and int(validation.get("changed_channel_count", -1)) == 1
		and validation.get("changed_channel_ids", []) == ["energy_balance_ledger"]
		and String(context.get("required_active_actuator_mapping_id", ""))
		== WorldScript.R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID
		and String(context.get("required_active_work_mapping_id", ""))
		== WorldScript.R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID
		and String(runtime_binding.get("runtime_profile_id", ""))
		== ProfileScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		and String(runtime_binding.get("collector_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_COLLECTOR_ID
	)


static func _solver_telemetry_v1() -> Dictionary:
	return {
		"schema": "sporespore.godot_jolt_solver_energy_exchange_telemetry.v1",
		"profile_id": "godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v1",
		"telemetry_sequence": SPACE_STEP_SEQUENCE,
		"capture_space_step_sequence": SPACE_STEP_SEQUENCE,
		"read_space_step_sequence": SPACE_STEP_SEQUENCE,
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
		bodies.append(
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
	var joints: Array = []
	for joint_id_value in WorldScript.ORDERED_JOINT_IDS:
		joints.append(
			{
				"joint_id": String(joint_id_value),
				"motor_enabled": not no_actuation_requested,
			}
		)
	return {
		"semantic_step": 1,
		"ordered_body_readbacks": bodies,
		"ordered_joint_readbacks": joints,
		"no_actuation_requested": no_actuation_requested,
		"actuator_mapping_id": (
			""
			if no_actuation_requested
			else RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		),
		"work_mapping_id": (
			"" if no_actuation_requested else RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
		),
		"step_actuator_work_j": 0.0 if no_actuation_requested else ACTIVE_STEP_MOTOR_WORK_J,
		"external_intervention_event_count": 0,
		"step_signed_external_work_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"step_signed_discrete_staging_exchange_j": 0.0,
	}


static func _motor_receipts_v1(zero_work: bool) -> Array:
	var rows: Array = []
	for index in range(WorldScript.ORDERED_ACTUATOR_IDS.size()):
		rows.append(
			{
				"actuator_id": String(WorldScript.ORDERED_ACTUATOR_IDS[index]),
				"joint_id": String(WorldScript.ORDERED_JOINT_IDS[index]),
				"actuator_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
				"work_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
				"capture_space_step_sequence": SPACE_STEP_SEQUENCE,
				"read_space_step_sequence": SPACE_STEP_SEQUENCE,
				"net_motor_work_j": 0.0 if zero_work else 0.0625,
				"source_measurement": true,
				"mechanical_energy_residual_used_as_work_source": false,
			}
		)
	return rows


static func _cancelling_motor_receipts_v1() -> Array:
	var rows := _motor_receipts_v1(false)
	var values := [100.0, -100.0, 50.0, -50.0, 25.0, -25.0, 10.0, -9.5]
	for index in range(rows.size()):
		(rows[index] as Dictionary)["net_motor_work_j"] = values[index]
	return rows


static func _application_receipt_v1(no_actuation_requested: bool) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d65_godot_command_application_receipt_v1"
			if no_actuation_requested
			else "sporespore_qsdk_r24d57_godot_command_application_receipt_v1"
		),
		"ok": true,
		"motor_enabled_count": 0 if no_actuation_requested else 8,
		"host_write_count": 8,
		"host_readback_count": 8,
		"host_constraint_configuration_write_count": 8,
		"active_constraint_motor_configuration_modified": not no_actuation_requested,
		"pre_solver_rigid_body_state_modified": false,
		"solver_state_advanced": false,
		"physics_state_modified": not no_actuation_requested,
		"solver_step_count": 0,
		"adapter_side_discrete_staging_event_count": 0,
		"actuation_realization_id": RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"application_mutation_semantics_id": RouteScript.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID,
		"native_contact_solver_coupled": true,
		"pre_solver_direct_body_impulse_write_count": 0,
		"controller_realization_identity_checked": true,
		"application_mutation_semantics_checked": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _complete_fixture_v1(
	sdk: Object,
	context: Dictionary,
	solver_receipt: Dictionary,
	inputs_receipt: Dictionary,
	partition_receipt: Dictionary,
) -> Dictionary:
	var predecessor := (
		RouteScript.zero_world_fixture_solver_coupled_complete_energy_v1(sdk, context)
	)
	if not bool(predecessor.get("ok", false)):
		return _failure("QSDK_R24D144_PREDECESSOR_FIXTURE_INVALID", predecessor)
	var observation_base: Dictionary = (predecessor["observation_v3"] as Dictionary).duplicate(true)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	var solver_sha256 := _sha256(sdk, solver_receipt)
	var inputs_sha256 := _sha256(sdk, inputs_receipt)
	var partition_sha256 := _sha256(sdk, partition_receipt)
	if solver_sha256.is_empty() or inputs_sha256.is_empty() or partition_sha256.is_empty():
		return _failure("QSDK_R24D144_FIXTURE_DIGEST_INVALID")
	var actuator_work := float(partition_receipt["step_actuator_work_j"])
	var constraint_exchange := float(partition_receipt["step_signed_constraint_exchange_j"])
	var energy_source := {
		"schema_version": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_receipt_v1",
		"semantic_step": 1,
		"initial_mechanical_energy_j": 20.0,
		"current_mechanical_energy_j": 20.0 + actuator_work + constraint_exchange,
		"cumulative_applied_actuator_work_j": actuator_work,
		"cumulative_signed_external_work_j": 0.0,
		"cumulative_signed_constraint_exchange_j": constraint_exchange,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"cumulative_passive_dissipation_j": 0.0,
		"step_signed_constraint_exchange_j": constraint_exchange,
		"step_position_constraint_potential_exchange_j": float(
			partition_receipt["position_constraint_potential_exchange_j"]
		),
		"adapter_side_discrete_staging_event_count": 0,
		"solver_energy_exchange_receipt_sha256": solver_sha256,
		"solver_coupled_partition_receipt_sha256": partition_sha256,
		"world_energy_configuration_receipt_sha256": inputs_sha256,
		"actuator_constraint_disjointness_receipt_sha256": partition_sha256,
		"partition_rule_id": RouteScript.R144_PARTITION_RULE_ID,
		"raw_step_signed_solver_exchange_j": float(
			partition_receipt["raw_step_signed_solver_exchange_j"]
		),
		"step_actuator_work_j": actuator_work,
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
		"schema_version": "sporespore_qsdk_r24d144_zero_world_source_components_v1",
		"semantic_step": 1,
		"solver_energy_exchange_receipt": solver_receipt.duplicate(true),
		"complete_energy_inputs_receipt": inputs_receipt.duplicate(true),
		"solver_coupled_partition_receipt": partition_receipt.duplicate(true),
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	var bound := RouteScript.compose_solver_coupled_complete_energy_observations_v1(
		sdk, context, observation_base, energy_source, components
	)
	if not bool(bound.get("ok", false)):
		return _failure("QSDK_R24D144_COMPLETE_COMPOSITION_INVALID", bound)
	return {
		"ok": true,
		"bound": bound,
		"observation_base": observation_base,
		"energy_source_receipt": energy_source,
		"source_component_receipts": components,
	}


static func _solver_mutation_rejections_v1(base: Dictionary, gravity: Vector3) -> int:
	var mutations: Array = []
	var stale := base.duplicate(true)
	stale["capture_space_step_sequence"] = SPACE_STEP_SEQUENCE - 1
	mutations.append(stale)
	var incomplete := base.duplicate(true)
	incomplete["complete"] = false
	mutations.append(incomplete)
	var nonfinite := base.duplicate(true)
	nonfinite["joint_velocity_constraint_exchange_j"] = NAN
	mutations.append(nonfinite)
	var rejected := 0
	for mutation in mutations:
		var receipt := WorldScript.native_solver_energy_exchange_contract_v1(
			mutation, SPACE_STEP_SEQUENCE, gravity
		)
		rejected += int(_zero_world_refusal_v1(receipt))
	return rejected


static func _input_mutation_rejections_v1() -> int:
	var mutations: Array = []
	var motor := _partition_inputs_v1(false)
	((motor["ordered_joint_readbacks"] as Array)[0] as Dictionary)["motor_enabled"] = false
	mutations.append(motor)
	var mapping := _partition_inputs_v1(false)
	mapping["actuator_mapping_id"] = "wrong"
	mutations.append(mapping)
	var zero_work := _partition_inputs_v1(true)
	zero_work["step_actuator_work_j"] = 0.1
	mutations.append(zero_work)
	var damping := _partition_inputs_v1(false)
	((damping["ordered_body_readbacks"] as Array)[0] as Dictionary)["linear_damp"] = 0.01
	mutations.append(damping)
	var external := _partition_inputs_v1(false)
	external["external_intervention_event_count"] = 1
	mutations.append(external)
	var rejected := 0
	for mutation in mutations:
		var receipt := (
			WorldScript.solver_coupled_complete_energy_partition_inputs_contract_v1(
				mutation
			)
		)
		rejected += int(_zero_world_refusal_v1(receipt))
	return rejected


static func _partition_mutation_rejections_v1(
	solver_receipt: Dictionary,
	motor_receipts: Array,
	declaration: Dictionary,
) -> int:
	var rejected := 0
	var missing_motor := motor_receipts.duplicate(true)
	missing_motor.pop_back()
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_contract_v1(
				solver_receipt, missing_motor, ACTIVE_STEP_MOTOR_WORK_J, SPACE_STEP_SEQUENCE, declaration
			)
		)
	)
	var stale_motor := motor_receipts.duplicate(true)
	(stale_motor[0] as Dictionary)["capture_space_step_sequence"] = SPACE_STEP_SEQUENCE - 1
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_contract_v1(
				solver_receipt, stale_motor, ACTIVE_STEP_MOTOR_WORK_J, SPACE_STEP_SEQUENCE, declaration
			)
		)
	)
	var nonfinite_motor := motor_receipts.duplicate(true)
	(nonfinite_motor[0] as Dictionary)["net_motor_work_j"] = NAN
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_contract_v1(
				solver_receipt, nonfinite_motor, ACTIVE_STEP_MOTOR_WORK_J, SPACE_STEP_SEQUENCE, declaration
			)
		)
	)
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_contract_v1(
				solver_receipt, motor_receipts, 0.25, SPACE_STEP_SEQUENCE, declaration
			)
		)
	)
	for key in [
		"joint_velocity_exchange_includes_native_motor_work",
		"subtract_native_motor_work_exactly_once",
		"motor_work_also_counted_as_constraint_exchange",
		"whole_step_mechanical_residual_used_as_work_source",
	]:
		var mutation := declaration.duplicate(true)
		mutation[key] = not bool(mutation[key])
		rejected += int(
			_zero_world_refusal_v1(
				WorldScript.solver_coupled_complete_energy_partition_contract_v1(
					solver_receipt,
					motor_receipts,
					ACTIVE_STEP_MOTOR_WORK_J,
					SPACE_STEP_SEQUENCE,
					mutation,
				)
			)
		)
	var wrong_total := solver_receipt.duplicate(true)
	wrong_total["step_signed_constraint_exchange_j"] = float(
		wrong_total["step_signed_constraint_exchange_j"]
	) + 0.25
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_contract_v1(
				wrong_total,
				motor_receipts,
				ACTIVE_STEP_MOTOR_WORK_J,
				SPACE_STEP_SEQUENCE,
				declaration,
			)
		)
	)
	var wrong_mapping := motor_receipts.duplicate(true)
	(wrong_mapping[0] as Dictionary)["work_mapping_id"] = "wrong"
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_contract_v1(
				solver_receipt,
				wrong_mapping,
				ACTIVE_STEP_MOTOR_WORK_J,
				SPACE_STEP_SEQUENCE,
				declaration,
			)
		)
	)
	return rejected


static func _application_mutation_rejections_v1() -> int:
	var active_control := {"no_actuation_requested": false}
	var model := {
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
	}
	var mutations: Array = []
	var motor_count := _application_receipt_v1(false)
	motor_count["motor_enabled_count"] = 7
	mutations.append([active_control, model, motor_count])
	var realization := _application_receipt_v1(false)
	realization["actuation_realization_id"] = "wrong"
	mutations.append([active_control, model, realization])
	var mutation_scope := _application_receipt_v1(false)
	mutation_scope["physics_state_modified"] = false
	mutations.append([active_control, model, mutation_scope])
	mutations.append(
		[
			active_control,
			{
				"complete_energy_profile_selected": true,
				"solver_coupled_complete_energy_profile_selected": false,
			},
			_application_receipt_v1(false),
		]
	)
	var body_impulse := _application_receipt_v1(false)
	body_impulse["body_impulse_write_count"] = 1
	mutations.append([active_control, model, body_impulse])
	var rejected := 0
	for item in mutations:
		var receipt := (
			RouteScript.solver_coupled_complete_energy_application_receipt_contract_v1(
				item[0], item[1], item[2]
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
	var overlap_source: Dictionary = fixture["energy_source_receipt"].duplicate(true)
	overlap_source["motor_work_also_counted_as_constraint_exchange"] = true
	var overlap_bound := RouteScript.compose_solver_coupled_complete_energy_observations_v1(
		sdk,
		context,
		fixture["observation_base"],
		overlap_source,
		fixture["source_component_receipts"],
	)
	rejected += int(_zero_world_refusal_v1(overlap_bound))
	var wrong_context := context.duplicate(true)
	wrong_context["energy_route_id"] = RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
	var cross_bound := RouteScript.compose_solver_coupled_complete_energy_observations_v1(
		sdk,
		wrong_context,
		fixture["observation_base"],
		fixture["energy_source_receipt"],
		fixture["source_component_receipts"],
	)
	rejected += int(_zero_world_refusal_v1(cross_bound))
	var fixture_bound: Dictionary = fixture["bound"]
	var wrong_capability_context := context.duplicate(true)
	var wrong_capability_channels: Array = (
		(wrong_capability_context["capability"] as Dictionary)["ordered_channels"]
	)
	(wrong_capability_channels[ProfileScript.ENERGY_BALANCE_CHANNEL_INDEX] as Dictionary)[
		"mapping_rule_id"
	] = "godot_jolt_r24d136_complete_solver_energy_partition_projection_v1"
	var wrong_capability_bound := (
		RouteScript.compose_solver_coupled_complete_energy_observations_v1(
			sdk,
			wrong_capability_context,
			fixture["observation_base"],
			fixture["energy_source_receipt"],
			fixture["source_component_receipts"],
		)
	)
	rejected += int(_zero_world_refusal_v1(wrong_capability_bound))
	var wrong_observation := (
		(fixture_bound["observation_v3"] as Dictionary).duplicate(true)
	)
	(wrong_observation["energy_balance"] as Dictionary)["source_profile_id"] = (
		RouteScript.R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	rejected += int(
		RouteScript.solver_coupled_complete_energy_partition_authority_for_observation_v1(
			context, wrong_observation
		).is_empty()
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
		"schema_version": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_zero_world_v1",
		"gate_id": "QSDK-R24D144",
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
