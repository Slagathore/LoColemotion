"""Reconstruct the R10N pre-world task-digest refusal and prospective repair."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

from v52_extended_support_transfer import ROOT, read, binding, verify
from r10n_route_integration import committed_digest

RECORD = ROOT / 'sdk/recovery/r10n_reader_binding_repair_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10N_READER_BINDING_REPAIR_' + code)


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10n_reader_binding_repair_v1', 'SCHEMA')
    for item in record['sources'].values():
        verify(item)
    seen = set()
    for item in record['retained_evidence']:
        require(item['path'] not in seen, 'DUPLICATE_EVIDENCE')
        seen.add(item['path']); verify(item)
    failed = Path(record['failed_gate_root'])
    result = read(failed / 'supervisor_result.json')
    require(result['source_snapshot'] == dict(head=record['failed_source'], dirty=False,
        status=[], changed_file_bindings=[]), 'FAILED_SOURCE')
    require(result['ok'] is False and result['physical_attempt_started'] is False
        and result['children'] == [] and result['independent_audit'] is None
        and result['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:candidate_reader', 'FAILED_GATE')
    stages = result['safety_stages']
    require(len(stages) == 17 and sum(s['test_count'] for s in stages[:-1]) == 79
        and all(s['passed'] is True for s in stages[:-1]) and stages[-1]['passed'] is False
        and stages[-1]['test_count'] == 2 and stages[-1]['timed_out'] is False, 'FAILED_STAGES')
    log = (failed / 'candidate_reader.stderr.log').read_text(encoding='utf-8-sig')
    require(log.count('ValueError: R10N_FINITE_TASK_CONTRACT_DRIFT') == 2
        and 'FAILED (errors=2)' in log, 'ORIGINAL_ERRORS')
    task = verify(record['sources']['task'])
    predecessor = verify(record['sources']['predecessor_task'])
    old_digest = hashlib.sha256(predecessor.read_bytes()).hexdigest()
    new_digest = hashlib.sha256(task.read_bytes()).hexdigest()
    name = record['sources']['finite_auditor']['path']
    old = subprocess.check_output(['git', 'show', record['failed_source'] + ':' + name], cwd=ROOT)
    corrected = verify(record['sources']['finite_auditor']).read_bytes()
    old_assignment = ("TASK_SHA = '" + old_digest + "'").encode()
    new_assignment = ("TASK_SHA = '" + new_digest + "'").encode()
    require(old.count(old_assignment) == 1 and corrected == old.replace(old_assignment, new_assignment), 'EXACT_REPAIR')
    # The task bytes and every semantic schedule field are unchanged.
    require(committed_digest(record['failed_source'], record['sources']['task']['path'])
        == record['sources']['task']['raw_sha256'], 'TASK_CHANGED')
    original_entry = read(verify(record['sources']['original_entry']))
    corrected_entry = read(verify(record['sources']['corrected_entry']))
    require({k:v for k,v in original_entry.items() if k != 'bound_source_files'}
        == {k:v for k,v in corrected_entry.items() if k != 'bound_source_files'}, 'ENTRY_SEMANTICS')
    original_schedule = read(verify(record['sources']['original_schedule']))
    corrected_schedule = read(verify(record['sources']['corrected_schedule']))
    require(list(original_schedule['schedules'].values()) == list(corrected_schedule['schedules'].values()), 'SCHEDULE_SEMANTICS')
    original_profile = read(verify(record['sources']['original_profile']))
    corrected_profile = read(verify(record['sources']['corrected_profile']))
    omit = {'candidate_id', 'diagnostic_schedule_id', 'diagnostic_schedule_sha256'}
    require({k:v for k,v in original_profile.items() if k not in omit}
        == {k:v for k,v in corrected_profile.items() if k not in omit}, 'CANDIDATE_SEMANTICS')
    focused = Path(record['focused_root'])
    before = read(focused / 'source_before.json')
    require((focused / 'source_before.json').read_bytes() == (focused / 'source_after.json').read_bytes(), 'SOURCE_STABILITY')
    copied = {item['path']:item for item in read(focused / 'source_files_manifest.json')['files']}
    require(set(copied) == {item['path'] for item in before['changed_file_bindings']}, 'SOURCE_POPULATION')
    for item in before['changed_file_bindings']:
        actual = binding(focused / 'source_files' / item['path'])
        require(actual['raw_sha256'] == copied[item['path']]['raw_sha256']
            == 'sha256:' + item['sha256'].removeprefix('sha256:'), 'COPIED_SOURCE')
    for item in corrected_entry['bound_source_files']:
        observed = copied[item['path']]['raw_sha256'] if item['path'] in copied else committed_digest(before['head'], item['path'])
        require(observed == item['raw_sha256'], 'FOCUSED_SOURCE:' + item['path'])
        if current_sources:
            require(binding(item['path'])['raw_sha256'] == observed, 'CURRENT_SOURCE:' + item['path'])
    stages = read(focused / 'stages.json')
    require([(s['id'], s['test_count']) for s in stages] == [('r10n_finite_task', 5), ('candidate_recovery_route', 4)], 'FOCUSED_STAGES')
    for stage in stages:
        require(stage['passed'] is True and stage['timed_out'] is False and stage['exit_code'] == 0, 'FOCUSED_RESULT')
        for label in ['stdout', 'stderr']:
            raw = (focused / stage[label]).read_bytes()
            require(hashlib.sha256(raw).hexdigest() == stage[label + '_sha256'], 'FOCUSED_LOG')
        text = (focused / stage['stderr']).read_text(encoding='utf-8-sig')
        require(re.findall(r'^Ran ([0-9]+) tests in [0-9.]+s$', text, re.MULTILINE) == [str(stage['test_count'])]
            and re.search(r'\nOK\s*$', text), 'TEST_TERMINAL')
    route = read(Path(record['route_root']) / 'result.json')
    require(route['ok'] is True and len(route['checks']) == 48 and all(v is True for v in route['checks'].values())
        and route['world_build_count'] == route['solver_step_count'] == 0, 'ROUTE_CHECKS')
    require(record['claim_boundary'] == dict(original_failed_gate_preserved=True,
        full_gate_passed_on_corrected_source=False, physical_attempt_started=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False,
        release_authority=False, sdk1_score='14/20'), 'CLAIMS')
    return dict(ok=True, retained_files=len(seen), failed_gate_passed_tests=79,
        focused_tests_passed=9, actual_route_checks=48, bound_sources=len(corrected_entry['bound_source_files']),
        **record['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--current-sources', action='store_true')
    print(json.dumps(audit(parser.parse_args().current_sources), sort_keys=True))
