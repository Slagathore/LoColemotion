extends RefCounted
const R10AP := preload("res://sdk/adapters/godot/gdscript/r10ap_recovery_route_v1.gd")
const R10AM := preload("res://sdk/adapters/godot/gdscript/r10am_recovery_route_v1.gd")
const R10AJ := preload("res://sdk/adapters/godot/gdscript/r10aj_recovery_route_v1.gd")
const R10AI := preload("res://sdk/adapters/godot/gdscript/r10ai_recovery_route_v1.gd")
const R10AG := preload("res://sdk/adapters/godot/gdscript/r10ag_recovery_route_v1.gd")
const R10AB := preload("res://sdk/adapters/godot/gdscript/r10ab_recovery_route_v1.gd")
const R10AA := preload("res://sdk/adapters/godot/gdscript/r10aa_recovery_route_v1.gd")
const R10Z := preload("res://sdk/adapters/godot/gdscript/r10z_recovery_route_v1.gd")
const R10Y := preload("res://sdk/adapters/godot/gdscript/r10y_recovery_route_v1.gd")
const R10V := preload("res://sdk/adapters/godot/gdscript/r10v_recovery_route_v1.gd")
const R10U := preload("res://sdk/adapters/godot/gdscript/r10u_recovery_route_v1.gd")
const R10T := preload("res://sdk/adapters/godot/gdscript/r10t_recovery_route_v1.gd")
const R10S := preload("res://sdk/adapters/godot/gdscript/r10s_recovery_route_v1.gd")
const R10R := preload("res://sdk/adapters/godot/gdscript/r10r_recovery_route_v1.gd")
const R10Q := preload("res://sdk/adapters/godot/gdscript/r10q_recovery_route_v1.gd")
const R10O := preload("res://sdk/adapters/godot/gdscript/r10o_recovery_route_v1.gd")
const R10N := preload("res://sdk/adapters/godot/gdscript/r10n_recovery_route_v1.gd")
const R10M := preload("res://sdk/adapters/godot/gdscript/r10m_recovery_route_v1.gd")
const R10L := preload("res://sdk/adapters/godot/gdscript/r10l_recovery_route_v1.gd")
const R10K := preload("res://sdk/adapters/godot/gdscript/r10k_recovery_route_v1.gd")
## Explicit successor selection; historical R10G callers retain direct entry.
const ID := "r10h_v50_stance_entry_route_v1"
const NEUTRAL_ID := "r10h_bw5r_b_neutral_entry_v1"
const PHASE := "no_kick_neutral_stance_entry"
const SEGMENT := "neutral_stance_entry"
const ENTRY := "r10h_v50_joint_bounded_contact_gated_v1"
const START := "r10h_v50_front_left_first_post_interaction_v1"
const PATH := "res://sdk/recovery/r10h_v50_walking_route_contract_v3.json"
const TASK_PATH := "res://sdk/recovery/r10h_stance_entry_finite_cycle_contract_v1.json"
const Readiness := preload("res://sdk/adapters/godot/gdscript/recovery_walking_readiness_v1.gd")
static var task: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TASK_PATH))
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))

const FLEXED_ID := "r10i_v50_flexed_entry_route_v1"
const FLEXED_ENTRY := "r10i_v50_joint_bounded_contact_gated_v1"
const FLEXED_START := "r10i_v50_front_left_first_post_interaction_v1"
const FLEXED_NEUTRAL_ID := "r10i_joint_pose_entry_v1"
const FLEXED_NATIVE_ID := "sporespore_balanced_wave_joint_pose_entry_v1"
const FLEXED_PATH := "res://sdk/recovery/r10i_v50_walking_route_contract_v4.json"
const FLEXED_TASK_PATH := "res://sdk/recovery/r10i_flexed_entry_finite_cycle_contract_v1.json"
static var flexed_task: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLEXED_TASK_PATH))
static var flexed_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLEXED_PATH))

