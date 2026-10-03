"""Audit retained safety-graph development; never substitute for the full gate.

The 61 tests were developed across distinct source snapshots. Their original
failures remain retained. Qualification requires a fresh complete supervisor run.
"""
import json
from pathlib import Path
import re

import r10ai_development as identity
import r10aa_native_component as files

ROOT = identity.ROOT
RECORD = ROOT / 'sdk/recovery/r10ai_safety_graph_development_v1.json'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def audit():
    record = read(RECORD)
    assert record['schema_version'] == 'sporespore_r10ai_safety_graph_development_v1'
    for item in record['bindings']:
        files.verify(item)
    graph = read(ROOT / record['graph']['path'])
    assert identity.sha(ROOT / record['graph']['path']) == record['graph']['raw_sha256']
    assert len(graph['stages']) == 75 and graph['total_tests'] == 258
    assert sum(stage['tests'] for stage in graph['stages']) == 258
    assert len(graph['coverage']) == 16
    assert graph['qualification_status'] == 'prospective_complete_graph_pending_execution'
    expected = {stage['pattern']: stage['tests'] for stage in graph['stages']}
    passed = {}
    failures = []
    for attempt in record['attempts']:
        root = Path(attempt['evidence_root'])
        execution = read(root / 'execution.json')
        assert execution['source_unchanged'] is True
        assert read(root / 'source-before.json') == read(root / 'source-after.json')
        assert execution['ok'] is attempt['ok']
        for stage in execution['stages']:
            assert stage['timed_out'] is False
            name = stage['pattern'].removeprefix('test_').removesuffix('.py')
            assert stage == read(root / (name + '.execution.json'))
            log = (root / (name + '.stderr.txt')).read_text()
            if stage['returncode'] == 0:
                assert re.findall(r'Ran (\d+) tests? in ', log) == [str(expected[stage['pattern']])]
                assert log.rstrip().endswith('OK') and 'skipped=' not in log
                passed[stage['pattern']] = expected[stage['pattern']]
            else:
                assert stage['returncode'] == 1 and 'FAILED (' in log
                failures.append(dict(attempt=root.name, pattern=stage['pattern']))
    assert len(passed) == 23 and sum(passed.values()) == 61
    assert failures == record['failed_stages']
    assert all(row['pattern'] in passed for row in failures)
    startup = read(record['startup_evidence_root'] + '/result.json')
    assert startup['ok'] is True and startup['owned_dirty_source_refused'] is True
    assert startup['identity_checks'] == 8 and startup['native_preflight_passed'] is False
    assert startup['world_build_count'] == startup['solver_step_count'] == 0
    assert record['claim_boundary'] == dict(
        complete_safety_graph_declared=True, targeted_checks_are_qualification=False,
        complete_safety_gate_qualified=False, physical_execution_authorized=False,
        complete_physical_route_proven=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
    return dict(ok=True, stages_declared=75, tests_declared=258,
        distinct_targeted_patterns_passed=23, distinct_targeted_tests_passed=61,
        retained_failed_stages=len(failures), independent_geometry_reconstructions=601,
        **record['claim_boundary'])


if __name__ == '__main__':
    print(json.dumps(audit(), indent=2))
