extends "res://tests/test_sdk_balanced_wave_bw26j_actual_worker_receipt_authority.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BW28Y zero-world commissioning of the exact successor receipt path.
##
## Every frozen BW28Y cell enters the shared route with its manifest-declared
## cohort, traverses the actual inherited BW25Y -> BW20F constructor, and emits
## a BW28Y raw receipt. The summaries describe hypothetical perfect completed
## worlds, but this script creates no world and grants no scientific authority.

const Bw28CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const BW28Y_PREREGISTRATION_PATH := (
	"res://sdk/balanced_wave_bw28y_yaw_development_preregistration.json"
)
const BW28Y_CANDIDATES_PATH := (
	"res://sdk/balanced_wave_bw28y_yaw_development_candidates.json"
)
const BW28Y_MANIFEST_PATH := (
	"res://sdk/balanced_wave_bw28y_yaw_development_manifest.json"
)
const BW28Y_PREFIX := "BW28Y_ACTUAL_RECEIPT_PATH "
const BW28Y_CAMPAIGN_ID := "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT"
const BW28Y_GATE_ID := "BW28Y"
const BW28Y_RAW_CELL_SCHEMA := "sporespore_balanced_wave_bw28y_yaw_development_raw_cell_v1"
const BW28Y_CAMPAIGN_ATTEMPT_ID := "BW28Y-ZERO-WORLD-ACTUAL-PATH-PREFLIGHT"