## R10J: the same ramp, then a separate zero-amplitude V50 hold session for the
## measured-ready dwell. Ramp and hold each carry an explicit 240-command budget.
const HOLD_ID := "r10j_v50_settled_hold_route_v1"
const HOLD_ENTRY := "r10j_v50_joint_bounded_contact_gated_v1"
const HOLD_START := "r10j_v50_front_left_first_post_interaction_v1"
const HOLD_ALIAS := "r10j_v50_zero_amplitude_hold_v1"
const HOLD_SEGMENT := "v50_hold_stance_entry"
const HOLD_EVENT := "v50_hold_entry_step"
const HOLD_PATH := "res://sdk/recovery/r10j_v50_walking_route_contract_v6.json"
const HOLD_TASK_PATH := "res://sdk/recovery/r10j_settled_hold_finite_cycle_contract_v1.json"
static var hold_task: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HOLD_TASK_PATH))
static var hold_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HOLD_PATH))

static func flexed_selected_v1(id: String) -> bool:
	return id == FLEXED_ID

static func hold_selected_v1(id: String) -> bool:
	return id in [R10AP.ID, R10AM.ID, R10AJ.ID, R10AI.ID, R10AG.ID, HOLD_ID, R10K.ID, R10L.ID, R10M.ID, R10N.ID, R10O.ID, R10Q.ID, R10R.ID, R10S.ID, R10T.ID, R10U.ID, R10V.ID, R10Y.ID, R10Z.ID, R10AA.ID, R10AB.ID]

## Routes whose entry ramp is the R10I measured-joint flexed ramp.
static func ramped_selected_v1(id: String) -> bool:
	return id in [R10AP.ID, R10AM.ID, R10AJ.ID, R10AI.ID, R10AG.ID, FLEXED_ID, HOLD_ID, R10K.ID, R10L.ID, R10M.ID, R10N.ID, R10O.ID, R10Q.ID, R10R.ID, R10S.ID, R10T.ID, R10U.ID, R10V.ID, R10Y.ID, R10Z.ID, R10AA.ID, R10AB.ID]

static func selected_v1(id: String) -> bool:
	return id in [R10AP.ID, R10AM.ID, R10AJ.ID, R10AI.ID, R10AG.ID, ID, FLEXED_ID, HOLD_ID, R10K.ID, R10L.ID, R10M.ID, R10N.ID, R10O.ID, R10Q.ID, R10R.ID, R10S.ID, R10T.ID, R10U.ID, R10V.ID, R10Y.ID, R10Z.ID, R10AA.ID, R10AB.ID]

static func task_for_v1(id: String) -> Dictionary:
	if id == R10AP.ID: return R10AP.task
	if id == R10AM.ID: return R10AM.task
	if id == R10AJ.ID: return R10AJ.task
	if id == R10AI.ID: return R10AI.task
	if id == R10AG.ID: return R10AG.task
	if id == R10AB.ID: return R10AB.task
	if id == R10AA.ID: return R10AA.task
	if id == R10Z.ID: return R10Z.task
	if id == R10Y.ID: return R10Y.task
	if id == R10V.ID: return R10V.task
	if id == R10U.ID: return R10U.task
	if id == R10T.ID: return R10T.task
	if id == R10S.ID: return R10S.task
	if id == R10R.ID: return R10R.task
	if id == R10Q.ID: return R10Q.task
	if id == R10O.ID: return R10O.task
	if id == R10N.ID: return R10N.task
	if id == R10M.ID: return R10M.task
	if id == R10L.ID: return R10L.task
	if id == R10K.ID: return R10K.task
	return hold_task if hold_selected_v1(id) else flexed_task if flexed_selected_v1(id) else task

static func task_path_for_v1(id: String) -> String:
	if id == R10AP.ID: return R10AP.TASK_PATH
	if id == R10AM.ID: return R10AM.TASK_PATH
	if id == R10AJ.ID: return R10AJ.TASK_PATH
	if id == R10AI.ID: return R10AI.TASK_PATH
	if id == R10AG.ID: return R10AG.TASK_PATH
	if id == R10AB.ID: return R10AB.TASK_PATH
	if id == R10AA.ID: return R10AA.TASK_PATH
	if id == R10Z.ID: return R10Z.TASK_PATH
	if id == R10Y.ID: return R10Y.TASK_PATH
	if id == R10V.ID: return R10V.TASK_PATH
	if id == R10U.ID: return R10U.TASK_PATH
	if id == R10T.ID: return R10T.TASK_PATH
	if id == R10S.ID: return R10S.TASK_PATH
	if id == R10R.ID: return R10R.TASK_PATH
	if id == R10Q.ID: return R10Q.TASK_PATH
	if id == R10O.ID: return R10O.TASK_PATH
	if id == R10N.ID: return R10N.TASK_PATH
	if id == R10M.ID: return R10M.TASK_PATH
	if id == R10L.ID: return R10L.TASK_PATH
	if id == R10K.ID: return R10K.TASK_PATH
	return HOLD_TASK_PATH if hold_selected_v1(id) else FLEXED_TASK_PATH if flexed_selected_v1(id) else TASK_PATH

