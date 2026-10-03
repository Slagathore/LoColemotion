class_name LabBr12PoseRecoveryFixtureFactory
extends RefCounted

## Deterministic, non-physics fixtures for BR12 observer and feasibility cells.


static func role_configuration() -> Dictionary:
	return {
		"schema_version": "body_region_contact_role_registry_configuration_v1",
		"roles":
		[
			_role("feet", true, true, ["upright"]),
			_role("ventral_body", true, false, ["prone"]),
			_role("dorsal_body", true, false, ["supine"]),
			_role("left_lateral_body", true, false, ["left_side"]),
			_role("right_lateral_body", true, false, ["right_side"]),
			_role("front_pad", true, true, ["prone_support"]),
			_role("rear_pad", true, true, ["prone_support"]),
		],
		"automatic_creature_guidance_enabled": false,
		"contact_creation_authority": false,
	}


static func classifier_configuration() -> Dictionary:
	return {
		"schema_version": "pose_classifier_configuration_v1",
		"upright_up_dot_min": 0.8,
		"face_vertical_dot_min": 0.7,
		"side_vertical_dot_min": 0.7,
		"upright_height_ratio_min": 0.65,
		"minimum_class_margin": 0.15,
		"required_contact_roles":
		{
			"upright": ["feet"],
			"prone": ["ventral_body"],
			"supine": ["dorsal_body"],
			"left_side": ["left_lateral_body"],
			"right_side": ["right_lateral_body"],
		},
		"automatic_creature_guidance_enabled": false,
	}


static func profile() -> Dictionary:
	return {
		"schema_version": "recovery_profile_configuration_v1",
		"profile_id": "labeled_box_prone_recovery_feasibility",
		"accepted_start_poses": ["prone"],
		"required_joint_roles": ["front_hip", "rear_hip"],
		"candidate_contact_roles": ["front_pad", "rear_pad"],
		"forbidden_contact_roles": ["head"],
		"phases":
		[
			{
				"phase_id": "ESTABLISH_SUPPORT",
				"required_joint_roles": ["front_hip", "rear_hip"],
				"required_contact_roles": ["front_pad", "rear_pad"],
				"required_reach_roles": ["front_pad"],
				"required_torque_nm":
				{
					"front_hip": 10.0,
					"rear_hip": 12.0,
				},
				"required_power_w":
				{
					"front_hip": 3.0,
					"rear_hip": 4.0,
				},
				"required_friction_ratio": 0.4,
				"minimum_structural_margin_fraction": 0.1,
				"maximum_duration_s": 1.0,
				"success_dwell_ticks": 6,
			},
		],
		"maximum_duration_s": 4.0,
		"minimum_torque_reserve_fraction": 0.2,
		"automatic_creature_guidance_enabled": false,
		"actuation_authority": false,
	}


static func capabilities() -> Dictionary:
	return {
		"available_joint_roles": ["front_hip", "rear_hip"],
		"available_contact_roles": ["front_pad", "rear_pad"],
		"reachable_contact_roles": ["front_pad", "rear_pad"],
		"joint_capacities":
		{
			"front_hip": _capacity(20.0, 10.0, 30.0),
			"rear_hip": _capacity(24.0, 10.0, 32.0),
		},
		"contact_friction_coefficients":
		{
			"front_pad": 0.8,
			"rear_pad": 0.8,
		},
		"external_assistance_enabled": false,
		"automatic_creature_guidance_enabled": false,
	}


static func box_state(pose: String) -> Dictionary:
	var basis := Basis.IDENTITY
	var contacts: Array = ["feet"]
	var height := 1.0
	var foot_support := true
	match pose:
		"prone":
			basis = Basis(Vector3.RIGHT, -PI / 2.0)
			contacts = ["ventral_body"]
			height = 0.3
			foot_support = false
		"supine":
			basis = Basis(Vector3.RIGHT, PI / 2.0)
			contacts = ["dorsal_body"]
			height = 0.3
			foot_support = false
		"left_side":
			basis = Basis(Vector3.BACK, PI / 2.0)
			contacts = ["left_lateral_body"]
			height = 0.3
			foot_support = false
		"right_side":
			basis = Basis(Vector3.BACK, -PI / 2.0)
			contacts = ["right_lateral_body"]
			height = 0.3
			foot_support = false
		"ambiguous_prone_left":
			var inverse_sqrt_two := sqrt(0.5)
			var right := Vector3(inverse_sqrt_two, inverse_sqrt_two, 0.0)
			var up := Vector3(0.0, 0.0, -1.0)
			var backward := Vector3(-inverse_sqrt_two, inverse_sqrt_two, 0.0)
			basis = Basis(right, up, backward)
			contacts = ["left_lateral_body", "ventral_body"]
			height = 0.3
			foot_support = false
		_:
			pass
	return {
		"basis": basis,
		"support_height_m": height,
		"reference_stance_height_m": 1.0,
		"contact_regions": contacts,
		"has_foot_support": foot_support,
		"linear_speed_m_s": 0.0,
		"angular_speed_rad_s": 0.0,
		"stable_for_ticks": 12,
	}


static func _role(role_id: String, may_bear: bool, steady_stance: bool, tags: Array) -> Dictionary:
	return {
		"role_id": role_id,
		"may_bear_recovery_load": may_bear,
		"allowed_steady_stance": steady_stance,
		"pose_evidence_tags": tags,
	}


static func _capacity(torque: float, power: float, structural: float) -> Dictionary:
	return {
		"maximum_active_torque_nm": torque,
		"maximum_power_w": power,
		"structural_torque_nm": structural,
	}
