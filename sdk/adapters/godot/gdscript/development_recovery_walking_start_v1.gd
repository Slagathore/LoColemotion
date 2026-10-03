extends RefCounted
# gdlint: disable=max-line-length

## Pure session initialization and retained-source verification; no world or motor access.
const Launcher := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const Startup := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd")
const CONTRACT_PATH := "res://sdk/development/recovery_walking_start_contract_v1.json"
static var _r10ap_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10ap_v56_walking_start_contract_v1.json"))
static var _r10am_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10am_v56_walking_start_contract_v1.json"))
static var _r10aj_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10aj_v56_walking_start_contract_v1.json"))
static var _r10ai_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10ai_v56_walking_start_contract_v1.json"))
static var _r10ag_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10ag_v56_walking_start_contract_v1.json"))
static var _r10af_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10af_v56_walking_start_contract_v1.json"))
static var _r10ae_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10ae_v56_walking_start_contract_v1.json"))
static var _r10ad_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10ad_v56_walking_start_contract_v1.json"))
static var _r10ac_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10ac_v56_walking_start_contract_v1.json"))
static var _r10ab_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10ab_v56_walking_start_contract_v1.json"))
static var _r10aa_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10aa_v56_walking_start_contract_v1.json"))
static var _r10z_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10z_v56_walking_start_contract_v1.json"))
static var _r10y_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10y_v56_walking_start_contract_v1.json"))
static var _r10v_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10v_v56_walking_start_contract_v1.json"))
static var _r10u_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10u_v56_walking_start_contract_v1.json"))
static var _r10t_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10t_v56_walking_start_contract_v1.json"))
static var _r10s_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10s_v56_walking_start_contract_v1.json"))
static var _r10r_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10r_v55_walking_start_contract_v1.json"))
static var _r10q_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10q_v55_walking_start_contract_v1.json"))
static var _r10o_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10o_v55_walking_start_contract_v1.json"))
static var _r10n_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10n_v54_walking_start_contract_v1.json"))
static var _r10m_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10m_v53_walking_start_contract_v1.json"))
static var _r10l_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10l_v52_walking_start_contract_v1.json"))
static var _r10k_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10k_v51_walking_start_contract_v1.json"))
static var _contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
static var _contact_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_contact_gated_walking_start_contract_v1.json"))
static var _rotated_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_front_left_first_walking_start_contract_v1.json"))
static var _swing_end_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_swing_end_walking_start_contract_v1.json"))
static var _support_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_bounded_support_walking_start_contract_v1.json"))
static var _floor_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_floor_support_walking_start_contract_v1.json"))

static var _feasible_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_feasible_support_walking_start_contract_v1.json"))
static var _smooth_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_smooth_swing_walking_start_contract_v1.json"))
static var _reference_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_reference_velocity_walking_start_contract_v1.json"))
static var _wave_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_wave_velocity_walking_start_contract_v1.json"))
static var _airborne_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_airborne_reference_walking_start_contract_v1.json"))
static var _absent_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_absent_contact_reference_walking_start_contract_v1.json"))
static var _upright_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_upright_stance_walking_start_contract_v2.json"))
static var _stance_latch_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_stance_latch_walking_start_contract_v1.json"))
static var _support_progression_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_support_progression_walking_start_contract_v1.json"))
static var _finite_route_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10g_v50_walking_start_contract_v3.json"))
static var _flexed_entry_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10i_v50_walking_start_contract_v4.json"))
static var _hold_entry_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10j_v50_walking_start_contract_v6.json"))
static var _stance_entry_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r10h_v50_walking_start_contract_v3.json"))
static var _startup_velocity_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_startup_reference_velocity_walking_start_contract_v1.json"))
static var _remaining_support_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_remaining_support_release_walking_start_contract_v1.json"))
static var _support_hold_posture_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_support_hold_posture_walking_start_contract_v1.json"))

static func contract_for_v1(id: Variant) -> Dictionary:
	for fixed in [_r10ap_contract, _r10am_contract, _r10aj_contract, _r10ai_contract, _rotated_contract, _contact_contract, _swing_end_contract, _support_contract, _floor_contract, _feasible_contract, _smooth_contract, _reference_contract, _wave_contract, _airborne_contract, _absent_contract, _upright_contract, _stance_latch_contract, _support_progression_contract, _support_hold_posture_contract, _remaining_support_contract, _startup_velocity_contract, _finite_route_contract, _stance_entry_contract, _flexed_entry_contract, _hold_entry_contract, _r10k_contract, _r10l_contract, _r10m_contract, _r10n_contract, _r10o_contract, _r10q_contract, _r10r_contract, _r10s_contract, _r10t_contract, _r10u_contract, _r10v_contract, _r10y_contract, _r10z_contract, _r10aa_contract, _r10ab_contract, _r10ac_contract, _r10ad_contract, _r10ae_contract, _r10ag_contract, _r10af_contract]:
		if id is String and id == fixed.get("profile_id"):
			return fixed
	return _contract

