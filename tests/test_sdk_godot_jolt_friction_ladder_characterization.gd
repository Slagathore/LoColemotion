extends SceneTree

## Isolated Godot/Jolt authored-friction characterization harness.
##
## With no mode argument this exactly retains the P5M.1-R1 ladder. The
## Additive --bw3, --bw3r, --bw4, --bw5v, --bw5c, and --bw20f modes own only
## their prospectively frozen material cells.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigScript := preload("res://scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd")
const CanonicalizerScript := preload(
	"res://scripts/lab/mechanics/contact_canonicalizer.gd"
)
const SlipObserverScript := preload(
	"res://scripts/lab/mechanics/contact_slip_observer.gd"
)
const BreakawayAnalyzerScript := preload(
	"res://scripts/lab/mechanics/friction_breakaway_analyzer.gd"
)

const RECEIPT_SCHEMA_VERSION := (
	"sporespore_godot_jolt_friction_ladder_r1_receipt_v1"
)
const BW3_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw3_material_characterization_receipt_v1"
)
const BW3_PREFLIGHT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw3_material_characterization_preflight_receipt_v1"
)
const RECEIPT_PREFIX := "SDK_FRICTION_LADDER_RECEIPT "
const BW3_RECEIPT_PREFIX := "BALANCED_WAVE_BW3_MATERIAL_CHARACTERIZATION_RECEIPT "
const BW3_PREFLIGHT_PREFIX := (
	"BALANCED_WAVE_BW3_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
)
const BW3R_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw3r_material_characterization_receipt_v1"
)
const BW3R_PREFLIGHT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw3r_material_characterization_preflight_receipt_v1"
)
const BW3R_RECEIPT_PREFIX := (
	"BALANCED_WAVE_BW3R_MATERIAL_CHARACTERIZATION_RECEIPT "
)
const BW3R_PREFLIGHT_PREFIX := (
	"BALANCED_WAVE_BW3R_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
)
const BW4_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw4_material_characterization_receipt_v1"
)
const BW4_PREFLIGHT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw4_material_characterization_preflight_receipt_v1"
)
const BW4_RECEIPT_PREFIX := (
	"BALANCED_WAVE_BW4_MATERIAL_CHARACTERIZATION_RECEIPT "
)
const BW4_PREFLIGHT_PREFIX := (
	"BALANCED_WAVE_BW4_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
)
const BW5V_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw5v_material_characterization_receipt_v1"
)
const BW5V_PREFLIGHT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw5v_material_characterization_preflight_receipt_v1"
)
const BW5V_RECEIPT_PREFIX := (
	"BALANCED_WAVE_BW5V_MATERIAL_CHARACTERIZATION_RECEIPT "
)
const BW5V_PREFLIGHT_PREFIX := (
	"BALANCED_WAVE_BW5V_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
)
const BW5C_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw5c_material_characterization_receipt_v1"
)
const BW5C_PREFLIGHT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw5c_material_characterization_preflight_receipt_v1"
)
const BW5C_RECEIPT_PREFIX := (
	"BALANCED_WAVE_BW5C_MATERIAL_CHARACTERIZATION_RECEIPT "
)
const BW5C_PREFLIGHT_PREFIX := (
	"BALANCED_WAVE_BW5C_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
)
const BW20F_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw20f_material_characterization_receipt_v1"
)
const BW20F_RECEIPT_PREFIX := (
	"BALANCED_WAVE_BW20F_MATERIAL_CHARACTERIZATION_RECEIPT "
)
const PHYSICS_TICKS_PER_SECOND := 120
const SOLVER_VELOCITY_STEPS := 20
const SOLVER_POSITION_STEPS := 7
const SETTLE_TICKS := 180
const STAGE_TICKS := 60
const ANALYSIS_TICKS := 30
const FRICTIONLESS_FORCE_N := 2.0
const POSITIVE_FRICTION_VALUES := [0.2, 0.4, 0.6, 0.8, 1.0, 1.8]
const BW3_POSITIVE_FRICTION_VALUES := [0.3, 0.7, 1.2]
const BW3R_POSITIVE_FRICTION_VALUES := [0.25, 0.55, 1.1]
const BW4_POSITIVE_FRICTION_VALUES := [0.15, 0.5, 0.9, 1.4]
const BW5V_POSITIVE_FRICTION_VALUES := [0.05, 0.65, 1.3]
const BW5C_POSITIVE_FRICTION_VALUES := [0.12, 0.48, 0.95, 1.5]
const BW20F_POSITIVE_FRICTION_VALUES := [0.09, 0.37, 0.76, 1.18]
const REPLICATE_COUNT := 3
const MAXIMUM_FORCE_SPREAD_N := 2.0
const MAXIMUM_BREAKAWAY_BRACKET_WIDTH_N := 2.0
const MAXIMUM_MONOTONIC_FORCE_DECREASE_N := 2.0
const MAXIMUM_MONOTONIC_RATIO_DECREASE := 0.05
const EXPECTED_WORLD_COUNT := 19
const EXPECTED_GATE_COUNT := 31
const BW3_EXPECTED_WORLD_COUNT := 10
const BW3_EXPECTED_GATE_COUNT := 19
const BW4_EXPECTED_WORLD_COUNT := 13
const BW4_EXPECTED_GATE_COUNT := 23
const BREAKAWAY_CONFIG := {
	"minimum_samples_per_stage": ANALYSIS_TICKS,
	"maximum_holding_speed_mps": 0.01,
	"maximum_holding_displacement_m": 0.003,
	"minimum_sliding_speed_mps": 0.05,
	"minimum_sliding_displacement_m": 0.01,
}

var _passed := 0
var _failed := 0
var _bw3_mode := false
var _bw3r_mode := false
var _bw4_mode := false
var _bw5v_mode := false
var _bw5c_mode := false
var _bw20f_mode := false
var _preflight_only := false


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	_bw3_mode = arguments.has("--bw3")
	_bw3r_mode = arguments.has("--bw3r")
	_bw4_mode = arguments.has("--bw4")
	_bw5v_mode = arguments.has("--bw5v")
	_bw5c_mode = arguments.has("--bw5c")
	_bw20f_mode = arguments.has("--bw20f")
	_preflight_only = arguments.has("--preflight-only")
	call_deferred("_run")


