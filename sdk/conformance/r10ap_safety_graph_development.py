"""Authenticate retained safety development without granting qualification.

Every observed source key is reconstructed from its retained snapshot and Git
parent. A later passing stage does not alter an earlier failure. The real clean
supervisor must still execute the entire graph, including fresh report cases.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re

import r10ap_development as identity
import r10ap_development_launch as launch
import r10ap_safety_development as development
from r10ap_route_integration import committed_blobs
from r10ac_support_loss_diagnosis import binding
from r10aa_native_component import verify

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ap_safety_graph_development_v1.json'
CLAIMS = dict(complete_safety_graph_declared=True, targeted_checks_are_qualification=False,
    complete_safety_gate_qualified=False, physical_execution_authorized=False,
    complete_physical_route_proven=False, world_build_count=0, solver_step_count=0,
    physical_acceptance_authority=False, release_authority=False)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def authenticate_source(root):
    before = read(root / 'source-before.json')
    assert before == read(root / 'source-after.json')
    dependencies = read(root / 'dependencies.json')
    verify(dependencies['source_key'])
    assert dependencies['files'] == read(dependencies['source_key']['path'])['bound_source_files']
    changed = {row['path']: row for row in before['changed_files']}
    needed = [row['path'] for row in dependencies['files'] if row['path'] not in changed]
    blobs = committed_blobs(before['head'], needed)
    for row in dependencies['files']:
        replacement = changed.get(row['path'])
        if replacement is not None:
            assert not replacement['deleted']
            variants = [base64.b64decode(replacement['replacement_base64'], validate=True)]
        else:
            raw = blobs[row['path']]
            variants = [raw, raw.replace(b'\n', b'\r\n')] if b'\r\n' not in raw else [raw]
            current = (ROOT / row['path']).read_bytes()
            if current.replace(b'\r\n', b'\n') == raw.replace(b'\r\n', b'\n'):
                variants.append(current)
        assert any(len(raw) == row['byte_length'] and
            'sha256:' + hashlib.sha256(raw).hexdigest() == row['raw_sha256'] for raw in variants), row['path']
    return dependencies['source_key']


def inspect(startup_root):
    graph = launch.contract()
    assert len(graph['stages']) == 75 and graph['total_tests'] == 258
    expected = {s['pattern']: s for s in graph['stages']}
    required = {s['pattern'] for s in graph['stages'] if s['id'] in development.DEFAULT_IDS}
    attempts, passed, failures, roots = [], {}, [], set()
    for root in sorted(EVIDENCE.glob('r10ap-safety-development-*')):
        execution = read(root / 'execution.json')
        assert execution['source_unchanged'] is execution['tokens_unchanged'] is True
        assert read(root / 'tokens-before.json') == read(root / 'tokens-after.json') == []
        key = authenticate_source(root)
        roots.add(root)
        for stage in execution['stages']:
            name = stage['pattern'].removesuffix('.py')
            assert stage == read(root / (name + '.execution.json'))
            assert stage['pattern'] in required and stage['tests'] == expected[stage['pattern']]['tests']
            assert stage['timed_out'] is False
            log = (root / (name + '.stderr.txt')).read_text()
            if stage['passed']:
                assert stage['returncode'] == 0 and log.rstrip().endswith('OK') and 'skipped=' not in log
                assert re.findall(r'Ran (\d+) tests? in ', log) == [str(stage['tests'])]
                passed[stage['pattern']] = dict(tests=stage['tests'], source_key=key, evidence_root=root.as_posix())
            else:
                assert stage['returncode'] == 1 and ('FAILED (' in log or 'Traceback' in log)
                failures.append(dict(evidence_root=root.as_posix(), pattern=stage['pattern'], source_key=key))
            for line in (root / (name + '.stdout.txt')).read_text().splitlines():
                match = re.fullmatch(r'[A-Z0-9_]+(?:ROOT|CHECK|EVIDENCE) (C:[\\/].+)', line)
                if match:
                    child = Path(match[1]).resolve()
                    assert child.parent == EVIDENCE and child.is_dir()
                    roots.add(child)
        assert execution['ok'] == all(s['passed'] for s in execution['stages'])
        attempts.append(dict(evidence_root=root.as_posix(), ok=execution['ok'], source_key=key))
    assert set(passed) == required
    startup_root = Path(startup_root).resolve()
    assert startup_root.parent == EVIDENCE
    startup = read(startup_root / 'result.json')
    assert startup['ok'] is startup['owned_dirty_source_refused'] is True
    assert startup['native_preflight_passed'] is False and startup['identity_checks'] == 8
    assert startup['world_build_count'] == startup['solver_step_count'] == 0
    roots.add(startup_root)
    return dict(graph=binding(launch.CONTRACT), attempts=attempts, passed=passed,
        failed_stages=failures, startup_evidence_root=startup_root.as_posix(),
        evidence=[binding(p) for root in sorted(roots) for p in sorted(root.rglob('*')) if p.is_file()])


def main(close=False, startup_root=None):
    if close:
        assert not RECORD.exists() and startup_root
        result = inspect(startup_root)
        development.write(RECORD, dict(schema_version='sporespore_r10ap_safety_graph_development_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                authority_mode='targeted_zero_world_safety_development', question_class='development'),
            **result, claim_boundary=CLAIMS,
            next_action='Run the complete fresh supervisor gate at the clean pushed freeze before the single diagnostic. Targeted results across source keys are not qualification.'))
    else:
        record = read(RECORD)
        assert record['claim_boundary'] == CLAIMS
        for item in record['evidence']: verify(item)
        result = inspect(record['startup_evidence_root'])
        assert all(record[k] == value for k, value in result.items())
    return dict(stages_declared=75, tests_declared=258,
        targeted_patterns_passed=len(result['passed']),
        targeted_tests_passed=sum(v['tests'] for v in result['passed'].values()),
        retained_failed_stages=len(result['failed_stages']), **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--close', action='store_true'); parser.add_argument('--startup-root', type=Path)
    args = parser.parse_args()
    print(json.dumps(main(args.close, args.startup_root), indent=2))
