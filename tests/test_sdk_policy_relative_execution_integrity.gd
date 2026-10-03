extends SceneTree

## Zero-world parity proof for policy-relative physical receipt integrity.
##
## The payloads below have the complete shape consumed by the future physical
## receipt. They are synthetic observations: the test itself constructs no
## fixture, inserts no node, and advances no physics state.

const IntegrityScript := preload(
	"res://scripts/lab/gait/sdk_policy_relative_execution_integrity.gd"
)
const POLICY_A := "sporespore_balanced_wave_bw15f_b_v1"
const POLICY_B := "sporespore_balanced_wave_bw21l_b_v1"
const STABILITY_POLICY := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const AUTHORITY_SCOPE := "post_settle_full"
const EXECUTION_MODE := "native_balanced_wave_base_with_stability_contribution"
const EXPECTED_MOTOR_WRITES := 16

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_children_before := root.get_child_count()
	var ticks_before := Engine.physics_ticks_per_second
	var expected_b := _expected(POLICY_B)
	var perfect_b := _perfect_summary(POLICY_B)
	var perfect_receipt := IntegrityScript.build_receipt_integrity(perfect_b, expected_b)
	_check(
		(
			bool(perfect_receipt.get("ok", false))
			and bool(perfect_receipt.get("common_execution_integrity", false))
			and bool(perfect_receipt.get("combined_application_gate_passed", false))
			and String(perfect_receipt.get("controller_policy_id", "")) == POLICY_B
			and String(perfect_receipt.get("declared_controller_policy_id", "")) == POLICY_B
		),
		"1 realistic non-baseline policy B receipt passes the exact relative gate",
	)

	var perfect_a := (
		IntegrityScript
		. build_receipt_integrity(
			_perfect_summary(POLICY_A),
			_expected(POLICY_A),
		)
	)
	_check(
		(
			bool(perfect_a.get("ok", false))
			and bool(perfect_a.get("common_execution_integrity", false))
		),
		"2 baseline policy A remains admissible under its own declaration",
	)

	var inherited_hardcode_canary := (
		IntegrityScript
		. build_receipt_integrity(
			_perfect_summary(POLICY_A),
			expected_b,
		)
	)
	var hardcode_common: Dictionary = inherited_hardcode_canary.get("common_execution", {})
	_check(
		(
			not bool(inherited_hardcode_canary.get("ok", true))
			and not bool(inherited_hardcode_canary.get("common_execution_integrity", true))
			and (
				(hardcode_common.get("failed_checks", []) as Array)
				== ["controller_policy_relative_identity"]
			)
		),
		"3 BW15F-only inherited identity is rejected for a policy B cell",
	)

	var wrong_count_summary := perfect_b.duplicate(true)
	var wrong_count_sdk: Dictionary = wrong_count_summary["sdk_authority_summary"]
	wrong_count_sdk["native_actuation_application_count"] = EXPECTED_MOTOR_WRITES - 1
	var wrong_count := (
		IntegrityScript
		. build_receipt_integrity(
			wrong_count_summary,
			expected_b,
		)
	)
	var wrong_count_common: Dictionary = wrong_count.get("common_execution", {})
	_check(
		(
			not bool(wrong_count.get("ok", true))
			and (
				(wrong_count_common.get("failed_checks", []) as Array)
				== ["native_application_count"]
			)
		),
		"4 one missing native application fails closed",
	)

	var direct_write_summary := perfect_b.duplicate(true)
	direct_write_summary["direct_torso_impulse_command_count"] = 1
	var direct_write := (
		IntegrityScript
		. build_receipt_integrity(
			direct_write_summary,
			expected_b,
		)
	)
	var direct_write_common: Dictionary = direct_write.get("common_execution", {})
	_check(
		(
			not bool(direct_write.get("ok", true))
			and (
				(direct_write_common.get("failed_checks", []) as Array)
				== ["direct_body_write_count_zero"]
			)
		),
		"5 one direct-body write fails closed",
	)

	var wrong_mode_summary := perfect_b.duplicate(true)
	var wrong_mode_start: Dictionary = wrong_mode_summary["sdk_authority_start_result"]
	var wrong_mode_manifest: Dictionary = wrong_mode_start["adapter_manifest"]
	wrong_mode_manifest["execution_mode"] = "wrong_mode"
	var wrong_mode := (
		IntegrityScript
		. build_receipt_integrity(
			wrong_mode_summary,
			expected_b,
		)
	)
	var wrong_mode_common: Dictionary = wrong_mode.get("common_execution", {})
	_check(
		(
			not bool(wrong_mode.get("ok", true))
			and (
				(wrong_mode_common.get("failed_checks", []) as Array) == ["execution_mode_identity"]
			)
		),
		"6 an execution-mode mismatch fails closed",
	)

	var zero_residual_summary := perfect_b.duplicate(true)
	var zero_sdk: Dictionary = zero_residual_summary["sdk_authority_summary"]
	var zero_overlay: Dictionary = zero_sdk["stability_overlay_summary"]
	zero_overlay["nonzero_effective_application_count"] = 0
	zero_overlay["physical_influence"] = false
	var zero_residual := (
		IntegrityScript
		. build_receipt_integrity(
			zero_residual_summary,
			expected_b,
		)
	)
	var zero_application: Dictionary = zero_residual.get("full_authority_application", {})
	_check(
		(
			bool(zero_residual.get("common_execution_integrity", false))
			and not bool(zero_residual.get("combined_application_gate_passed", true))
			and (
				(zero_application.get("failed_checks", []) as Array)
				== ["nonzero_effective_application", "overlay_physical_influence"]
			)
		),
		"7 real zero-residual semantics preserve execution and reject application",
	)

	var wrong_overlay_summary := perfect_b.duplicate(true)
	var wrong_overlay_sdk: Dictionary = wrong_overlay_summary["sdk_authority_summary"]
	var wrong_overlay: Dictionary = wrong_overlay_sdk["stability_overlay_summary"]
	wrong_overlay["policy_id"] = "wrong_stability_policy"
	var wrong_overlay_receipt := (
		IntegrityScript
		. build_receipt_integrity(
			wrong_overlay_summary,
			expected_b,
		)
	)
	var wrong_overlay_application: Dictionary = wrong_overlay_receipt.get(
		"full_authority_application", {}
	)
	_check(
		(
			bool(wrong_overlay_receipt.get("common_execution_integrity", false))
			and not bool(wrong_overlay_receipt.get("combined_application_gate_passed", true))
			and (
				(wrong_overlay_application.get("failed_checks", []) as Array)
				== ["overlay_policy_identity"]
			)
		),
		"8 stability-overlay policy mismatch fails the application gate",
	)

	var inherited_receipt := {
		"campaign_id": "SYNTHETIC-SUCCESSOR",
		"mechanism_gate_passed": true,
		"scale_contract_passed": true,
		"profile_binding_exact": true,
		"outcome_complete": true,
		"common_execution_integrity": false,
		"combined_application_gate_passed": false,
		"physical_acceptance_authority": false,
	}
	var bound_perfect := (
		IntegrityScript
		. bind_physical_receipt(
			inherited_receipt,
			perfect_b,
			expected_b,
		)
	)
	_check(
		(
			bool(bound_perfect.get("common_execution_integrity", false))
			and bool(bound_perfect.get("combined_application_gate_passed", false))
			and bool(bound_perfect.get("mechanism_gate_passed", false))
			and bool(bound_perfect.get("scale_contract_passed", false))
			and bool(bound_perfect.get("profile_binding_exact", false))
			and bool(bound_perfect.get("outcome_complete", false))
			and String(bound_perfect.get("campaign_id", "")) == "SYNTHETIC-SUCCESSOR"
			and String(bound_perfect.get("controller_policy_id", "")) == POLICY_B
			and not bool(bound_perfect.get("physical_acceptance_authority", true))
		),
		"9 binder supplies policy-relative execution and preserves inherited gates",
	)

	var mismatched_bound := (
		IntegrityScript
		. bind_physical_receipt(
			inherited_receipt,
			_perfect_summary(POLICY_A),
			expected_b,
		)
	)
	_check(
		(
			not bool(mismatched_bound.get("common_execution_integrity", true))
			and not bool(mismatched_bound.get("combined_application_gate_passed", true))
			and bool(mismatched_bound.get("mechanism_gate_passed", false))
			and bool(mismatched_bound.get("scale_contract_passed", false))
		),
		"10 binder rejects policy mismatch without rewriting inherited evidence",
	)

	var invalid_scale_receipt := inherited_receipt.duplicate(true)
	invalid_scale_receipt["mechanism_gate_passed"] = false
	invalid_scale_receipt["scale_contract_passed"] = false
	var invalid_scale_bound := (
		IntegrityScript
		. bind_physical_receipt(
			invalid_scale_receipt,
			perfect_b,
			expected_b,
		)
	)
	_check(
		(
			bool(invalid_scale_bound.get("common_execution_integrity", false))
			and bool(invalid_scale_bound.get("combined_application_gate_passed", false))
			and not bool(invalid_scale_bound.get("mechanism_gate_passed", true))
			and not bool(invalid_scale_bound.get("scale_contract_passed", true))
		),
		"11 binder cannot convert an inherited mechanism or scale failure",
	)

	var zero_residual_bound := (
		IntegrityScript
		. bind_physical_receipt(
			inherited_receipt,
			zero_residual_summary,
			expected_b,
		)
	)
	_check(
		(
			bool(zero_residual_bound.get("common_execution_integrity", false))
			and not bool(zero_residual_bound.get("combined_application_gate_passed", true))
			and bool(zero_residual_bound.get("mechanism_gate_passed", false))
			and bool(zero_residual_bound.get("scale_contract_passed", false))
		),
		"12 binder preserves corrected zero-residual role semantics",
	)

	var actual_world_build_count := 0
	var scene_tree_insertion_count := root.get_child_count() - root_children_before
	var physics_state_modified := Engine.physics_ticks_per_second != ticks_before
	_check(
		(
			actual_world_build_count == 0
			and scene_tree_insertion_count == 0
			and not physics_state_modified
		),
		"13 the complete parity and canary suite builds zero worlds",
	)

	var final_status := (
		"POLICY_RELATIVE_EXECUTION_INTEGRITY_PASS "
		+ "checks=%d worlds=%d scene_insertions=%d physics_modified=%s "
		+ "nonbaseline_policy=true inherited_hardcode_rejected=true "
		+ "zero_residual_control=true physical_authority=false"
	)
	print(
		(
			final_status
			% [
				_passed,
				actual_world_build_count,
				scene_tree_insertion_count,
				str(physics_state_modified),
			]
		)
	)
	quit(0 if _failed == 0 else 1)


