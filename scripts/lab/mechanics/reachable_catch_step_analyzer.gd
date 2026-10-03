class_name LabReachableCatchStepAnalyzer
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## Digest-bound BR10 paired reachable-catch experiment contract.
##
## The positive claim is deliberately limited to one material sagittal
## scaffold and one preregistered disturbance. The active world must create a
## previously absent semantic distal contact through finite joint torques,
## advance through observed TOUCH/LOAD/BEARING phases, expand the measured
## support interval, and regain a bounded stance dwell. A matched no-catch
## world must retain the same disturbance and scaffold.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const PlannerScript := preload("res://scripts/lab/mechanics/reachable_catch_step_planner.gd")

const SCHEMA_VERSION := "reachable_catch_step_experiment_configuration_v1"
const CLAIM_BOUNDARY := (
	"BR10 paired reachable new-contact catch step on the exact inherited BR7 "
	+ "sagittal scaffold: one no-catch control and one active-catch world; one "
	+ "material unpowered out-of-plane guide with in-plane X/Y translation and "
	+ "pitch released; four passive hinges driven only through paired finite "
	+ "joint actuators; one ordinary left distal contact bearing at the declared "
	+ "disturbance while the observed right distal sphere is unloaded and clear; "
	+ "one preparation-only root freeze released exactly with one declared pitch "
	+ "impulse; one deterministic support-expanding plan selected on the first "
	+ "post-disturbance observation; finite swing commands to a world target; "
	+ "observed SEARCH to TOUCH to LOAD to BEARING authority; bounded normal-load "
	+ "rate and friction-reserved sagittal tangent commands mapped through an "
	+ "explicit J-transpose contract; full command-ledger, executor, receipt, and "
	+ "contact-capacity reconciliation; measured support-interval expansion; and "
	+ "a post-catch world-target/posture handoff that retains ordinary contacts "
	+ "through the complete horizon. Commanded contact-force shares are not "
	+ "measured per-foot loads. The positive result establishes only this "
	+ "scaffold-constrained planar reachable catch step and return to the declared "
	+ "stance dwell relative to its matched no-catch crash control. It establishes "
	+ "no per-foot measured load allocation, free-3D standing or bracing, general "
	+ "articulated load-bearing limb, generalized fall arrest, getting up, gait, "
	+ "walking, creature repair, or automatic creature guidance."
)
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"physics_hz",
	"disturbance_tick",
	"catch_start_tick",
	"catch_ramp_ticks",
	"trial_end_tick",
	"baseline_height_m",
	"root_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"initial_q1_rad",
	"initial_q2_rad",
	"target_q1_rad",
	"target_q2_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"pitch_position_gain_nm_rad",
	"pitch_velocity_gain_nm_s_rad",
	"handoff_pitch_position_gain_nm_rad",
	"handoff_pitch_velocity_gain_nm_s_rad",
	"handoff_joint_position_gain_nm_rad",
	"handoff_joint_velocity_gain_nm_s_rad",
	"horizontal_position_gain_n_m",
	"horizontal_velocity_gain_n_s_m",
	"horizontal_friction_reserve_fraction",
	"maximum_contact_normal_n",
	"minimum_bearing_command_n",
	"maximum_normal_load_rate_n_s",
	"friction_coefficient",
	"pitch_impulse_n_m_s",
	"reaction_deadline_s",
	"declared_path_clearance_m",
	"catch_path_lift_m",
	"catch_target_penetration_m",
	"planner_joint_speed_bounds_rad_s",
	"contact_confirm_ticks",
	"load_confirm_ticks",
	"bearing_confirm_ticks",
	"load_enter_n",
	"bearing_enter_n",
	"maximum_separating_speed_m_s",
	"stance_pitch_tolerance_rad",
	"stance_pitch_rate_tolerance_rad_s",
	"stance_height_tolerance_m",
	"stance_dwell_ticks",
	"actuator_spec_sha256",
	"planner_configuration",
	"maximum_touchdown_approach_speed_m_s",
	"maximum_predicted_local_normal_load_n",
	"minimum_measured_support_improvement_m",
	"maximum_support_prediction_error_m",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
	"maximum_horizontal_position_error_m",
	"maximum_horizontal_speed_m_s",
	"maximum_commanded_tangent_n",
	"maximum_pitch_excursion_rad",
	"maximum_height_error_m",
	"minimum_post_stance_samples",
	"maximum_post_stance_pitch_error_rad",
	"maximum_post_stance_pitch_rate_rad_s",
	"maximum_post_stance_height_error_m",
	"maximum_final_pitch_error_rad",
	"maximum_final_pitch_rate_rad_s",
	"maximum_final_height_error_m",
	"minimum_control_touchdown_approach_speed_m_s",
	"minimum_control_predicted_local_normal_load_n",
	"minimum_control_pitch_excursion_rad",
	"out_of_plane_planar_guide_enabled",
	"preparation_root_freeze_enabled",
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"pose_teleport_enabled",
	"per_foot_load_sensor_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_stance_claim_enabled",
	"articulated_limb_generality_claim_enabled",
	"fall_arrest_claim_enabled",
	"getting_up_claim_enabled",
	"gait_claim_enabled",
	"walking_claim_enabled",
	"scaffold_constrained_planar_catch_claim_enabled",
]
const INTEGER_FIELDS: Array[String] = [
	"physics_hz",
	"disturbance_tick",
	"catch_start_tick",
	"catch_ramp_ticks",
	"trial_end_tick",
	"contact_confirm_ticks",
	"load_confirm_ticks",
	"bearing_confirm_ticks",
	"stance_dwell_ticks",
	"minimum_post_stance_samples",
]
const FINITE_FIELDS: Array[String] = [
	"baseline_height_m",
	"root_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"initial_q1_rad",
	"initial_q2_rad",
	"target_q1_rad",
	"target_q2_rad",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"pitch_position_gain_nm_rad",
	"pitch_velocity_gain_nm_s_rad",
	"handoff_pitch_position_gain_nm_rad",
	"handoff_pitch_velocity_gain_nm_s_rad",
	"handoff_joint_position_gain_nm_rad",
	"handoff_joint_velocity_gain_nm_s_rad",
	"horizontal_position_gain_n_m",
	"horizontal_velocity_gain_n_s_m",
	"horizontal_friction_reserve_fraction",
	"maximum_contact_normal_n",
	"minimum_bearing_command_n",
	"maximum_normal_load_rate_n_s",
	"friction_coefficient",
	"pitch_impulse_n_m_s",
	"reaction_deadline_s",
	"declared_path_clearance_m",
	"catch_path_lift_m",
	"catch_target_penetration_m",
	"load_enter_n",
	"bearing_enter_n",
	"maximum_separating_speed_m_s",
	"stance_pitch_tolerance_rad",
	"stance_pitch_rate_tolerance_rad_s",
	"stance_height_tolerance_m",
	"maximum_touchdown_approach_speed_m_s",
	"maximum_predicted_local_normal_load_n",
	"minimum_measured_support_improvement_m",
	"maximum_support_prediction_error_m",
	"maximum_pairing_residual_nm",
	"maximum_applied_torque_nm",
	"maximum_horizontal_position_error_m",
	"maximum_horizontal_speed_m_s",
	"maximum_commanded_tangent_n",
	"maximum_pitch_excursion_rad",
	"maximum_height_error_m",
	"maximum_post_stance_pitch_error_rad",
	"maximum_post_stance_pitch_rate_rad_s",
	"maximum_post_stance_height_error_m",
	"maximum_final_pitch_error_rad",
	"maximum_final_pitch_rate_rad_s",
	"maximum_final_height_error_m",
	"minimum_control_touchdown_approach_speed_m_s",
	"minimum_control_predicted_local_normal_load_n",
	"minimum_control_pitch_excursion_rad",
]
const POSITIVE_FIELDS: Array[String] = [
	"baseline_height_m",
	"root_height_m",
	"root_mass_kg",
	"link_mass_kg",
	"link_length_m",
	"foot_radius_m",
	"joint_position_gain_nm_rad",
	"joint_velocity_gain_nm_s_rad",
	"height_position_gain_n_m",
	"height_velocity_gain_n_s_m",
	"pitch_position_gain_nm_rad",
	"pitch_velocity_gain_nm_s_rad",
	"handoff_pitch_position_gain_nm_rad",
	"handoff_pitch_velocity_gain_nm_s_rad",
	"handoff_joint_position_gain_nm_rad",
	"handoff_joint_velocity_gain_nm_s_rad",
	"horizontal_position_gain_n_m",
	"horizontal_velocity_gain_n_s_m",
	"maximum_contact_normal_n",
	"minimum_bearing_command_n",
	"maximum_normal_load_rate_n_s",
	"friction_coefficient",
	"pitch_impulse_n_m_s",
	"reaction_deadline_s",
	"declared_path_clearance_m",
	"catch_path_lift_m",
	"catch_target_penetration_m",
	"load_enter_n",
	"bearing_enter_n",
	"maximum_separating_speed_m_s",
	"stance_pitch_tolerance_rad",
	"stance_pitch_rate_tolerance_rad_s",
	"stance_height_tolerance_m",
	"maximum_touchdown_approach_speed_m_s",
	"maximum_predicted_local_normal_load_n",
	"minimum_measured_support_improvement_m",
	"maximum_support_prediction_error_m",
	"maximum_applied_torque_nm",
	"maximum_horizontal_position_error_m",
	"maximum_horizontal_speed_m_s",
	"maximum_commanded_tangent_n",
	"maximum_pitch_excursion_rad",
	"maximum_height_error_m",
	"maximum_post_stance_pitch_error_rad",
	"maximum_post_stance_pitch_rate_rad_s",
	"maximum_post_stance_height_error_m",
	"maximum_final_pitch_error_rad",
	"maximum_final_pitch_rate_rad_s",
	"maximum_final_height_error_m",
	"minimum_control_touchdown_approach_speed_m_s",
	"minimum_control_predicted_local_normal_load_n",
	"minimum_control_pitch_excursion_rad",
]
const FORBIDDEN_TRUE_FIELDS: Array[String] = [
	"built_in_motors_enabled",
	"joint_limits_enabled",
	"passive_tissues_enabled",
	"controller_root_force_enabled",
	"foot_pin_enabled",
	"pose_teleport_enabled",
	"per_foot_load_sensor_enabled",
	"automatic_creature_guidance_enabled",
	"free_3d_stance_claim_enabled",
	"articulated_limb_generality_claim_enabled",
	"fall_arrest_claim_enabled",
	"getting_up_claim_enabled",
	"gait_claim_enabled",
	"walking_claim_enabled",
]
const SUMMARY_NUMERIC_FIELDS: Array[String] = [
	"executed_ticks",
	"disturbance_operation_count",
	"root_release_operation_count",
	"catch_plan_count",
	"catch_command_count",
	"first_catch_command_tick",
	"predicted_contact_tick",
	"predicted_reach_time_s",
	"planner_support_improvement_m",
	"first_touch_tick",
	"first_load_tick",
	"first_bearing_tick",
	"stance_return_tick",
	"stance_world_hold_command_count",
	"stabilize_handoff_command_count",
	"touchdown_approach_speed_m_s",
	"peak_predicted_local_normal_load_n",
	"initial_right_contact_count",
	"non_distal_contact_count",
	"support_interval_before_m",
	"support_interval_after_m",
	"measured_support_improvement_m",
	"maximum_horizontal_position_error_m",
	"maximum_horizontal_speed_m_s",
	"maximum_commanded_tangent_n",
	"maximum_applied_torque_nm",
	"maximum_pairing_residual_nm",
	"actuator_saturation_count",
	"allocator_clamp_count",
	"maximum_normal_load_rate_n_s",
	"post_impulse_pitch_rate_rad_s",
	"pitch_at_first_bearing_rad",
	"maximum_pitch_excursion_rad",
	"maximum_height_error_m",
	"post_stance_sample_count",
	"post_stance_bearing_loss_count",
	"maximum_post_stance_pitch_error_rad",
	"maximum_post_stance_pitch_rate_rad_s",
	"maximum_post_stance_height_error_m",
	"final_pitch_rad",
	"final_pitch_rate_rad_s",
	"final_height_error_m",
	"root_rescue_operation_count",
	"foot_pin_operation_count",
	"pose_teleport_operation_count",
	"automatic_creature_guidance_operation_count",
]
const SUMMARY_BOOL_FIELDS: Array[String] = [
	"catch_enabled",
	"fixture_complete",
	"planar_guide_exact",
	"hinges_exact",
	"all_receipts_complete",
	"contact_capacity_complete",
	"left_bearing_at_release",
	"preparation_root_freeze_released",
	"planner_selected",
	"stance_world_hold_active",
	"normal_load_rate_is_bearing_command_only",
	"target_arrival_used_for_phase_transition",
	"local_load_is_generalized_per_foot_allocation",
	"per_contact_commands_are_measurements",
	"free_3d_stance_established",
]


