class_name LabRecoveryEnergyLedger
extends RefCounted

## BR13 work/reserve preflight and post-trace energy reconciliation.
##
## Guide work is explicit and bounded. A positive guide-work contribution
## cannot be silently counted as creature actuation.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"total_mass_kg",
	"gravity_m_s2",
	"minimum_height_gain_m",
	"minimum_torque_reserve_fraction",
	"minimum_power_reserve_fraction",
	"minimum_structural_reserve_fraction",
	"maximum_abs_inferred_guide_work_j",
	"maximum_energy_balance_residual_j",
	"automatic_creature_guidance_allowed",
]
const PREFLIGHT_FIELDS: Array[String] = [
	"schema_version",
	"start_com_height_m",
	"target_com_height_m",
	"available_positive_work_j",
	"required_peak_torque_nm",
	"available_peak_torque_nm",
	"required_peak_power_w",
	"available_peak_power_w",
	"required_structural_torque_nm",
	"available_structural_torque_nm",
]
const TRACE_FIELDS: Array[String] = [
	"schema_version",
	"initial_com_height_m",
	"final_com_height_m",
	"initial_kinetic_energy_j",
	"final_kinetic_energy_j",
	"actuator_positive_work_j",
	"actuator_absorbed_work_j",
	"known_external_work_j",
	"inferred_guide_work_j",
	"reported_contact_dissipation_j",
]


static func build(configuration: Dictionary) -> Dictionary:
	if not _exact_fields(configuration, CONFIGURATION_FIELDS):
		return _failure("RECOVERY_ENERGY_CONFIGURATION_FIELDS_INVALID")
	if String(configuration.get("schema_version", "")) != "recovery_energy_ledger_v1":
		return _failure("RECOVERY_ENERGY_CONFIGURATION_SCHEMA_INVALID")
	for field in [
		"total_mass_kg",
		"gravity_m_s2",
		"minimum_height_gain_m",
		"minimum_torque_reserve_fraction",
		"minimum_power_reserve_fraction",
		"minimum_structural_reserve_fraction",
		"maximum_abs_inferred_guide_work_j",
		"maximum_energy_balance_residual_j",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) < 0.0:
			return _failure("RECOVERY_ENERGY_CONFIGURATION_NUMBER_INVALID:%s" % field)
	if (
		float(configuration["total_mass_kg"]) <= 0.0
		or float(configuration["gravity_m_s2"]) <= 0.0
		or float(configuration["minimum_height_gain_m"]) <= 0.0
		or float(configuration["minimum_torque_reserve_fraction"]) >= 1.0
		or float(configuration["minimum_power_reserve_fraction"]) >= 1.0
		or float(configuration["minimum_structural_reserve_fraction"]) >= 1.0
		or typeof(configuration.get("automatic_creature_guidance_allowed")) != TYPE_BOOL
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure("RECOVERY_ENERGY_CONFIGURATION_BOUND_INVALID")
	var sealed := configuration.duplicate(true)
	sealed["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "configuration": FrozenValueScript.snapshot(sealed)}


static func preflight(configuration: Dictionary, request: Dictionary) -> Dictionary:
	var built := build(configuration)
	if not bool(built.get("ok", false)):
		return built
	if not _exact_fields(request, PREFLIGHT_FIELDS):
		return _failure("RECOVERY_ENERGY_PREFLIGHT_FIELDS_INVALID")
	if String(request.get("schema_version", "")) != "recovery_energy_preflight_v1":
		return _failure("RECOVERY_ENERGY_PREFLIGHT_SCHEMA_INVALID")
	for field in PREFLIGHT_FIELDS.slice(1):
		if not _finite_number(request.get(field)) or float(request[field]) < 0.0:
			return _failure("RECOVERY_ENERGY_PREFLIGHT_NUMBER_INVALID:%s" % field)
	var config: Dictionary = built["configuration"]
	var height_gain := float(request["target_com_height_m"]) - float(request["start_com_height_m"])
	var required_potential := (
		float(config["total_mass_kg"]) * float(config["gravity_m_s2"]) * height_gain
	)
	var torque_reserve := _reserve(
		float(request["required_peak_torque_nm"]), float(request["available_peak_torque_nm"])
	)
	var power_reserve := _reserve(
		float(request["required_peak_power_w"]), float(request["available_peak_power_w"])
	)
	var structural_reserve := _reserve(
		float(request["required_structural_torque_nm"]),
		float(request["available_structural_torque_nm"])
	)
	var failures: Array[String] = []
	if height_gain < float(config["minimum_height_gain_m"]):
		failures.append("RECOVERY_HEIGHT_GAIN_INSUFFICIENT")
	if float(request["available_positive_work_j"]) < required_potential:
		failures.append("RECOVERY_POSITIVE_WORK_CAPACITY_INSUFFICIENT")
	if torque_reserve < float(config["minimum_torque_reserve_fraction"]):
		failures.append("RECOVERY_TORQUE_RESERVE_INSUFFICIENT")
	if power_reserve < float(config["minimum_power_reserve_fraction"]):
		failures.append("RECOVERY_POWER_RESERVE_INSUFFICIENT")
	if structural_reserve < float(config["minimum_structural_reserve_fraction"]):
		failures.append("RECOVERY_STRUCTURAL_RESERVE_INSUFFICIENT")
	return {
		"ok": true,
		"report":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "recovery_energy_preflight_report_v1",
					"configuration_sha256": config["configuration_sha256"],
					"feasible": failures.is_empty(),
					"failure_codes": failures,
					"height_gain_m": height_gain,
					"required_potential_gain_j": required_potential,
					"available_positive_work_j": float(request["available_positive_work_j"]),
					"torque_reserve_fraction": torque_reserve,
					"power_reserve_fraction": power_reserve,
					"structural_reserve_fraction": structural_reserve,
					"actuation_authority": false,
					"automatic_creature_guidance_allowed": false,
				}
			)
		),
	}


