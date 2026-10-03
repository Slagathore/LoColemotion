class_name LabCanonicalSpatialArrestExperiment
extends RefCounted

## Exact BR14A.4 existing-contact spatial disturbance-arrest contract.
##
## Both worlds use the same pose-feedback controller before the declared
## disturbance. The active world retains feedback afterward; the causal
## control retains only the same static feedforward commands. No foot is
## moved and no new contact is created.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const StanceExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_stance_experiment.gd"
)

const SCHEMA_VERSION := "canonical_spatial_arrest_experiment_v1"
const EXPERIMENT_ID := "BR14A.4.canonical_existing_contact_roll_arrest.v1"
const POSITIVE_CLAIM := "canonical_existing_contact_roll_arrest_observed_in_commissioning"
const CLAIM_BOUNDARY := (
	"Exact BR14A.4 commissioning only: after the selected BR14A quadruped "
	+ "establishes its preregistered four-contact stance, one declared world-X "
	+ "torque impulse is applied to the torso in both matched worlds. The active "
	+ "world retains preregistered pose feedback; the control retains the same "
	+ "static feedforward but loses pose feedback. A passing run may report "
	+ "bounded existing-contact roll arrest for this exact morphology, controller, "
	+ "disturbance, solver, seed set, and thresholds. It is not formal BR14A "
	+ "acceptance, measured per-foot load allocation, new-contact bracing, fall "
	+ "arrest, get-up, morphology transfer, a load-transfer step, gait, walking, "
	+ "repair, automatic application, or creature guidance."
)
const FIELDS: Array[String] = [
	"schema_version",
	"experiment_id",
	"source_profile_id",
	"source_profile_sha256",
	"source_stance_experiment_id",
	"source_stance_experiment_sha256",
	"behavior_state",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"trial_ticks",
	"disturbance_tick",
	"disturbance_axis_world",
	"disturbance_torque_impulse_nms",
	"position_gain_nm_per_rad",
	"velocity_gain_nm_s_per_rad",
	"pre_disturbance_height_error_limit_m",
	"pre_disturbance_tilt_limit_rad",
	"recovery_height_error_limit_m",
	"recovery_tilt_limit_rad",
	"recovery_axis_speed_limit_rad_s",
	"recovery_full_speed_limit_rad_s",
	"recovery_dwell_ticks_required",
	"maximum_recovery_ticks",
	"minimum_observed_peak_axis_speed_rad_s",
	"minimum_post_disturbance_contact_fraction",
	"maximum_anchor_error_m",
	"maximum_hinge_axis_error_rad",
	"maximum_structural_torque_nm",
	"active_seed_set",
	"causal_control",
	"allowed_static_bodies",
	"allowed_scaffolds",
	"positive_claim",
	"claim_boundary",
	"physical_commissioning_execution_authorized",
	"formal_milestone_acceptance_authorized",
	"encyclopedia_admission_authorized",
	"step_gait_or_walking_claim_allowed",
	"automatic_creature_guidance_allowed",
]


static func configuration() -> Dictionary:
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var stance_result := StanceExperimentScript.compile(StanceExperimentScript.configuration())
	assert(bool(profile_result.get("ok", false)))
	assert(bool(stance_result.get("ok", false)))
	var profile: Dictionary = profile_result["profile"]
	var stance: Dictionary = stance_result["experiment"]
	return {
		"schema_version": SCHEMA_VERSION,
		"experiment_id": EXPERIMENT_ID,
		"source_profile_id": profile["profile_id"],
		"source_profile_sha256": profile["profile_sha256"],
		"source_stance_experiment_id": stance["experiment_id"],
		"source_stance_experiment_sha256": stance["experiment_sha256"],
		"behavior_state": "FREE_3D_EXISTING_CONTACT_ROLL_ARREST",
		"physics_hz": profile["physics_hz"],
		"solver_velocity_steps": profile["solver_velocity_steps"],
		"solver_position_steps": profile["solver_position_steps"],
		"trial_ticks": 720,
		"disturbance_tick": 360,
		"disturbance_axis_world": [1.0, 0.0, 0.0],
		"disturbance_torque_impulse_nms": 0.020,
		"position_gain_nm_per_rad": stance["position_gain_nm_per_rad"],
		"velocity_gain_nm_s_per_rad": stance["velocity_gain_nm_s_per_rad"],
		"pre_disturbance_height_error_limit_m": stance["height_error_limit_m"],
		"pre_disturbance_tilt_limit_rad": stance["tilt_limit_rad"],
		"recovery_height_error_limit_m": stance["height_error_limit_m"],
		"recovery_tilt_limit_rad": stance["tilt_limit_rad"],
		"recovery_axis_speed_limit_rad_s": 0.08,
		"recovery_full_speed_limit_rad_s": stance["angular_speed_limit_rad_s"],
		"recovery_dwell_ticks_required": 60,
		"maximum_recovery_ticks": 180,
		"minimum_observed_peak_axis_speed_rad_s": 0.20,
		"minimum_post_disturbance_contact_fraction": 0.95,
		"maximum_anchor_error_m": stance["maximum_anchor_error_m"],
		"maximum_hinge_axis_error_rad": stance["maximum_hinge_axis_error_rad"],
		"maximum_structural_torque_nm": stance["maximum_structural_torque_nm"],
		"active_seed_set": profile["seed_set"],
		"causal_control": "pose_feedback_withdrawn_after_identical_disturbance",
		"allowed_static_bodies": ["ordinary_floor"],
		"allowed_scaffolds": [],
		"positive_claim": POSITIVE_CLAIM,
		"claim_boundary": CLAIM_BOUNDARY,
		"physical_commissioning_execution_authorized": true,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"step_gait_or_walking_claim_allowed": false,
		"automatic_creature_guidance_allowed": false,
	}


static func compile(candidate: Dictionary) -> Dictionary:
	if not _exact_fields(candidate, FIELDS):
		return _failure("CANONICAL_SPATIAL_ARREST_EXPERIMENT_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_ARREST_EXPERIMENT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_ARREST_EXPERIMENT_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_commissioning_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var stance_result := StanceExperimentScript.compile(StanceExperimentScript.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(stance_result.get("ok", false)):
		return false
	var profile: Dictionary = profile_result["profile"]
	var stance: Dictionary = stance_result["experiment"]
	return (
		String(candidate["source_profile_sha256"]) == String(profile["profile_sha256"])
		and (
			String(candidate["source_stance_experiment_sha256"])
			== String(stance["experiment_sha256"])
		)
		and int(candidate["disturbance_tick"]) > int(stance["dwell_ticks_required"])
		and int(candidate["disturbance_tick"]) < int(candidate["trial_ticks"])
		and (
			int(candidate["maximum_recovery_ticks"]) + int(candidate["disturbance_tick"])
			<= int(candidate["trial_ticks"])
		)
		and _vector3(candidate["disturbance_axis_world"]).is_equal_approx(Vector3.RIGHT)
		and float(candidate["disturbance_torque_impulse_nms"]) > 0.0
		and (candidate["active_seed_set"] as Array) == (profile["seed_set"] as Array)
		and (candidate["allowed_static_bodies"] as Array) == ["ordinary_floor"]
		and (candidate["allowed_scaffolds"] as Array).is_empty()
		and bool(candidate["physical_commissioning_execution_authorized"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["step_gait_or_walking_claim_allowed"])
		and not bool(candidate["automatic_creature_guidance_allowed"])
		and String(candidate["positive_claim"]) == POSITIVE_CLAIM
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
	)


static func _exact_fields(value: Dictionary, fields: Array[String]) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func _vector3(value: Variant) -> Vector3:
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
