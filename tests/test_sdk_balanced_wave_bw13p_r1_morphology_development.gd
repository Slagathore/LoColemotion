extends "res://tests/test_sdk_qsdk_r05_independent_morphology.gd"

## Paired, outcome-exposed BW13P-R1 morphology development harness.
##
## The complete R05B 12-by-3 matrix is reused for hypothesis selection only.
## The invalid aa92940 source is retained but never resumed. Walking is
## recorded but is not a harness-success condition. Integrity, mechanism
## receipts, the declared signed-offset runtime boundary, and real combined
## full-authority application remain mandatory on every physical cell.

const BW13P_PREREGISTRATION_PATH := (
	"res://sdk/balanced_wave_bw13p_r1_morphology_development_preregistration.json"
)
const BW13P_PREREGISTRATION_SCHEMA := (
	"sporespore_balanced_wave_bw13p_r1_morphology_development_preregistration_v1"
)
const BW13P_PREREGISTRATION_STATUS := "frozen_before_first_bw13p_r1_physics_world"
const BW13P_IMPLEMENTATION_PARENT_COMMIT := "e798e21e97ed95d5627ae0974d30a26feb0560a1"
const BW13P_CANDIDATE_ENVIRONMENT_VARIABLE := "SPORESPORE_BW13P_R1_CANDIDATE"
const BW13P_CANDIDATE_IDS := ["BW13P-A", "BW13P-B", "BW13P-C", "BW13P-D"]
const BW13P_STABILITY_POLICY_IDS := [
	"sporespore_scheduled_load_transfer_bw13p_a_v3",
	"sporespore_scheduled_load_transfer_bw13p_b_v3",
	"sporespore_scheduled_load_transfer_bw13p_c_v3",
	"sporespore_scheduled_load_transfer_bw13p_d_v3",
]
const BW13P_MODES := [
	"control",
	"preferred_normal_force",
	"remaining_support_centroid",
	"combined",
]
const BW13P_POLICY_DIGESTS := [
	"sha256:5843bcb182dbf68072246a3c730e53033fc705818186fcb3f0fd8ad4e0120a47",
	"sha256:4d5a0ebaf6a6dfdbc20ce1a538ef84b1a1c2a85c559d67c84bbeac586d6c3887",
	"sha256:522947d355d39543bfc5cc8af4b930aba1db8409c10ad5d7e9f8c81deac1f0f4",
	"sha256:05d0460c3cccec4e25bc5cf9040a8fa82c681264bd1efaaec4f8601efb27e05e",
]


func _candidate_index() -> int:
	return BW13P_CANDIDATE_IDS.find(
		OS.get_environment(BW13P_CANDIDATE_ENVIRONMENT_VARIABLE),
	)


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW13P_PREREGISTRATION_PATH,
		"preregistration_schema": BW13P_PREREGISTRATION_SCHEMA,
		"preregistration_status": BW13P_PREREGISTRATION_STATUS,
		"campaign_id": "BW13P-R1-MORPHOLOGY-DEVELOPMENT",
		"gate_id": "BW13P-R1",
		"generator_policy_id": ProportionSpecScript.QSDK_R05B_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.QSDK_R05B_INDEPENDENT_INDICES,
		"campaign_seeds": [21601, 21602, 21603],
		"generated_receipt_schema":
		"sporespore_bw13p_r1_development_generated_cells_receipt_v1",
		"entrypoint_receipt_schema":
		"sporespore_bw13p_r1_development_entrypoint_preflight_v1",
		"cell_receipt_schema": "sporespore_bw13p_r1_morphology_development_cell_v1",
		"generated_prefix": "BW13P_R1_DEVELOPMENT_GENERATED_CELLS ",
		"entrypoint_prefix": "BW13P_R1_DEVELOPMENT_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "BW13P_R1_DEVELOPMENT_CELL ",
		"display_name": "BW13P-R1 paired morphology development",
	}


func _stability_policy_id() -> String:
	var index := _candidate_index()
	return String(BW13P_STABILITY_POLICY_IDS[index]) if index >= 0 else ""


func _walking_required_for_cell_success() -> bool:
	return false


func _expected_full_authority_execution_mode() -> String:
	return "native_balanced_wave_base_with_stability_contribution"


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