func _run() -> void:
	_passed = 0
	_failed = 0
	print("\n=== BW28Y actual receipt-path zero-world preflight ===")
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var preregistration := _read_json(BW28Y_PREREGISTRATION_PATH)
	var declarations := _read_json(BW28Y_CANDIDATES_PATH)
	var manifest := _read_json(BW28Y_MANIFEST_PATH)
	var predecessor_contract := _read_json(BW26I_CONTRACT_PATH)
	var raw_contract: Dictionary = predecessor_contract.get("raw_receipt_contract", {})
	var common_keys: Array = raw_contract.get("required_common_keys", [])
	var role_keys: Array = raw_contract.get("required_candidate_and_control_keys", [])
	var cells: Array = manifest.get("ordered_cells", [])
	_check(
		_validate_declarations(preregistration, declarations, manifest)
		and cells.size() == 28,
		"the BW28Y declarations, candidate digests, and 28-cell manifest are exact",
	)

	var raw_receipts: Array = []
	var candidate_count := 0
	var control_count := 0
	var safety_count := 0
	var actual_constructor_count := 0
	var candidate_overlay_influence_count := 0
	var control_overlay_influence_count := 0
	var control_base_observed_count := 0
	var control_residual_semantics_count := 0
	for cell_value in cells:
		var cell: Dictionary = (cell_value as Dictionary).duplicate(true)
		var role := String(cell.get("role", ""))
		_configure_cell(cell)
		var prepared := (
			_prepare_zero_safety(cell) if role == "safety" else _prepare_cell(0)
		)
		var summary := (
			_perfect_safety_summary(prepared)
			if role == "safety"
			else _perfect_physical_summary(cell, prepared)
		)
		var overlay: Dictionary = (
			summary.get("sdk_authority_summary", {}) as Dictionary
		).get("stability_overlay_summary", {}) as Dictionary
		if role == "candidate" and bool(overlay.get("physical_influence", false)):
			candidate_overlay_influence_count += 1
		elif role == "control" and bool(overlay.get("physical_influence", false)):
			control_overlay_influence_count += 1
		var world_attempt_id := "BW28Y-ZW::%s" % String(cell["cell_id"])
		var receipt := ActualWorkerReceiptRouteScript.compose(
			self,
			cell,
			summary,
			common_keys,
			[] if role == "safety" else role_keys,
			BW28Y_CAMPAIGN_ATTEMPT_ID,
			world_attempt_id,
		)
		_clear_cell_configuration()
		raw_receipts.append(receipt.duplicate(true))
		actual_constructor_count += 1
		if role == "candidate":
			candidate_count += 1
		elif role == "control":
			control_count += 1
			if (
				bool(receipt.get("base_controller_application_observed", false))
				and bool(
					receipt.get("broad_base_controller_physical_influence_observed", false)
				)
			):
				control_base_observed_count += 1
			if (
				not bool(receipt.get("residual_application_expected", true))
				and not bool(receipt.get("residual_application_observed", true))
				and int(receipt.get("sdk_effective_application_count", -1)) == 0
				and not bool(receipt.get("combined_application_gate_passed", true))
			):
				control_residual_semantics_count += 1
		elif role == "safety":
			safety_count += 1
		_check(
			bool(receipt.get("raw_receipt_complete", false))
			and (receipt.get("receipt_route_failure_codes", []) as Array).is_empty()
			and String(receipt.get("schema_version", "")) == BW28Y_RAW_CELL_SCHEMA
			and String(receipt.get("campaign_id", "")) == BW28Y_CAMPAIGN_ID
			and String(receipt.get("gate_id", "")) == BW28Y_GATE_ID
			and String(receipt.get("cohort", "")) == String(cell["cohort"])
			and String(receipt.get("world_attempt_id", "")) == world_attempt_id
			and bool(receipt.get("role_gate_passed", false))
			and not bool(receipt.get("walking_result_controls_process_exit", true))
			and not bool(receipt.get("physical_acceptance_authority", true)),
			"%s traverses the actual inherited constructor as a complete BW28Y raw receipt"
			% String(cell["cell_id"]),
		)

	var missing_cohort_cell: Dictionary = (cells[0] as Dictionary).duplicate(true)
	missing_cohort_cell.erase("cohort")
	var missing_cohort_canary := ActualWorkerReceiptRouteScript.compose(
		self,
		missing_cohort_cell,
		{},
		common_keys,
		role_keys,
		BW28Y_CAMPAIGN_ATTEMPT_ID,
		"BW28Y-ZW::MISSING-COHORT-CANARY",
	)
	var missing_cohort_rejected := (
		not bool(missing_cohort_canary.get("raw_receipt_complete", true))
		and (
			missing_cohort_canary.get("receipt_route_failure_codes", []) as Array
		).has("MISSING_DECLARED_COHORT")
	)
	_check(missing_cohort_rejected, "a missing manifest cohort fails before constructor entry")

	var negative_cell: Dictionary = (cells[1] as Dictionary).duplicate(true)
	_configure_cell(negative_cell)
	var negative_prepared := _prepare_cell(0)
	var negative_summary := _perfect_physical_summary(negative_cell, negative_prepared)
	negative_summary["walking_gate_receipts"]["bounded_tilt"] = false
	negative_summary["physical_wave_gait_walking_observed"] = false
	var negative_receipt := ActualWorkerReceiptRouteScript.compose(
		self,
		negative_cell,
		negative_summary,
		common_keys,
		role_keys,
		BW28Y_CAMPAIGN_ATTEMPT_ID,
		"BW28Y-ZW::%s" % String(negative_cell["cell_id"]),
	)
	_clear_cell_configuration()
	var negative_receipt_complete := (
		bool(negative_receipt.get("raw_receipt_complete", false))
		and not bool(
			(negative_receipt.get("walking_gate_receipts", {}) as Dictionary).get(
				"bounded_tilt",
				true,
			)
		)
		and bool(negative_receipt.get("common_execution_integrity", false))
		and bool(negative_receipt.get("outcome_complete", false))
		and not bool(negative_receipt.get("walking_observed", true))
		and not bool(negative_receipt.get("physical_acceptance_authority", true))
	)
	_check(
		negative_receipt_complete,
		"a valid walking-negative observation remains a structurally complete BW28Y receipt",
	)

	var control_semantics_exact := (
		candidate_overlay_influence_count == 24
		and control_overlay_influence_count == 0
		and control_base_observed_count == 3
		and control_residual_semantics_count == 3
	)
	_check(
		control_semantics_exact,
		"inactive control residual overlays remain distinct from the active portable base",
	)
	var scene_tree_insertion_count := root.get_child_count() - root_children_before
	var physics_state_modified := Engine.physics_ticks_per_second != physics_hz_before
	var aggregate_ok := (
		_failed == 0
		and raw_receipts.size() == 28
		and candidate_count == 24
		and control_count == 3
		and safety_count == 1
		and actual_constructor_count == 28
		and missing_cohort_rejected
		and negative_receipt_complete
		and control_semantics_exact
		and scene_tree_insertion_count == 0
		and not physics_state_modified
	)
	var aggregate := {
		"schema_version": "sporespore_balanced_wave_bw28y_actual_receipt_path_v1",
		"ok": aggregate_ok,
		"campaign_id": BW28Y_CAMPAIGN_ID,
		"gate_id": BW28Y_GATE_ID,
		"campaign_attempt_id": BW28Y_CAMPAIGN_ATTEMPT_ID,
		"raw_receipts": raw_receipts,
		"raw_receipt_count": raw_receipts.size(),
		"candidate_receipt_count": candidate_count,
		"control_receipt_count": control_count,
		"safety_receipt_count": safety_count,
		"actual_inherited_constructor_call_count": actual_constructor_count,
		"missing_declared_cohort_rejected": missing_cohort_rejected,
		"negative_walking_raw_receipt": negative_receipt,
		"negative_walking_raw_receipt_complete": negative_receipt_complete,
		"candidate_overlay_physical_influence_count": candidate_overlay_influence_count,
		"control_overlay_physical_influence_count": control_overlay_influence_count,
		"control_base_controller_observed_count": control_base_observed_count,
		"control_residual_semantics_count": control_residual_semantics_count,
		"control_overlay_and_base_semantics_exact": control_semantics_exact,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"physics_state_modified": physics_state_modified,
		"locomotion_outcome_exposed": false,
		"walking_acceptance": false,
		"turning_acceptance": false,
		"material_robustness": false,
		"candidate_selected": false,
		"development_selection_authority": false,
		"physical_acceptance_authority": false,
	}
	print(BW28Y_PREFIX, JSON.stringify(aggregate, "", true, true))
	if aggregate_ok:
		print(
			"BW28Y_ACTUAL_RECEIPT_PATH_GODOT_PASS receipts=28 candidates=24 "
			+ "controls=3 safety=1 constructors=28 control_semantics=True worlds=0 "
			+ "physical_authority=False"
		)
	quit(0 if aggregate_ok else 1)


