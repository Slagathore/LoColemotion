class_name LabSdkPolicyRelativeExecutionIntegrity
extends RefCounted
# gdlint: disable=max-line-length

## Pure policy-relative execution-integrity evaluator.
##
## Physical campaign workers may inherit historical fixture implementations,
## but they must not inherit a campaign-specific controller-policy predicate.
## This evaluator compares the live SDK summary to the policy declared by the
## active cell. It accepts ordinary Dictionaries so the exact physical receipt
## path can be traversed with realistic synthetic summaries before any world is
## built.

const SCHEMA_VERSION := "sporespore_policy_relative_execution_integrity_v1"
const APPLICATION_SCHEMA_VERSION := "sporespore_policy_relative_full_authority_application_integrity_v1"
const RECEIPT_SCHEMA_VERSION := "sporespore_policy_relative_physical_receipt_integrity_v1"
const OVERLAY_SCHEMA_VERSION := "sporespore_godot_jolt_stability_overlay_summary_v1"


static func evaluate_common_execution(
	summary: Dictionary,
	expected: Dictionary,
) -> Dictionary:
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var start_result: Dictionary = summary.get("sdk_authority_start_result", {})
	var manifest: Dictionary = start_result.get("adapter_manifest", {})
	var sdk_steps := int(sdk_summary.get("step_count", -1))
	var expected_actuator_count := int(expected.get("actuator_count", -1))
	var expected_motor_writes := sdk_steps * expected_actuator_count
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var expected_policy_id := String(expected.get("controller_policy_id", ""))
	var expected_stability_policy_id := String(expected.get("stability_policy_id", ""))
	var expected_authority_scope := String(expected.get("authority_scope", ""))
	var expected_execution_mode := String(expected.get("execution_mode", ""))
	var checks := {
		"declared_controller_policy_nonempty": not expected_policy_id.is_empty(),
		"declared_stability_policy_nonempty": not expected_stability_policy_id.is_empty(),
		"declared_authority_scope_nonempty": not expected_authority_scope.is_empty(),
		"declared_execution_mode_nonempty": not expected_execution_mode.is_empty(),
		"declared_actuator_count_positive": expected_actuator_count > 0,
		"world_build_count":
		int(summary.get("world_build_count", -1)) == int(expected.get("world_build_count", -2)),
		"physics_engine":
		String(summary.get("physics_engine", "")) == String(expected.get("physics_engine", "")),
		"physics_hz": int(summary.get("physics_hz", -1)) == int(expected.get("physics_hz", -2)),
		"solver_velocity_steps":
		(
			int(summary.get("solver_velocity_steps", -1))
			== int(expected.get("solver_velocity_steps", -2))
		),
		"solver_position_steps":
		(
			int(summary.get("solver_position_steps", -1))
			== int(expected.get("solver_position_steps", -2))
		),
		"body_count": int(summary.get("body_count", -1)) == int(expected.get("body_count", -2)),
		"limb_count": int(summary.get("limb_count", -1)) == int(expected.get("limb_count", -2)),
		"world_reset_count_zero": int(summary.get("world_reset_count", -1)) == 0,
		"direct_body_write_count_zero": direct_body_write_count == 0,
		"sdk_authority_enabled": bool(summary.get("sdk_authority_enabled", false)),
		"summary_authority_scope":
		String(summary.get("sdk_authority_scope", "")) == expected_authority_scope,
		"summary_authority_failure_empty":
		String(summary.get("sdk_authority_failure_code", "")).is_empty(),
		"sdk_summary_ok": bool(sdk_summary.get("ok", false)),
		"sdk_actuation_authority": bool(sdk_summary.get("actuation_authority", false)),
		"controller_policy_relative_identity":
		String(sdk_summary.get("controller_policy_id", "")) == expected_policy_id,
		"stability_policy_identity":
		String(sdk_summary.get("stability_policy_id", "")) == expected_stability_policy_id,
		"sdk_authority_scope":
		String(sdk_summary.get("authority_scope", "")) == expected_authority_scope,
		"sdk_step_count_positive": sdk_steps > 0,
		"validated_command_count":
		int(sdk_summary.get("validated_balanced_wave_command_count", -1)) == expected_motor_writes,
		"native_application_count":
		int(sdk_summary.get("native_actuation_application_count", -1)) == expected_motor_writes,
		"sdk_mismatch_count_zero": int(sdk_summary.get("mismatch_count", -1)) == 0,
		"sdk_safe_no_actuation_count_zero":
		int(sdk_summary.get("safe_no_actuation_count", -1)) == 0,
		"native_safe_disable_count_zero":
		int(sdk_summary.get("native_safe_disable_application_count", -1)) == 0,
		"execution_mode_identity":
		String(manifest.get("execution_mode", "")) == expected_execution_mode,
	}
	return _result(
		SCHEMA_VERSION,
		"POLICY_RELATIVE_COMMON_EXECUTION_INVALID",
		checks,
		{
			"expected_controller_policy_id": expected_policy_id,
			"observed_controller_policy_id": String(sdk_summary.get("controller_policy_id", "")),
			"expected_stability_policy_id": expected_stability_policy_id,
			"observed_stability_policy_id": String(sdk_summary.get("stability_policy_id", "")),
			"sdk_step_count": sdk_steps,
			"expected_motor_write_count": expected_motor_writes,
			"direct_body_write_count": direct_body_write_count,
		},
	)


