class_name LabQsdkR10bBoundedUprightPushRecovery
extends RefCounted
# gdlint: disable=max-line-length

## Pure descriptor, challenge, trace, and evaluator authority for QSDK-R10B.
##
## Every function in this source is zero-world. The physical worker supplies a
## completed walker summary; this module validates it without constructing a
## Node, reading native state, or stepping a solver.

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
const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd"
)
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const DESIGN_PATH := "res://sdk/qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json"
const DESIGN_RAW_SHA256 := "f5738803e65d25b3225c0b054ced5f21613650f2a5aa1d79e76b700ad7d36f66"
const L2_DESIGN_PATH := "res://sdk/qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1.json"
const L2_DESIGN_RAW_SHA256 := "5acc66edbc274616898b25ede236207ff77ca92e596ffbf171472ca9dfc7a478"
const L3_DESIGN_PATH := "res://sdk/qsdk_r10b_l3_serialization_stable_trace_validation_successor_design_v1.json"
const L3_DESIGN_RAW_SHA256 := "ad8d147ee5a508aee3104fb346dcedde692568a9f9093a73e3bdbca638901f76"
const GATE_ID := "QSDK-R10B"
const OFFICIAL_CAMPAIGN_ID := "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
const DEVELOPMENT_GHOST_CAMPAIGN_ID := "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
const GENERATOR_POLICY_ID := "qsdk_r10b_exact_reference_quadruped_v1"
const GENERATOR_INDEX := 0
const REFERENCE_MORPHOLOGY_ID := "qsdk_r10a_exact_reference_quadruped_v1"
const SELECTED_CANDIDATE_ID := "BW5R-B"
const SELECTED_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const SELECTED_POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const BASELINE_ARM_ID := "matched_no_impulse_control"
const PUSH_ARM_ID := "lateral_upright_impulse"
const ARM_ORDER := [BASELINE_ARM_ID, PUSH_ARM_ID]
const DEVELOPMENT_GHOST_SEEDS := [50300]
const HELD_OUT_SEEDS := [50301, 50302, 50303]
const ALL_SEEDS := [50300, 50301, 50302, 50303]
const EXPECTED_LIMB_ORDER := ["front_left", "front_right", "rear_left", "rear_right"]

const TRACE_POLICY_ID := "qsdk_r10b_bounded_upright_push_recovery_trace_v3"
const TRACE_ROW_SCHEMA := "sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v3"
const MINIMUM_SDK_STEP_COUNT := 2152
const MAXIMUM_SDK_STEP_COUNT := 2872
const PUSH_MARKER_STEP := 540
const TRACE_SAMPLING_PHASE := "post_physics_for_applied_semantic_step"
const PRE_WINDOW_START := 180
const PRE_WINDOW_END_EXCLUSIVE := 540
const BASELINE_WINDOW_START := 541
const BASELINE_WINDOW_END_EXCLUSIVE := 901
const FIRST_RECOVERY_START := 541
const LAST_RECOVERY_START := 900
const WINDOW_STEP_COUNT := 360
const MAXIMUM_TORSO_TILT_RAD := 0.60
const MINIMUM_TORSO_HEIGHT_M := 0.25
const MINIMUM_AIRBORNE_DWELL_STEPS := 3
const MINIMUM_FORWARD_ADVANCE_M := 0.01
const MINIMUM_NATIVE_EFFECT_M_S := 1.0e-4
const VECTOR_TOLERANCE := 1.0e-12
const QUATERNION_NORM_TOLERANCE := 1.0e-9

const REFERENCE_PROPORTION_SPEC := {
	"schema_version": "sporespore_physical_quadruped_proportion_spec_v1",
	"morphology_id": REFERENCE_MORPHOLOGY_ID,
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 0.5142857142857142,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}


