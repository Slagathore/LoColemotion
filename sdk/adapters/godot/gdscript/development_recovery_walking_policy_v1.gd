extends RefCounted
# gdlint: disable=max-line-length

## Explicit caller-selected development identity. Never infer the expected
## policy from an observed receipt; crossed or unknown selections fail closed.
const FiniteRoute := preload("res://sdk/adapters/godot/gdscript/recovery_finite_cycle_route_v1.gd")
const R10AP := FiniteRoute.StanceEntry.R10AP
const R10AM := FiniteRoute.StanceEntry.R10AM
const R10AJ := FiniteRoute.StanceEntry.R10AJ
const R10AI := FiniteRoute.StanceEntry.R10AI
const R10AG := FiniteRoute.StanceEntry.R10AG
const R10AB := FiniteRoute.StanceEntry.R10AB
const R10AA := FiniteRoute.StanceEntry.R10AA
const R10Z := FiniteRoute.StanceEntry.R10Z
const R10Y := FiniteRoute.StanceEntry.R10Y
const R10V := FiniteRoute.StanceEntry.R10V
const R10U := FiniteRoute.StanceEntry.R10U
const R10T := FiniteRoute.StanceEntry.R10T
const R10S := FiniteRoute.StanceEntry.R10S
const R10R := FiniteRoute.StanceEntry.R10R
const R10Q := FiniteRoute.StanceEntry.R10Q
const R10O := FiniteRoute.StanceEntry.R10O
const R10N := FiniteRoute.StanceEntry.R10N
const R10M := FiniteRoute.StanceEntry.R10M
const R10L := FiniteRoute.StanceEntry.R10L
const R10K := FiniteRoute.StanceEntry.R10K
const JOINT_ENTRY_PATH := "res://sdk/recovery/r10i_joint_pose_entry_policy_contract_v1.json"
static var joint_entry_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JOINT_ENTRY_PATH))
const PATH := "res://sdk/development/recovery_swing_end_walking_policy_contract_v1.json"
const POLICY_ID := "sporespore_balanced_wave_recovery_swing_end_recontact_v1"
const SUPPORT_POLICY_ID := "sporespore_balanced_wave_recovery_bounded_support_v1"
const SUPPORT_PATH := "res://sdk/development/recovery_bounded_support_walking_policy_contract_v1.json"
const FLOOR_POLICY_ID := "sporespore_balanced_wave_recovery_floor_support_v1"
const FLOOR_PATH := "res://sdk/development/recovery_floor_support_walking_policy_contract_v1.json"
const FEASIBLE_POLICY_ID := "sporespore_balanced_wave_recovery_feasible_support_v1"
const FEASIBLE_PATH := "res://sdk/development/recovery_feasible_support_walking_policy_contract_v1.json"
const SMOOTH_POLICY_ID := "sporespore_balanced_wave_recovery_smooth_swing_v1"
const SMOOTH_PATH := "res://sdk/development/recovery_smooth_swing_walking_policy_contract_v1.json"
const REFERENCE_POLICY_ID := "sporespore_balanced_wave_recovery_reference_velocity_v1"
const REFERENCE_PATH := "res://sdk/development/recovery_reference_velocity_walking_policy_contract_v1.json"
const WAVE_POLICY_ID := "sporespore_balanced_wave_recovery_wave_velocity_v1"
const WAVE_PATH := "res://sdk/development/recovery_wave_velocity_walking_policy_contract_v1.json"
const AIRBORNE_POLICY_ID := "sporespore_balanced_wave_recovery_airborne_reference_v1"
const AIRBORNE_PATH := "res://sdk/development/recovery_airborne_reference_walking_policy_contract_v1.json"
const ABSENT_POLICY_ID := "sporespore_balanced_wave_recovery_absent_contact_reference_v1"
const UPRIGHT_POLICY_ID := "sporespore_balanced_wave_recovery_upright_stance_v1"
const ABSENT_PATH := "res://sdk/development/recovery_absent_contact_reference_walking_policy_contract_v1.json"
const UPRIGHT_PATH := "res://sdk/development/recovery_upright_stance_walking_policy_contract_v2.json"
const STANCE_LATCH_POLICY_ID := "sporespore_balanced_wave_recovery_stance_latched_upright_v1"
const STANCE_LATCH_PATH := "res://sdk/development/recovery_stance_latch_walking_policy_contract_v1.json"
const PROGRESSION_POLICY_ID := "sporespore_balanced_wave_recovery_support_progression_v1"
const PROGRESSION_PATH := "res://sdk/development/recovery_support_progression_walking_policy_contract_v1.json"
const EXTENDED_PREPARATION_POLICY_ID := "sporespore_balanced_wave_recovery_extended_preparation_v1"
const EXTENDED_PREPARATION_PATH := "res://sdk/development/recovery_extended_preparation_walking_policy_contract_v1.json"
static var extended_preparation_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXTENDED_PREPARATION_PATH))
const INITIALIZED_BRAKE_POLICY_ID := "sporespore_balanced_wave_recovery_initialized_zero_brake_v1"
const INITIALIZED_BRAKE_PATH := "res://sdk/development/recovery_initialized_zero_brake_walking_policy_contract_v1.json"
static var initialized_brake_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INITIALIZED_BRAKE_PATH))
const ZERO_BRAKE_POLICY_ID := "sporespore_balanced_wave_recovery_zero_velocity_brake_v1"
const ZERO_BRAKE_PATH := "res://sdk/development/recovery_zero_velocity_brake_walking_policy_contract_v1.json"
static var zero_brake_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ZERO_BRAKE_PATH))
const BOUNDED_STOP_POLICY_ID := "sporespore_balanced_wave_recovery_bounded_stop_velocity_v1"
const BOUNDED_STOP_PATH := "res://sdk/development/recovery_bounded_stop_velocity_walking_policy_contract_v1.json"
static var bounded_stop_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOUNDED_STOP_PATH))
const EXTENDED_TRANSFER_POLICY_ID := "sporespore_balanced_wave_recovery_extended_support_transfer_v1"
const EXTENDED_TRANSFER_PATH := "res://sdk/development/recovery_extended_support_transfer_walking_policy_contract_v1.json"
static var extended_transfer_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXTENDED_TRANSFER_PATH))
const JOINT_HEIGHT_POLICY_ID := "sporespore_balanced_wave_recovery_joint_feasible_height_v1"
const JOINT_HEIGHT_PATH := "res://sdk/development/recovery_joint_feasible_height_walking_policy_contract_v1.json"
static var joint_height_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JOINT_HEIGHT_PATH))
const STARTUP_VELOCITY_POLICY_ID := "sporespore_balanced_wave_recovery_startup_reference_velocity_v1"
const STARTUP_VELOCITY_PATH := "res://sdk/development/recovery_startup_reference_velocity_walking_policy_contract_v1.json"
static var startup_velocity_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STARTUP_VELOCITY_PATH))
const REMAINING_POLICY_ID := "sporespore_balanced_wave_recovery_remaining_support_release_v1"
const REMAINING_PATH := "res://sdk/development/recovery_remaining_support_release_walking_policy_contract_v1.json"
static var remaining_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REMAINING_PATH))
const POSTURE_POLICY_ID := "sporespore_balanced_wave_recovery_support_hold_posture_v1"
const POSTURE_PATH := "res://sdk/development/recovery_support_hold_posture_walking_policy_contract_v1.json"
const LEGACY_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const LEGACY_POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
static var support_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SUPPORT_PATH))
static var floor_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLOOR_PATH))
static var feasible_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FEASIBLE_PATH))
static var smooth_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SMOOTH_PATH))
static var reference_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE_PATH))
static var wave_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WAVE_PATH))
static var airborne_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AIRBORNE_PATH))
static var absent_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ABSENT_PATH))
static var upright_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UPRIGHT_PATH))
static var stance_latch_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STANCE_LATCH_PATH))
static var support_progression_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROGRESSION_PATH))
static var support_hold_posture_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POSTURE_PATH))
static var entry_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_swing_end_walking_entry_contract_v1.json"))

