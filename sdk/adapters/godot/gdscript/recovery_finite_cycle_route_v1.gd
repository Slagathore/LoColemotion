extends RefCounted
const R10AFSelection := preload("res://sdk/adapters/godot/gdscript/r10af_capture_selection_v1.gd")
const R10AESelection := preload("res://sdk/adapters/godot/gdscript/r10ae_capture_selection_v1.gd")
const R10ADSelection := preload("res://sdk/adapters/godot/gdscript/r10ad_capture_selection_v1.gd")
const R10ACSelection := preload("res://sdk/adapters/godot/gdscript/r10ac_capture_selection_v1.gd")
const StanceEntry := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_route_v1.gd")
## Caller-selected integration identity; native policy identity remains V50.
const ID := "r10g_v50_finite_cycle_walking_route_v1"
const ENTRY := "r10g_v50_joint_bounded_contact_gated_v3"
const START := "r10g_v50_front_left_first_post_interaction_v3"
const PATH := "res://sdk/recovery/r10g_v50_walking_route_contract_v3.json"
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func selected_v1(id: String) -> bool:
	return id == ID or StanceEntry.selected_v1(id)

static func contract_for_v1(id: String) -> Dictionary:
	return StanceEntry.contract_for_v1(id) if StanceEntry.selected_v1(id) else contract

static func segment_selected_v1(id: String, segment: String) -> bool:
	return segment in ["walking_resume", "matched_continuation"] if selected_v1(id) else segment == "walking_resume"

static func binding_v1(id: String, segment: String) -> Dictionary:
	if id == StanceEntry.R10AP.ID and not StanceEntry.R10AP.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10AM.ID and not StanceEntry.R10AM.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10AJ.ID and not StanceEntry.R10AJ.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10AI.ID and not StanceEntry.R10AI.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10AG.ID and not StanceEntry.R10AG.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10AB.ID and not StanceEntry.R10AB.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10AA.ID and not StanceEntry.R10AA.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10Z.ID and not StanceEntry.R10Z.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10Y.ID and not StanceEntry.R10Y.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10V.ID and not StanceEntry.R10V.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10U.ID and not StanceEntry.R10U.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10T.ID and not StanceEntry.R10T.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10S.ID and not StanceEntry.R10S.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10R.ID and not StanceEntry.R10R.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10Q.ID and not StanceEntry.R10Q.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10O.ID and not StanceEntry.R10O.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10N.ID and not StanceEntry.R10N.native_identity_consistent_v1():
		return {}
	if id == StanceEntry.R10M.ID and not StanceEntry.R10M.native_identity_consistent_v1():
		return {}
	var fixed := contract_for_v1(id)
	var path := StanceEntry.path_for_v1(id) if StanceEntry.selected_v1(id) else PATH
	if not selected_v1(id) or not segment_selected_v1(id, segment) or fixed.get("selection_id") != id:
		return {}
	for key in ["native_component_record", "runtime_binding", "task_contract"]:
		if "sha256:" + FileAccess.get_sha256("res://" + fixed[key]) != fixed[key + "_sha256"]:
			return {}
	if fixed.get("physical_acceptance_authority") != false or fixed.get("release_authority") != false:
		return {}
	return {"policy_id": fixed["policy_id"], "policy_digest": "sha256:" + FileAccess.get_sha256(path), "development": true}

static func schedule_valid_v1(schedule: Dictionary) -> bool:
	if schedule.get("walking_entry_profile_id") == R10AFSelection.ENTRY:
		var native := R10AFSelection.native_schedule_v1(schedule)
		return not native.is_empty() and schedule_valid_v1(native)
	if schedule.get("walking_entry_profile_id") == R10AESelection.ENTRY:
		var native := R10AESelection.native_schedule_v1(schedule)
		return not native.is_empty() and schedule_valid_v1(native)
	if schedule.get("walking_entry_profile_id") == R10ADSelection.ENTRY:
		var native := R10ADSelection.native_schedule_v1(schedule)
		return not native.is_empty() and schedule_valid_v1(native)
	if schedule.get("walking_entry_profile_id") == R10ACSelection.ENTRY:
		var native := R10ACSelection.native_schedule_v1(schedule)
		return not native.is_empty() and schedule_valid_v1(native)
	var id: String = schedule.get("walking_policy_id", "")
	var fixed := contract_for_v1(id)
	var path := StanceEntry.path_for_v1(id) if StanceEntry.selected_v1(id) else PATH
	return (not binding_v1(id, "walking_resume").is_empty()
		and schedule.get("walking_entry_profile_id") == fixed.entry_profile_id
		and schedule.get("walking_start_profile_id") == fixed.start_profile_id
		and schedule.get("runtime_sha256") == fixed.runtime_sha256
		and schedule.get("walking_policy_contract_sha256") == "sha256:" + FileAccess.get_sha256(path)
		and not schedule.has("walking_replay_profile_id"))

