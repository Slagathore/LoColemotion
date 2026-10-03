extends "res://tests/test_sdk_godot_jolt_material_robustness.gd"
# gdlint: disable=max-file-lines

## Zero-world satisfiability proof for the physical entrypoint and exact
## post-physics gate.
##
## Every declared policy first traverses the real physical entrypoint through
## all validation preceding fixture construction. It then executes the real
## portable planner, endpoint-force mapper, and bounded-influence path against
## deterministic available and unavailable observations. Those real receipts,
## rather than hand-authored activity counts, feed the same full analysis path
## used by physical campaign cells. No fixture or physics world is constructed.

const GateAdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const GateWaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
const GateClockSpecScript := preload(
	"res://scripts/lab/gait/physical_gait_clock_spec.gd"
)
const GateMaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const GATE_POLICY_IDS := [
	"sporespore_scheduled_load_transfer_bw11r_a_v3",
	"sporespore_scheduled_load_transfer_bw11r_b_v3",
	"sporespore_scheduled_load_transfer_bw11r_c_v3",
	"sporespore_scheduled_load_transfer_bw11r_d_v3",
	"sporespore_scheduled_load_transfer_bw13p_a_v3",
	"sporespore_scheduled_load_transfer_bw13p_b_v3",
	"sporespore_scheduled_load_transfer_bw13p_c_v3",
	"sporespore_scheduled_load_transfer_bw13p_d_v3",
]
const GATE_POLICY_MODES := [
	"control",
	"preferred_normal_force",
	"remaining_support_centroid",
	"combined",
	"control",
	"preferred_normal_force",
	"remaining_support_centroid",
	"combined",
]
## Each four-arm family has one factorial control that disables both scheduled
## load-transfer factors, not the shared baseline centroidal correction. Every
## policy therefore has a real nonzero baseline witness in the deliberately
## off-center synthetic available state. Factor activity is checked separately.
const GATE_EXPECT_NONZERO_BASELINE_ACTIVITY := [
	true,
	true,
	true,
	true,
	true,
	true,
	true,
	true,
]
const GATE_BASE_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const GATE_FULL_AUTHORITY_STABILITY_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const GATE_FULL_AUTHORITY_SCOPE := "post_settle_full"
const GATE_DECLARED_SIGNED_PHASE_OFFSETS := [-3, -2]
const GATE_GAIT_STEPS := {
	"front_left": 54,
	"front_right": 54,
	"rear_left": 54,
	"rear_right": 54,
}

var _gate_declared_policy_id := ""
var _gate_expect_nonzero_activity := false
var _gate_passed := 0
var _gate_failed := 0


