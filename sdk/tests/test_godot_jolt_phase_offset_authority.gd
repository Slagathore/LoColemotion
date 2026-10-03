extends SceneTree

## Development-only commissioning of the host bridge's one-time phase-offset
## synchronization. It uses the reference fixture, not any GQ15 cohort body,
## and therefore does not treat this fixture's offset walking result as a C6
## cohort gate. The formal runner retains every frozen physical walking gate.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const HandoffProfile := preload("res://tests/test_sdk_godot_jolt_authority_handoff.gd")

const SDK_AUTHORITY_OPTIONS := {
	"enabled": true,
	"descriptor": HandoffProfile.DESCRIPTOR,
	"comparison_tolerance": 2.5e-7,
	"authority_scope": "post_settle_full",
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt phase-offset authority commissioning ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var clock_result := GaitClockSpecScript.compile(GaitClockSpecScript.gq15_clock())
	_check(bool(clock_result.get("ok", false)), "the frozen GQ15 clock compiles")
	if not bool(clock_result.get("ok", false)):
		_finish()
		return
	for phase_offset_ticks in [1, -2]:
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
				{"gait_phase_offset_ticks": phase_offset_ticks},
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
		var receipt: Dictionary = authority.get(
			"phase_offset_synchronization_receipt",
			{},
		)
		print(
			"SDK_PHASE_OFFSET_COMMISSIONING_RECEIPT ",
			JSON.stringify(
				{
					"phase_offset_ticks": phase_offset_ticks,
					"walking": summary.get("physical_wave_gait_walking_observed", false),
					"failure_code": summary.get("failure_code", ""),
					"walking_gate_receipts": summary.get("walking_gate_receipts", {}),
					"final_torso_displacement_world_m":
					summary.get("final_torso_displacement_world_m", Vector3.ZERO),
					"maximum_tilt_rad": summary.get("maximum_tilt_rad", NAN),
					"minimum_torso_height_m": summary.get("minimum_torso_height_m", NAN),
					"authority_ok": authority.get("ok", false),
					"mismatch_count": authority.get("mismatch_count", -1),
					"maximum_absolute_phase_error_steps":
					authority.get("maximum_absolute_phase_error_steps", -1),
					"synchronization": receipt,
				}
			),
		)
		_check(
			int(summary.get("world_build_count", 0)) == 1,
			"one reference world executes for phase offset %d" % phase_offset_ticks,
		)
		_check(
			bool(receipt.get("scheduled", false))
			and int(receipt.get("requested_offset_ticks", -99)) == phase_offset_ticks
			and int(receipt.get("activation_semantic_step", -1)) == 360
			and int(receipt.get("application_count", -1)) == 1
			and int(receipt.get("synchronized_limb_count", -1)) == 4,
			"phase offset %d synchronizes once at the frozen boundary" % phase_offset_ticks,
		)
		_check(
			bool(authority.get("ok", false))
			and int(authority.get("mismatch_count", -1)) == 0
			and int(authority.get("safe_no_actuation_count", -1)) == 0
			and int(authority.get("native_safe_disable_application_count", -1)) == 0
			and int(authority.get("maximum_absolute_phase_error_steps", -1)) == 0,
			"phase offset %d retains exact native parity and safety" % phase_offset_ticks,
		)
		_check(
			bool(
				(summary.get("walking_gate_receipts", {}) as Dictionary).get(
					"native_sdk_exclusive_post_settle_actuation",
					false,
				)
			)
			and bool(
				(summary.get("walking_gate_receipts", {}) as Dictionary).get(
					"contact_gated_evidence_horizon_completed",
					false,
				)
			)
			and bool(
				(summary.get("walking_gate_receipts", {}) as Dictionary).get(
					"every_limb_completed_evidence_gait_horizon",
					false,
				)
			)
			and not bool(summary.get("formal_milestone_acceptance_authorized", true))
			and not bool(summary.get("encyclopedia_admission_authorized", true)),
			"phase offset %d completes under exclusive native authority without formal claims"
			% phase_offset_ticks,
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
	print("\nSDK phase-offset commissioning summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
