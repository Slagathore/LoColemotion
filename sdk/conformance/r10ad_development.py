"""Prospective R10AD diagnostic identity; no launch reservation or qualification.

The new seed maps to an exposed phase. It is not fresh held-out evidence.
This module does not import or renew the consumed R10AB source key.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
DESIGN = ROOT / 'sdk/recovery/r10ad_contact_frame_development_design_v1.json'
DESIGN_SHA = 'sha256:7c71982c68b0e086b454134952c16dc57a582ce8cd4c80cd2e1aa873265b2d76'
PROFILE = ROOT / 'sdk/development/recovery_candidates/r10ad-contact-frame-diagnostic-v1.json'
PROFILE_SHA = 'sha256:43b9aea64f769d31f26b7d63109a0d0dcb97a8d03381bac38e4e7235b4016208'
SEED, PHASE = 62248, 248
SINGLE = 'single_kick_controller_diagnostic_v1'
ROLE = 'kick_passive_recovery_resume'
PREFIX_PROFILE = 'r10ad_declared_contact_frame_prefix_phase_v1'
STAGE = 'contact_frame_diagnostic'
CONTEXT_KEY = 'r10ad_development'


def require(ok, code):
    if not ok:
        raise ValueError('R10AD_DEVELOPMENT_' + code)


def sha(path):
    return 'sha256:' + hashlib.sha256(Path(path).read_bytes()).hexdigest()


def reference():
    require(sha(PROFILE) == PROFILE_SHA, 'PROFILE_DRIFT')
    return dict(resource='res://' + PROFILE.relative_to(ROOT).as_posix(), raw_sha256=PROFILE_SHA)


def seed_identity(seed):
    require(type(seed) is int and seed == SEED, 'UNDECLARED_SEED')
    label = 'R10AD-CONTACT-FRAME-PREFIX-248-V1'
    return dict(seed=seed, label=label, sha256='sha256:' + hashlib.sha256(label.encode()).hexdigest(), prefix_phase=PHASE)


def prefix_selection(seed, profile):
    require(profile == PREFIX_PROFILE, 'PREFIX_PROFILE')
    seed_identity(seed)
    return dict(schema_version='sporespore_r10ad_prefix_phase_selection_v1', profile_id=profile,
        seed=seed, prefix_phase=PHASE, source_design_sha256=DESIGN_SHA,
        physical_acceptance_authority=False, release_authority=False)


def context(mode, source_commit, candidate_reference, diagnostic_seed=SEED):
    require(mode == SINGLE and type(source_commit) is str
        and re.fullmatch(r'[0-9a-f]{40}', source_commit), 'MODE_OR_SOURCE')
    require(sha(DESIGN) == DESIGN_SHA, 'DESIGN_DRIFT')
    require(candidate_reference == reference(), 'CANDIDATE_BINDING')
    design = json.loads(DESIGN.read_text(encoding='utf-8'))
    return dict(schema_version='sporespore_r10ad_development_child_context_v1',
        source_commit=source_commit, candidate_profile=reference(),
        design_binding=dict(resource='res://' + DESIGN.relative_to(ROOT).as_posix(), raw_sha256=DESIGN_SHA),
        seed=seed_identity(diagnostic_seed), required_entry_kind='partial', stage=STAGE,
        capture_profile_id=design['telemetry']['profile_id'], observer_engine=design['engine'],
        physical_acceptance_authority=False, release_authority=False)


def validate_declaration(value):
    require(type(value) is dict, 'DECLARATION_KIND')
    require(not any(key != CONTEXT_KEY and re.fullmatch(r'r10[a-z]+_(development|campaign|host)', key)
        for key in value), 'CROSSED_CAMPAIGN')
    require(all(value.get(key) is False for key in ('comparative_authority', 'baseline_reused',
        'official_qualification', 'physical_acceptance_authority', 'release_authority')), 'CLAIMS')
    source = value.get('source_snapshot')
    require(type(source) is dict and set(source) == {'head', 'dirty', 'status', 'changed_file_bindings'}
        and source.get('dirty') is False and source.get('status') == []
        and source.get('changed_file_bindings') == [], 'CLEAN_SOURCE')
    expected = context(value.get('development_execution_mode'), source.get('head'),
        value.get('candidate_profile'), value.get('seed'))
    # JSON equality also keeps booleans distinct from numeric substitutes.
    require(json.dumps(value.get(CONTEXT_KEY), sort_keys=True) == json.dumps(expected, sort_keys=True), 'CONTEXT_BINDING')
    children, attempt = value.get('children'), value.get('attempt_id')
    require(type(attempt) is str and re.fullmatch(r'[0-9a-f]{32}', attempt), 'ATTEMPT_ID')
    require(type(children) is list and len(children) == 1 and type(children[0]) is dict
        and children[0].get('role') == ROLE, 'ROLE_POPULATION')
    seen = {attempt}
    for field in ('child_attempt_id', 'termination_nonce'):
        identity = children[0].get(field)
        require(type(identity) is str and re.fullmatch(r'[0-9a-f]{32}', identity)
            and identity not in seen, 'CHILD_ID_REUSE')
        seen.add(identity)
    expected_path = (EVIDENCE / ('development-recovery-smoke-' + attempt) / 'children' / ROLE).as_posix()
    path = children[0].get('evidence_path')
    require(type(path) is str and path.replace('\\', '/') == expected_path, 'CHILD_PATH')
    return dict(seed=SEED, identity=seed_identity(SEED), roles=[ROLE], required_entry_kind='partial')


def validate_report_header(report, declaration):
    validate_declaration(declaration)
    require(type(report) is dict, 'REPORT_KIND')
    require(json.dumps(report.get(CONTEXT_KEY), sort_keys=True)
        == json.dumps(declaration[CONTEXT_KEY], sort_keys=True), 'REPORT_CONTEXT')
    identity = seed_identity(SEED)
    require(report.get('arm_id') == ROLE and report.get('source_commit') == declaration['source_snapshot']['head']
        and report.get('child_attempt_id') == declaration['children'][0]['child_attempt_id']
        and report.get('parent_attempt_id') == declaration['attempt_id'], 'REPORT_CHILD')
    require(type(report.get('seed')) is int and report['seed'] == SEED
        and report.get('seed_label') == identity['label'] and report.get('seed_sha256') == identity['sha256']
        and report.get('held_out') is False and type(report.get('held_out_cell_access_count')) is int
        and report['held_out_cell_access_count'] == 0, 'REPORT_SEED')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', required=True)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--candidate-resource', required=True)
    parser.add_argument('--candidate-sha256', required=True)
    args = parser.parse_args()
    print(json.dumps(context(args.mode, args.source_commit,
        dict(resource=args.candidate_resource, raw_sha256=args.candidate_sha256)), separators=(',', ':')))
