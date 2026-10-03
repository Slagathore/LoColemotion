extends RefCounted
# gdlint: disable=max-line-length

## Explicit amplitude and phase-mode identities, never a record rewrite.
const R10AP_CONTRACT_PATH := "res://sdk/recovery/r10ap_v56_walking_entry_contract_v9.json"
const R10AM_CONTRACT_PATH := "res://sdk/recovery/r10am_v56_walking_entry_contract_v11.json"
const R10AJ_CONTRACT_PATH := "res://sdk/recovery/r10aj_v56_walking_entry_contract_v11.json"
const R10AI_CONTRACT_PATH := "res://sdk/recovery/r10ai_v56_walking_entry_contract_v14.json"
const R10AG_CONTRACT_PATH := "res://sdk/recovery/r10ag_v56_walking_entry_contract_v15.json"
const R10AF_CONTRACT_PATH := "res://sdk/recovery/r10af_v56_walking_entry_contract_v7.json"
const R10AE_CONTRACT_PATH := "res://sdk/recovery/r10ae_v56_walking_entry_contract_v11.json"
const R10AD_CONTRACT_PATH := "res://sdk/recovery/r10ad_v56_walking_entry_contract_v5.json"
const R10AC_CONTRACT_PATH := "res://sdk/recovery/r10ac_v56_walking_entry_contract_v28.json"
const R10AB_CONTRACT_PATH := "res://sdk/recovery/r10ab_v56_walking_entry_contract_v6.json"
const R10AA_CONTRACT_PATH := "res://sdk/recovery/r10aa_v56_walking_entry_contract_v8.json"
const R10Z_CONTRACT_PATH := "res://sdk/recovery/r10z_v56_walking_entry_contract_v10.json"
const R10Y_CONTRACT_PATH := "res://sdk/recovery/r10y_v56_walking_entry_contract_v22.json"
const R10V_CONTRACT_PATH := "res://sdk/recovery/r10x_v56_walking_entry_contract_v3.json"
const R10U_CONTRACT_PATH := "res://sdk/recovery/r10u_v56_walking_entry_contract_v14.json"
const R10T_CONTRACT_PATH := "res://sdk/recovery/r10t_v56_walking_entry_contract_v25.json"
const R10S_CONTRACT_PATH := "res://sdk/recovery/r10s_v56_walking_entry_contract_v8.json"
const R10R_CONTRACT_PATH := "res://sdk/recovery/r10r_v55_walking_entry_contract_v5.json"
const R10Q_CONTRACT_PATH := "res://sdk/recovery/r10q_v55_walking_entry_contract_v7.json"
const R10O_CONTRACT_PATH := "res://sdk/recovery/r10o_v55_walking_entry_contract_v2.json"
const R10N_CONTRACT_PATH := "res://sdk/recovery/r10n_v54_walking_entry_contract_v2.json"
const R10M_CONTRACT_PATH := "res://sdk/recovery/r10m_v53_walking_entry_contract_v1.json"
const R10L_CONTRACT_PATH := "res://sdk/recovery/r10l_v52_walking_entry_contract_v6.json"
static var r10ap_contract: Dictionary = _load_contract_v1(R10AP_CONTRACT_PATH)
static var r10am_contract: Dictionary = _load_contract_v1(R10AM_CONTRACT_PATH)
static var r10aj_contract: Dictionary = _load_contract_v1(R10AJ_CONTRACT_PATH)
static var r10ai_contract: Dictionary = _load_contract_v1(R10AI_CONTRACT_PATH)
static var r10ag_contract: Dictionary = _load_contract_v1(R10AG_CONTRACT_PATH)
static var r10af_contract: Dictionary = _load_contract_v1(R10AF_CONTRACT_PATH)
static var r10ae_contract: Dictionary = _load_contract_v1(R10AE_CONTRACT_PATH)
static var r10ad_contract: Dictionary = _load_contract_v1(R10AD_CONTRACT_PATH)
static var r10ac_contract: Dictionary = _load_contract_v1(R10AC_CONTRACT_PATH)
static var r10ab_contract: Dictionary = _load_contract_v1(R10AB_CONTRACT_PATH)
static var r10aa_contract: Dictionary = _load_contract_v1(R10AA_CONTRACT_PATH)
static var r10z_contract: Dictionary = _load_contract_v1(R10Z_CONTRACT_PATH)
static var r10y_contract: Dictionary = _load_contract_v1(R10Y_CONTRACT_PATH)
static var r10v_contract: Dictionary = _load_contract_v1(R10V_CONTRACT_PATH)
static var r10u_contract: Dictionary = _load_contract_v1(R10U_CONTRACT_PATH)
static var r10t_contract: Dictionary = _load_contract_v1(R10T_CONTRACT_PATH)
static var r10s_contract: Dictionary = _load_contract_v1(R10S_CONTRACT_PATH)
static var r10r_contract: Dictionary = _load_contract_v1(R10R_CONTRACT_PATH)
static var r10q_contract: Dictionary = _load_contract_v1(R10Q_CONTRACT_PATH)
static var r10o_contract: Dictionary = _load_contract_v1(R10O_CONTRACT_PATH)
static var r10n_contract: Dictionary = _load_contract_v1(R10N_CONTRACT_PATH)
static var r10m_contract: Dictionary = _load_contract_v1(R10M_CONTRACT_PATH)
static var r10l_contract: Dictionary = _load_contract_v1(R10L_CONTRACT_PATH)
const R10K_CONTRACT_PATH := "res://sdk/recovery/r10k_v51_walking_entry_contract_v23.json"
static var r10k_contract: Dictionary = _load_contract_v1(R10K_CONTRACT_PATH)
const CONTRACT_PATH := "res://sdk/development/recovery_first_swing_walking_entry_contract_v1.json"
const LIMITED_CONTRACT_PATH := "res://sdk/development/recovery_joint_bounded_walking_entry_contract_v1.json"
const CONTACT_CONTRACT_PATH := "res://sdk/development/recovery_contact_gated_walking_entry_contract_v1.json"
const ROTATED_CONTRACT_PATH := "res://sdk/development/recovery_front_left_first_walking_entry_contract_v1.json"
const SWING_END_CONTRACT_PATH := "res://sdk/development/recovery_swing_end_walking_entry_contract_v1.json"
const SUPPORT_CONTRACT_PATH := "res://sdk/development/recovery_bounded_support_walking_entry_contract_v1.json"
const FLOOR_CONTRACT_PATH := "res://sdk/development/recovery_floor_support_walking_entry_contract_v1.json"
const FEASIBLE_CONTRACT_PATH := "res://sdk/development/recovery_feasible_support_walking_entry_contract_v1.json"
const SMOOTH_CONTRACT_PATH := "res://sdk/development/recovery_smooth_swing_walking_entry_contract_v1.json"
const REFERENCE_CONTRACT_PATH := "res://sdk/development/recovery_reference_velocity_walking_entry_contract_v1.json"
const WAVE_CONTRACT_PATH := "res://sdk/development/recovery_wave_velocity_walking_entry_contract_v1.json"
const AIRBORNE_CONTRACT_PATH := "res://sdk/development/recovery_airborne_reference_walking_entry_contract_v1.json"
const ABSENT_CONTRACT_PATH := "res://sdk/development/recovery_absent_contact_reference_walking_entry_contract_v1.json"
const UPRIGHT_CONTRACT_PATH := "res://sdk/development/recovery_upright_stance_walking_entry_contract_v2.json"
const STANCE_LATCH_CONTRACT_PATH := "res://sdk/development/recovery_stance_latch_walking_entry_contract_v1.json"
const PROGRESSION_CONTRACT_PATH := "res://sdk/development/recovery_support_progression_walking_entry_contract_v1.json"
const FLEXED_ENTRY_CONTRACT_PATH := "res://sdk/recovery/r10i_v50_walking_entry_contract_v4.json"
const HOLD_ENTRY_CONTRACT_PATH := "res://sdk/recovery/r10j_v50_walking_entry_contract_v6.json"
const STANCE_ENTRY_CONTRACT_PATH := "res://sdk/recovery/r10h_v50_walking_entry_contract_v3.json"
const FINITE_ROUTE_CONTRACT_PATH := "res://sdk/recovery/r10g_v50_walking_entry_contract_v3.json"
const STARTUP_VELOCITY_CONTRACT_PATH := "res://sdk/development/recovery_startup_reference_velocity_walking_entry_contract_v1.json"
const REMAINING_CONTRACT_PATH := "res://sdk/development/recovery_remaining_support_release_walking_entry_contract_v1.json"
const POSTURE_CONTRACT_PATH := "res://sdk/development/recovery_support_hold_posture_walking_entry_contract_v1.json"
static var contract: Dictionary = _load_contract_v1()
static var limited_contract: Dictionary = _load_contract_v1(LIMITED_CONTRACT_PATH)
static var contact_contract: Dictionary = _load_contract_v1(CONTACT_CONTRACT_PATH)
static var rotated_contract: Dictionary = _load_contract_v1(ROTATED_CONTRACT_PATH)
static var swing_end_contract: Dictionary = _load_contract_v1(SWING_END_CONTRACT_PATH)
static var support_contract: Dictionary = _load_contract_v1(SUPPORT_CONTRACT_PATH)
static var floor_contract: Dictionary = _load_contract_v1(FLOOR_CONTRACT_PATH)
static var feasible_contract: Dictionary = _load_contract_v1(FEASIBLE_CONTRACT_PATH)
static var smooth_contract: Dictionary = _load_contract_v1(SMOOTH_CONTRACT_PATH)
static var reference_contract: Dictionary = _load_contract_v1(REFERENCE_CONTRACT_PATH)
static var wave_contract: Dictionary = _load_contract_v1(WAVE_CONTRACT_PATH)
static var airborne_contract: Dictionary = _load_contract_v1(AIRBORNE_CONTRACT_PATH)
static var absent_contract: Dictionary = _load_contract_v1(ABSENT_CONTRACT_PATH)
static var upright_contract: Dictionary = _load_contract_v1(UPRIGHT_CONTRACT_PATH)
static var stance_latch_contract: Dictionary = _load_contract_v1(STANCE_LATCH_CONTRACT_PATH)
static var support_progression_contract: Dictionary = _load_contract_v1(PROGRESSION_CONTRACT_PATH)
static var finite_route_contract: Dictionary = _load_contract_v1(FINITE_ROUTE_CONTRACT_PATH)
static var flexed_entry_contract: Dictionary = _load_contract_v1(FLEXED_ENTRY_CONTRACT_PATH)
static var hold_entry_contract: Dictionary = _load_contract_v1(HOLD_ENTRY_CONTRACT_PATH)
static var stance_entry_contract: Dictionary = _load_contract_v1("res://sdk/recovery/r10h_v50_walking_entry_contract_v3.json")
static var startup_velocity_contract: Dictionary = _load_contract_v1(STARTUP_VELOCITY_CONTRACT_PATH)
static var remaining_support_contract: Dictionary = _load_contract_v1(REMAINING_CONTRACT_PATH)
static var support_hold_posture_contract: Dictionary = _load_contract_v1(POSTURE_CONTRACT_PATH)