func _run() -> void:
	var campaign_label := _campaign_label()
	print("\n=== SDK Godot/Jolt %s ===" % campaign_label)
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/velocity_steps",
		SOLVER_VELOCITY_STEPS,
	)
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/position_steps",
		SOLVER_POSITION_STEPS,
	)
	var engine_receipt := _engine_receipt()
	_check(
		String(engine_receipt["physics_engine"]) == "Jolt Physics"
		and int(engine_receipt["physics_hz"]) == PHYSICS_TICKS_PER_SECOND
		and int(engine_receipt["solver_velocity_steps"]) == SOLVER_VELOCITY_STEPS
		and int(engine_receipt["solver_position_steps"]) == SOLVER_POSITION_STEPS,
		"1 realized engine is exactly Jolt 120 Hz with 20/7 solver steps",
	)
	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	_check(
		bool(profile.get("executable", false)),
		"2 full contact observer is executable",
	)
	if _preflight_only:
		_run_prospective_preflight(profile, engine_receipt)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var invalid_friction := (
		0.25
		if _bw4_mode or _bw5v_mode or _bw5c_mode or _bw20f_mode
		else (0.3 if _bw3r_mode else (0.4 if _bw3_mode else 0.3))
	)
	var invalid := _build_rig(
		CaptureClockScript.new(),
		profile,
		invalid_friction,
	)
	var invalid_value_rejected := (
		not bool(invalid.get("ok", true))
		and _has_configuration_error(invalid, "SDK_FRICTION_LADDER_VALUE_INVALID")
	)
	_check(
		invalid_value_rejected,
		"3 fixture rejects a value outside the frozen campaign cells",
	)

	var frictionless := await _run_frictionless(profile)
	_check(
		bool(frictionless.get("ok", false))
		and String(frictionless.get("classification", ""))
		== BreakawayAnalyzerScript.SLIDING,
		"4 frictionless world slides under the frozen 2 N force",
	)

	var cells: Array[Dictionary] = []
	var gate_number := 5
	for friction_value in _positive_friction_values():
		var friction := float(friction_value)
		var replicates: Array[Dictionary] = []
		for replicate_index in range(REPLICATE_COUNT):
			var replicate := await _run_positive_ramp(
				profile,
				friction,
				replicate_index + 1,
			)
			replicates.append(replicate)
			_check(
				bool(replicate.get("ok", false)),
				"%d friction %.2f replicate %d completes the frozen bracket"
				% [gate_number, friction, replicate_index + 1],
			)
			gate_number += 1
		var cell := _analyze_cell(friction, replicates)
		cells.append(cell)
		_check(
			bool(cell.get("ok", false)),
			"%d friction %.2f is repeatable and yields a conservative coefficient"
			% [gate_number, friction],
		)
		gate_number += 1

	var monotonic := _analyze_monotonicity(cells)
	_check(
		bool(monotonic.get("ok", false)),
		"%d ordered friction cells satisfy frozen operational monotonicity"
		% gate_number,
	)
	gate_number += 1
	var positive_values := _positive_friction_values()
	var profile_derivation_ok := cells.size() == positive_values.size()
	for cell in cells:
		var coefficient: Dictionary = cell.get("coefficient_derivation", {})
		profile_derivation_ok = (
			profile_derivation_ok
			and bool(coefficient.get("ok", false))
			and float(coefficient.get("controller_mu", 0.0)) > 0.0
			and float(coefficient.get("controller_mu", INF)) <= 1.0
		)
	_check(
		profile_derivation_ok,
		"%d all positive cells publish finite conservative coefficients"
		% gate_number,
	)
	gate_number += 1
	var negative_claims_exact := true
	_check(
		negative_claims_exact,
		"%d isolated characterization grants no locomotion or SDK claim"
		% gate_number,
	)

	var receipt := {
		"schema_version": _receipt_schema_version(),
		"ok": _failed == 0,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": _expected_gate_count(),
		"engine": engine_receipt,
		"observer_profile_executable": bool(profile.get("executable", false)),
		"invalid_value_control":
		{
			"attempted_friction": invalid_friction,
			"rejected": invalid_value_rejected,
			"failure_code":
			"SDK_FRICTION_LADDER_VALUE_INVALID" if invalid_value_rejected else "",
		},
		"fixture":
		{
			"fixture_id": _fixture_id(),
			"authored_friction_values": _authored_friction_values(),
			"positive_friction_values": positive_values,
			"frictionless_force_n": FRICTIONLESS_FORCE_N,
			"floor_size_m": _vector(RigScript.FLOOR_SIZE_M),
			"settle_ticks": SETTLE_TICKS,
			"stage_ticks": STAGE_TICKS,
			"analysis_ticks": ANALYSIS_TICKS,
			"force_stages_n": _force_stages(),
			"force_application": "RigidBody3D.apply_central_force_once_per_tick",
			"stopping_rule": "stop_after_two_consecutive_completed_sliding_stages",
			"hidden_rotation_constraint": false,
			"hidden_damping": false,
		},
		"breakaway_config": BREAKAWAY_CONFIG.duplicate(true),
		"expected_world_count": _expected_world_count(),
		"observed_world_count": 1 + cells.size() * REPLICATE_COUNT,
		"frictionless_control": frictionless,
		"positive_cells": cells,
		"monotonicity": monotonic,
		"adapter_actuation_applied": false,
		"physics_transform_or_velocity_written": false,
		"development_data_only": not (_bw4_mode or _bw5c_mode or _bw20f_mode),
		"cold_characterization": _bw4_mode or _bw5c_mode or _bw20f_mode,
		"walking": false,
		"material_robustness": false,
		"balance_improvement": false,
		"physical_balance_recovery": false,
		"friction_material_locomotion_robustness": false,
		"continuous_friction_coverage": false,
		"cross_engine_equivalence": false,
		"rough_terrain_robustness": false,
		"external_push_recovery": false,
		"sensor_fault_robustness": false,
		"fresh_morphology_validation": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
	}
	print(
		_receipt_prefix(),
		JSON.stringify(receipt, "", true, true),
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _run_frictionless(profile: Dictionary) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = _build_rig(clock, profile, 0.0)
	if not bool(rig.get("ok", false)) or not _material_contract_exact(rig, 0.0):
		return {
			"ok": false,
			"failure_code": "FRICTIONLESS_FIXTURE_INVALID",
			"world_build_count": 0,
			"rig": rig,
		}
	var world := rig["world"] as Node3D
	root.add_child(world)
	var next_step := await _settle(clock, 0)
	var stage := await _sample_stage(
		rig,
		clock,
		next_step,
		"frictionless_002N",
		FRICTIONLESS_FORCE_N,
	)
	world.queue_free()
	await process_frame
	var summary: Dictionary = stage.get("summary", {})
	var classification := _classify(summary)
	return {
		"ok":
		bool(stage.get("complete", false))
		and classification == BreakawayAnalyzerScript.SLIDING,
		"failure_code":
		""
		if (
			bool(stage.get("complete", false))
			and classification == BreakawayAnalyzerScript.SLIDING
		)
		else "FRICTIONLESS_CONTROL_DID_NOT_SLIDE",
		"world_build_count": 1,
		"classification": classification,
		"material_contract": rig["material_contract"],
		"stage": summary,
	}


func _run_positive_ramp(
		profile: Dictionary,
		friction: float,
		replicate_index: int) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = _build_rig(clock, profile, friction)
	if not bool(rig.get("ok", false)) or not _material_contract_exact(rig, friction):
		return {
			"ok": false,
			"failure_code": "POSITIVE_FIXTURE_INVALID",
			"friction": friction,
			"replicate_index": replicate_index,
			"world_build_count": 0,
			"rig": rig,
		}
	var world := rig["world"] as Node3D
	root.add_child(world)
	var next_step := await _settle(clock, 0)
	var stages: Array = []
	var complete := true
	var consecutive_sliding := 0
	var steady_slide_stage: Dictionary = {}
	for force_value in _force_stages():
		var force_n := float(force_value)
		var sampled := await _sample_stage(
			rig,
			clock,
			next_step,
			"load_%03dN" % int(force_n),
			force_n,
		)
		next_step = int(sampled.get("next_step", next_step))
		complete = complete and bool(sampled.get("complete", false))
		var summary: Dictionary = sampled.get("summary", {})
		stages.append(summary)
		if _classify(summary) == BreakawayAnalyzerScript.SLIDING:
			consecutive_sliding += 1
		else:
			consecutive_sliding = 0
		if consecutive_sliding >= 2:
			if _bw3_mode:
				var steady_sample := await _sample_stage(
					rig,
					clock,
					next_step,
					"steady_slide_%03dN" % int(force_n),
					force_n,
				)
				next_step = int(steady_sample.get("next_step", next_step))
				complete = complete and bool(steady_sample.get("complete", false))
				steady_slide_stage = steady_sample.get("summary", {})
			break
	world.queue_free()
	await process_frame

	var built := BreakawayAnalyzerScript.build_config(BREAKAWAY_CONFIG)
	if not bool(built.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "BREAKAWAY_CONFIG_INVALID",
			"friction": friction,
			"replicate_index": replicate_index,
			"world_build_count": 1,
			"stage_summaries": stages,
		}
	var analysis: Dictionary = BreakawayAnalyzerScript.analyze(
		built["config"],
		stages,
	)
	var classified: Array = analysis.get("classified_stages", [])
	var sliding_pair := _first_consecutive_sliding_pair(classified)
	var positive_held := false
	for stage_value in classified:
		var classified_stage: Dictionary = stage_value
		if (
			float(classified_stage.get("applied_shear_force_n", 0.0)) > 0.0
			and String(classified_stage.get("classification", ""))
			== BreakawayAnalyzerScript.HELD
		):
			positive_held = true
			break
	var lower_force := float(analysis.get("breakaway_force_lower_n", NAN))
	var upper_force := float(analysis.get("breakaway_force_upper_n", NAN))
	var lower_ratio := float(analysis.get("empirical_static_ratio_lower", NAN))
	var upper_ratio := float(analysis.get("empirical_static_ratio_upper", NAN))
	var first_sliding_tilt := float(
		sliding_pair.get("first", {}).get("max_body_tilt_rad", INF)
	)
	var second_sliding_tilt := float(
		sliding_pair.get("second", {}).get("max_body_tilt_rad", INF)
	)
	var steady_slide: Dictionary = {}
	if _bw3_mode:
		steady_slide = _steady_slide_characterization(
			steady_slide_stage,
			float(
				sliding_pair.get("second", {}).get(
					"applied_shear_force_n",
					NAN,
				)
			),
		)
	var acceptance := (
		complete
		and bool(analysis.get("ok", false))
		and bool(analysis.get("breakaway_detected", false))
		and positive_held
		and bool(sliding_pair.get("ok", false))
		and is_finite(lower_force)
		and is_finite(upper_force)
		and upper_force > lower_force
		and upper_force - lower_force <= MAXIMUM_BREAKAWAY_BRACKET_WIDTH_N + 1.0e-9
		and is_finite(lower_ratio)
		and is_finite(upper_ratio)
		and lower_ratio > 0.0
		and upper_ratio > lower_ratio
		and first_sliding_tilt < deg_to_rad(5.0)
		and second_sliding_tilt < deg_to_rad(5.0)
		and (not _bw3_mode or bool(steady_slide.get("ok", false)))
	)
	var result := {
		"ok": acceptance,
		"failure_code": "" if acceptance else "FRICTION_LADDER_REPLICATE_REJECTED",
		"friction": friction,
		"replicate_index": replicate_index,
		"world_build_count": 1,
		"material_contract": rig["material_contract"],
		"contact_cap_per_body": int(rig["contact_cap_per_body"]),
		"breakaway_analysis": analysis,
		"classified_stages": classified,
		"breakaway_force_lower_n": lower_force,
		"breakaway_force_upper_n": upper_force,
		"empirical_static_ratio_lower": lower_ratio,
		"empirical_static_ratio_upper": upper_ratio,
		"first_sliding_stage": sliding_pair.get("first", {}),
		"second_sliding_stage": sliding_pair.get("second", {}),
		"all_stage_observations_complete": complete,
		"positive_force_held_observed": positive_held,
		"two_consecutive_sliding_stages_observed":
		bool(sliding_pair.get("ok", false)),
	}
	if _bw3_mode:
		result["steady_slide_characterization"] = steady_slide
	return result


static func _steady_slide_characterization(
		stage: Dictionary,
		expected_force_n: float) -> Dictionary:
	var force_n := float(stage.get("applied_shear_force_n", NAN))
	var speed_mps := float(stage.get("max_slip_speed_mps", NAN))
	var displacement_m := float(stage.get("tangential_displacement_m", NAN))
	var mean_normal_load_n := float(stage.get("mean_normal_load_n", NAN))
	var tilt_rad := float(stage.get("max_body_tilt_rad", NAN))
	var accepted := (
		not stage.is_empty()
		and is_finite(expected_force_n)
		and is_finite(force_n)
		and absf(force_n - expected_force_n) <= 1.0e-9
		and int(stage.get("sample_count", -1)) == ANALYSIS_TICKS
		and int(stage.get("valid_sample_count", -1)) == ANALYSIS_TICKS
		and int(stage.get("contact_sample_count", -1)) == ANALYSIS_TICKS
		and bool(stage.get("capacity_complete", false))
		and _classify(stage) == BreakawayAnalyzerScript.SLIDING
		and is_finite(speed_mps)
		and speed_mps >= float(BREAKAWAY_CONFIG["minimum_sliding_speed_mps"])
		and is_finite(displacement_m)
		and displacement_m
		>= float(BREAKAWAY_CONFIG["minimum_sliding_displacement_m"])
		and is_finite(mean_normal_load_n)
		and mean_normal_load_n > 0.0
		and is_finite(tilt_rad)
		and tilt_rad < deg_to_rad(5.0)
	)
	return {
		"ok": accepted,
		"failure_code": "" if accepted else "STEADY_SLIDE_STAGE_REJECTED",
		"operational_definition":
		(
			"third consecutive classified-SLIDING 60-tick stage; "
			+ "same fixed applied force as the preceding stage; "
			+ "final 30 ticks observed"
		),
		"steady_velocity_claim": false,
		"kinetic_friction_coefficient_claim": false,
		"applied_shear_force_n": force_n,
		"max_slip_speed_mps": speed_mps,
		"tangential_displacement_m": displacement_m,
		"mean_normal_load_n": mean_normal_load_n,
		"max_body_tilt_rad": tilt_rad,
		"stage": stage.duplicate(true),
	}


func _analyze_cell(friction: float, replicates: Array[Dictionary]) -> Dictionary:
	var all_valid := replicates.size() == REPLICATE_COUNT
	for replicate in replicates:
		all_valid = all_valid and bool(replicate.get("ok", false))
	var first_sliding_forces: Array[float] = []
	var lower_forces: Array[float] = []
	var lower_ratios: Array[float] = []
	for replicate in replicates:
		first_sliding_forces.append(
			float(replicate.get("breakaway_force_upper_n", NAN))
		)
		lower_forces.append(float(replicate.get("breakaway_force_lower_n", NAN)))
		lower_ratios.append(
			float(replicate.get("empirical_static_ratio_lower", NAN))
		)
	var first_sliding_spread := _spread(first_sliding_forces)
	var lower_force_spread := _spread(lower_forces)
	var minimum_lower_force := _minimum(lower_forces)
	var minimum_lower_ratio := _minimum(lower_ratios)
	var coefficient := _derive_controller_coefficient(minimum_lower_ratio)
	var acceptance := (
		all_valid
		and first_sliding_spread <= MAXIMUM_FORCE_SPREAD_N + 1.0e-9
		and lower_force_spread <= MAXIMUM_FORCE_SPREAD_N + 1.0e-9
		and bool(coefficient.get("ok", false))
	)
	return {
		"ok": acceptance,
		"failure_code": "" if acceptance else "FRICTION_LADDER_CELL_REJECTED",
		"authored_friction": friction,
		"replicates": replicates,
		"first_sliding_force_spread_n": first_sliding_spread,
		"lower_breakaway_force_spread_n": lower_force_spread,
		"minimum_lower_breakaway_force_n": minimum_lower_force,
		"minimum_lower_empirical_ratio": minimum_lower_ratio,
		"coefficient_derivation": coefficient,
	}


static func _analyze_monotonicity(cells: Array[Dictionary]) -> Dictionary:
	var violations: Array[Dictionary] = []
	var previous_force := -INF
	var previous_ratio := -INF
	for cell in cells:
		var friction := float(cell.get("authored_friction", NAN))
		var lower_force := float(cell.get("minimum_lower_breakaway_force_n", NAN))
		var lower_ratio := float(cell.get("minimum_lower_empirical_ratio", NAN))
		if (
			not is_finite(friction)
			or not is_finite(lower_force)
			or not is_finite(lower_ratio)
		):
			violations.append(
				{
					"authored_friction": friction,
					"code": "NONFINITE_MONOTONICITY_INPUT",
				}
			)
		elif (
			lower_force < previous_force - MAXIMUM_MONOTONIC_FORCE_DECREASE_N
			or lower_ratio < previous_ratio - MAXIMUM_MONOTONIC_RATIO_DECREASE
		):
			violations.append(
				{
					"authored_friction": friction,
					"code": "OPERATIONAL_MONOTONICITY_VIOLATION",
					"previous_lower_force_n": previous_force,
					"current_lower_force_n": lower_force,
					"previous_lower_ratio": previous_ratio,
					"current_lower_ratio": lower_ratio,
				}
			)
		previous_force = lower_force
		previous_ratio = lower_ratio
	return {
		"ok": violations.is_empty(),
		"maximum_force_decrease_n": MAXIMUM_MONOTONIC_FORCE_DECREASE_N,
		"maximum_ratio_decrease": MAXIMUM_MONOTONIC_RATIO_DECREASE,
		"violations": violations,
	}


static func _derive_controller_coefficient(minimum_lower_ratio: float) -> Dictionary:
	if not is_finite(minimum_lower_ratio) or minimum_lower_ratio <= 0.0:
		return {
			"ok": false,
			"failure_code": "MINIMUM_LOWER_RATIO_INVALID",
		}
	var controller_mu := minf(1.0, floorf(100.0 * minimum_lower_ratio) / 100.0)
	return {
		"ok": controller_mu > 0.0,
		"failure_code": "" if controller_mu > 0.0 else "CONTROLLER_MU_NOT_POSITIVE",
		"minimum_lower_ratio": minimum_lower_ratio,
		"rounding_rule": "min(1.0,floor(100*minimum_lower_ratio)/100)",
		"documented_godot_maximum_cap": 1.0,
		"controller_mu": controller_mu,
		"cross_engine_equivalent": false,
		"locomotion_robustness": false,
	}


func _settle(clock, start_step: int) -> int:
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	for offset in range(SETTLE_TICKS):
		var step_id := start_step + offset
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback",
		)
		await physics_frame
		clock.close_epoch()
	return start_step + SETTLE_TICKS


