"""Declared R10S development population and finite results; no acceptance lane."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import qsdk_r10f_l15_collection_retention as packet

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
DESIGN = ROOT / 'sdk/recovery/r10s_extended_preparation_design_v1.json'
DESIGN_SHA = 'sha256:a34411ee9608133c5b755dff8a273423e8f10f053803fa74150af1d8305506c2'
ROUTE = 'r10s_v56_upright_recovery_route_v1'
ROLES = ['matched_no_kick_continuation', 'kick_passive_recovery_resume']
PAIR = 'fresh_paired_development_diagnostic_v1'
SINGLE = 'single_kick_controller_diagnostic_v1'
CONTEXT_SCHEMA = 'sporespore_r10s_development_child_context_v1'
RESULT_SCHEMA = 'sporespore_r10s_finite_development_result_v1'
CONTEXT_KEYS = {'schema_version', 'source_commit', 'candidate_profile', 'design_binding', 'seed',
    'required_entry_kind', 'stage', 'prerequisite_single_diagnostic', 'prerequisite_pair', 'physical_acceptance_authority', 'release_authority'}


def require(ok, code):
    if not ok:
        raise ValueError('R10S_DEVELOPMENT_' + code)


def read(path):
    return packet.parse_json(Path(path).read_text(encoding='utf-8'))


def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def seed_identity(seed):
    require(type(seed) is int and seed in (41046, 41045, 41041, 41043), 'UNDECLARED_SEED')
    phase = {41046: 246, 41045: 245, 41041: 241, 41043: 243}[seed]
    label = 'R10S-DEVELOPMENT-PREFIX-' + str(phase) + '-V1'
    return dict(seed=seed, label=label, sha256='sha256:' + hashlib.sha256(label.encode()).hexdigest(), prefix_phase=phase)


def positive_result(result, candidate_reference, *, paired):
    """Shape validation only; launch qualification also reconstructs the audit."""
    if type(result) is not dict or result.get('schema_version') != RESULT_SCHEMA:
        return False
    if not packet.same(result.get('candidate_profile'), candidate_reference) or not packet.same(result.get('seed'), 41046):
        return False
    cells = result.get('cells')
    roles = ROLES if paired else [ROLES[1]]
    return (result.get('all_tasks_positive') is True and result.get('branch_coverage_complete') is True
        and result.get('physical_acceptance_authority') is False and result.get('release_authority') is False
        and type(cells) is list and len(cells) == len(roles)
        and all(type(c) is dict for c in cells) and [c.get('role') for c in cells] == roles
        and all(c.get('finite_task_predicates_passed') is True for c in cells)
        and (cells[0].get('entry_kind') == 'unselected' and cells[1].get('entry_kind') == 'upright'
             if paired else cells[0].get('entry_kind') == 'upright'))


def qualify_prerequisite(root, candidate_reference, *, paired):
    """Reconstruct the required earlier stage, including its real launch audit."""
    root = Path(root).resolve()
    require(root.parent == EVIDENCE.resolve() and re.fullmatch(r'development-recovery-smoke-[0-9a-f]{32}', root.name), 'PREREQUISITE_ROOT')
    declaration = read(root / 'declaration.json')
    required_stage = 'paired_commissioning' if paired else 'initial_single_diagnostic'
    require(declaration.get('seed') == 41046 and declaration.get('r10s_development', {}).get('stage') == required_stage,
            'PREREQUISITE_CYCLE_OR_POPULATION')
    require(declaration.get('development_execution_mode') == (PAIR if paired else SINGLE), 'PREREQUISITE_MODE')
    import development_recovery_smoke as smoke
    checkpoint = smoke.retained_checkpoint(root)
    require(positive_result(checkpoint['observed'].get('r10s_finite_development'), candidate_reference, paired=paired), 'PREREQUISITE_NOT_POSITIVE')
    supervisor = read(root / 'supervisor_result.json')
    require(supervisor.get('ok') is True and supervisor.get('failure_code') == '', 'PREREQUISITE_SUPERVISOR_FAILURE')
    path = root / 'independent_audit.stdout.json'
    return dict(path=path.as_posix(), raw_sha256=sha(path), attempt_id=declaration['attempt_id'])


def context(mode, source_commit, candidate_reference, prerequisite_root=None, diagnostic_seed=None):
    require(mode in (PAIR, SINGLE) and re.fullmatch(r'[0-9a-f]{40}', source_commit), 'MODE_OR_SOURCE')
    require(sha(DESIGN) == DESIGN_SHA, 'DESIGN_DRIFT')
    seed = 41046 if diagnostic_seed is None else diagnostic_seed
    require(type(seed) is int and seed in (41046,41045,41041,41043) and (mode != PAIR or seed == 41046), 'MODE_SEED')
    single, pair = None, None
    if mode == PAIR:
        require(prerequisite_root is not None, 'PAIR_REQUIRES_POSITIVE_SINGLE')
        stage = 'paired_commissioning'
        single = qualify_prerequisite(prerequisite_root, candidate_reference, paired=False)
    elif seed == 41046:
        require(prerequisite_root is None, 'INITIAL_SINGLE_HAS_PREREQUISITE')
        stage = 'initial_single_diagnostic'
    else:
        require(prerequisite_root is not None, 'ADDITIONAL_SINGLE_REQUIRES_POSITIVE_PAIR')
        stage = 'additional_branch_diagnostic'
        pair = qualify_prerequisite(prerequisite_root, candidate_reference, paired=True)
    return dict(schema_version=CONTEXT_SCHEMA, source_commit=source_commit, candidate_profile=candidate_reference,
        design_binding=dict(resource='res://sdk/recovery/r10s_extended_preparation_design_v1.json', raw_sha256=DESIGN_SHA),
        seed=seed_identity(seed), required_entry_kind={41046:'upright',41045:'upright',41041:'partial',41043:'prone'}[seed],
        stage=stage, prerequisite_single_diagnostic=single, prerequisite_pair=pair,
        physical_acceptance_authority=False, release_authority=False)


def validate_context(value, declaration, *, verify_prerequisite=True):
    require(type(value) is dict and set(value) == CONTEXT_KEYS and value['schema_version'] == CONTEXT_SCHEMA, 'CONTEXT_SHAPE')
    require('r10r_development' not in declaration and 'r10q_development' not in declaration and 'r10p_campaign' not in declaration and 'r10o_development' not in declaration and 'r10j_campaign' not in declaration and 'r10k_development' not in declaration and 'r10l_development' not in declaration and 'r10n_development' not in declaration and 'r10m_development' not in declaration and sha(DESIGN) == DESIGN_SHA, 'CROSSED_CAMPAIGN_OR_DESIGN')
    mode = declaration.get('development_execution_mode')
    require(mode in (PAIR, SINGLE), 'MODE')
    seed = declaration.get('seed')
    require(type(seed) is int and (seed == 41046 if mode == PAIR else seed in (41046, 41045, 41041, 41043)), 'MODE_SEED')
    require(packet.same(value['seed'], seed_identity(seed)) and packet.same(declaration.get('seed'), seed), 'SEED_BINDING')
    require(value['required_entry_kind'] == {41046: 'upright', 41045: 'upright', 41041: 'partial', 41043: 'prone'}[seed], 'BRANCH_BINDING')
    require(value['physical_acceptance_authority'] is False and value['release_authority'] is False, 'AUTHORITY')
    require(packet.same(value['design_binding'], dict(resource='res://sdk/recovery/r10s_extended_preparation_design_v1.json', raw_sha256=DESIGN_SHA)), 'DESIGN_BINDING')
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
    initial = mode == SINGLE and seed == 41046
    expected_stage = 'initial_single_diagnostic' if initial else 'paired_commissioning' if mode == PAIR else 'additional_branch_diagnostic'
    require(value['stage'] == expected_stage, 'STAGE')
    if initial:
        require(value['prerequisite_single_diagnostic'] is None and value['prerequisite_pair'] is None, 'INITIAL_SINGLE_HAS_PREREQUISITE')
    else:
        paired = mode == SINGLE
        active_key = 'prerequisite_pair' if paired else 'prerequisite_single_diagnostic'
        inactive_key = 'prerequisite_single_diagnostic' if paired else 'prerequisite_pair'
        require(value[inactive_key] is None, 'CROSSED_PREREQUISITE_STAGE')
        bound = value[active_key]
        require(type(bound) is dict and set(bound) == {'path','raw_sha256','attempt_id'} and
                type(bound['attempt_id']) is str and re.fullmatch(r'[0-9a-f]{32}', bound['attempt_id']) and bound['attempt_id'] != attempt,
                'PREREQUISITE_BINDING')
        path = Path(bound['path']).resolve()
        require(path.name == 'independent_audit.stdout.json' and path.parent.name == 'development-recovery-smoke-' + bound['attempt_id']
            and path.parent.parent == EVIDENCE.resolve() and sha(path) == bound['raw_sha256'], 'PREREQUISITE_BYTES')
        require(positive_result(read(path).get('r10s_finite_development'), declaration['candidate_profile'], paired=paired), 'PREREQUISITE_RESULT')
        if verify_prerequisite:
            require(packet.same(qualify_prerequisite(path.parent, declaration['candidate_profile'], paired=paired), bound), 'PREREQUISITE_REAUDIT')
    return dict(seed=seed, identity=seed_identity(seed), roles=roles, required_entry_kind=value['required_entry_kind'])


def validate_declaration(declaration):
    import development_recovery_candidate as candidate
    selected = candidate.selection(declaration.get('candidate_profile'))
    require(selected.get('diagnostic_schedule', {}).get('walking_policy_id') == ROUTE, 'ROUTE')
    return validate_context(declaration.get('r10s_development'), declaration)


def validate_report_header(report, declaration, population):
    require(packet.same(report.get('r10s_development'), declaration['r10s_development']), 'REPORT_CONTEXT')
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
        schema_version='sporespore_r10s_prefix_phase_selection_v1', profile_id='r10s_declared_development_prefix_phase_v1',
        seed=identity['seed'], prefix_phase=phase, source_design_sha256=DESIGN_SHA,
        physical_acceptance_authority=False, release_authority=False)), 'PREFIX_SELECTION_SOURCE')


def finite_result(declaration, cells):
    population = validate_context(declaration['r10s_development'], declaration, verify_prerequisite=False)
    require([c.get('role') for c in cells] == population['roles'], 'RESULT_POPULATION')
    require(all(type(c.get('finite_task_predicates_passed')) is bool for c in cells), 'RESULT_DOMAIN')
    active = next(c for c in cells if c['role'] == ROLES[1])
    return dict(schema_version=RESULT_SCHEMA, seed=population['seed'], prefix_phase=population['identity']['prefix_phase'],
        candidate_profile=declaration['candidate_profile'], cells=cells,
        all_tasks_positive=all(c['finite_task_predicates_passed'] for c in cells),
        branch_coverage_complete=active['entry_kind'] == population['required_entry_kind'],
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', required=True, choices=[PAIR, SINGLE])
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--candidate-resource', required=True)
    parser.add_argument('--candidate-sha256', required=True)
    parser.add_argument('--prerequisite-root')
    parser.add_argument('--diagnostic-seed', type=int, choices=[41046, 41045, 41041, 41043])
    args = parser.parse_args()
    value = context(args.mode, args.source_commit, dict(resource=args.candidate_resource, raw_sha256=args.candidate_sha256), args.prerequisite_root, args.diagnostic_seed)
    print(json.dumps(value, separators=(',', ':')))
