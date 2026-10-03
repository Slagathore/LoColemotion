class_name SporeQsdkR10fRecoveryNativeLocomotionFacadeV1
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=function-arguments-number
# gdlint: disable=max-file-lines
# gdlint: disable=max-returns

## BW5R-B authority over the already-live R172 recovery-native S169 body.
##
## This facade never constructs a body. It validates the recovery world's nine
## bodies and eight hinges, maps those exact Node instances to the established
## locomotion adapter, and owns one fresh portable controller session per
## walking segment. Reanchoring changes only controller task-frame memory; body
## transforms, velocities, solver state, and contact identity remain untouched.

const R10DGPrefix := preload("res://sdk/adapters/godot/gdscript/r10dg_development_seed_v1.gd")
const R10APPrefix := preload("res://sdk/adapters/godot/gdscript/r10ap_development_seed_v1.gd")
const R10AMPrefix := preload("res://sdk/adapters/godot/gdscript/r10am_development_seed_v1.gd")
const R10AJPrefix := preload("res://sdk/adapters/godot/gdscript/r10aj_development_seed_v1.gd")
const R10AIPrefix := preload("res://sdk/adapters/godot/gdscript/r10ai_development_seed_v1.gd")
const R10AGPrefix := preload("res://sdk/adapters/godot/gdscript/r10ag_development_seed_v1.gd")
const R10AFPrefix := preload("res://sdk/adapters/godot/gdscript/r10af_development_seed_v1.gd")
const R10AEPrefix := preload("res://sdk/adapters/godot/gdscript/r10ae_development_seed_v1.gd")
const R10ADPrefix := preload("res://sdk/adapters/godot/gdscript/r10ad_development_seed_v1.gd")
const R10ACPrefix := preload("res://sdk/adapters/godot/gdscript/r10ac_development_seed_v2.gd")
const R10XPrefix := preload("res://sdk/adapters/godot/gdscript/r10x_campaign_prefix_v1.gd")
const R10WPrefix := preload("res://sdk/adapters/godot/gdscript/r10w_campaign_prefix_v1.gd")
const RecoveryRoute := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const RecoveryWorld := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const SdkAdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const DevelopmentWalkingFrame := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_frame_v1.gd")
const DevelopmentWalkingStart := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_start_v1.gd")
const DevelopmentWalkingContacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_contacts_v1.gd")
const NativeWalkingContacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd")
var _development_contact_profile_id := ""
const DevelopmentWalkingPolicy := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_policy_v1.gd")
var _development_walking_policy_id := ""
const MaterialProfiles := preload("res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd")
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const CanonicalOwnershipL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd"
)

const GATE_ID := "QSDK-R10F"
const FACADE_ID := "sporespore_qsdk_r10f_recovery_native_s169_locomotion_facade_v1"
const CONFIGURATION_SCHEMA := "sporespore_qsdk_r10f_recovery_native_locomotion_configuration_v1"
const BINDING_SCHEMA := "sporespore_qsdk_r10f_recovery_native_locomotion_binding_v1"
const SAME_BODY_IDENTITY_SCHEMA := "sporespore_qsdk_r10f_same_body_node_identity_receipt_v1"
const SESSION_SCHEMA := "sporespore_qsdk_r10f_recovery_native_locomotion_session_v1"
const STEP_SCHEMA := "sporespore_qsdk_r10f_recovery_native_locomotion_step_v1"
const MOTOR_CONFIGURATION_SCHEMA := "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1"
const MOTOR_POPULATION_READBACK_SCHEMA := "sporespore_qsdk_r10f_recovery_native_motor_population_readback_v1"
const WALKING_HOST_CAP_BINDING_SCHEMA := "sporespore_qsdk_r10f_l12_walking_host_cap_projection_binding_v1"
const WALKING_ACTUATION_HANDOFF_SCHEMA := "sporespore_qsdk_r10f_l12_walking_actuation_handoff_receipt_v1"
const WALKING_LEDGER_APPLICATION_SCHEMA := "sporespore_qsdk_r10f_l12_bw5r_b_route_aware_discrete_staging_application_intent_v1"
const WALKING_LEDGER_APPLICATION_SCHEMA_V2 := "sporespore_qsdk_r10f_l13_bw5r_b_route_aware_discrete_staging_application_intent_v2"
const WALKING_HOST_TARGET_PROJECTION_SCHEMA := "sporespore_qsdk_r10f_godot_binary32_motor_target_projection_v1"
const WALKING_LEDGER_PREDICATE_RECEIPT_SCHEMA := "sporespore_qsdk_r10f_l13_walking_ledger_predicate_receipt_v1"
const NO_ACTUATION_LEDGER_APPLICATION_SCHEMA := "sporespore_qsdk_r10f_no_actuation_route_aware_discrete_staging_application_intent_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_recovery_native_locomotion_failure_v1"