func _sample_stage(
		rig: Dictionary,
		clock,
		start_step: int,
		stage_id: String,
		force_n: float) -> Dictionary:
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var body = rig["body"]
	var sample_count := 0
	var valid_sample_count := 0
	var contact_sample_count := 0
	var maximum_slip_speed_mps := 0.0
	var normal_load_sum_n := 0.0
	var first_position := Vector3(INF, INF, INF)
	var last_position := Vector3(INF, INF, INF)
	var maximum_body_tilt_rad := 0.0
	var capacity_complete := true
	for local_step in range(STAGE_TICKS):
		var step_id := start_step + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback",
		)
		body.apply_central_force(Vector3(force_n, 0.0, 0.0))
		await physics_frame
		clock.close_epoch()
		if local_step < STAGE_TICKS - ANALYSIS_TICKS:
			continue
		sample_count += 1
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity_observation: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			capacity_complete
			and bool(capacity_observation.get("finite", false))
			and not bool(capacity_observation.get("saturated_ever", true))
		)
		var canonical := _canonical_frame(rig, body, step_id)
		if (
			not bool(canonical.get("ok", false))
			or int(canonical.get("canonical_patch_count", 0)) != 1
		):
			continue
		contact_sample_count += 1
		var patch: Dictionary = canonical["patches"][0]
		var slip: Dictionary = SlipObserverScript.observe(
			patch,
			step_s,
			Vector3(force_n, 0.0, 0.0),
			_post_step_kinematics(body, patch),
		)
		if not bool(slip.get("observation_valid", false)):
			continue
		valid_sample_count += 1
		maximum_slip_speed_mps = maxf(
			maximum_slip_speed_mps,
			float(slip["slip_speed_mps"]),
		)
		normal_load_sum_n += float(slip["predicted_normal_load_n"])
		var position := _sample_position(body.latest_body_sample)
		if not first_position.is_finite():
			first_position = position
		last_position = position
		maximum_body_tilt_rad = maxf(
			maximum_body_tilt_rad,
			_sample_tilt_rad(body.latest_body_sample),
		)
	var displacement_m := (
		Vector2(
			last_position.x - first_position.x,
			last_position.z - first_position.z,
		).length()
		if first_position.is_finite() and last_position.is_finite()
		else INF
	)
	var complete := (
		capacity_complete
		and sample_count == ANALYSIS_TICKS
		and valid_sample_count == sample_count
		and contact_sample_count == sample_count
		and is_finite(displacement_m)
	)
	var summary := {
		"stage_id": stage_id,
		"applied_shear_force_n": force_n,
		"sample_count": sample_count,
		"valid_sample_count": valid_sample_count,
		"contact_sample_count": contact_sample_count,
		"max_slip_speed_mps": maximum_slip_speed_mps,
		"tangential_displacement_m": displacement_m,
		"mean_normal_load_n":
		normal_load_sum_n / float(maxi(valid_sample_count, 1)),
		"max_body_tilt_rad": maximum_body_tilt_rad,
		"capacity_complete": capacity_complete,
	}
	print(
		(
			"  %s F=%6.1fN samples=%d/%d slip=%.5fm/s dx=%.5fm "
			+ "normal=%.3fN tilt=%.3fdeg class=%s"
		)
		% [
			stage_id,
			force_n,
			valid_sample_count,
			sample_count,
			maximum_slip_speed_mps,
			displacement_m,
			float(summary["mean_normal_load_n"]),
			rad_to_deg(maximum_body_tilt_rad),
			_classify(summary),
		],
	)
	return {
		"complete": complete,
		"summary": summary,
		"next_step": start_step + STAGE_TICKS,
	}


