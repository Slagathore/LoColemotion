"""Retained R10K component audit. Reads only; no DLL call or world is created."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10k_partial_fall_component_implementation_v1.json'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def require(ok, code):
    if not ok:
        raise ValueError('R10K_COMPONENT_' + code)


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    raw = path.read_bytes()
    require(len(raw) == item['byte_length'] and 'sha256:' + hashlib.sha256(raw).hexdigest() == item['raw_sha256'], 'FILE_DRIFT:' + item['path'])
    return path


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_partial_fall_component_implementation_v1', 'SCHEMA')
    require(record['status'] == 'native_component_verified_production_route_not_integrated', 'STATUS')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
        sdk1_score='14/20', production_route_integrated=False, original_campaign_regraded=False), 'CLAIMS')
    for key in ['design', 'runtime_binding', 'runtime', 'native_component_completion']:
        verify(record[key])
    paths = set()
    for item in record['retained_evidence']:
        require(item['path'] not in paths, 'DUPLICATE_EVIDENCE')
        paths.add(item['path'])
        verify(item)
    binding = read(ROOT / record['runtime_binding']['path'])
    require(binding['runtime'] == record['runtime'] and binding['core_test_count'] == 382, 'BUILD')
    require(all(stage['exit_code'] == 0 for stage in binding['build_stages']), 'BUILD_FAILURE')
    if current_sources:
        for item in record['source_files'] + binding['source_files']:
            verify(item)
    complete = read(record['native_component_completion']['path'])
    require(complete['exit_code'] == 0 and complete['source_unchanged'] is True
        and complete['world_build_count'] == 0 and complete['solver_step_count'] == 0, 'NATIVE_COMPLETION')
    evidence = Path(complete['evidence_root'])
    log = (evidence / 'stderr.log').read_text(encoding='utf-8')
    require(re.search(r'Ran 6 tests in .*\n\nOK\s*$', log) is not None, 'NATIVE_TEST_COUNT')
    godot = read(evidence / 'component/godot-result.json')
    require(godot['ok'] is True and len(godot['rows']) == 20 and all(godot['checks'].values())
        and all(row['matches'] for row in godot['rows']), 'GODOT')
    require(godot['world_build_count'] == 0 and godot['solver_step_count'] == 0
        and not godot['physical_acceptance_authority'] and not godot['release_authority'], 'GODOT_CLAIMS')
    negatives = read(evidence / 'component/native-refusals.json')
    require(len(negatives) == 14 and all(row['status'] != 0
        and json.loads(row['response_utf8'])['ok'] is False for row in negatives), 'NEGATIVE_CONTROLS')
    require(len(read(evidence / 'component/v20-v7-original-byte-parity.json')) == 12, 'LEGACY_PARITY')
    passive = read(evidence / 'component/retained-passive-summary.json')
    expected = [dict(seed=50641, commands=240, selected_branch='partial'),
        dict(seed=50642, commands=240, selected_branch='partial'), dict(seed=50643, commands=117, selected_branch='prone')]
    require(passive['cases'] == expected and passive['original_passive_responses_reproduced_exactly'] == 597, 'PASSIVE_INPUTS')
    for case in expected:
        row = read(evidence / ('component/retained-passive-' + str(case['seed']) + '.json'))
        require(row['exposed_input_diagnostic_only'] is True and row['original_campaign_regraded'] is False, 'EXPOSED_SCOPE')
        require(len(row['rows']) == case['commands'] and all(item['original_response_reproduced_exactly'] for item in row['rows']), 'PASSIVE_PARITY')
        verify(row['source'])
    return dict(ok=True, core_tests_passed=382, native_component_tests_passed=6,
        godot_cases_passed=20, negative_controls_passed=14, legacy_control_responses_byte_exact=12,
        original_passive_responses_byte_exact=597, measured_partial_entries=2, measured_prone_entries=1,
        retained_evidence_files=len(paths), current_sources_verified=current_sources,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False,
        release_authority=False, production_route_integrated=False, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('R10K_PARTIAL_COMPONENT ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
