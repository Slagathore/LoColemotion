extends SceneTree

## Candidate 35 full post-settle native authority: the Rust SDK owns clocked
## warmup, the clocked-to-contact-gated evidence transition, the complete
## evidence horizon, cooldown, and terminal settling in one continuous world.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const HandoffProfile := preload("res://tests/test_sdk_godot_jolt_authority_handoff.gd")

const SDK_AUTHORITY_OPTIONS := {
	"enabled": true,
	"descriptor": HandoffProfile.DESCRIPTOR,
	# The longer post-settle path reaches larger target magnitudes than the
	# evidence-only handoff. A failed diagnostic run measured a pre-divergence
	# float32 mapping floor of 3.255412e-8 rad/s and 1.375289e-8 steering.
	"comparison_tolerance": 4.0e-8,
	"authority_scope": "post_settle_full",
}
const MAXIMUM_POSITION_MAPPING_ERROR_RAD := 5.0e-9
const MAXIMUM_VELOCITY_MAPPING_ERROR_RAD_S := 4.0e-8
const MAXIMUM_SPEED_LIMIT_MAPPING_ERROR_RAD_S := 1.0e-12
const MAXIMUM_STEERING_MAPPING_ERROR := 2.0e-8

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt Candidate 35 full post-settle native authority ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var clock_result := GaitClockSpecScript.compile(GaitClockSpecScript.gq15_clock())
	_check(bool(clock_result.get("ok", false)), "the frozen GQ15 clock compiles")
	if not bool(clock_result.get("ok", false)):
		_finish()
		return
	var summary: Dictionary = await (
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
			{},
			HandoffProfile.ROBUSTNESS_OPTIONS,
			FixtureSpecScript.reference_spec(),
			HandoffProfile.PATH_STEERING_OPTIONS,
			HandoffProfile.ACTUATOR_IMPULSE_OPTIONS,
			HandoffProfile.MOTOR_VELOCITY_OPTIONS,
			{},
			clock_result["gait_clock_options"],
			HandoffProfile.SOLVER_POLICY_OPTIONS,
			{},
			{},
			SDK_AUTHORITY_OPTIONS,
		)
	)
	var authority: Dictionary = summary.get("sdk_authority_summary", {})
	var evidence_displacement: Vector3 = summary.get(
		"evidence_torso_displacement_world_m",
		Vector3.ZERO,
	)
	print(
		"SDK_FULL_AUTHORITY_RECEIPT ",
		JSON.stringify(
			{
				"schema_version": "sporespore_sdk_full_authority_receipt_v1",
				"ok":
				bool(summary.get("physical_wave_gait_walking_observed", false))
				and bool(authority.get("ok", false)),
				"physics_engine": summary.get("physics_engine", ""),
				"physics_hz": summary.get("physics_hz", -1),
				"solver_velocity_steps": summary.get("solver_velocity_steps", -1),
				"solver_position_steps": summary.get("solver_position_steps", -1),
				"world_build_count": summary.get("world_build_count", -1),
				"executed_ticks": summary.get("executed_ticks", -1),
				"sdk_adapter_start_tick": summary.get("sdk_adapter_start_tick", -1),
				"native_step_count": authority.get("step_count", -1),
				"compared_actuator_command_count":
				authority.get("compared_actuator_command_count", -1),
				"native_actuation_application_count":
				authority.get("native_actuation_application_count", -1),
				"legacy_post_settle_actuation_application_count":
				summary.get("legacy_post_settle_actuation_application_count", -1),
				"mismatch_count": authority.get("mismatch_count", -1),
				"safe_no_actuation_count": authority.get("safe_no_actuation_count", -1),
				"native_safe_disable_application_count":
				authority.get("native_safe_disable_application_count", -1),
				"maximum_absolute_target_position_error_rad":
				authority.get("maximum_absolute_target_position_error_rad", NAN),
				"maximum_absolute_target_velocity_error_rad_s":
				authority.get("maximum_absolute_target_velocity_error_rad_s", NAN),
				"maximum_absolute_speed_limit_error_rad_s":
				authority.get("maximum_absolute_speed_limit_error_rad_s", NAN),
				"maximum_absolute_phase_error_steps":
				authority.get("maximum_absolute_phase_error_steps", -1),
				"maximum_absolute_steering_error":
				authority.get("maximum_absolute_steering_error", NAN),
				"comparison_tolerance": authority.get("comparison_tolerance", NAN),
				"evidence_start_tick": summary.get("evidence_start_tick", -1),
				"evidence_end_tick": summary.get("evidence_end_tick", -1),
				"evidence_gait_advance_ticks_by_limb":
				summary.get("evidence_gait_advance_ticks_by_limb", {}),
				"evidence_forward_displacement_m": evidence_displacement.x,
				"maximum_tilt_rad": summary.get("maximum_tilt_rad", NAN),
				"maximum_anchor_error_m": summary.get("maximum_anchor_error_m", NAN),
				"maximum_hinge_axis_error_rad":
				summary.get("maximum_hinge_axis_error_rad", NAN),
				"contact_gate_timeout_count_by_limb":
				summary.get("contact_gate_timeout_count_by_limb", {}),
				"physical_wave_gait_walking_observed":
				summary.get("physical_wave_gait_walking_observed", false),
				"formal_milestone_acceptance_authorized":
				summary.get("formal_milestone_acceptance_authorized", true),
				"encyclopedia_admission_authorized":
				summary.get("encyclopedia_admission_authorized", true),
			},
		),
	)
	if (
		not bool(summary.get("physical_wave_gait_walking_observed", false))
		or not bool(authority.get("ok", false))
	):
		print(
			"SDK_FULL_AUTHORITY_FAILURE_DIAGNOSTIC ",
			{
				"failure_code": summary.get("failure_code", ""),
				"walking_gates": summary.get("walking_gate_receipts", {}),
				"authority_failure_code": summary.get("sdk_authority_failure_code", ""),
				"last_application": summary.get("sdk_authority_last_application_result", {}),
				"executed_ticks": summary.get("executed_ticks", -1),
				"adapter_start_tick": summary.get("sdk_adapter_start_tick", -1),
				"maximum_anchor_error_m": summary.get("maximum_anchor_error_m", NAN),
				"maximum_hinge_axis_error_rad":
				summary.get("maximum_hinge_axis_error_rad", NAN),
				"authority": authority,
			},
		)
	_check(int(summary.get("world_build_count", 0)) == 1, "one private Jolt world executes")
	_check(
		String(summary.get("sdk_authority_scope", "")) == "post_settle_full"
		and int(summary.get("sdk_adapter_start_tick", -1)) == 240,
		"native authority starts at the frozen post-settle boundary",
	)
	var authority_steps := int(authority.get("step_count", 0))
	var expected_authority_steps := (
		int(summary.get("executed_ticks", 0)) - int(summary.get("sdk_adapter_start_tick", 0))
	)
	_check(
		bool(authority.get("ok", false))
		and authority_steps == expected_authority_steps
		and authority_steps > 1800,
		"native authority spans warmup, evidence, cooldown, and terminal settling",
	)
	_check(
		int(authority.get("native_actuation_application_count", -1)) == authority_steps * 8
		and int(authority.get("compared_actuator_command_count", -1)) == authority_steps * 8,
		"all eight native commands are compared and applied on every post-settle frame",
	)
	_check(
		int(summary.get("legacy_post_settle_actuation_application_count", -1)) == 0
		and int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0,
		"legacy GDScript applies no motor command after the native takeover",
	)
	_check(
		int(authority.get("mismatch_count", -1)) == 0
		and int(authority.get("safe_no_actuation_count", -1)) == 0
		and int(authority.get("native_safe_disable_application_count", -1)) == 0
		and int(authority.get("maximum_absolute_phase_error_steps", -1)) == 0,
		"clocked and contact-gated native phases match with no safety failure",
	)
	_check(
		float(authority.get("maximum_absolute_target_position_error_rad", INF))
		<= MAXIMUM_POSITION_MAPPING_ERROR_RAD,
		"position mapping remains inside its signal-specific float32 ceiling",
	)
	_check(
		float(authority.get("maximum_absolute_target_velocity_error_rad_s", INF))
		<= MAXIMUM_VELOCITY_MAPPING_ERROR_RAD_S,
		"velocity mapping remains inside its signal-specific float32 ceiling",
	)
	_check(
		float(authority.get("maximum_absolute_speed_limit_error_rad_s", INF))
		<= MAXIMUM_SPEED_LIMIT_MAPPING_ERROR_RAD_S,
		"speed-limit mapping remains inside its signal-specific ceiling",
	)
	_check(
		float(authority.get("maximum_absolute_steering_error", INF))
		<= MAXIMUM_STEERING_MAPPING_ERROR,
		"steering mapping remains inside its signal-specific float32 ceiling",
	)
	var manifest: Dictionary = authority.get("adapter_manifest", {})
	_check(
		bool(manifest.get("actuation_authority", false))
		and (manifest.get("phase_progression_modes", []) as Array)
		== ["clocked", "contact_gated"],
		"the capability manifest freezes both native phase-progression modes",
	)
	_check(
		bool(
			(summary.get("walking_gate_receipts", {}) as Dictionary).get(
				"native_sdk_exclusive_post_settle_actuation",
				false,
			)
		)
		and bool(summary.get("physical_wave_gait_walking_observed", false)),
		"native-exclusive post-settle authority and every physical walking gate pass",
	)
	_check(
		not bool(summary.get("formal_milestone_acceptance_authorized", true))
		and not bool(summary.get("encyclopedia_admission_authorized", true)),
		"the development full-authority run grants no formal or knowledge authority",
	)
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print("\nSDK Godot/Jolt full-authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
