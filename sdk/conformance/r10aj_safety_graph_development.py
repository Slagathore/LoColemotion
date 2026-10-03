"""Audit targeted safety development; a fresh complete supervisor gate is required."""
import json
from pathlib import Path
import re
import hashlib
import r10aj_development as identity
from r10aa_native_component import verify

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10aj_safety_graph_development_v1.json'
CLAIMS = dict(complete_safety_graph_declared=True, targeted_checks_are_qualification=False,
    complete_safety_gate_qualified=False, physical_execution_authorized=False,
    complete_physical_route_proven=False, world_build_count=0, solver_step_count=0,
    physical_acceptance_authority=False, release_authority=False)


def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def audit():
    record = read(RECORD)
    assert record['schema_version']=='sporespore_r10aj_safety_graph_development_v1'
    assert record['claim_boundary']==CLAIMS
    for item in record['bindings']: verify(item)
    graph = read(ROOT/record['graph']['path'])
    assert identity.sha(ROOT/record['graph']['path'])==record['graph']['raw_sha256']
    assert len(graph['stages'])==75 and graph['total_tests']==258
    assert sum(s['tests'] for s in graph['stages'])==258 and len(graph['coverage'])==16
    expected={s['pattern']:s['tests'] for s in graph['stages']}
    archives={(r['original_path'],r['raw_sha256']):Path(r['path']) for r in record['historical_source_archives']}
    passed={};failures=[]
    for attempt in record['attempts']:
        root=Path(attempt['evidence_root']);execution=read(root/'execution.json')
        assert execution['source_unchanged'] is execution['tokens_unchanged'] is True
        assert read(root/'source-before.json')==read(root/'source-after.json')
        assert read(root/'tokens-before.json')==read(root/'tokens-after.json')==[]
        assert execution['ok'] is attempt['ok']
        dependencies=read(root/'dependencies.json');verify(dependencies['source_key'])
        for item in dependencies['files']:
            path=ROOT/item['path'];raw=path.read_bytes()
            if 'sha256:'+hashlib.sha256(raw).hexdigest()!=item['raw_sha256']:
                path=archives[(item['path'],item['raw_sha256'])];raw=path.read_bytes()
            assert len(raw)==item['byte_length'] and 'sha256:'+hashlib.sha256(raw).hexdigest()==item['raw_sha256']
        for stage in execution['stages']:
            name=stage['pattern'].removesuffix('.py')
            assert stage==read(root/(name+'.execution.json')) and stage['timed_out'] is False
            log=(root/(name+'.stderr.txt')).read_text()
            if stage['passed']:
                assert stage['returncode']==0 and log.rstrip().endswith('OK') and 'skipped=' not in log
                assert re.findall(r'Ran (\d+) tests? in ',log)==[str(expected[stage['pattern']])]
                passed[stage['pattern']]=expected[stage['pattern']]
            else:
                assert stage['returncode']==1 and 'FAILED (' in log
                failures.append(dict(attempt=root.name,pattern=stage['pattern']))
    assert len(passed)==22 and sum(passed.values())==56
    assert failures==record['failed_stages'] and all(r['pattern'] in passed for r in failures)
    startup=read(Path(record['startup_evidence_root'])/'result.json')
    assert startup['ok'] is startup['owned_dirty_source_refused'] is True
    assert startup['identity_checks']==8 and startup['native_preflight_passed'] is False
    assert startup['world_build_count']==startup['solver_step_count']==0
    return dict(ok=True,stages_declared=75,tests_declared=258,
        distinct_targeted_patterns_passed=22,distinct_targeted_tests_passed=56,
        retained_failed_stages=len(failures),**CLAIMS)


if __name__=='__main__': print(json.dumps(audit(),indent=2))
