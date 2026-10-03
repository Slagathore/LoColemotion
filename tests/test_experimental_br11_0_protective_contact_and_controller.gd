extends SceneTree

## BR11.0 strict semantic protective-contact and pure controller contracts.

const ControllerScript := preload("res://scripts/lab/mechanics/fall_arrest_controller.gd")
const RoleRegistryScript := preload(
	"res://scripts/lab/mechanics/protective_contact_role_registry.gd"
)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR11.0 protective contact and controller ===")
	var registry_result := RoleRegistryScript.compile(_role_configuration())
	_check(bool(registry_result.get("ok", false)), "strict protective role registry seals")
	if not bool(registry_result.get("ok", false)):
		_finish()
		return
	var registry: Dictionary = registry_result["registry"]
	_check(
		(
			int(registry["role_counts"]["protective_distal"]) == 1
			and int(registry["role_counts"]["core_impact"]) == 1
			and not bool(registry["automatic_creature_guidance_allowed"])
		),
		"registry retains one protective and one core role with no guidance authority"
	)
	var protective := RoleRegistryScript.classify(
		registry, _observation("br11_protective_link", "br11_protective_distal_shape")
	)
	var core := RoleRegistryScript.classify(
		registry, _observation("br11_torso", "br11_torso_core_shape")
	)
	_check(
		(
			bool(protective.get("protective_contact", false))
			and not bool(protective.get("core_contact", true))
		),
		"semantic protective distal observation classifies only as protective"
	)
	_check(
		bool(core.get("core_contact", false)) and not bool(core.get("protective_contact", true)),
		"semantic torso observation classifies only as core impact"
	)
	var absent := _observation("br11_torso", "br11_torso_core_shape")
	absent["contact_observed"] = false
	var absent_result := RoleRegistryScript.classify(registry, absent)
	_check(
		bool(absent_result.get("ok", false)) and absent_result.get("role") == null,
		"an authored role does not invent an unobserved contact"
	)
	var wrong_surface := _observation("br11_torso", "br11_torso_core_shape")
	wrong_surface["counterparty_surface_tag"] = "creature_body"
	_check(
		not bool(RoleRegistryScript.classify(registry, wrong_surface).get("ok", true)),
		"self or creature contact cannot masquerade as protective ground contact"
	)
	var duplicate := _role_configuration()
	duplicate["roles"].append((duplicate["roles"][0] as Dictionary).duplicate(true))
	_check(
		not bool(RoleRegistryScript.compile(duplicate).get("ok", true)),
		"duplicate semantic role identity fails closed"
	)
	var missing_core := _role_configuration()
	missing_core["roles"].pop_back()
	_check(
		not bool(RoleRegistryScript.compile(missing_core).get("ok", true)),
		"registry without a core-impact role fails closed"
	)
	var guidance := _role_configuration()
	guidance["automatic_creature_guidance_allowed"] = true
	_check(
		not bool(RoleRegistryScript.compile(guidance).get("ok", true)),
		"role metadata cannot enable automatic creature guidance"
	)

	var controller_result := ControllerScript.compile(_controller_configuration())
	_check(bool(controller_result.get("ok", false)), "strict finite-request controller seals")
	if not bool(controller_result.get("ok", false)):
		_finish()
		return
	var controller: Dictionary = controller_result["controller"]
	var monitor := ControllerScript.resolve(controller, _controller_input("MONITOR", 0.5, 0.2))
	var arrest := ControllerScript.resolve(controller, _controller_input("FALL_ARREST", 0.5, 0.2))
	var fallen := ControllerScript.resolve(controller, _controller_input("FALLEN", 0.5, 0.2))
	_check(
		(
			float(monitor["resolution"]["requested_torque_nm"]) == 0.0
			and float(fallen["resolution"]["requested_torque_nm"]) == 0.0
		),
		"controller requests no torque outside FALL_ARREST"
	)
	_check(
		(
			float(arrest["resolution"]["requested_torque_nm"]) == (30.0 * (-1.1 - 0.5) - 5.0 * 0.2)
			and not bool(arrest["resolution"]["physics_mutation_authority"])
		),
		"FALL_ARREST request is exact PD arithmetic with no mutation authority"
	)
	var nonfinite := _controller_input("FALL_ARREST", NAN, 0.0)
	_check(
		not bool(ControllerScript.resolve(controller, nonfinite).get("ok", true)),
		"nonfinite controller observation fails closed"
	)
	var unknown_phase := _controller_input("BRACE", 0.0, 0.0)
	_check(
		not bool(ControllerScript.resolve(controller, unknown_phase).get("ok", true)),
		"unrecognized supervisor phase fails closed"
	)
	var forged_controller := controller.duplicate(true)
	forged_controller["kp_nm_per_rad"] = 300.0
	_check(
		not bool(
			(
				ControllerScript
				. resolve(forged_controller, _controller_input("FALL_ARREST", 0.0, 0.0))
				. get("ok", true)
			)
		),
		"post-compile controller gain mutation fails the digest boundary"
	)
	_finish()


static func _role_configuration() -> Dictionary:
	return {
		"schema_version": "protective_contact_role_registry_configuration_v1",
		"registry_id": "br11_test_roles",
		"roles":
		[
			{
				"body_id": "br11_protective_link",
				"shape_id": "br11_protective_distal_shape",
				"role": "protective_distal",
			},
			{
				"body_id": "br11_torso",
				"shape_id": "br11_torso_core_shape",
				"role": "core_impact",
			},
		],
		"automatic_creature_guidance_allowed": false,
	}


static func _observation(body_id: String, shape_id: String) -> Dictionary:
	return {
		"schema_version": "protective_contact_role_observation_v1",
		"body_id": body_id,
		"shape_id": shape_id,
		"counterparty_surface_tag": "lab_ground",
		"contact_observed": true,
	}


static func _controller_configuration() -> Dictionary:
	return {
		"schema_version": "fall_arrest_controller_configuration_v1",
		"controller_id": "br11_test_controller",
		"target_relative_angle_rad": -1.1,
		"kp_nm_per_rad": 30.0,
		"kd_nm_s_per_rad": 5.0,
		"maximum_abs_angle_error_rad": 3.2,
		"maximum_abs_rate_rad_s": 30.0,
		"automatic_creature_guidance_allowed": false,
	}


static func _controller_input(phase: String, angle: float, rate: float) -> Dictionary:
	return {
		"schema_version": "fall_arrest_controller_input_v1",
		"tick": 1,
		"supervisor_phase": phase,
		"measured_relative_angle_rad": angle,
		"measured_relative_rate_rad_s": rate,
	}


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