static func build(configuration: Dictionary) -> Dictionary:
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("REACHABLE_CATCH_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("REACHABLE_CATCH_CONFIGURATION_SCHEMA_UNSUPPORTED")
	for field in INTEGER_FIELDS:
		var value: Variant = configuration.get(field)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) != floorf(float(value))
			or int(value) <= 0
		):
			return _failure("REACHABLE_CATCH_POSITIVE_INTEGER_INVALID:%s" % field)
	for field in FINITE_FIELDS:
		var value: Variant = configuration.get(field)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return _failure("REACHABLE_CATCH_FINITE_VALUE_INVALID:%s" % field)
	for field in POSITIVE_FIELDS:
		if float(configuration[field]) <= 0.0:
			return _failure("REACHABLE_CATCH_POSITIVE_VALUE_INVALID:%s" % field)
	if (
		float(configuration["horizontal_friction_reserve_fraction"]) <= 0.0
		or float(configuration["horizontal_friction_reserve_fraction"]) >= 1.0
		or int(configuration["catch_start_tick"]) != int(configuration["disturbance_tick"]) + 1
		or (
			int(configuration["catch_start_tick"]) + int(configuration["catch_ramp_ticks"])
			>= int(configuration["trial_end_tick"])
		)
		or (
			float(configuration["minimum_bearing_command_n"])
			>= float(configuration["maximum_contact_normal_n"])
		)
	):
		return _failure("REACHABLE_CATCH_CONFIGURATION_RANGE_INVALID")
	var speed_bounds: Variant = configuration.get("planner_joint_speed_bounds_rad_s")
	if (
		not speed_bounds is Array
		or (speed_bounds as Array).size() != 2
		or not _positive_numeric_array(speed_bounds)
	):
		return _failure("REACHABLE_CATCH_SPEED_BOUNDS_INVALID")
	if (
		typeof(configuration.get("out_of_plane_planar_guide_enabled")) != TYPE_BOOL
		or not bool(configuration["out_of_plane_planar_guide_enabled"])
		or typeof(configuration.get("preparation_root_freeze_enabled")) != TYPE_BOOL
		or not bool(configuration["preparation_root_freeze_enabled"])
		or (
			typeof(configuration.get("scaffold_constrained_planar_catch_claim_enabled"))
			!= TYPE_BOOL
		)
		or not bool(configuration["scaffold_constrained_planar_catch_claim_enabled"])
	):
		return _failure("REACHABLE_CATCH_REQUIRED_BOUNDARY_DISABLED")
	for field in FORBIDDEN_TRUE_FIELDS:
		if typeof(configuration.get(field)) != TYPE_BOOL or bool(configuration[field]):
			return _failure("REACHABLE_CATCH_FORBIDDEN_ASSIST_OR_CLAIM:%s" % field)
	var actuator_sha := String(configuration.get("actuator_spec_sha256", ""))
	if not _sha256(actuator_sha):
		return _failure("REACHABLE_CATCH_ACTUATOR_DIGEST_INVALID")
	if not configuration.get("planner_configuration") is Dictionary:
		return _failure("REACHABLE_CATCH_PLANNER_CONFIGURATION_MISSING")
	var planner := PlannerScript.compile(configuration["planner_configuration"])
	if not bool(planner.get("ok", false)):
		return _failure(
			"REACHABLE_CATCH_PLANNER_CONFIGURATION_INVALID",
			{"planner_failure_code": planner.get("failure_code", "")}
		)
	var cosine := (
		(float(configuration["baseline_height_m"]) - float(configuration["foot_radius_m"]))
		/ (2.0 * float(configuration["link_length_m"]))
	)
	if cosine <= 0.0 or cosine > 1.0:
		return _failure("REACHABLE_CATCH_INITIAL_SUPPORT_IK_INVALID")
	var payload := configuration.duplicate(true)
	payload["target_foot_local_m"] = _endpoint(
		float(configuration["target_q1_rad"]),
		float(configuration["target_q2_rad"]),
		float(configuration["link_length_m"])
	)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	payload["planner_configuration_sha256"] = String(
		planner["configuration"]["configuration_sha256"]
	)
	payload["expected_first_catch_command_tick"] = int(configuration["catch_start_tick"])
	payload["latest_allowed_predicted_contact_tick"] = (
		int(configuration["disturbance_tick"])
		+ int(ceil(float(configuration["reaction_deadline_s"]) * int(configuration["physics_hz"])))
	)
	payload["claim_boundary"] = CLAIM_BOUNDARY
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(
	contract: Dictionary, active_summary: Dictionary, control_summary: Dictionary
) -> Dictionary:
	var verified := _verify_contract(contract)
	if not bool(verified.get("ok", false)):
		return verified
	for summary_value in [active_summary, control_summary]:
		var summary: Dictionary = summary_value
		if String(summary.get("schema_version", "")) != "reachable_catch_step_summary_v1":
			return _failure("REACHABLE_CATCH_SUMMARY_SCHEMA_INVALID")
		if (
			String(summary.get("configuration_sha256", ""))
			!= String(contract["configuration_sha256"])
		):
			return _failure("REACHABLE_CATCH_SUMMARY_CONFIGURATION_DIGEST_MISMATCH")
		if (
			String(summary.get("actuator_spec_sha256", ""))
			!= String(contract["actuator_spec_sha256"])
		):
			return _failure("REACHABLE_CATCH_SUMMARY_ACTUATOR_DIGEST_MISMATCH")
		for field in SUMMARY_NUMERIC_FIELDS:
			if (
				not summary.has(field)
				or typeof(summary[field]) not in [TYPE_INT, TYPE_FLOAT]
				or not is_finite(float(summary[field]))
			):
				return _failure("REACHABLE_CATCH_SUMMARY_NUMERIC_MISSING:%s" % field)
		for field in SUMMARY_BOOL_FIELDS:
			if not summary.has(field) or typeof(summary[field]) != TYPE_BOOL:
				return _failure("REACHABLE_CATCH_SUMMARY_BOOL_MISSING:%s" % field)
		for field in [
			"fixture_failure_code",
			"planner_failure_code",
			"selected_candidate_id",
			"final_phase",
		]:
			if not summary.has(field) or typeof(summary[field]) != TYPE_STRING:
				return _failure("REACHABLE_CATCH_SUMMARY_STRING_MISSING:%s" % field)
		if not summary.get("phase_trace") is Array:
			return _failure("REACHABLE_CATCH_PHASE_TRACE_INVALID")

	var failures: Array[String] = []
	if (
		not bool(active_summary["catch_enabled"])
		or bool(control_summary["catch_enabled"])
		or not _fixture_integrity(active_summary, int(contract["trial_end_tick"]))
		or not _fixture_integrity(control_summary, int(contract["trial_end_tick"]))
	):
		failures.append("REACHABLE_CATCH_PAIRED_FIXTURE_INTEGRITY")
	if (
		int(active_summary["disturbance_operation_count"]) != 1
		or int(control_summary["disturbance_operation_count"]) != 1
		or int(active_summary["root_release_operation_count"]) != 1
		or int(control_summary["root_release_operation_count"]) != 1
		or not bool(active_summary["left_bearing_at_release"])
		or not bool(control_summary["left_bearing_at_release"])
		or not bool(active_summary["preparation_root_freeze_released"])
		or not bool(control_summary["preparation_root_freeze_released"])
	):
		failures.append("REACHABLE_CATCH_DISTURBANCE_OR_RELEASE_INTEGRITY")
	if (
		not bool(active_summary["planner_selected"])
		or int(active_summary["catch_plan_count"]) != 1
		or (
			int(active_summary["first_catch_command_tick"])
			!= int(contract["expected_first_catch_command_tick"])
		)
		or String(active_summary["selected_candidate_id"]) != "forward_catch"
		or not String(active_summary["planner_failure_code"]).is_empty()
		or int(control_summary["catch_plan_count"]) != 0
		or int(control_summary["catch_command_count"]) != 0
	):
		failures.append("REACHABLE_CATCH_PLANNER_CAUSALITY")
	if (
		int(active_summary["initial_right_contact_count"]) != 0
		or int(active_summary["first_touch_tick"]) <= int(contract["catch_start_tick"])
		or int(active_summary["first_load_tick"]) <= int(active_summary["first_touch_tick"])
		or int(active_summary["first_bearing_tick"]) <= int(active_summary["first_load_tick"])
		or (active_summary["phase_trace"] as Array) != ["TOUCH", "LOAD", "BEARING"]
		or String(active_summary["final_phase"]) != "BEARING"
	):
		failures.append("REACHABLE_CATCH_ORDERED_NEW_CONTACT_EVIDENCE")
	if (
		(
			int(active_summary["predicted_contact_tick"])
			> int(contract["latest_allowed_predicted_contact_tick"])
		)
		or int(active_summary["first_touch_tick"]) > int(active_summary["predicted_contact_tick"])
		or (
			float(active_summary["measured_support_improvement_m"])
			< float(contract["minimum_measured_support_improvement_m"])
		)
		or (
			float(active_summary["support_interval_after_m"])
			<= float(active_summary["support_interval_before_m"])
		)
		or (
			absf(
				(
					float(active_summary["planner_support_improvement_m"])
					- float(active_summary["measured_support_improvement_m"])
				)
			)
			> float(contract["maximum_support_prediction_error_m"])
		)
	):
		failures.append("REACHABLE_CATCH_CLOCK_OR_SUPPORT_EXPANSION")
	if (
		(
			float(active_summary["touchdown_approach_speed_m_s"])
			> float(contract["maximum_touchdown_approach_speed_m_s"])
		)
		or (
			float(active_summary["peak_predicted_local_normal_load_n"])
			> float(contract["maximum_predicted_local_normal_load_n"])
		)
		or int(active_summary["non_distal_contact_count"]) != 0
	):
		failures.append("REACHABLE_CATCH_TOUCHDOWN_ENVELOPE")
	if (
		int(active_summary["stance_return_tick"]) <= int(active_summary["first_bearing_tick"])
		or (
			int(active_summary["post_stance_sample_count"])
			!= int(contract["trial_end_tick"]) - int(active_summary["stance_return_tick"])
		)
		or (
			int(active_summary["post_stance_sample_count"])
			< int(contract["minimum_post_stance_samples"])
		)
		or int(active_summary["post_stance_bearing_loss_count"]) != 0
		or not bool(active_summary["stance_world_hold_active"])
		or (
			int(active_summary["stance_world_hold_command_count"])
			!= int(active_summary["post_stance_sample_count"])
		)
	):
		failures.append("REACHABLE_CATCH_STANCE_HANDOFF_INTEGRITY")
	if (
		(
			float(active_summary["maximum_post_stance_pitch_error_rad"])
			> float(contract["maximum_post_stance_pitch_error_rad"])
		)
		or (
			float(active_summary["maximum_post_stance_pitch_rate_rad_s"])
			> float(contract["maximum_post_stance_pitch_rate_rad_s"])
		)
		or (
			float(active_summary["maximum_post_stance_height_error_m"])
			> float(contract["maximum_post_stance_height_error_m"])
		)
		or (
			absf(float(active_summary["final_pitch_rad"]))
			> float(contract["maximum_final_pitch_error_rad"])
		)
		or (
			absf(float(active_summary["final_pitch_rate_rad_s"]))
			> float(contract["maximum_final_pitch_rate_rad_s"])
		)
		or (
			float(active_summary["final_height_error_m"])
			> float(contract["maximum_final_height_error_m"])
		)
	):
		failures.append("REACHABLE_CATCH_POST_STANCE_STABILITY")
	if (
		(
			float(active_summary["maximum_horizontal_position_error_m"])
			> float(contract["maximum_horizontal_position_error_m"])
		)
		or (
			float(active_summary["maximum_horizontal_speed_m_s"])
			> float(contract["maximum_horizontal_speed_m_s"])
		)
		or (
			float(active_summary["maximum_commanded_tangent_n"])
			> float(contract["maximum_commanded_tangent_n"])
		)
		or (
			float(active_summary["maximum_pitch_excursion_rad"])
			> float(contract["maximum_pitch_excursion_rad"])
		)
		or (
			float(active_summary["maximum_height_error_m"])
			> float(contract["maximum_height_error_m"])
		)
	):
		failures.append("REACHABLE_CATCH_ACTIVE_MOTION_ENVELOPE")
	if (
		(
			float(active_summary["maximum_pairing_residual_nm"])
			> float(contract["maximum_pairing_residual_nm"])
		)
		or (
			float(active_summary["maximum_applied_torque_nm"])
			> float(contract["maximum_applied_torque_nm"])
		)
		or int(active_summary["actuator_saturation_count"]) != 0
		or not bool(active_summary["normal_load_rate_is_bearing_command_only"])
		or (
			float(active_summary["maximum_normal_load_rate_n_s"])
			> float(contract["maximum_normal_load_rate_n_s"]) + 1.0e-7
		)
	):
		failures.append("REACHABLE_CATCH_FINITE_ACTUATION_ENVELOPE")
	if (
		int(control_summary["first_touch_tick"]) <= int(active_summary["predicted_contact_tick"])
		or (
			float(control_summary["touchdown_approach_speed_m_s"])
			< float(contract["minimum_control_touchdown_approach_speed_m_s"])
		)
		or (
			float(control_summary["peak_predicted_local_normal_load_n"])
			< float(contract["minimum_control_predicted_local_normal_load_n"])
		)
		or (
			float(control_summary["maximum_pitch_excursion_rad"])
			< float(contract["minimum_control_pitch_excursion_rad"])
		)
		or int(control_summary["actuator_saturation_count"]) <= 0
		or int(control_summary["stance_return_tick"]) >= 0
	):
		failures.append("REACHABLE_CATCH_MATCHED_CONTROL_SEVERITY")
	if not _containment(active_summary):
		failures.append("REACHABLE_CATCH_ASSISTANCE_OR_MEASUREMENT_CONTAINMENT")

	return {
		"ok": true,
		"accepted": failures.is_empty(),
		"failures": failures,
		"claim_boundary": CLAIM_BOUNDARY,
		"milestone_cells": ["BR10.0", "BR10.1", "BR10.2", "BR10.3"],
		"integrity_cell": "BR10.4",
		"does_not_establish":
		[
			"per_foot_measured_load_allocation",
			"free_3d_standing",
			"free_3d_bracing",
			"general_articulated_load_bearing_limb",
			"generalized_fall_arrest",
			"getting_up",
			"gait",
			"walking",
			"creature_repair",
			"automatic_creature_guidance",
		],
	}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var original: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("REACHABLE_CATCH_CONTRACT_FIELD_MISSING:%s" % field)
		original[field] = contract[field]
	if String(contract.get("configuration_sha256", "")) != CanonicalJsonScript.sha256(original):
		return _failure("REACHABLE_CATCH_CONTRACT_DIGEST_MISMATCH")
	if String(contract.get("claim_boundary", "")) != CLAIM_BOUNDARY:
		return _failure("REACHABLE_CATCH_CLAIM_BOUNDARY_MISMATCH")
	var expected_endpoint := _endpoint(
		float(contract["target_q1_rad"]),
		float(contract["target_q2_rad"]),
		float(contract["link_length_m"])
	)
	if contract.get("target_foot_local_m") != expected_endpoint:
		return _failure("REACHABLE_CATCH_DERIVED_TARGET_MISMATCH")
	return {"ok": true}


