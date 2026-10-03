"""Single-use R10AG development launch reservation; never acceptance authority.

The contact-frame diagnostic requires its own complete safety-stage contract.
Until that contract is declared and every stage passes, authorization refuses.
Historical R10V gate helpers are reused only for exact log and Git validation.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re

import r10ag_context_handoff as handoff
import r10ag_development as development
import r10v_development_launch as shared
import r10ag_host_runtime as host
import development_recovery_candidate as candidate
import r10ag_population_binding as population

ROOT, EVIDENCE = development.ROOT, development.EVIDENCE
CONTRACT = ROOT / 'sdk/development/r10ag_safety_stage_contract_v1.json'
LAUNCH_FILE = 'r10ag_development_launch.json'
TOKEN = 'r10ag_contact_frame_diagnostic_65248_consumption_v1.json'
REMOTE = shared.REMOTE
COVERAGE = ('construction', 'launch_ownership', 'bounded_stepping', 'serialization',
    'finalization', 'no_claim_publication', 'contact_frame_capture',
    'independent_combined_replay', 'compact_retention', 'startup_preflight', 'context_handoff',
    'detection_frame_classification', 'walking_source_transport')
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))
binding = shared.binding
write_new = shared.write_new
from r10ag_startup_preflight import current_freeze


def require(value, code):
    if not value:
        raise ValueError('R10AG_LAUNCH_' + code)


def contract():
    require(CONTRACT.is_file(), 'COMPLETE_SAFETY_CONTRACT_PENDING')
    value = read(CONTRACT)
    require(value.get('schema_version') == 'sporespore_r10ag_safety_stage_contract_v1'
        and same(value.get('population'), dict(seed=65248, roles=[development.ROLE], mode=development.SINGLE))
        and value.get('design_sha256') == development.DESIGN_SHA
        and same(value.get('candidate_profile'), development.reference())
        and value.get('complete_applicable_coverage') is True
        and value.get('additional_required_controls') == []
        and value.get('physical_acceptance_authority') is False
        and value.get('release_authority') is False, 'SAFETY_CONTRACT')
    require(same(value.get('population_binding_correction'), population.reference()), 'POPULATION_CORRECTION_BINDING')
    population.audit()
    stages = value.get('stages')
    require(type(stages) is list and bool(stages), 'EMPTY_SAFETY_CONTRACT')
    ids = set()
    for stage in stages:
        require(type(stage) is dict and type(stage.get('id')) is str
            and re.fullmatch(r'[a-z0-9_]+', stage['id']) and stage['id'] not in ids
            and type(stage.get('pattern')) is str and re.fullmatch(r'test_[a-z0-9_]+\.py', stage['pattern'])
            and type(stage.get('tests')) is int and stage['tests'] > 0
            and type(stage.get('candidate_bound')) is bool, 'SAFETY_STAGE_SPEC')
        if 'timeout_seconds' in stage:
            require(type(stage['timeout_seconds']) is int and 1 <= stage['timeout_seconds'] <= 600,
                'SAFETY_STAGE_TIMEOUT')
        ids.add(stage['id'])
    require(type(value.get('total_tests')) is int
        and value['total_tests'] == sum(s['tests'] for s in stages), 'SAFETY_TEST_TOTAL')
    coverage = value.get('coverage')
    require(type(coverage) is dict and set(coverage) == set(COVERAGE), 'COVERAGE_POPULATION')
    for area in COVERAGE:
        covered = coverage[area]
        require(type(covered) is dict and type(covered.get('argument')) is str
            and bool(covered['argument'].strip()) and type(covered.get('stage_ids')) is list
            and bool(covered['stage_ids']) and all(type(s) is str and s in ids for s in covered['stage_ids']),
            'COVERAGE_STAGE_BINDING')
    return value


def same(left, right):
    return json.dumps(left, sort_keys=True, allow_nan=False) == json.dumps(right, sort_keys=True, allow_nan=False)


def declared(path):
    path = Path(path).resolve()
    require(path.name == 'declaration.json' and path.parent.parent == EVIDENCE.resolve()
        and re.fullmatch(r'development-recovery-smoke-[0-9a-f]{32}', path.parent.name), 'DECLARATION_ROOT')
    value = read(path)
    require(path.parent.name == 'development-recovery-smoke-' + value['attempt_id'], 'ATTEMPT_ROOT')
    development.validate_declaration(value)
    host.validate_binding(value.get('runtime'))
    import development_recovery_smoke as smoke
    smoke.declared_schedule(value)
    head = value['source_snapshot']['head']
    require(value['source_snapshot'] == dict(head=head, dirty=False, status=[], changed_file_bindings=[]), 'DECLARED_SOURCE_NOT_CLEAN')
    require(all(value.get(key) is False for key in
        ('official_qualification', 'physical_acceptance_authority', 'release_authority')), 'CLAIMS')
    return value


def safety(path, value):
    contract()
    return shared.safety(Path(path), value, contract_path=CONTRACT)


def reservation(path, value):
    return dict(schema_version='sporespore_r10ag_stage_consumption_v1', design_sha256=development.DESIGN_SHA,
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='single_use_development_population_reservation', question_class='development'),
        stage=development.STAGE, seed=65248, attempt_id=value['attempt_id'],
        declaration=binding(path), source_commit=value['source_snapshot']['head'], attempt_limit=1)


def authorize(path):
    """Called by the real supervisor under its operation lock, before any child."""
    path = Path(path).resolve()
    value = declared(path)
    logs = safety(path, value)
    context_receipt = handoff.verify(path)
    # Source-key admission and actual images are reopened before population use.
    candidate.selection(development.reference())
    host.bind_runtime(value['runtime']['images']['godot_console']['path'],
        value['runtime']['images']['powershell_host']['path'])
    freeze = current_freeze(value['source_snapshot']['head'])
    target = path.parent / LAUNCH_FILE
    require(not target.exists(), 'ATTEMPT_ALREADY_AUTHORIZED')
    token = EVIDENCE / TOKEN
    try:
        write_new(token, reservation(path, value))
    except FileExistsError as error:
        raise ValueError('R10AG_LAUNCH_POPULATION_ALREADY_CONSUMED') from error
    # Reservation is durable first. A later publication failure cannot permit retry.
    record = dict(schema_version='sporespore_r10ag_development_launch_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='bounded_development_launch_guard', question_class='development'),
        attempt_id=value['attempt_id'], stage=development.STAGE, declaration=binding(path),
        source_key=binding(candidate.R10AG_ROUTE_ENTRY_PATH), runtime_binding=value['runtime'],
        freeze=freeze, safety_contract=binding(CONTRACT), safety_logs=logs, stage_reservation=binding(token),
        context_handoff=context_receipt,
        created_utc=datetime.now(timezone.utc).isoformat(), official_qualification=False,
        physical_acceptance_authority=False, release_authority=False)
    write_new(target, record)
    return dict(ok=True, launch=binding(target), stage=record['stage'])


def verify(path):
    """Read the original receipts; never reserve an attempt during auditing."""
    path = Path(path).resolve()
    value = declared(path)
    require((path.parent / LAUNCH_FILE).is_file(), 'LAUNCH_RECEIPT_REQUIRED')
    record = read(path.parent / LAUNCH_FILE)
    require(record.get('schema_version') == 'sporespore_r10ag_development_launch_v1'
        and record.get('attempt_id') == value['attempt_id'] and record.get('declaration') == binding(path)
        and record.get('stage') == development.STAGE, 'RECORD_BINDING')
    require(record.get('context_handoff') == handoff.verify(path), 'RECORD_CONTEXT_HANDOFF')
    require(record.get('safety_contract') == binding(CONTRACT), 'RECORD_GATE_CONTRACT')
    require(record.get('source_key') == binding(candidate.R10AG_ROUTE_ENTRY_PATH), 'RECORD_SOURCE_KEY')
    require(same(record.get('runtime_binding'), value['runtime']), 'RECORD_RUNTIME')
    require(record.get('safety_logs') == safety(path, value), 'RECORD_GATE')
    head = value['source_snapshot']['head']
    require(same(record.get('freeze'), dict(root=ROOT.as_posix(), remote=REMOTE, branch='main', head=head,
        origin_main=head, live_origin_main=head, clean=True)), 'RECORDED_FREEZE')
    require(all(record.get(key) is False for key in
        ('official_qualification', 'physical_acceptance_authority', 'release_authority')), 'RECORD_CLAIMS')
    token = EVIDENCE / TOKEN
    require(record.get('stage_reservation') == binding(token)
        and same(read(token), reservation(path, value)), 'RESERVATION_IDENTITY')
    return dict(ok=True, launch=binding(path.parent / LAUNCH_FILE), stage=record['stage'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--authorize', type=Path)
    mode.add_argument('--verify', type=Path)
    mode.add_argument('--check-freeze')
    mode.add_argument('--contract', action='store_true')
    args = parser.parse_args()
    result = (authorize(args.authorize) if args.authorize else verify(args.verify) if args.verify
        else current_freeze(args.check_freeze) if args.check_freeze else contract())
    print(json.dumps(result, separators=(',', ':')))
