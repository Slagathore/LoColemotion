class_name LabCanonicalSpatialQuadrupedProfile
extends RefCounted
# gdlint: disable=max-line-length

## Exact BR14A laboratory morphology preregistration.
##
## This is the conservative spatial expansion of the accepted BR13 fixture:
## the 6 kg torso and 8 kg total system mass are preserved; each 1 kg
## symmetry-collapsed limb pair becomes two 0.5 kg physical limbs; the
## accepted pair actuator budget supplies a conservative per-DOF candidate cap
## after the physical left/right split. Hip abduction and knee pitch are new
## candidate joint roles, not accepted BR13 capacity inferences. Selection
## authorizes only prephysical BR14A.0-BR14A.2 analysis, never physics
## execution or guidance.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "canonical_spatial_quadruped_profile_v1"
const PROFILE_ID := "br14a.wide_low_independent_quadruped.v1"
const POSITIVE_CLAIM := "canonical_spatial_quadruped_preregistered_prephysically"
const CLAIM_BOUNDARY := (
	"BR14A exact laboratory morphology preregistration only: one wide, low, "
	+ "independently actuated 12-DOF quadruped conservatively expanded from "
	+ "the accepted BR13 symmetry-collapsed fixture. Selection authorizes "
	+ "only BR14A.0-BR14A.2 prephysical analysis. It establishes no physical "
	+ "execution, inverse-kinematic reach, collision clearance, complete "
	+ "inverse dynamics, free-3D stance, bracing, catch, fall arrest, get-up, "
	+ "morphology transfer, final game-creature anatomy, step, gait, walking, "
	+ "repair, automatic application, or creature guidance."
)
const PROFILE_FIELDS: Array[String] = [
	"schema_version",
	"profile_id",
	"source_planar_profile_id",
	"selection_rationale",
	"coordinate_frame",
	"characteristic_length_m",
	"gravity_m_s2",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"torso",
	"limbs",
	"whole_system_center_of_mass_world_m",
	"whole_system_mass_kg",
	"contact_friction_coefficient",
	"contact_normal_capacity_n",
	"actuator_template",
	"minimum_joint_limit_margin_rad",
	"required_wrench_axes",
	"intentionally_omitted_wrench_axes",
	"allowed_scaffolds",
	"seed_set",
	"required_prephysical_cells",
	"future_physical_cells",
	"expected_infeasible_controls",
	"positive_claim",
	"claim_boundary",
	"physical_execution_authorized",
	"morphology_generalization_allowed",
	"final_game_creature_selected",
	"step_gait_or_walking_claim_allowed",
	"automatic_creature_guidance_allowed",
]
const LIMB_FIELDS: Array[String] = [
	"limb_id",
	"longitudinal_role",
	"lateral_role",
	"upper_mass_kg",
	"lower_mass_kg",
	"upper_length_m",
	"lower_length_m",
	"foot_radius_m",
	"hip_world_m",
	"knee_world_m",
	"foot_center_world_m",
	"contact_point_world_m",
	"joint_dofs",
]
const JOINT_FIELDS: Array[String] = [
	"joint_id",
	"joint_group_id",
	"role",
	"axis_world",
	"pivot_world_m",
	"angle_rad",
	"minimum_angle_rad",
	"maximum_angle_rad",
]
const TORSO_FIELDS: Array[String] = [
	"body_id",
	"mass_kg",
	"size_m",
	"center_world_m",
]
const ACTUATOR_TEMPLATE_FIELDS: Array[String] = [
	"enabled",
	"max_isometric_torque_nm",
	"no_load_speed_rad_s",
	"max_positive_power_w",
	"max_absorption_power_w",
	"max_eccentric_multiplier",
	"activation_time_s",
	"deactivation_time_s",
	"max_torque_rate_nm_s",
	"structural_torque_limit_nm",
	"tear_dwell_s",
	"capacity_source",
	"muscle_pcsa_m2",
	"specific_tension_pa",
	"moment_arm_m",
]


