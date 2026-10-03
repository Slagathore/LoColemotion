class_name LabCanonicalSpatialStanceExperiment
extends RefCounted

## Exact BR14A.3 physical-execution contract.
##
## The morphology profile deliberately authorizes only prephysical selection.
## This separate contract crosses only the bounded commissioning boundary for
## the named free-3D stance fixture. It freezes controller gains, run length,
## success envelopes, controls, and nonclaims before final evidence is taken.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")

const SCHEMA_VERSION := "canonical_spatial_stance_experiment_v1"
const EXPERIMENT_ID := "BR14A.3.canonical_free_3d_static_stance.v1"
const POSITIVE_CLAIM := "canonical_free_3d_static_stance_observed_in_commissioning"
const CLAIM_BOUNDARY := (
	"Exact BR14A.3 commissioning only: the selected nine-body, 12-DOF "
	+ "laboratory quadruped may be executed for the named active-versus-zero-command "
	+ "free-3D static-stance experiment on an ordinary floor. A passing run may "
	+ "report a bounded stance observation for this exact morphology, controller, "
	+ "seed set, solver configuration, and thresholds. It is not formal milestone "
	+ "acceptance, accepted encyclopedia knowledge, per-foot load allocation, "
	+ "recovery, protective contact, bracing, fall arrest, get-up, morphology "
	+ "transfer, final game-creature anatomy, step, gait, walking, repair, "
	+ "automatic application, or creature guidance."
)
const FIELDS: Array[String] = [
	"schema_version",
	"experiment_id",
	"source_profile_id",
	"source_profile_sha256",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
	"trial_ticks",
	"dwell_ticks_required",
	"controller_id",
	"position_gain_nm_per_rad",
	"velocity_gain_nm_s_per_rad",
	"height_error_limit_m",
	"tilt_limit_rad",
	"linear_speed_limit_m_s",
	"angular_speed_limit_rad_s",
	"minimum_contact_fraction",
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
	assert(bool(profile_result.get("ok", false)))
	var profile: Dictionary = profile_result["profile"]
	return {
		"schema_version": SCHEMA_VERSION,
		"experiment_id": EXPERIMENT_ID,
		"source_profile_id": profile["profile_id"],
		"source_profile_sha256": profile["profile_sha256"],
		"physics_hz": profile["physics_hz"],
		"solver_velocity_steps": profile["solver_velocity_steps"],
		"solver_position_steps": profile["solver_position_steps"],
		"trial_ticks": 600,
		"dwell_ticks_required": 120,
		"controller_id": "relative_pose_pd_plus_static_feedforward_v1",
		"position_gain_nm_per_rad": 40.0,
		"velocity_gain_nm_s_per_rad": 0.50,
		"height_error_limit_m": 0.06,
		"tilt_limit_rad": 0.12,
		"linear_speed_limit_m_s": 0.12,
		"angular_speed_limit_rad_s": 0.20,
		"minimum_contact_fraction": 0.95,
		"maximum_anchor_error_m": 0.01,
		"maximum_hinge_axis_error_rad": 0.10,
		"maximum_structural_torque_nm":
		float(profile["actuator_template"]["structural_torque_limit_nm"]),
		"active_seed_set": profile["seed_set"],
		"causal_control": "same_initial_state_zero_command_twin",
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
		return _failure("CANONICAL_SPATIAL_STANCE_EXPERIMENT_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_STANCE_EXPERIMENT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_STANCE_EXPERIMENT_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_commissioning_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	if not bool(profile_result.get("ok", false)):
		return false
	var profile: Dictionary = profile_result["profile"]
	return (
		String(candidate["source_profile_id"]) == String(profile["profile_id"])
		and String(candidate["source_profile_sha256"]) == String(profile["profile_sha256"])
		and int(candidate["physics_hz"]) == int(profile["physics_hz"])
		and int(candidate["solver_velocity_steps"]) == int(profile["solver_velocity_steps"])
		and int(candidate["solver_position_steps"]) == int(profile["solver_position_steps"])
		and int(candidate["trial_ticks"]) >= int(candidate["dwell_ticks_required"])
		and int(candidate["dwell_ticks_required"]) > 0
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


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