func _validate_contract(preregistration: Dictionary, selected_policy: Dictionary) -> bool:
	var base_contract_ok := super._validate_contract(preregistration, selected_policy)
	if not base_contract_ok:
		var campaign := _campaign_contract()
		print(
			"BW13P_R1_BASE_CONTRACT_DIAGNOSTIC ",
			JSON.stringify(
				{
					"campaign": campaign,
					"actual_schema": String(preregistration.get("schema_version", "")),
					"actual_status": String(preregistration.get("status", "")),
					"actual_gate_id": String(preregistration.get("gate_id", "")),
					"actual_campaign_id": String(preregistration.get("campaign_id", "")),
					"actual_selected_candidate_id":
					String(preregistration.get("selected_candidate_id", "")),
					"actual_selected_policy_id":
					String(preregistration.get("selected_policy_id", "")),
					"actual_selected_policy_digest":
					String(preregistration.get("selected_policy_digest", "")),
					"actual_generator":
					(preregistration.get("morphology_generator", {}) as Dictionary),
					"actual_repetitions":
					(preregistration.get("repetitions", {}) as Dictionary),
					"actual_material":
					(preregistration.get("material", {}) as Dictionary),
					"actual_claim_boundary":
					(preregistration.get("claim_boundary", {}) as Dictionary),
					"selected_policy": selected_policy,
					"world_build_count": 0,
					"physical_acceptance_authority": false,
				},
				"",
				true,
				true,
			),
		)
		return false
	var index := _candidate_index()
	if index < 0:
		return false
	var candidates: Array = preregistration.get("candidates", [])
	if candidates.size() != 4:
		return false
	var candidate: Dictionary = candidates[index]
	var mechanism: Dictionary = preregistration.get("mechanism_hypothesis", {})
	var portable: Dictionary = preregistration.get("portable_implementation", {})
	var repetitions: Dictionary = preregistration.get("repetitions", {})
	var mechanism_eligibility: Dictionary = preregistration.get(
		"mechanism_receipt_eligibility",
		{},
	)
	var invalid_source: Dictionary = preregistration.get(
		"invalid_bw13p_source_interlock",
		{},
	)
	var runtime_revision: Dictionary = preregistration.get(
		"runtime_boundary_revision",
		{},
	)
	var selection: Dictionary = preregistration.get("selection", {})
	var claims: Dictionary = preregistration.get("claim_boundary", {})
	var exact := (
		String(preregistration.get("implementation_parent_commit", ""))
		== BW13P_IMPLEMENTATION_PARENT_COMMIT
		and bool(preregistration.get("development_data_only", false))
		and not bool(preregistration.get("development_candidate_selected", true))
		and (
			String(preregistration.get("campaign_role", ""))
			== "paired_outcome_exposed_morphology_hypothesis_selection"
		)
		and (preregistration.get("candidate_order", []) as Array) == BW13P_CANDIDATE_IDS
		and String(candidate.get("candidate_id", "")) == String(BW13P_CANDIDATE_IDS[index])
		and (
			String(candidate.get("stability_policy_id", ""))
			== String(BW13P_STABILITY_POLICY_IDS[index])
		)
		and String(candidate.get("mode", "")) == String(BW13P_MODES[index])
		and (candidate.get("branch_surfaces", []) as Array).is_empty()
		and bool(candidate.get("total_preferred_normal_force_conserved", false))
		and (
			String(
				(preregistration.get("candidate_policy_digests", {}) as Dictionary).get(
					BW13P_CANDIDATE_IDS[index],
					"",
				)
			)
			== String(BW13P_POLICY_DIGESTS[index])
		)
		and CanonicalJsonScript.sha256(candidate) == String(BW13P_POLICY_DIGESTS[index])
		and bool(mechanism.get("total_preferred_normal_force_conserved_exactly", false))
		and int(mechanism.get("morphology_branch_surface_count", -1)) == 0
		and int(mechanism.get("material_branch_surface_count", -1)) == 0
		and int(mechanism.get("seed_branch_surface_count", -1)) == 0
		and int(mechanism.get("failure_identity_branch_surface_count", -1)) == 0
		and int(mechanism.get("outcome_branch_surface_count", -1)) == 0
		and int(mechanism.get("new_fitted_numeric_threshold_count", -1)) == 0
		and bool(portable.get("predecessor_command_feasibility_may_not_censor_bw13p", false))
		and bool(portable.get("bw13p_command_receives_the_only_exposed_feasibility_verdict", false))
		and int(repetitions.get("expected_world_count_per_candidate", -1)) == 36
		and int(repetitions.get("expected_complete_world_count", -1)) == 144
		and bool(repetitions.get("early_stop_for_outcome_forbidden", false))
		and (
			String(invalid_source.get("rejected_source_commit", ""))
			== "aa92940e6f8aca258df17d051dc7fd8c294d4eb7"
		)
		and int(invalid_source.get("complete_world_count", -1)) == 36
		and int(invalid_source.get("integrity_pass_count", -1)) == 0
		and int(invalid_source.get("native_sdk_step_count", -1)) == 0
		and bool(invalid_source.get("rejected_source_repair_or_rerun_forbidden", false))
		and bool(
			invalid_source.get(
				"unopened_b_c_d_launch_from_rejected_source_forbidden",
				false,
			)
		)
		and (
			String(runtime_revision.get("phase_receipt_schema", ""))
			== "sporespore_sdk_phase_offset_synchronization_receipt_v2"
		)
		and (
			String(runtime_revision.get("full_integrity_receipt_schema", ""))
			== "sporespore_full_integrity_gate_satisfiability_receipt_v4"
		)
		and (
			_integer_array(
				runtime_revision.get("declared_signed_phase_offsets", []),
			)
			== [-3, -2]
		)
		and bool(
			runtime_revision.get(
				"every_candidate_and_declared_offset_must_execute_native_controller_before_world",
				false,
			)
		)
		and bool(
			runtime_revision.get(
				"perfect_declared_synthetic_result_must_pass_exact_production_gate",
				false,
			)
		)
		and bool(
			mechanism_eligibility.get(
				"all_candidates_require_one_combined_full_authority_application_per_sdk_step",
				false,
			)
		)
		and bool(
			mechanism_eligibility.get(
				"all_candidates_require_eight_combined_motor_writes_per_sdk_step",
				false,
			)
		)
		and bool(
			mechanism_eligibility.get(
				"all_candidates_require_nonzero_effective_stability_influence",
				false,
			)
		)
		and bool(selection.get("all_four_complete_36_world_reports_required", false))
		and bool(selection.get("treatment_must_be_strictly_lexicographically_better_than_control", false))
		and not bool(claims.get("walking_acceptance", true))
		and not bool(claims.get("independent_morphology_validation", true))
		and not bool(claims.get("completed_engine_neutral_sdk", true))
		and not bool(claims.get("physical_acceptance_authority", true))
	)
	if not exact:
		print(
			"BW13P_R1_REVISION_CONTRACT_DIAGNOSTIC ",
			JSON.stringify(
				{
					"implementation_parent_commit":
					preregistration.get("implementation_parent_commit", ""),
					"candidate": candidate,
					"mechanism": mechanism,
					"portable": portable,
					"repetitions": repetitions,
					"invalid_source": invalid_source,
					"runtime_revision": runtime_revision,
					"mechanism_eligibility": mechanism_eligibility,
					"selection": selection,
					"claim_boundary": claims,
					"candidate_digest": CanonicalJsonScript.sha256(candidate),
					"expected_candidate_digest":
					String(BW13P_POLICY_DIGESTS[index]),
					"world_build_count": 0,
					"physical_acceptance_authority": false,
				},
				"",
				true,
				true,
			),
		)
	return exact