func _bw25y_physical_cell_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var receipt := super._bw25y_physical_cell_receipt(cell, summary)
	return _bind_bw28y_raw_identity(receipt)


func _bw25y_zero_safety_receipt(cell: Dictionary, summary: Dictionary) -> Dictionary:
	var receipt := super._bw25y_zero_safety_receipt(cell, summary)
	return _bind_bw28y_raw_identity(receipt)


func _bind_bw28y_raw_identity(receipt: Dictionary) -> Dictionary:
	receipt["schema_version"] = BW28Y_RAW_CELL_SCHEMA
	receipt["campaign_id"] = BW28Y_CAMPAIGN_ID
	receipt["gate_id"] = BW28Y_GATE_ID
	receipt["physical_acceptance_authority"] = false
	return receipt


func _validate_declarations(
	preregistration: Dictionary,
	declarations: Dictionary,
	manifest: Dictionary,
) -> bool:
	var candidates: Array = declarations.get("candidates", [])
	var digests: Dictionary = declarations.get("candidate_composition_digests", {})
	if candidates.size() != 2:
		return false
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		if (
			Bw28CanonicalJsonScript.sha256(candidate)
			!= String(digests.get(String(candidate.get("candidate_id", "")), ""))
		):
			return false
	var control: Dictionary = declarations.get("policy_relative_control", {})
	return (
		String(preregistration.get("campaign_id", "")) == BW28Y_CAMPAIGN_ID
		and String(declarations.get("campaign_id", "")) == BW28Y_CAMPAIGN_ID
		and String(manifest.get("campaign_id", "")) == BW28Y_CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == BW28Y_GATE_ID
		and String(declarations.get("gate_id", "")) == BW28Y_GATE_ID
		and String(manifest.get("gate_id", "")) == BW28Y_GATE_ID
		and Bw28CanonicalJsonScript.sha256(control)
		== String(declarations.get("policy_relative_control_composition_digest", ""))
		and not bool(manifest.get("physical_execution_authorized", true))
		and not bool(manifest.get("independent_validation_authority", true))
	)
