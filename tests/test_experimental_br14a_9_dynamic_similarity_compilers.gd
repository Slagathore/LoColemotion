extends SceneTree
# gdlint: disable=max-line-length

## No-world GS3 dynamic-similarity compiler contract.

const ClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const EXPECTED_LOCKED_S2_CONTROLLER_DIGEST := "sha256:7478184503ca25fe591675afdee7366615e885763ecb0ed0e57e0bf82a3445cc"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.9 dynamic-similarity compilers ===")
	var reference_clock_result := ClockSpecScript.compile()
	var reference_clock: Dictionary = reference_clock_result.get("gait_clock_options", {})
	_check(
		(
			bool(reference_clock_result.get("ok", false))
			and int(reference_clock.get("cycle_ticks", -1)) == 360
			and int(reference_clock.get("swing_ticks", -1)) == 72
			and float(reference_clock.get("motor_position_gain_per_s", NAN)) == 8.0
			and float(reference_clock.get("motor_rate_damping", NAN)) == 0.65
		),
		"empty clock request preserves the established reference controller",
	)

	var reference_path_result := (
		WaveGaitScript
		. _normalize_path_steering_options(
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			}
		)
	)
	var reference_actuator_result := WaveGaitScript._normalize_actuator_impulse_options({})
	var reference_motor_result := WaveGaitScript._normalize_motor_velocity_options({})
	var reference_controller := (
		WaveGaitScript
		. _controller_configuration(
			-1.0,
			10.0,
			1.75,
			"lateral",
			["rear_left", "front_left", "rear_right", "front_right"],
			72,
			0.40,
			"all",
			112,
			{
				"contact_gated_phase_progression": true,
				"maximum_contact_gate_hold_ticks": 96,
				"maximum_contact_gated_phase_skew_ticks": 12,
				"lateral_stride_steering_gain_per_m": 0.0,
			},
			reference_path_result.get("path_steering_options", {}),
			reference_actuator_result.get("actuator_impulse_options", {}),
			reference_motor_result.get("motor_velocity_options", {}),
			reference_clock,
		)
	)
	_check(
		(
			bool(reference_path_result.get("ok", false))
			and bool(reference_actuator_result.get("ok", false))
			and bool(reference_motor_result.get("ok", false))
			and not reference_controller.has("gait_clock_options")
			and (
				CanonicalJsonScript.sha256(reference_controller)
				== EXPECTED_LOCKED_S2_CONTROLLER_DIGEST
			)
		),
		"reference controller configuration remains byte-identical to official GS2",
	)

	var unit_clock_result := ClockSpecScript.dynamic_similarity_clock(1.0)
	var unit_clock: Dictionary = unit_clock_result.get("gait_clock_options", {})
	_check(
		(
			bool(unit_clock_result.get("ok", false))
			and int(unit_clock_result.get("world_build_count", -1)) == 0
			and _clock_numeric_values_match(unit_clock, reference_clock)
		),
		"unit dynamic scale is numerically identity-preserving without physics",
	)

	var upper_clock_result := ClockSpecScript.dynamic_similarity_clock(1.1)
	var upper_clock: Dictionary = upper_clock_result.get("gait_clock_options", {})
	_check(
		(
			bool(upper_clock_result.get("ok", false))
			and int(upper_clock.get("cycle_ticks", -1)) == 376
			and int(upper_clock.get("swing_ticks", -1)) == 75
			and int(upper_clock.get("settle_ticks", -1)) == 252
			and int(upper_clock.get("terminal_settle_ticks", -1)) == 252
			and int(upper_clock.get("evidence_boundary_alignment_ticks", -1)) == 117
			and int(upper_clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 752
			and int(upper_clock.get("maximum_contact_gate_hold_ticks", -1)) == 100
			and int(upper_clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 13
			and int(upper_clock.get("steering_update_interval_ticks", -1)) == 94
			and int(upper_clock.get("minimum_airborne_dwell_ticks", -1)) == 3
		),
		"upper clock integer receipts match the preregistered rounding law",
	)
	_check(
		(
			_is_close(
				float(upper_clock.get("motor_position_gain_per_s", NAN)),
				7.62770071396474,
			)
			and _is_close(
				float(upper_clock.get("maximum_motor_target_speed_rad_s", NAN)),
				3.33711906235957,
			)
			and _is_close(
				float(upper_clock.get("motor_rate_damping", NAN)),
				0.65,
			)
		),
		"upper clock motor receipts match the inverse-square-root time law",
	)

	var reference_fixture := FixtureSpecScript.reference_spec()
	var reference_compiled := FixtureSpecScript.compile(reference_fixture)
	var unit_fixture_result := FixtureSpecScript.dynamic_similarity_scaled_spec(1.0)
	_check(
		(
			bool(reference_compiled.get("ok", false))
			and bool(unit_fixture_result.get("ok", false))
			and (
				String(unit_fixture_result.get("fixture_spec_sha256", ""))
				== String(reference_compiled.get("fixture_spec_sha256", ""))
			)
		),
		"unit dynamic fixture is byte-identical to the reference fixture",
	)

	var upper_fixture_result := FixtureSpecScript.dynamic_similarity_scaled_spec(1.1)
	var upper_fixture: Dictionary = upper_fixture_result.get("fixture_spec", {})
	_check(
		(
			bool(upper_fixture_result.get("ok", false))
			and int(upper_fixture_result.get("world_build_count", -1)) == 0
			and _is_close(float(upper_fixture_result.get("time_scale", NAN)), sqrt(1.1))
			and _is_close(
				float(upper_fixture_result.get("density_mass_scale", NAN)),
				pow(1.1, 3.0),
			)
			and _is_close(
				float(
					(
						upper_fixture_result
						. get(
							"dynamic_similarity_motor_impulse_scale",
							NAN,
						)
					)
				),
				1.4641,
			)
		),
		"upper fixture exposes exact no-world scale-law receipts",
	)

	var upper_torso: Dictionary = upper_fixture.get("torso", {})
	var upper_dynamics: Dictionary = upper_fixture.get("body_dynamics", {})
	var upper_motor: Dictionary = upper_fixture.get("motor_impulses", {})
	_check(
		(
			_is_close(float(upper_torso.get("mass_kg", NAN)), 3.0 * pow(1.1, 3.0))
			and _is_close(
				float(upper_dynamics.get("linear_damp", NAN)),
				0.0762770071396474,
			)
			and _is_close(
				float(upper_dynamics.get("angular_damp", NAN)),
				0.143019388386839,
			)
			and _is_close(float(upper_motor.get("hip_max_impulse_nms", NAN)), 0.0805255)
			and _is_close(
				float(upper_motor.get("knee_base_max_impulse_nms", NAN)),
				0.0658845,
			)
			and _limb_scaling_exact(upper_fixture, reference_fixture, 1.1)
		),
		"upper dynamic fixture applies s, s-cubed, s-fourth, and inverse-time laws",
	)

	var fixed_upper_result := FixtureSpecScript.uniform_scaled_spec(1.1)
	var fixed_upper: Dictionary = fixed_upper_result.get("fixture_spec", {})
	_check(
		(
			bool(fixed_upper_result.get("ok", false))
			and _is_close(
				float(fixed_upper_result.get("fixed_period_motor_impulse_scale", NAN)),
				pow(1.1, 5.0),
			)
			and (
				(fixed_upper.get("body_dynamics", {}) as Dictionary)
				== (reference_fixture["body_dynamics"] as Dictionary)
			)
			and (
				String(fixed_upper_result.get("fixture_spec_sha256", ""))
				!= String(upper_fixture_result.get("fixture_spec_sha256", ""))
			)
		),
		"validated fixed-period generation remains unchanged and distinct",
	)

	var invalid_clock := ClockSpecScript.dynamic_similarity_clock(0.0)
	var out_of_campaign_clock := ClockSpecScript.dynamic_similarity_clock(1.151)
	var direct_out_of_campaign_clock := upper_clock.duplicate(true)
	direct_out_of_campaign_clock["uniform_scale"] = 1.151
	var direct_out_of_campaign_result := ClockSpecScript.compile(direct_out_of_campaign_clock)
	var invalid_fixture := FixtureSpecScript.dynamic_similarity_scaled_spec(INF)
	_check(
		(
			not bool(invalid_clock.get("ok", true))
			and int(invalid_clock.get("world_build_count", -1)) == 0
			and not bool(out_of_campaign_clock.get("ok", true))
			and (
				String(out_of_campaign_clock.get("failure_code", ""))
				== "UNIFORM_SCALE_OUT_OF_RANGE"
			)
			and int(out_of_campaign_clock.get("world_build_count", -1)) == 0
			and not bool(direct_out_of_campaign_result.get("ok", true))
			and (
				String(direct_out_of_campaign_result.get("failure_code", ""))
				== "UNIFORM_SCALE_OUT_OF_RANGE"
			)
			and int(direct_out_of_campaign_result.get("world_build_count", -1)) == 0
			and not bool(invalid_fixture.get("ok", true))
			and int(invalid_fixture.get("world_build_count", -1)) == 0
		),
		"invalid and out-of-campaign scales fail closed before physics",
	)

	var malformed_clock := reference_clock.duplicate(true)
	malformed_clock["cycle_ticks"] = 361
	var malformed_result := ClockSpecScript.compile(malformed_clock)
	_check(
		(
			not bool(malformed_result.get("ok", true))
			and String(malformed_result.get("failure_code", "")) == "INVALID_GAIT_CLOCK_RELATION"
			and int(malformed_result.get("world_build_count", -1)) == 0
		),
		"non-quarter-aligned clock requests fail closed",
	)

	var tampered_clock := upper_clock.duplicate(true)
	tampered_clock["settle_ticks"] = int(tampered_clock["settle_ticks"]) + 1
	var tampered_result := ClockSpecScript.compile(tampered_clock)
	_check(
		(
			not bool(tampered_result.get("ok", true))
			and (
				String(tampered_result.get("failure_code", ""))
				== "GAIT_CLOCK_POLICY_RECEIPT_MISMATCH"
			)
			and int(tampered_result.get("world_build_count", -1)) == 0
		),
		"relation-valid clock tampering fails the exact policy receipt",
	)

	var walker := WaveGaitScript.new()
	var mismatched_walker_result: Dictionary = await (
		walker
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
			{},
			{},
			{},
			{},
			{},
			{},
			upper_clock,
		)
	)
	_check(
		(
			not bool(mismatched_walker_result.get("ok", true))
			and (
				String(mismatched_walker_result.get("failure_code", ""))
				== "DYNAMIC_GAIT_CLOCK_RECEIPT_MISMATCH"
			)
			and int(mismatched_walker_result.get("world_build_count", -1)) == 0
		),
		"walker rejects mismatched dynamic timing before building a world",
	)

	_check(
		(
			not upper_fixture.has("formal_milestone_acceptance_authorized")
			and not upper_fixture.has("automatic_creature_guidance_allowed")
			and (
				String(upper_clock.get("policy_id", ""))
				== ClockSpecScript.DYNAMIC_SIMILARITY_POLICY_ID
			)
		),
		"compiler receipts grant no promotion or automatic creature authority",
	)
	_finish()


func _clock_numeric_values_match(candidate: Dictionary, reference: Dictionary) -> bool:
	for key in reference.keys():
		if key == "policy_id":
			continue
		if candidate.get(key) != reference.get(key):
			return false
	return true


func _limb_scaling_exact(
	fixture: Dictionary,
	reference: Dictionary,
	scale: float,
) -> bool:
	var limbs: Array = fixture.get("limbs", [])
	var reference_limbs: Array = reference.get("limbs", [])
	if limbs.size() != reference_limbs.size():
		return false
	for index in range(limbs.size()):
		var limb: Dictionary = limbs[index]
		var reference_limb: Dictionary = reference_limbs[index]
		if (
			not _is_close(
				float(limb.get("upper_mass_kg", NAN)),
				float(reference_limb["upper_mass_kg"]) * pow(scale, 3.0),
			)
			or not _is_close(
				float(limb.get("distal_mass_kg", NAN)),
				float(reference_limb["distal_mass_kg"]) * pow(scale, 3.0),
			)
			or not _is_close(
				float(limb.get("upper_length_m", NAN)),
				float(reference_limb["upper_length_m"]) * scale,
			)
			or not _is_close(
				float(limb.get("lower_length_m", NAN)),
				float(reference_limb["lower_length_m"]) * scale,
			)
		):
			return false
	return true


func _is_close(actual: float, expected: float, tolerance: float = 1.0e-12) -> bool:
	return is_finite(actual) and absf(actual - expected) <= tolerance


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
