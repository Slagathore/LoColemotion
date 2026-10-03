extends SceneTree
# gdlint: disable=max-line-length

## BR14A canonical laboratory morphology preregistration and prephysical
## application of BR14A.0-BR14A.2. No physics body is constructed here.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const ActuatorOracleScript := preload("res://scripts/lab/mechanics/spatial_actuator_load_oracle.gd")
const ContactOracleScript := preload(
	"res://scripts/lab/mechanics/spatial_contact_feasibility_oracle.gd"
)
const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const RankOracleScript := preload("res://scripts/lab/mechanics/spatial_wrench_rank_oracle.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.P0 canonical spatial quadruped ===")
	var compiled := ProfileScript.compile(ProfileScript.configuration())
	_check(bool(compiled.get("ok", false)), "exact canonical spatial profile seals")
	if not bool(compiled.get("ok", false)):
		printerr("  profile_failure=", compiled)
		_finish()
		return
	var profile: Dictionary = compiled["profile"]
	_test_profile_boundary(profile)
	var rank_report := _test_rank(profile)
	var contact_report := _test_contact_feasibility(profile)
	_test_actuator_load(profile, contact_report)
	_test_expected_infeasible_controls(profile)
	_test_profile_containment(profile, rank_report)
	_finish()


func _test_profile_boundary(profile: Dictionary) -> void:
	print("- exact BR13 expansion preserves mass while removing symmetry collapse")
	var limbs: Array = profile["limbs"]
	var joint_count := 0
	var physical_limb_ids: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		physical_limb_ids[String(limb["limb_id"])] = true
		joint_count += (limb["joint_dofs"] as Array).size()
	_check(
		(
			(
				String(profile["source_planar_profile_id"])
				== "canonical_symmetry_collapsed_quadruped_prone_v1"
			)
			and String(profile["profile_id"]) == ProfileScript.PROFILE_ID
		),
		"selection retains explicit provenance from the accepted BR13 reference"
	)
	_check(
		limbs.size() == 4 and physical_limb_ids.size() == 4 and joint_count == 12,
		"four independent physical limbs expose twelve preregistered revolute DOFs"
	)
	_check(
		(
			_close(float(profile["whole_system_mass_kg"]), 8.0)
			and _close(float(profile["torso"]["mass_kg"]), 6.0)
			and _close(float(profile["actuator_template"]["max_isometric_torque_nm"]), 30.0)
			and _close(float(profile["actuator_template"]["max_positive_power_w"]), 250.0)
		),
		"8 kg mass is preserved and the per-DOF candidate cap is half the BR13 pair envelope"
	)
	_check(
		(
			(profile["allowed_scaffolds"] as Array).is_empty()
			and (profile["intentionally_omitted_wrench_axes"] as Array).is_empty()
			and (profile["required_wrench_axes"] as Array).size() == 6
		),
		"all spatial wrench axes are required and no scaffold is allowed"
	)
	_check(
		(
			bool(profile["canonical_morphology_selected_prephysically"])
			and not bool(profile["physical_execution_authorized"])
			and not bool(profile["morphology_generalization_allowed"])
			and not bool(profile["final_game_creature_selected"])
			and not bool(profile["step_gait_or_walking_claim_allowed"])
			and not bool(profile["automatic_creature_guidance_allowed"])
		),
		"selection authorizes no physics, generalization, final creature, walking, or guidance"
	)