static func schedule_valid_v1(schedule: Dictionary) -> bool:
	if FiniteRoute.selected_v1(schedule.get("walking_policy_id", "")) or schedule.get("walking_entry_profile_id") in [FiniteRoute.ENTRY, FiniteRoute.StanceEntry.ENTRY, FiniteRoute.StanceEntry.FLEXED_ENTRY]:
		return FiniteRoute.schedule_valid_v1(schedule)
	var id: Variant = schedule.get("walking_policy_id", "")
	if not (id is String):
		return false
	if schedule.get("walking_entry_profile_id") == airborne_contract["entry_profile_id"] and id != AIRBORNE_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == absent_contract["entry_profile_id"] and id != ABSENT_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == upright_contract["entry_profile_id"] and id != UPRIGHT_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == extended_preparation_contract["entry_profile_id"] and id != EXTENDED_PREPARATION_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == initialized_brake_contract["entry_profile_id"] and id != INITIALIZED_BRAKE_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == zero_brake_contract["entry_profile_id"] and id != ZERO_BRAKE_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == bounded_stop_contract["entry_profile_id"] and id != BOUNDED_STOP_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == extended_transfer_contract["entry_profile_id"] and id != EXTENDED_TRANSFER_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == joint_height_contract["entry_profile_id"] and id != JOINT_HEIGHT_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == startup_velocity_contract["entry_profile_id"] and id != STARTUP_VELOCITY_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == remaining_contract["entry_profile_id"] and id != REMAINING_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == support_hold_posture_contract["entry_profile_id"] and id != POSTURE_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == support_progression_contract["entry_profile_id"] and id != PROGRESSION_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == stance_latch_contract["entry_profile_id"] and id != STANCE_LATCH_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == wave_contract["entry_profile_id"] and id != WAVE_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == reference_contract["entry_profile_id"] and id != REFERENCE_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == smooth_contract["entry_profile_id"] and id != SMOOTH_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == feasible_contract["entry_profile_id"] and id != FEASIBLE_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == floor_contract["entry_profile_id"] and id != FLOOR_POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == entry_contract["profile_id"] and id != POLICY_ID:
		return false
	if schedule.get("walking_entry_profile_id") == support_contract["entry_profile_id"] and id != SUPPORT_POLICY_ID:
		return false
	if id.is_empty():
		return true
	if floor_selected_v1(id):
		var fixed := contract_for_v1(id)
		return (not binding_v1(id, "walking_resume").is_empty()
			and schedule.get("walking_entry_profile_id") == fixed["entry_profile_id"]
			and schedule.get("walking_start_profile_id") == fixed["start_profile_id"]
			and schedule.get("runtime_sha256") == fixed["runtime_sha256"]
			and schedule.get("walking_policy_contract_sha256") == "sha256:" + FileAccess.get_sha256(EXTENDED_PREPARATION_PATH if id == EXTENDED_PREPARATION_POLICY_ID else INITIALIZED_BRAKE_PATH if id == INITIALIZED_BRAKE_POLICY_ID else ZERO_BRAKE_PATH if id == ZERO_BRAKE_POLICY_ID else BOUNDED_STOP_PATH if id == BOUNDED_STOP_POLICY_ID else EXTENDED_TRANSFER_PATH if id == EXTENDED_TRANSFER_POLICY_ID else JOINT_HEIGHT_PATH if id == JOINT_HEIGHT_POLICY_ID else STARTUP_VELOCITY_PATH if id == STARTUP_VELOCITY_POLICY_ID else REMAINING_PATH if id == REMAINING_POLICY_ID else POSTURE_PATH if id == POSTURE_POLICY_ID else PROGRESSION_PATH if id == PROGRESSION_POLICY_ID else STANCE_LATCH_PATH if id == STANCE_LATCH_POLICY_ID else UPRIGHT_PATH if id == UPRIGHT_POLICY_ID else ABSENT_PATH if id == ABSENT_POLICY_ID else AIRBORNE_PATH if id == AIRBORNE_POLICY_ID else WAVE_PATH if id == WAVE_POLICY_ID else REFERENCE_PATH if id == REFERENCE_POLICY_ID else SMOOTH_PATH if id == SMOOTH_POLICY_ID else FEASIBLE_PATH if id == FEASIBLE_POLICY_ID else FLOOR_PATH)
			and not schedule.has("walking_replay_profile_id"))
	if id == SUPPORT_POLICY_ID:
		return (not binding_v1(id, "walking_resume").is_empty()
			and schedule.get("walking_entry_profile_id") == support_contract["entry_profile_id"]
			and schedule.get("walking_start_profile_id") == support_contract["start_profile_id"]
			and schedule.get("runtime_sha256") == support_contract["runtime_sha256"]
			and schedule.get("walking_policy_contract_sha256") == "sha256:" + FileAccess.get_sha256(SUPPORT_PATH)
			and not schedule.has("walking_replay_profile_id"))
	return (not binding_v1(id, "walking_resume").is_empty()
		and schedule.get("walking_entry_profile_id") == entry_contract["profile_id"]
		and schedule.get("walking_start_profile_id") == entry_contract["required_start_profile_id"]
		and schedule.get("runtime_sha256") == contract["runtime_sha256"]
		and schedule.get("walking_policy_contract_sha256") == "sha256:" + FileAccess.get_sha256(PATH)
		and not schedule.has("walking_replay_profile_id"))