static func valid_selection_v1(id: Variant) -> bool:
	var fixed := contract_for_v1(id)
	if not (id is String) or (not id.is_empty() and id != fixed["profile_id"]):
		return false
	if fixed.has("parent_start_contract") and "sha256:" + FileAccess.get_sha256("res://" + fixed["parent_start_contract"]) != fixed["parent_start_contract_sha256"]:
		return false
	if fixed.has("initial_gait_step_offset") and (fixed["initial_gait_step_offset"] != Launcher.CYCLE_TICKS / 4 or fixed.get("first_swing_limb_id") != "front_left"):
		return false
	return id.is_empty() or "sha256:" + FileAccess.get_sha256(fixed["normal_launcher_resource"]) == fixed["normal_launcher_raw_sha256"]

static func schedule_valid_v1(schedule: Dictionary) -> bool:
	var id: Variant = schedule.get("walking_start_profile_id", "")
	var required := Startup.required_start_profile_v1(schedule.get("walking_entry_profile_id"))
	if not required.is_empty() and (not (id is String) or id != required):
		return false
	var exact: Variant = contract_for_v1(id).get("exact_entry_profile_id")
	var entry_id: Variant = schedule.get("walking_entry_profile_id", "")
	if exact != null and (not (entry_id is String) or entry_id != exact):
		return false
	return (valid_selection_v1(id) and (id.is_empty()
		or Startup.phase_family_id_v1(schedule.get("walking_entry_profile_id")) == contract_for_v1(id)["walking_entry_profile_id"]))

static func normal_initial_gait_steps_v1(id: String) -> Dictionary:
	if id.is_empty() or not valid_selection_v1(id):
		return {}
	# Execute the existing normal-launch plan, not a copied phase calculation.
	var plan := Launcher.compile_sdk_execution_mode_plan(true, true, "post_settle_full",
		Launcher.SDK_P5I3B_STABILITY_POLICY_ID, 0)
	if plan.get("ok") != true or plan.get("full_post_settle_authority_enabled") != true:
		return {}
	var phases: Dictionary = plan.get("zero_base_initial_gait_steps", {})
	# A declared pre-session phase offset rotates the existing gait order.
	# There is no pose change or mid-session memory rewrite.
	var offset := int(contract_for_v1(id).get("initial_gait_step_offset", 0))
	for limb in phases:
		phases[limb] += offset
	# Godot's generic JSON parser represents declaration counts as binary64.
	# Validate and project declarations only; never rewrite retained observations.
	var expected: Dictionary = contract_for_v1(id)["initial_gait_steps"].duplicate(true)
	for limb in expected:
		var value: Variant = expected[limb]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value) or value != int(value):
			return {}
		expected[limb] = int(value)
	if phases != expected:
		return {}
	return phases.duplicate(true)

static func validate_report_v1(report: Dictionary, id: String) -> Dictionary:
	if not valid_selection_v1(id):
		return _failure("SELECTION")
	var arm: Variant = report.get("retained_arm")
	if not (arm is Dictionary) or not (arm.get("walking_sessions", []) is Array):
		return _failure("SESSIONS")
	var validated := 0
	for session in arm.get("walking_sessions", []):
		if not (session is Dictionary) or not (session.get("start_receipt", {}) is Dictionary):
			return _failure("SESSION_SHAPE")
		var start: Dictionary = session.get("start_receipt", {})
		var selected: Variant = start.get("development_walking_start_profile_id", "")
		var resume: bool = session.get("evaluation_segment_id") in contract_for_v1(id).get("allowed_evaluation_segments", ["walking_resume"])
		if not (selected is String) or selected != (id if resume else ""):
			return _failure("SESSION_SELECTION")
		if id.is_empty() or not resume:
			continue
		var expected := normal_initial_gait_steps_v1(id)
		if (expected.is_empty() or start.get("initial_gait_steps") != expected
			or start.get("gait_phase_seed") != report.get("seed")
			or start.get("session_id") != session.get("session_id")):
			return _failure("INITIAL_PHASE")
		var rows: Variant = report.get("development_walking_entry", {}).get("rows")
		if not (rows is Array):
			return _failure("ROWS")
		var matching: Array = rows.filter(func(row): return row is Dictionary and row.get("session_id") == session.get("session_id"))
		if matching.is_empty() or matching[0].get("session_local_step") != 1:
			return _failure("FIRST_COMMAND")
		var memory: Variant = matching[0].get("request", {}).get("memory")
		if not (memory is Dictionary) or memory.get("last_semantic_step") != null:
			return _failure("INITIAL_MEMORY")
		var limbs: Variant = memory.get("ordered_limb_memory")
		if not (limbs is Array) or limbs.size() != expected.size():
			return _failure("INITIAL_MEMORY")
		var seen := {}
		for limb in limbs:
			if not (limb is Dictionary) or not expected.has(limb.get("limb_id")) or seen.has(limb["limb_id"]):
				return _failure("INITIAL_MEMORY")
			if limb.get("gait_step") != expected[limb["limb_id"]]:
				return _failure("INITIAL_MEMORY")
			seen[limb["limb_id"]] = true
		validated += 1
	return {"ok": true, "profile_id": id, "validated_resume_sessions": validated,
		"world_build_count": 0, "solver_step_count": 0, "native_physics_read_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_START_" + code}