func _test_rank(profile: Dictionary) -> Dictionary:
	print("- selected contact geometry retains six-axis non-scaffold rank")
	var columns: Array = []
	var center := _vector3(profile["whole_system_center_of_mass_world_m"])
	for limb_value in profile["limbs"]:
		var limb: Dictionary = limb_value
		var contact_id := "%s.foot" % String(limb["limb_id"])
		var point := _vector3(limb["contact_point_world_m"])
		for direction_index in range(3):
			var direction: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD][direction_index]
			var result := RankOracleScript.contact_force_column(
				"%s.direction_%d" % [contact_id, direction_index],
				contact_id,
				point,
				center,
				direction
			)
			columns.append(result["column"])
	var request := {
		"schema_version": RankOracleScript.SCHEMA_VERSION,
		"analysis_id": "br14a.canonical_quadruped.rank",
		"reference_frame": "centroidal_world",
		"characteristic_length_m": profile["characteristic_length_m"],
		"rank_tolerance": 1.0e-9,
		"axis_residual_tolerance": 1.0e-7,
		"columns": columns,
		"required_axes": profile["required_wrench_axes"],
		"intentionally_omitted_axes": profile["intentionally_omitted_wrench_axes"],
		"claim_boundary": RankOracleScript.CLAIM_BOUNDARY,
		"automatic_creature_guidance_allowed": false,
	}
	var compiled := RankOracleScript.compile(request)
	_check(bool(compiled.get("ok", false)), "selected four-contact rank request seals")
	var analyzed := RankOracleScript.analyze(compiled["request"])
	var report: Dictionary = analyzed["report"]
	_check(
		(
			int(report["non_scaffold_linearized_rank"]) == 6
			and int(report["ordinary_contact_linearized_rank"]) == 6
			and int(report["scaffold_column_count"]) == 0
		),
		"four ordinary-contact linearizations span all six spatial wrench axes"
	)
	_check(
		bool(report["all_required_axes_structurally_spanned_without_scaffold"]),
		"every preregistered required axis lies in the non-scaffold linear span"
	)
	return report


func _test_contact_feasibility(profile: Dictionary) -> Dictionary:
	print("- symmetric weight support fits the conservative contact command set")
	var contacts: Array = []
	for limb_value in profile["limbs"]:
		var limb: Dictionary = limb_value
		(
			contacts
			. append(
				{
					"contact_id": "%s.foot" % String(limb["limb_id"]),
					"point_world_m": limb["contact_point_world_m"],
					"normal_world": [0, 1, 0],
					"tangent_u_world": [1, 0, 0],
					"tangent_v_world": [0, 0, -1],
					"friction_coefficient": profile["contact_friction_coefficient"],
					"normal_capacity_n": profile["contact_normal_capacity_n"],
					"ordinary_unilateral_contact": true,
				}
			)
		)
	var weight := float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"])
	var request := _contact_request(profile, contacts, [0, weight, 0, 0, 0, 0])
	var compiled := ContactOracleScript.compile(request)
	_check(bool(compiled.get("ok", false)), "selected symmetric support request seals")
	var analyzed := ContactOracleScript.analyze(compiled["request"])
	var report: Dictionary = analyzed["report"]
	_check(
		bool(report["feasible"]) and int(report["contact_count"]) == 4,
		"four bounded ordinary contacts support the declared weight command"
	)
	var normal_sum := 0.0
	var minimum_normal := INF
	var maximum_normal := -INF
	for command_value in report["contact_commands"]:
		var command: Dictionary = command_value
		var normal := float(command["normal_command_n"])
		normal_sum += normal
		minimum_normal = minf(minimum_normal, normal)
		maximum_normal = maxf(maximum_normal, normal)
	_check(
		absf(normal_sum - weight) <= 1.0e-3 and maximum_normal - minimum_normal <= 1.0e-3,
		"symmetric stance allocates the total weight evenly within declared tolerance"
	)
	return report


func _test_actuator_load(profile: Dictionary, contact_report: Dictionary) -> void:
	print("- selected static command fits conservative split actuator budgets")
	var request := _actuator_request(profile, contact_report, "")
	var compiled := ActuatorOracleScript.compile(request)
	_check(bool(compiled.get("ok", false)), "selected twelve-DOF actuator request seals")
	var analyzed := ActuatorOracleScript.analyze(compiled["request"])
	var report: Dictionary = analyzed["report"]
	_check(
		bool(report["screen_passed"]) and int(report["joint_count"]) == 12,
		"all twelve joint loads fit full-activation BR4 envelopes and limits"
	)
	var maximum_utilization := 0.0
	for joint_value in report["joint_reports"]:
		maximum_utilization = maxf(
			maximum_utilization, float(joint_value["directional_capacity_utilization"])
		)
	_check(
		maximum_utilization < 0.20,
		"static declared contact command remains below twenty percent actuator utilization"
	)
	_check(
		(
			not bool(report["contact_feasibility_established_by_this_oracle"])
			and not bool(report["declared_bias_terms_complete"])
			and not bool(report["inverse_kinematic_reach_established"])
			and not bool(report["physical_stance_or_recovery_established"])
		),
		"actuator pass remains an incomplete prephysical upper bound"
	)