static func selected_id_v1(selection: Dictionary, segment_id: String) -> String:
	var id: String = selection.get("diagnostic_schedule", {}).get("walking_policy_id", "")
	if id == R10AP.ID and segment_id == R10AP.POST_HOLD_SEGMENT: return R10AP.POST_HOLD_ALIAS
	if id == R10AM.ID and segment_id == R10AM.POST_HOLD_SEGMENT: return R10AM.POST_HOLD_ALIAS
	if id == R10AJ.ID and segment_id == R10AJ.POST_HOLD_SEGMENT: return R10AJ.POST_HOLD_ALIAS
	if id == R10AI.ID and segment_id == R10AI.POST_HOLD_SEGMENT: return R10AI.POST_HOLD_ALIAS
	if id == R10AG.ID and segment_id == R10AG.POST_HOLD_SEGMENT: return R10AG.POST_HOLD_ALIAS
	if id == R10AB.ID and segment_id == R10AB.POST_HOLD_SEGMENT: return R10AB.POST_HOLD_ALIAS
	if id == R10AA.ID and segment_id == R10AA.POST_HOLD_SEGMENT: return R10AA.POST_HOLD_ALIAS
	if id == R10Z.ID and segment_id == R10Z.POST_HOLD_SEGMENT: return R10Z.POST_HOLD_ALIAS
	if id == R10Y.ID and segment_id == R10Y.POST_HOLD_SEGMENT: return R10Y.POST_HOLD_ALIAS
	if id == R10V.ID and segment_id == R10V.POST_HOLD_SEGMENT: return R10V.POST_HOLD_ALIAS
	if id == R10U.ID and segment_id == R10U.POST_HOLD_SEGMENT: return R10U.POST_HOLD_ALIAS
	if id == R10T.ID and segment_id == R10T.POST_HOLD_SEGMENT: return R10T.POST_HOLD_ALIAS
	if FiniteRoute.StanceEntry.hold_selected_v1(id) and segment_id == FiniteRoute.StanceEntry.HOLD_SEGMENT: return FiniteRoute.StanceEntry.hold_alias_for_v1(id)
	if FiniteRoute.StanceEntry.selected_v1(id) and segment_id == FiniteRoute.StanceEntry.SEGMENT: return FiniteRoute.StanceEntry.entry_selection_for_v1(id)
	return id if FiniteRoute.segment_selected_v1(id, segment_id) else ""

static func owner_for_phase_v1(phase: String, id: String) -> String:
	if phase == "post_recovery_stationary_settling" and id in [R10AP.ID, R10AP.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10AM.ID, R10AM.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10AJ.ID, R10AJ.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10AI.ID, R10AI.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10AG.ID, R10AG.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10AB.ID, R10AB.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10AA.ID, R10AA.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10Z.ID, R10Z.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10Y.ID, R10Y.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10V.ID, R10V.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10U.ID, R10U.POST_HOLD_ALIAS]: return "stance"
	if phase == "post_recovery_stationary_settling" and id in [R10T.ID, R10T.POST_HOLD_ALIAS]: return "stance"
	if FiniteRoute.StanceEntry.ramped_selected_v1(id) and phase == FiniteRoute.StanceEntry.PHASE: return "stance"
	if binding_v1(id, "walking_resume").is_empty():
		return ""
	return "stance" if not id.is_empty() and (phase == "fresh_selected_policy_walking_resume" or (FiniteRoute.selected_v1(id) and phase == "matched_no_kick_continuation")) else "walking_bw5r_b"

