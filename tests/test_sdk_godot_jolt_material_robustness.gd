extends SceneTree

## P5M.3-R1 first-result harness.
##
## The full mode constructs the preregistered 23 worlds exactly once from a
## clean pushed source. The preflight-only mode compiles the frozen matrix,
## seeds, fixtures, profiles, and clock without constructing a world or
## exposing a locomotion outcome.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")

const RECEIPT_SCHEMA := "sporespore_godot_jolt_material_robustness_r1_receipt_v1"
const PREFLIGHT_SCHEMA := "sporespore_godot_jolt_material_robustness_r1_preflight_receipt_v1"
const BW2_RECEIPT_SCHEMA := "sporespore_balanced_wave_bw2_material_receipt_v1"
const BW2_PREFLIGHT_SCHEMA := "sporespore_balanced_wave_bw2_material_preflight_receipt_v1"
const EXPECTED_GATE_COUNT := 32
const BW2_EXPECTED_GATE_COUNT := 30
const EXPECTED_WORLD_COUNT := 23
const EXPECTED_STEP_COUNT := 1514
const EXPECTED_MOTOR_WRITE_COUNT := EXPECTED_STEP_COUNT * 8
const MAXIMUM_OVERLAY_DELTA_RAD_S := 0.075
const MAXIMUM_OVERLAY_SLEW_RAD_S_PER_STEP := 0.010
const MAXIMUM_READBACK_ERROR_RAD_S := 2.0e-8
const MAXIMUM_HOST_COMMAND_QUANTIZATION_ERROR_RAD_S := 1.2e-7
const MAXIMUM_LIMITER_RECONSTRUCTION_ERROR := 5.0e-8
const MINIMUM_PAIRED_TERMINAL_SEPARATION_M := 1.0e-5
const CORE_FRAME_TOLERANCE := 1.0e-9

const FEEDBACK_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const BW2_CANDIDATES := {
	"--bw2-a":
	{
		"candidate_id": "BW2-A",
		"policy_id": "sporespore_balanced_wave_v1",
		"policy_digest": "sha256:d1ce56ba1a74f843700559e1b240c3a5a4ea33c31d7a14d874fdd2c6ebfb2fd9",
	},
	"--bw2-b":
	{
		"candidate_id": "BW2-B",
		"policy_id": "sporespore_balanced_wave_bw2_b_v1",
		"policy_digest": "sha256:0ab4fa4c4e37441b26bdd00d23926e4511892201150bf61554c5b1362edf7913",
	},
	"--bw2-c":
	{
		"candidate_id": "BW2-C",
		"policy_id": "sporespore_balanced_wave_bw2_c_v1",
		"policy_digest": "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3",
	},
	"--bw2r-a":
	{
		"candidate_id": "BW2R-A",
		"policy_id": "sporespore_balanced_wave_bw2r_a_v1",
		"policy_digest": "sha256:4ffb7abd947f60287b81c9105fb99b2964355d0e16e13b64bc8b18d9fcec6343",
	},
	"--bw2r-b":
	{
		"candidate_id": "BW2R-B",
		"policy_id": "sporespore_balanced_wave_bw2r_b_v1",
		"policy_digest": "sha256:44e8bfd0e4e1227db56ace8c58fc62fa6dd6bfc0d1cb993367510214272da144",
	},
	"--bw2r-c":
	{
		"candidate_id": "BW2R-C",
		"policy_id": "sporespore_balanced_wave_bw2r_c_v1",
		"policy_digest": "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0",
	},
	"--bw4r-a":
	{
		"candidate_id": "BW4R-A",
		"policy_id": "sporespore_balanced_wave_bw4r_a_v1",
		"policy_digest": "sha256:40dc551e99fea518df68c35d49e3d7d9605484e25cb385f938b3568ddcab2cf4",
	},
	"--bw4r-b":
	{
		"candidate_id": "BW4R-B",
		"policy_id": "sporespore_balanced_wave_bw4r_b_v1",
		"policy_digest": "sha256:2496dc6da6dea17cfc7ffee0027234fa7a2a0f4eea8bc463a68db9a9d105bae7",
	},
	"--bw5r-a":
	{
		"candidate_id": "BW5R-A",
		"policy_id": "sporespore_balanced_wave_bw5r_a_v1",
		"policy_digest": "sha256:6001dd2b5926908a1bad16d17e49e233cbfb1dfa7eb360bdfe8e4df147b245ac",
	},
	"--bw5r-b":
	{
		"candidate_id": "BW5R-B",
		"policy_id": "sporespore_balanced_wave_bw5r_b_v1",
		"policy_digest": "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
	},
	"--bw5r-c":
	{
		"candidate_id": "BW5R-C",
		"policy_id": "sporespore_balanced_wave_bw5r_c_v1",
		"policy_digest": "sha256:c067ece936a53edb9cc9d667a68274451e4db67b762ab262bf42e8efe88d742d",
	},
}
const OVERLAY_RUNTIME_ID := "sporespore_godot_jolt_stability_overlay_runtime_v1"
const OVERLAY_MEMORY_ID := "sporespore_stability_overlay_memory_v1"
const P5I3C_R2_SOURCE_COMMIT := "df6c9e55e2e8eaf9433eba83f70d6031ca186592"
const P5I3C_R2_REPORT_SHA256 := "d0971317d174f7bb5aef4cbea1f79c462182a0cd3e4ce59c83980ef6a7cb305b"
const P5M2_SOURCE_COMMIT := "3d7e5d9e7e4092014fb84f57b1ef19acd7397cff"
const P5M2_REPORT_SHA256 := "31892f82d188c0d43726c78ab829e3b1a3925b011748fb5a9621ca0fb6740a6d"

const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "godot_jolt_stability_physical_influence_reference",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 1.0,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.275,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const ACTUATOR_IMPULSE_OPTIONS := {
	"mass_adaptive_actuator_enabled": true,
	"actuator_policy_id": "g3_gp3_global_actuator_margin_v1",
	"actuator_impulse_scale": 1.015,
}
const MOTOR_VELOCITY_OPTIONS := {
	"mass_adaptive_motor_velocity_enabled": true,
	"motor_velocity_policy_id": "g3_gp5_morphology_interaction_anchor_guard_v1",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s": 3.5,
	"anchor_error_guard_enabled": true,
	"morphology_interaction_score": 0.0,
	"anchor_error_guard_activation_fraction": 0.90,
	"anchor_error_guard_maximum_motor_target_speed_rad_s": 2.5,
}
const SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE := 2.0e-8
const CAMPAIGN_SEEDS := [16001, 16002, 16003]
const PRIMARY_CELLS := [
	{
		"mu_token": "060",
		"authored_friction": 0.6,
		"profile_id": "godot_jolt_p5m1r1_mu060_v1",
	},
	{
		"mu_token": "080",
		"authored_friction": 0.8,
		"profile_id": "godot_jolt_p5m1r1_mu080_v1",
	},
	{
		"mu_token": "100",
		"authored_friction": 1.0,
		"profile_id": "godot_jolt_p5m1r1_mu100_v1",
	},
	{
		"mu_token": "180",
		"authored_friction": 1.8,
		"profile_id": "godot_jolt_p5m1r1_mu180_v1",
	},
]
const DIAGNOSTIC_CELLS := [
	{
		"mu_token": "020",
		"authored_friction": 0.2,
		"profile_id": "godot_jolt_p5m1r1_mu020_v1",
	},
	{
		"mu_token": "040",
		"authored_friction": 0.4,
		"profile_id": "godot_jolt_p5m1r1_mu040_v1",
	},
]
const ZERO_CELL := {
	"mu_token": "000",
	"authored_friction": 0.0,
	"profile_id": "godot_jolt_p5m1r1_mu000_v1",
}
const EXPECTED_CELL_IDS := [
	"primary_mu060_s16001_treatment",
	"primary_mu060_s16001_control",
	"primary_mu060_s16002_treatment",
	"primary_mu060_s16003_treatment",
	"primary_mu080_s16001_treatment",
	"primary_mu080_s16001_control",
	"primary_mu080_s16002_treatment",
	"primary_mu080_s16003_treatment",
	"primary_mu100_s16001_treatment",
	"primary_mu100_s16001_control",
	"primary_mu100_s16002_treatment",
	"primary_mu100_s16003_treatment",
	"primary_mu180_s16001_treatment",
	"primary_mu180_s16001_control",
	"primary_mu180_s16002_treatment",
	"primary_mu180_s16003_treatment",
	"diagnostic_mu020_s16001_treatment",
	"diagnostic_mu020_s16002_treatment",
	"diagnostic_mu020_s16003_treatment",
	"diagnostic_mu040_s16001_treatment",
	"diagnostic_mu040_s16002_treatment",
	"diagnostic_mu040_s16003_treatment",
	"negative_mu000_s16001_treatment",
]

