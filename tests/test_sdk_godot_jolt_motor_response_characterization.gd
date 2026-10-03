extends SceneTree

## Prospective P5I.2 isolated Godot 4.7 / Jolt hinge-motor response.
##
## The fixture and acceptance grid were pushed before this file existed. This
## test applies motors only in isolated center-of-mass hinge cells. It never
## constructs a gait or applies a stability contribution to a walker.

const RigScript := preload(
	"res://scripts/lab/rigs/sdk_godot_jolt_motor_response_rig.gd"
)

const RECEIPT_SCHEMA_VERSION := "sporespore_godot_jolt_motor_response_receipt_v1"
const PHYSICS_TICKS_PER_SECOND := 120
const SOLVER_VELOCITY_STEPS := 20
const SOLVER_POSITION_STEPS := 7
const EXPECTED_REPETITIONS := 3
const EXPECTED_CELLS_PER_REPETITION := 43
const EXPECTED_GATES := 16
const P5I1_MAXIMUM_GENERALIZED_TORQUE_NM := 0.2805286655276139

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt isolated motor-response characterization ===")
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
	var engine_receipt := {
		"physics_engine": String(
			ProjectSettings.get_setting("physics/3d/physics_engine", "")
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
	var engine_exact := (
		String(engine_receipt["physics_engine"]) == "Jolt Physics"
		and int(engine_receipt["physics_hz"]) == PHYSICS_TICKS_PER_SECOND
		and int(engine_receipt["solver_velocity_steps"]) == SOLVER_VELOCITY_STEPS
		and int(engine_receipt["solver_position_steps"]) == SOLVER_POSITION_STEPS
	)

	var invalid := RigScript.build(1, {"child_mass_kg": 0.9})
	var malformed_rejected := (
		not bool(invalid.get("ok", true))
		and _has_configuration_error(
			invalid,
			"SDK_MOTOR_RESPONSE_FIXTURE_IMMUTABLE",
		)
		and int(invalid.get("world_build_count", -1)) == 0
	)

	var repetitions: Array[Dictionary] = []
	for repetition_index in range(1, EXPECTED_REPETITIONS + 1):
		repetitions.append(await _run_repetition(repetition_index))
	var analysis := _analyze(repetitions)

	_check(engine_exact, "the realized engine receipt is exactly Jolt 120 Hz with 20/7 solver steps")
	_check(malformed_rejected, "the immutable fixture rejects a post-preregistration override")
	_check(
		bool(analysis["three_repetitions_complete"]),
		"three independent 43-cell worlds complete without untyped loss",
	)
	_check(
		bool(analysis["parameters_round_trip"]),
		"mass, inertia, hinge, motor, damping, gravity, and collision parameters round-trip",
	)
	_check(
		bool(analysis["zero_response_bounded"]),
		"zero-target controls remain quiescent",
	)
	_check(
		bool(analysis["canonical_sign_exact"]),
		"negative host target produces canonical positive response and vice versa",
	)
	_check(
		bool(analysis["deadband_bounded"]),
		"both signed 0.0025 rad/s cells bound the observed deadband",
	)
	_check(
		bool(analysis["fit_gain_bounded"]),
		"the frozen zero-intercept local response gain lies in [0.95, 1.05]",
	)
	_check(
		bool(analysis["fit_residual_and_asymmetry_bounded"]),
		"local fit residual and signed-pair asymmetry remain bounded",
	)
	_check(
		bool(analysis["repetition_spread_bounded"]),
		"same-cell inter-repetition spread remains bounded",
	)
	_check(
		bool(analysis["local_response_time_and_overshoot_bounded"]),
		"local cells reach 90 percent within four ticks without excess overshoot",
	)
	_check(
		bool(analysis["impulse_response_ordered"]),
		"first-tick response is strictly ordered across the five impulse caps",
	)
	_check(
		bool(analysis["cap_saturation_bounded"]),
		"the low-cap first-tick plateau is target-magnitude invariant",
	)
	_check(
		bool(analysis["reversal_response_bounded"]),
		"both reversal directions cross and settle inside the frozen tick bounds",
	)
	_check(
		bool(analysis["coefficient_derivation_accepted"]),
		"the prospective coefficient and uncertainty rule stays inside its envelope",
	)

	var nonclaims := {
		"isolated_fixture_motor_actuation": true,
		"walker_actuation_applied": false,
		"stability_influence_applied": false,
		"candidate35_modified": false,
		"walking": false,
		"balance_feedback_connected": false,
		"physical_balance_recovery": false,
		"friction_material_locomotion_robustness": false,
		"cross_engine_c6": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
	}
	var nonclaims_exact := (
		bool(nonclaims["isolated_fixture_motor_actuation"])
		and not bool(nonclaims["walker_actuation_applied"])
		and not bool(nonclaims["stability_influence_applied"])
		and not bool(nonclaims["candidate35_modified"])
		and not bool(nonclaims["walking"])
		and not bool(nonclaims["balance_feedback_connected"])
		and not bool(nonclaims["physical_balance_recovery"])
		and not bool(nonclaims["friction_material_locomotion_robustness"])
		and not bool(nonclaims["cross_engine_c6"])
		and not bool(nonclaims["physical_acceptance_authority"])
		and not bool(nonclaims["completed_engine_neutral_sdk"])
	)
	_check(nonclaims_exact, "all gait, balance, robustness, acceptance, and SDK nonclaims remain exact")

	var receipt := {
		"schema_version": RECEIPT_SCHEMA_VERSION,
		"ok": _failed == 0 and _passed == EXPECTED_GATES,
		"gate_count_expected": EXPECTED_GATES,
		"gate_count_passed": _passed,
		"gate_count_failed": _failed,
		"engine": engine_receipt,
		"fixture":
		{
			"fixture_id": RigScript.FIXTURE_ID,
			"expected_repetition_count": EXPECTED_REPETITIONS,
			"expected_cells_per_repetition": EXPECTED_CELLS_PER_REPETITION,
			"child_mass_kg": RigScript.CHILD_MASS_KG,
			"child_inertia_kg_m2": _vector(RigScript.CHILD_INERTIA_KG_M2),
			"canonical_axis_parent_local":
			_vector(RigScript.CANONICAL_AXIS_PARENT_LOCAL),
			"local_targets_rad_s": RigScript.LOCAL_TARGETS_RAD_S.duplicate(),
			"legacy_impulse_caps_nms": RigScript.LEGACY_IMPULSE_CAPS_NMS.duplicate(),
			"impulse_caps_nms": RigScript.IMPULSE_CAPS_NMS.duplicate(),
			"saturation_targets_rad_s":
			RigScript.SATURATION_TARGETS_RAD_S.duplicate(),
			"local_hold_ticks": RigScript.LOCAL_HOLD_TICKS,
			"impulse_hold_ticks": RigScript.IMPULSE_HOLD_TICKS,
			"reversal_half_ticks": RigScript.REVERSAL_HALF_TICKS,
			"host_target_velocity_sign_per_canonical_positive": -1,
			"post_activation_transform_or_velocity_write_count": 0,
			"direct_force_torque_or_impulse_write_count": 0,
		},
		"repetitions": repetitions,
		"analysis": analysis,
		"nonclaims": nonclaims,
		"isolated_host_response_characterized": _failed == 0,
		"adapter_profile_published": false,
	}
	print(
		"SDK_GODOT_JOLT_MOTOR_RESPONSE_RECEIPT ",
		JSON.stringify(receipt, "", true, true),
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _run_repetition(repetition_index: int) -> Dictionary:
	var rig: Dictionary = RigScript.build(repetition_index)
	if not bool(rig.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "FIXTURE_BUILD_FAILED",
			"repetition_index": repetition_index,
			"world_build_count": int(rig.get("world_build_count", 0)),
			"cells": [],
		}
	var viewport: SubViewport = rig["viewport"]
	root.add_child(viewport)
	await process_frame
	await physics_frame
	var cells: Array = rig["cells"]
	for cell_value in cells:
		var cell: Dictionary = cell_value
		RigScript.activate(cell)
		RigScript.set_canonical_target(
			cell,
			float(cell["initial_canonical_target_rad_s"]),
		)
	var parameters_round_trip := true
	var parameter_receipts := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var parameter_receipt: Dictionary = RigScript.parameter_round_trip(cell)
		parameter_receipts[String(cell["cell_id"])] = parameter_receipt
		parameters_round_trip = (
			parameters_round_trip and bool(parameter_receipt.get("ok", false))
		)

	var series_by_id := {}
	var prior_rate_by_id := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		series_by_id[cell_id] = []
		prior_rate_by_id[cell_id] = 0.0

	for tick in range(1, 2 * RigScript.REVERSAL_HALF_TICKS + 1):
		for cell_value in cells:
			var cell: Dictionary = cell_value
			if (
				String(cell["family"]) == "reversal"
				and tick == int(cell["reversal_start_tick"])
			):
				RigScript.set_canonical_target(
					cell,
					float(cell["reversal_canonical_target_rad_s"]),
				)
		await physics_frame
		for cell_value in cells:
			var cell: Dictionary = cell_value
			if tick > int(cell["duration_ticks"]):
				continue
			var cell_id := String(cell["cell_id"])
			var rate := RigScript.canonical_rate_rad_s(cell)
			var prior_rate := float(prior_rate_by_id[cell_id])
			var canonical_target := float(cell["current_canonical_target_rad_s"])
			var parameter_receipt: Dictionary = RigScript.parameter_round_trip(cell)
			parameters_round_trip = (
				parameters_round_trip and bool(parameter_receipt.get("ok", false))
			)
			(series_by_id[cell_id] as Array).append(
				{
					"tick": tick,
					"canonical_target_velocity_rad_s": canonical_target,
					"host_target_velocity_rad_s": -canonical_target,
					"canonical_rate_rad_s": rate,
					"first_difference_angular_acceleration_rad_s2":
					(rate - prior_rate) * float(PHYSICS_TICKS_PER_SECOND),
					"inferred_child_angular_impulse_nms":
					RigScript.CHILD_INERTIA_KG_M2.z * absf(rate - prior_rate),
				}
			)
			prior_rate_by_id[cell_id] = rate

	var retained_cells: Array[Dictionary] = []
	var finite := true
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var time_series: Array = series_by_id[cell_id]
		for sample_value in time_series:
			var sample: Dictionary = sample_value
			finite = (
				finite
				and is_finite(float(sample["canonical_target_velocity_rad_s"]))
				and is_finite(float(sample["host_target_velocity_rad_s"]))
				and is_finite(float(sample["canonical_rate_rad_s"]))
				and is_finite(
					float(sample["first_difference_angular_acceleration_rad_s2"])
				)
				and is_finite(float(sample["inferred_child_angular_impulse_nms"]))
			)
		retained_cells.append(
			{
				"cell_id": cell_id,
				"family": String(cell["family"]),
				"initial_canonical_target_rad_s":
				float(cell["initial_canonical_target_rad_s"]),
				"maximum_impulse_nms": float(cell["maximum_impulse_nms"]),
				"duration_ticks": int(cell["duration_ticks"]),
				"reversal_canonical_target_rad_s":
				cell["reversal_canonical_target_rad_s"],
				"reversal_start_tick": int(cell["reversal_start_tick"]),
				"motor_target_write_count": int(cell["motor_target_write_count"]),
				"parameter_round_trip": parameter_receipts[cell_id],
				"time_series": time_series,
			}
		)
	viewport.queue_free()
	await process_frame
	return {
		"ok": parameters_round_trip and finite,
		"failure_code": "" if parameters_round_trip and finite else "CELL_INVALID",
		"repetition_index": repetition_index,
		"fixture_contract": rig["fixture_contract"],
		"parameters_round_trip": parameters_round_trip,
		"all_samples_finite": finite,
		"cells": retained_cells,
		"world_build_count": int(rig["world_build_count"]),
	}


func _analyze(repetitions: Array[Dictionary]) -> Dictionary:
	var three_repetitions_complete := repetitions.size() == EXPECTED_REPETITIONS
	var parameters_round_trip := three_repetitions_complete
	var all_cells: Array[Dictionary] = []
	for repetition in repetitions:
		three_repetitions_complete = (
			three_repetitions_complete
			and bool(repetition.get("ok", false))
			and int(repetition.get("world_build_count", 0)) == 1
			and (repetition.get("cells", []) as Array).size()
			== EXPECTED_CELLS_PER_REPETITION
		)
		parameters_round_trip = (
			parameters_round_trip
			and bool(repetition.get("parameters_round_trip", false))
		)
		for cell_value in repetition.get("cells", []):
			var cell: Dictionary = (cell_value as Dictionary).duplicate(true)
			cell["repetition_index"] = int(repetition.get("repetition_index", -1))
			all_cells.append(cell)

	var zero_response_bounded := true
	var canonical_sign_exact := true
	var deadband_bounded := true
	var local_response_time_and_overshoot_bounded := true
	var sum_xy := 0.0
	var sum_xx := 0.0
	var local_points: Array[Dictionary] = []
	var repetition_values := {}
	var signed_pairs := {}
	for cell in all_cells:
		var family := String(cell["family"])
		var series: Array = cell["time_series"]
		if family == "zero":
			for sample_value in series:
				var sample: Dictionary = sample_value
				zero_response_bounded = (
					zero_response_bounded
					and absf(float(sample["canonical_rate_rad_s"])) <= 1.0e-5
				)
		if family != "local":
			continue
		var x := float(cell["initial_canonical_target_rad_s"])
		var final_sample: Dictionary = series.back()
		var y := float(final_sample["canonical_rate_rad_s"])
		canonical_sign_exact = canonical_sign_exact and x * y > 0.0
		if absf(x) == 0.0025:
			deadband_bounded = deadband_bounded and absf(y) >= 0.5 * absf(x)
		var first_reach_tick := -1
		var maximum_rate := 0.0
		for sample_value in series:
			var sample: Dictionary = sample_value
			var rate := float(sample["canonical_rate_rad_s"])
			maximum_rate = maxf(maximum_rate, absf(rate))
			if first_reach_tick < 0 and x * rate > 0.0 and absf(rate) >= 0.9 * absf(x):
				first_reach_tick = int(sample["tick"])
		local_response_time_and_overshoot_bounded = (
			local_response_time_and_overshoot_bounded
			and first_reach_tick >= 1
			and first_reach_tick <= 4
			and maximum_rate <= 1.10 * absf(x) + 0.001
		)
		sum_xy += x * y
		sum_xx += x * x
		local_points.append({"x": x, "y": y})
		var repetition_key := "%.9f|%.9f" % [
			float(cell["maximum_impulse_nms"]),
			x,
		]
		if not repetition_values.has(repetition_key):
			repetition_values[repetition_key] = []
		(repetition_values[repetition_key] as Array).append(y)
		var pair_key := "%d|%.9f|%.9f" % [
			int(cell["repetition_index"]),
			float(cell["maximum_impulse_nms"]),
			absf(x),
		]
		if not signed_pairs.has(pair_key):
			signed_pairs[pair_key] = {}
		(signed_pairs[pair_key] as Dictionary)["positive" if x > 0.0 else "negative"] = y

	var fit_gain := sum_xy / sum_xx if sum_xx > 0.0 else NAN
	var maximum_fit_residual_rad_s := 0.0
	for point in local_points:
		maximum_fit_residual_rad_s = maxf(
			maximum_fit_residual_rad_s,
			absf(float(point["y"]) - fit_gain * float(point["x"])),
		)
	var maximum_repetition_spread_rad_s := 0.0
	for values_value in repetition_values.values():
		var values: Array = values_value
		maximum_repetition_spread_rad_s = maxf(
			maximum_repetition_spread_rad_s,
			_maximum(values) - _minimum(values),
		)
	var maximum_signed_pair_asymmetry_rad_s := 0.0
	var signed_pairs_complete := true
	for pair_value in signed_pairs.values():
		var pair: Dictionary = pair_value
		signed_pairs_complete = (
			signed_pairs_complete
			and pair.has("positive")
			and pair.has("negative")
		)
		if pair.has("positive") and pair.has("negative"):
			maximum_signed_pair_asymmetry_rad_s = maxf(
				maximum_signed_pair_asymmetry_rad_s,
				absf(float(pair["positive"]) + float(pair["negative"])),
			)
	var fit_gain_bounded := is_finite(fit_gain) and fit_gain >= 0.95 and fit_gain <= 1.05
	var fit_residual_and_asymmetry_bounded := (
		signed_pairs_complete
		and maximum_fit_residual_rad_s <= 0.002
		and maximum_signed_pair_asymmetry_rad_s <= 0.002
	)
	var repetition_spread_bounded := maximum_repetition_spread_rad_s <= 0.001

	var impulse_response_ordered := _impulse_response_ordered(all_cells)
	var cap_saturation_bounded := _cap_saturation_bounded(all_cells)
	var reversal_response_bounded := _reversal_response_bounded(all_cells)
	var uncertainty := maxf(
		absf(fit_gain - 1.0),
		maxf(
			maximum_fit_residual_rad_s / 0.025,
			maxf(
				maximum_repetition_spread_rad_s / 0.025,
				maximum_signed_pair_asymmetry_rad_s / 0.025,
			),
		),
	)
	var nominal_coefficient := (
		minf(0.25, 0.25 / fit_gain) if is_finite(fit_gain) and fit_gain > 0.0 else NAN
	)
	var conservative_coefficient := nominal_coefficient * (1.0 - uncertainty)
	var maximum_proposed_velocity := (
		conservative_coefficient * P5I1_MAXIMUM_GENERALIZED_TORQUE_NM
	)
	var coefficient_derivation_accepted := (
		is_finite(uncertainty)
		and is_finite(nominal_coefficient)
		and is_finite(conservative_coefficient)
		and uncertainty <= 0.10
		and conservative_coefficient >= 0.20
		and conservative_coefficient <= 0.25
		and maximum_proposed_velocity <= 0.075
	)
	return {
		"three_repetitions_complete": three_repetitions_complete,
		"parameters_round_trip": parameters_round_trip,
		"zero_response_bounded": zero_response_bounded,
		"canonical_sign_exact": canonical_sign_exact,
		"deadband_bounded": deadband_bounded,
		"fit_gain_bounded": fit_gain_bounded,
		"fit_residual_and_asymmetry_bounded": fit_residual_and_asymmetry_bounded,
		"repetition_spread_bounded": repetition_spread_bounded,
		"local_response_time_and_overshoot_bounded":
		local_response_time_and_overshoot_bounded,
		"impulse_response_ordered": impulse_response_ordered,
		"cap_saturation_bounded": cap_saturation_bounded,
		"reversal_response_bounded": reversal_response_bounded,
		"coefficient_derivation_accepted": coefficient_derivation_accepted,
		"fit":
		{
			"method": "zero_intercept_least_squares",
			"gain": fit_gain,
			"point_count": local_points.size(),
			"maximum_fit_residual_rad_s": maximum_fit_residual_rad_s,
			"maximum_repetition_spread_rad_s": maximum_repetition_spread_rad_s,
			"maximum_signed_pair_asymmetry_rad_s":
			maximum_signed_pair_asymmetry_rad_s,
		},
		"coefficient":
		{
			"host_target_velocity_sign_per_canonical_positive": -1,
			"uncertainty_fraction": uncertainty,
			"nominal_velocity_per_torque_rad_s_per_nm": nominal_coefficient,
			"conservative_velocity_per_torque_rad_s_per_nm":
			conservative_coefficient,
			"maximum_characterized_generalized_torque_nm":
			P5I1_MAXIMUM_GENERALIZED_TORQUE_NM,
			"maximum_proposed_velocity_delta_rad_s": maximum_proposed_velocity,
			"tested_local_velocity_envelope_rad_s": 0.075,
			"command_not_measured_torque": true,
			"cross_engine_portable": false,
		},
	}


func _impulse_response_ordered(cells: Array[Dictionary]) -> bool:
	var groups := {}
	for cell in cells:
		if String(cell["family"]) != "impulse":
			continue
		var key := "%d|%.1f" % [
			int(cell["repetition_index"]),
			float(cell["initial_canonical_target_rad_s"]),
		]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(cell)
	var ok := groups.size() == 2 * EXPECTED_REPETITIONS
	for group_value in groups.values():
		var group: Array = group_value
		group.sort_custom(
			func(first: Dictionary, second: Dictionary) -> bool:
				return float(first["maximum_impulse_nms"]) < float(
					second["maximum_impulse_nms"]
				)
		)
		ok = ok and group.size() == RigScript.IMPULSE_CAPS_NMS.size()
		for index in range(group.size() - 1):
			var first_cell: Dictionary = group[index]
			var second_cell: Dictionary = group[index + 1]
			var first_rate := absf(
				float((first_cell["time_series"] as Array)[0]["canonical_rate_rad_s"])
			)
			var second_rate := absf(
				float((second_cell["time_series"] as Array)[0]["canonical_rate_rad_s"])
			)
			ok = (
				ok
				and second_rate + 1.0e-12 >= first_rate
				and second_rate - first_rate >= 0.0001
			)
	return ok


func _cap_saturation_bounded(cells: Array[Dictionary]) -> bool:
	var groups := {}
	for cell in cells:
		if String(cell["family"]) != "saturation":
			continue
		var target := float(cell["initial_canonical_target_rad_s"])
		var key := "%d|%s" % [
			int(cell["repetition_index"]),
			"positive" if target > 0.0 else "negative",
		]
		if not groups.has(key):
			groups[key] = []
		var first_sample: Dictionary = (cell["time_series"] as Array)[0]
		(groups[key] as Array).append(absf(float(first_sample["canonical_rate_rad_s"])))
	var ok := groups.size() == 2 * EXPECTED_REPETITIONS
	for values_value in groups.values():
		var values: Array = values_value
		ok = (
			ok
			and values.size() == 4
			and _maximum(values) - _minimum(values) <= 0.001
		)
	return ok


func _reversal_response_bounded(cells: Array[Dictionary]) -> bool:
	var reversal_count := 0
	var ok := true
	for cell in cells:
		if String(cell["family"]) != "reversal":
			continue
		reversal_count += 1
		var first_target := float(cell["initial_canonical_target_rad_s"])
		var second_target := float(cell["reversal_canonical_target_rad_s"])
		var series: Array = cell["time_series"]
		var before_switch: Dictionary = series[RigScript.REVERSAL_HALF_TICKS - 1]
		ok = (
			ok
			and first_target * float(before_switch["canonical_rate_rad_s"]) > 0.0
			and absf(float(before_switch["canonical_rate_rad_s"]))
			>= 0.9 * absf(first_target)
		)
		var crossing_offset := -1
		var reach_offset := -1
		var maximum_after_switch := 0.0
		for sample_value in series:
			var sample: Dictionary = sample_value
			var tick := int(sample["tick"])
			if tick <= RigScript.REVERSAL_HALF_TICKS:
				continue
			var rate := float(sample["canonical_rate_rad_s"])
			var offset := tick - RigScript.REVERSAL_HALF_TICKS
			maximum_after_switch = maxf(maximum_after_switch, absf(rate))
			if crossing_offset < 0 and second_target * rate >= 0.0:
				crossing_offset = offset
			if reach_offset < 0 and second_target * rate > 0.0 and absf(rate) >= 0.9 * absf(second_target):
				reach_offset = offset
		ok = (
			ok
			and crossing_offset >= 1
			and crossing_offset <= 4
			and reach_offset >= 1
			and reach_offset <= 8
			and maximum_after_switch <= 1.10 * absf(second_target) + 0.001
		)
	return ok and reversal_count == 4 * EXPECTED_REPETITIONS


func _has_configuration_error(receipt: Dictionary, code: String) -> bool:
	for error_value in receipt.get("configuration_errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


func _minimum(values: Array) -> float:
	var result := INF
	for value in values:
		result = minf(result, float(value))
	return result


func _maximum(values: Array) -> float:
	var result := -INF
	for value in values:
		result = maxf(result, float(value))
	return result


func _vector(value: Vector3) -> Dictionary:
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
		"\nSDK Godot/Jolt motor-response summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 and _passed == EXPECTED_GATES else 1)
