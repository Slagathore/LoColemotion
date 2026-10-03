"""Independent serialized R10AP worker-segment replay; no full-route authority."""
import argparse
import json
from pathlib import Path
import re
import traceback
import uuid

import r10ap_worker_component as worker

native = worker.native
ROOT, EVIDENCE = worker.ROOT, worker.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10ap_segment_reader_component_v1.json'
SCRIPT = ROOT/'tests/test_development_r10ap_segment_reader.gd'
CLAIMS = dict(synthetic_measurements_only=True, full_report_checked=False,
    candidate_admission_exercised=False, complete_safety_gate_qualified=False,
    world_build_count=0, solver_step_count=0, physical_acceptance_authority=False,
    release_authority=False)


def dependencies():
    paths = {Path(__file__), Path(worker.__file__), worker.RECORD}
    pending = [SCRIPT]
    while pending:
        path = pending.pop()
        if path in paths:
            continue
        paths.add(path)
        if path.suffix == '.gd':
            for resource in re.findall(r'res://([^"\s]+)', path.read_text()):
                target = ROOT/resource
                if target.is_file() and target not in paths:
                    pending.append(target)
    return sorted(paths)


def validate(out):
    worker.validate_child(out, 'reader', None)
    result = native.closure.read(out/'reader.json')
    replay = result['replay']
    expected = dict(transition_count=303, entry_observation_count=240,
        partial_observation_count=63, canonical_initialization_count=0,
        canonical_observation_count=0, complete_route_proven=False)
    assert all(replay.get(k) == v for k, v in expected.items())
    assert all(result.get(k) == v for k, v in CLAIMS.items()
        if k in ('synthetic_measurements_only', 'full_report_checked',
            'world_build_count', 'solver_step_count', 'physical_acceptance_authority', 'release_authority'))
    return dict(checks_passed=len(result['checks']), **expected)


def run():
    assert not RECORD.exists()
    out = EVIDENCE/('r10ap-segment-component-'+uuid.uuid4().hex)
    out.mkdir()
    print('R10AP_SEGMENT_ROOT '+out.as_posix(), flush=True)
    worker.audit()
    source = Path(native.closure.read(worker.RECORD)['evidence_root'])/'partial.json'
    bindings = [native.closure.bind(p) for p in [*dependencies(), source]]
    before = worker.source._source_snapshot()
    native.closure.write_new(out/'source-before.json', before)
    native.closure.write_new(out/'bindings-before.json', bindings)
    execution = dict(ok=False, **CLAIMS)
    try:
        engine = native.inputs()[-1]
        native.closure.write_new(out/'declaration.json', dict(source=native.closure.bind(source),
            engine=engine, covered='Serialized partial segment, all 303 transitions and native replays; old reader, old owner, crossed memory and retention refusal.',
            not_covered='Fresh initialization, full report, hold/walking consumption, launch or physics.', **CLAIMS))
        worker.run_child(out, 'reader', SCRIPT.name, source, engine)
        observed = validate(out)
        native.closure.write_new(out/'result.json', dict(observed=observed, **CLAIMS))
        execution['ok'] = True
    except BaseException:
        execution['error'] = traceback.format_exc()
        raise
    finally:
        after = worker.source._source_snapshot()
        ending = [native.closure.bind(p) for p in [*dependencies(), source]]
        native.closure.write_new(out/'source-after.json', after)
        native.closure.write_new(out/'bindings-after.json', ending)
        execution['source_unchanged'] = before == after and bindings == ending
        native.closure.write_new(out/'execution.json', execution)
    assert execution['source_unchanged']
    native.closure.write_new(RECORD, dict(schema_version='sporespore_r10ap_segment_reader_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_serialized_segment_replay', question_class='development'),
        evidence_root=out.as_posix(), dependencies=bindings,
        retained_evidence=[native.closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],
        observed=observed, claim_boundary=CLAIMS,
        next_action='Bind the prospective candidate and full production report reader, including positive hold and walking, then complete the entire applicable safety graph before any fresh diagnostic world.'))
    return observed


def audit():
    record = native.closure.read(RECORD)
    assert record['claim_boundary'] == CLAIMS
    for item in record['dependencies'] + record['retained_evidence']:
        native.builds.verify(item)
    worker.audit()
    out = Path(record['evidence_root'])
    assert native.closure.read(out/'source-before.json') == native.closure.read(out/'source-after.json')
    assert native.closure.read(out/'bindings-before.json') == native.closure.read(out/'bindings-after.json') == record['dependencies']
    execution = native.closure.read(out/'execution.json')
    assert execution['ok'] and execution['source_unchanged']
    observed = validate(out)
    assert record['observed'] == observed == native.closure.read(out/'result.json')['observed']
    return dict(observed=observed, **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(), indent=2))