var _passed := 0
var _failed := 0
var _bw2_mode := false
var _bw2_candidate_id := "BW2-A"
var _bw2_policy_id := "sporespore_balanced_wave_v1"
var _bw2_policy_digest := (
	"sha256:d1ce56ba1a74f843700559e1b240c3a5a4ea33c31d7a14d874fdd2c6ebfb2fd9"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt P5M.3-R1 cold material-robustness matrix ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	var preflight_only := user_args.has("--preflight-only")
	var candidate_args: Array[String] = []
	for argument_value in user_args:
		var argument := String(argument_value)
		if BW2_CANDIDATES.has(argument):
			candidate_args.append(argument)
	_bw2_mode = candidate_args.size() == 1
	if _bw2_mode:
		var selected: Dictionary = BW2_CANDIDATES[candidate_args[0]]
		_bw2_candidate_id = String(selected["candidate_id"])
		_bw2_policy_id = String(selected["policy_id"])
		_bw2_policy_digest = String(selected["policy_digest"])
	var allowed_args := ["--preflight-only"]
	if _bw2_mode:
		allowed_args.append(candidate_args[0])
	var arguments_valid := candidate_args.size() <= 1 and user_args.size() <= allowed_args.size()
	for argument_value in user_args:
		arguments_valid = arguments_valid and String(argument_value) in allowed_args
	if not arguments_valid:
		push_error(
			"P5M.3-R1 accepts --preflight-only and at most one frozen BW2 candidate argument"
		)
		quit(1)
		return
	if _bw2_mode:
		await _run_bw2_material(preflight_only)
		return

	var preflight := _compile_preflight()
	if preflight_only:
		var preflight_receipt := _preflight_receipt(preflight)
		print(
			"SDK_MATERIAL_ROBUSTNESS_PREFLIGHT_RECEIPT ",
			JSON.stringify(preflight_receipt, "", true, true),
		)
		quit(0 if bool(preflight_receipt["ok"]) else 1)
		return

	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(clock_ok, "1 the frozen GQ15 clock compiles exactly")
	_check(matrix_ok, "2 the frozen ordered 23-cell matrix is exact")
	_check(inputs_ok, "3 every frozen seed, profile, and fixture compiles before world creation")
	if not (clock_ok and matrix_ok and inputs_ok):
		_emit_full_receipt(preflight, [], [], {}, {}, false, false, false)
		_finish()
		return

	var matrix: Array = preflight["matrix"]
	var gait_clock_options: Dictionary = preflight["gait_clock_options"]
	var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
	var input_by_profile: Dictionary = preflight["input_by_profile"]
	var cell_receipts: Array = []
	var summary_by_cell_id: Dictionary = {}
	var primary_pass_count := 0
	var control_pass_count := 0
	var diagnostic_treatment_pass_count := 0
	var diagnostic_execution_count := 0
	var zero_pass_count := 0

	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var profile_id := String(cell["profile_id"])
		var seed_key := str(int(cell["campaign_seed"]))
		var input: Dictionary = input_by_profile[profile_id]
		var perturbation: Dictionary = perturbation_by_seed[seed_key]
		print(
			"P5M3_CELL_START ",
			cell_id,
			" world=",
			cell_receipts.size() + 1,
			"/",
			EXPECTED_WORLD_COUNT,
		)
		var summary: Dictionary = await _run_cell(
			gait_clock_options,
			cell,
			perturbation,
			input["fixture_spec"],
		)
		summary_by_cell_id[cell_id] = summary
		var receipt := _analyze_cell(cell, summary, perturbation, input)
		cell_receipts.append(receipt)
		var cell_gate_passed := bool(receipt["campaign_execution_gate_passed"])
		_check(
			cell_gate_passed,
			"%s completes its frozen execution and role-specific gate" % cell_id,
		)
		if String(cell["cohort"]) == "primary" and String(cell["mode"]) == "treatment":
			if bool(receipt["treatment_gate_passed"]):
				primary_pass_count += 1
		elif String(cell["mode"]) == "control":
			if bool(receipt["control_gate_passed"]):
				control_pass_count += 1
		elif String(cell["cohort"]) == "diagnostic":
			if bool(receipt["diagnostic_execution_complete"]):
				diagnostic_execution_count += 1
			if bool(receipt["treatment_gate_passed"]):
				diagnostic_treatment_pass_count += 1
		elif String(cell["cohort"]) == "negative":
			if bool(receipt["zero_friction_safety_gate_passed"]):
				zero_pass_count += 1
		print("SDK_MATERIAL_ROBUSTNESS_CELL ", JSON.stringify(receipt, "", true, true))

	var primary_acceptance := primary_pass_count == 12
	_check(
		primary_acceptance,
		"27 all 12 preregistered primary treatment worlds pass every treatment gate",
	)
	var controls_complete := control_pass_count == 4
	_check(
		controls_complete,
		"28 all four material-matched seed-16001 controls pass their shadow gates",
	)
	var paired_receipts := _paired_receipts(
		matrix,
		summary_by_cell_id,
	)
	var paired_causal_complete := (
		paired_receipts.size() == 4 and _all_pair_gates_pass(paired_receipts)
	)
	_check(
		paired_causal_complete,
		"29 all four matched pairs retain identity and nonzero terminal separation",
	)
	var diagnostics_complete := diagnostic_execution_count == 6
	_check(
		diagnostics_complete,
		"30 all six lower diagnostic worlds are complete and classified",
	)
	var zero_control_complete := zero_pass_count == 1
	_check(
		zero_control_complete,
		"31 the zero-friction world retains provenance and bounded fail-safe behavior",
	)
	var negative_claims_exact := (
		not primary_acceptance
		or (
			not bool(preflight.get("continuous_friction_coverage", true))
			and not bool(preflight.get("cross_engine_equivalence", true))
			and not bool(preflight.get("rough_terrain_robustness", true))
			and not bool(preflight.get("external_push_recovery", true))
			and not bool(preflight.get("sensor_fault_robustness", true))
			and not bool(preflight.get("fresh_morphology_validation", true))
			and not bool(preflight.get("completed_sdk", true))
		)
	)
	_check(
		negative_claims_exact,
		"32 every untested robustness and completed-SDK claim remains false",
	)

	_emit_full_receipt(
		preflight,
		cell_receipts,
		paired_receipts,
		{
			"primary_pass_count": primary_pass_count,
			"control_pass_count": control_pass_count,
			"diagnostic_execution_count": diagnostic_execution_count,
			"diagnostic_treatment_pass_count": diagnostic_treatment_pass_count,
			"zero_pass_count": zero_pass_count,
		},
		{
			"primary_acceptance": primary_acceptance,
			"controls_complete": controls_complete,
			"paired_causal_complete": paired_causal_complete,
			"diagnostics_complete": diagnostics_complete,
			"extended_discrete_cohort_passed": diagnostic_treatment_pass_count == 6,
			"zero_control_complete": zero_control_complete,
		},
		primary_acceptance,
		diagnostic_treatment_pass_count == 6,
		zero_control_complete,
	)
	_finish()


func _run_bw2_material(preflight_only: bool) -> void:
	print("\n=== SDK balanced-wave %s frozen 23-cell material matrix ===" % _bw2_candidate_id)
	var preflight := _compile_preflight()
	if preflight_only:
		var preflight_receipt := _bw2_preflight_receipt(preflight)
		print(
			"BALANCED_WAVE_BW2_MATERIAL_PREFLIGHT_RECEIPT ",
			JSON.stringify(preflight_receipt, "", true, true),
		)
		quit(0 if bool(preflight_receipt["ok"]) else 1)
		return

	var clock_ok := bool(preflight.get("clock_ok", false))
	var matrix_ok := bool(preflight.get("matrix_ok", false))
	var inputs_ok := bool(preflight.get("inputs_ok", false))
	_check(clock_ok, "1 the frozen GQ15 clock compiles exactly")
	_check(matrix_ok, "2 the frozen ordered P5M.3-R1 23-cell matrix is exact")
	_check(inputs_ok, "3 every seed, profile, fixture, and selected BW2 binding compiles")
	if not (clock_ok and matrix_ok and inputs_ok):
		_emit_bw2_material_receipt(preflight, [], {})
		_finish_bw2()
		return

	var matrix: Array = preflight["matrix"]
	var gait_clock_options: Dictionary = preflight["gait_clock_options"]
	var perturbation_by_seed: Dictionary = preflight["perturbation_by_seed"]
	var input_by_profile: Dictionary = preflight["input_by_profile"]
	var cell_receipts: Array = []
	var integrity_failure_count := 0
	var nonzero_treatment_count := 0
	var nonzero_treatment_nonwalk_count := 0
	var nonzero_treatment_with_stability_count := 0
	var control_integrity_count := 0
	var zero_exact_count := 0
	var aggregate_walking_gate_failure_count := 0

	for cell_value in matrix:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var profile_id := String(cell["profile_id"])
		var seed_key := str(int(cell["campaign_seed"]))
		var input: Dictionary = input_by_profile[profile_id]
		var perturbation: Dictionary = perturbation_by_seed[seed_key]
		print(
			"BW2_MATERIAL_CELL_START ",
			cell_id,
			" world=",
			cell_receipts.size() + 1,
			"/",
			EXPECTED_WORLD_COUNT,
		)
		var summary: Dictionary = await _run_cell(
			gait_clock_options,
			cell,
			perturbation,
			input["fixture_spec"],
		)
		var receipt := _analyze_cell(cell, summary, perturbation, input, true)
		cell_receipts.append(receipt)
		var execution_ok := bool(receipt["campaign_execution_gate_passed"])
		_check(
			execution_ok,
			"%s completes with exact %s execution integrity" % [cell_id, _bw2_candidate_id],
		)
		if not execution_ok:
			integrity_failure_count += 1
		if String(cell["mode"]) == "control":
			if execution_ok:
				control_integrity_count += 1
		elif float(cell["authored_friction"]) == 0.0:
			if bool(receipt["zero_friction_safety_gate_passed"]):
				zero_exact_count += 1
		else:
			nonzero_treatment_count += 1
			if not bool(receipt["walking_observed"]):
				nonzero_treatment_nonwalk_count += 1
			if (
				(
					int(
						(receipt.get("stability_contribution_shadow", {}) as Dictionary).get(
							"nonzero_active_command_count", 0
						)
					)
					> 0
				)
				and (
					int(
						(receipt.get("stability_overlay", {}) as Dictionary).get(
							"nonzero_effective_application_count", 0
						)
					)
					> 0
				)
			):
				nonzero_treatment_with_stability_count += 1
			aggregate_walking_gate_failure_count += _walking_gate_failure_count(
				receipt.get("walking_gate_receipts", {}),
			)
		print("BALANCED_WAVE_BW2_MATERIAL_CELL ", JSON.stringify(receipt, "", true, true))

	_check(
		(
			cell_receipts.size() == EXPECTED_WORLD_COUNT
			and nonzero_treatment_count == 18
			and control_integrity_count == 4
			and zero_exact_count == 1
		),
		"27 all 23 frozen roles complete with exact matrix cardinality",
	)
	_check(
		integrity_failure_count == 0,
		"28 the complete material matrix has zero infrastructure or integrity failures",
	)
	_check(
		nonzero_treatment_with_stability_count == nonzero_treatment_count,
		"29 every eligible nonzero-friction treatment applies nonzero stability influence",
	)
	_check(
		(
			zero_exact_count == 1
			and not bool(preflight.get("continuous_friction_coverage", true))
			and not bool(preflight.get("cross_engine_equivalence", true))
			and not bool(preflight.get("rough_terrain_robustness", true))
			and not bool(preflight.get("external_push_recovery", true))
			and not bool(preflight.get("sensor_fault_robustness", true))
			and not bool(preflight.get("fresh_morphology_validation", true))
			and not bool(preflight.get("completed_sdk", true))
		),
		"30 zero friction fails safely and every broader claim remains false",
	)

	_emit_bw2_material_receipt(
		preflight,
		cell_receipts,
		{
			"integrity_failure_count": integrity_failure_count,
			"eligible_nonzero_treatment_count": nonzero_treatment_count,
			"eligible_nonzero_treatment_nonwalk_count": nonzero_treatment_nonwalk_count,
			"eligible_nonzero_treatment_with_nonzero_stability_count":
			nonzero_treatment_with_stability_count,
			"control_integrity_count": control_integrity_count,
			"zero_friction_exact_fallback_count": zero_exact_count,
			"aggregate_walking_gate_failure_count": aggregate_walking_gate_failure_count,
		},
	)
	_finish_bw2()


func _campaign_seeds() -> Array:
	return CAMPAIGN_SEEDS


func _required_profile_ids() -> Array:
	return [
		"godot_jolt_p5m1r1_mu000_v1",
		"godot_jolt_p5m1r1_mu020_v1",
		"godot_jolt_p5m1r1_mu040_v1",
		"godot_jolt_p5m1r1_mu060_v1",
		"godot_jolt_p5m1r1_mu080_v1",
		"godot_jolt_p5m1r1_mu100_v1",
		"godot_jolt_p5m1r1_mu180_v1",
	]


func _expected_cell_ids() -> Array:
	return EXPECTED_CELL_IDS


func _expected_world_count() -> int:
	return EXPECTED_WORLD_COUNT


func _bridge_profile_id() -> String:
	return "godot_jolt_p5m1r1_mu060_v1"


func _validation_manifest_receipt() -> Dictionary:
	return {
		"ok": true,
		"applicable": false,
		"world_build_count": 0,
		"locomotion_outcome_exposed": false,
	}


func _compile_preflight() -> Dictionary:
	var clock_result := GaitClockSpecScript.compile(GaitClockSpecScript.gq15_clock())
	var compiled_clock_options: Dictionary = (
		clock_result
		. get(
			"gait_clock_options",
			{},
		)
	)
	var matrix := _build_matrix()
	var expected_cell_ids := _expected_cell_ids()
	var expected_world_count := _expected_world_count()
	var cell_ids: Array = []
	for cell_value in matrix:
		cell_ids.append(String((cell_value as Dictionary)["cell_id"]))
	var matrix_ok := (
		matrix.size() == expected_world_count
		and cell_ids == expected_cell_ids
		and _matrix_cardinality_exact(matrix)
	)
	var perturbation_by_seed := {}
	var seed_receipts: Array = []
	var task_frame_receipts: Array = []
	var seeds_ok := true
	var campaign_seeds := _campaign_seeds()
	for seed_value in campaign_seeds:
		var seed := int(seed_value)
		var result := WaveGaitScript.compile_seeded_initial_perturbation(seed)
		seeds_ok = seeds_ok and bool(result.get("ok", false))
		if bool(result.get("ok", false)):
			var perturbation: Dictionary = result["initial_perturbation"]
			var configuration_failure := (
				WaveGaitScript
				. _sdk_shadow_configuration_failure(
					-1.0,
					1.75,
					"lateral",
					72,
					0.40,
					"all",
					perturbation,
					ROBUSTNESS_OPTIONS,
					PATH_STEERING_OPTIONS,
					compiled_clock_options,
					false,
					true,
				)
			)
			var base_steps := {
				"rear_left": 42,
				"front_left": 42,
				"rear_right": 42,
				"front_right": 42,
			}
			var phase_offset := int(perturbation["gait_phase_offset_ticks"])
			var initial_steps := (
				WaveGaitScript
				. _sdk_initial_gait_steps(
					base_steps,
					phase_offset,
					true,
				)
			)
			var phase_helpers_exact := (
				String(configuration_failure).is_empty()
				and int(initial_steps["rear_left"]) == 42 + phase_offset
				and int(initial_steps["front_left"]) == 42 + phase_offset
				and int(initial_steps["rear_right"]) == 42 + phase_offset
				and int(initial_steps["front_right"]) == 42 + phase_offset
				and (
					(
						WaveGaitScript
						. _sdk_effective_phase_offset_ticks(
							phase_offset,
							true,
							false,
							0,
							100,
						)
					)
					== phase_offset
				)
				and (
					(
						WaveGaitScript
						. _sdk_effective_phase_offset_ticks(
							phase_offset,
							false,
							false,
							0,
							100,
						)
					)
					== 0
				)
			)
			seeds_ok = seeds_ok and phase_helpers_exact
			var task_frame_receipt := _task_frame_preflight_receipt(
				seed,
				float(perturbation["fixture_yaw_rad"]),
			)
			seeds_ok = seeds_ok and bool(task_frame_receipt.get("ok", false))
			perturbation_by_seed[str(seed)] = perturbation.duplicate(true)
			seed_receipts.append(_perturbation_receipt(perturbation))
			task_frame_receipts.append(task_frame_receipt)

	var input_by_profile := {}
	var profile_receipts: Array = []
	var profiles_ok := true
	var required_profile_ids := _required_profile_ids()
	for profile_id_value in required_profile_ids:
		var profile_id := String(profile_id_value)
		var resolved: Dictionary = MaterialProfilesScript.resolve(profile_id)
		profiles_ok = profiles_ok and bool(resolved.get("ok", false))
		if not bool(resolved.get("ok", false)):
			continue
		var profile: Dictionary = resolved["profile"]
		var requested_fixture := FixtureSpecScript.reference_spec()
		requested_fixture["contact_material"] = (profile["body_material"] as Dictionary).duplicate(
			true
		)
		var fixture_result := FixtureSpecScript.compile(requested_fixture)
		var profile_validation := (
			MaterialProfilesScript
			. validate_for_fixture(
				profile_id,
				requested_fixture["contact_material"],
				SOLVER_POLICY_OPTIONS,
			)
		)
		var requested_shadow_options := {
			"enabled": true,
			"descriptor": DESCRIPTOR,
			"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"stability_policy_id": FEEDBACK_POLICY_ID,
			"material_profile_id": profile_id,
		}
		var requested_authority_options := {
			"enabled": true,
			"descriptor": DESCRIPTOR,
			"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"authority_scope": "stability_contribution_overlay",
			"stability_policy_id": FEEDBACK_POLICY_ID,
			"material_profile_id": profile_id,
		}
		if _bw2_mode:
			requested_shadow_options["controller_policy_id"] = _bw2_policy_id
			requested_authority_options["controller_policy_id"] = _bw2_policy_id
		var shadow_normalization := (
			WaveGaitScript
			. _normalize_sdk_shadow_options(
				requested_shadow_options,
			)
		)
		var authority_normalization := (
			WaveGaitScript
			. _normalize_sdk_authority_options(
				requested_authority_options,
			)
		)
		var exact := (
			bool(fixture_result.get("ok", false))
			and bool(profile_validation.get("ok", false))
			and bool(shadow_normalization.get("ok", false))
			and bool(authority_normalization.get("ok", false))
			and (
				String(
					(shadow_normalization.get("sdk_shadow_options", {}) as Dictionary).get(
						"material_profile_id", ""
					)
				)
				== profile_id
			)
			and (
				String(
					(authority_normalization.get("sdk_authority_options", {}) as Dictionary).get(
						"material_profile_id", ""
					)
				)
				== profile_id
			)
			and (
				not _bw2_mode
				or (
					(
						String(
							(shadow_normalization.get("sdk_shadow_options", {}) as Dictionary).get(
								"controller_policy_id", ""
							)
						)
						== _bw2_policy_id
					)
					and (
						String(
							(
								(
									authority_normalization.get("sdk_authority_options", {})
									as Dictionary
								)
								. get("controller_policy_id", "")
							)
						)
						== _bw2_policy_id
					)
				)
			)
			and (
				absf(
					(
						float(profile["authored_friction"])
						- float(requested_fixture["contact_material"]["friction"])
					)
				)
				<= 1.0e-12
			)
		)
		profiles_ok = profiles_ok and exact
		if not exact:
			continue
		input_by_profile[profile_id] = {
			"profile": profile.duplicate(true),
			"profile_sha256": String(resolved["profile_sha256"]),
			"fixture_spec": (fixture_result["fixture_spec"] as Dictionary).duplicate(true),
			"fixture_spec_sha256": String(fixture_result["fixture_spec_sha256"]),
		}
		(
			profile_receipts
			. append(
				{
					"profile_id": profile_id,
					"profile_sha256": String(resolved["profile_sha256"]),
					"fixture_spec_sha256": String(fixture_result["fixture_spec_sha256"]),
					"authored_friction": float(profile["authored_friction"]),
					"characterized_friction_coefficient":
					float(profile["characterized_friction_coefficient"]),
					"characterization_source_commit":
					String(profile["characterization_source_commit"]),
					"characterization_report_sha256":
					String(profile["characterization_report_sha256"]),
				}
			)
		)
	var bridge_conformance := _bridge_preflight_conformance(
		input_by_profile.get(_bridge_profile_id(), {}),
	)
	var validation_manifest := _validation_manifest_receipt()
	var inputs_ok := (
		seeds_ok
		and perturbation_by_seed.size() == campaign_seeds.size()
		and profiles_ok
		and input_by_profile.size() == required_profile_ids.size()
		and bool(bridge_conformance.get("ok", false))
		and bool(validation_manifest.get("ok", false))
	)
	return {
		"ok": bool(clock_result.get("ok", false)) and matrix_ok and inputs_ok,
		"clock_ok": bool(clock_result.get("ok", false)),
		"matrix_ok": matrix_ok,
		"inputs_ok": inputs_ok,
		"matrix": matrix,
		"cell_ids": cell_ids,
		"gait_clock_options": compiled_clock_options.duplicate(true),
		"perturbation_by_seed": perturbation_by_seed,
		"seed_receipts": seed_receipts,
		"task_frame_receipts": task_frame_receipts,
		"bridge_conformance": bridge_conformance,
		"validation_manifest": validation_manifest,
		"input_by_profile": input_by_profile,
		"profile_receipts": profile_receipts,
		"expected_world_count": expected_world_count,
		"world_build_count": 0,
		"continuous_friction_coverage": false,
		"cross_engine_equivalence": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_fault_robustness": false,
		"fresh_morphology_validation": false,
		"completed_sdk": false,
	}


static func _task_frame_preflight_receipt(seed: int, yaw_rad: float) -> Dictionary:
	# Force the trigonometric values through Vector3/real_t before invoking the
	# adapter serializer. This reproduces the boundary that rejected 8badd0a
	# without constructing a physics world.
	var lateral_real_t := Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)).normalized()
	var forward_real_t := Vector3.UP.cross(lateral_real_t).normalized()
	var forward: Dictionary = (
		AdapterScript
		. _unit_vector_dictionary_binary64(
			forward_real_t,
		)
	)
	var lateral: Dictionary = (
		AdapterScript
		. _unit_vector_dictionary_binary64(
			lateral_real_t,
		)
	)
	var up: Dictionary = AdapterScript._unit_vector_dictionary_binary64(Vector3.UP)
	var forward_norm_error := absf(_vector_norm_squared(forward) - 1.0)
	var lateral_norm_error := absf(_vector_norm_squared(lateral) - 1.0)
	var up_norm_error := absf(_vector_norm_squared(up) - 1.0)
	var forward_lateral_dot := absf(_vector_dot(forward, lateral))
	var forward_up_dot := absf(_vector_dot(forward, up))
	var lateral_up_dot := absf(_vector_dot(lateral, up))
	return {
		"ok":
		(
			forward_norm_error <= CORE_FRAME_TOLERANCE
			and lateral_norm_error <= CORE_FRAME_TOLERANCE
			and up_norm_error <= CORE_FRAME_TOLERANCE
			and forward_lateral_dot <= CORE_FRAME_TOLERANCE
			and forward_up_dot <= CORE_FRAME_TOLERANCE
			and lateral_up_dot <= CORE_FRAME_TOLERANCE
		),
		"campaign_seed": seed,
		"fixture_yaw_rad": yaw_rad,
		"forward_axis_world_unit": forward,
		"lateral_axis_world_unit": lateral,
		"up_axis_world_unit": up,
		"forward_norm_squared_error": forward_norm_error,
		"lateral_norm_squared_error": lateral_norm_error,
		"up_norm_squared_error": up_norm_error,
		"forward_lateral_absolute_dot": forward_lateral_dot,
		"forward_up_absolute_dot": forward_up_dot,
		"lateral_up_absolute_dot": lateral_up_dot,
		"core_frame_tolerance": CORE_FRAME_TOLERANCE,
		"world_build_count": 0,
	}


