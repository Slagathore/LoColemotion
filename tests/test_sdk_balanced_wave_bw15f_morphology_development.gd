extends "res://tests/test_sdk_qsdk_r05_independent_morphology.gd"

## Four-arm, outcome-exposed BW15F sign/gain development harness.
##
## The R05B cohort is reused only for paired hypothesis selection. Walking is
## an observed outcome, never a harness-success condition. Every arm must keep
## exact portable-controller receipts, exclusive native motor authority, and
## complete execution integrity across all 36 worlds.

const BW15F_PREREGISTRATION_PATH := (
	"res://sdk/balanced_wave_bw15f_morphology_development_preregistration.json"
)
const BW15F_PREREGISTRATION_SCHEMA := (
	"sporespore_balanced_wave_bw15f_morphology_development_preregistration_v1"
)
const BW15F_PREREGISTRATION_STATUS := "frozen_before_first_bw15f_physics_world"
const BW15F_IMPLEMENTATION_PARENT_COMMIT := "632c22dc429c7f1c7e610e72b2ac9950fcea26cb"
const BW15F_CANDIDATE_ENVIRONMENT_VARIABLE := "SPORESPORE_BW15F_CANDIDATE"
const BW15F_CANDIDATE_IDS := ["BW15F-A", "BW15F-B", "BW15F-C", "BW15F-D"]
const BW15F_CONTROLLER_POLICY_IDS := [
	"sporespore_balanced_wave_bw5r_b_v1",
	"sporespore_balanced_wave_bw15f_b_v1",
	"sporespore_balanced_wave_bw15f_c_v1",
	"sporespore_balanced_wave_bw15f_d_v1",
]
const BW15F_MODES := [
	"control",
	"forward_velocity_foot_placement",
	"forward_velocity_foot_placement",
	"forward_velocity_foot_placement",
]
const BW15F_ERROR_ORIENTATION_IDS := [
	"",
	"desired_minus_measured_forward_velocity_error_v1",
	"measured_minus_desired_forward_velocity_error_v1",
	"measured_minus_desired_forward_velocity_error_v1",
]
const BW15F_MAXIMUM_CORRECTIONS_RAD := [0.0, 0.03, 0.03, 0.06]
const BW15F_POLICY_DIGESTS := [
	"sha256:ac9fe7e62493ed2d21d3c95f0eb51cde45d7a53e7e22365ce422c68ad031a423",
	"sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd",
	"sha256:7ba445b2756a8fc43e245334f3215fc77dd5c68142dd0be33a3dfeaf2c75433f",
	"sha256:f26320a4019a86f1ec700f297af12156a61ea41a026d489b69d1b649fafdcf60",
]
const BW15F_RUNTIME_PROFILE_DIGESTS := [
	"sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e",
	"sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413",
	"sha256:c18b5ff2202060a4f6e8e0a93c57eb9137e5394c99170e4b8edb9a569340f796",
	"sha256:7355df08b7650412326535fdc51fba0e805dc20b1b8fe7d3d018537eeb503466",
]


func _candidate_index() -> int:
	return BW15F_CANDIDATE_IDS.find(
		OS.get_environment(BW15F_CANDIDATE_ENVIRONMENT_VARIABLE),
	)


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW15F_PREREGISTRATION_PATH,
		"preregistration_schema": BW15F_PREREGISTRATION_SCHEMA,
		"preregistration_status": BW15F_PREREGISTRATION_STATUS,
		"campaign_id": "BW15F-MORPHOLOGY-DEVELOPMENT",
		"gate_id": "BW15F",
		"generator_policy_id": ProportionSpecScript.QSDK_R05B_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.QSDK_R05B_INDEPENDENT_INDICES,
		"campaign_seeds": [21601, 21602, 21603],
		"generated_receipt_schema":
		"sporespore_bw15f_development_generated_cells_receipt_v1",
		"entrypoint_receipt_schema":
		"sporespore_bw15f_development_entrypoint_preflight_v1",
		"cell_receipt_schema": "sporespore_bw15f_morphology_development_cell_v1",
		"generated_prefix": "BW15F_DEVELOPMENT_GENERATED_CELLS ",
		"entrypoint_prefix": "BW15F_DEVELOPMENT_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "BW15F_DEVELOPMENT_CELL ",
		"display_name": "BW15F four-arm sign/gain development",
	}


func _controller_candidate_id() -> String:
	var index := _candidate_index()
	return String(BW15F_CANDIDATE_IDS[index]) if index >= 0 else ""