func _test_expected_infeasible_controls(profile: Dictionary) -> void:
	print("- preregistered low-friction and disabled-axis controls fail as predicted")
	var contacts: Array = []
	for limb_value in profile["limbs"]:
		var limb: Dictionary = limb_value
		(
			contacts
			. append(
				{
					"contact_id": "%s.foot" % String(limb["limb_id"]),
					"point_world_m": limb["contact_point_world_m"],
					"normal_world": [0, 1, 0],
					"tangent_u_world": [1, 0, 0],
					"tangent_v_world": [0, 0, -1],
					"friction_coefficient": 0.10,
					"normal_capacity_n": profile["contact_normal_capacity_n"],
					"ordinary_unilateral_contact": true,
				}
			)
		)
	var weight := float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"])
	var low_friction_request := _contact_request(profile, contacts, [20.0, weight, 0, 0, 0, 0])
	var low_compiled := ContactOracleScript.compile(low_friction_request)
	var low_report: Dictionary = ContactOracleScript.analyze(low_compiled["request"])["report"]
	_check(
		not bool(low_report["feasible"]),
		"low-friction lateral-wrench control fails the predicted contact constraint"
	)
	var nominal_report := _test_contact_feasibility_quiet(profile)
	var disabled_request := _actuator_request(profile, nominal_report, "front_left.hip_abduction")
	var disabled_compiled := ActuatorOracleScript.compile(disabled_request)
	var disabled_report: Dictionary = (
		ActuatorOracleScript.analyze(disabled_compiled["request"])["report"]
	)
	_check(
		not bool(disabled_report["screen_passed"]),
		"disabled front-left abduction control fails its loaded joint envelope"
	)


func _test_profile_containment(profile: Dictionary, rank_report: Dictionary) -> void:
	print("- profile identity and selection boundary fail closed")
	var scaffolded := ProfileScript.configuration()
	scaffolded["allowed_scaffolds"] = ["roll_guide"]
	_check(
		not bool(ProfileScript.compile(scaffolded).get("ok", true)),
		"scaffold injection invalidates the exact canonical profile"
	)
	var walking := ProfileScript.configuration()
	walking["step_gait_or_walking_claim_allowed"] = true
	_check(
		not bool(ProfileScript.compile(walking).get("ok", true)),
		"walking authority cannot enter morphology preregistration"
	)
	var final_creature := ProfileScript.configuration()
	final_creature["final_game_creature_selected"] = true
	_check(
		not bool(ProfileScript.compile(final_creature).get("ok", true)),
		"laboratory reference cannot be relabeled final game anatomy"
	)
	var mass_drift := ProfileScript.configuration()
	mass_drift["limbs"][0]["upper_mass_kg"] = 0.5
	_check(
		not bool(ProfileScript.compile(mass_drift).get("ok", true)),
		"post-selection mass drift requires a new profile identity"
	)
	_check(
		(
			not bool(rank_report["canonical_morphology_selected"])
			and bool(profile["canonical_morphology_selected_prephysically"])
		),
		"generic rank report remains generic while the separate exact profile records selection"
	)


func _contact_request(profile: Dictionary, contacts: Array, desired: Array) -> Dictionary:
	return {
		"schema_version": ContactOracleScript.SCHEMA_VERSION,
		"analysis_id": "br14a.canonical_quadruped.contact",
		"reference_frame": "centroidal_world",
		"center_of_mass_world_m": profile["whole_system_center_of_mass_world_m"],
		"characteristic_length_m": profile["characteristic_length_m"],
		"desired_wrench_world": desired,
		"contacts": contacts,
		"residual_tolerance": 1.0e-3,
		"maximum_iterations": 20000,
		"claim_boundary": ContactOracleScript.CLAIM_BOUNDARY,
		"automatic_creature_guidance_allowed": false,
	}


