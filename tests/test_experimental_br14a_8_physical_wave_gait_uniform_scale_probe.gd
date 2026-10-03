extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## G2 one-world uniform-scale physical probe.
##
## This program is campaign-only. A no-argument invocation performs one guard
## assertion and creates no physics world. The policy-receipt mode also creates
## no physics world. The campaign runner supplies one preregistered scale,
## campaign, role, and repetition per isolated process.

const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const ClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CAMPAIGN_GS1 := "G2-GS1"
const CAMPAIGN_GS2 := "G2-GS2"
const CAMPAIGN_GS3 := "G2-GS3"
const GS1_SELECTION_SCALES := [0.900, 0.950, 1.000, 1.050, 1.100]
const GS1_HELD_OUT_SCALES := [0.925, 0.975, 1.025, 1.075]
const GS2_SELECTION_SCALES := [0.900, 0.950, 1.000, 1.050, 1.075]
const GS2_HELD_OUT_SCALES := [0.925, 0.975, 1.025]
const GS3_SELECTION_SCALES := [1.000, 1.100, 1.150]
const GS3_HELD_OUT_SCALES := [1.050, 1.125]
const S2_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 96,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.8 G2 uniform-scale wave gait ===")
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		_check(
			true,
			"uniform-scale probing remains campaign-only without a supplied cell",
		)
		_finish()
		return
	if user_args.size() == 2 and String(user_args[0]) == "policy-receipt":
		var receipt_campaign := String(user_args[1])
		var receipt_grid := _campaign_grid(receipt_campaign)
		_check(
			not receipt_grid.is_empty(),
			"policy receipt names one preregistered campaign",
		)
		if receipt_grid.is_empty():
			_finish()
			return
		var receipt_policy := _formula_policy(receipt_campaign, receipt_grid)
		var receipt_digest := CanonicalJsonScript.sha256(receipt_policy)
		_check(
			receipt_digest.begins_with("sha256:") and receipt_digest.length() == 71,
			"formula-complete policy digest seals without constructing a world",
		)
		print(
			(
				"UNIFORM_SCALE_POLICY_RECEIPT campaign=%s policy_digest=%s"
				% [receipt_campaign, receipt_digest]
			)
		)
		_finish()
		return
	_check(user_args.size() == 4, "one scale, campaign, role, and repetition are supplied")
	if user_args.size() != 4:
		_finish()
		return
	var uniform_scale := String(user_args[0]).to_float()
	var campaign_generation := String(user_args[1])
	var campaign_role := String(user_args[2])
	var repetition := String(user_args[3]).to_int()
	var campaign_grid := _campaign_grid(campaign_generation)
	var declared_cell := _declared_cell(
		uniform_scale,
		campaign_generation,
		campaign_role,
		repetition,
	)
	_check(
		declared_cell,
		"campaign, scale, role, and repetition match the preregistered grid",
	)
	if not declared_cell:
		_finish()
		return

	var policy := _formula_policy(campaign_generation, campaign_grid)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var dynamic_similarity := campaign_generation == CAMPAIGN_GS3
	var clock_result: Dictionary = (
		ClockSpecScript.dynamic_similarity_clock(uniform_scale)
		if dynamic_similarity
		else ClockSpecScript.compile()
	)
	var gait_clock: Dictionary = clock_result.get("gait_clock_options", {})
	var gait_clock_digest := CanonicalJsonScript.sha256(gait_clock)
	_check(
		(
			policy_digest.begins_with("sha256:")
			and policy_digest.length() == 71
			and gait_clock_digest.begins_with("sha256:")
			and gait_clock_digest.length() == 71
		),
		"formula-complete policy and gait-clock digests seal before world construction",
	)
	var generated: Dictionary = (
		FixtureSpecScript.dynamic_similarity_scaled_spec(uniform_scale)
		if dynamic_similarity
		else FixtureSpecScript.uniform_scaled_spec(uniform_scale)
	)
	_check(
		(
			bool(clock_result.get("ok", false))
			and int(clock_result.get("world_build_count", -1)) == 0
			and bool(generated.get("ok", false))
			and int(generated.get("world_build_count", -1)) == 0
		),
		"uniform clock and fixture compile before world construction",
	)
	if not bool(clock_result.get("ok", false)) or not bool(generated.get("ok", false)):
		print("UNIFORM_SCALE_COMPILE_FAILURE clock=", clock_result, " fixture=", generated)
		_finish()
		return
	var fixture_spec: Dictionary = generated["fixture_spec"]
	_check(
		_uniform_generator_receipts_exact(generated, uniform_scale, campaign_generation),
		"generator receipts match the preregistered density, impulse, and timing laws",
	)
	_check(
		_uniform_fixture_exact(fixture_spec, uniform_scale, campaign_generation),
		"every generated geometry, mass, margin, and motor field matches the reference formula",
	)
	_check(
		_fixture_invariants_exact(fixture_spec, uniform_scale, campaign_generation),
		"material, damping policy, collision behavior, and joint limits are formula-exact",
	)

	var requested_thresholds := _evidence_thresholds(uniform_scale)
	var compiled_thresholds: Dictionary = WaveGaitScript.compile_evidence_threshold_options(
		requested_thresholds
	)
	_check(
		(
			bool(compiled_thresholds.get("ok", false))
			and int(compiled_thresholds.get("world_build_count", -1)) == 0
			and (
				(compiled_thresholds["evidence_threshold_options"] as Dictionary)
				== requested_thresholds
			)
		),
		"dimensionless walking thresholds compile before world construction",
	)
	if not bool(compiled_thresholds.get("ok", false)):
		print("UNIFORM_SCALE_THRESHOLD_FAILURE ", compiled_thresholds)
		_finish()
		return
	var requested_perturbation := _requested_perturbation(
		uniform_scale,
		campaign_generation,
		campaign_role,
		repetition,
	)
	var robustness_options := _robustness_options(campaign_generation, gait_clock)
	var path_steering := _path_steering_options(
		uniform_scale,
		campaign_generation,
		gait_clock,
	)
	var requested_gait_clock := gait_clock if dynamic_similarity else {}
	var summary: Dictionary = await (
		WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			int(gait_clock["swing_ticks"]),
			0.40,
			"all",
			int(gait_clock["evidence_boundary_alignment_ticks"]),
			false,
			requested_perturbation,
			robustness_options,
			fixture_spec,
			path_steering,
			{},
			{},
			requested_thresholds,
			requested_gait_clock,
		)
	)
	var world_executed := int(summary.get("world_build_count", 0)) == 1
	_check(world_executed, "one private physical world returns a complete summary")
	if not world_executed:
		print("UNIFORM_SCALE_WORLD_FAILURE ", summary)
		_finish()
		return

	var fixture_digest := String(summary.get("fixture_spec_sha256", ""))
	var controller_digest := String(summary.get("controller_configuration_sha256", ""))
	var threshold_digest := String(summary.get("evidence_threshold_configuration_sha256", ""))
	_check(
		(
			fixture_digest == String(generated["fixture_spec_sha256"])
			and (summary["fixture_spec"] as Dictionary) == fixture_spec
			and is_equal_approx(float(summary.get("fixture_view_scale", NAN)), uniform_scale)
		),
		"realized world preserves the compiled fixture digest and scale-derived presentation",
	)
	_check(
		(
			(summary.get("evidence_threshold_options", {}) as Dictionary) == requested_thresholds
			and (
				threshold_digest
				== String(compiled_thresholds["evidence_threshold_configuration_sha256"])
			)
		),
		"realized normalized-threshold receipt and digest are exact",
	)
	_check(
		_controller_receipt_exact(
			summary,
			uniform_scale,
			campaign_generation,
			gait_clock,
			robustness_options,
			path_steering,
		),
		"controller timing, motor, robustness, and path receipts match the selected formula",
	)
	_check(
		_perturbation_receipt_exact(
			summary.get("initial_perturbation", {}),
			uniform_scale,
			campaign_generation,
			campaign_role,
			repetition,
		),
		"initial perturbation matches the preregistered scale-specific repetition",
	)
	_check(
		(
			int(summary.get("body_count", 0)) == 9
			and int(summary.get("limb_count", 0)) == 4
			and int(summary.get("world_reset_count", -1)) == 0
			and int(summary.get("cycle_ticks", -1)) == int(gait_clock["cycle_ticks"])
			and int(summary.get("swing_ticks", -1)) == int(gait_clock["swing_ticks"])
		),
		"nine free bodies retain the exact four-limb topology and compiled gait period",
	)
	_check(
		(
			int(summary.get("direct_torso_force_command_count", -1)) == 0
			and int(summary.get("direct_torso_impulse_command_count", -1)) == 0
			and int(summary.get("direct_torso_velocity_command_count", -1)) == 0
			and int(summary.get("direct_torso_transform_command_count", -1)) == 0
		),
		"no root force, impulse, velocity, transform, freeze, or teleport command appears",
	)
	_check(
		_realized_impulses_exact(summary, uniform_scale, campaign_generation),
		"realized hip and knee motor impulses match the selected scale law",
	)
	_check(
		(
			String(summary.get("physics_engine", "")) == "Jolt Physics"
			and int(summary.get("physics_hz", -1)) == 120
			and int(summary.get("solver_velocity_steps", -1)) == 20
			and int(summary.get("solver_position_steps", -1)) == 6
		),
		"pinned Jolt solver settings execute in the isolated world",
	)
	_check(
		_all_true(summary.get("walking_gate_receipts", {})),
		"every topology, contact, movement, recovery, and normalized structural gate passes",
	)
	_check(
		_contact_progression_exact(summary, int(gait_clock["cycle_ticks"])),
		"every limb completes the full evidence horizon, two cycles, and zero gate timeouts",
	)
	_check(
		_normalized_metric_bounds_exact(summary, requested_thresholds),
		"measured movement and structural values satisfy the preregistered normalized bounds",
	)
	_check(
		(
			bool(summary.get("physical_wave_gait_walking_observed", false))
			and bool(summary.get("ok", false))
			and String(summary.get("failure_code", "")) == ""
		),
		"one-world physical walking is established for this declared scale cell",
	)
	_check(
		(
			not bool(summary.get("formal_milestone_acceptance_authorized", true))
			and not bool(summary.get("encyclopedia_admission_authorized", true))
			and not bool(summary.get("automatic_creature_guidance_allowed", true))
		),
		"development result retains all broader acceptance and guidance nonclaims",
	)

	var evidence_displacement: Vector3 = summary.get(
		"evidence_torso_displacement_world_m", Vector3.ZERO
	)
	var final_displacement: Vector3 = summary.get("final_torso_displacement_world_m", Vector3.ZERO)
	print(
		(
			(
				"UNIFORM_SCALE_RESULT scale=%.6f campaign=%s role=%s repetition=%d "
				+ "policy_digest=%s clock_digest=%s walking=%s fixture_digest=%s "
				+ "controller_digest=%s threshold_digest=%s "
				+ "evidence=(%.6f,%.6f,%.6f) final=(%.6f,%.6f,%.6f) "
				+ "anchor=%.9f hinge=%.9f height=%.9f"
			)
			% [
				uniform_scale,
				campaign_generation,
				campaign_role,
				repetition,
				policy_digest,
				gait_clock_digest,
				str(bool(summary.get("physical_wave_gait_walking_observed", false))).to_lower(),
				fixture_digest,
				controller_digest,
				threshold_digest,
				evidence_displacement.x,
				evidence_displacement.y,
				evidence_displacement.z,
				final_displacement.x,
				final_displacement.y,
				final_displacement.z,
				float(summary.get("maximum_anchor_error_m", NAN)),
				float(summary.get("maximum_hinge_axis_error_rad", NAN)),
				float(summary.get("minimum_torso_height_m", NAN)),
			]
		)
	)
	_finish()


