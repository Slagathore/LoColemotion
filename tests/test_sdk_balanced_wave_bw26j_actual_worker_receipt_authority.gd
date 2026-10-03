extends "res://tests/test_sdk_balanced_wave_bw26i_actual_worker_receipt_route.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BW26J is a distinct correction of BW26I's invalid zero-world commissioning.
## It keeps the actual inherited receipt constructor, but makes the hypothetical
## completed-world fixtures scientifically neutral and distinguishes the
## control's inactive residual overlay from its still-active portable base.

const BW26J_CONTRACT_PATH := (
	"res://sdk/balanced_wave_bw26j_actual_worker_receipt_authority_contract.json"
)
const BW26J_PREFIX := "BW26J_ACTUAL_WORKER_RECEIPT_AUTHORITY "
const BW26J_CAMPAIGN_ATTEMPT_ID := "BW26J-ZERO-WORLD-AUTHORITY-COMMISSIONING"


func _run() -> void:
	_passed = 0
	_failed = 0
	print("\n=== BW26J actual-worker receipt authority commissioning ===")
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var contract := _read_json(BW26J_CONTRACT_PATH)
	var predecessor_contract := _read_json(BW26I_CONTRACT_PATH)
	var manifest := _read_json(BW25Y_PREREGISTRATION_PATH)
	var raw_contract: Dictionary = predecessor_contract.get("raw_receipt_contract", {})
	var common_keys: Array = raw_contract.get("required_common_keys", [])
	var role_keys: Array = raw_contract.get("required_candidate_and_control_keys", [])
	var cells: Array = manifest.get("matrix", {}).get("ordered_cells", [])
	_check(
		String(contract.get("campaign_id", ""))
		== "BW26J-ACTUAL-WORKER-RECEIPT-AUTHORITY-COMMISSIONING"
		and String(contract.get("gate_id", "")) == "BW26J"
		and cells.size() == 28,
		"the BW26J authority identity and 28 inherited route fixtures are exact",
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
		cell["cohort"] = "bw26j_%s_route_fixture" % role
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
		var world_attempt_id := "BW26J-ZW::%s" % String(cell["cell_id"])
		var receipt := ActualWorkerReceiptRouteScript.compose(
			self,
			cell,
			summary,
			common_keys,
			[] if role == "safety" else role_keys,
			BW26J_CAMPAIGN_ATTEMPT_ID,
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
			and String(receipt.get("schema_version", "")) == BW25Y_RAW_CELL_SCHEMA
			and String(receipt.get("cohort", "")) == String(cell["cohort"])
			and String(receipt.get("world_attempt_id", "")) == world_attempt_id
			and bool(receipt.get("role_gate_passed", false))
			and not bool(receipt.get("walking_result_controls_process_exit", true))
			and not bool(receipt.get("physical_acceptance_authority", true)),
			"%s traverses the actual inherited constructor as a complete raw receipt"
			% String(cell["cell_id"]),
		)

	var missing_cohort_cell: Dictionary = (cells[0] as Dictionary).duplicate(true)
	var missing_cohort_canary := ActualWorkerReceiptRouteScript.compose(
		self,
		missing_cohort_cell,
		{},
		common_keys,
		role_keys,
		BW26J_CAMPAIGN_ATTEMPT_ID,
		"BW26J-ZW::MISSING-COHORT-CANARY",
	)
	var missing_cohort_rejected := (
		not bool(missing_cohort_canary.get("raw_receipt_complete", true))
		and (
			missing_cohort_canary.get("receipt_route_failure_codes", []) as Array
		).has("MISSING_DECLARED_COHORT")
	)
	_check(missing_cohort_rejected, "an undeclared inherited cohort fails before constructor entry")

	var negative_cell: Dictionary = (cells[1] as Dictionary).duplicate(true)
	negative_cell["cohort"] = "bw26j_candidate_route_fixture"
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
		BW26J_CAMPAIGN_ATTEMPT_ID,
		"BW26J-ZW::%s" % String(negative_cell["cell_id"]),
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
		and not bool(negative_receipt.get("physical_acceptance_authority", true))
	)
	_check(
		negative_receipt_complete,
		"a walking-negative observation remains a structurally complete route receipt",
	)

	var control_semantics_exact := (
		control_overlay_influence_count == 0
		and control_base_observed_count == 3
		and control_residual_semantics_count == 3
		and candidate_overlay_influence_count == 24
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
		"schema_version":
		"sporespore_balanced_wave_bw26j_actual_worker_receipt_authority_godot_v1",
		"ok": aggregate_ok,
		"campaign_id": "BW26J-ACTUAL-WORKER-RECEIPT-AUTHORITY-COMMISSIONING",
		"gate_id": "BW26J",
		"campaign_attempt_id": BW26J_CAMPAIGN_ATTEMPT_ID,
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
	print(BW26J_PREFIX, JSON.stringify(aggregate, "", true, true))
	if aggregate_ok:
		print(
			"BW26J_ACTUAL_WORKER_AUTHORITY_GODOT_PASS receipts=28 candidates=24 "
			+ "controls=3 safety=1 constructors=28 control_semantics=True worlds=0 "
			+ "physical_authority=False"
		)
	quit(0 if aggregate_ok else 1)


func _perfect_physical_summary(cell: Dictionary, prepared: Dictionary) -> Dictionary:
	var summary := super._perfect_physical_summary(cell, prepared)
	var walking_gates: Dictionary = summary["walking_gate_receipts"]
	for gate_id in walking_gates.keys():
		walking_gates[gate_id] = true
	summary["physical_wave_gait_walking_observed"] = true
	var sdk_summary: Dictionary = summary["sdk_authority_summary"]
	var residual_expected := String(cell["role"]) == "candidate"
	var overlay: Dictionary = sdk_summary["stability_overlay_summary"]
	overlay["physical_influence"] = residual_expected
	sdk_summary["minimum_cross_track_error_m"] = -0.05
	sdk_summary["maximum_cross_track_error_m"] = 0.05
	sdk_summary["cumulative_absolute_cross_track_error_m_s"] = 0.25
	sdk_summary["maximum_absolute_requested_steering_fraction"] = 0.10
	sdk_summary["maximum_absolute_filtered_steering_fraction"] = 0.08
	sdk_summary["maximum_absolute_steering_delta_per_step"] = 0.01
	summary["final_task_frame_lateral_displacement_m"] = 0.01
	return summary
