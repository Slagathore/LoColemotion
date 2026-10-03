"""Declared R10U development population and finite results; no acceptance lane."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import qsdk_r10f_l15_collection_retention as packet

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
DESIGN = ROOT / 'sdk/recovery/r10u_audit_handoff_design_v1.json'
DESIGN_SHA = 'sha256:81f18c3e99929ee02c830f973c32c3db4fdb5917a5efa2863d59e5ee2a7fa981'
ROUTE = 'r10u_v56_post_recovery_hold_route_v1'
ROLES = ['matched_no_kick_continuation', 'kick_passive_recovery_resume']
PAIR = 'fresh_paired_development_diagnostic_v1'
SINGLE = 'single_kick_controller_diagnostic_v1'
CONTEXT_SCHEMA = 'sporespore_r10u_development_child_context_v1'
RESULT_SCHEMA = 'sporespore_r10u_finite_development_result_v1'
CONTEXT_KEYS = {'schema_version', 'source_commit', 'candidate_profile', 'design_binding', 'seed',
    'required_entry_kind', 'required_handoff', 'stage', 'prerequisite_pair', 'physical_acceptance_authority', 'release_authority'}


def require(ok, code):
    if not ok:
        raise ValueError('R10U_DEVELOPMENT_' + code)


def read(path):
    return packet.parse_json(Path(path).read_text(encoding='utf-8'))


def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def seed_identity(seed):
    require(type(seed) is int and seed in (41245, 41246, 41241, 41243), 'UNDECLARED_SEED')
    phase = {41245: 245, 41246: 246, 41241: 241, 41243: 243}[seed]
    label = 'R10U-DEVELOPMENT-PREFIX-' + str(phase) + '-V1'
    return dict(seed=seed, label=label, sha256='sha256:' + hashlib.sha256(label.encode()).hexdigest(), prefix_phase=phase)


def positive_result(result, candidate_reference, *, paired):
    """Shape validation only; launch qualification also reconstructs the audit."""
    # R10U starts with a matched pair. No single-child result can open its chain.
    if paired is not True:
        return False
    if type(result) is not dict or result.get('schema_version') != RESULT_SCHEMA:
        return False
    if not packet.same(result.get('candidate_profile'), candidate_reference) or not packet.same(result.get('seed'), 41245):
        return False
    cells = result.get('cells')
    roles = ROLES if paired else [ROLES[1]]
    return (result.get('all_tasks_positive') is True and result.get('branch_coverage_complete') is True
        and result.get('physical_acceptance_authority') is False and result.get('release_authority') is False
        and type(cells) is list and len(cells) == len(roles)
        and all(type(c) is dict for c in cells) and [c.get('role') for c in cells] == roles
        and all(c.get('finite_task_predicates_passed') is True for c in cells)
        and cells[-1].get('post_recovery_handoff') == 'bounded_hold'
        and (cells[0].get('entry_kind') == 'unselected' and cells[1].get('entry_kind') == 'upright'
             if paired else cells[0].get('entry_kind') == 'upright'))


def qualify_prerequisite(root, candidate_reference, *, paired):
    """Reconstruct the required earlier stage, including its real launch audit."""
    require(paired is True, 'ONLY_PAIR_PREREQUISITE')
    root = Path(root).resolve()
    require(root.parent == EVIDENCE.resolve() and re.fullmatch(r'development-recovery-smoke-[0-9a-f]{32}', root.name), 'PREREQUISITE_ROOT')
    declaration = read(root / 'declaration.json')
    required_stage = 'paired_commissioning'
    require(declaration.get('seed') == 41245 and declaration.get('r10u_development', {}).get('stage') == required_stage,
            'PREREQUISITE_CYCLE_OR_POPULATION')
    require(declaration.get('development_execution_mode') == (PAIR if paired else SINGLE), 'PREREQUISITE_MODE')
    import development_recovery_smoke as smoke
    checkpoint = smoke.retained_checkpoint(root)
    require(positive_result(checkpoint['observed'].get('r10u_finite_development'), candidate_reference, paired=paired), 'PREREQUISITE_NOT_POSITIVE')
    supervisor = read(root / 'supervisor_result.json')
    require(supervisor.get('ok') is True and supervisor.get('failure_code') == '', 'PREREQUISITE_SUPERVISOR_FAILURE')
    path = root / 'independent_audit.stdout.json'
    return dict(path=path.as_posix(), raw_sha256=sha(path), attempt_id=declaration['attempt_id'])


def context(mode, source_commit, candidate_reference, prerequisite_root=None, diagnostic_seed=None):
    require(mode in (PAIR, SINGLE) and re.fullmatch(r'[0-9a-f]{40}', source_commit), 'MODE_OR_SOURCE')
    require(sha(DESIGN) == DESIGN_SHA, 'DESIGN_DRIFT')
    seed = 41245 if diagnostic_seed is None else diagnostic_seed
    require(type(seed) is int and (seed == 41245 if mode == PAIR else seed in (41246,41241,41243)), 'MODE_SEED')
    pair = None
    if mode == PAIR:
        require(prerequisite_root is None, 'INITIAL_PAIR_HAS_PREREQUISITE')
        stage = 'paired_commissioning'
    else:
        require(prerequisite_root is not None, 'ADDITIONAL_SINGLE_REQUIRES_POSITIVE_PAIR')
        stage = 'additional_branch_diagnostic'
        pair = qualify_prerequisite(prerequisite_root, candidate_reference, paired=True)
    return dict(schema_version=CONTEXT_SCHEMA, source_commit=source_commit, candidate_profile=candidate_reference,
        design_binding=dict(resource='res://sdk/recovery/r10u_audit_handoff_design_v1.json', raw_sha256=DESIGN_SHA),
        seed=seed_identity(seed), required_entry_kind={41245:'upright',41246:'upright',41241:'partial',41243:'prone'}[seed],
        required_handoff='bounded_hold' if seed == 41245 else 'direct',
        stage=stage, prerequisite_pair=pair,
        physical_acceptance_authority=False, release_authority=False)


def validate_context(value, declaration, *, verify_prerequisite=True):
    require(type(value) is dict and set(value) == CONTEXT_KEYS and value['schema_version'] == CONTEXT_SCHEMA, 'CONTEXT_SHAPE')
    require('r10t_development' not in declaration and 'r10s_development' not in declaration and 'r10r_development' not in declaration and 'r10q_development' not in declaration and 'r10p_campaign' not in declaration and 'r10o_development' not in declaration and 'r10j_campaign' not in declaration and 'r10k_development' not in declaration and 'r10l_development' not in declaration and 'r10n_development' not in declaration and 'r10m_development' not in declaration and sha(DESIGN) == DESIGN_SHA, 'CROSSED_CAMPAIGN_OR_DESIGN')
    mode = declaration.get('development_execution_mode')
    require(mode in (PAIR, SINGLE), 'MODE')
    seed = declaration.get('seed')
    require(type(seed) is int and (seed == 41245 if mode == PAIR else seed in (41246, 41241, 41243)), 'MODE_SEED')
    require(packet.same(value['seed'], seed_identity(seed)) and packet.same(declaration.get('seed'), seed), 'SEED_BINDING')
    require(value['required_entry_kind'] == {41245: 'upright', 41246: 'upright', 41241: 'partial', 41243: 'prone'}[seed], 'BRANCH_BINDING')
    require(value['required_handoff'] == ('bounded_hold' if seed == 41245 else 'direct'), 'HANDOFF_BINDING')
    require(value['physical_acceptance_authority'] is False and value['release_authority'] is False, 'AUTHORITY')
    require(packet.same(value['design_binding'], dict(resource='res://sdk/recovery/r10u_audit_handoff_design_v1.json', raw_sha256=DESIGN_SHA)), 'DESIGN_BINDING')
    head = declaration.get('source_snapshot', {}).get('head')
    require(type(head) is str and re.fullmatch(r'[0-9a-f]{40}', head) and value['source_commit'] == head, 'SOURCE_BINDING')
    require(packet.same(value['candidate_profile'], declaration.get('candidate_profile')), 'CANDIDATE_BINDING')
    roles = ROLES if mode == PAIR else [ROLES[1]]
    children = declaration.get('children')
    require(type(children) is list and [c.get('role') for c in children] == roles, 'ROLE_POPULATION')
    attempt = declaration.get('attempt_id')
    require(type(attempt) is str and re.fullmatch(r'[0-9a-f]{32}', attempt), 'ATTEMPT_ID')
    seen = set()
    for child in children:
        for field in ('child_attempt_id', 'termination_nonce'):
            value_id = child.get(field)
            require(type(value_id) is str and re.fullmatch(r'[0-9a-f]{32}', value_id) and value_id not in seen and value_id != attempt, 'CHILD_ID_REUSE')
            seen.add(value_id)
        expected = EVIDENCE / ('development-recovery-smoke-' + attempt) / 'children' / child['role']
        require(Path(child['evidence_path']).resolve() == expected.resolve(), 'CHILD_PATH')
    initial = mode == PAIR
    expected_stage = 'paired_commissioning' if initial else 'additional_branch_diagnostic'
    require(value['stage'] == expected_stage, 'STAGE')
    if initial:
        require(value['prerequisite_pair'] is None, 'INITIAL_PAIR_HAS_PREREQUISITE')
    else:
        bound = value['prerequisite_pair']
        require(type(bound) is dict and set(bound) == {'path','raw_sha256','attempt_id'} and
                type(bound['attempt_id']) is str and re.fullmatch(r'[0-9a-f]{32}', bound['attempt_id']) and bound['attempt_id'] != attempt,
                'PREREQUISITE_BINDING')
        path = Path(bound['path']).resolve()
        require(path.name == 'independent_audit.stdout.json' and path.parent.name == 'development-recovery-smoke-' + bound['attempt_id']
            and path.parent.parent == EVIDENCE.resolve() and sha(path) == bound['raw_sha256'], 'PREREQUISITE_BYTES')
        require(positive_result(read(path).get('r10u_finite_development'), declaration['candidate_profile'], paired=True), 'PREREQUISITE_RESULT')
        if verify_prerequisite:
            require(packet.same(qualify_prerequisite(path.parent, declaration['candidate_profile'], paired=True), bound), 'PREREQUISITE_REAUDIT')
    return dict(seed=seed, identity=seed_identity(seed), roles=roles, required_entry_kind=value['required_entry_kind'], required_handoff=value['required_handoff'])


def validate_declaration(declaration):
    import development_recovery_candidate as candidate
    selected = candidate.selection(declaration.get('candidate_profile'))
    require(selected.get('diagnostic_schedule', {}).get('walking_policy_id') == ROUTE, 'ROUTE')
    return validate_context(declaration.get('r10u_development'), declaration)


def validate_report_header(report, declaration, population):
    require(packet.same(report.get('r10u_development'), declaration['r10u_development']), 'REPORT_CONTEXT')
    identity = population['identity']
    require(report.get('seed_label') == identity['label'] and report.get('seed_sha256') == identity['sha256']
        and packet.same(report.get('held_out_cell_access_count'), 0), 'REPORT_SEED')
    arm = report.get('retained_arm', {})
    prefixes = [s for s in arm.get('walking_sessions', []) if s.get('evaluation_segment_id') == 'walking_prefix']
    require(len(prefixes) == 1, 'PREFIX_SESSION_POPULATION')
    # The independently replayed start contract binds the explicit non-modulo phase.
    phase = identity['prefix_phase']
    receipt = prefixes[0].get('start_receipt', {})
    require(packet.same(receipt.get('initial_gait_steps'), dict.fromkeys(('front_left', 'front_right', 'rear_left', 'rear_right'), phase)), 'PREFIX_PHASE')
    require(packet.same(receipt.get('development_prefix_phase_selection'), dict(
        schema_version='sporespore_r10u_prefix_phase_selection_v1', profile_id='r10u_declared_development_prefix_phase_v1',
        seed=identity['seed'], prefix_phase=phase, source_design_sha256=DESIGN_SHA,
        physical_acceptance_authority=False, release_authority=False)), 'PREFIX_SELECTION_SOURCE')


def finite_result(declaration, cells):
    population = validate_context(declaration['r10u_development'], declaration, verify_prerequisite=False)
    require([c.get('role') for c in cells] == population['roles'], 'RESULT_POPULATION')
    require(all(type(c.get('finite_task_predicates_passed')) is bool for c in cells), 'RESULT_DOMAIN')
    active = next(c for c in cells if c['role'] == ROLES[1])
    return dict(schema_version=RESULT_SCHEMA, ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='bounded_development_result', question_class='development'), seed=population['seed'], prefix_phase=population['identity']['prefix_phase'],
        candidate_profile=declaration['candidate_profile'], cells=cells,
        all_tasks_positive=all(c['finite_task_predicates_passed'] for c in cells),
        branch_coverage_complete=(active['entry_kind'] == population['required_entry_kind']
            and active.get('post_recovery_handoff') == population['required_handoff']),
        required_handoff=population['required_handoff'],
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', required=True, choices=[PAIR, SINGLE])
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--candidate-resource', required=True)
    parser.add_argument('--candidate-sha256', required=True)
    parser.add_argument('--prerequisite-root')
    parser.add_argument('--diagnostic-seed', type=int, choices=[41245, 41246, 41241, 41243])
    args = parser.parse_args()
    value = context(args.mode, args.source_commit, dict(resource=args.candidate_resource, raw_sha256=args.candidate_sha256), args.prerequisite_root, args.diagnostic_seed)
    print(json.dumps(value, separators=(',', ':')))
