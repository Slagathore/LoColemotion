class_name SporeGodotRecoveryNativeRouteV1
extends RefCounted
# gdlint: disable=max-line-length

## Exact Godot/Jolt recovery transport and command-application route.
##
## The sibling native-world module supplies complete direct-state, contact, and
## instrumented-telemetry measurements. This module binds those fields to the
## qualified profile, constructs the portable V2 source chain, projects the
## same sample into energy V3, invokes the portable supervisor/controller, and
## validates all eight hinge writes before changing any body or joint. World
## construction and stepping remain explicit caller operations; this route
## never hides a physical step or substitutes a missing measurement.

const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const DevelopmentStanceProfile := preload("res://sdk/adapters/godot/gdscript/development_recovery_stance_profile_v1.gd")
const CollectionTransportL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd"
)
const CanonicalOwnershipL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd"
)
const ProfileCapabilityScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
)
const ActuatorBindingScript := preload(
	"res://sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd"
)
const NativeWorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const DiscreteStagingRouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const ContiguousBoundaryTransportScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)

const ROUTE_ID := "sporespore_qsdk_r24d57_godot_jolt_recovery_observation_v3_route_v1"
const ENERGY_MAPPING_PROFILE_ID := "godot_jolt_r24d57_native_recovery_energy_mapping_v1"
const R126_DEVELOPMENT_ROUTE_ID := "sporespore_qsdk_r24d126_godot_jolt_incomplete_energy_development_route_v1"
const R126_ENERGY_AUTHORITY_PROFILE_ID := "godot_jolt_r24d126_incomplete_energy_partition_authority_v1"
const R126_ENERGY_AUTHORITY_SOURCE_SHA256 := "sha256:da405c692776564d091c4be0e4adf282e720445b0859738b139fc2cdd0c60da6"
const R136_COMPLETE_ENERGY_ROUTE_ID := "sporespore_qsdk_r24d136_godot_jolt_complete_energy_recovery_observation_v3_route_v1"
const R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID := "godot_jolt_r24d136_complete_native_recovery_energy_mapping_v1"
const R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID := "godot_jolt_r24d136_complete_energy_partition_authority_v1"
const R136_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256 := "sha256:b5daccd4d59052820954824dcbb30c3caabb6ff614b8470c4036d77d39670518"
const R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID := "godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1"
const R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID := "godot_jolt_r24d129_solver_coupled_constraint_configuration_mutation_v1"
const ENERGY_COMPONENT_PARTITION_V3_ID := "sporespore_disjoint_actuator_external_constraint_discrete_staging_passive_energy_partition_v3"
const ADAPTER_ID := "sporespore_godot_jolt_adapter"
const ENGINE_ID := "godot_jolt4_7"
const COLLECTOR_ID := "sporespore_godot_jolt_motor_and_solved_contact_v3_recovery_collector_v1"
const R136_COMPLETE_ENERGY_COLLECTOR_ID := "sporespore_godot_jolt_complete_energy_v4_recovery_collector_v1"
const R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID := "godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_joint_impulse_v1"
const R136_REQUIRED_ACTIVE_WORK_MAPPING_ID := "godot_jolt_r24d109_order_neutral_joint_space_effective_inertia_population_guarded_centered_joint_work_v1"
const R137_COMPLETE_ENERGY_ACTUATION_REALIZATION_ID := "godot_jolt_r24d137_complete_energy_r109_force_based_realization_v1"
const R144_COMPLETE_ENERGY_ROUTE_ID := "sporespore_qsdk_r24d144_godot_jolt_solver_coupled_complete_energy_recovery_observation_v3_route_v1"
const R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID := "godot_jolt_r24d144_solver_coupled_complete_native_recovery_energy_mapping_v1"
const R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID := "godot_jolt_r24d144_solver_coupled_complete_energy_partition_authority_v1"
const R144_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256 := "sha256:1583fb7c1652104a07a24378ed62bf390215d831b033ea5e2b1c2a2c45644858"
const R144_COMPLETE_ENERGY_COLLECTOR_ID := "sporespore_godot_jolt_solver_coupled_complete_energy_v4_recovery_collector_v1"
const R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID := "godot_jolt_r24d144_solver_coupled_native_constraint_motor_mapping_v1"
const R144_REQUIRED_ACTIVE_WORK_MAPPING_ID := "godot_jolt_r24d144_current_step_native_hinge_motor_work_mapping_v1"
const R144_PARTITION_RULE_ID := "godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1"
const R148_COMPLETE_ENERGY_ROUTE_ID := DiscreteStagingRouteScript.ROUTE_ID
const R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID := DiscreteStagingRouteScript.MAPPING_PROFILE_ID
const R148_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID := DiscreteStagingRouteScript.AUTHORITY_PROFILE_ID
const R148_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256 := "sha256:d09eb73bbb8073c3b7c5b36744ed36acb566cbc66bf8063582099063917a0330"
const R148_COMPLETE_ENERGY_COLLECTOR_ID := DiscreteStagingRouteScript.COLLECTOR_ID
const R148_STAGING_RULE_ID := "godot_jolt_gravity_force_and_position_staging_exchange_v1"
const R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID := "godot_jolt_r24d151_commissioned_discrete_staging_complete_energy_partition_authority_v1"
const R151_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256 := "sha256:75e587a17fb599986051b6627f0977d791d041b3f7b15ee5faf19d782641b95c"
const R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID := (
	"godot_jolt_r24d152_route_aware_discrete_staging_application_provenance_v1"
)
const R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID := (
	"godot_jolt_r24d154_accumulator_aware_discrete_staging_in_run_invariant_validator_v2"
)
const R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID := (
	"godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1"
)
const R162_ROTATION_AWARE_CAPABILITY_VARIANT_ID := (
	"godot_jolt_r24d162_rotation_aware_discrete_staging_complete_energy_capability_v1"
)
const R162_ROTATION_AWARE_COLLECTOR_ID := (
	"sporespore_godot_jolt_rotation_aware_complete_energy_v6_recovery_collector_v1"
)
const R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA := (
	"sporespore_qsdk_r24d157_godot_solver_energy_exchange_contract_v2"
)
const R162_SOLVER_ENERGY_TELEMETRY_SCHEMA := (
	"sporespore.godot_jolt_solver_energy_exchange_telemetry.v2"
)
const R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID := (
	"godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v6"
)
const R162_ROTATION_AWARE_PARTITION_CONTRACT_SCHEMA := (
	"sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_energy_partition_contract_v1"
)
const R162_ROTATION_AWARE_SOURCE_RECEIPT_SCHEMA := (
	"sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_energy_source_receipt_v1"
)
const R162_ROTATION_AWARE_COMPONENT_RECEIPTS_SCHEMA := (
	"sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_source_component_receipts_v1"
)
const R162_R161_DIAGNOSIS_RAW_SHA256 := (
	"sha256:1f163c137f04b180ebbddbd4774641d54ac145e46bd302a607ea551d6a61984e"
)
const R163_ROTATION_AWARE_ROUTE_GHOST_PROFILE_ID := (
	"godot_jolt_r24d163_rotation_aware_recovery_ledger_two_step_integration_ghost_v1"
)
const R164_ROTATION_AWARE_FINITE_BEHAVIOR_PROFILE_ID := (
	"godot_jolt_r24d164_rotation_aware_recovery_ledger_finite_behavior_pair_v1"
)
const R165_ROTATION_AWARE_SOURCE_TRACE_VALIDATOR_PROFILE_ID := (
	"godot_jolt_r24d165_rotation_aware_native_source_trace_schema_validator_v1"
)
const R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID := (
	ContiguousBoundaryTransportScript.TRANSPORT_PROFILE_ID
)
const R168_R167_TRANSPORT_DESIGN_RAW_SHA256 := (
	"sha256:c44789a252976208aace4b541e2030564a38399df2e5facbbb00586ccb70e775"
)
const R169_CONTIGUOUS_BOUNDARY_ROUTE_GHOST_PROFILE_ID := (
	"godot_jolt_r24d169_contiguous_boundary_transport_two_step_route_ghost_v1"
)
const R169_R168_ZERO_WORLD_CLOSURE_RAW_SHA256 := (
	"sha256:bee6cb165a15c86d2bb8eabe2c4a3a36672a63fd60ec26b919e90ef15e7bde6c"
)
const R170_CONTIGUOUS_BOUNDARY_RECOVERY_BEHAVIOR_PROFILE_ID := (
	"godot_jolt_r24d170_contiguous_boundary_rotation_aware_recovery_finite_behavior_pair_v1"
)
const R170_R165_PHYSICAL_CLOSURE_RAW_SHA256 := (
	"sha256:ee9637e48f416ad178a30404e019892b9bb0e5291bc1b58741b1a35052fba6a4"
)
const R170_R169_PHYSICAL_CLOSURE_RAW_SHA256 := (
	"sha256:1a95e5788a8c367d089941df4dc6bdc071c568f0b7bffd6e2e2374f514a4b1df"
)
const R172_INITIALIZER_RETENTION_RECOVERY_BEHAVIOR_PROFILE_ID := (
	"godot_jolt_r24d172_initializer_receipt_retention_contiguous_boundary_recovery_finite_behavior_pair_v1"
)
const R172_R170_PHYSICAL_CLOSURE_RAW_SHA256 := (
	"sha256:cf1f476f88f9a82ca934306c25b6d0684d693971dbaa9f1192de2d7d6539d3b7"
)
const R172_R171_ZERO_WORLD_CLOSURE_RAW_SHA256 := (
	"sha256:e9b390e496c4e357dd1e938c4e6f34554f1dc0b0a8f3147c098d2f98c7db3627"
)
const R149_LIVE_BOUNDARY_TRANSPORT_ID := "godot_jolt_r24d149_pre_callback_to_post_solver_body_boundary_transport_v1"
const TASK_ID := "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
const SEMANTICS_ID := "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
const ACTUATOR_PROFILE_ID := "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
const ACTUATOR_PROFILE_SHA256 := "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
const THRESHOLD_PROFILE_ID := "sporespore_exact_s169_recovery_development_thresholds_v1"
const RECOVERY_CONTROLLER_ID := "sporespore_exact_s169_prone_to_standing_controller_v1"
const RECOVERY_CONTROLLER_V2_ID := "sporespore_exact_s169_prone_to_standing_controller_v2"
const RECOVERY_CONTROLLER_V3_ID := "sporespore_exact_s169_prone_to_standing_controller_v3"
const RECOVERY_CONTROLLER_V4_ID := "sporespore_exact_s169_prone_to_standing_controller_v4"
const RECOVERY_CONTROLLER_V5_ID := "sporespore_exact_s169_prone_to_standing_controller_v5"
const RECOVERY_CONTROLLER_V6_ID := "sporespore_exact_s169_prone_to_standing_controller_v6"
const RECOVERY_CONTROLLER_V7_ID := "sporespore_exact_s169_prone_to_standing_controller_v7"
const RECOVERY_CONTROLLER_V8_ID := "sporespore_exact_s169_prone_to_standing_controller_v8"
const STANCE_CONTROLLER_ID := "sporespore_exact_s169_stance_handoff_controller_v1"
const RECOVERY_MORPHOLOGY_ID := "qsdk_r24_recovery_s169_v1"
const RECOVERY_DESCRIPTOR_SHA256 := "sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6"
const BASE_DESCRIPTOR_SHA256 := "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
const BASE_MORPHOLOGY_SPEC_SHA256 := "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
const RECOVERY_MORPHOLOGY_SPEC_SHA256 := "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"
const OUTER_STEP_DURATION_S := 1.0 / 120.0
const LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN := -1.0
const HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND := 1.1920928955078125e-7
const HOST_REAL_BINARY32_MINIMUM_SUBNORMAL := 1.401298464324817e-45

const ORDERED_ACTUATOR_IDS := [
	"front_left_hip_motor",
	"front_left_knee_motor",
	"front_right_hip_motor",
	"front_right_knee_motor",
	"rear_left_hip_motor",
	"rear_left_knee_motor",
	"rear_right_hip_motor",
	"rear_right_knee_motor",
]
const ORDERED_JOINT_IDS := [
	"front_left_hip",
	"front_left_knee",
	"front_right_hip",
	"front_right_knee",
	"rear_left_hip",
	"rear_left_knee",
	"rear_right_hip",
	"rear_right_knee",
]
const ORDERED_CONTACT_SITE_IDS := [
	"front_left_foot",
	"front_right_foot",
	"rear_left_foot",
	"rear_right_foot",
]
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
const ORDERED_CAPS_NMS := [
	0.05362625170687301,
	0.4567500054836273,
	0.05362625170687301,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
]


static func exact_base_descriptor_v1() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "qsdk_r05_generated_s169",
		"torso_length_scale": 1.0041015625,
		"torso_width_scale": 1.0031893004115227,
		"upper_length_fraction": 0.5219571428571428,
		"hip_span_scale": 0.9856413994169096,
		"foot_radius_scale": 0.9987180691209617,
		"front_limb_mass_scale": 0.975022758306782,
	}


static func exact_recovery_descriptor_v1() -> Dictionary:
	return {
		"schema_version": "sporespore_recovery_morphology_descriptor_v1",
		"recovery_morphology_id": RECOVERY_MORPHOLOGY_ID,
		"base_descriptor": exact_base_descriptor_v1(),
		"joint_authority":
		{
			"hip_anchor_parent_y_m": 0.0,
			"hip_limit_magnitude_rad": 1.6,
			"knee_limit_magnitude_rad": 1.1,
		},
		"canonical_prone_pose":
		{
			"front_hip_angle_rad": 1.55,
			"front_knee_angle_rad": 1.1,
			"rear_hip_angle_rad": -1.55,
			"rear_knee_angle_rad": -1.1,
		},
	}


static func _prepare_context_for_profile_v1(
	sdk: Object,
	complete_energy_profile: bool,
) -> Dictionary:
	var gate_prefix := "QSDK_R24D136" if complete_energy_profile else "QSDK_R24D57"
	if sdk == null:
		return _failure("%s_SDK_MISSING" % gate_prefix)
	var profile_receipt := (
		ProfileCapabilityScript.complete_energy_profile_receipt_v1()
		if complete_energy_profile
		else ProfileCapabilityScript.profile_receipt_v1()
	)
	var expected_profile_id := (
		ProfileCapabilityScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		if complete_energy_profile
		else ProfileCapabilityScript.INSTRUMENTED_PROFILE_ID
	)
	var runtime: Dictionary = profile_receipt.get("runtime_identity", {})
	var capability: Dictionary = profile_receipt.get("capability", {})
	var validation: Dictionary = profile_receipt.get("validation", {})
	if (
		not bool(profile_receipt.get("instrumented_profile_selected", false))
		or String(profile_receipt.get("profile_id", "")) != expected_profile_id
		or not bool(runtime.get("exact_binary_pair_match", false))
		or not bool(runtime.get("telemetry_method_registered", false))
		or (
			complete_energy_profile
			and (
				not bool(runtime.get("complete_energy_profile_selected", false))
				or not bool(
					(
						runtime
						. get(
							"solver_energy_exchange_telemetry_method_registered",
							false,
						)
					)
				)
				or not bool(validation.get("complete_energy_profile_selected", false))
			)
		)
		or not bool(validation.get("ok", false))
		or int(validation.get("supported_channel_count", -1)) != 10
	):
		return _failure("%s_EXACT_INSTRUMENTED_PROFILE_REQUIRED" % gate_prefix)

	var compiled := RecoveryRuntimeScript.compile_recovery_morphology_v1(
		sdk, exact_recovery_descriptor_v1()
	)
	if (
		String(compiled.get("support_status", "")) != "supported_exact"
		or String(compiled.get("recovery_morphology_id", "")) != RECOVERY_MORPHOLOGY_ID
		or String(compiled.get("descriptor_sha256", "")) != RECOVERY_DESCRIPTOR_SHA256
		or String(compiled.get("base_descriptor_sha256", "")) != BASE_DESCRIPTOR_SHA256
		or String(compiled.get("base_morphology_spec_sha256", "")) != BASE_MORPHOLOGY_SPEC_SHA256
		or (
			String(compiled.get("recovery_morphology_spec_sha256", ""))
			!= RECOVERY_MORPHOLOGY_SPEC_SHA256
		)
	):
		return _failure("%s_RECOVERY_MORPHOLOGY_IDENTITY_INVALID" % gate_prefix)

	var capability_sha256 := _sha256(sdk, capability)
	var runtime_qualification_sha256 := _sha256(sdk, profile_receipt)
	if capability_sha256.is_empty() or runtime_qualification_sha256.is_empty():
		return _failure("%s_CONTEXT_DIGEST_FAILED" % gate_prefix)
	var profile_resolution := RecoveryRuntimeScript.resolve_actuator_cap_profile_v1(
		sdk, ACTUATOR_PROFILE_ID, exact_base_descriptor_v1()
	)
	if (
		String(profile_resolution.get("support_status", "")) != "supported_exact"
		or String(profile_resolution.get("profile_sha256", "")) != ACTUATOR_PROFILE_SHA256
	):
		return _failure("%s_ACTUATOR_PROFILE_INVALID" % gate_prefix)

	var context := {
		"schema_version":
		(
			"sporespore_qsdk_r24d136_godot_complete_energy_recovery_route_context_v1"
			if complete_energy_profile
			else "sporespore_qsdk_r24d57_godot_recovery_route_context_v1"
		),
		"ok": true,
		"runtime_profile_receipt": profile_receipt,
		"capability": capability,
		"capability_sha256": capability_sha256,
		"runtime_qualification_sha256": runtime_qualification_sha256,
		"compiled_recovery_morphology": compiled,
		"morphology_context":
		{
			"schema_version": "sporespore_recovery_morphology_context_v1",
			"recovery_morphology_id": String(compiled["recovery_morphology_id"]),
			"recovery_descriptor": (compiled["descriptor"] as Dictionary).duplicate(true),
			"recovery_descriptor_sha256": String(compiled["descriptor_sha256"]),
			"base_descriptor_sha256": String(compiled["base_descriptor_sha256"]),
			"base_morphology_spec_sha256": String(compiled["base_morphology_spec_sha256"]),
			"recovery_morphology_spec_sha256": String(compiled["recovery_morphology_spec_sha256"]),
		},
		"runtime_binding":
		{
			"schema_version": "sporespore_recovery_native_collector_binding_v1",
			"collector_id":
			R136_COMPLETE_ENERGY_COLLECTOR_ID if complete_energy_profile else COLLECTOR_ID,
			"runtime_profile_id": expected_profile_id,
			"runtime_qualification_sha256": runtime_qualification_sha256,
			"capability_sha256": capability_sha256,
			"exact_runtime_identity_qualified": true,
			"native_post_step_only": true,
			"source_measurement_only": true,
			"missing_value_synthesis_permitted": false,
			"engine_identity_exposed_to_controller": false,
		},
		"actuator_profile_resolution": profile_resolution,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if complete_energy_profile:
		context["complete_energy_profile_selected"] = true
		context["energy_route_id"] = R136_COMPLETE_ENERGY_ROUTE_ID
		context["energy_mapping_profile_id"] = R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		context["required_active_actuator_mapping_id"] = (R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID)
		context["required_active_work_mapping_id"] = R136_REQUIRED_ACTIVE_WORK_MAPPING_ID
		context["native_joint_motors_must_be_disabled"] = true
		context["continuous_collision_detection_permitted"] = false
		context["body_damping_must_be_replace_mode_zero"] = true
	return context


## The V2 route context changes no runtime, morphology, caps, or thresholds. It
## adds only the explicit controller selection authorized by R112.
static func prepare_context_v2(sdk: Object, recovery_controller_id: String) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V2_ID:
		return _failure("QSDK_R24D113_CONTROLLER_ID_INVALID")
	var context := prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return context
	context["schema_version"] = "sporespore_qsdk_r24d113_godot_recovery_route_context_v2"
	context["recovery_controller_id"] = recovery_controller_id
	return context


## R117 preserves the V2 pose and route while binding the versioned 8 rad/s
## distal-support speed ceiling selected by the retained-state R116 diagnosis.
static func prepare_context_v3(sdk: Object, recovery_controller_id: String) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V3_ID:
		return _failure("QSDK_R24D117_CONTROLLER_ID_INVALID")
	var context := prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return context
	context["schema_version"] = "sporespore_qsdk_r24d117_godot_recovery_route_context_v3"
	context["recovery_controller_id"] = recovery_controller_id
	return context


## R120 preserves the complete V3 route while continuing its qualified 8 rad/s
## speed ceiling across the raise-body phase boundary selected by R119.
static func prepare_context_v4(sdk: Object, recovery_controller_id: String) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V4_ID:
		return _failure("QSDK_R24D120_CONTROLLER_ID_INVALID")
	var context := prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return context
	context["schema_version"] = "sporespore_qsdk_r24d120_godot_recovery_route_context_v4"
	context["recovery_controller_id"] = recovery_controller_id
	return context


## R123 preserves the complete V4 route while changing only its raise-body
## speed ceiling from 8 to the bounded 22 rad/s input selected by R122.
static func prepare_context_v5(sdk: Object, recovery_controller_id: String) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V5_ID:
		return _failure("QSDK_R24D123_CONTROLLER_ID_INVALID")
	var context := prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return context
	context["schema_version"] = "sporespore_qsdk_r24d123_godot_recovery_route_context_v5"
	context["recovery_controller_id"] = recovery_controller_id
	return context


## R127 reuses the complete qualified V5 context and changes only the bound
## controller/adapter bundle identity. The named realization uses Jolt's hinge
## constraint motor inside the native contact solve; it does not add a new
## portable target, speed, cap, threshold, or acceptance rule.
static func prepare_context_v6(sdk: Object, recovery_controller_id: String) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D127_CONTROLLER_ID_INVALID")
	var context := prepare_context_v5(sdk, RECOVERY_CONTROLLER_V5_ID)
	if not bool(context.get("ok", false)):
		return context
	context["schema_version"] = "sporespore_qsdk_r24d127_godot_recovery_route_context_v6"
	context["predecessor_recovery_controller_id"] = RECOVERY_CONTROLLER_V5_ID
	context["recovery_controller_id"] = recovery_controller_id
	context["actuation_realization"] = {
		"schema_version": "sporespore_qsdk_r24d127_godot_actuation_realization_v1",
		"actuation_realization_id": R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"host_api": "HingeJoint3D.FLAG_ENABLE_MOTOR_and_PARAM_MOTOR_TARGET_VELOCITY",
		"native_contact_solver_coupled": true,
		"pre_solver_direct_body_impulse_write_count": 0,
		"energy_source_profile_id": ENERGY_MAPPING_PROFILE_ID,
		"portable_policy_changed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	return context


static func prepare_context_v1(sdk: Object) -> Dictionary:
	return _prepare_context_for_profile_v1(sdk, false)


## R136 is a distinct exact-runtime context. It changes no morphology, policy,
## caps, threshold, or outcome; it selects only the source-measured complete
## constraint/passive partition and its deliberately scoped native subset.
static func prepare_complete_energy_context_v1(sdk: Object) -> Dictionary:
	return _prepare_context_for_profile_v1(sdk, true)


## R137 keeps the exact portable V6 policy while replacing its incompatible
## solver-coupled native-motor realization with the R109 force/body-impulse
## mapping required by the qualified complete-energy partition. This is an
## adapter execution profile, not a new portable controller generation.
static func prepare_complete_energy_context_v2(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D137_CONTROLLER_ID_INVALID")
	var context := prepare_complete_energy_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return context
	context["schema_version"] = ("sporespore_qsdk_r24d137_godot_complete_energy_recovery_route_context_v2")
	context["recovery_controller_id"] = recovery_controller_id
	context["portable_controller_changed"] = false
	context["actuation_realization"] = {
		"schema_version": "sporespore_qsdk_r24d137_godot_complete_energy_actuation_realization_v1",
		"actuation_realization_id": R137_COMPLETE_ENERGY_ACTUATION_REALIZATION_ID,
		"actuator_mapping_id": R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": R136_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"native_contact_solver_coupled": false,
		"native_joint_motors_disabled": true,
		"pre_solver_direct_body_impulse_realization": true,
		"energy_source_profile_id": R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"portable_policy_changed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	return context


## R144 is additive to R136: it reuses the same exact instrumented binary pair
## and complete solver source, but selects the already-qualified R127 native
## motor realization and a new disjoint adapter partition. No controller,
## morphology, cap, phase target, threshold, or native engine binary changes.
static func prepare_complete_energy_context_v3(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D144_CONTROLLER_ID_INVALID")
	if (
		(
			R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
			!= NativeWorldScript.R144_SOLVER_COUPLED_COMPLETE_ENERGY_ACTUATOR_MAPPING_ID
		)
		or (
			R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
			!= NativeWorldScript.R144_SOLVER_COUPLED_COMPLETE_ENERGY_WORK_MAPPING_ID
		)
		or (
			R144_PARTITION_RULE_ID
			!= NativeWorldScript.R144_SOLVER_COUPLED_COMPLETE_ENERGY_PARTITION_RULE_ID
		)
	):
		return _failure("QSDK_R24D144_WORLD_ROUTE_PARTITION_IDENTITY_DRIFT")
	var context := prepare_complete_energy_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_capability_sha256 := String(context.get("capability_sha256", ""))
	var predecessor_runtime_qualification_sha256 := String(
		context.get("runtime_qualification_sha256", "")
	)
	var profile_receipt := (
		ProfileCapabilityScript.solver_coupled_complete_energy_profile_receipt_v1()
	)
	var runtime_value: Variant = profile_receipt.get("runtime_identity")
	var capability_value: Variant = profile_receipt.get("capability")
	var validation_value: Variant = profile_receipt.get("validation")
	if (
		not (runtime_value is Dictionary)
		or not (capability_value is Dictionary)
		or not (validation_value is Dictionary)
	):
		return _failure("QSDK_R24D144_CAPABILITY_VARIANT_SHAPE_INVALID")
	var runtime: Dictionary = runtime_value
	var capability: Dictionary = capability_value
	var validation: Dictionary = validation_value
	if (
		not bool(profile_receipt.get("instrumented_profile_selected", false))
		or (
			String(profile_receipt.get("profile_id", ""))
			!= ProfileCapabilityScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		)
		or (
			String(profile_receipt.get("capability_variant_id", ""))
			!= ProfileCapabilityScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		)
		or (
			String(profile_receipt.get("adapter_energy_mapping_profile_id", ""))
			!= R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or not bool(runtime.get("exact_binary_pair_match", false))
		or not bool(runtime.get("complete_energy_profile_selected", false))
		or not bool(validation.get("ok", false))
		or not bool(validation.get("solver_coupled_complete_energy_profile_selected", false))
		or int(validation.get("supported_channel_count", -1)) != 10
		or int(validation.get("changed_channel_count", -1)) != 1
		or validation.get("changed_channel_ids", []) != ["energy_balance_ledger"]
	):
		return _failure("QSDK_R24D144_EXACT_CAPABILITY_VARIANT_REQUIRED")
	var capability_sha256 := _sha256(sdk, capability)
	var runtime_qualification_sha256 := _sha256(sdk, profile_receipt)
	if capability_sha256.is_empty() or runtime_qualification_sha256.is_empty():
		return _failure("QSDK_R24D144_CAPABILITY_VARIANT_DIGEST_FAILED")
	context["schema_version"] = ("sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_recovery_route_context_v3")
	context["runtime_profile_receipt"] = profile_receipt
	context["capability"] = capability
	context["capability_sha256"] = capability_sha256
	context["runtime_qualification_sha256"] = runtime_qualification_sha256
	context["predecessor_capability_sha256"] = predecessor_capability_sha256
	context["predecessor_runtime_qualification_sha256"] = (predecessor_runtime_qualification_sha256)
	context["capability_variant_id"] = (
		ProfileCapabilityScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
	)
	context["adapter_energy_mapping_profile_id"] = R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	context["capability_transition"] = {
		"schema_version":
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_capability_transition_v1",
		"predecessor_capability_sha256": predecessor_capability_sha256,
		"capability_sha256": capability_sha256,
		"changed_channel_count": 1,
		"changed_channel_ids": ["energy_balance_ledger"],
		"runtime_binary_pair_changed": false,
		"telemetry_profile_changed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	context["recovery_controller_id"] = recovery_controller_id
	context["portable_controller_changed"] = false
	context["solver_coupled_complete_energy_profile_selected"] = true
	context["energy_route_id"] = R144_COMPLETE_ENERGY_ROUTE_ID
	context["energy_mapping_profile_id"] = R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	context["required_active_actuator_mapping_id"] = (R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID)
	context["required_active_work_mapping_id"] = R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
	context["partition_rule_id"] = R144_PARTITION_RULE_ID
	context["native_joint_motors_must_be_disabled"] = false
	context["active_native_joint_motor_enabled_count"] = 8
	context["zero_command_native_joint_motor_enabled_count"] = 0
	(context["runtime_binding"] as Dictionary)["collector_id"] = (R144_COMPLETE_ENERGY_COLLECTOR_ID)
	(context["runtime_binding"] as Dictionary)["runtime_qualification_sha256"] = (runtime_qualification_sha256)
	(context["runtime_binding"] as Dictionary)["capability_sha256"] = capability_sha256
	context["actuation_realization"] = {
		"schema_version":
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_actuation_realization_v1",
		"actuation_realization_id": R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"actuator_mapping_id": R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": R144_PARTITION_RULE_ID,
		"native_contact_solver_coupled": true,
		"native_joint_motors_disabled": false,
		"pre_solver_direct_body_impulse_realization": false,
		"energy_source_profile_id": R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"portable_policy_changed": false,
		"native_engine_binary_changed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not _solver_coupled_complete_energy_capability_binding_exact_v1(context):
		return _failure("QSDK_R24D144_CAPABILITY_BINDING_INVALID")
	return context


## Shared fail-closed binding check used by context construction, mapping, and
## authority projection. It is deliberately pure and opens no world.
static func _solver_coupled_complete_energy_capability_binding_exact_v1(
	context: Dictionary,
) -> bool:
	var receipt_value: Variant = context.get("runtime_profile_receipt")
	var capability_value: Variant = context.get("capability")
	var binding_value: Variant = context.get("runtime_binding")
	var transition_value: Variant = context.get("capability_transition")
	if (
		not (receipt_value is Dictionary)
		or not (capability_value is Dictionary)
		or not (binding_value is Dictionary)
		or not (transition_value is Dictionary)
	):
		return false
	var receipt: Dictionary = receipt_value
	var capability: Dictionary = capability_value
	var binding: Dictionary = binding_value
	var transition: Dictionary = transition_value
	var expected_capability := (
		ProfileCapabilityScript.solver_coupled_complete_energy_capability_v1()
	)
	var expected_validation := (
		ProfileCapabilityScript.validate_solver_coupled_complete_energy_capability_v1(capability)
	)
	return (
		capability == expected_capability
		and receipt.get("capability", {}) == capability
		and receipt.get("validation", {}) == expected_validation
		and (
			String(receipt.get("profile_id", ""))
			== ProfileCapabilityScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		)
		and (
			String(receipt.get("capability_variant_id", ""))
			== ProfileCapabilityScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		)
		and (
			String(receipt.get("adapter_energy_mapping_profile_id", ""))
			== R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		and (
			String(context.get("capability_variant_id", ""))
			== ProfileCapabilityScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		)
		and (
			String(context.get("adapter_energy_mapping_profile_id", ""))
			== R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		and String(binding.get("collector_id", "")) == R144_COMPLETE_ENERGY_COLLECTOR_ID
		and (
			String(binding.get("capability_sha256", ""))
			== String(context.get("capability_sha256", ""))
		)
		and (
			String(binding.get("runtime_qualification_sha256", ""))
			== String(context.get("runtime_qualification_sha256", ""))
		)
		and int(transition.get("changed_channel_count", -1)) == 1
		and transition.get("changed_channel_ids", []) == ["energy_balance_ledger"]
		and (
			String(transition.get("capability_sha256", ""))
			== String(context.get("capability_sha256", ""))
		)
		and not bool(transition.get("runtime_binary_pair_changed", true))
		and not bool(transition.get("telemetry_profile_changed", true))
		and not bool(transition.get("physical_acceptance_authority", true))
		and not bool(transition.get("release_authority", true))
	)


## R148 is a zero-world route-mapping successor to R144. It keeps the exact
## native binary, solver/motor partition, controller, and morphology, and
## changes only the energy channel's declared staging source. Physical world
## construction remains explicitly closed until the distinct R149 ghost.
static func prepare_complete_energy_context_v4(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D148_CONTROLLER_ID_INVALID")
	var context := prepare_complete_energy_context_v3(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_capability_sha256 := String(context.get("capability_sha256", ""))
	var predecessor_runtime_qualification_sha256 := String(
		context.get("runtime_qualification_sha256", "")
	)
	var profile_receipt := (
		ProfileCapabilityScript.discrete_staging_complete_energy_profile_receipt_v1()
	)
	var runtime_value: Variant = profile_receipt.get("runtime_identity")
	var capability_value: Variant = profile_receipt.get("capability")
	var validation_value: Variant = profile_receipt.get("validation")
	if (
		not (runtime_value is Dictionary)
		or not (capability_value is Dictionary)
		or not (validation_value is Dictionary)
	):
		return _failure("QSDK_R24D148_CAPABILITY_VARIANT_SHAPE_INVALID")
	var runtime: Dictionary = runtime_value
	var capability: Dictionary = capability_value
	var validation: Dictionary = validation_value
	if (
		not bool(profile_receipt.get("instrumented_profile_selected", false))
		or (
			String(profile_receipt.get("profile_id", ""))
			!= ProfileCapabilityScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		)
		or (
			String(profile_receipt.get("capability_variant_id", ""))
			!= ProfileCapabilityScript.DISCRETE_STAGING_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		)
		or (
			String(profile_receipt.get("adapter_energy_mapping_profile_id", ""))
			!= R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or not bool(runtime.get("exact_binary_pair_match", false))
		or not bool(runtime.get("complete_energy_profile_selected", false))
		or not bool(validation.get("ok", false))
		or not bool(validation.get("discrete_staging_complete_energy_profile_selected", false))
		or int(validation.get("supported_channel_count", -1)) != 10
		or int(validation.get("changed_channel_count", -1)) != 1
		or validation.get("changed_channel_ids", []) != ["energy_balance_ledger"]
	):
		return _failure("QSDK_R24D148_EXACT_CAPABILITY_VARIANT_REQUIRED")
	var capability_sha256 := _sha256(sdk, capability)
	var runtime_qualification_sha256 := _sha256(sdk, profile_receipt)
	if capability_sha256.is_empty() or runtime_qualification_sha256.is_empty():
		return _failure("QSDK_R24D148_CAPABILITY_VARIANT_DIGEST_FAILED")
	context["schema_version"] = ("sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_recovery_route_context_v4")
	context["runtime_profile_receipt"] = profile_receipt
	context["capability"] = capability
	context["capability_sha256"] = capability_sha256
	context["runtime_qualification_sha256"] = runtime_qualification_sha256
	context["predecessor_capability_sha256"] = predecessor_capability_sha256
	context["predecessor_runtime_qualification_sha256"] = (predecessor_runtime_qualification_sha256)
	context["capability_variant_id"] = (
		ProfileCapabilityScript.DISCRETE_STAGING_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
	)
	context["adapter_energy_mapping_profile_id"] = (R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID)
	context["capability_transition"] = {
		"schema_version":
		"sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_capability_transition_v1",
		"predecessor_capability_sha256": predecessor_capability_sha256,
		"capability_sha256": capability_sha256,
		"changed_channel_count": 1,
		"changed_channel_ids": ["energy_balance_ledger"],
		"runtime_binary_pair_changed": false,
		"telemetry_profile_changed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	context["discrete_staging_complete_energy_profile_selected"] = true
	context["energy_route_id"] = R148_COMPLETE_ENERGY_ROUTE_ID
	context["energy_mapping_profile_id"] = R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	context["discrete_staging_rule_id"] = R148_STAGING_RULE_ID
	context["discrete_staging_force_contract"] = (DiscreteStagingRouteScript.force_contract_v1())
	context["physical_world_construction_authorized"] = false
	context["physical_world_construction_next_gate"] = "QSDK-R24D149"
	(context["runtime_binding"] as Dictionary)["collector_id"] = (R148_COMPLETE_ENERGY_COLLECTOR_ID)
	(context["runtime_binding"] as Dictionary)["runtime_qualification_sha256"] = (runtime_qualification_sha256)
	(context["runtime_binding"] as Dictionary)["capability_sha256"] = capability_sha256
	var realization: Dictionary = (context["actuation_realization"] as Dictionary).duplicate(true)
	realization["schema_version"] = ("sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_actuation_realization_v1")
	realization["energy_source_profile_id"] = R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	realization["portable_policy_changed"] = false
	realization["native_engine_binary_changed"] = false
	context["actuation_realization"] = realization
	if not _discrete_staging_complete_energy_capability_binding_exact_v1(context):
		return _failure("QSDK_R24D148_CAPABILITY_BINDING_INVALID")
	return context


## R149 changes no capability, policy, controller, or energy equation. It adds
## only a distinct production-world transport selection around the immutable
## R148 context so the two-step development ghost can commission live capture.
static func prepare_complete_energy_context_v5(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v4(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D149_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = ("sporespore_qsdk_r24d149_godot_discrete_staging_live_transport_recovery_route_context_v5")
	context["r148_zero_world_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_authorized"] = true
	context.erase("physical_world_construction_next_gate")
	context["physical_world_construction_gate_id"] = "QSDK-R24D149"
	context["live_boundary_transport_selected"] = true
	context["live_boundary_transport_id"] = R149_LIVE_BOUNDARY_TRANSPORT_ID
	context["live_boundary_transport_commissioned"] = false
	if not _r149_discrete_staging_live_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D149_LIVE_CONTEXT_BINDING_INVALID")
	return context


## R150 is an additive campaign binding over the unchanged R149 live transport.
## It changes no native source, policy, controller, capability, or physical
## route; it gives the distinct core-identity successor its own construction
## authority after the R149 attempt was consumed.
static func prepare_complete_energy_context_v6(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v5(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D150_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = ("sporespore_qsdk_r24d150_godot_discrete_staging_core_bound_recovery_route_context_v6")
	context["r149_live_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_gate_id"] = "QSDK-R24D150"
	context["portable_core_identity_binding_selected"] = true
	if not _r150_discrete_staging_live_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D150_LIVE_CONTEXT_BINDING_INVALID")
	return context


## R151 changes no policy, threshold, cohort, runtime, or physical route. It
## gives the already commissioned R150 transport a distinct finite-behavior
## construction identity and binds the separately versioned complete-energy
## authority used by the portable step and evaluator calls.
static func prepare_complete_energy_context_v7(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v6(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D151_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = ("sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_context_v7")
	context["r150_core_bound_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_gate_id"] = "QSDK-R24D151"
	context["finite_behavior_pair_selected"] = true
	context["complete_energy_authority_profile_id"] = (R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID)
	if not _r151_discrete_staging_behavior_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D151_BEHAVIOR_CONTEXT_BINDING_INVALID")
	return context


## R152 reopens no behavior question. It binds the exact R151 application
## identity to a one-step production sampler seam while preserving R144 as the
## native solver/motor/constraint predecessor partition.
static func prepare_complete_energy_context_v8(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v6(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D152_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d152_godot_route_aware_application_provenance_context_v8"
	)
	context["r150_core_bound_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_gate_id"] = "QSDK-R24D152"
	context["route_aware_application_provenance_selected"] = true
	context["application_provenance_profile_id"] = (
		R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
	)
	context["complete_energy_authority_profile_id"] = (
		R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
	)
	if not _r152_route_aware_application_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D152_APPLICATION_CONTEXT_BINDING_INVALID")
	return context


## R153 changes no policy, threshold, cohort, runtime, energy mapping, or
## evaluator. It gives the R152-commissioned route-aware application path a
## distinct finite-behavior construction identity after R151 was consumed as
## integration-invalid before its first native sample.
static func prepare_complete_energy_context_v9(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v8(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D153_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_context_v9"
	)
	context["r152_route_aware_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_gate_id"] = "QSDK-R24D153"
	context["finite_behavior_pair_selected"] = true
	if not _r153_route_aware_behavior_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D153_BEHAVIOR_CONTEXT_BINDING_INVALID")
	return context


## R154 preserves the entire R153 behavior question and commissioned physical
## route. It versions only the in-run consumer rule for the adapter's already-
## cumulative discrete-staging event count.
static func prepare_complete_energy_context_v10(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v9(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D154_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_behavior_context_v10"
	)
	context["r153_route_aware_behavior_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_gate_id"] = "QSDK-R24D154"
	context["accumulator_aware_invariant_validation_selected"] = true
	context["in_run_invariant_validator_profile_id"] = (
		R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID
	)
	if not _r154_accumulator_aware_behavior_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D154_BEHAVIOR_CONTEXT_BINDING_INVALID")
	return context


## R162 changes the native runtime/capability and recovery-ledger consumer only.
## It reconstructs the already-bound morphology, controller, application,
## staging, and accumulator semantics under the R157-qualified v6 binary pair.
## This context is intentionally non-physical; a later distinct authority must
## authorize construction before it can reach a solver.
static func prepare_complete_energy_context_v11(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R24D162_SDK_MISSING")
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D162_CONTROLLER_ID_INVALID")
	if (
		R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		!= ProfileCapabilityScript.ROTATION_AWARE_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		or R162_ROTATION_AWARE_CAPABILITY_VARIANT_ID
		!= ProfileCapabilityScript.ROTATION_AWARE_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
	):
		return _failure("QSDK_R24D162_CAPABILITY_IDENTITY_DRIFT")

	var profile_receipt := (
		ProfileCapabilityScript.rotation_aware_complete_energy_profile_receipt_v1()
	)
	var runtime_value: Variant = profile_receipt.get("runtime_identity")
	var capability_value: Variant = profile_receipt.get("capability")
	var validation_value: Variant = profile_receipt.get("validation")
	if (
		not (runtime_value is Dictionary)
		or not (capability_value is Dictionary)
		or not (validation_value is Dictionary)
	):
		return _failure("QSDK_R24D162_CAPABILITY_VARIANT_SHAPE_INVALID")
	var runtime: Dictionary = runtime_value
	var capability: Dictionary = capability_value
	var validation: Dictionary = validation_value
	if (
		not bool(profile_receipt.get("instrumented_profile_selected", false))
		or (
			String(profile_receipt.get("profile_id", ""))
			!= ProfileCapabilityScript.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		)
		or String(profile_receipt.get("capability_variant_id", ""))
		!= R162_ROTATION_AWARE_CAPABILITY_VARIANT_ID
		or String(profile_receipt.get("adapter_energy_mapping_profile_id", ""))
		!= R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		or not bool(profile_receipt.get("rotation_aware_energy_ledger_profile_selected", false))
		or not bool(runtime.get("exact_binary_pair_match", false))
		or not bool(runtime.get("complete_energy_profile_selected", false))
		or not bool(validation.get("ok", false))
		or not bool(validation.get("rotation_aware_energy_ledger_profile_selected", false))
		or int(validation.get("supported_channel_count", -1)) != 10
		or int(validation.get("changed_channel_count", -1)) != 1
		or validation.get("changed_channel_ids", []) != ["energy_balance_ledger"]
	):
		return _failure("QSDK_R24D162_EXACT_CAPABILITY_VARIANT_REQUIRED")

	var compiled := RecoveryRuntimeScript.compile_recovery_morphology_v1(
		sdk, exact_recovery_descriptor_v1()
	)
	if (
		String(compiled.get("support_status", "")) != "supported_exact"
		or String(compiled.get("recovery_morphology_id", "")) != RECOVERY_MORPHOLOGY_ID
		or String(compiled.get("descriptor_sha256", "")) != RECOVERY_DESCRIPTOR_SHA256
		or String(compiled.get("base_descriptor_sha256", "")) != BASE_DESCRIPTOR_SHA256
		or String(compiled.get("base_morphology_spec_sha256", ""))
		!= BASE_MORPHOLOGY_SPEC_SHA256
		or String(compiled.get("recovery_morphology_spec_sha256", ""))
		!= RECOVERY_MORPHOLOGY_SPEC_SHA256
	):
		return _failure("QSDK_R24D162_RECOVERY_MORPHOLOGY_IDENTITY_INVALID")
	var profile_resolution := RecoveryRuntimeScript.resolve_actuator_cap_profile_v1(
		sdk, ACTUATOR_PROFILE_ID, exact_base_descriptor_v1()
	)
	if (
		String(profile_resolution.get("support_status", "")) != "supported_exact"
		or String(profile_resolution.get("profile_sha256", "")) != ACTUATOR_PROFILE_SHA256
	):
		return _failure("QSDK_R24D162_ACTUATOR_PROFILE_INVALID")
	var capability_sha256 := _sha256(sdk, capability)
	var runtime_qualification_sha256 := _sha256(sdk, profile_receipt)
	if capability_sha256.is_empty() or runtime_qualification_sha256.is_empty():
		return _failure("QSDK_R24D162_CONTEXT_DIGEST_FAILED")

	var context := {
		"schema_version": (
			"sporespore_qsdk_r24d162_godot_rotation_aware_recovery_ledger_context_v11"
		),
		"ok": true,
		"runtime_profile_receipt": profile_receipt,
		"capability": capability,
		"capability_sha256": capability_sha256,
		"runtime_qualification_sha256": runtime_qualification_sha256,
		"compiled_recovery_morphology": compiled,
		"morphology_context": {
			"schema_version": "sporespore_recovery_morphology_context_v1",
			"recovery_morphology_id": String(compiled["recovery_morphology_id"]),
			"recovery_descriptor": (compiled["descriptor"] as Dictionary).duplicate(true),
			"recovery_descriptor_sha256": String(compiled["descriptor_sha256"]),
			"base_descriptor_sha256": String(compiled["base_descriptor_sha256"]),
			"base_morphology_spec_sha256": String(compiled["base_morphology_spec_sha256"]),
			"recovery_morphology_spec_sha256": String(
				compiled["recovery_morphology_spec_sha256"]
			),
		},
		"runtime_binding": {
			"schema_version": "sporespore_recovery_native_collector_binding_v1",
			"collector_id": R162_ROTATION_AWARE_COLLECTOR_ID,
			"runtime_profile_id": (
				ProfileCapabilityScript.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
			),
			"runtime_qualification_sha256": runtime_qualification_sha256,
			"capability_sha256": capability_sha256,
			"exact_runtime_identity_qualified": true,
			"native_post_step_only": true,
			"source_measurement_only": true,
			"missing_value_synthesis_permitted": false,
			"engine_identity_exposed_to_controller": false,
		},
		"actuator_profile_resolution": profile_resolution,
		"capability_variant_id": R162_ROTATION_AWARE_CAPABILITY_VARIANT_ID,
		"adapter_energy_mapping_profile_id": R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
		"predecessor_adapter_energy_mapping_profile_id": R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
		"rotation_aware_energy_ledger_profile_selected": true,
		"recovery_energy_ledger_profile_id": R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
		"solver_energy_consumer_contract_schema_version": (
			R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA
		),
		"solver_energy_telemetry_schema_version": R162_SOLVER_ENERGY_TELEMETRY_SCHEMA,
		"solver_energy_telemetry_profile_id": R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID,
		"r24d161_diagnosis_raw_sha256": R162_R161_DIAGNOSIS_RAW_SHA256,
		"recovery_controller_id": recovery_controller_id,
		"portable_controller_changed": false,
		"energy_route_id": R148_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"required_active_actuator_mapping_id": R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"required_active_work_mapping_id": R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": R144_PARTITION_RULE_ID,
		"native_joint_motors_must_be_disabled": false,
		"active_native_joint_motor_enabled_count": 8,
		"zero_command_native_joint_motor_enabled_count": 0,
		"continuous_collision_detection_permitted": false,
		"body_damping_must_be_replace_mode_zero": true,
		"discrete_staging_rule_id": R148_STAGING_RULE_ID,
		"discrete_staging_force_contract": DiscreteStagingRouteScript.force_contract_v1(),
		"route_aware_application_provenance_selected": true,
		"application_provenance_profile_id": R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID,
		"complete_energy_authority_profile_id": R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"accumulator_aware_invariant_validation_selected": true,
		"in_run_invariant_validator_profile_id": (
			R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID
		),
		"finite_behavior_pair_selected": false,
		"physical_world_construction_authorized": false,
		"physical_world_construction_blocked_by": "QSDK-R24D162_ZERO_WORLD_ONLY",
		"actuation_realization": {
			"schema_version": (
				"sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_actuation_realization_v1"
			),
			"actuation_realization_id": R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
			"actuator_mapping_id": R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
			"work_mapping_id": R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
			"partition_rule_id": R144_PARTITION_RULE_ID,
			"native_contact_solver_coupled": true,
			"native_joint_motors_disabled": false,
			"pre_solver_direct_body_impulse_realization": false,
			"energy_source_profile_id": R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
			"portable_policy_changed": false,
			"native_engine_binary_changed": true,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not rotation_aware_energy_ledger_context_binding_exact_v1(context):
		return _failure("QSDK_R24D162_CONTEXT_BINDING_INVALID")
	return context


## R163 is the first construction authority for the already-qualified R162
## ledger. It changes no controller, route, mapping, threshold, or measurement
## semantics. The context is valid only for one separately supervised
## integration ghost after a clean zero-world qualification closure exists.
static func prepare_complete_energy_context_v12(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v11(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D163_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d163_godot_rotation_aware_recovery_route_context_v12"
	)
	context["r162_zero_world_context_sha256"] = predecessor_context_sha256
	context.erase("physical_world_construction_blocked_by")
	context["physical_world_construction_authorized"] = true
	context["physical_world_construction_gate_id"] = "QSDK-R24D163"
	context["portable_core_identity_binding_selected"] = true
	context["route_ghost_profile_id"] = R163_ROTATION_AWARE_ROUTE_GHOST_PROFILE_ID
	context["route_ghost_only"] = true
	context["recovery_behavior_evaluation_authorized"] = false
	if not rotation_aware_route_ghost_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D163_ROUTE_CONTEXT_BINDING_INVALID")
	return context


## R164 preserves the exact R154 finite candidate-plus-matched-zero behavior
## question while changing only its physical/measurement identity to the
## R162 ledger route commissioned by R163. It is a distinct finite development
## campaign, not a replay or reinterpretation of either consumed result.
static func prepare_complete_energy_context_v13(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v12(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D164_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_context_v13"
	)
	context["r163_route_ghost_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_gate_id"] = "QSDK-R24D164"
	context.erase("route_ghost_profile_id")
	context.erase("route_ghost_only")
	context["finite_behavior_pair_selected"] = true
	context["finite_behavior_profile_id"] = R164_ROTATION_AWARE_FINITE_BEHAVIOR_PROFILE_ID
	context["recovery_behavior_evaluation_authorized"] = true
	if not rotation_aware_finite_behavior_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D164_BEHAVIOR_CONTEXT_BINDING_INVALID")
	return context


## R165 changes only the behavior consumer's native-source-trace schema
## selection after R164 proved that the v6 route correctly emits the R162
## rotation-aware trace. R164's consumed context remains byte-for-byte valid
## under its original, now-known-incomplete validator semantics.
static func prepare_complete_energy_context_v14(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v13(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D165_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_context_v14"
	)
	context["r164_finite_behavior_context_sha256"] = predecessor_context_sha256
	context["physical_world_construction_gate_id"] = "QSDK-R24D165"
	context["rotation_aware_source_trace_validation_selected"] = true
	context["native_source_trace_validator_profile_id"] = (
		R165_ROTATION_AWARE_SOURCE_TRACE_VALIDATOR_PROFILE_ID
	)
	if not rotation_aware_source_trace_behavior_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D165_BEHAVIOR_CONTEXT_BINDING_INVALID")
	return context


## R168 replaces only the known-aliased R149 body-boundary transport with the
## R167-qualified contiguous cache state machine. It deliberately derives from
## the non-physical R162 ledger context: this is implementation completeness,
## not a new behavior attempt or retrospective correction of R154/R164/R165.
static func prepare_complete_energy_context_v15(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v11(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D168_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d168_godot_contiguous_boundary_transport_context_v15"
	)
	context["r162_zero_world_context_sha256"] = predecessor_context_sha256
	context["r167_transport_design_raw_sha256"] = R168_R167_TRANSPORT_DESIGN_RAW_SHA256
	context["contiguous_boundary_transport_profile_selected"] = true
	context["contiguous_boundary_transport_design_id"] = (
		ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
	)
	context["contiguous_boundary_transport_profile_id"] = (
		R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
	)
	context["boundary_transport_state_schema_version"] = (
		ContiguousBoundaryTransportScript.STATE_SCHEMA
	)
	context["boundary_transport_pair_schema_version"] = (
		ContiguousBoundaryTransportScript.PAIR_SCHEMA
	)
	context["legacy_aliased_boundary_transport_selected"] = false
	context["physical_world_construction_blocked_by"] = "QSDK-R24D168_ZERO_WORLD_ONLY"
	if not rotation_aware_contiguous_boundary_transport_context_binding_exact_v1(
		sdk, context
	):
		return _failure("QSDK_R24D168_CONTEXT_BINDING_INVALID")
	return context


## R169 authorizes only a distinct one-world, two-completed-step production
## route ghost over the R168-qualified transport. It derives byte-exactly from
## V15 and grants no recovery-behavior evaluation or standing authority.
static func prepare_complete_energy_context_v16(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v15(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D169_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d169_godot_contiguous_boundary_route_ghost_context_v16"
	)
	context["r168_transport_context_sha256"] = predecessor_context_sha256
	context["r168_zero_world_closure_raw_sha256"] = (
		R169_R168_ZERO_WORLD_CLOSURE_RAW_SHA256
	)
	context.erase("physical_world_construction_blocked_by")
	context["physical_world_construction_authorized"] = true
	context["physical_world_construction_gate_id"] = "QSDK-R24D169"
	context["portable_core_identity_binding_selected"] = true
	context["route_ghost_profile_id"] = R169_CONTIGUOUS_BOUNDARY_ROUTE_GHOST_PROFILE_ID
	context["route_ghost_only"] = true
	context["recovery_behavior_evaluation_authorized"] = false
	if not contiguous_boundary_transport_route_ghost_context_binding_exact_v1(
		sdk, context
	):
		return _failure("QSDK_R24D169_ROUTE_CONTEXT_BINDING_INVALID")
	return context


## R170 preserves the exact consumed R165 behavior question and changes only
## the diagnosed R149 boundary transport to the R168/R169-qualified contiguous
## transport. The R169 route value is not an input to behavior, thresholds, or
## acceptance; its immutable closure supplies route-completeness authority only.
static func prepare_complete_energy_context_v17(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v14(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D170_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d170_godot_contiguous_boundary_recovery_behavior_context_v17"
	)
	context["r165_behavior_context_sha256"] = predecessor_context_sha256
	context["r165_physical_closure_raw_sha256"] = (
		R170_R165_PHYSICAL_CLOSURE_RAW_SHA256
	)
	context["r169_route_ghost_physical_closure_raw_sha256"] = (
		R170_R169_PHYSICAL_CLOSURE_RAW_SHA256
	)
	context["physical_world_construction_gate_id"] = "QSDK-R24D170"
	context["contiguous_boundary_transport_profile_selected"] = true
	context["contiguous_boundary_transport_design_id"] = (
		ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
	)
	context["contiguous_boundary_transport_profile_id"] = (
		R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
	)
	context["boundary_transport_state_schema_version"] = (
		ContiguousBoundaryTransportScript.STATE_SCHEMA
	)
	context["boundary_transport_pair_schema_version"] = (
		ContiguousBoundaryTransportScript.PAIR_SCHEMA
	)
	context["legacy_aliased_boundary_transport_selected"] = false
	context["contiguous_boundary_behavior_profile_id"] = (
		R170_CONTIGUOUS_BOUNDARY_RECOVERY_BEHAVIOR_PROFILE_ID
	)
	if not contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D170_BEHAVIOR_CONTEXT_BINDING_INVALID")
	return context


## R172 preserves the exact R170 physical question under a new identity and
## changes only the R171-qualified initializer-receipt retention seam. The
## consumed R170 result remains publication-invalid/incomplete and is never an
## outcome input; its closure and the R171 qualification closure are immutable
## provenance bindings.
static func prepare_complete_energy_context_v18(
	sdk: Object,
	recovery_controller_id: String,
) -> Dictionary:
	var context := prepare_complete_energy_context_v17(sdk, recovery_controller_id)
	if not bool(context.get("ok", false)):
		return context
	var predecessor_context_sha256 := _sha256(sdk, context)
	if predecessor_context_sha256.is_empty():
		return _failure("QSDK_R24D172_PREDECESSOR_CONTEXT_DIGEST_FAILED")
	context["schema_version"] = (
		"sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
	)
	context["r170_behavior_context_sha256"] = predecessor_context_sha256
	context["r170_physical_closure_raw_sha256"] = (
		R172_R170_PHYSICAL_CLOSURE_RAW_SHA256
	)
	context["r171_initializer_receipt_retention_closure_raw_sha256"] = (
		R172_R171_ZERO_WORLD_CLOSURE_RAW_SHA256
	)
	context["physical_world_construction_gate_id"] = "QSDK-R24D172"
	context["contiguous_boundary_behavior_profile_id"] = (
		R172_INITIALIZER_RETENTION_RECOVERY_BEHAVIOR_PROFILE_ID
	)
	if not contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk, context):
		return _failure("QSDK_R24D172_BEHAVIOR_CONTEXT_BINDING_INVALID")
	return context


## Development controller overlay over the exact retained native measurement
## machinery. It grants no new-world or behavior authority: the eventual worker
## must bind the candidate separately while retaining its V6 setup context.
static func prepare_rearward_fold_context_v1(sdk: Object) -> Dictionary:
	var source := prepare_complete_energy_context_v18(sdk, RECOVERY_CONTROLLER_V6_ID)
	if not bool(source.get("ok", false)):
		return source
	var context := source.duplicate(true)
	context["schema_version"] = "sporespore_development_rearward_fold_context_v1"
	context["source_native_context_sha256"] = _sha256(sdk, source)
	context["recovery_controller_id"] = RECOVERY_CONTROLLER_V7_ID
	context["portable_controller_changed"] = true
	context["actuation_realization"]["portable_policy_changed"] = true
	context["finite_behavior_pair_selected"] = false
	context["recovery_behavior_evaluation_authorized"] = false
	context["physical_world_construction_authorized"] = false
	context.erase("physical_world_construction_gate_id")
	context["physical_world_construction_blocked_by"] = "DEVELOPMENT_CANDIDATE_REQUIRES_SEPARATE_WORKER_BINDING"
	return context


static func rearward_fold_context_binding_exact_v1(sdk: Object, context: Dictionary) -> bool:
	if sdk == null or context.get("schema_version") != "sporespore_development_rearward_fold_context_v1":
		return false
	var selected := {"recovery_controller_id": RECOVERY_CONTROLLER_V7_ID,
		"portable_controller_changed": true, "finite_behavior_pair_selected": false,
		"recovery_behavior_evaluation_authorized": false, "physical_world_construction_authorized": false,
		"physical_world_construction_blocked_by": "DEVELOPMENT_CANDIDATE_REQUIRES_SEPARATE_WORKER_BINDING"}
	for key in selected:
		if typeof(context.get(key)) != typeof(selected[key]) or context[key] != selected[key]:
			return false
	if (context.has("physical_world_construction_gate_id")
		or not (context.get("actuation_realization") is Dictionary)
		or context["actuation_realization"].get("portable_policy_changed") != true):
		return false
	# Validate the bound ancestry, as the existing R172 context validator does.
	# Do not rediscover/re-hash the native runtime at every controller step.
	# The launcher/runtime binding still independently checks actual binaries.
	var source := context.duplicate(true)
	source["schema_version"] = "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
	source["recovery_controller_id"] = RECOVERY_CONTROLLER_V6_ID
	source["portable_controller_changed"] = false
	source["actuation_realization"]["portable_policy_changed"] = false
	source["finite_behavior_pair_selected"] = true
	source["recovery_behavior_evaluation_authorized"] = true
	source["physical_world_construction_authorized"] = true
	source["physical_world_construction_gate_id"] = "QSDK-R24D172"
	source.erase("source_native_context_sha256")
	source.erase("physical_world_construction_blocked_by")
	return (_sha256(sdk, source) == context.get("source_native_context_sha256")
		and contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk, source))


## The same compiled collection, supervisor, energy authority and command
## planner as V6, with a separately checked candidate context. This consumes
## supplied observations only; no model, sampler or solver is called here.
static func advance_rearward_fold_control_v1(
	sdk: Object, context: Dictionary, bound: Dictionary, memory: Dictionary,
	source_application: Dictionary,
) -> Dictionary:
	if not rearward_fold_context_binding_exact_v1(sdk, context):
		return _failure("DEVELOPMENT_REARWARD_FOLD_CONTEXT_INVALID")
	return advance_behavior_solver_coupled_complete_energy_l15_v1(
		sdk, context, bound, memory, "candidate_command", String(memory.get("phase", "")), source_application
	)


## V8 changes only the portable target-speed profile. Preserve the exact V6
## measurement ancestry; the V7 entrypoint still refuses this distinct context.
static func prepare_rate_limited_recovery_context_v1(sdk: Object) -> Dictionary:
	var context := prepare_rearward_fold_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return context
	context["schema_version"] = "sporespore_development_rate_limited_recovery_context_v1"
	context["recovery_controller_id"] = RECOVERY_CONTROLLER_V8_ID
	return context


static func rate_limited_recovery_context_binding_exact_v1(sdk: Object, context: Dictionary) -> bool:
	if (context.get("schema_version") != "sporespore_development_rate_limited_recovery_context_v1"
		or context.get("recovery_controller_id") != RECOVERY_CONTROLLER_V8_ID):
		return false
	var ancestor := context.duplicate(true)
	ancestor["schema_version"] = "sporespore_development_rearward_fold_context_v1"
	ancestor["recovery_controller_id"] = RECOVERY_CONTROLLER_V7_ID
	return rearward_fold_context_binding_exact_v1(sdk, ancestor)


static func advance_rate_limited_recovery_control_v1(
	sdk: Object, context: Dictionary, bound: Dictionary, memory: Dictionary,
	source_application: Dictionary,
) -> Dictionary:
	if not rate_limited_recovery_context_binding_exact_v1(sdk, context):
		return _failure("DEVELOPMENT_RATE_LIMITED_RECOVERY_CONTEXT_INVALID")
	return advance_behavior_solver_coupled_complete_energy_l15_v1(
		sdk, context, bound, memory, "candidate_command", String(memory.get("phase", "")), source_application
	)


## Stable candidate context: old per-controller contexts keep their exact
## contracts. Only this opt-in path accepts profile-selected controller data.
static func prepare_development_candidate_context_v1(sdk: Object, controller_id: String) -> Dictionary:
	var context := prepare_rearward_fold_context_v1(sdk)
	if context.get("ok") != true:
		return context
	context["schema_version"] = "sporespore_development_recovery_candidate_context_v1"
	context["recovery_controller_id"] = controller_id
	if not development_candidate_context_binding_exact_v1(sdk, context, controller_id):
		return _failure("DEVELOPMENT_CANDIDATE_CONTEXT_INVALID")
	return context


static func development_candidate_context_binding_exact_v1(sdk: Object, context: Dictionary,
	expected_controller_id: String = "") -> bool:
	var controller_id: Variant = context.get("recovery_controller_id")
	if (context.get("schema_version") != "sporespore_development_recovery_candidate_context_v1"
		or not (controller_id is String) or controller_id == RECOVERY_CONTROLLER_V6_ID
		or (expected_controller_id != "" and controller_id != expected_controller_id)):
		return false
	var owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
	if owner.profile_v1(controller_id).is_empty():
		return false
	var ancestor := context.duplicate(true)
	ancestor["schema_version"] = "sporespore_development_rearward_fold_context_v1"
	ancestor["recovery_controller_id"] = RECOVERY_CONTROLLER_V7_ID
	return rearward_fold_context_binding_exact_v1(sdk, ancestor)


static func rotation_aware_energy_ledger_context_binding_exact_v1(
	context: Dictionary,
) -> bool:
	var runtime_receipt_value: Variant = context.get("runtime_profile_receipt")
	var validation_value: Variant = (
		(runtime_receipt_value as Dictionary).get("validation")
		if runtime_receipt_value is Dictionary
		else null
	)
	return (
		String(context.get("schema_version", ""))
		== "sporespore_qsdk_r24d162_godot_rotation_aware_recovery_ledger_context_v11"
		and bool(context.get("ok", false))
		and runtime_receipt_value is Dictionary
		and validation_value is Dictionary
		and bool((runtime_receipt_value as Dictionary).get("instrumented_profile_selected", false))
		and String((runtime_receipt_value as Dictionary).get("profile_id", ""))
		== ProfileCapabilityScript.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		and bool((validation_value as Dictionary).get("rotation_aware_energy_ledger_profile_selected", false))
		and String(context.get("capability_variant_id", ""))
		== R162_ROTATION_AWARE_CAPABILITY_VARIANT_ID
		and String(context.get("adapter_energy_mapping_profile_id", ""))
		== R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		and String(context.get("predecessor_adapter_energy_mapping_profile_id", ""))
		== R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and bool(context.get("rotation_aware_energy_ledger_profile_selected", false))
		and String(context.get("recovery_energy_ledger_profile_id", ""))
		== R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		and String(context.get("solver_energy_consumer_contract_schema_version", ""))
		== R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA
		and String(context.get("solver_energy_telemetry_schema_version", ""))
		== R162_SOLVER_ENERGY_TELEMETRY_SCHEMA
		and String(context.get("solver_energy_telemetry_profile_id", ""))
		== R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID
		and String(context.get("r24d161_diagnosis_raw_sha256", ""))
		== R162_R161_DIAGNOSIS_RAW_SHA256
		and String(context.get("energy_route_id", "")) == R148_COMPLETE_ENERGY_ROUTE_ID
		and String(context.get("energy_mapping_profile_id", ""))
		== R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(context.get("partition_rule_id", "")) == R144_PARTITION_RULE_ID
		and bool(context.get("complete_energy_profile_selected", false))
		and bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		and bool(context.get("discrete_staging_complete_energy_profile_selected", false))
		and bool(context.get("route_aware_application_provenance_selected", false))
		and bool(context.get("accumulator_aware_invariant_validation_selected", false))
		and not bool(context.get("finite_behavior_pair_selected", true))
		and not bool(context.get("physical_world_construction_authorized", true))
		and not context.has("physical_world_construction_gate_id")
		and int(context.get("model_construction_count", -1)) == 0
		and int(context.get("world_attempt_count", -1)) == 0
		and int(context.get("world_build_count", -1)) == 0
		and int(context.get("solver_step_count", -1)) == 0
		and not bool(context.get("physics_state_modified", true))
		and not bool(context.get("physical_acceptance_authority", true))
		and not bool(context.get("release_authority", true))
	)


static func rotation_aware_contiguous_boundary_transport_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or String(context.get("schema_version", ""))
		!= "sporespore_qsdk_r24d168_godot_contiguous_boundary_transport_context_v15"
		or not bool(context.get("contiguous_boundary_transport_profile_selected", false))
		or String(context.get("contiguous_boundary_transport_design_id", ""))
		!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
		or String(context.get("contiguous_boundary_transport_profile_id", ""))
		!= R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
		or String(context.get("boundary_transport_state_schema_version", ""))
		!= ContiguousBoundaryTransportScript.STATE_SCHEMA
		or String(context.get("boundary_transport_pair_schema_version", ""))
		!= ContiguousBoundaryTransportScript.PAIR_SCHEMA
		or String(context.get("r167_transport_design_raw_sha256", ""))
		!= R168_R167_TRANSPORT_DESIGN_RAW_SHA256
		or bool(context.get("legacy_aliased_boundary_transport_selected", true))
		or bool(context.get("physical_world_construction_authorized", true))
		or String(context.get("physical_world_construction_blocked_by", ""))
		!= "QSDK-R24D168_ZERO_WORLD_ONLY"
		or context.has("physical_world_construction_gate_id")
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d162_godot_rotation_aware_recovery_ledger_context_v11"
	)
	predecessor["physical_world_construction_blocked_by"] = "QSDK-R24D162_ZERO_WORLD_ONLY"
	for key in [
		"r162_zero_world_context_sha256",
		"r167_transport_design_raw_sha256",
		"contiguous_boundary_transport_profile_selected",
		"contiguous_boundary_transport_design_id",
		"contiguous_boundary_transport_profile_id",
		"boundary_transport_state_schema_version",
		"boundary_transport_pair_schema_version",
		"legacy_aliased_boundary_transport_selected",
	]:
		predecessor.erase(key)
	return (
		rotation_aware_energy_ledger_context_binding_exact_v1(predecessor)
		and _sha256(sdk, predecessor)
		== String(context.get("r162_zero_world_context_sha256", ""))
	)


static func rotation_aware_route_ghost_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or String(context.get("schema_version", ""))
		!= "sporespore_qsdk_r24d163_godot_rotation_aware_recovery_route_context_v12"
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", ""))
		!= "QSDK-R24D163"
		or not bool(context.get("portable_core_identity_binding_selected", false))
		or String(context.get("route_ghost_profile_id", ""))
		!= R163_ROTATION_AWARE_ROUTE_GHOST_PROFILE_ID
		or not bool(context.get("route_ghost_only", false))
		or bool(context.get("recovery_behavior_evaluation_authorized", true))
		or context.has("physical_world_construction_blocked_by")
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d162_godot_rotation_aware_recovery_ledger_context_v11"
	)
	predecessor["physical_world_construction_authorized"] = false
	predecessor["physical_world_construction_blocked_by"] = (
		"QSDK-R24D162_ZERO_WORLD_ONLY"
	)
	for key in [
		"r162_zero_world_context_sha256",
		"physical_world_construction_gate_id",
		"portable_core_identity_binding_selected",
		"route_ghost_profile_id",
		"route_ghost_only",
		"recovery_behavior_evaluation_authorized",
	]:
		predecessor.erase(key)
	return (
		rotation_aware_energy_ledger_context_binding_exact_v1(predecessor)
		and _sha256(sdk, predecessor)
		== String(context.get("r162_zero_world_context_sha256", ""))
	)


static func rotation_aware_finite_behavior_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or String(context.get("schema_version", ""))
		!= "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_context_v13"
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", ""))
		!= "QSDK-R24D164"
		or not bool(context.get("portable_core_identity_binding_selected", false))
		or not bool(context.get("finite_behavior_pair_selected", false))
		or String(context.get("finite_behavior_profile_id", ""))
		!= R164_ROTATION_AWARE_FINITE_BEHAVIOR_PROFILE_ID
		or not bool(context.get("recovery_behavior_evaluation_authorized", false))
		or context.has("route_ghost_profile_id")
		or context.has("route_ghost_only")
		or context.has("physical_world_construction_blocked_by")
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d163_godot_rotation_aware_recovery_route_context_v12"
	)
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D163"
	predecessor["route_ghost_profile_id"] = R163_ROTATION_AWARE_ROUTE_GHOST_PROFILE_ID
	predecessor["route_ghost_only"] = true
	predecessor["finite_behavior_pair_selected"] = false
	predecessor["recovery_behavior_evaluation_authorized"] = false
	for key in [
		"r163_route_ghost_context_sha256",
		"finite_behavior_profile_id",
	]:
		predecessor.erase(key)
	return (
		rotation_aware_route_ghost_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor)
		== String(context.get("r163_route_ghost_context_sha256", ""))
	)


static func rotation_aware_source_trace_behavior_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or String(context.get("schema_version", ""))
		!= "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_context_v14"
		or String(context.get("physical_world_construction_gate_id", ""))
		!= "QSDK-R24D165"
		or not bool(context.get("rotation_aware_source_trace_validation_selected", false))
		or String(context.get("native_source_trace_validator_profile_id", ""))
		!= R165_ROTATION_AWARE_SOURCE_TRACE_VALIDATOR_PROFILE_ID
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_context_v13"
	)
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D164"
	for key in [
		"r164_finite_behavior_context_sha256",
		"rotation_aware_source_trace_validation_selected",
		"native_source_trace_validator_profile_id",
	]:
		predecessor.erase(key)
	return (
		rotation_aware_finite_behavior_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor)
		== String(context.get("r164_finite_behavior_context_sha256", ""))
	)


static func _discrete_staging_complete_energy_capability_binding_exact_v1(
	context: Dictionary,
) -> bool:
	var receipt_value: Variant = context.get("runtime_profile_receipt")
	var capability_value: Variant = context.get("capability")
	var binding_value: Variant = context.get("runtime_binding")
	var transition_value: Variant = context.get("capability_transition")
	if (
		not (receipt_value is Dictionary)
		or not (capability_value is Dictionary)
		or not (binding_value is Dictionary)
		or not (transition_value is Dictionary)
	):
		return false
	var receipt: Dictionary = receipt_value
	var capability: Dictionary = capability_value
	var binding: Dictionary = binding_value
	var transition: Dictionary = transition_value
	var expected_capability := (
		ProfileCapabilityScript.discrete_staging_complete_energy_capability_v1()
	)
	var expected_validation := (
		ProfileCapabilityScript.validate_discrete_staging_complete_energy_capability_v1(capability)
	)
	return (
		capability == expected_capability
		and receipt.get("capability", {}) == capability
		and receipt.get("validation", {}) == expected_validation
		and (
			String(receipt.get("profile_id", ""))
			== ProfileCapabilityScript.COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		)
		and (
			String(receipt.get("capability_variant_id", ""))
			== ProfileCapabilityScript.DISCRETE_STAGING_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		)
		and (
			String(receipt.get("adapter_energy_mapping_profile_id", ""))
			== R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		and (
			String(context.get("capability_variant_id", ""))
			== ProfileCapabilityScript.DISCRETE_STAGING_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		)
		and (
			String(context.get("adapter_energy_mapping_profile_id", ""))
			== R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		and bool(context.get("discrete_staging_complete_energy_profile_selected", false))
		and String(context.get("energy_route_id", "")) == R148_COMPLETE_ENERGY_ROUTE_ID
		and String(context.get("discrete_staging_rule_id", "")) == R148_STAGING_RULE_ID
		and (
			context.get("discrete_staging_force_contract", {})
			== DiscreteStagingRouteScript.force_contract_v1()
		)
		and not bool(context.get("physical_world_construction_authorized", true))
		and String(binding.get("collector_id", "")) == R148_COMPLETE_ENERGY_COLLECTOR_ID
		and (
			String(binding.get("capability_sha256", ""))
			== String(context.get("capability_sha256", ""))
		)
		and (
			String(binding.get("runtime_qualification_sha256", ""))
			== String(context.get("runtime_qualification_sha256", ""))
		)
		and int(transition.get("changed_channel_count", -1)) == 1
		and transition.get("changed_channel_ids", []) == ["energy_balance_ledger"]
		and (
			String(transition.get("capability_sha256", ""))
			== String(context.get("capability_sha256", ""))
		)
		and not bool(transition.get("runtime_binary_pair_changed", true))
		and not bool(transition.get("telemetry_profile_changed", true))
		and not bool(transition.get("physical_acceptance_authority", true))
		and not bool(transition.get("release_authority", true))
	)


static func _r149_discrete_staging_live_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or (
			String(context.get("schema_version", ""))
			!= "sporespore_qsdk_r24d149_godot_discrete_staging_live_transport_recovery_route_context_v5"
		)
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", "")) != "QSDK-R24D149"
		or not bool(context.get("live_boundary_transport_selected", false))
		or String(context.get("live_boundary_transport_id", "")) != R149_LIVE_BOUNDARY_TRANSPORT_ID
		or bool(context.get("live_boundary_transport_commissioned", true))
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = ("sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_recovery_route_context_v4")
	predecessor["physical_world_construction_authorized"] = false
	predecessor["physical_world_construction_next_gate"] = "QSDK-R24D149"
	for key in [
		"r148_zero_world_context_sha256",
		"physical_world_construction_gate_id",
		"live_boundary_transport_selected",
		"live_boundary_transport_id",
		"live_boundary_transport_commissioned",
	]:
		predecessor.erase(key)
	return (
		_discrete_staging_complete_energy_capability_binding_exact_v1(predecessor)
		and _sha256(sdk, predecessor) == String(context.get("r148_zero_world_context_sha256", ""))
	)


static func _r150_discrete_staging_live_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or (
			String(context.get("schema_version", ""))
			!= "sporespore_qsdk_r24d150_godot_discrete_staging_core_bound_recovery_route_context_v6"
		)
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", "")) != "QSDK-R24D150"
		or not bool(context.get("portable_core_identity_binding_selected", false))
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = ("sporespore_qsdk_r24d149_godot_discrete_staging_live_transport_recovery_route_context_v5")
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D149"
	predecessor.erase("r149_live_context_sha256")
	predecessor.erase("portable_core_identity_binding_selected")
	return (
		_r149_discrete_staging_live_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor) == String(context.get("r149_live_context_sha256", ""))
	)


static func _r151_discrete_staging_behavior_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or (
			String(context.get("schema_version", ""))
			!= "sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_context_v7"
		)
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", "")) != "QSDK-R24D151"
		or not bool(context.get("portable_core_identity_binding_selected", false))
		or not bool(context.get("finite_behavior_pair_selected", false))
		or (
			String(context.get("complete_energy_authority_profile_id", ""))
			!= R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		)
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = ("sporespore_qsdk_r24d150_godot_discrete_staging_core_bound_recovery_route_context_v6")
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D150"
	predecessor.erase("r150_core_bound_context_sha256")
	predecessor.erase("finite_behavior_pair_selected")
	predecessor.erase("complete_energy_authority_profile_id")
	return (
		_r150_discrete_staging_live_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor) == String(context.get("r150_core_bound_context_sha256", ""))
	)


static func _r152_route_aware_application_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or (
			String(context.get("schema_version", ""))
			!= "sporespore_qsdk_r24d152_godot_route_aware_application_provenance_context_v8"
		)
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", "")) != "QSDK-R24D152"
		or not bool(context.get("portable_core_identity_binding_selected", false))
		or not bool(context.get("route_aware_application_provenance_selected", false))
		or String(context.get("application_provenance_profile_id", ""))
		!= R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		or String(context.get("complete_energy_authority_profile_id", ""))
		!= R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d150_godot_discrete_staging_core_bound_recovery_route_context_v6"
	)
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D150"
	for key in [
		"r150_core_bound_context_sha256",
		"route_aware_application_provenance_selected",
		"application_provenance_profile_id",
		"complete_energy_authority_profile_id",
	]:
		predecessor.erase(key)
	return (
		_r150_discrete_staging_live_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor) == String(context.get("r150_core_bound_context_sha256", ""))
	)


static func _r153_route_aware_behavior_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or (
			String(context.get("schema_version", ""))
			!= "sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_context_v9"
		)
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", "")) != "QSDK-R24D153"
		or not bool(context.get("portable_core_identity_binding_selected", false))
		or not bool(context.get("route_aware_application_provenance_selected", false))
		or String(context.get("application_provenance_profile_id", ""))
		!= R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		or String(context.get("complete_energy_authority_profile_id", ""))
		!= R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		or not bool(context.get("finite_behavior_pair_selected", false))
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d152_godot_route_aware_application_provenance_context_v8"
	)
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D152"
	predecessor.erase("r152_route_aware_context_sha256")
	predecessor.erase("finite_behavior_pair_selected")
	return (
		_r152_route_aware_application_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor)
		== String(context.get("r152_route_aware_context_sha256", ""))
	)


static func _r154_accumulator_aware_behavior_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or (
			String(context.get("schema_version", ""))
			!= "sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_behavior_context_v10"
		)
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", "")) != "QSDK-R24D154"
		or not bool(context.get("finite_behavior_pair_selected", false))
		or not bool(context.get("route_aware_application_provenance_selected", false))
		or not bool(context.get("accumulator_aware_invariant_validation_selected", false))
		or (
			String(context.get("in_run_invariant_validator_profile_id", ""))
			!= R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID
		)
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_context_v9"
	)
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D153"
	predecessor.erase("r153_route_aware_behavior_context_sha256")
	predecessor.erase("accumulator_aware_invariant_validation_selected")
	predecessor.erase("in_run_invariant_validator_profile_id")
	return (
		_r153_route_aware_behavior_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor)
		== String(context.get("r153_route_aware_behavior_context_sha256", ""))
	)


static func contiguous_boundary_transport_route_ghost_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk == null
		or String(context.get("schema_version", ""))
		!= "sporespore_qsdk_r24d169_godot_contiguous_boundary_route_ghost_context_v16"
		or not bool(context.get("physical_world_construction_authorized", false))
		or String(context.get("physical_world_construction_gate_id", ""))
		!= "QSDK-R24D169"
		or not bool(context.get("portable_core_identity_binding_selected", false))
		or String(context.get("route_ghost_profile_id", ""))
		!= R169_CONTIGUOUS_BOUNDARY_ROUTE_GHOST_PROFILE_ID
		or not bool(context.get("route_ghost_only", false))
		or bool(context.get("recovery_behavior_evaluation_authorized", true))
		or context.has("physical_world_construction_blocked_by")
		or String(context.get("r168_zero_world_closure_raw_sha256", ""))
		!= R169_R168_ZERO_WORLD_CLOSURE_RAW_SHA256
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d168_godot_contiguous_boundary_transport_context_v15"
	)
	predecessor["physical_world_construction_authorized"] = false
	predecessor["physical_world_construction_blocked_by"] = "QSDK-R24D168_ZERO_WORLD_ONLY"
	for key in [
		"r168_transport_context_sha256",
		"r168_zero_world_closure_raw_sha256",
		"physical_world_construction_gate_id",
		"portable_core_identity_binding_selected",
		"route_ghost_profile_id",
		"route_ghost_only",
		"recovery_behavior_evaluation_authorized",
	]:
		predecessor.erase(key)
	return (
		rotation_aware_contiguous_boundary_transport_context_binding_exact_v1(
			sdk, predecessor
		)
		and _sha256(sdk, predecessor)
		== String(context.get("r168_transport_context_sha256", ""))
	)


static func contiguous_boundary_recovery_behavior_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	if (
		sdk != null
		and String(context.get("schema_version", ""))
		== "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
		and String(context.get("physical_world_construction_gate_id", ""))
		== "QSDK-R24D172"
		and String(context.get("contiguous_boundary_behavior_profile_id", ""))
		== R172_INITIALIZER_RETENTION_RECOVERY_BEHAVIOR_PROFILE_ID
		and String(context.get("r170_physical_closure_raw_sha256", ""))
		== R172_R170_PHYSICAL_CLOSURE_RAW_SHA256
		and String(
			context.get("r171_initializer_receipt_retention_closure_raw_sha256", "")
		)
		== R172_R171_ZERO_WORLD_CLOSURE_RAW_SHA256
	):
		var r170_predecessor := context.duplicate(true)
		r170_predecessor["schema_version"] = (
			"sporespore_qsdk_r24d170_godot_contiguous_boundary_recovery_behavior_context_v17"
		)
		r170_predecessor["physical_world_construction_gate_id"] = "QSDK-R24D170"
		r170_predecessor["contiguous_boundary_behavior_profile_id"] = (
			R170_CONTIGUOUS_BOUNDARY_RECOVERY_BEHAVIOR_PROFILE_ID
		)
		for key in [
			"r170_behavior_context_sha256",
			"r170_physical_closure_raw_sha256",
			"r171_initializer_receipt_retention_closure_raw_sha256",
		]:
			r170_predecessor.erase(key)
		return (
			contiguous_boundary_recovery_behavior_context_binding_exact_v1(
				sdk, r170_predecessor
			)
			and _sha256(sdk, r170_predecessor)
			== String(context.get("r170_behavior_context_sha256", ""))
		)
	if (
		sdk == null
		or String(context.get("schema_version", ""))
		!= "sporespore_qsdk_r24d170_godot_contiguous_boundary_recovery_behavior_context_v17"
		or String(context.get("physical_world_construction_gate_id", ""))
		!= "QSDK-R24D170"
		or not bool(context.get("finite_behavior_pair_selected", false))
		or not bool(context.get("recovery_behavior_evaluation_authorized", false))
		or not bool(context.get("rotation_aware_source_trace_validation_selected", false))
		or not bool(context.get("contiguous_boundary_transport_profile_selected", false))
		or String(context.get("contiguous_boundary_transport_design_id", ""))
		!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
		or String(context.get("contiguous_boundary_transport_profile_id", ""))
		!= R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
		or String(context.get("boundary_transport_state_schema_version", ""))
		!= ContiguousBoundaryTransportScript.STATE_SCHEMA
		or String(context.get("boundary_transport_pair_schema_version", ""))
		!= ContiguousBoundaryTransportScript.PAIR_SCHEMA
		or bool(context.get("legacy_aliased_boundary_transport_selected", true))
		or String(context.get("contiguous_boundary_behavior_profile_id", ""))
		!= R170_CONTIGUOUS_BOUNDARY_RECOVERY_BEHAVIOR_PROFILE_ID
		or String(context.get("r165_physical_closure_raw_sha256", ""))
		!= R170_R165_PHYSICAL_CLOSURE_RAW_SHA256
		or String(context.get("r169_route_ghost_physical_closure_raw_sha256", ""))
		!= R170_R169_PHYSICAL_CLOSURE_RAW_SHA256
	):
		return false
	var predecessor := context.duplicate(true)
	predecessor["schema_version"] = (
		"sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_context_v14"
	)
	predecessor["physical_world_construction_gate_id"] = "QSDK-R24D165"
	for key in [
		"r165_behavior_context_sha256",
		"r165_physical_closure_raw_sha256",
		"r169_route_ghost_physical_closure_raw_sha256",
		"contiguous_boundary_transport_profile_selected",
		"contiguous_boundary_transport_design_id",
		"contiguous_boundary_transport_profile_id",
		"boundary_transport_state_schema_version",
		"boundary_transport_pair_schema_version",
		"legacy_aliased_boundary_transport_selected",
		"contiguous_boundary_behavior_profile_id",
	]:
		predecessor.erase(key)
	return (
		rotation_aware_source_trace_behavior_context_binding_exact_v1(sdk, predecessor)
		and _sha256(sdk, predecessor)
		== String(context.get("r165_behavior_context_sha256", ""))
	)


static func _discrete_staging_live_context_binding_exact_v1(
	sdk: Object,
	context: Dictionary,
) -> bool:
	return (
		_r149_discrete_staging_live_context_binding_exact_v1(sdk, context)
		or _r150_discrete_staging_live_context_binding_exact_v1(sdk, context)
		or _r151_discrete_staging_behavior_context_binding_exact_v1(sdk, context)
		or _r152_route_aware_application_context_binding_exact_v1(sdk, context)
		or _r153_route_aware_behavior_context_binding_exact_v1(sdk, context)
		or _r154_accumulator_aware_behavior_context_binding_exact_v1(sdk, context)
		or rotation_aware_route_ghost_context_binding_exact_v1(sdk, context)
		or rotation_aware_finite_behavior_context_binding_exact_v1(sdk, context)
		or rotation_aware_source_trace_behavior_context_binding_exact_v1(sdk, context)
		or rotation_aware_contiguous_boundary_transport_context_binding_exact_v1(
			sdk, context
		)
		or contiguous_boundary_transport_route_ghost_context_binding_exact_v1(
			sdk, context
		)
		or contiguous_boundary_recovery_behavior_context_binding_exact_v1(
			sdk, context
		)
	)


static func _registered_recovery_controller_id_v1(controller_id: String) -> bool:
	# Prospective candidate identifiers can traverse the shared native wrapper.
	# This format check is not compiled registration or support authority; the
	# selected DLL must accept the actual planning request before motor writes.
	if CanonicalOwnershipL15.candidate_id_valid_v1(controller_id):
		return true
	return (
		controller_id
		in [
			RECOVERY_CONTROLLER_ID,
			RECOVERY_CONTROLLER_V2_ID,
			RECOVERY_CONTROLLER_V3_ID,
			RECOVERY_CONTROLLER_V4_ID,
			RECOVERY_CONTROLLER_V5_ID,
			RECOVERY_CONTROLLER_V6_ID,
			RECOVERY_CONTROLLER_V7_ID,
			RECOVERY_CONTROLLER_V8_ID,
		]
	)


static func _context_recovery_controller_id_v1(context: Dictionary) -> String:
	var controller_id := String(context.get("recovery_controller_id", RECOVERY_CONTROLLER_ID))
	if (context.get("schema_version") == "sporespore_development_recovery_candidate_context_v1"
		and CanonicalOwnershipL15.candidate_id_valid_v1(controller_id)):
		# This is a selection, not registration proof: the compiled planner
		# still refuses a syntactically valid but unregistered controller.
		return controller_id
	return controller_id if _registered_recovery_controller_id_v1(controller_id) else ""


## Pure, zero-world proof that the exact engine-neutral morphology compiles
## into the genuine Godot scene topology and canonical prone initializer.
static func native_world_blueprint_v1(sdk: Object, context: Dictionary) -> Dictionary:
	return NativeWorldScript.compile_blueprint_v1(sdk, context)


## Physical construction remains a separate, explicit operation.  Callers
## must pass the live SceneTree and await the result; no world can be opened by
## prepare_context_v1(), native_world_blueprint_v1(), or any conformance test.
static func build_native_world_v1(
	tree: SceneTree,
	sdk: Object,
	context: Dictionary,
) -> Dictionary:
	var discrete_staging_profile := bool(
		context.get("discrete_staging_complete_energy_profile_selected", false)
	)
	if (
		discrete_staging_profile
		and not _discrete_staging_live_context_binding_exact_v1(sdk, context)
	):
		return _failure("QSDK_R24D148_PHYSICAL_WORLD_CONTEXT_INVALID")
	var model := await NativeWorldScript.build_world_v1(tree, sdk, context)
	if not bool(model.get("ok", false)):
		return model
	if discrete_staging_profile:
		model["discrete_staging_accumulator"] = (
			DiscreteStagingRouteScript.initial_accumulator_v1()
		)
		model["discrete_staging_live_transport_id"] = (
			R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
			if bool(context.get("contiguous_boundary_transport_profile_selected", false))
			else R149_LIVE_BOUNDARY_TRANSPORT_ID
		)
	return model


## Bind the physical worker's inactive initializer readback to the R168 state
## machine. A future physical successor may call this only after separately
## authorizing world construction; R168 itself remains zero-world.
static func initialize_contiguous_boundary_transport_native_world_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
) -> Dictionary:
	if not bool(context.get("contiguous_boundary_transport_profile_selected", false)):
		return _failure("QSDK_R24D168_BOUNDARY_TRANSPORT_CONTEXT_REQUIRED")
	if (
		String(context.get("contiguous_boundary_transport_design_id", ""))
		!= ContiguousBoundaryTransportScript.TRANSPORT_DESIGN_ID
		or String(context.get("contiguous_boundary_transport_profile_id", ""))
		!= R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
	):
		return _failure("QSDK_R24D168_BOUNDARY_TRANSPORT_CONTEXT_INVALID")
	return NativeWorldScript.initialize_contiguous_boundary_transport_v1(
		sdk,
		model,
		attempt_id,
		arm_id,
		model_instance_id,
	)


static func contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
	sdk: Object,
	model: Dictionary,
	initializer_receipt: Dictionary,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
) -> bool:
	return NativeWorldScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
		sdk,
		model,
		initializer_receipt,
		attempt_id,
		arm_id,
		model_instance_id,
	)


static func initial_native_application_v1(sdk: Object, model: Dictionary) -> Dictionary:
	return NativeWorldScript.initial_candidate_application_v1(sdk, model)


## Behavior successors bind the first native step to the supervisor's true
## phase and retain candidate versus matched-zero identity even though both
## bootstrap with disabled motors.
static func initial_behavior_application_v1(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	return NativeWorldScript.initial_behavior_application_v1(sdk, model, arm_kind, phase)


static func initial_behavior_application_v2(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V2_ID:
		return _failure("QSDK_R24D113_INITIAL_CONTROLLER_ID_INVALID")
	return NativeWorldScript.initial_behavior_application_v2(
		sdk, model, arm_kind, phase, recovery_controller_id
	)


static func initial_behavior_application_v3(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V3_ID:
		return _failure("QSDK_R24D117_INITIAL_CONTROLLER_ID_INVALID")
	return NativeWorldScript.initial_behavior_application_v3(
		sdk, model, arm_kind, phase, recovery_controller_id
	)


static func initial_behavior_application_v4(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V4_ID:
		return _failure("QSDK_R24D120_INITIAL_CONTROLLER_ID_INVALID")
	return NativeWorldScript.initial_behavior_application_v4(
		sdk, model, arm_kind, phase, recovery_controller_id
	)


static func initial_behavior_application_v5(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V5_ID:
		return _failure("QSDK_R24D123_INITIAL_CONTROLLER_ID_INVALID")
	return NativeWorldScript.initial_behavior_application_v5(
		sdk, model, arm_kind, phase, recovery_controller_id
	)


static func initial_behavior_application_v6(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D127_INITIAL_CONTROLLER_ID_INVALID")
	var application := NativeWorldScript.initial_behavior_application_v6(
		sdk, model, arm_kind, phase, recovery_controller_id
	)
	if not bool(application.get("ok", false)):
		return application
	application["actuation_realization_id"] = R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
	application["native_contact_solver_coupled"] = true
	application["pre_solver_direct_body_impulse_write_count"] = 0
	application["energy_source_profile_id"] = ENERGY_MAPPING_PROFILE_ID
	return application


## The first R137 step remains the exact V6 actuation-free bootstrap. These
## fields make the selected complete-energy execution route explicit before
## the first solver step without inventing actuator work or changing the pose.
static func initial_behavior_application_complete_energy_v1(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D137_INITIAL_CONTROLLER_ID_INVALID")
	if not bool(model.get("complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D137_COMPLETE_ENERGY_MODEL_PROFILE_REQUIRED")
	var application := NativeWorldScript.initial_behavior_application_v6(
		sdk, model, arm_kind, phase, recovery_controller_id
	)
	if not bool(application.get("ok", false)):
		return application
	application["complete_energy_profile_selected"] = true
	application["energy_route_id"] = R136_COMPLETE_ENERGY_ROUTE_ID
	application["energy_mapping_profile_id"] = R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	application["actuation_realization_id"] = (R137_COMPLETE_ENERGY_ACTUATION_REALIZATION_ID)
	application["native_contact_solver_coupled"] = false
	application["native_joint_motors_disabled"] = true
	application["pre_solver_direct_body_impulse_write_count"] = 0
	application["structural_zero_actuator_work"] = true
	return application


## R144's bootstrap is still the exact V6 actuation-free first step. It binds
## the successor route before physics while correctly retaining zero enabled
## motors and zero actuator work for that step.
static func initial_behavior_application_solver_coupled_complete_energy_v1(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D144_INITIAL_CONTROLLER_ID_INVALID")
	if not bool(model.get("solver_coupled_complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_MODEL_PROFILE_REQUIRED")
	var application := NativeWorldScript.initial_behavior_application_v6(
		sdk, model, arm_kind, phase, recovery_controller_id
	)
	if not bool(application.get("ok", false)):
		return application
	application["complete_energy_profile_selected"] = true
	application["solver_coupled_complete_energy_profile_selected"] = true
	application["energy_route_id"] = R144_COMPLETE_ENERGY_ROUTE_ID
	application["energy_mapping_profile_id"] = R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	application["partition_rule_id"] = R144_PARTITION_RULE_ID
	application["actuation_realization_id"] = R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
	application["native_contact_solver_coupled"] = true
	application["native_joint_motors_disabled"] = true
	application["pre_solver_direct_body_impulse_write_count"] = 0
	application["structural_zero_actuator_work"] = true
	application["bootstrap_application"] = true
	application["actuator_mapping_id"] = ""
	application["work_mapping_id"] = ""
	return application


static func initial_behavior_application_discrete_staging_complete_energy_v1(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	if not bool(model.get("discrete_staging_complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D151_DISCRETE_STAGING_MODEL_PROFILE_REQUIRED")
	var application := initial_behavior_application_solver_coupled_complete_energy_v1(
		sdk,
		model,
		arm_kind,
		phase,
		recovery_controller_id,
	)
	if not bool(application.get("ok", false)):
		return application
	application["predecessor_complete_energy_route_id"] = R144_COMPLETE_ENERGY_ROUTE_ID
	application["energy_route_id"] = R148_COMPLETE_ENERGY_ROUTE_ID
	application["energy_mapping_profile_id"] = R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	application["discrete_staging_complete_energy_profile_selected"] = true
	application["complete_energy_authority_profile_id"] = (R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID)
	return application


static func initial_behavior_application_route_aware_discrete_staging_v2(
	sdk: Object,
	model: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
) -> Dictionary:
	var application := initial_behavior_application_discrete_staging_complete_energy_v1(
		sdk,
		model,
		arm_kind,
		phase,
		recovery_controller_id,
	)
	if not bool(application.get("ok", false)):
		return application
	application["application_provenance_profile_id"] = (
		R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
	)
	return application


## Sample one completed real native step, then feed that exact source
## population through the same binding used by zero-world conformance.
static func collect_native_world_observation_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	application_intent: Dictionary,
	semantic_step: int,
	phase: String,
) -> Dictionary:
	var measured := (
		NativeWorldScript
		. sample_native_step_v1(
			sdk,
			context,
			model,
			application_intent,
			semantic_step,
			phase,
		)
	)
	if not bool(measured.get("ok", false)):
		return measured
	var bound := compose_observations_v1(
		sdk,
		context,
		measured["observation_base"],
		measured["energy_source_receipt"],
		measured["source_component_receipts"],
	)
	if not bool(bound.get("ok", false)):
		return bound
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_native_bound_measurement_v1",
		"ok": true,
		"measurement": measured,
		"bound": bound,
		"native_runtime_observation_collection_executed": true,
		"model_construction_count": int(measured["model_construction_count"]),
		"world_attempt_count": int(measured["world_attempt_count"]),
		"world_build_count": int(measured["world_build_count"]),
		"solver_step_count": int(measured["solver_step_count"]),
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func cleanup_native_world_v1(model: Dictionary) -> void:
	NativeWorldScript.cleanup_world_v1(model)


## Bind one complete measured native sample to the strict collection request.
## `observation_base` contains every RecoveryObservationV2 field except schema
## and energy. `energy_source_receipt` must explicitly report the staging event
## count; absence is rejected and cannot become an implicit zero.
static func _compose_observations_for_energy_profile_v1(
	sdk: Object,
	context: Dictionary,
	observation_base: Dictionary,
	energy_source_receipt: Dictionary,
	source_component_receipts: Dictionary,
	route_id: String,
	mapping_profile_id: String,
	mapping_receipt_schema: String,
	bound_observations_schema: String,
	gate_prefix: String,
	complete_energy_profile: bool,
	solver_coupled_complete_energy_profile: bool = false,
	discrete_staging_complete_energy_profile: bool = false,
) -> Dictionary:
	if not bool(context.get("ok", false)):
		return _failure("%s_CONTEXT_NOT_READY" % gate_prefix)
	var energy_source_valid := (
		DiscreteStagingRouteScript.source_receipt_complete_v1(energy_source_receipt)
		if discrete_staging_complete_energy_profile
		else (
			_solver_coupled_complete_energy_source_complete_v1(energy_source_receipt)
			if solver_coupled_complete_energy_profile
			else (
				_complete_energy_source_complete_v1(energy_source_receipt)
				if complete_energy_profile
				else _energy_source_complete(energy_source_receipt)
			)
		)
	)
	if not energy_source_valid:
		return _failure("%s_ENERGY_SOURCE_INCOMPLETE" % gate_prefix)
	if (
		not bool(source_component_receipts.get("source_measurement", false))
		or (
			discrete_staging_complete_energy_profile
			and not DiscreteStagingRouteScript.source_components_complete_v1(
				sdk, energy_source_receipt, source_component_receipts
			)
		)
	):
		return _failure("%s_COMPONENT_RECEIPTS_NOT_MEASURED" % gate_prefix)
	var staging_event_count := int(
		energy_source_receipt["adapter_side_discrete_staging_event_count"]
	)
	var staging_exchange_j := float(
		energy_source_receipt["cumulative_signed_discrete_staging_exchange_j"]
	)
	if (
		not discrete_staging_complete_energy_profile
		and (staging_event_count != 0 or staging_exchange_j != 0.0)
	):
		return _failure("%s_GODOT_STAGING_ZERO_NOT_STRUCTURAL" % gate_prefix)

	var source_values_sha256 := _sha256(sdk, energy_source_receipt)
	var mapping_receipt := {
		"schema_version": mapping_receipt_schema,
		"route_id": route_id,
		"mapping_profile_id": mapping_profile_id,
		"source_values_sha256": source_values_sha256,
		"source_measurement": true,
		"adapter_side_discrete_staging_event_count": staging_event_count,
		"missing_measurement_synthesis_count": 0,
	}
	if discrete_staging_complete_energy_profile:
		mapping_receipt["cumulative_signed_discrete_staging_exchange_j"] = (staging_exchange_j)
		mapping_receipt["discrete_staging_rule_id"] = R148_STAGING_RULE_ID
		mapping_receipt["discrete_staging_observer_receipt_sha256"] = String(
			energy_source_receipt.get("discrete_staging_observer_receipt_sha256", "")
		)
		mapping_receipt["discrete_staging_mapping_receipt_sha256"] = String(
			energy_source_receipt.get("discrete_staging_mapping_receipt_sha256", "")
		)
		mapping_receipt["staging_mapped_to_external_work"] = false
		mapping_receipt["staging_mapped_to_passive_dissipation"] = false
	else:
		mapping_receipt["structural_zero_discrete_staging_exchange_j"] = (staging_exchange_j)
	if complete_energy_profile:
		mapping_receipt["constraint_exchange_partition_complete"] = true
		mapping_receipt["passive_dissipation_partition_complete"] = true
		mapping_receipt["component_partition_complete"] = true
		mapping_receipt["whole_step_mechanical_residual_used_as_component"] = false
		mapping_receipt["residual_balancing_permitted"] = false
		if solver_coupled_complete_energy_profile:
			mapping_receipt["partition_rule_id"] = R144_PARTITION_RULE_ID
			mapping_receipt["native_motor_work_subtracted_exactly_once"] = true
			mapping_receipt["motor_work_also_counted_as_constraint_exchange"] = false
	var mapping_receipt_sha256 := _sha256(sdk, mapping_receipt)
	var source_component_receipts_sha256 := _sha256(sdk, source_component_receipts)
	if (
		source_values_sha256.is_empty()
		or mapping_receipt_sha256.is_empty()
		or source_component_receipts_sha256.is_empty()
	):
		return _failure("%s_SOURCE_DIGEST_FAILED" % gate_prefix)

	var initial_energy := float(energy_source_receipt["initial_mechanical_energy_j"])
	var current_energy := float(energy_source_receipt["current_mechanical_energy_j"])
	var actuator_work := float(energy_source_receipt["cumulative_applied_actuator_work_j"])
	var external_work := float(energy_source_receipt["cumulative_signed_external_work_j"])
	var constraint_exchange := float(
		energy_source_receipt["cumulative_signed_constraint_exchange_j"]
	)
	var passive_dissipation := float(energy_source_receipt["cumulative_passive_dissipation_j"])
	var observation_v2 := observation_base.duplicate(true)
	observation_v2["schema_version"] = "sporespore_recovery_observation_v2"
	observation_v2["energy_balance"] = {
		"schema_version": "sporespore_recovery_energy_balance_ledger_v2",
		"equation_id":
		"current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2",
		"component_partition_id":
		"sporespore_disjoint_actuator_external_constraint_passive_energy_partition_v2",
		"source_profile_id": mapping_profile_id,
		"source_values_sha256": source_values_sha256,
		"initial_mechanical_energy_j": initial_energy,
		"current_mechanical_energy_j": current_energy,
		"cumulative_applied_actuator_work_j": actuator_work,
		"cumulative_signed_external_work_j": external_work,
		"cumulative_signed_constraint_exchange_j": constraint_exchange,
		"cumulative_passive_dissipation_j": passive_dissipation,
		"source_measurement": true,
	}
	var observation_base_sha256 := _sha256(sdk, observation_base)
	var ledger_sha256 := _sha256(sdk, observation_v2["energy_balance"])
	var portable_observation_sha256 := _sha256(sdk, observation_v2)
	var source_binding := {
		"schema_version": "sporespore_recovery_observation_v2_source_binding_v1",
		"producer_adapter_id": ADAPTER_ID,
		"source_route_id": route_id,
		"mapping_profile_id": mapping_profile_id,
		"mapping_receipt_sha256": mapping_receipt_sha256,
		"source_component_receipts_sha256": source_component_receipts_sha256,
		"observation_base_sha256": observation_base_sha256,
		"ledger_sha256": ledger_sha256,
		"portable_observation_sha256": portable_observation_sha256,
	}
	var source_chain_sha256 := _sha256(sdk, source_binding)
	if (
		observation_base_sha256.is_empty()
		or ledger_sha256.is_empty()
		or portable_observation_sha256.is_empty()
		or source_chain_sha256.is_empty()
	):
		return _failure("%s_OBSERVATION_BINDING_DIGEST_FAILED" % gate_prefix)
	source_binding["source_chain_sha256"] = source_chain_sha256

	var observation_v3 := observation_base.duplicate(true)
	observation_v3["schema_version"] = "sporespore_recovery_observation_v3"
	observation_v3["energy_balance"] = {
		"schema_version": "sporespore_recovery_energy_balance_ledger_v3",
		"equation_id":
		"current_minus_initial_minus_actuator_minus_external_minus_constraint_minus_discrete_staging_plus_passive_v3",
		"component_partition_id":
		"sporespore_disjoint_actuator_external_constraint_discrete_staging_passive_energy_partition_v3",
		"source_profile_id": mapping_profile_id,
		"source_values_sha256": source_values_sha256,
		"initial_mechanical_energy_j": initial_energy,
		"current_mechanical_energy_j": current_energy,
		"cumulative_applied_actuator_work_j": actuator_work,
		"cumulative_signed_external_work_j": external_work,
		"cumulative_signed_constraint_exchange_j": constraint_exchange,
		"cumulative_signed_discrete_staging_exchange_j": staging_exchange_j,
		"cumulative_passive_dissipation_j": passive_dissipation,
		"source_measurement": true,
	}
	return {
		"schema_version": bound_observations_schema,
		"ok": true,
		"observation_v2": observation_v2,
		"observation_v3": observation_v3,
		"source_binding": source_binding,
		"mapping_receipt": mapping_receipt,
		"adapter_side_discrete_staging_event_count": staging_event_count,
		"missing_measurement_synthesis_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func collection_request_v1(
	context: Dictionary,
	bound: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	return {
		"schema_version": "sporespore_recovery_native_collection_request_v3",
		"task_id": TASK_ID,
		"semantics_id": SEMANTICS_ID,
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"descriptor": exact_base_descriptor_v1(),
		"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
		"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
		"runtime_binding": (context["runtime_binding"] as Dictionary).duplicate(true),
		"arm_kind": arm_kind,
		"phase": phase,
		"observation": (bound["observation_v2"] as Dictionary).duplicate(true),
		"observation_source_binding": (bound["source_binding"] as Dictionary).duplicate(true),
	}


static func initialize_behavior_arm_v1(
	sdk: Object,
	context: Dictionary,
	arm_kind: String,
) -> Dictionary:
	if arm_kind != "candidate_command" and arm_kind != "matched_zero_command":
		return _failure("QSDK_R24D65_BEHAVIOR_ARM_KIND_INVALID")
	var initialization := (
		RecoveryRuntimeScript
		. initialize_v2(
			sdk,
			{
				"schema_version": "sporespore_recovery_initialize_request_v2",
				"task_id": TASK_ID,
				"semantics_id": SEMANTICS_ID,
				"actuator_profile_id": ACTUATOR_PROFILE_ID,
				"threshold_profile_id": THRESHOLD_PROFILE_ID,
				"descriptor": exact_base_descriptor_v1(),
				"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
				"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
				"arm_kind": arm_kind,
			}
		)
	)
	if (
		String(initialization.get("support_status", "")) != "supported_exact"
		or initialization.get("refusal_reason", "unexpected") != null
		or not (initialization.get("memory") is Dictionary)
		or not bool(initialization.get("controller_implemented", false))
		or not bool(initialization.get("physical_threshold_authority", false))
		or bool(initialization.get("physical_question_opened", true))
		or int(initialization.get("model_construction_count", -1)) != 0
		or int(initialization.get("world_attempt_count", -1)) != 0
		or int(initialization.get("world_build_count", -1)) != 0
		or int(initialization.get("solver_step_count", -1)) != 0
		or bool(initialization.get("physics_state_modified", true))
		or bool(initialization.get("prone_to_standing_claimed", true))
		or bool(initialization.get("physical_acceptance_authority", true))
		or bool(initialization.get("release_authority", true))
	):
		return _failure("QSDK_R24D65_BEHAVIOR_INITIALIZATION_REFUSED", initialization)
	var memory: Dictionary = initialization["memory"]
	if String(memory.get("phase", "")) != "confirm_prone":
		return _failure("QSDK_R24D65_BEHAVIOR_INITIAL_PHASE_INVALID", memory)
	return {
		"schema_version": "sporespore_qsdk_r24d65_godot_behavior_initialization_v1",
		"ok": true,
		"arm_kind": arm_kind,
		"initialization_receipt": initialization,
		"memory": memory.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Advance the frozen portable V4 supervisor over one already-measured native
## observation and plan exactly the next recovery- or stance-owned command.
## This function is pure with respect to physics; the caller owns every world
## construction, solver step, application, and retained observation.
static func advance_behavior_v4(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	memory: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	return _advance_behavior_versioned(sdk, context, bound, memory, arm_kind, phase, false)


## Additive R126 route. The returned portable step remains the exact V1 shape;
## the separate progression receipt carries incomplete-energy development use.
static func advance_behavior_v5(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	memory: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	return _advance_behavior_versioned(sdk, context, bound, memory, arm_kind, phase, true)


static func advance_behavior_complete_energy_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	memory: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	if not bool(context.get("complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	return _advance_behavior_versioned(sdk, context, bound, memory, arm_kind, phase, true)


static func advance_behavior_solver_coupled_complete_energy_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	memory: Dictionary,
	arm_kind: String,
	phase: String,
) -> Dictionary:
	if not bool(context.get("solver_coupled_complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	return _advance_behavior_versioned(sdk, context, bound, memory, arm_kind, phase, true)


## Explicit R10F-L15 entry point. The inner route retains the one real call in
## a per-invocation sink; this wrapper carries it through every later return,
## including portable-step, progression and control-planning failures.
static func advance_behavior_solver_coupled_complete_energy_l15_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	memory: Dictionary,
	arm_kind: String,
	phase: String,
	source_application: Dictionary,
) -> Dictionary:
	var capture := {"source_application": source_application}
	var result: Dictionary
	var preflight := _l15_advance_sources_v1(sdk, context, bound, memory, source_application)
	if preflight.get("ok") != true:
		result = preflight
	else:
		result = _advance_behavior_versioned(
			sdk, context, bound, memory, arm_kind, phase, true, capture
		)
	if result.is_empty():
		# A script error is not a valid empty success. Do not invent evidence
		# for a call whose boundary did not return a retained receipt.
		result = _failure("QSDK_R10F_L15_ADVANCE_RESULT_MISSING")
	if capture.has("collection_transport_retention"):
		result["collection_transport_retention"] = capture["collection_transport_retention"]
	elif capture.get("collection_boundary_entered") == true:
		# The invocation entered collection but did not return a receipt. Its
		# call/response state is unknown, not an asserted zero-call preflight.
		return _failure("QSDK_R10F_L15_COLLECTION_RETENTION_MISSING", result)
	else:
		result["collection_transport_retention"] = CollectionTransportL15.route_not_called_v1(
			String(result.get("failure_code", "QSDK_R10F_L15_COLLECTION_NOT_REACHED")),
			{
				"source_application": source_application,
				"source_memory": memory,
				"bound_observation": bound,
			}
		)
	return result


static func _l15_advance_sources_v1(
	sdk: Object, context: Dictionary, bound: Dictionary,
	memory: Dictionary, source_application: Dictionary
) -> Dictionary:
	if not bool(context.get("solver_coupled_complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	for key in ["morphology_context", "capability", "runtime_binding"]:
		if not (context.get(key) is Dictionary):
			return _failure("QSDK_R10F_L15_COLLECTION_CONTEXT_SOURCE_MISSING:%s" % key)
	for key in ["observation_v2", "observation_v3", "source_binding"]:
		if not (bound.get(key) is Dictionary):
			return _failure("QSDK_R10F_L15_COLLECTION_BOUND_SOURCE_MISSING:%s" % key)
	if source_application.is_empty():
		return _failure("QSDK_R10F_L15_COLLECTION_APPLICATION_SOURCE_MISSING")
	if (
		source_application.get("schema_version") == CanonicalOwnershipL15.APPLICATION_SCHEMA
		or source_application.has("canonical_controller_owner")
		or source_application.has("canonical_ownership_mapping")
		or source_application.has("canonical_ownership_mapping_sha256")
	):
		# The memory is the actual argument that this invocation will advance,
		# not the mapping's own embedded copy supplied back to its validator.
		return CanonicalOwnershipL15.validate_v1(sdk, source_application, memory,
			String(context.get("recovery_controller_id", "")))
	if source_application.get("controller_owner") in ["recovery_v6", "recovery_v7", "recovery_v8", "recovery_candidate"]:
		return _failure("QSDK_R10F_L15_PENDING_RECOVERY_MAPPING_REQUIRED")
	# Precondition recovery and later active commands retain their existing
	# application contract; only the new no-actuation schema requires mapping.
	return {"ok": true}


static func _advance_behavior_versioned(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	memory: Dictionary,
	arm_kind: String,
	phase: String,
	use_energy_partition_authority: bool,
	l15_collection_capture: Variant = null,
) -> Dictionary:
	if (
		(arm_kind != "candidate_command" and arm_kind != "matched_zero_command")
		or String(memory.get("phase", "")) != phase
	):
		return _failure("QSDK_R24D65_BEHAVIOR_STEP_IDENTITY_INVALID")
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	if recovery_controller_id.is_empty():
		return _failure("QSDK_R24D113_BEHAVIOR_CONTROLLER_CONTEXT_INVALID")
	var collection_request := collection_request_v1(context, bound, arm_kind, phase)
	var collection: Dictionary
	if l15_collection_capture is Dictionary:
		l15_collection_capture["collection_boundary_entered"] = true
		var captured := RecoveryRuntimeScript.collect_native_v3_l15_v1(
			sdk, collection_request, l15_collection_capture["source_application"], memory, bound
		)
		l15_collection_capture["collection_transport_retention"] = (
			captured["collection_transport_retention"]
		)
		collection = captured["collection"]
	else:
		collection = RecoveryRuntimeScript.collect_native_v3(sdk, collection_request)
	if (
		String(collection.get("support_status", "")) != "supported_exact"
		or collection.get("refusal_reason", "unexpected") != null
		or not bool(collection.get("supplied_native_post_step_observation_validated", false))
		or bool(collection.get("native_runtime_observation_collection_executed", true))
		or bool(collection.get("engine_identity_exposed_to_controller", true))
		or int(collection.get("model_construction_count", -1)) != 0
		or int(collection.get("world_attempt_count", -1)) != 0
		or int(collection.get("world_build_count", -1)) != 0
		or int(collection.get("solver_step_count", -1)) != 0
		or bool(collection.get("physics_state_modified", true))
		or bool(collection.get("physical_acceptance_authority", true))
		or bool(collection.get("release_authority", true))
	):
		var failure_detail := collection.duplicate(true)
		var observation_value: Variant = collection_request.get("observation")
		var orientation_value: Variant = null
		if observation_value is Dictionary:
			var state_value: Variant = (observation_value as Dictionary).get("state")
			if state_value is Dictionary:
				var base_pose_value: Variant = (state_value as Dictionary).get("base_pose_world")
				if base_pose_value is Dictionary:
					orientation_value = (base_pose_value as Dictionary).get("orientation_xyzw")
		failure_detail["base_orientation_diagnostic"] = (
			NativeWorldScript.diagnose_orientation_xyzw_v1(orientation_value)
		)
		return _failure("QSDK_R24D65_BEHAVIOR_COLLECTION_REFUSED", failure_detail)
	var step_request := {
		"schema_version": "sporespore_recovery_step_request_v4",
		"descriptor": exact_base_descriptor_v1(),
		"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
		"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
		"memory": memory.duplicate(true),
		"observation": (bound["observation_v3"] as Dictionary).duplicate(true),
	}
	var energy_partition_authority: Variant = null
	var development_progression: Variant = null
	var step: Dictionary
	var complete_energy_profile := bool(context.get("complete_energy_profile_selected", false))
	var solver_coupled_complete_energy_profile := bool(
		context.get("solver_coupled_complete_energy_profile_selected", false)
	)
	var discrete_staging_complete_energy_profile := bool(
		context.get("discrete_staging_complete_energy_profile_selected", false)
	)
	if use_energy_partition_authority:
		var authority := (
			commissioned_discrete_staging_complete_energy_partition_authority_v1(
				sdk, context, bound
			)
			if discrete_staging_complete_energy_profile
			else (
				solver_coupled_complete_energy_partition_authority_v1(context, bound)
				if solver_coupled_complete_energy_profile
				else (
					complete_energy_partition_authority_v1(context, bound)
					if complete_energy_profile
					else incomplete_energy_partition_authority_v1(context, bound)
				)
			)
		)
		if authority.is_empty():
			return _failure(
				(
					"QSDK_R24D151_COMPLETE_ENERGY_AUTHORITY_BINDING_INVALID"
					if discrete_staging_complete_energy_profile
					else (
						"QSDK_R24D144_COMPLETE_ENERGY_AUTHORITY_BINDING_INVALID"
						if solver_coupled_complete_energy_profile
						else (
							"QSDK_R24D136_COMPLETE_ENERGY_AUTHORITY_BINDING_INVALID"
							if complete_energy_profile
							else "QSDK_R24D126_ENERGY_AUTHORITY_BINDING_INVALID"
						)
					)
				)
			)
		energy_partition_authority = authority
		step_request["schema_version"] = "sporespore_recovery_step_request_v5"
		step_request["energy_partition_authority"] = authority.duplicate(true)
		var wrapped_step := RecoveryRuntimeScript.step_v5(sdk, step_request)
		if (
			String(wrapped_step.get("schema_version", "")) != "sporespore_recovery_step_receipt_v2"
			or not (wrapped_step.get("step") is Dictionary)
			or not (wrapped_step.get("development_progression") is Dictionary)
		):
			return _failure(
				(
					"QSDK_R24D151_PORTABLE_STEP_V2_REFUSED"
					if discrete_staging_complete_energy_profile
					else (
						"QSDK_R24D144_PORTABLE_STEP_V2_REFUSED"
						if solver_coupled_complete_energy_profile
						else (
							"QSDK_R24D136_PORTABLE_STEP_V2_REFUSED"
							if complete_energy_profile
							else "QSDK_R24D126_PORTABLE_STEP_V2_REFUSED"
						)
					)
				),
				wrapped_step,
			)
		step = wrapped_step["step"]
		development_progression = wrapped_step["development_progression"]
		var progression: Dictionary = development_progression
		var progression_common_invalid := (
			bool(progression.get("prone_to_standing_claimed", true))
			or bool(progression.get("physical_acceptance_authority", true))
			or bool(progression.get("release_authority", true))
			or int(progression.get("world_build_count", -1)) != 0
			or int(progression.get("solver_step_count", -1)) != 0
			or bool(progression.get("physics_state_modified", true))
		)
		var progression_profile_invalid := (
			(
				(
					String(progression.get("authority_profile_id", ""))
					!= (
						R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
						if discrete_staging_complete_energy_profile
						else (
							R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
							if solver_coupled_complete_energy_profile
							else R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
						)
					)
				)
				or not bool(progression.get("component_partition_complete", false))
				or not bool(progression.get("exact_balance_safety_authority", false))
				or bool(progression.get("development_progression_permitted", true))
				or not bool(progression.get("stable_stance_completion_authorized", false))
				or (
					bool(progression.get("physical_result_authorized", false))
					!= bool(step.get("physical_result", false))
				)
			)
			if complete_energy_profile
			else (
				(
					String(progression.get("authority_profile_id", ""))
					!= R126_ENERGY_AUTHORITY_PROFILE_ID
				)
				or bool(progression.get("component_partition_complete", true))
				or bool(progression.get("exact_balance_safety_authority", true))
				or not bool(progression.get("development_progression_permitted", false))
				or bool(progression.get("stable_stance_completion_authorized", true))
				or bool(progression.get("physical_result_authorized", true))
			)
		)
		if progression_common_invalid or progression_profile_invalid:
			return _failure(
				(
					"QSDK_R24D151_COMPLETE_ENERGY_PROGRESSION_INVALID"
					if discrete_staging_complete_energy_profile
					else (
						"QSDK_R24D144_COMPLETE_ENERGY_PROGRESSION_INVALID"
						if solver_coupled_complete_energy_profile
						else (
							"QSDK_R24D136_COMPLETE_ENERGY_PROGRESSION_INVALID"
							if complete_energy_profile
							else "QSDK_R24D126_DEVELOPMENT_PROGRESSION_INVALID"
						)
					)
				),
				progression,
			)
	else:
		step = RecoveryRuntimeScript.step_v4(sdk, step_request)
	if (
		String(step.get("support_status", "")) != "supported_exact"
		or step.get("refusal_reason", "unexpected") != null
		or not (step.get("memory") is Dictionary)
		or String(step.get("prior_phase", "")) != phase
		or not bool(step.get("post_step_observation_only", false))
		or bool(step.get("phase_skip_permitted", true))
		or not bool(step.get("controller_implemented", false))
		or not bool(step.get("physical_threshold_authority", false))
		or int(step.get("world_build_count", -1)) != 0
		or int(step.get("solver_step_count", -1)) != 0
		or bool(step.get("physics_state_modified", true))
		or bool(step.get("physical_acceptance_authority", true))
		or bool(step.get("release_authority", true))
	):
		return _failure("QSDK_R24D65_BEHAVIOR_PORTABLE_STEP_REFUSED", step)
	var next_memory: Dictionary = step["memory"]
	var next_phase := String(next_memory.get("phase", ""))
	if next_phase.is_empty():
		return _failure("QSDK_R24D65_BEHAVIOR_NEXT_PHASE_MISSING")
	var terminal := next_phase in ["complete", "failed", "refused"]
	var control: Variant = null
	var stance_observation_binding: Variant = null
	if not terminal:
		if next_phase == "stance_handoff" or next_phase == "stance_dwell":
			if arm_kind != "candidate_command":
				return _failure("QSDK_R24D65_MATCHED_ZERO_REACHED_STANCE_OWNER")
			if use_energy_partition_authority:
				var stance_v4 := (
					RecoveryRuntimeScript
					. plan_stance_control_v4(
						sdk,
						{
							"schema_version": "sporespore_recovery_stance_control_request_v4",
							"controller_id": DevelopmentStanceProfile.for_recovery_v1(recovery_controller_id),
							"collection": collection_request,
							"handoff_or_stance_step": step,
							"portable_step_observation_v3":
							(bound["observation_v3"] as Dictionary).duplicate(true),
							"energy_partition_authority":
							(energy_partition_authority as Dictionary).duplicate(true),
							"development_progression":
							(development_progression as Dictionary).duplicate(true),
						}
					)
				)
				if not stance_observation_binding_receipt_valid_v1(
					sdk,
					stance_v4,
					collection_request,
					step,
					bound["observation_v3"] as Dictionary,
					energy_partition_authority as Dictionary,
					development_progression as Dictionary,
				):
					return _failure("QSDK_R24D133_STANCE_OBSERVATION_BINDING_INVALID", stance_v4)
				control = stance_v4["control_receipt"]
				stance_observation_binding = stance_v4["observation_binding"]
			else:
				control = (
					RecoveryRuntimeScript
					. plan_stance_control_v3(
						sdk,
						{
							"schema_version": "sporespore_recovery_stance_control_request_v3",
							"controller_id": STANCE_CONTROLLER_ID,
							"collection": collection_request,
							"handoff_or_stance_step": step,
						}
					)
				)
		else:
			var next_collection := collection_request.duplicate(true)
			next_collection["phase"] = next_phase
			control = (
				RecoveryRuntimeScript
				. plan_control_v3(
					sdk,
					{
						"schema_version": "sporespore_recovery_control_request_v3",
						"controller_id": recovery_controller_id,
						"phase_step": int(next_memory.get("phase_steps_observed", -1)),
						"collection": next_collection,
					}
				)
			)
		if not (control is Dictionary):
			return _failure("QSDK_R24D65_BEHAVIOR_CONTROL_MISSING")
		var control_receipt: Dictionary = control
		if (
			String(control_receipt.get("support_status", "")) != "supported_exact"
			or control_receipt.get("refusal_reason", "unexpected") != null
			or not bool(control_receipt.get("controller_implemented", false))
			or not bool(control_receipt.get("deterministic", false))
			or int(control_receipt.get("engine_identity_input_count", -1)) != 0
			or int(control_receipt.get("engine_specific_policy_branch_count", -1)) != 0
			or bool(control_receipt.get("fallback_controller_active", true))
			or int(control_receipt.get("model_construction_count", -1)) != 0
			or int(control_receipt.get("world_attempt_count", -1)) != 0
			or int(control_receipt.get("world_build_count", -1)) != 0
			or int(control_receipt.get("solver_step_count", -1)) != 0
			or bool(control_receipt.get("physics_state_modified", true))
			or bool(control_receipt.get("physical_acceptance_authority", true))
			or bool(control_receipt.get("release_authority", true))
		):
			return _failure("QSDK_R24D65_BEHAVIOR_CONTROL_REFUSED", control_receipt)
	var result := {
		"schema_version": "sporespore_qsdk_r24d65_godot_behavior_advance_v1",
		"ok": true,
		"collection_request": collection_request,
		"collection_receipt": collection,
		"step_receipt": step,
		"next_memory": next_memory.duplicate(true),
		"terminal": terminal,
		"control_receipt": control,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if use_energy_partition_authority:
		result["schema_version"] = (
			"sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_advance_v1"
			if discrete_staging_complete_energy_profile
			else (
				"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_behavior_advance_v1"
				if solver_coupled_complete_energy_profile
				else (
					"sporespore_qsdk_r24d136_godot_complete_energy_behavior_advance_v1"
					if complete_energy_profile
					else R126_DEVELOPMENT_ROUTE_ID
				)
			)
		)
		result["energy_partition_authority"] = energy_partition_authority
		result["development_progression_receipt"] = development_progression
		result["stance_observation_binding_receipt"] = stance_observation_binding
	return result


static func collect_complete_energy_native_world_observation_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	application_intent: Dictionary,
	semantic_step: int,
	phase: String,
) -> Dictionary:
	if not bool(context.get("complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	var measured := (
		NativeWorldScript
		. sample_native_step_v1(
			sdk,
			context,
			model,
			application_intent,
			semantic_step,
			phase,
		)
	)
	if not bool(measured.get("ok", false)):
		return measured
	var bound := compose_complete_energy_observations_v1(
		sdk,
		context,
		measured["observation_base"],
		measured["energy_source_receipt"],
		measured["source_component_receipts"],
	)
	if not bool(bound.get("ok", false)):
		return bound
	var authority := complete_energy_partition_authority_v1(context, bound)
	if authority.is_empty():
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_AUTHORITY_BINDING_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d136_godot_complete_energy_native_bound_measurement_v1",
		"ok": true,
		"measurement": measured,
		"bound": bound,
		"energy_partition_authority": authority,
		"energy_partition_authority_sha256": _sha256(sdk, authority),
		"native_runtime_observation_collection_executed": true,
		"model_construction_count": int(measured["model_construction_count"]),
		"world_attempt_count": int(measured["world_attempt_count"]),
		"world_build_count": int(measured["world_build_count"]),
		"solver_step_count": int(measured["solver_step_count"]),
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func collect_solver_coupled_complete_energy_native_world_observation_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	application_intent: Dictionary,
	semantic_step: int,
	phase: String,
) -> Dictionary:
	if not bool(context.get("solver_coupled_complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	var measured := (
		NativeWorldScript
		. sample_native_step_v1(
			sdk,
			context,
			model,
			application_intent,
			semantic_step,
			phase,
		)
	)
	if not bool(measured.get("ok", false)):
		return measured
	var bound := compose_solver_coupled_complete_energy_observations_v1(
		sdk,
		context,
		measured["observation_base"],
		measured["energy_source_receipt"],
		measured["source_component_receipts"],
	)
	if not bool(bound.get("ok", false)):
		return bound
	var authority := solver_coupled_complete_energy_partition_authority_v1(context, bound)
	if authority.is_empty():
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_AUTHORITY_BINDING_INVALID")
	return {
		"schema_version":
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_bound_measurement_v1",
		"ok": true,
		"measurement": measured,
		"bound": bound,
		"energy_partition_authority": authority,
		"energy_partition_authority_sha256": _sha256(sdk, authority),
		"native_runtime_observation_collection_executed": true,
		"model_construction_count": int(measured["model_construction_count"]),
		"world_attempt_count": int(measured["world_attempt_count"]),
		"world_build_count": int(measured["world_build_count"]),
		"solver_step_count": int(measured["solver_step_count"]),
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R149's live production collector: retain the callback/post-solver boundary
## pair, invoke the already-qualified R148 observer, advance its append-only
## accumulator once, and then use the exact R148 portable mapping seam.
static func collect_discrete_staging_complete_energy_native_world_observation_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	application_intent: Dictionary,
	semantic_step: int,
	phase: String,
	development_profiler: RefCounted = null,
	development_context_cache: RefCounted = null,
) -> Dictionary:
	if development_profiler != null:
		development_profiler.begin_v1("global_context_validation")
	var context_valid: bool = (
		development_context_cache.validate_v1(sdk, context, 1)
		if development_context_cache != null
		else _discrete_staging_live_context_binding_exact_v1(sdk, context)
	)
	if development_profiler != null:
		development_profiler.end_v1("global_context_validation")
	if not context_valid:
		return _failure("QSDK_R24D149_LIVE_CONTEXT_REQUIRED")
	if development_profiler != null:
		development_profiler.begin_v1("native_sampling_and_source_validation")
	var measured := (
		NativeWorldScript
		. sample_native_step_v1(
			sdk,
			context,
			model,
			application_intent,
			semantic_step,
			phase,
		)
	)
	if development_profiler != null:
		development_profiler.end_v1("native_sampling_and_source_validation")
	if not bool(measured.get("ok", false)):
		return measured
	var capture_value: Variant = measured.get("discrete_staging_boundary_capture")
	var components_value: Variant = measured.get("source_component_receipts")
	var accumulator_value: Variant = model.get("discrete_staging_accumulator")
	if (
		not (capture_value is Dictionary)
		or not (components_value is Dictionary)
		or not (accumulator_value is Dictionary)
	):
		return _failure("QSDK_R24D149_LIVE_SOURCE_POPULATION_MISSING")
	var capture: Dictionary = capture_value
	var predecessor_components: Dictionary = components_value
	var contiguous_transport_selected := bool(
		context.get("contiguous_boundary_transport_profile_selected", false)
	)
	var transport_state_after: Dictionary = {}
	if contiguous_transport_selected:
		var transport_state_value: Variant = capture.get("transport_state_after")
		if (
			not (transport_state_value is Dictionary)
			or not ContiguousBoundaryTransportScript.state_valid_v1(
				sdk, transport_state_value
			)
			or int((transport_state_value as Dictionary).get("state_revision", -1))
			!= semantic_step
			or int(capture.get("cache_advance_count_pending_commit", -1)) != 1
		):
			return _failure("QSDK_R24D168_PENDING_TRANSPORT_STATE_INVALID")
		transport_state_after = (transport_state_value as Dictionary).duplicate(true)
	var retained_capture := capture.duplicate(true)
	retained_capture.erase("transport_state_after")
	var solver_receipt_value: Variant = predecessor_components.get("solver_energy_exchange_receipt")
	var source_trace_value: Variant = predecessor_components.get("source_trace")
	if (
		not bool(capture.get("ok", false))
		or int(capture.get("semantic_step", -1)) != semantic_step
		or not (capture.get("ordered_body_boundaries") is Array)
		or not (solver_receipt_value is Dictionary)
		or not (source_trace_value is Dictionary)
	):
		return _failure("QSDK_R24D149_LIVE_SOURCE_POPULATION_INVALID")
	var solver_receipt: Dictionary = solver_receipt_value
	var source_trace: Dictionary = source_trace_value
	var displacement := _vector3_from_json_v1(
		(
			solver_receipt
			. get(
				"position_constraint_mass_weighted_displacement_kg_m",
				{},
			)
		)
	)
	var observer_receipt := (
		DiscreteStagingRouteScript
		. measure_native_step_v1(
			semantic_step,
			semantic_step - 1,
			float(source_trace.get("solver_step_s", NAN)),
			(capture["ordered_body_boundaries"] as Array).duplicate(true),
			displacement,
		)
	)
	if not bool(observer_receipt.get("ok", false)):
		return observer_receipt
	if development_profiler != null:
		development_profiler.begin_v1("energy_observation_composition")
	var bound := compose_discrete_staging_complete_energy_observations_v1(
		sdk,
		context,
		measured["observation_base"],
		measured["energy_source_receipt"],
		predecessor_components,
		observer_receipt,
		accumulator_value,
	)
	if development_profiler != null:
		development_profiler.end_v1("energy_observation_composition")
	if not bool(bound.get("ok", false)):
		return bound
	var mapping: Dictionary = bound["native_to_portable_staging_mapping"]
	var mapped_measurement := measured.duplicate(true)
	var rotation_aware := bool(
		context.get("rotation_aware_energy_ledger_profile_selected", false)
	)
	mapped_measurement["schema_version"] = (
		"sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_measurement_v1"
		if rotation_aware
		else "sporespore_qsdk_r24d149_godot_jolt_discrete_staging_native_measurement_v1"
	)
	mapped_measurement["energy_source_receipt"] = mapping["energy_source_receipt"]
	mapped_measurement["source_component_receipts"] = (mapping["source_component_receipts"])
	mapped_measurement["discrete_staging_observer_receipt"] = observer_receipt
	mapped_measurement["discrete_staging_boundary_capture"] = retained_capture
	if rotation_aware:
		mapped_measurement["recovery_energy_ledger_profile_id"] = (
			R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		)
		mapped_measurement["rotation_integration_exchange_included_exactly_once"] = true
	model["discrete_staging_accumulator"] = mapping["accumulator_after"]
	model["adapter_side_discrete_staging_event_count"] = semantic_step
	if contiguous_transport_selected:
		model["contiguous_boundary_transport_state"] = transport_state_after
	return {
		"schema_version": (
			"sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_bound_measurement_v1"
			if rotation_aware
			else "sporespore_qsdk_r24d149_godot_discrete_staging_complete_energy_native_bound_measurement_v1"
		),
		"ok": true,
		"measurement": mapped_measurement,
		"bound": bound,
		"discrete_staging_boundary_capture": retained_capture,
		"discrete_staging_observer_receipt": observer_receipt,
		"discrete_staging_accumulator_after": mapping["accumulator_after"],
		"discrete_staging_accumulator_after_sha256": mapping["accumulator_after_sha256"],
		"native_runtime_observation_collection_executed": true,
		"rotation_aware_energy_ledger_profile_selected": rotation_aware,
		"contiguous_boundary_transport_profile_selected": contiguous_transport_selected,
		"contiguous_boundary_transport_state_revision": (
			int(transport_state_after.get("state_revision", -1))
			if contiguous_transport_selected
			else -1
		),
		"contiguous_boundary_transport_cache_advance_committed": (
			contiguous_transport_selected
		),
		"recovery_energy_ledger_profile_id": (
			R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID if rotation_aware else ""
		),
		"model_construction_count": int(measured["model_construction_count"]),
		"world_attempt_count": int(measured["world_attempt_count"]),
		"world_build_count": int(measured["world_build_count"]),
		"solver_step_count": int(measured["solver_step_count"]),
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func compose_observations_v1(
	sdk: Object,
	context: Dictionary,
	observation_base: Dictionary,
	energy_source_receipt: Dictionary,
	source_component_receipts: Dictionary,
) -> Dictionary:
	return _compose_observations_for_energy_profile_v1(
		sdk,
		context,
		observation_base,
		energy_source_receipt,
		source_component_receipts,
		ROUTE_ID,
		ENERGY_MAPPING_PROFILE_ID,
		"sporespore_qsdk_r24d57_godot_energy_mapping_receipt_v1",
		"sporespore_qsdk_r24d57_godot_bound_observations_v1",
		"QSDK_R24D57",
		false,
	)


static func compose_complete_energy_observations_v1(
	sdk: Object,
	context: Dictionary,
	observation_base: Dictionary,
	energy_source_receipt: Dictionary,
	source_component_receipts: Dictionary,
) -> Dictionary:
	if not bool(context.get("complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	return _compose_observations_for_energy_profile_v1(
		sdk,
		context,
		observation_base,
		energy_source_receipt,
		source_component_receipts,
		R136_COMPLETE_ENERGY_ROUTE_ID,
		R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"sporespore_qsdk_r24d136_godot_complete_energy_mapping_receipt_v1",
		"sporespore_qsdk_r24d136_godot_complete_energy_bound_observations_v1",
		"QSDK_R24D136",
		true,
	)


static func compose_solver_coupled_complete_energy_observations_v1(
	sdk: Object,
	context: Dictionary,
	observation_base: Dictionary,
	energy_source_receipt: Dictionary,
	source_component_receipts: Dictionary,
) -> Dictionary:
	if (
		not bool(context.get("complete_energy_profile_selected", false))
		or not bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		or String(context.get("energy_route_id", "")) != R144_COMPLETE_ENERGY_ROUTE_ID
		or (
			String(context.get("energy_mapping_profile_id", ""))
			!= R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or not _solver_coupled_complete_energy_capability_binding_exact_v1(context)
	):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	return _compose_observations_for_energy_profile_v1(
		sdk,
		context,
		observation_base,
		energy_source_receipt,
		source_component_receipts,
		R144_COMPLETE_ENERGY_ROUTE_ID,
		R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_mapping_receipt_v1",
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_bound_observations_v1",
		"QSDK_R24D144",
		true,
		true,
	)


## Project the R162 native source population through the unchanged R148
## staging mapper without erasing its new rotation receipt. The R148 portable
## route and mapping IDs stay exact because rotation is measurement
## completeness inside the existing constraint channel, not a new portable
## policy input. Both the original v6 receipts and the compatibility
## projection are content-addressed in the additive mapping receipt.
static func _map_rotation_aware_discrete_staging_step_v1(
	sdk: Object,
	predecessor_energy_source_receipt: Dictionary,
	predecessor_source_component_receipts: Dictionary,
	discrete_staging_observer_receipt: Dictionary,
	discrete_staging_accumulator_before: Dictionary,
) -> Dictionary:
	if not _rotation_aware_predecessor_sources_exact_v1(
		sdk,
		predecessor_energy_source_receipt,
		predecessor_source_component_receipts,
	):
		return _failure("QSDK_R24D163_ROTATION_AWARE_PREDECESSOR_INVALID")
	var original_energy_sha256 := _sha256(sdk, predecessor_energy_source_receipt)
	var original_components_sha256 := _sha256(
		sdk, predecessor_source_component_receipts
	)
	if original_energy_sha256.is_empty() or original_components_sha256.is_empty():
		return _failure("QSDK_R24D163_ROTATION_AWARE_PREDECESSOR_DIGEST_FAILED")

	var projected_energy := predecessor_energy_source_receipt.duplicate(true)
	projected_energy["schema_version"] = (
		DiscreteStagingRouteScript.PREDECESSOR_SOURCE_RECEIPT_SCHEMA
	)
	var projected_components := predecessor_source_component_receipts.duplicate(true)
	projected_components["schema_version"] = (
		DiscreteStagingRouteScript.PREDECESSOR_SOURCE_COMPONENT_RECEIPTS_SCHEMA
	)
	var projected_energy_sha256 := _sha256(sdk, projected_energy)
	var projected_components_sha256 := _sha256(sdk, projected_components)
	var mapped := DiscreteStagingRouteScript.map_step_v1(
		sdk,
		projected_energy,
		projected_components,
		discrete_staging_observer_receipt,
		discrete_staging_accumulator_before,
	)
	if not bool(mapped.get("ok", false)):
		return mapped
	if projected_energy_sha256.is_empty() or projected_components_sha256.is_empty():
		return _failure("QSDK_R24D163_ROTATION_AWARE_PROJECTION_DIGEST_FAILED")

	var mapping_receipt: Dictionary = mapped["mapping_receipt"]
	mapping_receipt["recovery_energy_ledger_profile_id"] = (
		R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	mapping_receipt["rotation_aware_predecessor_energy_source_receipt_sha256"] = (
		original_energy_sha256
	)
	mapping_receipt[
		"rotation_aware_predecessor_source_component_receipts_sha256"
	] = original_components_sha256
	mapping_receipt["predecessor_energy_source_projection_sha256"] = (
		projected_energy_sha256
	)
	mapping_receipt["predecessor_source_component_projection_sha256"] = (
		projected_components_sha256
	)
	mapping_receipt["rotation_integration_exchange_included_exactly_once"] = true
	mapping_receipt["portable_energy_route_changed"] = false
	mapping_receipt["portable_energy_mapping_profile_changed"] = false
	var mapping_receipt_sha256 := _sha256(sdk, mapping_receipt)
	if mapping_receipt_sha256.is_empty():
		return _failure("QSDK_R24D163_ROTATION_AWARE_MAPPING_DIGEST_FAILED")

	var energy_source: Dictionary = mapped["energy_source_receipt"]
	energy_source["recovery_energy_ledger_profile_id"] = (
		R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	energy_source["rotation_aware_predecessor_energy_source_receipt_sha256"] = (
		original_energy_sha256
	)
	energy_source[
		"rotation_aware_predecessor_source_component_receipts_sha256"
	] = original_components_sha256
	energy_source["rotation_integration_exchange_included_exactly_once"] = true
	energy_source["discrete_staging_mapping_receipt_sha256"] = mapping_receipt_sha256

	var components: Dictionary = mapped["source_component_receipts"]
	components["recovery_energy_ledger_profile_id"] = (
		R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	components["rotation_aware_predecessor_energy_source_receipt_sha256"] = (
		original_energy_sha256
	)
	components[
		"rotation_aware_predecessor_source_component_receipts_sha256"
	] = original_components_sha256
	components["rotation_integration_exchange_included_exactly_once"] = true
	components["discrete_staging_mapping_receipt"] = mapping_receipt
	components["discrete_staging_mapping_receipt_sha256"] = mapping_receipt_sha256

	if (
		not DiscreteStagingRouteScript.source_receipt_complete_v1(energy_source)
		or not DiscreteStagingRouteScript.source_components_complete_v1(
			sdk, energy_source, components
		)
	):
		return _failure("QSDK_R24D163_ROTATION_AWARE_MAPPED_SOURCE_INVALID")
	mapped["schema_version"] = (
		"sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_step_mapping_v1"
	)
	mapped["energy_source_receipt"] = energy_source
	mapped["source_component_receipts"] = components
	mapped["mapping_receipt"] = mapping_receipt
	mapped["mapping_receipt_sha256"] = mapping_receipt_sha256
	mapped["rotation_aware_predecessor_energy_source_receipt"] = (
		predecessor_energy_source_receipt.duplicate(true)
	)
	mapped["rotation_aware_predecessor_source_component_receipts"] = (
		predecessor_source_component_receipts.duplicate(true)
	)
	mapped["rotation_aware_predecessor_energy_source_receipt_sha256"] = (
		original_energy_sha256
	)
	mapped[
		"rotation_aware_predecessor_source_component_receipts_sha256"
	] = original_components_sha256
	mapped["recovery_energy_ledger_profile_id"] = (
		R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	mapped["rotation_integration_exchange_included_exactly_once"] = true
	return mapped


static func _rotation_aware_predecessor_sources_exact_v1(
	sdk: Object,
	energy_source: Dictionary,
	components: Dictionary,
) -> bool:
	if sdk == null:
		return false
	var solver_value: Variant = components.get("solver_energy_exchange_receipt")
	var partition_value: Variant = components.get("solver_coupled_partition_receipt")
	if not (solver_value is Dictionary) or not (partition_value is Dictionary):
		return false
	var solver: Dictionary = solver_value
	var partition: Dictionary = partition_value
	var semantic_step := int(energy_source.get("semantic_step", -1))
	return (
		String(energy_source.get("schema_version", ""))
		== R162_ROTATION_AWARE_SOURCE_RECEIPT_SCHEMA
		and String(components.get("schema_version", ""))
		== R162_ROTATION_AWARE_COMPONENT_RECEIPTS_SCHEMA
		and semantic_step > 0
		and int(components.get("semantic_step", -2)) == semantic_step
		and String(energy_source.get("recovery_energy_ledger_profile_id", ""))
		== R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		and String(components.get("recovery_energy_ledger_profile_id", ""))
		== R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		and String(solver.get("schema_version", ""))
		== R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA
		and String(solver.get("telemetry_schema_version", ""))
		== R162_SOLVER_ENERGY_TELEMETRY_SCHEMA
		and String(solver.get("telemetry_profile_id", ""))
		== R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID
		and String(partition.get("schema_version", ""))
		== R162_ROTATION_AWARE_PARTITION_CONTRACT_SCHEMA
		and String(partition.get("recovery_energy_ledger_profile_id", ""))
		== R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		and int(partition.get("numerical_term_count", -1)) == 14
		and bool(solver.get("rotation_integration_partition_complete", false))
		and bool(partition.get("rotation_integration_partition_complete", false))
		and bool(
			partition.get(
				"rotation_integration_exchange_included_exactly_once", false
			)
		)
		and bool(
			energy_source.get(
				"rotation_integration_exchange_included_exactly_once", false
			)
		)
		and bool(
			components.get(
				"rotation_integration_exchange_included_exactly_once", false
			)
		)
		and is_finite(
			float(
				energy_source.get("rotation_integration_kinetic_exchange_j", NAN)
			)
		)
		and float(energy_source.get("rotation_integration_kinetic_exchange_j", NAN))
		== float(partition.get("rotation_integration_kinetic_exchange_j", NAN))
		and float(energy_source.get("step_signed_constraint_exchange_j", NAN))
		== float(partition.get("step_signed_constraint_exchange_j", NAN))
		and float(energy_source.get("raw_step_signed_solver_exchange_j", NAN))
		== float(partition.get("raw_step_signed_solver_exchange_j", NAN))
		and float(energy_source.get("step_actuator_work_j", NAN))
		== float(partition.get("step_actuator_work_j", NAN))
		and _sha256(sdk, solver)
		== String(components.get("solver_energy_exchange_receipt_sha256", ""))
		and _sha256(sdk, partition)
		== String(components.get("solver_coupled_partition_receipt_sha256", ""))
		and String(components.get("solver_energy_exchange_receipt_sha256", ""))
		== String(energy_source.get("solver_energy_exchange_receipt_sha256", ""))
		and String(components.get("solver_coupled_partition_receipt_sha256", ""))
		== String(energy_source.get("solver_coupled_partition_receipt_sha256", ""))
		and bool(energy_source.get("native_motor_work_subtracted_exactly_once", false))
		and not bool(
			energy_source.get("motor_work_also_counted_as_constraint_exchange", true)
		)
		and bool(energy_source.get("component_partition_complete", false))
		and bool(components.get("component_partition_complete", false))
		and bool(energy_source.get("source_measurement", false))
		and bool(components.get("source_measurement", false))
		and not bool(
			energy_source.get(
				"mechanical_energy_residual_used_as_work_source", true
			)
		)
		and not bool(
			components.get("mechanical_energy_residual_used_as_work_source", true)
		)
	)


## R148's pure production mapping seam. The observer and accumulator are
## validated and content-addressed before the generic portable V3 composer is
## allowed to consume a nonzero staging channel.
static func compose_discrete_staging_complete_energy_observations_v1(
	sdk: Object,
	context: Dictionary,
	observation_base: Dictionary,
	predecessor_energy_source_receipt: Dictionary,
	predecessor_source_component_receipts: Dictionary,
	discrete_staging_observer_receipt: Dictionary,
	discrete_staging_accumulator_before: Dictionary,
) -> Dictionary:
	if (
		not bool(context.get("complete_energy_profile_selected", false))
		or not bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		or not bool(context.get("discrete_staging_complete_energy_profile_selected", false))
		or String(context.get("energy_route_id", "")) != R148_COMPLETE_ENERGY_ROUTE_ID
		or (
			String(context.get("energy_mapping_profile_id", ""))
			!= R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or not (
			_discrete_staging_complete_energy_capability_binding_exact_v1(context)
			or _discrete_staging_live_context_binding_exact_v1(sdk, context)
			or rearward_fold_context_binding_exact_v1(sdk, context)
			or rate_limited_recovery_context_binding_exact_v1(sdk, context)
			or development_candidate_context_binding_exact_v1(sdk, context)
		)
	):
		return _failure("QSDK_R24D148_COMPLETE_ENERGY_CONTEXT_REQUIRED")
	var rotation_aware := bool(
		context.get("rotation_aware_energy_ledger_profile_selected", false)
	)
	var mapped := (
		_map_rotation_aware_discrete_staging_step_v1(
			sdk,
			predecessor_energy_source_receipt,
			predecessor_source_component_receipts,
			discrete_staging_observer_receipt,
			discrete_staging_accumulator_before,
		)
		if rotation_aware
		else DiscreteStagingRouteScript.map_step_v1(
			sdk,
			predecessor_energy_source_receipt,
			predecessor_source_component_receipts,
			discrete_staging_observer_receipt,
			discrete_staging_accumulator_before,
		)
	)
	if not bool(mapped.get("ok", false)):
		return mapped
	var bound := _compose_observations_for_energy_profile_v1(
		sdk,
		context,
		observation_base,
		mapped["energy_source_receipt"],
		mapped["source_component_receipts"],
		R148_COMPLETE_ENERGY_ROUTE_ID,
		R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_mapping_receipt_v1",
		"sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_bound_observations_v1",
		"QSDK_R24D148",
		true,
		true,
		true,
	)
	if not bool(bound.get("ok", false)):
		return bound
	bound["native_to_portable_staging_mapping"] = mapped
	bound["discrete_staging_accumulator_after"] = mapped["accumulator_after"]
	bound["discrete_staging_accumulator_after_sha256"] = (mapped["accumulator_after_sha256"])
	if rotation_aware:
		bound["recovery_energy_ledger_profile_id"] = (
			R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		)
		bound["rotation_integration_exchange_included_exactly_once"] = true
	return bound


## R133 consumer-side check for the additive core V4 projection receipt. It
## recomputes both full representation hashes and the source-binding hash, so
## retained route evidence cannot silently detach the V3 step from its V2
## stance-control projection after the core call returns.
static func stance_observation_binding_receipt_valid_v1(
	sdk: Object,
	wrapped: Dictionary,
	collection_request: Dictionary,
	step: Dictionary,
	portable_step_observation_v3: Dictionary,
	energy_partition_authority: Dictionary,
	development_progression: Dictionary,
) -> bool:
	var control_value: Variant = wrapped.get("control_receipt")
	var binding_value: Variant = wrapped.get("observation_binding")
	var observation_v2_value: Variant = collection_request.get("observation")
	var source_binding_value: Variant = collection_request.get("observation_source_binding")
	if (
		String(wrapped.get("schema_version", "")) != "sporespore_recovery_stance_control_receipt_v2"
		or not (control_value is Dictionary)
		or not (binding_value is Dictionary)
		or not (observation_v2_value is Dictionary)
		or not (source_binding_value is Dictionary)
	):
		return false
	var control: Dictionary = control_value
	var binding: Dictionary = binding_value
	var observation_v2: Dictionary = observation_v2_value
	var source_binding: Dictionary = source_binding_value
	var observation_v2_sha256 := _sha256(sdk, observation_v2)
	var observation_v3_sha256 := _sha256(sdk, portable_step_observation_v3)
	var source_binding_sha256 := _sha256(sdk, source_binding)
	var energy_partition_authority_sha256 := _sha256(sdk, energy_partition_authority)
	var development_progression_sha256 := _sha256(sdk, development_progression)
	return (
		(
			String(binding.get("schema_version", ""))
			== "sporespore_recovery_stance_observation_binding_receipt_v1"
		)
		and not observation_v2_sha256.is_empty()
		and not observation_v3_sha256.is_empty()
		and not source_binding_sha256.is_empty()
		and not energy_partition_authority_sha256.is_empty()
		and not development_progression_sha256.is_empty()
		and String(binding.get("collection_observation_v2_sha256", "")) == observation_v2_sha256
		and String(binding.get("portable_step_observation_v3_sha256", "")) == observation_v3_sha256
		and String(step.get("observation_sha256", "")) == observation_v3_sha256
		and String(control.get("observation_sha256", "")) == observation_v3_sha256
		and (
			String(binding.get("shared_observation_base_sha256", ""))
			== String(source_binding.get("observation_base_sha256", ""))
		)
		and String(binding.get("observation_source_binding_sha256", "")) == source_binding_sha256
		and (
			String(binding.get("energy_partition_authority_sha256", ""))
			== energy_partition_authority_sha256
		)
		and (
			String(binding.get("development_progression_receipt_sha256", ""))
			== development_progression_sha256
		)
		and (
			String(development_progression.get("energy_partition_authority_sha256", ""))
			== energy_partition_authority_sha256
		)
		and int(binding.get("semantic_step", -1)) == int(observation_v2.get("semantic_step", -2))
		and (
			int(binding.get("semantic_step", -1))
			== int(portable_step_observation_v3.get("semantic_step", -2))
		)
		and bool(binding.get("source_bound_v2_collection_validated", false))
		and bool(binding.get("portable_step_v3_validated", false))
		and bool(binding.get("cross_representation_base_binding_validated", false))
		and bool(binding.get("development_progression_validated", false))
		and (
			bool(binding.get("development_handoff_authorized", false))
			== bool(development_progression.get("development_progression_used", true))
		)
		and int(binding.get("model_construction_count", -1)) == 0
		and int(binding.get("world_attempt_count", -1)) == 0
		and int(binding.get("world_build_count", -1)) == 0
		and int(binding.get("solver_step_count", -1)) == 0
		and not bool(binding.get("physics_state_modified", true))
		and not bool(binding.get("physical_acceptance_authority", true))
		and not bool(binding.get("release_authority", true))
		and int(wrapped.get("model_construction_count", -1)) == 0
		and int(wrapped.get("world_attempt_count", -1)) == 0
		and int(wrapped.get("world_build_count", -1)) == 0
		and int(wrapped.get("solver_step_count", -1)) == 0
		and not bool(wrapped.get("physics_state_modified", true))
		and not bool(wrapped.get("prone_to_standing_claimed", true))
		and not bool(wrapped.get("physical_acceptance_authority", true))
		and not bool(wrapped.get("release_authority", true))
	)


## R126 binds the immutable R86 diagnosis to the exact R57 observation source.
## The receipt is deliberately incomplete: it can authorize only the additive
## development handoff and can never authorize balance, completion, or release.
static func incomplete_energy_partition_authority_v1(
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	var observation_value: Variant = bound.get("observation_v3")
	if not (observation_value is Dictionary):
		return {}
	return incomplete_energy_partition_authority_for_observation_v1(
		context,
		observation_value,
	)


## Bind the same qualified R126 authority directly to a retained V3 sample.
## This is shared by online stepping and offline paired evaluation so the two
## routes cannot silently disagree about incomplete-energy progression.
static func incomplete_energy_partition_authority_for_observation_v1(
	context: Dictionary,
	observation: Dictionary,
) -> Dictionary:
	var energy_value: Variant = observation.get("energy_balance")
	var engine_value: Variant = observation.get("engine_step_identity")
	if not (energy_value is Dictionary) or not (engine_value is Dictionary):
		return {}
	var energy: Dictionary = energy_value
	var engine: Dictionary = engine_value
	var capability_sha256 := String(context.get("capability_sha256", ""))
	if (
		capability_sha256.is_empty()
		or String(engine.get("adapter_id", "")) != ADAPTER_ID
		or String(engine.get("engine", "")) != ENGINE_ID
		or String(engine.get("capability_sha256", "")) != capability_sha256
		or String(energy.get("source_profile_id", "")) != ENERGY_MAPPING_PROFILE_ID
		or String(energy.get("component_partition_id", "")) != ENERGY_COMPONENT_PARTITION_V3_ID
	):
		return {}
	return {
		"schema_version": "sporespore_recovery_energy_partition_authority_v1",
		"authority_profile_id": R126_ENERGY_AUTHORITY_PROFILE_ID,
		"authority_source_sha256": R126_ENERGY_AUTHORITY_SOURCE_SHA256,
		"adapter_id": ADAPTER_ID,
		"engine": ENGINE_ID,
		"capability_sha256": capability_sha256,
		"energy_source_profile_id": ENERGY_MAPPING_PROFILE_ID,
		"component_partition_id": ENERGY_COMPONENT_PARTITION_V3_ID,
		"constraint_exchange_partition_complete": false,
		"passive_dissipation_partition_complete": false,
		"component_partition_complete": false,
		"exact_balance_safety_authority": false,
		"unclosed_energy_residual_preserved": true,
		"residual_balancing_permitted": false,
		"development_progression_permitted": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R136 binds exact balance authority only to the distinct v4 capability and
## complete source mapping. This permits the existing supervisor to consume a
## measured balance residual; it never creates physical acceptance or release
## authority and cannot be projected onto the historical R57 ledger.
static func complete_energy_partition_authority_v1(
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	var observation_value: Variant = bound.get("observation_v3")
	if not (observation_value is Dictionary):
		return {}
	return complete_energy_partition_authority_for_observation_v1(
		context,
		observation_value,
	)


static func complete_energy_partition_authority_for_observation_v1(
	context: Dictionary,
	observation: Dictionary,
) -> Dictionary:
	var energy_value: Variant = observation.get("energy_balance")
	var engine_value: Variant = observation.get("engine_step_identity")
	if not (energy_value is Dictionary) or not (engine_value is Dictionary):
		return {}
	var energy: Dictionary = energy_value
	var engine: Dictionary = engine_value
	var capability_sha256 := String(context.get("capability_sha256", ""))
	if (
		not bool(context.get("complete_energy_profile_selected", false))
		or capability_sha256.is_empty()
		or String(engine.get("adapter_id", "")) != ADAPTER_ID
		or String(engine.get("engine", "")) != ENGINE_ID
		or String(engine.get("capability_sha256", "")) != capability_sha256
		or String(energy.get("source_profile_id", "")) != R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		or String(energy.get("component_partition_id", "")) != ENERGY_COMPONENT_PARTITION_V3_ID
	):
		return {}
	return {
		"schema_version": "sporespore_recovery_energy_partition_authority_v1",
		"authority_profile_id": R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"authority_source_sha256": R136_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256,
		"adapter_id": ADAPTER_ID,
		"engine": ENGINE_ID,
		"capability_sha256": capability_sha256,
		"energy_source_profile_id": R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"component_partition_id": ENERGY_COMPONENT_PARTITION_V3_ID,
		"constraint_exchange_partition_complete": true,
		"passive_dissipation_partition_complete": true,
		"component_partition_complete": true,
		"exact_balance_safety_authority": true,
		"unclosed_energy_residual_preserved": false,
		"residual_balancing_permitted": false,
		"development_progression_permitted": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func solver_coupled_complete_energy_partition_authority_v1(
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	var observation_value: Variant = bound.get("observation_v3")
	if not (observation_value is Dictionary):
		return {}
	return solver_coupled_complete_energy_partition_authority_for_observation_v1(
		context,
		observation_value,
	)


static func solver_coupled_complete_energy_partition_authority_for_observation_v1(
	context: Dictionary,
	observation: Dictionary,
) -> Dictionary:
	var energy_value: Variant = observation.get("energy_balance")
	var engine_value: Variant = observation.get("engine_step_identity")
	if not (energy_value is Dictionary) or not (engine_value is Dictionary):
		return {}
	var energy: Dictionary = energy_value
	var engine: Dictionary = engine_value
	var capability_sha256 := String(context.get("capability_sha256", ""))
	if (
		not bool(context.get("complete_energy_profile_selected", false))
		or not bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		or String(context.get("energy_route_id", "")) != R144_COMPLETE_ENERGY_ROUTE_ID
		or String(context.get("partition_rule_id", "")) != R144_PARTITION_RULE_ID
		or not _solver_coupled_complete_energy_capability_binding_exact_v1(context)
		or capability_sha256.is_empty()
		or String(engine.get("adapter_id", "")) != ADAPTER_ID
		or String(engine.get("engine", "")) != ENGINE_ID
		or String(engine.get("capability_sha256", "")) != capability_sha256
		or String(energy.get("source_profile_id", "")) != R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		or String(energy.get("component_partition_id", "")) != ENERGY_COMPONENT_PARTITION_V3_ID
	):
		return {}
	return {
		"schema_version": "sporespore_recovery_energy_partition_authority_v1",
		"authority_profile_id": R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"authority_source_sha256": R144_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256,
		"adapter_id": ADAPTER_ID,
		"engine": ENGINE_ID,
		"capability_sha256": capability_sha256,
		"energy_source_profile_id": R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"component_partition_id": ENERGY_COMPONENT_PARTITION_V3_ID,
		"constraint_exchange_partition_complete": true,
		"passive_dissipation_partition_complete": true,
		"component_partition_complete": true,
		"exact_balance_safety_authority": true,
		"unclosed_energy_residual_preserved": false,
		"residual_balancing_permitted": false,
		"development_progression_permitted": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R148 authority is intentionally prospective and zero-world-only. It proves
## the exact observer/mapping/profile identity but cannot authorize progression
## until R149 has commissioned the live native boundary transport.
static func discrete_staging_complete_energy_partition_authority_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	var observation_value: Variant = bound.get("observation_v3")
	var mapping_value: Variant = bound.get("native_to_portable_staging_mapping")
	if not (observation_value is Dictionary) or not (mapping_value is Dictionary):
		return {}
	var observation: Dictionary = observation_value
	var energy_value: Variant = observation.get("energy_balance")
	var engine_value: Variant = observation.get("engine_step_identity")
	var mapping: Dictionary = mapping_value
	var source_value: Variant = mapping.get("energy_source_receipt")
	var components_value: Variant = mapping.get("source_component_receipts")
	if (
		not (energy_value is Dictionary)
		or not (engine_value is Dictionary)
		or not (source_value is Dictionary)
		or not (components_value is Dictionary)
	):
		return {}
	var energy: Dictionary = energy_value
	var engine: Dictionary = engine_value
	var source: Dictionary = source_value
	var components: Dictionary = components_value
	var capability_sha256 := String(context.get("capability_sha256", ""))
	if (
		not _discrete_staging_complete_energy_capability_binding_exact_v1(context)
		or capability_sha256.is_empty()
		or String(engine.get("adapter_id", "")) != ADAPTER_ID
		or String(engine.get("engine", "")) != ENGINE_ID
		or String(engine.get("capability_sha256", "")) != capability_sha256
		or String(energy.get("source_profile_id", "")) != R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		or String(energy.get("component_partition_id", "")) != ENERGY_COMPONENT_PARTITION_V3_ID
		or not DiscreteStagingRouteScript.source_receipt_complete_v1(source)
		or not DiscreteStagingRouteScript.source_components_complete_v1(sdk, source, components)
	):
		return {}
	return {
		"schema_version": "sporespore_recovery_energy_partition_authority_v1",
		"authority_profile_id": R148_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"authority_source_sha256": R148_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256,
		"adapter_id": ADAPTER_ID,
		"engine": ENGINE_ID,
		"capability_sha256": capability_sha256,
		"energy_source_profile_id": R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"component_partition_id": ENERGY_COMPONENT_PARTITION_V3_ID,
		"discrete_staging_rule_id": R148_STAGING_RULE_ID,
		"observer_design_qualified": false,
		"native_to_portable_mapping_qualified": false,
		"live_native_transport_commissioned": false,
		"component_partition_physically_commissioned": false,
		"exact_balance_safety_authority": false,
		"development_progression_permitted": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R151 is the first behavior consumer of the R148 ledger. R153 reuses that
## exact authority only after adding the R152-qualified application provenance
## ancestry. The R148 authority above remains prospective and immutable.
static func commissioned_discrete_staging_complete_energy_partition_authority_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	if not _commissioned_discrete_staging_behavior_context_binding_exact_v2(sdk, context):
		return {}
	var observation_value: Variant = bound.get("observation_v3")
	if not (observation_value is Dictionary):
		return {}
	# R164 reaches this authority through the independently commissioned R163
	# rotation-aware route. Its exact context binding replaces the obsolete
	# legacy-runtime reconstruction below while the observation-level authority
	# checks remain identical.
	if (
		rotation_aware_finite_behavior_context_binding_exact_v1(sdk, context)
		or rotation_aware_source_trace_behavior_context_binding_exact_v1(sdk, context)
		or contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk, context)
		or rearward_fold_context_binding_exact_v1(sdk, context)
		or rate_limited_recovery_context_binding_exact_v1(sdk, context)
		or development_candidate_context_binding_exact_v1(sdk, context)
	):
		return commissioned_discrete_staging_complete_energy_partition_authority_for_observation_v1(
			sdk,
			context,
			observation_value,
		)
	# The immutable R148 authority is deliberately closed when physical-world
	# construction is enabled. Reconstruct its exact zero-world predecessor and
	# verify the content-addressed ancestry before reusing that mapping audit;
	# passing the live R151 context directly would correctly fail R148's gate.
	var r148_context := prepare_complete_energy_context_v4(
		sdk,
		_context_recovery_controller_id_v1(context),
	)
	if (
		not bool(r148_context.get("ok", false))
		or (_sha256(sdk, r148_context) != String(context.get("r148_zero_world_context_sha256", "")))
		or (
			discrete_staging_complete_energy_partition_authority_v1(
				sdk,
				r148_context,
				bound,
			)
			. is_empty()
		)
	):
		return {}
	return commissioned_discrete_staging_complete_energy_partition_authority_for_observation_v1(
		sdk,
		context,
		observation_value,
	)


static func commissioned_discrete_staging_complete_energy_partition_authority_for_observation_v1(
	sdk: Object,
	context: Dictionary,
	observation: Dictionary,
) -> Dictionary:
	if not _commissioned_discrete_staging_behavior_context_binding_exact_v2(sdk, context):
		return {}
	var energy_value: Variant = observation.get("energy_balance")
	var engine_value: Variant = observation.get("engine_step_identity")
	if not (energy_value is Dictionary) or not (engine_value is Dictionary):
		return {}
	var energy: Dictionary = energy_value
	var engine: Dictionary = engine_value
	var capability_sha256 := String(context.get("capability_sha256", ""))
	if (
		capability_sha256.is_empty()
		or String(context.get("energy_route_id", "")) != R148_COMPLETE_ENERGY_ROUTE_ID
		or (
			String(context.get("energy_mapping_profile_id", ""))
			!= R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or String(context.get("discrete_staging_rule_id", "")) != R148_STAGING_RULE_ID
		or String(engine.get("adapter_id", "")) != ADAPTER_ID
		or String(engine.get("engine", "")) != ENGINE_ID
		or String(engine.get("capability_sha256", "")) != capability_sha256
		or String(energy.get("source_profile_id", "")) != R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		or String(energy.get("component_partition_id", "")) != ENERGY_COMPONENT_PARTITION_V3_ID
	):
		return {}
	return {
		"schema_version": "sporespore_recovery_energy_partition_authority_v1",
		"authority_profile_id": R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"authority_source_sha256": R151_COMPLETE_ENERGY_AUTHORITY_SOURCE_SHA256,
		"adapter_id": ADAPTER_ID,
		"engine": ENGINE_ID,
		"capability_sha256": capability_sha256,
		"energy_source_profile_id": R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"component_partition_id": ENERGY_COMPONENT_PARTITION_V3_ID,
		"constraint_exchange_partition_complete": true,
		"passive_dissipation_partition_complete": true,
		"component_partition_complete": true,
		"exact_balance_safety_authority": true,
		"unclosed_energy_residual_preserved": false,
		"residual_balancing_permitted": false,
		"development_progression_permitted": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _commissioned_discrete_staging_behavior_context_binding_exact_v2(
	sdk: Object,
	context: Dictionary,
) -> bool:
	return (
		_r151_discrete_staging_behavior_context_binding_exact_v1(sdk, context)
		or _r153_route_aware_behavior_context_binding_exact_v1(sdk, context)
		or _r154_accumulator_aware_behavior_context_binding_exact_v1(sdk, context)
		or rotation_aware_finite_behavior_context_binding_exact_v1(sdk, context)
		or rotation_aware_source_trace_behavior_context_binding_exact_v1(sdk, context)
		or contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk, context)
		or rearward_fold_context_binding_exact_v1(sdk, context)
		or rate_limited_recovery_context_binding_exact_v1(sdk, context)
		or development_candidate_context_binding_exact_v1(sdk, context)
	)


static func initial_state_sha256_v1(sdk: Object, observation_v3: Dictionary) -> String:
	var state_value: Variant = observation_v3.get("state")
	var energy_value: Variant = observation_v3.get("energy_balance")
	if not (state_value is Dictionary) or not (energy_value is Dictionary):
		return ""
	var state: Dictionary = state_value
	var energy: Dictionary = energy_value
	return _sha256(
		sdk,
		{
			"base_pose_world": state.get("base_pose_world"),
			"base_twist_world": state.get("base_twist_world"),
			"ordered_joint_observations": state.get("ordered_joint_observations"),
			"ordered_contact_observations": state.get("ordered_contact_observations"),
			"gravity_world_m_s2": state.get("gravity_world_m_s2"),
			"task_frame": state.get("task_frame"),
			"center_of_mass": observation_v3.get("center_of_mass"),
			"ordered_foot_bearing_observations":
			observation_v3.get("ordered_foot_bearing_observations"),
			"ordered_body_clearance_observations":
			observation_v3.get("ordered_body_clearance_observations"),
			"energy_initial_mechanical_j": energy.get("initial_mechanical_energy_j"),
			"energy_current_mechanical_j": energy.get("current_mechanical_energy_j"),
		}
	)


static func evaluate_behavior_v4(
	sdk: Object,
	context: Dictionary,
	candidate_trace: Dictionary,
	matched_zero_trace: Dictionary,
) -> Dictionary:
	var request := {
		"schema_version": "sporespore_recovery_evaluation_request_v4",
		"task_id": TASK_ID,
		"semantics_id": SEMANTICS_ID,
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"threshold_profile_id": THRESHOLD_PROFILE_ID,
		"descriptor": exact_base_descriptor_v1(),
		"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
		"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
		"candidate_trace": candidate_trace.duplicate(true),
		"matched_zero_command_trace": matched_zero_trace.duplicate(true),
	}
	var evaluation := RecoveryRuntimeScript.evaluate_trace_v4(sdk, request)
	if (
		String(evaluation.get("support_status", "")) != "supported_exact"
		or evaluation.get("refusal_reason", "unexpected") != null
		or int(evaluation.get("model_construction_count", -1)) != 0
		or int(evaluation.get("world_attempt_count", -1)) != 0
		or int(evaluation.get("world_build_count", -1)) != 0
		or int(evaluation.get("solver_step_count", -1)) != 0
		or bool(evaluation.get("physics_state_modified", true))
		or bool(evaluation.get("physical_acceptance_authority", true))
		or bool(evaluation.get("release_authority", true))
	):
		return _failure("QSDK_R24D65_BEHAVIOR_EVALUATION_REFUSED", evaluation)
	return {
		"schema_version": "sporespore_qsdk_r24d65_godot_behavior_evaluation_v1",
		"ok": true,
		"request_sha256": _sha256(sdk, request),
		"evaluation_receipt": evaluation,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Replay the production V5 development semantics used by the V6 controller.
## The incomplete R126 authority remains non-acceptance and non-release data;
## this route only prevents offline replay from dropping a production input.
static func evaluate_behavior_v5(
	sdk: Object,
	context: Dictionary,
	candidate_trace: Dictionary,
	matched_zero_trace: Dictionary,
) -> Dictionary:
	var observations_value: Variant = candidate_trace.get("observations")
	if (
		not (observations_value is Array)
		or (observations_value as Array).is_empty()
		or not ((observations_value as Array)[0] is Dictionary)
	):
		return _failure("QSDK_R24D134_EVALUATION_AUTHORITY_SOURCE_INVALID")
	var complete_energy_profile := bool(context.get("complete_energy_profile_selected", false))
	var solver_coupled_complete_energy_profile := bool(
		context.get("solver_coupled_complete_energy_profile_selected", false)
	)
	var discrete_staging_complete_energy_profile := bool(
		context.get("discrete_staging_complete_energy_profile_selected", false)
	)
	var energy_partition_authority := (
		commissioned_discrete_staging_complete_energy_partition_authority_for_observation_v1(
			sdk, context, (observations_value as Array)[0]
		)
		if discrete_staging_complete_energy_profile
		else (
			solver_coupled_complete_energy_partition_authority_for_observation_v1(
				context, (observations_value as Array)[0]
			)
			if solver_coupled_complete_energy_profile
			else (
				complete_energy_partition_authority_for_observation_v1(
					context, (observations_value as Array)[0]
				)
				if complete_energy_profile
				else incomplete_energy_partition_authority_for_observation_v1(
					context, (observations_value as Array)[0]
				)
			)
		)
	)
	if energy_partition_authority.is_empty():
		return _failure("QSDK_R24D134_EVALUATION_AUTHORITY_BINDING_INVALID")
	var request := {
		"schema_version": "sporespore_recovery_evaluation_request_v5",
		"task_id": TASK_ID,
		"semantics_id": SEMANTICS_ID,
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"threshold_profile_id": THRESHOLD_PROFILE_ID,
		"descriptor": exact_base_descriptor_v1(),
		"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
		"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
		"energy_partition_authority": energy_partition_authority.duplicate(true),
		"candidate_trace": candidate_trace.duplicate(true),
		"matched_zero_command_trace": matched_zero_trace.duplicate(true),
	}
	var evaluation := RecoveryRuntimeScript.evaluate_trace_v5(sdk, request)
	if (
		String(evaluation.get("support_status", "")) != "supported_exact"
		or evaluation.get("refusal_reason", "unexpected") != null
		or int(evaluation.get("model_construction_count", -1)) != 0
		or int(evaluation.get("world_attempt_count", -1)) != 0
		or int(evaluation.get("world_build_count", -1)) != 0
		or int(evaluation.get("solver_step_count", -1)) != 0
		or bool(evaluation.get("physics_state_modified", true))
		or bool(evaluation.get("physical_acceptance_authority", true))
		or bool(evaluation.get("release_authority", true))
	):
		return _failure("QSDK_R24D134_BEHAVIOR_EVALUATION_REFUSED", evaluation)
	return {
		"schema_version":
		(
			"sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_evaluation_v1"
			if discrete_staging_complete_energy_profile
			else (
				"sporespore_qsdk_r24d146_godot_solver_coupled_complete_energy_behavior_evaluation_v1"
				if solver_coupled_complete_energy_profile
				else (
					"sporespore_qsdk_r24d136_godot_complete_energy_behavior_evaluation_v1"
					if complete_energy_profile
					else "sporespore_qsdk_r24d134_godot_behavior_evaluation_v1"
				)
			)
		),
		"ok": true,
		"request_sha256": _sha256(sdk, request),
		"energy_partition_authority_sha256": _sha256(sdk, energy_partition_authority),
		"evaluation_receipt": evaluation,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Validate the portable physical-evaluation receipt as a consumer contract.
## A supported failed or incomplete result is valid finite evidence; the
## positive-only all-negative-control conjunction applies only to a pass.
static func validate_physical_evaluation_receipt_v1(
	evaluation: Dictionary,
) -> Dictionary:
	var verdict := String(evaluation.get("verdict", ""))
	var passed := verdict == "physical_development_passed"
	var failed := verdict == "physical_development_failed"
	var incomplete := verdict == "physical_development_incomplete"
	var allowed_verdict := passed or failed or incomplete
	var candidate_value: Variant = evaluation.get("candidate_trace")
	var zero_value: Variant = evaluation.get("matched_zero_command_trace")
	var candidate: Dictionary = candidate_value if candidate_value is Dictionary else {}
	var zero: Dictionary = zero_value if zero_value is Dictionary else {}
	var candidate_trace_complete := bool(candidate.get("completed", false))
	var zero_trace_complete := bool(zero.get("completed", false))
	var candidate_trace_failed := String(candidate.get("final_phase", "")) == "failed"
	var zero_trace_failed := String(zero.get("final_phase", "")) == "failed"
	var expected_candidate_physical_complete := candidate_trace_complete
	var expected_zero_physical_failed := not zero_trace_complete and zero_trace_failed
	var expected_passed := expected_candidate_physical_complete and expected_zero_physical_failed
	var expected_incomplete := (
		not candidate_trace_complete
		and not candidate_trace_failed
		and not zero_trace_complete
		and not zero_trace_failed
	)
	var expected_verdict := (
		"physical_development_passed"
		if expected_passed
		else (
			"physical_development_incomplete"
			if expected_incomplete
			else "physical_development_failed"
		)
	)
	var common_checks := {
		"schema_exact":
		String(evaluation.get("schema_version", "")) == "sporespore_recovery_evaluation_receipt_v1",
		"support_exact": String(evaluation.get("support_status", "")) == "supported_exact",
		"refusal_absent": evaluation.get("refusal_reason", "unexpected") == null,
		"verdict_allowed": allowed_verdict,
		"initial_state_identity_matched":
		bool(evaluation.get("initial_state_identity_matched", false)),
		"physical_development_trace_valid":
		bool(evaluation.get("physical_development_trace_valid", false)),
		"controller_implemented": bool(evaluation.get("controller_implemented", false)),
		"physical_threshold_authority": bool(evaluation.get("physical_threshold_authority", false)),
		"physical_question_opened": bool(evaluation.get("physical_question_opened", false)),
		"candidate_trace_present": candidate_value is Dictionary,
		"matched_zero_trace_present": zero_value is Dictionary,
		"candidate_trace_not_refused": not bool(candidate.get("refused", true)),
		"matched_zero_trace_not_refused": not bool(zero.get("refused", true)),
		"candidate_trace_observations_accepted":
		(
			int(candidate.get("observation_count", -1)) >= 1
			and (
				int(candidate.get("accepted_observation_count", -2))
				== int(candidate.get("observation_count", -1))
			)
		),
		"matched_zero_trace_observations_accepted":
		(
			int(zero.get("observation_count", -1)) >= 1
			and (
				int(zero.get("accepted_observation_count", -2))
				== int(zero.get("observation_count", -1))
			)
		),
		"evaluator_model_count_zero": int(evaluation.get("model_construction_count", -1)) == 0,
		"evaluator_world_attempt_count_zero": int(evaluation.get("world_attempt_count", -1)) == 0,
		"evaluator_world_build_count_zero": int(evaluation.get("world_build_count", -1)) == 0,
		"evaluator_solver_step_count_zero": int(evaluation.get("solver_step_count", -1)) == 0,
		"evaluator_physics_unmodified": not bool(evaluation.get("physics_state_modified", true)),
		"physical_acceptance_authority_absent":
		not bool(evaluation.get("physical_acceptance_authority", true)),
		"release_authority_absent": not bool(evaluation.get("release_authority", true)),
	}
	var verdict_checks := {
		"verdict_matches_trace_outcome": verdict == expected_verdict,
		"physical_result_matches_passed_verdict":
		bool(evaluation.get("physical_result", false)) == expected_passed,
		"standing_claim_matches_passed_verdict":
		bool(evaluation.get("prone_to_standing_claimed", false)) == expected_passed,
		"all_negative_control_flag_matches_passed_verdict":
		(
			bool(evaluation.get("all_negative_control_requirements_enforced", false))
			== expected_passed
		),
		"candidate_physical_completion_matches_trace":
		(
			bool(evaluation.get("candidate_physical_path_completed", false))
			== expected_candidate_physical_complete
		),
		"matched_zero_physical_failure_matches_trace":
		(
			bool(
				(
					evaluation
					. get(
						"matched_zero_command_physical_control_failed_to_complete",
						false,
					)
				)
			)
			== expected_zero_physical_failed
		),
		"synthetic_candidate_completion_absent":
		not bool(evaluation.get("candidate_synthetic_path_completed", true)),
		"synthetic_zero_failure_absent":
		not bool(
			(
				evaluation
				. get(
					"matched_zero_command_control_failed_to_complete",
					true,
				)
			)
		),
		"synthetic_canary_absent": not bool(evaluation.get("synthetic_canary_passed", true)),
	}
	var common_pass_count := 0
	for value in common_checks.values():
		common_pass_count += int(bool(value))
	var verdict_pass_count := 0
	for value in verdict_checks.values():
		verdict_pass_count += int(bool(value))
	var ok := (
		common_pass_count == common_checks.size() and verdict_pass_count == verdict_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_godot_physical_evaluation_receipt_acceptance_v1",
		"ok": ok,
		"status": "accepted" if ok else "refused",
		"failure_code": "" if ok else "QSDK_GODOT_PHYSICAL_EVALUATION_RECEIPT_REFUSED",
		"verdict": verdict,
		"scientific_outcome":
		(
			"invalid"
			if not ok
			else ("positive" if passed else ("negative" if failed else "incomplete"))
		),
		"common_checks": common_checks,
		"verdict_checks": verdict_checks,
		"common_check_count": common_checks.size(),
		"common_pass_count": common_pass_count,
		"verdict_check_count": verdict_checks.size(),
		"verdict_pass_count": verdict_pass_count,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Retain one compact digest and count projection of every completed arm's
## per-step invariant receipts, including on later invalid terminal paths.
static func compact_behavior_arm_invariant_summary_v1(
	sdk: Object,
	arm_results: Dictionary,
	ordered_arm_kinds: Array,
	total_solver_step_count: int,
) -> Dictionary:
	var ordered_summaries: Array = []
	var summarized_solver_steps := 0
	var all_summaries_valid := true
	for arm_kind_value in ordered_arm_kinds:
		var arm_kind := String(arm_kind_value)
		if not arm_results.has(arm_kind):
			continue
		var result_value: Variant = arm_results[arm_kind]
		if not result_value is Dictionary:
			all_summaries_valid = false
			continue
		var result: Dictionary = result_value
		var invariant_value: Variant = result.get("in_run_invariant_receipts")
		if not invariant_value is Array:
			all_summaries_valid = false
			continue
		var invariants: Array = invariant_value
		var outer_steps := int(result.get("outer_step_count", -1))
		var native_steps := int(result.get("native_solver_step_count", -1))
		var declared_count := int(result.get("in_run_invariant_receipt_count", -1))
		var declared_arm_kind := String(result.get("arm_kind", ""))
		var trace_sha256 := String(result.get("trace_v3_sha256", ""))
		var initial_state_sha256 := String(result.get("declared_initial_state_sha256", ""))
		var arm_identity_valid := declared_arm_kind == arm_kind
		var digest_shapes_valid := (
			trace_sha256.begins_with("sha256:")
			and trace_sha256.length() == 71
			and trace_sha256.trim_prefix("sha256:").is_valid_hex_number(false)
			and initial_state_sha256.begins_with("sha256:")
			and initial_state_sha256.length() == 71
			and initial_state_sha256.trim_prefix("sha256:").is_valid_hex_number(false)
		)
		var all_invariants_passed := true
		for invariant_value_item in invariants:
			if (
				not invariant_value_item is Dictionary
				or not bool(
					(
						(invariant_value_item as Dictionary)
						. get(
							"all_in_run_physical_invariants_passed",
							false,
						)
					)
				)
			):
				all_invariants_passed = false
				break
		var population_sha256 := "" if sdk == null else _sha256(sdk, invariants)
		var summary_valid := (
			outer_steps >= 1
			and native_steps == outer_steps
			and declared_count == outer_steps
			and invariants.size() == outer_steps
			and all_invariants_passed
			and arm_identity_valid
			and digest_shapes_valid
			and not population_sha256.is_empty()
		)
		all_summaries_valid = all_summaries_valid and summary_valid
		summarized_solver_steps += maxi(native_steps, 0)
		(
			ordered_summaries
			. append(
				{
					"arm_kind": arm_kind,
					"arm_result_validation_passed": summary_valid,
					"outer_step_count": outer_steps,
					"native_solver_step_count": native_steps,
					"in_run_invariant_receipt_count": declared_count,
					"in_run_invariant_population_sha256": population_sha256,
					"all_in_run_physical_invariants_passed": all_invariants_passed,
					"arm_identity_valid": arm_identity_valid,
					"digest_shapes_valid": digest_shapes_valid,
					"final_phase": String(result.get("final_phase", "")),
					"terminal_failure_code": result.get("terminal_failure_code"),
					"trace_v3_sha256": trace_sha256,
					"declared_initial_state_sha256": initial_state_sha256,
				}
			)
		)
	var aggregate_sha256 := "" if sdk == null else _sha256(sdk, ordered_summaries)
	var ok := (
		all_summaries_valid
		and ordered_summaries.size() == arm_results.size()
		and summarized_solver_steps == total_solver_step_count
		and not aggregate_sha256.is_empty()
	)
	return {
		"schema_version": "sporespore_qsdk_godot_behavior_arm_invariant_summary_v1",
		"ok": ok,
		"status": "population_consistent" if ok else "population_inconsistent",
		"summary_scope": "completed_arm_in_run_invariant_populations",
		"ordered_arm_kinds": ordered_arm_kinds.duplicate(),
		"completed_arm_count": ordered_summaries.size(),
		"total_solver_step_count": total_solver_step_count,
		"summarized_solver_step_count": summarized_solver_steps,
		"ordered_arm_summaries": ordered_summaries,
		"ordered_arm_summaries_sha256": aggregate_sha256,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func collect_and_plan_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	phase: String,
	phase_step: int,
) -> Dictionary:
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	if recovery_controller_id.is_empty():
		return _failure("QSDK_R24D113_CONTROL_CONTROLLER_CONTEXT_INVALID")
	var collection_request := collection_request_v1(context, bound, "candidate_command", phase)
	var collection := RecoveryRuntimeScript.collect_native_v3(sdk, collection_request)
	if (
		String(collection.get("support_status", "")) != "supported_exact"
		or not bool(collection.get("supplied_native_post_step_observation_validated", false))
	):
		return _failure("QSDK_R24D57_NATIVE_COLLECTION_REFUSED", collection)
	var control := (
		RecoveryRuntimeScript
		. plan_control_v3(
			sdk,
			{
				"schema_version": "sporespore_recovery_control_request_v3",
				"controller_id": recovery_controller_id,
				"phase_step": phase_step,
				"collection": collection_request,
			}
		)
	)
	if String(control.get("support_status", "")) != "supported_exact":
		return _failure("QSDK_R24D57_CONTROL_REFUSED", control)
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_collection_and_control_v1",
		"ok": true,
		"collection_request": collection_request,
		"collection_receipt": collection,
		"control_receipt": control,
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func initialize_and_step_v4(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	return _initialize_and_step_versioned(sdk, context, bound, false)


static func initialize_and_step_v5(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	return _initialize_and_step_versioned(sdk, context, bound, true)


static func _initialize_and_step_versioned(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	use_r126_development_progression: bool,
) -> Dictionary:
	var initialization := (
		RecoveryRuntimeScript
		. initialize_v2(
			sdk,
			{
				"schema_version": "sporespore_recovery_initialize_request_v2",
				"task_id": TASK_ID,
				"semantics_id": SEMANTICS_ID,
				"actuator_profile_id": ACTUATOR_PROFILE_ID,
				"threshold_profile_id": THRESHOLD_PROFILE_ID,
				"descriptor": exact_base_descriptor_v1(),
				"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
				"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
				"arm_kind": "candidate_command",
			}
		)
	)
	if (
		String(initialization.get("support_status", "")) != "supported_exact"
		or not (initialization.get("memory") is Dictionary)
	):
		return _failure("QSDK_R24D57_INITIALIZATION_REFUSED", initialization)
	var step_request := {
		"schema_version": "sporespore_recovery_step_request_v4",
		"descriptor": exact_base_descriptor_v1(),
		"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
		"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
		"memory": (initialization["memory"] as Dictionary).duplicate(true),
		"observation": (bound["observation_v3"] as Dictionary).duplicate(true),
	}
	var development_progression: Variant = null
	var step: Dictionary
	if use_r126_development_progression:
		var authority := incomplete_energy_partition_authority_v1(context, bound)
		if authority.is_empty():
			return _failure("QSDK_R24D126_ENERGY_AUTHORITY_BINDING_INVALID")
		step_request["schema_version"] = "sporespore_recovery_step_request_v5"
		step_request["energy_partition_authority"] = authority.duplicate(true)
		var wrapped_step := RecoveryRuntimeScript.step_v5(sdk, step_request)
		if (
			String(wrapped_step.get("schema_version", "")) != "sporespore_recovery_step_receipt_v2"
			or not (wrapped_step.get("step") is Dictionary)
			or not (wrapped_step.get("development_progression") is Dictionary)
		):
			return _failure("QSDK_R24D126_PORTABLE_STEP_V2_REFUSED", wrapped_step)
		step = wrapped_step["step"]
		development_progression = wrapped_step["development_progression"]
	else:
		step = RecoveryRuntimeScript.step_v4(sdk, step_request)
	if String(step.get("support_status", "")) != "supported_exact":
		return _failure("QSDK_R24D57_STEP_V4_REFUSED", step)
	var result := {
		"schema_version": "sporespore_qsdk_r24d57_godot_step_v4_route_v1",
		"ok": true,
		"initialization_receipt": initialization,
		"step_receipt": step,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if use_r126_development_progression:
		result["schema_version"] = R126_DEVELOPMENT_ROUTE_ID
		result["development_progression_receipt"] = development_progression
	return result


## Apply an already accepted portable control receipt to exact Godot hinges.
## Every object, order, cap, position, speed, and digest check completes before
## the first host write. The canonical-to-host sign is explicit and immutable.
static func apply_control_v1(
	sdk: Object,
	control: Dictionary,
	joint_by_actuator_id: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool,
) -> Dictionary:
	var controller_id := String(control.get("controller_id", ""))
	if (
		String(control.get("schema_version", "")) != "sporespore_recovery_control_receipt_v1"
		or String(control.get("support_status", "")) != "supported_exact"
		or control.get("refusal_reason", "unexpected") != null
		or not _registered_recovery_controller_id_v1(controller_id)
		or not bool(control.get("deterministic", false))
		or String(control.get("owner", "")) != "recovery"
		or bool(control.get("matched_zero_command", true))
		or bool(control.get("no_actuation_requested", true))
		or int(control.get("engine_identity_input_count", -1)) != 0
		or int(control.get("engine_specific_policy_branch_count", -1)) != 0
		or bool(control.get("fallback_controller_active", true))
	):
		return _failure("QSDK_R24D57_CONTROL_RECEIPT_INVALID")
	return _apply_active_control_commands_v1(
		sdk,
		control,
		joint_by_actuator_id,
		position_by_joint_id,
		require_zero_world,
		"recovery",
		controller_id,
		null,
		0,
		"r24d57_godot_recovery_command_step_",
	)


## Project the canonical binary64 command onto the exact binary32 host-real
## surface Godot/Jolt accepts. The projection is explicit and retained rather
## than treating deterministic host quantization as a command-readback fault.
static func godot_host_real_command_projection_v1(
	canonical_target_velocity_rad_s: float,
	maximum_target_speed_rad_s: float,
) -> Dictionary:
	if (
		not is_finite(canonical_target_velocity_rad_s)
		or not is_finite(maximum_target_speed_rad_s)
		or maximum_target_speed_rad_s <= 0.0
		or absf(canonical_target_velocity_rad_s) > maximum_target_speed_rad_s
	):
		return _failure(
			"QSDK_R24D78_HOST_REAL_COMMAND_PROJECTION_INPUT_INVALID",
			{
				"canonical_target_velocity_rad_s": canonical_target_velocity_rad_s,
				"published_maximum_target_speed_rad_s": maximum_target_speed_rad_s,
			},
		)
	var godot_unprojected_target_velocity_rad_s := (
		canonical_target_velocity_rad_s * LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN
	)
	var host_values := PackedFloat32Array([godot_unprojected_target_velocity_rad_s])
	if host_values.size() != 1:
		return _failure("QSDK_R24D78_HOST_REAL_COMMAND_PROJECTION_FAILED")
	var godot_projected_target_velocity_rad_s := float(host_values[0])
	var signed_quantization_error_rad_s := (
		godot_projected_target_velocity_rad_s - godot_unprojected_target_velocity_rad_s
	)
	var absolute_quantization_error_rad_s := absf(signed_quantization_error_rad_s)
	var maximum_quantization_error_bound_rad_s := maxf(
		absf(godot_unprojected_target_velocity_rad_s) * HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND,
		HOST_REAL_BINARY32_MINIMUM_SUBNORMAL,
	)
	if (
		not is_finite(godot_projected_target_velocity_rad_s)
		or absf(godot_projected_target_velocity_rad_s) > maximum_target_speed_rad_s
		or absolute_quantization_error_rad_s > maximum_quantization_error_bound_rad_s
	):
		return _failure(
			"QSDK_R24D78_HOST_REAL_COMMAND_PROJECTION_INVALID",
			{
				"canonical_target_velocity_rad_s": canonical_target_velocity_rad_s,
				"godot_unprojected_target_velocity_rad_s": godot_unprojected_target_velocity_rad_s,
				"godot_projected_target_velocity_rad_s": godot_projected_target_velocity_rad_s,
				"absolute_quantization_error_rad_s": absolute_quantization_error_rad_s,
				"maximum_quantization_error_bound_rad_s": maximum_quantization_error_bound_rad_s,
				"published_maximum_target_speed_rad_s": maximum_target_speed_rad_s,
			},
		)
	return {
		"schema_version": "sporespore_qsdk_r24d78_godot_host_real_command_projection_v1",
		"ok": true,
		"canonical_target_velocity_rad_s": canonical_target_velocity_rad_s,
		"godot_unprojected_target_velocity_rad_s": godot_unprojected_target_velocity_rad_s,
		"godot_projected_target_velocity_rad_s": godot_projected_target_velocity_rad_s,
		"host_velocity_sign": LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN,
		"published_maximum_target_speed_rad_s": maximum_target_speed_rad_s,
		"host_real_format": "ieee_754_binary32",
		"projection_method": "PackedFloat32Array",
		"signed_quantization_error_rad_s": signed_quantization_error_rad_s,
		"absolute_quantization_error_rad_s": absolute_quantization_error_rad_s,
		"maximum_quantization_error_bound_rad_s": maximum_quantization_error_bound_rad_s,
		"projected_command_within_published_speed": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Validate a host readback against a self-consistent projection receipt. A
## command that was already projected to binary32 must round-trip exactly.
static func validate_godot_host_real_command_readback_v1(
	projection: Dictionary,
	host_readback_target_velocity_rad_s: float,
) -> Dictionary:
	if (
		(
			String(projection.get("schema_version", ""))
			!= "sporespore_qsdk_r24d78_godot_host_real_command_projection_v1"
		)
		or not bool(projection.get("ok", false))
		or String(projection.get("host_real_format", "")) != "ieee_754_binary32"
		or String(projection.get("projection_method", "")) != "PackedFloat32Array"
	):
		return _failure("QSDK_R24D78_HOST_REAL_COMMAND_PROJECTION_RECEIPT_INVALID")
	var canonical_target_velocity_rad_s := float(
		projection.get("canonical_target_velocity_rad_s", NAN)
	)
	var maximum_target_speed_rad_s := float(
		projection.get("published_maximum_target_speed_rad_s", NAN)
	)
	var expected := godot_host_real_command_projection_v1(
		canonical_target_velocity_rad_s,
		maximum_target_speed_rad_s,
	)
	if not bool(expected.get("ok", false)):
		return _failure(
			"QSDK_R24D78_HOST_REAL_COMMAND_PROJECTION_RECOMPUTE_INVALID",
			expected,
		)
	var projected := float(projection.get("godot_projected_target_velocity_rad_s", NAN))
	if (
		not is_finite(host_readback_target_velocity_rad_s)
		or projected != float(expected["godot_projected_target_velocity_rad_s"])
		or (
			float(projection.get("godot_unprojected_target_velocity_rad_s", NAN))
			!= float(expected["godot_unprojected_target_velocity_rad_s"])
		)
		or (
			float(projection.get("absolute_quantization_error_rad_s", NAN))
			!= float(expected["absolute_quantization_error_rad_s"])
		)
		or host_readback_target_velocity_rad_s != projected
	):
		return _failure(
			"QSDK_R24D78_HOST_REAL_COMMAND_READBACK_INVALID",
			{
				"projection": projection,
				"expected_projection": expected,
				"host_readback_target_velocity_rad_s": host_readback_target_velocity_rad_s,
				"host_readback_error_rad_s": host_readback_target_velocity_rad_s - projected,
			},
		)
	return {
		"schema_version": "sporespore_qsdk_r24d78_godot_host_real_command_readback_v1",
		"ok": true,
		"projection": projection.duplicate(true),
		"host_readback_target_velocity_rad_s": host_readback_target_velocity_rad_s,
		"host_readback_error_rad_s": 0.0,
		"exact_projected_readback": true,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## General behavior application over the same validated eight-hinge transport.
## It adds only the two control shapes the route ghost never needed: true
## no-actuation receipts and the already-public exclusive stance owner.
static func apply_behavior_control_v1(
	sdk: Object,
	control: Dictionary,
	joint_by_actuator_id: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool,
) -> Dictionary:
	if (
		String(control.get("schema_version", "")) != "sporespore_recovery_control_receipt_v1"
		or String(control.get("support_status", "")) != "supported_exact"
		or control.get("refusal_reason", "unexpected") != null
		or not bool(control.get("controller_implemented", false))
		or not bool(control.get("deterministic", false))
		or int(control.get("engine_identity_input_count", -1)) != 0
		or int(control.get("engine_specific_policy_branch_count", -1)) != 0
		or bool(control.get("fallback_controller_active", true))
		or int(control.get("model_construction_count", -1)) != 0
		or int(control.get("world_attempt_count", -1)) != 0
		or int(control.get("world_build_count", -1)) != 0
		or int(control.get("solver_step_count", -1)) != 0
		or bool(control.get("physics_state_modified", true))
		or bool(control.get("prone_to_standing_claimed", true))
		or bool(control.get("physical_acceptance_authority", true))
		or bool(control.get("release_authority", true))
	):
		return _failure("QSDK_R24D65_BEHAVIOR_CONTROL_RECEIPT_INVALID")
	var owner := String(control.get("owner", ""))
	var controller_id := String(control.get("controller_id", ""))
	var matched_zero := bool(control.get("matched_zero_command", false))
	var no_actuation := bool(control.get("no_actuation_requested", false))
	if no_actuation:
		var commands_value: Variant = control.get("ordered_commands")
		var command_digest_value: Variant = control.get("command_sha256", "unexpected")
		var zero_identity_valid := (
			matched_zero
			and owner == "none"
			and _registered_recovery_controller_id_v1(controller_id)
			and not bool(control.get("recovery_controller_active", true))
			and not bool(control.get("stance_handoff_requested", true))
		)
		var candidate_identity_valid := (
			not matched_zero
			and owner == "recovery"
			and _registered_recovery_controller_id_v1(controller_id)
			and bool(control.get("recovery_controller_active", false))
			and not bool(control.get("stance_handoff_requested", true))
			and String(control.get("phase", "")) == "confirm_prone"
		)
		if (
			not (commands_value is Array)
			or not (commands_value as Array).is_empty()
			or command_digest_value != null
			or not (zero_identity_valid or candidate_identity_valid)
		):
			return _failure("QSDK_R24D65_NO_ACTUATION_CONTROL_IDENTITY_INVALID")
		return _apply_no_actuation_control_v1(
			sdk,
			control,
			joint_by_actuator_id,
			position_by_joint_id,
			require_zero_world,
		)
	if matched_zero:
		return _failure("QSDK_R24D65_MATCHED_ZERO_ACTIVE_CONTROL_INVALID")
	if (
		owner == "recovery"
		and _registered_recovery_controller_id_v1(controller_id)
		and bool(control.get("recovery_controller_active", false))
		and not bool(control.get("stance_handoff_requested", true))
	):
		return _apply_active_control_commands_v1(
			sdk,
			control,
			joint_by_actuator_id,
			position_by_joint_id,
			require_zero_world,
			"recovery",
			controller_id,
			null,
			0,
			"r24d65_godot_recovery_command_step_",
		)
	if (
		owner == "stance"
		and DevelopmentStanceProfile.registered_v1(controller_id)
		and not bool(control.get("recovery_controller_active", true))
	):
		return _apply_active_control_commands_v1(
			sdk,
			control,
			joint_by_actuator_id,
			position_by_joint_id,
			require_zero_world,
			"stance",
			null,
			controller_id,
			1,
			"r24d65_godot_stance_command_step_",
		)
	return _failure("QSDK_R24D65_ACTIVE_CONTROL_OWNER_INVALID")


## R127 binds V6 to the existing native HingeJoint3D constraint-motor route.
## The underlying validated writes remain R57/R65 mechanics; this additive
## receipt makes the solver-coupled realization and incomplete R57 energy
## source explicit. Existing callers still require V6; the new candidate caller
## must explicitly select V7, and crossed identities are refused before writes.
static func apply_behavior_control_solver_coupled_native_constraint_motor_v10(
	sdk: Object,
	control: Dictionary,
	joint_by_actuator_id: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool,
	expected_recovery_controller_id: String = RECOVERY_CONTROLLER_V6_ID,
) -> Dictionary:
	var owner := String(control.get("owner", ""))
	var controller_id := String(control.get("controller_id", ""))
	if ((expected_recovery_controller_id not in [RECOVERY_CONTROLLER_V6_ID, RECOVERY_CONTROLLER_V7_ID, RECOVERY_CONTROLLER_V8_ID]
		and not CanonicalOwnershipL15.candidate_id_valid_v1(expected_recovery_controller_id))
		or owner != "stance" and controller_id != expected_recovery_controller_id
		or owner == "stance" and controller_id != DevelopmentStanceProfile.for_recovery_v1(expected_recovery_controller_id)):
		return _failure("QSDK_R24D127_CONTROLLER_REALIZATION_IDENTITY_INVALID")
	var receipt := apply_behavior_control_v1(
		sdk,
		control,
		joint_by_actuator_id,
		position_by_joint_id,
		require_zero_world,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	var no_actuation := bool(control.get("no_actuation_requested", false))
	var expected_motor_count := 0 if no_actuation else 8
	if (
		int(receipt.get("motor_enabled_count", -1)) != expected_motor_count
		or int(receipt.get("body_impulse_write_count", 0)) != 0
	):
		return _failure("QSDK_R24D127_SOLVER_COUPLED_RECEIPT_INVALID", receipt)
	receipt["actuation_realization_id"] = R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
	receipt["portable_recovery_controller_id"] = expected_recovery_controller_id
	receipt["native_contact_solver_coupled"] = true
	receipt["solver_coupled_motor_target_write_count"] = expected_motor_count
	receipt["pre_solver_direct_body_impulse_write_count"] = 0
	receipt["energy_source_profile_id"] = ENERGY_MAPPING_PROFILE_ID
	receipt["controller_realization_identity_checked"] = true
	return receipt


## R129 preserves the qualified R127 realization and the complete R128 command
## application. It versions only the producer/consumer mutation semantics that
## invalidated R128: enabling and targeting an active HingeJoint3D motor is a
## physics-object configuration mutation even before the solver advances. The
## receipt separately keeps direct rigid-body mutation and solver advancement
## false, while a matched-zero disable/reset remains non-actuating.
static func apply_behavior_control_solver_coupled_native_constraint_motor_v11(
	sdk: Object,
	control: Dictionary,
	joint_by_actuator_id: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool,
	expected_recovery_controller_id: String = RECOVERY_CONTROLLER_V6_ID,
) -> Dictionary:
	var receipt := apply_behavior_control_solver_coupled_native_constraint_motor_v10(
		sdk,
		control,
		joint_by_actuator_id,
		position_by_joint_id,
		require_zero_world,
		expected_recovery_controller_id,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	var no_actuation := bool(control.get("no_actuation_requested", false))
	var active_constraint_motor_configuration_modified := not no_actuation
	if (
		bool(receipt.get("physics_state_modified", true))
		or (
			bool(receipt.get("zero_world_host_surface", not require_zero_world))
			!= require_zero_world
		)
		or int(receipt.get("host_write_count", -1)) != 8
		or int(receipt.get("host_readback_count", -1)) != 8
		or int(receipt.get("solver_step_count", -1)) != 0
	):
		return _failure("QSDK_R24D129_PREDECESSOR_APPLICATION_RECEIPT_INVALID", receipt)
	receipt["application_mutation_semantics_id"] = (R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID)
	receipt["host_constraint_configuration_write_count"] = 8
	receipt["active_constraint_motor_configuration_modified"] = (active_constraint_motor_configuration_modified)
	receipt["pre_solver_rigid_body_state_modified"] = false
	receipt["solver_state_advanced"] = false
	receipt["physics_state_mutation_scope"] = (
		"constraint_motor_configuration_pre_solver"
		if active_constraint_motor_configuration_modified
		else "none"
	)
	receipt["physics_state_modified"] = active_constraint_motor_configuration_modified
	receipt["application_mutation_semantics_checked"] = true
	return receipt


## R87 successor application for the genuine recovery behavior worker. The
## portable receipt, target construction, command ordering, controller owners,
## and S169 caps are unchanged. Only the recovery route's native realization
## changes: all hard constraint motors must already be disabled, and each
## accepted joint command becomes a source-measured equal-and-opposite body
## impulse pair. Every source and projection check completes before the first
## body mutation.
static func apply_behavior_control_force_based_v2(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
	native_angular_velocity_guard_required: bool = false,
	native_angular_velocity_nested_projection_required: bool = false,
	component_norm_numeric_predicate_required: bool = false,
	refinement_safe_guard_required: bool = false,
	order_neutral_population_projection_required: bool = false,
	joint_target_monotone_population_projection_required: bool = false,
	joint_space_effective_inertia_population_projection_required: bool = false,
) -> Dictionary:
	if (
		native_angular_velocity_nested_projection_required
		and not native_angular_velocity_guard_required
	):
		return _failure("QSDK_R24D96_NESTED_PROJECTION_REQUIRES_OUTER_GUARD")
	if (
		component_norm_numeric_predicate_required
		and (
			not native_angular_velocity_guard_required
			or not native_angular_velocity_nested_projection_required
		)
	):
		return _failure("QSDK_R24D99_COMPONENT_NORM_REQUIRES_NESTED_GUARD")
	if refinement_safe_guard_required and not component_norm_numeric_predicate_required:
		return _failure("QSDK_R24D100_REFINEMENT_SAFE_REQUIRES_COMPONENT_NORM")
	if order_neutral_population_projection_required and not refinement_safe_guard_required:
		return _failure("QSDK_R24D103_POPULATION_REQUIRES_REFINEMENT_SAFE_GUARD")
	if (
		joint_target_monotone_population_projection_required
		and not order_neutral_population_projection_required
	):
		return _failure("QSDK_R24D107_TARGET_MONOTONE_REQUIRES_ORDER_NEUTRAL_POPULATION")
	if (
		joint_space_effective_inertia_population_projection_required
		and not order_neutral_population_projection_required
	):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_REQUIRES_ORDER_NEUTRAL_POPULATION")
	if (
		joint_space_effective_inertia_population_projection_required
		and joint_target_monotone_population_projection_required
	):
		return _failure("QSDK_R24D109_EFFECTIVE_INERTIA_SUCCESSOR_MODE_AMBIGUOUS")
	if (
		String(control.get("schema_version", "")) != "sporespore_recovery_control_receipt_v1"
		or String(control.get("support_status", "")) != "supported_exact"
		or control.get("refusal_reason", "unexpected") != null
		or not bool(control.get("controller_implemented", false))
		or not bool(control.get("deterministic", false))
		or int(control.get("engine_identity_input_count", -1)) != 0
		or int(control.get("engine_specific_policy_branch_count", -1)) != 0
		or bool(control.get("fallback_controller_active", true))
		or int(control.get("model_construction_count", -1)) != 0
		or int(control.get("world_attempt_count", -1)) != 0
		or int(control.get("world_build_count", -1)) != 0
		or int(control.get("solver_step_count", -1)) != 0
		or bool(control.get("physics_state_modified", true))
		or bool(control.get("prone_to_standing_claimed", true))
		or bool(control.get("physical_acceptance_authority", true))
		or bool(control.get("release_authority", true))
		or not bool(model.get("ok", false))
	):
		return _failure("QSDK_R24D87_FORCE_BASED_CONTROL_RECEIPT_INVALID")
	var joint_by_actuator_value: Variant = model.get("joint_by_actuator_id")
	if not (joint_by_actuator_value is Dictionary):
		return _failure("QSDK_R24D87_FORCE_BASED_MODEL_JOINTS_INVALID")
	var joint_by_actuator_id: Dictionary = joint_by_actuator_value
	var owner := String(control.get("owner", ""))
	var controller_id := String(control.get("controller_id", ""))
	var matched_zero := bool(control.get("matched_zero_command", false))
	var no_actuation := bool(control.get("no_actuation_requested", false))
	if no_actuation:
		var commands_value: Variant = control.get("ordered_commands")
		var zero_identity_valid := (
			matched_zero
			and owner == "none"
			and _registered_recovery_controller_id_v1(controller_id)
			and not bool(control.get("recovery_controller_active", true))
			and not bool(control.get("stance_handoff_requested", true))
		)
		var candidate_identity_valid := (
			not matched_zero
			and owner == "recovery"
			and _registered_recovery_controller_id_v1(controller_id)
			and bool(control.get("recovery_controller_active", false))
			and not bool(control.get("stance_handoff_requested", true))
			and String(control.get("phase", "")) == "confirm_prone"
		)
		if (
			not (commands_value is Array)
			or not (commands_value as Array).is_empty()
			or control.get("command_sha256", "unexpected") != null
			or not (zero_identity_valid or candidate_identity_valid)
		):
			return _failure("QSDK_R24D87_FORCE_BASED_NO_ACTUATION_IDENTITY_INVALID")
		return _apply_no_actuation_control_v1(
			sdk,
			control,
			joint_by_actuator_id,
			position_by_joint_id,
			false,
		)
	if matched_zero:
		return _failure("QSDK_R24D87_FORCE_BASED_MATCHED_ZERO_ACTIVE_INVALID")
	if (
		owner == "recovery"
		and _registered_recovery_controller_id_v1(controller_id)
		and bool(control.get("recovery_controller_active", false))
		and not bool(control.get("stance_handoff_requested", true))
	):
		return _apply_force_based_active_control_v1(
			sdk,
			control,
			model,
			position_by_joint_id,
			"recovery",
			controller_id,
			null,
			0,
			"r24d87_godot_force_based_recovery_command_step_",
			native_angular_velocity_guard_required,
			native_angular_velocity_nested_projection_required,
			component_norm_numeric_predicate_required,
			refinement_safe_guard_required,
			order_neutral_population_projection_required,
			joint_target_monotone_population_projection_required,
			joint_space_effective_inertia_population_projection_required,
		)
	if (
		owner == "stance"
		and controller_id == STANCE_CONTROLLER_ID
		and not bool(control.get("recovery_controller_active", true))
	):
		return _apply_force_based_active_control_v1(
			sdk,
			control,
			model,
			position_by_joint_id,
			"stance",
			null,
			STANCE_CONTROLLER_ID,
			1,
			"r24d87_godot_force_based_stance_command_step_",
			native_angular_velocity_guard_required,
			native_angular_velocity_nested_projection_required,
			component_norm_numeric_predicate_required,
			refinement_safe_guard_required,
			order_neutral_population_projection_required,
			joint_target_monotone_population_projection_required,
			joint_space_effective_inertia_population_projection_required,
		)
	return _failure("QSDK_R24D87_FORCE_BASED_ACTIVE_OWNER_INVALID")


## R94 successor seam. The portable policy, S169 command/cap semantics, and R87
## predecessor projection are unchanged; active body writes additionally require
## the source-measured native angular-velocity guard and immediate readback.
static func apply_behavior_control_force_based_guarded_v3(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	return apply_behavior_control_force_based_v2(
		sdk,
		control,
		model,
		position_by_joint_id,
		true,
		false,
	)


## R96 successor seam. The frozen outer guard remains native readback authority;
## the pair solver targets the independently derived inner projection boundary.
static func apply_behavior_control_force_based_nested_guarded_v4(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	return apply_behavior_control_force_based_v2(
		sdk,
		control,
		model,
		position_by_joint_id,
		true,
		true,
	)


## R99 successor seam. Policy semantics, limits, target, commands, and caps are
## unchanged; all guard decisions use one widened-component relation.
static func apply_behavior_control_force_based_component_norm_nested_guarded_v5(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	return apply_behavior_control_force_based_v2(
		sdk,
		control,
		model,
		position_by_joint_id,
		true,
		true,
		true,
	)


## R100 changes only the representational refinement terminal. Portable policy,
## commands, caps, inner target, outer guard, and native readback authority are
## identical to R99.
static func apply_behavior_control_force_based_refinement_safe_component_norm_nested_guarded_v6(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	return apply_behavior_control_force_based_v2(
		sdk,
		control,
		model,
		position_by_joint_id,
		true,
		true,
		true,
		true,
	)


## R103 changes only allocation/application topology. All eight frozen R87
## requests are projected as one canonical nine-body population, then each
## nonzero body receives at most one validated aggregate impulse.
static func apply_behavior_control_force_based_order_neutral_population_guarded_v7(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	return apply_behavior_control_force_based_v2(
		sdk,
		control,
		model,
		position_by_joint_id,
		true,
		true,
		true,
		true,
		true,
	)


## R107 changes only the prewrite common-scale choice. The R87 controller,
## requests, caps, R103 body guard, aggregate application topology, and native
## outer-guard readback authority remain unchanged.
static func apply_behavior_control_force_based_joint_target_monotone_population_guarded_v8(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	return apply_behavior_control_force_based_v2(
		sdk,
		control,
		model,
		position_by_joint_id,
		true,
		true,
		true,
		true,
		true,
		true,
	)


## R109 changes only the joint-space impulse allocation. The portable target,
## published S169 caps, R103 body guard/application topology, and native
## readback authority remain unchanged.
static func apply_behavior_control_force_based_joint_space_effective_inertia_population_guarded_v9(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	return apply_behavior_control_force_based_v2(
		sdk,
		control,
		model,
		position_by_joint_id,
		true,
		true,
		true,
		true,
		true,
		false,
		true,
	)


## Pure contract shared by the production R136 wrapper and zero-world mutation
## controls. It accepts only the exact R109 active receipt or the existing
## actuation-free bootstrap receipt, both with every native motor disabled and
## no solver step or adapter-side staging event yet performed.
static func complete_energy_application_receipt_contract_v1(
	control: Dictionary,
	model: Dictionary,
	receipt: Dictionary,
) -> Dictionary:
	if (
		typeof(model.get("complete_energy_profile_selected")) != TYPE_BOOL
		or not bool(model["complete_energy_profile_selected"])
	):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_MODEL_PROFILE_REQUIRED")
	if (
		typeof(control.get("no_actuation_requested")) != TYPE_BOOL
		or typeof(receipt.get("ok")) != TYPE_BOOL
		or typeof(receipt.get("motor_enabled_count")) != TYPE_INT
		or typeof(receipt.get("solver_step_count")) != TYPE_INT
		or typeof(receipt.get("adapter_side_discrete_staging_event_count")) != TYPE_INT
		or typeof(receipt.get("physics_state_modified")) != TYPE_BOOL
		or typeof(receipt.get("physical_acceptance_authority")) != TYPE_BOOL
		or typeof(receipt.get("release_authority")) != TYPE_BOOL
	):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_APPLICATION_SHAPE_INVALID")
	if not bool(receipt.get("ok", false)):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_APPLICATION_REFUSED", receipt)
	var no_actuation_requested := bool(control.get("no_actuation_requested", false))
	if (
		int(receipt.get("motor_enabled_count", -1)) != 0
		or int(receipt.get("solver_step_count", -1)) != 0
		or int(receipt.get("adapter_side_discrete_staging_event_count", -1)) != 0
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_PREDECESSOR_RECEIPT_INVALID", receipt)
	if no_actuation_requested:
		if (
			(
				String(receipt.get("schema_version", ""))
				!= "sporespore_qsdk_r24d65_godot_command_application_receipt_v1"
			)
			or bool(receipt.get("physics_state_modified", true))
			or int(receipt.get("validated_command_count", -1)) != 0
		):
			return _failure("QSDK_R24D136_NO_ACTUATION_PARTITION_INVALID", receipt)
	else:
		if (
			(
				String(receipt.get("schema_version", ""))
				!= "sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_application_receipt_v1"
			)
			or (
				String(receipt.get("actuator_mapping_id", ""))
				!= R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
			)
			or String(receipt.get("work_mapping_id", "")) != R136_REQUIRED_ACTIVE_WORK_MAPPING_ID
			or int(receipt.get("hard_constraint_motor_disabled_count", -1)) != 8
			or not bool(
				(
					receipt
					. get(
						"joint_space_effective_inertia_population_projection_required",
						false,
					)
				)
			)
		):
			return _failure("QSDK_R24D136_ACTIVE_ACTUATOR_PARTITION_INVALID", receipt)
	return {
		"schema_version": "sporespore_qsdk_r24d136_godot_complete_energy_application_contract_v1",
		"ok": true,
		"no_actuation_requested": no_actuation_requested,
		"native_joint_motors_disabled": true,
		"hard_constraint_motor_disabled_count": 8,
		"actuator_mapping_id": String(receipt.get("actuator_mapping_id", "")),
		"work_mapping_id": String(receipt.get("work_mapping_id", "")),
		"adapter_side_discrete_staging_event_count": 0,
		"solver_step_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R136 production seam for the complete energy profile. The active path is
## exactly the qualified R109 force/body-impulse realization, so actuator work
## stays disjoint from the newly measured native constraint exchange. The
## bootstrap/no-actuation path keeps an explicit structural zero. Both paths
## prove native joint motors are disabled before a solver step is permitted.
static func apply_behavior_control_complete_energy_v1(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	if not bool(model.get("complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D136_COMPLETE_ENERGY_MODEL_PROFILE_REQUIRED")
	var receipt := apply_behavior_control_force_based_joint_space_effective_inertia_population_guarded_v9(
		sdk,
		control,
		model,
		position_by_joint_id,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	var contract := complete_energy_application_receipt_contract_v1(
		control,
		model,
		receipt,
	)
	if not bool(contract.get("ok", false)):
		return contract
	var no_actuation_requested := bool(contract["no_actuation_requested"])
	var predecessor_schema_version := String(receipt["schema_version"])
	receipt["schema_version"] = ("sporespore_qsdk_r24d136_godot_complete_energy_command_application_receipt_v1")
	receipt["predecessor_schema_version"] = predecessor_schema_version
	receipt["complete_energy_profile_selected"] = true
	receipt["energy_route_id"] = R136_COMPLETE_ENERGY_ROUTE_ID
	receipt["energy_mapping_profile_id"] = R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	receipt["energy_component_partition_id"] = ENERGY_COMPONENT_PARTITION_V3_ID
	receipt["no_actuation_requested"] = no_actuation_requested
	receipt["native_joint_motors_disabled"] = true
	receipt["hard_constraint_motor_disabled_count"] = 8
	receipt["constraint_exchange_source_owned_by_native_solver_telemetry"] = true
	receipt["actuator_work_source_owned_by_r109_application"] = not no_actuation_requested
	if no_actuation_requested:
		receipt["actuator_mapping_id"] = ""
		receipt["work_mapping_id"] = ""
		receipt["structural_zero_actuator_work"] = true
	return receipt


## R137 preserves the R136 wrapper receipt as an explicit embedded identity,
## then exposes the exact predecessor schema expected by the native sampler.
## This is a representation correction only: the already-applied impulses,
## work accounting, guards, readbacks, and complete-energy contract are byte-
## for-byte those produced by the qualified R136/R109 path.
static func apply_behavior_control_complete_energy_v2(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
) -> Dictionary:
	var receipt := apply_behavior_control_complete_energy_v1(
		sdk,
		control,
		model,
		position_by_joint_id,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	return complete_energy_sampler_application_receipt_v1(receipt)


## Pure representation seam used by production after physical application and
## by zero-world mutation controls with shaped receipts. It cannot apply an
## impulse, construct a model, or step a solver.
static func complete_energy_sampler_application_receipt_v1(
	receipt: Dictionary,
) -> Dictionary:
	var wrapper_schema_version := String(receipt.get("schema_version", ""))
	var predecessor_schema_version := String(receipt.get("predecessor_schema_version", ""))
	var no_actuation_requested := bool(receipt.get("no_actuation_requested", false))
	var expected_predecessor_schema := (
		"sporespore_qsdk_r24d65_godot_command_application_receipt_v1"
		if no_actuation_requested
		else "sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_application_receipt_v1"
	)
	if (
		(
			wrapper_schema_version
			!= "sporespore_qsdk_r24d136_godot_complete_energy_command_application_receipt_v1"
		)
		or predecessor_schema_version != expected_predecessor_schema
		or not bool(receipt.get("ok", false))
		or not bool(receipt.get("complete_energy_profile_selected", false))
		or String(receipt.get("energy_route_id", "")) != R136_COMPLETE_ENERGY_ROUTE_ID
		or (
			String(receipt.get("energy_mapping_profile_id", ""))
			!= R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or not bool(receipt.get("native_joint_motors_disabled", false))
		or int(receipt.get("hard_constraint_motor_disabled_count", -1)) != 8
		or int(receipt.get("motor_enabled_count", -1)) != 0
		or int(receipt.get("adapter_side_discrete_staging_event_count", -1)) != 0
		or (
			bool(receipt.get("actuator_work_source_owned_by_r109_application", true))
			!= (not no_actuation_requested)
		)
		or (
			no_actuation_requested
			and (
				not String(receipt.get("actuator_mapping_id", "")).is_empty()
				or not String(receipt.get("work_mapping_id", "")).is_empty()
				or not bool(receipt.get("structural_zero_actuator_work", false))
			)
		)
		or (
			not no_actuation_requested
			and (
				(
					String(receipt.get("actuator_mapping_id", ""))
					!= R136_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
				)
				or (
					String(receipt.get("work_mapping_id", ""))
					!= R136_REQUIRED_ACTIVE_WORK_MAPPING_ID
				)
			)
		)
	):
		return _failure("QSDK_R24D137_COMPLETE_ENERGY_WRAPPER_IDENTITY_INVALID")
	receipt["schema_version"] = predecessor_schema_version
	receipt["complete_energy_wrapper_schema_version"] = wrapper_schema_version
	receipt["complete_energy_sampler_representation"] = true
	receipt["bootstrap_application"] = false
	receipt["actuation_realization_id"] = R137_COMPLETE_ENERGY_ACTUATION_REALIZATION_ID
	receipt["portable_recovery_controller_id"] = RECOVERY_CONTROLLER_V6_ID
	receipt["native_contact_solver_coupled"] = false
	return receipt


## Pure R144 application contract shared by production and zero-world controls.
## It recognizes only the already-qualified R129 constraint-configuration
## semantics, exact V6/R127 realization, eight active motors (or zero for an
## explicit no-actuation step), and no direct rigid-body impulse realization.
static func solver_coupled_complete_energy_application_receipt_contract_v1(
	control: Dictionary,
	model: Dictionary,
	receipt: Dictionary,
) -> Dictionary:
	if (
		not bool(model.get("complete_energy_profile_selected", false))
		or not bool(model.get("solver_coupled_complete_energy_profile_selected", false))
	):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_MODEL_PROFILE_REQUIRED")
	if (
		typeof(control.get("no_actuation_requested")) != TYPE_BOOL
		or typeof(receipt.get("ok")) != TYPE_BOOL
		or typeof(receipt.get("motor_enabled_count")) != TYPE_INT
		or typeof(receipt.get("host_write_count")) != TYPE_INT
		or typeof(receipt.get("host_readback_count")) != TYPE_INT
		or typeof(receipt.get("host_constraint_configuration_write_count")) != TYPE_INT
		or typeof(receipt.get("active_constraint_motor_configuration_modified")) != TYPE_BOOL
		or typeof(receipt.get("pre_solver_rigid_body_state_modified")) != TYPE_BOOL
		or typeof(receipt.get("solver_state_advanced")) != TYPE_BOOL
		or typeof(receipt.get("physics_state_modified")) != TYPE_BOOL
		or typeof(receipt.get("physical_acceptance_authority")) != TYPE_BOOL
		or typeof(receipt.get("release_authority")) != TYPE_BOOL
	):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_APPLICATION_SHAPE_INVALID")
	if not bool(receipt.get("ok", false)):
		return _failure("QSDK_R24D144_COMPLETE_ENERGY_APPLICATION_REFUSED", receipt)
	var no_actuation_requested := bool(control["no_actuation_requested"])
	var expected_motor_count := 0 if no_actuation_requested else 8
	var expected_predecessor_schema := (
		"sporespore_qsdk_r24d65_godot_command_application_receipt_v1"
		if no_actuation_requested
		else "sporespore_qsdk_r24d57_godot_command_application_receipt_v1"
	)
	if (
		String(receipt.get("schema_version", "")) != expected_predecessor_schema
		or int(receipt.get("motor_enabled_count", -1)) != expected_motor_count
		or int(receipt.get("host_write_count", -1)) != 8
		or int(receipt.get("host_readback_count", -1)) != 8
		or int(receipt.get("host_constraint_configuration_write_count", -1)) != 8
		or (
			bool(receipt.get("active_constraint_motor_configuration_modified", true))
			!= (not no_actuation_requested)
		)
		or bool(receipt.get("physics_state_modified", true)) != (not no_actuation_requested)
		or bool(receipt.get("pre_solver_rigid_body_state_modified", true))
		or bool(receipt.get("solver_state_advanced", true))
		or int(receipt.get("solver_step_count", -1)) != 0
		or int(receipt.get("body_impulse_write_count", 0)) != 0
		or int(receipt.get("adapter_side_discrete_staging_event_count", -1)) != 0
		or (
			String(receipt.get("actuation_realization_id", ""))
			!= R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		)
		or (
			String(receipt.get("application_mutation_semantics_id", ""))
			!= R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID
		)
		or not bool(receipt.get("native_contact_solver_coupled", false))
		or int(receipt.get("pre_solver_direct_body_impulse_write_count", -1)) != 0
		or not bool(receipt.get("controller_realization_identity_checked", false))
		or not bool(receipt.get("application_mutation_semantics_checked", false))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return _failure("QSDK_R24D144_SOLVER_COUPLED_APPLICATION_IDENTITY_INVALID", receipt)
	return {
		"schema_version":
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_application_contract_v1",
		"ok": true,
		"no_actuation_requested": no_actuation_requested,
		"native_joint_motor_enabled_count": expected_motor_count,
		"actuator_mapping_id":
		"" if no_actuation_requested else R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": "" if no_actuation_requested else R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": R144_PARTITION_RULE_ID,
		"native_contact_solver_coupled": true,
		"pre_solver_direct_body_impulse_write_count": 0,
		"adapter_side_discrete_staging_event_count": 0,
		"solver_step_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## R144 production application: preserve the exact R129 native motor writes,
## then add only the complete-energy mapping and partition identities consumed
## by the sampler. No command, target, cap, controller, or host write changes.
static func apply_behavior_control_solver_coupled_complete_energy_v1(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool = false,
	expected_recovery_controller_id: String = RECOVERY_CONTROLLER_V6_ID,
) -> Dictionary:
	var receipt := apply_behavior_control_solver_coupled_native_constraint_motor_v11(
		sdk,
		control,
		model.get("joint_by_actuator_id", {}),
		position_by_joint_id,
		require_zero_world,
		expected_recovery_controller_id,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	var contract := solver_coupled_complete_energy_application_receipt_contract_v1(
		control,
		model,
		receipt,
	)
	if not bool(contract.get("ok", false)):
		return contract
	var no_actuation_requested := bool(contract["no_actuation_requested"])
	var predecessor_schema_version := String(receipt["schema_version"])
	receipt["schema_version"] = ("sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1")
	receipt["predecessor_schema_version"] = predecessor_schema_version
	receipt["complete_energy_profile_selected"] = true
	receipt["solver_coupled_complete_energy_profile_selected"] = true
	receipt["energy_route_id"] = R144_COMPLETE_ENERGY_ROUTE_ID
	receipt["energy_mapping_profile_id"] = R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	receipt["partition_rule_id"] = R144_PARTITION_RULE_ID
	receipt["actuator_mapping_id"] = String(contract["actuator_mapping_id"])
	receipt["work_mapping_id"] = String(contract["work_mapping_id"])
	receipt["no_actuation_requested"] = no_actuation_requested
	receipt["native_joint_motors_disabled"] = no_actuation_requested
	receipt["native_joint_motor_enabled_count"] = int(contract["native_joint_motor_enabled_count"])
	receipt["constraint_exchange_source_owned_by_native_solver_telemetry"] = true
	receipt["actuator_work_source_owned_by_native_motor_telemetry"] = true
	receipt["native_motor_work_partitioned_from_whole_joint_exchange"] = true
	receipt["complete_energy_sampler_representation"] = true
	if no_actuation_requested:
		receipt["structural_zero_actuator_work"] = true
	return receipt


## R151 preserves the exact R144 native constraint-motor mutation and work
## partition, then changes only the observation-route representation consumed
## after the subsequent solver step. The separate schema makes cross-route
## relabeling visible without duplicating the physical application mechanics.
static func apply_behavior_control_discrete_staging_complete_energy_v1(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool = false,
	expected_recovery_controller_id: String = RECOVERY_CONTROLLER_V6_ID,
) -> Dictionary:
	if not bool(model.get("discrete_staging_complete_energy_profile_selected", false)):
		return _failure("QSDK_R24D151_DISCRETE_STAGING_MODEL_PROFILE_REQUIRED")
	var receipt := apply_behavior_control_solver_coupled_complete_energy_v1(
		sdk,
		control,
		model,
		position_by_joint_id,
		require_zero_world,
		expected_recovery_controller_id,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	var predecessor_schema_version := String(receipt.get("schema_version", ""))
	receipt["schema_version"] = ("sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_command_application_receipt_v1")
	receipt["predecessor_complete_energy_schema_version"] = predecessor_schema_version
	receipt["predecessor_complete_energy_route_id"] = R144_COMPLETE_ENERGY_ROUTE_ID
	receipt["energy_route_id"] = R148_COMPLETE_ENERGY_ROUTE_ID
	receipt["energy_mapping_profile_id"] = R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	receipt["discrete_staging_complete_energy_profile_selected"] = true
	receipt["complete_energy_authority_profile_id"] = (R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID)
	return receipt


static func apply_behavior_control_route_aware_discrete_staging_v2(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool = false,
	expected_recovery_controller_id: String = RECOVERY_CONTROLLER_V6_ID,
) -> Dictionary:
	var receipt := apply_behavior_control_discrete_staging_complete_energy_v1(
		sdk,
		control,
		model,
		position_by_joint_id,
		require_zero_world,
		expected_recovery_controller_id,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	var predecessor_schema_version := String(receipt.get("schema_version", ""))
	receipt["schema_version"] = (
		"sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_energy_command_application_receipt_v1"
	)
	receipt["predecessor_route_aware_application_schema_version"] = (
		predecessor_schema_version
	)
	receipt["application_provenance_profile_id"] = (
		R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
	)
	return receipt


## Explicit prospective V7 entry. All existing callers default to V6 and
## continue refusing a V7 receipt. Shared mechanics validate the actual V7
## commands and keep their identity through native motor and energy receipts.
static func apply_rearward_fold_control_v1(
	sdk: Object, control: Dictionary, model: Dictionary,
	position_by_joint_id: Dictionary, require_zero_world: bool = false,
) -> Dictionary:
	return apply_behavior_control_route_aware_discrete_staging_v2(
		sdk, control, model, position_by_joint_id, require_zero_world, RECOVERY_CONTROLLER_V7_ID
	)


## Explicit V8 selection; legacy V6/V7 entrypoints retain their own identities.
static func apply_rate_limited_recovery_control_v1(
	sdk: Object, control: Dictionary, model: Dictionary,
	position_by_joint_id: Dictionary, require_zero_world: bool = false,
) -> Dictionary:
	return apply_behavior_control_route_aware_discrete_staging_v2(
		sdk, control, model, position_by_joint_id, require_zero_world, RECOVERY_CONTROLLER_V8_ID
	)


static func _apply_force_based_active_control_v1(
	sdk: Object,
	control: Dictionary,
	model: Dictionary,
	position_by_joint_id: Dictionary,
	controller_owner: String,
	recovery_controller_id: Variant,
	stance_controller_id: Variant,
	handoff_event_count: int,
	command_id_prefix: String,
	native_angular_velocity_guard_required: bool,
	native_angular_velocity_nested_projection_required: bool,
	component_norm_numeric_predicate_required: bool,
	refinement_safe_guard_required: bool,
	order_neutral_population_projection_required: bool,
	joint_target_monotone_population_projection_required: bool,
	joint_space_effective_inertia_population_projection_required: bool,
) -> Dictionary:
	var commands_value: Variant = control.get("ordered_commands")
	if not (commands_value is Array) or (commands_value as Array).size() != 8:
		return _failure("QSDK_R24D87_FORCE_BASED_COMMAND_CARDINALITY_INVALID")
	var commands: Array = commands_value
	var expected_command_sha256 := String(control.get("command_sha256", ""))
	var recomputed_digest_receipt := RecoveryRuntimeScript.canonicalize(sdk, commands)
	if String(recomputed_digest_receipt.get("sha256", "")) != expected_command_sha256:
		return _failure("QSDK_R24D87_FORCE_BASED_COMMAND_DIGEST_INVALID")
	var joint_by_actuator_value: Variant = model.get("joint_by_actuator_id")
	var joint_states_value: Variant = model.get("joint_states")
	if (
		not (joint_by_actuator_value is Dictionary)
		or not (joint_states_value is Dictionary)
		or (joint_by_actuator_value as Dictionary).size() != 8
		or (joint_states_value as Dictionary).size() != 8
		or position_by_joint_id.size() != 8
		or int(model.get("host_step_count", -1)) != int(control.get("semantic_step", -2))
	):
		return _failure("QSDK_R24D87_FORCE_BASED_HOST_SURFACE_INVALID")
	var joint_by_actuator_id: Dictionary = joint_by_actuator_value
	var joint_states: Dictionary = joint_states_value
	var source_semantic_step := int(control.get("semantic_step", -1))
	var unique_joint_instances: Dictionary = {}
	var ordered_projections: Array = []
	var source_snapshot_by_body_id: Dictionary = {}
	for index in range(8):
		var command_value: Variant = commands[index]
		if not (command_value is Dictionary):
			return _failure("QSDK_R24D87_FORCE_BASED_COMMAND_RECORD_INVALID:%d" % index)
		var command: Dictionary = command_value
		var actuator_id := String(command.get("actuator_id", ""))
		var joint_id := String(command.get("joint_id", ""))
		var target := float(command.get("target_position_rad", NAN))
		var maximum_speed := float(command.get("maximum_target_speed_rad_s", NAN))
		var cap := float(command.get("maximum_outer_step_impulse_nms", NAN))
		if (
			String(command.get("schema_version", "")) != "sporespore_recovery_control_command_v1"
			or actuator_id != String(ORDERED_ACTUATOR_IDS[index])
			or joint_id != String(ORDERED_JOINT_IDS[index])
			or String(command.get("mode", "")) != "position_velocity"
			or float(command.get("target_velocity_rad_s", NAN)) != 0.0
			or not is_finite(target)
			or not is_finite(maximum_speed)
			or maximum_speed <= 0.0
			or cap != float(ORDERED_CAPS_NMS[index])
			or not joint_by_actuator_id.has(actuator_id)
			or not joint_states.has(joint_id)
			or not position_by_joint_id.has(joint_id)
		):
			return _failure("QSDK_R24D87_FORCE_BASED_COMMAND_IDENTITY_INVALID:%d" % index)
		var joint_value: Variant = joint_by_actuator_id[actuator_id]
		var state_value: Variant = joint_states[joint_id]
		if not (joint_value is HingeJoint3D) or not (state_value is Dictionary):
			return _failure("QSDK_R24D87_FORCE_BASED_JOINT_STATE_INVALID:%d" % index)
		var joint: HingeJoint3D = joint_value
		var state: Dictionary = state_value
		if (
			state.get("joint") != joint
			or not (state.get("parent") is RigidBody3D)
			or not (state.get("child") is RigidBody3D)
			or state.get("axis_parent_local") != Vector3.BACK
			or joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
			or float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)) != 0.0
		):
			return _failure("QSDK_R24D87_FORCE_BASED_HARD_MOTOR_NOT_DISABLED:%d" % index)
		var instance_id := int(joint.get_instance_id())
		if unique_joint_instances.has(instance_id):
			return _failure("QSDK_R24D87_FORCE_BASED_JOINT_DUPLICATE:%d" % index)
		unique_joint_instances[instance_id] = true
		var parent: RigidBody3D = state["parent"]
		var child: RigidBody3D = state["child"]
		var parent_id := String(parent.get_meta("lab_body_id"))
		var child_id := String(child.get_meta("lab_body_id"))
		var parent_snapshot_value: Variant = parent.get("latest_direct_state_snapshot")
		var child_snapshot_value: Variant = child.get("latest_direct_state_snapshot")
		if not (parent_snapshot_value is Dictionary) or not (child_snapshot_value is Dictionary):
			return _failure("QSDK_R24D87_FORCE_BASED_SOURCE_MISSING:%d" % index)
		var parent_snapshot: Dictionary = parent_snapshot_value
		var child_snapshot: Dictionary = child_snapshot_value
		if (
			int(parent_snapshot.get("callback_sequence", -1)) != source_semantic_step
			or int(child_snapshot.get("callback_sequence", -1)) != source_semantic_step
			or not bool(parent_snapshot.get("source_measurement", false))
			or not bool(child_snapshot.get("source_measurement", false))
			or not (parent_snapshot.get("transform") is Transform3D)
			or not (parent_snapshot.get("angular_velocity_world_rad_s") is Vector3)
			or not (child_snapshot.get("angular_velocity_world_rad_s") is Vector3)
			or (
				native_angular_velocity_guard_required
				and not (parent_snapshot.get("inverse_inertia_tensor_world_kg_inv_m2") is Basis)
			)
			or (
				native_angular_velocity_guard_required
				and not (child_snapshot.get("inverse_inertia_tensor_world_kg_inv_m2") is Basis)
			)
		):
			return _failure("QSDK_R24D87_FORCE_BASED_SOURCE_STALE:%d" % index)
		var parent_transform: Transform3D = parent_snapshot["transform"]
		var parent_angular: Vector3 = parent_snapshot["angular_velocity_world_rad_s"]
		var child_angular: Vector3 = child_snapshot["angular_velocity_world_rad_s"]
		if (
			native_angular_velocity_guard_required
			and (
				not parent_angular.is_finite()
				or not child_angular.is_finite()
				or not _basis_is_finite_v1(
					parent_snapshot["inverse_inertia_tensor_world_kg_inv_m2"]
				)
				or not _basis_is_finite_v1(child_snapshot["inverse_inertia_tensor_world_kg_inv_m2"])
			)
		):
			return _failure("QSDK_R24D94_GUARDED_SOURCE_INVALID:%d" % index)
		if native_angular_velocity_guard_required:
			source_snapshot_by_body_id[parent_id] = parent_snapshot
			source_snapshot_by_body_id[child_id] = child_snapshot
		var axis_world := (parent_transform.basis * Vector3.BACK).normalized()
		var measured_relative_velocity := (child_angular - parent_angular).dot(axis_world)
		var position := float(position_by_joint_id[joint_id])
		var cap_projection := (
			NativeWorldScript
			. native_effective_impulse_limit_projection_v1(
				actuator_id,
				cap,
			)
		)
		if (
			not is_finite(position)
			or not bool(cap_projection.get("ok", false))
			or (
				float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
				!= float(cap_projection["configured_host_maximum_impulse_nms"])
			)
		):
			return _failure("QSDK_R24D87_FORCE_BASED_CAP_OR_POSITION_INVALID:%d" % index)
		var canonical_velocity := clampf(
			(target - position) / OUTER_STEP_DURATION_S,
			-maximum_speed,
			maximum_speed,
		)
		var projection := (
			NativeWorldScript
			. force_based_joint_impulse_projection_v1(
				index,
				actuator_id,
				joint_id,
				parent_id,
				child_id,
				source_semantic_step,
				true,
				Vector3.BACK,
				axis_world,
				canonical_velocity,
				maximum_speed,
				measured_relative_velocity,
				cap,
			)
		)
		if not bool(projection.get("ok", false)):
			return _failure(
				"QSDK_R24D87_FORCE_BASED_PROJECTION_INVALID:%d" % index,
				projection,
			)
		var projection_validation := (
			NativeWorldScript.validate_force_based_joint_impulse_projection_v1(projection)
		)
		if not bool(projection_validation.get("ok", false)):
			return _failure(
				"QSDK_R24D87_FORCE_BASED_PROJECTION_RECEIPT_INVALID:%d" % index,
				projection_validation,
			)
		projection = projection_validation["projection"]
		var child_impulse := _vector3_from_json_v1(
			projection.get("child_angular_impulse_world_nms")
		)
		var parent_impulse := _vector3_from_json_v1(
			projection.get("parent_angular_impulse_world_nms")
		)
		if (
			not child_impulse.is_finite()
			or not parent_impulse.is_finite()
			or child_impulse + parent_impulse != Vector3.ZERO
		):
			return _failure("QSDK_R24D87_FORCE_BASED_PAIR_INVALID:%d" % index)
		(
			ordered_projections
			. append(
				{
					"parent": parent,
					"child": child,
					"parent_impulse_world_nms": parent_impulse,
					"child_impulse_world_nms": child_impulse,
					"projection": projection,
					"actuator_index": index,
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"parent_body_id": parent_id,
					"child_body_id": child_id,
				}
			)
		)

	var application_semantic_step := source_semantic_step + 1
	var phase := String(control.get("phase", ""))
	if (
		source_semantic_step < 1
		or application_semantic_step < 2
		or phase.is_empty()
		or not expected_command_sha256.begins_with("sha256:")
		or expected_command_sha256.length() != 71
	):
		return _failure("QSDK_R24D87_FORCE_BASED_APPLICATION_IDENTITY_INVALID")
	if native_angular_velocity_guard_required:
		return _apply_guarded_force_based_projection_population_v1(
			model,
			ordered_projections,
			source_snapshot_by_body_id,
			source_semantic_step,
			application_semantic_step,
			phase,
			expected_command_sha256,
			controller_owner,
			recovery_controller_id,
			stance_controller_id,
			handoff_event_count,
			native_angular_velocity_nested_projection_required,
			component_norm_numeric_predicate_required,
			refinement_safe_guard_required,
			order_neutral_population_projection_required,
			joint_target_monotone_population_projection_required,
			joint_space_effective_inertia_population_projection_required,
		)
	var ordered_receipts: Array = []
	for projection_value in ordered_projections:
		var item: Dictionary = projection_value
		var parent: RigidBody3D = item["parent"]
		var child: RigidBody3D = item["child"]
		parent.apply_torque_impulse(item["parent_impulse_world_nms"])
		child.apply_torque_impulse(item["child_impulse_world_nms"])
		var receipt: Dictionary = (item["projection"] as Dictionary).duplicate(true)
		receipt["parent_api"] = "RigidBody3D.apply_torque_impulse"
		receipt["child_api"] = "RigidBody3D.apply_torque_impulse"
		receipt["parent_call_returned"] = true
		receipt["child_call_returned"] = true
		receipt["body_impulse_write_count"] = 2
		ordered_receipts.append(receipt)
	return {
		"schema_version": "sporespore_qsdk_r24d87_godot_force_based_command_application_receipt_v1",
		"ok": true,
		"route_id": ROUTE_ID,
		"actuator_mapping_id": NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"work_mapping_id": NativeWorldScript.FORCE_BASED_WORK_MAPPING_ID,
		"semantic_step": application_semantic_step,
		"source_control_semantic_step": source_semantic_step,
		"phase": phase,
		"command_id": "%s%d" % [command_id_prefix, application_semantic_step],
		"command_sha256": expected_command_sha256,
		"zero_command": false,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"ordered_intents": ordered_receipts.duplicate(true),
		"controller_owner": controller_owner,
		"recovery_controller_id": recovery_controller_id,
		"stance_controller_id": stance_controller_id,
		"handoff_event_count": handoff_event_count,
		"fallback_controller_active": false,
		"validated_command_count": 8,
		"host_write_count": 16,
		"host_readback_count": 8,
		"body_impulse_write_count": 16,
		"ordered_receipts": ordered_receipts,
		"adapter_side_discrete_staging_event_count": 0,
		"root_actuation_count": 0,
		"fallback_control_count": 0,
		"engine_specific_policy_branch_count": 0,
		"zero_world_host_surface": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _apply_guarded_force_based_projection_population_v1(
	model: Dictionary,
	ordered_predecessor_projections: Array,
	source_snapshot_by_body_id: Dictionary,
	source_semantic_step: int,
	application_semantic_step: int,
	phase: String,
	expected_command_sha256: String,
	controller_owner: String,
	recovery_controller_id: Variant,
	stance_controller_id: Variant,
	handoff_event_count: int,
	nested_projection_required: bool,
	component_norm_numeric_predicate_required: bool,
	refinement_safe_guard_required: bool,
	order_neutral_population_projection_required: bool,
	joint_target_monotone_population_projection_required: bool,
	joint_space_effective_inertia_population_projection_required: bool,
) -> Dictionary:
	var body_nodes_value: Variant = model.get("body_nodes")
	if (
		not (body_nodes_value is Dictionary)
		or (body_nodes_value as Dictionary).size() != ORDERED_BODY_IDS.size()
		or source_snapshot_by_body_id.size() != ORDERED_BODY_IDS.size()
		or ordered_predecessor_projections.size() != ORDERED_ACTUATOR_IDS.size()
	):
		return _failure("QSDK_R24D94_GUARDED_BODY_SOURCE_POPULATION_INVALID")
	var runtime_limit_projection := (
		NativeWorldScript.jolt_angular_velocity_limit_runtime_projection_v1()
	)
	var guard_limit_projection := (
		NativeWorldScript
		. native_angular_velocity_guard_limit_projection_v1(runtime_limit_projection)
	)
	if not bool(guard_limit_projection.get("ok", false)):
		return _failure("QSDK_R24D94_GUARDED_RUNTIME_LIMIT_INVALID", guard_limit_projection)
	var inner_projection_target: Dictionary = {}
	if nested_projection_required:
		inner_projection_target = (
			NativeWorldScript
			. native_angular_velocity_inner_projection_target_v1(guard_limit_projection)
		)
		if not bool(inner_projection_target.get("ok", false)):
			return _failure(
				"QSDK_R24D96_NESTED_GUARDED_INNER_TARGET_INVALID",
				inner_projection_target,
			)
	var guard_limit := float(guard_limit_projection["guard_limit_rad_s"])
	var effective_limit := float(guard_limit_projection["effective_max_angular_velocity_rad_s"])
	var body_nodes: Dictionary = body_nodes_value
	var native_angular_velocity_by_body_id: Dictionary = {}
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body_value: Variant = body_nodes.get(body_id)
		var snapshot_value: Variant = source_snapshot_by_body_id.get(body_id)
		if not (body_value is RigidBody3D) or not (snapshot_value is Dictionary):
			return _failure("QSDK_R24D94_GUARDED_BODY_SOURCE_MISSING:%s" % body_id)
		var body: RigidBody3D = body_value
		var snapshot: Dictionary = snapshot_value
		var snapshot_angular_value: Variant = snapshot.get("angular_velocity_world_rad_s")
		var native_angular_value: Variant = PhysicsServer3D.body_get_state(
			body.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY
		)
		var native_effective_relation: Dictionary = {}
		if component_norm_numeric_predicate_required and native_angular_value is Vector3:
			native_effective_relation = (
				NativeWorldScript
				. angular_velocity_component_norm_limit_relation_v1(
					native_angular_value, effective_limit
				)
			)
		if (
			not (snapshot_angular_value is Vector3)
			or not (native_angular_value is Vector3)
			or not (snapshot_angular_value as Vector3).is_finite()
			or not (native_angular_value as Vector3).is_finite()
			or native_angular_value != snapshot_angular_value
			or (
				component_norm_numeric_predicate_required
				and (
					not bool(native_effective_relation.get("ok", false))
					or not bool(native_effective_relation.get("inside_or_on_limit", false))
				)
			)
			or (
				not component_norm_numeric_predicate_required
				and (native_angular_value as Vector3).length() > effective_limit
			)
		):
			return _failure(
				"QSDK_R24D94_GUARDED_INITIAL_NATIVE_READBACK_INVALID:%s" % body_id,
				{
					"snapshot": snapshot_angular_value,
					"native_readback": native_angular_value,
				},
			)
		native_angular_velocity_by_body_id[body_id] = native_angular_value
	if order_neutral_population_projection_required:
		return _apply_order_neutral_population_guarded_force_based_projection_v1(
			body_nodes,
			ordered_predecessor_projections,
			source_snapshot_by_body_id,
			native_angular_velocity_by_body_id,
			source_semantic_step,
			application_semantic_step,
			phase,
			expected_command_sha256,
			controller_owner,
			recovery_controller_id,
			stance_controller_id,
			handoff_event_count,
			guard_limit_projection,
			inner_projection_target,
			joint_target_monotone_population_projection_required,
			joint_space_effective_inertia_population_projection_required,
		)

	var ordered_receipts: Array = []
	var guard_engagement_count := 0
	var minimum_applied_scale := 1.0
	var completed_body_impulse_write_count := 0
	var completed_native_readback_count := ORDERED_BODY_IDS.size()
	for item_index in range(ordered_predecessor_projections.size()):
		var item_value: Variant = ordered_predecessor_projections[item_index]
		if not (item_value is Dictionary):
			return _guarded_application_failure_v1(
				"QSDK_R24D94_GUARDED_PREDECESSOR_POPULATION_INVALID:%d" % item_index,
				{},
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		var item: Dictionary = item_value
		var parent: RigidBody3D = item["parent"]
		var child: RigidBody3D = item["child"]
		var parent_body_id := String(item["parent_body_id"])
		var child_body_id := String(item["child_body_id"])
		var parent_snapshot: Dictionary = source_snapshot_by_body_id[parent_body_id]
		var child_snapshot: Dictionary = source_snapshot_by_body_id[child_body_id]
		var guard_pair := (
			(
				NativeWorldScript
				. nested_native_angular_velocity_guard_pair_projection_v3(
					int(item["actuator_index"]),
					String(item["actuator_id"]),
					String(item["joint_id"]),
					parent_body_id,
					child_body_id,
					source_semantic_step,
					inner_projection_target,
					native_angular_velocity_by_body_id[parent_body_id],
					native_angular_velocity_by_body_id[child_body_id],
					parent_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
					child_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
					item["parent_impulse_world_nms"],
					item["child_impulse_world_nms"],
				)
			)
			if refinement_safe_guard_required
			else (
				(
					NativeWorldScript
					. nested_native_angular_velocity_guard_pair_projection_v2(
						int(item["actuator_index"]),
						String(item["actuator_id"]),
						String(item["joint_id"]),
						parent_body_id,
						child_body_id,
						source_semantic_step,
						inner_projection_target,
						native_angular_velocity_by_body_id[parent_body_id],
						native_angular_velocity_by_body_id[child_body_id],
						parent_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
						child_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
						item["parent_impulse_world_nms"],
						item["child_impulse_world_nms"],
					)
				)
				if component_norm_numeric_predicate_required
				else (
					(
						NativeWorldScript
						. nested_native_angular_velocity_guard_pair_projection_v1(
							int(item["actuator_index"]),
							String(item["actuator_id"]),
							String(item["joint_id"]),
							parent_body_id,
							child_body_id,
							source_semantic_step,
							inner_projection_target,
							native_angular_velocity_by_body_id[parent_body_id],
							native_angular_velocity_by_body_id[child_body_id],
							parent_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
							child_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
							item["parent_impulse_world_nms"],
							item["child_impulse_world_nms"],
						)
					)
					if nested_projection_required
					else (
						NativeWorldScript
						. native_angular_velocity_guard_pair_projection_v1(
							int(item["actuator_index"]),
							String(item["actuator_id"]),
							String(item["joint_id"]),
							parent_body_id,
							child_body_id,
							source_semantic_step,
							guard_limit_projection,
							native_angular_velocity_by_body_id[parent_body_id],
							native_angular_velocity_by_body_id[child_body_id],
							parent_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
							child_snapshot["inverse_inertia_tensor_world_kg_inv_m2"],
							item["parent_impulse_world_nms"],
							item["child_impulse_world_nms"],
						)
					)
				)
			)
		)
		if not bool(guard_pair.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D94_GUARDED_PAIR_PROJECTION_INVALID:%d" % item_index,
				guard_pair,
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		var guarded_projection := (
			(
				NativeWorldScript
				. refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
					item["projection"], guard_pair
				)
			)
			if refinement_safe_guard_required
			else (
				(
					NativeWorldScript
					. component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
						item["projection"], guard_pair
					)
				)
				if component_norm_numeric_predicate_required
				else (
					NativeWorldScript.nested_guarded_force_based_joint_impulse_projection_v1(
						item["projection"], guard_pair
					)
					if nested_projection_required
					else NativeWorldScript.guarded_force_based_joint_impulse_projection_v1(
						item["projection"], guard_pair
					)
				)
			)
		)
		var guarded_validation := (
			(
				NativeWorldScript
				. validate_refinement_safe_component_norm_nested_guarded_force_based_joint_impulse_projection_v2(
					guarded_projection
				)
			)
			if refinement_safe_guard_required
			else (
				(
					NativeWorldScript
					. validate_component_norm_nested_guarded_force_based_joint_impulse_projection_v1(
						guarded_projection
					)
				)
				if component_norm_numeric_predicate_required
				else (
					(
						NativeWorldScript
						. validate_nested_guarded_force_based_joint_impulse_projection_v1(
							guarded_projection
						)
					)
					if nested_projection_required
					else NativeWorldScript.validate_guarded_force_based_joint_impulse_projection_v1(
						guarded_projection
					)
				)
			)
		)
		if not bool(guarded_validation.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D94_GUARDED_PROJECTION_INVALID:%d" % item_index,
				guarded_validation,
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		guarded_projection = guarded_validation["projection"]
		var parent_impulse := _vector3_from_json_v1(
			guarded_projection.get("parent_angular_impulse_world_nms")
		)
		var child_impulse := _vector3_from_json_v1(
			guarded_projection.get("child_angular_impulse_world_nms")
		)
		parent.apply_torque_impulse(parent_impulse)
		child.apply_torque_impulse(child_impulse)
		completed_body_impulse_write_count += 2
		var parent_post_value: Variant = PhysicsServer3D.body_get_state(
			parent.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY
		)
		var child_post_value: Variant = PhysicsServer3D.body_get_state(
			child.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY
		)
		completed_native_readback_count += 2
		var parent_post_relation: Dictionary = {}
		var child_post_relation: Dictionary = {}
		if (
			component_norm_numeric_predicate_required
			and parent_post_value is Vector3
			and child_post_value is Vector3
		):
			parent_post_relation = (
				NativeWorldScript
				. angular_velocity_component_norm_limit_relation_v1(parent_post_value, guard_limit)
			)
			child_post_relation = (
				NativeWorldScript
				. angular_velocity_component_norm_limit_relation_v1(child_post_value, guard_limit)
			)
		if (
			not (parent_post_value is Vector3)
			or not (child_post_value is Vector3)
			or not (parent_post_value as Vector3).is_finite()
			or not (child_post_value as Vector3).is_finite()
			or (
				component_norm_numeric_predicate_required
				and (
					not bool(parent_post_relation.get("inside_or_on_limit", false))
					or not bool(child_post_relation.get("inside_or_on_limit", false))
				)
			)
			or (
				not component_norm_numeric_predicate_required
				and (parent_post_value as Vector3).length() > guard_limit
			)
			or (
				not component_norm_numeric_predicate_required
				and (child_post_value as Vector3).length() > guard_limit
			)
		):
			return _guarded_application_failure_v1(
				"QSDK_R24D94_GUARDED_IMMEDIATE_NATIVE_READBACK_INVALID:%d" % item_index,
				{
					"guard_limit_rad_s": guard_limit,
					"parent_post": parent_post_value,
					"child_post": child_post_value,
				},
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		var parent_post: Vector3 = parent_post_value
		var child_post: Vector3 = child_post_value
		native_angular_velocity_by_body_id[parent_body_id] = parent_post
		native_angular_velocity_by_body_id[child_body_id] = child_post
		var native_readback_receipt := (
			(
				NativeWorldScript
				. refinement_safe_component_norm_nested_native_angular_velocity_guard_readback_receipt_v2(
					guarded_projection, parent_post, child_post
				)
			)
			if refinement_safe_guard_required
			else (
				(
					NativeWorldScript
					. component_norm_nested_native_angular_velocity_guard_readback_receipt_v1(
						guarded_projection, parent_post, child_post
					)
				)
				if component_norm_numeric_predicate_required
				else (
					NativeWorldScript.nested_native_angular_velocity_guard_readback_receipt_v1(
						guarded_projection, parent_post, child_post
					)
					if nested_projection_required
					else NativeWorldScript.native_angular_velocity_guard_readback_receipt_v1(
						guarded_projection, parent_post, child_post
					)
				)
			)
		)
		if not bool(native_readback_receipt.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D94_GUARDED_READBACK_RECEIPT_INVALID:%d" % item_index,
				native_readback_receipt,
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		var receipt: Dictionary = guarded_projection.duplicate(true)
		receipt["parent_api"] = "RigidBody3D.apply_torque_impulse"
		receipt["child_api"] = "RigidBody3D.apply_torque_impulse"
		receipt["parent_call_returned"] = true
		receipt["child_call_returned"] = true
		receipt["body_impulse_write_count"] = 2
		receipt["native_angular_velocity_readback"] = native_readback_receipt
		guard_engagement_count += int(
			bool(guarded_projection["native_angular_velocity_guard_engaged"])
		)
		var applied_scale_projection := (
			(
				NativeWorldScript
				. refinement_safe_component_norm_guarded_force_based_applied_scale_projection_v2(
					guarded_projection
				)
			)
			if refinement_safe_guard_required
			else (
				NativeWorldScript.component_norm_guarded_force_based_applied_scale_projection_v1(
					guarded_projection
				)
				if component_norm_numeric_predicate_required
				else NativeWorldScript.guarded_force_based_applied_scale_projection_v1(
					guarded_projection, nested_projection_required
				)
			)
		)
		if not bool(applied_scale_projection.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D97_ROUTE_APPLIED_SCALE_PROJECTION_INVALID:%d" % item_index,
				applied_scale_projection,
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		minimum_applied_scale = minf(
			minimum_applied_scale,
			float(applied_scale_projection["applied_scale"]),
		)
		ordered_receipts.append(receipt)

	var application_receipt := {
		"schema_version":
		(
			"sporespore_qsdk_r24d100_godot_refinement_safe_component_norm_nested_guarded_force_based_command_application_receipt_v1"
			if refinement_safe_guard_required
			else (
				"sporespore_qsdk_r24d99_godot_component_norm_nested_guarded_force_based_command_application_receipt_v1"
				if component_norm_numeric_predicate_required
				else (
					"sporespore_qsdk_r24d96_godot_nested_guarded_force_based_command_application_receipt_v1"
					if nested_projection_required
					else "sporespore_qsdk_r24d94_godot_guarded_force_based_command_application_receipt_v1"
				)
			)
		),
		"ok": true,
		"route_id": ROUTE_ID,
		"actuator_mapping_id":
		(
			(
				NativeWorldScript
				. REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			)
			if refinement_safe_guard_required
			else (
				NativeWorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
				if component_norm_numeric_predicate_required
				else (
					NativeWorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
					if nested_projection_required
					else NativeWorldScript.GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
				)
			)
		),
		"work_mapping_id":
		(
			(
				NativeWorldScript
				. REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			)
			if refinement_safe_guard_required
			else (
				NativeWorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
				if component_norm_numeric_predicate_required
				else (
					NativeWorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
					if nested_projection_required
					else NativeWorldScript.GUARDED_FORCE_BASED_WORK_MAPPING_ID
				)
			)
		),
		"predecessor_actuator_mapping_id": NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"semantic_step": application_semantic_step,
		"source_control_semantic_step": source_semantic_step,
		"phase": phase,
		"command_id":
		(
			(
				"r24d100_godot_refinement_safe_component_norm_nested_guarded_force_based_command_step_%d"
				% application_semantic_step
			)
			if refinement_safe_guard_required
			else (
				(
					"r24d99_godot_component_norm_nested_guarded_force_based_command_step_%d"
					% application_semantic_step
				)
				if component_norm_numeric_predicate_required
				else (
					(
						"r24d96_godot_nested_guarded_force_based_command_step_%d"
						% application_semantic_step
					)
					if nested_projection_required
					else (
						"r24d94_godot_guarded_force_based_command_step_%d"
						% application_semantic_step
					)
				)
			)
		),
		"command_sha256": expected_command_sha256,
		"zero_command": false,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"ordered_intents": ordered_receipts.duplicate(true),
		"controller_owner": controller_owner,
		"recovery_controller_id": recovery_controller_id,
		"stance_controller_id": stance_controller_id,
		"handoff_event_count": handoff_event_count,
		"fallback_controller_active": false,
		"validated_command_count": 8,
		"host_write_count": 16,
		"host_readback_count": 8,
		"body_impulse_write_count": completed_body_impulse_write_count,
		"ordered_receipts": ordered_receipts,
		"native_angular_velocity_guard_required": true,
		"native_angular_velocity_guard_limit_projection": guard_limit_projection,
		"native_angular_velocity_guard_engagement_count": guard_engagement_count,
		"native_angular_velocity_guard_minimum_applied_scale": minimum_applied_scale,
		"native_angular_velocity_initial_readback_count": ORDERED_BODY_IDS.size(),
		"native_angular_velocity_post_application_readback_count": 16,
		"native_angular_velocity_total_readback_count": completed_native_readback_count,
		"all_immediate_native_readbacks_inside_guard": true,
		"adapter_side_discrete_staging_event_count": 0,
		"root_actuation_count": 0,
		"fallback_control_count": 0,
		"engine_specific_policy_branch_count": 0,
		"zero_world_host_surface": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if nested_projection_required:
		application_receipt["native_angular_velocity_inner_projection_target"] = (
			inner_projection_target.duplicate(true)
		)
		application_receipt["native_angular_velocity_nested_projection_required"] = true
		application_receipt["projection_target_separated_from_native_readback_guard"] = true
	if component_norm_numeric_predicate_required:
		application_receipt["numeric_predicate_id"] = (
			NativeWorldScript.COMPONENT_NORM_NUMERIC_PREDICATE_ID
		)
		application_receipt["component_norm_numeric_predicate_required"] = true
	if refinement_safe_guard_required:
		application_receipt["refinement_safe_guard_required"] = true
	return application_receipt


static func _apply_order_neutral_population_guarded_force_based_projection_v1(
	body_nodes: Dictionary,
	ordered_predecessor_projections: Array,
	source_snapshot_by_body_id: Dictionary,
	native_angular_velocity_by_body_id: Dictionary,
	source_semantic_step: int,
	application_semantic_step: int,
	phase: String,
	expected_command_sha256: String,
	controller_owner: String,
	recovery_controller_id: Variant,
	stance_controller_id: Variant,
	handoff_event_count: int,
	guard_limit_projection: Dictionary,
	inner_projection_target: Dictionary,
	joint_target_monotone_population_projection_required: bool = false,
	joint_space_effective_inertia_population_projection_required: bool = false,
) -> Dictionary:
	var initial_native_readback_count := ORDERED_BODY_IDS.size()
	var request_values: Array = []
	var predecessor_projection_values: Array = []
	var inverse_inertia_tensor_by_body_id: Dictionary = {}
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var snapshot_value: Variant = source_snapshot_by_body_id.get(body_id)
		if not (snapshot_value is Dictionary):
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_SOURCE_SNAPSHOT_INVALID:%s" % body_id,
				{},
				0,
				initial_native_readback_count,
			)
		var snapshot: Dictionary = snapshot_value
		var inverse_inertia_value: Variant = snapshot.get("inverse_inertia_tensor_world_kg_inv_m2")
		if not (inverse_inertia_value is Basis):
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_INERTIA_SOURCE_INVALID:%s" % body_id,
				{},
				0,
				initial_native_readback_count,
			)
		inverse_inertia_tensor_by_body_id[body_id] = inverse_inertia_value
	for item_index in range(ordered_predecessor_projections.size()):
		var item_value: Variant = ordered_predecessor_projections[item_index]
		if not (item_value is Dictionary):
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_PREDECESSOR_INVALID:%d" % item_index,
				{},
				0,
				initial_native_readback_count,
			)
		var item: Dictionary = item_value
		predecessor_projection_values.append(item.get("projection"))
		(
			request_values
			. append(
				{
					"actuator_index": int(item.get("actuator_index", -1)),
					"actuator_id": String(item.get("actuator_id", "")),
					"joint_id": String(item.get("joint_id", "")),
					"parent_body_id": String(item.get("parent_body_id", "")),
					"child_body_id": String(item.get("child_body_id", "")),
					"requested_parent_impulse_world_nms": item.get("parent_impulse_world_nms"),
					"requested_child_impulse_world_nms": item.get("child_impulse_world_nms"),
				}
			)
		)
	var joint_space_effective_inertia_population_projection: Dictionary = {}
	var joint_target_monotone_population_projection: Dictionary = {}
	var population_projection: Dictionary = {}
	if joint_space_effective_inertia_population_projection_required:
		joint_space_effective_inertia_population_projection = (
			NativeWorldScript
			. joint_space_effective_inertia_population_guard_projection_v1(
				predecessor_projection_values,
				native_angular_velocity_by_body_id,
				inverse_inertia_tensor_by_body_id,
				source_semantic_step,
				inner_projection_target,
			)
		)
		if not bool(joint_space_effective_inertia_population_projection.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D109_EFFECTIVE_INERTIA_POPULATION_PROJECTION_INVALID",
				joint_space_effective_inertia_population_projection,
				0,
				initial_native_readback_count,
			)
		var effective_inertia_population_validation := (
			NativeWorldScript
			. validate_joint_space_effective_inertia_population_guard_projection_v1(
				joint_space_effective_inertia_population_projection
			)
		)
		if not bool(effective_inertia_population_validation.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D109_EFFECTIVE_INERTIA_POPULATION_VALIDATION_FAILED",
				effective_inertia_population_validation,
				0,
				initial_native_readback_count,
			)
		joint_space_effective_inertia_population_projection = (effective_inertia_population_validation["projection"])
		population_projection = (joint_space_effective_inertia_population_projection["body_guard_population_projection"])
	elif joint_target_monotone_population_projection_required:
		joint_target_monotone_population_projection = (
			NativeWorldScript
			. joint_target_monotone_population_guard_projection_v1(
				predecessor_projection_values,
				native_angular_velocity_by_body_id,
				inverse_inertia_tensor_by_body_id,
				source_semantic_step,
				inner_projection_target,
			)
		)
		if not bool(joint_target_monotone_population_projection.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D107_TARGET_MONOTONE_POPULATION_PROJECTION_INVALID",
				joint_target_monotone_population_projection,
				0,
				initial_native_readback_count,
			)
		var target_population_validation := (
			NativeWorldScript
			. validate_joint_target_monotone_population_guard_projection_v1(
				joint_target_monotone_population_projection
			)
		)
		if not bool(target_population_validation.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D107_TARGET_MONOTONE_POPULATION_VALIDATION_FAILED",
				target_population_validation,
				0,
				initial_native_readback_count,
			)
		joint_target_monotone_population_projection = (target_population_validation["projection"])
		population_projection = (joint_target_monotone_population_projection["body_guard_population_projection"])
	else:
		population_projection = (
			NativeWorldScript
			. order_neutral_population_guard_projection_v1(
				request_values,
				native_angular_velocity_by_body_id,
				inverse_inertia_tensor_by_body_id,
				source_semantic_step,
				inner_projection_target,
			)
		)
		if not bool(population_projection.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_PROJECTION_INVALID",
				population_projection,
				0,
				initial_native_readback_count,
			)
		var population_validation := (
			NativeWorldScript
			. validate_order_neutral_population_guard_projection_v1(population_projection)
		)
		if not bool(population_validation.get("ok", false)):
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_PROJECTION_VALIDATION_FAILED",
				population_validation,
				0,
				initial_native_readback_count,
			)
		population_projection = population_validation["projection"]

	# Freeze every per-actuator attribution and every native body binding before
	# the first write. A later validation failure therefore cannot create a
	# partially applied population.
	var ordered_joint_projections: Array = []
	for item_index in range(ordered_predecessor_projections.size()):
		var item: Dictionary = ordered_predecessor_projections[item_index]
		var joint_projection := (
			(
				NativeWorldScript
				. joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
					item["projection"],
					joint_space_effective_inertia_population_projection,
					item_index,
				)
			)
			if joint_space_effective_inertia_population_projection_required
			else (
				(
					NativeWorldScript
					. joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
						item["projection"],
						joint_target_monotone_population_projection,
						item_index,
					)
				)
				if joint_target_monotone_population_projection_required
				else (
					NativeWorldScript
					. order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
						item["projection"], population_projection, item_index
					)
				)
			)
		)
		var joint_validation := (
			(
				NativeWorldScript
				. validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
					joint_projection,
					joint_space_effective_inertia_population_projection,
				)
			)
			if joint_space_effective_inertia_population_projection_required
			else (
				(
					NativeWorldScript
					. validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
						joint_projection,
						joint_target_monotone_population_projection,
					)
				)
				if joint_target_monotone_population_projection_required
				else (
					NativeWorldScript
					. validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
						joint_projection, population_projection
					)
				)
			)
		)
		if not bool(joint_validation.get("ok", false)):
			return _guarded_application_failure_v1(
				(
					"QSDK_R24D109_EFFECTIVE_INERTIA_JOINT_PROJECTION_INVALID:%d" % item_index
					if joint_space_effective_inertia_population_projection_required
					else (
						"QSDK_R24D107_TARGET_MONOTONE_JOINT_PROJECTION_INVALID:%d" % item_index
						if joint_target_monotone_population_projection_required
						else "QSDK_R24D103_POPULATION_JOINT_PROJECTION_INVALID:%d" % item_index
					)
				),
				joint_validation,
				0,
				initial_native_readback_count,
			)
		ordered_joint_projections.append(joint_validation["projection"])
	var body_projection_values: Variant = population_projection.get("ordered_body_projections")
	if not (body_projection_values is Array):
		return _guarded_application_failure_v1(
			"QSDK_R24D103_POPULATION_BODY_PLAN_MISSING",
			{},
			0,
			initial_native_readback_count,
		)
	var body_projections: Array = body_projection_values
	if body_projections.size() != ORDERED_BODY_IDS.size():
		return _guarded_application_failure_v1(
			"QSDK_R24D103_POPULATION_BODY_PLAN_CARDINALITY_INVALID",
			{},
			0,
			initial_native_readback_count,
		)
	var ordered_body_application_plan: Array = []
	for body_index in range(ORDERED_BODY_IDS.size()):
		var body_id := String(ORDERED_BODY_IDS[body_index])
		var body_value: Variant = body_nodes.get(body_id)
		var body_projection_value: Variant = body_projections[body_index]
		if not (body_value is RigidBody3D) or not (body_projection_value is Dictionary):
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_BODY_BINDING_INVALID:%s" % body_id,
				{},
				0,
				initial_native_readback_count,
			)
		var body_projection: Dictionary = body_projection_value
		var aggregate_impulse := _vector3_from_json_v1(
			body_projection.get("applied_aggregate_impulse_world_nms")
		)
		if (
			String(body_projection.get("body_id", "")) != body_id
			or not aggregate_impulse.is_finite()
			or (
				bool(body_projection.get("nonzero_body_impulse", false))
				!= (aggregate_impulse != Vector3.ZERO)
			)
		):
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_BODY_PLAN_INVALID:%s" % body_id,
				body_projection,
				0,
				initial_native_readback_count,
			)
		(
			ordered_body_application_plan
			. append(
				{
					"body_index": body_index,
					"body_id": body_id,
					"body": body_value,
					"aggregate_impulse_world_nms": aggregate_impulse,
					"projection": body_projection,
				}
			)
		)

	var completed_body_impulse_write_count := 0
	var ordered_body_application_receipts: Array = []
	for plan_value in ordered_body_application_plan:
		var plan: Dictionary = plan_value
		var body: RigidBody3D = plan["body"]
		var impulse: Vector3 = plan["aggregate_impulse_world_nms"]
		var call_performed := impulse != Vector3.ZERO
		if call_performed:
			body.apply_torque_impulse(impulse)
			completed_body_impulse_write_count += 1
		(
			ordered_body_application_receipts
			. append(
				{
					"body_index": int(plan["body_index"]),
					"body_id": String(plan["body_id"]),
					"api": "RigidBody3D.apply_torque_impulse",
					"aggregate_impulse_world_nms":
					(plan["projection"] as Dictionary)["applied_aggregate_impulse_world_nms"],
					"call_performed": call_performed,
					"call_returned": call_performed,
					"body_impulse_write_count": int(call_performed),
					"canonical_body_order": true,
				}
			)
		)
	if (
		completed_body_impulse_write_count
		!= int(population_projection.get("nonzero_body_impulse_count", -1))
	):
		return _guarded_application_failure_v1(
			"QSDK_R24D103_POPULATION_BODY_WRITE_COUNT_INVALID",
			{},
			completed_body_impulse_write_count,
			initial_native_readback_count,
		)

	var post_angular_velocity_by_body_id: Dictionary = {}
	var completed_native_readback_count := initial_native_readback_count
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var body: RigidBody3D = body_nodes[body_id]
		var post_value: Variant = PhysicsServer3D.body_get_state(
			body.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY
		)
		completed_native_readback_count += 1
		if not (post_value is Vector3) or not (post_value as Vector3).is_finite():
			return _guarded_application_failure_v1(
				"QSDK_R24D103_POPULATION_POST_READBACK_INVALID:%s" % body_id,
				{},
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		post_angular_velocity_by_body_id[body_id] = post_value
	var population_readback := (
		NativeWorldScript
		. order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			population_projection, post_angular_velocity_by_body_id
		)
	)
	var population_readback_validation := (
		NativeWorldScript
		. validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			population_projection, population_readback
		)
	)
	if not bool(population_readback_validation.get("ok", false)):
		return _guarded_application_failure_v1(
			"QSDK_R24D103_POPULATION_READBACK_INVALID",
			population_readback_validation,
			completed_body_impulse_write_count,
			completed_native_readback_count,
		)
	population_readback = population_readback_validation["receipt"]

	var ordered_receipts: Array = []
	for item_index in range(ordered_joint_projections.size()):
		var joint_projection: Dictionary = ordered_joint_projections[item_index]
		var joint_readback := (
			(
				NativeWorldScript
				. joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
					joint_projection,
					joint_space_effective_inertia_population_projection,
					population_readback,
				)
			)
			if joint_space_effective_inertia_population_projection_required
			else (
				(
					NativeWorldScript
					. joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
						joint_projection,
						joint_target_monotone_population_projection,
						population_readback,
					)
				)
				if joint_target_monotone_population_projection_required
				else (
					NativeWorldScript
					. order_neutral_population_joint_angular_velocity_readback_receipt_v1(
						joint_projection, population_projection, population_readback
					)
				)
			)
		)
		var joint_readback_validation := (
			(
				NativeWorldScript
				. validate_joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
					joint_projection,
					joint_space_effective_inertia_population_projection,
					population_readback,
					joint_readback,
				)
			)
			if joint_space_effective_inertia_population_projection_required
			else (
				(
					NativeWorldScript
					. validate_joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
						joint_projection,
						joint_target_monotone_population_projection,
						population_readback,
						joint_readback,
					)
				)
				if joint_target_monotone_population_projection_required
				else (
					NativeWorldScript
					. validate_order_neutral_population_joint_angular_velocity_readback_receipt_v1(
						joint_projection,
						population_projection,
						population_readback,
						joint_readback,
					)
				)
			)
		)
		if not bool(joint_readback_validation.get("ok", false)):
			return _guarded_application_failure_v1(
				(
					"QSDK_R24D109_EFFECTIVE_INERTIA_JOINT_READBACK_INVALID:%d" % item_index
					if joint_space_effective_inertia_population_projection_required
					else (
						"QSDK_R24D107_TARGET_MONOTONE_JOINT_READBACK_INVALID:%d" % item_index
						if joint_target_monotone_population_projection_required
						else "QSDK_R24D103_POPULATION_JOINT_READBACK_INVALID:%d" % item_index
					)
				),
				joint_readback_validation,
				completed_body_impulse_write_count,
				completed_native_readback_count,
			)
		var receipt := joint_projection.duplicate(true)
		receipt["aggregate_body_application"] = true
		receipt["joint_attribution_only"] = true
		receipt["direct_joint_body_impulse_write_count"] = 0
		receipt["body_impulse_write_count"] = 0
		receipt["native_angular_velocity_readback"] = (joint_readback_validation["receipt"])
		ordered_receipts.append(receipt)

	var common_applied_scale := (
		float(
			joint_space_effective_inertia_population_projection.get(
				"nominal_composed_common_scale", NAN
			)
		)
		if joint_space_effective_inertia_population_projection_required
		else (
			float(
				joint_target_monotone_population_projection.get(
					"nominal_composed_common_scale", NAN
				)
			)
			if joint_target_monotone_population_projection_required
			else float(population_projection.get("common_applied_scale", NAN))
		)
	)
	var population_guard_engaged := (
		bool(joint_space_effective_inertia_population_projection.get("solver_guard_engaged", false))
		or bool(joint_target_monotone_population_projection.get("target_guard_engaged", false))
		or bool(population_projection.get("population_guard_engaged", false))
	)
	var application_receipt := {
		"schema_version":
		(
			"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_application_receipt_v1"
			if joint_space_effective_inertia_population_projection_required
			else (
				"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_force_based_command_application_receipt_v1"
				if joint_target_monotone_population_projection_required
				else "sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_force_based_command_application_receipt_v1"
			)
		),
		"ok": true,
		"route_id": ROUTE_ID,
		"actuator_mapping_id":
		(
			(
				NativeWorldScript
				. JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			)
			if joint_space_effective_inertia_population_projection_required
			else (
				(
					NativeWorldScript
					. JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
				)
				if joint_target_monotone_population_projection_required
				else (
					NativeWorldScript
					. ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
				)
			)
		),
		"work_mapping_id":
		(
			(
				NativeWorldScript
				. JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			)
			if joint_space_effective_inertia_population_projection_required
			else (
				(
					NativeWorldScript
					. JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
				)
				if joint_target_monotone_population_projection_required
				else NativeWorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			)
		),
		"predecessor_actuator_mapping_id": NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID,
		"semantic_step": application_semantic_step,
		"source_control_semantic_step": source_semantic_step,
		"phase": phase,
		"command_id":
		(
			(
				"r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_step_%d"
				if joint_space_effective_inertia_population_projection_required
				else (
					"r24d107_godot_joint_target_monotone_population_guarded_force_based_command_step_%d"
					if joint_target_monotone_population_projection_required
					else "r24d103_godot_order_neutral_population_guarded_force_based_command_step_%d"
				)
			)
			% application_semantic_step
		),
		"command_sha256": expected_command_sha256,
		"zero_command": false,
		"motor_enabled_count": 0,
		"hard_constraint_motor_disabled_count": 8,
		"hard_constraint_motor_target_write_count": 0,
		"ordered_intents": ordered_receipts.duplicate(true),
		"controller_owner": controller_owner,
		"recovery_controller_id": recovery_controller_id,
		"stance_controller_id": stance_controller_id,
		"handoff_event_count": handoff_event_count,
		"fallback_controller_active": false,
		"validated_command_count": ORDERED_ACTUATOR_IDS.size(),
		"host_write_count": completed_body_impulse_write_count,
		"host_readback_count": ORDERED_ACTUATOR_IDS.size(),
		"body_impulse_write_count": completed_body_impulse_write_count,
		"ordered_receipts": ordered_receipts,
		"ordered_body_application_receipts": ordered_body_application_receipts,
		"order_neutral_population_native_angular_velocity_readback": population_readback,
		"native_angular_velocity_guard_required": true,
		"native_angular_velocity_guard_limit_projection": guard_limit_projection,
		"native_angular_velocity_guard_engagement_count":
		ORDERED_ACTUATOR_IDS.size() if population_guard_engaged else 0,
		"native_angular_velocity_guard_minimum_applied_scale": common_applied_scale,
		"native_angular_velocity_initial_readback_count": initial_native_readback_count,
		"native_angular_velocity_post_application_readback_count": ORDERED_BODY_IDS.size(),
		"native_angular_velocity_total_readback_count": completed_native_readback_count,
		"all_immediate_native_readbacks_inside_guard": true,
		"native_angular_velocity_inner_projection_target": inner_projection_target.duplicate(true),
		"native_angular_velocity_nested_projection_required": true,
		"projection_target_separated_from_native_readback_guard": true,
		"numeric_predicate_id": NativeWorldScript.COMPONENT_NORM_NUMERIC_PREDICATE_ID,
		"component_norm_numeric_predicate_required": true,
		"refinement_safe_guard_required": true,
		"order_neutral_population_projection_required": true,
		"aggregate_body_application_required": true,
		"per_actuator_attribution_required": true,
		"input_iteration_order_has_action_authority": false,
		"adapter_side_discrete_staging_event_count": 0,
		"root_actuation_count": 0,
		"fallback_control_count": 0,
		"engine_specific_policy_branch_count": 0,
		"zero_world_host_surface": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": completed_body_impulse_write_count > 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if joint_space_effective_inertia_population_projection_required:
		application_receipt["joint_space_effective_inertia_population_guard_projection"] = (joint_space_effective_inertia_population_projection)
		application_receipt["joint_space_effective_inertia_population_projection_required"] = true
		application_receipt["joint_space_effective_inertia_common_pre_scale"] = float(
			joint_space_effective_inertia_population_projection["joint_space_common_pre_scale"]
		)
		application_receipt["body_guard_common_applied_scale"] = float(
			joint_space_effective_inertia_population_projection["body_guard_common_applied_scale"]
		)
		application_receipt["representation_refinement_count"] = int(
			joint_space_effective_inertia_population_projection["representation_refinement_count"]
		)
		application_receipt["all_joint_target_errors_nonincreasing"] = true
		application_receipt["joint_target_crossing_count"] = 0
	elif joint_target_monotone_population_projection_required:
		application_receipt["joint_target_monotone_population_guard_projection"] = (joint_target_monotone_population_projection)
		application_receipt["joint_target_monotone_population_projection_required"] = true
		application_receipt["joint_target_monotone_common_pre_scale"] = float(
			joint_target_monotone_population_projection["target_common_pre_scale"]
		)
		application_receipt["body_guard_common_applied_scale"] = float(
			joint_target_monotone_population_projection["body_guard_common_applied_scale"]
		)
		application_receipt["population_zero_hold_for_nonhelpful_joint_delta"] = bool(
			joint_target_monotone_population_projection["population_zero_hold_for_nonhelpful_joint_delta"]
		)
		application_receipt["all_joint_target_errors_nonincreasing"] = true
		application_receipt["joint_target_crossing_count"] = 0
	else:
		application_receipt["order_neutral_population_guard_projection"] = population_projection
	return application_receipt


static func _guarded_application_failure_v1(
	code: String,
	detail: Dictionary,
	body_impulse_write_count: int,
	native_readback_count: int,
) -> Dictionary:
	var failure := _failure(code, detail)
	failure["physics_state_modified"] = body_impulse_write_count > 0
	failure["body_impulse_write_count"] = body_impulse_write_count
	failure["native_angular_velocity_readback_count"] = native_readback_count
	failure["solver_step_count"] = 0
	return failure


static func _vector3_from_json_v1(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var source: Dictionary = value
	return Vector3(
		float(source.get("x", NAN)),
		float(source.get("y", NAN)),
		float(source.get("z", NAN)),
	)


static func _basis_is_finite_v1(value: Basis) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()


static func _apply_active_control_commands_v1(
	sdk: Object,
	control: Dictionary,
	joint_by_actuator_id: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool,
	controller_owner: String,
	recovery_controller_id: Variant,
	stance_controller_id: Variant,
	handoff_event_count: int,
	command_id_prefix: String,
) -> Dictionary:
	var commands_value: Variant = control.get("ordered_commands")
	if not (commands_value is Array) or (commands_value as Array).size() != 8:
		return _failure("QSDK_R24D57_COMMAND_CARDINALITY_INVALID")
	var commands: Array = commands_value
	var expected_command_sha256 := String(control.get("command_sha256", ""))
	var recomputed_digest_receipt := RecoveryRuntimeScript.canonicalize(sdk, commands)
	var recomputed_command_sha256 := String(recomputed_digest_receipt.get("sha256", ""))
	if recomputed_command_sha256 != expected_command_sha256:
		return _failure(
			"QSDK_R24D57_COMMAND_DIGEST_INVALID",
			_command_digest_mismatch_diagnostic_v1(
				sdk,
				control,
				commands,
				expected_command_sha256,
				recomputed_digest_receipt,
			),
		)
	if joint_by_actuator_id.size() != 8 or position_by_joint_id.size() != 8:
		return _failure("QSDK_R24D57_HOST_SURFACE_CARDINALITY_INVALID")

	var unique_instances: Dictionary = {}
	var preflight: Array = []
	for index in range(8):
		var command_value: Variant = commands[index]
		if not (command_value is Dictionary):
			return _failure("QSDK_R24D57_COMMAND_RECORD_INVALID")
		var command: Dictionary = command_value
		var actuator_id := String(command.get("actuator_id", ""))
		var joint_id := String(command.get("joint_id", ""))
		var target := float(command.get("target_position_rad", NAN))
		var maximum_speed := float(command.get("maximum_target_speed_rad_s", NAN))
		var cap := float(command.get("maximum_outer_step_impulse_nms", NAN))
		if (
			String(command.get("schema_version", "")) != "sporespore_recovery_control_command_v1"
			or actuator_id != ORDERED_ACTUATOR_IDS[index]
			or joint_id != ORDERED_JOINT_IDS[index]
			or String(command.get("mode", "")) != "position_velocity"
			or float(command.get("target_velocity_rad_s", NAN)) != 0.0
			or not is_finite(target)
			or not is_finite(maximum_speed)
			or maximum_speed <= 0.0
			or cap != float(ORDERED_CAPS_NMS[index])
			or not joint_by_actuator_id.has(actuator_id)
			or not position_by_joint_id.has(joint_id)
		):
			return _failure("QSDK_R24D57_COMMAND_IDENTITY_INVALID:%d" % index)
		var joint_value: Variant = joint_by_actuator_id[actuator_id]
		if not (joint_value is HingeJoint3D):
			return _failure("QSDK_R24D57_HOST_JOINT_TYPE_INVALID:%d" % index)
		var joint: HingeJoint3D = joint_value
		if require_zero_world and (joint.get_parent() != null or joint.is_inside_tree()):
			return _failure("QSDK_R24D57_ZERO_WORLD_JOINT_INSERTED:%d" % index)
		var instance_id := int(joint.get_instance_id())
		if unique_instances.has(instance_id):
			return _failure("QSDK_R24D57_HOST_JOINT_DUPLICATE:%d" % index)
		unique_instances[instance_id] = true
		var position := float(position_by_joint_id[joint_id])
		var host_cap_projection := (
			NativeWorldScript
			. native_effective_impulse_limit_projection_v1(
				actuator_id,
				cap,
			)
		)
		if not bool(host_cap_projection.get("ok", false)):
			return _failure(
				"QSDK_R24D69_NATIVE_EFFECTIVE_LIMIT_PROJECTION_INVALID:%d" % index,
				host_cap_projection,
			)
		var cap_readback := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
		if (
			not is_finite(position)
			or not is_finite(cap_readback)
			or cap_readback != float(host_cap_projection["configured_host_maximum_impulse_nms"])
			or cap_readback > cap
			or not bool(
				(
					host_cap_projection
					. get(
						"native_effective_limit_not_above_published",
						false,
					)
				)
			)
		):
			return _failure(
				"QSDK_R24D69_NATIVE_EFFECTIVE_LIMIT_OR_POSITION_INVALID:%d" % index,
				{
					"published_cap_nms": cap,
					"host_cap_readback_nms": cap_readback,
					"host_cap_projection": host_cap_projection,
				},
			)
		var canonical_velocity := clampf(
			(target - position) / OUTER_STEP_DURATION_S,
			-maximum_speed,
			maximum_speed,
		)
		var host_real_projection := godot_host_real_command_projection_v1(
			canonical_velocity,
			maximum_speed,
		)
		if not bool(host_real_projection.get("ok", false)):
			return _failure(
				"QSDK_R24D78_COMMAND_HOST_REAL_PROJECTION_INVALID:%d" % index,
				host_real_projection,
			)
		(
			preflight
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"joint": joint,
					"canonical_target_velocity_rad_s": canonical_velocity,
					"godot_target_velocity_rad_s":
					float(host_real_projection["godot_projected_target_velocity_rad_s"]),
					"host_real_command_projection": host_real_projection,
					"published_maximum_outer_step_impulse_nms": cap,
					"host_maximum_impulse_readback_nms": cap_readback,
					"host_cap_projection": host_cap_projection,
				}
			)
		)

	var ordered_receipts: Array = []
	for item_value in preflight:
		var item: Dictionary = item_value
		var joint: HingeJoint3D = item["joint"]
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
		(
			joint
			. set_param(
				HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
				float(item["godot_target_velocity_rad_s"]),
			)
		)
		var readback := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY))
		var readback_validation := validate_godot_host_real_command_readback_v1(
			item["host_real_command_projection"],
			readback,
		)
		if not bool(readback_validation.get("ok", false)):
			return _failure(
				"QSDK_R24D78_COMMAND_READBACK_INVALID:%d" % ordered_receipts.size(),
				readback_validation,
			)
		(
			ordered_receipts
			. append(
				{
					"actuator_id": String(item["actuator_id"]),
					"joint_id": String(item["joint_id"]),
					"canonical_target_velocity_rad_s":
					float(item["canonical_target_velocity_rad_s"]),
					"godot_target_velocity_rad_s": readback,
					"godot_unprojected_target_velocity_rad_s":
					float(
						(item["host_real_command_projection"] as Dictionary)["godot_unprojected_target_velocity_rad_s"]
					),
					"godot_projected_target_velocity_rad_s":
					float(
						(item["host_real_command_projection"] as Dictionary)["godot_projected_target_velocity_rad_s"]
					),
					"godot_host_readback_target_velocity_rad_s": readback,
					"host_real_command_projection":
					(item["host_real_command_projection"] as Dictionary).duplicate(true),
					"host_real_command_readback": readback_validation,
					"host_velocity_sign": LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN,
					"published_maximum_outer_step_impulse_nms":
					float(item["published_maximum_outer_step_impulse_nms"]),
					"host_maximum_impulse_readback_nms":
					float(item["host_maximum_impulse_readback_nms"]),
					"host_cap_projection":
					(item["host_cap_projection"] as Dictionary).duplicate(true),
				}
			)
		)
	var source_control_semantic_step := int(control.get("semantic_step", -1))
	var application_semantic_step := source_control_semantic_step + 1
	var phase := String(control.get("phase", ""))
	var command_sha256 := String(control.get("command_sha256", ""))
	if (
		source_control_semantic_step < 1
		or application_semantic_step < 2
		or phase.is_empty()
		or not command_sha256.begins_with("sha256:")
		or command_sha256.length() != 71
	):
		return _failure("QSDK_R24D57_APPLICATION_INTENT_IDENTITY_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_command_application_receipt_v1",
		"ok": true,
		"route_id": ROUTE_ID,
		"semantic_step": application_semantic_step,
		"source_control_semantic_step": source_control_semantic_step,
		"phase": phase,
		"command_id": "%s%d" % [command_id_prefix, application_semantic_step],
		"command_sha256": command_sha256,
		"zero_command": false,
		"motor_enabled_count": 8,
		"ordered_intents": ordered_receipts.duplicate(true),
		"controller_owner": controller_owner,
		"recovery_controller_id": recovery_controller_id,
		"stance_controller_id": stance_controller_id,
		"handoff_event_count": handoff_event_count,
		"fallback_controller_active": false,
		"validated_command_count": 8,
		"host_write_count": 8,
		"host_readback_count": 8,
		"ordered_receipts": ordered_receipts,
		"adapter_side_discrete_staging_event_count": 0,
		"root_actuation_count": 0,
		"fallback_control_count": 0,
		"engine_specific_policy_branch_count": 0,
		"zero_world_host_surface": require_zero_world,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _apply_no_actuation_control_v1(
	sdk: Object,
	control: Dictionary,
	joint_by_actuator_id: Dictionary,
	position_by_joint_id: Dictionary,
	require_zero_world: bool,
) -> Dictionary:
	if joint_by_actuator_id.size() != 8 or position_by_joint_id.size() != 8:
		return _failure("QSDK_R24D65_NO_ACTUATION_HOST_SURFACE_CARDINALITY_INVALID")
	var unique_instances: Dictionary = {}
	var ordered_intents: Array = []
	for index in range(8):
		var actuator_id := String(ORDERED_ACTUATOR_IDS[index])
		var joint_id := String(ORDERED_JOINT_IDS[index])
		if not joint_by_actuator_id.has(actuator_id) or not position_by_joint_id.has(joint_id):
			return _failure("QSDK_R24D65_NO_ACTUATION_HOST_IDENTITY_INVALID:%d" % index)
		var joint_value: Variant = joint_by_actuator_id[actuator_id]
		if not (joint_value is HingeJoint3D):
			return _failure("QSDK_R24D65_NO_ACTUATION_HOST_JOINT_INVALID:%d" % index)
		var joint: HingeJoint3D = joint_value
		if require_zero_world and (joint.get_parent() != null or joint.is_inside_tree()):
			return _failure("QSDK_R24D65_NO_ACTUATION_ZERO_WORLD_JOINT_INSERTED:%d" % index)
		var instance_id := int(joint.get_instance_id())
		if unique_instances.has(instance_id):
			return _failure("QSDK_R24D65_NO_ACTUATION_HOST_JOINT_DUPLICATE:%d" % index)
		unique_instances[instance_id] = true
		if not is_finite(float(position_by_joint_id[joint_id])):
			return _failure("QSDK_R24D65_NO_ACTUATION_POSITION_INVALID:%d" % index)
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		var enabled := joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		var velocity := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY))
		if enabled or velocity != 0.0:
			return _failure("QSDK_R24D65_NO_ACTUATION_READBACK_INVALID:%d" % index)
		(
			ordered_intents
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"motor_enabled": false,
					"host_target_velocity_rad_s": velocity,
				}
			)
		)
	var source_control_semantic_step := int(control.get("semantic_step", -1))
	var application_semantic_step := source_control_semantic_step + 1
	var phase := String(control.get("phase", ""))
	if source_control_semantic_step < 1 or application_semantic_step < 2 or phase.is_empty():
		return _failure("QSDK_R24D65_NO_ACTUATION_APPLICATION_IDENTITY_INVALID")
	var command_record := {
		"schema_version": "sporespore_qsdk_r24d65_godot_no_actuation_command_v1",
		"source_control_sha256": _sha256(sdk, control),
		"source_control_semantic_step": source_control_semantic_step,
		"application_semantic_step": application_semantic_step,
		"phase": phase,
		"arm_kind":
		(
			"matched_zero_command"
			if bool(control.get("matched_zero_command", false))
			else "candidate_command"
		),
		"ordered_intents": ordered_intents,
	}
	var command_sha256 := _sha256(sdk, command_record)
	if String(command_record["source_control_sha256"]).is_empty() or command_sha256.is_empty():
		return _failure("QSDK_R24D65_NO_ACTUATION_COMMAND_DIGEST_INVALID")
	var owner := String(control["owner"])
	return {
		"schema_version": "sporespore_qsdk_r24d65_godot_command_application_receipt_v1",
		"ok": true,
		"route_id": ROUTE_ID,
		"semantic_step": application_semantic_step,
		"source_control_semantic_step": source_control_semantic_step,
		"phase": phase,
		"command_id": "r24d65_godot_no_actuation_step_%d" % application_semantic_step,
		"command_sha256": command_sha256,
		"zero_command": bool(control["matched_zero_command"]),
		"motor_enabled_count": 0,
		"ordered_intents": ordered_intents.duplicate(true),
		"controller_owner": owner,
		"recovery_controller_id":
		String(control.get("controller_id", "")) if owner == "recovery" else null,
		"stance_controller_id": STANCE_CONTROLLER_ID if owner == "stance" else null,
		"handoff_event_count": 1 if owner == "stance" else 0,
		"fallback_controller_active": false,
		"validated_command_count": 0,
		"host_write_count": 8,
		"host_readback_count": 8,
		"ordered_receipts": ordered_intents.duplicate(true),
		"adapter_side_discrete_staging_event_count": 0,
		"root_actuation_count": 0,
		"fallback_control_count": 0,
		"engine_specific_policy_branch_count": 0,
		"zero_world_host_surface": require_zero_world,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Native-shaped synthetic fixture for route conformance only. The receipt that
## consumes it must retain native_runtime_observation_collection_executed=false.
static func zero_world_fixture_v1(sdk: Object, context: Dictionary) -> Dictionary:
	return _zero_world_fixture_for_controller_v1(sdk, context, RECOVERY_CONTROLLER_ID)


static func zero_world_fixture_v2(sdk: Object, context: Dictionary) -> Dictionary:
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	if recovery_controller_id != RECOVERY_CONTROLLER_V2_ID:
		return _failure("QSDK_R24D113_ZERO_WORLD_CONTROLLER_CONTEXT_INVALID")
	return _zero_world_fixture_for_controller_v1(sdk, context, recovery_controller_id)


static func zero_world_fixture_v3(sdk: Object, context: Dictionary) -> Dictionary:
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	if recovery_controller_id != RECOVERY_CONTROLLER_V3_ID:
		return _failure("QSDK_R24D117_ZERO_WORLD_CONTROLLER_CONTEXT_INVALID")
	return _zero_world_fixture_for_controller_v1(sdk, context, recovery_controller_id)


static func zero_world_fixture_v4(sdk: Object, context: Dictionary) -> Dictionary:
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	if recovery_controller_id != RECOVERY_CONTROLLER_V4_ID:
		return _failure("QSDK_R24D120_ZERO_WORLD_CONTROLLER_CONTEXT_INVALID")
	return _zero_world_fixture_for_controller_v1(sdk, context, recovery_controller_id)


static func zero_world_fixture_v5(sdk: Object, context: Dictionary) -> Dictionary:
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	if recovery_controller_id != RECOVERY_CONTROLLER_V5_ID:
		return _failure("QSDK_R24D123_ZERO_WORLD_CONTROLLER_CONTEXT_INVALID")
	return _zero_world_fixture_for_controller_v1(sdk, context, recovery_controller_id)


static func zero_world_fixture_v6(sdk: Object, context: Dictionary) -> Dictionary:
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	if recovery_controller_id != RECOVERY_CONTROLLER_V6_ID:
		return _failure("QSDK_R24D127_ZERO_WORLD_CONTROLLER_CONTEXT_INVALID")
	var realization_value: Variant = context.get("actuation_realization")
	if not (realization_value is Dictionary):
		return _failure("QSDK_R24D127_ACTUATION_REALIZATION_MISSING")
	var realization: Dictionary = realization_value
	if (
		(
			String(realization.get("actuation_realization_id", ""))
			!= R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		)
		or not bool(realization.get("native_contact_solver_coupled", false))
		or int(realization.get("pre_solver_direct_body_impulse_write_count", -1)) != 0
		or String(realization.get("energy_source_profile_id", "")) != ENERGY_MAPPING_PROFILE_ID
	):
		return _failure("QSDK_R24D127_ACTUATION_REALIZATION_INVALID")
	return _zero_world_fixture_for_controller_v1(sdk, context, recovery_controller_id)


static func zero_world_fixture_solver_coupled_complete_energy_v1(
	sdk: Object,
	context: Dictionary,
) -> Dictionary:
	var recovery_controller_id := _context_recovery_controller_id_v1(context)
	var realization_value: Variant = context.get("actuation_realization")
	if (
		recovery_controller_id != RECOVERY_CONTROLLER_V6_ID
		or not bool(context.get("complete_energy_profile_selected", false))
		or not bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		or not _solver_coupled_complete_energy_capability_binding_exact_v1(context)
		or not (realization_value is Dictionary)
	):
		return _failure("QSDK_R24D144_ZERO_WORLD_CONTEXT_INVALID")
	var realization: Dictionary = realization_value
	if (
		(
			String(realization.get("actuation_realization_id", ""))
			!= R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		)
		or not bool(realization.get("native_contact_solver_coupled", false))
		or bool(realization.get("native_joint_motors_disabled", true))
		or bool(realization.get("pre_solver_direct_body_impulse_realization", true))
		or (
			String(realization.get("energy_source_profile_id", ""))
			!= R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		)
		or (
			String(realization.get("actuator_mapping_id", ""))
			!= R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		)
		or String(realization.get("work_mapping_id", "")) != R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
		or String(realization.get("partition_rule_id", "")) != R144_PARTITION_RULE_ID
	):
		return _failure("QSDK_R24D144_ZERO_WORLD_REALIZATION_INVALID")
	return _zero_world_fixture_for_controller_v1(sdk, context, recovery_controller_id)


static func _zero_world_fixture_for_controller_v1(
	sdk: Object,
	context: Dictionary,
	recovery_controller_id: String,
) -> Dictionary:
	if not _registered_recovery_controller_id_v1(recovery_controller_id):
		return _failure("QSDK_R24D113_ZERO_WORLD_CONTROLLER_ID_INVALID")
	var capability_sha256 := String(context.get("capability_sha256", ""))
	var applied_component := {
		"schema_version": "sporespore_qsdk_r24d57_zero_world_applied_component_v1",
		"semantic_step": 1,
		"ordered_applied_impulses_nms": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	var command_component := {
		"schema_version": "sporespore_qsdk_r24d57_zero_world_prior_command_v1",
		"command_id": "r24d57_zero_world_candidate_prior_command_v1",
		"source_measurement": true,
	}
	var source_trace := {
		"schema_version": "sporespore_qsdk_r24d57_zero_world_source_trace_v1",
		"semantic_step": 1,
		"host_step_before": 0,
		"host_step_after": 1,
		"synthetic_zero_world_fixture": true,
	}
	var applied_sha256 := _sha256(sdk, applied_component)
	var command_sha256 := _sha256(sdk, command_component)
	var source_trace_sha256 := _sha256(sdk, source_trace)
	if applied_sha256.is_empty() or command_sha256.is_empty() or source_trace_sha256.is_empty():
		return _failure("QSDK_R24D57_ZERO_WORLD_FIXTURE_DIGEST_FAILED")

	var joints: Array = []
	for joint_id in ORDERED_JOINT_IDS:
		(
			joints
			. append(
				{
					"joint_id": String(joint_id),
					"position_rad": 0.0,
					"velocity_rad_s": 0.0,
					"anchor_error_m": 0.0,
					"validity": {"position": true, "velocity": true, "anchor_error": true},
				}
			)
		)
	var contacts: Array = []
	var foot_bearings: Array = []
	for contact_id in ORDERED_CONTACT_SITE_IDS:
		(
			contacts
			. append(
				{
					"contact_site_id": String(contact_id),
					"presence": true,
					"bears_support": true,
					"normal_load_n": null,
					"provenance":
					{
						"adapter_id": ADAPTER_ID,
						"engine_contact_ids": ["%s_zero_world_contact" % String(contact_id)],
						"aggregation_rule_id": "r24d57_godot_qualified_bearing_v1",
						"quality": "qualified_bearing",
					},
				}
			)
		)
		(
			foot_bearings
			. append(
				{
					"contact_site_id": String(contact_id),
					"bearing_normal_impulse_ns": 0.05,
					"ordinary_unilateral_contact": true,
					"source_measurement": true,
				}
			)
		)
	var clearances: Array = []
	for body_id_value in ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var torso := body_id == "torso"
		(
			clearances
			. append(
				{
					"adapter_id": ADAPTER_ID,
					"body_id": body_id,
					"nonfoot_contact_present": torso,
					"ventral_surface_contact": torso,
					"accumulated_nonfoot_normal_impulse_ns": 0.05 if torso else 0.0,
					"minimum_nonfoot_clearance_m": 0.0 if torso else 0.01,
					"engine_contact_ids": ["torso_zero_world_contact"] if torso else [],
					"classification_rule_id": "r24d57_godot_nonfoot_clearance_v1",
					"foot_site_contacts_excluded": true,
					"source_measurement": true,
				}
			)
		)
	var applied_impulses: Array = []
	for actuator_id in ORDERED_ACTUATOR_IDS:
		(
			applied_impulses
			. append(
				{
					"actuator_id": String(actuator_id),
					"applied_angular_impulse_nms": 0.0,
					"host_clamped": false,
				}
			)
		)
	var observation_base := {
		"task_id": TASK_ID,
		"semantics_id": SEMANTICS_ID,
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"semantic_step": 1,
		"outer_step_duration_s": OUTER_STEP_DURATION_S,
		"state":
		{
			"schema_version": "sporespore_state_frame_v1",
			"semantic_step": 1,
			"sample_time_s": OUTER_STEP_DURATION_S,
			"base_pose_world":
			{
				"position_m": {"x": 0.0, "y": 0.06, "z": 0.0},
				"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
			},
			"base_twist_world":
			{
				"linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
				"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
			},
			"ordered_joint_observations": joints,
			"ordered_contact_observations": contacts,
			"previous_applied_actuation": null,
			"gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
			"task_frame":
			{
				"origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
				"forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
				"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
				"up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
				"reference_yaw_rad": 0.0,
			},
			"adapter_capability_sha256": capability_sha256,
		},
		"center_of_mass":
		{
			"position_world_m": {"x": 0.0, "y": 0.06, "z": 0.0},
			"linear_velocity_world_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
			"source_measurement": true,
		},
		"ordered_foot_bearing_observations": foot_bearings,
		"ordered_body_clearance_observations": clearances,
		"applied_actuation":
		{
			"adapter_id": ADAPTER_ID,
			"adapter_receipt_sha256": applied_sha256,
			"source_semantic_step": 1,
			"command_id": "r24d57_zero_world_candidate_prior_command_v1",
			"command_sha256": command_sha256,
			"actuator_profile_id": ACTUATOR_PROFILE_ID,
			"actuator_profile_sha256": ACTUATOR_PROFILE_SHA256,
			"zero_command": false,
			"ordered_applied_impulses": applied_impulses,
			"source_measurement": true,
		},
		"external_interventions":
		{
			"root_force_application_count": 0,
			"root_torque_application_count": 0,
			"root_impulse_application_count": 0,
			"root_pose_write_count": 0,
			"root_velocity_write_count": 0,
			"pin_or_guide_constraint_count": 0,
			"hidden_body_actuation_count": 0,
			"pose_teleport_count": 0,
			"collision_disable_count": 0,
			"contact_relabel_count": 0,
			"gravity_mutation_count": 0,
			"time_scale_mutation_count": 0,
			"engine_specific_policy_branch_count": 0,
		},
		"controller_ownership":
		{
			"owner": "recovery",
			"recovery_controller_id": recovery_controller_id,
			"stance_controller_id": null,
			"handoff_event_count": 0,
			"fallback_controller_active": false,
			"source_measurement": true,
		},
		"engine_step_identity":
		{
			"schema_version": "sporespore_recovery_engine_step_identity_v1",
			"source_kind": "native_post_step",
			"adapter_id": ADAPTER_ID,
			"engine": ENGINE_ID,
			"capability_sha256": capability_sha256,
			"source_trace_sha256": source_trace_sha256,
			"semantic_step": 1,
			"host_step_before": 0,
			"host_step_after": 1,
			"native_solver_substep_count": 1,
			"post_step_observation": true,
			"engine_identity_exposed_to_policy": false,
		},
	}
	var energy_source_receipt := {
		"schema_version": "sporespore_qsdk_r24d57_godot_native_energy_source_receipt_v1",
		"semantic_step": 1,
		"initial_mechanical_energy_j": 20.0,
		"current_mechanical_energy_j": 20.0,
		"cumulative_applied_actuator_work_j": 0.0,
		"cumulative_signed_external_work_j": 0.0,
		"cumulative_signed_constraint_exchange_j": 0.0,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"cumulative_passive_dissipation_j": 0.0,
		"adapter_side_discrete_staging_event_count": 0,
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	var component_receipts := {
		"schema_version": "sporespore_qsdk_r24d57_godot_source_component_receipts_v1",
		"semantic_step": 1,
		"channel_count": 10,
		"applied_component": applied_component,
		"source_trace": source_trace,
		"source_measurement": true,
		"synthetic_zero_world_fixture": true,
	}
	return compose_observations_v1(
		sdk, context, observation_base, energy_source_receipt, component_receipts
	)


static func zero_world_command_surface_v1(context: Dictionary) -> Dictionary:
	var joint_by_actuator_id: Dictionary = {}
	var position_by_joint_id: Dictionary = {}
	var ordered_joints: Array[HingeJoint3D] = []
	for index in range(8):
		var joint := HingeJoint3D.new()
		joint.name = String(ORDERED_ACTUATOR_IDS[index])
		joint_by_actuator_id[ORDERED_ACTUATOR_IDS[index]] = joint
		position_by_joint_id[ORDERED_JOINT_IDS[index]] = 0.0
		ordered_joints.append(joint)
	var binding := (
		ActuatorBindingScript
		. new()
		. bind_profile(
			context["actuator_profile_resolution"],
			joint_by_actuator_id,
			ActuatorBindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS,
		)
	)
	if not bool(binding.get("ok", false)):
		for joint in ordered_joints:
			joint.free()
		return _failure("QSDK_R24D57_ZERO_WORLD_CAP_BINDING_FAILED", binding)
	var strict_host_cap_bindings: Array = []
	for index in range(8):
		var actuator_id := String(ORDERED_ACTUATOR_IDS[index])
		var published_cap := float(ORDERED_CAPS_NMS[index])
		var joint: HingeJoint3D = joint_by_actuator_id[actuator_id]
		var preguard_readback := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
		var projection := (
			NativeWorldScript
			. native_effective_impulse_limit_projection_v1(
				actuator_id,
				published_cap,
			)
		)
		if not bool(projection.get("ok", false)):
			for cleanup_joint in ordered_joints:
				cleanup_joint.free()
			return _failure(
				"QSDK_R24D69_ZERO_WORLD_NATIVE_EFFECTIVE_LIMIT_PROJECTION_FAILED",
				projection,
			)
		(
			joint
			. set_param(
				HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
				float(projection["configured_host_maximum_impulse_nms"]),
			)
		)
		var guarded_readback := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
		if (
			guarded_readback != float(projection["configured_host_maximum_impulse_nms"])
			or guarded_readback > published_cap
			or not bool(projection.get("native_effective_limit_not_above_published", false))
		):
			for cleanup_joint in ordered_joints:
				cleanup_joint.free()
			return _failure(
				"QSDK_R24D69_ZERO_WORLD_NATIVE_EFFECTIVE_LIMIT_READBACK_FAILED:%d" % index,
				{
					"projection": projection,
					"guarded_readback_nms": guarded_readback,
				},
			)
		var guarded_binding := projection.duplicate(true)
		guarded_binding["legacy_profile_binding_readback_nms"] = preguard_readback
		guarded_binding["guarded_host_readback_nms"] = guarded_readback
		strict_host_cap_bindings.append(guarded_binding)
	return {
		"ok": true,
		"joint_by_actuator_id": joint_by_actuator_id,
		"position_by_joint_id": position_by_joint_id,
		"ordered_joints": ordered_joints,
		"binding_receipt": binding,
		"strict_host_cap_guard_receipt":
		{
			"schema_version":
			"sporespore_qsdk_r24d69_godot_native_effective_limit_guard_receipt_v1",
			"projection_id": NativeWorldScript.NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_ID,
			"ordered_bindings": strict_host_cap_bindings,
			"validated_actuator_count": strict_host_cap_bindings.size(),
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
	}


static func free_zero_world_command_surface_v1(surface: Dictionary) -> void:
	for joint_value in surface.get("ordered_joints", []):
		if joint_value is HingeJoint3D:
			var joint: HingeJoint3D = joint_value
			if is_instance_valid(joint) and joint.get_parent() == null:
				joint.free()


static func _energy_source_complete(value: Dictionary) -> bool:
	var required := [
		"schema_version",
		"semantic_step",
		"initial_mechanical_energy_j",
		"current_mechanical_energy_j",
		"cumulative_applied_actuator_work_j",
		"cumulative_signed_external_work_j",
		"cumulative_signed_constraint_exchange_j",
		"cumulative_signed_discrete_staging_exchange_j",
		"cumulative_passive_dissipation_j",
		"adapter_side_discrete_staging_event_count",
		"source_measurement",
	]
	for key in required:
		if not value.has(key):
			return false
	if not bool(value.get("source_measurement", false)):
		return false
	for key in required.slice(2, 9):
		if not is_finite(float(value[key])):
			return false
	return int(value["adapter_side_discrete_staging_event_count"]) >= 0


static func _complete_energy_source_complete_v1(
	value: Dictionary,
	expected_schema_version: String = "sporespore_qsdk_r24d136_godot_complete_energy_source_receipt_v1",
) -> bool:
	if not _energy_source_complete(value):
		return false
	var required := [
		"step_signed_constraint_exchange_j",
		"step_position_constraint_potential_exchange_j",
		"solver_energy_exchange_receipt_sha256",
		"world_energy_configuration_receipt_sha256",
		"actuator_constraint_disjointness_receipt_sha256",
		"constraint_exchange_partition_complete",
		"passive_dissipation_partition_complete",
		"component_partition_complete",
		"exact_balance_safety_authority",
		"unclosed_energy_residual_preserved",
		"mechanical_energy_residual_used_as_work_source",
		"residual_balancing_permitted",
	]
	for key in required:
		if not value.has(key):
			return false
	for key in [
		"step_signed_constraint_exchange_j",
		"step_position_constraint_potential_exchange_j",
	]:
		if not is_finite(float(value[key])):
			return false
	for key in [
		"solver_energy_exchange_receipt_sha256",
		"world_energy_configuration_receipt_sha256",
		"actuator_constraint_disjointness_receipt_sha256",
	]:
		var digest := String(value[key])
		if not digest.begins_with("sha256:") or digest.length() != 71:
			return false
	return (
		String(value.get("schema_version", "")) == expected_schema_version
		and int(value.get("semantic_step", 0)) > 0
		and float(value["cumulative_signed_external_work_j"]) == 0.0
		and float(value["cumulative_signed_discrete_staging_exchange_j"]) == 0.0
		and float(value["cumulative_passive_dissipation_j"]) == 0.0
		and int(value["adapter_side_discrete_staging_event_count"]) == 0
		and bool(value["constraint_exchange_partition_complete"])
		and bool(value["passive_dissipation_partition_complete"])
		and bool(value["component_partition_complete"])
		and bool(value["exact_balance_safety_authority"])
		and not bool(value["unclosed_energy_residual_preserved"])
		and not bool(value["mechanical_energy_residual_used_as_work_source"])
		and not bool(value["residual_balancing_permitted"])
	)


static func _solver_coupled_complete_energy_source_complete_v1(
	value: Dictionary,
) -> bool:
	if not _complete_energy_source_complete_v1(
		value,
		"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_receipt_v1",
	):
		return false
	for key in [
		"solver_coupled_partition_receipt_sha256",
		"partition_rule_id",
		"raw_step_signed_solver_exchange_j",
		"step_actuator_work_j",
		"native_motor_work_subtracted_exactly_once",
		"motor_work_also_counted_as_constraint_exchange",
	]:
		if not value.has(key):
			return false
	var partition_digest := String(value["solver_coupled_partition_receipt_sha256"])
	return (
		partition_digest.begins_with("sha256:")
		and partition_digest.length() == 71
		and String(value["partition_rule_id"]) == R144_PARTITION_RULE_ID
		and is_finite(float(value["raw_step_signed_solver_exchange_j"]))
		and is_finite(float(value["step_actuator_work_j"]))
		and bool(value["native_motor_work_subtracted_exactly_once"])
		and not bool(value["motor_work_also_counted_as_constraint_exchange"])
	)


static func _sha256(sdk: Object, value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	var digest := String(receipt.get("sha256", ""))
	return digest if digest.begins_with("sha256:") and digest.length() == 71 else ""


## Retain the complete pre-write identity needed to diagnose a cross-language
## command-digest disagreement. This receipt does not guess which command is
## wrong: the portable control schema currently supplies only one population
## digest, so every decoded command and its independently recomputed digest is
## preserved for an exact successor comparison.
static func _command_digest_mismatch_diagnostic_v1(
	sdk: Object,
	control: Dictionary,
	commands: Array,
	expected_command_sha256: String,
	recomputed_digest_receipt: Dictionary,
) -> Dictionary:
	var command_diagnostics: Array = []
	for index in range(commands.size()):
		var command_value: Variant = commands[index]
		var command: Dictionary = command_value if command_value is Dictionary else {}
		var command_digest_receipt := RecoveryRuntimeScript.canonicalize(sdk, command_value)
		var numeric_binary64_le_hex := {}
		for field in [
			"target_position_rad",
			"target_velocity_rad_s",
			"maximum_target_speed_rad_s",
			"maximum_outer_step_impulse_nms",
		]:
			var value := float(command.get(field, NAN))
			numeric_binary64_le_hex[field] = (
				PackedFloat64Array([value]).to_byte_array().hex_encode()
			)
		(
			command_diagnostics
			. append(
				{
					"command_index": index,
					"actuator_id": String(command.get("actuator_id", "")),
					"joint_id": String(command.get("joint_id", "")),
					"recomputed_command_sha256": String(command_digest_receipt.get("sha256", "")),
					"recomputed_command_canonical_json":
					String(command_digest_receipt.get("canonical_json", "")),
					"numeric_binary64_little_endian_hex": numeric_binary64_le_hex,
					"decoded_command": command.duplicate(true),
				}
			)
		)
	return {
		"schema_version": "sporespore_qsdk_command_digest_mismatch_diagnostic_v1",
		"controller_id": String(control.get("controller_id", "")),
		"controller_owner": String(control.get("owner", "")),
		"phase": String(control.get("phase", "")),
		"phase_step": int(control.get("phase_step", -1)),
		"source_control_semantic_step": int(control.get("semantic_step", -1)),
		"application_semantic_step": int(control.get("semantic_step", -1)) + 1,
		"expected_command_sha256": expected_command_sha256,
		"recomputed_command_sha256": String(recomputed_digest_receipt.get("sha256", "")),
		"recomputed_population_canonical_json":
		String(recomputed_digest_receipt.get("canonical_json", "")),
		"ordered_command_count": commands.size(),
		"ordered_command_diagnostics": command_diagnostics,
		"offending_command_uniquely_identified": false,
		"reason_offending_command_not_unique":
		"portable_receipt_exposes_population_digest_without_per_command_source_digests",
		"host_write_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d57_godot_recovery_route_failure_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