static func _load_contract_v1(path: String = CONTRACT_PATH) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if path == R10AP_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AM_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AJ_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AI_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AG_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AF_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AE_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AD_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AC_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AB_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10AA_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10Z_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10Y_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10V_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10U_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	if path == R10T_CONTRACT_PATH and (not (value is Dictionary) or value.get("source_key_complete") != true): return {}
	var first_contact := 1 if path in [R10AP_CONTRACT_PATH, R10AM_CONTRACT_PATH, R10AJ_CONTRACT_PATH, R10AI_CONTRACT_PATH, CONTACT_CONTRACT_PATH, ROTATED_CONTRACT_PATH, SWING_END_CONTRACT_PATH, SUPPORT_CONTRACT_PATH, FLOOR_CONTRACT_PATH, FEASIBLE_CONTRACT_PATH, SMOOTH_CONTRACT_PATH, REFERENCE_CONTRACT_PATH, WAVE_CONTRACT_PATH, AIRBORNE_CONTRACT_PATH, ABSENT_CONTRACT_PATH, UPRIGHT_CONTRACT_PATH, STANCE_LATCH_CONTRACT_PATH, PROGRESSION_CONTRACT_PATH, POSTURE_CONTRACT_PATH, REMAINING_CONTRACT_PATH, STARTUP_VELOCITY_CONTRACT_PATH, FINITE_ROUTE_CONTRACT_PATH, STANCE_ENTRY_CONTRACT_PATH, FLEXED_ENTRY_CONTRACT_PATH, HOLD_ENTRY_CONTRACT_PATH, R10K_CONTRACT_PATH, R10L_CONTRACT_PATH, R10M_CONTRACT_PATH, R10N_CONTRACT_PATH, R10O_CONTRACT_PATH, R10Q_CONTRACT_PATH, R10R_CONTRACT_PATH, R10S_CONTRACT_PATH, R10T_CONTRACT_PATH, R10U_CONTRACT_PATH, R10V_CONTRACT_PATH, R10Y_CONTRACT_PATH, R10Z_CONTRACT_PATH, R10AA_CONTRACT_PATH, R10AB_CONTRACT_PATH, R10AC_CONTRACT_PATH, R10AD_CONTRACT_PATH, R10AE_CONTRACT_PATH, R10AG_CONTRACT_PATH, R10AF_CONTRACT_PATH] else 361
	if not (value is Dictionary) or value.get("warmup_steps") != 72 or value.get("first_full_amplitude_local_step") != 73 or value.get("first_contact_gated_local_step") != first_contact:
		return {}
	for field in ["phase_progression_contract", "amplitude_and_retention_contract"]:
		if "sha256:" + FileAccess.get_sha256("res://" + value[field]) != value[field + "_sha256"]:
			return {}
	if "sha256:" + FileAccess.get_sha256(value["normal_launcher_resource"]) != value["normal_launcher_raw_sha256"]:
		return {}
	if path in [R10AP_CONTRACT_PATH, R10AM_CONTRACT_PATH, R10AJ_CONTRACT_PATH, R10AI_CONTRACT_PATH, LIMITED_CONTRACT_PATH, CONTACT_CONTRACT_PATH, ROTATED_CONTRACT_PATH, SWING_END_CONTRACT_PATH, SUPPORT_CONTRACT_PATH, FLOOR_CONTRACT_PATH, FEASIBLE_CONTRACT_PATH, SMOOTH_CONTRACT_PATH, REFERENCE_CONTRACT_PATH, WAVE_CONTRACT_PATH, AIRBORNE_CONTRACT_PATH, ABSENT_CONTRACT_PATH, UPRIGHT_CONTRACT_PATH, STANCE_LATCH_CONTRACT_PATH, PROGRESSION_CONTRACT_PATH, POSTURE_CONTRACT_PATH, REMAINING_CONTRACT_PATH, STARTUP_VELOCITY_CONTRACT_PATH, FINITE_ROUTE_CONTRACT_PATH, STANCE_ENTRY_CONTRACT_PATH, FLEXED_ENTRY_CONTRACT_PATH, HOLD_ENTRY_CONTRACT_PATH, R10K_CONTRACT_PATH, R10L_CONTRACT_PATH, R10M_CONTRACT_PATH, R10N_CONTRACT_PATH, R10O_CONTRACT_PATH, R10Q_CONTRACT_PATH, R10R_CONTRACT_PATH, R10S_CONTRACT_PATH, R10T_CONTRACT_PATH, R10U_CONTRACT_PATH, R10V_CONTRACT_PATH, R10Y_CONTRACT_PATH, R10Z_CONTRACT_PATH, R10AA_CONTRACT_PATH, R10AB_CONTRACT_PATH, R10AC_CONTRACT_PATH, R10AD_CONTRACT_PATH, R10AE_CONTRACT_PATH, R10AG_CONTRACT_PATH, R10AF_CONTRACT_PATH]:
		if value.get("maximum_amplitude") != 1.1 / (0.82 * 1.75 + 0.4):
			return {}
		for source in value.get("bound_source_files", []):
			if "sha256:" + FileAccess.get_sha256("res://" + source["path"]) != source["raw_sha256"]:
				return {}
	return value

