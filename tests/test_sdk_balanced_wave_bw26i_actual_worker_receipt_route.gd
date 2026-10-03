extends "res://tests/test_sdk_balanced_wave_bw25y_yaw_development.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BW26I zero-world commissioning of the actual inherited post-world route.
## Every BW25Y-shaped worker role enters the exact BW25Y -> BW20F -> BW17P ->
## R05 receipt constructor using a real-shaped synthetic completed-world
## summary. No physics world or scene node is constructed here.

const ActualWorkerReceiptRouteScript := preload(
	"res://scripts/lab/gait/sdk_actual_worker_receipt_route.gd"
)
const BW26I_CONTRACT_PATH := (
	"res://sdk/balanced_wave_bw26i_actual_worker_receipt_route_contract.json"
)
const BW26I_PREFIX := "BW26I_ACTUAL_WORKER_RECEIPT_ROUTE "
const BW26I_CAMPAIGN_ATTEMPT_ID := "BW26I-ZERO-WORLD-COMMISSIONING"
const SYNTHETIC_STEP_COUNT := 4
const SYNTHETIC_MOTOR_WRITE_COUNT := SYNTHETIC_STEP_COUNT * EXPECTED_ACTUATOR_COUNT_BW17P
const PERFECT_WALKING_GATE_IDS := [
	"bounded_anchor_error",
	"bounded_hinge_axis_error",
	"bounded_joint_only_lateral_stride_steering",
	"bounded_lateral_drift",
	"bounded_tilt",
	"bounded_torso_height",
	"bounded_yaw_drift",
	"contact_gated_evidence_horizon_completed",
	"contact_gating_completed_without_timeout",
	"every_contact_observer_executed",
	"every_limb_completed_evidence_gait_horizon",
	"every_limb_forward_relocation",
	"every_limb_two_contact_cycles",
	"evidence_four_contact_stance",
	"fixture_spec_compiled_before_world_creation",
	"initial_four_contact_stance",
	"initial_perturbation_within_declared_envelope",
	"minimum_evidence_forward_translation",
	"minimum_final_forward_translation",
	"native_sdk_exclusive_post_settle_actuation",
	"no_torso_force_or_impulse_or_velocity_or_transform_command",
	"no_world_reset",
	"one_continuous_world",
	"pinned_jolt_solver_settings",
	"terminal_four_contact_recovery",
	"zero_torso_contact",
]