static func binding_v1(id: String, segment_id: String) -> Dictionary:
	if id in [R10AP.ENTRY_ALIAS, R10AP.HOLD_ALIAS, R10AP.POST_HOLD_ALIAS]: return R10AP.alias_binding_v1(id, segment_id)
	if id in [R10AM.ENTRY_ALIAS, R10AM.HOLD_ALIAS, R10AM.POST_HOLD_ALIAS]: return R10AM.alias_binding_v1(id, segment_id)
	if id in [R10AJ.ENTRY_ALIAS, R10AJ.HOLD_ALIAS, R10AJ.POST_HOLD_ALIAS]: return R10AJ.alias_binding_v1(id, segment_id)
	if id in [R10AI.ENTRY_ALIAS, R10AI.HOLD_ALIAS, R10AI.POST_HOLD_ALIAS]: return R10AI.alias_binding_v1(id, segment_id)
	if id in [R10AG.ENTRY_ALIAS, R10AG.HOLD_ALIAS, R10AG.POST_HOLD_ALIAS]: return R10AG.alias_binding_v1(id, segment_id)
	if id in [R10AB.ENTRY_ALIAS, R10AB.HOLD_ALIAS, R10AB.POST_HOLD_ALIAS]: return R10AB.alias_binding_v1(id, segment_id)
	if id in [R10AA.ENTRY_ALIAS, R10AA.HOLD_ALIAS, R10AA.POST_HOLD_ALIAS]: return R10AA.alias_binding_v1(id, segment_id)
	if id in [R10Z.ENTRY_ALIAS, R10Z.HOLD_ALIAS, R10Z.POST_HOLD_ALIAS]: return R10Z.alias_binding_v1(id, segment_id)
	if id in [R10Y.ENTRY_ALIAS, R10Y.HOLD_ALIAS, R10Y.POST_HOLD_ALIAS]: return R10Y.alias_binding_v1(id, segment_id)
	if id in [R10V.ENTRY_ALIAS, R10V.HOLD_ALIAS, R10V.POST_HOLD_ALIAS]: return R10V.alias_binding_v1(id, segment_id)
	if id in [R10U.ENTRY_ALIAS, R10U.HOLD_ALIAS, R10U.POST_HOLD_ALIAS]: return R10U.alias_binding_v1(id, segment_id)
	if id in [R10T.ENTRY_ALIAS, R10T.HOLD_ALIAS, R10T.POST_HOLD_ALIAS]: return R10T.alias_binding_v1(id, segment_id)
	if id in [R10S.ENTRY_ALIAS, R10S.HOLD_ALIAS]: return R10S.alias_binding_v1(id, segment_id)
	if id in [R10R.ENTRY_ALIAS, R10R.HOLD_ALIAS]: return R10R.alias_binding_v1(id, segment_id)
	if id in [R10Q.ENTRY_ALIAS, R10Q.HOLD_ALIAS]: return R10Q.alias_binding_v1(id, segment_id)
	if id in [R10O.ENTRY_ALIAS, R10O.HOLD_ALIAS]: return R10O.alias_binding_v1(id, segment_id)
	if id in [R10N.ENTRY_ALIAS, R10N.HOLD_ALIAS]: return R10N.alias_binding_v1(id, segment_id)
	if id in [R10M.ENTRY_ALIAS, R10M.HOLD_ALIAS]: return R10M.alias_binding_v1(id, segment_id)
	if id in [R10L.ENTRY_ALIAS, R10L.HOLD_ALIAS]: return R10L.alias_binding_v1(id, segment_id)
	if id in [R10K.ENTRY_ALIAS, R10K.HOLD_ALIAS]: return R10K.alias_binding_v1(id, segment_id)
	if id == FiniteRoute.StanceEntry.HOLD_ALIAS:
		# R10J hold: the unchanged V50 native policy at zero amplitude in its own session.
		if segment_id not in [FiniteRoute.StanceEntry.HOLD_SEGMENT, "walking_resume", "matched_continuation"]: return {}
		var hold := FiniteRoute.StanceEntry.hold_contract
		if hold.get("selection_id") != FiniteRoute.StanceEntry.HOLD_ID or hold.get("hold_alias_id") != id or hold.get("policy_id") != STARTUP_VELOCITY_POLICY_ID: return {}
		for key in ["native_component_record", "runtime_binding", "task_contract"]:
			if "sha256:" + FileAccess.get_sha256("res://" + hold[key]) != hold[key + "_sha256"]: return {}
		if hold.get("physical_acceptance_authority") != false or hold.get("release_authority") != false: return {}
		return {"policy_id": STARTUP_VELOCITY_POLICY_ID, "policy_digest": "sha256:" + FileAccess.get_sha256(FiniteRoute.StanceEntry.HOLD_PATH), "development": true}
	if id in [FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, FiniteRoute.StanceEntry.FLEXED_NATIVE_ID]:
		if segment_id not in joint_entry_contract.allowed_segment_ids: return {}
		for key in ["native_component_record", "runtime_binding"]:
			if "sha256:" + FileAccess.get_sha256("res://"+joint_entry_contract[key]) != joint_entry_contract[key+"_sha256"]: return {}
		return {"policy_id": FiniteRoute.StanceEntry.FLEXED_NATIVE_ID, "policy_digest": "sha256:"+FileAccess.get_sha256(JOINT_ENTRY_PATH), "development": true}
	if id == FiniteRoute.StanceEntry.NEUTRAL_ID:
		return {"policy_id": LEGACY_POLICY_ID, "policy_digest": LEGACY_POLICY_DIGEST, "development": false} if segment_id in [FiniteRoute.StanceEntry.SEGMENT, "walking_resume", "matched_continuation"] else {}
	if FiniteRoute.selected_v1(id):
		return FiniteRoute.binding_v1(id, segment_id)
	if id.is_empty():
		return {"policy_id": LEGACY_POLICY_ID, "policy_digest": LEGACY_POLICY_DIGEST, "development": false}
	var fixed := contract_for_v1(id)
	if fixed.is_empty() or segment_id != fixed["allowed_segment_id"]:
		return {}
	for key in ["native_component_record", "runtime_binding"]:
		if "sha256:" + FileAccess.get_sha256("res://" + fixed[key]) != fixed[key + "_sha256"]:
			return {}
	if fixed.get("policy_id") != id or fixed.get("physical_acceptance_authority") != false or fixed.get("release_authority") != false:
		return {}
	return {"policy_id": id, "policy_digest": "sha256:" + FileAccess.get_sha256(EXTENDED_PREPARATION_PATH if id == EXTENDED_PREPARATION_POLICY_ID else INITIALIZED_BRAKE_PATH if id == INITIALIZED_BRAKE_POLICY_ID else ZERO_BRAKE_PATH if id == ZERO_BRAKE_POLICY_ID else BOUNDED_STOP_PATH if id == BOUNDED_STOP_POLICY_ID else EXTENDED_TRANSFER_PATH if id == EXTENDED_TRANSFER_POLICY_ID else JOINT_HEIGHT_PATH if id == JOINT_HEIGHT_POLICY_ID else STARTUP_VELOCITY_PATH if id == STARTUP_VELOCITY_POLICY_ID else REMAINING_PATH if id == REMAINING_POLICY_ID else POSTURE_PATH if id == POSTURE_POLICY_ID else PROGRESSION_PATH if id == PROGRESSION_POLICY_ID else STANCE_LATCH_PATH if id == STANCE_LATCH_POLICY_ID else UPRIGHT_PATH if id == UPRIGHT_POLICY_ID else ABSENT_PATH if id == ABSENT_POLICY_ID else AIRBORNE_PATH if id == AIRBORNE_POLICY_ID else WAVE_PATH if id == WAVE_POLICY_ID else REFERENCE_PATH if id == REFERENCE_POLICY_ID else SMOOTH_PATH if id == SMOOTH_POLICY_ID else FEASIBLE_PATH if id == FEASIBLE_POLICY_ID else FLOOR_PATH if id == FLOOR_POLICY_ID else SUPPORT_PATH if id == SUPPORT_POLICY_ID else PATH), "development": true}