static func compile_generation(generator_index_value: Variant) -> Dictionary:
	if typeof(generator_index_value) != TYPE_INT:
		return _failure("QSDK_R10B_GENERATOR_INDEX_TYPE_INVALID")
	var generator_index := int(generator_index_value)
	if generator_index != GENERATOR_INDEX:
		return _failure("QSDK_R10B_GENERATOR_INDEX_UNKNOWN")
	var proportion_spec := REFERENCE_PROPORTION_SPEC.duplicate(true)
	var compiled := ProportionSpecScript.compile(proportion_spec)
	if not bool(compiled.get("ok", false)):
		return _failure("QSDK_R10B_REFERENCE_PROPORTION_COMPILE_FAILED")
	var generator_receipt := {
		"schema_version": "sporespore_qsdk_r10b_reference_generation_receipt_v1",
		"generator_policy_id": GENERATOR_POLICY_ID,
		"generator_index": GENERATOR_INDEX,
		"morphology_id": REFERENCE_MORPHOLOGY_ID,
		"proportion_spec_sha256": CanonicalJsonScript.sha256(proportion_spec),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
	}
	return {
		"ok": true,
		"failure_code": "",
		"generator_receipt": generator_receipt,
		"generator_receipt_sha256": CanonicalJsonScript.sha256(generator_receipt),
		"proportion_spec": proportion_spec,
		"proportion_spec_sha256": CanonicalJsonScript.sha256(proportion_spec),
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
		return _failure("QSDK_R10B_GENERATION_DIGEST_MISMATCH")
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
			"qsdk_r10a_lateral_upright_impulse_v1"
			if push_arm
			else "qsdk_r10a_matched_no_impulse_control_v1"
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
	if FileAccess.get_sha256(DESIGN_PATH).to_lower() != DESIGN_RAW_SHA256:
		return _failure("QSDK_R10B_R10A_DESIGN_DIGEST_MISMATCH")
	if FileAccess.get_sha256(L2_DESIGN_PATH).to_lower() != L2_DESIGN_RAW_SHA256:
		return _failure("QSDK_R10B_L2_DESIGN_DIGEST_MISMATCH")
	if FileAccess.get_sha256(L3_DESIGN_PATH).to_lower() != L3_DESIGN_RAW_SHA256:
		return _failure("QSDK_R10B_L3_DESIGN_DIGEST_MISMATCH")
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
		return _failure("QSDK_R10B_STATIC_CONTRACT_COMPILE_FAILED")
	return {
		"ok": true,
		"failure_code": "",
		"arm_id": arm_id,
		"campaign_seed": campaign_seed,
		"cell_id": cell_id(arm_id, campaign_seed),
		"generation": generation,
		"challenge_options": challenge["environment_challenge_options"],
		"challenge_configuration_sha256": challenge["environment_challenge_configuration_sha256"],
		"trace_options": trace["sdk_physical_trace_options"],
		"trace_configuration_sha256": trace["sdk_physical_trace_configuration_sha256"],
		"l2_design_raw_sha256": "sha256:" + L2_DESIGN_RAW_SHA256,
		"l3_design_raw_sha256": "sha256:" + L3_DESIGN_RAW_SHA256,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func evaluate_world(
	summary: Dictionary,
	arm_id: String,
	campaign_seed: int,
) -> Dictionary:
	var static_contract := compile_static_contract(arm_id, campaign_seed)
	if not bool(static_contract.get("ok", false)):
		return _invalid_world(
			arm_id,
			campaign_seed,
			String(static_contract.get("failure_code", "QSDK_R10B_STATIC_CONTRACT_INVALID")),
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
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10B_REQUIRED_SUMMARY_OBJECT_MISSING")
	var sdk_summary: Dictionary = sdk_summary_value
	var trace: Dictionary = trace_value
	var walking_receipts: Dictionary = walking_receipts_value
	var sdk_step_count := int(sdk_summary.get("step_count", -1))
	var trace_rows_value: Variant = trace.get("rows", null)
	if typeof(trace_rows_value) != TYPE_ARRAY:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10B_TRACE_ROWS_NOT_ARRAY")
	var rows: Array = trace_rows_value
	var summary_failure_code_value: Variant = summary.get("failure_code", null)
	if typeof(summary_failure_code_value) != TYPE_STRING:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10B_SUMMARY_FAILURE_CODE_INVALID")
	var summary_failure_code := String(summary_failure_code_value)
	var walking_summary_consistent: bool = (
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
	var walking_receipts_structurally_complete: bool = _boolean_dictionary_complete(
		walking_receipts
	)
	var common_execution_integrity: bool = (
		int(summary.get("world_build_count", -1)) == 1
		and int(summary.get("world_reset_count", -1)) == 0
		and String(summary.get("physics_engine", "")) == "Jolt Physics"
		and int(summary.get("physics_hz", -1)) == 120
		and int(summary.get("solver_velocity_steps", -1)) == 20
		and int(summary.get("solver_position_steps", -1)) == 7
		and int(summary.get("body_count", -1)) == 9
		and int(summary.get("limb_count", -1)) == 4
		and direct_body_write_count == 0
		and bool(summary.get("sdk_authority_enabled", false))
		and String(summary.get("sdk_authority_scope", "")) == "post_settle_full"
		and String(summary.get("sdk_authority_failure_code", "")).is_empty()
		and bool(sdk_summary.get("ok", false))
		and bool(sdk_summary.get("actuation_authority", false))
		and String(sdk_summary.get("controller_policy_id", "")) == SELECTED_POLICY_ID
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
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10B_COMMON_EXECUTION_INTEGRITY_INVALID")

	var perturbation_value: Variant = summary.get("initial_perturbation", null)
	if typeof(perturbation_value) != TYPE_DICTIONARY:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10B_INITIAL_PERTURBATION_MISSING")
	var perturbation: Dictionary = perturbation_value
	if int(perturbation.get("campaign_seed", -1)) != campaign_seed:
		return _invalid_world(arm_id, campaign_seed, "QSDK_R10B_INITIAL_PERTURBATION_SEED_MISMATCH")

	var trace_validation := _validate_trace_rows(rows, expected_cell_id)
	if not bool(trace_validation.get("ok", false)):
		return _invalid_world(
			arm_id,
			campaign_seed,
			String(trace_validation.get("failure_code", "QSDK_R10B_TRACE_INVALID")),
		)
	var application_validation := _validate_application(summary, arm_id)
	if not bool(application_validation.get("ok", false)):
		return _invalid_world(
			arm_id,
			campaign_seed,
			String(application_validation.get("failure_code", "QSDK_R10B_APPLICATION_INVALID")),
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
		"schema_version": "sporespore_qsdk_r10b_world_evaluation_v1",
		"gate_id": GATE_ID,
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
		"walking_receipts_structurally_complete": true,
		"ordinary_walking_passed": ordinary_walking_passed,
		"walking_gate_receipts": walking_receipts.duplicate(true),
		"pre_push_window": pre_window,
		"baseline_post_marker_window": baseline_window,
		"recovery_search": recovery_search,
		"application_receipt": application_validation["receipt"],
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


static func evaluate_pair(
	baseline: Dictionary,
	push: Dictionary,
) -> Dictionary:
	if (
		String(baseline.get("schema_version", "")) != "sporespore_qsdk_r10b_world_evaluation_v1"
		or String(push.get("schema_version", "")) != "sporespore_qsdk_r10b_world_evaluation_v1"
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
		return _invalid_pair("QSDK_R10B_PAIR_IDENTITY_OR_WORLD_INTEGRITY_INVALID")
	var baseline_axis := _vector3_from_array(baseline.get("marker_lateral_axis_world_unit", null))
	var push_axis := _vector3_from_array(push.get("marker_lateral_axis_world_unit", null))
	var baseline_before := _vector3_from_array(
		baseline.get("marker_linear_velocity_before_world_m_s", null)
	)
	var baseline_after := _vector3_from_array(
		baseline.get("marker_linear_velocity_after_world_m_s", null)
	)
	var push_before := _vector3_from_array(
		push.get("marker_linear_velocity_before_world_m_s", null)
	)
	var push_after := _vector3_from_array(push.get("marker_linear_velocity_after_world_m_s", null))
	if (
		not baseline_axis.is_finite()
		or not push_axis.is_finite()
		or not baseline_before.is_finite()
		or not baseline_after.is_finite()
		or not push_before.is_finite()
		or not push_after.is_finite()
		or not baseline_axis.is_equal_approx(push_axis)
	):
		return _invalid_pair("QSDK_R10B_PAIR_MARKER_PROJECTION_INVALID")
	var baseline_jump := (baseline_after - baseline_before).dot(baseline_axis)
	var push_jump := (push_after - push_before).dot(push_axis)
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
		return _invalid_pair("QSDK_R10B_PAIRED_NATIVE_EFFECT_NOT_CONFIRMED")
	var behavior_passed := (
		bool(baseline.get("behavior_passed", false)) and bool(push.get("behavior_passed", false))
	)
	return {
		"schema_version": "sporespore_qsdk_r10b_pair_evaluation_v1",
		"gate_id": GATE_ID,
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
		return _failure("QSDK_R10B_TRACE_ROW_COUNT_OUT_OF_RANGE")
	var first_forward: Array = []
	var first_lateral: Array = []
	var projection_receipt_acceptance_count := 0
	var exported_axis_acceptance_count := 0
	var maximum_projection_receipt_absolute_delta := 0.0
	var maximum_exported_axis_norm_delta := 0.0
	for index in range(rows.size()):
		if typeof(rows[index]) != TYPE_DICTIONARY:
			return _failure("QSDK_R10B_TRACE_ROW_NOT_OBJECT")
		var row: Dictionary = rows[index]
		if (
			String(row.get("schema_version", "")) != TRACE_ROW_SCHEMA
			or String(row.get("cell_id", "")) != expected_cell_id
			or int(row.get("semantic_step", -1)) != index
			or String(row.get("sampling_phase", "")) != TRACE_SAMPLING_PHASE
			or int(row.get("push_marker_semantic_step", -1)) != PUSH_MARKER_STEP
			or int(row.get("validated_portable_command_count", -1)) != 8
			or int(row.get("native_actuation_application_count", -1)) != 8
			or not bool(row.get("post_physics_observation_complete", false))
			or bool(row.get("observer_physics_state_modified", true))
			or typeof(row.get("torso_ground_contact")) != TYPE_BOOL
		):
			return _failure("QSDK_R10B_TRACE_ROW_HEADER_INVALID")
		var position := ExportedScalarValidationScript.finite_components_v1(
			row.get("torso_position_world_m", null), 3
		)
		var linear_velocity := ExportedScalarValidationScript.finite_components_v1(
			row.get("torso_linear_velocity_world_m_s", null), 3
		)
		var angular_velocity := ExportedScalarValidationScript.finite_components_v1(
			row.get("torso_angular_velocity_world_rad_s", null), 3
		)
		var forward := ExportedScalarValidationScript.finite_components_v1(
			row.get("task_frame_forward_axis_world_unit", null), 3
		)
		var lateral := ExportedScalarValidationScript.finite_components_v1(
			row.get("task_frame_lateral_axis_world_unit", null), 3
		)
		var orientation_validation := validate_trace_orientation_projection(
			row.get("torso_orientation_xyzw", null),
			row.get("torso_orientation_projection", null),
		)
		var tilt_value: Variant = row.get("torso_tilt_rad", null)
		var tilt := float(tilt_value) if typeof(tilt_value) in [TYPE_FLOAT, TYPE_INT] else NAN
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
			return _failure("QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID")
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
			return _failure("QSDK_R10B_TRACE_TASK_FRAME_CHANGED")
		for contact_field in ["ordered_foot_contacts_before", "ordered_foot_contacts_after"]:
			var contacts_value: Variant = row.get(String(contact_field), null)
			if typeof(contacts_value) != TYPE_DICTIONARY:
				return _failure("QSDK_R10B_TRACE_CONTACT_OBJECT_MISSING")
			var contacts: Dictionary = contacts_value
			if not _exact_boolean_limb_contacts(contacts):
				return _failure("QSDK_R10B_TRACE_CONTACTS_INVALID")
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
	}


static func _validate_application(summary: Dictionary, arm_id: String) -> Dictionary:
	var count := int(summary.get("external_push_application_count", -1))
	var receipt_value: Variant = summary.get("external_push_receipt", null)
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return _failure("QSDK_R10B_EXTERNAL_PUSH_RECEIPT_NOT_OBJECT")
	var receipt: Dictionary = receipt_value
	if arm_id == BASELINE_ARM_ID:
		if count != 0 or not receipt.is_empty():
			return _failure("QSDK_R10B_BASELINE_NATIVE_IMPULSE_MISMATCH")
		return {
			"ok": true,
			"failure_code": "",
			"receipt":
			{
				"application_count": 0,
				"effect_sampled": false,
				"effect_magnitude_m_s": 0.0,
			},
		}
	var impulse_task := _vector3_from_variant(receipt.get("impulse_task_n_s", null))
	var impulse_world := _vector3_from_variant(receipt.get("impulse_world_n_s", null))
	var observed_delta := _vector3_from_variant(
		receipt.get("observed_next_tick_velocity_delta_world_m_s", null)
	)
	var effect_magnitude := float(
		receipt.get("observed_next_tick_velocity_delta_magnitude_m_s", NAN)
	)
	if (
		count != 1
		or String(receipt.get("profile_id", "")) != "lateral_impulse_v1"
		or int(receipt.get("step_from_sdk_start", -1)) != PUSH_MARKER_STEP
		or int(receipt.get("application_count", -1)) != 1
		or bool(receipt.get("controller_command", true))
		or not bool(receipt.get("effect_sampled", false))
		or not impulse_task.is_equal_approx(Vector3(0.0, 0.0, 0.25))
		or not impulse_world.is_finite()
		or absf(impulse_world.length() - 0.25) > VECTOR_TOLERANCE
		or not observed_delta.is_finite()
		or not is_finite(effect_magnitude)
		or absf(observed_delta.length() - effect_magnitude) > 1.0e-9
	):
		return _failure("QSDK_R10B_PUSH_NATIVE_IMPULSE_RECEIPT_MISMATCH")
	return {
		"ok": true,
		"failure_code": "",
		"receipt":
		{
			"application_count": 1,
			"profile_id": "lateral_impulse_v1",
			"step_from_sdk_start": PUSH_MARKER_STEP,
			"effect_sampled": true,
			"effect_magnitude_m_s": effect_magnitude,
			"observed_velocity_delta_world_m_s":
			[
				observed_delta.x,
				observed_delta.y,
				observed_delta.z,
			],
		},
	}


static func _evaluate_window(rows: Array, start: int, end_exclusive: int) -> Dictionary:
	if start < 1 or end_exclusive - start != WINDOW_STEP_COUNT or end_exclusive > rows.size():
		return {
			"passed": false,
			"failure_code": "QSDK_R10B_WINDOW_BOUNDS_INVALID",
			"start_semantic_step": start,
			"end_semantic_step_exclusive": end_exclusive,
		}
	var safe_envelope_passed := true
	var command_application_passed := true
	for step in range(start, end_exclusive):
		var row: Dictionary = rows[step]
		var position := _vector3_from_array(row["torso_position_world_m"])
		safe_envelope_passed = (
			safe_envelope_passed
			and position.y >= MINIMUM_TORSO_HEIGHT_M
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
		every_limb_airborne_then_recontact = every_limb_airborne_then_recontact and limb_passed
		contact_cycle_by_limb[limb_id] = {
			"passed": limb_passed,
			"longest_airborne_dwell_steps": longest_airborne_dwell,
			"qualifying_recontact_semantic_step": qualifying_recontact_step,
		}
	var origin_row: Dictionary = rows[start - 1]
	var terminal_row: Dictionary = rows[end_exclusive - 1]
	var origin_position := _vector3_from_array(origin_row["torso_position_world_m"])
	var terminal_position := _vector3_from_array(terminal_row["torso_position_world_m"])
	var forward_axis := _vector3_from_array(origin_row["task_frame_forward_axis_world_unit"])
	var forward_advance := (terminal_position - origin_position).dot(forward_axis)
	var forward_advance_passed := forward_advance >= MINIMUM_FORWARD_ADVANCE_M
	var passed := (
		safe_envelope_passed
		and command_application_passed
		and every_limb_airborne_then_recontact
		and forward_advance_passed
	)
	return {
		"passed": passed,
		"failure_code": "" if passed else "QSDK_R10B_WINDOW_REQUIREMENT_FAILED",
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
		"failure_code": "QSDK_R10B_NO_VALID_RECOVERY_WINDOW",
		"first_valid_start_semantic_step": -1,
		"reentry_latency_steps": -1,
		"reentry_latency_s": NAN,
		"window": {},
	}


static func _boolean_dictionary_complete(values: Dictionary) -> bool:
	if values.is_empty():
		return false
	for value in values.values():
		if typeof(value) != TYPE_BOOL:
			return false
	return true


static func _all_boolean_values_true(values: Dictionary) -> bool:
	if not _boolean_dictionary_complete(values):
		return false
	for value in values.values():
		if not bool(value):
			return false
	return true


static func _exact_boolean_limb_contacts(contacts: Dictionary) -> bool:
	if contacts.size() != EXPECTED_LIMB_ORDER.size():
		return false
	for limb_id_value in EXPECTED_LIMB_ORDER:
		var limb_id := String(limb_id_value)
		if not contacts.has(limb_id) or typeof(contacts[limb_id]) != TYPE_BOOL:
			return false
	return true


static func _vector3_from_array(value: Variant) -> Vector3:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 3:
		return Vector3(INF, INF, INF)
	var values: Array = value
	for component in values:
		if typeof(component) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(component)):
			return Vector3(INF, INF, INF)
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func _vector3_from_variant(value: Variant) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return value
	if typeof(value) == TYPE_ARRAY:
		return _vector3_from_array(value)
	if typeof(value) == TYPE_DICTIONARY:
		var values: Dictionary = value
		if values.size() != 3 or not values.has("x") or not values.has("y") or not values.has("z"):
			return Vector3(INF, INF, INF)
		return _vector3_from_array([values["x"], values["y"], values["z"]])
	return Vector3(INF, INF, INF)


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
	var within_r10b_length_contract := (
		bool(diagnostic.get("ok", false))
		and diagnostic.get("norm_delta", null) != null
		and float(diagnostic["norm_delta"]) <= QUATERNION_NORM_TOLERANCE
	)
	return {
		"schema_version": "sporespore_qsdk_r10b_l3_trace_orientation_validation_v2",
		"ok": receipt_valid and within_r10b_length_contract,
		"failure_code":
		(
			""
			if receipt_valid and within_r10b_length_contract
			else "QSDK_R10B_TRACE_ORIENTATION_PROJECTION_INVALID"
		),
		"projection_receipt_valid": receipt_valid,
		"projection_receipt_structure_exact":
		(
			String(receipt_validation.get("failure_code", ""))
			not in [
				"projection_receipt_not_object",
				"projection_receipt_key_set_mismatch",
				"projection_receipt_static_field_mismatch",
				"projection_receipt_source_orientation_mismatch",
			]
		),
		"projection_receipt_row_orientation_link_exact":
		bool(receipt_validation.get("row_orientation_link_exact", false)),
		"projection_receipt_maximum_absolute_delta":
		float(receipt_validation.get("maximum_absolute_delta", 0.0)),
		"projection_receipt_maximum_representation_allowance":
		float(receipt_validation.get("maximum_representation_allowance", 0.0)),
		"projection_receipt_validation": receipt_validation,
		"within_r10b_length_contract": within_r10b_length_contract,
		"r10b_quaternion_length_tolerance": QUATERNION_NORM_TOLERANCE,
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


static func _invalid_world(arm_id: String, campaign_seed: int, code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10b_world_evaluation_v1",
		"gate_id": GATE_ID,
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
		"schema_version": "sporespore_qsdk_r10b_pair_evaluation_v1",
		"gate_id": GATE_ID,
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
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
