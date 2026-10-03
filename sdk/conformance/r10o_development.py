"""Declared R10O development population and finite results; no acceptance lane."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import qsdk_r10f_l15_collection_retention as packet

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
DESIGN = ROOT / 'sdk/recovery/r10o_initialized_zero_brake_successor_design_v1.json'
DESIGN_SHA = 'sha256:9a4bb652285cbf468568a6313405bf034d2fdd7944a08c19671c78dd5c648a2b'
ROUTE = 'r10o_v55_partial_fall_recovery_route_v1'
ROLES = ['matched_no_kick_continuation', 'kick_passive_recovery_resume']
PAIR = 'fresh_paired_development_diagnostic_v1'
SINGLE = 'single_kick_controller_diagnostic_v1'
CONTEXT_SCHEMA = 'sporespore_r10o_development_child_context_v1'
RESULT_SCHEMA = 'sporespore_r10o_finite_development_result_v1'
CONTEXT_KEYS = {'schema_version', 'source_commit', 'candidate_profile', 'design_binding', 'seed',
    'required_entry_kind', 'prerequisite_pair', 'physical_acceptance_authority', 'release_authority'}


def require(ok, code):
    if not ok:
        raise ValueError('R10O_DEVELOPMENT_' + code)


def read(path):
    return packet.parse_json(Path(path).read_text(encoding='utf-8'))


def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def seed_identity(seed):
    require(type(seed) is int and seed in (40741, 40743), 'UNDECLARED_SEED')
    phase = {40741: 241, 40743: 243}[seed]
    label = 'R10O-DEVELOPMENT-PREFIX-' + str(phase) + ('-PAIR-V1' if seed == 40741 else '-SINGLE-KICK-V1')
    return dict(seed=seed, label=label, sha256='sha256:' + hashlib.sha256(label.encode()).hexdigest(), prefix_phase=phase)


def positive_pair_result(result, candidate_reference):
    """A shape check, downstream of exact retained audit validation."""
    if type(result) is not dict or result.get('schema_version') != RESULT_SCHEMA:
        return False
    if not packet.same(result.get('candidate_profile'), candidate_reference) or result.get('seed') != 40741:
        return False
    cells = result.get('cells')
    return (result.get('all_tasks_positive') is True and result.get('branch_coverage_complete') is True
        and result.get('physical_acceptance_authority') is False and result.get('release_authority') is False
        and type(cells) is list and len(cells) == 2 and [c.get('role') for c in cells] == ROLES
        and all(c.get('finite_task_predicates_passed') is True for c in cells)
        and cells[0].get('entry_kind') == 'unselected' and cells[1].get('entry_kind') == 'partial')


def qualify_prerequisite(root, candidate_reference):
    """Re-audit a completed positive pair before enabling the other branch."""
    root = Path(root).resolve()
    require(root.parent == EVIDENCE.resolve() and re.fullmatch(r'development-recovery-smoke-[0-9a-f]{32}', root.name), 'PREREQUISITE_ROOT')
    declaration = read(root / 'declaration.json')
    require(declaration.get('seed') == 40741 and declaration.get('r10o_development', {}).get('prerequisite_pair') is None,
        'PREREQUISITE_CYCLE_OR_POPULATION')
    import development_recovery_smoke as smoke
    checkpoint = smoke.retained_checkpoint(root)
    observed = checkpoint['observed']
    require(positive_pair_result(observed.get('r10o_finite_development'), candidate_reference), 'PREREQUISITE_NOT_POSITIVE_PAIR')
    supervisor = read(root / 'supervisor_result.json')
    require(supervisor.get('ok') is True and supervisor.get('failure_code') == '', 'PREREQUISITE_SUPERVISOR_FAILURE')
    path = root / 'independent_audit.stdout.json'
    return dict(path=path.as_posix(), raw_sha256=sha(path), attempt_id=declaration['attempt_id'])


def context(mode, source_commit, candidate_reference, prerequisite_root=None):
    require(mode in (PAIR, SINGLE) and re.fullmatch(r'[0-9a-f]{40}', source_commit), 'MODE_OR_SOURCE')
    require(sha(DESIGN) == DESIGN_SHA, 'DESIGN_DRIFT')
    seed = 40741 if mode == PAIR else 40743
    if mode == PAIR:
        require(prerequisite_root is None, 'PAIR_HAS_PREREQUISITE')
        prerequisite = None
    else:
        require(prerequisite_root is not None, 'SINGLE_REQUIRES_POSITIVE_PAIR')
        prerequisite = qualify_prerequisite(prerequisite_root, candidate_reference)
    return dict(schema_version=CONTEXT_SCHEMA, source_commit=source_commit, candidate_profile=candidate_reference,
        design_binding=dict(resource='res://sdk/recovery/r10o_initialized_zero_brake_successor_design_v1.json', raw_sha256=DESIGN_SHA),
        seed=seed_identity(seed), required_entry_kind='partial' if seed == 40741 else 'prone', prerequisite_pair=prerequisite,
        physical_acceptance_authority=False, release_authority=False)


def validate_context(value, declaration, *, verify_prerequisite=True):
    require(type(value) is dict and set(value) == CONTEXT_KEYS and value['schema_version'] == CONTEXT_SCHEMA, 'CONTEXT_SHAPE')
    require('r10j_campaign' not in declaration and 'r10k_development' not in declaration and 'r10l_development' not in declaration and 'r10n_development' not in declaration and 'r10m_development' not in declaration and sha(DESIGN) == DESIGN_SHA, 'CROSSED_CAMPAIGN_OR_DESIGN')
    mode = declaration.get('development_execution_mode')
    require(mode in (PAIR, SINGLE), 'MODE')
    seed = 40741 if mode == PAIR else 40743
    require(packet.same(value['seed'], seed_identity(seed)) and packet.same(declaration.get('seed'), seed), 'SEED_BINDING')
    require(value['required_entry_kind'] == ('partial' if seed == 40741 else 'prone'), 'BRANCH_BINDING')
    require(value['physical_acceptance_authority'] is False and value['release_authority'] is False, 'AUTHORITY')
    require(packet.same(value['design_binding'], dict(resource='res://sdk/recovery/r10o_initialized_zero_brake_successor_design_v1.json', raw_sha256=DESIGN_SHA)), 'DESIGN_BINDING')
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
    if mode == PAIR:
        require(value['prerequisite_pair'] is None, 'PAIR_HAS_PREREQUISITE')
    else:
        bound = value['prerequisite_pair']
        require(type(bound) is dict and set(bound) == {'path', 'raw_sha256', 'attempt_id'}, 'PREREQUISITE_BINDING')
        path = Path(bound['path']).resolve()
        require(path.name == 'independent_audit.stdout.json' and path.parent.name == 'development-recovery-smoke-' + bound['attempt_id']
            and path.parent.parent == EVIDENCE.resolve() and sha(path) == bound['raw_sha256'], 'PREREQUISITE_BYTES')
        require(positive_pair_result(read(path).get('r10o_finite_development'), declaration['candidate_profile']), 'PREREQUISITE_RESULT')
        if verify_prerequisite:
            require(packet.same(qualify_prerequisite(path.parent, declaration['candidate_profile']), bound), 'PREREQUISITE_REAUDIT')
    return dict(seed=seed, identity=seed_identity(seed), roles=roles, required_entry_kind=value['required_entry_kind'])


def validate_declaration(declaration):
    import development_recovery_candidate as candidate
    selected = candidate.selection(declaration.get('candidate_profile'))
    require(selected.get('diagnostic_schedule', {}).get('walking_policy_id') == ROUTE, 'ROUTE')
    return validate_context(declaration.get('r10o_development'), declaration)


def validate_report_header(report, declaration, population):
    require(packet.same(report.get('r10o_development'), declaration['r10o_development']), 'REPORT_CONTEXT')
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
        schema_version='sporespore_r10o_prefix_phase_selection_v1', profile_id='r10o_declared_development_prefix_phase_v1',
        seed=identity['seed'], prefix_phase=phase, source_design_sha256=DESIGN_SHA,
        physical_acceptance_authority=False, release_authority=False)), 'PREFIX_SELECTION_SOURCE')


def finite_result(declaration, cells):
    population = validate_context(declaration['r10o_development'], declaration, verify_prerequisite=False)
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
    args = parser.parse_args()
    value = context(args.mode, args.source_commit, dict(resource=args.candidate_resource, raw_sha256=args.candidate_sha256), args.prerequisite_root)
    print(json.dumps(value, separators=(',', ':')))
