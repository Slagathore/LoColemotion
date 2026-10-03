"""R10AB's first declared single-kick development population, never acceptance.

This module binds identity and publication. It neither reserves an attempt nor
qualifies a launcher; launch requires the complete applicable safety gate.
"""
import argparse
import hashlib
from pathlib import Path
import re

import qsdk_r10f_l15_collection_retention as packet

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
DESIGN = ROOT / 'sdk/recovery/r10ab_partial_downward_rise_development_design_v1.json'
DESIGN_SHA = 'sha256:2f1dd3df7edd561ec94ddb2cfffe8d2e72553b9914a5924a8635c940e9be186b'
ROUTE = 'r10ab_partial_downward_rise_route_v1'
SINGLE = 'single_kick_controller_diagnostic_v1'
ROLES = ['kick_passive_recovery_resume']
CONTEXT_SCHEMA = 'sporespore_r10ab_development_child_context_v1'
CONTEXT_KEYS = {'schema_version', 'source_commit', 'candidate_profile', 'design_binding', 'seed',
    'required_entry_kind', 'stage', 'physical_acceptance_authority', 'release_authority'}


def require(ok, code):
    if not ok:
        raise ValueError('R10AB_DEVELOPMENT_' + code)


def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def seed_identity(seed):
    require(type(seed) is int and seed == 51008, 'UNDECLARED_SEED')
    label = 'R10AB-DEVELOPMENT-PREFIX-248-V1'
    return dict(seed=seed, label=label, sha256='sha256:' + hashlib.sha256(label.encode()).hexdigest(), prefix_phase=248)


def context(mode, source_commit, candidate_reference, diagnostic_seed=51008):
    require(mode == SINGLE and type(source_commit) is str and re.fullmatch(r'[0-9a-f]{40}', source_commit), 'MODE_OR_SOURCE')
    require(sha(DESIGN) == DESIGN_SHA, 'DESIGN_DRIFT')
    return dict(schema_version=CONTEXT_SCHEMA, source_commit=source_commit, candidate_profile=candidate_reference,
        design_binding=dict(resource='res://' + DESIGN.relative_to(ROOT).as_posix(), raw_sha256=DESIGN_SHA),
        seed=seed_identity(diagnostic_seed), required_entry_kind='partial', stage='first_support_diagnostic',
        physical_acceptance_authority=False, release_authority=False)


def validate_context(value, declaration):
    require(type(value) is dict and set(value) == CONTEXT_KEYS, 'CONTEXT_SHAPE')
    require(not any(key != 'r10ab_development' and re.fullmatch(r'r10[a-z]+_(development|campaign|host)', key)
        for key in declaration), 'CROSSED_CAMPAIGN')
    require(declaration.get('comparative_authority') is False and declaration.get('baseline_reused') is False, 'COMPARISON_OR_BASELINE_REUSE')
    expected = context(declaration.get('development_execution_mode'), declaration.get('source_snapshot', {}).get('head'),
        declaration.get('candidate_profile'), declaration.get('seed'))
    require(packet.same(value, expected), 'CONTEXT_BINDING')
    children = declaration.get('children')
    require(type(children) is list and len(children) == 1 and type(children[0]) is dict
        and children[0].get('role') == ROLES[0], 'ROLE_POPULATION')
    attempt = declaration.get('attempt_id')
    require(type(attempt) is str and re.fullmatch(r'[0-9a-f]{32}', attempt), 'ATTEMPT_ID')
    seen = {attempt}
    for field in ('child_attempt_id', 'termination_nonce'):
        identity = children[0].get(field)
        require(type(identity) is str and re.fullmatch(r'[0-9a-f]{32}', identity) and identity not in seen, 'CHILD_ID_REUSE')
        seen.add(identity)
    expected_path = EVIDENCE / ('development-recovery-smoke-' + attempt) / 'children' / ROLES[0]
    require(type(children[0].get('evidence_path')) is str
        and Path(children[0]['evidence_path']).resolve() == expected_path.resolve(), 'CHILD_PATH')
    return dict(seed=51008, identity=seed_identity(51008), roles=ROLES, required_entry_kind='partial')


def validate_declaration(declaration):
    import development_recovery_candidate as candidate
    selected = candidate.selection(declaration.get('candidate_profile'))
    require(selected.get('diagnostic_schedule', {}).get('walking_policy_id') == ROUTE, 'ROUTE')
    return validate_context(declaration.get('r10ab_development'), declaration)


def validate_report_header(report, declaration, population):
    require(packet.same(report.get('r10ab_development'), declaration['r10ab_development']), 'REPORT_CONTEXT')
    identity = population['identity']
    child = declaration['children'][0]
    require(report.get('arm_id') == ROLES[0] and report.get('child_attempt_id') == child['child_attempt_id']
        and report.get('parent_attempt_id') == declaration['attempt_id'], 'REPORT_CHILD')
    require(report.get('seed_label') == identity['label'] and report.get('seed_sha256') == identity['sha256']
        and packet.same(report.get('seed'), 51008) and report.get('held_out') is False
        and packet.same(report.get('held_out_cell_access_count'), 0), 'REPORT_SEED')
    prefixes = [s for s in report.get('retained_arm', {}).get('walking_sessions', []) if s.get('evaluation_segment_id') == 'walking_prefix']
    require(len(prefixes) == 1, 'PREFIX_SESSION_POPULATION')
    receipt = prefixes[0].get('start_receipt', {})
    require(packet.same(receipt.get('initial_gait_steps'), dict.fromkeys(('front_left', 'front_right', 'rear_left', 'rear_right'), 248)), 'PREFIX_PHASE')
    require(packet.same(receipt.get('development_prefix_phase_selection'), dict(
        schema_version='sporespore_r10ab_prefix_phase_selection_v1', profile_id='r10ab_declared_development_prefix_phase_v1',
        seed=51008, prefix_phase=248, source_design_sha256=DESIGN_SHA,
        physical_acceptance_authority=False, release_authority=False)), 'PREFIX_SELECTION_SOURCE')


def finite_result(declaration, cells):
    population = validate_context(declaration.get('r10ab_development'), declaration)
    require(type(cells) is list and len(cells) == 1 and type(cells[0]) is dict
        and cells[0].get('role') == ROLES[0], 'RESULT_POPULATION')
    require(type(cells[0].get('finite_task_predicates_passed')) is bool, 'RESULT_DOMAIN')
    return dict(schema_version='sporespore_r10ab_finite_development_result_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='bounded_development_result', question_class='development'),
        seed=population['seed'], prefix_phase=248, candidate_profile=declaration['candidate_profile'], cells=cells,
        all_tasks_positive=cells[0]['finite_task_predicates_passed'], branch_coverage_complete=cells[0].get('entry_kind') == 'partial',
        paired_commissioning_satisfied=False, comparative_authority=False, baseline_reused=False,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    import json
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', required=True, choices=[SINGLE])
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--candidate-resource', required=True)
    parser.add_argument('--candidate-sha256', required=True)
    parser.add_argument('--diagnostic-seed', type=int, choices=[51008], default=51008)
    args = parser.parse_args()
    print(json.dumps(context(args.mode, args.source_commit, dict(resource=args.candidate_resource,
        raw_sha256=args.candidate_sha256), args.diagnostic_seed), separators=(',', ':')))
