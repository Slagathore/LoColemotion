class_name LabCanonicalSpatialWrenchContactCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed development contract for the third BR14A.5 controller family.
##
## Candidate 3 retains candidate 2's measured-state preparation and
## damped-least-squares swing map, then adds the separately commissioned
## whole-system centroidal allocator as an explicit commanded-wrench
## correction on the three stance limbs. It remains development-only until a
## separate commissioning test judges every preregistered physical gate.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate2Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_centroidal_contact_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_wrench_contact_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_spatial_wrench_contact_candidate.v1"
const CANDIDATE_STATUS := "candidate_rejected_contact_transition_wrench_infeasible"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 third-candidate rejection commissioning only: the selected "
	+ "nine-body, 12-DOF quadruped may execute candidate 2's source-pinned "
	+ "measured-state preparation and damped-least-squares swing map with a "
	+ "declared vertical-then-horizontal clearance path while the "
	+ "separately commissioned whole-system centroidal allocator contributes "
	+ "bounded commanded-wrench deltas through receipt-backed equal/opposite "
	+ "joint torques and a preferred four-to-three contact transition. Allocated "
	+ "per-contact values are commands, not measured loads. The exact first seed "
	+ "fails closed when physical swing-contact loss makes the zero-feedback "
	+ "three-contact wrench exceed a pinned contact-normal capacity; that one "
	+ "witness rejects only this exact all-seed candidate. Unexecuted seeds receive "
	+ "no conclusion, and the rejection does not prove the morphology or all future "
	+ "controllers incapable. This establishes no protective contact, free-3D "
	+ "recovery, per-foot measured load allocation, "
	+ "bearing, load transfer, locomotor step, gait, walking, formal acceptance, "
	+ "encyclopedia knowledge, repair, automatic application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate2Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_SPATIAL_WRENCH_PROTECTIVE_CONTACT_DEVELOPMENT"
	candidate["vertical_lift_complete_tick"] = 780
	candidate["swing_lift_path_policy"] = "vertical_then_horizontal_smoothstep_v1"
	candidate["centroidal_controller_id"] = ("whole_system_allocator_joint_task_delta_v1")
	candidate["support_target_policy"] = ("preferred_four_to_three_contact_wrench_plus_discrete_authority_projection_v1")
	candidate["causal_control"] = ("source_pinned_shift_lift_allocator_disturbance_and_touchdown_timeline_v1")
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	if not _exact_fields(candidate, Candidate2Script.FIELDS):
		return _failure("CANONICAL_SPATIAL_WRENCH_CONTACT_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_WRENCH_CONTACT_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_WRENCH_CONTACT_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	return (
		String(candidate["schema_version"]) == SCHEMA_VERSION
		and String(candidate["experiment_id"]) == EXPERIMENT_ID
		and (
			String(candidate["centroidal_controller_id"])
			== "whole_system_allocator_joint_task_delta_v1"
		)
		and (
			String(candidate["swing_lift_path_policy"]) == "vertical_then_horizontal_smoothstep_v1"
		)
		and int(candidate["lift_start_tick"]) < int(candidate["vertical_lift_complete_tick"])
		and int(candidate["vertical_lift_complete_tick"]) < int(candidate["lift_complete_tick"])
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_STATUS
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and bool(candidate["physical_development_execution_authorized"])
		and bool(candidate["physical_commissioning_execution_authorized"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
		and not bool(candidate["per_foot_load_claim_allowed"])
		and not bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["step_gait_or_walking_claim_allowed"])
		and not bool(candidate["automatic_creature_guidance_allowed"])
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