static func _campaign_grid(campaign_generation: String) -> Dictionary:
	if campaign_generation == CAMPAIGN_GS1:
		return {
			"selection_scales": GS1_SELECTION_SCALES.duplicate(),
			"held_out_scales": GS1_HELD_OUT_SCALES.duplicate(),
		}
	if campaign_generation == CAMPAIGN_GS2:
		return {
			"selection_scales": GS2_SELECTION_SCALES.duplicate(),
			"held_out_scales": GS2_HELD_OUT_SCALES.duplicate(),
		}
	if campaign_generation == CAMPAIGN_GS3:
		return {
			"selection_scales": GS3_SELECTION_SCALES.duplicate(),
			"held_out_scales": GS3_HELD_OUT_SCALES.duplicate(),
		}
	return {}


static func _declared_cell(
	uniform_scale: float,
	campaign_generation: String,
	campaign_role: String,
	repetition: int,
) -> bool:
	if not is_finite(uniform_scale):
		return false
	var campaign_grid := _campaign_grid(campaign_generation)
	if campaign_grid.is_empty():
		return false
	if campaign_role == "selection":
		return repetition == 0 and _contains_scale(campaign_grid["selection_scales"], uniform_scale)
	if campaign_role == "heldout":
		return (
			repetition >= 1
			and repetition <= 3
			and _contains_scale(campaign_grid["held_out_scales"], uniform_scale)
		)
	return false


