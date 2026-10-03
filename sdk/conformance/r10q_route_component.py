"""Verify retained R10Q route integration evidence without creating worlds.

The full-report reader, launch gate and physical task remain separate gates.
Every original failed review is retained with its original source snapshot.
"""
import json
from pathlib import Path
import development_recovery_candidate as candidate
import r10p_entry_domain_diagnosis as prior

ROOT = prior.ROOT
RECORD = ROOT / 'sdk/recovery/r10q_route_component_v1.json'


def require(value, code):
    if not value:
        raise ValueError('R10Q_ROUTE_COMPONENT_' + code)


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    actual = prior.binding(path)
    require(actual['raw_sha256'] == item['raw_sha256'] and actual['byte_length'] == item['byte_length'], 'BINDING:' + str(path))
    return path


def audit(record):
    require(record['schema_version'] == 'sporespore_r10q_route_component_v1', 'SCHEMA')
    claims = dict(world_build_count=0, solver_step_count=0, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, complete_report_validated=False,
        complete_smoke_safety_gate_passed=False, full_360_phase_startup_sweep_complete=False,
        successor_physics_observed=False, original_results_regraded=False, sdk1_score='14/20')
    require(record['claim_boundary'] == claims, 'CLAIMS')
    verify(record['auditor'])
    for item in record['tested_source_files'] + record['retained_evidence']:
        verify(item)
    runtime = json.loads(verify(record['runtime_binding']).read_bytes())
    verify(runtime['runtime'])
    for item in runtime['source_files']:
        verify(item)
    selected = candidate.selection(record['candidate_profile'])
    require(selected['diagnostic_schedule']['walking_policy_id'] == 'r10q_v55_upright_recovery_route_v1'
        and selected['reader'] == 'res://sdk/trace_analysis/r10q_recovery_replay.gd', 'PROFILE_SELECTION')
    root = Path(record['successful_review'])
    for name, count in [('finite', 9), ('routes', 3)]:
        execution = json.loads((root / (name + '.execution.json')).read_bytes())
        require(execution['exit_code'] == 0 and execution['world_build_count'] == execution['solver_step_count'] == 0, 'TEST_EXECUTION')
        log = (root / (name + '.stderr.log')).read_text()
        require('Ran ' + str(count) + ' tests in ' in log and log.rstrip().endswith('OK'), 'TEST_POPULATION')
    require((root / 'routes/source_before.json').read_bytes() == (root / 'routes/source_after.json').read_bytes(), 'SOURCE_DRIFT')
    results = {}
    for name, count in [('routes', 50), ('producer', 23), ('reader', 18)]:
        result = json.loads((root / ('routes/' + name + '.json')).read_bytes())
        execution = json.loads((root / ('routes/' + name + '.execution.json')).read_bytes())
        require(execution['exit_code'] == 0 and result['ok'] is True and len(result['checks']) == count
            and all(value is True for value in result['checks'].values()), 'GODOT_RESULT:' + name)
        require(result['world_build_count'] == result['solver_step_count'] == 0 and
            result['physical_acceptance_authority'] is False and result['release_authority'] is False, 'GODOT_CLAIMS')
        results[name] = result
    failed = json.loads((Path(record['failed_review']) / 'routes.json').read_bytes())
    require(failed['ok'] is False and [key for key, value in failed['checks'].items() if not value] == ['ramp_production_motor_ledger'], 'ORIGINAL_FAILURE')
    require(failed['result']['ramp']['ledger']['detail']['failure_code'] == 'ADAPTER_NATIVE_SAFE_NO_ACTUATION:FRAME_INVALID', 'ORIGINAL_REFUSAL')
    fixture = results['producer']['input']
    require(results['producer']['selector_exercised'] is True and results['producer']['launcher_validation_exercised'] is False
        and results['producer']['synthetic_measurements_only'] is True and results['producer']['complete_report_exercised'] is False, 'FIXTURE_SCOPE')
    retained = fixture['retention']
    require(len(retained['orchestrator_transitions']) == 304 and len(retained['entry_packets']) == 240
        and not retained['canonical_packets'] and not fixture['partial_retention']['step_packets'], 'NATIVE_POPULATION')
    upright = fixture['upright_retention']
    require(len(upright['step_packets']) == 63 and upright['final_memory']['standing_samples_observed'] == 60
        and fixture['final_state']['upright_stabilization_complete'] is True
        and fixture['final_state']['partial_standing_complete'] is False, 'UPRIGHT_COMPLETION')
    replay = results['reader']['replay']
    require(replay['ok'] is True and replay['transition_count'] == 304 and replay['entry_observation_count'] == 240
        and replay['upright_observation_count'] == 63 and replay['canonical_initialization_count'] == 0
        and replay['partial_initialization_count'] == 0 and results['reader']['complete_report_exercised'] is False, 'COLD_SEGMENT_REPLAY')
    return dict(ok=True, tests_passed=12, godot_checks_passed=91, replayed_transitions=304,
        passive_samples=240, upright_samples=63, consecutive_standing_samples=60, **claims)


if __name__ == '__main__':
    print('R10Q_ROUTE_COMPONENT ' + json.dumps(audit(json.loads(RECORD.read_bytes())), separators=(',', ':')))