func _run() -> void:
	_passed = 0
	_failed = 0
	print("\n=== BW26I actual inherited worker-receipt route commissioning ===")
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var contract := _read_json(BW26I_CONTRACT_PATH)
	var manifest := _read_json(BW25Y_PREREGISTRATION_PATH)
	var raw_contract: Dictionary = contract.get("raw_receipt_contract", {})
	var common_keys: Array = raw_contract.get("required_common_keys", [])
	var role_keys: Array = raw_contract.get("required_candidate_and_control_keys", [])
	var cells: Array = manifest.get("matrix", {}).get("ordered_cells", [])
	_check(
		String(contract.get("campaign_id", ""))
		== "BW26I-ACTUAL-WORKER-RECEIPT-ROUTE-COMMISSIONING"
		and String(contract.get("gate_id", "")) == "BW26I"
		and cells.size() == 28,
		"the BW26I infrastructure identity and 28 inherited route fixtures are exact",
	)

	var raw_receipts: Array = []
	var candidate_count := 0
	var control_count := 0
	var safety_count := 0
	var actual_constructor_count := 0
	for cell_value in cells:
		var cell: Dictionary = (cell_value as Dictionary).duplicate(true)
		var role := String(cell.get("role", ""))
		cell["cohort"] = "bw26i_%s_route_fixture" % role
		_configure_cell(cell)
		var prepared := (
			_prepare_zero_safety(cell) if role == "safety" else _prepare_cell(0)
		)
		var summary := (
			_perfect_safety_summary(prepared)
			if role == "safety"
			else _perfect_physical_summary(cell, prepared)
		)
		var world_attempt_id := "BW26I-ZW::%s" % String(cell["cell_id"])
		var receipt := ActualWorkerReceiptRouteScript.compose(
			self,
			cell,
			summary,
			common_keys,
			[] if role == "safety" else role_keys,
			BW26I_CAMPAIGN_ATTEMPT_ID,
			world_attempt_id,
		)
		_clear_cell_configuration()
		raw_receipts.append(receipt.duplicate(true))
		actual_constructor_count += 1
		if role == "candidate":
			candidate_count += 1
		elif role == "control":
			control_count += 1
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
		BW26I_CAMPAIGN_ATTEMPT_ID,
		"BW26I-ZW::MISSING-COHORT-CANARY",
	)
	var missing_cohort_rejected := (
		not bool(missing_cohort_canary.get("raw_receipt_complete", true))
		and (
			missing_cohort_canary.get("receipt_route_failure_codes", []) as Array
		).has("MISSING_DECLARED_COHORT")
	)
	_check(missing_cohort_rejected, "an undeclared inherited cohort fails before constructor entry")

	var negative_cell: Dictionary = (cells[1] as Dictionary).duplicate(true)
	negative_cell["cohort"] = "bw26i_candidate_route_fixture"
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
		BW26I_CAMPAIGN_ATTEMPT_ID,
		"BW26I-ZW::%s" % String(negative_cell["cell_id"]),
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
		and scene_tree_insertion_count == 0
		and not physics_state_modified
	)
	var aggregate := {
		"schema_version":
		"sporespore_balanced_wave_bw26i_actual_worker_receipt_route_godot_v1",
		"ok": aggregate_ok,
		"campaign_id": "BW26I-ACTUAL-WORKER-RECEIPT-ROUTE-COMMISSIONING",
		"gate_id": "BW26I",
		"campaign_attempt_id": BW26I_CAMPAIGN_ATTEMPT_ID,
		"raw_receipts": raw_receipts,
		"raw_receipt_count": raw_receipts.size(),
		"candidate_receipt_count": candidate_count,
		"control_receipt_count": control_count,
		"safety_receipt_count": safety_count,
		"actual_inherited_constructor_call_count": actual_constructor_count,
		"missing_declared_cohort_canary": missing_cohort_canary,
		"missing_declared_cohort_rejected": missing_cohort_rejected,
		"negative_walking_raw_receipt": negative_receipt,
		"negative_walking_raw_receipt_complete": negative_receipt_complete,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"physics_state_modified": physics_state_modified,
		"locomotion_outcome_exposed": false,
		"walking_acceptance": false,
		"turning_acceptance": false,
		"material_robustness": false,
		"physical_acceptance_authority": false,
	}
	print(BW26I_PREFIX, JSON.stringify(aggregate, "", true, true))
	if aggregate_ok:
		print(
			"BW26I_ACTUAL_WORKER_ROUTE_GODOT_PASS receipts=28 candidates=24 "
			+ "controls=3 safety=1 constructors=28 worlds=0 physical_authority=False"
		)
	quit(0 if aggregate_ok else 1)