static func _first_consecutive_sliding_pair(stages: Array) -> Dictionary:
	for index in range(1, stages.size()):
		var previous: Dictionary = stages[index - 1]
		var current: Dictionary = stages[index]
		if (
			String(previous.get("classification", ""))
			== BreakawayAnalyzerScript.SLIDING
			and String(current.get("classification", ""))
			== BreakawayAnalyzerScript.SLIDING
		):
			return {
				"ok": true,
				"first": previous,
				"second": current,
			}
	return {
		"ok": false,
		"first": {},
		"second": {},
	}


static func _force_stages() -> Array[float]:
	var result: Array[float] = []
	for force_n in range(0, 81):
		result.append(float(force_n))
	for force_n in [90.0, 100.0, 110.0]:
		result.append(force_n)
	return result


static func _classify(stage: Dictionary) -> String:
	var speed := float(stage.get("max_slip_speed_mps", NAN))
	var displacement := float(stage.get("tangential_displacement_m", NAN))
	if (
		speed <= float(BREAKAWAY_CONFIG["maximum_holding_speed_mps"])
		and displacement
		<= float(BREAKAWAY_CONFIG["maximum_holding_displacement_m"])
	):
		return BreakawayAnalyzerScript.HELD
	if (
		speed >= float(BREAKAWAY_CONFIG["minimum_sliding_speed_mps"])
		and displacement
		>= float(BREAKAWAY_CONFIG["minimum_sliding_displacement_m"])
	):
		return BreakawayAnalyzerScript.SLIDING
	return BreakawayAnalyzerScript.AMBIGUOUS