static func evaluate_full_authority_application(
	summary: Dictionary,
	expected: Dictionary,
	common_execution: Dictionary,
) -> Dictionary:
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var overlay: Dictionary = sdk_summary.get("stability_overlay_summary", {})
	var walking_gates: Dictionary = summary.get("walking_gate_receipts", {})
	var sdk_steps := int(sdk_summary.get("step_count", -1))
	var expected_motor_writes := sdk_steps * int(expected.get("actuator_count", -1))
	var checks := {
		"common_execution_integrity": bool(common_execution.get("ok", false)),
		"full_authority_contribution_enabled":
		bool(summary.get("sdk_full_authority_stability_contribution_enabled", false)),
		"fixed_exposure_disabled": not bool(summary.get("sdk_p5i3c_fixed_exposure_enabled", true)),
		"legacy_overlay_base_count_zero":
		int(summary.get("legacy_sdk_overlay_base_application_count", -1)) == 0,
		"legacy_post_settle_count_zero":
		int(summary.get("legacy_post_settle_actuation_application_count", -1)) == 0,
		"legacy_evidence_count_zero":
		int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0,
		"overlay_schema": String(overlay.get("schema_version", "")) == OVERLAY_SCHEMA_VERSION,
		"overlay_ok": bool(overlay.get("ok", false)),
		"overlay_policy_identity":
		String(overlay.get("policy_id", "")) == String(expected.get("stability_policy_id", "")),
		"overlay_authority_scope":
		String(overlay.get("authority_scope", "")) == String(expected.get("authority_scope", "")),
		"overlay_application_count": int(overlay.get("application_step_count", -1)) == sdk_steps,
		"overlay_motor_write_count":
		int(overlay.get("motor_write_count", -1)) == expected_motor_writes,
		"portable_base_application_count":
		int(overlay.get("portable_controller_base_application_count", -1)) == expected_motor_writes,
		"nonzero_effective_application":
		int(overlay.get("nonzero_effective_application_count", 0)) > 0,
		"combined_speed_limit_violations_zero":
		int(overlay.get("combined_speed_limit_violation_count", -1)) == 0,
		"overlay_failure_count_zero": int(overlay.get("failure_count", -1)) == 0,
		"overlay_failure_codes_empty": (overlay.get("failure_codes", []) as Array).is_empty(),
		"overlay_physical_influence": bool(overlay.get("physical_influence", false)),
		"sdk_overlay_runtime_ok": bool(sdk_summary.get("stability_overlay_runtime_ok", false)),
		"native_sdk_exclusive_post_settle_actuation":
		bool(walking_gates.get("native_sdk_exclusive_post_settle_actuation", false)),
	}
	return _result(
		APPLICATION_SCHEMA_VERSION,
		"POLICY_RELATIVE_FULL_AUTHORITY_APPLICATION_INVALID",
		checks,
		{
			"sdk_step_count": sdk_steps,
			"expected_motor_write_count": expected_motor_writes,
			"observed_nonzero_effective_application_count":
			int(overlay.get("nonzero_effective_application_count", -1)),
		},
	)