static func floor_selected_v1(id: String) -> bool:
	return FiniteRoute.selected_v1(id) or id in [R10AP.HOLD_ALIAS, R10AM.HOLD_ALIAS, R10AJ.HOLD_ALIAS, R10AP.POST_HOLD_ALIAS, R10AM.POST_HOLD_ALIAS, R10AJ.POST_HOLD_ALIAS, R10AI.HOLD_ALIAS, R10AI.POST_HOLD_ALIAS, R10AG.HOLD_ALIAS, R10AG.POST_HOLD_ALIAS,  FLOOR_POLICY_ID, FEASIBLE_POLICY_ID, SMOOTH_POLICY_ID, REFERENCE_POLICY_ID, WAVE_POLICY_ID, AIRBORNE_POLICY_ID, ABSENT_POLICY_ID, UPRIGHT_POLICY_ID, STANCE_LATCH_POLICY_ID, PROGRESSION_POLICY_ID, POSTURE_POLICY_ID, REMAINING_POLICY_ID, STARTUP_VELOCITY_POLICY_ID, JOINT_HEIGHT_POLICY_ID, EXTENDED_TRANSFER_POLICY_ID, BOUNDED_STOP_POLICY_ID, ZERO_BRAKE_POLICY_ID, INITIALIZED_BRAKE_POLICY_ID, EXTENDED_PREPARATION_POLICY_ID, FiniteRoute.StanceEntry.HOLD_ALIAS, R10K.HOLD_ALIAS, R10L.HOLD_ALIAS, R10M.HOLD_ALIAS, R10N.HOLD_ALIAS, R10O.HOLD_ALIAS, R10Q.HOLD_ALIAS, R10R.HOLD_ALIAS, R10S.HOLD_ALIAS, R10T.HOLD_ALIAS, R10U.HOLD_ALIAS, R10T.POST_HOLD_ALIAS, R10U.POST_HOLD_ALIAS, R10V.HOLD_ALIAS, R10V.POST_HOLD_ALIAS, R10Y.HOLD_ALIAS, R10Z.HOLD_ALIAS, R10Y.POST_HOLD_ALIAS, R10Z.POST_HOLD_ALIAS, R10AA.HOLD_ALIAS, R10AA.POST_HOLD_ALIAS, R10AB.HOLD_ALIAS, R10AB.POST_HOLD_ALIAS]

static func measured_body_selected_v1(id: String) -> bool:
	return FiniteRoute.selected_v1(id) or id in [R10AP.HOLD_ALIAS, R10AM.HOLD_ALIAS, R10AJ.HOLD_ALIAS, R10AP.POST_HOLD_ALIAS, R10AM.POST_HOLD_ALIAS, R10AJ.POST_HOLD_ALIAS, R10AI.HOLD_ALIAS, R10AI.POST_HOLD_ALIAS, R10AG.HOLD_ALIAS, R10AG.POST_HOLD_ALIAS,  REMAINING_POLICY_ID, STARTUP_VELOCITY_POLICY_ID, JOINT_HEIGHT_POLICY_ID, EXTENDED_TRANSFER_POLICY_ID, BOUNDED_STOP_POLICY_ID, ZERO_BRAKE_POLICY_ID, INITIALIZED_BRAKE_POLICY_ID, EXTENDED_PREPARATION_POLICY_ID, FiniteRoute.StanceEntry.HOLD_ALIAS, R10K.HOLD_ALIAS, R10L.HOLD_ALIAS, R10M.HOLD_ALIAS, R10N.HOLD_ALIAS, R10O.HOLD_ALIAS, R10Q.HOLD_ALIAS, R10R.HOLD_ALIAS, R10S.HOLD_ALIAS, R10T.HOLD_ALIAS, R10U.HOLD_ALIAS, R10T.POST_HOLD_ALIAS, R10U.POST_HOLD_ALIAS, R10V.HOLD_ALIAS, R10V.POST_HOLD_ALIAS, R10Y.HOLD_ALIAS, R10Z.HOLD_ALIAS, R10Y.POST_HOLD_ALIAS, R10Z.POST_HOLD_ALIAS, R10AA.HOLD_ALIAS, R10AA.POST_HOLD_ALIAS, R10AB.HOLD_ALIAS, R10AB.POST_HOLD_ALIAS]

