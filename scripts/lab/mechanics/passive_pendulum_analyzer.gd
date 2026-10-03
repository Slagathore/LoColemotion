class_name LabPassivePendulumAnalyzer
extends RefCounted

## L2.0 fixed-base passive-pendulum contract.
##
## This analyzer owns the analytic rigid-link oracle and refuses hidden motors,
## limits, contact, external torque, interpolation, and unknown configuration
## fields. It establishes passive joint truth only; it has no actuator or
## creature-support semantics.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "passive_pendulum_analysis_v1"
const CONFIGURATION_SCHEMA_VERSION := "passive_pendulum_configuration_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"trial_id",
	"physics_hz",
	"duration_s",
	"mass_kg",
	"link_width_m",
	"link_length_m",
	"link_depth_m",
	"pivot_to_com_m",
	"gravity_m_s2",
	"initial_angle_rad",
	"angular_damp_s_inv",
	"damping_class",
	"parent_mode",
	"motor_enabled",
	"limit_enabled",
	"external_torque_enabled",
	"contact_enabled",
]
const VALID_DAMPING_CLASSES := [
	"undamped_control",
	"damped_comparison",
]


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected_keys: Array = REQUIRED_FIELDS.duplicate()
	expected_keys.sort()
	if keys != expected_keys:
		errors.append("CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("CONFIGURATION_SCHEMA_UNSUPPORTED")
	var trial_id := String(configuration.get("trial_id", ""))
	if not _is_stable_id(trial_id):
		errors.append("TRIAL_ID_INVALID")
	var physics_hz := _exact_positive_integer(configuration.get("physics_hz"))
	if physics_hz < 60 or physics_hz > 240:
		errors.append("PHYSICS_HZ_OUTSIDE_DECLARED_RANGE")
	var duration_s := float(configuration.get("duration_s", NAN))
	if not is_finite(duration_s) or duration_s < 4.0 or duration_s > 12.0:
		errors.append("DURATION_OUTSIDE_DECLARED_RANGE")
	var mass_kg := float(configuration.get("mass_kg", NAN))
	var width_m := float(configuration.get("link_width_m", NAN))
	var length_m := float(configuration.get("link_length_m", NAN))
	var depth_m := float(configuration.get("link_depth_m", NAN))
	var pivot_to_com_m := float(configuration.get("pivot_to_com_m", NAN))
	var gravity_m_s2 := float(configuration.get("gravity_m_s2", NAN))
	var initial_angle_rad := float(configuration.get("initial_angle_rad", NAN))
	var angular_damp := float(configuration.get("angular_damp_s_inv", NAN))
	for measurement in [
		mass_kg,
		width_m,
		length_m,
		depth_m,
		pivot_to_com_m,
		gravity_m_s2,
	]:
		if not is_finite(float(measurement)) or float(measurement) <= 0.0:
			errors.append("NONPOSITIVE_PHYSICAL_PARAMETER")
			break
	if (
		is_finite(length_m)
		and is_finite(pivot_to_com_m)
		and absf(pivot_to_com_m - 0.5 * length_m) > 1.0e-9
	):
		errors.append("PIVOT_NOT_AT_LINK_END")
	if (
		not is_finite(initial_angle_rad)
		or absf(initial_angle_rad) < 0.1
		or absf(initial_angle_rad) > 0.3
	):
		errors.append("INITIAL_ANGLE_OUTSIDE_SMALL_ANGLE_FIXTURE")
	if not is_finite(angular_damp) or angular_damp < 0.0 or angular_damp > 2.0:
		errors.append("ANGULAR_DAMP_OUTSIDE_DECLARED_RANGE")
	var damping_class := String(configuration.get("damping_class", ""))
	if damping_class not in VALID_DAMPING_CLASSES:
		errors.append("DAMPING_CLASS_INVALID")
	elif damping_class == "undamped_control" and angular_damp != 0.0:
		errors.append("UNDAMPED_CONTROL_HAS_DAMPING")
	elif damping_class == "damped_comparison" and angular_damp < 0.2:
		errors.append("DAMPED_COMPARISON_TOO_WEAK")
	if String(configuration.get("parent_mode", "")) != "fixed_static":
		errors.append("PARENT_MODE_NOT_FIXED_STATIC")
	for forbidden_flag in [
		"motor_enabled",
		"limit_enabled",
		"external_torque_enabled",
		"contact_enabled",
	]:
		if configuration.get(forbidden_flag) != false:
			errors.append("%s_FORBIDDEN" % forbidden_flag.to_upper())
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "PASSIVE_PENDULUM_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var inertia_com_kg_m2 := mass_kg * (width_m * width_m + length_m * length_m) / 12.0
	var inertia_pivot_kg_m2 := inertia_com_kg_m2 + mass_kg * pivot_to_com_m * pivot_to_com_m
	var small_angle_period_s := (
		TAU * sqrt(inertia_pivot_kg_m2 / (mass_kg * gravity_m_s2 * pivot_to_com_m))
	)
	var payload := configuration.duplicate(true)
	payload["expected_sample_count"] = roundi(duration_s * physics_hz)
	payload["inertia_com_axis_kg_m2"] = inertia_com_kg_m2
	payload["inertia_pivot_axis_kg_m2"] = inertia_pivot_kg_m2
	payload["analytic_small_angle_period_s"] = small_angle_period_s
	payload["claim_boundary"] = (
		"Exact fixed-base passive hinge fixture only; no actuator, load-bearing, "
		+ "standing, bracing, recovery, gait, or walking claim."
	)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {
		"ok": true,
		"contract": FrozenValueScript.snapshot(payload),
	}


static func analyze(contract: Dictionary, samples: Array) -> Dictionary:
	var contract_check := _verify_contract(contract)
	if not bool(contract_check.get("ok", false)):
		return contract_check
	var expected_count := int(contract["expected_sample_count"])
	if samples.size() != expected_count:
		return _failure(
			"PASSIVE_PENDULUM_SAMPLE_COUNT_MISMATCH",
			"Trial does not contain the preregistered sample count."
		)
	var previous_time := -INF
	var max_anchor_error_m := 0.0
	var max_axis_error_rad := 0.0
	var max_swing_rad := 0.0
	var max_off_axis_rate_rad_s := 0.0
	var downward_crossings_s: Array[float] = []
	var energies: Array[float] = []
	var angles: Array[float] = []
	var rates: Array[float] = []
	var step_s := 1.0 / float(contract["physics_hz"])
	for index in range(samples.size()):
		if not samples[index] is Dictionary:
			return _failure(
				"PASSIVE_PENDULUM_SAMPLE_INVALID", "Every pendulum sample must be one dictionary."
			)
		var sample: Dictionary = samples[index]
		for field in [
			"time_s",
			"angle_rad",
			"axis_rate_rad_s",
			"anchor_error_m",
			"axis_error_rad",
			"swing_residual_rad",
			"off_axis_rate_rad_s",
		]:
			var value: Variant = sample.get(field)
			if not (value is float or value is int) or not is_finite(float(value)):
				return _failure(
					"PASSIVE_PENDULUM_SAMPLE_NONFINITE",
					"Sample contains a missing or nonfinite channel.",
					{"sample": index, "field": field}
				)
		var time_s := float(sample["time_s"])
		var expected_time_s := float(index + 1) * step_s
		if absf(time_s - expected_time_s) > 1.0e-8:
			return _failure(
				"PASSIVE_PENDULUM_SAMPLE_SCHEDULE_MISMATCH",
				"Sample time does not match the sealed physics-step schedule.",
				{
					"sample": index,
					"expected_time_s": expected_time_s,
					"actual_time_s": time_s,
				}
			)
		if time_s <= previous_time:
			return _failure(
				"PASSIVE_PENDULUM_TIME_NOT_MONOTONIC", "Sample time must increase strictly."
			)
		previous_time = time_s
		for error_field in [
			"anchor_error_m",
			"axis_error_rad",
			"swing_residual_rad",
			"off_axis_rate_rad_s",
		]:
			if float(sample[error_field]) < 0.0:
				return _failure(
					"PASSIVE_PENDULUM_ERROR_CHANNEL_NEGATIVE",
					"Norm and residual channels must be nonnegative.",
					{"sample": index, "field": error_field}
				)
		var angle := float(sample["angle_rad"])
		var rate := float(sample["axis_rate_rad_s"])
		angles.append(angle)
		rates.append(rate)
		max_anchor_error_m = maxf(max_anchor_error_m, float(sample["anchor_error_m"]))
		max_axis_error_rad = maxf(max_axis_error_rad, float(sample["axis_error_rad"]))
		max_swing_rad = maxf(max_swing_rad, float(sample["swing_residual_rad"]))
		max_off_axis_rate_rad_s = maxf(
			max_off_axis_rate_rad_s, float(sample["off_axis_rate_rad_s"])
		)
		energies.append(_mechanical_energy(contract, angle, rate))
		if index > 0:
			var previous: Dictionary = samples[index - 1]
			var previous_angle := float(previous["angle_rad"])
			if previous_angle > 0.0 and angle <= 0.0 and rate < 0.0:
				var fraction := previous_angle / (previous_angle - angle)
				downward_crossings_s.append(
					float(previous["time_s"]) + fraction * (time_s - float(previous["time_s"]))
				)
	if downward_crossings_s.size() < 2:
		return _failure(
			"PASSIVE_PENDULUM_PERIOD_UNAVAILABLE",
			"Trial does not contain two same-direction zero crossings."
		)
	var periods_s: Array[float] = []
	for index in range(1, downward_crossings_s.size()):
		periods_s.append(downward_crossings_s[index] - downward_crossings_s[index - 1])
	var mean_period_s := _mean(periods_s)
	var analytic_period_s := float(contract["analytic_small_angle_period_s"])
	var period_error_fraction := absf(mean_period_s - analytic_period_s) / analytic_period_s
	var initial_energy_j := float(energies[0])
	if initial_energy_j <= 0.0:
		return _failure(
			"PASSIVE_PENDULUM_INITIAL_ENERGY_INVALID", "Initial pendulum energy must be positive."
		)
	var energy_min_j := float(energies.min())
	var energy_max_j := float(energies.max())
	var energy_range_fraction := (energy_max_j - energy_min_j) / initial_energy_j
	var energy_final_fraction := float(energies[-1]) / initial_energy_j
	var half := samples.size() / 2
	var early_amplitude_rad := _max_abs(angles.slice(0, half))
	var late_amplitude_rad := _max_abs(angles.slice(half))
	var amplitude_retention_fraction := (
		late_amplitude_rad / early_amplitude_rad if early_amplitude_rad > 0.0 else INF
	)
	var damping_class := String(contract["damping_class"])
	var initial_angle_error_rad := absf(float(angles[0]) - float(contract["initial_angle_rad"]))
	var acceptance_failures: Array[String] = []
	if max_anchor_error_m > 5.0e-3:
		acceptance_failures.append("ANCHOR_ERROR_EXCEEDED")
	if max_axis_error_rad > 2.0e-2:
		acceptance_failures.append("AXIS_ERROR_EXCEEDED")
	if max_swing_rad > 2.0e-2:
		acceptance_failures.append("SWING_RESIDUAL_EXCEEDED")
	if max_off_axis_rate_rad_s > 5.0e-2:
		acceptance_failures.append("OFF_AXIS_RATE_EXCEEDED")
	if initial_angle_error_rad > 1.0e-2:
		acceptance_failures.append("INITIAL_ANGLE_MISMATCH")
	if float(rates[0]) >= 0.0:
		acceptance_failures.append("INITIAL_GRAVITY_DIRECTION_INVALID")
	if period_error_fraction > 0.05:
		acceptance_failures.append("PERIOD_ERROR_EXCEEDED")
	if damping_class == "undamped_control":
		if energy_range_fraction > 0.12:
			acceptance_failures.append("UNDAMPED_ENERGY_RANGE_EXCEEDED")
		if amplitude_retention_fraction < 0.88:
			acceptance_failures.append("UNDAMPED_AMPLITUDE_RETENTION_TOO_LOW")
	else:
		if energy_final_fraction > 0.45:
			acceptance_failures.append("DAMPED_FINAL_ENERGY_TOO_HIGH")
		if amplitude_retention_fraction > 0.75:
			acceptance_failures.append("DAMPED_AMPLITUDE_RETENTION_TOO_HIGH")
	var accepted := acceptance_failures.is_empty()
	var result := {
		"schema_version": SCHEMA_VERSION,
		"trial_id": contract["trial_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"damping_class": damping_class,
		"sample_count": samples.size(),
		"downward_crossings_s": downward_crossings_s,
		"measured_periods_s": periods_s,
		"mean_period_s": mean_period_s,
		"analytic_small_angle_period_s": analytic_period_s,
		"period_error_fraction": period_error_fraction,
		"max_anchor_error_m": max_anchor_error_m,
		"max_axis_error_rad": max_axis_error_rad,
		"max_swing_residual_rad": max_swing_rad,
		"max_off_axis_rate_rad_s": max_off_axis_rate_rad_s,
		"initial_energy_j": initial_energy_j,
		"energy_min_j": energy_min_j,
		"energy_max_j": energy_max_j,
		"energy_final_fraction": energy_final_fraction,
		"energy_range_fraction": energy_range_fraction,
		"early_amplitude_rad": early_amplitude_rad,
		"late_amplitude_rad": late_amplitude_rad,
		"amplitude_retention_fraction": amplitude_retention_fraction,
		"initial_measured_angle_rad": angles[0],
		"initial_angle_error_rad": initial_angle_error_rad,
		"initial_rate_rad_s": rates[0],
		"accepted": accepted,
		"acceptance_failures": acceptance_failures,
		"claim_boundary": contract["claim_boundary"],
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {
		"ok": true,
		"result": FrozenValueScript.snapshot(result),
	}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure(
				"PASSIVE_PENDULUM_CONTRACT_INCOMPLETE",
				"Contract is missing a source configuration field."
			)
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure(
			"PASSIVE_PENDULUM_CONTRACT_INVALID",
			"Contract source configuration is no longer admissible.",
			rebuilt
		)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure(
			"PASSIVE_PENDULUM_CONTRACT_DIGEST_MISMATCH",
			"Contract changed after configuration sealing."
		)
	return {"ok": true}


static func _mechanical_energy(contract: Dictionary, angle_rad: float, rate_rad_s: float) -> float:
	var kinetic := 0.5 * float(contract["inertia_pivot_axis_kg_m2"]) * rate_rad_s * rate_rad_s
	var potential := (
		float(contract["mass_kg"])
		* float(contract["gravity_m_s2"])
		* float(contract["pivot_to_com_m"])
		* (1.0 - cos(angle_rad))
	)
	return kinetic + potential


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return NAN
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


static func _max_abs(values: Array) -> float:
	var maximum := 0.0
	for value in values:
		maximum = maxf(maximum, absf(float(value)))
	return maximum


static func _exact_positive_integer(value: Variant) -> int:
	if value is int and int(value) > 0:
		return int(value)
	if (
		value is float
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and float(value) > 0.0
	):
		return int(value)
	return -1


static func _is_stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String, message: String, details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"message": message,
		"details": details,
	}
