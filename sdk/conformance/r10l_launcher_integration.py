"""Read-only R10L launcher declaration and exact safety-graph evidence audit."""
import argparse
import json
from pathlib import Path
import re
from v52_extended_support_transfer import ROOT, read, binding, verify
from r10k_preparation_report import sources

RECORD = ROOT / 'sdk/recovery/r10l_launcher_safety_integration_v1.json'

def require(ok, code):
    if not ok: raise ValueError('R10L_LAUNCHER_' + code)

def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10l_launcher_safety_integration_v1', 'SCHEMA')
    require(record['claim_boundary'] == dict(launcher_and_complete_stage_selection_verified=True,
        full_safety_gate_passed=False, physical_attempt_started=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20'), 'CLAIMS')
    for key in ['auditor','predecessor_record','entry_contract','candidate_profile','stage_contract','runtime_binding']:
        verify(record[key])
    verify(read(verify(record['runtime_binding']))['runtime'])
    seen = set()
    for item in record['retained_evidence']:
        require(item['path'] not in seen, 'DUPLICATE_EVIDENCE')
        seen.add(item['path']); verify(item)
    root = Path(record['launcher_root'])
    require((root/'source_before.json').read_bytes() == (root/'source_after.json').read_bytes(), 'SOURCE_STABILITY')
    count = sources(record['entry_contract'], root/'source_before.json', current_sources)
    selected = read(root/'selected-stages.json')
    expected = read(verify(record['stage_contract']))
    require([{k:s[k] for k in ['id','pattern','tests']} for s in selected['stages']] == expected['stages'], 'STAGE_GRAPH')
    require(len(selected['stages']) == 40 and selected['test_count'] == expected['total_tests'] == 195
        and sum(selected['discovered_test_counts'].values()) == 195, 'STAGE_POPULATION')
    paired = read(root/'paired-declaration.json')
    require(paired['seed'] == 40441 and paired['r10l_development']['seed']['prefix_phase'] == 241
        and paired['r10l_development']['required_entry_kind'] == 'partial'
        and paired['r10l_development']['prerequisite_pair'] is None and paired['maximum_steps_per_child'] == 3512,
        'PAIR_DECLARATION')
    require(read(root/'paired.execution.json')['returncode'] == 0, 'LIBRARY_DECLARATION')
    for name in ['complete','missing','wrong_count','false_pass','untyped_pass','timeout','missing_first_stage','crossed_pattern','missing_preparation']:
        process = read(root/('prelaunch-'+name+'.execution.json'))
        require(process['returncode'] == (0 if name == 'complete' else 1), 'PRELAUNCH_CONTROL:'+name)
        require('-Library' in process['command'][-1] and '-RunSmoke' not in process['command'][-1], 'NO_PHYSICAL_TEST')
        if name != 'complete':
            require('R10L_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING' in (root/('prelaunch-'+name+'.stderr.txt')).read_text(encoding='utf-8'), 'PRELAUNCH_REFUSAL')
    require(read(root/'single-without-pair.execution.json')['returncode'] == 1
        and 'SINGLE_REQUIRES_POSITIVE_PAIR' in (root/'single-without-pair.stderr.txt').read_text(encoding='utf-8'), 'SINGLE_PREREQUISITE')
    for name in ['zero','boolean','too-long']:
        require(read(root/('timeout-'+name+'.execution.json'))['returncode'] == 1
            and 'DEVELOPMENT_STAGE_TIMEOUT_INVALID' in (root/('timeout-'+name+'.stderr.txt')).read_text(encoding='utf-8'), 'STAGE_TIMEOUT')
    require(re.search(r'Ran 5 tests in .*\n\nOK\s*$', verify(record['test_log']).read_text(encoding='utf-8-sig')), 'TEST_LOG')
    if current_sources:
        import development_recovery_candidate as candidate
        chosen = candidate.selection(candidate.reference_for_path(verify(record['candidate_profile'])))
        require(chosen['diagnostic_schedule']['walking_policy_id'] == 'r10l_v52_partial_fall_recovery_route_v1', 'CURRENT_SELECTION')
    return dict(ok=True, tests=5, selected_safety_stages=40, selected_safety_tests=195, bound_sources=count,
        retained_files=len(seen), full_gate_passed=False, world_build_count=0, solver_step_count=0, sdk1_score='14/20')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--current-sources',action='store_true')
    args=parser.parse_args(); print(json.dumps(audit(args.current_sources),sort_keys=True))