static func contract_for_v1(id: String) -> Dictionary:
	if id in [R10AP.ID, R10AP.ENTRY_ALIAS, R10AP.HOLD_ALIAS, R10AP.POST_HOLD_ALIAS]: return R10AP.contract_for_v1(id)
	if id in [R10AM.ID, R10AM.ENTRY_ALIAS, R10AM.HOLD_ALIAS, R10AM.POST_HOLD_ALIAS]: return R10AM.contract_for_v1(id)
	if id in [R10AJ.ID, R10AJ.ENTRY_ALIAS, R10AJ.HOLD_ALIAS, R10AJ.POST_HOLD_ALIAS]: return R10AJ.contract_for_v1(id)
	if id in [R10AI.ID, R10AI.ENTRY_ALIAS, R10AI.HOLD_ALIAS, R10AI.POST_HOLD_ALIAS]: return R10AI.contract_for_v1(id)
	if id in [R10AG.ID, R10AG.ENTRY_ALIAS, R10AG.HOLD_ALIAS, R10AG.POST_HOLD_ALIAS]: return R10AG.contract_for_v1(id)
	if id in [R10AB.ID, R10AB.ENTRY_ALIAS, R10AB.HOLD_ALIAS, R10AB.POST_HOLD_ALIAS]: return R10AB.contract_for_v1(id)
	if id in [R10AA.ID, R10AA.ENTRY_ALIAS, R10AA.HOLD_ALIAS, R10AA.POST_HOLD_ALIAS]: return R10AA.contract_for_v1(id)
	if id in [R10Z.ID, R10Z.ENTRY_ALIAS, R10Z.HOLD_ALIAS, R10Z.POST_HOLD_ALIAS]: return R10Z.contract_for_v1(id)
	if id in [R10Y.ID, R10Y.ENTRY_ALIAS, R10Y.HOLD_ALIAS, R10Y.POST_HOLD_ALIAS]: return R10Y.contract_for_v1(id)
	if id in [R10V.ID, R10V.ENTRY_ALIAS, R10V.HOLD_ALIAS, R10V.POST_HOLD_ALIAS]: return R10V.contract_for_v1(id)
	if id in [R10U.ID, R10U.ENTRY_ALIAS, R10U.HOLD_ALIAS, R10U.POST_HOLD_ALIAS]: return R10U.contract_for_v1(id)
	if id in [R10T.ID, R10T.ENTRY_ALIAS, R10T.HOLD_ALIAS, R10T.POST_HOLD_ALIAS]: return R10T.contract_for_v1(id)
	if id in [R10S.ID, R10S.ENTRY_ALIAS, R10S.HOLD_ALIAS]: return R10S.contract_for_v1(id)
	if id in [R10R.ID, R10R.ENTRY_ALIAS, R10R.HOLD_ALIAS]: return R10R.contract_for_v1(id)
	if id in [R10Q.ID, R10Q.ENTRY_ALIAS, R10Q.HOLD_ALIAS]: return R10Q.contract_for_v1(id)
	if id in [R10O.ID, R10O.ENTRY_ALIAS, R10O.HOLD_ALIAS]: return R10O.contract_for_v1(id)
	if id in [R10N.ID, R10N.ENTRY_ALIAS, R10N.HOLD_ALIAS]: return R10N.contract_for_v1(id)
	if id in [R10M.ID, R10M.ENTRY_ALIAS, R10M.HOLD_ALIAS]: return R10M.contract_for_v1(id)
	if id in [R10L.ID, R10L.ENTRY_ALIAS, R10L.HOLD_ALIAS]: return R10L.contract_for_v1(id)
	if id in [R10K.ID, R10K.ENTRY_ALIAS, R10K.HOLD_ALIAS]: return R10K.contract_for_v1(id)
	if id == EXTENDED_PREPARATION_POLICY_ID: return extended_preparation_contract
	if id == INITIALIZED_BRAKE_POLICY_ID: return initialized_brake_contract
	if id == ZERO_BRAKE_POLICY_ID: return zero_brake_contract
	if id == BOUNDED_STOP_POLICY_ID: return bounded_stop_contract
	if id == EXTENDED_TRANSFER_POLICY_ID: return extended_transfer_contract
	if id == JOINT_HEIGHT_POLICY_ID: return joint_height_contract
	if id == FiniteRoute.StanceEntry.HOLD_ALIAS: return FiniteRoute.StanceEntry.hold_contract
	if id in [FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, FiniteRoute.StanceEntry.FLEXED_NATIVE_ID]: return joint_entry_contract
	if FiniteRoute.selected_v1(id):
		return FiniteRoute.contract_for_v1(id)
	if id == STARTUP_VELOCITY_POLICY_ID:
		return startup_velocity_contract
	if id == REMAINING_POLICY_ID:
		return remaining_contract
	if id == POSTURE_POLICY_ID:
		return support_hold_posture_contract
	if id == PROGRESSION_POLICY_ID:
		return support_progression_contract
	if id == STANCE_LATCH_POLICY_ID:
		return stance_latch_contract
	if id == UPRIGHT_POLICY_ID:
		return upright_contract
	if id == ABSENT_POLICY_ID:
		return absent_contract
	if id == AIRBORNE_POLICY_ID:
		return airborne_contract
	if id == WAVE_POLICY_ID:
		return wave_contract
	if id == REFERENCE_POLICY_ID:
		return reference_contract
	if id == SMOOTH_POLICY_ID:
		return smooth_contract
	if id == FEASIBLE_POLICY_ID:
		return feasible_contract
	if id == FLOOR_POLICY_ID:
		return floor_contract
	if id == SUPPORT_POLICY_ID:
		return support_contract
	return contract if id == POLICY_ID else {}

static func schema_v1(legacy: String, component: String, binding: Dictionary) -> String:
	if binding.get("policy_id") == FiniteRoute.StanceEntry.FLEXED_NATIVE_ID and binding.get("development") == true: return joint_entry_contract.receipt_schema_prefix + component + "_v1"
	if floor_selected_v1(binding.get("policy_id", "")) and binding["development"]:
		return contract_for_v1(binding["policy_id"])["receipt_schema_prefix"] + component + "_v1"
	if binding.get("policy_id") == SUPPORT_POLICY_ID and binding["development"]:
		return support_contract["receipt_schema_prefix"] + component + "_v1"
	return "sporespore_development_swing_end_walking_" + component + "_v1" if binding["development"] else legacy

