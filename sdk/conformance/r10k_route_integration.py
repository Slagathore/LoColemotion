"""Read-only retained R10K route integration audit; never launches a world."""
import argparse
import hashlib
import json
import subprocess

from r10k_partial_component import ROOT, read, require, verify

RECORD = ROOT / 'sdk/recovery/r10k_route_integration_v1.json'


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_r10k_route_integration_v1', 'ROUTE_SCHEMA')
    require(record['claim_boundary'] == dict(world_build_count=0, solver_step_count=0,
        physical_execution_authorized=False, physical_acceptance_authority=False,
        release_authority=False, complete_production_route_qualified=False,
        recovery_reader_integrated=False, sdk1_score='14/20'), 'ROUTE_CLAIMS')
    native = read(verify(record['native_component']))
    verify(native['runtime'])
    verify(native['runtime_binding'])
    verify(record['predecessor_adapter_component'])
    seen = set()
    for item in record['retained_evidence']:
        require(item['path'] not in seen, 'ROUTE_DUPLICATE_EVIDENCE')
        seen.add(item['path'])
        verify(item)
    if current_sources:
        for item in record['source_files']:
            verify(item)
        import development_recovery_candidate as candidate
        selected = candidate.selection(candidate.reference_for_path(verify(record['candidate_profile'])))
        require(selected['diagnostic_schedule']['walking_policy_id'] == 'r10k_v51_partial_fall_recovery_route_v1', 'ROUTE_SELECTION')
    path = verify(record['final_result'])
    base = path.parent
    result = read(path)
    require(result['ok'] is True and len(result['checks']) == 45 and all(result['checks'].values()), 'ROUTE_CHECKS')
    require(read(base / 'execution.json')['exit_code'] == 0
        and 'ERROR:' not in (base / 'stderr.log').read_text(encoding='utf-8'), 'ROUTE_EXECUTION')
    require((base / 'source_before.json').read_bytes() == (base / 'source_after.json').read_bytes(), 'ROUTE_SOURCE_DRIFT')
    data = result['result']
    for key, phase in [('runtime_preflight', 241), ('phase_243_runtime_preflight', 243)]:
        require(data[key]['ok'] is True and set(data[key]['initial_gait_steps'].values()) == {phase}
            and data[key]['native_controller_session_create_count'] == data[key]['native_controller_session_destroy_count'] == 1,
            'ROUTE_PREFIX_PREFLIGHT')
    require(data['unknown_seed_preflight_refusal']['ok'] is False, 'ROUTE_PREFIX_REFUSAL')
    routes = read(verify(record['route_contract']))
    for label, expected in [('resume', routes['policy_id']), ('matched', routes['policy_id']),
        ('ramp', 'sporespore_balanced_wave_joint_pose_entry_v1'),
        ('hold', 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1')]:
        value = data[label]
        ledger = value['ledger']
        require(value['start']['ok'] is True and value['start']['controller_policy_id'] == expected
            and ledger['ok'] is True and ledger['detached_hinge_parameter_container_count'] == 8
            and ledger['world_build_count'] == ledger['solver_step_count'] == ledger['scene_tree_insertion_count'] == 0,
            'ROUTE_NATIVE_LEDGER')
        if label in ['resume', 'matched']:
            require(ledger['walking_actuation_handoff_receipt']['selected_policy_digest'] == record['route_contract']['raw_sha256'],
                'ROUTE_SELECTED_DIGEST')
    regression_path = verify(record['worker_regression_source_snapshot'])
    regression = regression_path.parent
    snapshot = read(regression_path)
    require(regression_path.read_bytes() == (regression / 'source_after.json').read_bytes()
        and read(regression / 'source-stability.json')['source_unchanged'] is True, 'ROUTE_REGRESSION_DRIFT')
    changed = {item['path']: item for item in snapshot['changed_files']}
    for item in record['regression_source_files']:
        if item['path'] in changed:
            expected = changed[item['path']]['raw_sha256']
        else:
            raw = subprocess.check_output(['git', 'show', snapshot['head'] + ':' + item['path']], cwd=ROOT)
            expected = 'sha256:' + hashlib.sha256(raw).hexdigest()
        require(expected == item['raw_sha256'], 'ROUTE_REGRESSION_SOURCE_BINDING')
        if current_sources:
            verify(item)
    for label, count in [('orchestrator', 58), ('partial-worker', 16), ('prone-worker', 10), ('legacy-worker', 10)]:
        checked = read(regression / (label + '.json'))
        require(checked['ok'] is True and len(checked['checks']) == count and all(checked['checks'].values())
            and read(regression / (label + '.execution.json'))['exit_code'] == 0
            and 'ERROR:' not in (regression / (label + '.stderr.log')).read_text(encoding='utf-8'), 'ROUTE_REGRESSION_' + label)
    partial = read(regression / 'partial-worker.json')
    require(len(partial['partial_packets']) == 63 and partial['final_partial_memory']['standing_samples_observed'] == 60
        and partial['final_state']['canonical_start_global_step'] is None, 'ROUTE_PARTIAL_HISTORY')
    return dict(ok=True, route_godot_checks_passed=45, worker_regression_godot_checks_passed=94,
        native_policy_facades=4, declared_prefix_phases=[241, 243], retained_evidence_files=len(seen),
        current_sources_verified=current_sources, **record['claim_boundary'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('R10K_ROUTE_INTEGRATION ' + json.dumps(audit(args.current_sources), separators=(',', ':')))