static func _material_contract_exact(rig: Dictionary, expected_friction: float) -> bool:
	var contract: Dictionary = rig.get("material_contract", {})
	for side in ["body", "floor"]:
		var material: Dictionary = contract.get(side, {})
		if (
			absf(float(material.get("friction", NAN)) - expected_friction) > 1.0e-6
			or not bool(material.get("rough", false))
			or absf(float(material.get("bounce", NAN))) > 1.0e-9
			or not bool(material.get("absorbent", false))
		):
			return false
	return (
		String(contract.get("godot_pair_rule", ""))
		== "highest_friction_both_rough_v1"
		and absf(
			float(contract.get("authored_friction_cell", NAN))
			- expected_friction
		)
		<= 1.0e-6
	)


static func _canonical_frame(rig: Dictionary, body, step_id: int) -> Dictionary:
	var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
	return CanonicalizerScript.canonicalize(
		body.latest_contacts_v2,
		diagnostics.get("observation", {}),
		{
			"physics_step_id": step_id,
			"capture_epoch": step_id,
			"sample_phase": "integrate_callback",
			"run_id": String(rig["run_id"]),
			"capture_stream_id": String(rig["capture_stream_id"]),
			"observer_profile_id": "full_contacts_v2",
			"observer_adapter_id": "rigid_body_integrate_forces_v2",
			"body_id": String(rig["body_id"]),
		},
	)


static func _post_step_kinematics(
		body: RigidBody3D,
		patch: Dictionary) -> Dictionary:
	return {
		"physics_step_id": int(patch["physics_step_id"]),
		"capture_epoch": int(patch["capture_epoch"]),
		"sample_phase": "post_step",
		"body_linear_velocity_world_mps": body.linear_velocity,
		"body_angular_velocity_world_rad_s": body.angular_velocity,
		"body_center_of_mass_world_m": body.global_transform * body.center_of_mass,
		"counterparty_velocity_world_mps": Vector3.ZERO,
	}


static func _sample_position(body_sample: Dictionary) -> Vector3:
	var transform_value: Variant = body_sample.get("transform")
	if not transform_value is Dictionary:
		return Vector3(INF, INF, INF)
	var origin_value: Variant = (transform_value as Dictionary).get("origin")
	if not origin_value is Array or (origin_value as Array).size() != 3:
		return Vector3(INF, INF, INF)
	return Vector3(
		float(origin_value[0]),
		float(origin_value[1]),
		float(origin_value[2]),
	)


static func _sample_tilt_rad(body_sample: Dictionary) -> float:
	var transform_value: Variant = body_sample.get("transform")
	if not transform_value is Dictionary:
		return INF
	var basis_value: Variant = (transform_value as Dictionary).get("basis")
	if not basis_value is Array or (basis_value as Array).size() != 3:
		return INF
	var y_value: Variant = (basis_value as Array)[1]
	if not y_value is Array or (y_value as Array).size() != 3:
		return INF
	var local_up := Vector3(
		float(y_value[0]),
		float(y_value[1]),
		float(y_value[2]),
	)
	if not local_up.is_finite() or local_up.length_squared() <= 1.0e-8:
		return INF
	return acos(clampf(local_up.normalized().dot(Vector3.UP), -1.0, 1.0))


static func _spread(values: Array[float]) -> float:
	if values.is_empty():
		return INF
	for value in values:
		if not is_finite(value):
			return INF
	return values.max() - values.min()


static func _minimum(values: Array[float]) -> float:
	if values.is_empty():
		return NAN
	for value in values:
		if not is_finite(value):
			return NAN
	return values.min()


