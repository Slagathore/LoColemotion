class_name LabCanonicalSpatialRearLeftBoundedAtomicLocomotorStep
extends RefCounted
# gdlint: disable=max-line-length

## Sealed positive contract for one rear-left diagonal atomic locomotor step.
##
## This establishes limb-level portability in an independent fresh world. It
## does not establish same-world alternation or repeated stepping.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const FrontRightStepScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_bounded_atomic_locomotor_step.gd"
)

const SCHEMA_VERSION := "canonical_spatial_rear_left_bounded_atomic_locomotor_step_v1"
const EXPERIMENT_ID := "BR14A.5.rear_left_bounded_atomic_locomotor_step.v1"
const CANDIDATE_STATUS := "positive_rear_left_bounded_atomic_locomotor_step"
const ATOMIC_STEP_POLICY_ID := "single_relocation_then_directed_body_translation_v1"
const EXACT_SEEDS := [14001, 14002, 14003]
const CLAIM_BOUNDARY := (
	"Exact BR14A.5 diagonal-limb atomic-step commissioning only: across seeds "
	+ "14001, 14002, and 14003, the nine-body free-3D canonical morphology "
	+ "releases its rear-left foot, commands a 0.025 m forward and 0.012 m "
	+ "upward clearance target with bounded 700 N/m position gain, 30 N*s/m "
	+ "velocity gain, and 20 N task-force cap, and creates an ordinary floor "
	+ "contact after at least 0.014 m horizontal relocation with no more than "
	+ "0.012 m target error. After the inherited 600-tick settling delay, COM "
	+ "and torso must advance at least 0.008 m and 0.009 m in positive world X. "
	+ "A fixed post-recontact interval from ticks 1000 through 1299 suppresses "
	+ "the roll/pitch velocity-feedback terms that development proved could "
	+ "inject energy for this support geometry; position feedback and all "
	+ "existing force/moment caps remain active. A ground-mediated yaw-rate "
	+ "damper is capped at 0.2 N*m requested moment and 0.5 N per endpoint. "
	+ "Final foot relocation must remain 0.035-0.065 m, final foothold error "
	+ "may not exceed 0.065 m, lateral body translation may not exceed 0.003 m, "
	+ "and translation-phase foot slip may not exceed 0.010 m. Long-horizon "
	+ "quiet recovery, four ordinary contacts, zero torso contact, complete "
	+ "paired-actuation receipts, intact joint geometry, zero structural "
	+ "saturation, and zero allocator infeasibility remain mandatory. This "
	+ "establishes one rear-left bounded atomic locomotor step in a fresh world "
	+ "and two-limb atomic-step portability when combined with the separately "
	+ "commissioned front-right program. It establishes no same-world second "
	+ "step, alternation, repeated stepping, gait, walking, speed control, "
	+ "steering, terrain or morphology transfer, accurate final foothold "
	+ "placement, formal milestone acceptance, encyclopedia knowledge, repair, "
	+ "automatic application, or creature guidance."
)


static func configuration() -> Dictionary:
	var candidate := FrontRightStepScript.configuration().duplicate(true)
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["experiment_id"] = EXPERIMENT_ID
	candidate["behavior_state"] = "FREE_3D_REAR_LEFT_BOUNDED_ATOMIC_LOCOMOTOR_STEP"
	candidate["swing_limb_id"] = "rear_left"
	candidate["swing_contact_id"] = "rear_left.foot"
	candidate["semantic_relocation_clear_offset_m"] = [0.025, 0.012, 0.0]
	candidate["semantic_relocation_lift_ticks"] = 6
	candidate["semantic_relocation_lower_ticks"] = 10
	candidate["semantic_relocation_position_gain_n_per_m"] = 700.0
	candidate["semantic_relocation_velocity_gain_ns_per_m"] = 30.0
	candidate["maximum_semantic_relocation_task_force_n"] = 20.0
	candidate["maximum_semantic_recontact_latency_ticks"] = 20
	candidate["minimum_semantic_relocation_horizontal_displacement_m"] = 0.014
	candidate["maximum_semantic_relocation_horizontal_target_error_m"] = 0.012
	candidate["minimum_post_recontact_com_translation_m"] = 0.008
	candidate["minimum_post_recontact_torso_translation_m"] = 0.009
	candidate["post_recontact_roll_velocity_gain_nm_s_per_rad"] = 0.0
	candidate["post_recontact_pitch_velocity_gain_nm_s_per_rad"] = 0.0
	candidate["post_recontact_attitude_velocity_feedback_override_delay_ticks"] = 1000
	candidate["post_recontact_attitude_velocity_feedback_override_duration_ticks"] = 300
	candidate["post_recontact_yaw_rate_damping_enabled"] = true
	candidate["post_recontact_yaw_rate_gain_nm_s_per_rad"] = 1.0
	candidate["maximum_post_recontact_yaw_damping_moment_nm"] = 0.2
	candidate["maximum_post_recontact_yaw_damping_endpoint_force_n"] = 0.5
	candidate["exact_seed_set"] = EXACT_SEEDS
	candidate["atomic_step_policy_id"] = ATOMIC_STEP_POLICY_ID
	candidate["candidate_status"] = CANDIDATE_STATUS
	candidate["candidate_result"] = CANDIDATE_STATUS
	candidate["claim_boundary"] = CLAIM_BOUNDARY
	candidate["physical_commissioning_execution_authorized"] = true
	candidate["locomotor_step_claim_allowed"] = true
	return candidate


