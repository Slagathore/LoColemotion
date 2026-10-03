extends "res://tests/test_sdk_qsdk_r05e_morphology_route.gd"

## One-world, non-held-out commissioning ghost for the R05E production route.


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": "res://sdk/qsdk_r05e_development_route_ghost_preregistration.json",
		"preregistration_schema": "sporespore_qsdk_r05e_development_route_ghost_preregistration_v1",
		"preregistration_status": "frozen_before_first_qsdk_r05e_development_ghost_world",
		"campaign_id": ExactSpecScript.DEVELOPMENT_GHOST_CAMPAIGN_ID,
		"gate_id": "QSDK-R05E-GHOST",
		"campaign_role": "development_route_ghost",
		"generator_policy_id": ExactSpecScript.GENERATOR_POLICY_ID,
		"generator_indices": [ExactSpecScript.DEVELOPMENT_GHOST_INDEX],
		"campaign_seeds": [40001],
		"generated_receipt_schema": "sporespore_qsdk_r05e_development_ghost_generated_cells_receipt_v1",
		"entrypoint_receipt_schema": "sporespore_qsdk_r05e_development_ghost_entrypoint_preflight_v1",
		"authorization_preflight_schema": "sporespore_qsdk_r05e_development_ghost_authorization_preflight_v1",
		"cell_receipt_schema": "sporespore_qsdk_r05e_development_ghost_cell_v1",
		"generated_prefix": "QSDK_R05E_DEVELOPMENT_GHOST_GENERATED_CELLS ",
		"entrypoint_prefix": "QSDK_R05E_DEVELOPMENT_GHOST_ENTRYPOINT_PREFLIGHT ",
		"authorization_preflight_prefix": "QSDK_R05E_DEVELOPMENT_GHOST_AUTHORIZATION_PREFLIGHT ",
		"cell_prefix": "QSDK_R05E_DEVELOPMENT_GHOST_CELL ",
		"display_name": "QSDK-R05E development route ghost",
		"physical_authorization_required": true,
	}


func _expected_morphology_count() -> int:
	return 1


func _expected_world_count() -> int:
	return 1


func _walking_required_for_cell_success() -> bool:
	return false