static func task_boundary_v1(report: Dictionary, memory: Dictionary, id: String = ID) -> Dictionary:
	var fixed := contract_for_v1(id)
	var role: String = report.get("arm_id", "")
	var kicked := role == "kick_passive_recovery_resume"
	var known := kicked or role == "matched_no_kick_continuation"
	var maximum := 3752 if kicked and id in [StanceEntry.R10AP.ID, StanceEntry.R10AM.ID, StanceEntry.R10AJ.ID, StanceEntry.R10AI.ID, StanceEntry.R10AG.ID, StanceEntry.R10T.ID, StanceEntry.R10U.ID, StanceEntry.R10V.ID, StanceEntry.R10Y.ID, StanceEntry.R10Z.ID, StanceEntry.R10AA.ID, StanceEntry.R10AB.ID] else 3512 if kicked else 2552 if StanceEntry.hold_selected_v1(id) else 2312 if StanceEntry.selected_v1(id) else 2072
	return {"schema_version": "sporespore_r10ap_finite_task_boundary_v1" if id == StanceEntry.R10AP.ID else "sporespore_r10am_finite_task_boundary_v1" if id == StanceEntry.R10AM.ID else "sporespore_r10aj_finite_task_boundary_v1" if id == StanceEntry.R10AJ.ID else "sporespore_r10ai_finite_task_boundary_v1" if id == StanceEntry.R10AI.ID else "sporespore_r10ag_finite_task_boundary_v1" if id == StanceEntry.R10AG.ID else "sporespore_r10ab_finite_task_boundary_v1" if id == StanceEntry.R10AB.ID else "sporespore_r10aa_finite_task_boundary_v1" if id == StanceEntry.R10AA.ID else "sporespore_r10z_finite_task_boundary_v1" if id == StanceEntry.R10Z.ID else "sporespore_r10y_finite_task_boundary_v1" if id == StanceEntry.R10Y.ID else "sporespore_r10v_finite_task_boundary_v1" if id == StanceEntry.R10V.ID else "sporespore_r10u_finite_task_boundary_v1" if id == StanceEntry.R10U.ID else "sporespore_r10t_finite_task_boundary_v1" if id == StanceEntry.R10T.ID else "sporespore_r10s_finite_task_boundary_v1" if id == StanceEntry.R10S.ID else "sporespore_r10r_finite_task_boundary_v1" if id == StanceEntry.R10R.ID else "sporespore_r10q_finite_task_boundary_v1" if id == StanceEntry.R10Q.ID else "sporespore_r10o_finite_task_boundary_v1" if id == StanceEntry.R10O.ID else "sporespore_r10n_finite_task_boundary_v1" if id == StanceEntry.R10N.ID else "sporespore_r10m_finite_task_boundary_v1" if id == StanceEntry.R10M.ID else "sporespore_r10l_finite_task_boundary_v1" if id == StanceEntry.R10L.ID else "sporespore_r10k_finite_task_boundary_v1" if id == StanceEntry.R10K.ID else "sporespore_r10j_finite_task_boundary_v1" if StanceEntry.hold_selected_v1(id) else "sporespore_r10i_finite_task_boundary_v1" if StanceEntry.flexed_selected_v1(id) else "sporespore_r10h_finite_task_boundary_v1" if StanceEntry.selected_v1(id) else "sporespore_r10g_finite_task_boundary_v1",
		"task_contract_sha256": fixed["task_contract_sha256"], "route_selection_id": id,
		"native_policy_id": fixed["policy_id"], "role": role,
		"post_interaction_segment": "walking_resume" if kicked else "matched_continuation",
		"maximum_role_solver_steps": maximum,
		"role_and_budget_valid": known and report.get("solver_step_count", maximum + 1) <= maximum,
		"planned_cycle_count": memory.get("completed", {}).size(),
		"walking_cutoff_command": memory.get("cycle_end_command", 0),
		"stopping_commands": memory.get("stopping_commands", 0),
		"cycle_and_stop_boundary_reached": report.get("stop_reason") == "diagnostic_cycle_aligned_stop_complete" and memory.get("completed", {}).size() == 4 and memory.get("stopping_commands") == 120,
		"fixed_tail_coverage_reinterpreted": false,
		"physical_acceptance_authority": false, "release_authority": false}