func _controller_policy_id() -> String:
	var index := _candidate_index()
	return String(BW15F_CONTROLLER_POLICY_IDS[index]) if index >= 0 else ""


func _controller_policy_digest() -> String:
	var index := _candidate_index()
	return String(BW15F_POLICY_DIGESTS[index]) if index >= 0 else ""


func _walking_required_for_cell_success() -> bool:
	return false


func _compile_campaign_generation(generator_index: int) -> Dictionary:
	return ProportionSpecScript.compile_qsdk_r05b_generation(generator_index)


func _verify_campaign_generation(
	generator_index: int,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	return (
		ProportionSpecScript
		. verify_qsdk_r05b_generation(
			generator_index,
			expected_generator_receipt_sha256,
			expected_proportion_spec_sha256,
		)
	)


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	_selected_policy: Dictionary,
) -> bool:
	var index := _candidate_index()
	if index < 0:
		return false
	var candidates: Array = preregistration.get("candidates", [])
	var candidate_digests: Dictionary = preregistration.get(
		"candidate_policy_digests",
		{},
	)
	if candidates.size() != BW15F_CANDIDATE_IDS.size():
		return false
	var candidate: Dictionary = candidates[index]
	var orientation_value: Variant = candidate.get(
		"velocity_error_orientation_id",
		null,
	)
	var correction_value := float(
		candidate.get("maximum_hip_target_correction_rad", NAN)
	)
	var candidate_specific_exact := false
	if index == 0:
		candidate_specific_exact = (
			orientation_value == null
			and candidate.get("forward_velocity_foot_placement_mode_id", null) == null
			and String(candidate.get("normalized_error_formula", "")) == "none"
			and is_zero_approx(correction_value)
			and String(candidate.get("cycle_envelope", "")) == "none"
		)
	else:
		candidate_specific_exact = (
			String(candidate.get("forward_velocity_foot_placement_mode_id", ""))
			== "forward_velocity_foot_placement_v1"
			and String(orientation_value)
			== String(BW15F_ERROR_ORIENTATION_IDS[index])
			and is_equal_approx(
				correction_value,
				float(BW15F_MAXIMUM_CORRECTIONS_RAD[index]),
			)
			and String(candidate.get("cycle_envelope", ""))
			== "unchanged_bw14v_smoothstep_swing_and_one_minus_smoothstep_stance"
		)
	return (
		(preregistration.get("candidate_order", []) as Array) == BW15F_CANDIDATE_IDS
		and String(candidate.get("candidate_id", ""))
		== String(BW15F_CANDIDATE_IDS[index])
		and String(candidate.get("controller_policy_id", ""))
		== String(BW15F_CONTROLLER_POLICY_IDS[index])
		and String(candidate.get("mode", "")) == String(BW15F_MODES[index])
		and String(candidate.get("parent_candidate_id", "")) == "BW5R-B"
		and String(candidate.get("parent_policy_id", ""))
		== "sporespore_balanced_wave_bw5r_b_v1"
		and String(candidate.get("runtime_profile_sha256", ""))
		== String(BW15F_RUNTIME_PROFILE_DIGESTS[index])
		and (candidate.get("branch_surfaces", []) as Array).is_empty()
		and int(candidate.get("morphology_condition_count", -1)) == 0
		and int(candidate.get("material_condition_count", -1)) == 0
		and int(candidate.get("seed_condition_count", -1)) == 0
		and int(candidate.get("failure_identity_condition_count", -1)) == 0
		and int(candidate.get("outcome_condition_count", -1)) == 0
		and candidate_specific_exact
		and String(candidate_digests.get(BW15F_CANDIDATE_IDS[index], ""))
		== String(BW15F_POLICY_DIGESTS[index])
		and CanonicalJsonScript.sha256(candidate) == String(BW15F_POLICY_DIGESTS[index])
	)