func _perfect_physical_summary(cell: Dictionary, prepared: Dictionary) -> Dictionary:
	var residual_expected := String(cell["role"]) == "candidate"
	var nonzero_effective_application_count := 8 if residual_expected else 0
	var maximum_applied_velocity := 0.001 if residual_expected else 0.0
	var is_successor := String(cell["candidate_id"]) == "BW25Y-B"
	var walking_gates: Dictionary = {}
	for gate_id in PERFECT_WALKING_GATE_IDS:
		walking_gates[String(gate_id)] = true
	if String(cell["candidate_id"]) == "BW25Y-A":
		walking_gates["bounded_lateral_drift"] = false
	var controller_mechanism := {
		"schema_version": "sporespore_forward_velocity_foot_placement_execution_summary_v1",
		"enabled": true,
		"mode_id": "forward_velocity_foot_placement_v1",
		"velocity_error_orientation_id": "desired_minus_measured_forward_velocity_error_v1",
		"receipt_count": SYNTHETIC_STEP_COUNT,
		"morphology_branch_surface_count": 0,
		"controller_parameter": true,
		"maximum_absolute_normalized_forward_velocity_error": 0.25,
		"maximum_absolute_hip_target_correction_rad": 0.01,
		"maximum_declared_hip_target_correction_rad": 0.03,
		"walking_claim_authorized": false,
		"physical_acceptance_authority": false,
	}
	var load_transfer := {
		"enabled": true,
		"policy_id": BW25Y_STABILITY_POLICY_ID,
		"portable_plan_operation": "plan_scheduled_load_transfer_v3_json",
		"receipt_schema_version": "sporespore_scheduled_load_transfer_receipt_v3",
		"receipt_count": SYNTHETIC_STEP_COUNT,
		"active_step_count": 0,
		"preferred_normal_step_count": 0,
		"remaining_centroid_step_count": 0,
		"available_receipt_count": SYNTHETIC_STEP_COUNT,
		"observation_unavailable_receipt_count": 0,
		"upstream_infeasible_receipt_count": 0,
		"fail_zero_receipt_count": 0,
		"activation_uses_scheduler_boundaries_only": true,
		"morphology_branch_surface_count": 0,
	}
	var contribution := {
		"schema_version": "sporespore_godot_jolt_stability_contribution_shadow_summary_v1",
		"ok": true,
		"influence_operation": "bound_stability_influence_v3_json",
		"global_scale_applied_before_magnitude_and_slew": true,
		"global_requested_correction_scale": float(cell["global_requested_correction_scale"]),
		"attempt_count": SYNTHETIC_STEP_COUNT,
		"influence_output_count": SYNTHETIC_MOTOR_WRITE_COUNT,
		"untyped_count": 0,
		"profile_conversion_failure_count": 0,
		"limiter_mismatch_count": 0,
		"inactive_zero_mismatch_count": 0,
		"mismatch_count": 0,
		"failure_codes": [],
		"feedback_nonzero_attempt_count": SYNTHETIC_STEP_COUNT,
		"maximum_absolute_proposed_velocity_rad_s": 0.01,
		"maximum_absolute_applied_velocity_rad_s": maximum_applied_velocity,
	}
	var overlay := {
		"schema_version": "sporespore_godot_jolt_stability_overlay_summary_v1",
		"ok": true,
		"policy_id": BW25Y_STABILITY_POLICY_ID,
		"authority_scope": "post_settle_full",
		"application_step_count": SYNTHETIC_STEP_COUNT,
		"motor_write_count": SYNTHETIC_MOTOR_WRITE_COUNT,
		"portable_controller_base_application_count": SYNTHETIC_MOTOR_WRITE_COUNT,
		"nonzero_effective_application_count": nonzero_effective_application_count,
		"combined_speed_limit_violation_count": 0,
		"failure_count": 0,
		"failure_codes": [],
		"physical_influence": true,
	}
	var sdk_summary := {
		"ok": true,
		"actuation_authority": true,
		"controller_policy_id": String(cell["controller_policy_id"]),
		"controller_profile_sha256": String(cell["runtime_profile_sha256"]),
		"adapter_capability_sha256": "sha256:" + ("a".repeat(64)),
		"stability_policy_id": BW25Y_STABILITY_POLICY_ID,
		"authority_scope": "post_settle_full",
		"step_count": SYNTHETIC_STEP_COUNT,
		"validated_balanced_wave_command_count": SYNTHETIC_MOTOR_WRITE_COUNT,
		"native_actuation_application_count": SYNTHETIC_MOTOR_WRITE_COUNT,
		"mismatch_count": 0,
		"safe_no_actuation_count": 0,
		"native_safe_disable_application_count": 0,
		"failure_codes": [],
		"forward_velocity_foot_placement_summary": controller_mechanism,
		"scheduled_load_transfer_summary": load_transfer,
		"stability_contribution_shadow_summary": contribution,
		"stability_overlay_summary": overlay,
		"stability_overlay_runtime_ok": true,
		"minimum_cross_track_error_m": -0.08 if is_successor else -0.16,
		"maximum_cross_track_error_m": 0.10 if is_successor else 0.20,
		"cumulative_absolute_cross_track_error_m_s": 0.40 if is_successor else 0.80,
		"steering_feedback_update_count": SYNTHETIC_STEP_COUNT,
		"steering_filter_application_count": SYNTHETIC_STEP_COUNT,
		"steering_saturation_count": 0,
		"steering_slew_limited_count": 0,
		"maximum_absolute_requested_steering_fraction": 0.25 if is_successor else 0.18,
		"maximum_absolute_filtered_steering_fraction": 0.20 if is_successor else 0.15,
		"maximum_absolute_steering_delta_per_step": 0.01,
	}
	var fixture_spec: Dictionary = (prepared["fixture_spec"] as Dictionary).duplicate(true)
	var material_profile: Dictionary = (prepared["material_profile"] as Dictionary).duplicate(true)
	return {
		"ok": true,
		"failure_code": "",
		"world_build_count": 1,
		"world_reset_count": 0,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"body_count": 9,
		"limb_count": 4,
		"executed_ticks": 244,
		"sdk_adapter_start_tick": 240,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"legacy_post_settle_actuation_application_count": 0,
		"legacy_evidence_actuation_application_count": 0,
		"legacy_sdk_overlay_base_application_count": 0,
		"sdk_full_authority_stability_contribution_enabled": true,
		"sdk_p5i3c_fixed_exposure_enabled": false,
		"sdk_authority_enabled": true,
		"sdk_authority_scope": "post_settle_full",
		"sdk_authority_failure_code": "",
		"sdk_authority_start_result": {
			"adapter_manifest": {
				"execution_mode": BW25Y_EXECUTION_MODE,
				"stability_influence_scale_authority": "portable_core_v3",
				"stability_influence_global_scale":
				float(cell["global_requested_correction_scale"]),
				"controller_profile": {
					"yaw_error_stride_gain_per_rad":
					float(cell["yaw_error_stride_gain_per_rad"]),
				},
				"stability_v3": {
					"feedback_policy": {
						"enabled": true,
						"portable_plan_operation": "plan_scheduled_load_transfer_v3_json",
					},
					"physical_overlay": {
						"enabled": true,
						"base_command": "portable_balanced_wave_ordered_command",
					},
				},
			},
		},
		"sdk_authority_summary": sdk_summary,
		"walking_gate_receipts": walking_gates,
		"physical_wave_gait_walking_observed": _all_true(walking_gates),
		"contact_gate_timeout_count_by_limb": {
			"front_left": 0,
			"front_right": 0,
			"rear_left": 0,
			"rear_right": 0,
		},
		"evidence_torso_displacement_world_m": Vector3(0.25, 0.0, 0.01),
		"final_torso_displacement_world_m": Vector3(0.20, 0.0, 0.01),
		"evidence_task_frame_forward_displacement_m": 0.25,
		"final_task_frame_forward_displacement_m": 0.20,
		"final_task_frame_lateral_displacement_m": 0.02 if is_successor else 0.04,
		"maximum_tilt_rad": 0.05,
		"minimum_torso_height_m": 0.80,
		"maximum_anchor_error_m": 0.005,
		"maximum_hinge_axis_error_rad": 0.01,
		"initial_torso_position_world_m": Vector3(0.0, 1.0, 0.0),
		"initial_torso_orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"initial_perturbation": {
			"fixture_yaw_rad": 0.0,
			"gait_phase_offset_ticks": int(cell["campaign_seed"]) % 4,
			"fixture_vertical_clearance_m": 0.0,
		},
		"fixture_spec": fixture_spec,
		"fixture_spec_sha256": String(prepared["fixture_spec_sha256"]),
		"sdk_material_profile": material_profile,
		"sdk_material_profile_sha256": String(cell["profile_digest"]),
		"evidence_threshold_configuration_sha256": "sha256:" + ("e".repeat(64)),
		"solver_policy_configuration_sha256": "sha256:" + ("d".repeat(64)),
		"controller_configuration_sha256": "sha256:" + ("c".repeat(64)),
	}


func _perfect_safety_summary(prepared: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"failure_code": "",
		"world_build_count": 1,
		"world_reset_count": 0,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"body_count": 9,
		"limb_count": 4,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"physical_wave_gait_walking_observed": false,
		"fixture_spec": (prepared["fixture_spec"] as Dictionary).duplicate(true),
		"fixture_spec_sha256": String(prepared["fixture_spec_sha256"]),
		"evidence_threshold_configuration_sha256": "sha256:" + ("e".repeat(64)),
		"solver_policy_configuration_sha256": "sha256:" + ("d".repeat(64)),
		"controller_configuration_sha256": "sha256:" + ("c".repeat(64)),
		"initial_perturbation": {
			"fixture_yaw_rad": 0.0,
			"gait_phase_offset_ticks": 0,
			"fixture_vertical_clearance_m": 0.0,
		},
		"initial_torso_position_world_m": Vector3(0.0, 1.0, 0.0),
		"initial_torso_orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"maximum_tilt_rad": 0.05,
		"minimum_torso_height_m": 0.80,
		"maximum_anchor_error_m": 0.005,
		"maximum_hinge_axis_error_rad": 0.01,
	}
