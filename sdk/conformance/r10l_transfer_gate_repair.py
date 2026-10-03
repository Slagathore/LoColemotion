"""Verify the retained R10L v5 zero-world refusal and v6 focused repair evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from v52_extended_support_transfer import ROOT, read, binding, verify
from r10k_preparation_report import sources

RECORD = ROOT / 'sdk/recovery/r10l_transfer_gate_repair_v1.json'


def require(ok, code):
    if not ok:
        raise ValueError('R10L_TRANSFER_REPAIR_' + code)


def audit(current_sources=False):
    r = read(RECORD)
    require(r['schema_version'] == 'sporespore_r10l_transfer_gate_repair_v1', 'SCHEMA')
    for key in ['auditor', 'original_supervisor', 'original_entry', 'entry_contract',
                'candidate_profile', 'stage_contract', 'runtime_binding']:
        verify(r[key])
    seen = set()
    for item in r['retained_evidence']:
        require(item['path'] not in seen, 'DUPLICATE_EVIDENCE')
        seen.add(item['path'])
        verify(item)
    original = read(verify(r['original_supervisor']))
    require(original['ok'] is False and original['failure_code'] ==
            'SMOKE_SAFETY_GATE_FAILED:r10l_extended_transfer', 'ORIGINAL_REFUSAL')
    require(original['physical_attempt_started'] is False and original['children'] == []
            and original['independent_audit'] is None, 'ORIGINAL_NO_PHYSICS')
    require(original['source_snapshot']['head'] == r['source_parent_commit']
            and original['source_snapshot']['dirty'] is False, 'ORIGINAL_FREEZE')
    stages = original['safety_stages']
    require(len(stages) == 18 and all(s['passed'] is True for s in stages[:-1])
            and sum(s['test_count'] for s in stages[:-1]) == 81, 'ORIGINAL_PROGRESS')
    final = stages[-1]
    require(final['id'] == 'r10l_extended_transfer' and final['passed'] is False
            and final['test_count'] == 0 and final['expected_test_count'] == 6
            and final['exit_code'] == 1 and final['timed_out'] is False, 'ORIGINAL_STAGE')
    gate_root = Path(r['original_supervisor']['path']).parent
    for stage in stages:
        for stream in ['stdout', 'stderr']:
            path = gate_root / stage[stream]
            require(path.as_posix() in seen and hashlib.sha256(path.read_bytes()).hexdigest()
                    == stage[stream + '_sha256'], 'ORIGINAL_STAGE_LOG')
    error = (gate_root / final['stderr']).read_text(encoding='utf-8-sig')
    require("ExtendedSupportTransfer.retain() missing 1 required positional argument: 'value'"
            in error, 'ORIGINAL_CAUSE')
    for key, count in [('transfer_log', 6), ('launcher_log', 5)]:
        require(re.search(r'Ran ' + str(count) + r' tests in .*\n\nOK\s*$',
                          verify(r[key]).read_text(encoding='utf-8-sig')), 'FOCUSED_TESTS')
    root = Path(r['launcher_root'])
    require((root / 'source_before.json').read_bytes() ==
            (root / 'source_after.json').read_bytes(), 'SOURCE_STABILITY')
    count = sources(r['entry_contract'], root / 'source_before.json', current_sources)
    selected = read(root / 'selected-stages.json')
    contract = read(verify(r['stage_contract']))
    require([{k: s[k] for k in ['id', 'pattern', 'tests']} for s in selected['stages']]
            == contract['stages'] and selected['test_count'] == 195, 'UNCHANGED_GATE')
    runtime = read(verify(r['runtime_binding']))['runtime']
    verify(runtime)
    receipt = read(Path(r['transfer_root']) / 'selected-runtime.json')
    require(receipt['runtime'] == runtime and receipt['candidate_profile']['raw_sha256']
            == r['candidate_profile']['raw_sha256'], 'SELECTED_RUNTIME')
    require(r['claim_boundary'] == dict(full_safety_gate_passed=False,
            physical_attempt_started=False, world_build_count=0, solver_step_count=0,
            original_attempt_reclassified=False, physical_acceptance_authority=False,
            release_authority=False, sdk1_score='14/20'), 'CLAIMS')
    return dict(ok=True, original_gate_passed_tests=81, focused_tests=11,
                bound_sources=count, retained_files=len(seen), full_gate_passed=False,
                world_build_count=0, solver_step_count=0, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    print(json.dumps(audit(parser.parse_args().current_sources), sort_keys=True))
