class_name LabRailLegSupportAnalyzer
extends RefCounted
# gdlint: disable=max-line-length

## Digest-bound BR6A/L4.3 two-link vertical-carriage support contract.

const BodyWrenchScript := preload("res://scripts/lab/mechanics/body_wrench.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ForceMapScript := preload("res://scripts/lab/mechanics/force_to_joint_map.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "rail_leg_support_configuration_v1"
const CLAIM_BOUNDARY := (
	"BR6A/L4.3 exact two-link sagittal leg on an explicit vertical carriage rail, "
	+ "with one ordinary frictionless distal sphere contact, paired finite joint "
	+ "torques, a V1 vertical load allocator, J-transpose force mapping, crouch/rise, "
	+ "and one declared downward carriage impulse. The rail removes balance and its "
	+ "reaction remains observable. This establishes articulated rail-constrained "
	+ "vertical support only; it establishes no free-root standing, per-foot allocation, "
	+ "bracing, fall arrest, getting up, gait, or walking."
)
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"settle_ticks",
	"crouch_ramp_ticks",
	"crouch_hold_ticks",
	"rise_ramp_ticks",
	"rise_hold_ticks",
	"recovery_ticks",
	"baseline_height_m",
	"crouch_height_m",
	"carriage_mass_kg",
	"link_1_mass_kg",
	"link_2_mass_kg",
	"link_1_length_m",
	"link_2_length_m",
	"foot_radius_m",
	"downward_impulse_ns",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"minimum_load_n",
	"maximum_load_n",
	"maximum_load_rate_n_s",
	"maximum_static_height_error_m",
	"maximum_static_velocity_m_s",
	"maximum_static_support_error_n",
	"minimum_contact_fraction",
	"minimum_crouch_depth_m",
	"maximum_final_height_error_m",
	"minimum_rise_potential_gain_j",
	"minimum_rise_active_work_j",
	"minimum_impulse_drop_m",
	"maximum_recovery_height_error_m",
	"maximum_recovery_velocity_m_s",
	"recovery_dwell_ticks",
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
]