static func configuration() -> Dictionary:
	var limbs: Array = []
	for longitudinal in ["front", "rear"]:
		for lateral in ["left", "right"]:
			var x := -0.22 if longitudinal == "front" else 0.22
			var z_sign := -1.0 if lateral == "left" else 1.0
			var hip := Vector3(x, 0.40, 0.10 * z_sign)
			var foot_center := Vector3(x, 0.05, 0.22 * z_sign)
			var midpoint := 0.5 * (hip + foot_center)
			var half_span := 0.5 * hip.distance_to(foot_center)
			var knee_offset := sqrt(0.25 * 0.25 - half_span * half_span)
			var knee_x := x - knee_offset if longitudinal == "front" else x + knee_offset
			var knee := Vector3(knee_x, midpoint.y, midpoint.z)
			var limb_id := "%s_%s" % [longitudinal, lateral]
			limbs.append(_limb(limb_id, longitudinal, lateral, hip, knee, foot_center))
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": PROFILE_ID,
		"source_planar_profile_id": "canonical_symmetry_collapsed_quadruped_prone_v1",
		"selection_rationale":
		"Spatial expansion preserving accepted BR13 mass; hip-pitch pair capacity split left/right; new hip-abduction and knee roles use the same explicit-lab per-DOF candidate cap without claiming anatomical derivation; wide ordinary-contact support polygon; no choice of final game anatomy.",
		"coordinate_frame": "centroidal_world_x_forward_y_up_z_right",
		"characteristic_length_m": 0.60,
		"gravity_m_s2": 9.8,
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 4,
		"torso":
		{
			"body_id": "torso",
			"mass_kg": 6.0,
			"size_m": [0.60, 0.16, 0.20],
			"center_world_m": [0.0, 0.44, 0.0],
		},
		"limbs": limbs,
		"whole_system_center_of_mass_world_m": [0.0, 0.38625, 0.0],
		"whole_system_mass_kg": 8.0,
		"contact_friction_coefficient": 0.60,
		"contact_normal_capacity_n": 39.2,
		"actuator_template":
		{
			"enabled": true,
			"max_isometric_torque_nm": 30.0,
			"no_load_speed_rad_s": 30.0,
			"max_positive_power_w": 250.0,
			"max_absorption_power_w": 400.0,
			"max_eccentric_multiplier": 1.5,
			"activation_time_s": 0.005,
			"deactivation_time_s": 0.050,
			"max_torque_rate_nm_s": 4000.0,
			"structural_torque_limit_nm": 40.0,
			"tear_dwell_s": 0.05,
			"capacity_source": "explicit_lab",
			"muscle_pcsa_m2": 0.0,
			"specific_tension_pa": 0.0,
			"moment_arm_m": 0.0,
		},
		"minimum_joint_limit_margin_rad": 0.20,
		"required_wrench_axes":
		["force_x", "force_y", "force_z", "moment_x", "moment_y", "moment_z"],
		"intentionally_omitted_wrench_axes": [],
		"allowed_scaffolds": [],
		"seed_set": [14001, 14002, 14003],
		"required_prephysical_cells":
		[
			"BR14A.0.non_scaffold_spatial_rank",
			"BR14A.1.symmetric_weight_contact_feasibility",
			"BR14A.2.declared_actuator_load_envelope",
		],
		"future_physical_cells":
		[
			"BR14A.3.free_3d_static_stance",
			"BR14A.4.free_3d_existing_contact_arrest",
			"BR14A.5.free_3d_protective_contact",
			"BR14A.6.free_3d_get_up",
			"BR14A.7.scaffold_annealing_and_adversarial_controls",
		],
		"expected_infeasible_controls":
		[
			"low_friction_lateral_wrench",
			"front_left_abduction_disabled",
			"any_scaffold_injected",
		],
		"positive_claim": POSITIVE_CLAIM,
		"claim_boundary": CLAIM_BOUNDARY,
		"physical_execution_authorized": false,
		"morphology_generalization_allowed": false,
		"final_game_creature_selected": false,
		"step_gait_or_walking_claim_allowed": false,
		"automatic_creature_guidance_allowed": false,
	}


