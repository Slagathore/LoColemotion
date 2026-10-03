extends "res://tests/test_sdk_balanced_wave_bw32n_successor_worker.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines

const Bw34Common := preload("res://scripts/lab/gait/sdk_bw34y_worker_common.gd")
const BW34Y_RAW_PREFIX := "BW34Y_ROUGH_YAW_RESCUE_RAW_CELL "
const BW34Y_PREFLIGHT_PREFIX := "BW34Y_ROUGH_YAW_RESCUE_WORKER_PREFLIGHT "
const BW34Y_REAL_SHAPED_PREFIX := "BW34Y_ROUGH_YAW_RESCUE_REAL_SHAPED_RECEIPTS "
const BW34Y_PREFLIGHT_SCHEMA := "sporespore_balanced_wave_bw34y_rough_yaw_rescue_worker_preflight_v1"

var _bw34y_cell: Dictionary = {}


func _bw19v_candidate_index() -> int:
	return 1 if not _bw34y_cell.is_empty() else -1


func _candidate_id() -> String:
	return String(_bw34y_cell.get("candidate_id", ""))


func _candidate_composition_digest() -> String:
	return Bw34Common.candidate_composition_digest(_candidate_id())


func _candidate_global_scale() -> float:
	return float(_bw34y_cell.get("global_requested_correction_scale", NAN))


func _controller_candidate_id() -> String:
	return _candidate_id()


func _controller_policy_id() -> String:
	return String(_bw34y_cell.get("controller_policy_id", ""))


func _controller_policy_digest() -> String:
	return String(_bw34y_cell.get("runtime_profile_sha256", ""))


func _stability_policy_id() -> String:
	return (
		"sporespore_scheduled_load_transfer_bw13p_a_v3"
		if not _bw34y_cell.is_empty()
		else ""
	)


func _expected_full_authority_execution_mode() -> String:
	return (
		"native_balanced_wave_base_with_stability_contribution"
		if not _bw34y_cell.is_empty()
		else ""
	)


func _walking_required_for_cell_success() -> bool:
	return false


func _run() -> void:
	print("\n=== BW34Y rough yaw-rescue native worker ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "preflight-all":
		await _run_all_bw34y_preflight()
		return
	if user_args.size() == 1 and String(user_args[0]) == "receipt-preflight-all":
		_run_real_shaped_receipt_preflight_all_bw34y()
		return
	var mode := String(user_args[0]) if user_args.size() == 2 else ""
	var cell_id := String(user_args[1]) if user_args.size() == 2 else ""
	var cell := Bw34Common.find_cell(cell_id)
	if mode not in ["preflight", "authorization-preflight", "physical"] or cell.is_empty():
		push_error("BW34Y requires preflight, authorization-preflight, or physical plus one exact cell")
		quit(1)
		return
	if not Bw34Common.static_contract_exact(String(cell["candidate_id"])):
		push_error("BW34Y declaration, native binding, or stage-one freeze identity changed")
		quit(1)
		return
	if not _configure_bw34y_cell(cell):
		_clear_bw34y_cell()
		push_error("BW34Y exact rough yaw-rescue challenge, candidate, or material input failed")
		quit(1)
		return
	if mode in ["preflight", "authorization-preflight"]:
		var authorization_requested := mode == "authorization-preflight"
		var authorization_exact := (
			Bw34Common.physical_authorization_exact(
				cell_id,
				String(cell["candidate_id"]),
				true,
			)
			if authorization_requested
			else true
		)
		var receipt := await _run_bw34y_preflight(
			cell,
			authorization_exact,
			authorization_requested,
		)
		_clear_bw34y_cell()
		print(BW34Y_PREFLIGHT_PREFIX, JSON.stringify(receipt, "", true, true))
		quit(0 if bool(receipt.get("ok", false)) else 1)
		return
	if not Bw34Common.physical_authorization_exact(
		cell_id,
		String(cell["candidate_id"]),
		false,
	):
		_clear_bw34y_cell()
		push_error("BW34Y physical entry requires exact retained one-shot supervisor authorization")
		quit(1)
		return
	var summary := await _run_cell(0, int(cell["campaign_seed"]), false)
	var receipt := Bw34Common.compose_dynamic_final_receipt(cell, summary)
	_clear_bw34y_cell()
	print(BW34Y_RAW_PREFIX, JSON.stringify(receipt, "", true, true))
	quit(0 if bool(receipt.get("role_gate_passed", false)) else 1)


func _configure_bw34y_cell(cell: Dictionary) -> bool:
	var candidate_id := String(cell.get("candidate_id", ""))
	var requested := Bw34Common.challenge_profile(String(cell.get("challenge_profile_id", "")))
	var compiled := WaveGaitScript.compile_environment_challenge_options(requested)
	_bw34y_cell = cell.duplicate(true)
	_bw32n_manifest_cell = cell.duplicate(true)
	_bw32n_challenge_options = (
		(compiled.get("environment_challenge_options", {}) as Dictionary).duplicate(true)
	)
	_bw20f_profile_id = Bw34Common.MATERIAL_PROFILE_ID
	return (
		bool(compiled.get("ok", false))
		and not _bw32n_challenge_options.is_empty()
		and Bw34Common.candidate_binding_exact(candidate_id)
		and _candidate_id() == candidate_id
		and _controller_policy_id() == String(cell.get("controller_policy_id", ""))
		and _controller_policy_digest() == String(cell.get("runtime_profile_sha256", ""))
		and absf(_candidate_global_scale() - float(cell.get("global_requested_correction_scale", NAN))) <= 1.0e-12
	)


func _clear_bw34y_cell() -> void:
	_bw34y_cell = {}
	_bw32n_manifest_cell = {}
	_bw32n_challenge_options = {}
	_bw20f_profile_id = ""
	OS.unset_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE)


