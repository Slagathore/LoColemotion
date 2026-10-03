"""Read-only audit of retained R10K Godot source and native bridge checks."""
import argparse
import json
import re

from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/recovery/r10k_source_bridge_component_implementation_v1.json'


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_source_bridge_component_implementation_v1', 'BRIDGE_SCHEMA')
    require(record['status'] == 'source_and_native_bridges_verified_worker_not_integrated', 'BRIDGE_STATUS')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        physical_execution_authorized=False, physical_acceptance_authority=False,
        release_authority=False, production_route_integrated=False,
        original_campaign_regraded=False, sdk1_score='14/20'), 'BRIDGE_CLAIMS')
    native = read(verify(record['native_component']))
    verify(native['runtime_binding'])
    verify(native['runtime'])
    paths = set()
    for item in record['retained_evidence']:
        require(item['path'] not in paths, 'BRIDGE_DUPLICATE_EVIDENCE')
        paths.add(item['path'])
        verify(item)
    if current_sources:
        for item in record['source_files']:
            verify(item)
    complete_path = verify(record['completion'])
    complete = read(complete_path)
    require(complete['exit_code'] == 0 and complete['world_build_count'] == 0
        and complete['solver_step_count'] == 0, 'BRIDGE_COMPLETION')
    base = complete_path.parent
    require(re.search(r'Ran 2 tests in .*\n\nOK\s*$',
        (base / 'stderr.log').read_text(encoding='utf-8')) is not None, 'BRIDGE_TEST_COUNT')
    component = base / 'component'
    stability = read(component / 'source-stability.json')
    require(stability['source_unchanged'] is True and
        (component / 'source_before.json').read_bytes() == (component / 'source_after.json').read_bytes(), 'BRIDGE_SOURCE_DRIFT')
    results = {}
    for name, count in [('task-source', 99), ('recovery-stage', 61)]:
        result = read(component / (name + '.json'))
        execution = read(component / (name + '.execution.json'))
        require(execution['exit_code'] == 0 and result['ok'] is True
            and len(result['checks']) == count and all(result['checks'].values()), 'BRIDGE_' + name)
        require(result['world_build_count'] == 0 and result['solver_step_count'] == 0
            and not result['physical_acceptance_authority'] and not result['release_authority'], 'BRIDGE_NATIVE_CLAIMS')
        require('ERROR:' not in (component / (name + '.stderr.log')).read_text(encoding='utf-8'), 'BRIDGE_NATIVE_ERROR')
        results[name] = result
    require(results['task-source']['measurements']['synthetic_snapshots'] is True, 'BRIDGE_SYNTHETIC_SCOPE')
    stage = results['recovery-stage']
    require(stage['exposed_inputs_not_regraded'] is True and stage['synthetic_step_fixtures'] is True, 'BRIDGE_INPUT_SCOPE')
    entries = [row for row in stage['results'] if 'seed' in row]
    require([(row['seed'], row['count'], row['last_packet']['entry_kind']) for row in entries]
        == [(50641, 240, 'partial'), (50642, 240, 'partial'), (50643, 117, 'prone')], 'BRIDGE_ENTRY_ROUTES')
    steps = [row for row in stage['results'] if 'synthetic_step_fixture' in row]
    require(len(steps) == 5, 'BRIDGE_STEP_COUNT')
    for row in steps:
        request = json.loads(row['call']['request']['utf8_text'])
        response = json.loads(row['call']['response']['utf8_text'])
        descriptor = request['step']['declaration']['entry_request']['passive_request']['declaration']['initialization']['descriptor']
        require(request['collection']['descriptor'] == descriptor and response['ok'] is True
            and response['value'] == row['expected'], 'BRIDGE_EXACT_NATIVE_STEP')
    return dict(ok=True, godot_source_checks_passed=99, godot_bridge_checks_passed=61,
        original_passive_measurements=597, synthetic_partial_control_steps=5,
        retained_evidence_files=len(paths), current_sources_verified=current_sources,
        **record['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('R10K_SOURCE_BRIDGE_COMPONENT ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