static func compile(candidate: Dictionary) -> Dictionary:
	if not _exact_fields(candidate, PROFILE_FIELDS):
		return _failure("CANONICAL_SPATIAL_PROFILE_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_PROFILE_NOT_EXACT")
	if not _derived_invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_PROFILE_DERIVED_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["profile_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["canonical_morphology_selected_prephysically"] = true
	return {"ok": true, "profile": FrozenValueScript.snapshot(sealed)}


static func _limb(
	limb_id: String,
	longitudinal: String,
	lateral: String,
	hip: Vector3,
	knee: Vector3,
	foot_center: Vector3
) -> Dictionary:
	var contact := Vector3(foot_center.x, 0.0, foot_center.z)
	var pitch_axis := (knee - hip).cross(foot_center - knee).normalized()
	return {
		"limb_id": limb_id,
		"longitudinal_role": longitudinal,
		"lateral_role": lateral,
		"upper_mass_kg": 0.25,
		"lower_mass_kg": 0.25,
		"upper_length_m": 0.25,
		"lower_length_m": 0.25,
		"foot_radius_m": 0.05,
		"hip_world_m": _array(hip),
		"knee_world_m": _array(knee),
		"foot_center_world_m": _array(foot_center),
		"contact_point_world_m": _array(contact),
		"joint_dofs":
		[
			_joint(
				"%s.hip_abduction" % limb_id,
				"%s.hip" % limb_id,
				"hip_abduction",
				Vector3.RIGHT,
				hip,
				-0.8,
				0.8
			),
			_joint(
				"%s.hip_pitch" % limb_id,
				"%s.hip" % limb_id,
				"hip_pitch",
				pitch_axis,
				hip,
				-1.5,
				1.5
			),
			_joint(
				"%s.knee_pitch" % limb_id,
				"%s.knee" % limb_id,
				"knee_pitch",
				pitch_axis,
				knee,
				-1.8,
				1.8
			),
		],
	}


static func _joint(
	joint_id: String,
	joint_group_id: String,
	role: String,
	axis: Vector3,
	pivot: Vector3,
	minimum: float,
	maximum: float
) -> Dictionary:
	return {
		"joint_id": joint_id,
		"joint_group_id": joint_group_id,
		"role": role,
		"axis_world": _array(axis),
		"pivot_world_m": _array(pivot),
		"angle_rad": 0.0,
		"minimum_angle_rad": minimum,
		"maximum_angle_rad": maximum,
	}


static func _derived_invariants_hold(profile: Dictionary) -> bool:
	if not _exact_fields(profile["torso"], TORSO_FIELDS):
		return false
	if not _exact_fields(profile["actuator_template"], ACTUATOR_TEMPLATE_FIELDS):
		return false
	var limbs: Array = profile["limbs"]
	if limbs.size() != 4:
		return false
	var mass := float(profile["torso"]["mass_kg"])
	var limb_ids: Dictionary = {}
	var joint_ids: Dictionary = {}
	var contact_ids: Dictionary = {}
	for limb_value in limbs:
		if typeof(limb_value) != TYPE_DICTIONARY:
			return false
		var limb: Dictionary = limb_value
		if not _exact_fields(limb, LIMB_FIELDS):
			return false
		var limb_id := String(limb["limb_id"])
		if limb_ids.has(limb_id):
			return false
		limb_ids[limb_id] = true
		contact_ids["%s.foot" % limb_id] = true
		mass += float(limb["upper_mass_kg"]) + float(limb["lower_mass_kg"])
		var hip := _vector3(limb["hip_world_m"])
		var knee := _vector3(limb["knee_world_m"])
		var foot := _vector3(limb["foot_center_world_m"])
		if (
			absf(hip.distance_to(knee) - float(limb["upper_length_m"])) > 1.0e-6
			or absf(knee.distance_to(foot) - float(limb["lower_length_m"])) > 1.0e-6
			or (limb["joint_dofs"] as Array).size() != 3
		):
			return false
		for joint_value in limb["joint_dofs"]:
			if typeof(joint_value) != TYPE_DICTIONARY:
				return false
			var joint: Dictionary = joint_value
			if not _exact_fields(joint, JOINT_FIELDS):
				return false
			var joint_id := String(joint["joint_id"])
			if joint_ids.has(joint_id):
				return false
			joint_ids[joint_id] = true
			if absf(_vector3(joint["axis_world"]).length() - 1.0) > 1.0e-6:
				return false
	return (
		absf(mass - float(profile["whole_system_mass_kg"])) <= 1.0e-9
		and contact_ids.size() == 4
		and joint_ids.size() == 12
		and (profile["allowed_scaffolds"] as Array).is_empty()
		and (profile["intentionally_omitted_wrench_axes"] as Array).is_empty()
		and not bool(profile["physical_execution_authorized"])
		and not bool(profile["morphology_generalization_allowed"])
		and not bool(profile["final_game_creature_selected"])
		and not bool(profile["step_gait_or_walking_claim_allowed"])
		and not bool(profile["automatic_creature_guidance_allowed"])
	)


static func _array(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]


static func _vector3(value: Variant) -> Vector3:
	var array: Array = value
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


static func _exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