static func build(configuration: Dictionary) -> Dictionary:
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("RAIL_LEG_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("RAIL_LEG_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in [
		"physics_hz",
		"settle_ticks",
		"crouch_ramp_ticks",
		"crouch_hold_ticks",
		"rise_ramp_ticks",
		"rise_hold_ticks",
		"recovery_ticks",
		"recovery_dwell_ticks",
	]:
		if (
			typeof(configuration.get(field)) not in [TYPE_INT, TYPE_FLOAT]
			or float(configuration[field]) != floorf(float(configuration[field]))
			or int(configuration[field]) <= 0
		):
			return _failure("RAIL_LEG_POSITIVE_INTEGER_INVALID:%s" % field)
	for field in REQUIRED_FIELDS.slice(8, 36):
		if (
			typeof(configuration.get(field)) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(configuration[field]))
			or float(configuration[field]) < 0.0
		):
			return _failure("RAIL_LEG_FINITE_NONNEGATIVE_INVALID:%s" % field)
	for field in [
		"baseline_height_m",
		"crouch_height_m",
		"carriage_mass_kg",
		"link_1_mass_kg",
		"link_2_mass_kg",
		"link_1_length_m",
		"link_2_length_m",
		"foot_radius_m",
		"height_position_gain_n_m",
		"height_velocity_gain_n_s_m",
		"joint_position_gain_nm_rad",
		"joint_velocity_gain_nm_s_rad",
		"maximum_load_n",
		"maximum_load_rate_n_s",
	]:
		if float(configuration[field]) <= 0.0:
			return _failure("RAIL_LEG_POSITIVE_VALUE_INVALID:%s" % field)
	if (
		float(configuration["crouch_height_m"]) >= float(configuration["baseline_height_m"])
		or float(configuration["minimum_load_n"]) >= float(configuration["maximum_load_n"])
		or float(configuration["minimum_contact_fraction"]) <= 0.0
		or float(configuration["minimum_contact_fraction"]) > 1.0
	):
		return _failure("RAIL_LEG_RANGE_INVALID")
	for field in REQUIRED_FIELDS.slice(36):
		if typeof(configuration.get(field)) != TYPE_BOOL or bool(configuration[field]):
			return _failure("RAIL_LEG_FORBIDDEN_ASSIST:%s" % field)
	var baseline := _symmetric_ik(configuration, float(configuration["baseline_height_m"]))
	var crouch := _symmetric_ik(configuration, float(configuration["crouch_height_m"]))
	if not bool(baseline.get("ok", false)) or not bool(crouch.get("ok", false)):
		return _failure("RAIL_LEG_DECLARED_HEIGHT_UNREACHABLE")
	var payload := configuration.duplicate(true)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["total_ticks"] = _total_ticks(configuration)
	payload["claim_boundary"] = CLAIM_BOUNDARY
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func preflight_height(
	contract: Dictionary, actuator_spec: Dictionary, target_height_m: float
) -> Dictionary:
	var verified := _verify_contract(contract)
	if not bool(verified.get("ok", false)):
		return verified
	var ik := _symmetric_ik(contract, target_height_m)
	if not bool(ik.get("ok", false)):
		return {
			"ok": true,
			"feasible": false,
			"reason": "HEIGHT_TARGET_UNREACHABLE",
			"target_height_m": target_height_m,
		}
	if String(actuator_spec.get("schema_version", "")) != "actuator_spec_v1":
		return _failure("RAIL_LEG_ACTUATOR_SPEC_INVALID")
	var total_mass := (
		float(contract["carriage_mass_kg"])
		+ float(contract["link_1_mass_kg"])
		+ float(contract["link_2_mass_kg"])
	)
	var gravity := _gravity_magnitude()
	var wrench_build := BodyWrenchScript.compile(
		{
			"schema_version": "body_wrench_v1",
			"wrench_id": "l4_3.preflight",
			"source_id": "l4_3.static_weight",
			"frame_id": "world",
			"application_point_world_m": [0.0, 0.0, 0.0],
			"force_world_n": [0.0, total_mass * gravity, 0.0],
			"moment_world_nm": [0.0, 0.0, 0.0],
		}
	)
	if not bool(wrench_build.get("ok", false)):
		return _failure("RAIL_LEG_PREFLIGHT_WRENCH_INVALID")
	var mapping := ForceMapScript.map(
		_force_map_request(contract, ik, wrench_build["wrench"], gravity)
	)
	if not bool(mapping.get("ok", false)):
		return _failure("RAIL_LEG_PREFLIGHT_FORCE_MAP_INVALID")
	var values: Dictionary = mapping["mapping"]
	var required := maxf(
		absf(float(values["joint_1_feedforward_nm"])),
		absf(float(values["joint_2_feedforward_nm"]))
	)
	var capacity := float(actuator_spec.get("max_isometric_torque_nm", -1.0))
	return {
		"ok": true,
		"feasible": required <= capacity,
		"reason": "FEASIBLE" if required <= capacity else "ACTUATOR_STATIC_TORQUE_INFEASIBLE",
		"target_height_m": target_height_m,
		"joint_1_target_rad": float(ik["joint_1_angle_rad"]),
		"joint_2_target_rad": float(ik["joint_2_angle_rad"]),
		"required_peak_torque_nm": required,
		"available_isometric_torque_nm": capacity,
	}


