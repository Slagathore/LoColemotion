class_name LabControlledFallArrestAnalyzer
extends RefCounted
# gdlint: disable=max-file-lines

## Digest-bound BR11 paired controlled-fall analyzer.
##
## The declared severity proxy is whole-system kinetic energy immediately
## before the first semantic core contact. It is a mechanics proxy, not an
## injury prediction. Raw local predicted impulses remain local witnesses and
## are never summed into a whole-system or per-body allocation.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA := "controlled_fall_arrest_configuration_v1"
const SUMMARY_SCHEMA := "controlled_fall_arrest_summary_v1"
const CLAIM_BOUNDARY := (
	"BR11 paired controlled fall arrest in one exact planar scaffold: the active world "
	+ "uses one finite paired hinge actuator to deploy one semantic protective distal "
	+ "contact before semantic core impact; whole-system mechanics samples retain "
	+ "available centroidal angular momentum; the declared pre-core kinetic-energy "
	+ "severity proxy, core approach speed, and local predicted core-load witness improve "
	+ "relative to one same-state zero-command control; impulse and mechanical-energy "
	+ "accounts remain explicit; and both worlds terminate in an observed stable FALLEN "
	+ "state. The severity proxy is not an injury model, raw predicted impulses are not "
	+ "per-body or per-foot load allocation, and the positive result establishes only "
	+ "this scaffold-constrained planar protective fall. It establishes no upright "
	+ "recovery, free-3D standing or bracing, generalized fall arrest, getting up, gait, "
	+ "walking, creature repair, or automatic creature guidance."
)
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"actuator_spec_sha256",
	"physics_hz",
	"trial_ticks",
	"fall_arrest_start_tick",
	"fallen_confirm_ticks",
	"torso_mass_kg",
	"torso_size_m",
	"protective_mass_kg",
	"protective_length_m",
	"protective_width_m",
	"initial_torso_position_m",
	"initial_torso_angle_rad",
	"initial_protective_relative_angle_rad",
	"initial_linear_velocity_m_s",
	"initial_angular_velocity_rad_s",
	"floor_friction",
	"target_relative_angle_rad",
	"controller_kp_nm_per_rad",
	"controller_kd_nm_s_per_rad",
	"maximum_abs_angle_error_rad",
	"maximum_abs_rate_rad_s",
	"maximum_active_to_control_severity_ratio",
	"maximum_active_to_control_core_speed_ratio",
	"maximum_active_to_control_core_load_ratio",
	"maximum_active_to_control_linear_momentum_ratio",
	"maximum_energy_accounting_residual_j",
	"stable_linear_speed_m_s",
	"stable_angular_speed_rad_s",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
	"out_of_plane_planar_guide_enabled",
	"built_in_motor_enabled",
	"joint_limit_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"pose_teleport_enabled",
	"per_body_load_allocation_enabled",
	"injury_claim_enabled",
	"upright_recovery_claim_enabled",
	"free_3d_claim_enabled",
	"getting_up_claim_enabled",
	"gait_claim_enabled",
	"walking_claim_enabled",
	"automatic_creature_guidance_enabled",
	"scaffold_constrained_planar_fall_arrest_claim_enabled",
]
const SUMMARY_FIELDS: Array[String] = [
	"schema_version",
	"configuration_sha256",
	"actuator_spec_sha256",
	"arrest_enabled",
	"fixture_complete",
	"fixture_failure_code",
	"executed_ticks",
	"planar_guide_exact",
	"hinge_exact",
	"all_receipts_complete",
	"angular_momentum_available",
	"protective_role_registered",
	"core_role_registered",
	"first_protective_contact_tick",
	"first_core_contact_tick",
	"protective_before_core",
	"initial_linear_momentum_world_n_s",
	"pre_core_linear_momentum_world_n_s",
	"initial_angular_momentum_about_com_world_n_m_s",
	"pre_core_angular_momentum_about_com_world_n_m_s",
	"initial_total_kinetic_energy_j",
	"pre_core_total_kinetic_energy_j",
	"core_approach_speed_m_s",
	"peak_predicted_local_core_load_n",
	"reconstructed_external_impulse_world_n_s",
	"initial_mechanical_energy_j",
	"final_mechanical_energy_j",
	"actuator_work_j",
	"contact_dissipation_j",
	"energy_accounting_residual_j",
	"final_supervisor_phase",
	"fallen_transition_tick",
	"stable_fallen_observed",
	"upright_recovery_observed",
	"final_linear_speed_m_s",
	"final_angular_speed_rad_s",
	"maximum_applied_torque_nm",
	"maximum_pairing_residual_nm",
	"actuator_saturation_count",
	"root_rescue_operation_count",
	"foot_pin_operation_count",
	"pose_teleport_operation_count",
	"automatic_creature_guidance_operation_count",
	"local_core_load_is_generalized_allocation",
	"severity_proxy_is_injury_model",
]
const FORBIDDEN_TRUE_FIELDS: Array[String] = [
	"built_in_motor_enabled",
	"joint_limit_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"pose_teleport_enabled",
	"per_body_load_allocation_enabled",
	"injury_claim_enabled",
	"upright_recovery_claim_enabled",
	"free_3d_claim_enabled",
	"getting_up_claim_enabled",
	"gait_claim_enabled",
	"walking_claim_enabled",
	"automatic_creature_guidance_enabled",
]