func _run() -> void:
	print("\n=== SDK full integrity-gate satisfiability preflight ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var profile_result: Dictionary = GateMaterialProfilesScript.resolve("godot_jolt_bw5c_mu095_v1")
	var profile: Dictionary = profile_result.get("profile", {})
	var profile_sha256 := String(profile_result.get("profile_sha256", ""))
	_gate_check(
		(
			bool(profile_result.get("ok", false))
			and not profile.is_empty()
			and profile_sha256.begins_with("sha256:")
		),
		"0 frozen material profile resolves without constructing a world",
	)
	if profile.is_empty():
		_gate_finish()
		return

	var selected_policy_full_authority_start := _selected_policy_full_authority_start(
		profile,
	)
	_gate_check(
		bool(selected_policy_full_authority_start.get("ok", false)),
		"1 selected BW5R-B reaches exact full-authority adapter start without a world",
	)

	_bw2_policy_id = GATE_BASE_CONTROLLER_POLICY_ID
	var runtime_boundary_witnesses: Array = []
	var runtime_boundaries_exact := true
	for policy_index in range(4, GATE_POLICY_IDS.size()):
		var policy_id := String(GATE_POLICY_IDS[policy_index])
		for phase_offset_value in GATE_DECLARED_SIGNED_PHASE_OFFSETS:
			var runtime_witness := _real_policy_runtime_boundary_witness(
				profile,
				policy_id,
				int(phase_offset_value),
			)
			runtime_boundary_witnesses.append(runtime_witness)
			runtime_boundaries_exact = (
				runtime_boundaries_exact
				and bool(runtime_witness.get("ok", false))
				and (
					String(runtime_witness.get("controller_policy_id", ""))
					== GATE_BASE_CONTROLLER_POLICY_ID
				)
				and (
					String(runtime_witness.get("stability_policy_id", ""))
					== policy_id
				)
				and (
					int(
						runtime_witness.get(
							"requested_phase_offset_ticks",
							-99,
						)
					)
					== int(phase_offset_value)
				)
				and bool(
					runtime_witness.get(
						"gait_memory_nonnegative",
						false,
					)
				)
				and bool(
					runtime_witness.get(
						"native_controller_step_passed",
						false,
					)
				)
				and bool(
					runtime_witness.get(
						"portable_scheduled_plan_passed",
						false,
					)
				)
				and bool(
					runtime_witness.get(
						"execution_mode_plan_passed",
						false,
					)
				)
				and (
					int(runtime_witness.get("native_controller_command_count", -1))
					== 8
				)
				and int(runtime_witness.get("actual_world_build_count", -1)) == 0
				and int(runtime_witness.get("scene_tree_insertion_count", -1)) == 0
				and not bool(runtime_witness.get("physics_state_modified", true))
				and not bool(runtime_witness.get("locomotion_outcome_exposed", true))
			)
	_gate_check(
		(
			runtime_boundaries_exact
			and runtime_boundary_witnesses.size()
			== 4 * GATE_DECLARED_SIGNED_PHASE_OFFSETS.size()
		),
		"2 every BW13P policy and signed offset crosses its real runtime boundary",
	)
	var worst_case_runtime_horizon := _real_policy_runtime_horizon_witness(
		profile,
		String(GATE_POLICY_IDS[4]),
		int(GATE_DECLARED_SIGNED_PHASE_OFFSETS[0]),
	)
	var worst_case_runtime_horizon_exact := (
		bool(worst_case_runtime_horizon.get("ok", false))
		and (
			String(worst_case_runtime_horizon.get("schema_version", ""))
			== "sporespore_declared_policy_runtime_horizon_preflight_v1"
		)
		and bool(
			worst_case_runtime_horizon.get(
				"execution_mode_plan_passed",
				false,
			)
		)
		and (
			int(worst_case_runtime_horizon.get("native_controller_step_count", -1))
			== int(worst_case_runtime_horizon.get("declared_step_count", -2))
		)
		and (
			int(worst_case_runtime_horizon.get("portable_scheduled_plan_count", -1))
			== int(worst_case_runtime_horizon.get("declared_step_count", -2))
		)
		and (
			int(worst_case_runtime_horizon.get("phase_mode_transition_count", -1))
			== 3
		)
		and int(worst_case_runtime_horizon.get("actual_world_build_count", -1)) == 0
		and int(worst_case_runtime_horizon.get("scene_tree_insertion_count", -1)) == 0
		and not bool(worst_case_runtime_horizon.get("physics_state_modified", true))
		and not bool(worst_case_runtime_horizon.get("locomotion_outcome_exposed", true))
	)
	_gate_check(
		worst_case_runtime_horizon_exact,
		"3 worst signed offset crosses the complete 3,232-step zero-world runtime horizon",
	)
	var r1_misroute_negative_control := _r1_misroute_negative_control(
		profile,
	)
	var r1_misroute_detected := (
		not bool(r1_misroute_negative_control.get("ok", true))
		and (
			String(r1_misroute_negative_control.get("failure_code", ""))
			== "DECLARED_POLICY_RUNTIME_HORIZON_NEGATIVE_GAIT_MEMORY"
		)
		and int(r1_misroute_negative_control.get("failing_semantic_step", -1)) == 0
		and int(r1_misroute_negative_control.get("actual_world_build_count", -1)) == 0
	)
	_gate_check(
		r1_misroute_detected,
		"4 the retained R1 fixed-exposure misroute is rejected at synthetic step zero",
	)

	var all_policies_satisfiable := true
	var receipts: Array = []
	var entrypoint_receipts: Array = []
	var semantic_witnesses: Array = []
	for index in range(GATE_POLICY_IDS.size()):
		_gate_declared_policy_id = String(GATE_POLICY_IDS[index])
		_gate_expect_nonzero_activity = bool(GATE_EXPECT_NONZERO_BASELINE_ACTIVITY[index])
		var entrypoint_receipt := await _physical_entrypoint_preflight(
			profile,
			_gate_declared_policy_id,
		)
		entrypoint_receipts.append(entrypoint_receipt)
		var semantic_witness := _real_policy_semantic_witness(
			profile,
			_gate_declared_policy_id,
			index,
		)
		semantic_witnesses.append(semantic_witness)
		var receipt := _synthetic_execution_integrity_preflight(
			profile,
			profile_sha256,
			"sha256:%s" % "8".repeat(64),
			{
				"campaign_seed": 0,
				"fixture_vertical_clearance_m": 0.0,
				"fixture_yaw_rad": 0.0,
				"initial_linear_velocity_world_m_s": Vector3.ZERO,
				"initial_torso_angular_velocity_world_rad_s": Vector3.ZERO,
				"gait_phase_offset_ticks": 0,
			},
			_gate_expect_nonzero_activity,
			1,
			semantic_witness,
		)
		receipts.append(receipt)
		all_policies_satisfiable = (
			all_policies_satisfiable
			and bool(entrypoint_receipt.get("ok", false))
			and bool(entrypoint_receipt.get("entrypoint_control_flow_complete", false))
			and (
				String(entrypoint_receipt.get("declared_stability_policy_id", ""))
				== _gate_declared_policy_id
			)
			and (
				String(entrypoint_receipt.get("declared_controller_policy_id", ""))
				== GATE_BASE_CONTROLLER_POLICY_ID
			)
			and int(entrypoint_receipt.get("actual_world_build_count", -1)) == 0
			and int(entrypoint_receipt.get("scene_tree_insertion_count", -1)) == 0
			and not bool(entrypoint_receipt.get("physics_state_modified", true))
			and not bool(entrypoint_receipt.get("locomotion_outcome_exposed", true))
			and not bool(entrypoint_receipt.get("physical_acceptance_authority", true))
			and bool(semantic_witness.get("ok", false))
			and int(semantic_witness.get("actual_world_build_count", -1)) == 0
			and int(semantic_witness.get("scene_tree_insertion_count", -1)) == 0
			and not bool(semantic_witness.get("physics_state_modified", true))
			and bool(receipt.get("ok", false))
			and bool(
				(
					receipt
					. get(
						"common_execution_integrity",
						false,
					)
				)
			)
			and bool(
				(
					receipt
					. get(
						"campaign_execution_gate_passed",
						false,
					)
				)
			)
			and (
				String(
					(
						receipt
						. get(
							"declared_stability_policy_id",
							"",
						)
					)
				)
				== _gate_declared_policy_id
			)
			and (
				int(
					(
						receipt
						. get(
							"synthetic_unavailable_step_count",
							-1,
						)
					)
				)
				== 1
			)
			and int(receipt.get("actual_world_build_count", -1)) == 0
			and not bool(
				(
					receipt
					. get(
						"physical_acceptance_authority",
						true,
					)
				)
			)
		)
	_gate_check(
		all_policies_satisfiable,
		"5 real entrypoint, policy semantics, and exact full gate accept every declaration",
	)

	var factorial_semantics_exact := semantic_witnesses.size() == GATE_POLICY_IDS.size()
	for index in range(semantic_witnesses.size()):
		var witness: Dictionary = semantic_witnesses[index]
		factorial_semantics_exact = (
			factorial_semantics_exact
			and String(witness.get("available_mode", "")) == String(GATE_POLICY_MODES[index])
			and (
				bool(witness.get("available_factor_active", index % 4 == 0))
				== (index % 4 != 0)
			)
			and bool(witness.get("available_feedback_request_nonzero", false))
			and int(witness.get("available_nonzero_mapped_command_count", 0)) > 0
			and int(witness.get("available_nonzero_applied_contribution_count", 0)) > 0
			and (
				index < 4
				or bool(witness.get("full_authority_combined_application_passed", false))
			)
			and bool(witness.get("unavailable_fail_zero_required", false))
			and int(witness.get("unavailable_safe_zero_contribution_count", -1)) == 8
		)
	_gate_check(
		factorial_semantics_exact,
		"6 real receipts separate shared baseline influence from factorial activity",
	)

	## BW12E declared the factorial control as an exact-zero whole-overlay
	## control. Replaying that declaration against the actual A-policy witness
	## must fail before a world; this is the exact regression BW12E exposed.
	_gate_declared_policy_id = GATE_POLICY_IDS[0]
	_gate_expect_nonzero_activity = false
	var bw12e_control_regression := _synthetic_execution_integrity_preflight(
		profile,
		profile_sha256,
		"sha256:%s" % "8".repeat(64),
		{
			"campaign_seed": 0,
			"fixture_vertical_clearance_m": 0.0,
			"fixture_yaw_rad": 0.0,
			"initial_linear_velocity_world_m_s": Vector3.ZERO,
			"initial_torso_angular_velocity_world_rad_s": Vector3.ZERO,
			"gait_phase_offset_ticks": 0,
		},
		false,
		1,
		semantic_witnesses[0],
	)
	var bw12e_control_mismatch_detected := (
		not bool(bw12e_control_regression.get("ok", true))
		and (
			String(bw12e_control_regression.get("failure_code", ""))
			== "DECLARED_POLICY_MECHANISM_UNSATISFIABLE"
		)
	)
	_gate_check(
		bw12e_control_mismatch_detected,
		"7 the BW12E exact-zero control declaration is rejected without a world",
	)

	var missing_semantic_witness := _synthetic_execution_integrity_preflight(
		profile,
		profile_sha256,
		"sha256:%s" % "8".repeat(64),
		{},
		true,
		1,
	)
	var missing_semantic_witness_rejected := (
		not bool(missing_semantic_witness.get("ok", true))
		and (
			String(missing_semantic_witness.get("failure_code", ""))
			== "POLICY_SEMANTIC_WITNESS_REQUIRED"
		)
		and int(missing_semantic_witness.get("actual_world_build_count", -1)) == 0
		and not bool(
			(
				missing_semantic_witness
				. get(
					"physical_acceptance_authority",
					true,
				)
			)
		)
	)
	_gate_check(
		missing_semantic_witness_rejected,
		"8 a caller cannot hand-author activity counts without a real policy witness",
	)

	_gate_declared_policy_id = GATE_POLICY_IDS[3]
	_gate_expect_nonzero_activity = true
	var invalid_count := _synthetic_execution_integrity_preflight(
		profile,
		profile_sha256,
		"sha256:%s" % "8".repeat(64),
		{},
		true,
		EXPECTED_STEP_COUNT + 1,
		semantic_witnesses[3],
	)
	_gate_check(
		(
			not bool(invalid_count.get("ok", true))
			and (
				String(invalid_count.get("failure_code", ""))
				== "SYNTHETIC_UNAVAILABLE_STEP_COUNT_INVALID"
			)
		),
		"9 malformed synthetic partitions fail closed",
	)

	var aggregate := {
		"schema_version": "sporespore_full_integrity_gate_satisfiability_receipt_v5",
		"passed": _gate_failed == 0,
		"policy_ids": GATE_POLICY_IDS,
		"selected_policy_full_authority_start": selected_policy_full_authority_start,
		"declared_signed_phase_offsets": GATE_DECLARED_SIGNED_PHASE_OFFSETS,
		"policy_runtime_boundary_witnesses": runtime_boundary_witnesses,
		"worst_case_runtime_horizon_witness": worst_case_runtime_horizon,
		"worst_case_runtime_horizon_passed": worst_case_runtime_horizon_exact,
		"r1_misroute_negative_control": r1_misroute_negative_control,
		"r1_misroute_detected_before_world": r1_misroute_detected,
		"exact_declared_policy_runtime_boundaries_called": true,
		"exact_worst_case_declared_policy_runtime_horizon_called": true,
		"declared_policy_runtime_boundary_count":
		runtime_boundary_witnesses.size(),
		"declared_policy_runtime_boundaries_passed": runtime_boundaries_exact,
		"production_execution_mode_resolver_called": true,
		"perfect_zero_error_runtime_boundary_on_every_declared_policy": true,
		"perfect_zero_error_full_runtime_horizon_on_worst_signed_offset": true,
		"perfect_synthetic_full_integrity_gate_passed":
		all_policies_satisfiable,
		"entrypoint_receipts": entrypoint_receipts,
		"policy_semantic_witnesses": semantic_witnesses,
		"policy_receipts": receipts,
		"exact_pre_world_entrypoint_called": true,
		"exact_selected_policy_full_authority_start_called": true,
		"selected_policy_full_authority_start_passed":
		bool(selected_policy_full_authority_start.get("ok", false)),
		"real_portable_policy_semantics_called": true,
		"real_endpoint_force_mapping_called": true,
		"real_bounded_influence_called": true,
		"exact_post_physics_gate_called": true,
		"perfect_zero_error_mismatch_failure_and_violation_counts": true,
		"mechanism_activity_counts_derived_from_real_policy_receipts": true,
		"bw12e_exact_zero_control_mismatch_detected": bw12e_control_mismatch_detected,
		"missing_policy_semantic_witness_rejected": missing_semantic_witness_rejected,
		"synthetic_unavailable_step_count_per_policy": 1,
		"real_policy_semantic_sample_count": GATE_POLICY_IDS.size() * 2,
		"observed_world_count": 0,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}
	print(
		"FULL_INTEGRITY_GATE_SATISFIABILITY ",
		JSON.stringify(aggregate, "", true, true),
	)
	_gate_finish()


func _selected_policy_full_authority_start(profile: Dictionary) -> Dictionary:
	var original_physics_hz := Engine.physics_ticks_per_second
	var original_root_child_count := root.get_child_count()
	var adapter: RefCounted = GateAdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			DESCRIPTOR,
			GATE_GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			120,
			SOLVER_POLICY_OPTIONS,
			GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"clocked",
			true,
			0,
			360,
			GATE_FULL_AUTHORITY_SCOPE,
			GATE_FULL_AUTHORITY_STABILITY_POLICY_ID,
			profile,
			GATE_BASE_CONTROLLER_POLICY_ID,
		)
	)
	var manifest: Dictionary = start.get("adapter_manifest", {})
	var scene_tree_insertion_count := root.get_child_count() - original_root_child_count
	var physics_state_modified := Engine.physics_ticks_per_second != original_physics_hz
	var exact := (
		bool(start.get("ok", false))
		and String(start.get("controller_policy_id", "")) == GATE_BASE_CONTROLLER_POLICY_ID
		and String(start.get("authority_scope", "")) == GATE_FULL_AUTHORITY_SCOPE
		and bool(start.get("actuation_authority", false))
		and String(start.get("stability_policy_id", "")) == GATE_FULL_AUTHORITY_STABILITY_POLICY_ID
		and String(manifest.get("controller_policy_id", "")) == GATE_BASE_CONTROLLER_POLICY_ID
		and String(manifest.get("authority_scope", "")) == GATE_FULL_AUTHORITY_SCOPE
		and bool(manifest.get("actuation_authority", false))
		and String(manifest.get("execution_mode", "")) == "native_authority_with_legacy_observer"
		and int(start.get("world_build_count", -1)) == 0
		and scene_tree_insertion_count == 0
		and not physics_state_modified
		and not bool(start.get("physical_acceptance_authority", true))
	)
	return {
		"schema_version": "sporespore_selected_policy_full_authority_start_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "SELECTED_POLICY_FULL_AUTHORITY_START_INVALID",
		"controller_policy_id": String(start.get("controller_policy_id", "")),
		"authority_scope": String(start.get("authority_scope", "")),
		"actuation_authority": bool(start.get("actuation_authority", false)),
		"stability_policy_id": String(start.get("stability_policy_id", "")),
		"adapter_capability_sha256": String(start.get("adapter_capability_sha256", "")),
		"phase_offset_synchronization_receipt":
		(start.get("phase_offset_synchronization_receipt", {}) as Dictionary).duplicate(true),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"physics_state_modified": physics_state_modified,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _real_policy_runtime_boundary_witness(
	profile: Dictionary,
	stability_policy_id: String,
	phase_offset_ticks: int,
) -> Dictionary:
	return _real_policy_runtime_witness(
		profile,
		stability_policy_id,
		phase_offset_ticks,
		false,
	)


func _real_policy_runtime_horizon_witness(
	profile: Dictionary,
	stability_policy_id: String,
	phase_offset_ticks: int,
) -> Dictionary:
	return _real_policy_runtime_witness(
		profile,
		stability_policy_id,
		phase_offset_ticks,
		true,
	)


func _real_policy_runtime_witness(
	profile: Dictionary,
	stability_policy_id: String,
	phase_offset_ticks: int,
	complete_horizon: bool,
) -> Dictionary:
	var original_physics_hz := Engine.physics_ticks_per_second
	var original_root_child_count := root.get_child_count()
	var execution_mode_plan := GateWaveGaitScript.compile_sdk_execution_mode_plan(
		true,
		true,
		GATE_FULL_AUTHORITY_SCOPE,
		stability_policy_id,
		phase_offset_ticks,
	)
	if not bool(execution_mode_plan.get("ok", false)):
		return {
			"schema_version":
			(
				"sporespore_declared_policy_runtime_horizon_preflight_v1"
				if complete_horizon
				else "sporespore_declared_policy_runtime_boundary_preflight_v1"
			),
			"ok": false,
			"failure_code":
			(
				"DECLARED_POLICY_RUNTIME_HORIZON_EXECUTION_MODE:%s"
				% String(execution_mode_plan.get("failure_code", "UNKNOWN"))
			),
			"controller_policy_id": GATE_BASE_CONTROLLER_POLICY_ID,
			"stability_policy_id": stability_policy_id,
			"requested_phase_offset_ticks": phase_offset_ticks,
			"execution_mode_plan": execution_mode_plan.duplicate(true),
			"execution_mode_plan_passed": false,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count":
			root.get_child_count() - original_root_child_count,
			"physics_state_modified":
			Engine.physics_ticks_per_second != original_physics_hz,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
	var initial_gait_steps: Dictionary = (
		execution_mode_plan.get("zero_base_initial_gait_steps", {}) as Dictionary
	).duplicate(true)
	var adapter: RefCounted = GateAdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			DESCRIPTOR,
			initial_gait_steps,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			120,
			SOLVER_POLICY_OPTIONS,
			GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"clocked",
			true,
			phase_offset_ticks,
			360,
			GATE_FULL_AUTHORITY_SCOPE,
			stability_policy_id,
			profile,
			GATE_BASE_CONTROLLER_POLICY_ID,
		)
	)
	if not bool(start.get("ok", false)):
		return {
			"schema_version":
			(
				"sporespore_declared_policy_runtime_horizon_preflight_v1"
				if complete_horizon
				else "sporespore_declared_policy_runtime_boundary_preflight_v1"
			),
			"ok": false,
			"failure_code":
			(
				"DECLARED_POLICY_RUNTIME_BOUNDARY_START:%s"
				% String(start.get("failure_code", "UNKNOWN"))
			),
			"controller_policy_id": GATE_BASE_CONTROLLER_POLICY_ID,
			"stability_policy_id": stability_policy_id,
			"requested_phase_offset_ticks": phase_offset_ticks,
			"execution_mode_plan": execution_mode_plan.duplicate(true),
			"execution_mode_plan_passed":
			bool(execution_mode_plan.get("ok", false)),
			"actual_world_build_count": 0,
			"scene_tree_insertion_count":
			root.get_child_count() - original_root_child_count,
			"physics_state_modified":
			Engine.physics_ticks_per_second != original_physics_hz,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
	var witness: Dictionary
	if complete_horizon:
		var clock := GateClockSpecScript.gq15_clock()
		var contact_gated_start_step := (
			int(clock["warmup_cycles"]) * int(clock["cycle_ticks"])
			+ int(clock["evidence_boundary_alignment_ticks"])
		)
		var contact_gated_end_step := (
			contact_gated_start_step
			+ int(clock["evidence_cycles"]) * int(clock["cycle_ticks"])
			+ int(clock["maximum_contact_gated_evidence_extension_ticks"])
		)
		var declared_step_count := (
			contact_gated_end_step
			+ int(clock["cooldown_cycles"]) * int(clock["cycle_ticks"])
			+ int(clock["terminal_settle_ticks"])
		)
		witness = (
			adapter
			. preflight_perfect_declared_policy_runtime_horizon(
				declared_step_count,
				contact_gated_start_step,
				contact_gated_end_step,
			)
		)
	else:
		witness = adapter.preflight_perfect_declared_policy_runtime_boundary()
	witness["execution_mode_plan"] = execution_mode_plan.duplicate(true)
	witness["execution_mode_plan_passed"] = (
		bool(execution_mode_plan.get("ok", false))
		and bool(
			execution_mode_plan.get(
				"full_post_settle_authority_enabled",
				false,
			)
		)
		and not bool(execution_mode_plan.get("fixed_exposure_enabled", true))
		and not bool(
			execution_mode_plan.get(
				"legacy_base_motor_writes_allowed",
				true,
			)
		)
		and (
			String(execution_mode_plan.get("phase_offset_application_mode", ""))
			== "scheduled_once_at_warmup_boundary"
		)
		and (
			(
				execution_mode_plan.get(
					"zero_base_initial_gait_steps",
					{},
				) as Dictionary
			).values()
			== [0, 0, 0, 0]
		)
	)
	witness["scene_tree_insertion_count"] = (
		root.get_child_count() - original_root_child_count
	)
	witness["physics_state_modified"] = (
		Engine.physics_ticks_per_second != original_physics_hz
	)
	return witness


func _r1_misroute_negative_control(profile: Dictionary) -> Dictionary:
	var adapter: RefCounted = GateAdapterScript.new()
	var negative_initial_steps := {
		"front_left": -3,
		"front_right": -3,
		"rear_left": -3,
		"rear_right": -3,
	}
	var start: Dictionary = (
		adapter
		. start(
			DESCRIPTOR,
			negative_initial_steps,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			120,
			SOLVER_POLICY_OPTIONS,
			GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"clocked",
			true,
			-3,
			360,
			GATE_FULL_AUTHORITY_SCOPE,
			String(GATE_POLICY_IDS[4]),
			profile,
			GATE_BASE_CONTROLLER_POLICY_ID,
		)
	)
	if not bool(start.get("ok", false)):
		return {
			"schema_version":
			"sporespore_declared_policy_runtime_horizon_preflight_v1",
			"ok": false,
			"failure_code":
			(
				"R1_MISROUTE_NEGATIVE_CONTROL_START:%s"
				% String(start.get("failure_code", "UNKNOWN"))
			),
			"failing_semantic_step": -1,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
	return adapter.preflight_perfect_declared_policy_runtime_horizon(
		3232,
		472,
		2632,
	)


func _physical_entrypoint_preflight(
	profile: Dictionary,
	stability_policy_id: String,
) -> Dictionary:
	var requested_fixture := FixtureSpecScript.reference_spec()
	requested_fixture["contact_material"] = (
		(profile.get("body_material", {}) as Dictionary).duplicate(true)
	)
	var perturbation := {
		"campaign_seed": 0,
		"fixture_vertical_clearance_m": 0.0,
		"fixture_yaw_rad": 0.0,
		"initial_linear_velocity_world_m_s": Vector3.ZERO,
		"initial_torso_angular_velocity_world_rad_s": Vector3.ZERO,
		"gait_phase_offset_ticks": 0,
	}
	var authority_options := {
		"enabled": true,
		"descriptor": DESCRIPTOR,
		"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
		"authority_scope": "stability_contribution_overlay",
		"stability_policy_id": stability_policy_id,
		"material_profile_id": "godot_jolt_bw5c_mu095_v1",
		"controller_policy_id": GATE_BASE_CONTROLLER_POLICY_ID,
	}
	var original_physics_hz := Engine.physics_ticks_per_second
	var original_root_child_count := root.get_child_count()
	var receipt: Dictionary = await (
		WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			72,
			0.40,
			"all",
			112,
			false,
			perturbation,
			ROBUSTNESS_OPTIONS,
			requested_fixture,
			PATH_STEERING_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			MOTOR_VELOCITY_OPTIONS,
			{},
			GaitClockSpecScript.gq15_clock(),
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			authority_options,
			{},
			{},
			true,
		)
	)
	var state_unchanged := (
		Engine.physics_ticks_per_second == original_physics_hz
		and root.get_child_count() == original_root_child_count
	)
	receipt["physics_state_modified"] = not state_unchanged
	receipt["scene_tree_insertion_count"] = (root.get_child_count() - original_root_child_count)
	return receipt


func _start_policy_semantic_adapter(
	profile: Dictionary,
	stability_policy_id: String,
	authority_scope: String,
) -> Dictionary:
	var adapter: RefCounted = GateAdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			DESCRIPTOR,
			GATE_GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			120,
			SOLVER_POLICY_OPTIONS,
			GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"contact_gated",
			true,
			0,
			-1,
			authority_scope,
			stability_policy_id,
			profile,
			GATE_BASE_CONTROLLER_POLICY_ID,
		)
	)
	if not bool(start.get("ok", false)):
		return _policy_semantic_failure(
			stability_policy_id,
			"POLICY_SEMANTIC_ADAPTER_START:%s" % String(start.get("failure_code", "")),
		)
	var compiled: Dictionary = adapter.compiled_morphology_for_conformance()
	var morphology: Dictionary = compiled.get("morphology", {})
	if not bool(compiled.get("ok", false)) or morphology.is_empty():
		return _policy_semantic_failure(
			stability_policy_id,
			"POLICY_SEMANTIC_MORPHOLOGY_UNAVAILABLE",
		)
	return {
		"ok": true,
		"adapter": adapter,
		"morphology": morphology,
	}