static func selected_v1(id: Variant) -> bool:
	return id is String and ((not contract.is_empty() and id == contract["profile_id"]) or limited_selected_v1(id) or contact_gated_selected_v1(id))

static func contact_gated_selected_v1(id: Variant) -> bool:
	return not contact_contract_for_v1(id).is_empty()

static func contact_contract_for_v1(id: Variant) -> Dictionary:
	for fixed in [r10ap_contract, r10am_contract, r10aj_contract, r10ai_contract, contact_contract, rotated_contract, swing_end_contract, support_contract, floor_contract, feasible_contract, smooth_contract, reference_contract, wave_contract, airborne_contract, absent_contract, upright_contract, stance_latch_contract, support_progression_contract, support_hold_posture_contract, remaining_support_contract, startup_velocity_contract, finite_route_contract, stance_entry_contract, flexed_entry_contract, hold_entry_contract, r10k_contract, r10l_contract, r10m_contract, r10n_contract, r10o_contract, r10q_contract, r10r_contract, r10s_contract, r10t_contract, r10u_contract, r10v_contract, r10y_contract, r10z_contract, r10aa_contract, r10ab_contract, r10ac_contract, r10ad_contract, r10ae_contract, r10ag_contract, r10af_contract]:
		if not fixed.is_empty() and id is String and id == fixed["profile_id"]:
			return fixed
	return {}

static func required_start_profile_v1(id: Variant) -> String:
	return contact_contract_for_v1(id).get("required_start_profile_id", "")

static func limited_selected_v1(id: Variant) -> bool:
	return not limited_contract.is_empty() and id is String and id == limited_contract["profile_id"]

static func maximum_amplitude_v1(id: Variant) -> float:
	if contact_gated_selected_v1(id):
		return float(contact_contract_for_v1(id)["maximum_amplitude"])
	return float(limited_contract["maximum_amplitude"]) if limited_selected_v1(id) else 1.0

static func phase_family_id_v1(id: Variant) -> Variant:
	if contact_gated_selected_v1(id):
		return contact_contract_for_v1(id)["phase_progression_entry_profile_id"]
	if limited_selected_v1(id):
		return limited_contract["phase_progression_entry_profile_id"]
	return contract["phase_progression_entry_profile_id"] if selected_v1(id) else id