static func native_profile_valid_v1(profile: Dictionary, legacy_profile: Dictionary, selected_id: String = POLICY_ID, sdk: Object = null) -> bool:
	var fixed := contract_for_v1(selected_id)
	if selected_id in [R10AP.ID, R10AM.ID, R10AJ.ID, R10AI.ID, R10AG.ID, JOINT_HEIGHT_POLICY_ID, EXTENDED_TRANSFER_POLICY_ID, BOUNDED_STOP_POLICY_ID, ZERO_BRAKE_POLICY_ID, INITIALIZED_BRAKE_POLICY_ID, EXTENDED_PREPARATION_POLICY_ID, R10K.ID, R10L.ID, R10M.ID, R10N.ID, R10O.ID, R10Q.ID, R10R.ID, R10S.ID, R10T.ID, R10U.ID, R10V.ID, R10Y.ID, R10Z.ID, R10AA.ID, R10AB.ID]:
		# V51/V52/V53 native profiles and contracts must use the same exact float decoder.
		# Static ordinary-JSON loading is sufficient for names and file hashes only.
		if sdk == null: return false
		var exact: Variant = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(R10AP.PATH if selected_id == R10AP.ID else R10AM.PATH if selected_id == R10AM.ID else R10AJ.PATH if selected_id == R10AJ.ID else R10AI.PATH if selected_id == R10AI.ID else R10AG.PATH if selected_id == R10AG.ID else R10AB.PATH if selected_id == R10AB.ID else R10AA.PATH if selected_id == R10AA.ID else R10Z.PATH if selected_id == R10Z.ID else R10Y.PATH if selected_id == R10Y.ID else R10V.PATH if selected_id == R10V.ID else R10U.PATH if selected_id == R10U.ID else R10T.PATH if selected_id == R10T.ID else R10S.PATH if selected_id == R10S.ID else R10R.PATH if selected_id == R10R.ID else R10Q.PATH if selected_id == R10Q.ID else R10O.PATH if selected_id == R10O.ID else R10N.PATH if selected_id == R10N.ID else R10M.PATH if selected_id == R10M.ID else R10L.PATH if selected_id == R10L.ID else R10K.PATH if selected_id == R10K.ID else EXTENDED_PREPARATION_PATH if selected_id == EXTENDED_PREPARATION_POLICY_ID else INITIALIZED_BRAKE_PATH if selected_id == INITIALIZED_BRAKE_POLICY_ID else ZERO_BRAKE_PATH if selected_id == ZERO_BRAKE_POLICY_ID else BOUNDED_STOP_PATH if selected_id == BOUNDED_STOP_POLICY_ID else EXTENDED_TRANSFER_PATH if selected_id == EXTENDED_TRANSFER_POLICY_ID else JOINT_HEIGHT_PATH))
		if not (exact is Dictionary): return false
		fixed = exact
	if measured_body_selected_v1(selected_id) or selected_id in [R10AP.ENTRY_ALIAS, R10AM.ENTRY_ALIAS, R10AJ.ENTRY_ALIAS, R10AI.ENTRY_ALIAS, R10AG.ENTRY_ALIAS, FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, FiniteRoute.StanceEntry.FLEXED_NATIVE_ID, R10K.ENTRY_ALIAS, R10L.ENTRY_ALIAS, R10M.ENTRY_ALIAS, R10O.ENTRY_ALIAS, R10Q.ENTRY_ALIAS, R10R.ENTRY_ALIAS, R10S.ENTRY_ALIAS, R10T.ENTRY_ALIAS, R10U.ENTRY_ALIAS, R10V.ENTRY_ALIAS, R10Y.ENTRY_ALIAS, R10Z.ENTRY_ALIAS, R10AA.ENTRY_ALIAS, R10AB.ENTRY_ALIAS]:
		return profile == fixed.get("native_profile") and legacy_profile.get("policy_id") == LEGACY_POLICY_ID
	if measured_body_selected_v1(selected_id) or selected_id in [FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, FiniteRoute.StanceEntry.FLEXED_NATIVE_ID, R10K.ENTRY_ALIAS, R10L.ENTRY_ALIAS, R10M.ENTRY_ALIAS, R10N.ENTRY_ALIAS]:
		return profile == fixed.get("native_profile") and legacy_profile.get("policy_id") == LEGACY_POLICY_ID
	if fixed.is_empty():
		return false
	if legacy_profile.get("policy_id") != LEGACY_POLICY_ID or legacy_profile.has("recontact_gate_mode_id"):
		return false
	var expected := legacy_profile.duplicate(true)
	expected["schema_version"] = fixed["native_profile_schema"]
	expected["policy_id"] = selected_id
	expected["recontact_gate_mode_id"] = fixed["recontact_gate_mode_id"]
	if selected_id in [SUPPORT_POLICY_ID, FLOOR_POLICY_ID, FEASIBLE_POLICY_ID, SMOOTH_POLICY_ID, REFERENCE_POLICY_ID, WAVE_POLICY_ID, AIRBORNE_POLICY_ID, ABSENT_POLICY_ID, UPRIGHT_POLICY_ID, STANCE_LATCH_POLICY_ID, PROGRESSION_POLICY_ID, POSTURE_POLICY_ID, REMAINING_POLICY_ID, STARTUP_VELOCITY_POLICY_ID]:
		expected["stance_support_mode_id"] = fixed["stance_support_mode_id"]
	if selected_id in [SMOOTH_POLICY_ID, REFERENCE_POLICY_ID, WAVE_POLICY_ID, AIRBORNE_POLICY_ID, ABSENT_POLICY_ID, UPRIGHT_POLICY_ID, STANCE_LATCH_POLICY_ID, PROGRESSION_POLICY_ID, POSTURE_POLICY_ID, REMAINING_POLICY_ID, STARTUP_VELOCITY_POLICY_ID]:
		expected["swing_lift_mode_id"] = fixed["swing_lift_mode_id"]
	if selected_id in [REFERENCE_POLICY_ID, WAVE_POLICY_ID, AIRBORNE_POLICY_ID, ABSENT_POLICY_ID, UPRIGHT_POLICY_ID, STANCE_LATCH_POLICY_ID, PROGRESSION_POLICY_ID, POSTURE_POLICY_ID, REMAINING_POLICY_ID, STARTUP_VELOCITY_POLICY_ID]:
		expected["reference_velocity_mode_id"] = fixed["reference_velocity_mode_id"]
	if selected_id in [PROGRESSION_POLICY_ID, POSTURE_POLICY_ID, REMAINING_POLICY_ID, STARTUP_VELOCITY_POLICY_ID]:
		expected["support_progression_mode_id"] = fixed["support_progression_mode_id"]
	if selected_id == POSTURE_POLICY_ID:
		expected["support_hold_posture_mode_id"] = fixed["support_hold_posture_mode_id"]
	return profile == expected