static func analyze(contract: Dictionary, summary: Dictionary) -> Dictionary:
	var verified := _verify_contract(contract)
	if not bool(verified.get("ok", false)):
		return verified
	var required := [
		"fixture_complete",
		"sample_count",
		"static_maximum_height_error_m",
		"static_maximum_velocity_m_s",
		"static_maximum_support_error_n",
		"contact_fraction",
		"crouch_depth_m",
		"final_rise_height_error_m",
		"rise_potential_energy_gain_j",
		"rise_active_work_j",
		"impulse_maximum_drop_m",
		"impulse_recovered",
		"impulse_recovery_ticks",
		"recovery_final_height_error_m",
		"recovery_final_velocity_m_s",
		"rail_contract_exact",
		"hinges_exact",
		"all_receipts_complete",
		"maximum_pairing_residual_nm",
		"maximum_requested_torque_nm",
		"maximum_applied_torque_nm",
		"actuator_saturation_count",
		"allocator_saturation_count",
		"allocator_anti_windup_count",
		"disturbance_operation_count",
		"root_rescue_operation_count",
		"passive_operation_count",
		"foot_pin_operation_count",
		"maximum_rail_tangential_load_n",
		"per_foot_allocation_available",
	]
	for field in required:
		if not summary.has(field):
			return _failure("RAIL_LEG_SUMMARY_FIELD_MISSING:%s" % field)
	for field in [
		"sample_count",
		"static_maximum_height_error_m",
		"static_maximum_velocity_m_s",
		"static_maximum_support_error_n",
		"contact_fraction",
		"crouch_depth_m",
		"final_rise_height_error_m",
		"rise_potential_energy_gain_j",
		"rise_active_work_j",
		"impulse_maximum_drop_m",
		"impulse_recovery_ticks",
		"recovery_final_height_error_m",
		"recovery_final_velocity_m_s",
		"maximum_pairing_residual_nm",
		"maximum_requested_torque_nm",
		"maximum_applied_torque_nm",
		"actuator_saturation_count",
		"allocator_saturation_count",
		"allocator_anti_windup_count",
		"disturbance_operation_count",
		"root_rescue_operation_count",
		"passive_operation_count",
		"foot_pin_operation_count",
		"maximum_rail_tangential_load_n",
	]:
		if (
			typeof(summary[field]) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(summary[field]))
		):
			return _failure("RAIL_LEG_SUMMARY_NONFINITE:%s" % field)
	var failures: Array[String] = []
	if (
		not bool(summary["fixture_complete"])
		or int(summary["sample_count"]) != int(contract["total_ticks"])
		or not bool(summary["rail_contract_exact"])
		or not bool(summary["hinges_exact"])
		or not bool(summary["all_receipts_complete"])
	):
		failures.append("RAIL_LEG_FIXTURE_INTEGRITY")
	if float(summary["maximum_pairing_residual_nm"]) > 1.0e-9:
		failures.append("RAIL_LEG_TORQUE_PAIRING")
	if int(summary["actuator_saturation_count"]) != 0:
		failures.append("RAIL_LEG_ACTUATOR_SATURATED")
	if (
		int(summary["root_rescue_operation_count"]) != 0
		or int(summary["passive_operation_count"]) != 0
		or int(summary["foot_pin_operation_count"]) != 0
		or int(summary["disturbance_operation_count"]) != 1
	):
		failures.append("RAIL_LEG_INTERVENTION_BOUNDARY")
	if (
		int(summary["allocator_anti_windup_count"])
		!= int(summary["allocator_saturation_count"])
	):
		failures.append("RAIL_LEG_ANTI_WINDUP_MISMATCH")
	if (
		float(summary["static_maximum_height_error_m"])
			> float(contract["maximum_static_height_error_m"])
		or float(summary["static_maximum_velocity_m_s"])
			> float(contract["maximum_static_velocity_m_s"])
		or float(summary["static_maximum_support_error_n"])
			> float(contract["maximum_static_support_error_n"])
		or float(summary["contact_fraction"]) < float(contract["minimum_contact_fraction"])
	):
		failures.append("RAIL_LEG_STATIC_SUPPORT")
	if (
		float(summary["crouch_depth_m"]) < float(contract["minimum_crouch_depth_m"])
		or float(summary["final_rise_height_error_m"])
			> float(contract["maximum_final_height_error_m"])
		or float(summary["rise_potential_energy_gain_j"])
			< float(contract["minimum_rise_potential_gain_j"])
		or float(summary["rise_active_work_j"]) < float(contract["minimum_rise_active_work_j"])
	):
		failures.append("RAIL_LEG_CROUCH_RISE")
	if (
		float(summary["impulse_maximum_drop_m"]) < float(contract["minimum_impulse_drop_m"])
		or not bool(summary["impulse_recovered"])
		or float(summary["recovery_final_height_error_m"])
			> float(contract["maximum_recovery_height_error_m"])
		or float(summary["recovery_final_velocity_m_s"])
			> float(contract["maximum_recovery_velocity_m_s"])
	):
		failures.append("RAIL_LEG_IMPULSE_RECOVERY")
	if bool(summary["per_foot_allocation_available"]):
		failures.append("RAIL_LEG_FALSE_ALLOCATION_CLAIM")
	return {
		"ok": true,
		"accepted": failures.is_empty(),
		"acceptance_failures": failures,
		"claim_boundary": CLAIM_BOUNDARY,
		"rail_scaffold_present": true,
		"allocator_saturation_observed": int(summary["allocator_saturation_count"]) > 0,
		"maximum_observed_rail_tangential_load_n":
		float(summary["maximum_rail_tangential_load_n"]),
		"does_not_establish":
		[
			"free_root_standing",
			"balance",
			"per_foot_load_allocation",
			"bracing",
			"fall_arrest",
			"getting_up",
			"gait",
			"walking",
			"automatic_creature_guidance",
		],
	}