static func contract_for_v1(id: String) -> Dictionary:
	if id == R10AP.ID: return R10AP.contract
	if id == R10AM.ID: return R10AM.contract
	if id == R10AJ.ID: return R10AJ.contract
	if id == R10AI.ID: return R10AI.contract
	if id == R10AG.ID: return R10AG.contract
	if id == R10AB.ID: return R10AB.contract
	if id == R10AA.ID: return R10AA.contract
	if id == R10Z.ID: return R10Z.contract
	if id == R10Y.ID: return R10Y.contract
	if id == R10V.ID: return R10V.contract
	if id == R10U.ID: return R10U.contract
	if id == R10T.ID: return R10T.contract
	if id == R10S.ID: return R10S.contract
	if id == R10R.ID: return R10R.contract
	if id == R10Q.ID: return R10Q.contract
	if id == R10O.ID: return R10O.contract
	if id == R10N.ID: return R10N.contract
	if id == R10M.ID: return R10M.contract
	if id == R10L.ID: return R10L.contract
	if id == R10K.ID: return R10K.contract
	return hold_contract if hold_selected_v1(id) else flexed_contract if flexed_selected_v1(id) else contract

static func path_for_v1(id: String) -> String:
	if id == R10AP.ID: return R10AP.PATH
	if id == R10AM.ID: return R10AM.PATH
	if id == R10AJ.ID: return R10AJ.PATH
	if id == R10AI.ID: return R10AI.PATH
	if id == R10AG.ID: return R10AG.PATH
	if id == R10AB.ID: return R10AB.PATH
	if id == R10AA.ID: return R10AA.PATH
	if id == R10Z.ID: return R10Z.PATH
	if id == R10Y.ID: return R10Y.PATH
	if id == R10V.ID: return R10V.PATH
	if id == R10U.ID: return R10U.PATH
	if id == R10T.ID: return R10T.PATH
	if id == R10S.ID: return R10S.PATH
	if id == R10R.ID: return R10R.PATH
	if id == R10Q.ID: return R10Q.PATH
	if id == R10O.ID: return R10O.PATH
	if id == R10N.ID: return R10N.PATH
	if id == R10M.ID: return R10M.PATH
	if id == R10L.ID: return R10L.PATH
	if id == R10K.ID: return R10K.PATH
	return HOLD_PATH if hold_selected_v1(id) else FLEXED_PATH if flexed_selected_v1(id) else PATH

static func entry_selection_for_v1(id: String) -> String:
	if id == R10AP.ID: return R10AP.ENTRY_ALIAS
	if id == R10AM.ID: return R10AM.ENTRY_ALIAS
	if id == R10AJ.ID: return R10AJ.ENTRY_ALIAS
	if id == R10AI.ID: return R10AI.ENTRY_ALIAS
	if id == R10AG.ID: return R10AG.ENTRY_ALIAS
	if id == R10AB.ID: return R10AB.ENTRY_ALIAS
	if id == R10AA.ID: return R10AA.ENTRY_ALIAS
	if id == R10Z.ID: return R10Z.ENTRY_ALIAS
	if id == R10Y.ID: return R10Y.ENTRY_ALIAS
	if id == R10V.ID: return R10V.ENTRY_ALIAS
	if id == R10U.ID: return R10U.ENTRY_ALIAS
	if id == R10T.ID: return R10T.ENTRY_ALIAS
	if id == R10S.ID: return R10S.ENTRY_ALIAS
	if id == R10R.ID: return R10R.ENTRY_ALIAS
	if id == R10Q.ID: return R10Q.ENTRY_ALIAS
	if id == R10O.ID: return R10O.ENTRY_ALIAS
	if id == R10N.ID: return R10N.ENTRY_ALIAS
	if id == R10M.ID: return R10M.ENTRY_ALIAS
	if id == R10L.ID: return R10L.ENTRY_ALIAS
	if id == R10K.ID: return R10K.ENTRY_ALIAS
	return FLEXED_NEUTRAL_ID if ramped_selected_v1(id) else NEUTRAL_ID

