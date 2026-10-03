extends "res://tests/test_sdk_balanced_wave_bw22l_lateral_development.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Exact zero-world regression for the final BW22L physical receipt composer.
##
## A generic predecessor preflight proved the policy-relative binder, but it
## did not prove that BW22L's final wrapper retained the binder's nested
## identity receipt. This test passes a realistic perfect summary through the
## exact BW22L -> BW20F -> BW17P -> R05 stack for both candidates and the
## zero-residual control. It also proves that the inherited unbound wrapper and
## an observed policy mismatch both fail closed, without constructing a world.

const RECEIPT_PARITY_PREFIX := "BW22L_POLICY_RECEIPT_COMPOSITION "
const HISTORICAL_FIXED_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
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
	print("\n=== BW22L final physical receipt composition preflight ===")
	var root_children_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var manifest := _read_json(BW22L_PREREGISTRATION_PATH)
	var cells := _representative_cells(manifest)
	_check(cells.size() == 3, "three representative policy/role cells are declared")

	var perfect_receipt_count := 0
	var candidate_receipt_count := 0
	var control_receipt_count := 0
	var historical_hardcode_canary_count := 0
	var identity_mismatch_canary_count := 0
	var observed_policy_ids: Array = []
	for cell_value in cells:
		var cell: Dictionary = cell_value
		_configure_cell(cell)
		var prepared := _prepare_cell(0)
		var prepared_exact := (
			bool(prepared.get("ok", false))
			and int(prepared.get("world_build_count", -1)) == 0
			and not bool(prepared.get("physical_acceptance_authority", true))
		)
		_check(prepared_exact, "%s fixture/profile compiles without a world" % cell["candidate_id"])
		if not prepared_exact:
			_clear_cell_configuration()
			continue

		var summary := _perfect_physical_summary(cell, prepared)
		var declared_policy_id := String(cell["controller_policy_id"])
		var role := String(cell["role"])
		var residual_expected := role == "candidate"
		var historical_receipt := _bw20f_physical_cell_receipt(cell, summary)
		var receipt := _bw22l_physical_cell_receipt(cell, summary)
		var policy_relative_common: Dictionary = (
			receipt
			. get(
				"policy_relative_common_execution",
				{},
			)
		)
		var exact_receipt := (
			String(receipt.get("controller_policy_id", "")) == declared_policy_id
			and String(receipt.get("declared_controller_policy_id", "")) == declared_policy_id
			and (
				String(policy_relative_common.get("schema_version", ""))
				== "sporespore_policy_relative_execution_integrity_v1"
			)
			and bool(policy_relative_common.get("ok", false))
			and bool(receipt.get("profile_binding_exact", false))
			and bool(receipt.get("common_execution_integrity", false))
			and bool(receipt.get("mechanism_gate_passed", false))
			and bool(receipt.get("outcome_complete", false))
			and (
				bool(receipt.get("residual_application_expected", not residual_expected))
				== residual_expected
			)
			and (
				bool(receipt.get("residual_application_observed", not residual_expected))
				== residual_expected
			)
			and bool(receipt.get("combined_application_gate_passed", false)) == residual_expected
			and int(receipt.get("sdk_mismatch_count", -1)) == 0
			and int(receipt.get("sdk_failure_count", -1)) == 0
			and _role_gate_passed(receipt)
			and not bool(receipt.get("walking_claim_authorized", true))
			and not bool(receipt.get("material_acceptance_claim_authorized", true))
			and not bool(receipt.get("physical_acceptance_authority", true))
		)
		if not exact_receipt:
			print(
				"POLICY_AWARE_PHYSICAL_RECEIPT_FAILURE ",
				(
					JSON
					. stringify(
						{
							"candidate_id": String(cell["candidate_id"]),
							"candidate_index": _candidate_index(),
							"controller_policy_id": String(receipt.get("controller_policy_id", "")),
							"declared_controller_policy_id": declared_policy_id,
							"profile_binding_exact":
							bool(receipt.get("profile_binding_exact", false)),
							"common_execution_integrity":
							bool(receipt.get("common_execution_integrity", false)),
							"mechanism_gate_passed":
							bool(receipt.get("mechanism_gate_passed", false)),
							"outcome_complete": bool(receipt.get("outcome_complete", false)),
							"residual_application_expected":
							bool(
								receipt.get("residual_application_expected", not residual_expected)
							),
							"residual_application_observed":
							bool(
								receipt.get("residual_application_observed", not residual_expected)
							),
							"combined_application_gate_passed":
							bool(receipt.get("combined_application_gate_passed", false)),
							"sdk_mismatch_count": int(receipt.get("sdk_mismatch_count", -1)),
							"sdk_failure_count": int(receipt.get("sdk_failure_count", -1)),
							"role_gate_passed": _role_gate_passed(receipt),
						},
						"",
						true,
						true,
					)
				)
			)
		_check(
			exact_receipt,
			"%s perfect summary passes the exact composed role gate" % cell["candidate_id"]
		)
		if exact_receipt:
			perfect_receipt_count += 1
		observed_policy_ids.append(String(receipt.get("controller_policy_id", "")))
		if role == "candidate":
			candidate_receipt_count += 1
		else:
			control_receipt_count += 1

		if declared_policy_id != HISTORICAL_FIXED_POLICY_ID:
			var historical_rejected := (
				not bool(historical_receipt.get("common_execution_integrity", true))
				and not _role_gate_passed(historical_receipt)
				and bool(receipt.get("common_execution_integrity", false))
				and _role_gate_passed(receipt)
			)
			_check(
				historical_rejected,
				"%s historical fixed-BW15F predicate is a rejecting canary" % cell["candidate_id"],
			)
			if historical_rejected:
				historical_hardcode_canary_count += 1

		var mismatched_summary := summary.duplicate(true)
		var mismatched_sdk_summary: Dictionary = (
			(mismatched_summary["sdk_authority_summary"] as Dictionary).duplicate(true)
		)
		mismatched_sdk_summary["controller_policy_id"] = _different_policy_id(declared_policy_id)
		mismatched_summary["sdk_authority_summary"] = mismatched_sdk_summary
		var mismatched_receipt := _bw22l_physical_cell_receipt(
			cell,
			mismatched_summary,
		)
		var mismatch_rejected := (
			(
				String(mismatched_receipt.get("controller_policy_id", ""))
				== String(mismatched_sdk_summary["controller_policy_id"])
			)
			and not bool(mismatched_receipt.get("common_execution_integrity", true))
			and not _role_gate_passed(mismatched_receipt)
		)
		_check(mismatch_rejected, "%s observed policy mismatch fails closed" % cell["candidate_id"])
		if mismatch_rejected:
			identity_mismatch_canary_count += 1
		_clear_cell_configuration()

	var actual_world_build_count := 0
	var scene_tree_insertion_count := root.get_child_count() - root_children_before
	var physics_state_modified := Engine.physics_ticks_per_second != physics_hz_before
	var aggregate_ok := (
		_failed == 0
		and perfect_receipt_count == 3
		and candidate_receipt_count == 2
		and control_receipt_count == 1
		and historical_hardcode_canary_count == 1
		and identity_mismatch_canary_count == 3
		and (
			observed_policy_ids
			== [
				BW22L_POLICY_IDS[0],
				BW22L_POLICY_IDS[1],
				BW22L_POLICY_IDS[0],
			]
		)
		and scene_tree_insertion_count == 0
		and not physics_state_modified
	)
	var aggregate := {
		"schema_version": "sporespore_policy_aware_physical_receipt_composition_preflight_v1",
		"ok": aggregate_ok,
		"perfect_composed_receipt_count": perfect_receipt_count,
		"candidate_receipt_count": candidate_receipt_count,
		"control_receipt_count": control_receipt_count,
		"historical_fixed_bw15f_hardcode_canary_count": historical_hardcode_canary_count,
		"observed_policy_mismatch_canary_count": identity_mismatch_canary_count,
		"observed_policy_ids": observed_policy_ids,
		"synthetic_declared_physical_summary_count": cells.size(),
		"actual_world_build_count": actual_world_build_count,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"physics_state_modified": physics_state_modified,
		"locomotion_outcome_exposed": false,
		"walking_acceptance": false,
		"material_robustness": false,
		"physical_acceptance_authority": false,
	}
	print(RECEIPT_PARITY_PREFIX, JSON.stringify(aggregate, "", true, true))
	if aggregate_ok:
		print(
			(
				"BW22L_POLICY_RECEIPT_COMPOSITION_PASS "
				+ "summaries=3 candidates=2 controls=1 inherited_drop_canaries=1 "
				+ "mismatch_canaries=3 worlds=0 physical_authority=False"
			)
		)
	quit(0 if aggregate_ok else 1)


