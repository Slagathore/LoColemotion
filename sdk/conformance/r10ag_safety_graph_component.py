"""Audit selected V23 safety components and the prospective complete graph.

Component tests span named source snapshots. Only a new full supervisor gate
can qualify the final clean source; this record grants no world authority.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

import r10ag_development_launch as launch
import r10ag_launch_integration_component as previous
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

RECORD = ROOT / 'sdk/recovery/r10ag_safety_graph_component_v1.json'
PARENT = '746ca418913ea75a9392ecfa2f45d6344abab217'
BATCHES = [
    'r10ag-selected-safety-d16689d3c72a4b8395af85ec5b4f84b3',
    'r10ag-route-safety-a577cbced4f447aca2831eb93b4f28f6',
    'r10ag-route-repair-964e35384038459eb8670428cd2d71c5',
    'r10ag-hold-closure-6abfdcd3b98247ec9f070aaef9e98c13',
]
STARTUP = EVIDENCE / 'r10ag-startup-preflight-2156f256fd694f68a5b0add6bf5850c2'
CLAIMS = dict(complete_safety_graph_declared=True, complete_safety_gate_qualified=False,
    physical_execution_authorized=False, physical_acceptance_authority=False,
    release_authority=False, physical_attempt_started_at_checkpoint=False,
    world_build_count=0, solver_step_count=0, sdk1_score='14/20', full_program_score='14/25')


def historical_launch():
    raw = subprocess.check_output(['git', 'cat-file', 'blob', PARENT + ':' + previous.RECORD.relative_to(ROOT).as_posix()], cwd=ROOT)
    record = read(previous.RECORD)
    assert json.loads(raw) == record and record['claim_boundary'] == previous.CLAIMS
    for item in [record['auditor'], *record['bindings']]:
        path = Path(item['path'])
        if bind(path) == item:
            continue
        assert path.is_relative_to(ROOT), path
        raw = subprocess.check_output(['git', 'cat-file', 'blob', PARENT + ':' + path.relative_to(ROOT).as_posix()], cwd=ROOT)
        variants = [raw] if b'\r\n' in raw else [raw, raw.replace(b'\n', b'\r\n')]
        assert any(len(data) == item['byte_length'] and 'sha256:' + hashlib.sha256(data).hexdigest() == item['raw_sha256'] for data in variants), path
    return dict(ok=True, source_commit=PARENT, component=bind(previous.RECORD),
        historical_reports=previous.historical_reports(), current_source_qualification=False)


def observations():
    statuses, runs, roots = {}, [], set()
    for name in BATCHES:
        root = EVIDENCE / name
        execution = read(root / 'execution.json')
        stderr = (root / 'stderr.log').read_text(encoding='utf-8-sig')
        rows = re.findall(r'^test_\S+ \(([^)]+)\) \.\.\. (ok|FAIL|ERROR)$', stderr, re.M)
        assert len(rows) == execution['tests']
        statuses.update(rows)
        assert execution['complete_safety_gate'] is False
        runs.append(dict(root=root.as_posix(), execution=execution))
        for line in (root / 'stdout.log').read_text(encoding='utf-8-sig').splitlines():
            match = re.search(r'(?:ROOT|EVIDENCE)\s+([A-Za-z]:[\\/].*)$', line)
            if match:
                path = Path(match[1]).resolve()
                assert path.parent == EVIDENCE.resolve() and path.name.startswith(('r10ag-', 'development-v50-godot-body-')), path
                roots.add(path)
    assert len(statuses) == 47 and set(statuses.values()) == {'ok'}, statuses
    snapshots, legacy_snapshot_gaps = [], []
    for root in sorted(roots):
        pairs = [('source_before.json', 'source_after.json'), ('source-before.json', 'source-after.json'), ('r10ag-source-before.json', 'r10ag-source-after.json')]
        matches = [(root / before, root / after) for before, after in pairs if (root / before).exists()]
        if not matches:
            assert root.name == "development-v50-godot-body-4520a83ce7fe4426b47c52a79dd3ca80", root
            legacy_snapshot_gaps.append(root.as_posix())
            continue
        assert len(matches) == 1, root
        before, after = matches[0]
        assert read(before) == read(after), root
        snapshots.append(dict(root=root.as_posix(), before=bind(before), after=bind(after)))
    startup = read(STARTUP / 'result.json')
    assert startup['ok'] is True and startup['native_preflight_passed'] is True
    assert startup['source_commit'] == PARENT and startup['source_clean'] is True
    assert startup['candidate_source_key_checked'] is False and startup['complete_safety_gate_checked'] is False
    assert startup['world_build_count'] == startup['solver_step_count'] == 0
    return dict(distinct_component_tests_passed=47, total_test_executions=sum(r['execution']['tests'] for r in runs),
        retained_batches=runs, source_snapshots=snapshots, evidence_roots=[p.as_posix() for p in sorted(roots)],
        inherited_adapter_local_snapshot_gap=legacy_snapshot_gaps, clean_startup=bind(STARTUP / 'result.json'),
        clean_startup_source=PARENT, final_source_qualification=False)


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in [record['auditor'], *record['bindings']]:
        assert bind(item['path']) == item, item['path']
    graph = launch.contract()
    assert len(graph['stages']) == 65 and graph['total_tests'] == 240 and len(graph['coverage']) == 13
    assert record['historical_launch'] == historical_launch()
    assert record['observed'] == observations()
    return dict(ok=True, distinct_component_tests_passed=47, stages=65, tests=240,
        population_correction=launch.population.audit(), **CLAIMS)


def create():
    assert not RECORD.exists()
    assert not (EVIDENCE / launch.TOKEN).exists()
    observed = observations()
    names = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD'], cwd=ROOT, text=True).splitlines()
    names += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], cwd=ROOT, text=True).splitlines()
    selectors = {'sdk/conformance/development_recovery_candidate.py', 'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd'}
    paths = {ROOT / name for name in names if Path(name).suffix in ('.py', '.gd', '.json') and name not in selectors}
    roots = [EVIDENCE / name for name in BATCHES] + [Path(path) for path in observed['evidence_roots']] + [STARTUP]
    for root in roots:
        paths.update(path for path in root.rglob('*') if path.is_file())
    record = dict(schema_version='sporespore_r10ag_safety_graph_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_selected_controller_safety_components', question_class='development'),
        auditor=bind(__file__), bindings=[bind(path) for path in sorted(paths)], observed=observed,
        historical_launch=historical_launch(), claim_boundary=CLAIMS,
        retained_failures=[
            'Initial scheduler fixture read state instead of state_after; worker fixtures had not selected v7 telemetry identity.',
            'Segment fixture omitted v7 selection; shared hold fixture omitted AG aliases, sample retention and post-hold phase.',
            'Immutable finite-task document inherited seed 51008; distinct population correction binds existing design seed 65248 without modifying the evaluator or original document.'],
        limitations=[
            'The 47 passing tests span explicit source snapshots and are not a complete gate on the final admission key. The inherited measured-body fixture retains selected runtime, inputs and commands but no local before/after snapshot; the full gate must bind its enclosing source.',
            'Prior clean startup was verified at 746ca418; the full supervisor must repeat it at the prospective freeze.',
            'Synthetic scheduler outer identities are copied and rehashed; original V23 native receipt identities remain unchanged.',
            'A positive single-kick diagnostic still requires fresh paired commissioning, official qualification, fresh held-out acceptance and M07 adoption.'])
    result = audit(record)
    write_new(RECORD, record)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print(json.dumps(create() if args.create else audit(read(RECORD))))