static func build_receipt_integrity(
	summary: Dictionary,
	expected: Dictionary,
) -> Dictionary:
	var common := evaluate_common_execution(summary, expected)
	var application := evaluate_full_authority_application(summary, expected, common)
	return {
		"schema_version": RECEIPT_SCHEMA_VERSION,
		"ok": bool(common.get("ok", false)) and bool(application.get("ok", false)),
		"common_execution_integrity": bool(common.get("ok", false)),
		"combined_application_gate_passed": bool(application.get("ok", false)),
		"controller_policy_id":
		String(
			(
				(summary.get("sdk_authority_summary", {}) as Dictionary)
				. get(
					"controller_policy_id",
					"",
				)
			)
		),
		"declared_controller_policy_id": String(expected.get("controller_policy_id", "")),
		"common_execution": common,
		"full_authority_application": application,
		"synthetic_acceptance_authority": false,
		"physical_acceptance_authority": false,
	}


static func bind_physical_receipt(
	receipt: Dictionary,
	summary: Dictionary,
	expected: Dictionary,
) -> Dictionary:
	## Bind cell-declared identity checks to an already composed receipt.
	##
	## The inherited receipt remains authoritative for mechanism, material,
	## profile, scale, outcome, and campaign-specific fields. Only the two
	## execution predicates whose historical implementation was coupled to a
	## fixed controller identity are supplied by this policy-relative evaluator.
	## Role semantics remain with the caller: a zero-residual control should
	## retain common execution while full-authority application stays false.
	var integrity := build_receipt_integrity(summary, expected)
	var common: Dictionary = integrity.get("common_execution", {})
	var application: Dictionary = integrity.get("full_authority_application", {})
	var bound := receipt.duplicate(true)
	bound["controller_policy_id"] = String(
		(
			(summary.get("sdk_authority_summary", {}) as Dictionary)
			. get(
				"controller_policy_id",
				"",
			)
		)
	)
	bound["declared_controller_policy_id"] = String(expected.get("controller_policy_id", ""))
	bound["common_execution_integrity"] = bool(common.get("ok", false))
	bound["combined_application_gate_passed"] = bool(application.get("ok", false))
	bound["policy_relative_common_execution"] = common.duplicate(true)
	bound["policy_relative_full_authority_application"] = application.duplicate(true)
	bound["policy_relative_receipt_integrity"] = integrity.duplicate(true)
	bound["synthetic_acceptance_authority"] = false
	bound["physical_acceptance_authority"] = false
	return bound


static func _result(
	schema_version: String,
	failure_code: String,
	checks: Dictionary,
	observations: Dictionary,
) -> Dictionary:
	var failed_checks: Array[String] = []
	for check_name in checks:
		if not bool(checks[check_name]):
			failed_checks.append(String(check_name))
	failed_checks.sort()
	return {
		"schema_version": schema_version,
		"ok": failed_checks.is_empty(),
		"failure_code": "" if failed_checks.is_empty() else failure_code,
		"checks": checks.duplicate(true),
		"failed_checks": failed_checks,
		"observations": observations.duplicate(true),
		"physical_acceptance_authority": false,
	}