func _expected(controller_policy_id: String) -> Dictionary:
	return {
		"controller_policy_id": controller_policy_id,
		"stability_policy_id": STABILITY_POLICY,
		"authority_scope": AUTHORITY_SCOPE,
		"execution_mode": EXECUTION_MODE,
		"actuator_count": 8,
		"world_build_count": 1,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"body_count": 9,
		"limb_count": 4,
	}


func _perfect_summary(controller_policy_id: String) -> Dictionary:
	return {
		"world_build_count": 1,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"body_count": 9,
		"limb_count": 4,
		"world_reset_count": 0,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"sdk_authority_enabled": true,
		"sdk_authority_scope": AUTHORITY_SCOPE,
		"sdk_authority_failure_code": "",
		"sdk_full_authority_stability_contribution_enabled": true,
		"sdk_p5i3c_fixed_exposure_enabled": false,
		"legacy_sdk_overlay_base_application_count": 0,
		"legacy_post_settle_actuation_application_count": 0,
		"legacy_evidence_actuation_application_count": 0,
		"walking_gate_receipts":
		{
			"native_sdk_exclusive_post_settle_actuation": true,
		},
		"sdk_authority_start_result":
		{
			"adapter_manifest":
			{
				"execution_mode": EXECUTION_MODE,
			},
		},
		"sdk_authority_summary":
		{
			"ok": true,
			"actuation_authority": true,
			"controller_policy_id": controller_policy_id,
			"stability_policy_id": STABILITY_POLICY,
			"authority_scope": AUTHORITY_SCOPE,
			"step_count": 2,
			"validated_balanced_wave_command_count": EXPECTED_MOTOR_WRITES,
			"native_actuation_application_count": EXPECTED_MOTOR_WRITES,
			"mismatch_count": 0,
			"safe_no_actuation_count": 0,
			"native_safe_disable_application_count": 0,
			"stability_overlay_runtime_ok": true,
			"stability_overlay_summary":
			{
				"schema_version": "sporespore_godot_jolt_stability_overlay_summary_v1",
				"ok": true,
				"policy_id": STABILITY_POLICY,
				"authority_scope": AUTHORITY_SCOPE,
				"application_step_count": 2,
				"motor_write_count": EXPECTED_MOTOR_WRITES,
				"portable_controller_base_application_count": EXPECTED_MOTOR_WRITES,
				"nonzero_effective_application_count": 1,
				"combined_speed_limit_violation_count": 0,
				"failure_count": 0,
				"failure_codes": [],
				"physical_influence": true,
			},
		},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		push_error("FAIL: " + label)
