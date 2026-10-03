extends SceneTree
# gdlint: disable=max-line-length

## BR14A.6 development robustness test. The command-line seed is compiled into
## bounded, recorded physical initial-condition perturbations. A passing seed
## must satisfy the same walking gates as the unperturbed candidate; no bound
## is relaxed and no result is authorized for promotion by this test alone.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")

const LIMB_IDS := ["front_left", "front_right", "rear_left", "rear_right"]
const EXPECTED_REFERENCE_FIXTURE_DIGEST := "sha256:18361994a68e2a9a150aa539aff39679ba4b6e892092e26d218b08f6e12e9c3b"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.6 seeded physical wave-gait robustness ===")
	var solver_velocity_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/velocity_steps", -1)
	)
	var solver_position_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/position_steps", -1)
	)
	if solver_velocity_steps != 20 or solver_position_steps != 6:
		print(
			(
				(
					"  ISOLATED_VARIANT_REQUIRED velocity_steps=%d position_steps=%d "
					+ "required=20/6"
				)
				% [solver_velocity_steps, solver_position_steps]
			)
		)
		_check(
			(
				(
					String(ProjectSettings.get_setting("physics/3d/physics_engine", ""))
					== "Jolt Physics"
				)
				and solver_velocity_steps == 20
				and solver_position_steps == 4
			),
			"repository-wide solver-4 regression refuses to impersonate the seeded solver-6 variant",
		)
		_finish()
		return
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		_check(
			true,
			"seeded robustness remains explicit campaign-only without a supplied seed",
		)
		_finish()
		return
	_check(user_args.size() == 1, "exactly one campaign seed is supplied")
	if user_args.size() != 1:
		_finish()
		return
	var campaign_seed := int(user_args[0])
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(campaign_seed)
	_check(
		bool(perturbation_result.get("ok", false)),
		"campaign seed compiles into a bounded initial perturbation",
	)
	if not bool(perturbation_result.get("ok", false)):
		printerr("  perturbation_result=", perturbation_result)
		_finish()
		return
	var perturbation: Dictionary = perturbation_result["initial_perturbation"]
	var robustness_options := {
		"contact_gated_phase_progression": true,
		"maximum_contact_gate_hold_ticks": 96,
		"maximum_contact_gated_phase_skew_ticks": 12,
		"lateral_stride_steering_gain_per_m": 0.5,
	}
	var initial_linear_velocity: Vector3 = perturbation["initial_linear_velocity_world_m_s"]
	var initial_angular_velocity: Vector3 = perturbation["initial_torso_angular_velocity_world_rad_s"]
	print(
		(
			(
				"SEED_PERTURBATION seed=%d clearance=%.9f yaw=%.9f "
				+ "linear=(%.9f,%.9f,%.9f) angular=(%.9f,%.9f,%.9f) phase=%d"
			)
			% [
				campaign_seed,
				float(perturbation["fixture_vertical_clearance_m"]),
				float(perturbation["fixture_yaw_rad"]),
				initial_linear_velocity.x,
				initial_linear_velocity.y,
				initial_linear_velocity.z,
				initial_angular_velocity.x,
				initial_angular_velocity.y,
				initial_angular_velocity.z,
				int(perturbation["gait_phase_offset_ticks"]),
			]
		)
	)
	_check(
		(
			int(perturbation["campaign_seed"]) == campaign_seed
			and (
				float(perturbation["fixture_vertical_clearance_m"]) > 0.0
				or absf(float(perturbation["fixture_yaw_rad"])) > 0.0
				or not initial_linear_velocity.is_zero_approx()
				or not initial_angular_velocity.is_zero_approx()
				or int(perturbation["gait_phase_offset_ticks"]) != 0
			)
		),
		"seed realization is recorded and physically non-nominal",
	)
	var summary := await WaveGaitScript.new().run(
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
		robustness_options
	)
	print(
		(
			(
				"SEED_WALK_RESULT seed=%d walking=%s cycles=%s rejected=%s "
				+ "minimum_relocation=%s evidence=%s final=%s yaw=%.9f "
				+ "tilt=%.9f anchor=%.9f anchor_joint=%s anchor_tick=%d "
				+ "hinge=%.9f horizon=%d advance=%d "
				+ "holds=%s release_holds=%s recontact_holds=%s timeouts=%s"
			)
			% [
				campaign_seed,
				str(summary.get("physical_wave_gait_walking_observed", false)),
				str(summary.get("contact_cycle_count_by_limb", {})),
				str(summary.get("rejected_short_contact_cycle_count_by_limb", {})),
				str(summary.get("minimum_cycle_relocation_by_limb_m", {})),
				str(summary.get("evidence_torso_displacement_world_m", Vector3.ZERO)),
				str(summary.get("final_torso_displacement_world_m", Vector3.ZERO)),
				float(summary.get("final_yaw_drift_rad", NAN)),
				float(summary.get("maximum_tilt_rad", NAN)),
				float(summary.get("maximum_anchor_error_m", NAN)),
				String(summary.get("maximum_anchor_error_joint_id", "")),
				int(summary.get("maximum_anchor_error_tick", -1)),
				float(summary.get("maximum_hinge_axis_error_rad", NAN)),
				int(summary.get("evidence_end_tick", -1)),
				int(summary.get("evidence_gait_advance_ticks", -1)),
				str(summary.get("contact_gate_hold_tick_count_by_limb", {})),
				str(summary.get("contact_gate_release_hold_tick_count_by_limb", {})),
				str(summary.get("contact_gate_recontact_hold_tick_count_by_limb", {})),
				str(summary.get("contact_gate_timeout_count_by_limb", {})),
			]
		)
	)
	_check(
		(
			bool(summary.get("ok", false))
			and bool(summary.get("physical_wave_gait_walking_observed", false))
		),
		"seeded candidate establishes the unchanged walking predicate",
	)
	_check(
		summary.get("initial_perturbation", {}) == perturbation,
		"summary returns the exact realized seed perturbation",
	)
	_check(
		(
			summary.get("robustness_options", {}) == robustness_options
			and (
				String(summary.get("fixture_spec_sha256", "")) == EXPECTED_REFERENCE_FIXTURE_DIGEST
			)
			and (
				String(
					(summary.get("controller_configuration", {}) as Dictionary).get(
						"schema_version", ""
					)
				)
				== "sporespore_physical_wave_gait_controller_configuration_v1"
			)
			and (
				(summary.get("controller_configuration", {}) as Dictionary).get(
					"robustness_options", {}
				)
				== robustness_options
			)
			and String(summary.get("controller_configuration_sha256", "")).begins_with("sha256:")
			and String(summary.get("controller_configuration_sha256", "")).length() == 71
		),
		"summary returns the exact digested fixture and contact-gating controller configuration",
	)
	_check(
		(
			String(summary.get("physics_engine", "")) == "Jolt Physics"
			and int(summary.get("physics_hz", 0)) == 120
			and int(summary.get("solver_velocity_steps", 0)) == 20
			and int(summary.get("solver_position_steps", 0)) == 6
		),
		"seeded run retains the pinned physics environment",
	)
	_check(
		(
			int(summary.get("evidence_end_tick", -1)) >= 1792
			and int(summary.get("evidence_end_tick", -1)) <= 2512
			and int(summary.get("evidence_gait_advance_ticks", -1)) == 1080
			and not bool(summary.get("contact_gated_evidence_horizon_timeout", true))
			and (
				int(summary.get("executed_ticks", 0))
				== int(summary.get("evidence_end_tick", -1)) + 600
			)
		),
		"seeded evidence advances three gait cycles inside the bounded dynamic horizon",
	)
	_check(
		(
			int(summary.get("world_build_count", 0)) == 1
			and int(summary.get("world_reset_count", -1)) == 0
			and int(summary.get("body_count", 0)) == 9
			and int(summary.get("limb_count", 0)) == 4
		),
		"seeded run retains one continuous nine-body world",
	)
	_check(
		(
			int(summary.get("initial_linear_velocity_body_initialization_count", 0)) == 9
			and int(summary.get("initial_torso_angular_velocity_initialization_count", 0)) == 1
		),
		"seeded velocity perturbations are applied only at fixture initialization",
	)
	_check(
		(
			int(summary.get("direct_torso_force_command_count", -1)) == 0
			and int(summary.get("direct_torso_impulse_command_count", -1)) == 0
			and int(summary.get("direct_torso_velocity_command_count", -1)) == 0
			and int(summary.get("direct_torso_transform_command_count", -1)) == 0
			and int(summary.get("lateral_stride_steering_target_adjustment_count", 0)) > 0
			and (
				float(summary.get("maximum_absolute_lateral_stride_steering_fraction", INF)) <= 0.20
			)
		),
		"no seeded run gains post-release root locomotor authority",
	)
	var callback_counts: Dictionary = summary.get("contact_observer_callback_count_by_limb", {})
	var every_observer_executed := callback_counts.size() == 4
	for limb_id in LIMB_IDS:
		every_observer_executed = (
			every_observer_executed
			and (int(callback_counts.get(limb_id, 0)) == int(summary.get("executed_ticks", 0)) + 1)
		)
	_check(every_observer_executed, "every seeded foot contact observer executes exactly")
	var cycle_counts: Dictionary = summary.get("contact_cycle_count_by_limb", {})
	var minimum_relocations: Dictionary = summary.get("minimum_cycle_relocation_by_limb_m", {})
	var every_limb_repeated_and_relocated := cycle_counts.size() == 4
	for limb_id in LIMB_IDS:
		every_limb_repeated_and_relocated = (
			every_limb_repeated_and_relocated
			and int(cycle_counts.get(limb_id, 0)) >= 2
			and float(minimum_relocations.get(limb_id, -INF)) >= 0.012
		)
	_check(
		every_limb_repeated_and_relocated,
		"every seeded limb repeats real forward-relocating contact cycles",
	)
	var evidence_displacement: Vector3 = summary.get(
		"evidence_torso_displacement_world_m", Vector3(-INF, -INF, -INF)
	)
	var final_displacement: Vector3 = summary.get(
		"final_torso_displacement_world_m", Vector3(-INF, -INF, -INF)
	)
	_check(
		(
			evidence_displacement.x >= 0.040
			and final_displacement.x >= 0.030
			and absf(final_displacement.z) <= 0.10
		),
		"seeded torso advances with the unchanged lateral bound",
	)
	_check(
		(
			float(summary.get("final_yaw_drift_rad", INF)) <= 0.45
			and float(summary.get("maximum_tilt_rad", INF)) <= 0.60
			and float(summary.get("minimum_torso_height_m", -INF)) >= 0.25
			and int(summary.get("torso_contact_ticks", -1)) == 0
		),
		"seeded torso retains yaw, tilt, height, and contact safety",
	)
	_check(
		(
			float(summary.get("maximum_anchor_error_m", INF)) <= 0.025
			and float(summary.get("maximum_hinge_axis_error_rad", INF)) <= 0.20
		),
		"seeded joint structure remains inside the unchanged bounds",
	)
	_check(
		(
			bool(summary.get("initial_all_four_contacts", false))
			and bool(summary.get("evidence_all_four_contacts_at_start", false))
			and bool(summary.get("terminal_all_four_contacts", false))
		),
		"seeded run starts, measures, and recovers on four feet",
	)
	var gates: Dictionary = summary.get("walking_gate_receipts", {})
	var every_gate_true := not gates.is_empty()
	for gate_value in gates.values():
		every_gate_true = every_gate_true and bool(gate_value)
	_check(every_gate_true, "every named seeded walking gate remains true")
	var contact_gate_timeouts: Dictionary = summary.get("contact_gate_timeout_count_by_limb", {})
	var zero_contact_gate_timeouts := contact_gate_timeouts.size() == 4
	for limb_id in LIMB_IDS:
		zero_contact_gate_timeouts = (
			zero_contact_gate_timeouts and int(contact_gate_timeouts.get(limb_id, -1)) == 0
		)
	_check(zero_contact_gate_timeouts, "contact-gated phase progression never times out")
	_check(
		(
			not bool(summary.get("formal_milestone_acceptance_authorized", true))
			and not bool(summary.get("encyclopedia_admission_authorized", true))
			and not bool(summary.get("automatic_creature_guidance_allowed", true))
		),
		"seeded development evidence cannot self-promote into trusted knowledge",
	)
	var invalid_seed_result := WaveGaitScript.compile_seeded_initial_perturbation(0)
	_check(
		(
			not bool(invalid_seed_result.get("ok", true))
			and (
				String(invalid_seed_result.get("failure_code", ""))
				== "INVALID_INITIAL_PERTURBATION_SEED"
			)
		),
		"nonpositive perturbation seed fails closed",
	)
	var invalid_field := await WaveGaitScript.new().run(
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
		{"campaign_seed": campaign_seed, "undeclared_force": 1.0}
	)
	var invalid_steering_gain := await WaveGaitScript.new().run(
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
		{"lateral_stride_steering_gain_per_m": -0.1}
	)
	_check(
		(
			not bool(invalid_field.get("ok", true))
			and (
				String(invalid_field.get("failure_code", ""))
				== "UNKNOWN_INITIAL_PERTURBATION_FIELD"
			)
			and not bool(invalid_steering_gain.get("ok", true))
			and (
				String(invalid_steering_gain.get("failure_code", ""))
				== "INVALID_LATERAL_STRIDE_STEERING_GAIN"
			)
		),
		"undeclared perturbation and invalid steering fields fail before world creation",
	)
	_finish()


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