static func _bridge_preflight_conformance(input: Dictionary) -> Dictionary:
	if input.is_empty():
		return {"ok": false, "failure_code": "P5M3_R1_PREFLIGHT_PROFILE_MISSING"}
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			DESCRIPTOR,
			{
				"rear_left": 0,
				"front_left": 0,
				"rear_right": 0,
				"front_right": 0,
			},
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			PI * 0.5,
			120,
			SOLVER_POLICY_OPTIONS,
			GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"clocked",
			false,
			0,
			-1,
			"shadow",
			FEEDBACK_POLICY_ID,
			input["profile"],
		)
	)
	if not bool(start.get("ok", false)):
		return {
			"ok": false,
			"failure_code":
			"P5M3_R1_PREFLIGHT_ADAPTER_START:%s" % String(start.get("failure_code", "")),
		}
	var compiled: Dictionary = adapter.compiled_morphology_for_conformance()
	if not bool(compiled.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "P5M3_R1_PREFLIGHT_MORPHOLOGY_UNAVAILABLE",
		}
	var morphology: Dictionary = compiled["morphology"]
	var mapped_commands: Array = []
	for actuator_id_value in morphology.get("ordered_actuator_ids", []):
		(
			mapped_commands
			. append(
				{
					"actuator_id": String(actuator_id_value),
					"mapping_mode": "support_command",
					"generalized_torque_command_nm": 0.1,
				}
			)
		)
	var available: Dictionary = (
		adapter
		. _bound_stability_contribution_shadow(
			0,
			morphology,
			mapped_commands,
			"available",
		)
	)
	var unavailable: Dictionary = (
		adapter
		. _bound_stability_contribution_shadow(
			1,
			morphology,
			[],
			"observation_unavailable",
		)
	)
	var unavailable_receipt: Dictionary = unavailable.get("influence_receipt", {})
	var unavailable_contributions: Array = unavailable.get("ordered_contributions", [])
	var exact_zero_count := 0
	for contribution_value in unavailable_contributions:
		var contribution: Dictionary = contribution_value
		if (
			float(contribution.get("applied_canonical_velocity_delta_rad_s", NAN)) == 0.0
			and float(contribution.get("host_target_velocity_delta_rad_s", NAN)) == 0.0
			and bool(contribution.get("fallback_zeroed", false))
		):
			exact_zero_count += 1
	var available_nonzero_count := 0
	for contribution_value in available.get("ordered_contributions", []):
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
			available_nonzero_count += 1
	var exact := (
		bool(available.get("ok", false))
		and available_nonzero_count == 8
		and bool(unavailable.get("ok", false))
		and String(unavailable.get("support_mode", "")) == "unavailable"
		and bool(unavailable.get("unavailable", false))
		and not bool(unavailable.get("upstream_infeasible", true))
		and int(unavailable.get("influence_output_count", -1)) == 8
		and int(unavailable.get("fallback_zero_output_count", -1)) == 8
		and exact_zero_count == 8
		and String(unavailable_receipt.get("availability", "")) == "observation_unavailable"
		and bool(unavailable_receipt.get("fallback_applied", false))
		and bool(
			(
				unavailable_receipt
				. get(
					"fallback_bypasses_slew_to_reach_zero",
					false,
				)
			)
		)
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "P5M3_R1_BRIDGE_CONFORMANCE_MISMATCH",
		"available_nonzero_output_count": available_nonzero_count,
		"unavailable_exact_zero_output_count": exact_zero_count,
		"unavailable_influence_output_count": int(unavailable.get("influence_output_count", -1)),
		"unavailable_fallback_zero_output_count":
		int(unavailable.get("fallback_zero_output_count", -1)),
		"unavailable_receipt": unavailable_receipt.duplicate(true),
		"world_build_count": 0,
		"adapter_actuation_applied": false,
		"physics_state_modified": false,
	}