func _run_prospective_preflight(
		profile: Dictionary,
		engine_receipt: Dictionary) -> void:
	_check(
		(
			int(_bw3_mode)
			+ int(_bw3r_mode)
			+ int(_bw4_mode)
			+ int(_bw5v_mode)
			+ int(_bw5c_mode)
		)
		== 1,
		"3 preflight is restricted to one separately identified prospective campaign",
	)
	var preregistration_path := (
		"res://sdk/balanced_wave_bw5c_preregistration.json"
		if _bw5c_mode
		else (
			"res://sdk/balanced_wave_bw5v_preregistration.json"
			if _bw5v_mode
			else (
				"res://sdk/balanced_wave_bw4_preregistration.json"
				if _bw4_mode
				else (
					"res://sdk/balanced_wave_bw3r_preregistration.json"
					if _bw3r_mode
					else "res://sdk/balanced_wave_bw3_preregistration.json"
				)
			)
		)
	)
	var preregistration := _load_json(
		preregistration_path
	)
	var selected := _load_json("res://sdk/balanced_wave_selected_policy.json")
	var expected_candidate_id := (
		"BW5R-B"
		if _bw5v_mode or _bw5c_mode
		else ("BW2R-C" if _bw3r_mode or _bw4_mode else "BW2-C")
	)
	var expected_policy_id := (
		"sporespore_balanced_wave_bw5r_b_v1"
		if _bw5v_mode or _bw5c_mode
		else (
			"sporespore_balanced_wave_bw2r_c_v1"
			if _bw3r_mode or _bw4_mode
			else "sporespore_balanced_wave_bw2_c_v1"
		)
	)
	var expected_digest := (
		"sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
		if _bw5v_mode or _bw5c_mode
		else (
			"sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0"
			if _bw3r_mode or _bw4_mode
			else "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
		)
	)
	var selected_binding_exact := false
	if (
		String(selected.get("selected_candidate_id", "")) == expected_candidate_id
		and String(selected.get("selected_policy_id", "")) == expected_policy_id
		and (
			String(selected.get("selected_candidate_policy_digest", ""))
			== expected_digest
		)
	):
		selected_binding_exact = true
	if not selected_binding_exact:
		for history_value in selected.get("selection_history", []):
			var history: Dictionary = history_value
			if (
				String(history.get("candidate_id", "")) == expected_candidate_id
				and String(history.get("policy_id", "")) == expected_policy_id
				and String(history.get("policy_digest", "")) == expected_digest
			):
				selected_binding_exact = true
				break
	var preregistered_policy: Dictionary = preregistration.get(
		"selected_policy",
		{},
	)
	var preregistered_candidate_id := (
		String(preregistered_policy.get("candidate_id", ""))
		if _bw5c_mode
		else String(preregistration.get("selected_candidate_id", ""))
	)
	var preregistered_policy_id := (
		String(preregistered_policy.get("policy_id", ""))
		if _bw5c_mode
		else String(preregistration.get("selected_policy_id", ""))
	)
	var preregistered_digest := (
		String(preregistered_policy.get("policy_digest", ""))
		if _bw5c_mode
		else String(preregistration.get("selected_candidate_digest", ""))
	)
	var selected_branch_surfaces: Array = (
		selected.get("selected_profile", {}).get("branch_surfaces", [])
	)
	var identities_exact: bool = (
		String(preregistration.get("schema_version", ""))
		== (
			"sporespore_balanced_wave_bw5c_preregistration_v1"
			if _bw5c_mode
			else (
				"sporespore_balanced_wave_bw5v_preregistration_v1"
				if _bw5v_mode
				else (
					"sporespore_balanced_wave_bw4_preregistration_v1"
					if _bw4_mode
					else (
						"sporespore_balanced_wave_bw3r_preregistration_v1"
						if _bw3r_mode
						else "sporespore_balanced_wave_bw3_preregistration_v1"
					)
				)
			)
		)
		and String(preregistration.get("status", ""))
		== (
			"frozen_before_first_bw5c_characterization_world"
			if _bw5c_mode
			else (
				"frozen_before_first_bw5v_characterization_world"
				if _bw5v_mode
				else (
					"frozen_before_first_bw4_characterization_world"
					if _bw4_mode
					else (
						"frozen_before_first_bw3r_characterization_world"
						if _bw3r_mode
						else "frozen_before_first_bw3_characterization_world"
					)
				)
			)
		)
		and preregistered_candidate_id == expected_candidate_id
		and preregistered_policy_id == expected_policy_id
		and preregistered_digest == expected_digest
		and selected_binding_exact
		and (
			not _bw5c_mode
			or (
				String(
					preregistered_policy.get("runtime_profile_digest", "")
				)
				== "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e"
				and bool(
					preregistered_policy.get(
						"branch_surfaces_required_empty",
						false,
					)
				)
				and selected_branch_surfaces.is_empty()
				and bool(preregistration.get("cold_characterization", false))
				and not bool(preregistration.get("cold_acceptance", true))
			)
		)
		and (
			not _bw5v_mode
			or (
				String(
					preregistration.get("selection_evidence", {})
					.get("sha256", "")
				)
				== "d2819d1bca45592fe54f1fc22cd2ad19d64fb3cd9eafd8ad848601338f8b50fc"
				and String(
					preregistration.get("selection_evidence", {})
					.get("source_commit", "")
				)
				== "d17b77afefddb19ae401f3f8f2e8b3b7708a02e6"
				and bool(
					preregistration.get("selection_evidence", {})
					.get("accepted", false)
				)
				and int(
					preregistration.get("selection_evidence", {})
					.get("observed_world_count", -1)
				)
				== 174
				and int(
					preregistration.get("selection_evidence", {})
					.get("input_report_count", -1)
				)
				== 15
			)
		)
		and (
			not _bw4_mode
			or (
				String(
					preregistration.get("prerequisite_evidence", {})
					.get("bw3r_validation", {})
					.get("sha256", "")
				)
				== "8cb29f019497a1b9bd0f4285ccd7eef20083ccd1b636ec5ef914d7e10e261913"
				and bool(
					preregistration.get("prerequisite_evidence", {})
					.get("bw3r_validation", {})
					.get("accepted", false)
				)
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw3r_validation", {})
					.get("observed_world_count", -1)
				)
				== 12
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw3r_validation", {})
					.get("passed_gate_count", -1)
				)
				== 22
			)
		)
		and (
			not _bw5c_mode
			or (
				String(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("sha256", "")
				)
				== "a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee"
				and String(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("source_commit", "")
				)
				== "7d8b046f752974b8d9498db91b0d46ae99ac1729"
				and String(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("result_status", "")
				)
				== "validation_passed"
				and String(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("campaign_partition", "")
				)
				== "independent_bw5v_validation"
				and bool(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("accepted", false)
				)
				and bool(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("validation_data_only", false)
				)
				and not bool(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("opened_validation_replay", true)
				)
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("observed_world_count", -1)
				)
				== 12
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("passed_gate_count", -1)
				)
				== 22
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("treatment_pass_count", -1)
				)
				== 9
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("control_pass_count", -1)
				)
				== 3
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("causal_pair_pass_count", -1)
				)
				== 3
				and int(
					preregistration.get("prerequisite_evidence", {})
					.get("bw5v_validation", {})
					.get("integrity_failure_count", -1)
				)
				== 0
			)
		)
	)
	_check(
		identities_exact,
		"4 preregistration and selected-policy identities are exact",
	)
	var characterization: Dictionary = preregistration.get(
		"material_characterization",
		{},
	)
	var authored_values_exact: bool = (
		characterization.get("authored_friction_values", [])
		== _positive_friction_values()
	)
	var replication_exact: bool = (
		int(characterization.get("replicate_count_per_value", -1))
		== REPLICATE_COUNT
		and int(characterization.get("frictionless_control_world_count", -1))
		== 1
	)
	var counts_exact: bool = (
		int(characterization.get("expected_world_count", -1))
		== _expected_world_count()
		and int(characterization.get("expected_gate_count", -1))
		== _expected_gate_count()
	)
	var cold_boundary: Dictionary = preregistration.get("cold_boundary", {})
	var cold_values_exact: bool = (
		cold_boundary.get("bw4_authored_friction_values", [])
		== BW4_POSITIVE_FRICTION_VALUES
	)
	var cold_seed_values: Array = cold_boundary.get("bw4_validation_seeds", [])
	var cold_seeds_exact: bool = (
		cold_seed_values.size() == 3
		and int(cold_seed_values[0]) == 18001
		and int(cold_seed_values[1]) == 18002
		and int(cold_seed_values[2]) == 18003
	)
	var cold_value_reservation_exact: bool = bool(
		cold_boundary.get(
			"values_are_exactly_the_pre_bw3r_reserved_bw4_values",
			false
		)
	)
	var cold_seed_reservation_exact: bool = bool(
		cold_boundary.get(
			"seeds_are_exactly_the_pre_bw3r_reserved_bw4_seeds",
			false
		)
	)
	var cold_boundary_exact: bool = (
		not _bw4_mode
		or (
			cold_values_exact
			and cold_seeds_exact
			and cold_value_reservation_exact
			and cold_seed_reservation_exact
		)
	)
	var validation_boundary: Dictionary = preregistration.get(
		"independent_validation_boundary",
		{},
	)
	var bw5v_validation_values_exact: bool = (
		validation_boundary.get("authored_friction_values", [])
		== BW5V_POSITIVE_FRICTION_VALUES
	)
	var bw5v_validation_seed_values: Array = validation_boundary.get(
		"campaign_seeds",
		[],
	)
	var bw5v_validation_seeds_exact: bool = (
		bw5v_validation_seed_values.size() == 3
		and int(bw5v_validation_seed_values[0]) == 19501
		and int(bw5v_validation_seed_values[1]) == 19502
		and int(bw5v_validation_seed_values[2]) == 19503
	)
	var cold_reservation: Dictionary = preregistration.get(
		"cold_acceptance_reservation",
		{},
	)
	var bw5v_cold_values_exact: bool = (
		cold_reservation.get("authored_friction_values", [])
		== [0.12, 0.48, 0.95, 1.5]
	)
	var bw5v_cold_seed_values: Array = cold_reservation.get(
		"campaign_seeds",
		[],
	)
	var bw5v_cold_seeds_exact: bool = (
		bw5v_cold_seed_values.size() == 3
		and int(bw5v_cold_seed_values[0]) == 20001
		and int(bw5v_cold_seed_values[1]) == 20002
		and int(bw5v_cold_seed_values[2]) == 20003
	)
	var bw5v_boundary_exact: bool = (
		not _bw5v_mode
		or (
			bw5v_validation_values_exact
			and bw5v_validation_seeds_exact
			and bw5v_cold_values_exact
			and bw5v_cold_seeds_exact
			and bool(
				validation_boundary.get(
					"values_and_seeds_exactly_match_bw5r_reservation",
					false,
				)
			)
			and bool(
				validation_boundary.get(
					"selection_did_not_observe_values_or_seeds",
					false,
				)
			)
			and bool(
				cold_reservation.get(
					"remains_unopened_during_bw5v",
					false,
				)
			)
		)
	)
	var reservation_provenance: Dictionary = preregistration.get(
		"reservation_provenance",
		{},
	)
	var bw5c_values_exact: bool = (
		reservation_provenance.get("authored_friction_values", [])
		== BW5C_POSITIVE_FRICTION_VALUES
	)
	var bw5c_seed_values: Array = reservation_provenance.get(
		"campaign_seeds",
		[],
	)
	var bw5c_seeds_exact: bool = (
		bw5c_seed_values.size() == 3
		and int(bw5c_seed_values[0]) == 20001
		and int(bw5c_seed_values[1]) == 20002
		and int(bw5c_seed_values[2]) == 20003
	)
	var bw5c_prior_sources_exact: bool = (
		String(
			reservation_provenance.get("bw5v_preregistration", {})
			.get("sha256", "")
		)
		== "77c7ae3f4367cf79ce7dbead74f319426da19c00e15884aa1a25dcfd738abff6"
		and String(
			reservation_provenance.get("bw5v_preregistration", {})
			.get("source_commit", "")
		)
		== "2a5eb94dca81a8c638e31a0d7c9692c270b44ca6"
		and String(
			reservation_provenance.get("bw5v_validation_manifest", {})
			.get("sha256", "")
		)
		== "90e579fe39a205449a8de57c7bc90b9d4787bfc7b85d7b1c3cbd4b949a0bfcd8"
		and String(
			reservation_provenance.get("bw5v_validation_manifest", {})
			.get("source_commit", "")
		)
		== "7d8b046f752974b8d9498db91b0d46ae99ac1729"
	)
	var cold_validation_matrix: Dictionary = preregistration.get(
		"cold_validation_matrix",
		{},
	)
	var cold_validation_seed_values: Array = cold_validation_matrix.get(
		"seeds",
		[],
	)
	var cold_validation_seeds_exact: bool = (
		cold_validation_seed_values.size() == 3
		and int(cold_validation_seed_values[0]) == 20001
		and int(cold_validation_seed_values[1]) == 20002
		and int(cold_validation_seed_values[2]) == 20003
	)
	var bw5c_later_validation_exact: bool = (
		cold_validation_matrix.get("authored_friction_values", [])
		== BW5C_POSITIVE_FRICTION_VALUES
		and cold_validation_seeds_exact
		and int(
			cold_validation_matrix.get("expected_treatment_world_count", -1)
		)
		== 12
		and int(
			cold_validation_matrix.get("expected_control_world_count", -1)
		)
		== 4
		and int(
			cold_validation_matrix.get(
				"expected_zero_friction_safety_world_count",
				-1,
			)
		)
		== 1
		and int(cold_validation_matrix.get("expected_world_count", -1)) == 17
		and int(cold_validation_matrix.get("expected_gate_count", -1)) == 28
		and bool(
			cold_validation_matrix.get("averaging_forbidden", false)
		)
		and bool(
			cold_validation_matrix.get("failed_cell_replacement_forbidden", false)
		)
		and bool(
			cold_validation_matrix.get("post_result_gate_edit_forbidden", false)
		)
	)
	var bw5c_boundary_exact: bool = (
		not _bw5c_mode
		or (
			bw5c_values_exact
			and bw5c_seeds_exact
			and bw5c_prior_sources_exact
			and bw5c_later_validation_exact
			and bool(
				reservation_provenance.get(
					"values_and_seeds_exactly_match_both_prior_reservations",
					false,
				)
			)
			and bool(
				reservation_provenance.get(
					"values_and_seeds_disjoint_from_all_opened_partitions",
					false,
				)
			)
			and bool(
				reservation_provenance.get(
					"bw5r_selection_did_not_observe_values_or_seeds",
					false,
				)
			)
			and bool(
				reservation_provenance.get(
					"bw5v_characterization_did_not_observe_values_or_seeds",
					false,
				)
			)
			and bool(
				reservation_provenance.get(
					"bw5v_validation_did_not_observe_values_or_seeds",
					false,
				)
			)
		)
	)
	var steady_slide_rule_exact: bool = (
		String(characterization.get("steady_slide_definition", ""))
		== (
			"third consecutive classified-SLIDING 60-tick stage; "
			+ "same fixed applied force as the preceding stage; "
			+ "final 30 ticks observed"
		)
	)
	var matrix_exact: bool = (
		authored_values_exact
		and replication_exact
		and counts_exact
		and cold_boundary_exact
		and bw5v_boundary_exact
		and bw5c_boundary_exact
		and steady_slide_rule_exact
	)
	_check(
		matrix_exact,
		"5 prospective material values, replication, counts, and steady-slide rule are frozen",
	)
	var rigs_exact := true
	var fixture_receipts: Array = []
	for friction_value in _authored_friction_values():
		var friction := float(friction_value)
		var rig := _build_rig(
			CaptureClockScript.new(),
			profile,
			friction,
		)
		var exact := (
			bool(rig.get("ok", false))
			and String(rig.get("fixture_id", "")) == _fixture_id()
			and _material_contract_exact(rig, friction)
		)
		rigs_exact = rigs_exact and exact
		fixture_receipts.append(
			{
				"authored_friction": friction,
				"fixture_id": String(rig.get("fixture_id", "")),
				"material_contract_exact": exact,
			}
		)
		var world_value: Variant = rig.get("world")
		if world_value is Node:
			(world_value as Node).free()
	_check(
		rigs_exact and fixture_receipts.size() == _authored_friction_values().size(),
		"6 all isolated fixtures compile without SceneTree insertion",
	)
	var receipt := {
		"schema_version": (
			BW5C_PREFLIGHT_SCHEMA_VERSION
			if _bw5c_mode
			else (
				BW5V_PREFLIGHT_SCHEMA_VERSION
				if _bw5v_mode
				else (
					BW4_PREFLIGHT_SCHEMA_VERSION
					if _bw4_mode
					else (
						BW3R_PREFLIGHT_SCHEMA_VERSION
						if _bw3r_mode
						else BW3_PREFLIGHT_SCHEMA_VERSION
					)
				)
			)
		),
		"ok": _failed == 0,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": 6,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"selected_candidate_id": expected_candidate_id,
		"selected_policy_id": expected_policy_id,
		"selected_candidate_digest": expected_digest,
		"engine": engine_receipt,
		"authored_friction_values": _positive_friction_values(),
		"matrix_contract":
		{
			"authored_values_exact": authored_values_exact,
			"replication_exact": replication_exact,
			"counts_exact": counts_exact,
			"cold_boundary_exact": cold_boundary_exact,
			"cold_values_exact": cold_values_exact,
			"cold_seeds_exact": cold_seeds_exact,
			"cold_value_reservation_exact": cold_value_reservation_exact,
			"cold_seed_reservation_exact": cold_seed_reservation_exact,
			"bw5v_boundary_exact": bw5v_boundary_exact,
			"bw5v_validation_values_exact": bw5v_validation_values_exact,
			"bw5v_validation_seeds_exact": bw5v_validation_seeds_exact,
			"bw5v_cold_values_exact": bw5v_cold_values_exact,
			"bw5v_cold_seeds_exact": bw5v_cold_seeds_exact,
			"bw5c_boundary_exact": bw5c_boundary_exact,
			"bw5c_values_exact": bw5c_values_exact,
			"bw5c_seeds_exact": bw5c_seeds_exact,
			"bw5c_prior_sources_exact": bw5c_prior_sources_exact,
			"bw5c_later_validation_exact": bw5c_later_validation_exact,
			"steady_slide_rule_exact": steady_slide_rule_exact,
		},
		"fixture_receipts": fixture_receipts,
		"physical_outcome_opened": false,
		"development_data_only": not (_bw4_mode or _bw5c_mode),
		"cold_characterization": _bw4_mode or _bw5c_mode,
		"walking": false,
		"material_robustness": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
	}
	print(
		(
			BW5C_PREFLIGHT_PREFIX
			if _bw5c_mode
			else (
				BW5V_PREFLIGHT_PREFIX
				if _bw5v_mode
				else (
					BW4_PREFLIGHT_PREFIX
					if _bw4_mode
					else (
						BW3R_PREFLIGHT_PREFIX
						if _bw3r_mode
						else BW3_PREFLIGHT_PREFIX
					)
				)
			)
		),
		JSON.stringify(receipt, "", true, true),
	)


