"""Reopen the R10R native component, optionally repeating every original call."""
import argparse
import collections
import json
from pathlib import Path

from r10r_native_component import ROOT, RECORD, ExactInputCore, bind, read, LocomotionCoreError


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute(): path = ROOT / path
    actual = bind(path)
    assert actual['raw_sha256'] == item['raw_sha256'], item['path']
    if 'byte_length' in item: assert actual['byte_length'] == item['byte_length']
    return path


def audit(cold=False):
    record = read(RECORD)
    assert record['schema_version'] == 'sporespore_r10r_upright_native_component_v1'
    runtime = read(verify(record['runtime_binding']))
    for item in record['source_bindings'] + record['retained_evidence'] + [record['design_binding']]: verify(item)
    for item in runtime['source_files'] + runtime['build_evidence_files'] + [runtime['runtime'], runtime['compiled_fixtures']]: verify(item)
    assert record['core_tests'] == runtime['core_test_count'] == 410
    assert record['compiled_sources'] == len(runtime['source_files']) == 101
    root = Path(record['evidence_root'])
    assert (root/'source_before.json').read_bytes() == (root/'source_after.json').read_bytes()
    declaration, result = read(root/'declaration.json'), read(root/'result.json')
    assert result == record['observed'] and result['ok'] is True
    for item in declaration['sources'] + declaration['declarations']: verify(item)
    core = ExactInputCore(runtime['runtime']['path']) if cold else None
    counts, seen, controls = collections.Counter(), set(), []
    with (root/'native_calls.jsonl').open(encoding='utf-8') as stream:
        for line in stream:
            row = json.loads(line)
            identity = (row['group'], row['identity'])
            assert identity not in seen
            seen.add(identity)
            counts[row['group']] += 1
            response = row['response_raw_utf8'].encode()
            envelope = json.loads(response)
            if row['failure_code'] is None:
                assert envelope['ok'] is True
            else:
                assert row['group'] == 'negative_controls' and envelope['ok'] is False
                assert envelope['failure_code'] == row['failure_code']
                controls.append(dict(case=row['identity'], failure_code=row['failure_code']))
            if core:
                error = None
                try: core._call_json_input(row['method'], row['request_raw_utf8'].encode())
                except LocomotionCoreError as failure: error = failure.failure_code
                assert error == row['failure_code'] and core.raw_response == response, identity
    assert counts == declaration['expected_calls'] == result['populations']
    assert sum(counts.values()) == result['native_calls'] == 3191
    assert controls == result['negative_controls'] and len(controls) == 10
    for key in ['full_route_integrated','complete_smoke_safety_gate_passed','physical_response_predicted',
                'physical_acceptance_authority','release_authority']:
        assert result[key] is False
    assert result['physical_world_count'] == result['solver_step_count'] == 0
    return dict(ok=True, native_calls=3191, cold_replayed=3191 if cold else 0,
        core_tests=410, compiled_sources=101, negative_controls=10,
        original_q_report_responses_byte_identical=True, full_route_integrated=False,
        complete_smoke_safety_gate_passed=False, physical_world_count=0, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--cold', action='store_true')
    args = parser.parse_args()
    print('R10R_NATIVE_COMPONENT_AUDIT ' + json.dumps(audit(args.cold)), flush=True)
