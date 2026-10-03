extends "res://tests/test_sdk_qsdk_r05e_morphology_route.gd"

## QSDK-R05E exact finite twelve-body held-out decision worker.


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": "res://sdk/qsdk_r05e_exact_finite_morphology_preregistration.json",
		"preregistration_schema": "sporespore_qsdk_r05e_exact_finite_morphology_preregistration_v1",
		"preregistration_status": "frozen_before_first_qsdk_r05e_heldout_physics_world",
		"campaign_id": ExactSpecScript.OFFICIAL_CAMPAIGN_ID,
		"gate_id": "QSDK-R05E",
		"campaign_role": "held_out_finite_decision",
		"generator_policy_id": ExactSpecScript.GENERATOR_POLICY_ID,
		"generator_indices": ExactSpecScript.OFFICIAL_INDICES,
		"campaign_seeds": [40101, 40102, 40103],
		"generated_receipt_schema": "sporespore_qsdk_r05e_exact_finite_generated_cells_receipt_v1",
		"entrypoint_receipt_schema": "sporespore_qsdk_r05e_exact_finite_entrypoint_preflight_v1",
		"authorization_preflight_schema": "sporespore_qsdk_r05e_exact_finite_authorization_preflight_v1",
		"cell_receipt_schema": "sporespore_qsdk_r05e_exact_finite_cell_v1",
		"generated_prefix": "QSDK_R05E_EXACT_FINITE_GENERATED_CELLS ",
		"entrypoint_prefix": "QSDK_R05E_EXACT_FINITE_ENTRYPOINT_PREFLIGHT ",
		"authorization_preflight_prefix": "QSDK_R05E_EXACT_FINITE_AUTHORIZATION_PREFLIGHT ",
		"cell_prefix": "QSDK_R05E_EXACT_FINITE_CELL ",
		"display_name": "QSDK-R05E exact finite held-out morphology",
		"physical_authorization_required": true,
	}