func _validate_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	if not super._validate_contract(preregistration, selected_policy):
		return false
	var mechanism: Dictionary = preregistration.get("mechanism_hypothesis", {})
	var predecessor: Dictionary = preregistration.get("predecessor_interlocks", {})
	var repetitions: Dictionary = preregistration.get("repetitions", {})
	var eligibility: Dictionary = preregistration.get(
		"mechanism_receipt_eligibility",
		{},
	)
	var selection: Dictionary = preregistration.get("selection", {})
	var claims: Dictionary = preregistration.get("claim_boundary", {})
	var factorial: Dictionary = mechanism.get("factorial_interpretation", {})
	return (
		String(preregistration.get("implementation_parent_commit", ""))
		== BW15F_IMPLEMENTATION_PARENT_COMMIT
		and String(preregistration.get("campaign_role", ""))
		== "paired_outcome_exposed_global_sign_gain_hypothesis_selection"
		and bool(preregistration.get("development_data_only", false))
		and not bool(preregistration.get("development_candidate_selected", true))
		and bool(predecessor.get("r05b_cohort_outcome_exposed", false))
		and bool(predecessor.get(
			"bw14v_repair_rerun_reclassification_or_selection_forbidden",
			false,
		))
		and int(predecessor.get("bw14v_world_count", -1)) == 72
		and int(predecessor.get("bw14v_treatment_reached_declared_correction_cap_count", -1))
		== 36
		and not bool(predecessor.get("r05c_opened", true))
		and bool(predecessor.get("r05c_may_not_be_opened_by_bw15f", false))
		and not bool(predecessor.get("unbiased_friction_reservation_opened", true))
		and String(factorial.get("b_to_c", ""))
		== "error_orientation_only_at_fixed_0_03_rad_gain"
		and String(factorial.get("c_to_d", ""))
		== "gain_only_with_fixed_measured_minus_desired_orientation"
		and int(mechanism.get("morphology_condition_count", -1)) == 0
		and int(mechanism.get("material_condition_count", -1)) == 0
		and int(mechanism.get("seed_condition_count", -1)) == 0
		and int(mechanism.get("failure_identity_condition_count", -1)) == 0
		and int(mechanism.get("outcome_condition_count", -1)) == 0
		and bool(mechanism.get("continuous_at_touchdown", false))
		and bool(mechanism.get("continuous_at_cycle_boundary", false))
		and bool(mechanism.get("portable_core_owns_mechanism", false))
		and bool(mechanism.get("host_specific_feedback_forbidden", false))
		and not bool(mechanism.get("phase_factor_varied", true))
		and int(repetitions.get("expected_world_count_per_candidate", -1)) == 36
		and int(repetitions.get("expected_complete_world_count", -1)) == 144
		and bool(repetitions.get("early_stop_for_outcome_forbidden", false))
		and bool(eligibility.get(
			"control_requires_mechanism_disabled_and_zero_receipt_count",
			false,
		))
		and bool(eligibility.get(
			"treatments_require_one_forward_velocity_receipt_per_sdk_step",
			false,
		))
		and bool(eligibility.get(
			"treatments_require_four_ordered_limb_corrections_per_receipt",
			false,
		))
		and bool(eligibility.get(
			"receipt_orientation_must_equal_candidate_declaration",
			false,
		))
		and bool(selection.get("all_candidate_reports_required", false))
		and bool(selection.get(
			"best_treatment_must_be_strictly_lexicographically_better_than_control",
			false,
		))
		and (selection.get("treatment_tie_order", []) as Array)
		== ["BW15F-B", "BW15F-C", "BW15F-D"]
		and not bool(claims.get("walking_acceptance", true))
		and not bool(claims.get("independent_morphology_validation", true))
		and not bool(claims.get("completed_engine_neutral_sdk", true))
		and not bool(claims.get("physical_acceptance_authority", true))
	)


