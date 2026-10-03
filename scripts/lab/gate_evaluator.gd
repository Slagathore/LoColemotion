class_name LabGateEvaluator
extends RefCounted

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func evaluate_l0(experiment_id: String, metrics: Dictionary, tolerances: Dictionary) -> Dictionary:
	var checks: Array = []
	match experiment_id:
		"L0_0_STATIONARY_GRAVITY_OFF":
			checks.append(_upper_bound(
				"max_position_error_m",
				metrics,
				tolerances.get("max_position_error_m", 0.0001)))
			checks.append(_upper_bound(
				"max_velocity_error_m_s",
				metrics,
				tolerances.get("max_velocity_error_m_s", 0.0001)))
			checks.append(_upper_bound(
				"total_contact_count",
				metrics,
				tolerances.get("total_contact_count", 0)))
			checks.append(_upper_bound(
				"external_work_j",
				metrics,
				tolerances.get("external_work_j", 0.0)))
		"L0_1_FREE_FALL":
			checks.append(_upper_bound(
				"max_acceleration_error_m_s2",
				metrics,
				tolerances.get("max_acceleration_error_m_s2", 0.05)))
			checks.append(_upper_bound(
				"max_velocity_error_m_s",
				metrics,
				tolerances.get("max_velocity_error_m_s", 0.01)))
			checks.append(_upper_bound(
				"max_position_error_m",
				metrics,
				tolerances.get("max_position_error_m", 0.05)))
		"L0_2_BALLISTIC_ZERO_G":
			checks.append(_upper_bound(
				"max_position_error_m",
				metrics,
				tolerances.get("max_position_error_m", 0.002)))
			checks.append(_upper_bound(
				"max_velocity_error_m_s",
				metrics,
				tolerances.get("max_velocity_error_m_s", 0.001)))
			checks.append(_upper_bound(
				"max_momentum_error_kg_m_s",
				metrics,
				tolerances.get("max_momentum_error_kg_m_s", 0.000002)))
		"L0_3_OBSERVER_AB":
			checks.append(_upper_bound(
				"max_position_delta_m",
				metrics,
				tolerances.get("max_position_delta_m", 0.0001)))
			checks.append(_upper_bound(
				"max_velocity_delta_m_s",
				metrics,
				tolerances.get("max_velocity_delta_m_s", 0.0001)))
			checks.append(_upper_bound(
				"max_contact_profile_position_delta_m",
				metrics,
				tolerances.get("max_contact_profile_position_delta_m", 0.0001)))
			checks.append(_upper_bound(
				"max_contact_profile_velocity_delta_m_s",
				metrics,
				tolerances.get("max_contact_profile_velocity_delta_m_s", 0.0001)))
		"L0_4_TRACE_PLAYBACK":
			checks.append(_upper_bound(
				"replay_mismatch_count",
				metrics,
				tolerances.get("replay_mismatch_count", 0)))
		_:
			return FrozenValueScript.snapshot({
				"gate_id": "UNKNOWN_L0_GATE",
				"pass": false,
				"checks": [],
				"reason": "UNKNOWN_EXPERIMENT_ID",
			})
	var passed := true
	for check in checks:
		passed = passed and bool(check["pass"])
	return FrozenValueScript.snapshot({
		"gate_id": experiment_id,
		"pass": passed,
		"checks": checks,
		"reason": null if passed else "ANALYTIC_TOLERANCE_EXCEEDED",
	})


static func _upper_bound(metric_id: String, metrics: Dictionary, limit: Variant) -> Dictionary:
	if not metrics.has(metric_id):
		return {
			"metric_id": metric_id,
			"pass": false,
			"observed": null,
			"operator": "<=",
			"limit": limit,
			"reason": "METRIC_MISSING",
		}
	var observed := float(metrics[metric_id])
	var numeric_limit := float(limit)
	return {
		"metric_id": metric_id,
		"pass": is_finite(observed) and observed <= numeric_limit,
		"observed": observed,
		"operator": "<=",
		"limit": numeric_limit,
		"reason": null,
	}