static func _contains_scale(scales: Array, candidate: float) -> bool:
	for scale_value in scales:
		if is_equal_approx(float(scale_value), candidate):
			return true
	return false


static func _formula_policy(campaign_generation: String, campaign_grid: Dictionary) -> Dictionary:
	if campaign_generation == CAMPAIGN_GS1:
		return {
			"schema_version": "sporespore_g2_gs1_uniform_scale_policy_v1",
			"linear_geometry_exponent": 1.0,
			"constant_density_mass_exponent": 3.0,
			"fixed_period_motor_impulse_exponent": 5.0,
			"gait_period_policy": "fixed_360_ticks",
			"joint_target_speed_policy": "fixed_radians_per_second",
			"cross_track_gain_policy": "reference_0p5_divided_by_uniform_scale",
			"evidence_threshold_policy_id": "uniform_scale_dimensionless_thresholds_v1",
			"selection_scales": GS1_SELECTION_SCALES.duplicate(),
			"held_out_scales": GS1_HELD_OUT_SCALES.duplicate(),
			"formal_milestone_acceptance_authorized": false,
			"automatic_creature_guidance_allowed": false,
		}
	if campaign_generation == CAMPAIGN_GS3:
		return {
			"schema_version": "sporespore_g2_gs3_dynamic_similarity_policy_v1",
			"campaign_generation": CAMPAIGN_GS3,
			"clock_policy_id": ClockSpecScript.DYNAMIC_SIMILARITY_POLICY_ID,
			"linear_geometry_exponent": 1.0,
			"constant_density_mass_exponent": 3.0,
			"dynamic_similarity_motor_impulse_exponent": 4.0,
			"gait_time_scale_policy": "sqrt_uniform_scale",
			"quarter_cycle_ticks_policy": "round_positive_90_sqrt_scale",
			"cycle_ticks_policy": "four_times_quarter_cycle_ticks",
			"swing_ticks_policy": "round_positive_0p20_cycle_ticks",
			"settle_ticks_policy": "round_positive_240_sqrt_scale",
			"terminal_settle_ticks_policy": "round_positive_240_sqrt_scale",
			"alignment_ticks_policy": "round_positive_112_over_360_cycle_ticks",
			"contact_extension_ticks_policy": "two_cycle_ticks",
			"contact_hold_ticks_policy": "round_positive_96_over_360_cycle_ticks",
			"phase_skew_ticks_policy": "round_positive_12_over_360_cycle_ticks",
			"steering_interval_policy": "quarter_cycle_ticks",
			"airborne_dwell_ticks_policy": "round_positive_3_over_360_cycle_ticks",
			"motor_position_gain_policy": "reference_8_divided_by_sqrt_scale",
			"motor_target_speed_policy": "reference_3p5_divided_by_sqrt_scale",
			"motor_rate_damping_policy": "fixed_0p65",
			"body_damping_policy": "reference_divided_by_sqrt_scale",
			"cross_track_gain_policy": "reference_0p5_divided_by_uniform_scale",
			"linear_perturbation_policy": "reference_times_sqrt_scale",
			"angular_perturbation_policy": "reference_divided_by_sqrt_scale",
			"phase_offset_policy": "signed_round_positive_reference_times_sqrt_scale",
			"evidence_threshold_policy_id": "uniform_scale_dimensionless_thresholds_v1",
			"selection_scales": GS3_SELECTION_SCALES.duplicate(),
			"held_out_scales": GS3_HELD_OUT_SCALES.duplicate(),
			"held_out_repetitions": [1, 2, 3],
			"formal_milestone_acceptance_authorized": false,
			"automatic_creature_guidance_allowed": false,
		}
	return {
		"schema_version": "sporespore_g2_uniform_scale_policy_v2",
		"campaign_generation": campaign_generation,
		"linear_geometry_exponent": 1.0,
		"constant_density_mass_exponent": 3.0,
		"fixed_period_motor_impulse_exponent": 5.0,
		"gait_period_policy": "fixed_360_ticks",
		"joint_target_speed_policy": "fixed_radians_per_second",
		"cross_track_gain_policy": "reference_0p5_divided_by_uniform_scale",
		"evidence_threshold_policy_id": "uniform_scale_dimensionless_thresholds_v1",
		"selection_scales": (campaign_grid["selection_scales"] as Array).duplicate(),
		"held_out_scales": (campaign_grid["held_out_scales"] as Array).duplicate(),
		"formal_milestone_acceptance_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}


static func _evidence_thresholds(uniform_scale: float) -> Dictionary:
	return {
		"evidence_threshold_policy_id": "uniform_scale_dimensionless_thresholds_v1",
		"minimum_foot_relocation_m": 0.012 * uniform_scale,
		"minimum_evidence_torso_advance_m": 0.040 * uniform_scale,
		"minimum_final_torso_advance_m": 0.030 * uniform_scale,
		"maximum_lateral_drift_m": 0.100 * uniform_scale,
		"maximum_yaw_drift_rad": 0.45,
		"maximum_tilt_rad": 0.60,
		"minimum_torso_height_m": 0.250 * uniform_scale,
		"maximum_anchor_error_m": 0.025 * uniform_scale,
		"maximum_hinge_axis_error_rad": 0.20,
	}


static func _robustness_options(
	campaign_generation: String,
	gait_clock: Dictionary,
) -> Dictionary:
	if campaign_generation != CAMPAIGN_GS3:
		return S2_ROBUSTNESS_OPTIONS.duplicate(true)
	return {
		"contact_gated_phase_progression": true,
		"maximum_contact_gate_hold_ticks": int(gait_clock["maximum_contact_gate_hold_ticks"]),
		"maximum_contact_gated_phase_skew_ticks":
		int(gait_clock["maximum_contact_gated_phase_skew_ticks"]),
		"lateral_stride_steering_gain_per_m": 0.0,
	}


static func _path_steering_options(
	uniform_scale: float,
	campaign_generation: String,
	gait_clock: Dictionary,
) -> Dictionary:
	var update_interval_ticks := (
		int(gait_clock["steering_update_interval_ticks"])
		if campaign_generation == CAMPAIGN_GS3
		else 90
	)
	return {
		"phase_bounded_path_steering_enabled": true,
		"cross_track_heading_gain_rad_per_m": 0.5 / uniform_scale,
		"yaw_error_stride_gain_per_rad": 1.0,
		"steering_update_interval_ticks": update_interval_ticks,
		"maximum_desired_heading_error_rad": 0.25,
		"maximum_steering_fraction": 0.20,
	}


static func _requested_perturbation(
	uniform_scale: float,
	campaign_generation: String,
	campaign_role: String,
	repetition: int,
) -> Dictionary:
	if campaign_role == "selection" or repetition == 1:
		return {}
	var time_scale := sqrt(uniform_scale)
	var linear_scale := time_scale if campaign_generation == CAMPAIGN_GS3 else uniform_scale
	var angular_scale := 1.0 / time_scale if campaign_generation == CAMPAIGN_GS3 else 1.0
	if repetition == 2:
		return {
			"campaign_seed": 15202,
			"fixture_vertical_clearance_m": 0.0007 * uniform_scale,
			"fixture_yaw_rad": 0.003,
			"initial_linear_velocity_world_m_s":
			Vector3(0.002 * linear_scale, 0.0, 0.001 * linear_scale),
			"initial_torso_angular_velocity_world_rad_s":
			Vector3(0.002 * angular_scale, 0.0, 0.001 * angular_scale),
			"gait_phase_offset_ticks":
			_scaled_signed_phase_offset(1, time_scale, campaign_generation),
		}
	return {
		"campaign_seed": 15203,
		"fixture_vertical_clearance_m": 0.0014 * uniform_scale,
		"fixture_yaw_rad": -0.006,
		"initial_linear_velocity_world_m_s":
		Vector3(0.004 * linear_scale, 0.0, -0.002 * linear_scale),
		"initial_torso_angular_velocity_world_rad_s":
		Vector3(0.003 * angular_scale, -0.002 * angular_scale, 0.002 * angular_scale),
		"gait_phase_offset_ticks": _scaled_signed_phase_offset(-2, time_scale, campaign_generation),
	}


static func _scaled_signed_phase_offset(
	reference_ticks: int,
	time_scale: float,
	campaign_generation: String,
) -> int:
	if campaign_generation != CAMPAIGN_GS3:
		return reference_ticks
	var magnitude := floori(absf(float(reference_ticks)) * time_scale + 0.5)
	return magnitude if reference_ticks >= 0 else -magnitude


static func _uniform_generator_receipts_exact(
	generated: Dictionary,
	uniform_scale: float,
	campaign_generation: String,
) -> bool:
	var dynamic_similarity := campaign_generation == CAMPAIGN_GS3
	var impulse_receipt_key := (
		"dynamic_similarity_motor_impulse_scale"
		if dynamic_similarity
		else "fixed_period_motor_impulse_scale"
	)
	var expected_impulse_scale := pow(uniform_scale, 4.0 if dynamic_similarity else 5.0)
	return (
		is_equal_approx(float(generated.get("uniform_scale", NAN)), uniform_scale)
		and is_equal_approx(
			float(generated.get("density_mass_scale", NAN)), pow(uniform_scale, 3.0)
		)
		and is_equal_approx(
			float(generated.get(impulse_receipt_key, NAN)),
			expected_impulse_scale,
		)
		and (
			not dynamic_similarity
			or is_equal_approx(float(generated.get("time_scale", NAN)), sqrt(uniform_scale))
		)
		and String(generated.get("fixture_spec_sha256", "")).length() == 71
	)


static func _uniform_fixture_exact(
	fixture: Dictionary,
	uniform_scale: float,
	campaign_generation: String,
) -> bool:
	var reference := FixtureSpecScript.reference_spec()
	var mass_scale := pow(uniform_scale, 3.0)
	var impulse_exponent := 4.0 if campaign_generation == CAMPAIGN_GS3 else 5.0
	var impulse_scale := pow(uniform_scale, impulse_exponent)
	var torso: Dictionary = fixture.get("torso", {})
	var reference_torso: Dictionary = reference["torso"]
	if (
		not is_equal_approx(float(torso.get("mass_kg", NAN)), 3.0 * mass_scale)
		or not _scaled_array_exact(
			torso.get("size_m", []), reference_torso["size_m"], uniform_scale
		)
		or not _scaled_array_exact(
			torso.get("initial_center_m", []),
			reference_torso["initial_center_m"],
			uniform_scale,
		)
	):
		return false
	var limbs: Array = fixture.get("limbs", [])
	var reference_limbs: Array = reference["limbs"]
	if limbs.size() != reference_limbs.size():
		return false
	for index in range(limbs.size()):
		var limb: Dictionary = limbs[index]
		var reference_limb: Dictionary = reference_limbs[index]
		if (
			String(limb.get("limb_id", "")) != String(reference_limb["limb_id"])
			or not _scaled_array_exact(
				limb.get("hip_offset_from_torso_center_m", []),
				reference_limb["hip_offset_from_torso_center_m"],
				uniform_scale,
			)
			or not _scaled_array_exact(
				limb.get("upper_cross_section_m", []),
				reference_limb["upper_cross_section_m"],
				uniform_scale,
			)
			or not is_equal_approx(
				float(limb.get("upper_mass_kg", NAN)),
				float(reference_limb["upper_mass_kg"]) * mass_scale,
			)
			or not is_equal_approx(
				float(limb.get("distal_mass_kg", NAN)),
				float(reference_limb["distal_mass_kg"]) * mass_scale,
			)
			or not is_equal_approx(
				float(limb.get("upper_length_m", NAN)),
				float(reference_limb["upper_length_m"]) * uniform_scale,
			)
			or not is_equal_approx(
				float(limb.get("lower_length_m", NAN)),
				float(reference_limb["lower_length_m"]) * uniform_scale,
			)
			or not is_equal_approx(
				float(limb.get("foot_radius_m", NAN)),
				float(reference_limb["foot_radius_m"]) * uniform_scale,
			)
		):
			return false
	var motor: Dictionary = fixture.get("motor_impulses", {})
	var reference_motor: Dictionary = reference["motor_impulses"]
	return (
		is_equal_approx(
			float(fixture.get("collision_margin_m", NAN)),
			float(reference["collision_margin_m"]) * uniform_scale,
		)
		and is_equal_approx(
			float(motor.get("hip_max_impulse_nms", NAN)),
			float(reference_motor["hip_max_impulse_nms"]) * impulse_scale,
		)
		and is_equal_approx(
			float(motor.get("knee_base_max_impulse_nms", NAN)),
			float(reference_motor["knee_base_max_impulse_nms"]) * impulse_scale,
		)
	)


static func _fixture_invariants_exact(
	fixture: Dictionary,
	uniform_scale: float,
	campaign_generation: String,
) -> bool:
	var reference := FixtureSpecScript.reference_spec()
	var expected_body_dynamics: Dictionary = (reference["body_dynamics"] as Dictionary).duplicate(
		true
	)
	if campaign_generation == CAMPAIGN_GS3:
		var inverse_time_scale := 1.0 / sqrt(uniform_scale)
		expected_body_dynamics["linear_damp"] = (
			float(expected_body_dynamics["linear_damp"]) * inverse_time_scale
		)
		expected_body_dynamics["angular_damp"] = (
			float(expected_body_dynamics["angular_damp"]) * inverse_time_scale
		)
	return (
		(
			(fixture.get("contact_material", {}) as Dictionary)
			== (reference["contact_material"] as Dictionary)
		)
		and ((fixture.get("body_dynamics", {}) as Dictionary) == expected_body_dynamics)
		and (
			(fixture.get("joint_limits", {}) as Dictionary)
			== (reference["joint_limits"] as Dictionary)
		)
		and not fixture.has("morphology_generalization_established")
		and not fixture.has("automatic_creature_guidance_allowed")
	)


static func _scaled_array_exact(realized: Array, reference: Array, scale: float) -> bool:
	if realized.size() != reference.size():
		return false
	for index in range(realized.size()):
		if not is_equal_approx(float(realized[index]), float(reference[index]) * scale):
			return false
	return true


static func _controller_receipt_exact(
	summary: Dictionary,
	uniform_scale: float,
	campaign_generation: String,
	gait_clock: Dictionary,
	requested_robustness: Dictionary,
	requested_path_steering: Dictionary,
) -> bool:
	var controller: Dictionary = summary.get("controller_configuration", {})
	var dynamic_similarity := campaign_generation == CAMPAIGN_GS3
	return (
		(
			String(controller.get("schema_version", ""))
			== "sporespore_physical_wave_gait_controller_configuration_v1"
		)
		and float(controller.get("motor_direction_sign", NAN)) == -1.0
		and float(controller.get("knee_motor_impulse_scale", NAN)) == 10.0
		and float(controller.get("knee_flexion_scale", NAN)) == 1.75
		and String(controller.get("gait_phase_order_id", "")) == "lateral"
		and int(controller.get("cycle_ticks", -1)) == int(gait_clock["cycle_ticks"])
		and int(controller.get("swing_ticks", -1)) == int(gait_clock["swing_ticks"])
		and int(controller.get("settle_ticks", -1)) == int(gait_clock["settle_ticks"])
		and (
			int(controller.get("terminal_settle_ticks", -1))
			== int(gait_clock["terminal_settle_ticks"])
		)
		and (
			int(controller.get("evidence_boundary_alignment_ticks", -1))
			== int(gait_clock["evidence_boundary_alignment_ticks"])
		)
		and is_equal_approx(
			float(controller.get("motor_position_gain_per_s", NAN)),
			float(gait_clock["motor_position_gain_per_s"]),
		)
		and is_equal_approx(
			float(controller.get("motor_rate_damping", NAN)),
			float(gait_clock["motor_rate_damping"]),
		)
		and is_equal_approx(
			float(controller.get("maximum_motor_target_speed_rad_s", NAN)),
			float(gait_clock["maximum_motor_target_speed_rad_s"]),
		)
		and float(controller.get("contact_clearance_assist_rad", NAN)) == 0.40
		and (controller.get("robustness_options", {}) as Dictionary) == requested_robustness
		and ((controller.get("path_steering_options", {}) as Dictionary) == requested_path_steering)
		and is_equal_approx(
			float(
				(controller["path_steering_options"] as Dictionary).get(
					"cross_track_heading_gain_rad_per_m", NAN
				)
			),
			0.5 / uniform_scale,
		)
		and not controller.has("actuator_impulse_options")
		and not controller.has("motor_velocity_options")
		and (
			((controller.get("gait_clock_options", {}) as Dictionary) == gait_clock)
			if dynamic_similarity
			else not controller.has("gait_clock_options")
		)
	)


static func _perturbation_receipt_exact(
	receipt_value: Variant,
	uniform_scale: float,
	campaign_generation: String,
	campaign_role: String,
	repetition: int,
) -> bool:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return false
	var receipt: Dictionary = receipt_value
	var expected := _requested_perturbation(
		uniform_scale,
		campaign_generation,
		campaign_role,
		repetition,
	)
	if expected.is_empty():
		return (
			int(receipt.get("campaign_seed", -1)) == 0
			and float(receipt.get("fixture_vertical_clearance_m", NAN)) == 0.0
			and float(receipt.get("fixture_yaw_rad", NAN)) == 0.0
			and (
				(receipt.get("initial_linear_velocity_world_m_s", Vector3.INF) as Vector3)
				. is_zero_approx()
			)
			and (
				(receipt.get("initial_torso_angular_velocity_world_rad_s", Vector3.INF) as Vector3)
				. is_zero_approx()
			)
			and int(receipt.get("gait_phase_offset_ticks", -99)) == 0
		)
	return (
		int(receipt.get("campaign_seed", -1)) == int(expected["campaign_seed"])
		and is_equal_approx(
			float(receipt.get("fixture_vertical_clearance_m", NAN)),
			float(expected["fixture_vertical_clearance_m"]),
		)
		and is_equal_approx(
			float(receipt.get("fixture_yaw_rad", NAN)), float(expected["fixture_yaw_rad"])
		)
		and (
			(receipt.get("initial_linear_velocity_world_m_s", Vector3.INF) as Vector3)
			. is_equal_approx(expected["initial_linear_velocity_world_m_s"])
		)
		and (
			(receipt.get("initial_torso_angular_velocity_world_rad_s", Vector3.INF) as Vector3)
			. is_equal_approx(expected["initial_torso_angular_velocity_world_rad_s"])
		)
		and (
			int(receipt.get("gait_phase_offset_ticks", -99))
			== int(expected["gait_phase_offset_ticks"])
		)
	)


static func _realized_impulses_exact(
	summary: Dictionary,
	uniform_scale: float,
	campaign_generation: String,
) -> bool:
	var impulse_exponent := 4.0 if campaign_generation == CAMPAIGN_GS3 else 5.0
	var impulse_scale := pow(uniform_scale, impulse_exponent)
	return (
		is_equal_approx(
			float(summary.get("realized_hip_max_impulse_nms", NAN)),
			0.055 * impulse_scale,
		)
		and is_equal_approx(
			float(summary.get("realized_knee_max_impulse_nms", NAN)),
			0.045 * 10.0 * impulse_scale,
		)
	)


static func _contact_progression_exact(summary: Dictionary, cycle_ticks: int) -> bool:
	var cycles: Dictionary = summary.get("contact_cycle_count_by_limb", {})
	var timeouts: Dictionary = summary.get("contact_gate_timeout_count_by_limb", {})
	var advance: Dictionary = summary.get("evidence_gait_advance_ticks_by_limb", {})
	for limb_id in ["front_left", "front_right", "rear_left", "rear_right"]:
		if (
			int(cycles.get(limb_id, 0)) < 2
			or int(timeouts.get(limb_id, -1)) != 0
			or int(advance.get(limb_id, -1)) != 3 * cycle_ticks
		):
			return false
	return true


static func _normalized_metric_bounds_exact(summary: Dictionary, thresholds: Dictionary) -> bool:
	var evidence: Vector3 = summary.get("evidence_torso_displacement_world_m", Vector3.INF)
	var final: Vector3 = summary.get("final_torso_displacement_world_m", Vector3.INF)
	var relocation: Dictionary = summary.get("minimum_cycle_relocation_by_limb_m", {})
	for limb_id in ["front_left", "front_right", "rear_left", "rear_right"]:
		if (
			not is_finite(float(relocation.get(limb_id, NAN)))
			or (
				float(relocation.get(limb_id, NAN)) < float(thresholds["minimum_foot_relocation_m"])
			)
		):
			return false
	return (
		evidence.x >= float(thresholds["minimum_evidence_torso_advance_m"])
		and final.x >= float(thresholds["minimum_final_torso_advance_m"])
		and absf(final.z) <= float(thresholds["maximum_lateral_drift_m"])
		and (
			absf(float(summary.get("final_yaw_drift_rad", INF)))
			<= float(thresholds["maximum_yaw_drift_rad"])
		)
		and float(summary.get("maximum_tilt_rad", INF)) <= float(thresholds["maximum_tilt_rad"])
		and (
			float(summary.get("minimum_torso_height_m", -INF))
			>= float(thresholds["minimum_torso_height_m"])
		)
		and (
			float(summary.get("maximum_anchor_error_m", INF))
			<= float(thresholds["maximum_anchor_error_m"])
		)
		and (
			float(summary.get("maximum_hinge_axis_error_rad", INF))
			<= float(thresholds["maximum_hinge_axis_error_rad"])
		)
	)


static func _all_true(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for receipt_value in (value as Dictionary).values():
		if typeof(receipt_value) != TYPE_BOOL or not bool(receipt_value):
			return false
	return not (value as Dictionary).is_empty()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