func _physical_cell_receipt(
	cell: Dictionary,
	seed: int,
	summary: Dictionary,
) -> Dictionary:
	var receipt := super._physical_cell_receipt(cell, seed, summary)
	var index := _candidate_index()
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var mechanism: Dictionary = sdk_summary.get(
		"forward_velocity_foot_placement_summary",
		{},
	)
	var sdk_steps := int(receipt.get("sdk_step_count", -1))
	var mechanism_exact := (
		index >= 0
		and String(mechanism.get("schema_version", ""))
		== "sporespore_forward_velocity_foot_placement_execution_summary_v1"
		and int(mechanism.get("morphology_branch_surface_count", -1)) == 0
		and bool(mechanism.get("controller_parameter", false))
		and not bool(mechanism.get("walking_claim_authorized", true))
		and not bool(mechanism.get("physical_acceptance_authority", true))
	)
	if index == 0:
		mechanism_exact = (
			mechanism_exact
			and not bool(mechanism.get("enabled", true))
			and String(mechanism.get("mode_id", "")).is_empty()
			and String(mechanism.get("velocity_error_orientation_id", "")).is_empty()
			and int(mechanism.get("receipt_count", -1)) == 0
			and is_zero_approx(float(mechanism.get(
				"maximum_absolute_normalized_forward_velocity_error",
				NAN,
			)))
			and is_zero_approx(float(mechanism.get(
				"maximum_absolute_hip_target_correction_rad",
				NAN,
			)))
			and is_zero_approx(float(mechanism.get(
				"maximum_declared_hip_target_correction_rad",
				NAN,
			)))
		)
	elif index in range(1, BW15F_CANDIDATE_IDS.size()):
		var maximum_error := float(
			mechanism.get("maximum_absolute_normalized_forward_velocity_error", NAN)
		)
		var maximum_correction := float(
			mechanism.get("maximum_absolute_hip_target_correction_rad", NAN)
		)
		var declared_correction := float(BW15F_MAXIMUM_CORRECTIONS_RAD[index])
		mechanism_exact = (
			mechanism_exact
			and bool(mechanism.get("enabled", false))
			and String(mechanism.get("mode_id", ""))
			== "forward_velocity_foot_placement_v1"
			and String(mechanism.get("velocity_error_orientation_id", ""))
			== String(BW15F_ERROR_ORIENTATION_IDS[index])
			and int(mechanism.get("receipt_count", -1)) == sdk_steps
			and sdk_steps > 0
			and is_finite(maximum_error)
			and maximum_error >= 0.0
			and maximum_error <= 1.0 + 1.0e-12
			and is_finite(maximum_correction)
			and maximum_correction >= 0.0
			and maximum_correction <= declared_correction + 1.0e-12
			and is_equal_approx(
				float(mechanism.get(
					"maximum_declared_hip_target_correction_rad",
					NAN,
				)),
				declared_correction,
			)
		)
	var base_integrity := bool(receipt.get("common_execution_integrity", false))
	var combined_application_exact := base_integrity
	var prepared := _prepare_cell(int(cell["generator_index"]))
	var lateral_bound := float(
		(prepared.get("evidence_threshold_options", {}) as Dictionary).get(
			"maximum_lateral_drift_m",
			NAN,
		)
	)
	var lateral_displacement := absf(
		float(receipt.get("final_task_frame_lateral_displacement_m", NAN))
	)
	var normalized_lateral_displacement := (
		lateral_displacement / lateral_bound
		if is_finite(lateral_displacement) and is_finite(lateral_bound) and lateral_bound > 0.0
		else NAN
	)
	var cumulative_cross_track_error_m_s := float(
		sdk_summary.get("cumulative_absolute_cross_track_error_m_s", NAN)
	)
	var development_integrity := (
		base_integrity
		and mechanism_exact
		and combined_application_exact
		and is_finite(normalized_lateral_displacement)
		and is_finite(cumulative_cross_track_error_m_s)
	)
	var walking_gates: Dictionary = receipt.get("walking_gate_receipts", {})
	var failed_walking_gate_count := 0
	for gate_value in walking_gates.values():
		if typeof(gate_value) != TYPE_BOOL or not bool(gate_value):
			failed_walking_gate_count += 1
	var release_timeout_count := 0
	for timeout_value in (
		summary.get("contact_gate_timeout_count_by_limb", {}) as Dictionary
	).values():
		release_timeout_count += int(timeout_value)
	receipt["campaign_role"] = (
		"paired_outcome_exposed_global_sign_gain_hypothesis_selection"
	)
	receipt["candidate_id"] = _controller_candidate_id()
	receipt["candidate_policy_digest"] = _controller_policy_digest()
	receipt["common_execution_integrity"] = development_integrity
	receipt["walking_observed"] = (
		development_integrity and bool(receipt.get("walking_observed", false))
	)
	receipt["mechanism_gate_passed"] = mechanism_exact
	receipt["combined_application_gate_passed"] = combined_application_exact
	receipt["forward_velocity_foot_placement_summary"] = mechanism.duplicate(true)
	receipt["failed_production_walking_gate_count"] = failed_walking_gate_count
	receipt["release_timeout_count"] = release_timeout_count
	receipt["maximum_lateral_drift_bound_m"] = lateral_bound
	receipt["normalized_absolute_task_frame_lateral_displacement"] = (
		normalized_lateral_displacement if is_finite(normalized_lateral_displacement) else null
	)
	receipt["cumulative_absolute_cross_track_error_m_s"] = (
		cumulative_cross_track_error_m_s if is_finite(cumulative_cross_track_error_m_s) else null
	)
	receipt["development_selection_authority"] = true
	receipt["independent_morphology_validation"] = false
	receipt["walking_acceptance"] = false
	return receipt
