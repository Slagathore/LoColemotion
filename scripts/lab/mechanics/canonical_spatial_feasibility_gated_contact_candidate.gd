class_name LabCanonicalSpatialFeasibilityGatedContactCandidate
extends RefCounted
# gdlint: disable=max-line-length

## Sealed rejection contract for the fourth BR14A.5 controller family.
##
## Candidate 4 retains candidate 3's receipt-backed whole-system allocator and
## staged swing map, but swing-path time is no longer wall-clock time. A
## read-only, zero-feedback three-contact wrench preflight and the already
## declared COM/capture handoff margin must both pass before each path
## increment. Failure retreats the path and reloads the fourth contact until
## the higher declared release margin is recovered; it never clips a force
## command or silently proceeds into an infeasible contact transition.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const Candidate2Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_centroidal_contact_candidate.gd"
)
const Candidate3Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_wrench_contact_candidate.gd"
)

const SCHEMA_VERSION := "canonical_spatial_feasibility_gated_contact_candidate_v1"
const EXPERIMENT_ID := "BR14A.5.front_right_feasibility_gated_contact_candidate.v1"
const CANDIDATE_STATUS := "candidate_rejected_safe_abort_no_clearance_rearm"
const CONTROLLER_ID := "predictive_feasibility_gated_whole_system_allocator_v1"
const SWING_PATH_POLICY := "feasibility_gated_vertical_then_horizontal_smoothstep_v1"
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 fourth-candidate rejection commissioning only: the selected "
	+ "nine-body, 12-DOF quadruped may execute a live-incenter, event-progressed "
	+ "front-right staged swing path only while a read-only zero-feedback "
	+ "three-contact wrench preflight, COM margin, and linearized capture margin "
	+ "all retain the exact declared feasible handoff. Gate loss retreats and "
	+ "reloads the swing contact until the higher declared release margin is "
	+ "recovered. The candidate retains "
	+ "candidate 3's preferred four-to-three whole-system wrench commands through "
	+ "receipt-backed equal/opposite joint torques. Preflight and allocated "
	+ "per-contact values are commands, not measured loads. The exact first seed "
	+ "retreats safely to zero swing progress, suppresses its disturbance, and "
	+ "returns near its initial four-contact pose, but never re-establishes the "
	+ "three-contact readiness gate or clears the selected foot. That witness "
	+ "rejects only this exact all-seed state machine; unexecuted seeds receive no "
	+ "conclusion. This establishes no protective contact, free-3D recovery, per-foot "
	+ "measured load allocation, bearing, load transfer, locomotor step, gait, "
	+ "walking, formal acceptance, encyclopedia knowledge, repair, automatic "
	+ "application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := Candidate3Script.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_FEASIBILITY_GATED_PROTECTIVE_CONTACT_DEVELOPMENT"
	candidate["centroidal_controller_id"] = CONTROLLER_ID
	candidate["swing_lift_path_policy"] = SWING_PATH_POLICY
	candidate["support_target_policy"] = ("live_triangle_incenter_plus_predictive_three_contact_wrench_gate_v1")
	candidate["causal_control"] = ("source_pinned_shift_event_progressed_lift_conditional_disturbance_and_touchdown_v1")
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	candidate["swing_progress_stride_ticks"] = 4
	candidate["infeasible_retreat_progress_ticks"] = 4
	candidate["feasibility_release_dwell_ticks_required"] = 40
	candidate["maximum_swing_attitude_deviation_rad"] = 0.04
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	if not _exact_fields(candidate, _fields()):
		return _failure("CANONICAL_SPATIAL_FEASIBILITY_GATED_FIELDS_INVALID")
	var canonical := configuration()
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_FEASIBILITY_GATED_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_FEASIBILITY_GATED_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	return (
		String(candidate["schema_version"]) == SCHEMA_VERSION
		and String(candidate["experiment_id"]) == EXPERIMENT_ID
		and String(candidate["centroidal_controller_id"]) == CONTROLLER_ID
		and String(candidate["swing_lift_path_policy"]) == SWING_PATH_POLICY
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_STATUS
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and int(candidate["swing_progress_stride_ticks"]) >= 1
		and int(candidate["infeasible_retreat_progress_ticks"]) >= 1
		and int(candidate["feasibility_release_dwell_ticks_required"]) >= 1
		and float(candidate["maximum_swing_attitude_deviation_rad"]) > 0.0
		and (
			float(candidate["maximum_swing_attitude_deviation_rad"])
			< float(candidate["recovery_tilt_limit_rad"])
		)
		and float(candidate["minimum_three_contact_handoff_margin_m"]) > 0.0
		and int(candidate["lift_start_tick"]) < int(candidate["vertical_lift_complete_tick"])
		and int(candidate["vertical_lift_complete_tick"]) < int(candidate["lift_complete_tick"])
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


static func _fields() -> Array[String]:
	var fields: Array[String] = []
	fields.assign(Candidate2Script.FIELDS)
	(
		fields
		. append_array(
			[
				"swing_progress_stride_ticks",
				"infeasible_retreat_progress_ticks",
				"feasibility_release_dwell_ticks_required",
				"maximum_swing_attitude_deviation_rad",
			]
		)
	)
	return fields


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
