"""Independent read-only diagnostic reader. No accepted behavior or route claim."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_l15_collection_context as context
import qsdk_r10f_l15_launch_relationship as launch
import qsdk_r10f_physical_closure as legacy
import development_step_cost_profile as step_profile
import development_passive_entry_profile as entry_profile

MARKER = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '
ROLES = ('matched_no_kick_continuation', 'kick_passive_recovery_resume')
SCHEMA = 'sporespore_sdk1_development_recovery_smoke_child_v1'
WORK = 'SDK1-GODOT-RECOVERY-DEVELOPMENT-SMOKE-V1'
PRONE_DEADLINE_SCHEDULE = 'existing_prone_confirmation_deadline_v1'


def require(ok, code):
    if not ok:
        raise ValueError('DEVELOPMENT_SMOKE_' + code)


def read(path):
    return packet.parse_json(path.read_text(encoding='utf-8'))


def sha(path):
    return 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()


def integer(value, low=0, high=2**63-1):
    return type(value) is int and low <= value <= high


def declared_schedule(declaration):
    """Two finite diagnostic cutoffs; never a controller timeout override."""
    if entry_profile.selected(declaration):
        return entry_profile.validate_declaration(declaration)
    after = 30
    if 'diagnostic_schedule_id' in declaration:
        require(declaration['diagnostic_schedule_id'] == PRONE_DEADLINE_SCHEDULE, 'SCHEDULE_ID')
        require(step_profile.declared_context_cache(declaration), 'SCHEDULE_REQUIRES_CACHE')
        after = 60
    expected = dict(maximum_precondition_steps=320, walking_prefix_steps=30,
                    interaction_steps=1, after_interaction_steps=after,
                    maximum_steps_per_child=352 + after)
    for key, value in expected.items():
        require(packet.same(declaration.get(key), value), 'SCHEDULE_' + key)
    return expected


def declared_roles(declaration):
    if declaration.get('diagnostic_schedule_id') == entry_profile.candidate_profile.contract()['worker_selection']['schedule']:
        return entry_profile.candidate_profile.declared_roles(declaration)
    # No single-child downgrade for historical or official paired contracts.
    require('development_execution_mode' not in declaration, 'MODE_NOT_ALLOWED_ON_LEGACY_SCHEDULE')
    return list(ROLES)


def validate_campaign_retention(report, declaration, campaign):
    """Exact campaign publication checks shared by production and native controls."""
    import r10j_campaign_authority
    require(packet.same(report.get('r10j_campaign'), declaration['r10j_campaign']), 'CAMPAIGN_HEADER')
    identity = r10j_campaign_authority.seed_identity(campaign['seed'])
    require(report.get('seed_label') == identity['label'] and report.get('seed_sha256') == identity['sha256'] and
            packet.same(report.get('held_out_cell_access_count'), 1 if campaign['held_out'] else 0), 'CAMPAIGN_SEED_RETENTION')


def validate_header(report, descriptor, declaration, worker_pid):
    schedule = declared_schedule(declaration)
    entry = entry_profile.selected(declaration)
    entry_worker = entry_profile.selection_for_declaration(declaration)['worker_selection'] if entry else {}
    campaign = None
    r10k_population = None
    r10ap_population = None
    r10am_population = None
    r10aj_population = None
    r10ai_population = None
    r10ag_population = None
    r10af_population = None
    r10ae_population = None
    r10ad_population = None
    r10ac_population = None
    r10ab_population = None
    r10aa_population = None
    r10z_population = None
    r10y_population = None
    r10v_population = None
    r10u_population = None
    r10t_population = None
    r10s_population = None
    r10r_population = None
    r10q_population = None
    r10o_population = None
    r10n_population = None
    r10m_population = None
    r10l_population = None
    if 'r10j_campaign' in declaration:
        import r10j_campaign_authority
        campaign = r10j_campaign_authority.validate_pair_declaration(declaration)
        validate_campaign_retention(report, declaration, campaign)
    else:
        require('r10j_campaign' not in report, 'UNDECLARED_CAMPAIGN')
    if 'r10k_development' in declaration:
        import r10k_development
        r10k_population = r10k_development.validate_declaration(declaration)
        r10k_development.validate_report_header(report, declaration, r10k_population)
    else:
        require('r10k_development' not in report, 'UNDECLARED_R10K_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10k_v51_partial_fall_recovery_route_v1', 'R10K_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10ap_development' in declaration:
        import r10ap_smoke_result
        r10ap_population = r10ap_smoke_result.validate_header(report, declaration)
    else:
        require('r10ap_development' not in report and 'r10ap_native_world_claim' not in report, 'UNDECLARED_R10AP_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10ap_progressive_headroom_route_v1', 'R10AP_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10am_development' in declaration:
        import r10am_smoke_result
        r10am_population = r10am_smoke_result.validate_header(report, declaration)
    else:
        require('r10am_development' not in report and 'r10am_native_world_claim' not in report, 'UNDECLARED_R10AM_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10am_support_anchored_route_v1', 'R10AM_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10aj_development' in declaration:
        import r10aj_smoke_result
        r10aj_population = r10aj_smoke_result.validate_header(report, declaration)
    else:
        require('r10aj_development' not in report and 'r10aj_native_world_claim' not in report, 'UNDECLARED_R10AJ_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10aj_hip_recenter_route_v1', 'R10AJ_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10ai_development' in declaration:
        import r10ai_smoke_result
        r10ai_population = r10ai_smoke_result.validate_header(report, declaration)
    else:
        require('r10ai_development' not in report and 'r10ai_native_world_claim' not in report, 'UNDECLARED_R10AI_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10ai_concurrent_load_rise_route_v1', 'R10AI_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10ag_development' in declaration:
        import r10ag_smoke_result
        r10ag_population = r10ag_smoke_result.validate_header(report, declaration)
    else:
        require('r10ag_development' not in report and 'r10ag_native_world_claim' not in report, 'UNDECLARED_R10AG_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10ag_detection_frame_load_seeking_route_v1', 'R10AG_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10af_development' in declaration:
        import r10af_smoke_result
        r10af_population = r10af_smoke_result.validate_header(report, declaration)
    else:
        require('r10af_development' not in report and 'r10af_native_world_claim' not in report, 'UNDECLARED_R10AF_DEVELOPMENT')
    if 'r10ae_development' in declaration:
        import r10ae_smoke_result
        r10ae_population = r10ae_smoke_result.validate_header(report, declaration)
    else:
        require('r10ae_development' not in report and 'r10ae_native_world_claim' not in report, 'UNDECLARED_R10AE_DEVELOPMENT')
    if 'r10ad_development' in declaration:
        import r10ad_smoke_result
        r10ad_population = r10ad_smoke_result.validate_header(report, declaration)
    else:
        require('r10ad_development' not in report and 'r10ad_native_world_claim' not in report, 'UNDECLARED_R10AD_DEVELOPMENT')
    if 'r10ac_development' in declaration:
        import r10ac_smoke_result
        r10ac_population = r10ac_smoke_result.validate_header(report, declaration)
    else:
        require('r10ac_development' not in report and 'r10ac_native_world_claim' not in report, 'UNDECLARED_R10AC_DEVELOPMENT')
    if 'r10ab_development' in declaration:
        import r10ab_development
        r10ab_population = r10ab_development.validate_declaration(declaration)
        r10ab_development.validate_report_header(report, declaration, r10ab_population)
    else:
        require('r10ab_development' not in report, 'UNDECLARED_R10AB_DEVELOPMENT')
        require(r10ap_population is not None or r10am_population is not None or r10aj_population is not None or r10ai_population is not None or r10ag_population is not None or r10af_population is not None or r10ae_population is not None or r10ad_population is not None or r10ac_population is not None or not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10ab_partial_downward_rise_route_v1', 'R10AB_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10aa_development' in declaration:
        import r10aa_development
        r10aa_population = r10aa_development.validate_declaration(declaration)
        r10aa_development.validate_report_header(report, declaration, r10aa_population)
    else:
        require('r10aa_development' not in report, 'UNDECLARED_R10AA_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10aa_partial_load_seeking_route_v1', 'R10AA_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10z_development' in declaration:
        import r10z_development
        r10z_population = r10z_development.validate_declaration(declaration)
        r10z_development.validate_report_header(report, declaration, r10z_population)
    else:
        require('r10z_development' not in report, 'UNDECLARED_R10Z_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10z_partial_pose_geometry_route_v1', 'R10Z_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10y_development' in declaration:
        import r10y_development
        r10y_population = r10y_development.validate_declaration(declaration)
        r10y_development.validate_report_header(report, declaration, r10y_population)
    else:
        require('r10y_development' not in report, 'UNDECLARED_R10Y_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10y_partial_direct_neutral_route_v1', 'R10Y_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10v_development' in declaration:
        import r10v_development
        r10v_population = r10v_development.validate_declaration(declaration)
        r10v_development.validate_report_header(report, declaration, r10v_population)
    else:
        require('r10v_development' not in report, 'UNDECLARED_R10V_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10v_v56_post_recovery_hold_route_v1', 'R10V_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10u_development' in declaration:
        import r10u_development
        r10u_population = r10u_development.validate_declaration(declaration)
        r10u_development.validate_report_header(report, declaration, r10u_population)
    else:
        require('r10u_development' not in report, 'UNDECLARED_R10U_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10u_v56_post_recovery_hold_route_v1', 'R10U_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10t_development' in declaration:
        import r10t_development
        r10t_population = r10t_development.validate_declaration(declaration)
        r10t_development.validate_report_header(report, declaration, r10t_population)
    else:
        require('r10t_development' not in report, 'UNDECLARED_R10T_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10t_v56_post_recovery_hold_route_v1', 'R10T_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10s_development' in declaration:
        import r10s_development
        r10s_population = r10s_development.validate_declaration(declaration)
        r10s_development.validate_report_header(report, declaration, r10s_population)
    else:
        require('r10s_development' not in report, 'UNDECLARED_R10S_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10s_v56_upright_recovery_route_v1', 'R10S_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10r_development' in declaration:
        import r10r_development
        r10r_population = r10r_development.validate_declaration(declaration)
        r10r_development.validate_report_header(report, declaration, r10r_population)
    else:
        require('r10r_development' not in report, 'UNDECLARED_R10R_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10r_v55_upright_recovery_route_v1', 'R10R_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10q_development' in declaration:
        import r10q_development
        r10q_population = r10q_development.validate_declaration(declaration)
        r10q_development.validate_report_header(report, declaration, r10q_population)
    else:
        require('r10q_development' not in report, 'UNDECLARED_R10Q_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10q_v55_upright_recovery_route_v1', 'R10Q_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10o_development' in declaration:
        import r10o_development
        r10o_population = r10o_development.validate_declaration(declaration)
        r10o_development.validate_report_header(report, declaration, r10o_population)
    else:
        require('r10o_development' not in report, 'UNDECLARED_R10O_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10o_v55_partial_fall_recovery_route_v1', 'R10O_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10n_development' in declaration:
        import r10n_development
        r10n_population = r10n_development.validate_declaration(declaration)
        r10n_development.validate_report_header(report, declaration, r10n_population)
    else:
        require('r10n_development' not in report, 'UNDECLARED_R10N_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10n_v54_partial_fall_recovery_route_v1', 'R10N_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10m_development' in declaration:
        import r10m_development
        r10m_population = r10m_development.validate_declaration(declaration)
        r10m_development.validate_report_header(report, declaration, r10m_population)
    else:
        require('r10m_development' not in report, 'UNDECLARED_R10M_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10m_v53_partial_fall_recovery_route_v1', 'R10M_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'r10l_development' in declaration:
        import r10l_development
        r10l_population = r10l_development.validate_declaration(declaration)
        r10l_development.validate_report_header(report, declaration, r10l_population)
    else:
        require('r10l_development' not in report, 'UNDECLARED_R10L_DEVELOPMENT')
        require(not entry or entry_profile.selection_for_declaration(declaration).get('diagnostic_schedule', {}).get('walking_policy_id') != 'r10l_v52_partial_fall_recovery_route_v1', 'R10L_DEVELOPMENT_CONTEXT_REQUIRED')
    if 'candidate_profile' in declaration:
        for key in ('candidate_profile', 'development_execution_mode', 'comparative_authority', 'baseline_reused'):
            require(packet.same(report.get(key), declaration.get(key)), 'CANDIDATE_HEADER_' + key)
    require(type(report) is dict and report.get('schema_version') == (entry_worker['report_schema'] if entry else SCHEMA), 'CHILD_SCHEMA')
    require(not entry or 'synthetic_test_fixture' not in report, 'SYNTHETIC_REPORT_NOT_PHYSICAL')
    for key, expected in {
        'work_id': entry_worker['work_id'] if entry else WORK, 'source_commit': declaration['source_snapshot']['head'],
        'parent_attempt_id': declaration['attempt_id'], 'child_attempt_id': descriptor['child_attempt_id'],
        'arm_id': descriptor['role'], 'process_id': worker_pid, 'seed': campaign['seed'] if campaign else r10ap_population['seed'] if r10ap_population else r10am_population['seed'] if r10am_population else r10aj_population['seed'] if r10aj_population else r10ai_population['seed'] if r10ai_population else r10ag_population['seed'] if r10ag_population else r10af_population['seed'] if r10af_population else r10ae_population['seed'] if r10ae_population else r10ad_population['seed'] if r10ad_population else r10ac_population['seed'] if r10ac_population else r10ab_population['seed'] if r10ab_population else r10aa_population['seed'] if r10aa_population else r10z_population['seed'] if r10z_population else r10y_population['seed'] if r10y_population else r10v_population['seed'] if r10v_population else r10u_population['seed'] if r10u_population else r10t_population['seed'] if r10t_population else r10s_population['seed'] if r10s_population else r10r_population['seed'] if r10r_population else r10q_population['seed'] if r10q_population else r10o_population['seed'] if r10o_population else r10n_population['seed'] if r10n_population else r10m_population['seed'] if r10m_population else r10l_population['seed'] if r10l_population else r10k_population['seed'] if r10k_population else 40200,
        'maximum_solver_step_count': schedule['maximum_steps_per_child'], 'model_construction_attempt_count': 1,
        'model_construction_count': 1, 'world_attempt_count': 1, 'world_build_count': 1,
        'complete_route_proven': False, 'held_out': campaign['held_out'] if campaign else False, 'physical_acceptance_authority': False,
        'release_authority': False, 'behavioral_conclusion': 'none',
        'telemetry_profile': 'unchanged_full_per_step_capture',
    }.items():
        require(packet.same(report.get(key), expected), 'HEADER_' + key)
    require(report.get('ok') is True, 'WORKER_INVALID:' + str(report.get('failure_code')))
    require(integer(report.get('solver_step_count'), 1, schedule['maximum_steps_per_child']), 'STEP_BOUND')
    require(packet.same(report.get('global_solver_frame_count'), report['solver_step_count']), 'FRAME_COUNT')
    require(integer(report.get('after_interaction_step_count'), 0, schedule['after_interaction_steps']), 'AFTER_BOUND')
    require(type(report.get('coverage_complete')) is bool, 'COVERAGE_KIND')
    expected_status = 'development_smoke_complete' if report['coverage_complete'] else 'development_smoke_coverage_incomplete'
    require(report.get('status') == expected_status, 'STATUS')
    scope = campaign['ledger_scope'] if campaign else dict(subsystem='recovery', engine_scope='godot_jolt',
        authority_mode='unofficial_physical_smoke', question_class='development')
    require(packet.same(report.get('ledger_scope'), scope), 'SCOPE')


def audit(root):
    root = root.resolve()
    evidence = Path(__file__).resolve().parents[3] / 'SporeSpore_Evidence'
    require(root.parent == evidence and re.fullmatch(r'development-recovery-smoke-[0-9a-f]{32}', root.name), 'ROOT')
    declaration = read(root / 'declaration.json')
    if 'r10ap_development' in declaration:
        import r10ap_development_launch
        r10ap_development_launch.verify(root / 'declaration.json')
    elif 'r10am_development' in declaration:
        import r10am_development_launch
        r10am_development_launch.verify(root / 'declaration.json')
    elif 'r10aj_development' in declaration:
        import r10aj_development_launch
        r10aj_development_launch.verify(root / 'declaration.json')
    elif 'r10ai_development' in declaration:
        import r10ai_development_launch
        r10ai_development_launch.verify(root / 'declaration.json')
    if 'r10ag_development' in declaration:
        import r10ag_development_launch
        r10ag_development_launch.verify(root / 'declaration.json')
    if 'r10af_development' in declaration:
        import r10af_development_launch
        r10af_development_launch.verify(root / 'declaration.json')
    if 'r10ae_development' in declaration:
        import r10ae_development_launch
        r10ae_development_launch.verify(root / 'declaration.json')
    if 'r10ad_development' in declaration:
        import r10ad_development_launch
        r10ad_development_launch.verify(root / 'declaration.json')
    if 'r10ac_development' in declaration:
        import r10ac_development_launch
        r10ac_development_launch.verify(root / 'declaration.json')
    if 'r10ab_development' in declaration:
        import r10ab_development_launch
        r10ab_development_launch.verify(root / 'declaration.json')
    if 'r10aa_development' in declaration:
        import r10aa_development_launch
        r10aa_development_launch.verify(root / 'declaration.json')
    if 'r10z_development' in declaration:
        import r10z_development_launch
        r10z_development_launch.verify(root / 'declaration.json')
    if 'r10y_development' in declaration:
        import r10y_development_launch
        r10y_development_launch.verify(root / 'declaration.json')
    if 'r10v_development' in declaration:
        import r10v_development_launch
        r10v_development_launch.verify(root / 'declaration.json')
    if 'r10u_development' in declaration:
        import r10u_development_launch
        r10u_development_launch.verify(root / 'declaration.json')
    if 'r10t_development' in declaration:
        import r10t_development_launch
        r10t_development_launch.verify(root / 'declaration.json')
    if 'r10s_development' in declaration:
        import r10s_development_launch
        r10s_development_launch.verify(root / 'declaration.json')
    if 'r10r_development' in declaration:
        import r10r_development_launch
        r10r_development_launch.verify(root / 'declaration.json')
    schedule = declared_schedule(declaration)
    entry = entry_profile.selected(declaration)
    entry_worker = entry_profile.selection_for_declaration(declaration)['worker_selection'] if entry else {}
    context_cache_expected = step_profile.declared_context_cache(declaration,
        expected_worker=entry_worker['worker'] if entry else step_profile.CACHE_WORKER_RESOURCE)
    require(declaration['physical_acceptance_authority'] is False and declaration['release_authority'] is False, 'DECLARATION_AUTHORITY')
    summaries = []
    development_cells = []
    previous_completed = None
    seen = set()
    for descriptor in declaration['children']:
        child = Path(descriptor['evidence_path']).resolve()
        require(child.parent == root / 'children' and child.name == descriptor['role'], 'CHILD_PATH')
        envelope = read(child / 'child_envelope.json')
        for key in ('role', 'child_attempt_id', 'termination_nonce'):
            require(packet.same(envelope[key], descriptor[key]), 'ENCLOSING_' + key)
        require(envelope['exit_code'] == 0 and envelope['termination_protocol_valid'] is True
                and envelope['engine_health_passed'] is True and envelope['raw_marker_valid'] is True, 'LAUNCH_INVALID')
        require(envelope['child_retry_count'] == 0 and envelope['child_replacement_count'] == 0, 'RETRY')
        for item in envelope['retained_artifact_bindings'].values():
            require(type(item) is dict, 'MISSING_RETAINED_FILE')
            path = Path(item['path']).resolve()
            require(path.parent == child and path.is_file(), 'RETAINED_PATH')
            require(path.stat().st_size == item['byte_length'] and sha(path) == item['raw_sha256'], 'RETAINED_BYTES')
        original = [line[len(MARKER):] for line in (child / 'worker.stdout.txt').read_text(encoding='utf-8').splitlines()
                    if line.startswith(MARKER)]
        require(len(original) == 1, 'RAW_MARKER')
        report = packet.parse_json(original[0])
        require(packet.same(report, read(child / 'worker_report.json')) and packet.same(report, envelope['report']), 'EXACT_RAW_BINDING')
        validate_header(report, descriptor, declaration, envelope['worker_process_id'])
        if 'r10ap_development' in declaration:
            import r10ap_smoke_result
            r10ap_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        elif 'r10am_development' in declaration:
            import r10am_smoke_result
            r10am_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        elif 'r10aj_development' in declaration:
            import r10aj_smoke_result
            r10aj_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        elif 'r10ai_development' in declaration:
            import r10ai_smoke_result
            r10ai_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        if 'r10ag_development' in declaration:
            import r10ag_smoke_result
            r10ag_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        if 'r10af_development' in declaration:
            import r10af_smoke_result
            r10af_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        if 'r10ae_development' in declaration:
            import r10ae_smoke_result
            r10ae_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        if 'r10ad_development' in declaration:
            import r10ad_smoke_result
            r10ad_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        if 'r10ac_development' in declaration:
            import r10ac_smoke_result
            r10ac_smoke_result.verify_physical_claim(report, root / 'declaration.json', envelope['worker_process_id'])
        profile_lines = [line[len(step_profile.MARKER):] for line in
                         (child / 'worker.stdout.txt').read_text(encoding='utf-8').splitlines()
                         if line.startswith(step_profile.MARKER)]
        profile = None
        if declaration.get('step_cost_profile_id') is not None:
            require(declaration['step_cost_profile_id'] == step_profile.PROFILE_ID and len(profile_lines) == 1,
                    'STEP_PROFILE_REQUIRED')
            profile = step_profile.validate_profile(packet.parse_json(profile_lines[0]), report, original[0],
                                                    context_cache_expected=context_cache_expected)
        else:
            require(not profile_lines, 'UNDECLARED_STEP_PROFILE')
        require(report['diagnostic_declaration_sha256'] == sha(root / 'declaration.json'), 'DECLARATION_BINDING')
        expected_launch = dict(schema_version='sporespore_qsdk_r10f_l15_launch_context_v1',
            parent_attempt_id=declaration['attempt_id'], child_attempt_id=descriptor['child_attempt_id'],
            role=descriptor['role'], source_commit=declaration['source_snapshot']['head'],
            authority_sha256=sha(root / 'declaration.json'), termination_nonce=descriptor['termination_nonce'],
            ready_marker_prefix='QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY ',
            root_image=declaration['runtime']['images']['godot_console'],
            worker_image=declaration['runtime']['images']['godot_engine'])
        launch.validate_receipt(envelope['r10f_l15_launch_relationship'], expected_context=expected_launch,
            root_process_id=envelope['process_id'], worker_process_id=envelope['worker_process_id'],
            started_utc=envelope['started_utc'], expected_ready_receipt=envelope['termination_ready_receipt'])
        started = launch.utc_ticks(envelope['started_utc'])
        completed = launch.utc_ticks(envelope['completed_utc'])
        require(started <= completed and (previous_completed is None or previous_completed <= started), 'OVERLAP')
        previous_completed = completed
        require(descriptor['child_attempt_id'] not in seen and descriptor['termination_nonce'] not in seen, 'REUSED_ID')
        seen.update((descriptor['child_attempt_id'], descriptor['termination_nonce']))
        expectation = declaration['prepared_context_expectation']
        context.validate_worker_comparison(report['l15_prepared_context_comparison'],
            expected_raw_binding=expectation['raw_capture_binding'], expected_identity=expectation['collection_identity'],
            canonical_sha256=legacy.canonical_sha256_v1)
        arm = report['retained_arm']
        count = report['solver_step_count']
        rows, invariants = arm['trace_rows'], arm['invariant_receipts']
        require(len(rows) == len(invariants) == count, 'COMPLETE_STEP_POPULATION')
        body = arm['body_population_instance_sha256']
        require(report['terminal_same_body_identity_receipt']['body_population_instance_sha256'] == body, 'BODY_IDENTITY')
        for step, (row, invariant) in enumerate(zip(rows, invariants), 1):
            require(row['global_semantic_step'] == invariant['global_semantic_step'] == step, 'STEP_SEQUENCE')
            require(row['arm_id'] == invariant['arm_id'] == descriptor['role'], 'ROW_ROLE')
            require(invariant['body_population_instance_sha256'] == body, 'STEP_BODY_IDENTITY')
            require(invariant['all_in_run_physical_invariants_passed'] is True
                    and type(invariant['predicates']) is dict and invariant['predicates']
                    and all(value is True for value in invariant['predicates'].values()), 'STEP_INVARIANT')
        for key in ('body_population_rebuild_count', 'body_transform_write_count', 'body_velocity_write_count', 'solver_reset_count'):
            require(packet.same(arm[key], 0), 'BODY_MUTATION_' + key)
        require(arm['active_walking_session'] == {} and arm['last_walking_evaluation_failure'] == {}, 'UNCLOSED_WALKING')
        for session in arm['walking_sessions']:
            evaluation = session['evaluation']
            require(evaluation['schema_version'] == 'sporespore_development_smoke_walking_diagnostics_v1'
                    and evaluation['ok'] is True and evaluation['development_smoke_only'] is True
                    and evaluation['behavioral_conclusion'] == 'none', 'WALKING_DIAGNOSTIC')
            require(session['completion_receipt']['adapter_shutdown_receipt']['explicit_shutdown_completed'] is True, 'SHUTDOWN')
        state = arm['orchestrator_state']
        covered = (state['walking_prefix_step_count'] == 30 and state['interaction_effect_step_count'] == 1
                   and report['after_interaction_step_count'] == schedule['after_interaction_steps']
                   and report['external_kick_application_count'] == (1 if descriptor['role'] == ROLES[1] else 0))
        require(report['coverage_complete'] is covered, 'COVERAGE')
        summaries.append(dict(role=descriptor['role'], coverage_complete=covered, solver_steps=count,
            extra_native_reads=report['explicit_worker_extra_native_readback_count'], stop_reason=report['stop_reason'],
            final_phase=state['phase'], child_envelope_sha256=sha(child / 'child_envelope.json')))
        if profile is not None:
            summaries[-1]['step_cost_profile'] = profile
        if entry:
            replay = entry_profile.consume_replay(child / 'worker_report.json')
            require(packet.same(replay, read(child / 'passive_entry_replay_result.json')), 'ENTRY_REPLAY_PUBLICATION')
            summaries[-1]['passive_entry_replay'] = replay
            if 'r10ap_development' in declaration:
                summaries[-1]['r10af_contact_frame_replay'] = r10ap_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            elif 'r10am_development' in declaration:
                summaries[-1]['r10af_contact_frame_replay'] = r10am_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            elif 'r10aj_development' in declaration:
                summaries[-1]['r10af_contact_frame_replay'] = r10aj_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            elif 'r10ai_development' in declaration:
                summaries[-1]['r10af_contact_frame_replay'] = r10ai_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            if 'r10ag_development' in declaration:
                summaries[-1]['r10af_contact_frame_replay'] = r10ag_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            if 'r10af_development' in declaration:
                summaries[-1]['r10af_contact_frame_replay'] = r10af_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            if 'r10ae_development' in declaration:
                summaries[-1]['r10ac_contact_frame_replay'] = r10ae_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            if 'r10ad_development' in declaration:
                summaries[-1]['r10ac_contact_frame_replay'] = r10ad_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            if 'r10ac_development' in declaration:
                summaries[-1]['r10ac_contact_frame_replay'] = r10ac_smoke_result.diagnostic_replay(report, root / 'declaration.json', replay)
            if 'r10k_development' in declaration or 'r10l_development' in declaration or 'r10m_development' in declaration or 'r10n_development' in declaration or 'r10o_development' in declaration or 'r10q_development' in declaration or 'r10r_development' in declaration or 'r10s_development' in declaration or 'r10t_development' in declaration or 'r10u_development' in declaration or 'r10v_development' in declaration or 'r10y_development' in declaration or 'r10ap_development' in declaration or 'r10am_development' in declaration or 'r10aj_development' in declaration or 'r10ai_development' in declaration or 'r10ag_development' in declaration or 'r10af_development' in declaration or 'r10ae_development' in declaration or 'r10ad_development' in declaration or 'r10ac_development' in declaration or 'r10ab_development' in declaration or 'r10aa_development' in declaration or 'r10z_development' in declaration:
                import sys
                sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'sdk/python'))
                from sporespore_locomotion import LocomotionCore
                if "r10ap_development" in declaration:
                    import r10ap_finite_task_audit as finite_task
                elif "r10am_development" in declaration:
                    import r10am_finite_task_audit as finite_task
                elif "r10aj_development" in declaration:
                    import r10aj_finite_task_audit as finite_task
                elif "r10ai_development" in declaration:
                    import r10ai_finite_task_audit as finite_task
                elif "r10ag_development" in declaration:
                    import r10ag_finite_task_audit as finite_task
                elif "r10af_development" in declaration:
                    import r10af_finite_task_audit as finite_task
                elif "r10ae_development" in declaration:
                    import r10ae_finite_task_audit as finite_task
                elif "r10ad_development" in declaration:
                    import r10ad_finite_task_audit as finite_task
                elif "r10ac_development" in declaration:
                    import r10ac_finite_task_audit as finite_task
                elif "r10ab_development" in declaration:
                    import r10ab_finite_task_audit as finite_task
                elif "r10aa_development" in declaration:
                    import r10aa_finite_task_audit as finite_task
                elif "r10z_development" in declaration:
                    import r10z_finite_task_audit as finite_task
                elif "r10y_development" in declaration:
                    import r10y_finite_task_audit as finite_task
                elif "r10v_development" in declaration:
                    import r10v_finite_task_audit as finite_task
                elif "r10u_development" in declaration:
                    import r10u_finite_task_audit as finite_task
                elif "r10t_development" in declaration:
                    import r10t_finite_task_audit as finite_task
                elif "r10s_development" in declaration:
                    import r10s_finite_task_audit as finite_task
                elif "r10r_development" in declaration:
                    import r10r_finite_task_audit as finite_task
                elif "r10q_development" in declaration:
                    import r10q_finite_task_audit as finite_task
                elif "r10o_development" in declaration:
                    import r10o_finite_task_audit as finite_task
                elif "r10n_development" in declaration:
                    import r10n_finite_task_audit as finite_task
                elif "r10m_development" in declaration:
                    import r10m_finite_task_audit as finite_task
                elif "r10l_development" in declaration:
                    import r10l_finite_task_audit as finite_task
                else:
                    import r10k_finite_task_audit as finite_task
                chosen = entry_profile.selection_for_report(report)
                core = LocomotionCore(entry_profile.binding(chosen)['runtime']['path'])
                compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
                measured = finite_task.measure(report, compiled)
                development_cells.append(dict(role=descriptor['role'], child_attempt_id=descriptor['child_attempt_id'],
                    entry_kind=state['r10v_entry_kind' if 'r10ap_development' in declaration or 'r10am_development' in declaration or 'r10aj_development' in declaration or 'r10ai_development' in declaration or 'r10ag_development' in declaration or 'r10af_development' in declaration or 'r10ae_development' in declaration or 'r10ad_development' in declaration or 'r10ac_development' in declaration or 'r10ab_development' in declaration or 'r10aa_development' in declaration or 'r10z_development' in declaration or 'r10y_development' in declaration or 'r10v_development' in declaration else 'r10u_entry_kind' if 'r10u_development' in declaration else 'r10t_entry_kind' if 'r10t_development' in declaration else 'r10s_entry_kind' if 'r10s_development' in declaration else 'r10r_entry_kind' if 'r10r_development' in declaration else 'r10q_entry_kind' if 'r10q_development' in declaration else 'r10k_entry_kind'], finite_task_predicates_passed=measured['finite_task_predicates_passed'],
                    measurement=measured, child_envelope_sha256=sha(child / 'child_envelope.json')))
                if 'r10t_development' in declaration or 'r10u_development' in declaration or 'r10v_development' in declaration or 'r10y_development' in declaration or 'r10ap_development' in declaration or 'r10am_development' in declaration or 'r10aj_development' in declaration or 'r10ai_development' in declaration or 'r10ag_development' in declaration or 'r10af_development' in declaration or 'r10ae_development' in declaration or 'r10ad_development' in declaration or 'r10ac_development' in declaration or 'r10ab_development' in declaration or 'r10aa_development' in declaration or 'r10z_development' in declaration:
                    development_cells[-1]['post_recovery_handoff'] = measured['entry']['post_recovery']['handoff']
    require([row['role'] for row in summaries] == declared_roles(declaration), 'PAIR_POPULATION')
    result = dict(schema_version='sporespore_sdk1_development_recovery_smoke_audit_v1', ok=True,
        coverage_complete=all(row['coverage_complete'] for row in summaries), children=summaries,
        total_solver_steps=sum(row['solver_steps'] for row in summaries),
        complete_route_proven=False, behavioral_conclusion='none', physical_acceptance_authority=False, release_authority=False)
    if 'r10k_development' in declaration:
        import r10k_development
        result['r10k_finite_development'] = r10k_development.finite_result(declaration, development_cells)
    if 'r10ap_development' in declaration:
        result['r10ap_contact_frame_diagnostic'] = r10ap_smoke_result.finite_result(declaration, development_cells, summaries)
    elif 'r10am_development' in declaration:
        result['r10am_contact_frame_diagnostic'] = r10am_smoke_result.finite_result(declaration, development_cells, summaries)
    elif 'r10aj_development' in declaration:
        result['r10aj_contact_frame_diagnostic'] = r10aj_smoke_result.finite_result(declaration, development_cells, summaries)
    elif 'r10ai_development' in declaration:
        result['r10ai_contact_frame_diagnostic'] = r10ai_smoke_result.finite_result(declaration, development_cells, summaries)
    if 'r10ag_development' in declaration:
        result['r10ag_contact_frame_diagnostic'] = r10ag_smoke_result.finite_result(declaration, development_cells, summaries)
    if 'r10af_development' in declaration:
        result['r10af_contact_frame_diagnostic'] = r10af_smoke_result.finite_result(declaration, development_cells, summaries)
    if 'r10ae_development' in declaration:
        result['r10ae_contact_frame_diagnostic'] = r10ae_smoke_result.finite_result(declaration, development_cells, summaries)
    if 'r10ad_development' in declaration:
        result['r10ad_contact_frame_diagnostic'] = r10ad_smoke_result.finite_result(declaration, development_cells, summaries)
    if 'r10ac_development' in declaration:
        result['r10ac_contact_frame_diagnostic'] = r10ac_smoke_result.finite_result(declaration, development_cells, summaries)
    if 'r10ab_development' in declaration:
        import r10ab_development
        result['r10ab_finite_development'] = r10ab_development.finite_result(declaration, development_cells)
    if 'r10aa_development' in declaration:
        import r10aa_development
        result['r10aa_finite_development'] = r10aa_development.finite_result(declaration, development_cells)
    if 'r10z_development' in declaration:
        import r10z_development
        result['r10z_finite_development'] = r10z_development.finite_result(declaration, development_cells)
    if 'r10y_development' in declaration:
        import r10y_development
        result['r10y_finite_development'] = r10y_development.finite_result(declaration, development_cells)
    if 'r10v_development' in declaration:
        import r10v_development
        result['r10v_finite_development'] = r10v_development.finite_result(declaration, development_cells)
    if 'r10u_development' in declaration:
        import r10u_development
        result['r10u_finite_development'] = r10u_development.finite_result(declaration, development_cells)
    if 'r10t_development' in declaration:
        import r10t_development
        result['r10t_finite_development'] = r10t_development.finite_result(declaration, development_cells)
    if 'r10s_development' in declaration:
        import r10s_development
        result['r10s_finite_development'] = r10s_development.finite_result(declaration, development_cells)
    if 'r10r_development' in declaration:
        import r10r_development
        result['r10r_finite_development'] = r10r_development.finite_result(declaration, development_cells)
    if 'r10q_development' in declaration:
        import r10q_development
        result['r10q_finite_development'] = r10q_development.finite_result(declaration, development_cells)
    if 'r10o_development' in declaration:
        import r10o_development
        result['r10o_finite_development'] = r10o_development.finite_result(declaration, development_cells)
    if 'r10n_development' in declaration:
        import r10n_development
        result['r10n_finite_development'] = r10n_development.finite_result(declaration, development_cells)
    if 'r10m_development' in declaration:
        import r10m_development
        result['r10m_finite_development'] = r10m_development.finite_result(declaration, development_cells)
    if 'r10l_development' in declaration:
        import r10l_development
        result['r10l_finite_development'] = r10l_development.finite_result(declaration, development_cells)
    return result


def retained_checkpoint(root):
    """Reopen an already finished attempt; never launch, rewrite, or qualify it."""
    observed = audit(root)
    root = root.resolve()
    declaration = read(root / 'declaration.json')
    result = read(root / 'supervisor_result.json')
    published = (root / 'published_marker.txt').read_text(encoding='utf-8')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    require(published.startswith(prefix) and packet.same(result, packet.parse_json(published[len(prefix):])),
            'FINAL_PUBLICATION_BINDING')
    require(packet.same(observed, read(root / 'independent_audit.stdout.json'))
            and packet.same(observed, result['independent_audit']), 'RETAINED_AUDIT_BINDING')
    require(packet.same(declaration['source_snapshot'], result['source_snapshot']), 'FINAL_SOURCE_BINDING')
    inventory = [dict(path=path.relative_to(root).as_posix(), byte_length=path.stat().st_size,
                      sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                 for path in sorted(root.rglob('*')) if path.is_file()]
    inventory_bytes = json.dumps(inventory, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('ascii')
    def seconds(record):
        return round((launch.utc_ticks(record['completed_utc']) - launch.utc_ticks(record['started_utc'])) / 10_000_000, 3)
    return dict(
        schema_version='sporespore_sdk1_development_recovery_smoke_retained_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                          authority_mode='unofficial_physical_smoke', question_class='development'),
        evidence_root=root.as_posix(), attempt_id=declaration['attempt_id'],
        source_snapshot=declaration['source_snapshot'], telemetry_profile=declaration['telemetry_profile'],
        retained_population=dict(file_count=len(inventory), byte_length=sum(row['byte_length'] for row in inventory),
                                 inventory_sha256='sha256:' + hashlib.sha256(inventory_bytes).hexdigest()),
        artifact_sha256={name: sha(root / name) for name in
                         ('supervisor_result.json', 'declaration.json', 'independent_audit.stdout.json')},
        elapsed_seconds=dict(whole_invocation=seconds(result), children={role: seconds(read(
            root / 'children' / role / 'child_envelope.json')) for role in declared_roles(read(root / 'declaration.json'))}),
        official_qualification_passed=False, observed=observed)


def validate_checkpoint(record, observed):
    # Exact whole-record comparison also refuses extra claims and changed types.
    require(packet.same(record, observed), 'CHECKPOINT_BINDING')


def retained_prone_deadline_failure(root):
    """Preserve the consumed initial deadline attempt, never repair its result."""
    root = root.resolve()
    evidence = Path(__file__).resolve().parents[3] / 'SporeSpore_Evidence'
    require(root.parent == evidence and root.name ==
            'development-recovery-smoke-0b0a56bac7614a32b588ae2810be0213', 'FAILURE_ROOT')
    declaration = read(root / 'declaration.json')
    declared_schedule(declaration)
    result = read(root / 'supervisor_result.json')
    published = (root / 'published_marker.txt').read_text(encoding='utf-8')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    require(published.startswith(prefix) and packet.same(result, packet.parse_json(published[len(prefix):])),
            'FAILURE_FINAL_PUBLICATION')
    require(result['ok'] is False and result['independent_audit'] is None
            and result['failure_code'] == 'SMOKE_CHILD_INVALID:' + ROLES[0], 'FAILURE_OUTCOME')
    require(len(result['children']) == 1 and result['children'][0]['role'] == ROLES[0]
            and not (root / 'children' / ROLES[1]).exists(), 'FAILURE_POPULATION')
    child = root / 'children' / ROLES[0]
    envelope = read(child / 'child_envelope.json')
    originals = [line[len(MARKER):] for line in (child / 'worker.stdout.txt').read_text(encoding='utf-8').splitlines()
                 if line.startswith(MARKER)]
    require(len(originals) == 1, 'FAILURE_RAW_MARKER')
    report = packet.parse_json(originals[0])
    require(packet.same(report, read(child / 'worker_report.json'))
            and packet.same(report, envelope['report']), 'FAILURE_EXACT_RAW_BINDING')
    for item in envelope['retained_artifact_bindings'].values():
        path = Path(item['path']).resolve()
        require(path.parent == child and path.stat().st_size == item['byte_length']
                and sha(path) == item['raw_sha256'], 'FAILURE_RETAINED_BYTES')
    require(envelope['exit_code'] == 1 and envelope['termination_protocol_valid'] is True
            and envelope['engine_health_passed'] is True and envelope['raw_marker_valid'] is True
            and envelope['child_retry_count'] == envelope['child_replacement_count'] == 0, 'FAILURE_CHILD_CLOSE')
    require(report['source_commit'] == declaration['source_snapshot']['head'] ==
            'f0c039fb37092501e694cfb43b7fa97532cd83f6'
            and packet.same(declaration['source_snapshot'], result['source_snapshot']), 'FAILURE_SOURCE')
    require(report['authorization_sha256'] == sha(root / 'declaration.json'), 'FAILURE_DECLARATION')
    arm = report['partial_arm']
    failure = arm['last_walking_evaluation_failure']
    require(report['ok'] is False and report['failure_code'] == 'DEVELOPMENT_SMOKE_WALKING_CLOSE_INVALID'
            and failure['evaluator_failure_code'] == 'QSDK_R10F_WALKING_EVALUATION_SHAPE_INVALID'
            and failure['walking_evaluation_input']['expected_step_count'] == 60
            and len(failure['walking_evaluation_input']['rows']) == 60, 'FAILURE_DIAGNOSIS')
    require(report['world_build_count'] == 1 and report['solver_step_count'] == report['global_solver_frame_count'] == 332
            and report['external_kick_application_count'] == 0
            and len(arm['trace_rows']) == len(arm['invariant_receipts']) == 332, 'FAILURE_COUNTS')
    require(all(row['global_semantic_step'] == index for index, row in enumerate(arm['trace_rows'], 1)),
            'FAILURE_TRACE_SEQUENCE')
    inventory = [dict(path=path.relative_to(root).as_posix(), byte_length=path.stat().st_size, raw_sha256=sha(path))
                 for path in sorted(root.rglob('*')) if path.is_file()]
    elapsed = (launch.utc_ticks(result['completed_utc']) - launch.utc_ticks(result['started_utc'])) / 10_000_000
    return dict(schema_version='sporespore_development_prone_deadline_failure_checkpoint_v1',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                                  authority_mode='retained_development_failure', question_class='development'),
                status='closed_consumed_infrastructure_invalid', evidence_root=root.as_posix(),
                attempt_id=declaration['attempt_id'], source_commit=report['source_commit'],
                retained_population=dict(file_count=len(inventory), byte_length=sum(v['byte_length'] for v in inventory),
                                         files=inventory),
                elapsed_seconds=round(elapsed, 3), world_count=1, solver_steps=332,
                extra_native_reads=report['explicit_worker_extra_native_readback_count'],
                kick_child_started=False, exact_failure_publication_verified=True,
                failure_code=report['failure_code'], evaluator_failure_code=failure['evaluator_failure_code'],
                diagnosis='Declared 60-step walking continuation reached an unchanged 30-step diagnostic evaluator cap.',
                complete_route_proven=False, behavioral_conclusion='none', physical_acceptance_authority=False,
                release_authority=False, repeat_consumed_attempt_permitted=False)


def retained_measured_entry_runtime_failure(root):
    """Cold preservation of the first new-runtime physical startup failure."""
    root = root.resolve()
    evidence = Path(__file__).resolve().parents[3] / 'SporeSpore_Evidence'
    require(root.parent == evidence and root.name ==
            'development-recovery-smoke-59843755052e4798b28e44b59b564d1e', 'ENTRY_FAILURE_ROOT')
    declaration = read(root / 'declaration.json')
    result = read(root / 'supervisor_result.json')
    marker = (root / 'published_marker.txt').read_text(encoding='utf-8')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    require(marker.startswith(prefix) and packet.same(result, packet.parse_json(marker[len(prefix):])),
            'ENTRY_FAILURE_PUBLICATION')
    require(result['ok'] is False and result['independent_audit'] is None
            and result['failure_code'] == 'SMOKE_CHILD_INVALID:' + ROLES[0]
            and len(result['children']) == 1 and not (root / 'children' / ROLES[1]).exists(),
            'ENTRY_FAILURE_POPULATION')
    require(packet.same(result['source_snapshot'], declaration['source_snapshot'])
            and result['source_snapshot']['dirty'] is False, 'ENTRY_FAILURE_SOURCE')
    child = root / 'children' / ROLES[0]
    envelope = read(child / 'child_envelope.json')
    report = read(child / 'worker_report.json')
    originals = [packet.parse_json(line[len(MARKER):]) for line in
                 (child / 'worker.stdout.txt').read_text(encoding='utf-8').splitlines() if line.startswith(MARKER)]
    require(len(originals) == 1 and packet.same(originals[0], report)
            and packet.same(report, envelope['report']), 'ENTRY_FAILURE_RAW_PUBLICATION')
    for item in list(envelope['retained_artifact_bindings'].values()) + [result['children'][0]['envelope']]:
        path = Path(item['path']).resolve()
        require(path.parent == child and path.stat().st_size == item['byte_length']
                and sha(path) == item['raw_sha256'], 'ENTRY_FAILURE_ARTIFACT')
    validate_header(report, declaration['children'][0], declaration, envelope['worker_process_id'])
    health = read(child / 'engine_health.json')
    stderr = (child / 'worker.stderr.txt').read_bytes()
    errors = [line for line in stderr.decode('utf-8').splitlines() if line.startswith('ERROR:')]
    require(envelope['exit_code'] == 0 and envelope['raw_marker_valid'] is True
            and envelope['termination_protocol_valid'] is True and envelope['engine_health_passed'] is False
            and health['passed'] is False and health['stderr_raw_sha256'] == sha(child / 'worker.stderr.txt')
            and health['stderr_raw_byte_length'] == len(stderr) and len(errors) == 65
            and health['ordered_unique_fatal_diagnostic_lines'] == list(dict.fromkeys(errors))
            and errors[0] == "ERROR: Attempt to register extension class 'SporeLocomotionSdk', which appears to be already registered."
            and b'scripts/lab/gait/sdk_godot_jolt_adapter.gd:705' in stderr, 'ENTRY_FAILURE_ENGINE_HEALTH')
    arm = report['retained_arm']
    require(report['solver_step_count'] == 752 and report['world_build_count'] == 1
            and report['external_kick_application_count'] == 0
            and len(arm['trace_rows']) == len(arm['invariant_receipts']) == 752
            and all(row['global_semantic_step'] == index for index, row in enumerate(arm['trace_rows'], 1)),
            'ENTRY_FAILURE_STEPS')
    for stage in result['safety_stages']:
        require(stage['passed'] is True and stage['test_count'] == stage['expected_test_count'], 'ENTRY_FAILURE_GATE')
        for stream in ('stdout', 'stderr'):
            require(sha(root / stage[stream]) == 'sha256:' + stage[stream + '_sha256'], 'ENTRY_FAILURE_GATE_BYTES')
    require(sum(stage['test_count'] for stage in result['safety_stages']) == 70, 'ENTRY_FAILURE_GATE_COUNT')
    inventory = [dict(path=path.relative_to(root).as_posix(), byte_length=path.stat().st_size, raw_sha256=sha(path))
                 for path in sorted(root.rglob('*')) if path.is_file()]
    return dict(schema_version='sporespore_development_measured_entry_runtime_failure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='retained_development_failure',
                          question_class='development'), status='closed_consumed_infrastructure_invalid',
        evidence_root=root.as_posix(), attempt_id=declaration['attempt_id'], source_snapshot=result['source_snapshot'],
        retained_population=dict(file_count=len(inventory), byte_length=sum(v['byte_length'] for v in inventory), files=inventory),
        elapsed_seconds=round((launch.utc_ticks(result['completed_utc']) - launch.utc_ticks(result['started_utc'])) / 10_000_000, 3),
        world_count=1, solver_steps=752, after_interaction_steps=480, kick_child_started=False,
        safety_tests_passed=70, engine_error_count=65, worker_report_ok=True, enclosing_health_passed=False,
        exact_failure_publication_verified=True, failure_code=result['failure_code'],
        diagnosis='Walking startup loaded the default extension after the worker selected its separate runtime; duplicate class registration invalidates the attempt.',
        complete_route_proven=False, behavioral_conclusion='none', physical_acceptance_authority=False,
        release_authority=False, repeat_consumed_attempt_permitted=False)


def measured_entry_native_application_links(application, bound):
    """The native execution receipt is distinct from the pre-step intent."""
    components = bound['source_component_receipts']['rotation_aware_source_component_receipts']
    native = components['application_receipt']
    actuation = bound['observation_v3']['applied_actuation']
    native_hash = legacy.canonical_sha256_v1(native)
    require(native_hash == components['application_receipt_sha256'] == actuation['adapter_receipt_sha256'],
            'ENTRY_NATIVE_RECEIPT_HASH')
    require(all(packet.same(application[key], native[key]) and packet.same(native[key], actuation[key])
                for key in ('command_id', 'command_sha256', 'zero_command')), 'ENTRY_NATIVE_COMMAND_LINK')
    require(packet.same(application['semantic_step'], native['semantic_step'])
            and packet.same(native['semantic_step'], actuation['source_semantic_step'])
            and packet.same(actuation['ordered_applied_impulses'], native['ordered_applied_impulses']),
            'ENTRY_NATIVE_STEP_OR_IMPULSE_LINK')
    return native_hash != legacy.canonical_sha256_v1(application)


def retained_measured_entry_replay_failure(root):
    """Retained-data diagnosis, not a repair or promotion of the failed run."""
    root = root.resolve()
    evidence = Path(__file__).resolve().parents[3] / 'SporeSpore_Evidence'
    require(root.parent == evidence and root.name ==
            'development-recovery-smoke-9793f1dc13204b44bd79230253c7a972', 'REPLAY_FAILURE_ROOT')
    result, declaration = read(root / 'supervisor_result.json'), read(root / 'declaration.json')
    prefix = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    marker = (root / 'published_marker.txt').read_text(encoding='utf-8')
    require(marker.startswith(prefix) and packet.same(result, packet.parse_json(marker[len(prefix):])), 'REPLAY_FAILURE_PUBLICATION')
    require(result['ok'] is False and result['independent_audit'] is None
            and result['failure_code'] == 'SMOKE_ENTRY_REPLAY_FAILED:' + ROLES[1]
            and len(result['children']) == 2 and packet.same(result['source_snapshot'], declaration['source_snapshot'])
            and result['source_snapshot']['dirty'] is False, 'REPLAY_FAILURE_OUTCOME')
    reports = []
    for descriptor, summary in zip(declaration['children'], result['children']):
        child = root / 'children' / descriptor['role']
        envelope, report = read(child / 'child_envelope.json'), read(child / 'worker_report.json')
        originals = [packet.parse_json(line[len(MARKER):]) for line in
                     (child / 'worker.stdout.txt').read_text(encoding='utf-8').splitlines() if line.startswith(MARKER)]
        require(len(originals) == 1 and packet.same(originals[0], report) and packet.same(report, envelope['report']),
                'REPLAY_FAILURE_CHILD_PUBLICATION')
        for item in list(envelope['retained_artifact_bindings'].values()) + [summary['envelope']]:
            path = Path(item['path']).resolve()
            require(path.parent == child and path.stat().st_size == item['byte_length'] and sha(path) == item['raw_sha256'],
                    'REPLAY_FAILURE_ARTIFACT')
        validate_header(report, descriptor, declaration, envelope['worker_process_id'])
        require(envelope['exit_code'] == 0 and envelope['engine_health_passed'] is True
                and envelope['raw_marker_valid'] is True and envelope['termination_protocol_valid'] is True
                and (child / 'worker.stderr.txt').read_bytes() == b'', 'REPLAY_FAILURE_NATIVE_HEALTH')
        require(report['solver_step_count'] == len(report['retained_arm']['trace_rows'])
                == len(report['retained_arm']['invariant_receipts']), 'REPLAY_FAILURE_STEP_POPULATION')
        reports.append(report)
    require([r['arm_id'] for r in reports] == list(ROLES), 'REPLAY_FAILURE_ROLES')
    baseline_replay = entry_profile.consume_replay(root / 'children' / ROLES[0] / 'worker_report.json')
    child = root / 'children' / ROLES[1]
    execution = read(child / 'passive_entry_replay/execution.json')
    require(execution['returncode'] == 1 and execution['timed_out'] is False
            and execution['input_raw_sha256'] == sha(child / 'worker_report.json'), 'REPLAY_FAILURE_EXECUTION')
    for stream in ('stdout', 'stderr'):
        path = child / 'passive_entry_replay' / (stream + '.txt')
        require(path.stat().st_size == execution[stream + '_binding']['byte_length']
                and sha(path) == execution[stream + '_binding']['raw_sha256'], 'REPLAY_FAILURE_EXECUTION_BYTES')
    lines = [line[len(entry_profile.MARKER):] for line in (child / 'passive_entry_replay/stdout.txt').read_text().splitlines()
             if line.startswith(entry_profile.MARKER)]
    require(len(lines) == 1, 'REPLAY_FAILURE_MARKER')
    failed_replay = packet.parse_json(lines[0])
    require(failed_replay['ok'] is False and failed_replay['failure_code'] ==
            'PASSIVE_ENTRY_REPLAY_APPLICATION_OBSERVATION_BINDING', 'REPLAY_FAILURE_DIAGNOSIS')
    report = reports[1]
    retained = report['passive_entry']
    population = [(p['source_application'], p['bound_observations']) for p in retained['entry_packets']]
    population += [(p['application'], packet.parse_json(p['collection_transport']['source_links']['bound_observation']['utf8_text']))
                   for p in retained['canonical_packets']]
    distinct = sum(measured_entry_native_application_links(app, bound) for app, bound in population)
    require(len(population) == distinct == 354 and [app['semantic_step'] for app, _ in population] == list(range(273, 627)),
            'REPLAY_FAILURE_NATIVE_LINK_POPULATION')
    inventory = [dict(path=path.relative_to(root).as_posix(), byte_length=path.stat().st_size, raw_sha256=sha(path))
                 for path in sorted(root.rglob('*')) if path.is_file()]
    state = report['retained_arm']['orchestrator_state']
    return dict(schema_version='sporespore_development_measured_entry_replay_failure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis',
                          question_class='development'), status='closed_consumed_independent_replay_invalid',
        evidence_root=root.as_posix(), attempt_id=declaration['attempt_id'], source_snapshot=result['source_snapshot'],
        retained_population=dict(file_count=len(inventory), byte_length=sum(v['byte_length'] for v in inventory), files=inventory),
        elapsed_seconds=round((launch.utc_ticks(result['completed_utc']) - launch.utc_ticks(result['started_utc'])) / 10_000_000, 3),
        world_count=2, solver_steps=sum(r['solver_step_count'] for r in reports),
        child_solver_steps={r['arm_id']:r['solver_step_count'] for r in reports}, native_engine_health_passed=True,
        original_independent_replay_passed=False, baseline_replay=baseline_replay,
        failed_replay=failed_replay, failure_code=result['failure_code'],
        native_execution_receipt_links_checked=354, native_receipts_distinct_from_intents=distinct,
        observed_controller_timeline={key:state[key] for key in ('epoch_start_global_step', 'canonical_start_global_step',
            'passive_descent_step_count', 'confirm_prone_step_count', 'consecutive_prone_sample_count',
            'post_kick_recovery_step_count', 'walking_resume_step_count', 'terminal_reason')},
        diagnosis='The reader compared an observation native-execution-receipt digest to the pre-step command intent digest. All 354 retained native receipts and command links match.',
        full_recovery_sequence_independently_replayed=False, complete_route_proven=False, behavioral_conclusion='none',
        physical_acceptance_authority=False, release_authority=False, repeat_consumed_attempt_permitted=False)


SUPPORT_DIAGNOSIS_RULE_COMMIT = '4bd32cacc04d80b28816404d7217c27069f5d20e'


def _support_rule_bytes(relative):
    # A later controller must not rewrite the rule source of an observed
    # diagnosis. The committed bytes remain the authority, not today's file.
    return entry_profile.subprocess.check_output(['git', 'show', SUPPORT_DIAGNOSIS_RULE_COMMIT + ':' + relative],
        cwd=entry_profile.ROOT, creationflags=entry_profile.subprocess.CREATE_NO_WINDOW)


def _support_rule_identity(relative):
    raw = _support_rule_bytes(relative)
    return dict(path=relative, byte_length=len(raw), raw_sha256=entry_profile.digest(raw))


def measured_entry_support_metrics(report):
    """Descriptive measurements only; reproduce the unchanged four-foot gate."""
    thresholds = packet.parse_json(_support_rule_bytes('sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json').decode())
    threshold = next(row['value'] for row in thresholds['threshold_profile']['thresholds']
                     if row['threshold_id'] == 'distal_bearing_minimum_impulse_ns')
    controller = packet.parse_json(_support_rule_bytes('sdk/recovery/r24d127_godot_jolt_solver_coupled_controller_contract_v1.json').decode())['controller_version_contract']
    targets = controller['successor_support_targets_rad']
    active = [p for p in report['passive_entry']['canonical_packets'] if p['application']['no_actuation_requested'] is False]
    require(len(active) == 240 and [p['global_semantic_step'] for p in active] == list(range(387, 627)), 'SUPPORT_POPULATION')
    require(all(p['application']['recovery_controller_id'] == controller['successor_controller_id'] and
                p['step_receipt']['prior_phase'] == 'establish_distal_support' for p in active), 'SUPPORT_CONTROLLER')
    histogram = {str(n): 0 for n in range(5)}
    per_foot = {}
    samples = []
    for row in active:
        bound = packet.parse_json(row['collection_transport']['source_links']['bound_observation']['utf8_text'])
        observation = bound['observation_v3']
        classification = row['step_receipt']['classification']
        base_contacts = observation['state']['ordered_contact_observations']
        feet = observation['ordered_foot_bearing_observations']
        require(len(base_contacts) == len(feet) == 4, 'SUPPORT_CONTACT_POPULATION')
        bearing = []
        for base, foot in zip(base_contacts, feet):
            site = foot['contact_site_id']
            per_foot.setdefault(site, 0)
            supported = (base['presence'] is True and base['bears_support'] is True and
                         foot['ordinary_unilateral_contact'] is True and foot['bearing_normal_impulse_ns'] >= threshold)
            if supported:
                bearing.append(site)
                per_foot[site] += 1
        require(classification['distal_support_gate'] is (len(bearing) == 4), 'SUPPORT_GATE_RECOMPUTATION')
        histogram[str(len(bearing))] += 1
        joints = observation['state']['ordered_joint_observations']
        require(len(joints) == len(targets) == 8, 'SUPPORT_JOINT_POPULATION')
        samples.append(dict(global_step=row['global_semantic_step'],
            torso_up_dot=classification['torso_up_dot'], torso_height_ratio=classification['torso_height_ratio'],
            feet_meeting_existing_support_requirement=len(bearing),
            maximum_joint_target_error_rad=max(abs(joint['position_rad'] - target) for joint, target in zip(joints, targets))))
    first_inverted = next((row['global_step'] for row in samples if row['torso_up_dot'] < 0.0), None)
    peak = max(samples, key=lambda row: row['torso_height_ratio'])
    return dict(active_step_count=len(active), active_simulated_seconds=len(active) / report['configuration']['physics_solver_policy']['physics_hz'],
        existing_per_foot_bearing_requirement_ns=threshold, support_gate_true_step_count=histogram['4'],
        simultaneous_bearing_foot_count_histogram=histogram, per_foot_bearing_step_count=per_foot,
        first_torso_up_vector_below_horizontal_step=first_inverted, peak_torso_height_sample=peak,
        terminal_sample=samples[-1], ordered_support_targets_rad=targets,
        selected_samples=[row for row in samples if row['global_step'] in (387, 400, 420, 436, 450, 470, 500, 550, 626)])


def retained_measured_entry_support_diagnosis(diagnostic_root):
    """Consume a separately retained full replay; never rerun or promote it."""
    original_path = entry_profile.ROOT / 'sdk/development_measured_entry_replay_failure_v1.json'
    original = read(original_path)
    report_path = Path(original['evidence_root']) / 'children' / ROLES[1] / 'worker_report.json'
    expected = next(row for row in original['retained_population']['files']
                    if row['path'] == 'children/' + ROLES[1] + '/worker_report.json')
    require(sha(report_path) == expected['raw_sha256'] and report_path.stat().st_size == expected['byte_length'], 'SUPPORT_INPUT_BINDING')
    replay = entry_profile.consume_replay(report_path, diagnostic_directory=diagnostic_root)
    report = read(report_path)
    metrics = measured_entry_support_metrics(report)
    require(metrics['support_gate_true_step_count'] == 0 and metrics['terminal_sample']['torso_up_dot'] < 0.0,
            'SUPPORT_OBSERVED_OUTCOME')
    state = report['retained_arm']['orchestrator_state']
    require(state['terminal_reason'] == 'phase_timeout:establish_distal_support' and state['walking_resume_step_count'] == 0,
            'SUPPORT_TERMINAL')
    files = [entry_profile.runtime.file_identity(path) for path in sorted(diagnostic_root.iterdir()) if path.is_file()]
    source_paths = ['sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json',
                    'sdk/recovery/r24d127_godot_jolt_solver_coupled_controller_contract_v1.json',
                    'sdk/core/src/recovery.rs', 'sdk/core/src/recovery_runtime.rs']
    return dict(schema_version='sporespore_development_measured_entry_support_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', question_class='development',
                          authority_mode='post_exposure_retained_data_diagnosis'),
        status='closed_separate_replay_passed_support_timeout_described',
        original_failure_checkpoint=dict(path=original_path.relative_to(entry_profile.ROOT).as_posix(), raw_sha256=sha(original_path)),
        original_attempt_status=original['status'], original_attempt_reclassified=False,
        original_report=dict(path=report_path.as_posix(), raw_sha256=sha(report_path), byte_length=report_path.stat().st_size),
        diagnostic_root=diagnostic_root.as_posix(), independent_replay=replay,
        retained_diagnostic_population=dict(file_count=len(files), byte_length=sum(row['byte_length'] for row in files), files=files),
        rule_sources=[_support_rule_identity(path) for path in source_paths],
        metrics=metrics, terminal_reason=state['terminal_reason'], walking_resume_step_count=0,
        descriptive_conclusion='The active support-pose sequence never attains simultaneous four-foot bearing; the torso overturns and settles upside down while joints approach their commanded targets.',
        causal_attribution_proven=False, successful_recovery_proven=False, complete_route_proven=False,
        new_world_build_count=0, new_native_physics_read_count=0, new_solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False, repeat_consumed_attempt_permitted=False)


def retained_entry_pose_comparison():
    """Compare two retained development starts, not a matched causal trial."""
    import math
    root = entry_profile.ROOT
    positive_closure_path = root / 'sdk/recovery/r24d172_godot_jolt_initializer_receipt_retention_recovery_behavior_physical_closure_v1.json'
    require(sha(positive_closure_path) == 'sha256:87b0c9497ab4fa91da8d58f9cba1be9ab906a0d2603cedd5b8abc92231f36fe8', 'ENTRY_COMPARISON_POSITIVE_CLOSURE')
    positive_closure = read(positive_closure_path)
    positive_path = Path(positive_closure['physical_attempt']['evidence_root']) / 'raw_result.json'
    require(sha(positive_path) == 'sha256:b36c0b091ae1142d7d9bc71f7aea99e99f1ac0133e8c9b90a29636a005c18b00', 'ENTRY_COMPARISON_POSITIVE_RAW')
    positive = read(positive_path)['candidate_arm']
    require(legacy.canonical_sha256_v1(positive['trace_v3']) == positive['trace_v3_sha256'] and positive['final_phase'] == 'complete',
            'ENTRY_COMPARISON_POSITIVE_TRACE')
    diagnosis_path = root / 'sdk/development_measured_entry_support_diagnosis_v1.json'
    diagnosis = read(diagnosis_path)
    observed_diagnosis = retained_measured_entry_support_diagnosis(Path(diagnosis['diagnostic_root']))
    validate_checkpoint(diagnosis, observed_diagnosis)
    negative_path = Path(diagnosis['original_report']['path'])
    negative = read(negative_path)
    positive_active = next(row for row in positive['command_application_receipts'] if row['no_actuation_requested'] is False)
    canonical = negative['passive_entry']['canonical_packets']
    negative_active = next(row for row in canonical if row['application']['no_actuation_requested'] is False)
    positive_before = next(row for row in positive['trace_v3']['observations'] if row['semantic_step'] == positive_active['semantic_step'] - 1)
    negative_before_packet = next(row for row in canonical if row['global_semantic_step'] == negative_active['global_semantic_step'] - 1)
    negative_before = packet.parse_json(negative_before_packet['collection_transport']['source_links']['bound_observation']['utf8_text'])['observation_v3']
    targets = diagnosis['metrics']['ordered_support_targets_rad']
    joints = []
    for index, (good, failed, target) in enumerate(zip(positive_before['state']['ordered_joint_observations'],
                                                       negative_before['state']['ordered_joint_observations'], targets)):
        require(good['joint_id'] == failed['joint_id'], 'ENTRY_COMPARISON_JOINT_ORDER')
        joints.append(dict(joint_id=good['joint_id'], canonical_entry_rad=good['position_rad'], fallen_entry_rad=failed['position_rad'],
            absolute_entry_difference_degrees=abs(good['position_rad'] - failed['position_rad']) * 180.0 / math.pi,
            unchanged_v6_support_target_rad=target, proposed_v7_support_target_rad=-target if index < 4 else target))
    require(len(joints) == 8 and positive_active['command_sha256'] == negative_active['application']['command_sha256'],
            'ENTRY_COMPARISON_SAME_INITIAL_COMMAND')
    def entry(observation, first_active_step):
        state = observation['state']
        q = state['base_pose_world']['orientation_xyzw']
        return dict(last_passive_step=observation['semantic_step'], first_active_step=first_active_step,
            torso_height_m=state['base_pose_world']['position_m']['y'], torso_up_dot=1.0 - 2.0 * (q['x']**2 + q['z']**2),
            angular_speed_rad_s=math.sqrt(sum(v*v for v in state['base_twist_world']['angular_velocity_rad_s'].values())),
            linear_speed_m_s=math.sqrt(sum(v*v for v in state['base_twist_world']['linear_velocity_m_s'].values())))
    return dict(schema_version='sporespore_development_rearward_fold_support_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt_retained_comparison_engine_neutral_candidate',
                          authority_mode='post_exposure_comparison_and_prospective_development_design', question_class='development'),
        authored_parent_commit=SUPPORT_DIAGNOSIS_RULE_COMMIT,
        sources=[entry_profile.runtime.file_identity(path) for path in (positive_closure_path, positive_path, diagnosis_path, negative_path)],
        canonical_entry=entry(positive_before, positive_active['semantic_step']),
        fallen_entry=entry(negative_before, negative_active['global_semantic_step']), joint_comparison=joints,
        initial_support_command_sha256=positive_active['command_sha256'], matched_causal_comparison=False,
        causal_attribution_proven=False, historical_results_reinterpreted=False,
        prospective_controller=dict(controller_id='sporespore_exact_s169_prone_to_standing_controller_v7',
            profile_id='sporespore_exact_s169_rearward_fold_recovery_development_v7',
            support_targets_rad=[row['proposed_v7_support_target_rad'] for row in joints],
            rule='Fixed rearward-fold support variant; mirror only the two front hip/knee target pairs, and interpolate this support pose to the unchanged zero-joint stance target.',
            automatic_pose_selection=False, engine_identity_input_count=0, threshold_changes=0,
            speed_changes=0, actuator_cap_changes=0, timeout_changes=0, ramp_duration_changes=0,
            physical_suitability_proven=False, native_worker_integrated=False),
        question='Does this fixed mirrored-front-leg support variant reach four-foot support from the observed rearward-folded post-kick entry without the recorded overturn?',
        scope='One bounded prospective development variant, not general prone recovery, force-aware recovery, a changed acceptance gate, or a replacement for V6.',
        new_world_build_count=0, new_native_physics_read_count=0, new_solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    parser.add_argument('--checkpoint', type=Path, help='Verify a compact retained receipt; read-only, no physics')
    args = parser.parse_args()
    try:
        if args.checkpoint:
            checkpoint = retained_checkpoint(args.root)
            validate_checkpoint(read(args.checkpoint), checkpoint)
            result = dict(checkpoint['observed'], retained_checkpoint_verified=True,
                          retained_population=checkpoint['retained_population'])
        else:
            result = audit(args.root)
    except (ValueError, KeyError, TypeError, OSError, legacy.ClosureFailure) as exc:
        print(json.dumps(dict(ok=False, failure_code=str(exc), physical_acceptance_authority=False, release_authority=False)))
        return 1
    print(json.dumps(result, allow_nan=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