static func _vector_norm_squared(value: Dictionary) -> float:
	return (
		float(value.get("x", NAN)) * float(value.get("x", NAN))
		+ float(value.get("y", NAN)) * float(value.get("y", NAN))
		+ float(value.get("z", NAN)) * float(value.get("z", NAN))
	)


static func _vector_dot(first: Dictionary, second: Dictionary) -> float:
	return (
		float(first.get("x", NAN)) * float(second.get("x", NAN))
		+ float(first.get("y", NAN)) * float(second.get("y", NAN))
		+ float(first.get("z", NAN)) * float(second.get("z", NAN))
	)


func _build_matrix() -> Array:
	var matrix: Array = []
	for material_value in PRIMARY_CELLS:
		var material: Dictionary = material_value
		for seed_value in CAMPAIGN_SEEDS:
			var seed := int(seed_value)
			matrix.append(_cell_spec("primary", "treatment", material, seed))
			if seed == 16001:
				matrix.append(_cell_spec("primary", "control", material, seed))
	for material_value in DIAGNOSTIC_CELLS:
		var material: Dictionary = material_value
		for seed_value in CAMPAIGN_SEEDS:
			matrix.append(_cell_spec("diagnostic", "treatment", material, int(seed_value)))
	matrix.append(_cell_spec("negative", "treatment", ZERO_CELL, 16001))
	return matrix


static func _cell_spec(
	cohort: String,
	mode: String,
	material: Dictionary,
	seed: int,
) -> Dictionary:
	return {
		"cell_id": "%s_mu%s_s%d_%s" % [cohort, String(material["mu_token"]), seed, mode],
		"cohort": cohort,
		"mode": mode,
		"campaign_seed": seed,
		"authored_friction": float(material["authored_friction"]),
		"profile_id": String(material["profile_id"]),
	}


func _matrix_cardinality_exact(matrix: Array) -> bool:
	var primary_treatment_count := 0
	var control_count := 0
	var diagnostic_count := 0
	var negative_count := 0
	for cell_value in matrix:
		var cell: Dictionary = cell_value
		if String(cell["cohort"]) == "primary" and String(cell["mode"]) == "treatment":
			primary_treatment_count += 1
		elif String(cell["mode"]) == "control":
			control_count += 1
		elif String(cell["cohort"]) == "diagnostic":
			diagnostic_count += 1
		elif String(cell["cohort"]) == "negative":
			negative_count += 1
	return (
		primary_treatment_count == 12
		and control_count == 4
		and diagnostic_count == 6
		and negative_count == 1
	)


func _run_cell(
	gait_clock_options: Dictionary,
	cell: Dictionary,
	perturbation: Dictionary,
	fixture_spec: Dictionary,
) -> Dictionary:
	var profile_id := String(cell["profile_id"])
	var shadow_options := {}
	var authority_options := {}
	if String(cell["mode"]) == "control":
		shadow_options = {
			"enabled": true,
			"descriptor": DESCRIPTOR,
			"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"stability_policy_id": FEEDBACK_POLICY_ID,
			"material_profile_id": profile_id,
		}
		if _bw2_mode:
			shadow_options["controller_policy_id"] = _bw2_policy_id
	else:
		authority_options = {
			"enabled": true,
			"descriptor": DESCRIPTOR,
			"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
			"authority_scope": "stability_contribution_overlay",
			"stability_policy_id": FEEDBACK_POLICY_ID,
			"material_profile_id": profile_id,
		}
		if _bw2_mode:
			authority_options["controller_policy_id"] = _bw2_policy_id
	return await (
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
			fixture_spec,
			PATH_STEERING_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			MOTOR_VELOCITY_OPTIONS,
			{},
			gait_clock_options,
			SOLVER_POLICY_OPTIONS,
			{},
			shadow_options,
			authority_options,
		)
	)


