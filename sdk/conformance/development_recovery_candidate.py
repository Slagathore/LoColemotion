"""Immutable candidate data; stable development harness, never acceptance authority."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import qsdk_r10f_l15_collection_retention as packet

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / 'sdk/development_recovery_candidate_contract_v1.json'
SCHEDULES_PATH = ROOT / 'sdk/development_recovery_candidate_schedules_v1.json'
DEFAULT_LIMITS = dict(maximum_precondition_steps=320, walking_prefix_steps=30, interaction_steps=1,
                      maximum_passive_descent_steps=240, after_interaction_steps=480, maximum_steps_per_child=832)
FIRST_SWING_ENTRY_PATH = ROOT / 'sdk/development/recovery_first_swing_walking_entry_contract_v1.json'
JOINT_BOUNDED_ENTRY_PATH = ROOT / 'sdk/development/recovery_joint_bounded_walking_entry_contract_v1.json'
CONTACT_GATED_ENTRY_PATH = ROOT / 'sdk/development/recovery_contact_gated_walking_entry_contract_v1.json'
CONTACT_GATED_START_PATH = ROOT / 'sdk/development/recovery_contact_gated_walking_start_contract_v1.json'
ROTATED_ENTRY_PATH = ROOT / 'sdk/development/recovery_front_left_first_walking_entry_contract_v1.json'
ROTATED_START_PATH = ROOT / 'sdk/development/recovery_front_left_first_walking_start_contract_v1.json'
SWING_END_ENTRY_PATH = ROOT / 'sdk/development/recovery_swing_end_walking_entry_contract_v1.json'
SWING_END_START_PATH = ROOT / 'sdk/development/recovery_swing_end_walking_start_contract_v1.json'
WALKING_POLICY_PATH = ROOT / 'sdk/development/recovery_swing_end_walking_policy_contract_v1.json'
SUPPORT_ENTRY_PATH = ROOT / 'sdk/development/recovery_bounded_support_walking_entry_contract_v1.json'
SUPPORT_START_PATH = ROOT / 'sdk/development/recovery_bounded_support_walking_start_contract_v1.json'
SUPPORT_POLICY_PATH = ROOT / 'sdk/development/recovery_bounded_support_walking_policy_contract_v1.json'
FLOOR_ENTRY_PATH = ROOT / 'sdk/development/recovery_floor_support_walking_entry_contract_v1.json'
FLOOR_START_PATH = ROOT / 'sdk/development/recovery_floor_support_walking_start_contract_v1.json'
FLOOR_POLICY_PATH = ROOT / 'sdk/development/recovery_floor_support_walking_policy_contract_v1.json'
FEASIBLE_ENTRY_PATH = ROOT / 'sdk/development/recovery_feasible_support_walking_entry_contract_v1.json'
FEASIBLE_START_PATH = ROOT / 'sdk/development/recovery_feasible_support_walking_start_contract_v1.json'
FEASIBLE_POLICY_PATH = ROOT / 'sdk/development/recovery_feasible_support_walking_policy_contract_v1.json'
SMOOTH_ENTRY_PATH = ROOT / 'sdk/development/recovery_smooth_swing_walking_entry_contract_v1.json'
SMOOTH_START_PATH = ROOT / 'sdk/development/recovery_smooth_swing_walking_start_contract_v1.json'
SMOOTH_POLICY_PATH = ROOT / 'sdk/development/recovery_smooth_swing_walking_policy_contract_v1.json'
REFERENCE_ENTRY_PATH = ROOT / 'sdk/development/recovery_reference_velocity_walking_entry_contract_v1.json'
REFERENCE_START_PATH = ROOT / 'sdk/development/recovery_reference_velocity_walking_start_contract_v1.json'
REFERENCE_POLICY_PATH = ROOT / 'sdk/development/recovery_reference_velocity_walking_policy_contract_v1.json'
WAVE_ENTRY_PATH = ROOT / 'sdk/development/recovery_wave_velocity_walking_entry_contract_v1.json'
WAVE_START_PATH = ROOT / 'sdk/development/recovery_wave_velocity_walking_start_contract_v1.json'
WAVE_POLICY_PATH = ROOT / 'sdk/development/recovery_wave_velocity_walking_policy_contract_v1.json'
AIRBORNE_ENTRY_PATH = ROOT / 'sdk/development/recovery_airborne_reference_walking_entry_contract_v1.json'
AIRBORNE_START_PATH = ROOT / 'sdk/development/recovery_airborne_reference_walking_start_contract_v1.json'
AIRBORNE_POLICY_PATH = ROOT / 'sdk/development/recovery_airborne_reference_walking_policy_contract_v1.json'
ABSENT_ENTRY_PATH = ROOT / 'sdk/development/recovery_absent_contact_reference_walking_entry_contract_v1.json'
UPRIGHT_ENTRY_PATH = ROOT / 'sdk/development/recovery_upright_stance_walking_entry_contract_v2.json'
STANCE_LATCH_ENTRY_PATH = ROOT / 'sdk/development/recovery_stance_latch_walking_entry_contract_v1.json'
PROGRESSION_ENTRY_PATH = ROOT / 'sdk/development/recovery_support_progression_walking_entry_contract_v1.json'
POSTURE_ENTRY_PATH = ROOT / 'sdk/development/recovery_support_hold_posture_walking_entry_contract_v1.json'
ABSENT_START_PATH = ROOT / 'sdk/development/recovery_absent_contact_reference_walking_start_contract_v1.json'
UPRIGHT_START_PATH = ROOT / 'sdk/development/recovery_upright_stance_walking_start_contract_v2.json'
STANCE_LATCH_START_PATH = ROOT / 'sdk/development/recovery_stance_latch_walking_start_contract_v1.json'
PROGRESSION_START_PATH = ROOT / 'sdk/development/recovery_support_progression_walking_start_contract_v1.json'
POSTURE_START_PATH = ROOT / 'sdk/development/recovery_support_hold_posture_walking_start_contract_v1.json'
ABSENT_POLICY_PATH = ROOT / 'sdk/development/recovery_absent_contact_reference_walking_policy_contract_v1.json'
UPRIGHT_POLICY_PATH = ROOT / 'sdk/development/recovery_upright_stance_walking_policy_contract_v2.json'
STANCE_LATCH_POLICY_PATH = ROOT / 'sdk/development/recovery_stance_latch_walking_policy_contract_v1.json'
PROGRESSION_POLICY_PATH = ROOT / 'sdk/development/recovery_support_progression_walking_policy_contract_v1.json'
POSTURE_POLICY_PATH = ROOT / 'sdk/development/recovery_support_hold_posture_walking_policy_contract_v1.json'
FINITE_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10g_v50_walking_entry_contract_v3.json"
FINITE_ROUTE_START_PATH = ROOT / "sdk/recovery/r10g_v50_walking_start_contract_v3.json"
FINITE_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10g_v50_walking_route_contract_v3.json"
FINITE_ROUTE_ID = "r10g_v50_finite_cycle_walking_route_v1"
FLEXED_ROUTE_ID = "r10i_v50_flexed_entry_route_v1"
FLEXED_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10i_v50_walking_entry_contract_v4.json"
FLEXED_ROUTE_START_PATH = ROOT / "sdk/recovery/r10i_v50_walking_start_contract_v4.json"
FLEXED_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10i_v50_walking_route_contract_v4.json"
R10AP_ROUTE_ID = "r10ap_progressive_headroom_route_v1"
R10AM_ROUTE_ID = "r10am_support_anchored_route_v1"
R10AJ_ROUTE_ID = "r10aj_hip_recenter_route_v1"
R10AI_ROUTE_ID = "r10ai_concurrent_load_rise_route_v1"
R10AG_ROUTE_ID = "r10ag_detection_frame_load_seeking_route_v1"
R10AB_ROUTE_ID = "r10ab_partial_downward_rise_route_v1"
R10AA_ROUTE_ID = "r10aa_partial_load_seeking_route_v1"
R10Z_ROUTE_ID = "r10z_partial_pose_geometry_route_v1"
R10Y_ROUTE_ID = "r10y_partial_direct_neutral_route_v1"
R10V_ROUTE_ID = "r10v_v56_post_recovery_hold_route_v1"
R10U_ROUTE_ID = "r10u_v56_post_recovery_hold_route_v1"
R10T_ROUTE_ID = "r10t_v56_post_recovery_hold_route_v1"
R10S_ROUTE_ID = "r10s_v56_upright_recovery_route_v1"
R10R_ROUTE_ID = "r10r_v55_upright_recovery_route_v1"
R10Q_ROUTE_ID = "r10q_v55_upright_recovery_route_v1"
R10O_ROUTE_ID = "r10o_v55_partial_fall_recovery_route_v1"
R10N_ROUTE_ID = "r10n_v54_partial_fall_recovery_route_v1"
R10M_ROUTE_ID = "r10m_v53_partial_fall_recovery_route_v1"
R10L_ROUTE_ID = "r10l_v52_partial_fall_recovery_route_v1"
R10AF_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10af_v56_walking_entry_contract_v7.json"
R10AF_ROUTE_START_PATH = ROOT / "sdk/recovery/r10af_v56_walking_start_contract_v1.json"
R10AE_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10ae_v56_walking_entry_contract_v11.json"
R10AE_ROUTE_START_PATH = ROOT / "sdk/recovery/r10ae_v56_walking_start_contract_v1.json"
R10AD_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10ad_v56_walking_entry_contract_v5.json"
R10AD_ROUTE_START_PATH = ROOT / "sdk/recovery/r10ad_v56_walking_start_contract_v1.json"
R10AC_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10ac_v56_walking_entry_contract_v28.json"
R10AC_ROUTE_START_PATH = ROOT / "sdk/recovery/r10ac_v56_walking_start_contract_v1.json"
R10AP_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10ap_v56_walking_entry_contract_v9.json"
R10AM_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10am_v56_walking_entry_contract_v11.json"
R10AJ_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10aj_v56_walking_entry_contract_v11.json"
R10AI_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10ai_v56_walking_entry_contract_v14.json"
R10AG_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10ag_v56_walking_entry_contract_v15.json"
R10AB_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10ab_v56_walking_entry_contract_v6.json"
R10AA_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10aa_v56_walking_entry_contract_v8.json"
R10Z_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10z_v56_walking_entry_contract_v10.json"
R10Y_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10y_v56_walking_entry_contract_v22.json"
R10V_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10x_v56_walking_entry_contract_v3.json"
R10U_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10u_v56_walking_entry_contract_v14.json"
R10T_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10t_v56_walking_entry_contract_v25.json"
R10S_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10s_v56_walking_entry_contract_v8.json"
R10R_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10r_v55_walking_entry_contract_v5.json"
R10Q_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10q_v55_walking_entry_contract_v7.json"
R10O_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10o_v55_walking_entry_contract_v2.json"
R10N_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10n_v54_walking_entry_contract_v2.json"
R10M_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10m_v53_walking_entry_contract_v1.json"
R10L_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10l_v52_walking_entry_contract_v6.json"
R10AP_ROUTE_START_PATH = ROOT / "sdk/recovery/r10ap_v56_walking_start_contract_v1.json"
R10AM_ROUTE_START_PATH = ROOT / "sdk/recovery/r10am_v56_walking_start_contract_v1.json"
R10AJ_ROUTE_START_PATH = ROOT / "sdk/recovery/r10aj_v56_walking_start_contract_v1.json"
R10AI_ROUTE_START_PATH = ROOT / "sdk/recovery/r10ai_v56_walking_start_contract_v1.json"
R10AG_ROUTE_START_PATH = ROOT / "sdk/recovery/r10ag_v56_walking_start_contract_v1.json"
R10AB_ROUTE_START_PATH = ROOT / "sdk/recovery/r10ab_v56_walking_start_contract_v1.json"
R10AA_ROUTE_START_PATH = ROOT / "sdk/recovery/r10aa_v56_walking_start_contract_v1.json"
R10Z_ROUTE_START_PATH = ROOT / "sdk/recovery/r10z_v56_walking_start_contract_v1.json"
R10Y_ROUTE_START_PATH = ROOT / "sdk/recovery/r10y_v56_walking_start_contract_v1.json"
R10V_ROUTE_START_PATH = ROOT / "sdk/recovery/r10v_v56_walking_start_contract_v1.json"
R10U_ROUTE_START_PATH = ROOT / "sdk/recovery/r10u_v56_walking_start_contract_v1.json"
R10T_ROUTE_START_PATH = ROOT / "sdk/recovery/r10t_v56_walking_start_contract_v1.json"
R10S_ROUTE_START_PATH = ROOT / "sdk/recovery/r10s_v56_walking_start_contract_v1.json"
R10R_ROUTE_START_PATH = ROOT / "sdk/recovery/r10r_v55_walking_start_contract_v1.json"
R10Q_ROUTE_START_PATH = ROOT / "sdk/recovery/r10q_v55_walking_start_contract_v1.json"
R10O_ROUTE_START_PATH = ROOT / "sdk/recovery/r10o_v55_walking_start_contract_v1.json"
R10N_ROUTE_START_PATH = ROOT / "sdk/recovery/r10n_v54_walking_start_contract_v1.json"
R10M_ROUTE_START_PATH = ROOT / "sdk/recovery/r10m_v53_walking_start_contract_v1.json"
R10L_ROUTE_START_PATH = ROOT / "sdk/recovery/r10l_v52_walking_start_contract_v1.json"
R10AP_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10ap_v56_walking_route_contract_v1.json"
R10AM_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10am_v56_walking_route_contract_v1.json"
R10AJ_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10aj_v56_walking_route_contract_v1.json"
R10AI_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10ai_v56_walking_route_contract_v1.json"
R10AG_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10ag_v56_walking_route_contract_v1.json"
R10AB_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10ab_v56_walking_route_contract_v2.json"
R10AA_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10aa_v56_walking_route_contract_v1.json"
R10Z_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10z_v56_walking_route_contract_v1.json"
R10Y_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10y_v56_walking_route_contract_v1.json"
R10V_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10v_v56_walking_route_contract_v2.json"
R10U_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10u_v56_walking_route_contract_v2.json"
R10T_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10t_v56_walking_route_contract_v1.json"
R10S_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10s_v56_walking_route_contract_v1.json"
R10R_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10r_v55_walking_route_contract_v2.json"
R10Q_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10q_v55_walking_route_contract_v1.json"
R10O_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10o_v55_walking_route_contract_v1.json"
R10N_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10n_v54_walking_route_contract_v1.json"
R10M_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10m_v53_walking_route_contract_v1.json"
R10L_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10l_v52_walking_route_contract_v1.json"
R10K_ROUTE_ID = "r10k_v51_partial_fall_recovery_route_v1"
R10K_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10k_v51_walking_entry_contract_v23.json"
R10K_ROUTE_START_PATH = ROOT / "sdk/recovery/r10k_v51_walking_start_contract_v1.json"
R10K_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10k_v51_walking_route_contract_v1.json"
HOLD_ROUTE_ID = "r10j_v50_settled_hold_route_v1"
HOLD_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10j_v50_walking_entry_contract_v6.json"
HOLD_ROUTE_START_PATH = ROOT / "sdk/recovery/r10j_v50_walking_start_contract_v6.json"
HOLD_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10j_v50_walking_route_contract_v6.json"
STANCE_ROUTE_ID = "r10h_v50_stance_entry_route_v1"
STANCE_ROUTE_ENTRY_PATH = ROOT / "sdk/recovery/r10h_v50_walking_entry_contract_v3.json"
STANCE_ROUTE_START_PATH = ROOT / "sdk/recovery/r10h_v50_walking_start_contract_v3.json"
STANCE_ROUTE_POLICY_PATH = ROOT / "sdk/recovery/r10h_v50_walking_route_contract_v3.json"
STARTUP_VELOCITY_ENTRY_PATH = ROOT / 'sdk/development/recovery_startup_reference_velocity_walking_entry_contract_v1.json'
STARTUP_VELOCITY_START_PATH = ROOT / 'sdk/development/recovery_startup_reference_velocity_walking_start_contract_v1.json'
STARTUP_VELOCITY_POLICY_PATH = ROOT / 'sdk/development/recovery_startup_reference_velocity_walking_policy_contract_v1.json'
REMAINING_ENTRY_PATH = ROOT / 'sdk/development/recovery_remaining_support_release_walking_entry_contract_v1.json'
REMAINING_START_PATH = ROOT / 'sdk/development/recovery_remaining_support_release_walking_start_contract_v1.json'
REMAINING_POLICY_PATH = ROOT / 'sdk/development/recovery_remaining_support_release_walking_policy_contract_v1.json'


def require(ok, code):
    if not ok:
        raise ValueError('DEVELOPMENT_CANDIDATE_' + code)


def read(path):
    return packet.parse_json(path.read_text(encoding='utf-8'))


def sha(path):
    return 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()


def resource_path(resource, prefix='res://sdk/'):
    require(type(resource) is str and resource.startswith(prefix) and '\\' not in resource, 'RESOURCE')
    path = (ROOT / resource.removeprefix('res://')).resolve()
    require(path.is_relative_to(ROOT / 'sdk') and 'res://' + path.relative_to(ROOT).as_posix() == resource,
            'RESOURCE_ESCAPE_OR_ALIAS')
    return path


def contract():
    return read(CONTRACT_PATH)


def schedule_path(schedule_id):
    require(type(schedule_id) is str and re.fullmatch(r'[a-z0-9][a-z0-9-]{0,79}', schedule_id) is not None, 'SCHEDULE_ID')
    path = ROOT / 'sdk/development/recovery_schedules' / (schedule_id + '.json')
    return path if path.is_file() else SCHEDULES_PATH


def walking_entry_phase_family(entry_id):
    """Reuse unchanged start/phase operations without conflating amplitude identities."""
    first_swing = read(FIRST_SWING_ENTRY_PATH)
    limited = read(JOINT_BOUNDED_ENTRY_PATH)
    contact = read(CONTACT_GATED_ENTRY_PATH)
    rotated = read(ROTATED_ENTRY_PATH)
    if entry_id == rotated['profile_id']:
        contact = rotated
    swing_end = read(SWING_END_ENTRY_PATH)
    if entry_id == swing_end['profile_id']:
        contact = swing_end
    support = read(SUPPORT_ENTRY_PATH)
    if entry_id == support['profile_id']:
        contact = support
    floor = read(FLOOR_ENTRY_PATH)
    if entry_id == floor['profile_id']:
        contact = floor
    feasible = read(FEASIBLE_ENTRY_PATH)
    if entry_id == feasible['profile_id']:
        contact = feasible
    smooth = read(SMOOTH_ENTRY_PATH)
    if entry_id == smooth['profile_id']:
        contact = smooth
    reference = read(REFERENCE_ENTRY_PATH)
    if entry_id == reference['profile_id']:
        contact = reference
    wave = read(WAVE_ENTRY_PATH)
    if entry_id == wave['profile_id']:
        contact = wave
    airborne = read(AIRBORNE_ENTRY_PATH)
    if entry_id == airborne['profile_id']:
        contact = airborne
    absent = read(ABSENT_ENTRY_PATH)
    if entry_id == absent['profile_id']:
        contact = absent
    upright = read(UPRIGHT_ENTRY_PATH)
    if entry_id == upright['profile_id']:
        contact = upright
    stance_latch = read(STANCE_LATCH_ENTRY_PATH)
    if entry_id == stance_latch['profile_id']:
        contact = stance_latch
    support_progression = read(PROGRESSION_ENTRY_PATH)
    if entry_id == support_progression['profile_id']:
        contact = support_progression
    support_hold_posture = read(POSTURE_ENTRY_PATH)
    if entry_id == support_hold_posture['profile_id']:
        contact = support_hold_posture
    remaining = read(REMAINING_ENTRY_PATH)
    if entry_id == remaining["profile_id"]:
        contact = remaining
    startup_velocity = read(STARTUP_VELOCITY_ENTRY_PATH)
    if entry_id == startup_velocity["profile_id"]:
        contact = startup_velocity
    finite_route = read(FINITE_ROUTE_ENTRY_PATH)
    if entry_id == finite_route["profile_id"]:
        contact = finite_route
    stance_route = read(STANCE_ROUTE_ENTRY_PATH)
    if entry_id == stance_route["profile_id"]:
        contact = stance_route
    flexed_route = read(FLEXED_ROUTE_ENTRY_PATH)
    if entry_id == flexed_route["profile_id"]:
        contact = flexed_route
    hold_route = read(HOLD_ROUTE_ENTRY_PATH)
    if entry_id == hold_route["profile_id"]:
        contact = hold_route
    r10af_route = read(R10AF_ROUTE_ENTRY_PATH)
    if entry_id == r10af_route["profile_id"]:
        require(r10af_route.get("source_key_complete") is True, "R10AF_SOURCE_KEY_INCOMPLETE")
        contact = r10af_route
    r10ae_route = read(R10AE_ROUTE_ENTRY_PATH)
    if entry_id == r10ae_route["profile_id"]:
        require(r10ae_route.get("source_key_complete") is True, "R10AE_SOURCE_KEY_INCOMPLETE")
        contact = r10ae_route
    r10ad_route = read(R10AD_ROUTE_ENTRY_PATH)
    if entry_id == r10ad_route["profile_id"]:
        require(r10ad_route.get("source_key_complete") is True, "R10AD_SOURCE_KEY_INCOMPLETE")
        contact = r10ad_route
    r10ac_route = read(R10AC_ROUTE_ENTRY_PATH)
    if entry_id == r10ac_route["profile_id"]:
        require(r10ac_route.get("source_key_complete") is True, "R10AC_SOURCE_KEY_INCOMPLETE")
        contact = r10ac_route
    r10ap_route = read(R10AP_ROUTE_ENTRY_PATH)
    r10am_route = read(R10AM_ROUTE_ENTRY_PATH)
    r10aj_route = read(R10AJ_ROUTE_ENTRY_PATH)
    r10ai_route = read(R10AI_ROUTE_ENTRY_PATH)
    r10ag_route = read(R10AG_ROUTE_ENTRY_PATH)
    if entry_id == r10ap_route["profile_id"]:
        require(r10ap_route.get("source_key_complete") is True, "R10AP_SOURCE_KEY_INCOMPLETE")
        contact = r10ap_route
    if entry_id == r10am_route["profile_id"]:
        require(r10am_route.get("source_key_complete") is True, "R10AM_SOURCE_KEY_INCOMPLETE")
        contact = r10am_route
    if entry_id == r10aj_route["profile_id"]:
        require(r10aj_route.get("source_key_complete") is True, "R10AJ_SOURCE_KEY_INCOMPLETE")
        contact = r10aj_route
    if entry_id == r10ai_route["profile_id"]:
        require(r10ai_route.get("source_key_complete") is True, "R10AI_SOURCE_KEY_INCOMPLETE")
        contact = r10ai_route
    if entry_id == r10ag_route["profile_id"]:
        require(r10ag_route.get("source_key_complete") is True, "R10AG_SOURCE_KEY_INCOMPLETE")
        contact = r10ag_route
    r10ab_route = read(R10AB_ROUTE_ENTRY_PATH)
    if entry_id == r10ab_route["profile_id"]:
        require(r10ab_route.get("source_key_complete") is True, "R10AB_SOURCE_KEY_INCOMPLETE")
        contact = r10ab_route
    r10aa_route = read(R10AA_ROUTE_ENTRY_PATH)
    if entry_id == r10aa_route["profile_id"]:
        require(r10aa_route.get("source_key_complete") is True, "R10AA_SOURCE_KEY_INCOMPLETE")
        contact = r10aa_route
    r10z_route = read(R10Z_ROUTE_ENTRY_PATH)
    if entry_id == r10z_route["profile_id"]:
        require(r10z_route.get("source_key_complete") is True, "R10Z_SOURCE_KEY_INCOMPLETE")
        contact = r10z_route
    r10y_route = read(R10Y_ROUTE_ENTRY_PATH)
    if entry_id == r10y_route["profile_id"]:
        require(r10y_route.get("source_key_complete") is True, "R10Y_SOURCE_KEY_INCOMPLETE")
        contact = r10y_route
    r10v_route = read(R10V_ROUTE_ENTRY_PATH)
    if entry_id == r10v_route["profile_id"]:
        require(r10v_route.get("source_key_complete") is True, "R10V_SOURCE_KEY_INCOMPLETE")
        contact = r10v_route
    r10u_route = read(R10U_ROUTE_ENTRY_PATH)
    if entry_id == r10u_route["profile_id"]:
        require(r10u_route.get("source_key_complete") is True, "R10U_SOURCE_KEY_INCOMPLETE")
        contact = r10u_route
    r10t_route = read(R10T_ROUTE_ENTRY_PATH)
    if entry_id == r10t_route["profile_id"]:
        require(r10t_route.get("source_key_complete") is True, "R10T_SOURCE_KEY_INCOMPLETE")
        contact = r10t_route
    r10s_route = read(R10S_ROUTE_ENTRY_PATH)
    if entry_id == r10s_route["profile_id"]:
        contact = r10s_route
    r10r_route = read(R10R_ROUTE_ENTRY_PATH)
    if entry_id == r10r_route["profile_id"]:
        contact = r10r_route
    r10q_route = read(R10Q_ROUTE_ENTRY_PATH)
    if entry_id == r10q_route["profile_id"]:
        contact = r10q_route
    r10o_route = read(R10O_ROUTE_ENTRY_PATH)
    if entry_id == r10o_route["profile_id"]:
        contact = r10o_route
    r10n_route = read(R10N_ROUTE_ENTRY_PATH)
    if entry_id == r10n_route["profile_id"]:
        contact = r10n_route
    r10m_route = read(R10M_ROUTE_ENTRY_PATH)
    if entry_id == r10m_route["profile_id"]:
        contact = r10m_route
    r10l_route = read(R10L_ROUTE_ENTRY_PATH)
    if entry_id == r10l_route["profile_id"]:
        contact = r10l_route
    r10k_route = read(R10K_ROUTE_ENTRY_PATH)
    if entry_id == r10k_route["profile_id"]:
        contact = r10k_route
    first_contact = 361
    if entry_id == contact['profile_id']:
        limited = contact
        first_contact = 1
    if entry_id == limited['profile_id']:
        require(limited['maximum_amplitude'] == 1.1 / (.82 * 1.75 + .4), 'WALKING_ENTRY_AMPLITUDE_BOUND')
        for source in limited['bound_source_files']:
            require(sha(ROOT / source['path']) == source['raw_sha256'], 'WALKING_ENTRY_CONTRACT_DRIFT')
        first_swing = limited
    if entry_id != first_swing['profile_id']:
        return entry_id
    require((first_swing['warmup_steps'], first_swing['first_full_amplitude_local_step'],
             first_swing['first_contact_gated_local_step']) == (72, 73, first_contact), 'WALKING_ENTRY_TIMING')
    for field in ('phase_progression_contract', 'amplitude_and_retention_contract'):
        require(sha(ROOT / first_swing[field]) == first_swing[field + '_sha256'], 'WALKING_ENTRY_CONTRACT_DRIFT')
    require(sha(ROOT / first_swing['normal_launcher_resource'].removeprefix('res://')) == first_swing['normal_launcher_raw_sha256'],
            'WALKING_ENTRY_LAUNCHER_DRIFT')
    return first_swing['phase_progression_entry_profile_id']


def walking_memory_transition_id(schedule):
    """Opt-in prospective schedule only; historical profiles retain strict replay."""
    selected = schedule.get('walking_replay_profile_id', '')
    require(type(selected) is str, 'WALKING_REPLAY_KIND')
    if not selected:
        return ''
    prospective = read(ROOT / 'sdk/development/recovery_prospective_walking_replay_contract_v1.json')
    require(selected == prospective['profile_id']
            and walking_entry_phase_family(schedule.get('walking_entry_profile_id')) == prospective['walking_entry_profile_id'], 'WALKING_REPLAY_SELECTION')
    path = ROOT / prospective['transition_contract']
    require(sha(path) == prospective['transition_contract_sha256'], 'WALKING_REPLAY_CONTRACT_DRIFT')
    transition = read(path)
    require(transition['profile_id'] == prospective['memory_transition_profile_id']
            and sha(ROOT / transition['adapter_resource'].removeprefix('res://')) == transition['adapter_raw_sha256'],
            'WALKING_REPLAY_ADAPTER_DRIFT')
    return transition['profile_id']


def walking_start_contract(selected):
    r10af = read(R10AF_ROUTE_START_PATH)
    if selected == r10af["profile_id"]:
        return r10af
    r10ae = read(R10AE_ROUTE_START_PATH)
    if selected == r10ae["profile_id"]:
        return r10ae
    r10ad = read(R10AD_ROUTE_START_PATH)
    if selected == r10ad["profile_id"]:
        return r10ad
    r10ac = read(R10AC_ROUTE_START_PATH)
    if selected == r10ac["profile_id"]:
        return r10ac
    r10ap_route = read(R10AP_ROUTE_START_PATH)
    r10am_route = read(R10AM_ROUTE_START_PATH)
    r10aj_route = read(R10AJ_ROUTE_START_PATH)
    r10ai_route = read(R10AI_ROUTE_START_PATH)
    r10ag_route = read(R10AG_ROUTE_START_PATH)
    if selected == r10ap_route["profile_id"]:
        return r10ap_route
    if selected == r10am_route["profile_id"]:
        return r10am_route
    if selected == r10aj_route["profile_id"]:
        return r10aj_route
    if selected == r10ai_route["profile_id"]:
        return r10ai_route
    if selected == r10ag_route["profile_id"]:
        return r10ag_route
    r10ab_route = read(R10AB_ROUTE_START_PATH)
    if selected == r10ab_route["profile_id"]:
        return r10ab_route
    r10aa_route = read(R10AA_ROUTE_START_PATH)
    if selected == r10aa_route["profile_id"]:
        return r10aa_route
    r10z_route = read(R10Z_ROUTE_START_PATH)
    if selected == r10z_route["profile_id"]:
        return r10z_route
    r10y_route = read(R10Y_ROUTE_START_PATH)
    if selected == r10y_route["profile_id"]:
        return r10y_route
    r10v_route = read(R10V_ROUTE_START_PATH)
    if selected == r10v_route["profile_id"]:
        return r10v_route
    r10u_route = read(R10U_ROUTE_START_PATH)
    if selected == r10u_route["profile_id"]:
        return r10u_route
    r10t_route = read(R10T_ROUTE_START_PATH)
    if selected == r10t_route["profile_id"]:
        return r10t_route
    r10s_route = read(R10S_ROUTE_START_PATH)
    if selected == r10s_route["profile_id"]:
        return r10s_route
    r10r_route = read(R10R_ROUTE_START_PATH)
    if selected == r10r_route["profile_id"]:
        return r10r_route
    r10q_route = read(R10Q_ROUTE_START_PATH)
    if selected == r10q_route["profile_id"]:
        return r10q_route
    r10o_route = read(R10O_ROUTE_START_PATH)
    if selected == r10o_route["profile_id"]:
        return r10o_route
    r10n_route = read(R10N_ROUTE_START_PATH)
    if selected == r10n_route["profile_id"]:
        return r10n_route
    r10m_route = read(R10M_ROUTE_START_PATH)
    if selected == r10m_route["profile_id"]:
        return r10m_route
    r10l_route = read(R10L_ROUTE_START_PATH)
    if selected == r10l_route["profile_id"]:
        return r10l_route
    r10k_route = read(R10K_ROUTE_START_PATH)
    if selected == r10k_route["profile_id"]:
        return r10k_route
    hold_route = read(HOLD_ROUTE_START_PATH)
    if selected == hold_route["profile_id"]:
        return hold_route
    flexed_route = read(FLEXED_ROUTE_START_PATH)
    if selected == flexed_route["profile_id"]:
        return flexed_route
    stance_route = read(STANCE_ROUTE_START_PATH)
    if selected == stance_route["profile_id"]:
        return stance_route
    finite_route = read(FINITE_ROUTE_START_PATH)
    if selected == finite_route["profile_id"]:
        return finite_route
    remaining = read(REMAINING_START_PATH)
    if selected == remaining["profile_id"]:
        return remaining
    startup_velocity = read(STARTUP_VELOCITY_START_PATH)
    if selected == startup_velocity["profile_id"]:
        return startup_velocity
    absent = read(ABSENT_START_PATH)
    if selected == absent['profile_id']:
        return absent
    upright = read(UPRIGHT_START_PATH)
    if selected == upright['profile_id']:
        return upright
    stance_latch = read(STANCE_LATCH_START_PATH)
    if selected == stance_latch['profile_id']:
        return stance_latch
    support_progression = read(PROGRESSION_START_PATH)
    if selected == support_progression['profile_id']:
        return support_progression
    support_hold_posture = read(POSTURE_START_PATH)
    if selected == support_hold_posture['profile_id']:
        return support_hold_posture
    airborne = read(AIRBORNE_START_PATH)
    if selected == airborne['profile_id']:
        return airborne
    wave = read(WAVE_START_PATH)
    if selected == wave['profile_id']:
        return wave
    reference = read(REFERENCE_START_PATH)
    if selected == reference['profile_id']:
        return reference
    smooth = read(SMOOTH_START_PATH)
    if selected == smooth['profile_id']:
        return smooth
    feasible = read(FEASIBLE_START_PATH)
    if selected == feasible['profile_id']:
        return feasible
    floor = read(FLOOR_START_PATH)
    if selected == floor['profile_id']:
        return floor
    support = read(SUPPORT_START_PATH)
    if selected == support['profile_id']:
        return support
    swing_end = read(SWING_END_START_PATH)
    if selected == swing_end['profile_id']:
        return swing_end
    rotated = read(ROTATED_START_PATH)
    if selected == rotated['profile_id']:
        return rotated
    contact = read(CONTACT_GATED_START_PATH)
    return contact if selected == contact['profile_id'] else read(ROOT / 'sdk/development/recovery_walking_start_contract_v1.json')


def walking_start_id(schedule):
    selected = schedule.get('walking_start_profile_id', '')
    require(type(selected) is str, 'WALKING_START_KIND')
    r10ap = read(R10AP_ROUTE_ENTRY_PATH)
    r10am = read(R10AM_ROUTE_ENTRY_PATH)
    r10aj = read(R10AJ_ROUTE_ENTRY_PATH)
    r10ai = read(R10AI_ROUTE_ENTRY_PATH)
    r10ag = read(R10AG_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10ap['profile_id']:
        require(selected == r10ap['required_start_profile_id'], 'WALKING_START_SELECTION')
    if schedule.get('walking_entry_profile_id') == r10am['profile_id']:
        require(selected == r10am['required_start_profile_id'], 'WALKING_START_SELECTION')
    if schedule.get('walking_entry_profile_id') == r10aj['profile_id']:
        require(selected == r10aj['required_start_profile_id'], 'WALKING_START_SELECTION')
    if schedule.get('walking_entry_profile_id') == r10ai['profile_id']:
        require(selected == r10ai['required_start_profile_id'], 'WALKING_START_SELECTION')
    if schedule.get('walking_entry_profile_id') == r10ag['profile_id']:
        require(selected == r10ag['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10ab = read(R10AB_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10ab['profile_id']:
        require(selected == r10ab['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10aa = read(R10AA_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10aa['profile_id']:
        require(selected == r10aa['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10z = read(R10Z_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10z['profile_id']:
        require(selected == r10z['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10y = read(R10Y_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10y['profile_id']:
        require(selected == r10y['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10v = read(R10V_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10v['profile_id']:
        require(selected == r10v['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10u = read(R10U_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10u['profile_id']:
        require(selected == r10u['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10t = read(R10T_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10t['profile_id']:
        require(selected == r10t['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10s = read(R10S_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10s['profile_id']:
        require(selected == r10s['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10r = read(R10R_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10r['profile_id']:
        require(selected == r10r['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10q = read(R10Q_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10q['profile_id']:
        require(selected == r10q['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10o = read(R10O_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10o['profile_id']:
        require(selected == r10o['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10n = read(R10N_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10n['profile_id']:
        require(selected == r10n['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10m = read(R10M_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10m['profile_id']:
        require(selected == r10m['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10l = read(R10L_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10l['profile_id']:
        require(selected == r10l['required_start_profile_id'], 'WALKING_START_SELECTION')
    r10k = read(R10K_ROUTE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == r10k['profile_id']:
        require(selected == r10k['required_start_profile_id'], 'WALKING_START_SELECTION')
    remaining = read(REMAINING_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == remaining['profile_id']:
        require(selected == remaining['required_start_profile_id'], 'WALKING_START_SELECTION')
    startup_velocity = read(STARTUP_VELOCITY_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == startup_velocity['profile_id']:
        require(selected == startup_velocity['required_start_profile_id'], 'WALKING_START_SELECTION')
    airborne = read(AIRBORNE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == airborne['profile_id']:
        require(selected == airborne['required_start_profile_id'], 'WALKING_START_SELECTION')
    absent = read(ABSENT_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == absent['profile_id']:
        require(selected == absent['required_start_profile_id'], 'WALKING_START_SELECTION')
    upright = read(UPRIGHT_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == upright['profile_id']:
        require(selected == upright['required_start_profile_id'], 'WALKING_START_SELECTION')
    stance_latch = read(STANCE_LATCH_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == stance_latch['profile_id']:
        require(selected == stance_latch['required_start_profile_id'], 'WALKING_START_SELECTION')
    support_progression = read(PROGRESSION_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == support_progression['profile_id']:
        require(selected == support_progression['required_start_profile_id'], 'WALKING_START_SELECTION')
    support_hold_posture = read(POSTURE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == support_hold_posture['profile_id']:
        require(selected == support_hold_posture['required_start_profile_id'], 'WALKING_START_SELECTION')
    wave = read(WAVE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == wave['profile_id']:
        require(selected == wave['required_start_profile_id'], 'WALKING_START_SELECTION')
    reference = read(REFERENCE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == reference['profile_id']:
        require(selected == reference['required_start_profile_id'], 'WALKING_START_SELECTION')
    smooth = read(SMOOTH_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == smooth['profile_id']:
        require(selected == smooth['required_start_profile_id'], 'WALKING_START_SELECTION')
    feasible = read(FEASIBLE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == feasible['profile_id']:
        require(selected == feasible['required_start_profile_id'], 'WALKING_START_SELECTION')
    floor = read(FLOOR_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == floor['profile_id']:
        require(selected == floor['required_start_profile_id'], 'WALKING_START_SELECTION')
    rotated = read(ROTATED_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == rotated['profile_id']:
        require(selected == rotated['required_start_profile_id'], 'WALKING_START_SELECTION')
    swing_end = read(SWING_END_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == swing_end['profile_id']:
        require(selected == swing_end['required_start_profile_id'], 'WALKING_START_SELECTION')
    support = read(SUPPORT_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == support['profile_id']:
        require(selected == support['required_start_profile_id'], 'WALKING_START_SELECTION')
    if selected:
        fixed = walking_start_contract(selected)
        require(selected == fixed['profile_id'] and walking_entry_phase_family(schedule.get('walking_entry_profile_id')) == fixed['walking_entry_profile_id'],
                'WALKING_START_SELECTION')
        if 'exact_entry_profile_id' in fixed:
            require(schedule.get('walking_entry_profile_id') == fixed['exact_entry_profile_id'], 'WALKING_START_SELECTION')
        if 'initial_gait_step_offset' in fixed:
            require(fixed['initial_gait_step_offset'] == 90 and fixed['first_swing_limb_id'] == 'front_left', 'WALKING_START_OFFSET')
        require(sha(ROOT / fixed['normal_launcher_resource'].removeprefix('res://')) == fixed['normal_launcher_raw_sha256'],
                'WALKING_START_LAUNCHER_DRIFT')
        if 'parent_start_contract' in fixed:
            require(sha(ROOT / fixed['parent_start_contract']) == fixed['parent_start_contract_sha256'], 'WALKING_START_PARENT_DRIFT')
    return selected


def walking_policy_id(schedule):
    if schedule.get('walking_entry_profile_id') == 'r10af_v56_joint_bounded_contact_gated_v1':
        import r10af_selection
        return walking_policy_id(r10af_selection.native_schedule(schedule))
    if schedule.get('walking_entry_profile_id') == 'r10ae_v56_joint_bounded_contact_gated_v1':
        import r10ae_selection
        return walking_policy_id(r10ae_selection.native_schedule(schedule))
    if schedule.get('walking_entry_profile_id') == 'r10ad_v56_joint_bounded_contact_gated_v1':
        import r10ad_selection
        return walking_policy_id(r10ad_selection.native_schedule(schedule))
    if schedule.get('walking_entry_profile_id') == 'r10ac_v56_joint_bounded_contact_gated_v1':
        import r10ac_selection
        return walking_policy_id(r10ac_selection.native_schedule(schedule))
    selected = schedule.get('walking_policy_id', '')
    route_path = R10AP_ROUTE_POLICY_PATH if selected == R10AP_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10ap_v56_joint_bounded_contact_gated_v1" else R10AM_ROUTE_POLICY_PATH if selected == R10AM_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10am_v56_joint_bounded_contact_gated_v1" else R10AJ_ROUTE_POLICY_PATH if selected == R10AJ_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10aj_v56_joint_bounded_contact_gated_v1" else R10AI_ROUTE_POLICY_PATH if selected == R10AI_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10ai_v56_joint_bounded_contact_gated_v1" else R10AG_ROUTE_POLICY_PATH if selected == R10AG_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10ag_v56_joint_bounded_contact_gated_v1" else R10AB_ROUTE_POLICY_PATH if selected == R10AB_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10ab_v56_joint_bounded_contact_gated_v1" else R10AA_ROUTE_POLICY_PATH if selected == R10AA_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10aa_v56_joint_bounded_contact_gated_v1" else R10Z_ROUTE_POLICY_PATH if selected == R10Z_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10z_v56_joint_bounded_contact_gated_v1" else R10Y_ROUTE_POLICY_PATH if selected == R10Y_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10y_v56_joint_bounded_contact_gated_v1" else R10V_ROUTE_POLICY_PATH if selected == R10V_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10v_v56_joint_bounded_contact_gated_v1" else R10U_ROUTE_POLICY_PATH if selected == R10U_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10u_v56_joint_bounded_contact_gated_v1" else R10T_ROUTE_POLICY_PATH if selected == R10T_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10t_v56_joint_bounded_contact_gated_v1" else R10S_ROUTE_POLICY_PATH if selected == R10S_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10s_v56_joint_bounded_contact_gated_v1" else R10R_ROUTE_POLICY_PATH if selected == R10R_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10r_v55_joint_bounded_contact_gated_v1" else R10Q_ROUTE_POLICY_PATH if selected == R10Q_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10q_v55_joint_bounded_contact_gated_v1" else R10O_ROUTE_POLICY_PATH if selected == R10O_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10o_v55_joint_bounded_contact_gated_v1" else R10N_ROUTE_POLICY_PATH if selected == R10N_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10n_v54_joint_bounded_contact_gated_v1" else R10M_ROUTE_POLICY_PATH if selected == R10M_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10m_v53_joint_bounded_contact_gated_v1" else R10L_ROUTE_POLICY_PATH if selected == R10L_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10l_v52_joint_bounded_contact_gated_v1" else R10K_ROUTE_POLICY_PATH if selected == R10K_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10k_v51_joint_bounded_contact_gated_v1" else HOLD_ROUTE_POLICY_PATH if selected == HOLD_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10j_v50_joint_bounded_contact_gated_v1" else FLEXED_ROUTE_POLICY_PATH if selected == FLEXED_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10i_v50_joint_bounded_contact_gated_v1" else STANCE_ROUTE_POLICY_PATH if selected == STANCE_ROUTE_ID or schedule.get("walking_entry_profile_id") == "r10h_v50_joint_bounded_contact_gated_v1" else FINITE_ROUTE_POLICY_PATH
    route = read(route_path)
    if selected in (FINITE_ROUTE_ID, STANCE_ROUTE_ID, FLEXED_ROUTE_ID, HOLD_ROUTE_ID, R10K_ROUTE_ID, R10L_ROUTE_ID, R10M_ROUTE_ID, R10N_ROUTE_ID, R10O_ROUTE_ID, R10Q_ROUTE_ID, R10R_ROUTE_ID, R10S_ROUTE_ID, R10T_ROUTE_ID, R10U_ROUTE_ID, R10V_ROUTE_ID, R10Y_ROUTE_ID, R10Z_ROUTE_ID, R10AA_ROUTE_ID, R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID, R10AB_ROUTE_ID) or schedule.get('walking_entry_profile_id') == route['entry_profile_id']:
        require(selected == route["selection_id"] and schedule.get('walking_entry_profile_id') == route['entry_profile_id']
                and schedule.get('walking_start_profile_id') == route['start_profile_id']
                and schedule.get('runtime_sha256') == route['runtime_sha256']
                and schedule.get('walking_policy_contract_sha256') == sha(route_path)
                and not schedule.get('walking_replay_profile_id'), 'FINITE_ROUTE_SELECTION')
        for field in ('native_component_record', 'runtime_binding', 'task_contract'):
            require(sha(ROOT / route[field]) == route[field + '_sha256'], 'FINITE_ROUTE_SOURCE_DRIFT')
        if selected in (R10O_ROUTE_ID, R10Q_ROUTE_ID, R10R_ROUTE_ID, R10S_ROUTE_ID, R10T_ROUTE_ID, R10U_ROUTE_ID, R10V_ROUTE_ID, R10Y_ROUTE_ID, R10Z_ROUTE_ID, R10AA_ROUTE_ID, R10AP_ROUTE_ID, R10AM_ROUTE_ID, R10AJ_ROUTE_ID, R10AI_ROUTE_ID, R10AG_ROUTE_ID, R10AB_ROUTE_ID):
            composition = read(ROOT / route['task_contract'])['controller_composition']
            require(composition['native_runtime_sha256'] == route['runtime_sha256']
                    and composition['post_interaction_walking'] == route['policy_id'], 'R10O_TASK_NATIVE_IDENTITY')
        if selected == R10N_ROUTE_ID:
            composition = read(ROOT / route['task_contract'])['controller_composition']
            require(composition['native_runtime_sha256'] == route['runtime_sha256']
                    and composition['post_interaction_walking'] == route['policy_id'], 'R10N_TASK_NATIVE_IDENTITY')
        if selected == R10M_ROUTE_ID:
            composition = read(ROOT / route['task_contract'])['controller_composition']
            require(composition['native_runtime_sha256'] == route['runtime_sha256']
                    and composition['post_interaction_walking'] == route['policy_id'], 'R10M_TASK_NATIVE_IDENTITY')
        require(route['physical_acceptance_authority'] is False and route['release_authority'] is False, 'FINITE_ROUTE_AUTHORITY')
        return selected
    require(type(selected) is str, 'WALKING_POLICY_KIND')
    entry = read(SWING_END_ENTRY_PATH)
    policy_path = WALKING_POLICY_PATH
    support_entry = read(SUPPORT_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == support_entry['profile_id']:
        entry = support_entry
        policy_path = SUPPORT_POLICY_PATH
    floor_entry = read(FLOOR_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == floor_entry['profile_id']:
        entry = floor_entry
        policy_path = FLOOR_POLICY_PATH
    feasible_entry = read(FEASIBLE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == feasible_entry['profile_id']:
        entry = feasible_entry
        policy_path = FEASIBLE_POLICY_PATH
    smooth_entry = read(SMOOTH_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == smooth_entry['profile_id']:
        entry = smooth_entry
        policy_path = SMOOTH_POLICY_PATH
    reference_entry = read(REFERENCE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == reference_entry['profile_id']:
        entry = reference_entry
        policy_path = REFERENCE_POLICY_PATH
    wave_entry = read(WAVE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == wave_entry['profile_id']:
        entry = wave_entry
        policy_path = WAVE_POLICY_PATH
    airborne_entry = read(AIRBORNE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == airborne_entry['profile_id']:
        entry = airborne_entry
        policy_path = AIRBORNE_POLICY_PATH
    absent_entry = read(ABSENT_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == absent_entry['profile_id']:
        entry = absent_entry
        policy_path = ABSENT_POLICY_PATH
    upright_entry = read(UPRIGHT_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == upright_entry['profile_id']:
        entry = upright_entry
        policy_path = UPRIGHT_POLICY_PATH
    stance_latch_entry = read(STANCE_LATCH_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == stance_latch_entry['profile_id']:
        entry = stance_latch_entry
        policy_path = STANCE_LATCH_POLICY_PATH
    support_progression_entry = read(PROGRESSION_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == support_progression_entry['profile_id']:
        entry = support_progression_entry
        policy_path = PROGRESSION_POLICY_PATH
    support_hold_posture_entry = read(POSTURE_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == support_hold_posture_entry['profile_id']:
        entry = support_hold_posture_entry
        policy_path = POSTURE_POLICY_PATH
    remaining = read(REMAINING_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == remaining['profile_id']:
        entry = remaining
        policy_path = REMAINING_POLICY_PATH
    startup_velocity = read(STARTUP_VELOCITY_ENTRY_PATH)
    if schedule.get('walking_entry_profile_id') == startup_velocity['profile_id']:
        entry = startup_velocity
        policy_path = STARTUP_VELOCITY_POLICY_PATH
    if schedule.get('walking_entry_profile_id') == entry['profile_id']:
        require(selected == entry['required_walking_policy_id'], 'WALKING_POLICY_SELECTION')
    if not selected:
        return ''
    fixed = read(policy_path)
    require(selected == fixed['policy_id'] and schedule.get('walking_entry_profile_id') == entry['profile_id']
            and schedule.get('walking_start_profile_id') == entry['required_start_profile_id']
            and schedule.get('runtime_sha256') == fixed['runtime_sha256']
            and schedule.get('walking_policy_contract_sha256') == sha(policy_path)
            and not schedule.get('walking_replay_profile_id'), 'WALKING_POLICY_SELECTION')
    for field in ('native_component_record', 'runtime_binding'):
        require(sha(ROOT / fixed[field]) == fixed[field + '_sha256'], 'WALKING_POLICY_SOURCE_DRIFT')
    return selected


def selection(reference):
    """Bind exact profile, manifest, extension and DLL identity before selection."""
    require(type(reference) is dict and set(reference) == {'resource', 'raw_sha256'}, 'REFERENCE')
    path = resource_path(reference['resource'], 'res://sdk/development/recovery_candidates/')
    require(path.suffix == '.json' and sha(path) == reference['raw_sha256'], 'PROFILE_DRIFT')
    value = read(path)
    fixed = contract()
    schedules = read(SCHEDULES_PATH)
    scheduled = type(value) is dict and value.get('schema_version') == schedules['profile_schema']
    keys = fixed['profile_keys'] + (schedules['extra_profile_keys'] if scheduled else [])
    require(type(value) is dict and set(value) == set(keys), 'PROFILE_KEYS')
    require(all(type(item) is str and item for item in value.values()), 'PROFILE_KINDS')
    require(scheduled or value['schema_version'] == fixed['profile_schema'], 'PROFILE_SCHEMA')
    require(re.fullmatch(r'[a-z0-9][a-z0-9-]{0,79}', value['candidate_id']) is not None, 'CANDIDATE_ID')
    require(re.fullmatch(r'sporespore_exact_s169_prone_to_standing_controller_v(?:[7-9]|[1-9][0-9]+)',
                        value['post_kick_controller_id']) is not None, 'CONTROLLER_ID')
    for key in ('runtime_binding', 'extension'):
        require(sha(resource_path(value[key])) == value[key + '_sha256'], key.upper() + '_DRIFT')
    binding = read(resource_path(value['runtime_binding']))
    require(binding['runtime']['raw_sha256'] == value['runtime_sha256'], 'DLL_IDENTITY')
    for image in (ROOT / binding['local_build_path'], Path(binding['runtime']['path'])):
        require(sha(image) == value['runtime_sha256'], 'DLL_DRIFT')
    result = dict(fixed)
    result.update(candidate_profile=dict(reference), candidate=value,
                  post_kick_controller_id=value['post_kick_controller_id'])
    result['worker_selection'] = dict(fixed['worker_selection'], binding=value['runtime_binding'], extension=value['extension'])
    if scheduled:
        path = schedule_path(value['diagnostic_schedule_id'])
        require(value['diagnostic_schedule_sha256'] == sha(path), 'SCHEDULE_DRIFT')
        schedules = read(path)
        schedule = schedules['schedules'].get(value['diagnostic_schedule_id'])
        require(type(schedule) is dict, 'SCHEDULE_ID')
        require(schedule['controller_id'] == value['post_kick_controller_id']
                and schedule['runtime_sha256'] == value['runtime_sha256'], 'SCHEDULE_CONTROLLER_OR_DLL')
        require(schedule['physical_acceptance_authority'] is False and schedule['release_authority'] is False,
                'SCHEDULE_AUTHORITY')
        bounds = schedule['limits']
        require(set(bounds) == set(DEFAULT_LIMITS) and all(type(v) is int for v in bounds.values()), 'SCHEDULE_LIMIT_KINDS')
        require(all(bounds[k] == v for k, v in DEFAULT_LIMITS.items()
                    if k not in ('after_interaction_steps', 'maximum_steps_per_child'))
                and 480 < bounds['after_interaction_steps'] <= 4096
                and bounds['maximum_steps_per_child'] == 352 + bounds['after_interaction_steps'], 'SCHEDULE_LIMITS')
        frame = schedule.get('walking_resume_frame_id', '')
        frame_contract = read(ROOT / 'sdk/development/recovery_walking_frame_contract_v1.json')
        require(type(frame) is str and frame in ('', frame_contract['resume_frame_id']), 'WALKING_FRAME_SELECTION')
        entry_id = schedule.get('walking_entry_profile_id', '')
        entry_contract = read(ROOT / 'sdk/development/recovery_walking_entry_contract_v1.json')
        clocked_entry = read(ROOT / 'sdk/development/recovery_clocked_walking_entry_contract_v1.json')
        first_swing_entry = read(FIRST_SWING_ENTRY_PATH)
        limited_entry = read(JOINT_BOUNDED_ENTRY_PATH)
        contact_entry = read(CONTACT_GATED_ENTRY_PATH)
        rotated_entry = read(ROTATED_ENTRY_PATH)
        swing_end_entry = read(SWING_END_ENTRY_PATH)
        support_entry = read(SUPPORT_ENTRY_PATH)
        floor_entry = read(FLOOR_ENTRY_PATH)
        feasible_entry = read(FEASIBLE_ENTRY_PATH)
        smooth_entry = read(SMOOTH_ENTRY_PATH)
        reference_entry = read(REFERENCE_ENTRY_PATH)
        wave_entry = read(WAVE_ENTRY_PATH)
        airborne_entry = read(AIRBORNE_ENTRY_PATH)
        absent_entry = read(ABSENT_ENTRY_PATH)
        upright_entry = read(UPRIGHT_ENTRY_PATH)
        stance_latch_entry = read(STANCE_LATCH_ENTRY_PATH)
        support_progression_entry = read(PROGRESSION_ENTRY_PATH)
        support_hold_posture_entry = read(POSTURE_ENTRY_PATH)
        startup_velocity_entry = read(STARTUP_VELOCITY_ENTRY_PATH)
        remaining_entry = read(REMAINING_ENTRY_PATH)
        require(type(entry_id) is str and entry_id in ('', entry_contract['profile_id'], clocked_entry['profile_id'], first_swing_entry['profile_id'], limited_entry['profile_id'], contact_entry['profile_id'], rotated_entry['profile_id'], swing_end_entry['profile_id'], support_entry['profile_id'], floor_entry['profile_id'], feasible_entry['profile_id'], smooth_entry['profile_id'], reference_entry['profile_id'], wave_entry['profile_id'], airborne_entry['profile_id'], absent_entry['profile_id'], upright_entry['profile_id'], stance_latch_entry['profile_id'], support_progression_entry['profile_id'], support_hold_posture_entry['profile_id'], remaining_entry['profile_id'], startup_velocity_entry['profile_id'], read(FINITE_ROUTE_ENTRY_PATH)['profile_id'], read(STANCE_ROUTE_ENTRY_PATH)['profile_id'], read(FLEXED_ROUTE_ENTRY_PATH)['profile_id'], read(HOLD_ROUTE_ENTRY_PATH)['profile_id'], read(R10K_ROUTE_ENTRY_PATH)['profile_id'], read(R10L_ROUTE_ENTRY_PATH)['profile_id'], read(R10M_ROUTE_ENTRY_PATH)['profile_id'], read(R10N_ROUTE_ENTRY_PATH)['profile_id'], read(R10O_ROUTE_ENTRY_PATH)['profile_id'], read(R10Q_ROUTE_ENTRY_PATH)['profile_id'], read(R10R_ROUTE_ENTRY_PATH)['profile_id'], read(R10S_ROUTE_ENTRY_PATH)['profile_id'], read(R10T_ROUTE_ENTRY_PATH)['profile_id'], read(R10U_ROUTE_ENTRY_PATH)['profile_id'], read(R10V_ROUTE_ENTRY_PATH)['profile_id'], read(R10Y_ROUTE_ENTRY_PATH)['profile_id'], read(R10Z_ROUTE_ENTRY_PATH)['profile_id'], read(R10AA_ROUTE_ENTRY_PATH)['profile_id'], read(R10AB_ROUTE_ENTRY_PATH)['profile_id'], read(R10AC_ROUTE_ENTRY_PATH)['profile_id'], read(R10AD_ROUTE_ENTRY_PATH)['profile_id'], read(R10AE_ROUTE_ENTRY_PATH)['profile_id'], read(R10AF_ROUTE_ENTRY_PATH)['profile_id'], read(R10AP_ROUTE_ENTRY_PATH)['profile_id'], read(R10AM_ROUTE_ENTRY_PATH)['profile_id'], read(R10AJ_ROUTE_ENTRY_PATH)['profile_id'], read(R10AI_ROUTE_ENTRY_PATH)['profile_id'], read(R10AG_ROUTE_ENTRY_PATH)['profile_id']), 'WALKING_ENTRY_SELECTION')
        walking_entry_phase_family(entry_id)
        contact_id = schedule.get('walking_contact_profile_id', '')
        contact_contract = read(ROOT / 'sdk/development/recovery_walking_contact_contract_v1.json')
        native_contact_contract = read(ROOT / 'sdk/development/recovery_native_walking_contact_contract_v1.json')
        require(type(contact_id) is str and contact_id in ('', contact_contract['profile_id'], native_contact_contract['profile_id'])
                and (not contact_id or bool(entry_id)), 'WALKING_CONTACT_SELECTION')
        walking_memory_transition_id(schedule)
        walking_start_id(schedule)
        walking_policy_id(schedule)
        result['diagnostic_schedule'] = schedule
        if schedule.get('walking_policy_id') == R10AP_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10ap_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10ap_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10ap_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10ap_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10ap_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10ap_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10AM_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10am_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10am_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10am_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10am_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10am_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10am_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10AJ_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10aj_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10aj_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10aj_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10aj_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10aj_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10aj_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10AI_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10ai_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10ai_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10ai_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10ai_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10ai_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10ai_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10AG_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10ag_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10ag_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10ag_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10ag_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10ag_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10ag_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10AB_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10ab_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10ab_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10ab_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10ab_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10ab_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10ab_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10AA_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10aa_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10aa_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10aa_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10aa_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10aa_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10aa_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10Z_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10z_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10z_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10z_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10z_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10z_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10z_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10Y_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10y_development_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10y_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10y_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10y_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10y_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10y_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10V_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10v_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10v_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10v_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10v_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10v_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10U_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10u_recovery_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10u_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10u_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10u_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10u_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10u_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10T_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10t_recovery_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10t_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10t_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10t_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10t_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10t_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10S_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10s_recovery_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10s_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10s_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10s_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10s_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10s_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10R_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10r_recovery_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10r_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10r_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10r_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10r_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10r_recovery_replay_receipt_v1'
        if schedule.get('walking_policy_id') == R10Q_ROUTE_ID:
            result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10q_recovery_worker_v1.gd'
            result['reader'] = 'res://sdk/trace_analysis/r10q_recovery_replay.gd'
            result['input_schema'] = 'sporespore_r10q_recovery_replay_input_v1'
            result['report_input_schema'] = 'sporespore_r10q_recovery_report_replay_input_v1'
            result['retention_schema'] = 'sporespore_r10q_recovery_entry_retention_v1'
            result['replay_receipt_schema'] = 'sporespore_r10q_recovery_replay_receipt_v1'
    if value['candidate_id'] == 'r10ap-progressive-headroom-v1':
        import r10ap_development
        require(reference == r10ap_development.reference(), 'R10AP_PROFILE')
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10am-support-anchored-v1':
        import r10am_development
        require(reference == r10am_development.reference(), 'R10AM_PROFILE')
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10aj-hip-recenter-v1':
        import r10aj_development
        require(reference == r10aj_development.reference(), 'R10AJ_PROFILE')
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10ai-concurrent-load-rise-v1':
        import r10ai_development
        require(reference == r10ai_development.reference(), 'R10AI_PROFILE')
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10ag-detection-frame-load-seeking-v1':
        import r10ag_development
        require(reference == r10ag_development.reference(), 'R10AG_PROFILE')
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10af-detection-frame-recovery-v1':
        import r10af_selection
        require(reference == r10af_selection.identity.reference(), 'R10AF_PROFILE')
        r10af_selection.native_schedule(result['diagnostic_schedule'])
        result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10af_development_worker_v1.gd'
        result['reader'] = 'res://sdk/trace_analysis/r10af_recovery_replay.gd'
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10ae-contact-frame-diagnostic-v1':
        import r10ae_selection
        require(reference == r10ae_selection.identity.reference(), 'R10AE_PROFILE')
        r10ae_selection.native_schedule(result['diagnostic_schedule'])
        result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10ae_development_worker_v1.gd'
        result['reader'] = 'res://sdk/trace_analysis/r10ae_recovery_replay.gd'
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10ad-contact-frame-diagnostic-v1':
        import r10ad_selection
        require(reference == r10ad_selection.identity.reference(), 'R10AD_PROFILE')
        r10ad_selection.native_schedule(result['diagnostic_schedule'])
        result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10ad_development_worker_v1.gd'
        result['reader'] = 'res://sdk/trace_analysis/r10ad_recovery_replay.gd'
        result['diagnostic_reader_requires_declaration'] = True
    if value['candidate_id'] == 'r10ac-contact-frame-diagnostic-v2':
        import r10ac_selection
        require(reference == r10ac_selection.identity.reference(), 'R10AC_PROFILE')
        r10ac_selection.native_schedule(result['diagnostic_schedule'])
        result['worker_selection']['worker'] = 'res://sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd'
        result['reader'] = 'res://sdk/trace_analysis/r10ac_recovery_replay.gd'
        result['diagnostic_reader_requires_declaration'] = True
    return result


def limits(chosen):
    return dict(chosen.get('diagnostic_schedule', {}).get('limits', DEFAULT_LIMITS))


def reference_for_path(path):
    path = path.resolve()
    require(path.is_relative_to(ROOT / 'sdk/development/recovery_candidates'), 'PROFILE_PATH')
    return dict(resource='res://' + path.relative_to(ROOT).as_posix(), raw_sha256=sha(path))


def declared_roles(declaration):
    """Single-child diagnostics cannot masquerade as paired or causal evidence."""
    fixed = contract()
    mode = declaration.get('development_execution_mode')
    require(mode in (fixed['single_mode'], fixed['paired_mode']), 'EXECUTION_MODE')
    require(declaration.get('comparative_authority') is False and declaration.get('baseline_reused') is False,
            'COMPARISON_OR_BASELINE_REUSE')
    roles = ([fixed['single_role']] if mode == fixed['single_mode'] else
             ['matched_no_kick_continuation', fixed['single_role']])
    require([child.get('role') for child in declaration.get('children', [])] == roles, 'ROLE_POPULATION')
    return roles


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('profile', type=Path)
    args = parser.parse_args()
    print(json.dumps(selection(reference_for_path(args.profile)), separators=(',', ':'), allow_nan=False))