func _physical_cell_receipt(
	cell: Dictionary,
	seed: int,
	summary: Dictionary,
) -> Dictionary:
	var receipt := super._physical_cell_receipt(cell, seed, summary)
	var index := _candidate_index()
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var load_transfer: Dictionary = sdk_summary.get("scheduled_load_transfer_summary", {})
	var contribution: Dictionary = sdk_summary.get("stability_contribution_shadow_summary", {})
	var overlay: Dictionary = sdk_summary.get("stability_overlay_summary", {})
	var sdk_steps := int(receipt.get("sdk_step_count", -1))
	var receipt_count := int(load_transfer.get("receipt_count", -1))
	var available_count := int(load_transfer.get("available_receipt_count", -1))
	var unavailable_count := int(
		load_transfer.get("observation_unavailable_receipt_count", -1)
	)
	var infeasible_count := int(load_transfer.get("upstream_infeasible_receipt_count", -1))
	var fail_zero_count := int(load_transfer.get("fail_zero_receipt_count", -1))
	var active_count := int(load_transfer.get("active_step_count", -1))
	var preferred_count := int(load_transfer.get("preferred_normal_step_count", -1))
	var centroid_count := int(load_transfer.get("remaining_centroid_step_count", -1))
	var factor_partition_exact := (
		(active_count == 0 and preferred_count == 0 and centroid_count == 0)
		if index == 0
		else (
			active_count > 0
			and (preferred_count > 0 if index in [1, 3] else preferred_count == 0)
			and (centroid_count > 0 if index in [2, 3] else centroid_count == 0)
		)
	)
	var mechanism_exact := (
		index >= 0
		and bool(load_transfer.get("enabled", false))
		and String(load_transfer.get("policy_id", "")) == _stability_policy_id()
		and (
			String(load_transfer.get("portable_plan_operation", ""))
			== "plan_scheduled_load_transfer_v3_json"
		)
		and (
			String(load_transfer.get("receipt_schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v3"
		)
		and receipt_count == sdk_steps
		and receipt_count > 0
		and available_count >= 0
		and unavailable_count >= 0
		and infeasible_count >= 0
		and available_count + unavailable_count + infeasible_count == receipt_count
		and fail_zero_count == unavailable_count + infeasible_count
		and factor_partition_exact
		and String(load_transfer.get("first_receipt_sha256", "")).begins_with("sha256:")
		and String(load_transfer.get("last_receipt_sha256", "")).begins_with("sha256:")
		and bool(load_transfer.get("activation_uses_scheduler_boundaries_only", false))
		and int(load_transfer.get("morphology_branch_surface_count", -1)) == 0
		and not bool(load_transfer.get("walking_claim_authorized", true))
		and not bool(load_transfer.get("physical_acceptance_authority", true))
	)
	var combined_application_exact := (
		bool(summary.get("sdk_full_authority_stability_contribution_enabled", false))
		and bool(sdk_summary.get("stability_overlay_runtime_ok", false))
		and bool(overlay.get("ok", false))
		and String(overlay.get("policy_id", "")) == _stability_policy_id()
		and String(overlay.get("authority_scope", "")) == "post_settle_full"
		and int(overlay.get("application_step_count", -1)) == sdk_steps
		and int(overlay.get("motor_write_count", -1)) == sdk_steps * EXPECTED_ACTUATOR_COUNT
		and (
			int(overlay.get("portable_controller_base_application_count", -1))
			== sdk_steps * EXPECTED_ACTUATOR_COUNT
		)
		and int(overlay.get("nonzero_effective_application_count", 0)) > 0
		and int(overlay.get("failure_count", -1)) == 0
		and int(overlay.get("direct_body_write_count", -1)) == 0
		and bool(overlay.get("physical_influence", false))
		and not bool(overlay.get("physical_acceptance_authority", true))
		and bool(contribution.get("ok", false))
		and int(contribution.get("attempt_count", -1)) == sdk_steps
		and int(contribution.get("mismatch_count", -1)) == 0
		and int(contribution.get("limiter_mismatch_count", -1)) == 0
		and int(contribution.get("inactive_zero_mismatch_count", -1)) == 0
		and int(contribution.get("profile_conversion_failure_count", -1)) == 0
	)
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
		bool(receipt.get("common_execution_integrity", false))
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
	receipt["campaign_role"] = "paired_outcome_exposed_morphology_hypothesis_selection"
	receipt["candidate_id"] = String(BW13P_CANDIDATE_IDS[index])
	receipt["candidate_policy_digest"] = String(BW13P_POLICY_DIGESTS[index])
	receipt["stability_policy_id"] = _stability_policy_id()
	receipt["common_execution_integrity"] = development_integrity
	receipt["walking_observed"] = (
		development_integrity and bool(receipt.get("walking_observed", false))
	)
	receipt["scheduled_load_transfer_gate_passed"] = mechanism_exact
	receipt["combined_full_authority_application_gate_passed"] = combined_application_exact
	receipt["scheduled_load_transfer_summary"] = load_transfer.duplicate(true)
	receipt["stability_contribution_summary"] = contribution.duplicate(true)
	receipt["stability_overlay_summary"] = overlay.duplicate(true)
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