func _analyze_cell(
	cell: Dictionary,
	summary: Dictionary,
	perturbation: Dictionary,
	input: Dictionary,
	balanced_wave_mode: bool = false,
) -> Dictionary:
	var mode := String(cell["mode"])
	var sdk_summary: Dictionary = (
		summary.get("sdk_shadow_summary", {})
		if mode == "control"
		else summary.get("sdk_authority_summary", {})
	)
	var contribution: Dictionary = (
		sdk_summary
		. get(
			"stability_contribution_shadow_summary",
			{},
		)
	)
	var overlay: Dictionary = sdk_summary.get("stability_overlay_summary", {})
	var mapping: Dictionary = sdk_summary.get("joint_mapping_shadow_summary", {})
	var common_exact := _common_execution_integrity(
		cell,
		summary,
		sdk_summary,
		contribution,
		overlay,
		mapping,
		perturbation,
		input,
		balanced_wave_mode,
	)
	var treatment_gate := (
		common_exact
		and mode == "treatment"
		and _positive_treatment_behavior(
			summary,
			sdk_summary,
			contribution,
			overlay,
			balanced_wave_mode,
		)
	)
	var control_gate := (
		common_exact
		and mode == "control"
		and _control_behavior(
			summary,
			sdk_summary,
			contribution,
			overlay,
			balanced_wave_mode,
		)
	)
	var diagnostic_execution := (
		common_exact
		and String(cell["cohort"]) == "diagnostic"
		and mode == "treatment"
		and _treatment_actuation_integrity(
			summary,
			sdk_summary,
			contribution,
			overlay,
			balanced_wave_mode,
		)
	)
	var zero_gate := (
		common_exact
		and String(cell["cohort"]) == "negative"
		and _zero_friction_behavior(
			summary,
			sdk_summary,
			contribution,
			overlay,
			input,
			balanced_wave_mode,
		)
	)
	var role_gate := false
	match String(cell["cohort"]):
		"primary":
			role_gate = control_gate if mode == "control" else treatment_gate
		"diagnostic":
			role_gate = diagnostic_execution
		"negative":
			role_gate = zero_gate
	if balanced_wave_mode:
		if mode == "control":
			role_gate = control_gate
		elif String(cell["cohort"]) == "negative":
			role_gate = zero_gate
		else:
			role_gate = (
				common_exact
				and _treatment_actuation_integrity(
					summary,
					sdk_summary,
					contribution,
					overlay,
					true,
				)
				and _balanced_wave_treatment_mechanism_integrity(
					contribution,
					overlay,
				)
				and _outcome_is_complete(summary)
			)
	var initial_position: Vector3 = (
		summary
		. get(
			"initial_torso_position_world_m",
			Vector3(INF, INF, INF),
		)
	)
	var final_position: Vector3 = (
		summary
		. get(
			"final_torso_position_world_m",
			Vector3(INF, INF, INF),
		)
	)
	var final_displacement: Vector3 = (
		summary
		. get(
			"final_torso_displacement_world_m",
			Vector3(INF, INF, INF),
		)
	)
	return {
		"cell_id": String(cell["cell_id"]),
		"cohort": String(cell["cohort"]),
		"mode": mode,
		"campaign_seed": int(cell["campaign_seed"]),
		"authored_friction": float(cell["authored_friction"]),
		"profile_id": String(cell["profile_id"]),
		"profile_sha256": String(input["profile_sha256"]),
		"fixture_spec_sha256": String(input["fixture_spec_sha256"]),
		"campaign_execution_gate_passed": role_gate,
		"common_execution_integrity": common_exact,
		"treatment_gate_passed": treatment_gate,
		"control_gate_passed": control_gate,
		"diagnostic_execution_complete": diagnostic_execution,
		"zero_friction_safety_gate_passed": zero_gate,
		"walking_observed": bool(summary.get("physical_wave_gait_walking_observed", false)),
		"walking_claim_authorized":
		String(cell["cohort"]) in ["primary", "diagnostic"] and treatment_gate,
		"world_build_count": int(summary.get("world_build_count", -1)),
		"step_count": int(sdk_summary.get("step_count", -1)),
		"native_actuation_application_count":
		int(sdk_summary.get("native_actuation_application_count", -1)),
		"controller_policy_id": String(sdk_summary.get("controller_policy_id", "")),
		"controller_runtime_version": String(sdk_summary.get("controller_runtime_version", "")),
		"controller_profile_sha256": String(sdk_summary.get("controller_profile_sha256", "")),
		"validated_balanced_wave_command_count":
		int(sdk_summary.get("validated_balanced_wave_command_count", -1)),
		"balanced_wave_step_receipt_count":
		int(sdk_summary.get("balanced_wave_step_receipt_count", -1)),
		"steering_feedback_update_count":
		int(sdk_summary.get("steering_feedback_update_count", -1)),
		"steering_filter_application_count":
		int(sdk_summary.get("steering_filter_application_count", -1)),
		"steering_saturation_count":
		int(sdk_summary.get("steering_saturation_count", -1)),
		"steering_slew_limited_count":
		int(sdk_summary.get("steering_slew_limited_count", -1)),
		"maximum_absolute_requested_steering_fraction":
		float(sdk_summary.get("maximum_absolute_requested_steering_fraction", INF)),
		"maximum_absolute_filtered_steering_fraction":
		float(sdk_summary.get("maximum_absolute_filtered_steering_fraction", INF)),
		"maximum_absolute_steering_delta_per_step":
		float(sdk_summary.get("maximum_absolute_steering_delta_per_step", INF)),
		"cumulative_absolute_cross_track_error_m_s":
		float(sdk_summary.get("cumulative_absolute_cross_track_error_m_s", INF)),
		"minimum_cross_track_error_m":
		float(sdk_summary.get("minimum_cross_track_error_m", INF)),
		"maximum_cross_track_error_m":
		float(sdk_summary.get("maximum_cross_track_error_m", INF)),
		"portable_controller_base_application_count":
		int(overlay.get("portable_controller_base_application_count", -1)),
		"base_command_source": String(overlay.get("base_command_source", "")),
		"candidate35_compared_actuator_command_count":
		int(sdk_summary.get("compared_actuator_command_count", -1)),
		"candidate35_safe_no_actuation_count": int(sdk_summary.get("safe_no_actuation_count", -1)),
		"candidate35_adapter_ok": bool(sdk_summary.get("ok", false)),
		"candidate35_adapter_failure_codes":
		(sdk_summary.get("failure_codes", []) as Array).duplicate(),
		"legacy_sdk_overlay_base_application_count":
		int(summary.get("legacy_sdk_overlay_base_application_count", -1)),
		"candidate35_mismatch_count": int(sdk_summary.get("mismatch_count", -1)),
		"candidate35_maximum_absolute_phase_error_steps":
		int(sdk_summary.get("maximum_absolute_phase_error_steps", -1)),
		"candidate35_maximum_absolute_speed_limit_error_rad_s":
		float(sdk_summary.get("maximum_absolute_speed_limit_error_rad_s", INF)),
		"initial_perturbation": _perturbation_receipt(perturbation),
		"initial_torso_position_world_m": _vector_dictionary(initial_position),
		"initial_torso_orientation_xyzw":
		(summary.get("initial_torso_orientation_xyzw", {}) as Dictionary).duplicate(true),
		"final_torso_position_world_m": _vector_dictionary(final_position),
		"final_torso_displacement_world_m": _vector_dictionary(final_displacement),
		"evidence_task_frame_forward_displacement_m":
		float(summary.get("evidence_task_frame_forward_displacement_m", NAN)),
		"final_task_frame_forward_displacement_m":
		float(summary.get("final_task_frame_forward_displacement_m", NAN)),
		"final_task_frame_lateral_displacement_m":
		float(summary.get("final_task_frame_lateral_displacement_m", NAN)),
		"task_frame_forward_axis_world_unit":
		_vector_dictionary(summary.get("task_frame_forward_axis_world_unit", Vector3.INF)),
		"task_frame_lateral_axis_world_unit":
		_vector_dictionary(summary.get("task_frame_lateral_axis_world_unit", Vector3.INF)),
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", INF)),
		"maximum_anchor_error_m": float(summary.get("maximum_anchor_error_m", INF)),
		"maximum_hinge_axis_error_rad": float(summary.get("maximum_hinge_axis_error_rad", INF)),
		"walking_gate_receipts":
		(summary.get("walking_gate_receipts", {}) as Dictionary).duplicate(true),
		"stability_shadow":
		(sdk_summary.get("stability_shadow_summary", {}) as Dictionary).duplicate(true),
		"joint_mapping_shadow": mapping.duplicate(true),
		"stability_contribution_shadow": contribution.duplicate(true),
		"stability_overlay": overlay.duplicate(true),
		"direct_body_write_count": _direct_body_write_count(summary),
		"sdk_failure_code":
		(
			String(summary.get("sdk_shadow_start_result", {}).get("failure_code", ""))
			if mode == "control"
			else String(summary.get("sdk_authority_failure_code", ""))
		),
		"continuous_friction_coverage": false,
		"cross_engine_equivalence": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_fault_robustness": false,
		"fresh_morphology_validation": false,
		"completed_sdk": false,
	}


func _common_execution_integrity(
	cell: Dictionary,
	summary: Dictionary,
	sdk_summary: Dictionary,
	contribution: Dictionary,
	overlay: Dictionary,
	mapping: Dictionary,
	perturbation: Dictionary,
	input: Dictionary,
	balanced_wave_mode: bool = false,
) -> bool:
	var stability_shadow: Dictionary = sdk_summary.get("stability_shadow_summary", {})
	var start_result: Dictionary = (
		summary.get("sdk_shadow_start_result", {})
		if String(cell["mode"]) == "control"
		else summary.get("sdk_authority_start_result", {})
	)
	return (
		int(summary.get("world_build_count", -1)) == 1
		and bool(start_result.get("ok", false))
		and int(sdk_summary.get("step_count", -1)) == EXPECTED_STEP_COUNT
		and _candidate_execution_integrity(cell, sdk_summary, balanced_wave_mode)
		and bool(summary.get("sdk_p5i3c_fixed_exposure_enabled", false))
		and int(summary.get("sdk_p5i3c_fixed_exposure_step_count", -1)) == EXPECTED_STEP_COUNT
		and (
			String(sdk_summary.get("stability_policy_id", ""))
			== _expected_stability_policy_id()
		)
		and int(sdk_summary.get("maximum_absolute_phase_error_steps", -1)) == 0
		and float(sdk_summary.get("maximum_absolute_speed_limit_error_rad_s", INF)) == 0.0
		and summary.get("initial_perturbation", {}) == perturbation
		and summary.get("realized_solver_policy_options", {}) == SOLVER_POLICY_OPTIONS
		and _profile_binding_exact(summary, sdk_summary, input)
		and bool(stability_shadow.get("ok", false))
		and int(stability_shadow.get("attempt_count", -1)) == EXPECTED_STEP_COUNT
		and _stability_observation_partition_exact(stability_shadow)
		and int(stability_shadow.get("mismatch_count", -1)) == 0
		and int(mapping.get("attempt_count", -1)) == EXPECTED_STEP_COUNT
		and (
			(
				int(mapping.get("available_count", -1))
				+ int(mapping.get("infeasible_count", -1))
				+ int(mapping.get("unavailable_count", -1))
			)
			== EXPECTED_STEP_COUNT
		)
		and int(mapping.get("mismatch_count", -1)) == 0
		and int(contribution.get("attempt_count", -1)) == EXPECTED_STEP_COUNT
		and (
			(
				int(contribution.get("available_count", -1))
				+ int(contribution.get("upstream_infeasible_count", -1))
				+ int(contribution.get("unavailable_count", -1))
			)
			== EXPECTED_STEP_COUNT
		)
		and int(contribution.get("untyped_count", -1)) == 0
		and int(contribution.get("influence_output_count", -1)) == EXPECTED_MOTOR_WRITE_COUNT
		and int(contribution.get("mismatch_count", -1)) == 0
		and int(contribution.get("profile_conversion_failure_count", -1)) == 0
		and int(contribution.get("limiter_mismatch_count", -1)) == 0
		and int(contribution.get("inactive_zero_mismatch_count", -1)) == 0
		and (contribution.get("failure_codes", []) as Array).is_empty()
		and (
			int(contribution.get("fallback_zero_output_count", -1))
			== (
				(
					int(contribution.get("upstream_infeasible_count", -2))
					+ int(contribution.get("unavailable_count", -2))
				)
				* 8
			)
		)
		and (
			float(contribution.get("maximum_limiter_reconstruction_error", INF))
			<= MAXIMUM_LIMITER_RECONSTRUCTION_ERROR
		)
		and (
			float(
				(
					contribution
					. get(
						"maximum_velocity_delta_slew_per_step_rad_s",
						INF,
					)
				)
			)
			== MAXIMUM_OVERLAY_SLEW_RAD_S_PER_STEP
		)
		and _direct_body_write_count(summary) == 0
		and int(overlay.get("direct_body_write_count", -1)) == 0
		and _finite_physical_receipts(summary)
	)


func _candidate_execution_integrity(
	cell: Dictionary,
	sdk_summary: Dictionary,
	balanced_wave_mode: bool = false,
) -> bool:
	if balanced_wave_mode:
		return (
			String(sdk_summary.get("controller_policy_id", "")) == _bw2_policy_id
			and (
				String(sdk_summary.get("controller_runtime_version", ""))
				== "sporespore_balanced_wave_runtime_v1"
			)
			and bool(sdk_summary.get("balanced_wave_shadow_valid", false))
			and not bool(sdk_summary.get("candidate35_shadow_parity_ok", true))
			and int(sdk_summary.get("safe_no_actuation_count", -1)) == 0
			and int(sdk_summary.get("compared_actuator_command_count", -1)) == 0
			and (
				int(sdk_summary.get("validated_balanced_wave_command_count", -1))
				== EXPECTED_MOTOR_WRITE_COUNT
			)
			and int(sdk_summary.get("balanced_wave_step_receipt_count", -1)) == EXPECTED_STEP_COUNT
			and int(sdk_summary.get("mismatch_count", -1)) == 0
			and String(sdk_summary.get("failure_code", "")).is_empty()
			and (sdk_summary.get("failure_codes", []) as Array).is_empty()
		)
	if (
		int(sdk_summary.get("safe_no_actuation_count", -1)) != 0
		or int(sdk_summary.get("compared_actuator_command_count", -1)) != EXPECTED_MOTOR_WRITE_COUNT
		or not String(sdk_summary.get("failure_code", "")).is_empty()
	):
		return false
	var treatment := String(cell.get("mode", "")) == "treatment"
	for failure_code_value in sdk_summary.get("failure_codes", []):
		var failure_code := String(failure_code_value)
		if treatment and failure_code.begins_with("ADAPTER_DYNAMIC_PARITY_MISMATCH:"):
			continue
		return false
	if not treatment:
		return (
			bool(sdk_summary.get("ok", false)) and int(sdk_summary.get("mismatch_count", -1)) == 0
		)
	return true


