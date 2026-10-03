class_name LabCanonicalSpatialContactStateLiftCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed rejection contract for the sixth BR14A.5 controller family.
##
## The grounded limb receives a vertical-only Jacobian-transpose task command.
## An observed semantic contact absence or positive geometric shape gap is
## required before the controller rebases the actual foot pose and hands
## authority to the free-space resolved-rate swing servo. A bounded release
## commitment can finish that mode switch without advancing the logical swing
## path; afterward, the predictive gate again controls every path increment.
## Neither observation is treated as measured load.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate5Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_blended_lift_contact_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_contact_state_lift_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_contact_state_lift_candidate.v1"
const CANDIDATE_STATUS := "candidate_rejected_geometric_gap_without_semantic_contact_removal"
const CONTROLLER_ID := "predictive_contact_state_lift_allocator_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 sixth-candidate rejection commissioning only: the selected "
	+ "front-right limb switches its commanded support topology to the other "
	+ "three feet, applies a vertical ground-release task, and may rebase into a "
	+ "free-space servo after a positive geometric shape gap. The exact first "
	+ "seed records a 0.002358 m gap while the Jolt semantic manifold remains "
	+ "present, executes the exact eight-tick no-path-advance commitment, reaches "
	+ "only two logical path ticks, and never observes semantic contact absence. "
	+ "It then retreats to zero and finishes inside the declared stance envelope. "
	+ "Contact or gap observations and allocator values are not measured load, "
	+ "bearing, or load allocation. This rejects only the exact all-seed "
	+ "candidate; unexecuted seeds receive no conclusion. It establishes no "
	+ "contact removal, protective contact, locomotor step, gait, walking, formal "
	+ "acceptance, encyclopedia knowledge, repair, automatic application, or "
	+ "creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate5Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_CONTACT_STATE_LIFT_DEVELOPMENT"
	candidate["centroidal_controller_id"] = CONTROLLER_ID
	candidate["contact_release_target_height_m"] = 0.150
	candidate["contact_release_target_velocity_m_s"] = 0.12
	candidate["contact_release_position_gain_n_per_m"] = 1000.0
	candidate["contact_release_velocity_gain_ns_per_m"] = 20.0
	candidate["maximum_contact_release_task_force_n"] = 40.0
	candidate["contact_release_blend_ticks"] = 1
	candidate["contact_release_dwell_ticks_required"] = 1
	candidate["contact_release_minimum_geometric_gap_m"] = 0.0015
	candidate["post_release_minimum_upward_velocity_m_s"] = 0.20
	candidate["post_release_velocity_hold_path_ticks"] = 12
	candidate["post_release_commit_ticks"] = 8
	candidate["swing_servo_blend_progress_ticks"] = 1
	candidate["swing_joint_velocity_gain_nm_s_per_rad"] = 20.0
	candidate["maximum_swing_joint_torque_nm"] = 30.0
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_CONTACT_STATE_LIFT_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_CONTACT_STATE_LIFT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_CONTACT_STATE_LIFT_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	return (
		String(candidate["schema_version"]) == SCHEMA_VERSION
		and String(candidate["experiment_id"]) == EXPERIMENT_ID
		and String(candidate["centroidal_controller_id"]) == CONTROLLER_ID
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_STATUS
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and int(candidate["pre_lift_unload_progress_ticks"]) == 0
		and float(candidate["contact_release_target_height_m"]) > 0.05
		and float(candidate["contact_release_target_velocity_m_s"]) > 0.0
		and float(candidate["contact_release_position_gain_n_per_m"]) > 0.0
		and float(candidate["contact_release_velocity_gain_ns_per_m"]) >= 0.0
		and float(candidate["maximum_contact_release_task_force_n"]) > 0.0
		and int(candidate["contact_release_blend_ticks"]) >= 1
		and int(candidate["contact_release_dwell_ticks_required"]) >= 1
		and float(candidate["contact_release_minimum_geometric_gap_m"]) > 0.0
		and float(candidate["post_release_minimum_upward_velocity_m_s"]) > 0.0
		and int(candidate["post_release_velocity_hold_path_ticks"]) >= 1
		and int(candidate["post_release_commit_ticks"]) >= 1
		and int(candidate["swing_servo_blend_progress_ticks"]) == 1
		and float(candidate["swing_joint_velocity_gain_nm_s_per_rad"]) == 20.0
		and float(candidate["maximum_swing_joint_torque_nm"]) == 30.0
		and bool(candidate["physical_development_execution_authorized"])
		and bool(candidate["physical_commissioning_execution_authorized"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["per_foot_load_claim_allowed"])
		and not bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["step_gait_or_walking_claim_allowed"])
		and not bool(candidate["automatic_creature_guidance_allowed"])
	)


static func _same_fields(value: Dictionary, canonical: Dictionary) -> bool:
	if value.size() != canonical.size():
		return false
	for field in canonical:
		if not value.has(field):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
