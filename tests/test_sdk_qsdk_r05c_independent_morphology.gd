extends "res://tests/test_sdk_qsdk_independent_morphology_v2.gd"

## Fresh QSDK-R05C independent validation of the selected BW15F-B policy.
##
## This specialization changes only the prospectively frozen campaign
## identity, unopened generator cells, fresh perturbation seeds, and the
## already selected branch-free controller identity. Production walking gates,
## material, solver, fixture construction, and host scaffold remain unchanged.

const BW15F_SELECTED_POLICY_PATH := "res://sdk/balanced_wave_bw15f_selected_policy.json"
const BW15F_SELECTED_CANDIDATE_ID := "BW15F-B"
const BW15F_SELECTED_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const BW15F_SELECTED_POLICY_DIGEST := (
	"sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
)


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": "res://sdk/qsdk_r05c_independent_morphology_preregistration.json",
		"preregistration_schema": "sporespore_qsdk_r05c_independent_morphology_preregistration_v1",
		"preregistration_status": "frozen_before_first_qsdk_r05c_physics_world",
		"campaign_id": "QSDK-R05C",
		"gate_id": "QSDK-R05C",
		"generator_policy_id": ProportionSpecScript.QSDK_R05C_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.QSDK_R05C_INDEPENDENT_INDICES,
		"campaign_seeds": [38101, 38102, 38103],
		"generated_receipt_schema": "sporespore_qsdk_r05c_generated_cells_receipt_v1",
		"entrypoint_receipt_schema": "sporespore_qsdk_r05c_entrypoint_preflight_receipt_v1",
		"cell_receipt_schema": "sporespore_qsdk_r05c_independent_morphology_cell_v1",
		"generated_prefix": "QSDK_R05C_GENERATED_CELLS ",
		"entrypoint_prefix": "QSDK_R05C_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "QSDK_R05C_CELL ",
		"display_name": "QSDK-R05C BW15F-B independent morphology",
	}


func _selected_policy_path() -> String:
	return BW15F_SELECTED_POLICY_PATH


func _controller_candidate_id() -> String:
	return BW15F_SELECTED_CANDIDATE_ID


func _controller_policy_id() -> String:
	return BW15F_SELECTED_POLICY_ID


func _controller_policy_digest() -> String:
	return BW15F_SELECTED_POLICY_DIGEST


func _compile_campaign_generation(generator_index: int) -> Dictionary:
	return ProportionSpecScript.compile_qsdk_r05c_generation(generator_index)


func _verify_campaign_generation(
	generator_index: int,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	return (
		ProportionSpecScript
		. verify_qsdk_r05c_generation(
			generator_index,
			expected_generator_receipt_sha256,
			expected_proportion_spec_sha256,
		)
	)