static func entry_owner_for_v1(id: String) -> String:
	return "stance" if ramped_selected_v1(id) else "walking_bw5r_b"

static func retention_schema_v1(id: String) -> String:
	if id == R10AP.ID: return "sporespore_r10ap_stance_entry_retention_v1"
	if id == R10AM.ID: return "sporespore_r10am_stance_entry_retention_v1"
	if id == R10AJ.ID: return "sporespore_r10aj_stance_entry_retention_v1"
	if id == R10AI.ID: return "sporespore_r10ai_stance_entry_retention_v1"
	if id == R10AG.ID: return "sporespore_r10ag_stance_entry_retention_v1"
	if id == R10AB.ID: return "sporespore_r10ab_stance_entry_retention_v1"
	if id == R10AA.ID: return "sporespore_r10aa_stance_entry_retention_v1"
	if id == R10Z.ID: return "sporespore_r10z_stance_entry_retention_v1"
	if id == R10Y.ID: return "sporespore_r10y_stance_entry_retention_v1"
	if id == R10V.ID: return "sporespore_r10v_stance_entry_retention_v1"
	if id == R10U.ID: return "sporespore_r10u_stance_entry_retention_v1"
	if id == R10T.ID: return "sporespore_r10t_stance_entry_retention_v1"
	if id == R10S.ID: return "sporespore_r10s_stance_entry_retention_v1"
	if id == R10R.ID: return "sporespore_r10r_stance_entry_retention_v1"
	if id == R10Q.ID: return "sporespore_r10q_stance_entry_retention_v1"
	if id == R10O.ID: return "sporespore_r10o_stance_entry_retention_v1"
	if id == R10N.ID: return "sporespore_r10n_stance_entry_retention_v1"
	if id == R10M.ID: return "sporespore_r10m_stance_entry_retention_v1"
	if id == R10L.ID: return "sporespore_r10l_stance_entry_retention_v1"
	if id == R10K.ID: return "sporespore_r10k_stance_entry_retention_v1"
	return "sporespore_r10j_stance_entry_retention_v1" if hold_selected_v1(id) else "sporespore_r10i_stance_entry_retention_v1" if flexed_selected_v1(id) else "sporespore_r10h_stance_entry_retention_v1"

static func initial_fields_v1() -> Dictionary:
	return {"neutral_entry_step_count": 0, "consecutive_neutral_ready": 0, "neutral_entry_session_id": ""}

static func initial_fields_for_v1(id: String) -> Dictionary:
	var fields := initial_fields_v1()
	if hold_selected_v1(id):
		fields.merge({"entry_ramp_complete": false, "hold_entry_step_count": 0, "hold_entry_session_id": ""})
	return fields

static func state_fields_valid_for_v1(state: Dictionary, id: String) -> bool:
	if not hold_selected_v1(id):
		return state_fields_valid_v1(state)
	var count: Variant = state.get("neutral_entry_step_count")
	var dwell: Variant = state.get("consecutive_neutral_ready")
	var session: Variant = state.get("neutral_entry_session_id")
	var ramp_complete: Variant = state.get("entry_ramp_complete")
	var hold_count: Variant = state.get("hold_entry_step_count")
	var hold_session: Variant = state.get("hold_entry_session_id")
	if (typeof(count) != TYPE_INT or typeof(dwell) != TYPE_INT or typeof(session) != TYPE_STRING
		or typeof(ramp_complete) != TYPE_BOOL or typeof(hold_count) != TYPE_INT or typeof(hold_session) != TYPE_STRING):
		return false
	if count < 0 or count > 240 or (count == 0) != session.is_empty():
		return false
	if hold_count < 0 or hold_count > 240 or (hold_count == 0) != hold_session.is_empty() or (hold_count > 0 and not ramp_complete):
		return false
	# Ready dwell is counted only inside the hold session.
	if dwell < 0 or dwell > mini(hold_count, 30) or (ramp_complete and count == 0):
		return false
	if state.get("arm_id") == "kick_passive_recovery_resume":
		return count == 0 and dwell == 0 and hold_count == 0 and not ramp_complete and state.get("phase") != PHASE
	if state.get("phase") == PHASE:
		return (count <= 240 and hold_count < 240 and dwell < 30 and state.get("matched_continuation_step_count") == 0
			and (ramp_complete or count < 240))
	if state.get("phase") in ["matched_no_kick_continuation", "complete"]:
		return ramp_complete and dwell == 30 and hold_count >= 30
	return true

