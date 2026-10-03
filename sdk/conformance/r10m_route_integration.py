"""Read-only audit of R10M integration drafts and their retained native checks.

This record is development evidence. It does not qualify the complete safety
population or grant physical or release acceptance.
"""
import argparse
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re
import subprocess

from v52_extended_support_transfer import ROOT, read, binding, verify
from r10k_preparation_report import reader, REFUSALS

RECORD = ROOT / 'sdk/recovery/r10m_route_integration_v1.json'
STAGES = ['candidate_recovery_route', 'candidate_profile', 'r10m_declaration',
    'candidate_measured_body_adapter', 'r10m_worker', 'r10m_recovery_reader',
    'candidate_reader', 'r10m_preparation_report']
CLAIMS = dict(full_route_implemented=True, complete_safety_gate_passed=False,
    physical_attempt_started=False, world_build_count=0, solver_step_count=0,
    physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def require(value, code):
    if not value:
        raise ValueError('R10M_INTEGRATION_' + code)


@lru_cache(maxsize=None)
def committed_digest(head, name):
    raw = subprocess.check_output(['git', 'show', head + ':' + name], cwd=ROOT)
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def observed_sources(root):
    snapshot = read(root / 'source_before.json')
    require((root / 'source_before.json').read_bytes() == (root / 'source_after.json').read_bytes(), 'SOURCE_STABILITY')
    manifest = read(root / 'source_files_manifest.json')
    require(manifest['source_head'] == snapshot['head'], 'SOURCE_HEAD')
    copied = {v['path']: v for v in manifest['files']}
    require(len(copied) == len(manifest['files']) == len(snapshot['changed_file_bindings']), 'SOURCE_POPULATION')
    for row in snapshot['changed_file_bindings']:
        name = row['path']
        item = copied[name]
        require(row['exists'] is True and item['raw_sha256'] == 'sha256:' + row['sha256'].removeprefix('sha256:'), 'SOURCE_SNAPSHOT_BINDING')
        actual = binding(root / 'source_files' / name)
        require(actual['raw_sha256'] == item['raw_sha256'] and actual['byte_length'] == item['byte_length'], 'SOURCE_COPY:' + name)
    contract = read(root / 'source_files/sdk/recovery/r10m_v53_walking_entry_contract_v1.json')
    for item in contract['bound_source_files']:
        name = item['path']
        actual = copied[name]['raw_sha256'] if name in copied else committed_digest(snapshot['head'], name)
        require(actual == item['raw_sha256'], 'OBSERVED_BOUND_SOURCE:' + name)
    return len(contract['bound_source_files'])


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10m_route_integration_v1', 'SCHEMA')
    require(record['claim_boundary'] == CLAIMS, 'CLAIMS')
    for key in ['auditor', 'entry_contract', 'candidate_profile', 'stage_contract', 'task_contract', 'runtime_binding', 'native_component']:
        verify(record[key])
    runtime = read(verify(record['runtime_binding']))
    verify(runtime['runtime'])
    task = read(verify(record['task_contract']))
    require(task['controller_composition']['native_runtime_sha256'] == runtime['runtime']['raw_sha256'], 'TASK_RUNTIME')
    previous = read(ROOT / 'sdk/recovery/r10l_extended_support_transfer_finite_cycle_contract_v1.json')
    for key in ['native_interaction', 'limits', 'finite_walking_observable', 'settled_tail',
                'whole_walking_envelope', 'partial_recovery', 'prone_recovery']:
        require(task[key] == previous[key], 'TASK_REQUIREMENT_CHANGED:' + key)
    seen = set()
    for item in record['retained_evidence']:
        require(item['path'] not in seen, 'DUPLICATE_EVIDENCE')
        seen.add(item['path']); verify(item)
    require(len(record['attempts']) == 3, 'ATTEMPT_POPULATION')
    source_counts = []
    for index, attempt in enumerate(record['attempts']):
        root = Path(attempt['root'])
        source_counts.append(observed_sources(root))
        stages = read(root / 'stages.json')
        ids = STAGES[:1] if index == 0 else STAGES if index == 1 else [STAGES[0], STAGES[1], STAGES[-1]]
        require([s['id'] for s in stages] == ids, 'ATTEMPT_STAGES')
        for stage in stages:
            passing = index == 2 or (index == 1 and stage['id'] != STAGES[-1])
            require(stage['passed'] is passing, 'STAGE_OUTCOME')
            for label in ['stdout', 'stderr']:
                raw = (root / stage[label]).read_bytes()
                require(hashlib.sha256(raw).hexdigest() == stage[label + '_sha256'], 'STAGE_LOG_BINDING')
            log = (root / stage['stderr']).read_text(encoding='utf-8-sig')
            if passing:
                counts = re.findall(r'^Ran ([0-9]+) tests? in [0-9.]+s$', log, re.MULTILINE)
                require(counts == [str(stage['expected_test_count'])] and stage['test_count'] == stage['expected_test_count']
                    and re.search(r'\nOK\s*$', log) and stage['exit_code'] == 0 and stage['timed_out'] is False, 'PASS_RECEIPT')
            elif index == 0:
                require(stage['test_count'] == 4 and stage['exit_code'] == 1 and stage['timed_out'] is False, 'SEED_FIXTURE_REFUSAL')
            else:
                require(stage['timed_out'] is True and stage['test_count'] == 0 and stage['exit_code'] == -1
                    and 600 <= stage['seconds'] < 630, 'PREPARATION_TIMEOUT')
    route = read(Path(record['corrected_route_root']) / 'result.json')
    require(route['ok'] is True and len(route['checks']) == 48 and all(v is True for v in route['checks'].values()), 'ROUTE_CHECKS')
    for label in ['resume', 'matched', 'ramp', 'hold']:
        ledger = route['result'][label]['ledger']
        require(ledger['ok'] is True and ledger['detached_hinge_parameter_container_count'] == 8
            and ledger['world_build_count'] == ledger['scene_tree_insertion_count'] == ledger['solver_step_count'] == 0, 'NATIVE_LEDGER')
    launcher = Path(record['corrected_launcher_root'])
    selection = read(launcher / 'selected-stages.json')
    contract = read(verify(record['stage_contract']))
    require([{k:s[k] for k in ['id','pattern','tests']} for s in selection['stages']] == contract['stages'], 'COMPLETE_GRAPH')
    require(len(contract['stages']) == 41 and selection['test_count'] == contract['total_tests'] == 201
        and sum(selection['discovered_test_counts'].values()) == 201, 'GRAPH_POPULATION')
    for stage in selection['stages']:
        require(stage.get('timeout_seconds', 180) == contract['stage_timeout_overrides_seconds'].get(stage['id'], 180), 'EXACT_TEST_TIMEOUT')
    paired = read(launcher / 'paired-declaration.json')
    require(paired['seed'] == 40541 and paired['r10m_development']['seed']['prefix_phase'] == 241
        and paired['r10m_development']['prerequisite_pair'] is None, 'PAIR_DECLARATION')
    for label in ['missing', 'wrong_count', 'false_pass', 'untyped_pass', 'timeout', 'missing_first_stage',
                  'crossed_pattern', 'missing_preparation', 'crossed_preparation_timeout']:
        require(read(launcher / ('prelaunch-' + label + '.execution.json'))['returncode'] == 1
            and 'R10M_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING' in (launcher / ('prelaunch-' + label + '.stderr.txt')).read_text(encoding='utf-8'), 'PRELAUNCH_CONTROL:' + label)
    require(read(launcher / 'prelaunch-complete.execution.json')['returncode'] == 0, 'COMPLETE_PRELAUNCH')
    for label in ['timeout-zero', 'timeout-boolean', 'timeout-too-long', 'registered-too-long', 'crossed-long-pattern', 'crossed-long-count']:
        require(read(launcher / (label + '.execution.json'))['returncode'] == 1
            and 'DEVELOPMENT_STAGE_TIMEOUT_INVALID' in (launcher / (label + '.stderr.txt')).read_text(encoding='utf-8'), 'TIMEOUT_CONTROL:' + label)
    require(read(launcher / 'single-without-pair.execution.json')['returncode'] == 1
        and 'SINGLE_REQUIRES_POSITIVE_PAIR' in (launcher / 'single-without-pair.stderr.txt').read_text(encoding='utf-8'), 'PRONE_PREREQUISITE')
    preparation = Path(record['corrected_preparation_root'])
    reader(preparation / 'report/passive_entry_replay')
    for label, refusal in REFUSALS.items():
        reader(preparation / label / 'passive_entry_replay', refusal)
    require((preparation / 'source_before.json').read_bytes() == (preparation / 'source_after.json').read_bytes()
        == (preparation / 'setup_source_after.json').read_bytes(), 'PREPARATION_SOURCE_STABILITY')
    require(read(preparation / 'execution.json')['exit_code'] == 0, 'PREPARATION_PRODUCER')
    final = Path(record['attempts'][2]['root'])
    require(binding(final / 'source_files' / record['entry_contract']['path'])['raw_sha256'] == record['entry_contract']['raw_sha256'], 'FINAL_ENTRY_BINDING')
    if current_sources:
        for item in read(verify(record['entry_contract']))['bound_source_files']:
            require(binding(item['path'])['raw_sha256'] == item['raw_sha256'], 'CURRENT_SOURCE:' + item['path'])
        import development_recovery_candidate as candidate
        chosen = candidate.selection(candidate.reference_for_path(verify(record['candidate_profile'])))
        require(chosen['diagnostic_schedule']['walking_policy_id'] == 'r10m_v53_partial_fall_recovery_route_v1', 'CURRENT_SELECTION')
    return dict(ok=True, retained_files=len(seen), observed_source_counts=source_counts,
        earlier_draft_passed_tests=51, corrected_route_launcher_preparation_tests=11,
        actual_route_checks=48, selected_safety_stages=41, selected_safety_tests=201, **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args(); print(json.dumps(audit(args.current_sources), sort_keys=True))