static func _profile_binding_exact(
	summary: Dictionary,
	sdk_summary: Dictionary,
	input: Dictionary,
) -> bool:
	var expected_profile: Dictionary = input["profile"]
	var expected_sha := String(input["profile_sha256"])
	var selected_profile: Dictionary = summary.get("sdk_material_profile", {})
	var manifest: Dictionary = sdk_summary.get("adapter_manifest", {})
	var stability_v2: Dictionary = manifest.get("stability_v2", {})
	var material_characterization: Dictionary = (
		stability_v2
		. get(
			"material_characterization",
			{},
		)
	)
	var manifest_profile: Dictionary = material_characterization.get("profile", {})
	var fixture_spec: Dictionary = summary.get("fixture_spec", {})
	return (
		selected_profile == expected_profile
		and String(summary.get("sdk_material_profile_sha256", "")) == expected_sha
		and manifest_profile == expected_profile
		and String(material_characterization.get("profile_sha256", "")) == expected_sha
		and (
			String(material_characterization.get("source_commit", ""))
			== String(expected_profile["characterization_source_commit"])
		)
		and (
			String(material_characterization.get("report_sha256", ""))
			== String(expected_profile["characterization_report_sha256"])
		)
		and (
			absf(
				(
					float(material_characterization.get("controller_friction_coefficient", NAN))
					- float(expected_profile["characterized_friction_coefficient"])
				)
			)
			<= 1.0e-12
		)
		and fixture_spec.get("contact_material", {}) == expected_profile["body_material"]
		and String(summary.get("fixture_spec_sha256", "")) == String(input["fixture_spec_sha256"])
	)


func _positive_treatment_behavior(
	summary: Dictionary,
	sdk_summary: Dictionary,
	contribution: Dictionary,
	overlay: Dictionary,
	balanced_wave_mode: bool = false,
) -> bool:
	return (
		_treatment_actuation_integrity(
			summary,
			sdk_summary,
			contribution,
			overlay,
			balanced_wave_mode,
		)
		and bool(summary.get("physical_wave_gait_walking_observed", false))
		and int(contribution.get("feedback_nonzero_attempt_count", 0)) > 0
		and int(contribution.get("nonzero_active_command_count", 0)) > 0
		and int(overlay.get("nonzero_effective_application_count", 0)) > 0
	)


func _treatment_actuation_integrity(
	summary: Dictionary,
	sdk_summary: Dictionary,
	contribution: Dictionary,
	overlay: Dictionary,
	balanced_wave_mode: bool = false,
) -> bool:
	return (
		String(sdk_summary.get("authority_scope", "")) == "stability_contribution_overlay"
		and bool(sdk_summary.get("stability_overlay_runtime_ok", false))
		and (
			int(sdk_summary.get("native_actuation_application_count", -1))
			== EXPECTED_MOTOR_WRITE_COUNT
		)
		and (
			int(summary.get("legacy_sdk_overlay_base_application_count", -1))
			== EXPECTED_MOTOR_WRITE_COUNT
		)
		and (
			(
				balanced_wave_mode
				and (
					String(overlay.get("base_command_source", ""))
					== "portable_controller_ordered_commands"
				)
				and (
					int(
						(
							overlay
							. get(
								"portable_controller_base_application_count",
								-1,
							)
						)
					)
					== EXPECTED_MOTOR_WRITE_COUNT
				)
			)
			or (
				not balanced_wave_mode
				and String(overlay.get("base_command_source", "")) == "legacy_host_command_context"
				and (
					int(
						(
							overlay
							. get(
								"portable_controller_base_application_count",
								-1,
							)
						)
					)
					== 0
				)
			)
		)
		and bool(overlay.get("ok", false))
		and String(overlay.get("policy_id", "")) == _expected_stability_policy_id()
		and String(overlay.get("runtime_id", "")) == OVERLAY_RUNTIME_ID
		and String(overlay.get("memory_id", "")) == OVERLAY_MEMORY_ID
		and int(overlay.get("application_step_count", -1)) == EXPECTED_STEP_COUNT
		and int(overlay.get("motor_write_count", -1)) == EXPECTED_MOTOR_WRITE_COUNT
		and int(overlay.get("combined_speed_limit_violation_count", -1)) == 0
		and int(overlay.get("failure_count", -1)) == 0
		and (
			float(overlay.get("maximum_absolute_requested_delta_rad_s", INF))
			<= MAXIMUM_OVERLAY_DELTA_RAD_S
		)
		and (
			float(overlay.get("maximum_absolute_effective_delta_rad_s", INF))
			<= MAXIMUM_OVERLAY_DELTA_RAD_S
		)
		and float(overlay.get("maximum_readback_error_rad_s", INF)) <= MAXIMUM_READBACK_ERROR_RAD_S
		and (
			float(
				(
					overlay
					. get(
						"maximum_host_command_quantization_error_rad_s",
						INF,
					)
				)
			)
			<= MAXIMUM_HOST_COMMAND_QUANTIZATION_ERROR_RAD_S
		)
		and (
			float(contribution.get("maximum_absolute_applied_velocity_rad_s", INF))
			<= MAXIMUM_OVERLAY_DELTA_RAD_S
		)
		and String(summary.get("sdk_authority_failure_code", "")).is_empty()
	)


func _expected_stability_policy_id() -> String:
	return FEEDBACK_POLICY_ID


func _stability_observation_partition_exact(stability_shadow: Dictionary) -> bool:
	return (
		int(stability_shadow.get("available_count", -1))
		== EXPECTED_STEP_COUNT
	)


func _balanced_wave_treatment_mechanism_integrity(
	contribution: Dictionary,
	overlay: Dictionary,
) -> bool:
	return (
		int(contribution.get("feedback_nonzero_attempt_count", 0)) > 0
		and int(contribution.get("nonzero_active_command_count", 0)) > 0
		and int(overlay.get("nonzero_effective_application_count", 0)) > 0
	)