static func state_fields_valid_v1(state: Dictionary) -> bool:
	var count: Variant = state.get("neutral_entry_step_count")
	var dwell: Variant = state.get("consecutive_neutral_ready")
	var session: Variant = state.get("neutral_entry_session_id")
	if typeof(count) != TYPE_INT or typeof(dwell) != TYPE_INT or typeof(session) != TYPE_STRING:
		return false
	if count < 0 or count > 240 or dwell < 0 or dwell > mini(count, 30) or (count == 0) != session.is_empty():
		return false
	if state.get("arm_id") == "kick_passive_recovery_resume":
		return count == 0 and dwell == 0 and state.get("phase") != PHASE
	if state.get("phase") == PHASE:
		return count < 240 and dwell < 30 and state.get("matched_continuation_step_count") == 0
	if state.get("phase") in ["matched_no_kick_continuation", "complete"]:
		return dwell == 30 and count >= 30
	return true

static func advance_neutral_v1(state: Dictionary, event: Dictionary, route: String = ID) -> String:
	if hold_selected_v1(route):
		return advance_hold_route_v1(state, event, route)
	var count: int = state.neutral_entry_step_count + 1
	var session: String = event.walking_session_id
	if (state.arm_id != "matched_no_kick_continuation" or event.event_kind != "neutral_stance_entry_step"
		or event.control_owner != entry_owner_for_v1(route) or event.actuation_owner != entry_owner_for_v1(route)
		or event.no_actuation_requested or not event.walking_actuation_applied or event.recovery_actuation_applied
		or event.walking_session_local_step != count or session.is_empty() or session == state.prefix_walking_session_id
		or not state.resume_or_continuation_session_id.is_empty()
		or event.recovery_epoch_local_step != event.global_semantic_step-state.epoch_start_global_step
		or event.recovery_epoch_local_step != count
		or event.recovery_controller_terminal_phase != "" or event.recovery_controller_terminal_reason != ""
		or event.kick_application_count != 0 or event.interaction_receipt_sha256 != ""
		or event.energy_initializer_sha256 != state.energy_initializer_sha256
		or event.walking_motors_disabled_in_same_pre_solver_event or event.walking_motors_enabled_during_interaction_solve):
		return "R10H_NEUTRAL_EVENT_INVALID"
	if state.neutral_entry_session_id.is_empty(): state.neutral_entry_session_id = session
	elif state.neutral_entry_session_id != session: return "R10H_NEUTRAL_SESSION_CROSSED"
	state.neutral_entry_step_count = count
	state.consecutive_neutral_ready = state.consecutive_neutral_ready+1 if event.neutral_entry_ready else 0
	state.recovery_epoch_step_count = event.recovery_epoch_local_step
	if state.consecutive_neutral_ready == 30:
		state.phase = "matched_no_kick_continuation"
	elif count == 240:
		state.phase = "failed"
		state.terminal_outcome = "failed"
		state.terminal_reason = "neutral_stance_entry_timeout"
	return ""