func _representative_cells(manifest: Dictionary) -> Array:
	if manifest.is_empty():
		return []
	var ordered_cells: Array = manifest.get("matrix", {}).get("ordered_cells", [])
	var result: Array = []
	for candidate_id in BW22L_CANDIDATE_IDS:
		for cell_value in ordered_cells:
			var cell: Dictionary = cell_value
			if (
				String(cell.get("role", "")) == "candidate"
				and String(cell.get("candidate_id", "")) == String(candidate_id)
			):
				result.append(cell.duplicate(true))
				break
	for cell_value in ordered_cells:
		var cell: Dictionary = cell_value
		if String(cell.get("role", "")) == "control":
			result.append(cell.duplicate(true))
			break
	return result


func _perfect_physical_summary(cell: Dictionary, prepared: Dictionary) -> Dictionary:
	var residual_expected := String(cell["role"]) == "candidate"
	var nonzero_effective_application_count := 8 if residual_expected else 0
	var maximum_applied_velocity := 0.001 if residual_expected else 0.0
	var walking_gates: Dictionary = {}
	for gate_id in PERFECT_WALKING_GATE_IDS:
		walking_gates[String(gate_id)] = true
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
		"policy_id": BW22L_STABILITY_POLICY_ID,
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
		"policy_id": BW22L_STABILITY_POLICY_ID,
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
		"adapter_capability_sha256": "sha256:synthetic_policy_aware_receipt_preflight",
		"stability_policy_id": BW22L_STABILITY_POLICY_ID,
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
		"minimum_cross_track_error_m": -0.05,
		"maximum_cross_track_error_m": 0.05,
		"cumulative_absolute_cross_track_error_m_s": 0.25,
		"steering_feedback_update_count": SYNTHETIC_STEP_COUNT,
		"steering_filter_application_count": SYNTHETIC_STEP_COUNT,
		"steering_saturation_count": 0,
		"steering_slew_limited_count": 0,
		"maximum_absolute_requested_steering_fraction": 0.10,
		"maximum_absolute_filtered_steering_fraction": 0.08,
		"maximum_absolute_steering_delta_per_step": 0.01,
	}
	var material_profile: Dictionary = (prepared["material_profile"] as Dictionary).duplicate(true)
	var fixture_spec: Dictionary = (prepared["fixture_spec"] as Dictionary).duplicate(true)
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
		"sdk_authority_start_result":
		{
			"adapter_manifest":
			{
				"execution_mode": BW22L_EXECUTION_MODE,
				"stability_influence_scale_authority": "portable_core_v3",
				"stability_influence_global_scale":
				float(cell["global_requested_correction_scale"]),
				"stability_v3":
				{
					"feedback_policy":
					{
						"enabled": true,
						"portable_plan_operation": "plan_scheduled_load_transfer_v3_json",
					},
					"physical_overlay":
					{
						"enabled": true,
						"base_command": "portable_balanced_wave_ordered_command",
					},
				},
			},
		},
		"sdk_authority_summary": sdk_summary,
		"walking_gate_receipts": walking_gates,
		"physical_wave_gait_walking_observed": true,
		"contact_gate_timeout_count_by_limb":
		{
			"front_left": 0,
			"front_right": 0,
			"rear_left": 0,
			"rear_right": 0,
		},
		"evidence_torso_displacement_world_m": Vector3(0.25, 0.0, 0.01),
		"final_torso_displacement_world_m": Vector3(0.20, 0.0, 0.01),
		"evidence_task_frame_forward_displacement_m": 0.25,
		"final_task_frame_forward_displacement_m": 0.20,
		"final_task_frame_lateral_displacement_m": 0.01,
		"maximum_tilt_rad": 0.05,
		"minimum_torso_height_m": 0.80,
		"maximum_anchor_error_m": 0.005,
		"maximum_hinge_axis_error_rad": 0.01,
		"initial_torso_position_world_m": Vector3(0.0, 1.0, 0.0),
		"initial_torso_orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"initial_perturbation":
		{
			"fixture_yaw_rad": 0.0,
			"gait_phase_offset_ticks": 0,
			"fixture_vertical_clearance_m": 0.0,
		},
		"fixture_spec": fixture_spec,
		"fixture_spec_sha256": String(prepared["fixture_spec_sha256"]),
		"sdk_material_profile": material_profile,
		"sdk_material_profile_sha256": String(cell["profile_digest"]),
		"evidence_threshold_configuration_sha256": "sha256:synthetic_thresholds",
		"solver_policy_configuration_sha256": "sha256:synthetic_solver_policy",
		"controller_configuration_sha256": "sha256:synthetic_controller_configuration",
	}


func _different_policy_id(declared_policy_id: String) -> String:
	for policy_id in BW22L_POLICY_IDS:
		if String(policy_id) != declared_policy_id:
			return String(policy_id)
	return "sporespore_invalid_policy_identity_canary"