static func symmetric_ik(contract: Dictionary, target_height_m: float) -> Dictionary:
	return _symmetric_ik(contract, target_height_m)


static func force_map_request(
	contract: Dictionary, joint_1_rad: float, joint_2_rad: float, wrench: Dictionary
) -> Dictionary:
	return _force_map_request(
		contract,
		{"joint_1_angle_rad": joint_1_rad, "joint_2_angle_rad": joint_2_rad},
		wrench,
		_gravity_magnitude()
	)


static func _symmetric_ik(configuration: Dictionary, target_height_m: float) -> Dictionary:
	if not is_finite(target_height_m):
		return {"ok": false, "failure_code": "HEIGHT_TARGET_NONFINITE"}
	var l1 := float(configuration.get("link_1_length_m", NAN))
	var l2 := float(configuration.get("link_2_length_m", NAN))
	var radius := float(configuration.get("foot_radius_m", NAN))
	if (
		not is_finite(l1)
		or not is_finite(l2)
		or not is_finite(radius)
		or absf(l1 - l2) > 1.0e-12
	):
		return {"ok": false, "failure_code": "SYMMETRIC_IK_REQUIRES_EQUAL_LINKS"}
	var cosine := (target_height_m - radius) / (l1 + l2)
	if cosine <= 0.0 or cosine > 1.0:
		return {"ok": false, "failure_code": "HEIGHT_TARGET_UNREACHABLE"}
	var alpha := acos(cosine)
	return {
		"ok": true,
		"joint_1_angle_rad": alpha,
		"joint_2_angle_rad": -2.0 * alpha,
		"absolute_link_2_angle_rad": -alpha,
	}


static func _force_map_request(
	contract: Dictionary, ik: Dictionary, wrench: Dictionary, gravity: float
) -> Dictionary:
	return {
		"schema_version": "two_link_force_map_request_v1",
		"joint_1_angle_rad": float(ik["joint_1_angle_rad"]),
		"joint_2_angle_rad": float(ik["joint_2_angle_rad"]),
		"link_1_length_m": float(contract["link_1_length_m"]),
		"link_2_length_m": float(contract["link_2_length_m"]),
		"carriage_mass_kg": float(contract["carriage_mass_kg"]),
		"link_1_mass_kg": float(contract["link_1_mass_kg"]),
		"link_2_mass_kg": float(contract["link_2_mass_kg"]),
		"gravity_m_s2": gravity,
		"wrench": wrench,
	}


static func _total_ticks(configuration: Dictionary) -> int:
	return (
		int(configuration["settle_ticks"])
		+ int(configuration["crouch_ramp_ticks"])
		+ int(configuration["crouch_hold_ticks"])
		+ int(configuration["rise_ramp_ticks"])
		+ int(configuration["rise_hold_ticks"])
		+ int(configuration["recovery_ticks"])
	)


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("RAIL_LEG_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if (
		not bool(rebuilt.get("ok", false))
		or CanonicalJsonScript.stringify(rebuilt["contract"])
			!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("RAIL_LEG_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _gravity_magnitude() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