func _build_rig(
		clock,
		profile: Dictionary,
		friction: float) -> Dictionary:
	if _bw20f_mode:
		return RigScript.build_bw20f(clock, profile, friction)
	if _bw5c_mode:
		return RigScript.build_bw5c(clock, profile, friction)
	if _bw5v_mode:
		return RigScript.build_bw5v(clock, profile, friction)
	if _bw4_mode:
		return RigScript.build_bw4(clock, profile, friction)
	if _bw3r_mode:
		return RigScript.build_bw3r(clock, profile, friction)
	if _bw3_mode:
		return RigScript.build_bw3(clock, profile, friction)
	return RigScript.build(clock, profile, friction)


func _positive_friction_values() -> Array:
	if _bw20f_mode:
		return BW20F_POSITIVE_FRICTION_VALUES.duplicate()
	if _bw5c_mode:
		return BW5C_POSITIVE_FRICTION_VALUES.duplicate()
	if _bw5v_mode:
		return BW5V_POSITIVE_FRICTION_VALUES.duplicate()
	if _bw4_mode:
		return BW4_POSITIVE_FRICTION_VALUES.duplicate()
	if _bw3r_mode:
		return BW3R_POSITIVE_FRICTION_VALUES.duplicate()
	if _bw3_mode:
		return BW3_POSITIVE_FRICTION_VALUES.duplicate()
	return POSITIVE_FRICTION_VALUES.duplicate()