func _actuator_request(
	profile: Dictionary, contact_report: Dictionary, disabled_joint_id: String
) -> Dictionary:
	var command_by_id: Dictionary = {}
	for command_value in contact_report["contact_commands"]:
		var command: Dictionary = command_value
		command_by_id[String(command["contact_id"])] = command
	var contacts: Array = []
	var joints: Array = []
	for limb_value in profile["limbs"]:
		var limb: Dictionary = limb_value
		var contact_id := "%s.foot" % String(limb["limb_id"])
		var command: Dictionary = command_by_id[contact_id]
		(
			contacts
			. append(
				{
					"contact_id": contact_id,
					"point_world_m": limb["contact_point_world_m"],
					"force_command_world_n": command["force_command_world_n"],
					"command_not_measurement": true,
				}
			)
		)
		for joint_value in limb["joint_dofs"]:
			var joint: Dictionary = joint_value
			var joint_id := String(joint["joint_id"])
			(
				joints
				. append(
					{
						"joint_id": joint_id,
						"axis_world": joint["axis_world"],
						"pivot_world_m": joint["pivot_world_m"],
						"angular_rate_rad_s": 0.0,
						"angle_rad": joint["angle_rad"],
						"minimum_angle_rad": joint["minimum_angle_rad"],
						"maximum_angle_rad": joint["maximum_angle_rad"],
						"downstream_contact_ids": [contact_id],
						"declared_bias_torque_nm": 0.0,
						"bias_torque_source": ActuatorOracleScript.BIAS_SOURCE,
						"full_activation_assumed": true,
						"actuator_spec":
						_actuator_spec(profile, joint_id, joint_id != disabled_joint_id),
					}
				)
			)
	return {
		"schema_version": ActuatorOracleScript.SCHEMA_VERSION,
		"analysis_id": "br14a.canonical_quadruped.actuator",
		"reference_frame": "centroidal_world",
		"minimum_joint_limit_margin_rad": profile["minimum_joint_limit_margin_rad"],
		"contacts": contacts,
		"joints": joints,
		"claim_boundary": ActuatorOracleScript.CLAIM_BOUNDARY,
		"automatic_creature_guidance_allowed": false,
	}


func _actuator_spec(profile: Dictionary, joint_id: String, enabled: bool) -> Dictionary:
	var template: Dictionary = profile["actuator_template"]
	var configuration := {
		"schema_version": ActuatorSpecScript.SCHEMA_VERSION,
		"actuator_id": "%s.actuator" % joint_id,
	}
	for field in ProfileScript.ACTUATOR_TEMPLATE_FIELDS:
		configuration[field] = template[field]
	configuration["enabled"] = enabled
	return ActuatorSpecScript.compile(configuration)["spec"]


func _test_contact_feasibility_quiet(profile: Dictionary) -> Dictionary:
	var contacts: Array = []
	for limb_value in profile["limbs"]:
		var limb: Dictionary = limb_value
		(
			contacts
			. append(
				{
					"contact_id": "%s.foot" % String(limb["limb_id"]),
					"point_world_m": limb["contact_point_world_m"],
					"normal_world": [0, 1, 0],
					"tangent_u_world": [1, 0, 0],
					"tangent_v_world": [0, 0, -1],
					"friction_coefficient": profile["contact_friction_coefficient"],
					"normal_capacity_n": profile["contact_normal_capacity_n"],
					"ordinary_unilateral_contact": true,
				}
			)
		)
	var weight := float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"])
	var request := _contact_request(profile, contacts, [0, weight, 0, 0, 0, 0])
	var compiled := ContactOracleScript.compile(request)
	return ContactOracleScript.analyze(compiled["request"])["report"]


func _vector3(value: Variant) -> Vector3:
	var array: Array = value
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


func _close(left: float, right: float, tolerance: float = 1.0e-8) -> bool:
	return absf(left - right) <= tolerance


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
