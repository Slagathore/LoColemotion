"""Read-only retained R10K worker-component audit. No native call or world."""
import argparse
import json
import re

from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/recovery/r10k_worker_component_implementation_v1.json'


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_worker_component_implementation_v1', 'WORKER_SCHEMA')
    require(record['status'] == 'worker_hooks_verified_route_not_registered', 'WORKER_STATUS')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
        complete_production_route_integrated=False, selector_and_launcher_validation_exercised=False,
        original_campaign_regraded=False, sdk1_score='14/20'), 'WORKER_CLAIMS')
    verify(record['source_bridge_component'])
    native = read(verify(record['native_component']))
    verify(native['runtime'])
    verify(native['runtime_binding'])
    paths = set()
    for item in record['retained_evidence']:
        require(item['path'] not in paths, 'WORKER_DUPLICATE_EVIDENCE')
        paths.add(item['path'])
        verify(item)
    if current_sources:
        for item in record['source_files']:
            verify(item)
    completion_path = verify(record['completion'])
    completion = read(completion_path)
    require(completion['exit_code'] == 0 and completion['world_build_count'] == 0
        and completion['solver_step_count'] == 0, 'WORKER_COMPLETION')
    base = completion_path.parent
    require(re.search(r'Ran 4 tests in .*\n\nOK\s*$',
        (base / 'stderr.log').read_text(encoding='utf-8')) is not None, 'WORKER_TEST_COUNT')
    base = base / 'component'
    require(read(base / 'source-stability.json')['source_unchanged'] is True
        and (base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes(), 'WORKER_SOURCE_DRIFT')
    results = {}
    for name, count in [('orchestrator', 58), ('partial-worker', 16), ('prone-worker', 10), ('legacy-worker', 10)]:
        result = read(base / (name + '.json'))
        execution = read(base / (name + '.execution.json'))
        require(execution['exit_code'] == 0 and result['ok'] is True
            and len(result['checks']) == count and all(result['checks'].values()), 'WORKER_' + name)
        require(result['world_build_count'] == 0 and result['solver_step_count'] == 0
            and not result['physical_acceptance_authority'] and not result['release_authority'], 'WORKER_NATIVE_CLAIMS')
        require('ERROR:' not in (base / (name + '.stderr.log')).read_text(encoding='utf-8'), 'WORKER_NATIVE_ERROR')
        results[name] = result
    orchestrator = results['orchestrator']
    require(orchestrator['synthetic_orchestration_events'] is True
        and orchestrator['exposed_inputs_not_regraded'] is True
        and sum(row.get('samples', 0) for row in orchestrator['results']) == 597, 'WORKER_ENTRY_SCOPE')
    partial = results['partial-worker']
    require(partial['synthetic_measurements_only'] is True and partial['selector_and_launcher_validation_exercised'] is False
        and len(partial['entry_packets']) == 240 and len(partial['partial_packets']) == 63, 'WORKER_PARTIAL_POPULATION')
    prior = partial['entry_packets'][-1]['native_receipt']['entry']['partial_memory']
    for index, packet in enumerate(partial['partial_packets'], 1):
        require(packet['ok'] is True and packet['prior_memory'] == prior, 'WORKER_PARTIAL_CHAIN')
        request = json.loads(packet['call']['request']['utf8_text'])
        response = json.loads(packet['call']['response']['utf8_text'])
        native = packet['native_receipt']
        require(request['step']['memory'] == prior and response['ok'] is True
            and response['value'] == native and native['step']['energy_epoch_reset'] is False, 'WORKER_NATIVE_SOURCE')
        prior = native['step']['memory']
        require(prior['total_steps_observed'] == index and prior['last_semantic_step'] == 512 + index, 'WORKER_PARTIAL_CLOCK')
    state = partial['final_state']
    require(prior == partial['final_partial_memory'] and prior['phase'] == 'complete'
        and prior['standing_samples_observed'] == 60 and state['phase'] == 'fresh_selected_policy_walking_resume'
        and state['canonical_start_global_step'] is None and state['confirm_prone_step_count'] == 0
        and state['post_kick_recovery_step_count'] == 0 and state['epoch_start_global_step'] == 272, 'WORKER_COMPLETE_PARTIAL_HISTORY')
    prone = results['prone-worker']
    require(prone['branch'] == 'prone' and prone['final_partial_memory'] == {}
        and (prone['final_state']['confirm_prone_step_count'], prone['final_state']['post_kick_recovery_step_count']) == (12, 2), 'WORKER_PRONE_PREFIX')
    legacy = results['legacy-worker']
    require(legacy['branch'] == 'legacy' and 'r10k_entry_kind' not in legacy['final_state']
        and legacy['partial_packets'] == [], 'WORKER_LEGACY')
    cold = read(verify(record['independent_native_replay']))
    require(cold['ok'] is True and cold['source_unchanged'] is True
        and cold['native_calls_reproduced_byte_exactly'] == len(cold['rows']) == 304
        and all(row['response_byte_exact'] for row in cold['rows']), 'WORKER_COLD_REPLAY')
    return dict(ok=True, component_tests_passed=4, actual_godot_checks_passed=94,
        exposed_passive_entry_samples=597, synthetic_worker_passive_steps=240,
        contiguous_synthetic_partial_worker_steps=63, standing_consecutive_samples=60,
        native_responses_byte_exact=304, retained_evidence_files=len(paths),
        current_sources_verified=current_sources, **record['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('R10K_WORKER_COMPONENT ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