static func validate_report_v1(report: Dictionary, id: String) -> Dictionary:
	if binding_v1(id, "walking_resume").is_empty():
		return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_POLICY_REPORT_SELECTION"}
	var count := 0
	if id.is_empty():
		return {"ok": true, "policy_id": id, "validated_resume_sessions": count}
	var expected := binding_v1(id, "walking_resume")
	var integration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_swing_end_walking_adapter_integration_v1.json"))
	var native_profile_digest: String = contract_for_v1(id)["native_profile_sha256"] if floor_selected_v1(id) or id == SUPPORT_POLICY_ID else integration["native_profile_sha256"]
	for session in report.get("retained_arm", {}).get("walking_sessions", []):
		var start: Dictionary = session.get("start_receipt", {})
		var resume: bool = FiniteRoute.segment_selected_v1(id, session.get("evaluation_segment_id", ""))
		if not resume:
			if id == R10AP.ID and session.get("evaluation_segment_id") == R10AP.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10AP.POST_HOLD_ALIAS, R10AP.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10AP.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10AP.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10AM.ID and session.get("evaluation_segment_id") == R10AM.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10AM.POST_HOLD_ALIAS, R10AM.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10AM.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10AM.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10AJ.ID and session.get("evaluation_segment_id") == R10AJ.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10AJ.POST_HOLD_ALIAS, R10AJ.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10AJ.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10AJ.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10AI.ID and session.get("evaluation_segment_id") == R10AI.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10AI.POST_HOLD_ALIAS, R10AI.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10AI.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10AI.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10AG.ID and session.get("evaluation_segment_id") == R10AG.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10AG.POST_HOLD_ALIAS, R10AG.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10AG.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10AG.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10AB.ID and session.get("evaluation_segment_id") == R10AB.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10AB.POST_HOLD_ALIAS, R10AB.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10AB.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10AB.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10AA.ID and session.get("evaluation_segment_id") == R10AA.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10AA.POST_HOLD_ALIAS, R10AA.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10AA.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10AA.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10Z.ID and session.get("evaluation_segment_id") == R10Z.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10Z.POST_HOLD_ALIAS, R10Z.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10Z.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10Z.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10Y.ID and session.get("evaluation_segment_id") == R10Y.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10Y.POST_HOLD_ALIAS, R10Y.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10Y.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10Y.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10V.ID and session.get("evaluation_segment_id") == R10V.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10V.POST_HOLD_ALIAS, R10V.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10V.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10V.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10U.ID and session.get("evaluation_segment_id") == R10U.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10U.POST_HOLD_ALIAS, R10U.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10U.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10U.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if id == R10T.ID and session.get("evaluation_segment_id") == R10T.POST_HOLD_SEGMENT:
				var hold_binding := binding_v1(R10T.POST_HOLD_ALIAS, R10T.POST_HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("schema_version") != schema_v1("", "session", hold_binding)
					or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != R10T.POST_HOLD_ALIAS or start.get("controller_profile_sha256") != contract_for_v1(R10T.POST_HOLD_ALIAS).native_profile_sha256
					or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != hold_binding.get("policy_id")):
					return {"ok": false, "failure_code": "DEVELOPMENT_POST_RECOVERY_HOLD_SESSION_CROSSED"}
				continue
			if FiniteRoute.StanceEntry.hold_selected_v1(id) and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.HOLD_SEGMENT:
				var hold_alias := FiniteRoute.StanceEntry.hold_alias_for_v1(id)
				var hold_binding := binding_v1(hold_alias, FiniteRoute.StanceEntry.HOLD_SEGMENT)
				if (hold_binding.is_empty() or start.get("selected_policy_id") != hold_binding.get("policy_id") or start.get("selected_policy_digest") != hold_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != hold_alias or start.get("controller_profile_sha256") != contract_for_v1(hold_alias).native_profile_sha256):
					return {"ok": false, "failure_code": "DEVELOPMENT_HOLD_ENTRY_SESSION_CROSSED"}
				continue
			if FiniteRoute.StanceEntry.ramped_selected_v1(id) and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.SEGMENT:
				var entry_alias := FiniteRoute.StanceEntry.entry_selection_for_v1(id)
				var entry_binding := binding_v1(entry_alias, FiniteRoute.StanceEntry.SEGMENT)
				if (start.get("selected_policy_id") != entry_binding.get("policy_id") or start.get("selected_policy_digest") != entry_binding.get("policy_digest")
					or start.get("development_walking_policy_id") != entry_alias or start.get("controller_profile_sha256") != contract_for_v1(entry_alias).native_profile_sha256):
					return {"ok": false, "failure_code": "DEVELOPMENT_JOINT_ENTRY_SESSION_CROSSED"}
				continue
			if start.get("selected_policy_id") != LEGACY_POLICY_ID or start.has("development_walking_policy_id"):
				return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_POLICY_PREFIX_CROSSED"}
			continue
		if (start.get("schema_version") != schema_v1("", "session", expected)
			or start.get("development_walking_policy_id") != id or start.get("selected_policy_id") != expected["policy_id"]
			or start.get("selected_policy_digest") != expected["policy_digest"]
			or start.get("controller_profile_sha256") != native_profile_digest
			or session.get("completion_receipt", {}).get("adapter_summary", {}).get("controller_policy_id") != expected["policy_id"]):
			return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_POLICY_SESSION_CROSSED"}
		count += 1
	return {"ok": true, "policy_id": id, "validated_resume_sessions": count, "physical_acceptance_authority": false, "release_authority": false}