func _real_policy_semantic_witness(
	profile: Dictionary,
	stability_policy_id: String,
	policy_index: int,
) -> Dictionary:
	var original_physics_hz := Engine.physics_ticks_per_second
	var original_root_child_count := root.get_child_count()
	var semantic_authority_scope := (
		"post_settle_full" if policy_index >= 4 else "stability_contribution_overlay"
	)
	var setup := _start_policy_semantic_adapter(
		profile,
		stability_policy_id,
		semantic_authority_scope,
	)
	if not bool(setup.get("ok", false)):
		return setup
	var adapter: RefCounted = setup.get("adapter")
	var morphology: Dictionary = setup.get("morphology", {})

	var available_state := _policy_semantic_stability_state(morphology, 54, 0.08)
	var available_plan: Dictionary = (
		adapter
		. call(
			"_scheduled_load_transfer_plan",
			54,
			morphology,
			available_state,
			1.0,
			true,
			"",
		)
	)
	if not bool(available_plan.get("ok", false)):
		return _policy_semantic_failure(
			stability_policy_id,
			"POLICY_SEMANTIC_AVAILABLE_PLAN:%s" % String(available_plan.get("failure_code", "")),
		)
	var available_receipt: Dictionary = available_plan.get("receipt", {})
	var centroidal_command: Dictionary = available_plan.get("centroidal_command", {})
	var kinematics := _policy_semantic_kinematics(morphology)
	var map_envelope: Dictionary = (
		adapter
		. call(
			"_call_input",
			StringName("map_endpoint_force_to_joint_v3_json"),
			{
				"schema_version": "sporespore_map_endpoint_force_to_joint_request_v3",
				"descriptor": DESCRIPTOR,
				"request":
				{
					"schema_version": "sporespore_endpoint_force_joint_map_request_v3",
					"semantic_step": 54,
					"centroidal_command": centroidal_command,
					"ordered_actuator_kinematics": kinematics,
				},
			},
		)
	)
	if not bool(map_envelope.get("ok", false)):
		return _policy_semantic_failure(
			stability_policy_id,
			"POLICY_SEMANTIC_ENDPOINT_MAP:%s" % String(map_envelope.get("failure_code", "")),
		)
	var mapped_commands: Array = (
		(map_envelope.get("value", {}) as Dictionary)
		. get(
			"ordered_generalized_joint_torque_commands",
			[],
		)
	)
	var influence: Dictionary = (
		adapter
		. call(
			"_bound_stability_contribution_shadow",
			54,
			morphology,
			mapped_commands,
			"available",
		)
	)
	if not bool(influence.get("ok", false)):
		return _policy_semantic_failure(
			stability_policy_id,
			"POLICY_SEMANTIC_AVAILABLE_INFLUENCE:%s" % String(influence.get("failure_code", "")),
		)

	var unavailable_state := available_state.duplicate(true)
	unavailable_state["semantic_step"] = 55
	for contact_value in unavailable_state.get("ordered_support_contacts", []):
		var contact: Dictionary = contact_value
		contact["presence"] = false
		contact["bears_support"] = false
		contact["point_world_m"] = null
	var unavailable_plan: Dictionary = (
		adapter
		. call(
			"_scheduled_load_transfer_plan",
			55,
			morphology,
			unavailable_state,
			1.0,
			false,
			"NO_QUALIFIED_SUPPORT_CONTACT",
		)
	)
	if not bool(unavailable_plan.get("ok", false)):
		return _policy_semantic_failure(
			stability_policy_id,
			(
				"POLICY_SEMANTIC_UNAVAILABLE_PLAN:%s"
				% String(unavailable_plan.get("failure_code", ""))
			),
		)
	var no_qualified_contact_ids: Array[String] = []
	var unavailable_influence: Dictionary = (
		adapter
		. call(
			"_scheduled_load_transfer_fail_zero_influence",
			55,
			morphology,
			no_qualified_contact_ids,
			unavailable_plan,
		)
	)
	var available_nonzero_mapped := 0
	for mapped_value in mapped_commands:
		var mapped: Dictionary = mapped_value
		if absf(float(mapped.get("generalized_torque_command_nm", 0.0))) > 0.0:
			available_nonzero_mapped += 1
	var available_nonzero_applied := _nonzero_contribution_count(influence)
	var full_authority_application := {
		"ok": true,
		"applied_command_count": 0,
		"nonzero_effective_application_count": 0,
	}
	var full_authority_combined_application_passed := policy_index < 4
	if policy_index >= 4:
		var application_influence := influence.duplicate(true)
		application_influence["stability_policy_id"] = stability_policy_id
		var joint_state_by_joint_id: Dictionary = {}
		var native_commands: Array = []
		for actuator_id_value in morphology.get("ordered_actuator_ids", []):
			var actuator_id := String(actuator_id_value)
			var joint_id := String(adapter.call("_legacy_joint_id_for_actuator", actuator_id))
			var joint := HingeJoint3D.new()
			joint_state_by_joint_id[joint_id] = {"joint": joint}
			native_commands.append(
				{
					"actuator_id": actuator_id,
					"mode": "position_velocity",
					"target_position_rad": 0.0,
					"target_velocity_rad_s": 0.0,
					"maximum_target_speed_rad_s": 10.0,
				}
			)
		full_authority_application = (
			adapter
			. apply_stability_contribution(
				{
					"ok": true,
					"failure_code": "",
					"overlay_inputs_valid": true,
					"semantic_step": 54,
					"native_output":
					{
						"actuation":
						{
							"safe_no_actuation": false,
							"ordered_commands": native_commands,
						},
					},
					"stability_contribution_shadow": application_influence,
				},
				{},
				joint_state_by_joint_id,
			)
		)
		full_authority_combined_application_passed = (
			bool(full_authority_application.get("ok", false))
			and int(full_authority_application.get("applied_command_count", -1)) == 8
			and (
				int(
					full_authority_application.get(
						"nonzero_effective_application_count",
						-1,
					)
				)
				> 0
			)
			and (
				String(full_authority_application.get("base_command_source", ""))
				== "portable_controller_ordered_commands"
			)
			and int(full_authority_application.get("direct_body_write_count", -1)) == 0
		)
		for joint_state_value in joint_state_by_joint_id.values():
			var joint_state: Dictionary = joint_state_value
			var joint: HingeJoint3D = joint_state.get("joint")
			if joint != null:
				joint.free()
	var unavailable_safe_zero := _safe_zero_contribution_count(
		unavailable_influence,
	)
	var feedback: Dictionary = available_plan.get("feedback_request", {})
	var unavailable_receipt: Dictionary = unavailable_plan.get("receipt", {})
	var scene_tree_insertion_count := root.get_child_count() - original_root_child_count
	var physics_state_modified := Engine.physics_ticks_per_second != original_physics_hz
	var exact := (
		String(available_receipt.get("mode", "")) == String(GATE_POLICY_MODES[policy_index])
		and (
			bool(available_receipt.get("active", policy_index % 4 == 0))
			== (policy_index % 4 != 0)
		)
		and String(available_plan.get("planning_availability", "")) == "available"
		and not bool(available_plan.get("fail_zero_required", true))
		and bool(feedback.get("feedback_request_nonzero", false))
		and available_nonzero_mapped > 0
		and available_nonzero_applied > 0
		and full_authority_combined_application_passed
		and int(influence.get("mismatch_count", -1)) == 0
		and int(influence.get("limiter_mismatch_count", -1)) == 0
		and (String(unavailable_plan.get("planning_availability", "")) == "observation_unavailable")
		and bool(unavailable_plan.get("fail_zero_required", false))
		and (
			String(unavailable_receipt.get("observation_unavailable_reason", ""))
			== "NO_QUALIFIED_SUPPORT_CONTACT"
		)
		and bool(unavailable_influence.get("ok", false))
		and int(unavailable_influence.get("mismatch_count", -1)) == 0
		and unavailable_safe_zero == 8
		and scene_tree_insertion_count == 0
		and not physics_state_modified
	)
	return {
		"schema_version": "sporespore_policy_semantic_preflight_witness_v1",
		"ok": exact,
		"failure_code": "" if exact else "POLICY_SEMANTIC_WITNESS_INVALID",
		"declared_stability_policy_id": stability_policy_id,
		"declared_controller_policy_id": GATE_BASE_CONTROLLER_POLICY_ID,
		"available_mode": String(available_receipt.get("mode", "")),
		"available_factor_active": bool(available_receipt.get("active", false)),
		"available_feedback_request_nonzero": bool(feedback.get("feedback_request_nonzero", false)),
		"available_nonzero_mapped_command_count": available_nonzero_mapped,
		"available_nonzero_active_command_count":
		int(influence.get("nonzero_active_command_count", -1)),
		"available_nonzero_applied_contribution_count": available_nonzero_applied,
		"available_maximum_absolute_applied_velocity_rad_s":
		float(influence.get("maximum_absolute_applied_velocity_rad_s", INF)),
		"available_mismatch_count": int(influence.get("mismatch_count", -1)),
		"available_limiter_mismatch_count": int(influence.get("limiter_mismatch_count", -1)),
		"semantic_authority_scope": semantic_authority_scope,
		"full_authority_combined_application_called": policy_index >= 4,
		"full_authority_combined_application_passed":
		full_authority_combined_application_passed,
		"full_authority_combined_application_receipt":
		{
			"ok": bool(full_authority_application.get("ok", false)),
			"failure_code": String(full_authority_application.get("failure_code", "")),
			"applied_command_count":
			int(full_authority_application.get("applied_command_count", -1)),
			"nonzero_effective_application_count":
			int(
				full_authority_application.get(
					"nonzero_effective_application_count",
					-1,
				)
			),
			"base_command_source":
			String(full_authority_application.get("base_command_source", "")),
			"direct_body_write_count":
			int(full_authority_application.get("direct_body_write_count", -1)),
		},
		"unavailable_fail_zero_required": bool(unavailable_plan.get("fail_zero_required", false)),
		"unavailable_safe_zero_contribution_count": unavailable_safe_zero,
		"unavailable_mismatch_count": int(unavailable_influence.get("mismatch_count", -1)),
		"real_portable_plan_called": true,
		"real_endpoint_force_map_called": true,
		"real_bounded_influence_called": true,
		"semantic_sample_count": 2,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"physics_state_modified": physics_state_modified,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


static func _policy_semantic_stability_state(
	morphology: Dictionary,
	semantic_step: int,
	lateral_center_of_mass_offset_m: float,
) -> Dictionary:
	var bodies: Array = []
	for body_id_value in morphology.get("ordered_body_ids", []):
		(
			bodies
			. append(
				{
					"body_id": String(body_id_value),
					"pose_world":
					{
						"position_m":
						{
							"x": 0.0,
							"y": 0.44,
							"z": lateral_center_of_mass_offset_m,
						},
						"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
					},
					"twist_world":
					{
						"linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
						"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
					},
				}
			)
		)
	var contacts: Array = []
	for contact_id_value in morphology.get("ordered_contact_site_ids", []):
		var contact_id := String(contact_id_value)
		(
			contacts
			. append(
				{
					"contact_site_id": contact_id,
					"presence": true,
					"bears_support": true,
					"point_world_m":
					{
						"x": 0.30 if contact_id.begins_with("front") else -0.30,
						"y": 0.0,
						"z": -0.20 if contact_id.contains("left") else 0.20,
					},
					"normal_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
					"surface_relative_velocity_world_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
					"material_id": "full_gate_semantic_preflight",
					"adapter_id": "full_gate_semantic_preflight",
					"engine_contact_ids": ["%s_semantic" % contact_id],
				}
			)
		)
	return {
		"schema_version": "sporespore_stability_state_v2",
		"semantic_step": semantic_step,
		"ordered_body_states": bodies,
		"ordered_support_contacts": contacts,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
		"adapter_capability_sha256": "sha256:%s" % "7".repeat(64),
	}


static func _policy_semantic_kinematics(morphology: Dictionary) -> Array:
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var limbs: Array = morphology_spec.get("limbs", [])
	var ordered: Array = []
	for actuator_value in morphology_spec.get("actuators", []):
		var actuator: Dictionary = actuator_value
		var joint_id := String(actuator.get("joint_id", ""))
		var owner: Dictionary = {}
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			if (limb.get("ordered_joint_ids", []) as Array).has(joint_id):
				owner = limb
				break
		var joint_index := (owner.get("ordered_joint_ids", []) as Array).find(joint_id)
		var contact_ids: Array = owner.get("ordered_contact_site_ids", [])
		(
			ordered
			. append(
				{
					"actuator_id": String(actuator.get("actuator_id", "")),
					"contact_site_id": String(contact_ids[0]) if not contact_ids.is_empty() else "",
					"joint_anchor_world_m": {"x": 0.0, "y": -0.25 * float(joint_index), "z": 0.0},
					"joint_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
					"endpoint_world_m": {"x": 0.0, "y": -0.5, "z": 0.0},
				}
			)
		)
	return ordered


static func _nonzero_contribution_count(influence: Dictionary) -> int:
	var count := 0
	for contribution_value in influence.get("ordered_contributions", []):
		var contribution: Dictionary = contribution_value
		if (
			absf(
				float(
					(
						contribution
						. get(
							"applied_canonical_velocity_delta_rad_s",
							0.0,
						)
					)
				)
			)
			> 0.0
		):
			count += 1
	return count


static func _safe_zero_contribution_count(influence: Dictionary) -> int:
	var count := 0
	for contribution_value in influence.get("ordered_contributions", []):
		var contribution: Dictionary = contribution_value
		if (
			(
				float(
					(
						contribution
						. get(
							"applied_canonical_velocity_delta_rad_s",
							NAN,
						)
					)
				)
				== 0.0
			)
			and (
				float(
					(
						contribution
						. get(
							"host_target_velocity_delta_rad_s",
							NAN,
						)
					)
				)
				== 0.0
			)
			and bool(contribution.get("fallback_zeroed", false))
		):
			count += 1
	return count


static func _policy_semantic_failure(
	stability_policy_id: String,
	failure_code: String,
) -> Dictionary:
	return {
		"schema_version": "sporespore_policy_semantic_preflight_witness_v1",
		"ok": false,
		"failure_code": failure_code,
		"declared_stability_policy_id": stability_policy_id,
		"declared_controller_policy_id": GATE_BASE_CONTROLLER_POLICY_ID,
		"semantic_sample_count": 0,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _expected_stability_policy_id() -> String:
	return _gate_declared_policy_id


func _stability_observation_partition_exact(
	stability_shadow: Dictionary,
) -> bool:
	return (
		(
			int(stability_shadow.get("available_count", -1))
			+ int(stability_shadow.get("unavailable_count", -1))
		)
		== EXPECTED_STEP_COUNT
	)


func _balanced_wave_treatment_mechanism_integrity(
	contribution: Dictionary,
	overlay: Dictionary,
) -> bool:
	var feedback_count := int(contribution.get("feedback_nonzero_attempt_count", -1))
	var active_count := int(contribution.get("nonzero_active_command_count", -1))
	var overlay_count := int(overlay.get("nonzero_effective_application_count", -1))
	if _gate_expect_nonzero_activity:
		return feedback_count > 0 and active_count > 0 and overlay_count > 0
	return feedback_count == 0 and active_count == 0 and overlay_count == 0


func _gate_check(condition: bool, label: String) -> void:
	if condition:
		_gate_passed += 1
		print("  PASS: ", label)
	else:
		_gate_failed += 1
		push_error("  FAIL: %s" % label)


func _gate_finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_gate_passed, _gate_failed])
	quit(0 if _gate_failed == 0 else 1)