static func build(configuration: Dictionary) -> Dictionary:
	var keys := _sorted_keys(configuration)
	var expected: Array = CONFIGURATION_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("CONTROLLED_FALL_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("CONTROLLED_FALL_CONFIGURATION_SCHEMA_UNSUPPORTED")
	if not _sha256(String(configuration.get("actuator_spec_sha256", ""))):
		return _failure("CONTROLLED_FALL_ACTUATOR_DIGEST_INVALID")
	for field in [
		"physics_hz",
		"trial_ticks",
		"fall_arrest_start_tick",
		"fallen_confirm_ticks",
	]:
		if typeof(configuration.get(field)) != TYPE_INT or int(configuration[field]) < 0:
			return _failure("CONTROLLED_FALL_INTEGER_INVALID:%s" % field)
	if (
		int(configuration["physics_hz"]) < 60
		or int(configuration["trial_ticks"]) < 120
		or int(configuration["fallen_confirm_ticks"]) < 1
		or int(configuration["fall_arrest_start_tick"]) >= int(configuration["trial_ticks"])
	):
		return _failure("CONTROLLED_FALL_TIMING_INVALID")
	for field in [
		"torso_mass_kg",
		"protective_mass_kg",
		"protective_length_m",
		"protective_width_m",
		"floor_friction",
		"controller_kp_nm_per_rad",
		"controller_kd_nm_s_per_rad",
		"maximum_abs_angle_error_rad",
		"maximum_abs_rate_rad_s",
		"maximum_active_to_control_severity_ratio",
		"maximum_active_to_control_core_speed_ratio",
		"maximum_active_to_control_core_load_ratio",
		"maximum_active_to_control_linear_momentum_ratio",
		"maximum_energy_accounting_residual_j",
		"stable_linear_speed_m_s",
		"stable_angular_speed_rad_s",
		"maximum_pairing_residual_nm",
		"maximum_applied_torque_nm",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) < 0.0:
			return _failure("CONTROLLED_FALL_NUMBER_INVALID:%s" % field)
	for field in [
		"initial_torso_angle_rad",
		"initial_protective_relative_angle_rad",
		"initial_angular_velocity_rad_s",
		"target_relative_angle_rad",
	]:
		if not _finite_number(configuration.get(field)):
			return _failure("CONTROLLED_FALL_NUMBER_INVALID:%s" % field)
	for field in [
		"torso_size_m",
		"initial_torso_position_m",
		"initial_linear_velocity_m_s",
	]:
		if not _vector3(configuration.get(field)).is_finite():
			return _failure("CONTROLLED_FALL_VECTOR_INVALID:%s" % field)
	if (
		_vector3(configuration["torso_size_m"]).x <= 0.0
		or _vector3(configuration["torso_size_m"]).y <= 0.0
		or _vector3(configuration["torso_size_m"]).z <= 0.0
	):
		return _failure("CONTROLLED_FALL_TORSO_SIZE_INVALID")
	for field in FORBIDDEN_TRUE_FIELDS:
		if not configuration.get(field) is bool or bool(configuration[field]):
			return _failure("CONTROLLED_FALL_FORBIDDEN_ASSIST_OR_CLAIM:%s" % field)
	if (
		not configuration.get("out_of_plane_planar_guide_enabled") is bool
		or not bool(configuration["out_of_plane_planar_guide_enabled"])
		or not configuration.get("scaffold_constrained_planar_fall_arrest_claim_enabled") is bool
		or not bool(configuration["scaffold_constrained_planar_fall_arrest_claim_enabled"])
	):
		return _failure("CONTROLLED_FALL_REQUIRED_BOUNDARY_DISABLED")
	var payload := configuration.duplicate(true)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["claim_boundary"] = CLAIM_BOUNDARY
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(
	contract: Dictionary, active_summary: Dictionary, control_summary: Dictionary
) -> Dictionary:
	var contract_check := _verify_contract(contract)
	if not bool(contract_check.get("ok", false)):
		return contract_check
	var active_check := _verify_summary(contract, active_summary, true)
	if not bool(active_check.get("ok", false)):
		return active_check
	var control_check := _verify_summary(contract, control_summary, false)
	if not bool(control_check.get("ok", false)):
		return control_check
	var failures: Array[String] = []
	var active_severity := float(active_summary["pre_core_total_kinetic_energy_j"])
	var control_severity := float(control_summary["pre_core_total_kinetic_energy_j"])
	var severity_ratio := active_severity / maxf(control_severity, 1.0e-9)
	var speed_ratio := (
		float(active_summary["core_approach_speed_m_s"])
		/ maxf(float(control_summary["core_approach_speed_m_s"]), 1.0e-9)
	)
	var load_ratio := (
		float(active_summary["peak_predicted_local_core_load_n"])
		/ maxf(float(control_summary["peak_predicted_local_core_load_n"]), 1.0e-9)
	)
	var active_linear_momentum := (
		_vector3(active_summary["pre_core_linear_momentum_world_n_s"]).length()
	)
	var control_linear_momentum := (
		_vector3(control_summary["pre_core_linear_momentum_world_n_s"]).length()
	)
	var linear_momentum_ratio := active_linear_momentum / maxf(control_linear_momentum, 1.0e-9)
	var initial_angular := (
		_vector3(active_summary["initial_angular_momentum_about_com_world_n_m_s"]).length()
	)
	var active_pre_core_angular := (
		_vector3(active_summary["pre_core_angular_momentum_about_com_world_n_m_s"]).length()
	)
	var angular_ratio := active_pre_core_angular / maxf(initial_angular, 1.0e-9)
	if (
		int(active_summary["first_protective_contact_tick"]) < 0
		or int(active_summary["first_core_contact_tick"]) < 0
		or (
			int(active_summary["first_protective_contact_tick"])
			>= int(active_summary["first_core_contact_tick"])
		)
		or not bool(active_summary["protective_before_core"])
	):
		failures.append("PROTECTIVE_CONTACT_NOT_BEFORE_CORE")
	if int(control_summary["first_core_contact_tick"]) < 0:
		failures.append("CONTROL_CORE_CONTACT_MISSING")
	if (
		int(control_summary["first_protective_contact_tick"]) >= 0
		and (
			int(control_summary["first_protective_contact_tick"])
			< int(control_summary["first_core_contact_tick"])
		)
	):
		failures.append("CONTROL_HAS_EARLY_PROTECTIVE_CONTACT")
	if severity_ratio > float(contract["maximum_active_to_control_severity_ratio"]):
		failures.append("SEVERITY_PROXY_NOT_REDUCED")
	if speed_ratio > float(contract["maximum_active_to_control_core_speed_ratio"]):
		failures.append("CORE_APPROACH_SPEED_NOT_REDUCED")
	if load_ratio > float(contract["maximum_active_to_control_core_load_ratio"]):
		failures.append("LOCAL_CORE_LOAD_WITNESS_NOT_REDUCED")
	if linear_momentum_ratio > float(contract["maximum_active_to_control_linear_momentum_ratio"]):
		failures.append("LINEAR_MOMENTUM_NOT_REDUCED")
	if (
		not _vectors_near(
			_vector3(active_summary["initial_linear_momentum_world_n_s"]),
			_vector3(control_summary["initial_linear_momentum_world_n_s"]),
			1.0e-6
		)
		or not _vectors_near(
			_vector3(active_summary["initial_angular_momentum_about_com_world_n_m_s"]),
			_vector3(control_summary["initial_angular_momentum_about_com_world_n_m_s"]),
			1.0e-6
		)
		or not is_equal_approx(
			float(active_summary["initial_total_kinetic_energy_j"]),
			float(control_summary["initial_total_kinetic_energy_j"])
		)
		or not is_equal_approx(
			float(active_summary["initial_mechanical_energy_j"]),
			float(control_summary["initial_mechanical_energy_j"])
		)
	):
		failures.append("PAIRED_INITIAL_STATE_MISMATCH")
	if (
		float(active_summary["maximum_applied_torque_nm"]) <= 0.0
		or absf(float(control_summary["maximum_applied_torque_nm"])) > 1.0e-9
		or absf(float(control_summary["actuator_work_j"])) > 1.0e-9
	):
		failures.append("ACTIVE_OR_ZERO_COMMAND_CONTROL_INVALID")
	for summary_value in [active_summary, control_summary]:
		var summary: Dictionary = summary_value
		if (
			not bool(summary["stable_fallen_observed"])
			or String(summary["final_supervisor_phase"]) != "FALLEN"
			or bool(summary["upright_recovery_observed"])
			or int(summary["fallen_transition_tick"]) < 0
			or int(summary["fallen_transition_tick"]) > int(summary["executed_ticks"])
			or (
				float(summary["final_linear_speed_m_s"])
				> float(contract["stable_linear_speed_m_s"]) + 1.0e-9
			)
			or (
				float(summary["final_angular_speed_rad_s"])
				> float(contract["stable_angular_speed_rad_s"]) + 1.0e-9
			)
		):
			failures.append("STABLE_FALLEN_TERMINAL_STATE_MISSING")
		if float(summary["contact_dissipation_j"]) < -1.0e-7:
			failures.append("CONTACT_DISSIPATION_NEGATIVE")
		if (
			absf(float(summary["energy_accounting_residual_j"]))
			> float(contract["maximum_energy_accounting_residual_j"])
		):
			failures.append("ENERGY_ACCOUNTING_RESIDUAL_EXCEEDED")
	return {
		"ok": true,
		"accepted": failures.is_empty(),
		"acceptance_failures": failures,
		"severity_proxy": "pre_core_whole_system_kinetic_energy_j",
		"active_to_control_severity_ratio": severity_ratio,
		"active_to_control_core_speed_ratio": speed_ratio,
		"active_to_control_core_load_ratio": load_ratio,
		"active_to_control_linear_momentum_ratio": linear_momentum_ratio,
		"active_to_initial_angular_momentum_ratio": angular_ratio,
		"claim_boundary": CLAIM_BOUNDARY,
		"milestone_cells": ["BR11.0", "BR11.1", "BR11.2", "BR11.3"],
		"integrity_cell": "BR11.4",
		"does_not_establish":
		[
			"injury_prediction",
			"per_body_measured_load_allocation",
			"upright_recovery",
			"free_3d_standing",
			"free_3d_bracing",
			"generalized_fall_arrest",
			"getting_up",
			"gait",
			"walking",
			"automatic_creature_guidance",
		],
	}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var source: Dictionary = {}
	for field in CONFIGURATION_FIELDS:
		if not contract.has(field):
			return _failure("CONTROLLED_FALL_CONTRACT_INCOMPLETE")
		source[field] = contract[field]
	var rebuilt := build(source)
	if not bool(rebuilt.get("ok", false)):
		return rebuilt
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("CONTROLLED_FALL_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _verify_summary(
	contract: Dictionary, summary: Dictionary, expected_enabled: bool
) -> Dictionary:
	var keys := _sorted_keys(summary)
	var expected: Array = SUMMARY_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("CONTROLLED_FALL_SUMMARY_FIELD_SET_MISMATCH")
	if String(summary.get("schema_version", "")) != SUMMARY_SCHEMA:
		return _failure("CONTROLLED_FALL_SUMMARY_SCHEMA_UNSUPPORTED")
	if String(summary.get("configuration_sha256", "")) != String(contract["configuration_sha256"]):
		return _failure("CONTROLLED_FALL_SUMMARY_CONFIGURATION_DIGEST_MISMATCH")
	if String(summary.get("actuator_spec_sha256", "")) != String(contract["actuator_spec_sha256"]):
		return _failure("CONTROLLED_FALL_SUMMARY_ACTUATOR_DIGEST_MISMATCH")
	for field in [
		"arrest_enabled",
		"fixture_complete",
		"planar_guide_exact",
		"hinge_exact",
		"all_receipts_complete",
		"angular_momentum_available",
		"protective_role_registered",
		"core_role_registered",
		"protective_before_core",
		"stable_fallen_observed",
		"upright_recovery_observed",
		"local_core_load_is_generalized_allocation",
		"severity_proxy_is_injury_model",
	]:
		if typeof(summary.get(field)) != TYPE_BOOL:
			return _failure("CONTROLLED_FALL_SUMMARY_BOOL_INVALID:%s" % field)
	for field in [
		"executed_ticks",
		"first_protective_contact_tick",
		"first_core_contact_tick",
		"fallen_transition_tick",
		"actuator_saturation_count",
		"root_rescue_operation_count",
		"foot_pin_operation_count",
		"pose_teleport_operation_count",
		"automatic_creature_guidance_operation_count",
	]:
		if typeof(summary.get(field)) != TYPE_INT:
			return _failure("CONTROLLED_FALL_SUMMARY_INTEGER_INVALID:%s" % field)
	for field in ["fixture_failure_code", "final_supervisor_phase"]:
		if typeof(summary.get(field)) != TYPE_STRING:
			return _failure("CONTROLLED_FALL_SUMMARY_STRING_INVALID:%s" % field)
	if bool(summary["arrest_enabled"]) != expected_enabled:
		return _failure("CONTROLLED_FALL_SUMMARY_MODE_MISMATCH")
	if (
		not bool(summary.get("fixture_complete", false))
		or not String(summary.get("fixture_failure_code", "")).is_empty()
		or int(summary.get("executed_ticks", -1)) != int(contract["trial_ticks"])
		or not bool(summary.get("planar_guide_exact", false))
		or not bool(summary.get("hinge_exact", false))
		or not bool(summary.get("all_receipts_complete", false))
		or not bool(summary.get("angular_momentum_available", false))
		or not bool(summary.get("protective_role_registered", false))
		or not bool(summary.get("core_role_registered", false))
		or bool(summary.get("local_core_load_is_generalized_allocation", true))
		or bool(summary.get("severity_proxy_is_injury_model", true))
	):
		return _failure("CONTROLLED_FALL_SUMMARY_INTEGRITY_FAILED")
	for field in [
		"initial_linear_momentum_world_n_s",
		"pre_core_linear_momentum_world_n_s",
		"initial_angular_momentum_about_com_world_n_m_s",
		"pre_core_angular_momentum_about_com_world_n_m_s",
		"reconstructed_external_impulse_world_n_s",
	]:
		if not _vector3(summary.get(field)).is_finite():
			return _failure("CONTROLLED_FALL_SUMMARY_VECTOR_NONFINITE:%s" % field)
	for field in [
		"initial_total_kinetic_energy_j",
		"pre_core_total_kinetic_energy_j",
		"core_approach_speed_m_s",
		"peak_predicted_local_core_load_n",
		"initial_mechanical_energy_j",
		"final_mechanical_energy_j",
		"actuator_work_j",
		"contact_dissipation_j",
		"energy_accounting_residual_j",
		"final_linear_speed_m_s",
		"final_angular_speed_rad_s",
		"maximum_applied_torque_nm",
		"maximum_pairing_residual_nm",
	]:
		if not _finite_number(summary.get(field)):
			return _failure("CONTROLLED_FALL_SUMMARY_NUMBER_NONFINITE:%s" % field)
	for field in [
		"initial_total_kinetic_energy_j",
		"pre_core_total_kinetic_energy_j",
		"core_approach_speed_m_s",
		"peak_predicted_local_core_load_n",
		"initial_mechanical_energy_j",
		"final_mechanical_energy_j",
		"final_linear_speed_m_s",
		"final_angular_speed_rad_s",
		"maximum_applied_torque_nm",
		"maximum_pairing_residual_nm",
	]:
		if float(summary[field]) < 0.0:
			return _failure("CONTROLLED_FALL_SUMMARY_NUMBER_NEGATIVE:%s" % field)
	if (
		int(summary["root_rescue_operation_count"]) != 0
		or int(summary["foot_pin_operation_count"]) != 0
		or int(summary["pose_teleport_operation_count"]) != 0
		or int(summary["automatic_creature_guidance_operation_count"]) != 0
		or int(summary["actuator_saturation_count"]) < 0
		or (
			float(summary["maximum_pairing_residual_nm"])
			> float(contract["maximum_pairing_residual_nm"]) + 1.0e-9
		)
		or (
			float(summary["maximum_applied_torque_nm"])
			> float(contract["maximum_applied_torque_nm"]) + 1.0e-7
		)
	):
		return _failure("CONTROLLED_FALL_SUMMARY_ASSIST_OR_ACTUATOR_BOUNDARY_FAILED")
	return {"ok": true}


static func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if not value is Array or (value as Array).size() != 3:
		return Vector3(INF, INF, INF)
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _vectors_near(first: Vector3, second: Vector3, tolerance: float) -> bool:
	return first.distance_to(second) <= tolerance


static func _sha256(value: String) -> bool:
	return (
		value.begins_with("sha256:")
		and value.length() == 71
		and value.trim_prefix("sha256:").is_valid_hex_number(false)
	)


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
