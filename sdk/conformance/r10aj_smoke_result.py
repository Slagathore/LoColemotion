"""R10AJ physical-report boundaries and diagnostic-only result aggregation."""
from pathlib import Path

import r10aj_development as identity
import r10aj_physical_identity as physical_identity
import r10aj_native_world_authority as authority
import r10aj_replay_host as replay_host
from qsdk_r10f_l15_collection_retention import same


def require(ok, code):
    if not ok: raise ValueError('R10AJ_SMOKE_' + code)


def validate_header(report, declaration):
    physical_identity.require_physical_declaration(declaration)
    population = identity.validate_declaration(declaration)
    identity.validate_report_header(report, declaration)
    require(not any(key in report for key in ('r10ai_development', 'r10ag_development', 'r10af_development', 'r10ae_development', 'r10ad_development', 'r10ac_development', 'r10ab_development', 'r10v_development')), 'CROSSED_REPORT_CONTEXT')
    sessions = [s for s in report.get('retained_arm', {}).get('walking_sessions', [])
        if s.get('evaluation_segment_id') == 'walking_prefix']
    require(len(sessions) == 1, 'PREFIX_POPULATION')
    receipt = sessions[0].get('start_receipt', {})
    require(same(receipt.get('initial_gait_steps'), dict.fromkeys(('front_left', 'front_right', 'rear_left', 'rear_right'), 248)), 'PREFIX_PHASE')
    require(same(receipt.get('development_prefix_phase_selection'),
        identity.prefix_selection(identity.SEED, identity.PREFIX_PROFILE)), 'PREFIX_PROVENANCE')
    claim = report.get('r10aj_native_world_claim')
    child = declaration['children'][0]
    require(type(claim) is dict and set(claim) == {'claim_binding', 'world_permission_consumed',
        'maximum_world_builds', 'physical_acceptance_authority', 'release_authority'}, 'CLAIM_SHAPE')
    require(claim.get('world_permission_consumed') is True and same(claim.get('maximum_world_builds'), 1)
        and claim.get('physical_acceptance_authority') is False and claim.get('release_authority') is False,
        'CLAIM_PERMISSION')
    bound = claim.get('claim_binding')
    require(type(bound) is dict and set(bound) == {'path', 'raw_sha256'}
        and bound.get('path') == (Path(child['evidence_path']) / authority.CLAIM).as_posix()
        and type(bound.get('raw_sha256')) is str and len(bound['raw_sha256']) == 71
        and bound['raw_sha256'].startswith('sha256:')
        and all(c in '0123456789abcdef' for c in bound['raw_sha256'][7:]), 'CLAIM_PATH_OR_HASH')
    return population


def verify_physical_claim(report, declaration_path, pid):
    actual = authority.verify(declaration_path, pid)
    require(same(report['r10aj_native_world_claim']['claim_binding'], actual), 'RETAINED_CLAIM')
    return actual


def diagnostic_replay(report, declaration_path, replay):
    # A full controller replay and the independent contact reader are mandatory.
    expected = replay_host.independent_result(report, declaration_path, replay)
    require(expected['diagnostic_steps_replayed'] == report['solver_step_count'], 'CONTACT_STEP_POPULATION')
    return expected


def finite_result(declaration, cells, children):
    identity.validate_declaration(declaration)
    require(type(cells) is list and len(cells) == 1 and cells[0].get('role') == identity.ROLE, 'RESULT_POPULATION')
    cell = cells[0]
    require(type(cell.get('finite_task_predicates_passed')) is bool
        and cell.get('child_attempt_id') == declaration['children'][0]['child_attempt_id'], 'RESULT_CHILD')
    require(type(children) is list and len(children) == 1 and children[0].get('role') == identity.ROLE,
        'RESULT_CONTACT_POPULATION')
    contact = children[0].get('r10af_contact_frame_replay')
    require(type(contact) is dict and contact.get('ok') is True
        and type(contact.get('classification_changes')) is int and contact['classification_changes'] >= 0
        and type(contact.get('matched_source_contacts')) is int and contact['matched_source_contacts'] >= contact['classification_changes']
        and contact.get('diagnostic_steps_replayed') == children[0].get('solver_steps')
        and contact.get('controller_observation_changed') is True
        and contact.get('physical_acceptance_authority') is False and contact.get('release_authority') is False,
        'RESULT_CONTACT_REPLAY')
    return dict(schema_version='sporespore_r10aj_contact_frame_diagnostic_result_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='bounded_contact_frame_diagnostic_result', question_class='development'),
        seed=identity.SEED, prefix_phase=identity.PHASE, candidate_profile=declaration['candidate_profile'], cells=cells,
        contact_frame_replay=contact, all_tasks_positive=cell['finite_task_predicates_passed'],
        branch_coverage_complete=cell.get('entry_kind') == 'partial',
        causal_repair_proven=False, paired_commissioning_satisfied=False, comparative_authority=False,
        baseline_reused=False, physical_acceptance_authority=False, release_authority=False)