func _run_all_bw34y_preflight() -> void:
	var receipts: Array = []
	var all_exact := Bw34Common.static_contract_exact()
	var adapter_start_count := 0
	for cell_id in Bw34Common.ordered_cell_ids():
		var cell := Bw34Common.find_cell(String(cell_id))
		var configured := _configure_bw34y_cell(cell)
		var parent_receipt: Dictionary = {}
		if configured:
			parent_receipt = await _run_cell(0, int(cell["campaign_seed"]), true)
			adapter_start_count += 1
		_clear_bw34y_cell()
		var exact := (
			configured
			and bool(parent_receipt.get("ok", false))
			and bool(parent_receipt.get("entrypoint_control_flow_complete", false))
			and int(parent_receipt.get("actual_world_build_count", -1)) == 0
			and int(parent_receipt.get("scene_tree_insertion_count", -1)) == 0
			and not bool(parent_receipt.get("physics_state_modified", true))
			and bool(parent_receipt.get("selected_policy_full_authority_start_passed", false))
			and not bool(parent_receipt.get("locomotion_outcome_exposed", true))
			and not bool(parent_receipt.get("physical_acceptance_authority", true))
		)
		all_exact = all_exact and exact
		receipts.append({
			"cell_id": String(cell.get("cell_id", "")),
			"candidate_id": String(cell.get("candidate_id", "")),
			"ok": exact,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": int(parent_receipt.get("scene_tree_insertion_count", -1)),
			"physics_state_modified": bool(parent_receipt.get("physics_state_modified", true)),
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		})
	var aggregate := {
		"schema_version": BW34Y_PREFLIGHT_SCHEMA,
		"ok": all_exact and receipts.size() == 3 and adapter_start_count == 3 and root.get_child_count() == 0,
		"campaign_id": Bw34Common.CAMPAIGN_ID,
		"gate_id": Bw34Common.GATE_ID,
		"cell_id": "ALL",
		"entrypoint_count": receipts.size(),
		"adapter_start_count": adapter_start_count,
		"entrypoint_receipts": receipts,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW34Y_PREFLIGHT_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _run_real_shaped_receipt_preflight_all_bw34y() -> void:
	var receipts: Array = []
	var all_exact := Bw34Common.static_contract_exact()
	for cell_id in Bw34Common.ordered_cell_ids():
		var cell := Bw34Common.find_cell(String(cell_id))
		var candidate_id := String(cell.get("candidate_id", ""))
		var seed := int(cell.get("campaign_seed", -1))
		# The baseline real-shaped set intentionally mirrors the retained
		# comparator pattern: seed 21001 walks and the other two are structurally
		# complete walking negatives. Selector canaries mutate this same shape.
		var walking := candidate_id == "BW34Y-A" and seed == 21001
		var summary := Bw34Common.synthetic_parent_summary(cell, walking)
		var receipt := Bw34Common.compose_dynamic_final_receipt(cell, summary)
		all_exact = (
			all_exact
			and not receipt.is_empty()
			and bool(receipt.get("common_execution_integrity", false))
			and bool(receipt.get("role_gate_passed", false))
			and bool(receipt.get("walking_observed", false)) == walking
		)
		receipts.append(receipt)
	var aggregate := {
		"schema_version": "sporespore_balanced_wave_bw34y_real_shaped_receipt_preflight_v1",
		"ok": all_exact and receipts.size() == 3 and root.get_child_count() == 0,
		"campaign_id": Bw34Common.CAMPAIGN_ID,
		"gate_id": Bw34Common.GATE_ID,
		"entrypoint_count": receipts.size(),
		"cell_receipts": receipts,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count(),
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(BW34Y_REAL_SHAPED_PREFIX, JSON.stringify(aggregate, "", true, true))
	quit(0 if bool(aggregate["ok"]) else 1)


func _run_bw34y_preflight(
	cell: Dictionary,
	authorization_exact: bool,
	authorization_requested: bool,
) -> Dictionary:
	var parent_receipt := await _run_cell(0, int(cell["campaign_seed"]), true)
	var exact := (
		bool(parent_receipt.get("ok", false))
		and bool(parent_receipt.get("entrypoint_control_flow_complete", false))
		and int(parent_receipt.get("actual_world_build_count", -1)) == 0
		and int(parent_receipt.get("scene_tree_insertion_count", -1)) == 0
		and not bool(parent_receipt.get("physics_state_modified", true))
		and bool(parent_receipt.get("selected_policy_full_authority_start_passed", false))
		and not bool(parent_receipt.get("locomotion_outcome_exposed", true))
		and not bool(parent_receipt.get("physical_acceptance_authority", true))
		and (authorization_exact if authorization_requested else true)
	)
	return {
		"schema_version": BW34Y_PREFLIGHT_SCHEMA,
		"ok": exact,
		"campaign_id": Bw34Common.CAMPAIGN_ID,
		"gate_id": Bw34Common.GATE_ID,
		"candidate_id": String(cell["candidate_id"]),
		"cell_id": String(cell["cell_id"]),
		"entrypoint_control_flow_complete": bool(parent_receipt.get("entrypoint_control_flow_complete", false)),
		"authorization_requested": authorization_requested,
		"authorization_exact": authorization_exact,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": int(parent_receipt.get("scene_tree_insertion_count", -1)),
		"physics_state_modified": bool(parent_receipt.get("physics_state_modified", true)),
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _preflight_selected_policy_full_authority_start(
	prepared: Dictionary,
	initial_perturbation: Dictionary,
) -> Dictionary:
	var root_child_count_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var requested_phase_offset_ticks := int(initial_perturbation["gait_phase_offset_ticks"])
	var execution_mode_plan := WaveGaitScript.compile_sdk_execution_mode_plan(
		true,
		true,
		"post_settle_full",
		_stability_policy_id(),
		requested_phase_offset_ticks,
	)
	if not bool(execution_mode_plan.get("ok", false)):
		return execution_mode_plan
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = adapter.start(
		(prepared["authority_options"] as Dictionary)["descriptor"],
		execution_mode_plan.get("zero_base_initial_gait_steps", {}) as Dictionary,
		0.0,
		Vector3.ZERO,
		Vector3.BACK,
		float(initial_perturbation["fixture_yaw_rad"]),
		120,
		SOLVER_POLICY_OPTIONS,
		SDK_COMPARISON_TOLERANCE,
		"clocked",
		true,
		requested_phase_offset_ticks,
		360,
		"post_settle_full",
		_stability_policy_id(),
		prepared["material_profile"],
		_controller_policy_id(),
		_candidate_global_scale(),
	)
	var boundary: Dictionary = {}
	if bool(start.get("ok", false)):
		boundary = adapter.preflight_perfect_declared_policy_runtime_boundary()
	var adapter_manifest: Dictionary = start.get("adapter_manifest", {})
	var controller_profile: Dictionary = adapter_manifest.get("controller_profile", {})
	var stability: Dictionary = adapter_manifest.get("stability_v3", {})
	var contribution: Dictionary = stability.get("contribution_shadow", {})
	var influence: Dictionary = boundary.get("portable_stability_influence_receipt", {})
	var candidate := Bw34Common.candidate_declaration(_candidate_id())
	var exact := (
		Bw34Common.candidate_binding_exact(_candidate_id())
		and not candidate.is_empty()
		and bool(start.get("ok", false))
		and String(start.get("controller_policy_id", "")) == _controller_policy_id()
		and String(start.get("controller_profile_sha256", "")) == _controller_policy_digest()
		and absf(float(controller_profile.get("yaw_error_stride_gain_per_rad", NAN)) - float(candidate.get("yaw_error_stride_gain_per_rad", NAN))) <= 1.0e-12
		and String(start.get("authority_scope", "")) == "post_settle_full"
		and String(start.get("stability_policy_id", "")) == _stability_policy_id()
		and String(adapter_manifest.get("execution_mode", "")) == _expected_full_authority_execution_mode()
		and String(adapter_manifest.get("stability_influence_scale_authority", "")) == "portable_core_v3"
		and absf(float(adapter_manifest.get("stability_influence_global_scale", NAN)) - _candidate_global_scale()) <= 1.0e-12
		and String(contribution.get("influence_operation", "")) == "bound_stability_influence_v3_json"
		and bool(boundary.get("ok", false))
		and bool(boundary.get("portable_stability_influence_required", false))
		and bool(boundary.get("portable_stability_influence_passed", false))
		and String(influence.get("stability_influence_operation", "")) == "bound_stability_influence_v3_json"
		and absf(float(influence.get("global_requested_correction_scale", NAN)) - _candidate_global_scale()) <= 1.0e-12
		and int(start.get("world_build_count", -1)) == 0
		and int(boundary.get("actual_world_build_count", -1)) == 0
		and root.get_child_count() == root_child_count_before
		and Engine.physics_ticks_per_second == physics_hz_before
		and not bool(start.get("physical_acceptance_authority", true))
	)
	return {
		"schema_version": "sporespore_bw34y_candidate_adapter_start_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "BW34Y_CANDIDATE_ADAPTER_START_INVALID",
		"candidate_id": _candidate_id(),
		"candidate_composition_digest": _candidate_composition_digest(),
		"controller_policy_id": String(start.get("controller_policy_id", "")),
		"controller_runtime_profile_sha256": String(start.get("controller_profile_sha256", "")),
		"yaw_error_stride_gain_per_rad": float(controller_profile.get("yaw_error_stride_gain_per_rad", NAN)),
		"authority_scope": String(start.get("authority_scope", "")),
		"actuation_authority": bool(start.get("actuation_authority", false)),
		"stability_policy_id": String(start.get("stability_policy_id", "")),
		"global_requested_correction_scale": _candidate_global_scale(),
		"adapter_capability_sha256": String(start.get("adapter_capability_sha256", "")),
		"requested_phase_offset_ticks": requested_phase_offset_ticks,
		"sdk_execution_mode_plan": execution_mode_plan.duplicate(true),
		"sdk_execution_mode_plan_passed": bool(execution_mode_plan.get("ok", false)),
		"declared_policy_runtime_boundary_preflight": boundary.duplicate(true),
		"declared_policy_runtime_boundary_preflight_passed": bool(boundary.get("ok", false)),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": root.get_child_count() - root_child_count_before,
		"physics_state_modified": Engine.physics_ticks_per_second != physics_hz_before,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
