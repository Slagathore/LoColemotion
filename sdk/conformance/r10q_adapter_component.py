"""Audit retained R10Q Godot component checks; optional exact C ABI replay.

This component record is not complete production-route qualification. The
worker inputs are synthetic, and no physical successor outcome is inferred.
"""
import argparse
import json
from pathlib import Path

import development_recovery_refusal as native
import r10p_entry_domain_diagnosis as prior

ROOT = prior.ROOT
RECORD = ROOT / 'sdk/recovery/r10q_adapter_component_v1.json'


def require(ok, code):
    if not ok:
        raise ValueError('R10Q_ADAPTER_' + code)


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    require(prior.binding(path)['raw_sha256'] == item['raw_sha256'], 'BINDING:' + str(path))
    return path


class ExactCore(native.RecordedCore):
    @staticmethod
    def _input_bytes(value):
        return value if isinstance(value, bytes) else native.RecordedCore._input_bytes(value)


def audit(record, cold=False):
    require(record['schema_version'] == 'sporespore_r10q_adapter_component_v1', 'SCHEMA')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        physical_execution_authorized=False, physical_acceptance_authority=False,
        release_authority=False, production_route_integrated=False,
        complete_smoke_safety_gate_passed=False, full_360_phase_startup_sweep_complete=False,
        successor_physics_observed=False, original_results_regraded=False, sdk1_score='14/20'), 'CLAIMS')
    for item in record['source_files'] + record['retained_evidence']:
        verify(item)
    for review in record['reviews']:
        base = Path(review['path'])
        result = json.loads((base / 'execution.json').read_bytes())
        require(result['exit_code'] == review['expected_exit_code'], 'REVIEW_OUTCOME')
        require(json.loads((base / 'component/source-stability.json').read_bytes())['source_unchanged'] is True, 'SOURCE_DRIFT')
    runtime = json.loads(verify(record['runtime_binding']).read_bytes())
    verify(runtime['runtime'])
    for item in runtime['source_files']:
        verify(item)
    core = ExactCore(runtime['runtime']['path']) if cold else None
    calls, checks = 0, 0

    def check_call(call):
        nonlocal calls
        require(call['ok'] is True and call['compiled_call_count'] == 1, 'CALL_NOT_SUCCESSFUL')
        raw = call['request']['utf8_text'].encode('utf-8')
        response = call['response']['utf8_text'].encode('utf-8')
        require(json.loads(response) == dict(ok=True, value=call['value']), 'CALL_ENVELOPE')
        if core is not None:
            value = core._call_json_input('ss_' + call['method'], raw)
            require(core.raw_response == response and value == call['value'], 'COLD_RESPONSE_BYTES')
        calls += 1

    results = {}
    for item in record['successful_results']:
        result = json.loads(verify(item['binding']).read_bytes())
        require(result['ok'] is True and len(result['checks']) == item['check_count']
                and all(v is True for v in result['checks'].values()), 'GODOT_CHECKS:' + item['name'])
        require(result['world_build_count'] == result['solver_step_count'] == 0
                and result['physical_acceptance_authority'] is False and result['release_authority'] is False, 'GODOT_AUTHORITY')
        checks += len(result['checks'])
        results[item['name']] = result

    entry = results['source-orchestrator']
    populations = [r for r in entry['results'] if 'exposed_seed' in r]
    require([(r['exposed_seed'], r['samples'], r['state']['r10q_entry_kind']) for r in populations]
            == [(50645, 240, 'upright'), (50646, 240, 'upright'), (50641, 240, 'partial'), (50643, 117, 'prone')], 'ENTRY_POPULATION')
    for population in populations:
        require(len(population['packets']) == population['samples'], 'ENTRY_RETENTION')
        for packet in population['packets']:
            check_call(packet['call'])
            require(packet['native_receipt'] == packet['call']['value']
                and packet['original_control_receipt'] == packet['native_receipt']['original_control']
                and packet['original_passive_receipt'] == packet['original_control_receipt']['entry']['original_passive_receipt'], 'ENTRY_ORIGINAL')
            if 'original_bridge_call' in packet:
                check_call(packet['original_bridge_call'])
                require(packet['original_bridge_call']['value'] == packet['original_control_receipt'], 'OLD_BRANCH_CHANGED')
    for row in entry['results']:
        if 'fixture_id' in row:
            require(row['request_exact'] is True, 'FIXTURE_REQUEST')
            check_call(row['call'])

    worker = results['upright-worker']
    require(worker['synthetic_measurements_only'] is True and worker['selector_and_launcher_validation_exercised'] is False, 'WORKER_SCOPE')
    require(len(worker['entry_packets']) == 240 and len(worker['upright_packets']) == 63, 'WORKER_POPULATION')
    for packet in worker['entry_packets']:
        check_call(packet['call'])
        require(packet['call']['value'] == packet['native_receipt'], 'WORKER_ENTRY_CALL')
    memory = worker['entry_packets'][-1]['native_receipt']['entry']['upright_memory']
    for count, packet in enumerate(worker['upright_packets'], 1):
        check_call(packet['call'])
        request = json.loads(packet['call']['request']['utf8_text'])
        require(packet['prior_memory'] == memory == request['step']['memory'], 'WORKER_MEMORY_CHAIN')
        require(packet['call']['value'] == packet['native_receipt'], 'WORKER_STEP_CALL')
        memory = packet['native_receipt']['step']['memory']
        require(memory['total_steps_observed'] == count and memory['last_semantic_step'] == 512 + count, 'WORKER_CLOCK')
        require(packet['native_receipt']['step']['upright_stabilization_complete'] is (count == 63), 'PREMATURE_COMPLETE')
    require(memory == worker['final_upright_memory'] and memory['standing_samples_observed'] == 60, 'WORKER_STANDING')
    state = worker['final_state']
    require(state['phase'] == 'fresh_selected_policy_walking_resume' and state['epoch_start_global_step'] == 272
        and state['canonical_start_global_step'] is None and state['confirm_prone_step_count'] == 0
        and state['partial_start_global_step'] is None and state['partial_recovery_step_count'] == 0, 'WORKER_HISTORY')
    require(calls == 1499, 'CALL_POPULATION')
    return dict(ok=True, godot_checks_passed=checks, retained_calls_verified=calls,
        cold_native_responses_byte_exact=calls if cold else 0, retained_entry_samples=837,
        synthetic_worker_passive_samples=240, synthetic_worker_recovery_samples=63,
        required_consecutive_standing_samples=60, **record['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--cold', action='store_true', help='Reproduce native response bytes under the operation lock.')
    args = parser.parse_args()
    print('R10Q_ADAPTER_COMPONENT ' + json.dumps(audit(json.loads(RECORD.read_bytes()), args.cold), separators=(',', ':')))
