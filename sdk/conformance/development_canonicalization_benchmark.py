"""Opt-in, zero-world comparison of two immutable compiled canonicalizers.

Retained inputs are data, not a replay under a new controller. Timings cover the
unchanged Python/C ABI wrapper (including its two buffer calls), not Godot,
physics, or the complete reader. Run under the repository operation lock.
"""
import argparse
import json
from pathlib import Path
import sys
import time
import uuid

import development_passive_entry_profile as entry
import development_recovery_candidate as candidate

sys.path.insert(0, str(entry.ROOT / 'sdk/python'))
from sporespore_locomotion import LocomotionCore, LocomotionCoreError

REPORT = entry.EVIDENCE / ('development-recovery-smoke-46cc3bddeed5433d8c25f6f3ae16e11c/'
                         'children/kick_passive_recovery_resume/worker_report.json')
REPORT_SHA = 'sha256:0cfacdd8cab241f50e9623168d6551f74ca04ae51fe6f723b059ec6a1126e267'


def outcome(core, value):
    try:
        result = core.canonicalize_json(value)
    except LocomotionCoreError as error:
        return dict(ok=False, status=error.status, failure_code=error.failure_code, detail=error.detail)
    candidate.require(result['sha256'] == entry.digest(result['canonical_json'].encode('utf-8')),
                      'BENCHMARK_RECEIPT_DIGEST')
    candidate.require(result['world_build_count'] == 0 and result['physical_acceptance_authority'] is False,
                      'BENCHMARK_RECEIPT_AUTHORITY')
    return dict(ok=True, value=result)


def write_new(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False, allow_nan=False)
        stream.write('\n')


def run(baseline_path, candidate_path):
    selections = [candidate.selection(candidate.reference_for_path(path))
                  for path in (baseline_path, candidate_path)]
    bindings = [entry.binding(selection) for selection in selections]
    candidate.require(bindings[0]['runtime'] != bindings[1]['runtime'], 'BENCHMARK_IDENTICAL_IMAGE')
    candidate.require(selections[0]['post_kick_controller_id'] == selections[1]['post_kick_controller_id'],
                      'BENCHMARK_CONTROLLER_CHANGED')
    for source in bindings[1]['source_files']:
        candidate.require(entry.runtime.file_identity(entry.ROOT / source['path'], display_path=source['path']) == source,
                          'BENCHMARK_CANDIDATE_SOURCE_DRIFT')
    before = entry._source_snapshot()
    directory = entry.EVIDENCE / ('development-canonicalization-benchmark-' + uuid.uuid4().hex)
    directory.mkdir()
    print('CANONICALIZATION_BENCHMARK_ROOT', directory, flush=True)
    write_new(directory / 'source_snapshot.json', before)
    write_new(directory / 'declaration.json', dict(
        profiles=[selection['candidate_profile'] for selection in selections],
        runtimes=[binding['runtime'] for binding in bindings], report_sha256=REPORT_SHA,
        timing_order=[0, 1, 1, 0], repetitions=20, benchmark_packet_indices=[0, 26, 27, 266],
        expected_control_fixture_count=6,
        timing_scope='Python wrapper and exported C ABI, including two buffer calls; not Godot or physics.',
        original_attempt_reclassified=False, world_build_count=0, solver_step_count=0))
    raw = REPORT.read_bytes()
    candidate.require(entry.digest(raw) == REPORT_SHA, 'BENCHMARK_REPORT_DRIFT')
    report = entry.packet.parse_json(raw.decode('utf-8'))
    packets = report['passive_entry']['canonical_packets']
    candidate.require(len(packets) == 267 and report['solver_step_count'] == 626, 'BENCHMARK_POPULATION')
    transports = [packet['collection_transport'] for packet in packets]
    requests = [entry.packet.parse_json(value['request']['utf8_text']) for value in transports]
    edges = [None, True, False, 0, -0.0, 1.0, 1.234567890123456, 1e-30,
             9007199254740991, 9007199254740992, -9007199254740992,
             {'z': [0.0, -0.0, 2, 'é雪\n\t"\\'], 'a': {'x': 1.0}}]
    cores = [LocomotionCore(binding['runtime']['path']) for binding in bindings]
    checked = refused = 0
    for value in [*edges, *transports, *requests]:
        old, new = [outcome(core, value) for core in cores]
        candidate.require(old == new, 'BENCHMARK_EXACT_OUTPUT_MISMATCH_' + str(checked))
        checked += 1
        refused += int(not old['ok'])
    candidate.require(refused == 2, 'BENCHMARK_REFUSAL_POPULATION')
    print('CANONICALIZATION_PARITY', checked, 'matched;', refused, 'refusals', flush=True)
    fixture = bindings[0]['compiled_fixtures']
    candidate.require(entry.runtime.file_identity(Path(fixture['path'])) == fixture, 'BENCHMARK_FIXTURE_DRIFT')
    control_count = 0
    for line in Path(fixture['path']).read_text().splitlines():
        prefix, _, payload = line.partition(' ')
        if prefix.endswith('_CONTROL_FIXTURE'):
            case = entry.packet.parse_json(payload)
            if case['request']['controller_id'] == selections[0]['post_kick_controller_id']:
                old, new = [core.recovery_plan_control_v1(case['request']) for core in cores]
                candidate.require(old == new, 'BENCHMARK_CONTROL_OUTPUT_MISMATCH')
                control_count += 1
    candidate.require(control_count == 6, 'BENCHMARK_CONTROL_POPULATION')
    values = [transports[0], requests[26], requests[27], transports[266]]
    expected = [outcome(cores[0], value) for value in values]
    timings = []
    for which in [0, 1, 1, 0]:
        started = time.perf_counter()
        actual = [outcome(cores[which], value) for _ in range(20) for value in values]
        elapsed = time.perf_counter() - started
        candidate.require(actual == expected * 20, 'BENCHMARK_TIMED_OUTPUT_DRIFT')
        timings.append(dict(runtime_index=which, elapsed_seconds=elapsed, logical_calls=len(actual)))
        print('CANONICALIZATION_TIMING', json.dumps(timings[-1]), flush=True)
    candidate.require(entry.digest(REPORT.read_bytes()) == REPORT_SHA, 'BENCHMARK_REPORT_CHANGED')
    candidate.require(entry.packet.same(before, entry._source_snapshot()), 'BENCHMARK_SOURCE_CHANGED')
    for selection in selections:
        candidate.selection(selection['candidate_profile'])
    receipt = dict(schema_version='sporespore_development_canonicalization_benchmark_v2',
        ledger_scope=dict(subsystem='recovery', engine_scope='core_c_abi',
                          authority_mode='retained_data_performance_controls', question_class='development'),
        declaration=entry.runtime.file_identity(directory / 'declaration.json'),
        source_snapshot=entry.runtime.file_identity(directory / 'source_snapshot.json'),
        report=entry.runtime.file_identity(REPORT), exact_output_case_count=checked,
        refusal_case_count=refused, exact_control_fixture_count=control_count,
        baseline_control_fixtures=fixture, timings=timings, source_unchanged=True,
        original_attempt_reclassified=False, complete_reader_replayed=False,
        world_build_count=0, native_physics_read_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
    write_new(directory / 'receipt.json', receipt)
    print('CANONICALIZATION_BENCHMARK_RECEIPT', directory / 'receipt.json', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline-profile', required=True, type=Path)
    parser.add_argument('--candidate-profile', required=True, type=Path)
    args = parser.parse_args()
    run(args.baseline_profile, args.candidate_profile)