## Exercise the exact post-physics analysis/integrity path without opening a
## world. Subclasses must set their declared controller/policy hooks first and
## supply a real no-world policy-semantic witness. A prospective campaign is
## unrunnable if this synthetic perfect result does not pass. Error, mismatch,
## failure, and violation counts are perfect zeros; mechanism activity counts
## are projected from the real planner/mapper/limiter receipts and may be
## nonzero when the declared policy requires influence.
func _synthetic_execution_integrity_preflight(
	profile: Dictionary,
	profile_sha256: String,
	fixture_spec_sha256: String,
	perturbation: Dictionary,
	expect_nonzero_stability_activity: bool,
	synthetic_unavailable_step_count: int = 0,
	policy_semantic_witness: Dictionary = {},
) -> Dictionary:
	if (
		synthetic_unavailable_step_count < 0
		or synthetic_unavailable_step_count > EXPECTED_STEP_COUNT
	):
		return {
			"schema_version":
			"sporespore_synthetic_execution_integrity_preflight_v2",
			"ok": false,
			"failure_code":
			"SYNTHETIC_UNAVAILABLE_STEP_COUNT_INVALID",
			"actual_world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	if policy_semantic_witness.is_empty():
		return {
			"schema_version":
			"sporespore_synthetic_execution_integrity_preflight_v2",
			"ok": false,
			"failure_code": "POLICY_SEMANTIC_WITNESS_REQUIRED",
			"actual_world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var semantic_witness_exact := (
		String(policy_semantic_witness.get("schema_version", ""))
		== "sporespore_policy_semantic_preflight_witness_v1"
		and bool(policy_semantic_witness.get("ok", false))
		and (
			String(
				policy_semantic_witness.get(
					"declared_stability_policy_id",
					"",
				)
			)
			== _expected_stability_policy_id()
		)
		and (
			String(
				policy_semantic_witness.get(
					"declared_controller_policy_id",
					"",
				)
			)
			== _bw2_policy_id
		)
		and bool(policy_semantic_witness.get("real_portable_plan_called", false))
		and bool(policy_semantic_witness.get("real_endpoint_force_map_called", false))
		and bool(policy_semantic_witness.get("real_bounded_influence_called", false))
		and int(policy_semantic_witness.get("semantic_sample_count", -1)) >= 2
		and int(policy_semantic_witness.get("actual_world_build_count", -1)) == 0
		and int(policy_semantic_witness.get("scene_tree_insertion_count", -1)) == 0
		and not bool(policy_semantic_witness.get("physics_state_modified", true))
		and int(policy_semantic_witness.get("available_mismatch_count", -1)) == 0
		and int(policy_semantic_witness.get("available_limiter_mismatch_count", -1)) == 0
		and int(policy_semantic_witness.get("unavailable_mismatch_count", -1)) == 0
		and bool(policy_semantic_witness.get("unavailable_fail_zero_required", false))
		and (
			int(
				policy_semantic_witness.get(
					"unavailable_safe_zero_contribution_count",
					-1,
				)
			)
			== 8
		)
	)
	if not semantic_witness_exact:
		return {
			"schema_version":
			"sporespore_synthetic_execution_integrity_preflight_v2",
			"ok": false,
			"failure_code": "POLICY_SEMANTIC_WITNESS_INVALID",
			"actual_world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var synthetic_available_step_count := (
		EXPECTED_STEP_COUNT - synthetic_unavailable_step_count
	)
	var feedback_activity_count := int(
		policy_semantic_witness.get(
			"available_feedback_request_nonzero",
			false,
		)
	)
	var active_command_count := int(
		policy_semantic_witness.get(
			"available_nonzero_active_command_count",
			0,
		)
	)
	var effective_application_count := int(
		policy_semantic_witness.get(
			"available_nonzero_applied_contribution_count",
			0,
		)
	)
	var cell := {
		"cell_id": "synthetic_integrity_preflight",
		"cohort": "baseline",
		"mode": "treatment",
		"campaign_seed": int(perturbation.get("campaign_seed", 0)),
		"authored_friction":
		float(profile.get("authored_friction", 0.0)),
		"profile_id": String(profile.get("profile_id", "")),
	}
	var material_characterization := {
		"profile": profile.duplicate(true),
		"profile_sha256": profile_sha256,
		"source_commit":
		String(profile.get("characterization_source_commit", "")),
		"report_sha256":
		String(profile.get("characterization_report_sha256", "")),
		"controller_friction_coefficient":
		float(profile.get("characterized_friction_coefficient", NAN)),
	}
	var stability_shadow := {
		"ok": true,
		"attempt_count": EXPECTED_STEP_COUNT,
		"available_count": synthetic_available_step_count,
		"unavailable_count": synthetic_unavailable_step_count,
		"mismatch_count": 0,
	}
	var mapping := {
		"attempt_count": EXPECTED_STEP_COUNT,
		"available_count": synthetic_available_step_count,
		"infeasible_count": 0,
		"unavailable_count": synthetic_unavailable_step_count,
		"mismatch_count": 0,
	}
	var contribution := {
		"attempt_count": EXPECTED_STEP_COUNT,
		"available_count": synthetic_available_step_count,
		"upstream_infeasible_count": 0,
		"unavailable_count": synthetic_unavailable_step_count,
		"untyped_count": 0,
		"influence_output_count": EXPECTED_MOTOR_WRITE_COUNT,
		"mismatch_count": 0,
		"profile_conversion_failure_count": 0,
		"limiter_mismatch_count": 0,
		"inactive_zero_mismatch_count": 0,
		"failure_codes": [],
		"fallback_zero_output_count":
		synthetic_unavailable_step_count * 8,
		"maximum_limiter_reconstruction_error": 0.0,
		"maximum_velocity_delta_slew_per_step_rad_s":
		MAXIMUM_OVERLAY_SLEW_RAD_S_PER_STEP,
		"maximum_absolute_applied_velocity_rad_s":
		float(
			policy_semantic_witness.get(
				"available_maximum_absolute_applied_velocity_rad_s",
				INF,
			)
		),
		"feedback_nonzero_attempt_count": feedback_activity_count,
		"nonzero_active_command_count": active_command_count,
	}
	var overlay := {
		"ok": true,
		"policy_id": _expected_stability_policy_id(),
		"runtime_id": OVERLAY_RUNTIME_ID,
		"memory_id": OVERLAY_MEMORY_ID,
		"application_step_count": EXPECTED_STEP_COUNT,
		"motor_write_count": EXPECTED_MOTOR_WRITE_COUNT,
		"combined_speed_limit_violation_count": 0,
		"failure_count": 0,
		"maximum_absolute_requested_delta_rad_s": 0.0,
		"maximum_absolute_effective_delta_rad_s": 0.0,
		"maximum_readback_error_rad_s": 0.0,
		"maximum_host_command_quantization_error_rad_s": 0.0,
		"direct_body_write_count": 0,
		"base_command_source": "portable_controller_ordered_commands",
		"portable_controller_base_application_count":
		EXPECTED_MOTOR_WRITE_COUNT,
		"nonzero_effective_application_count":
		effective_application_count,
	}
	var sdk_summary := {
		"step_count": EXPECTED_STEP_COUNT,
		"controller_policy_id": _bw2_policy_id,
		"controller_runtime_version":
		"sporespore_balanced_wave_runtime_v1",
		"balanced_wave_shadow_valid": true,
		"candidate35_shadow_parity_ok": false,
		"safe_no_actuation_count": 0,
		"compared_actuator_command_count": 0,
		"validated_balanced_wave_command_count":
		EXPECTED_MOTOR_WRITE_COUNT,
		"balanced_wave_step_receipt_count": EXPECTED_STEP_COUNT,
		"mismatch_count": 0,
		"failure_code": "",
		"failure_codes": [],
		"authority_scope": "stability_contribution_overlay",
		"stability_policy_id": _expected_stability_policy_id(),
		"maximum_absolute_phase_error_steps": 0,
		"maximum_absolute_speed_limit_error_rad_s": 0.0,
		"native_actuation_application_count":
		EXPECTED_MOTOR_WRITE_COUNT,
		"stability_overlay_runtime_ok": true,
		"adapter_manifest":
		{
			"stability_v2":
			{"material_characterization": material_characterization},
		},
		"stability_shadow_summary": stability_shadow,
		"joint_mapping_shadow_summary": mapping,
		"stability_contribution_shadow_summary": contribution,
		"stability_overlay_summary": overlay,
	}
	var summary := {
		"world_build_count": 1,
		"sdk_authority_start_result": {"ok": true, "failure_code": ""},
		"sdk_p5i3c_fixed_exposure_enabled": true,
		"sdk_p5i3c_fixed_exposure_step_count": EXPECTED_STEP_COUNT,
		"initial_perturbation": perturbation.duplicate(true),
		"realized_solver_policy_options": SOLVER_POLICY_OPTIONS,
		"sdk_material_profile": profile.duplicate(true),
		"sdk_material_profile_sha256": profile_sha256,
		"fixture_spec":
		{"contact_material": profile.get("body_material", {})},
		"fixture_spec_sha256": fixture_spec_sha256,
		"legacy_sdk_overlay_base_application_count":
		EXPECTED_MOTOR_WRITE_COUNT,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"maximum_tilt_rad": 0.0,
		"maximum_anchor_error_m": 0.0,
		"maximum_hinge_axis_error_rad": 0.0,
		"walking_gate_receipts": {"synthetic_perfect": true},
		"physical_wave_gait_walking_observed": true,
		"failure_code": "",
		"sdk_authority_failure_code": "",
		"initial_torso_position_world_m": Vector3.ZERO,
		"initial_torso_orientation_xyzw":
		{"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"final_torso_position_world_m": Vector3.ZERO,
		"final_torso_displacement_world_m": Vector3.ZERO,
		"evidence_task_frame_forward_displacement_m": 0.0,
		"final_task_frame_forward_displacement_m": 0.0,
		"final_task_frame_lateral_displacement_m": 0.0,
		"task_frame_forward_axis_world_unit": Vector3.FORWARD,
		"task_frame_lateral_axis_world_unit": Vector3.RIGHT,
		"sdk_authority_summary": sdk_summary,
	}
	var input := {
		"profile": profile.duplicate(true),
		"profile_sha256": profile_sha256,
		"fixture_spec_sha256": fixture_spec_sha256,
	}
	var analyzed := _analyze_cell(
		cell,
		summary,
		perturbation,
		input,
		true,
	)
	var mechanism_matches_declaration := (
		(
			feedback_activity_count > 0
			and active_command_count > 0
			and effective_application_count > 0
		)
		if expect_nonzero_stability_activity
		else (
			feedback_activity_count == 0
			and active_command_count == 0
			and effective_application_count == 0
		)
	)
	var full_gate_ok := (
		bool(analyzed.get("common_execution_integrity", false))
		and bool(
			analyzed.get(
				"campaign_execution_gate_passed",
				false,
			)
		)
		and mechanism_matches_declaration
	)
	return {
		"schema_version":
		"sporespore_synthetic_execution_integrity_preflight_v2",
		"ok": full_gate_ok,
		"failure_code":
		"" if full_gate_ok else "DECLARED_POLICY_MECHANISM_UNSATISFIABLE",
		"declared_stability_policy_id":
		_expected_stability_policy_id(),
		"declared_controller_policy_id": _bw2_policy_id,
		"expect_nonzero_stability_activity":
		expect_nonzero_stability_activity,
		"synthetic_available_step_count":
		synthetic_available_step_count,
		"synthetic_unavailable_step_count":
		synthetic_unavailable_step_count,
		"common_execution_integrity":
		bool(analyzed.get("common_execution_integrity", false)),
		"campaign_execution_gate_passed":
		bool(analyzed.get("campaign_execution_gate_passed", false)),
		"mechanism_matches_declaration": mechanism_matches_declaration,
		"policy_semantic_witness": policy_semantic_witness.duplicate(true),
		"mechanism_activity_counts_derived_from_real_policy_receipts": true,
		"synthetic_world_build_count_field": 1,
		"actual_world_build_count": 0,
		"locomotion_outcome_exposed": false,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _control_behavior(
	summary: Dictionary,
	sdk_summary: Dictionary,
	contribution: Dictionary,
	overlay: Dictionary,
	balanced_wave_mode: bool = false,
) -> bool:
	return (
		String(sdk_summary.get("authority_scope", "")) == "shadow"
		and (
			(
				balanced_wave_mode
				and bool(sdk_summary.get("balanced_wave_shadow_valid", false))
				and not bool(sdk_summary.get("candidate35_shadow_parity_ok", true))
			)
			or (
				not balanced_wave_mode
				and bool(sdk_summary.get("candidate35_shadow_parity_ok", false))
			)
		)
		and int(sdk_summary.get("native_actuation_application_count", -1)) == 0
		and int(summary.get("legacy_sdk_overlay_base_application_count", -1)) == 0
		and int(overlay.get("application_step_count", -1)) == 0
		and int(overlay.get("motor_write_count", -1)) == 0
		and int(overlay.get("failure_count", -1)) == 0
		and int(contribution.get("feedback_nonzero_attempt_count", 0)) > 0
		and (
			_outcome_is_complete(summary)
			if balanced_wave_mode
			else bool(summary.get("physical_wave_gait_walking_observed", false))
		)
		and (
			String(
				(
					(summary.get("sdk_shadow_start_result", {}) as Dictionary)
					. get(
						"failure_code",
						"",
					)
				)
			)
			. is_empty()
		)
	)


func _zero_friction_behavior(
	summary: Dictionary,
	sdk_summary: Dictionary,
	contribution: Dictionary,
	overlay: Dictionary,
	input: Dictionary,
	balanced_wave_mode: bool = false,
) -> bool:
	var profile: Dictionary = input["profile"]
	return (
		float(profile["authored_friction"]) == 0.0
		and float(profile["characterized_friction_coefficient"]) == 0.0
		and bool(profile["negative_control"])
		and _treatment_actuation_integrity(
			summary,
			sdk_summary,
			contribution,
			overlay,
			balanced_wave_mode,
		)
		and int(contribution.get("nonzero_active_command_count", -1)) == 0
		and float(contribution.get("maximum_absolute_applied_velocity_rad_s", INF)) == 0.0
		and int(overlay.get("nonzero_effective_application_count", -1)) == 0
		and float(overlay.get("maximum_absolute_effective_delta_rad_s", INF)) == 0.0
		and _outcome_is_complete(summary)
	)


static func _outcome_is_complete(summary: Dictionary) -> bool:
	return (
		summary.has("physical_wave_gait_walking_observed")
		and typeof(summary.get("physical_wave_gait_walking_observed")) == TYPE_BOOL
		and typeof(summary.get("failure_code", "")) == TYPE_STRING
	)


static func _walking_gate_failure_count(receipts_value: Variant) -> int:
	if typeof(receipts_value) != TYPE_DICTIONARY:
		return 1
	var receipts: Dictionary = receipts_value
	if receipts.is_empty():
		return 1
	var count := 0
	for gate_value in receipts.values():
		if typeof(gate_value) != TYPE_BOOL or not bool(gate_value):
			count += 1
	return count


static func _finite_physical_receipts(summary: Dictionary) -> bool:
	return (
		is_finite(float(summary.get("maximum_tilt_rad", NAN)))
		and is_finite(float(summary.get("maximum_anchor_error_m", NAN)))
		and is_finite(float(summary.get("maximum_hinge_axis_error_rad", NAN)))
		and typeof(summary.get("walking_gate_receipts", {})) == TYPE_DICTIONARY
		and not (summary.get("walking_gate_receipts", {}) as Dictionary).is_empty()
	)


static func _paired_receipts(
	matrix: Array,
	summary_by_cell_id: Dictionary,
) -> Array:
	var pairs: Array = []
	for material_value in PRIMARY_CELLS:
		var material: Dictionary = material_value
		var token := String(material["mu_token"])
		var treatment_id := "primary_mu%s_s16001_treatment" % token
		var control_id := "primary_mu%s_s16001_control" % token
		if not summary_by_cell_id.has(treatment_id) or not summary_by_cell_id.has(control_id):
			continue
		var treatment: Dictionary = summary_by_cell_id[treatment_id]
		var control: Dictionary = summary_by_cell_id[control_id]
		var initial_position_error_m := (
			(control["initial_torso_position_world_m"] as Vector3)
			. distance_to(treatment["initial_torso_position_world_m"] as Vector3)
		)
		var initial_orientation_error := _orientation_error(
			control.get("initial_torso_orientation_xyzw", {}),
			treatment.get("initial_torso_orientation_xyzw", {}),
		)
		var terminal_separation_m := (
			(control["final_torso_position_world_m"] as Vector3)
			. distance_to(treatment["final_torso_position_world_m"] as Vector3)
		)
		var identity_exact: bool = (
			(
				String(control.get("fixture_spec_sha256", ""))
				== String(treatment.get("fixture_spec_sha256", ""))
			)
			and (
				String(control.get("controller_configuration_sha256", ""))
				== String(treatment.get("controller_configuration_sha256", ""))
			)
			and (
				String(control.get("evidence_threshold_configuration_sha256", ""))
				== String(treatment.get("evidence_threshold_configuration_sha256", ""))
			)
			and (
				String(control.get("solver_policy_configuration_sha256", ""))
				== String(treatment.get("solver_policy_configuration_sha256", ""))
			)
			and control.get("gait_clock_options", {}) == treatment.get("gait_clock_options", {})
			and control.get("initial_perturbation", {}) == treatment.get("initial_perturbation", {})
			and control.get("sdk_material_profile", {}) == treatment.get("sdk_material_profile", {})
			and initial_position_error_m <= 1.0e-9
			and initial_orientation_error <= 1.0e-9
		)
		(
			pairs
			. append(
				{
					"pair_id": "primary_mu%s_s16001_pair" % token,
					"control_cell_id": control_id,
					"treatment_cell_id": treatment_id,
					"configuration_identity_exact": identity_exact,
					"initial_position_error_m": initial_position_error_m,
					"initial_orientation_error": initial_orientation_error,
					"terminal_position_separation_m": terminal_separation_m,
					"causal_influence_gate_passed":
					(
						identity_exact
						and terminal_separation_m >= MINIMUM_PAIRED_TERMINAL_SEPARATION_M
					),
					"balance_improvement": false,
					"physical_balance_recovery": false,
				}
			)
		)
	return pairs


static func _all_pair_gates_pass(pairs: Array) -> bool:
	for pair_value in pairs:
		if not bool((pair_value as Dictionary).get("causal_influence_gate_passed", false)):
			return false
	return true


static func _orientation_error(a_value: Variant, b_value: Variant) -> float:
	if typeof(a_value) != TYPE_DICTIONARY or typeof(b_value) != TYPE_DICTIONARY:
		return INF
	var a: Dictionary = a_value
	var b: Dictionary = b_value
	var direct := sqrt(
		(
			pow(float(a.get("x", INF)) - float(b.get("x", -INF)), 2.0)
			+ pow(float(a.get("y", INF)) - float(b.get("y", -INF)), 2.0)
			+ pow(float(a.get("z", INF)) - float(b.get("z", -INF)), 2.0)
			+ pow(float(a.get("w", INF)) - float(b.get("w", -INF)), 2.0)
		)
	)
	var antipodal := sqrt(
		(
			pow(float(a.get("x", INF)) + float(b.get("x", INF)), 2.0)
			+ pow(float(a.get("y", INF)) + float(b.get("y", INF)), 2.0)
			+ pow(float(a.get("z", INF)) + float(b.get("z", INF)), 2.0)
			+ pow(float(a.get("w", INF)) + float(b.get("w", INF)), 2.0)
		)
	)
	return minf(direct, antipodal)


static func _direct_body_write_count(summary: Dictionary) -> int:
	return (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)


static func _perturbation_receipt(perturbation: Dictionary) -> Dictionary:
	return {
		"campaign_seed": int(perturbation.get("campaign_seed", -1)),
		"fixture_vertical_clearance_m":
		float(perturbation.get("fixture_vertical_clearance_m", NAN)),
		"fixture_yaw_rad": float(perturbation.get("fixture_yaw_rad", NAN)),
		"initial_linear_velocity_world_m_s":
		_vector_dictionary(
			(
				perturbation
				. get(
					"initial_linear_velocity_world_m_s",
					Vector3(INF, INF, INF),
				)
			)
		),
		"initial_torso_angular_velocity_world_rad_s":
		_vector_dictionary(
			(
				perturbation
				. get(
					"initial_torso_angular_velocity_world_rad_s",
					Vector3(INF, INF, INF),
				)
			)
		),
		"gait_phase_offset_ticks": int(perturbation.get("gait_phase_offset_ticks", -999)),
	}


static func _vector_dictionary(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _preflight_receipt(preflight: Dictionary) -> Dictionary:
	return {
		"schema_version": PREFLIGHT_SCHEMA,
		"ok": bool(preflight.get("ok", false)),
		"clock_ok": bool(preflight.get("clock_ok", false)),
		"matrix_ok": bool(preflight.get("matrix_ok", false)),
		"inputs_ok": bool(preflight.get("inputs_ok", false)),
		"expected_world_count": EXPECTED_WORLD_COUNT,
		"observed_world_count": 0,
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"task_frame_receipts": (preflight.get("task_frame_receipts", []) as Array).duplicate(true),
		"bridge_conformance":
		(preflight.get("bridge_conformance", {}) as Dictionary).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"locomotion_outcome_exposed": false,
		"adapter_actuation_applied": false,
		"physics_transform_or_velocity_written": false,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
	}


func _bw2_preflight_receipt(preflight: Dictionary) -> Dictionary:
	return {
		"schema_version": BW2_PREFLIGHT_SCHEMA,
		"ok": bool(preflight.get("ok", false)),
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"clock_ok": bool(preflight.get("clock_ok", false)),
		"matrix_ok": bool(preflight.get("matrix_ok", false)),
		"inputs_ok": bool(preflight.get("inputs_ok", false)),
		"expected_world_count": EXPECTED_WORLD_COUNT,
		"observed_world_count": 0,
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"task_frame_receipts": (preflight.get("task_frame_receipts", []) as Array).duplicate(true),
		"bridge_conformance":
		(preflight.get("bridge_conformance", {}) as Dictionary).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"locomotion_outcome_exposed": false,
		"adapter_actuation_applied": false,
		"physics_transform_or_velocity_written": false,
		"development_data_only": true,
		"walking_acceptance": false,
		"material_robustness": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}


func _emit_bw2_material_receipt(
	preflight: Dictionary,
	cell_receipts: Array,
	metrics: Dictionary,
) -> void:
	var receipt := {
		"schema_version": BW2_RECEIPT_SCHEMA,
		"ok": _failed == 0,
		"candidate_id": _bw2_candidate_id,
		"policy_id": _bw2_policy_id,
		"candidate_policy_digest": _bw2_policy_digest,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": BW2_EXPECTED_GATE_COUNT,
		"expected_world_count": EXPECTED_WORLD_COUNT,
		"observed_world_count": cell_receipts.size(),
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"cells": cell_receipts.duplicate(true),
		"integrity_failure_count": int(metrics.get("integrity_failure_count", -1)),
		"eligible_nonzero_treatment_count":
		int(metrics.get("eligible_nonzero_treatment_count", -1)),
		"eligible_nonzero_treatment_nonwalk_count":
		int(metrics.get("eligible_nonzero_treatment_nonwalk_count", -1)),
		"eligible_nonzero_treatment_with_nonzero_stability_count":
		int(
			(
				metrics
				. get(
					"eligible_nonzero_treatment_with_nonzero_stability_count",
					-1,
				)
			)
		),
		"control_integrity_count": int(metrics.get("control_integrity_count", -1)),
		"zero_friction_exact_fallback_count":
		int(metrics.get("zero_friction_exact_fallback_count", -1)),
		"aggregate_walking_gate_failure_count":
		int(metrics.get("aggregate_walking_gate_failure_count", -1)),
		"development_data_only": true,
		"walking_acceptance": false,
		"material_robustness": false,
		"arbitrary_material_robustness": false,
		"continuous_friction_coverage": false,
		"arbitrary_quadruped_coverage": false,
		"continuous_full_volume_coverage": false,
		"cross_engine_c6": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_fault_robustness": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}
	print(
		"BALANCED_WAVE_BW2_MATERIAL_RECEIPT ",
		JSON.stringify(receipt, "", true, true),
	)


func _emit_full_receipt(
	preflight: Dictionary,
	cell_receipts: Array,
	paired_receipts: Array,
	counts: Dictionary,
	acceptance: Dictionary,
	primary_acceptance: bool,
	extended_discrete_cohort_passed: bool,
	zero_control_complete: bool,
) -> void:
	var receipt := {
		"schema_version": RECEIPT_SCHEMA,
		"ok": _failed == 0,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": EXPECTED_GATE_COUNT,
		"expected_world_count": EXPECTED_WORLD_COUNT,
		"observed_world_count": cell_receipts.size(),
		"expected_primary_treatment_count": 12,
		"observed_primary_treatment_pass_count": int(counts.get("primary_pass_count", 0)),
		"expected_control_count": 4,
		"observed_control_pass_count": int(counts.get("control_pass_count", 0)),
		"expected_diagnostic_count": 6,
		"observed_diagnostic_execution_count": int(counts.get("diagnostic_execution_count", 0)),
		"observed_diagnostic_treatment_pass_count":
		int(counts.get("diagnostic_treatment_pass_count", 0)),
		"expected_zero_control_count": 1,
		"observed_zero_control_pass_count": int(counts.get("zero_pass_count", 0)),
		"expected_paired_causal_count": 4,
		"observed_paired_causal_pass_count": _pair_pass_count(paired_receipts),
		"cell_ids": (preflight.get("cell_ids", []) as Array).duplicate(),
		"seed_receipts": (preflight.get("seed_receipts", []) as Array).duplicate(true),
		"profile_receipts": (preflight.get("profile_receipts", []) as Array).duplicate(true),
		"cells": cell_receipts.duplicate(true),
		"paired_controls": paired_receipts.duplicate(true),
		"acceptance": acceptance.duplicate(true),
		"primary_discrete_material_cohort": [0.6, 0.8, 1.0, 1.8],
		"primary_discrete_material_cohort_passed": primary_acceptance,
		"diagnostic_discrete_material_cohort": [0.2, 0.4],
		"extended_discrete_material_cohort_passed": extended_discrete_cohort_passed,
		"zero_friction_fail_safe_passed": zero_control_complete,
		"policy_id": FEEDBACK_POLICY_ID,
		"runtime_id": OVERLAY_RUNTIME_ID,
		"memory_id": OVERLAY_MEMORY_ID,
		"p5i3c_r2_source_commit": P5I3C_R2_SOURCE_COMMIT,
		"p5i3c_r2_report_sha256": P5I3C_R2_REPORT_SHA256,
		"p5m2_source_commit": P5M2_SOURCE_COMMIT,
		"p5m2_report_sha256": P5M2_REPORT_SHA256,
		"candidate35_branch_topology_changed": false,
		"p5i3c_gain_or_bound_changed": false,
		"post_result_cell_seed_or_threshold_changed": false,
		"continuous_friction_coverage": false,
		"arbitrary_material_robustness": false,
		"cross_engine_equivalence": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_fault_robustness": false,
		"balance_improvement": false,
		"physical_balance_recovery": false,
		"fresh_morphology_validation": false,
		"physical_full_volume_coverage": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
	}
	print(
		"SDK_MATERIAL_ROBUSTNESS_RECEIPT ",
		JSON.stringify(receipt, "", true, true),
	)


static func _pair_pass_count(pairs: Array) -> int:
	var count := 0
	for pair_value in pairs:
		if bool((pair_value as Dictionary).get("causal_influence_gate_passed", false)):
			count += 1
	return count


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK Godot/Jolt P5M.3-R1 summary: %d passed, %d failed" % [_passed, _failed],
	)
	quit(0 if _failed == 0 else 1)


func _finish_bw2() -> void:
	print(
		"\nSDK balanced-wave BW2 material summary: %d passed, %d failed" % [_passed, _failed],
	)
	if _passed != BW2_EXPECTED_GATE_COUNT:
		_failed += 1
		push_error(
			"Expected %d BW2 material gates, observed %d" % [BW2_EXPECTED_GATE_COUNT, _passed],
		)
	quit(0 if _failed == 0 else 1)