static func compile(candidate: Dictionary) -> Dictionary:
	var canonical := configuration()
	if not _same_fields(candidate, canonical):
		return _failure("CANONICAL_SPATIAL_REAR_LEFT_ATOMIC_STEP_FIELDS_INVALID")
	if CanonicalJsonScript.stringify(candidate) != CanonicalJsonScript.stringify(canonical):
		return _failure("CANONICAL_SPATIAL_REAR_LEFT_ATOMIC_STEP_NOT_EXACT")
	if not _invariants_hold(candidate):
		return _failure("CANONICAL_SPATIAL_REAR_LEFT_ATOMIC_STEP_INVARIANT_INVALID")
	var sealed := candidate.duplicate(true)
	sealed["experiment_sha256"] = CanonicalJsonScript.sha256(candidate)
	sealed["bounded_physical_development_execution_authorized"] = true
	return {"ok": true, "experiment": FrozenValueScript.snapshot(sealed)}


static func _invariants_hold(candidate: Dictionary) -> bool:
	return (
		String(candidate["schema_version"]) == SCHEMA_VERSION
		and String(candidate["experiment_id"]) == EXPERIMENT_ID
		and String(candidate["candidate_status"]) == CANDIDATE_STATUS
		and String(candidate["candidate_result"]) == CANDIDATE_STATUS
		and String(candidate["claim_boundary"]) == CLAIM_BOUNDARY
		and String(candidate["atomic_step_policy_id"]) == ATOMIC_STEP_POLICY_ID
		and String(candidate["swing_limb_id"]) == "rear_left"
		and String(candidate["swing_contact_id"]) == "rear_left.foot"
		and int(candidate["trial_ticks"]) == 2300
		and (candidate["semantic_relocation_clear_offset_m"] as Array) == [0.025, 0.012, 0.0]
		and int(candidate["semantic_relocation_lift_ticks"]) == 6
		and int(candidate["semantic_relocation_lower_ticks"]) == 10
		and is_equal_approx(float(candidate["semantic_relocation_position_gain_n_per_m"]), 700.0)
		and is_equal_approx(float(candidate["semantic_relocation_velocity_gain_ns_per_m"]), 30.0)
		and is_equal_approx(float(candidate["maximum_semantic_relocation_task_force_n"]), 20.0)
		and int(candidate["maximum_semantic_recontact_latency_ticks"]) == 20
		and is_equal_approx(
			float(candidate["minimum_semantic_relocation_horizontal_displacement_m"]), 0.014
		)
		and is_equal_approx(
			float(candidate["maximum_semantic_relocation_horizontal_target_error_m"]), 0.012
		)
		and is_equal_approx(float(candidate["minimum_post_recontact_com_translation_m"]), 0.008)
		and is_equal_approx(float(candidate["minimum_post_recontact_torso_translation_m"]), 0.009)
		and is_equal_approx(float(candidate["post_recontact_roll_velocity_gain_nm_s_per_rad"]), 0.0)
		and is_equal_approx(
			float(candidate["post_recontact_pitch_velocity_gain_nm_s_per_rad"]), 0.0
		)
		and (
			int(candidate["post_recontact_attitude_velocity_feedback_override_delay_ticks"]) == 1000
		)
		and (
			int(candidate["post_recontact_attitude_velocity_feedback_override_duration_ticks"])
			== 300
		)
		and bool(candidate["post_recontact_yaw_rate_damping_enabled"])
		and is_equal_approx(float(candidate["post_recontact_yaw_rate_gain_nm_s_per_rad"]), 1.0)
		and is_equal_approx(float(candidate["maximum_post_recontact_yaw_damping_moment_nm"]), 0.2)
		and is_equal_approx(
			float(candidate["maximum_post_recontact_yaw_damping_endpoint_force_n"]), 0.5
		)
		and (candidate["exact_seed_set"] as Array) == EXACT_SEEDS
		and bool(candidate["physical_development_execution_authorized"])
		and bool(candidate["physical_commissioning_execution_authorized"])
		and bool(candidate["locomotor_step_claim_allowed"])
		and not bool(candidate["formal_milestone_acceptance_authorized"])
		and not bool(candidate["encyclopedia_admission_authorized"])
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