static func _fixture_integrity(summary: Dictionary, expected_ticks: int) -> bool:
	return (
		bool(summary["fixture_complete"])
		and String(summary["fixture_failure_code"]).is_empty()
		and int(summary["executed_ticks"]) == expected_ticks
		and bool(summary["planar_guide_exact"])
		and bool(summary["hinges_exact"])
		and bool(summary["all_receipts_complete"])
		and bool(summary["contact_capacity_complete"])
	)


static func _containment(summary: Dictionary) -> bool:
	return (
		not bool(summary["target_arrival_used_for_phase_transition"])
		and not bool(summary["local_load_is_generalized_per_foot_allocation"])
		and not bool(summary["per_contact_commands_are_measurements"])
		and not bool(summary["free_3d_stance_established"])
		and int(summary["root_rescue_operation_count"]) == 0
		and int(summary["foot_pin_operation_count"]) == 0
		and int(summary["pose_teleport_operation_count"]) == 0
		and int(summary["automatic_creature_guidance_operation_count"]) == 0
	)


static func _endpoint(q1: float, q2: float, length: float) -> Array:
	var q12 := q1 + q2
	return [
		length * sin(q1) + length * sin(q12),
		-length * cos(q1) - length * cos(q12),
	]


static func _positive_numeric_array(values: Array) -> bool:
	for value in values:
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) <= 0.0
		):
			return false
	return true


static func _sha256(value: String) -> bool:
	return (
		value.begins_with("sha256:")
		and value.length() == 71
		and value.trim_prefix("sha256:").is_valid_hex_number(false)
	)


static func _failure(code: String, details: Dictionary = {}) -> Dictionary:
	var failure := {"ok": false, "failure_code": code}
	failure.merge(details)
	return failure
