class_name LabQsdkR10eObserverMinimizedUprightPushRecovery
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Zero-world descriptor and evaluator authority for QSDK-R10E.
##
## The physical worker supplies a completed walker summary. Every function here
## validates already-exported data without constructing a Node, reading native
## state, or stepping a solver.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const QuaternionScalarProjectionScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
)
const QuaternionScalarProjectionValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_validation_v2.gd"
)
const ExportedScalarValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/exported_scalar_validation_v1.gd"
)
const ScalarImpulseValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10e_native_impulse_scalar_receipt_validation_v2.gd"
)
const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd"
)
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const R05eSpecScript := preload("res://scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const DESIGN_PATH := "res://sdk/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json"
const DESIGN_RAW_SHA256 := "791dbf01b8720ca0851b5ec4f722ff421baeb9ca277399974db6338aec03e81a"
const R05E_SPEC_PATH := "res://scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd"
const R05E_SPEC_RAW_SHA256 := "eaa4baa51aada1ad885969d58de5ca68e50153cfe07435dacf89cd8b8bcfe527"
const GATE_ID := "QSDK-R10E"
const OFFICIAL_CAMPAIGN_ID := "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
const DEVELOPMENT_GHOST_CAMPAIGN_ID := "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
const GENERATOR_POLICY_ID := "qsdk_r10e_r05e_unopened_supported_start_v1"
const SOURCE_GENERATOR_POLICY_ID := "qsdk_r05e_exact_finite_axis_star_v1"
const GENERATOR_INDEX := 225
const MORPHOLOGY_ID := "qsdk_r05e_axis_star_foot_radius_low_s225"
const R05E_GENERATOR_RECEIPT_SHA256 := "sha256:11c04da70cf613bc5b40a38568de3e45e3658a3f1cf46bfa35cac23ab2713686"
const R05E_PROPORTION_SPEC_SHA256 := "sha256:491074191576f8f784e9cb305321c6fee32e46cf83692c796b6ed3d5467660cd"
const GENERATOR_RECEIPT_SHA256 := "sha256:4aef2888d84b80bf7c0ccba1c6dd1854567ca28d6536a2e2335d49ba1b2247a2"
const SELECTED_CANDIDATE_ID := "BW5R-B"
const SELECTED_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const SELECTED_POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const FIXTURE_SPEC_SHA256 := "sha256:805dc1d69617414a81cdad74f5cf7c6eaf44f0765a3d53c19f8af3f8324f569d"
const CONTROLLER_PROFILE_SHA256 := "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e"
const MATERIAL_PROFILE_SHA256 := "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
const ADAPTER_CAPABILITY_SHA256 := "sha256:b9f59849bb6b22c8837f9c2784345899b95a14b1aa058df53df480da9f7a4a68"
const BASELINE_ARM_ID := "matched_no_impulse_control"
const PUSH_ARM_ID := "lateral_upright_impulse"
const ARM_ORDER := [BASELINE_ARM_ID, PUSH_ARM_ID]
const DEVELOPMENT_GHOST_SEEDS := [40002]
const HELD_OUT_SEEDS := [40101, 40102, 40103]
const ALL_SEEDS := [40002, 40101, 40102, 40103]
const EXPECTED_LIMB_ORDER := ["front_left", "front_right", "rear_left", "rear_right"]
const EXPECTED_WALKING_RECEIPT_KEYS := [
	"bounded_anchor_error",
	"bounded_hinge_axis_error",
	"bounded_joint_only_lateral_stride_steering",
	"bounded_lateral_drift",
	"bounded_tilt",
	"bounded_torso_height",
	"bounded_yaw_drift",
	"contact_gated_evidence_horizon_completed",
	"contact_gating_completed_without_timeout",
	"every_contact_observer_executed",
	"every_limb_completed_evidence_gait_horizon",
	"every_limb_forward_relocation",
	"every_limb_two_contact_cycles",
	"evidence_four_contact_stance",
	"explicit_sdk_controller_session_shutdown",
	"fixture_spec_compiled_before_world_creation",
	"initial_four_contact_stance",
	"initial_perturbation_within_declared_envelope",
	"minimum_evidence_forward_translation",
	"minimum_final_forward_translation",
	"native_sdk_exclusive_post_settle_actuation",
	"no_torso_force_or_impulse_or_velocity_or_transform_command",
	"no_world_reset",
	"one_continuous_world",
	"pinned_jolt_solver_settings",
	"terminal_four_contact_recovery",
	"zero_torso_contact",
]

const TRACE_POLICY_ID := "qsdk_r10e_observer_minimized_upright_push_recovery_trace_v1"
const TRACE_ROW_SCHEMA := "sporespore_qsdk_r10e_observer_minimized_upright_push_recovery_trace_row_v1"
const OBSERVER_INSTRUMENTATION_SCHEMA := "sporespore_qsdk_r10e_deferred_recovery_trace_observer_instrumentation_v1"
const MINIMUM_SDK_STEP_COUNT := 2152
const MAXIMUM_SDK_STEP_COUNT := 2872
const PUSH_MARKER_STEP := 900
const TRACE_SAMPLING_PHASE := "post_physics_for_applied_semantic_step"
const PRE_WINDOW_START := 180
const PRE_WINDOW_END_EXCLUSIVE := 900
const BASELINE_WINDOW_START := 901
const BASELINE_WINDOW_END_EXCLUSIVE := 1621
const FIRST_RECOVERY_START := 901
const LAST_RECOVERY_START := 1260
const WINDOW_STEP_COUNT := 720
const MAXIMUM_TORSO_TILT_RAD := 0.60
const MINIMUM_TORSO_HEIGHT_M := 0.25
const MINIMUM_AIRBORNE_DWELL_STEPS := 3
const MINIMUM_FORWARD_ADVANCE_M := 0.02
const MINIMUM_NATIVE_EFFECT_M_S := 1.0e-4
const VECTOR_TOLERANCE := 1.0e-12
const QUATERNION_NORM_TOLERANCE := 1.0e-9

const TRACE_ROW_KEYS := [
	"cell_id",
	"native_actuation_application_count",
	"observer_physics_state_modified",
	"ordered_foot_contacts_after",
	"ordered_foot_contacts_before",
	"post_physics_observation_complete",
	"push_marker_semantic_step",
	"sampling_phase",
	"schema_version",
	"semantic_step",
	"task_frame_forward_axis_world_unit",
	"task_frame_lateral_axis_world_unit",
	"torso_angular_velocity_world_rad_s",
	"torso_ground_contact",
	"torso_linear_velocity_world_m_s",
	"torso_orientation_projection",
	"torso_orientation_xyzw",
	"torso_position_world_m",
	"torso_tilt_rad",
	"validated_portable_command_count",
]
const OBSERVER_INSTRUMENTATION_KEYS := [
	"additional_solver_step_during_materialization_count",
	"capture_buffer_capacity",
	"capture_buffer_preallocated",
	"captured_row_count",
	"captured_row_count_matches_trace_row_count",
	"downsampled_row_count",
	"live_nested_row_materialization_count",
	"live_quaternion_projection_receipt_count",
	"live_raw_after_capture_count",
	"live_raw_before_capture_count",
	"live_trace_json_or_hash_count",
	"live_trace_row_deep_duplicate_count",
	"materialization_after_final_solver_step_declared_by_caller",
	"missing_measurement_count",
	"physical_acceptance_authority",
	"physics_state_modified",
	"post_solver_materialized_row_count",
	"post_solver_materialized_row_count_matches_trace_row_count",
	"post_solver_projection_receipt_count",
	"post_solver_projection_receipt_count_matches_trace_row_count",
	"schema_version",
	"trace_policy_id",
	"trace_row_count",
	"trace_row_schema",
]

const SELECTED_PROPORTION_SPEC := {
	"schema_version": "sporespore_physical_quadruped_proportion_spec_v1",
	"morphology_id": MORPHOLOGY_ID,
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 0.5142857142857142,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 0.99375,
	"front_limb_mass_scale": 1.0,
}


static func compile_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return _failure("QSDK_R10E_GENERATOR_INDEX_TYPE_INVALID")
	var generator_index := int(generator_index_value)
	if generator_index != GENERATOR_INDEX:
		return _failure("QSDK_R10E_GENERATOR_INDEX_UNKNOWN")
	var source_generation := R05eSpecScript.compile_generation(generator_index)
	if (
		not bool(source_generation.get("ok", false))
		or (
			String(source_generation.get("generator_receipt_sha256", ""))
			!= R05E_GENERATOR_RECEIPT_SHA256
		)
		or (
			String(source_generation.get("proportion_spec_sha256", ""))
			!= R05E_PROPORTION_SPEC_SHA256
		)
	):
		return _failure("QSDK_R10E_R05E_SUPPORTED_GENERATION_INVALID")
	var proportion_spec: Dictionary = source_generation["proportion_spec"]
	if (
		CanonicalJsonScript.sha256(proportion_spec)
		!= CanonicalJsonScript.sha256(SELECTED_PROPORTION_SPEC)
	):
		return _failure("QSDK_R10E_SELECTED_PROPORTION_SPEC_MISMATCH")
	var compiled := ProportionSpecScript.compile(proportion_spec)
	if not bool(compiled.get("ok", false)):
		return _failure("QSDK_R10E_SUPPORTED_PROPORTION_COMPILE_FAILED")
	var material := MaterialProfilesScript.resolve(MATERIAL_PROFILE_ID)
	if (
		not bool(material.get("ok", false))
		or String(material.get("profile_sha256", "")) != MATERIAL_PROFILE_SHA256
	):
		return _failure("QSDK_R10E_SUPPORTED_MATERIAL_PROFILE_INVALID")
	var fixture_candidate: Dictionary = (compiled["fixture_spec"] as Dictionary).duplicate(true)
	fixture_candidate["contact_material"] = (
		((material["profile"] as Dictionary)["body_material"] as Dictionary).duplicate(true)
	)
	var fixture := FixtureSpecScript.compile(fixture_candidate)
	if (
		not bool(fixture.get("ok", false))
		or String(fixture.get("fixture_spec_sha256", "")) != FIXTURE_SPEC_SHA256
	):
		var mismatch := _failure("QSDK_R10E_SUPPORTED_FIXTURE_DIGEST_MISMATCH")
		mismatch["expected_fixture_spec_sha256"] = FIXTURE_SPEC_SHA256
		mismatch["observed_fixture_spec_sha256"] = String(fixture.get("fixture_spec_sha256", ""))
		return mismatch
	var generator_receipt := {
		"schema_version": "sporespore_qsdk_r10e_supported_start_generation_receipt_v1",
		"generator_policy_id": GENERATOR_POLICY_ID,
		"source_gate_id": "QSDK-R05E",
		"source_generator_policy_id": SOURCE_GENERATOR_POLICY_ID,
		"source_generator_receipt_sha256": R05E_GENERATOR_RECEIPT_SHA256,
		"source_proportion_spec_sha256": R05E_PROPORTION_SPEC_SHA256,
		"generator_index": GENERATOR_INDEX,
		"morphology_id": MORPHOLOGY_ID,
		"proportion_spec_sha256": CanonicalJsonScript.sha256(proportion_spec),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}
	var generator_receipt_sha256 := CanonicalJsonScript.sha256(generator_receipt)
	if generator_receipt_sha256 != GENERATOR_RECEIPT_SHA256:
		return _failure("QSDK_R10E_GENERATOR_RECEIPT_DIGEST_MISMATCH")
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": generator_receipt_sha256,
		"proportion_spec": proportion_spec.duplicate(true),
		"proportion_spec_sha256": CanonicalJsonScript.sha256(proportion_spec),
		"fixture_spec_sha256": String(fixture["fixture_spec_sha256"]),
		"material_profile_sha256": String(material["profile_sha256"]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}


static func verify_generation(
	generator_index_value: Variant,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	var generated := compile_generation(generator_index_value)
	if not bool(generated.get("ok", false)):
		return generated
	if (
		expected_generator_receipt_sha256.is_empty()
		or expected_proportion_spec_sha256.is_empty()
		or String(generated["generator_receipt_sha256"]) != expected_generator_receipt_sha256
		or String(generated["proportion_spec_sha256"]) != expected_proportion_spec_sha256
	):
		return _failure("QSDK_R10E_GENERATION_DIGEST_MISMATCH")
	return generated


static func cell_id(arm_id: String, campaign_seed: int) -> String:
	if not ARM_ORDER.has(arm_id) or not ALL_SEEDS.has(campaign_seed):
		return ""
	return "%s_s%d" % ["baseline" if arm_id == BASELINE_ARM_ID else "push", campaign_seed]


static func challenge_options(arm_id: String) -> Dictionary:
	if not ARM_ORDER.has(arm_id):
		return {}
	var push_arm := arm_id == PUSH_ARM_ID
	return {
		"challenge_profile_id":
		(
			"qsdk_r10e_lateral_upright_impulse_v1"
			if push_arm
			else "qsdk_r10e_matched_no_impulse_control_v1"
		),
		"terrain_profile_id": "flat_v1",
		"terrain_tile_length_m": 20.0,
		"terrain_tile_count": 1,
		"terrain_origin_x_m": -10.0,
		"terrain_heights_m": [0.0],
		"push_profile_id": "lateral_impulse_v1" if push_arm else "none",
		"push_step_from_sdk_start": PUSH_MARKER_STEP if push_arm else -1,
		"push_impulse_task_n_s": [0.0, 0.0, 0.25] if push_arm else [0.0, 0.0, 0.0],
		"observation_fault_profile_id": "none",
		"observation_noise_period_steps": 120,
		"base_position_noise_amplitude_m": 0.0,
		"base_linear_velocity_noise_amplitude_m_s": 0.0,
		"joint_position_noise_amplitude_rad": 0.0,
		"joint_velocity_noise_amplitude_rad_s": 0.0,
		"stability_body_position_noise_amplitude_m": 0.0,
		"stability_body_velocity_noise_amplitude_m_s": 0.0,
		"support_point_noise_amplitude_m": 0.0,
	}


static func trace_options(arm_id: String, campaign_seed: int) -> Dictionary:
	var id := cell_id(arm_id, campaign_seed)
	if id.is_empty():
		return {}
	return {
		"cell_id": id,
		"maximum_controller_step_count": MAXIMUM_SDK_STEP_COUNT,
		"minimum_controller_step_count": MINIMUM_SDK_STEP_COUNT,
		"policy_id": TRACE_POLICY_ID,
		"push_marker_semantic_step": PUSH_MARKER_STEP,
		"sampling_phase": TRACE_SAMPLING_PHASE,
		"trace_row_schema_version": TRACE_ROW_SCHEMA,
	}


static func compile_static_contract(arm_id: String, campaign_seed: int) -> Dictionary:
	if not ARM_ORDER.has(arm_id) or not ALL_SEEDS.has(campaign_seed):
		return _failure("QSDK_R10E_CELL_IDENTITY_INVALID")
	if FileAccess.get_sha256(DESIGN_PATH).to_lower() != DESIGN_RAW_SHA256:
		return _failure("QSDK_R10E_DESIGN_DIGEST_MISMATCH")
	if FileAccess.get_sha256(R05E_SPEC_PATH).to_lower() != R05E_SPEC_RAW_SHA256:
		return _failure("QSDK_R10E_R05E_SPEC_DIGEST_MISMATCH")
	var generation := compile_generation(GENERATOR_INDEX)
	var challenge := WaveGaitScript.compile_environment_challenge_options(challenge_options(arm_id))
	var trace := WaveGaitScript.compile_sdk_physical_trace_options(
		trace_options(arm_id, campaign_seed)
	)
	if (
		not bool(generation.get("ok", false))
		or not bool(challenge.get("ok", false))
		or not bool(trace.get("ok", false))
	):
		return _failure("QSDK_R10E_STATIC_CONTRACT_COMPILE_FAILED")
	return {
		"ok": true,
		"failure_code": "",
		"arm_id": arm_id,
		"campaign_seed": campaign_seed,
		"cell_id": cell_id(arm_id, campaign_seed),
		"ledger_scope":
		_ledger_scope_for_seed(
			campaign_seed,
			"zero_world_static_campaign_contract",
		),
		"generation": generation,
		"challenge_options": challenge["environment_challenge_options"],
		"challenge_configuration_sha256": challenge["environment_challenge_configuration_sha256"],
		"trace_options": trace["sdk_physical_trace_options"],
		"trace_configuration_sha256": trace["sdk_physical_trace_configuration_sha256"],
		"design_raw_sha256": "sha256:" + DESIGN_RAW_SHA256,
		"r05e_spec_raw_sha256": "sha256:" + R05E_SPEC_RAW_SHA256,
		"fixture_spec_sha256": FIXTURE_SPEC_SHA256,
		"controller_profile_sha256": CONTROLLER_PROFILE_SHA256,
		"material_profile_sha256": MATERIAL_PROFILE_SHA256,
		"adapter_capability_sha256": ADAPTER_CAPABILITY_SHA256,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func evaluate_world(summary: Dictionary, arm_id: String, campaign_seed: int) -> Dictionary:
	var static_contract := compile_static_contract(arm_id, campaign_seed)
	if not bool(static_contract.get("ok", false)):
		return _invalid_world(
			arm_id,
			campaign_seed,
			String(static_contract.get("failure_code", "QSDK_R10E_STATIC_CONTRACT_INVALID")),
		)
	var expected_cell_id := cell_id(arm_id, campaign_seed)
	var sdk_summary_value: Variant = summary.get("sdk_authority_summary", null)
	var trace_value: Variant = summary.get("sdk_physical_trace", null)
	var walking_receipts_value: Variant = summary.get("walking_gate_receipts", null)
	if (
		typeof(sdk_summary_value) != TYPE_DICTIONARY
		or typeof(trace_value) != TYPE_DICTIONARY
		or typeof(walking_receipts_value) != TYPE_DICTIONARY
	):
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10E_REQUIRED_SUMMARY_OBJECT_MISSING")
	var sdk_summary: Dictionary = sdk_summary_value
	var trace: Dictionary = trace_value
	var walking_receipts: Dictionary = walking_receipts_value
	var sdk_step_count := int(sdk_summary.get("step_count", -1))
	var trace_rows_value: Variant = trace.get("rows", null)
	var instrumentation_value: Variant = trace.get("observer_instrumentation_receipt", null)
	if typeof(trace_rows_value) != TYPE_ARRAY:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10E_TRACE_ROWS_NOT_ARRAY")
	var rows: Array = trace_rows_value
	var instrumentation_validation := _validate_observer_instrumentation(
		instrumentation_value,
		sdk_step_count,
		rows.size(),
	)
	if not bool(instrumentation_validation.get("ok", false)):
		return _invalid_world(
			arm_id,
			campaign_seed,
			String(
				(
					instrumentation_validation
					. get(
						"failure_code",
						"QSDK_R10E_OBSERVER_INSTRUMENTATION_INVALID",
					)
				)
			),
		)
	var summary_failure_code_value: Variant = summary.get("failure_code", null)
	if typeof(summary_failure_code_value) != TYPE_STRING:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10E_SUMMARY_FAILURE_CODE_INVALID")
	var summary_failure_code := String(summary_failure_code_value)
	var walking_summary_consistent := (
		(
			bool(summary.get("ok", false))
			== bool(summary.get("physical_wave_gait_walking_observed", false))
		)
		and (
			summary_failure_code.is_empty()
			if bool(summary.get("ok", false))
			else summary_failure_code == "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED"
		)
	)
	var direct_body_write_count := 0
	for field_value in [
		"direct_torso_force_command_count",
		"direct_torso_impulse_command_count",
		"direct_torso_velocity_command_count",
		"direct_torso_transform_command_count",
	]:
		direct_body_write_count += int(summary.get(String(field_value), -1000000))
	var trace_failures_value: Variant = trace.get("failure_codes", null)
	var walking_receipts_structurally_complete := _walking_receipts_complete(walking_receipts)
	var common_execution_integrity: bool = (
		int(summary.get("world_build_count", -1)) == 1
		and int(summary.get("world_reset_count", -1)) == 0
		and String(summary.get("physics_engine", "")) == "Jolt Physics"
		and int(summary.get("physics_hz", -1)) == 120
		and int(summary.get("solver_velocity_steps", -1)) == 20
		and int(summary.get("solver_position_steps", -1)) == 7
		and int(summary.get("body_count", -1)) == 9
		and int(summary.get("limb_count", -1)) == 4
		and String(summary.get("fixture_spec_sha256", "")) == FIXTURE_SPEC_SHA256
		and String(summary.get("sdk_material_profile_sha256", "")) == MATERIAL_PROFILE_SHA256
		and direct_body_write_count == 0
		and bool(summary.get("sdk_authority_enabled", false))
		and String(summary.get("sdk_authority_scope", "")) == "post_settle_full"
		and String(summary.get("sdk_authority_failure_code", "")).is_empty()
		and bool(sdk_summary.get("ok", false))
		and bool(sdk_summary.get("actuation_authority", false))
		and String(sdk_summary.get("controller_policy_id", "")) == SELECTED_POLICY_ID
		and String(sdk_summary.get("controller_profile_sha256", "")) == CONTROLLER_PROFILE_SHA256
		and String(sdk_summary.get("adapter_capability_sha256", "")) == ADAPTER_CAPABILITY_SHA256
		and sdk_step_count >= MINIMUM_SDK_STEP_COUNT
		and sdk_step_count <= MAXIMUM_SDK_STEP_COUNT
		and (
			sdk_step_count
			== (
				int(summary.get("executed_ticks", -1))
				- int(summary.get("sdk_adapter_start_tick", -1))
			)
		)
		and int(sdk_summary.get("validated_balanced_wave_command_count", -1)) == sdk_step_count * 8
		and int(sdk_summary.get("native_actuation_application_count", -1)) == sdk_step_count * 8
		and int(sdk_summary.get("mismatch_count", -1)) == 0
		and int(sdk_summary.get("safe_no_actuation_count", -1)) == 0
		and int(sdk_summary.get("native_safe_disable_application_count", -1)) == 0
		and int(summary.get("legacy_post_settle_actuation_application_count", -1)) == 0
		and int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0
		and walking_receipts_structurally_complete
		and walking_summary_consistent
		and bool(trace.get("enabled", false))
		and trace.get("options", {}) == static_contract["trace_options"]
		and (
			String(trace.get("configuration_sha256", ""))
			== String(static_contract["trace_configuration_sha256"])
		)
		and int(trace.get("row_count", -1)) == sdk_step_count
		and rows.size() == sdk_step_count
		and typeof(trace_failures_value) == TYPE_ARRAY
		and (trace_failures_value as Array).is_empty()
		and summary.get("environment_challenge_options", {}) == static_contract["challenge_options"]
		and (
			String(summary.get("environment_challenge_configuration_sha256", ""))
			== String(static_contract["challenge_configuration_sha256"])
		)
		and int(summary.get("terrain_shape_count", -1)) == 1
	)
	if not common_execution_integrity:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10E_COMMON_EXECUTION_INTEGRITY_INVALID")
	var perturbation_value: Variant = summary.get("initial_perturbation", null)
	if typeof(perturbation_value) != TYPE_DICTIONARY:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10E_INITIAL_PERTURBATION_MISSING")
	var perturbation: Dictionary = perturbation_value
	if int(perturbation.get("campaign_seed", -1)) != campaign_seed:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10E_INITIAL_PERTURBATION_SEED_MISMATCH")
	var trace_validation := _validate_trace_rows(rows, expected_cell_id)
	if not bool(trace_validation.get("ok", false)):
		return _invalid_world(
			arm_id,
			campaign_seed,
			String(trace_validation.get("failure_code", "QSDK_R10E_TRACE_INVALID")),
		)
	var application_validation := _validate_application(
		summary,
		arm_id,
		rows[PUSH_MARKER_STEP],
	)
	if not bool(application_validation.get("ok", false)):
		return _invalid_world(
			arm_id,
			campaign_seed,
			String(application_validation.get("failure_code", "QSDK_R10E_APPLICATION_INVALID")),
		)
	var pre_window := _evaluate_window(rows, PRE_WINDOW_START, PRE_WINDOW_END_EXCLUSIVE)
	var baseline_window := {}
	var recovery_search := {}
	if arm_id == BASELINE_ARM_ID:
		baseline_window = _evaluate_window(
			rows,
			BASELINE_WINDOW_START,
			BASELINE_WINDOW_END_EXCLUSIVE,
		)
	else:
		recovery_search = _find_first_recovery_window(rows)
	var ordinary_walking_passed := _all_boolean_values_true(walking_receipts)
	var arm_specific_passed := (
		bool(baseline_window.get("passed", false))
		if arm_id == BASELINE_ARM_ID
		else bool(recovery_search.get("found", false))
	)
	var behavior_passed := (
		ordinary_walking_passed and bool(pre_window.get("passed", false)) and arm_specific_passed
	)
	var marker_before: Dictionary = rows[PUSH_MARKER_STEP - 1]
	var marker_after: Dictionary = rows[PUSH_MARKER_STEP]
	return {
		"schema_version": "sporespore_qsdk_r10e_world_evaluation_v1",
		"gate_id": GATE_ID,
		"ledger_scope": _ledger_scope_for_seed(campaign_seed, "physical_world_evaluation"),
		"ok": true,
		"failure_code": "",
		"outcome_complete": true,
		"evidence_valid": true,
		"behavior_passed": behavior_passed,
		"arm_id": arm_id,
		"campaign_seed": campaign_seed,
		"cell_id": expected_cell_id,
		"sdk_step_count": sdk_step_count,
		"trace_row_count": rows.size(),
		"common_execution_integrity": true,
		"observer_instrumentation": instrumentation_validation,
		"walking_receipts_structurally_complete": true,
		"ordinary_walking_passed": ordinary_walking_passed,
		"walking_gate_receipts": walking_receipts.duplicate(true),
		"pre_push_window": pre_window,
		"baseline_post_marker_window": baseline_window,
		"recovery_search": recovery_search,
		"application_receipt": application_validation["receipt"],
		"application_validation": application_validation,
		"initial_perturbation_sha256": CanonicalJsonScript.sha256(perturbation),
		"marker_lateral_axis_world_unit":
		(marker_after["task_frame_lateral_axis_world_unit"] as Array).duplicate(),
		"marker_linear_velocity_before_world_m_s":
		(marker_before["torso_linear_velocity_world_m_s"] as Array).duplicate(),
		"marker_linear_velocity_after_world_m_s":
		(marker_after["torso_linear_velocity_world_m_s"] as Array).duplicate(),
		"evaluation_world_build_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func evaluate_pair(baseline: Dictionary, push: Dictionary) -> Dictionary:
	if (
		String(baseline.get("schema_version", "")) != "sporespore_qsdk_r10e_world_evaluation_v1"
		or String(push.get("schema_version", "")) != "sporespore_qsdk_r10e_world_evaluation_v1"
		or not bool(baseline.get("ok", false))
		or not bool(push.get("ok", false))
		or not bool(baseline.get("outcome_complete", false))
		or not bool(push.get("outcome_complete", false))
		or not bool(baseline.get("evidence_valid", false))
		or not bool(push.get("evidence_valid", false))
		or String(baseline.get("arm_id", "")) != BASELINE_ARM_ID
		or String(push.get("arm_id", "")) != PUSH_ARM_ID
		or int(baseline.get("campaign_seed", -1)) != int(push.get("campaign_seed", -2))
		or not ALL_SEEDS.has(int(baseline.get("campaign_seed", -1)))
		or String(baseline.get("initial_perturbation_sha256", "")).is_empty()
		or (
			String(baseline.get("initial_perturbation_sha256", ""))
			!= String(push.get("initial_perturbation_sha256", ""))
		)
	):
		return _invalid_pair("QSDK_R10E_PAIR_IDENTITY_OR_WORLD_INTEGRITY_INVALID")
	var baseline_axis := _finite_components(
		baseline.get("marker_lateral_axis_world_unit", null),
		3,
	)
	var push_axis := _finite_components(push.get("marker_lateral_axis_world_unit", null), 3)
	var baseline_before := _finite_components(
		baseline.get("marker_linear_velocity_before_world_m_s", null),
		3,
	)
	var baseline_after := _finite_components(
		baseline.get("marker_linear_velocity_after_world_m_s", null),
		3,
	)
	var push_before := _finite_components(
		push.get("marker_linear_velocity_before_world_m_s", null),
		3,
	)
	var push_after := _finite_components(
		push.get("marker_linear_velocity_after_world_m_s", null),
		3,
	)
	if (
		baseline_axis.size() != 3
		or push_axis.size() != 3
		or baseline_before.size() != 3
		or baseline_after.size() != 3
		or push_before.size() != 3
		or push_after.size() != 3
		or baseline_axis != push_axis
	):
		return _invalid_pair("QSDK_R10E_PAIR_MARKER_PROJECTION_INVALID")
	var baseline_jump := _dot(_subtract(baseline_after, baseline_before), baseline_axis)
	var push_jump := _dot(_subtract(push_after, push_before), push_axis)
	var paired_lateral_jump_difference := push_jump - baseline_jump
	var push_application: Dictionary = push.get("application_receipt", {})
	var effect_magnitude := float(push_application.get("effect_magnitude_m_s", NAN))
	var native_effect_confirmed := (
		is_finite(effect_magnitude)
		and effect_magnitude > MINIMUM_NATIVE_EFFECT_M_S
		and is_finite(paired_lateral_jump_difference)
		and paired_lateral_jump_difference > 0.0
	)
	if not native_effect_confirmed:
		return _invalid_pair("QSDK_R10E_PAIRED_NATIVE_EFFECT_NOT_CONFIRMED")
	var behavior_passed := (
		bool(baseline.get("behavior_passed", false)) and bool(push.get("behavior_passed", false))
	)
	return {
		"schema_version": "sporespore_qsdk_r10e_pair_evaluation_v1",
		"gate_id": GATE_ID,
		"ledger_scope":
		_ledger_scope_for_seed(
			int(baseline["campaign_seed"]),
			"zero_world_pair_evaluation",
		),
		"ok": true,
		"failure_code": "",
		"outcome_complete": true,
		"evidence_valid": true,
		"behavior_passed": behavior_passed,
		"campaign_seed": int(baseline["campaign_seed"]),
		"baseline_cell_id": String(baseline["cell_id"]),
		"push_cell_id": String(push["cell_id"]),
		"matched_initial_perturbation": true,
		"baseline_lateral_velocity_jump_m_s": baseline_jump,
		"push_lateral_velocity_jump_m_s": push_jump,
		"paired_lateral_velocity_jump_difference_m_s": paired_lateral_jump_difference,
		"native_effect_magnitude_m_s": effect_magnitude,
		"native_effect_confirmed": true,
		"baseline_behavior_passed": bool(baseline["behavior_passed"]),
		"push_behavior_passed": bool(push["behavior_passed"]),
		"evaluation_world_build_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _validate_trace_rows(rows: Array, expected_cell_id: String) -> Dictionary:
	if rows.size() < MINIMUM_SDK_STEP_COUNT or rows.size() > MAXIMUM_SDK_STEP_COUNT:
		return _failure("QSDK_R10E_TRACE_ROW_COUNT_OUT_OF_RANGE")
	var first_forward: Array = []
	var first_lateral: Array = []
	var projection_receipt_acceptance_count := 0
	var exported_axis_acceptance_count := 0
	var maximum_projection_receipt_absolute_delta := 0.0
	var maximum_exported_axis_norm_delta := 0.0
	for index in range(rows.size()):
		if typeof(rows[index]) != TYPE_DICTIONARY:
			return _failure("QSDK_R10E_TRACE_ROW_NOT_OBJECT")
		var row: Dictionary = rows[index]
		if not _has_exact_keys(row, TRACE_ROW_KEYS):
			return _failure("QSDK_R10E_TRACE_ROW_KEY_SET_MISMATCH")
		if (
			String(row["schema_version"]) != TRACE_ROW_SCHEMA
			or String(row["cell_id"]) != expected_cell_id
			or int(row["semantic_step"]) != index
			or String(row["sampling_phase"]) != TRACE_SAMPLING_PHASE
			or int(row["push_marker_semantic_step"]) != PUSH_MARKER_STEP
			or int(row["validated_portable_command_count"]) != 8
			or int(row["native_actuation_application_count"]) != 8
			or typeof(row["post_physics_observation_complete"]) != TYPE_BOOL
			or not bool(row["post_physics_observation_complete"])
			or typeof(row["observer_physics_state_modified"]) != TYPE_BOOL
			or bool(row["observer_physics_state_modified"])
			or typeof(row["torso_ground_contact"]) != TYPE_BOOL
		):
			return _failure("QSDK_R10E_TRACE_ROW_HEADER_INVALID")
		var position := (
			ExportedScalarValidationScript
			. finite_components_v1(
				row["torso_position_world_m"],
				3,
			)
		)
		var linear_velocity := (
			ExportedScalarValidationScript
			. finite_components_v1(
				row["torso_linear_velocity_world_m_s"],
				3,
			)
		)
		var angular_velocity := (
			ExportedScalarValidationScript
			. finite_components_v1(
				row["torso_angular_velocity_world_rad_s"],
				3,
			)
		)
		var forward := (
			ExportedScalarValidationScript
			. finite_components_v1(
				row["task_frame_forward_axis_world_unit"],
				3,
			)
		)
		var lateral := (
			ExportedScalarValidationScript
			. finite_components_v1(
				row["task_frame_lateral_axis_world_unit"],
				3,
			)
		)
		var orientation_validation := validate_trace_orientation_projection(
			row["torso_orientation_xyzw"],
			row["torso_orientation_projection"],
		)
		var tilt_value: Variant = row["torso_tilt_rad"]
		var tilt := float(tilt_value) if _is_numeric_scalar(tilt_value) else NAN
		var forward_norm_delta := (
			ExportedScalarValidationScript.norm_delta_v1(forward) if forward.size() == 3 else INF
		)
		var lateral_norm_delta := (
			ExportedScalarValidationScript.norm_delta_v1(lateral) if lateral.size() == 3 else INF
		)
		var axis_dot_absolute := (
			ExportedScalarValidationScript.dot_absolute_v1(forward, lateral)
			if forward.size() == 3 and lateral.size() == 3
			else INF
		)
		if (
			position.size() != 3
			or linear_velocity.size() != 3
			or angular_velocity.size() != 3
			or forward.size() != 3
			or lateral.size() != 3
			or not bool(orientation_validation.get("ok", false))
			or not is_finite(tilt)
			or tilt < 0.0
			or forward_norm_delta > VECTOR_TOLERANCE
			or lateral_norm_delta > VECTOR_TOLERANCE
			or axis_dot_absolute > VECTOR_TOLERANCE
		):
			return _failure("QSDK_R10E_TRACE_ROW_KINEMATICS_INVALID")
		projection_receipt_acceptance_count += 1
		exported_axis_acceptance_count += 1
		maximum_projection_receipt_absolute_delta = maxf(
			maximum_projection_receipt_absolute_delta,
			float(orientation_validation.get("projection_receipt_maximum_absolute_delta", 0.0)),
		)
		maximum_exported_axis_norm_delta = maxf(
			maximum_exported_axis_norm_delta,
			maxf(forward_norm_delta, lateral_norm_delta),
		)
		if index == 0:
			first_forward = forward.duplicate()
			first_lateral = lateral.duplicate()
		elif forward != first_forward or lateral != first_lateral:
			return _failure("QSDK_R10E_TRACE_TASK_FRAME_CHANGED")
		for contact_field in ["ordered_foot_contacts_before", "ordered_foot_contacts_after"]:
			var contacts_value: Variant = row[String(contact_field)]
			if typeof(contacts_value) != TYPE_DICTIONARY:
				return _failure("QSDK_R10E_TRACE_CONTACT_OBJECT_MISSING")
			if not _exact_boolean_limb_contacts(contacts_value as Dictionary):
				return _failure("QSDK_R10E_TRACE_CONTACTS_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"validated_row_count": rows.size(),
		"projection_receipt_acceptance_count": projection_receipt_acceptance_count,
		"exported_axis_acceptance_count": exported_axis_acceptance_count,
		"maximum_projection_receipt_absolute_delta": maximum_projection_receipt_absolute_delta,
		"maximum_exported_axis_norm_delta": maximum_exported_axis_norm_delta,
		"trace_policy_id": TRACE_POLICY_ID,
		"trace_row_schema": TRACE_ROW_SCHEMA,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _validate_observer_instrumentation(
	receipt_value: Variant,
	expected_sdk_step_count: int,
	trace_row_count: int,
) -> Dictionary:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return _failure("QSDK_R10E_OBSERVER_INSTRUMENTATION_MISSING")
	var receipt: Dictionary = receipt_value
	if not _has_exact_keys(receipt, OBSERVER_INSTRUMENTATION_KEYS):
		return _failure("QSDK_R10E_OBSERVER_INSTRUMENTATION_KEY_SET_MISMATCH")
	var exact := (
		String(receipt["schema_version"]) == OBSERVER_INSTRUMENTATION_SCHEMA
		and String(receipt["trace_policy_id"]) == TRACE_POLICY_ID
		and String(receipt["trace_row_schema"]) == TRACE_ROW_SCHEMA
		and typeof(receipt["capture_buffer_preallocated"]) == TYPE_BOOL
		and bool(receipt["capture_buffer_preallocated"])
		and int(receipt["capture_buffer_capacity"]) == MAXIMUM_SDK_STEP_COUNT
		and int(receipt["captured_row_count"]) == expected_sdk_step_count
		and int(receipt["live_raw_before_capture_count"]) == expected_sdk_step_count
		and int(receipt["live_raw_after_capture_count"]) == expected_sdk_step_count
		and int(receipt["live_nested_row_materialization_count"]) == 0
		and int(receipt["live_trace_row_deep_duplicate_count"]) == 0
		and int(receipt["live_trace_json_or_hash_count"]) == 0
		and int(receipt["live_quaternion_projection_receipt_count"]) == 0
		and int(receipt["post_solver_materialized_row_count"]) == trace_row_count
		and int(receipt["post_solver_projection_receipt_count"]) == trace_row_count
		and int(receipt["trace_row_count"]) == trace_row_count
		and typeof(receipt["captured_row_count_matches_trace_row_count"]) == TYPE_BOOL
		and bool(receipt["captured_row_count_matches_trace_row_count"])
		and (
			typeof(receipt["post_solver_materialized_row_count_matches_trace_row_count"])
			== TYPE_BOOL
		)
		and bool(receipt["post_solver_materialized_row_count_matches_trace_row_count"])
		and (
			typeof(receipt["post_solver_projection_receipt_count_matches_trace_row_count"])
			== TYPE_BOOL
		)
		and bool(receipt["post_solver_projection_receipt_count_matches_trace_row_count"])
		and (
			typeof(receipt["materialization_after_final_solver_step_declared_by_caller"])
			== TYPE_BOOL
		)
		and bool(receipt["materialization_after_final_solver_step_declared_by_caller"])
		and int(receipt["additional_solver_step_during_materialization_count"]) == 0
		and int(receipt["downsampled_row_count"]) == 0
		and int(receipt["missing_measurement_count"]) == 0
		and typeof(receipt["physics_state_modified"]) == TYPE_BOOL
		and not bool(receipt["physics_state_modified"])
		and typeof(receipt["physical_acceptance_authority"]) == TYPE_BOOL
		and not bool(receipt["physical_acceptance_authority"])
	)
	if not exact:
		return _failure("QSDK_R10E_OBSERVER_INSTRUMENTATION_VALUE_MISMATCH")
	return {
		"ok": true,
		"failure_code": "",
		"receipt": receipt.duplicate(true),
		"live_prohibited_operation_count": 0,
		"post_solver_materialized_row_count": trace_row_count,
		"post_solver_projection_receipt_count": trace_row_count,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _validate_application(
	summary: Dictionary,
	arm_id: String,
	marker_row: Dictionary,
) -> Dictionary:
	var count := int(summary.get("external_push_application_count", -1))
	var receipt_value: Variant = summary.get("external_push_receipt", null)
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return _failure("QSDK_R10E_EXTERNAL_PUSH_RECEIPT_NOT_OBJECT")
	var receipt: Dictionary = receipt_value
	if arm_id == BASELINE_ARM_ID:
		if count != 0 or not receipt.is_empty():
			return _failure("QSDK_R10E_BASELINE_NATIVE_IMPULSE_MISMATCH")
		return {
			"ok": true,
			"failure_code": "",
			"receipt":
			{
				"application_count": 0,
				"effect_sampled": false,
				"effect_magnitude_m_s": 0.0,
			},
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	return (
		ScalarImpulseValidationScript
		. validate_push_receipt(
			receipt,
			count,
			marker_row.get("task_frame_forward_axis_world_unit", null),
			marker_row.get("task_frame_lateral_axis_world_unit", null),
		)
	)


static func _evaluate_window(rows: Array, start: int, end_exclusive: int) -> Dictionary:
	if start < 1 or end_exclusive - start != WINDOW_STEP_COUNT or end_exclusive > rows.size():
		return {
			"passed": false,
			"failure_code": "QSDK_R10E_WINDOW_BOUNDS_INVALID",
			"start_semantic_step": start,
			"end_semantic_step_exclusive": end_exclusive,
		}
	var safe_envelope_passed := true
	var command_application_passed := true
	for step in range(start, end_exclusive):
		var row: Dictionary = rows[step]
		var position := _finite_components(row["torso_position_world_m"], 3)
		safe_envelope_passed = (
			safe_envelope_passed
			and position.size() == 3
			and float(position[1]) >= MINIMUM_TORSO_HEIGHT_M
			and float(row["torso_tilt_rad"]) <= MAXIMUM_TORSO_TILT_RAD
			and not bool(row["torso_ground_contact"])
		)
		command_application_passed = (
			command_application_passed
			and int(row["validated_portable_command_count"]) == 8
			and int(row["native_actuation_application_count"]) == 8
		)
	var contact_cycle_by_limb := {}
	var every_limb_airborne_then_recontact := true
	for limb_id_value in EXPECTED_LIMB_ORDER:
		var limb_id := String(limb_id_value)
		var airborne_dwell := 0
		var longest_airborne_dwell := 0
		var qualifying_recontact_step := -1
		for step in range(start, end_exclusive):
			var row: Dictionary = rows[step]
			var contacts: Dictionary = row["ordered_foot_contacts_after"]
			if not bool(contacts[limb_id]):
				airborne_dwell += 1
				longest_airborne_dwell = maxi(longest_airborne_dwell, airborne_dwell)
			elif airborne_dwell >= MINIMUM_AIRBORNE_DWELL_STEPS:
				qualifying_recontact_step = step
				break
			else:
				airborne_dwell = 0
		var limb_passed := qualifying_recontact_step >= 0
		every_limb_airborne_then_recontact = (every_limb_airborne_then_recontact and limb_passed)
		contact_cycle_by_limb[limb_id] = {
			"passed": limb_passed,
			"longest_airborne_dwell_steps": longest_airborne_dwell,
			"qualifying_recontact_semantic_step": qualifying_recontact_step,
		}
	var origin_row: Dictionary = rows[start - 1]
	var terminal_row: Dictionary = rows[end_exclusive - 1]
	var origin_position := _finite_components(origin_row["torso_position_world_m"], 3)
	var terminal_position := _finite_components(terminal_row["torso_position_world_m"], 3)
	var forward_axis := _finite_components(
		origin_row["task_frame_forward_axis_world_unit"],
		3,
	)
	var forward_advance := _dot(_subtract(terminal_position, origin_position), forward_axis)
	var forward_advance_passed := forward_advance >= MINIMUM_FORWARD_ADVANCE_M
	var passed := (
		safe_envelope_passed
		and command_application_passed
		and every_limb_airborne_then_recontact
		and forward_advance_passed
	)
	return {
		"passed": passed,
		"failure_code": "" if passed else "QSDK_R10E_WINDOW_REQUIREMENT_FAILED",
		"start_semantic_step": start,
		"end_semantic_step_exclusive": end_exclusive,
		"duration_steps": end_exclusive - start,
		"safe_envelope_passed": safe_envelope_passed,
		"command_application_passed": command_application_passed,
		"every_limb_airborne_then_recontact": every_limb_airborne_then_recontact,
		"contact_cycle_by_limb": contact_cycle_by_limb,
		"task_frame_forward_advance_m": forward_advance,
		"minimum_task_frame_forward_advance_m": MINIMUM_FORWARD_ADVANCE_M,
		"forward_advance_passed": forward_advance_passed,
	}


static func evaluate_two_cycle_window_for_zero_world_control(
	rows: Array,
	start: int,
	end_exclusive: int,
) -> Dictionary:
	var result := _evaluate_window(rows, start, end_exclusive)
	result["control_contract_id"] = "qsdk_r10e_prospective_two_cycle_v1"
	result["zero_world_control_only"] = true
	result["physical_acceptance_authority"] = false
	return result


static func _find_first_recovery_window(rows: Array) -> Dictionary:
	for start in range(FIRST_RECOVERY_START, LAST_RECOVERY_START + 1):
		var window := _evaluate_window(rows, start, start + WINDOW_STEP_COUNT)
		if bool(window.get("passed", false)):
			return {
				"found": true,
				"failure_code": "",
				"first_valid_start_semantic_step": start,
				"reentry_latency_steps": start - FIRST_RECOVERY_START,
				"reentry_latency_s": float(start - FIRST_RECOVERY_START) / 120.0,
				"window": window,
			}
	return {
		"found": false,
		"failure_code": "QSDK_R10E_NO_VALID_RECOVERY_WINDOW",
		"first_valid_start_semantic_step": -1,
		"reentry_latency_steps": -1,
		"reentry_latency_s": null,
		"window": {},
	}


static func validate_trace_orientation_projection(
	orientation_value: Variant,
	projection_value: Variant,
) -> Dictionary:
	var diagnostic := QuaternionScalarProjectionScript.diagnose_orientation_xyzw_v1(
		orientation_value
	)
	var receipt_validation := (
		QuaternionScalarProjectionValidationScript
		. validate_projection_receipt_v2(
			projection_value,
			orientation_value,
		)
	)
	var receipt_valid := bool(receipt_validation.get("ok", false))
	var within_length_contract := (
		bool(diagnostic.get("ok", false))
		and diagnostic.get("norm_delta", null) != null
		and float(diagnostic["norm_delta"]) <= QUATERNION_NORM_TOLERANCE
	)
	return {
		"schema_version": "sporespore_qsdk_r10e_trace_orientation_validation_v1",
		"ok": receipt_valid and within_length_contract,
		"failure_code":
		(
			""
			if receipt_valid and within_length_contract
			else "QSDK_R10E_TRACE_ORIENTATION_PROJECTION_INVALID"
		),
		"projection_receipt_valid": receipt_valid,
		"projection_receipt_maximum_absolute_delta":
		float(receipt_validation.get("maximum_absolute_delta", 0.0)),
		"projection_receipt_maximum_representation_allowance":
		float(receipt_validation.get("maximum_representation_allowance", 0.0)),
		"within_length_contract": within_length_contract,
		"quaternion_length_tolerance": QUATERNION_NORM_TOLERANCE,
		"quaternion_length_tolerance_changed": false,
		"whole_dictionary_equality_used": false,
		"orientation_diagnostic": diagnostic,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _walking_receipts_complete(values: Dictionary) -> bool:
	if values.size() != EXPECTED_WALKING_RECEIPT_KEYS.size():
		return false
	for key_value in EXPECTED_WALKING_RECEIPT_KEYS:
		var key := String(key_value)
		if not values.has(key) or typeof(values[key]) != TYPE_BOOL:
			return false
	return true


static func _all_boolean_values_true(values: Dictionary) -> bool:
	if not _walking_receipts_complete(values):
		return false
	for value in values.values():
		if not bool(value):
			return false
	return true


static func _exact_boolean_limb_contacts(contacts: Dictionary) -> bool:
	if not _has_exact_keys(contacts, EXPECTED_LIMB_ORDER):
		return false
	for limb_id_value in EXPECTED_LIMB_ORDER:
		if typeof(contacts[String(limb_id_value)]) != TYPE_BOOL:
			return false
	return true


static func _finite_components(value: Variant, expected_count: int) -> Array:
	return ExportedScalarValidationScript.finite_components_v1(value, expected_count)


static func _subtract(left: Array, right: Array) -> Array:
	if left.size() != 3 or right.size() != 3:
		return []
	return [
		float(left[0]) - float(right[0]),
		float(left[1]) - float(right[1]),
		float(left[2]) - float(right[2]),
	]


static func _dot(left: Array, right: Array) -> float:
	if left.size() != 3 or right.size() != 3:
		return NAN
	return (
		float(left[0]) * float(right[0])
		+ float(left[1]) * float(right[1])
		+ float(left[2]) * float(right[2])
	)


static func _is_numeric_scalar(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _has_exact_keys(values: Dictionary, expected_keys: Array) -> bool:
	if values.size() != expected_keys.size():
		return false
	for key_value in expected_keys:
		if not values.has(String(key_value)):
			return false
	return true


static func _ledger_scope_for_seed(campaign_seed: int, authority_mode: String) -> Dictionary:
	return {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": authority_mode,
		"question_class":
		"development" if DEVELOPMENT_GHOST_SEEDS.has(campaign_seed) else "finite decision",
	}


static func _invalid_world(arm_id: String, campaign_seed: int, code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10e_world_evaluation_v1",
		"gate_id": GATE_ID,
		"ledger_scope":
		_ledger_scope_for_seed(
			campaign_seed,
			"physical_world_evaluation_refusal",
		),
		"ok": false,
		"failure_code": code,
		"outcome_complete": false,
		"evidence_valid": false,
		"behavior_passed": false,
		"arm_id": arm_id,
		"campaign_seed": campaign_seed,
		"cell_id": cell_id(arm_id, campaign_seed),
		"evaluation_world_build_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _invalid_pair(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10e_pair_evaluation_v1",
		"gate_id": GATE_ID,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_pair_evaluation_refusal",
			"question_class": "development",
		},
		"ok": false,
		"failure_code": code,
		"outcome_complete": false,
		"evidence_valid": false,
		"behavior_passed": false,
		"evaluation_world_build_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10e_zero_world_refusal_v1",
		"gate_id": GATE_ID,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_contract_or_validation_refusal",
			"question_class": "development",
		},
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
