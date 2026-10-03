"""Audit retained R10AE integration components without granting qualification."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

import r10ad_startup_invalid_closure as retained

ROOT, EVIDENCE = retained.ROOT, retained.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ae_launch_integration_component_v1.json'
RUNS = {
    'r10ae-integration-6229dfaa09514a27a98be17e5753a42a':
        {'context_handoff': 3, 'native_interfaces': 4, 'host': 7},
    'r10ae-integration-86c831b175f849ab9835a7af4f48e685':
        {'launch_guard': 11, 'native_world_authority': 18, 'smoke_reader': 8,
         'retention_gate': 1, 'startup_preflight': 4},
}
HANDOFF = EVIDENCE / 'r10ae-handoff-757617904fcb4858aceec186da2395b8'
SNAPSHOTS = [
    ('r10ae-handoff-757617904fcb4858aceec186da2395b8', 'source-before.json', 'source-after.json', 5),
    ('r10ae-launch-guard-26e4f39aeadb4fc999cf4c08b10d33fa', 'source_before.json', 'source_after.json', 6),
]
COMPONENT_ROOTS = [
    HANDOFF.name, 'r10ae-native-interfaces-d4eaaab12f814233970c656969805a38',
    'r10ae-host-check-6667a56c9e394c4b9f5c4f8e76000a06',
    'r10ae-launch-guard-26e4f39aeadb4fc999cf4c08b10d33fa',
    'r10ae-launch-guard-c9e11c8cdd664b98baaa4f2a2476a58a',
    'r10ae-smoke-reader-c132b9993e91426593aa33c8bba13365',
    'r10ae-retention-check-7dba904294c44993a6c7e99e2517eb5e',
]
FAILURES = [
    ('r10ae-integration-ba35a65327cd4fc78024b905711d1b8b', 'r10ae-handoff-1069a39846cd4a928789e2d10e85d927', 'walking-start registry identifier'),
    ('r10ae-integration-c6ef21a408c14755a41df7e425df1d6e', 'r10ae-handoff-03a4fa5f78b74781827cee4600769910', 'finite-route admission alias'),
    ('r10ae-integration-2dc8d9abb2b74c59868eb454e2d8888f', 'r10ae-handoff-03346122cc534d14a6af23a083848ca6', 'producer JSON precision'),
    ('r10ae-integration-9ae5e2375b4b4e82b864488683243269', 'r10ae-handoff-f28008d4f75f46d995cab912521c156e', 'fixture omitted L15 environment mode'),
]
CLAIMS = dict(selected_runtime_context_handoff_verified=True,
    production_candidate_admission_exercised=True, production_environment_builder_exercised=True,
    single_use_claim_replaced_in_handoff_probe=True, authority_tests_use_isolated_synthetic_records=True,
    full_launch_path_proven=False, complete_safety_gate_qualified=False,
    physical_execution_authorized=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


def require(value, code):
    if not value:
        raise ValueError('R10AE_INTEGRATION_COMPONENT_' + code)


def tested_source(folder, before_name, after_name, version):
    before = retained.read(EVIDENCE / folder / before_name)
    require(before == retained.read(EVIDENCE / folder / after_name), 'SOURCE_STABILITY')
    require(before['remote'] == 'https://github.com/Slagathore/sporespore.git', 'SOURCE_REMOTE')
    replacements = {}
    for row in before['changed_files']:
        require(row['deleted'] is False, 'SOURCE_DELETION')
        data = base64.b64decode(row['replacement_base64'])
        require('sha256:' + hashlib.sha256(data).hexdigest() == row['raw_sha256'], 'SNAPSHOT_HASH')
        replacements[row['path']] = data
    key = ROOT / f'sdk/recovery/r10ae_v56_walking_entry_contract_v{version}.json'
    rows = retained.read(key)['bound_source_files']
    missing = [r for r in rows if r['path'] not in replacements]
    run = subprocess.run(['git', 'cat-file', '--batch'], cwd=ROOT,
        input=''.join(before['head'] + ':' + r['path'] + '\n' for r in missing).encode(),
        capture_output=True, check=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
    require(not run.stderr, 'GIT_STDERR')
    cursor = 0
    for row in missing:
        end = run.stdout.index(b'\n', cursor)
        header = run.stdout[cursor:end].split()
        require(len(header) == 3 and header[1] == b'blob', 'SOURCE_BLOB')
        size = int(header[2]); data = run.stdout[end + 1:end + 1 + size]; cursor = end + 2 + size
        replacements[row['path']] = data
    require(cursor == len(run.stdout), 'GIT_TAIL')
    for row in rows:
        data = replacements[row['path']]
        variants = [data] if b'\r\n' in data else [data, data.replace(b'\n', b'\r\n')]
        require(any(len(v) == row['byte_length'] and 'sha256:' + hashlib.sha256(v).hexdigest() == row['raw_sha256'] for v in variants), 'SOURCE_HASH:' + row['path'])
    return dict(source_key=retained.bind(key), source_files=len(rows), base_commit=before['head'])


def observed():
    counts = {}
    for folder, stages in RUNS.items():
        root = EVIDENCE / folder
        require(retained.read(root / 'stages.json') == [dict(stage=k, exit_code=0) for k in stages], 'STAGES')
        lock = retained.read(root / 'operation-lock.json')
        require(lock['acquired'] is True and lock['released'] is True, 'OPERATION_LOCK')
        for stage, count in stages.items():
            log = (root / (stage + '.stderr.log')).read_text(encoding='utf-8-sig')
            require(re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$', log, re.M) == [str(count)]
                and len(re.findall(r'^OK\s*$', log, re.M)) == 1, 'TEST_COUNT:' + stage)
            counts[stage] = count
    producer = retained.read(HANDOFF / 'r10ae_context_production/producer.json')
    consumer = retained.read(HANDOFF / 'r10ae_pre_world_consumption/consumer.json')
    require(producer['ok'] is True and consumer['construction_boundary_reached'] is True
        and consumer['comparison']['ok'] is True and consumer['configuration']['ok'] is True, 'HANDOFF')
    expected = producer['expectation']['raw_capture_binding']
    require(consumer['comparison']['expected_capture_binding'] == expected
        and consumer['comparison']['expected_capture_binding_matched'] is True, 'CONTEXT_MATCH')
    require(consumer['construction_guard']['failure_code'] == 'R10AE_NATIVE_WORLD_QUALIFICATION_PENDING', 'GUARD')
    for packet in (producer, consumer):
        require(all(type(packet[k]) is int and packet[k] == 0 for k in ('world_build_count', 'solver_step_count')), 'ZERO_WORLD')
    for outer, inner, reason in FAILURES:
        if outer == FAILURES[0][0]:
            require(retained.read(EVIDENCE / outer / 'execution.json') == dict(exit_code=1), 'FIRST_REFUSAL')
            stages = [dict(stage='context_handoff', exit_code=1)]
        else:
            stages = retained.read(EVIDENCE / outer / 'stages.json')
            if isinstance(stages, dict): stages = [stages]
        require(stages == [dict(stage='context_handoff', exit_code=1)], 'RETAINED_FAILURE:' + reason)
        require((EVIDENCE / inner / 'r10ae_context_proposal.json').is_file(), 'FAILURE_PROPOSAL')
    return dict(test_counts=counts, tests_passed=sum(counts.values()), retained_refused_rehearsals=len(FAILURES),
        tested_sources=[tested_source(*row) for row in SNAPSHOTS], capture_binding=expected,
        world_build_count=0, solver_step_count=0)


def audit(record):
    require(record['claim_boundary'] == CLAIMS, 'CLAIMS')
    for item in record['bindings'] + [record['auditor']]: retained.verify_binding(item)
    require(record['observed'] == observed(), 'OBSERVATIONS')
    return dict(ok=True, **record['observed'], **CLAIMS)


def create():
    folders = set(RUNS) | set(COMPONENT_ROOTS) | {name for row in FAILURES for name in row[:2]}
    paths = [p for folder in sorted(folders) for p in sorted((EVIDENCE / folder).rglob('*')) if p.is_file()]
    record = dict(schema_version='sporespore_r10ae_launch_integration_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_launch_integration_component', question_class='development'),
        auditor=retained.bind(__file__), bindings=[retained.bind(p) for p in paths],
        observed=observed(), claim_boundary=CLAIMS,
        retained_refusals=[dict(outer=a, inner=b, reason=c) for a, b, c in FAILURES],
        remaining='Complete controller-plus-contact report and workflow coverage, final safety graph and clean pushed native startup qualification remain. No physical population was reserved by these isolated tests.')
    audit(record); retained.write_new(RECORD, record)
    return dict(ok=True, record=retained.bind(RECORD), tests_passed=record['observed']['tests_passed'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print(json.dumps(create() if args.create else audit(retained.read(RECORD))))
