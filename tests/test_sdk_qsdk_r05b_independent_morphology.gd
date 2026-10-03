extends "res://tests/test_sdk_qsdk_r05_independent_morphology.gd"

## Fresh QSDK-R05B successor configuration.
##
## All mechanics and production gates are inherited from QSDK-R05. Only the
## prospectively frozen campaign identity, unopened generator cells, fresh
## perturbation seeds, and receipt identities differ.


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": "res://sdk/qsdk_r05b_independent_morphology_preregistration.json",
		"preregistration_schema": "sporespore_qsdk_r05b_independent_morphology_preregistration_v1",
		"preregistration_status": "frozen_before_first_qsdk_r05b_physics_world",
		"campaign_id": "QSDK-R05B",
		"gate_id": "QSDK-R05B",
		"generator_policy_id": ProportionSpecScript.QSDK_R05B_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.QSDK_R05B_INDEPENDENT_INDICES,
		"campaign_seeds": [21601, 21602, 21603],
		"generated_receipt_schema": "sporespore_qsdk_r05b_generated_cells_receipt_v1",
		"entrypoint_receipt_schema": "sporespore_qsdk_r05b_entrypoint_preflight_receipt_v1",
		"cell_receipt_schema": "sporespore_qsdk_r05b_independent_morphology_cell_v1",
		"generated_prefix": "QSDK_R05B_GENERATED_CELLS ",
		"entrypoint_prefix": "QSDK_R05B_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "QSDK_R05B_CELL ",
		"display_name": "QSDK-R05B independent morphology",
	}


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