const SELECTED_CANDIDATE_ID := "BW5R-B"
const SELECTED_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const SELECTED_POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
const SELECTED_CONTROLLER_RECEIPT_SCHEMA := "sporespore_controller_step_receipt_v2"
const MATERIAL_PROFILE_ID := MaterialProfiles.LEGACY_PROFILE_ID
const ACTUATOR_PROFILE_ID := RecoveryRoute.ACTUATOR_PROFILE_ID
const ACTUATOR_PROFILE_SHA256 := RecoveryRoute.ACTUATOR_PROFILE_SHA256
const BASE_DESCRIPTOR_SHA256 := RecoveryRoute.BASE_DESCRIPTOR_SHA256
const BASE_MORPHOLOGY_SPEC_SHA256 := RecoveryRoute.BASE_MORPHOLOGY_SPEC_SHA256
const RECOVERY_DESCRIPTOR_SHA256 := RecoveryRoute.RECOVERY_DESCRIPTOR_SHA256
const RECOVERY_MORPHOLOGY_SPEC_SHA256 := RecoveryRoute.RECOVERY_MORPHOLOGY_SPEC_SHA256
const RECOVERY_CONTROLLER_ID := RecoveryRoute.RECOVERY_CONTROLLER_V6_ID
const PHYSICS_HZ := 120
const SOLVER_POLICY := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const LIMB_ORDER := ["front_left", "front_right", "rear_left", "rear_right"]
const BODY_IDS := [
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
const JOINT_IDS := [
	"front_left_hip",
	"front_left_knee",
	"front_right_hip",
	"front_right_knee",
	"rear_left_hip",
	"rear_left_knee",
	"rear_right_hip",
	"rear_right_knee",
]
const SAME_BODY_NODE_IDENTITY := [
	"body:torso",
	"body:front_left_upper",
	"body:front_left_distal",
	"body:front_right_upper",
	"body:front_right_distal",
	"body:rear_left_upper",
	"body:rear_left_distal",
	"body:rear_right_upper",
	"body:rear_right_distal",
	"joint:front_left_hip",
	"joint:front_left_knee",
	"joint:front_right_hip",
	"joint:front_right_knee",
	"joint:rear_left_hip",
	"joint:rear_left_knee",
	"joint:rear_right_hip",
	"joint:rear_right_knee",
]
const WALKING_SEGMENT_IDS := ["walking_prefix", "walking_resume"]
const WALKING_EVALUATION_SEGMENT_IDS := ["walking_prefix", "matched_continuation", "walking_resume"]
const WALKING_HORIZON_STEPS := 720
const GAIT_CYCLE_STEPS := 360
const OUTCOME_DERIVED_KEYS := [
	"acceptance_threshold",
	"behavior_result",
	"energy_balance_residual_j",
	"physical_result",
	"recovery_success",
	"stable_stance_gate",
]
const WALKING_HOST_CAP_BINDING_KEYS := [
	"schema_version",
	"gate_id",
	"ok",
	"projection_id",
	"scope",
	"selection_rule",
	"ordered_actuator_ids",
	"ordered_published_caps_nms",
	"ordered_selected_host_caps_nms",
	"published_cap_by_actuator_id",
	"selected_host_cap_by_actuator_id",
	"ordered_projection_receipts",
	"projection_count",
	"selected_effective_limit_not_above_published_count",
	"immediately_higher_effective_limit_above_published_count",
	"binary32_maximality_proof_count",
	"published_cap_changed",
	"empirical_margin_added",
	"raw_measurement_clamped",
	"model_construction_count",
	"world_attempt_count",
	"world_build_count",
	"solver_step_count",
	"physics_state_modified",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const WALKING_ACTUATION_HANDOFF_KEYS := [
	"schema_version",
	"gate_id",
	"ok",
	"facade_id",
	"model_instance_id",
	"facade_segment_id",
	"evaluation_segment_id",
	"walking_session_id",
	"global_semantic_step",
	"selected_policy_id",
	"selected_policy_digest",
	"motor_configuration_receipt",
	"motor_configuration_receipt_sha256",
	"precommand_motor_population_readback",
	"precommand_motor_population_readback_sha256",
	"host_cap_projection_binding",
	"host_cap_projection_binding_sha256",
	"ordered_actuator_ids",
	"published_cap_by_actuator_id",
	"authorized_host_cap_by_actuator_id",
	"motor_enabled_count",
	"zero_target_velocity_count",
	"motor_configuration_write_count",
	"native_readback_count",
	"solver_step_count",
	"body_transform_write_count",
	"body_velocity_write_count",
	"body_impulse_write_count",
	"solver_reset_count",
	"physics_state_modified",
	"outcome_derived_correction",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const WALKING_HOST_TARGET_PROJECTION_KEYS := [
	"schema_version",
	"gate_id",
	"ok",
	"projection_rule",
	"projection_kind",
	"ordered_actuator_ids",
	"ordered_target_projections",
	"projection_count",
	"nonzero_controller_target_count",
	"controller_binary64_target_retained_separately",
	"expected_binary32_host_target_retained_separately",
	"application_readback_equals_projection_count",
	"population_readback_equals_projection_count",
	"application_population_readbacks_equal_count",
	"r69_host_cap_exact_count",
	"controller_command_rounded_before_write",
	"host_write_changed",
	"solver_input_changed",
	"empirical_margin_added",
	"tolerance_added",
	"raw_measurement_clamped",
	"outcome_derived_correction",
	"failed_predicate_ids",
	"model_construction_count",
	"world_attempt_count",
	"world_build_count",
	"solver_step_count",
	"physics_state_modified",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const WALKING_HOST_TARGET_PROJECTION_ROW_KEYS := [
	"actuator_id",
	"joint_id",
	"controller_binary64_target_velocity_rad_s",
	"expected_binary32_host_target_velocity_rad_s",
	"application_host_applied_binary64_target_velocity_rad_s",
	"application_motor_target_velocity_readback_rad_s",
	"population_motor_target_velocity_readback_rad_s",
	"published_cap_nms",
	"authorized_host_cap_nms",
	"application_declared_maximum_impulse_nms",
	"application_motor_maximum_impulse_readback_nms",
	"population_motor_maximum_impulse_readback_nms",
	"controller_request_finite",
	"binary32_projection_finite",
	"application_request_preserved_exactly",
	"application_readback_equals_projection_exactly",
	"population_readback_equals_projection_exactly",
	"application_population_readbacks_equal_exactly",
	"r69_host_cap_exact",
]

var _adapter: LabSdkGodotJoltAdapter
var _binding: Dictionary = {}
var _session_id := ""
var _segment_id := ""
var _global_start_step := -1
var _initial_gait_steps: Dictionary = {}
var _walking_actuation_handoff_receipt: Dictionary = {}
var _authorized_host_cap_by_actuator_id: Dictionary = {}
var _task_frame_origin_world := Vector3.ZERO
var _task_frame_forward_axis_world := Vector3.ZERO
var _task_frame_lateral_axis_world := Vector3.ZERO
var _task_frame_initial_yaw_rad := 0.0
var _started := false
var _shutdown := false


## Pure topology/configuration proof. The called recovery blueprint compiler is
## explicitly zero-world and returns JSON-safe declarations only.
static func configuration_receipt_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_LOCOMOTION_SDK_MISSING")
	var context := RecoveryRoute.prepare_complete_energy_context_v18(sdk, RECOVERY_CONTROLLER_ID)
	if (
		not bool(context.get("ok", false))
		or not RecoveryRoute.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
			sdk, context
		)
	):
		return _failure("QSDK_R10F_LOCOMOTION_RECOVERY_CONTEXT_INVALID")
	var blueprint := RecoveryRoute.native_world_blueprint_v1(sdk, context)
	if not _recovery_blueprint_exact_v1(blueprint):
		return _failure("QSDK_R10F_LOCOMOTION_RECOVERY_BLUEPRINT_INVALID")
	var material := MaterialProfiles.resolve(MATERIAL_PROFILE_ID)
	if not _material_profile_exact_v1(material):
		return _failure("QSDK_R10F_LOCOMOTION_MATERIAL_PROFILE_INVALID")
	var base_descriptor := RecoveryRoute.exact_base_descriptor_v1()
	var base_descriptor_sha256 := _sha256_v1(sdk, base_descriptor)
	var context_sha256 := _sha256_v1(sdk, context)
	var blueprint_sha256 := _sha256_v1(sdk, blueprint)
	if (
		base_descriptor_sha256 != BASE_DESCRIPTOR_SHA256
		or context_sha256.is_empty()
		or blueprint_sha256.is_empty()
	):
		return _failure("QSDK_R10F_LOCOMOTION_CONFIGURATION_DIGEST_INVALID")
	return {
		"schema_version": CONFIGURATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"facade_id": FACADE_ID,
		"selected_candidate_id": SELECTED_CANDIDATE_ID,
		"selected_policy_id": SELECTED_POLICY_ID,
		"selected_policy_digest": SELECTED_POLICY_DIGEST,
		"base_descriptor": base_descriptor,
		"base_descriptor_sha256": base_descriptor_sha256,
		"base_morphology_spec_sha256": BASE_MORPHOLOGY_SPEC_SHA256,
		"recovery_descriptor_sha256": RECOVERY_DESCRIPTOR_SHA256,
		"recovery_morphology_spec_sha256": RECOVERY_MORPHOLOGY_SPEC_SHA256,
		"actuator_profile_id": ACTUATOR_PROFILE_ID,
		"actuator_profile_sha256": ACTUATOR_PROFILE_SHA256,
		"material_profile_id": MATERIAL_PROFILE_ID,
		"material_profile_sha256": String(material["profile_sha256"]),
		"authored_friction": float((material["profile"] as Dictionary)["authored_friction"]),
		"physics_solver_policy": SOLVER_POLICY.duplicate(true),
		"recovery_context_sha256": context_sha256,
		"recovery_blueprint_sha256": blueprint_sha256,
		"ordered_same_body_node_ids": SAME_BODY_NODE_IDENTITY.duplicate(),
		"same_body_node_identity_count": SAME_BODY_NODE_IDENTITY.size(),
		"physical_body_population_created_once": true,
		"walking_fixture_label_only_wrap_permitted": false,
		"fresh_controller_session_per_walking_segment": true,
		"post_construction_transform_write_permitted": false,
		"post_construction_velocity_write_permitted": false,
		"solver_reset_permitted": false,
		"task_frame_memory_reanchor_permitted": true,
		"interaction_axes_bound_to_prefix_session_receipt": true,
		"walking_resume_uses_fresh_task_frame_receipt": true,
		"event_triggered_passive_recovery": true,
		"force_aware_recovery": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## A stronger zero-world preflight that actually opens and explicitly destroys
## one portable BW5R-B controller session. It still accepts no Node and cannot
## construct or step a physics world.
static func portable_session_preflight_v1(sdk: Object, gait_phase_seed: int, use_preloaded_native_runtime: bool = false, development_prefix_profile_id: String = "") -> Dictionary:
	var configuration := configuration_receipt_v1(sdk)
	if not bool(configuration.get("ok", false)):
		return configuration
	var material_result := MaterialProfiles.resolve(MATERIAL_PROFILE_ID)
	var adapter := SdkAdapterScript.new()
	var initial_gait_steps := initial_gait_steps_v1(gait_phase_seed, "walking_prefix", "", development_prefix_profile_id)
	if not development_prefix_profile_id.is_empty() and initial_gait_steps.is_empty():
		return _failure("R10AF_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == R10AFPrefix.PREFIX_PROFILE else "R10AE_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == R10AEPrefix.PREFIX_PROFILE else "R10AD_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == R10ADPrefix.PREFIX_PROFILE else "R10AB_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AB.PREFIX_PROFILE else "R10AA_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AA.PREFIX_PROFILE else "R10Z_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Z.PREFIX_PROFILE else "R10Y_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Y.PREFIX_PROFILE else "R10X_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == R10XPrefix.PREFIX_PROFILE else "R10W_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == R10WPrefix.PREFIX_PROFILE else "R10V_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10V.PREFIX_PROFILE else "R10U_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10U.PREFIX_PROFILE else "R10T_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10T.PREFIX_PROFILE else "R10S_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10S.PREFIX_PROFILE else "R10R_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10R.PREFIX_PROFILE else "R10Q_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Q.PREFIX_PROFILE else "R10O_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10O.PREFIX_PROFILE else "R10N_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10N.PREFIX_PROFILE else "R10M_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10M.PREFIX_PROFILE else "R10L_PREFIX_PHASE_SELECTION_INVALID" if development_prefix_profile_id == DevelopmentWalkingPolicy.R10L.PREFIX_PROFILE else "R10K_PREFIX_PHASE_SELECTION_INVALID")
	var started := (
		adapter
		. start(
			RecoveryRoute.exact_base_descriptor_v1(),
			initial_gait_steps,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			PHYSICS_HZ,
			SOLVER_POLICY.duplicate(true),
			SdkAdapterScript.DEFAULT_TOLERANCE,
			"contact_gated",
			true,
			0,
			-1,
			"post_settle_full",
			SdkAdapterScript.P5I3B_WEIGHT_SUPPORT_POLICY_ID,
			(material_result["profile"] as Dictionary).duplicate(true),
			SELECTED_POLICY_ID,
			-1.0, false, SdkAdapterScript.FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID,
			use_preloaded_native_runtime,
		)
	)
	if not bool(started.get("ok", false)):
		return _failure(
			"QSDK_R10F_LOCOMOTION_PORTABLE_SESSION_START_FAILED",
			{"adapter_failure_code": String(started.get("failure_code", ""))},
		)
	var compiled := adapter.compiled_morphology_for_conformance()
	var shutdown := adapter.shutdown()
	if (
		not bool(compiled.get("ok", false))
		or not bool(shutdown.get("ok", false))
		or int(compiled.get("world_build_count", -1)) != 0
		or int(shutdown.get("world_build_count", -1)) != 0
		or bool(shutdown.get("physics_state_modified", true))
	):
		return _failure("QSDK_R10F_LOCOMOTION_PORTABLE_SESSION_PREFLIGHT_INVALID")
	var manifest: Dictionary = compiled.get("adapter_manifest", {})
	var material_characterization: Dictionary = (
		(manifest.get("stability_v2", {}) as Dictionary).get("material_characterization", {})
	)
	if (
		String(manifest.get("controller_policy_id", "")) != SELECTED_POLICY_ID
		or (
			String(material_characterization.get("profile_sha256", ""))
			!= String(material_result.get("profile_sha256", ""))
		)
	):
		return _failure("QSDK_R10F_LOCOMOTION_PORTABLE_POLICY_CROSSED")
	return {
		"schema_version":
		"sporespore_qsdk_r10f_recovery_native_locomotion_portable_session_preflight_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"configuration": configuration,
		"initial_gait_steps": initial_gait_steps,
		"controller_policy_id": String(manifest["controller_policy_id"]),
		"controller_profile_sha256": String(started["controller_profile_sha256"]),
		"adapter_capability_sha256": String(started["adapter_capability_sha256"]),
		"material_profile_sha256": String(material_result["profile_sha256"]),
		"native_controller_session_create_count": 1,
		"native_controller_session_destroy_count":
		int(shutdown["native_controller_session_destroy_count"]),
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func initial_gait_steps_v1(gait_phase_seed: int, segment_id: String, development_start_profile_id: String = "", development_prefix_profile_id: String = "") -> Dictionary:
	var finite: Script = load("res://sdk/adapters/godot/gdscript/r10dh_campaign_context_v1.gd")
	if development_prefix_profile_id == finite.PREFIX:
		return finite.prefix_steps(gait_phase_seed) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	var discovery: Script = load("res://sdk/discovery/recovery_discovery_context_v1.gd")
	if development_prefix_profile_id == discovery.PREFIX:
		return discovery.prefix_steps(gait_phase_seed) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10DGPrefix.PREFIX_PROFILE:
		return R10DGPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10APPrefix.PREFIX_PROFILE:
		return R10APPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10AMPrefix.PREFIX_PROFILE:
		return R10AMPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10AJPrefix.PREFIX_PROFILE:
		return R10AJPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10AIPrefix.PREFIX_PROFILE:
		return R10AIPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10AGPrefix.PREFIX_PROFILE:
		return R10AGPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10AFPrefix.PREFIX_PROFILE:
		return R10AFPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10AEPrefix.PREFIX_PROFILE:
		return R10AEPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10ADPrefix.PREFIX_PROFILE:
		return R10ADPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10ACPrefix.PREFIX_PROFILE:
		return R10ACPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10XPrefix.PREFIX_PROFILE:
		return R10XPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if development_prefix_profile_id == R10WPrefix.PREFIX_PROFILE:
		return R10WPrefix.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id) if segment_id == "walking_prefix" and development_start_profile_id.is_empty() else {}
	if not development_prefix_profile_id.is_empty():
		if segment_id != "walking_prefix" or not development_start_profile_id.is_empty(): return {}
		return (DevelopmentWalkingPolicy.R10AB.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AB.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10AA.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AA.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10Z.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Z.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10Y.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AA.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10V.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Z.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10V.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Y.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10V.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10V.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10U.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10U.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10T.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10T.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10S.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10S.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10R.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10R.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10Q.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Q.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10O.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10O.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10N.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10N.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10M.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10M.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10L.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10L.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10K.prefix_gait_steps_v1(gait_phase_seed, development_prefix_profile_id))
	if gait_phase_seed < 0 or not WALKING_SEGMENT_IDS.has(segment_id):
		return {}
	if not development_start_profile_id.is_empty():
		return (DevelopmentWalkingStart.normal_initial_gait_steps_v1(development_start_profile_id)
			if segment_id == "walking_resume" else {})
	var common_phase := posmod(gait_phase_seed, GAIT_CYCLE_STEPS)
	return {
		"front_left": common_phase,
		"front_right": common_phase,
		"rear_left": common_phase,
		"rear_right": common_phase,
	}


## Physical binding: validate and retain references to the existing model only.
## No body or joint property is written here.
func bind_live_model_v1(model: Dictionary, model_instance_id: String) -> Dictionary:
	if _started or not _binding.is_empty():
		return _failure("QSDK_R10F_LOCOMOTION_MODEL_ALREADY_BOUND")
	if model_instance_id.is_empty():
		return _failure("QSDK_R10F_LOCOMOTION_MODEL_INSTANCE_ID_MISSING")
	var binding := _build_live_binding_v1(model, model_instance_id)
	if not bool(binding.get("ok", false)):
		return binding
	_binding = binding.duplicate(false)
	return binding


## Re-read only Godot Object identities for the already-bound population. This
## is deliberately not a native physics-state sample: it neither asks the
## solver for a body state nor touches a transform, velocity, contact, or
## motor. The content digest is the per-world population identity carried by
## the R10F orchestrator across every phase boundary.
func same_body_identity_receipt_v1(
	sdk: Object,
	global_semantic_step: int,
	phase: String,
) -> Dictionary:
	if sdk == null or _binding.is_empty() or global_semantic_step < 0 or phase.is_empty():
		return _failure("QSDK_R10F_SAME_BODY_IDENTITY_INPUT_INVALID")
	var initial_ids: Dictionary = _binding["instance_id_by_node_id"]
	var rows: Array = []
	for ordered_node_id_value in SAME_BODY_NODE_IDENTITY:
		var ordered_node_id := String(ordered_node_id_value)
		var node_value: Variant = null
		if ordered_node_id.begins_with("body:"):
			node_value = (_binding["body_nodes"] as Dictionary).get(ordered_node_id.substr(5))
		elif ordered_node_id.begins_with("joint:"):
			node_value = (_binding["joint_nodes"] as Dictionary).get(ordered_node_id.substr(6))
		else:
			return _failure("QSDK_R10F_SAME_BODY_IDENTITY_NODE_ID_INVALID")
		if not (node_value is Object) or not is_instance_valid(node_value):
			return _failure("QSDK_R10F_SAME_BODY_IDENTITY_NODE_MISSING:%s" % ordered_node_id)
		var initial_instance_id := int(initial_ids.get(ordered_node_id, -1))
		var current_instance_id := int((node_value as Object).get_instance_id())
		if initial_instance_id <= 0 or current_instance_id != initial_instance_id:
			return _failure("QSDK_R10F_SAME_BODY_IDENTITY_CHANGED:%s" % ordered_node_id)
		(
			rows
			. append(
				{
					"ordered_node_id": ordered_node_id,
					"initial_instance_id": initial_instance_id,
					"current_instance_id": current_instance_id,
					"same_instance": true,
				}
			)
		)
	var identity_payload := {
		"schema_version": "sporespore_qsdk_r10f_same_body_population_identity_v1",
		"gate_id": GATE_ID,
		"facade_id": FACADE_ID,
		"model_instance_id": String(_binding["model_instance_id"]),
		"ordered_same_body_node_ids": SAME_BODY_NODE_IDENTITY.duplicate(),
		"ordered_node_identity_rows": rows,
		"same_body_node_identity_count": rows.size(),
		"body_population_rebuilt": false,
		"joint_population_rebuilt": false,
	}
	var population_sha256 := _sha256_v1(sdk, identity_payload)
	if population_sha256.is_empty():
		return _failure("QSDK_R10F_SAME_BODY_IDENTITY_DIGEST_INVALID")
	var receipt := {
		"schema_version": SAME_BODY_IDENTITY_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"facade_id": FACADE_ID,
		"model_instance_id": String(_binding["model_instance_id"]),
		"global_semantic_step": global_semantic_step,
		"phase": phase,
		"ordered_same_body_node_ids": SAME_BODY_NODE_IDENTITY.duplicate(),
		"ordered_node_identity_rows": rows,
		"same_body_node_identity_count": rows.size(),
		"body_population_instance_sha256": population_sha256,
		"population_identity_payload": identity_payload,
		"body_population_rebuilt": false,
		"joint_population_rebuilt": false,
		"node_identity_read_count": rows.size(),
		"native_readback_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _sha256_v1(sdk, receipt)
	if not _digest_valid_v1(String(receipt["payload_sha256"])):
		return _failure("QSDK_R10F_SAME_BODY_IDENTITY_RECEIPT_DIGEST_INVALID")
	return receipt


func start_walking_session_v1(
	segment_id: String,
	session_id: String,
	gait_phase_seed: int,
	global_start_step: int,
	use_preloaded_native_runtime: bool = false,
	development_frame_id: String = "",
	development_contact_profile_id: String = "",
	development_start_profile_id: String = "",
	development_policy_id: String = "",
	development_prefix_profile_id: String = "",
) -> Dictionary:
	var policy := DevelopmentWalkingPolicy.binding_v1(development_policy_id, segment_id)
	if policy.is_empty():
		return _failure("DEVELOPMENT_WALKING_POLICY_SELECTION")
	if _started or _shutdown:
		return _failure("QSDK_R10F_LOCOMOTION_SESSION_LIFECYCLE_INVALID")
	if _binding.is_empty():
		return _failure("QSDK_R10F_LOCOMOTION_MODEL_NOT_BOUND")
	if (
		not WALKING_SEGMENT_IDS.has(segment_id)
		or session_id.is_empty()
		or gait_phase_seed < 0
		or global_start_step < 0
	):
		return _failure("QSDK_R10F_LOCOMOTION_SESSION_INPUT_INVALID")
	var material_result := MaterialProfiles.resolve(MATERIAL_PROFILE_ID)
	if not _material_profile_exact_v1(material_result):
		return _failure("QSDK_R10F_LOCOMOTION_SESSION_MATERIAL_INVALID")
	var shape_id := String(DevelopmentWalkingContacts._contract["profile_id"]) if NativeWalkingContacts.selected_v1(development_contact_profile_id) else development_contact_profile_id
	var contact_binding := DevelopmentWalkingContacts.bind_v1(_binding, shape_id)
	if contact_binding.get("ok") != true:
		return contact_binding
	var torso: RigidBody3D = _binding["torso"]
	var frame := DevelopmentWalkingFrame.frame_v1(torso.global_basis, segment_id, development_frame_id)
	if not bool(frame.get("ok", false)):
		return frame
	var lateral_axis_world: Vector3 = frame["lateral"]
	var forward_axis_world: Vector3 = frame["forward"]
	var initial_yaw_rad: float = frame["legacy_yaw_rad"]
	var gait_steps := (DevelopmentWalkingPolicy.R10AP.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AP.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10AM.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AM.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10AJ.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AJ.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10AI.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AI.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10AG.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AG.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10AB.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AB.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10AA.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10Z.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10Y.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10V.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10V.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10Y.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10V.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10V.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10U.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10U.POST_HOLD_ALIAS else DevelopmentWalkingPolicy.R10T.post_hold_gait_steps_v1(segment_id, development_start_profile_id, development_prefix_profile_id)
		if development_policy_id == DevelopmentWalkingPolicy.R10T.POST_HOLD_ALIAS
		else initial_gait_steps_v1(gait_phase_seed, segment_id, development_start_profile_id, development_prefix_profile_id))
	if gait_steps.is_empty():
		return _failure("QSDK_R10F_LOCOMOTION_SESSION_START_PROFILE_INVALID")
	var started := _start_adapter_from_frame_v1(frame, torso.global_position, gait_steps,
		material_result["profile"], use_preloaded_native_runtime, development_policy_id, segment_id)
	if not bool(started.get("ok", false)):
		_adapter = null
		return _failure(
			"QSDK_R10F_LOCOMOTION_SESSION_START_FAILED",
			{"adapter_failure_code": String(started.get("failure_code", ""))},
		)
	_started = true
	_development_walking_policy_id = development_policy_id
	_development_contact_profile_id = development_contact_profile_id
	_session_id = session_id
	_segment_id = segment_id
	_global_start_step = global_start_step
	_initial_gait_steps = gait_steps.duplicate(true)
	_walking_actuation_handoff_receipt = {}
	_authorized_host_cap_by_actuator_id = {}
	_task_frame_origin_world = torso.global_position
	_task_frame_forward_axis_world = forward_axis_world
	_task_frame_lateral_axis_world = lateral_axis_world
	_task_frame_initial_yaw_rad = initial_yaw_rad
	var receipt := {
		"schema_version": DevelopmentWalkingPolicy.schema_v1(SESSION_SCHEMA, "session", policy),
		"gate_id": GATE_ID,
		"ok": true,
		"facade_id": FACADE_ID,
		"model_instance_id": String(_binding["model_instance_id"]),
		"segment_id": segment_id,
		"session_id": session_id,
		"global_start_step": global_start_step,
		"initial_gait_steps": gait_steps,
		"selected_policy_id": policy["policy_id"],
		"task_frame_reanchored_in_controller_memory": true,
		"task_frame_origin_world_m": _vector3_array_v1(_task_frame_origin_world),
		"task_frame_forward_axis_world_host_real":
		_vector3_array_v1(_task_frame_forward_axis_world),
		"task_frame_lateral_axis_world_host_real":
		_vector3_array_v1(_task_frame_lateral_axis_world),
		"task_frame_initial_yaw_rad": _task_frame_initial_yaw_rad,
		"task_frame_frozen_for_walking_segment": true,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not development_prefix_profile_id.is_empty():
		receipt["development_prefix_phase_selection"] = (R10DGPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10DGPrefix.PREFIX_PROFILE else R10APPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10APPrefix.PREFIX_PROFILE else R10AMPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10AMPrefix.PREFIX_PROFILE else R10AJPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10AJPrefix.PREFIX_PROFILE else R10AIPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10AIPrefix.PREFIX_PROFILE else R10AGPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10AGPrefix.PREFIX_PROFILE else R10AFPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10AFPrefix.PREFIX_PROFILE else R10AEPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10AEPrefix.PREFIX_PROFILE else R10ADPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10ADPrefix.PREFIX_PROFILE else R10ACPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10ACPrefix.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10AB.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AB.PREFIX_PROFILE else R10XPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10XPrefix.PREFIX_PROFILE else R10WPrefix.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10WPrefix.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10AB.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10WPrefix.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10AA.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10WPrefix.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10AB.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == R10WPrefix.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10AA.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AA.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10Z.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Z.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10Y.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10AA.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10V.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Z.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10V.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Y.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10V.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10V.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10U.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10U.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10T.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10T.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10S.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10S.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10R.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10R.PREFIX_PROFILE else DevelopmentWalkingPolicy.R10Q.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10Q.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10O.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10O.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10N.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10N.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10M.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10M.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10L.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id)
			if development_prefix_profile_id == DevelopmentWalkingPolicy.R10L.PREFIX_PROFILE
			else DevelopmentWalkingPolicy.R10K.prefix_selection_v1(gait_phase_seed, development_prefix_profile_id))
	if not development_start_profile_id.is_empty():
		receipt["development_walking_start_profile_id"] = development_start_profile_id
		receipt["gait_phase_seed"] = gait_phase_seed
	if not development_frame_id.is_empty():
		receipt["development_walking_frame_id"] = development_frame_id
	if not development_contact_profile_id.is_empty():
		receipt["development_walking_contact_profile_id"] = development_contact_profile_id
	if policy["development"]:
		receipt["development_walking_policy_id"] = development_policy_id
		receipt["selected_policy_digest"] = policy["policy_digest"]
		receipt["controller_profile_sha256"] = started["controller_profile_sha256"]
	if DevelopmentWalkingPolicy.floor_selected_v1(development_policy_id):
		receipt["development_floor_source"] = _adapter._development_floor_source.duplicate(true)
	return receipt


## Actual adapter-start boundary, also callable by zero-world integration tests.
## No body or dummy world is needed to exercise the real compiled controller.
func _start_adapter_from_frame_v1(frame: Dictionary, origin: Vector3, gait_steps: Dictionary,
	material_profile: Dictionary, use_preloaded_native_runtime: bool,
	development_policy_id: String = "", evaluation_segment_id: String = "walking_resume") -> Dictionary:
	var policy := DevelopmentWalkingPolicy.binding_v1(development_policy_id, evaluation_segment_id)
	if policy.is_empty():
		return _failure("DEVELOPMENT_WALKING_POLICY_SELECTION")
	if development_policy_id == DevelopmentWalkingPolicy.R10AP.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10AP.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10AP_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10AM.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10AM.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10AM_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10AJ.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10AJ.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10AJ_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10AI.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10AI.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10AI_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10AG.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10AG.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10AG_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10AB.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10AB.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10AB_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10AA.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10AA_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10Z.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10Z_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10Y.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10Y.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10Y_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10V.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10V.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10V_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10U.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10U.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10U_POST_HOLD_INITIAL_GAIT_STEPS")
	if development_policy_id == DevelopmentWalkingPolicy.R10T.POST_HOLD_ALIAS and gait_steps != DevelopmentWalkingPolicy.R10T.post_hold_gait_steps_v1("walking_resume", "", ""):
		return _failure("R10T_POST_HOLD_INITIAL_GAIT_STEPS")
	_adapter = SdkAdapterScript.new()
	var started := _adapter.start(RecoveryRoute.exact_base_descriptor_v1(), gait_steps, 0.0,
		origin, frame["lateral"], frame["legacy_yaw_rad"], PHYSICS_HZ,
		SOLVER_POLICY.duplicate(true), SdkAdapterScript.DEFAULT_TOLERANCE,
		"contact_gated", true, 0, -1, "post_settle_full",
		SdkAdapterScript.P5I3B_WEIGHT_SUPPORT_POLICY_ID, material_profile.duplicate(true),
		policy["policy_id"], -1.0, false,
		SdkAdapterScript.FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID, use_preloaded_native_runtime)
	if started.get("ok") == true and development_policy_id in [DevelopmentWalkingPolicy.R10AP.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10AM.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10AJ.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10AP.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AM.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AJ.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AP.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AM.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AJ.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AI.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10AG.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10AI.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AG.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AI.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AG.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.NEUTRAL_ID, DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.HOLD_ALIAS, DevelopmentWalkingPolicy.R10K.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10K.HOLD_ALIAS, DevelopmentWalkingPolicy.R10L.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10M.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10N.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10O.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10Q.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10R.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10S.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10T.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10U.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10L.HOLD_ALIAS, DevelopmentWalkingPolicy.R10M.HOLD_ALIAS, DevelopmentWalkingPolicy.R10N.HOLD_ALIAS, DevelopmentWalkingPolicy.R10O.HOLD_ALIAS, DevelopmentWalkingPolicy.R10Q.HOLD_ALIAS, DevelopmentWalkingPolicy.R10R.HOLD_ALIAS, DevelopmentWalkingPolicy.R10S.HOLD_ALIAS, DevelopmentWalkingPolicy.R10T.HOLD_ALIAS, DevelopmentWalkingPolicy.R10U.HOLD_ALIAS, DevelopmentWalkingPolicy.R10T.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10U.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10V.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10V.HOLD_ALIAS, DevelopmentWalkingPolicy.R10V.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10Y.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10Z.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10Y.HOLD_ALIAS, DevelopmentWalkingPolicy.R10Z.HOLD_ALIAS, DevelopmentWalkingPolicy.R10Y.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AA.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10AA.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AB.ENTRY_ALIAS, DevelopmentWalkingPolicy.R10AB.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AB.POST_HOLD_ALIAS]:
		# Keep the selected lateral direction. Normalizing its binary32 cross
		# product a second time can destroy orthogonality at the core's 1e-9
		# tolerance. Swap/sign the same components; serialization normalizes
		# both axes in binary64 with the same norm. Historical starts stay exact.
		var lateral: Vector3 = _adapter._initial_lateral_axis_world
		_adapter._initial_forward_axis_world = Vector3(lateral.z, 0.0, -lateral.x)
	if started.get("ok") == true and policy["development"]:
		var legacy := _adapter._call_input("balanced_wave_policy_profile_json", {
			"schema_version": "sporespore_balanced_wave_policy_profile_request_v1",
			"policy_id": SELECTED_POLICY_ID, "descriptor": RecoveryRoute.exact_base_descriptor_v1()})
		if legacy.get("ok") != true or not DevelopmentWalkingPolicy.native_profile_valid_v1(_adapter._controller_profile, legacy.get("value", {}), development_policy_id, _adapter._api):
			_adapter.shutdown()
			return _failure("DEVELOPMENT_WALKING_POLICY_NATIVE_PROFILE_CROSSED")
	if started.get("ok") == true and DevelopmentWalkingPolicy.floor_selected_v1(development_policy_id):
		var floor_bound := _bind_current_floor_v1()
		if floor_bound.get("ok") != true:
			_adapter.shutdown()
			return floor_bound
	_adapter._development_native_step_failure_retention_enabled = started.get("ok") == true and (policy["development"] or development_policy_id in [DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.NEUTRAL_ID, DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID])
	# R10J hold: every command is stationary, including the first one before any anchored memory exists.
	_adapter._development_stationary_hold = started.get("ok") == true and development_policy_id in [DevelopmentWalkingPolicy.R10AP.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AM.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AJ.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AP.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AM.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AJ.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AI.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AG.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AI.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AG.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.HOLD_ALIAS, DevelopmentWalkingPolicy.R10K.HOLD_ALIAS, DevelopmentWalkingPolicy.R10L.HOLD_ALIAS, DevelopmentWalkingPolicy.R10M.HOLD_ALIAS, DevelopmentWalkingPolicy.R10N.HOLD_ALIAS, DevelopmentWalkingPolicy.R10O.HOLD_ALIAS, DevelopmentWalkingPolicy.R10Q.HOLD_ALIAS, DevelopmentWalkingPolicy.R10R.HOLD_ALIAS, DevelopmentWalkingPolicy.R10S.HOLD_ALIAS, DevelopmentWalkingPolicy.R10T.HOLD_ALIAS, DevelopmentWalkingPolicy.R10U.HOLD_ALIAS, DevelopmentWalkingPolicy.R10T.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10U.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10V.HOLD_ALIAS, DevelopmentWalkingPolicy.R10V.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10Y.HOLD_ALIAS, DevelopmentWalkingPolicy.R10Z.HOLD_ALIAS, DevelopmentWalkingPolicy.R10Y.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AA.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS, DevelopmentWalkingPolicy.R10AB.HOLD_ALIAS, DevelopmentWalkingPolicy.R10AB.POST_HOLD_ALIAS]
	return started


static func neutral_task_frame_axes_v1(initial_lateral: Vector3) -> Dictionary:
	# Reconstruct the actual selected adapter start for the independent reader.
	var lateral := initial_lateral
	lateral.y = 0.0
	lateral = lateral.normalized()
	return {"forward_axis_world_unit": SdkAdapterScript._unit_vector_dictionary_binary64(Vector3(lateral.z, 0.0, -lateral.x)),
		"lateral_axis_world_unit": SdkAdapterScript._unit_vector_dictionary_binary64(lateral),
		"up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0}}


## Pure binding of the unchanged published actuator profile to the exact R69
## binary32 values already configured on the recovery-native Godot hinges.
## Every projection is recomputed from source algebra; no live measurement or
## behavior outcome selects a cap here.
static func walking_host_cap_projection_binding_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_L12_HOST_CAP_SDK_MISSING")
	var ordered_actuator_ids: Array = RecoveryWorld.ORDERED_ACTUATOR_IDS.duplicate()
	var ordered_published_caps: Array = RecoveryWorld.ORDERED_PUBLISHED_CAPS_NMS.duplicate()
	if (
		ordered_actuator_ids != RecoveryRoute.ORDERED_ACTUATOR_IDS
		or ordered_actuator_ids.size() != JOINT_IDS.size()
		or ordered_published_caps.size() != JOINT_IDS.size()
	):
		return _failure("QSDK_R10F_L12_HOST_CAP_PROFILE_IDENTITY_INVALID")
	var ordered_selected_host_caps: Array = []
	var published_cap_by_actuator_id: Dictionary = {}
	var selected_host_cap_by_actuator_id: Dictionary = {}
	var ordered_projections: Array = []
	for index in range(ordered_actuator_ids.size()):
		var actuator_id := String(ordered_actuator_ids[index])
		var published_cap := float(ordered_published_caps[index])
		var projection := (
			RecoveryWorld
			. native_effective_impulse_limit_projection_v1(
				actuator_id,
				published_cap,
			)
		)
		if not bool(projection.get("ok", false)):
			return _failure(
				"QSDK_R10F_L12_HOST_CAP_PROJECTION_INVALID:%s" % actuator_id,
				{"projection": projection},
			)
		var selected_host_cap := float(projection.get("configured_host_maximum_impulse_nms", NAN))
		if (
			(
				String(projection.get("projection_id", ""))
				!= RecoveryWorld.NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_ID
			)
			or (
				String(projection.get("scope", ""))
				!= "exact_s169_published_actuator_profile_at_120_hz_only"
			)
			or String(projection.get("actuator_id", "")) != actuator_id
			or int(projection.get("actuator_index", -1)) != index
			or (
				float(projection.get("published_maximum_outer_step_impulse_nms", NAN))
				!= published_cap
			)
			or not is_finite(selected_host_cap)
			or selected_host_cap <= 0.0
			or selected_host_cap > published_cap
			or not bool(projection.get("native_effective_limit_not_above_published", false))
			or not bool(projection.get("next_native_effective_limit_above_published", false))
			or int(projection.get("configured_to_next_binary32_ulp_distance", -1)) != 1
			or bool(projection.get("published_cap_changed", true))
			or bool(projection.get("empirical_margin_added", true))
			or bool(projection.get("measurement_clamped", true))
		):
			return _failure("QSDK_R10F_L12_HOST_CAP_PROJECTION_FIELDS_INVALID:%s" % actuator_id)
		ordered_selected_host_caps.append(selected_host_cap)
		published_cap_by_actuator_id[actuator_id] = published_cap
		selected_host_cap_by_actuator_id[actuator_id] = selected_host_cap
		ordered_projections.append(projection.duplicate(true))
	var receipt := {
		"schema_version": WALKING_HOST_CAP_BINDING_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"projection_id": RecoveryWorld.NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_ID,
		"scope": "exact_s169_published_actuator_profile_at_120_hz_only",
		"selection_rule":
		"greatest_binary32_host_input_whose_complete_native_effective_impulse_projection_is_not_above_the_unchanged_published_cap",
		"ordered_actuator_ids": ordered_actuator_ids,
		"ordered_published_caps_nms": ordered_published_caps,
		"ordered_selected_host_caps_nms": ordered_selected_host_caps,
		"published_cap_by_actuator_id": published_cap_by_actuator_id,
		"selected_host_cap_by_actuator_id": selected_host_cap_by_actuator_id,
		"ordered_projection_receipts": ordered_projections,
		"projection_count": ordered_projections.size(),
		"selected_effective_limit_not_above_published_count": ordered_projections.size(),
		"immediately_higher_effective_limit_above_published_count": ordered_projections.size(),
		"binary32_maximality_proof_count": ordered_projections.size(),
		"published_cap_changed": false,
		"empirical_margin_added": false,
		"raw_measurement_clamped": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _sha256_v1(sdk, receipt)
	if not walking_host_cap_projection_binding_valid_v1(sdk, receipt):
		return _failure("QSDK_R10F_L12_HOST_CAP_BINDING_INVALID")
	return receipt


static func walking_host_cap_projection_binding_valid_v1(
	sdk: Object,
	receipt: Dictionary,
) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(receipt, WALKING_HOST_CAP_BINDING_KEYS)
		or String(receipt.get("schema_version", "")) != WALKING_HOST_CAP_BINDING_SCHEMA
		or String(receipt.get("gate_id", "")) != GATE_ID
		or not bool(receipt.get("ok", false))
		or (
			String(receipt.get("projection_id", ""))
			!= RecoveryWorld.NATIVE_EFFECTIVE_IMPULSE_LIMIT_PROJECTION_ID
		)
		or (
			String(receipt.get("scope", ""))
			!= "exact_s169_published_actuator_profile_at_120_hz_only"
		)
		or (
			String(receipt.get("selection_rule", ""))
			!= "greatest_binary32_host_input_whose_complete_native_effective_impulse_projection_is_not_above_the_unchanged_published_cap"
		)
		or receipt.get("ordered_actuator_ids") != RecoveryWorld.ORDERED_ACTUATOR_IDS
		or receipt.get("ordered_published_caps_nms") != RecoveryWorld.ORDERED_PUBLISHED_CAPS_NMS
		or not (receipt.get("ordered_selected_host_caps_nms") is Array)
		or not (receipt.get("published_cap_by_actuator_id") is Dictionary)
		or not (receipt.get("selected_host_cap_by_actuator_id") is Dictionary)
		or not (receipt.get("ordered_projection_receipts") is Array)
		or int(receipt.get("projection_count", -1)) != JOINT_IDS.size()
		or (
			int(receipt.get("selected_effective_limit_not_above_published_count", -1))
			!= JOINT_IDS.size()
		)
		or (
			int(receipt.get("immediately_higher_effective_limit_above_published_count", -1))
			!= JOINT_IDS.size()
		)
		or int(receipt.get("binary32_maximality_proof_count", -1)) != JOINT_IDS.size()
		or bool(receipt.get("published_cap_changed", true))
		or bool(receipt.get("empirical_margin_added", true))
		or bool(receipt.get("raw_measurement_clamped", true))
		or int(receipt.get("model_construction_count", -1)) != 0
		or int(receipt.get("world_attempt_count", -1)) != 0
		or int(receipt.get("world_build_count", -1)) != 0
		or int(receipt.get("solver_step_count", -1)) != 0
		or bool(receipt.get("physics_state_modified", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	var selected_caps: Array = receipt["ordered_selected_host_caps_nms"]
	var published_map: Dictionary = receipt["published_cap_by_actuator_id"]
	var selected_map: Dictionary = receipt["selected_host_cap_by_actuator_id"]
	var projections: Array = receipt["ordered_projection_receipts"]
	if (
		selected_caps.size() != JOINT_IDS.size()
		or published_map.size() != JOINT_IDS.size()
		or selected_map.size() != JOINT_IDS.size()
		or projections.size() != JOINT_IDS.size()
	):
		return false
	for index in range(JOINT_IDS.size()):
		var actuator_id := String(RecoveryWorld.ORDERED_ACTUATOR_IDS[index])
		var published_cap := float(RecoveryWorld.ORDERED_PUBLISHED_CAPS_NMS[index])
		if not (projections[index] is Dictionary):
			return false
		var expected := (
			RecoveryWorld
			. native_effective_impulse_limit_projection_v1(
				actuator_id,
				published_cap,
			)
		)
		if (
			not bool(expected.get("ok", false))
			or projections[index] != expected
			or not published_map.has(actuator_id)
			or not selected_map.has(actuator_id)
			or float(published_map[actuator_id]) != published_cap
			or float(selected_caps[index]) != float(expected["configured_host_maximum_impulse_nms"])
			or (
				float(selected_map[actuator_id])
				!= float(expected["configured_host_maximum_impulse_nms"])
			)
		):
			return false
	var payload := receipt.duplicate(true)
	payload["payload_sha256"] = ""
	return (
		_digest_valid_v1(String(receipt.get("payload_sha256", "")))
		and _sha256_v1(sdk, payload) == String(receipt["payload_sha256"])
	)


## Pure receipt composer used by both the live handoff and zero-world
## real-shaped fixtures. The configuration and readback are already-observed
## host operations; this function only validates, binds, and hashes them.
static func walking_actuation_handoff_receipt_v1(
	sdk: Object,
	model_instance_id: String,
	facade_segment_id: String,
	evaluation_segment_id: String,
	walking_session_id: String,
	global_semantic_step: int,
	motor_configuration_receipt: Dictionary,
	precommand_motor_population_readback: Dictionary,
	host_cap_projection_binding: Dictionary,
	development_policy_id: String = "",
) -> Dictionary:
	var policy := DevelopmentWalkingPolicy.binding_v1(development_policy_id, evaluation_segment_id)
	if policy.is_empty():
		return _failure("DEVELOPMENT_WALKING_POLICY_HANDOFF_SELECTION")
	if (
		sdk == null
		or model_instance_id.is_empty()
		or facade_segment_id not in WALKING_SEGMENT_IDS
		or evaluation_segment_id not in WALKING_EVALUATION_SEGMENT_IDS
		or walking_session_id.is_empty()
		or global_semantic_step <= 0
		or (facade_segment_id == "walking_prefix" and evaluation_segment_id != "walking_prefix")
		or (
			facade_segment_id == "walking_resume"
			and evaluation_segment_id not in ["matched_continuation", "walking_resume"]
		)
		or not walking_host_cap_projection_binding_valid_v1(
			sdk,
			host_cap_projection_binding,
		)
	):
		return _failure("QSDK_R10F_L12_WALKING_HANDOFF_INPUT_INVALID")
	var reason := "l12_walking_actuation_handoff_precommand:%s" % evaluation_segment_id
	if not _walking_handoff_motor_sources_valid_v1(
		motor_configuration_receipt,
		precommand_motor_population_readback,
		host_cap_projection_binding,
		global_semantic_step,
		reason,
	):
		return _failure("QSDK_R10F_L12_WALKING_HANDOFF_MOTOR_SOURCE_INVALID")
	var configuration_sha := _sha256_v1(sdk, motor_configuration_receipt)
	var readback_sha := _sha256_v1(sdk, precommand_motor_population_readback)
	var cap_binding_sha := String(host_cap_projection_binding.get("payload_sha256", ""))
	if (
		not _digest_valid_v1(configuration_sha)
		or not _digest_valid_v1(readback_sha)
		or not _digest_valid_v1(cap_binding_sha)
	):
		return _failure("QSDK_R10F_L12_WALKING_HANDOFF_SOURCE_DIGEST_INVALID")
	var receipt := {
		"schema_version": DevelopmentWalkingPolicy.schema_v1(WALKING_ACTUATION_HANDOFF_SCHEMA, "handoff", policy),
		"gate_id": GATE_ID,
		"ok": true,
		"facade_id": FACADE_ID,
		"model_instance_id": model_instance_id,
		"facade_segment_id": facade_segment_id,
		"evaluation_segment_id": evaluation_segment_id,
		"walking_session_id": walking_session_id,
		"global_semantic_step": global_semantic_step,
		"selected_policy_id": policy["policy_id"],
		"selected_policy_digest": policy["policy_digest"],
		"motor_configuration_receipt": motor_configuration_receipt.duplicate(true),
		"motor_configuration_receipt_sha256": configuration_sha,
		"precommand_motor_population_readback":
		precommand_motor_population_readback.duplicate(true),
		"precommand_motor_population_readback_sha256": readback_sha,
		"host_cap_projection_binding": host_cap_projection_binding.duplicate(true),
		"host_cap_projection_binding_sha256": cap_binding_sha,
		"ordered_actuator_ids": RecoveryWorld.ORDERED_ACTUATOR_IDS.duplicate(),
		"published_cap_by_actuator_id":
		(host_cap_projection_binding["published_cap_by_actuator_id"] as Dictionary).duplicate(true),
		"authorized_host_cap_by_actuator_id":
		(host_cap_projection_binding["selected_host_cap_by_actuator_id"] as Dictionary).duplicate(
			true
		),
		"motor_enabled_count": JOINT_IDS.size(),
		"zero_target_velocity_count": JOINT_IDS.size(),
		"motor_configuration_write_count": JOINT_IDS.size() * 2,
		"native_readback_count": JOINT_IDS.size() * 3,
		"solver_step_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"physics_state_modified": true,
		"outcome_derived_correction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _sha256_v1(sdk, receipt)
	if not walking_actuation_handoff_receipt_valid_v1(sdk, receipt, development_policy_id):
		return _failure("QSDK_R10F_L12_WALKING_HANDOFF_RECEIPT_INVALID")
	return receipt


static func walking_actuation_handoff_receipt_valid_v1(
	sdk: Object,
	receipt: Dictionary,
	development_policy_id: String = "",
) -> bool:
	var policy := DevelopmentWalkingPolicy.binding_v1(development_policy_id, String(receipt.get("evaluation_segment_id", "")))
	if policy.is_empty():
		return false
	if (
		sdk == null
		or not _keys_exact_v1(receipt, WALKING_ACTUATION_HANDOFF_KEYS)
		or String(receipt.get("schema_version", "")) != DevelopmentWalkingPolicy.schema_v1(WALKING_ACTUATION_HANDOFF_SCHEMA, "handoff", policy)
		or String(receipt.get("gate_id", "")) != GATE_ID
		or not bool(receipt.get("ok", false))
		or String(receipt.get("facade_id", "")) != FACADE_ID
		or String(receipt.get("model_instance_id", "")).is_empty()
		or String(receipt.get("facade_segment_id", "")) not in WALKING_SEGMENT_IDS
		or String(receipt.get("evaluation_segment_id", "")) not in WALKING_EVALUATION_SEGMENT_IDS
		or String(receipt.get("walking_session_id", "")).is_empty()
		or typeof(receipt.get("global_semantic_step")) != TYPE_INT
		or int(receipt.get("global_semantic_step", -1)) <= 0
		or String(receipt.get("selected_policy_id", "")) != policy["policy_id"]
		or String(receipt.get("selected_policy_digest", "")) != policy["policy_digest"]
		or not (receipt.get("motor_configuration_receipt") is Dictionary)
		or not (receipt.get("precommand_motor_population_readback") is Dictionary)
		or not (receipt.get("host_cap_projection_binding") is Dictionary)
		or receipt.get("ordered_actuator_ids") != RecoveryWorld.ORDERED_ACTUATOR_IDS
		or not (receipt.get("published_cap_by_actuator_id") is Dictionary)
		or not (receipt.get("authorized_host_cap_by_actuator_id") is Dictionary)
		or int(receipt.get("motor_enabled_count", -1)) != JOINT_IDS.size()
		or int(receipt.get("zero_target_velocity_count", -1)) != JOINT_IDS.size()
		or int(receipt.get("motor_configuration_write_count", -1)) != JOINT_IDS.size() * 2
		or int(receipt.get("native_readback_count", -1)) != JOINT_IDS.size() * 3
		or int(receipt.get("solver_step_count", -1)) != 0
		or int(receipt.get("body_transform_write_count", -1)) != 0
		or int(receipt.get("body_velocity_write_count", -1)) != 0
		or int(receipt.get("body_impulse_write_count", -1)) != 0
		or int(receipt.get("solver_reset_count", -1)) != 0
		or not bool(receipt.get("physics_state_modified", false))
		or bool(receipt.get("outcome_derived_correction", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	var facade_segment_id := String(receipt["facade_segment_id"])
	var evaluation_segment_id := String(receipt["evaluation_segment_id"])
	if (
		(facade_segment_id == "walking_prefix" and evaluation_segment_id != "walking_prefix")
		or (
			facade_segment_id == "walking_resume"
			and evaluation_segment_id not in ["matched_continuation", "walking_resume"]
		)
	):
		return false
	var cap_binding: Dictionary = receipt["host_cap_projection_binding"]
	if (
		not walking_host_cap_projection_binding_valid_v1(sdk, cap_binding)
		or (
			String(receipt.get("host_cap_projection_binding_sha256", ""))
			!= String(cap_binding.get("payload_sha256", ""))
		)
		or (
			receipt.get("published_cap_by_actuator_id")
			!= cap_binding.get("published_cap_by_actuator_id")
		)
		or (
			receipt.get("authorized_host_cap_by_actuator_id")
			!= cap_binding.get("selected_host_cap_by_actuator_id")
		)
	):
		return false
	var configuration: Dictionary = receipt["motor_configuration_receipt"]
	var readback: Dictionary = receipt["precommand_motor_population_readback"]
	var reason := "l12_walking_actuation_handoff_precommand:%s" % evaluation_segment_id
	if not _walking_handoff_motor_sources_valid_v1(
		configuration,
		readback,
		cap_binding,
		int(receipt["global_semantic_step"]),
		reason,
	):
		return false
	if (
		(
			String(receipt.get("motor_configuration_receipt_sha256", ""))
			!= _sha256_v1(sdk, configuration)
		)
		or (
			String(receipt.get("precommand_motor_population_readback_sha256", ""))
			!= _sha256_v1(sdk, readback)
		)
	):
		return false
	var payload := receipt.duplicate(true)
	payload["payload_sha256"] = ""
	return (
		_digest_valid_v1(String(receipt.get("payload_sha256", "")))
		and _sha256_v1(sdk, payload) == String(receipt["payload_sha256"])
	)


static func _walking_handoff_motor_sources_valid_v1(
	motor_configuration_receipt: Dictionary,
	precommand_motor_population_readback: Dictionary,
	host_cap_projection_binding: Dictionary,
	global_semantic_step: int,
	reason: String,
) -> bool:
	if (
		String(motor_configuration_receipt.get("schema_version", "")) != MOTOR_CONFIGURATION_SCHEMA
		or String(motor_configuration_receipt.get("gate_id", "")) != GATE_ID
		or not bool(motor_configuration_receipt.get("ok", false))
		or int(motor_configuration_receipt.get("global_semantic_step", -1)) != global_semantic_step
		or String(motor_configuration_receipt.get("reason", "")) != reason
		or not bool(motor_configuration_receipt.get("motor_enabled", false))
		or not (motor_configuration_receipt.get("ordered_joint_receipts") is Array)
		or (
			int(motor_configuration_receipt.get("motor_configuration_write_count", -1))
			!= JOINT_IDS.size() * 2
		)
		or int(motor_configuration_receipt.get("body_transform_write_count", -1)) != 0
		or int(motor_configuration_receipt.get("body_velocity_write_count", -1)) != 0
		or int(motor_configuration_receipt.get("body_impulse_write_count", -1)) != 0
		or int(motor_configuration_receipt.get("solver_reset_count", -1)) != 0
		or not bool(motor_configuration_receipt.get("physics_state_modified", false))
		or bool(motor_configuration_receipt.get("physical_acceptance_authority", true))
		or bool(motor_configuration_receipt.get("release_authority", true))
		or (
			String(precommand_motor_population_readback.get("schema_version", ""))
			!= MOTOR_POPULATION_READBACK_SCHEMA
		)
		or String(precommand_motor_population_readback.get("gate_id", "")) != GATE_ID
		or not bool(precommand_motor_population_readback.get("ok", false))
		or (
			int(precommand_motor_population_readback.get("global_semantic_step", -1))
			!= global_semantic_step
		)
		or String(precommand_motor_population_readback.get("reason", "")) != reason
		or not bool(precommand_motor_population_readback.get("expected_motor_enabled", false))
		or not (precommand_motor_population_readback.get("ordered_joint_readbacks") is Array)
		or (
			int(precommand_motor_population_readback.get("motor_enabled_count", -1))
			!= JOINT_IDS.size()
		)
		or (
			int(precommand_motor_population_readback.get("zero_target_velocity_count", -1))
			!= JOINT_IDS.size()
		)
		or (
			int(precommand_motor_population_readback.get("native_readback_count", -1))
			!= JOINT_IDS.size() * 3
		)
		or int(precommand_motor_population_readback.get("body_transform_write_count", -1)) != 0
		or int(precommand_motor_population_readback.get("body_velocity_write_count", -1)) != 0
		or int(precommand_motor_population_readback.get("body_impulse_write_count", -1)) != 0
		or int(precommand_motor_population_readback.get("solver_reset_count", -1)) != 0
		or int(precommand_motor_population_readback.get("solver_step_count", -1)) != 0
		or bool(precommand_motor_population_readback.get("physics_state_modified", true))
		or bool(precommand_motor_population_readback.get("physical_acceptance_authority", true))
		or bool(precommand_motor_population_readback.get("release_authority", true))
	):
		return false
	var configuration_rows: Array = motor_configuration_receipt["ordered_joint_receipts"]
	var readback_rows: Array = precommand_motor_population_readback["ordered_joint_readbacks"]
	var selected_host_caps: Dictionary = (
		host_cap_projection_binding
		. get(
			"selected_host_cap_by_actuator_id",
			{},
		)
	)
	if (
		configuration_rows.size() != JOINT_IDS.size()
		or readback_rows.size() != JOINT_IDS.size()
		or selected_host_caps.size() != JOINT_IDS.size()
	):
		return false
	for index in range(JOINT_IDS.size()):
		if (
			not (configuration_rows[index] is Dictionary)
			or not (readback_rows[index] is Dictionary)
		):
			return false
		var configuration_row: Dictionary = configuration_rows[index]
		var readback_row: Dictionary = readback_rows[index]
		var joint_id := String(JOINT_IDS[index])
		var actuator_id := String(RecoveryWorld.ORDERED_ACTUATOR_IDS[index])
		if (
			String(configuration_row.get("joint_id", "")) != joint_id
			or not bool(configuration_row.get("motor_enabled", false))
			or float(configuration_row.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or String(readback_row.get("joint_id", "")) != joint_id
			or String(readback_row.get("actuator_id", "")) != actuator_id
			or not bool(readback_row.get("motor_enabled", false))
			or float(readback_row.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or not selected_host_caps.has(actuator_id)
			or (
				float(readback_row.get("motor_maximum_impulse_nms", NAN))
				!= float(selected_host_caps[actuator_id])
			)
		):
			return false
	return true


func begin_walking_actuation_handoff_v1(
	sdk: Object,
	evaluation_segment_id: String,
	global_semantic_step: int,
) -> Dictionary:
	if (
		sdk == null
		or not _started
		or _shutdown
		or _binding.is_empty()
		or not _walking_actuation_handoff_receipt.is_empty()
		or evaluation_segment_id not in WALKING_EVALUATION_SEGMENT_IDS
		or global_semantic_step != _global_start_step + 1
	):
		return _failure("QSDK_R10F_L12_WALKING_HANDOFF_LIFECYCLE_INVALID")
	var cap_binding := walking_host_cap_projection_binding_v1(sdk)
	if not bool(cap_binding.get("ok", false)):
		return cap_binding
	var reason := "l12_walking_actuation_handoff_precommand:%s" % evaluation_segment_id
	var configuration := configure_all_motors_v1(true, global_semantic_step, reason)
	if not bool(configuration.get("ok", false)):
		return configuration
	var readback := motor_population_readback_v1(global_semantic_step, true, reason)
	if not bool(readback.get("ok", false)):
		return readback
	var receipt := walking_actuation_handoff_receipt_v1(
		sdk,
		String(_binding["model_instance_id"]),
		_segment_id,
		evaluation_segment_id,
		_session_id,
		global_semantic_step,
		configuration,
		readback,
		cap_binding,
		_development_walking_policy_id,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	_walking_actuation_handoff_receipt = receipt.duplicate(true)
	_authorized_host_cap_by_actuator_id = (
		(receipt["authorized_host_cap_by_actuator_id"] as Dictionary).duplicate(true)
	)
	return receipt


func _bind_current_floor_v1() -> Dictionary:
	var source := SdkAdapterScript.DevelopmentFloor.capture_v1(_adapter._api, _binding.get("floor"), _binding.get("model_instance_id", ""))
	if source.get("ok") != true:
		return source
	return _adapter.bind_development_floor_source_v1(source, _binding.get("model_instance_id", ""))


func _sample_walking_input_v1(local_step: int, amplitude: float, phase_mode: String) -> Dictionary:
	# Keep the sampler argument boundary directly testable without a world.
	if DevelopmentWalkingPolicy.floor_selected_v1(_adapter._controller_policy_id):
		var bound := _bind_current_floor_v1()
		if bound.get("ok") != true:
			return bound
	return _adapter.sample(local_step, amplitude, phase_mode,
		_binding["torso"], _binding["limbs"], _binding["floor"])


func sample_step_apply_v1(
	sdk: Object,
	global_semantic_step: int,
	session_local_step: int,
	phase: String,
	gait_amplitude: float = 1.0,
	development_native_contact_source: Dictionary = {},
	phase_progression_mode: String = "contact_gated",
) -> Dictionary:
	if (
		sdk == null
		or not _started
		or _shutdown
		or _adapter == null
		or global_semantic_step <= 0
		or session_local_step <= 0
		or phase.is_empty()
		or not is_finite(gait_amplitude)
		or gait_amplitude < 0.0
		or phase_progression_mode not in ["clocked", "contact_gated"]
		or _walking_actuation_handoff_receipt.is_empty()
		or _authorized_host_cap_by_actuator_id.size() != JOINT_IDS.size()
		or not walking_actuation_handoff_receipt_valid_v1(
			sdk,
			_walking_actuation_handoff_receipt,
			_development_walking_policy_id,
		)
		or (
			session_local_step == 1
			and (
				int(_walking_actuation_handoff_receipt.get("global_semantic_step", -1))
				!= global_semantic_step
			)
		)
		or (
			int(_walking_actuation_handoff_receipt.get("global_semantic_step", -1))
			!= global_semantic_step - session_local_step + 1
		)
	):
		return _failure("QSDK_R10F_LOCOMOTION_STEP_INPUT_INVALID")
	if NativeWalkingContacts.selected_v1(_development_contact_profile_id):
		var identity := same_body_identity_receipt_v1(sdk, global_semantic_step - 1, "native_walking_contact_input")
		if identity.get("ok") != true:
			return identity
		var prepared := NativeWalkingContacts.prepare_v1(sdk, development_native_contact_source, _binding,
			global_semantic_step, identity["body_population_instance_sha256"])
		if prepared.get("ok") != true:
			return prepared
	elif not development_native_contact_source.is_empty():
		return _failure("UNSELECTED_NATIVE_WALKING_CONTACT_SOURCE")
	var sample := _sample_walking_input_v1(session_local_step, gait_amplitude, phase_progression_mode)
	if not bool(sample.get("ok", false)):
		return _failure(
			"QSDK_R10F_LOCOMOTION_SAMPLE_FAILED",
			{"adapter_failure_code": String(sample.get("failure_code", ""))},
		)
	var step_result := (
		_adapter
		. step(
			sample,
			session_local_step,
			{},
			_initial_gait_steps,
			0.0,
			{},
			true,
		)
	)
	if not bool(step_result.get("ok", false)):
		return portable_step_failure_v1(step_result)
	var applied := (
		_adapter
		. apply_authority(
			step_result,
			_binding["joint_state_by_legacy_id"],
			true,
			_authorized_host_cap_by_actuator_id,
		)
	)
	if not bool(applied.get("ok", false)):
		var application_failure := _failure(
			"QSDK_R10F_LOCOMOTION_AUTHORITY_APPLICATION_FAILED",
			{"adapter_failure_code": String(applied.get("failure_code", ""))},
		)
		application_failure["portable_step_receipt"] = step_result.duplicate(true)
		application_failure["native_step_transport_verification"] = (
			(step_result.get("native_step_transport_verification", {}) as Dictionary)
			. duplicate(true)
		)
		application_failure["authority_application_receipt"] = applied.duplicate(true)
		return application_failure
	var motor_readback := motor_population_readback_v1(
		global_semantic_step,
		true,
		"post_bw5r_b_authority_application",
	)
	if not bool(motor_readback.get("ok", false)):
		var readback_failure := motor_readback.duplicate(true)
		readback_failure["portable_step_receipt"] = step_result.duplicate(true)
		readback_failure["native_step_transport_verification"] = (
			(step_result.get("native_step_transport_verification", {}) as Dictionary)
			. duplicate(true)
		)
		readback_failure["authority_application_receipt"] = applied.duplicate(true)
		readback_failure["motor_population_readback"] = motor_readback.duplicate(true)
		return readback_failure
	var ledger_intent := walking_ledger_application_intent_v2(
		sdk,
		global_semantic_step,
		phase,
		_session_id,
		session_local_step,
		step_result,
		applied,
		motor_readback,
		_walking_actuation_handoff_receipt,
		_development_walking_policy_id,
	)
	if not bool(ledger_intent.get("ok", false)):
		return ledger_intent
	if not _development_contact_profile_id.is_empty():
		# Synchronous command handling does not advance a solver step. These are
		# the same cached callback properties consumed by the sample above.
		sample["development_contact_sources"] = DevelopmentWalkingContacts.sources_v1(_binding["limbs"])
		if NativeWalkingContacts.selected_v1(_development_contact_profile_id):
			sample["development_native_contact_source"] = development_native_contact_source.duplicate(true)
	return {
		"schema_version": STEP_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"facade_id": FACADE_ID,
		"model_instance_id": String(_binding["model_instance_id"]),
		"segment_id": _segment_id,
		"session_id": _session_id,
		"global_semantic_step": global_semantic_step,
		"session_local_step": session_local_step,
		"sample_receipt": sample,
		"portable_step_receipt": step_result,
		"native_step_transport_verification":
		(step_result["native_step_transport_verification"] as Dictionary).duplicate(true),
		"authority_application_receipt": applied,
		"motor_population_readback": motor_readback,
		"walking_actuation_handoff_receipt": _walking_actuation_handoff_receipt.duplicate(true),
		"ledger_application_intent": ledger_intent,
		"host_target_projection_receipt":
		(ledger_intent["host_target_projection_receipt"] as Dictionary).duplicate(true),
		"walking_ledger_predicate_receipt":
		(ledger_intent["walking_ledger_predicate_receipt"] as Dictionary).duplicate(true),
		"applied_motor_command_count": int(applied["applied_command_count"]),
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Read the exact already-live motor population without writing it. The
## receipt is intentionally separate from both controller commands and solver
## telemetry: it proves what was configured before the next physics step.
func motor_population_readback_v1(
	global_semantic_step: int,
	expected_enabled: bool,
	reason: String,
) -> Dictionary:
	if _binding.is_empty() or global_semantic_step < 0 or reason.is_empty():
		return _failure("QSDK_R10F_LOCOMOTION_MOTOR_READBACK_INPUT_INVALID")
	var rows: Array = []
	var enabled_count := 0
	var zero_target_count := 0
	for index in range(JOINT_IDS.size()):
		var joint_id := String(JOINT_IDS[index])
		var actuator_id := String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
		var joint: HingeJoint3D = (_binding["joint_nodes"] as Dictionary)[joint_id]
		var enabled := bool(joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR))
		var target := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY))
		var maximum_impulse := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
		if (
			enabled != expected_enabled
			or not is_finite(target)
			or not is_finite(maximum_impulse)
			or maximum_impulse <= 0.0
			or (not expected_enabled and target != 0.0)
		):
			return _failure("QSDK_R10F_LOCOMOTION_MOTOR_READBACK_INVALID:%s" % joint_id)
		enabled_count += int(enabled)
		zero_target_count += int(target == 0.0)
		(
			rows
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"motor_enabled": enabled,
					"motor_target_velocity_rad_s": target,
					"motor_maximum_impulse_nms": maximum_impulse,
				}
			)
		)
	return {
		"schema_version": MOTOR_POPULATION_READBACK_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_semantic_step,
		"reason": reason,
		"expected_motor_enabled": expected_enabled,
		"ordered_joint_readbacks": rows,
		"motor_enabled_count": enabled_count,
		"zero_target_velocity_count": zero_target_count,
		"native_readback_count": JOINT_IDS.size() * 3,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Deterministic declaration of the representation Godot stores for a motor
## target. The binary64 controller request remains untouched and is still the
## value passed to set_param(); this receipt separately names the binary32
## realization returned by HingeJoint3D.
static func walking_host_target_projection_receipt_v1(
	sdk: Object,
	commands: Array,
	applications: Array,
	readbacks: Array,
	published_cap_by_actuator_id: Dictionary,
	authorized_host_cap_by_actuator_id: Dictionary,
) -> Dictionary:
	var rows: Array = []
	var failed_predicate_ids: Array[String] = []
	var nonzero_controller_target_count := 0
	var application_projection_match_count := 0
	var population_projection_match_count := 0
	var application_population_match_count := 0
	var r69_host_cap_exact_count := 0
	if (
		commands.size() != JOINT_IDS.size()
		or applications.size() != JOINT_IDS.size()
		or readbacks.size() != JOINT_IDS.size()
		or published_cap_by_actuator_id.size() != JOINT_IDS.size()
		or authorized_host_cap_by_actuator_id.size() != JOINT_IDS.size()
	):
		failed_predicate_ids.append("projection.source_cardinality_exact")
	else:
		for index in range(JOINT_IDS.size()):
			if (
				not (commands[index] is Dictionary)
				or not (applications[index] is Dictionary)
				or not (readbacks[index] is Dictionary)
			):
				failed_predicate_ids.append("projection.row.%d.source_shape" % index)
				continue
			var command: Dictionary = commands[index]
			var application: Dictionary = applications[index]
			var readback: Dictionary = readbacks[index]
			var actuator_id := String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
			var joint_id := String(JOINT_IDS[index])
			var controller_target_value: Variant = command.get("target_velocity_rad_s", null)
			var controller_target_numeric := (
				typeof(controller_target_value) in [TYPE_INT, TYPE_FLOAT]
			)
			var controller_target := (
				float(controller_target_value) if controller_target_numeric else 0.0
			)
			var controller_finite := controller_target_numeric and is_finite(controller_target)
			var expected_host_target := (
				float(PackedFloat32Array([controller_target])[0]) if controller_finite else 0.0
			)
			var application_host_request := float(
				application.get("host_applied_target_velocity_rad_s", NAN)
			)
			var application_readback := float(
				application.get("motor_target_velocity_readback_rad_s", NAN)
			)
			var population_readback := float(readback.get("motor_target_velocity_rad_s", NAN))
			var published_cap := float(published_cap_by_actuator_id.get(actuator_id, NAN))
			var authorized_host_cap := float(
				authorized_host_cap_by_actuator_id.get(actuator_id, NAN)
			)
			var application_cap := float(application.get("declared_maximum_impulse_nms", NAN))
			var application_cap_readback := float(
				application.get("motor_maximum_impulse_readback_nms", NAN)
			)
			var population_cap_readback := float(readback.get("motor_maximum_impulse_nms", NAN))
			var projection_finite := controller_finite and is_finite(expected_host_target)
			var application_request_exact := (
				controller_finite and application_host_request == controller_target
			)
			var application_projection_exact := (
				projection_finite and application_readback == expected_host_target
			)
			var population_projection_exact := (
				projection_finite and population_readback == expected_host_target
			)
			var application_population_exact := (
				is_finite(application_readback) and application_readback == population_readback
			)
			var r69_host_cap_exact := (
				is_finite(published_cap)
				and is_finite(authorized_host_cap)
				and published_cap > 0.0
				and authorized_host_cap > 0.0
				and authorized_host_cap <= published_cap
				and application_cap == authorized_host_cap
				and application_cap_readback == authorized_host_cap
				and population_cap_readback == authorized_host_cap
			)
			if controller_target != 0.0:
				nonzero_controller_target_count += 1
			application_projection_match_count += int(application_projection_exact)
			population_projection_match_count += int(population_projection_exact)
			application_population_match_count += int(application_population_exact)
			r69_host_cap_exact_count += int(r69_host_cap_exact)
			for predicate in [
				["identity", String(command.get("actuator_id", "")) == actuator_id],
				[
					"application_identity",
					(
						String(application.get("actuator_id", "")) == actuator_id
						and String(application.get("joint_id", "")) == joint_id
					),
				],
				[
					"population_identity",
					(
						String(readback.get("actuator_id", "")) == actuator_id
						and String(readback.get("joint_id", "")) == joint_id
					),
				],
				["controller_request_finite", controller_finite],
				["binary32_projection_finite", projection_finite],
				["application_request_preserved_exactly", application_request_exact],
				["application_readback_equals_projection", application_projection_exact],
				["population_readback_equals_projection", population_projection_exact],
				["application_population_readbacks_equal", application_population_exact],
				["r69_host_cap_exact", r69_host_cap_exact],
			]:
				if not bool(predicate[1]):
					failed_predicate_ids.append(
						"projection.row.%d.%s" % [index, String(predicate[0])]
					)
			(
				rows
				. append(
					{
						"actuator_id": actuator_id,
						"joint_id": joint_id,
						"controller_binary64_target_velocity_rad_s":
						controller_target if controller_finite else null,
						"expected_binary32_host_target_velocity_rad_s":
						expected_host_target if projection_finite else null,
						"application_host_applied_binary64_target_velocity_rad_s":
						application_host_request,
						"application_motor_target_velocity_readback_rad_s": application_readback,
						"population_motor_target_velocity_readback_rad_s": population_readback,
						"published_cap_nms": published_cap,
						"authorized_host_cap_nms": authorized_host_cap,
						"application_declared_maximum_impulse_nms": application_cap,
						"application_motor_maximum_impulse_readback_nms": application_cap_readback,
						"population_motor_maximum_impulse_readback_nms": population_cap_readback,
						"controller_request_finite": controller_finite,
						"binary32_projection_finite": projection_finite,
						"application_request_preserved_exactly": application_request_exact,
						"application_readback_equals_projection_exactly":
						application_projection_exact,
						"population_readback_equals_projection_exactly":
						population_projection_exact,
						"application_population_readbacks_equal_exactly":
						application_population_exact,
						"r69_host_cap_exact": r69_host_cap_exact,
					}
				)
			)
	var receipt := {
		"schema_version": WALKING_HOST_TARGET_PROJECTION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": failed_predicate_ids.is_empty(),
		"projection_rule": "float(PackedFloat32Array([controller_target_velocity_rad_s])[0])",
		"projection_kind": "deterministic_host_representation_not_empirical_correction",
		"ordered_actuator_ids": RecoveryRoute.ORDERED_ACTUATOR_IDS.duplicate(),
		"ordered_target_projections": rows,
		"projection_count": rows.size(),
		"nonzero_controller_target_count": nonzero_controller_target_count,
		"controller_binary64_target_retained_separately": true,
		"expected_binary32_host_target_retained_separately": true,
		"application_readback_equals_projection_count": application_projection_match_count,
		"population_readback_equals_projection_count": population_projection_match_count,
		"application_population_readbacks_equal_count": application_population_match_count,
		"r69_host_cap_exact_count": r69_host_cap_exact_count,
		"controller_command_rounded_before_write": false,
		"host_write_changed": false,
		"solver_input_changed": false,
		"empirical_margin_added": false,
		"tolerance_added": false,
		"raw_measurement_clamped": false,
		"outcome_derived_correction": false,
		"failed_predicate_ids": failed_predicate_ids.duplicate(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _sha256_v1(sdk, receipt)
	return receipt


static func walking_host_target_projection_receipt_valid_v1(
	sdk: Object,
	receipt: Dictionary,
) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(receipt, WALKING_HOST_TARGET_PROJECTION_KEYS)
		or String(receipt.get("schema_version", "")) != WALKING_HOST_TARGET_PROJECTION_SCHEMA
		or String(receipt.get("gate_id", "")) != GATE_ID
		or not bool(receipt.get("ok", false))
		or (
			String(receipt.get("projection_rule", ""))
			!= "float(PackedFloat32Array([controller_target_velocity_rad_s])[0])"
		)
		or (
			String(receipt.get("projection_kind", ""))
			!= "deterministic_host_representation_not_empirical_correction"
		)
		or receipt.get("ordered_actuator_ids") != RecoveryRoute.ORDERED_ACTUATOR_IDS
		or int(receipt.get("projection_count", -1)) != JOINT_IDS.size()
		or not bool(receipt.get("controller_binary64_target_retained_separately", false))
		or not bool(receipt.get("expected_binary32_host_target_retained_separately", false))
		or int(receipt.get("application_readback_equals_projection_count", -1)) != JOINT_IDS.size()
		or int(receipt.get("population_readback_equals_projection_count", -1)) != JOINT_IDS.size()
		or int(receipt.get("application_population_readbacks_equal_count", -1)) != JOINT_IDS.size()
		or int(receipt.get("r69_host_cap_exact_count", -1)) != JOINT_IDS.size()
		or bool(receipt.get("controller_command_rounded_before_write", true))
		or bool(receipt.get("host_write_changed", true))
		or bool(receipt.get("solver_input_changed", true))
		or bool(receipt.get("empirical_margin_added", true))
		or bool(receipt.get("tolerance_added", true))
		or bool(receipt.get("raw_measurement_clamped", true))
		or bool(receipt.get("outcome_derived_correction", true))
		or not (receipt.get("failed_predicate_ids") is Array)
		or not (receipt.get("failed_predicate_ids") as Array).is_empty()
		or int(receipt.get("model_construction_count", -1)) != 0
		or int(receipt.get("world_attempt_count", -1)) != 0
		or int(receipt.get("world_build_count", -1)) != 0
		or int(receipt.get("solver_step_count", -1)) != 0
		or bool(receipt.get("physics_state_modified", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	var declared_payload_sha256 := String(receipt.get("payload_sha256", ""))
	var payload := receipt.duplicate(true)
	payload["payload_sha256"] = ""
	if (
		not _digest_valid_v1(declared_payload_sha256)
		or _sha256_v1(sdk, payload) != declared_payload_sha256
	):
		return false
	var rows_value: Variant = receipt.get("ordered_target_projections")
	if not (rows_value is Array) or (rows_value as Array).size() != JOINT_IDS.size():
		return false
	var rows: Array = rows_value
	var nonzero_count := 0
	for index in range(JOINT_IDS.size()):
		if not (rows[index] is Dictionary):
			return false
		var row: Dictionary = rows[index]
		if not _keys_exact_v1(row, WALKING_HOST_TARGET_PROJECTION_ROW_KEYS):
			return false
		var controller_target := float(row.get("controller_binary64_target_velocity_rad_s", NAN))
		var expected_host_target := float(PackedFloat32Array([controller_target])[0])
		var published_cap := float(row.get("published_cap_nms", NAN))
		var authorized_host_cap := float(row.get("authorized_host_cap_nms", NAN))
		if (
			String(row.get("actuator_id", "")) != String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
			or String(row.get("joint_id", "")) != String(JOINT_IDS[index])
			or not is_finite(controller_target)
			or not is_finite(expected_host_target)
			or (
				float(row.get("expected_binary32_host_target_velocity_rad_s", NAN))
				!= expected_host_target
			)
			or (
				float(row.get("application_host_applied_binary64_target_velocity_rad_s", NAN))
				!= controller_target
			)
			or (
				float(row.get("application_motor_target_velocity_readback_rad_s", NAN))
				!= expected_host_target
			)
			or (
				float(row.get("population_motor_target_velocity_readback_rad_s", NAN))
				!= expected_host_target
			)
			or not is_finite(published_cap)
			or not is_finite(authorized_host_cap)
			or published_cap <= 0.0
			or authorized_host_cap <= 0.0
			or authorized_host_cap > published_cap
			or (
				float(row.get("application_declared_maximum_impulse_nms", NAN))
				!= authorized_host_cap
			)
			or (
				float(row.get("application_motor_maximum_impulse_readback_nms", NAN))
				!= authorized_host_cap
			)
			or (
				float(row.get("population_motor_maximum_impulse_readback_nms", NAN))
				!= authorized_host_cap
			)
			or not bool(row.get("controller_request_finite", false))
			or not bool(row.get("binary32_projection_finite", false))
			or not bool(row.get("application_request_preserved_exactly", false))
			or not bool(row.get("application_readback_equals_projection_exactly", false))
			or not bool(row.get("population_readback_equals_projection_exactly", false))
			or not bool(row.get("application_population_readbacks_equal_exactly", false))
			or not bool(row.get("r69_host_cap_exact", false))
		):
			return false
		nonzero_count += int(controller_target != 0.0)
	return int(receipt.get("nonzero_controller_target_count", -1)) == nonzero_count


## Pure compatibility projection for a BW5R-B command that has already been
## applied to the shared recovery-native hinges. The historical R148/R162
## sampler sees only its qualified route vocabulary; the nested receipts retain
## the real walking owner, portable controller identity, local session clock,
## and exact native target/cap readbacks.
static func walking_ledger_application_intent_v1(
	sdk: Object,
	global_semantic_step: int,
	phase: String,
	session_id: String,
	session_local_step: int,
	portable_step_receipt: Dictionary,
	authority_application_receipt: Dictionary,
	motor_population_readback: Dictionary,
	walking_actuation_handoff_receipt: Dictionary,
) -> Dictionary:
	if (
		sdk == null
		or global_semantic_step <= 0
		or phase.is_empty()
		or session_id.is_empty()
		or session_local_step <= 0
		or _has_outcome_derived_top_level_v1(portable_step_receipt)
		or _has_outcome_derived_top_level_v1(authority_application_receipt)
		or _has_outcome_derived_top_level_v1(motor_population_readback)
		or _has_outcome_derived_top_level_v1(walking_actuation_handoff_receipt)
		or not walking_actuation_handoff_receipt_valid_v1(
			sdk,
			walking_actuation_handoff_receipt,
		)
	):
		return _failure("QSDK_R10F_WALKING_LEDGER_INPUT_INVALID")
	var native_output_value: Variant = portable_step_receipt.get("native_output")
	var applications_value: Variant = authority_application_receipt.get("ordered_applications")
	var readbacks_value: Variant = motor_population_readback.get("ordered_joint_readbacks")
	if (
		not (native_output_value is Dictionary)
		or not (applications_value is Array)
		or not (readbacks_value is Array)
	):
		return _failure("QSDK_R10F_WALKING_LEDGER_SOURCE_SHAPE_INVALID")
	var native_output: Dictionary = native_output_value
	var actuation_value: Variant = native_output.get("actuation")
	if not (actuation_value is Dictionary):
		return _failure("QSDK_R10F_WALKING_LEDGER_ACTUATION_MISSING")
	var actuation: Dictionary = actuation_value
	var commands_value: Variant = actuation.get("ordered_commands")
	var controller_receipt_value: Variant = actuation.get("receipt")
	if not (commands_value is Array) or not (controller_receipt_value is Dictionary):
		return _failure("QSDK_R10F_WALKING_LEDGER_COMMAND_SOURCE_INVALID")
	var commands: Array = commands_value
	var applications: Array = applications_value
	var readbacks: Array = readbacks_value
	var controller_receipt: Dictionary = controller_receipt_value
	var controller_receipt_sha256 := String(actuation.get("receipt_sha256", ""))
	var published_cap_by_actuator_id: Dictionary = walking_actuation_handoff_receipt["published_cap_by_actuator_id"]
	var authorized_host_cap_by_actuator_id: Dictionary = walking_actuation_handoff_receipt["authorized_host_cap_by_actuator_id"]
	if (
		not bool(portable_step_receipt.get("ok", false))
		or String(portable_step_receipt.get("controller_policy_id", "")) != SELECTED_POLICY_ID
		or int(portable_step_receipt.get("semantic_step", -1)) != session_local_step
		or int(actuation.get("semantic_step", -1)) != session_local_step
		or bool(actuation.get("safe_no_actuation", true))
		or (
			String(portable_step_receipt.get("controller_step_receipt_sha256", ""))
			!= controller_receipt_sha256
		)
		or _sha256_v1(sdk, controller_receipt) != controller_receipt_sha256
		or (
			String(authority_application_receipt.get("schema_version", ""))
			!= "sporespore_godot_jolt_full_authority_application_receipt_v1"
		)
		or not bool(authority_application_receipt.get("ok", false))
		or int(authority_application_receipt.get("semantic_step", -1)) != session_local_step
		or int(authority_application_receipt.get("applied_command_count", -1)) != JOINT_IDS.size()
		or (
			authority_application_receipt.get("ordered_actuator_ids")
			!= RecoveryRoute.ORDERED_ACTUATOR_IDS
		)
		or not bool(authority_application_receipt.get("configured_motor_parameters_only", false))
		or not bool(authority_application_receipt.get("maximum_impulse_override_applied", false))
		or (
			authority_application_receipt.get("authorized_maximum_impulse_by_actuator_id")
			!= authorized_host_cap_by_actuator_id
		)
		or not bool(motor_population_readback.get("ok", false))
		or int(motor_population_readback.get("global_semantic_step", -1)) != global_semantic_step
		or not bool(motor_population_readback.get("expected_motor_enabled", false))
		or int(motor_population_readback.get("motor_enabled_count", -1)) != JOINT_IDS.size()
		or commands.size() != JOINT_IDS.size()
		or applications.size() != JOINT_IDS.size()
		or readbacks.size() != JOINT_IDS.size()
		or published_cap_by_actuator_id.size() != JOINT_IDS.size()
		or authorized_host_cap_by_actuator_id.size() != JOINT_IDS.size()
		or String(walking_actuation_handoff_receipt.get("walking_session_id", "")) != session_id
		or (
			int(walking_actuation_handoff_receipt.get("global_semantic_step", -1))
			!= global_semantic_step - session_local_step + 1
		)
	):
		return _failure("QSDK_R10F_WALKING_LEDGER_IDENTITY_INVALID")
	for index in range(JOINT_IDS.size()):
		if (
			not (commands[index] is Dictionary)
			or not (applications[index] is Dictionary)
			or not (readbacks[index] is Dictionary)
		):
			return _failure("QSDK_R10F_WALKING_LEDGER_ROW_SHAPE_INVALID:%d" % index)
		var command: Dictionary = commands[index]
		var application: Dictionary = applications[index]
		var readback: Dictionary = readbacks[index]
		var actuator_id := String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
		var joint_id := String(JOINT_IDS[index])
		var target := float(command.get("target_velocity_rad_s", NAN))
		var cap := float(application.get("declared_maximum_impulse_nms", NAN))
		var published_cap := float(published_cap_by_actuator_id.get(actuator_id, NAN))
		var authorized_host_cap := float(authorized_host_cap_by_actuator_id.get(actuator_id, NAN))
		if (
			String(command.get("actuator_id", "")) != actuator_id
			or String(application.get("actuator_id", "")) != actuator_id
			or String(readback.get("actuator_id", "")) != actuator_id
			or String(application.get("joint_id", "")) != joint_id
			or String(readback.get("joint_id", "")) != joint_id
			or not is_finite(target)
			or not is_finite(cap)
			or not is_finite(published_cap)
			or not is_finite(authorized_host_cap)
			or cap <= 0.0
			or published_cap <= 0.0
			or authorized_host_cap <= 0.0
			or authorized_host_cap > published_cap
			or cap != authorized_host_cap
			or float(application.get("host_applied_target_velocity_rad_s", NAN)) != target
			or float(application.get("motor_target_velocity_readback_rad_s", NAN)) != target
			or not bool(application.get("target_velocity_readback_matches", false))
			or not bool(application.get("maximum_impulse_readback_matches", false))
			or not bool(readback.get("motor_enabled", false))
			or float(readback.get("motor_target_velocity_rad_s", NAN)) != target
			or float(readback.get("motor_maximum_impulse_nms", NAN)) != authorized_host_cap
		):
			return _failure("QSDK_R10F_WALKING_LEDGER_ROW_INVALID:%d" % index)
	var controller_receipt_sha := _sha256_v1(sdk, controller_receipt)
	var authority_sha := _sha256_v1(sdk, authority_application_receipt)
	var readback_sha := _sha256_v1(sdk, motor_population_readback)
	var handoff_sha := String(walking_actuation_handoff_receipt.get("payload_sha256", ""))
	var command_record := {
		"schema_version": "sporespore_qsdk_r10f_bw5r_b_motor_command_binding_v1",
		"selected_policy_id": SELECTED_POLICY_ID,
		"selected_policy_digest": SELECTED_POLICY_DIGEST,
		"session_id": session_id,
		"session_local_step": session_local_step,
		"global_semantic_step": global_semantic_step,
		"phase": phase,
		"ordered_commands": commands.duplicate(true),
		"controller_step_receipt_sha256": controller_receipt_sha,
		"authority_application_receipt_sha256": authority_sha,
		"motor_population_readback_sha256": readback_sha,
		"walking_actuation_handoff_receipt_sha256": handoff_sha,
		"published_cap_by_actuator_id": published_cap_by_actuator_id.duplicate(true),
		"authorized_host_cap_by_actuator_id": authorized_host_cap_by_actuator_id.duplicate(true),
	}
	var command_sha := _sha256_v1(sdk, command_record)
	if (
		command_sha.is_empty()
		or authority_sha.is_empty()
		or readback_sha.is_empty()
		or not _digest_valid_v1(handoff_sha)
	):
		return _failure("QSDK_R10F_WALKING_LEDGER_DIGEST_INVALID")
	return {
		"schema_version": WALKING_LEDGER_APPLICATION_SCHEMA,
		"ok": true,
		"semantic_step": global_semantic_step,
		"source_control_semantic_step": global_semantic_step - 1,
		"phase": phase,
		"command_id": "qsdk_r10f_bw5r_b:%s:%d" % [session_id, session_local_step],
		"command_sha256": command_sha,
		"zero_command": false,
		"no_actuation_requested": false,
		"motor_enabled_count": JOINT_IDS.size(),
		"native_joint_motors_disabled": false,
		"actuator_mapping_id": RecoveryRoute.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": RecoveryRoute.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": RecoveryRoute.R144_PARTITION_RULE_ID,
		"actuation_realization_id": RecoveryRoute.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"application_mutation_semantics_id":
		RecoveryRoute.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID,
		"native_contact_solver_coupled": true,
		"bootstrap_application": false,
		"pre_solver_direct_body_impulse_write_count": 0,
		"body_impulse_write_count": 0,
		"adapter_side_discrete_staging_event_count": 0,
		"predecessor_complete_energy_route_id": RecoveryRoute.R144_COMPLETE_ENERGY_ROUTE_ID,
		"energy_route_id": RecoveryRoute.R148_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RecoveryRoute.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"discrete_staging_complete_energy_profile_selected": true,
		"complete_energy_authority_profile_id":
		RecoveryRoute.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"application_provenance_profile_id":
		RecoveryRoute.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID,
		"controller_owner": "walking_bw5r_b",
		"recovery_controller_id": null,
		"stance_controller_id": SELECTED_POLICY_ID,
		"handoff_event_count": 0,
		"walking_actuation_handoff_event_count": 1 if session_local_step == 1 else 0,
		"fallback_controller_active": false,
		"walking_controller_policy_id": SELECTED_POLICY_ID,
		"walking_controller_policy_digest": SELECTED_POLICY_DIGEST,
		"walking_session_id": session_id,
		"walking_session_local_step": session_local_step,
		"controller_step_receipt": controller_receipt.duplicate(true),
		"controller_step_receipt_sha256": controller_receipt_sha,
		"authority_application_receipt": authority_application_receipt.duplicate(true),
		"authority_application_receipt_sha256": authority_sha,
		"maximum_impulse_override_applied": true,
		"published_cap_by_actuator_id": published_cap_by_actuator_id.duplicate(true),
		"authorized_host_cap_by_actuator_id": authorized_host_cap_by_actuator_id.duplicate(true),
		"motor_population_readback": motor_population_readback.duplicate(true),
		"motor_population_readback_sha256": readback_sha,
		"walking_actuation_handoff_receipt": walking_actuation_handoff_receipt.duplicate(true),
		"walking_actuation_handoff_receipt_sha256": handoff_sha,
		"external_intervention_application_count": 0,
		"external_intervention_body_impulse_write_count": 0,
		"external_intervention_retained_separately": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## L13 successor ledger. Unlike the immutable L12 function above, this path
## takes native pre-parse verification as the controller-receipt authority and
## declares Godot's exact binary32 motor-target realization. Every preflight
## predicate is named, evaluated, and retained even when the ledger refuses.
static func walking_ledger_application_intent_v2(
	sdk: Object,
	global_semantic_step: int,
	phase: String,
	session_id: String,
	session_local_step: int,
	portable_step_receipt: Dictionary,
	authority_application_receipt: Dictionary,
	motor_population_readback: Dictionary,
	walking_actuation_handoff_receipt: Dictionary,
	development_policy_id: String = "",
) -> Dictionary:
	var policy := DevelopmentWalkingPolicy.binding_v1(development_policy_id, String(walking_actuation_handoff_receipt.get("evaluation_segment_id", "")))
	if policy.is_empty():
		return _failure("DEVELOPMENT_WALKING_POLICY_LEDGER_SELECTION")
	var native_output: Dictionary = {}
	var native_output_value: Variant = portable_step_receipt.get("native_output")
	if native_output_value is Dictionary:
		native_output = native_output_value
	var actuation: Dictionary = {}
	var actuation_value: Variant = native_output.get("actuation")
	if actuation_value is Dictionary:
		actuation = actuation_value
	var commands: Array = []
	var commands_value: Variant = actuation.get("ordered_commands")
	if commands_value is Array:
		commands = commands_value
	var controller_receipt: Dictionary = {}
	var controller_receipt_value: Variant = actuation.get("receipt")
	if controller_receipt_value is Dictionary:
		controller_receipt = controller_receipt_value
	var applications: Array = []
	var applications_value: Variant = authority_application_receipt.get("ordered_applications")
	if applications_value is Array:
		applications = applications_value
	var readbacks: Array = []
	var readbacks_value: Variant = motor_population_readback.get("ordered_joint_readbacks")
	if readbacks_value is Array:
		readbacks = readbacks_value
	var native_verification: Dictionary = {}
	var native_verification_value: Variant = portable_step_receipt.get(
		"native_step_transport_verification"
	)
	if native_verification_value is Dictionary:
		native_verification = native_verification_value
	var published_cap_by_actuator_id: Dictionary = {}
	var published_cap_value: Variant = walking_actuation_handoff_receipt.get(
		"published_cap_by_actuator_id"
	)
	if published_cap_value is Dictionary:
		published_cap_by_actuator_id = published_cap_value
	var authorized_host_cap_by_actuator_id: Dictionary = {}
	var authorized_cap_value: Variant = walking_actuation_handoff_receipt.get(
		"authorized_host_cap_by_actuator_id"
	)
	if authorized_cap_value is Dictionary:
		authorized_host_cap_by_actuator_id = authorized_cap_value
	var controller_receipt_sha256 := String(actuation.get("receipt_sha256", ""))

	var predicates: Array = []
	var failed_predicate_ids: Array[String] = []
	_append_walking_ledger_predicate_v1(
		predicates, failed_predicate_ids, "input.sdk_present", "identity", sdk != null
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"input.global_semantic_step_positive",
		"identity",
		global_semantic_step > 0
	)
	_append_walking_ledger_predicate_v1(
		predicates, failed_predicate_ids, "input.phase_present", "identity", not phase.is_empty()
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"input.session_id_present",
		"identity",
		not session_id.is_empty()
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"input.session_local_step_positive",
		"identity",
		session_local_step > 0
	)
	for source in [
		["portable_step", portable_step_receipt],
		["authority_application", authority_application_receipt],
		["motor_population", motor_population_readback],
		["walking_handoff", walking_actuation_handoff_receipt],
	]:
		_append_walking_ledger_predicate_v1(
			predicates,
			failed_predicate_ids,
			"identity.%s_has_no_outcome_derived_top_level" % String(source[0]),
			"identity",
			not _has_outcome_derived_top_level_v1(source[1]),
		)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.walking_handoff_valid",
		"identity",
		(
			sdk != null
			and walking_actuation_handoff_receipt_valid_v1(sdk, walking_actuation_handoff_receipt, development_policy_id)
		),
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.native_output_shape",
		"identity",
		native_output_value is Dictionary
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.actuation_shape",
		"identity",
		actuation_value is Dictionary
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.commands_shape",
		"identity",
		commands_value is Array
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.controller_receipt_shape",
		"identity",
		controller_receipt_value is Dictionary
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.applications_shape",
		"identity",
		applications_value is Array
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.readbacks_shape",
		"identity",
		readbacks_value is Array
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.portable_step_ok",
		"identity",
		bool(portable_step_receipt.get("ok", false))
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.selected_policy",
		"identity",
		String(portable_step_receipt.get("controller_policy_id", "")) == policy["policy_id"],
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.portable_step_clock",
		"identity",
		int(portable_step_receipt.get("semantic_step", -1)) == session_local_step,
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.actuation_step_clock",
		"identity",
		int(actuation.get("semantic_step", -1)) == session_local_step,
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.actuation_not_safe_no_actuation",
		"identity",
		not bool(actuation.get("safe_no_actuation", true))
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.native_transport_verification_present",
		"identity",
		native_verification_value is Dictionary
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.native_transport_verification_valid",
		"identity",
		(
			SdkAdapterScript
			. native_step_transport_verification_receipt_valid_v1(
				native_verification,
				policy["policy_id"],
				(
					SdkAdapterScript.DEVELOPMENT_EXTENDED_PREPARATION_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_ZERO_VELOCITY_BRAKE_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_BOUNDED_STOP_VELOCITY_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_STARTUP_VELOCITY_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_REMAINING_SUPPORT_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_REMAINING_SUPPORT_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_SUPPORT_HOLD_POSTURE_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_SUPPORT_HOLD_POSTURE_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_SUPPORT_PROGRESSION_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_SUPPORT_PROGRESSION_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_STANCE_LATCH_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_STANCE_LATCH_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_UPRIGHT_STANCE_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_UPRIGHT_STANCE_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_ABSENT_CONTACT_REFERENCE_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_ABSENT_CONTACT_REFERENCE_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_AIRBORNE_REFERENCE_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_AIRBORNE_REFERENCE_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_WAVE_VELOCITY_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_WAVE_VELOCITY_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_REFERENCE_VELOCITY_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_REFERENCE_VELOCITY_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_SMOOTH_SWING_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_SMOOTH_SWING_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_FEASIBLE_SUPPORT_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_FEASIBLE_SUPPORT_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_FLOOR_SUPPORT_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_FLOOR_SUPPORT_POLICY_ID
					else SdkAdapterScript.DEVELOPMENT_BOUNDED_SUPPORT_RECEIPT_SCHEMA
					if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_BOUNDED_SUPPORT_POLICY_ID
					else SELECTED_CONTROLLER_RECEIPT_SCHEMA
				),
				session_local_step,
				controller_receipt_sha256,
			)
		),
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.adapter_exposed_digest_equals_actuation_digest",
		"identity",
		(
			String(portable_step_receipt.get("controller_step_receipt_sha256", ""))
			== controller_receipt_sha256
		),
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.native_verified_digest_equals_actuation_digest",
		"identity",
		(
			String(native_verification.get("controller_receipt_sha256", ""))
			== controller_receipt_sha256
		),
	)
	if policy["policy_id"] == SdkAdapterScript.DEVELOPMENT_EXTENDED_PREPARATION_POLICY_ID:
		# V56 declares a distinct preparation bound. The decoded receipt must
		# retain that bound as well as the byte-verified native identity.
		var plane: Variant = controller_receipt.get("recovery_support_plane")
		var transfer: Variant = plane.get("measured_support_transfer") if plane is Dictionary else null
		var limit: Variant = transfer.get("maximum_preparation_commands") if transfer is Dictionary else null
		_append_walking_ledger_predicate_v1(predicates, failed_predicate_ids,
			"identity.v56_preparation_limit", "identity",
			typeof(limit) in [TYPE_INT, TYPE_FLOAT] and limit == 360)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.authority_application_schema",
		"identity",
		(
			String(authority_application_receipt.get("schema_version", ""))
			== "sporespore_godot_jolt_full_authority_application_receipt_v1"
		),
	)
	for authority_predicate in [
		["ok", bool(authority_application_receipt.get("ok", false))],
		[
			"step_clock",
			int(authority_application_receipt.get("semantic_step", -1)) == session_local_step,
		],
		[
			"command_count",
			int(authority_application_receipt.get("applied_command_count", -1)) == JOINT_IDS.size(),
		],
		[
			"actuator_order",
			(
				authority_application_receipt.get("ordered_actuator_ids")
				== RecoveryRoute.ORDERED_ACTUATOR_IDS
			),
		],
		[
			"motor_parameters_only",
			bool(authority_application_receipt.get("configured_motor_parameters_only", false)),
		],
		[
			"r69_override_applied",
			bool(authority_application_receipt.get("maximum_impulse_override_applied", false)),
		],
		[
			"r69_cap_map",
			(
				authority_application_receipt.get("authorized_maximum_impulse_by_actuator_id")
				== authorized_host_cap_by_actuator_id
			),
		],
	]:
		_append_walking_ledger_predicate_v1(
			predicates,
			failed_predicate_ids,
			"identity.authority_application_%s" % String(authority_predicate[0]),
			"identity",
			bool(authority_predicate[1]),
		)
	for readback_predicate in [
		["ok", bool(motor_population_readback.get("ok", false))],
		[
			"global_step_clock",
			int(motor_population_readback.get("global_semantic_step", -1)) == global_semantic_step,
		],
		[
			"motors_enabled",
			bool(motor_population_readback.get("expected_motor_enabled", false)),
		],
		[
			"enabled_count",
			int(motor_population_readback.get("motor_enabled_count", -1)) == JOINT_IDS.size(),
		],
	]:
		_append_walking_ledger_predicate_v1(
			predicates,
			failed_predicate_ids,
			"identity.motor_population_%s" % String(readback_predicate[0]),
			"identity",
			bool(readback_predicate[1]),
		)
	for cardinality_predicate in [
		["commands", commands.size() == JOINT_IDS.size()],
		["applications", applications.size() == JOINT_IDS.size()],
		["readbacks", readbacks.size() == JOINT_IDS.size()],
		["published_caps", published_cap_by_actuator_id.size() == JOINT_IDS.size()],
		["authorized_caps", authorized_host_cap_by_actuator_id.size() == JOINT_IDS.size()],
	]:
		_append_walking_ledger_predicate_v1(
			predicates,
			failed_predicate_ids,
			"identity.%s_cardinality" % String(cardinality_predicate[0]),
			"identity",
			bool(cardinality_predicate[1]),
		)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.handoff_session",
		"identity",
		String(walking_actuation_handoff_receipt.get("walking_session_id", "")) == session_id,
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"identity.handoff_global_step",
		"identity",
		(
			int(walking_actuation_handoff_receipt.get("global_semantic_step", -1))
			== global_semantic_step - session_local_step + 1
		),
	)
	var identity_predicate_count := predicates.size()

	var host_target_projection := walking_host_target_projection_receipt_v1(
		sdk,
		commands,
		applications,
		readbacks,
		published_cap_by_actuator_id,
		authorized_host_cap_by_actuator_id,
	)
	_append_walking_ledger_predicate_v1(
		predicates,
		failed_predicate_ids,
		"row.host_target_projection_receipt_valid",
		"row",
		walking_host_target_projection_receipt_valid_v1(sdk, host_target_projection),
	)
	var projection_rows: Array = []
	var projection_rows_value: Variant = host_target_projection.get("ordered_target_projections")
	if projection_rows_value is Array:
		projection_rows = projection_rows_value
	for index in range(JOINT_IDS.size()):
		var row: Dictionary = {}
		if index < projection_rows.size() and projection_rows[index] is Dictionary:
			row = projection_rows[index]
		var actuator_id := String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
		for row_predicate in [
			["shape", _keys_exact_v1(row, WALKING_HOST_TARGET_PROJECTION_ROW_KEYS)],
			["actuator_identity", String(row.get("actuator_id", "")) == actuator_id],
			["joint_identity", String(row.get("joint_id", "")) == String(JOINT_IDS[index])],
			["controller_request_finite", bool(row.get("controller_request_finite", false))],
			["binary32_projection_finite", bool(row.get("binary32_projection_finite", false))],
			[
				"application_request_preserved_exactly",
				bool(row.get("application_request_preserved_exactly", false)),
			],
			[
				"application_readback_equals_projection_exactly",
				bool(row.get("application_readback_equals_projection_exactly", false)),
			],
			[
				"population_readback_equals_projection_exactly",
				bool(row.get("population_readback_equals_projection_exactly", false)),
			],
			[
				"application_population_readbacks_equal_exactly",
				bool(row.get("application_population_readbacks_equal_exactly", false)),
			],
			["r69_host_cap_exact", bool(row.get("r69_host_cap_exact", false))],
		]:
			_append_walking_ledger_predicate_v1(
				predicates,
				failed_predicate_ids,
				"row.%d.%s" % [index, String(row_predicate[0])],
				"row",
				bool(row_predicate[1]),
				actuator_id,
				index,
			)
	var row_predicate_count := predicates.size() - identity_predicate_count
	var predicate_receipt := {
		"schema_version": DevelopmentWalkingPolicy.schema_v1(WALKING_LEDGER_PREDICATE_RECEIPT_SCHEMA, "predicates", policy),
		"gate_id": GATE_ID,
		"ok": failed_predicate_ids.is_empty(),
		"all_predicates_evaluated": true,
		"generic_failure_without_predicate_detail": false,
		"identity_predicate_count": identity_predicate_count,
		"row_predicate_count": row_predicate_count,
		"predicate_count": predicates.size(),
		"passed_predicate_count": predicates.size() - failed_predicate_ids.size(),
		"failed_predicate_count": failed_predicate_ids.size(),
		"failed_predicate_ids": failed_predicate_ids.duplicate(),
		"ordered_predicates": predicates.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	predicate_receipt["payload_sha256"] = _sha256_v1(sdk, predicate_receipt)
	if not failed_predicate_ids.is_empty():
		return {
			"schema_version": DevelopmentWalkingPolicy.schema_v1(WALKING_LEDGER_APPLICATION_SCHEMA_V2, "application", policy),
			"gate_id": GATE_ID,
			"ok": false,
			"failure_code": "QSDK_R10F_L13_WALKING_LEDGER_PREDICATES_FAILED",
			"failed_predicate_ids": failed_predicate_ids.duplicate(),
			"portable_step_receipt": portable_step_receipt.duplicate(true),
			"native_step_transport_verification": native_verification.duplicate(true),
			"controller_step_receipt": controller_receipt.duplicate(true),
			"authority_application_receipt": authority_application_receipt.duplicate(true),
			"motor_population_readback": motor_population_readback.duplicate(true),
			"walking_actuation_handoff_receipt": walking_actuation_handoff_receipt.duplicate(true),
			"host_target_projection_receipt": host_target_projection.duplicate(true),
			"walking_ledger_predicate_receipt": predicate_receipt.duplicate(true),
			"generic_failure_without_predicate_detail": false,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": bool(authority_application_receipt.get("ok", false)),
			"physical_acceptance_authority": false,
			"release_authority": false,
		}

	var controller_receipt_sha := String(native_verification["controller_receipt_sha256"])
	var native_verification_sha := String(native_verification["payload_sha256"])
	var host_target_projection_sha := String(host_target_projection["payload_sha256"])
	var predicate_receipt_sha := String(predicate_receipt["payload_sha256"])
	var authority_sha := _sha256_v1(sdk, authority_application_receipt)
	var readback_sha := _sha256_v1(sdk, motor_population_readback)
	var handoff_sha := String(walking_actuation_handoff_receipt.get("payload_sha256", ""))
	var command_record := {
		"schema_version": DevelopmentWalkingPolicy.schema_v1("sporespore_qsdk_r10f_l13_bw5r_b_motor_command_binding_v2", "command", policy),
		"selected_policy_id": policy["policy_id"],
		"selected_policy_digest": policy["policy_digest"],
		"session_id": session_id,
		"session_local_step": session_local_step,
		"global_semantic_step": global_semantic_step,
		"phase": phase,
		"ordered_commands": commands.duplicate(true),
		"controller_step_receipt_sha256": controller_receipt_sha,
		"controller_step_receipt_digest_authority": "native_preparse_transport_verification",
		"native_step_transport_verification_sha256": native_verification_sha,
		"authority_application_receipt_sha256": authority_sha,
		"host_target_projection_receipt_sha256": host_target_projection_sha,
		"motor_population_readback_sha256": readback_sha,
		"walking_actuation_handoff_receipt_sha256": handoff_sha,
		"walking_ledger_predicate_receipt_sha256": predicate_receipt_sha,
		"published_cap_by_actuator_id": published_cap_by_actuator_id.duplicate(true),
		"authorized_host_cap_by_actuator_id": authorized_host_cap_by_actuator_id.duplicate(true),
	}
	var command_sha := _sha256_v1(sdk, command_record)
	if (
		command_sha.is_empty()
		or authority_sha.is_empty()
		or readback_sha.is_empty()
		or not _digest_valid_v1(controller_receipt_sha)
		or not _digest_valid_v1(native_verification_sha)
		or not _digest_valid_v1(host_target_projection_sha)
		or not _digest_valid_v1(predicate_receipt_sha)
		or not _digest_valid_v1(handoff_sha)
	):
		var digest_failure_ids: Array[String] = ["identity.success_payload_digests_valid"]
		return {
			"schema_version": DevelopmentWalkingPolicy.schema_v1(WALKING_LEDGER_APPLICATION_SCHEMA_V2, "application", policy),
			"gate_id": GATE_ID,
			"ok": false,
			"failure_code": "QSDK_R10F_L13_WALKING_LEDGER_DIGEST_INVALID",
			"failed_predicate_ids": digest_failure_ids,
			"portable_step_receipt": portable_step_receipt.duplicate(true),
			"native_step_transport_verification": native_verification.duplicate(true),
			"controller_step_receipt": controller_receipt.duplicate(true),
			"authority_application_receipt": authority_application_receipt.duplicate(true),
			"motor_population_readback": motor_population_readback.duplicate(true),
			"walking_actuation_handoff_receipt": walking_actuation_handoff_receipt.duplicate(true),
			"host_target_projection_receipt": host_target_projection.duplicate(true),
			"walking_ledger_predicate_receipt": predicate_receipt.duplicate(true),
			"generic_failure_without_predicate_detail": false,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": true,
			"physical_acceptance_authority": false,
			"release_authority": false,
		}
	return {
		"schema_version": DevelopmentWalkingPolicy.schema_v1(WALKING_LEDGER_APPLICATION_SCHEMA_V2, "application", policy),
		"ok": true,
		"semantic_step": global_semantic_step,
		"source_control_semantic_step": global_semantic_step - 1,
		"phase": phase,
		"command_id": ("development_swing_end_walking:%s:%d" if policy["development"] else "qsdk_r10f_bw5r_b:%s:%d") % [session_id, session_local_step],
		"command_sha256": command_sha,
		"zero_command": false,
		"no_actuation_requested": false,
		"motor_enabled_count": JOINT_IDS.size(),
		"native_joint_motors_disabled": false,
		"actuator_mapping_id": RecoveryRoute.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": RecoveryRoute.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": RecoveryRoute.R144_PARTITION_RULE_ID,
		"actuation_realization_id": RecoveryRoute.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"application_mutation_semantics_id":
		RecoveryRoute.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID,
		"native_contact_solver_coupled": true,
		"bootstrap_application": false,
		"pre_solver_direct_body_impulse_write_count": 0,
		"body_impulse_write_count": 0,
		"adapter_side_discrete_staging_event_count": 0,
		"predecessor_complete_energy_route_id": RecoveryRoute.R144_COMPLETE_ENERGY_ROUTE_ID,
		"energy_route_id": RecoveryRoute.R148_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RecoveryRoute.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"discrete_staging_complete_energy_profile_selected": true,
		"complete_energy_authority_profile_id":
		RecoveryRoute.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"application_provenance_profile_id":
		RecoveryRoute.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID,
		"controller_owner": "stance" if policy["development"] else "walking_bw5r_b",
		"recovery_controller_id": null,
		"stance_controller_id": policy["policy_id"],
		"handoff_event_count": 0,
		"walking_actuation_handoff_event_count": 1 if session_local_step == 1 else 0,
		"fallback_controller_active": false,
		"walking_controller_policy_id": policy["policy_id"],
		"walking_controller_policy_digest": policy["policy_digest"],
		"walking_session_id": session_id,
		"walking_session_local_step": session_local_step,
		"controller_step_receipt": controller_receipt.duplicate(true),
		"controller_step_receipt_sha256": controller_receipt_sha,
		"controller_step_receipt_digest_authority": "native_preparse_transport_verification",
		"post_parse_controller_receipt_rehash_used": false,
		"native_step_transport_verification": native_verification.duplicate(true),
		"native_step_transport_verification_sha256": native_verification_sha,
		"authority_application_receipt": authority_application_receipt.duplicate(true),
		"authority_application_receipt_sha256": authority_sha,
		"host_target_projection_receipt": host_target_projection.duplicate(true),
		"host_target_projection_receipt_sha256": host_target_projection_sha,
		"walking_ledger_predicate_receipt": predicate_receipt.duplicate(true),
		"walking_ledger_predicate_receipt_sha256": predicate_receipt_sha,
		"maximum_impulse_override_applied": true,
		"published_cap_by_actuator_id": published_cap_by_actuator_id.duplicate(true),
		"authorized_host_cap_by_actuator_id": authorized_host_cap_by_actuator_id.duplicate(true),
		"motor_population_readback": motor_population_readback.duplicate(true),
		"motor_population_readback_sha256": readback_sha,
		"walking_actuation_handoff_receipt": walking_actuation_handoff_receipt.duplicate(true),
		"walking_actuation_handoff_receipt_sha256": handoff_sha,
		"external_intervention_application_count": 0,
		"external_intervention_body_impulse_write_count": 0,
		"external_intervention_retained_separately": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _append_walking_ledger_predicate_v1(
	predicates: Array,
	failed_predicate_ids: Array[String],
	predicate_id: String,
	scope: String,
	passed: bool,
	actuator_id: String = "",
	row_index: int = -1,
) -> void:
	(
		predicates
		. append(
			{
				"predicate_id": predicate_id,
				"scope": scope,
				"passed": passed,
				"actuator_id": actuator_id,
				"row_index": row_index,
			}
		)
	)
	if not passed:
		failed_predicate_ids.append(predicate_id)


## Pure no-actuation projection for the kick-effect, passive-prone, and first
## recovery observation boundaries. `pre_solver_direct_body_impulse_write_count`
## describes controller actuation only. A kick, when present, is retained under
## the explicitly separate external-intervention fields and never smuggled into
## the native motor-work partition.
static func no_actuation_ledger_application_intent_v1(
	sdk: Object,
	global_semantic_step: int,
	phase: String,
	controller_owner: String,
	recovery_controller_id: Variant,
	zero_command: bool,
	owner_source_receipt: Dictionary,
	motor_population_readback: Dictionary,
	interaction_receipt: Dictionary = {},
	expected_controller_id: String = RECOVERY_CONTROLLER_ID,
) -> Dictionary:
	var owner_profile := CanonicalOwnershipL15.profile_v1(expected_controller_id)
	if owner_profile.is_empty():
		return _failure("DEVELOPMENT_RECOVERY_OWNER_PROFILE_UNKNOWN")
	if (
		sdk == null
		or global_semantic_step <= 1
		or phase.is_empty()
		or controller_owner not in ["none", owner_profile["owner"]]
		or owner_source_receipt.is_empty()
		or _has_outcome_derived_top_level_v1(owner_source_receipt)
		or _has_outcome_derived_top_level_v1(motor_population_readback)
		or _has_outcome_derived_top_level_v1(interaction_receipt)
		or (controller_owner == owner_profile["owner"] and recovery_controller_id != expected_controller_id)
		or (controller_owner == "none" and recovery_controller_id != null)
	):
		return _failure("QSDK_R10F_NO_ACTUATION_LEDGER_INPUT_INVALID")
	var readbacks_value: Variant = motor_population_readback.get("ordered_joint_readbacks")
	if (
		not (readbacks_value is Array)
		or not bool(motor_population_readback.get("ok", false))
		or int(motor_population_readback.get("global_semantic_step", -1)) != global_semantic_step
		or bool(motor_population_readback.get("expected_motor_enabled", true))
		or int(motor_population_readback.get("motor_enabled_count", -1)) != 0
		or int(motor_population_readback.get("zero_target_velocity_count", -1)) != JOINT_IDS.size()
		or (readbacks_value as Array).size() != JOINT_IDS.size()
	):
		return _failure("QSDK_R10F_NO_ACTUATION_MOTOR_POPULATION_INVALID")
	for index in range(JOINT_IDS.size()):
		var row_value: Variant = (readbacks_value as Array)[index]
		if not (row_value is Dictionary):
			return _failure("QSDK_R10F_NO_ACTUATION_MOTOR_ROW_SHAPE_INVALID:%d" % index)
		var row: Dictionary = row_value
		if (
			String(row.get("actuator_id", "")) != String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
			or String(row.get("joint_id", "")) != String(JOINT_IDS[index])
			or bool(row.get("motor_enabled", true))
			or float(row.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or not is_finite(float(row.get("motor_maximum_impulse_nms", NAN)))
			or float(row.get("motor_maximum_impulse_nms", NAN)) <= 0.0
		):
			return _failure("QSDK_R10F_NO_ACTUATION_MOTOR_ROW_INVALID:%d" % index)
	var external_count := 0
	var interaction_sha: Variant = null
	if not interaction_receipt.is_empty():
		if (
			not EnergyInitializer.interaction_receipt_valid_v1(sdk, interaction_receipt)
			or (
				int(interaction_receipt.get("completed_effect_global_step", -1))
				!= global_semantic_step
			)
		):
			return _failure("QSDK_R10F_NO_ACTUATION_INTERACTION_INVALID")
		external_count = int(interaction_receipt["application_count"])
		interaction_sha = String(interaction_receipt["payload_sha256"])
	var owner_sha := _sha256_v1(sdk, owner_source_receipt)
	var readback_sha := _sha256_v1(sdk, motor_population_readback)
	var command_record := {
		"schema_version": "sporespore_qsdk_r10f_no_actuation_command_binding_v1",
		"global_semantic_step": global_semantic_step,
		"phase": phase,
		"controller_owner": controller_owner,
		"recovery_controller_id": recovery_controller_id,
		"zero_command": zero_command,
		"owner_source_receipt_sha256": owner_sha,
		"motor_population_readback_sha256": readback_sha,
		"external_intervention_receipt_sha256": interaction_sha,
		"external_intervention_application_count": external_count,
	}
	var command_sha := _sha256_v1(sdk, command_record)
	if owner_sha.is_empty() or readback_sha.is_empty() or command_sha.is_empty():
		return _failure("QSDK_R10F_NO_ACTUATION_LEDGER_DIGEST_INVALID")
	return {
		"schema_version": owner_profile["source_schema"],
		"ok": true,
		"semantic_step": global_semantic_step,
		"source_control_semantic_step": global_semantic_step - 1,
		"phase": phase,
		"command_id":
		"qsdk_r10f_no_actuation:%s:%s:%d" % [controller_owner, phase, global_semantic_step],
		"command_sha256": command_sha,
		"zero_command": zero_command,
		"no_actuation_requested": true,
		"motor_enabled_count": 0,
		"native_joint_motors_disabled": true,
		"structural_zero_actuator_work": true,
		"actuator_mapping_id": "",
		"work_mapping_id": "",
		"partition_rule_id": RecoveryRoute.R144_PARTITION_RULE_ID,
		"actuation_realization_id": RecoveryRoute.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"application_mutation_semantics_id":
		RecoveryRoute.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID,
		"native_contact_solver_coupled": true,
		"bootstrap_application": false,
		"pre_solver_direct_body_impulse_write_count": 0,
		"body_impulse_write_count": 0,
		"adapter_side_discrete_staging_event_count": 0,
		"predecessor_complete_energy_route_id": RecoveryRoute.R144_COMPLETE_ENERGY_ROUTE_ID,
		"energy_route_id": RecoveryRoute.R148_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RecoveryRoute.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"discrete_staging_complete_energy_profile_selected": true,
		"complete_energy_authority_profile_id":
		RecoveryRoute.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"application_provenance_profile_id":
		RecoveryRoute.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID,
		"controller_owner": controller_owner,
		"recovery_controller_id": recovery_controller_id,
		"stance_controller_id": null,
		"handoff_event_count": 0,
		"fallback_controller_active": false,
		"owner_source_receipt": owner_source_receipt.duplicate(true),
		"owner_source_receipt_sha256": owner_sha,
		"motor_population_readback": motor_population_readback.duplicate(true),
		"motor_population_readback_sha256": readback_sha,
		"external_intervention_receipt":
		interaction_receipt.duplicate(true) if not interaction_receipt.is_empty() else null,
		"external_intervention_receipt_sha256": interaction_sha,
		"external_intervention_application_count": external_count,
		"external_intervention_body_impulse_write_count": external_count,
		"external_intervention_retained_separately": true,
		"kick_work_included_in_recovery_epoch_ledger": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"force_aware_recovery_used": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## L15 is opt-in; every old caller retains the unchanged v1 application.
## This delegates all motor/command validation to that actual producer first.
static func no_actuation_ledger_application_intent_v2(
	sdk: Object,
	global_semantic_step: int,
	phase: String,
	controller_owner: String,
	recovery_controller_id: Variant,
	zero_command: bool,
	owner_source_receipt: Dictionary,
	motor_population_readback: Dictionary,
	source_memory: Dictionary,
	interaction_receipt: Dictionary = {},
	expected_controller_id: String = RECOVERY_CONTROLLER_ID,
) -> Dictionary:
	var source := no_actuation_ledger_application_intent_v1(
		sdk,
		global_semantic_step,
		phase,
		controller_owner,
		recovery_controller_id,
		zero_command,
		owner_source_receipt,
		motor_population_readback,
		interaction_receipt,
		expected_controller_id,
	)
	if source.get("ok") != true:
		return source
	return CanonicalOwnershipL15.build_v1(sdk, source, source_memory, expected_controller_id)


func configure_all_motors_v1(
	enabled: bool,
	global_semantic_step: int,
	reason: String,
) -> Dictionary:
	if _binding.is_empty() or global_semantic_step < 0 or reason.is_empty():
		return _failure("QSDK_R10F_LOCOMOTION_MOTOR_CONFIGURATION_INPUT_INVALID")
	var ordered_receipts: Array = []
	for joint_id in JOINT_IDS:
		var joint: HingeJoint3D = (_binding["joint_nodes"] as Dictionary)[joint_id]
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
		joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, enabled)
		(
			ordered_receipts
			. append(
				{
					"joint_id": joint_id,
					"motor_enabled": joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
					"motor_target_velocity_rad_s":
					float(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY)),
				}
			)
		)
	for row in ordered_receipts:
		if (
			bool(row["motor_enabled"]) != enabled
			or float(row["motor_target_velocity_rad_s"]) != 0.0
		):
			return _failure("QSDK_R10F_LOCOMOTION_MOTOR_CONFIGURATION_READBACK_INVALID")
	return {
		"schema_version": MOTOR_CONFIGURATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_semantic_step,
		"reason": reason,
		"motor_enabled": enabled,
		"ordered_joint_receipts": ordered_receipts,
		"motor_configuration_write_count": JOINT_IDS.size() * 2,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func finish_walking_session_v1() -> Dictionary:
	if not _started or _shutdown or _adapter == null:
		return _failure("QSDK_R10F_LOCOMOTION_SESSION_NOT_ACTIVE")
	var summary := _adapter.summary()
	var shutdown_receipt := _adapter.shutdown()
	_shutdown = true
	if not bool(shutdown_receipt.get("ok", false)):
		return _failure("QSDK_R10F_LOCOMOTION_SESSION_SHUTDOWN_FAILED")
	return {
		"schema_version": "sporespore_qsdk_r10f_recovery_native_locomotion_session_completion_v1",
		"gate_id": GATE_ID,
		"ok": bool(summary.get("ok", false)),
		"failure_code": String(summary.get("failure_code", "")),
		"segment_id": _segment_id,
		"session_id": _session_id,
		"adapter_summary": summary,
		"adapter_shutdown_receipt": shutdown_receipt,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _build_live_binding_v1(
	model: Dictionary,
	model_instance_id: String,
) -> Dictionary:
	var body_nodes_value: Variant = model.get("body_nodes")
	var joint_nodes_value: Variant = model.get("joint_nodes")
	var joint_states_value: Variant = model.get("joint_states")
	var floor_value: Variant = model.get("floor")
	var blueprint_value: Variant = model.get("blueprint")
	if (
		not (body_nodes_value is Dictionary)
		or not (joint_nodes_value is Dictionary)
		or not (joint_states_value is Dictionary)
		or not (floor_value is StaticBody3D)
		or not (blueprint_value is Dictionary)
		or not _recovery_blueprint_exact_v1(blueprint_value)
	):
		return _failure("QSDK_R10F_LOCOMOTION_LIVE_MODEL_SHAPE_INVALID")
	var body_nodes: Dictionary = body_nodes_value
	var joint_nodes: Dictionary = joint_nodes_value
	var source_joint_states: Dictionary = joint_states_value
	if (
		body_nodes.size() != BODY_IDS.size()
		or joint_nodes.size() != JOINT_IDS.size()
		or source_joint_states.size() != JOINT_IDS.size()
	):
		return _failure("QSDK_R10F_LOCOMOTION_LIVE_MODEL_CARDINALITY_INVALID")
	var instance_id_by_node_id: Dictionary = {}
	for body_id in BODY_IDS:
		var body_value: Variant = body_nodes.get(body_id)
		if not (body_value is RigidBody3D):
			return _failure("QSDK_R10F_LOCOMOTION_BODY_NODE_INVALID:%s" % body_id)
		var body: RigidBody3D = body_value
		if (
			String(body.get_meta("lab_body_id", "")) != body_id
			or not body.has_method("has_semantic_contact")
		):
			return _failure("QSDK_R10F_LOCOMOTION_BODY_IDENTITY_INVALID:%s" % body_id)
		instance_id_by_node_id["body:%s" % body_id] = int(body.get_instance_id())
	for joint_id in JOINT_IDS:
		var joint_value: Variant = joint_nodes.get(joint_id)
		var state_value: Variant = source_joint_states.get(joint_id)
		if not (joint_value is HingeJoint3D) or not (state_value is Dictionary):
			return _failure("QSDK_R10F_LOCOMOTION_JOINT_NODE_INVALID:%s" % joint_id)
		var state: Dictionary = state_value
		if (
			state.get("joint") != joint_value
			or not (state.get("parent") is RigidBody3D)
			or not (state.get("child") is RigidBody3D)
			or state.get("axis_parent_local") != Vector3.BACK
		):
			return _failure("QSDK_R10F_LOCOMOTION_JOINT_BINDING_INVALID:%s" % joint_id)
		instance_id_by_node_id["joint:%s" % joint_id] = int(
			(joint_value as HingeJoint3D).get_instance_id()
		)
	var limbs: Array = []
	var joint_state_by_legacy_id: Dictionary = {}
	for limb_id in LIMB_ORDER:
		var upper: RigidBody3D = body_nodes["%s_upper" % limb_id]
		var distal: RigidBody3D = body_nodes["%s_distal" % limb_id]
		var hip := _legacy_joint_state_v1(
			source_joint_states["%s_hip" % limb_id],
			"%s.hip_pitch" % limb_id,
			"hip_pitch",
		)
		var knee := _legacy_joint_state_v1(
			source_joint_states["%s_knee" % limb_id],
			"%s.knee_pitch" % limb_id,
			"knee_pitch",
		)
		joint_state_by_legacy_id[hip["joint_id"]] = hip
		joint_state_by_legacy_id[knee["joint_id"]] = knee
		(
			limbs
			. append(
				{
					"limb_id": limb_id,
					"upper": upper,
					"foot": distal,
					"joint_states": [hip, knee],
				}
			)
		)
	return {
		"schema_version": BINDING_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"facade_id": FACADE_ID,
		"model_instance_id": model_instance_id,
		"torso": body_nodes["torso"],
		"floor": floor_value,
		"limbs": limbs,
		"body_nodes": body_nodes,
		"joint_nodes": joint_nodes,
		"joint_state_by_legacy_id": joint_state_by_legacy_id,
		"ordered_same_body_node_ids": SAME_BODY_NODE_IDENTITY.duplicate(),
		"instance_id_by_node_id": instance_id_by_node_id,
		"same_body_node_identity_count": instance_id_by_node_id.size(),
		"body_population_rebuilt": false,
		"joint_population_rebuilt": false,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _legacy_joint_state_v1(
	source: Dictionary,
	legacy_joint_id: String,
	role: String,
) -> Dictionary:
	return {
		"joint_id": legacy_joint_id,
		"role": role,
		"parent": source["parent"],
		"child": source["child"],
		"joint": source["joint"],
		"rest_relative_basis": Basis.IDENTITY,
		"axis_parent_local": Vector3.BACK,
		"anchor_parent_local": source["anchor_parent_local"],
		"anchor_child_local": source["anchor_child_local"],
	}


static func _recovery_blueprint_exact_v1(blueprint: Dictionary) -> bool:
	if (
		(
			String(blueprint.get("schema_version", ""))
			!= "sporespore_qsdk_r24d57_godot_recovery_world_blueprint_v1"
		)
		or not bool(blueprint.get("ok", false))
		or int(blueprint.get("model_construction_count", -1)) != 0
		or int(blueprint.get("world_attempt_count", -1)) != 0
		or int(blueprint.get("world_build_count", -1)) != 0
		or int(blueprint.get("solver_step_count", -1)) != 0
		or bool(blueprint.get("physics_state_modified", true))
	):
		return false
	var body_by_id_value: Variant = blueprint.get("body_by_id")
	var joint_by_id_value: Variant = blueprint.get("joint_by_id")
	if not (body_by_id_value is Dictionary) or not (joint_by_id_value is Dictionary):
		return false
	var body_by_id: Dictionary = body_by_id_value
	var joint_by_id: Dictionary = joint_by_id_value
	if body_by_id.size() != BODY_IDS.size() or joint_by_id.size() != JOINT_IDS.size():
		return false
	for body_id in BODY_IDS:
		var body_value: Variant = body_by_id.get(body_id)
		if not (body_value is Dictionary):
			return false
		var collision: Dictionary = (body_value as Dictionary).get("collision", {})
		var expected_kind := "box" if body_id == "torso" else "capsule"
		if String(collision.get("kind", "")) != expected_kind:
			return false
	for joint_id in JOINT_IDS:
		if not (joint_by_id.get(joint_id) is Dictionary):
			return false
	var initializer: Dictionary = blueprint.get("initializer_manifest", {})
	return (
		(
			String(initializer.get("recovery_morphology_id", ""))
			== RecoveryRoute.RECOVERY_MORPHOLOGY_ID
		)
		and String(initializer.get("recovery_descriptor_sha256", "")) == RECOVERY_DESCRIPTOR_SHA256
		and (
			String(initializer.get("recovery_morphology_spec_sha256", ""))
			== RECOVERY_MORPHOLOGY_SPEC_SHA256
		)
		and int(initializer.get("direct_body_initialization_write_count", -1)) == 9
		and int(initializer.get("post_initialization_root_pose_write_count", -1)) == 0
		and int(initializer.get("post_initialization_root_velocity_write_count", -1)) == 0
	)


static func _material_profile_exact_v1(result: Dictionary) -> bool:
	var profile_value: Variant = result.get("profile")
	if not bool(result.get("ok", false)) or not (profile_value is Dictionary):
		return false
	var profile: Dictionary = profile_value
	return (
		String(profile.get("profile_id", "")) == MATERIAL_PROFILE_ID
		and float(profile.get("authored_friction", NAN)) == 1.8
		and float(profile.get("characterized_friction_coefficient", NAN)) == 1.0
		and String(profile.get("solver_policy_id", "")) == String(SOLVER_POLICY["solver_policy_id"])
		and _digest_valid_v1(String(result.get("profile_sha256", "")))
	)


static func _sha256_v1(sdk: Object, value: Variant) -> String:
	if sdk == null:
		return ""
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	var digest := String(receipt.get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _keys_exact_v1(value: Dictionary, required_keys: Array) -> bool:
	if value.size() != required_keys.size():
		return false
	for key_value in required_keys:
		if not value.has(String(key_value)):
			return false
	return true


static func _vector3_array_v1(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]


static func _digest_valid_v1(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _has_outcome_derived_top_level_v1(value: Dictionary) -> bool:
	for key in OUTCOME_DERIVED_KEYS:
		if value.has(key):
			return true
	return false


static func portable_step_failure_v1(step_result: Dictionary) -> Dictionary:
	# Production early return before apply_authority; preserve nested raw failure
	# strings for the worker's existing partial-arm publication projection.
	var result := _failure("QSDK_R10F_LOCOMOTION_PORTABLE_STEP_FAILED",
		{"adapter_failure_code": String(step_result.get("failure_code", ""))})
	result["portable_step_receipt"] = step_result.duplicate(true)
	result["native_step_transport_verification"] = (step_result.get("native_step_transport_verification", {}) as Dictionary).duplicate(true)
	return result


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