## R10J: ramp events are neutral_stance_entry_step; hold events are v50_hold_entry_step.
## A ramp event marked ready (native reference ramp complete with four native
## supports) closes the ramp; the next event must open the hold session.
static func advance_hold_route_v1(state: Dictionary, event: Dictionary, route: String) -> String:
	var session: String = event.walking_session_id
	var kind: String = event.event_kind
	if (state.arm_id != "matched_no_kick_continuation" or kind not in ["neutral_stance_entry_step", HOLD_EVENT]
		or event.control_owner != entry_owner_for_v1(route) or event.actuation_owner != entry_owner_for_v1(route)
		or event.no_actuation_requested or not event.walking_actuation_applied or event.recovery_actuation_applied
		or session.is_empty() or session == state.prefix_walking_session_id
		or not state.resume_or_continuation_session_id.is_empty()
		or event.recovery_epoch_local_step != event.global_semantic_step-state.epoch_start_global_step
		or event.recovery_epoch_local_step != state.neutral_entry_step_count + state.hold_entry_step_count + 1
		or event.recovery_controller_terminal_phase != "" or event.recovery_controller_terminal_reason != ""
		or event.kick_application_count != 0 or event.interaction_receipt_sha256 != ""
		or event.energy_initializer_sha256 != state.energy_initializer_sha256
		or event.walking_motors_disabled_in_same_pre_solver_event or event.walking_motors_enabled_during_interaction_solve):
		return "R10J_ENTRY_EVENT_INVALID"
	if kind == "neutral_stance_entry_step":
		if state.entry_ramp_complete: return "R10J_RAMP_AFTER_COMPLETION"
		var count: int = state.neutral_entry_step_count + 1
		if event.walking_session_local_step != count: return "R10J_RAMP_EVENT_INVALID"
		if state.neutral_entry_session_id.is_empty(): state.neutral_entry_session_id = session
		elif state.neutral_entry_session_id != session: return "R10J_RAMP_SESSION_CROSSED"
		state.neutral_entry_step_count = count
		state.recovery_epoch_step_count = event.recovery_epoch_local_step
		if event.neutral_entry_ready:
			state.entry_ramp_complete = true
		elif count == 240:
			state.phase = "failed"
			state.terminal_outcome = "failed"
			state.terminal_reason = "neutral_stance_entry_timeout"
		return ""
	if not state.entry_ramp_complete: return "R10J_HOLD_BEFORE_RAMP_COMPLETION"
	var hold_count: int = state.hold_entry_step_count + 1
	if event.walking_session_local_step != hold_count or session == state.neutral_entry_session_id: return "R10J_HOLD_EVENT_INVALID"
	if state.hold_entry_session_id.is_empty(): state.hold_entry_session_id = session
	elif state.hold_entry_session_id != session: return "R10J_HOLD_SESSION_CROSSED"
	state.hold_entry_step_count = hold_count
	state.consecutive_neutral_ready = state.consecutive_neutral_ready+1 if event.neutral_entry_ready else 0
	state.recovery_epoch_step_count = event.recovery_epoch_local_step
	if state.consecutive_neutral_ready == 30:
		state.phase = "matched_no_kick_continuation"
	elif hold_count == 240:
		state.phase = "failed"
		state.terminal_outcome = "failed"
		state.terminal_reason = "v50_hold_entry_timeout"
	return ""

static func hold_alias_for_v1(id: String) -> String:
	return R10AP.HOLD_ALIAS if id == R10AP.ID else R10AM.HOLD_ALIAS if id == R10AM.ID else R10AJ.HOLD_ALIAS if id == R10AJ.ID else R10AI.HOLD_ALIAS if id == R10AI.ID else R10AG.HOLD_ALIAS if id == R10AG.ID else R10AB.HOLD_ALIAS if id == R10AB.ID else R10AA.HOLD_ALIAS if id == R10AA.ID else R10Z.HOLD_ALIAS if id == R10Z.ID else R10Y.HOLD_ALIAS if id == R10Y.ID else R10V.HOLD_ALIAS if id == R10V.ID else R10U.HOLD_ALIAS if id == R10U.ID else R10T.HOLD_ALIAS if id == R10T.ID else R10S.HOLD_ALIAS if id == R10S.ID else R10R.HOLD_ALIAS if id == R10R.ID else R10Q.HOLD_ALIAS if id == R10Q.ID else R10O.HOLD_ALIAS if id == R10O.ID else R10N.HOLD_ALIAS if id == R10N.ID else R10M.HOLD_ALIAS if id == R10M.ID else R10L.HOLD_ALIAS if id == R10L.ID else R10K.HOLD_ALIAS if id == R10K.ID else HOLD_ALIAS
