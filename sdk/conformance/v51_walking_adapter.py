"""Read-only audit of retained V51 adapter integration; no native call or world."""
import argparse
import hashlib

from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/development/v51_walking_adapter_implementation_v1.json'


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_v51_walking_adapter_implementation_v1', 'V51_ADAPTER_SCHEMA')
    require(record['status'] == 'native_policy_adapter_and_facade_verified_full_route_pending', 'V51_ADAPTER_STATUS')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        full_r10k_route_registered=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False,
        original_campaign_regraded=False, sdk1_score='14/20'), 'V51_ADAPTER_CLAIMS')
    native = read(verify(record['native_component']))
    verify(native['runtime'])
    verify(native['runtime_binding'])
    policy_path = verify(record['policy_contract'])
    policy = read(policy_path)
    evidence = set()
    for item in record['retained_evidence']:
        require(item['path'] not in evidence, 'V51_ADAPTER_DUPLICATE_EVIDENCE')
        evidence.add(item['path'])
        verify(item)
    if current_sources:
        for item in record['source_files']:
            verify(item)
    final_path = verify(record['final_result'])
    base = final_path.parent
    result = read(final_path)
    require(read(base / 'execution.json')['exit_code'] == 0
        and 'ERROR:' not in (base / 'stderr.log').read_text(encoding='utf-8'), 'V51_ADAPTER_EXECUTION')
    require((base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes()
        and read(base / 'source-stability.json')['source_unchanged'] is True, 'V51_ADAPTER_SOURCE_DRIFT')
    require(result['ok'] is True and len(result['checks']) == 45
        and all(result['checks'].values()), 'V51_ADAPTER_CHECKS')
    require(result['world_build_count'] == result['solver_step_count'] == 0
        and not result['full_route_registered'] and not result['physical_acceptance_authority']
        and not result['release_authority'], 'V51_ADAPTER_NATIVE_CLAIMS')
    inputs = read(base / 'input.json')
    require(len(inputs['fixtures']) == len(inputs['exposed_sources']) == 3, 'V51_ADAPTER_INPUTS')
    for source in inputs['exposed_sources']:
        verify(source)
    for label in ['v51', 'v50']:
        retained = result['results'][label]
        require(len(retained['steps']) == len(retained['refusals']) == 3
            and all(row['response']['ok'] is False for row in retained['refusals']), 'V51_ADAPTER_REFUSALS')
        for index, step in enumerate(retained['steps'], 1):
            output = step['response']['value']
            require(step['request']['state']['semantic_step'] == index
                and step['response']['ok'] is True and len(output['actuation']['ordered_commands']) == 8
                and output['actuation']['safe_no_actuation'] is False, 'V51_ADAPTER_NATIVE_STEP')
            if index > 1:
                require(step['request']['memory'] == retained['steps'][index - 2]['response']['value']['next_memory'],
                    'V51_ADAPTER_MEMORY_CHAIN')
        ledger = retained['motor_ledger']
        require(retained['facade_start']['ok'] is True and ledger['ok'] is True
            and ledger['detached_hinge_parameter_container_count'] == 8
            and ledger['scene_tree_insertion_count'] == ledger['solver_step_count'] == ledger['world_build_count'] == 0,
            'V51_ADAPTER_PRODUCTION_LEDGER')
    selected = result['results']['v51']
    require(selected['native_profile'] == policy['native_profile']
        and selected['start']['controller_profile_sha256'] == policy['native_profile_sha256']
        and selected['motor_ledger']['walking_actuation_handoff_receipt']['selected_policy_digest'] == record['policy_contract']['raw_sha256'],
        'V51_ADAPTER_EXACT_POLICY')
    cold = read(base / 'cold-replay.json')
    require(cold['source_unchanged'] is True and len(cold['rows']) == 6, 'V51_ADAPTER_COLD_POPULATION')
    for row in cold['rows']:
        response = (base / f"{row['policy']}-{row['step']}.cold-response.json").read_bytes()
        require(row['native_status'] == 0 and row['response_byte_exact'] is True
            and row['expected_response_sha256'] == row['actual_response_sha256']
            == 'sha256:' + hashlib.sha256(response).hexdigest(), 'V51_ADAPTER_COLD_BYTES')
    return dict(ok=True, actual_godot_checks_passed=45, native_responses_byte_exact=6,
        actual_policy_facades=2, retained_evidence_files=len(evidence),
        current_sources_verified=current_sources, **record['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    import json
    print('V51_WALKING_ADAPTER ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