func _authored_friction_values() -> Array:
	if _bw20f_mode:
		return RigScript.BW20F_AUTHORED_FRICTION_VALUES.duplicate()
	if _bw5c_mode:
		return RigScript.BW5C_AUTHORED_FRICTION_VALUES.duplicate()
	if _bw5v_mode:
		return RigScript.BW5V_AUTHORED_FRICTION_VALUES.duplicate()
	if _bw4_mode:
		return RigScript.BW4_AUTHORED_FRICTION_VALUES.duplicate()
	if _bw3r_mode:
		return RigScript.BW3R_AUTHORED_FRICTION_VALUES.duplicate()
	if _bw3_mode:
		return RigScript.BW3_AUTHORED_FRICTION_VALUES.duplicate()
	return RigScript.AUTHORED_FRICTION_VALUES.duplicate()


func _fixture_id() -> String:
	if _bw20f_mode:
		return RigScript.BW20F_FIXTURE_ID
	if _bw5c_mode:
		return RigScript.BW5C_FIXTURE_ID
	if _bw5v_mode:
		return RigScript.BW5V_FIXTURE_ID
	if _bw4_mode:
		return RigScript.BW4_FIXTURE_ID
	if _bw3r_mode:
		return RigScript.BW3R_FIXTURE_ID
	return RigScript.BW3_FIXTURE_ID if _bw3_mode else RigScript.FIXTURE_ID


func _receipt_schema_version() -> String:
	if _bw20f_mode:
		return BW20F_RECEIPT_SCHEMA_VERSION
	if _bw5c_mode:
		return BW5C_RECEIPT_SCHEMA_VERSION
	if _bw5v_mode:
		return BW5V_RECEIPT_SCHEMA_VERSION
	if _bw4_mode:
		return BW4_RECEIPT_SCHEMA_VERSION
	if _bw3r_mode:
		return BW3R_RECEIPT_SCHEMA_VERSION
	return BW3_RECEIPT_SCHEMA_VERSION if _bw3_mode else RECEIPT_SCHEMA_VERSION


func _receipt_prefix() -> String:
	if _bw20f_mode:
		return BW20F_RECEIPT_PREFIX
	if _bw5c_mode:
		return BW5C_RECEIPT_PREFIX
	if _bw5v_mode:
		return BW5V_RECEIPT_PREFIX
	if _bw4_mode:
		return BW4_RECEIPT_PREFIX
	if _bw3r_mode:
		return BW3R_RECEIPT_PREFIX
	return BW3_RECEIPT_PREFIX if _bw3_mode else RECEIPT_PREFIX


func _expected_world_count() -> int:
	if _bw4_mode or _bw5c_mode or _bw20f_mode:
		return BW4_EXPECTED_WORLD_COUNT
	return (
		BW3_EXPECTED_WORLD_COUNT
		if _bw3_mode or _bw3r_mode or _bw5v_mode
		else EXPECTED_WORLD_COUNT
	)


func _expected_gate_count() -> int:
	if _bw4_mode or _bw5c_mode or _bw20f_mode:
		return BW4_EXPECTED_GATE_COUNT
	return (
		BW3_EXPECTED_GATE_COUNT
		if _bw3_mode or _bw3r_mode or _bw5v_mode
		else EXPECTED_GATE_COUNT
	)


func _campaign_label() -> String:
	if _bw20f_mode:
		return "BW20F BW19V-B cold material characterization"
	if _bw5c_mode:
		return "BW5C cold material characterization"
	if _bw5v_mode:
		return "BW5V independent-validation material characterization"
	if _bw4_mode:
		return "BW4 cold material characterization"
	if _bw3r_mode:
		return "BW3R material characterization"
	if _bw3_mode:
		return "BW3 material characterization"
	return "P5M.1-R1 friction ladder characterization"


static func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}


static func _has_configuration_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("configuration_errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


static func _engine_receipt() -> Dictionary:
	return {
		"physics_engine": String(
			ProjectSettings.get_setting("physics/3d/physics_engine", "")
		),
		"godot_runtime_version": String(
			Engine.get_version_info().get("string", "")
		),
		"physics_hz": Engine.physics_ticks_per_second,
		"solver_velocity_steps":
		int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps":
		int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
	}


static func _vector(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK Godot/Jolt %s summary: %d passed, %d failed"
		% [_campaign_label(), _passed, _failed],
	)
	quit(0 if _failed == 0 else 1)