static func reconcile(configuration: Dictionary, trace: Dictionary) -> Dictionary:
	var built := build(configuration)
	if not bool(built.get("ok", false)):
		return built
	if not _exact_fields(trace, TRACE_FIELDS):
		return _failure("RECOVERY_ENERGY_TRACE_FIELDS_INVALID")
	if String(trace.get("schema_version", "")) != "recovery_energy_trace_v1":
		return _failure("RECOVERY_ENERGY_TRACE_SCHEMA_INVALID")
	for field in TRACE_FIELDS.slice(1):
		if not _finite_number(trace.get(field)):
			return _failure("RECOVERY_ENERGY_TRACE_NUMBER_INVALID:%s" % field)
	for field in [
		"initial_com_height_m",
		"final_com_height_m",
		"initial_kinetic_energy_j",
		"final_kinetic_energy_j",
		"actuator_positive_work_j",
		"actuator_absorbed_work_j",
		"reported_contact_dissipation_j",
	]:
		if float(trace[field]) < 0.0:
			return _failure("RECOVERY_ENERGY_TRACE_NEGATIVE:%s" % field)
	var config: Dictionary = built["configuration"]
	var height_gain := float(trace["final_com_height_m"]) - float(trace["initial_com_height_m"])
	var potential_gain := (
		float(config["total_mass_kg"]) * float(config["gravity_m_s2"]) * height_gain
	)
	var kinetic_change := (
		float(trace["final_kinetic_energy_j"]) - float(trace["initial_kinetic_energy_j"])
	)
	var mechanical_change := potential_gain + kinetic_change
	var net_actuator_work := (
		float(trace["actuator_positive_work_j"]) - float(trace["actuator_absorbed_work_j"])
	)
	var supplied_work := (
		net_actuator_work
		+ float(trace["known_external_work_j"])
		+ float(trace["inferred_guide_work_j"])
	)
	var residual := (
		supplied_work - float(trace["reported_contact_dissipation_j"]) - mechanical_change
	)
	var failures: Array[String] = []
	if height_gain < float(config["minimum_height_gain_m"]):
		failures.append("RECOVERY_HEIGHT_GAIN_INSUFFICIENT")
	if float(trace["actuator_positive_work_j"]) + 1.0e-9 < potential_gain:
		failures.append("RECOVERY_POTENTIAL_GAIN_NOT_COVERED_BY_ACTUATION")
	if (
		absf(float(trace["inferred_guide_work_j"]))
		> float(config["maximum_abs_inferred_guide_work_j"])
	):
		failures.append("RECOVERY_GUIDE_WORK_BOUND_EXCEEDED")
	if absf(residual) > float(config["maximum_energy_balance_residual_j"]):
		failures.append("RECOVERY_ENERGY_BALANCE_RESIDUAL_EXCEEDED")
	return {
		"ok": true,
		"report":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "recovery_energy_reconciliation_v1",
					"configuration_sha256": config["configuration_sha256"],
					"accepted": failures.is_empty(),
					"failure_codes": failures,
					"height_gain_m": height_gain,
					"potential_energy_gain_j": potential_gain,
					"kinetic_energy_change_j": kinetic_change,
					"mechanical_energy_change_j": mechanical_change,
					"net_actuator_work_j": net_actuator_work,
					"known_external_work_j": float(trace["known_external_work_j"]),
					"inferred_guide_work_j": float(trace["inferred_guide_work_j"]),
					"reported_contact_dissipation_j":
					float(trace["reported_contact_dissipation_j"]),
					"energy_balance_residual_j": residual,
					"guide_work_is_measured": false,
					"guide_work_is_residual_inferred": true,
					"free_3d_recovery_established": false,
					"automatic_creature_guidance_allowed": false,
				}
			)
		),
	}


static func _reserve(required: float, available: float) -> float:
	if available <= 0.0:
		return -INF
	return (available - required) / available


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
