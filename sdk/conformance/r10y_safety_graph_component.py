"""Check retained gate integration evidence; the complete gate has not run."""
import argparse
import json
from pathlib import Path

import r10y_launcher_component as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10y_safety_graph_component_v1.json'
FAILED = EVIDENCE / 'r10y-safety-integration-e016e553ade8410d98fdde54944b2a7d'
RUNS = [EVIDENCE / ('r10y-safety-integration-' + suffix) for suffix in (
    '7355b6867f0a4d7284f5f8579c07d697', '498f481d7e8a414aa11f657939ddbaeb')]
KEYS = [ROOT / 'sdk/recovery' / f'r10y_v56_walking_entry_contract_v{i}.json' for i in (14, 15)]
CONTRACTS = [ROOT / 'sdk/development' / f'r10y_safety_stage_contract_v{i}.json' for i in (1, 2)]
POPULATIONS = [[('r10y_runtime', 4), ('r10y_native_control', 2), ('r10y_measured_body', 14),
    ('r10y_walking_boundaries', 1), ('r10y_launcher', 3)],
    [('r10y_launch_guard', 7), ('r10y_launcher', 3), ('r10y_compact_retention', 1)]]


def child_roots():
    roots = set()
    for folder in RUNS:
        for log in folder.glob('*.stdout.log'):
            for line in log.read_text(encoding='utf-8').splitlines():
                if ' ' not in line: continue
                label, value = line.split(' ', 1)
                if label.endswith(('_ROOT', '_EVIDENCE', '_CHECK')):
                    path = Path(value.strip())
                    if path.parent == EVIDENCE and path.is_dir(): roots.add(path)
    return sorted(roots)


def observations():
    assert prior.audit()['ok']
    failed = native.read(FAILED / 'result.json')
    assert failed['ok'] is False and failed['stages'] == []
    assert 'EXACT_JSON_UNSUPPORTED_TYPE:System.Threading.Mutex' in failed['failure_code']
    for folder, key, expected, inputs in zip(RUNS, KEYS, POPULATIONS, (1301, 1305), strict=True):
        assert prior.prior.prior.retained_source_key(key, folder) == inputs
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
        result = native.read(folder / 'result.json')
        assert result['ok'] is True and result['failure_code'] == ''
        assert result['world_build_count'] == result['solver_step_count'] == 0
        assert [(s['id'], s['test_count']) for s in result['stages']] == expected
        for stage in result['stages']:
            assert stage['passed'] is True and stage['timed_out'] is False and stage['exit_code'] == 0
            assert stage['test_count'] == stage['expected_test_count']
            for stream in ('stdout', 'stderr'):
                assert native.diagnosis.binding(folder / stage[stream])['raw_sha256'] == 'sha256:' + stage[stream + '_sha256']
    roots = child_roots()
    discoveries = [native.read(p / 'stage-discovery.json') for p in roots if (p / 'stage-discovery.json').is_file()]
    assert sorted((len(v['stages']), v['total_tests']) for v in discoveries) == [(48, 169), (49, 170)]
    for path, stages, tests in zip(CONTRACTS, (48, 49), (169, 170), strict=True):
        fixed = native.read(path)
        assert len(fixed['stages']) == stages and sum(s['tests'] for s in fixed['stages']) == fixed['total_tests'] == tests
        ids = {s['id'] for s in fixed['stages']}
        assert len(ids) == stages and fixed['complete_applicable_coverage'] is True
        assert set(k for group in fixed['coverage_by_risk'].values() for k in group) == ids
    retained = next(p for p in roots if p.name.startswith('r10y-retention-check-'))
    value = native.read(retained / 'result.json')
    assert value['ok'] is True and len(value['cases']) == 8 and all(c['passed'] for c in value['cases'])
    assert native.read(retained / 'source_before.json') == native.read(retained / 'source_after.json')
    return dict(ok=True, preliminary_tests=35, targeted_stage_executions=8,
        declared_stages=49, declared_tests=170, fresh_stage_discovery_checked=True,
        selected_dll_runtime_body_and_native_walking_boundaries_checked=True,
        cold_partial_native_calls=1978, orchestrator_checks=54, retained_payload_controls=8,
        original_wrapper_refusal_retained=True, complete_smoke_safety_gate_passed=False,
        physical_attempt_started=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    observed = observations()
    files = [p for folder in (FAILED, *RUNS, *child_roots()) for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10y_safety_graph_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='prospective_smoke_safety_graph_and_targeted_integration', question_class='development'),
        prior_launcher_component=native.diagnosis.binding(prior.RECORD), auditor=native.diagnosis.binding(Path(__file__)),
        source_keys=[native.diagnosis.binding(p) for p in KEYS], contracts=[native.diagnosis.binding(p) for p in CONTRACTS],
        retained_evidence=[native.diagnosis.binding(p) for p in files], observed=observed,
        next_action='From a clean pushed prospective freeze, execute the complete 49-stage gate. Only a full pass may reserve the one phase-248 SingleKick diagnostic. No gate receipt is reused from these component checks.'))
    return observed


def audit():
    value = native.read(RECORD)
    for row in [value['prior_launcher_component'], value['auditor'], *value['source_keys'], *value['contracts'], *value['retained_evidence']]:
        native.verify(row)
    observed = observations()
    assert value['observed'] == observed
    return observed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10Y_SAFETY_GRAPH_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
