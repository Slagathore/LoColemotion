"""Check the R10Y DLL exports and replay original partial calls byte-for-byte.

All inputs are supplied records or labeled synthetic fixtures. No engine world
is constructed. Historical calls keep their original API and raw input bytes.
Run this command under the repository native-operation lock.
"""
import argparse
from collections import Counter
import copy
import json
from pathlib import Path
import uuid

import development_passive_entry_profile as entry
import development_recovery_candidate_build as build
from development_recovery_refusal import RecordedCore
from sporespore_locomotion import LocomotionCoreError
import r10y_partial_recovery_diagnosis as diagnosis

ROOT, EVIDENCE = diagnosis.ROOT, diagnosis.EVIDENCE
BINDING = ROOT / 'sdk/development/recovery_candidates/r10y-partial-direct-neutral-core-v1.runtime.json'
RECORD = ROOT / 'sdk/recovery/r10y_partial_native_component_v1.json'
EXPECTED_COUNTS = dict(new_fixtures=5, negative_controls=17, original_partial_calls=1956)


class ExactInputCore(RecordedCore):
    @staticmethod
    def _input_bytes(value):
        return value if isinstance(value, bytes) else RecordedCore._input_bytes(value)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, indent=2, allow_nan=False) + '\n')


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    actual = diagnosis.binding(path)
    assert actual['raw_sha256'] == item['raw_sha256'], item['path']
    assert actual['byte_length'] == item['byte_length'], item['path']
    return path


def runtime():
    bound = read(BINDING)
    assert bound['core_test_count'] == 419
    assert bound['source_files'] == build.sources()
    for item in bound['build_evidence_files'] + [bound['runtime'], bound['compiled_fixtures']]:
        verify(item)
    fixtures = [json.loads(line.partition(' ')[2]) for line in verify(bound['compiled_fixtures']).read_text(encoding='utf-8').splitlines()
                if line.startswith('R10Y_PARTIAL_FIXTURE ')]
    assert [f['id'] for f in fixtures] == ['partial_entry', 'partial_step_1', 'partial_step_2', 'partial_step_3', 'partial_step_63']
    assert all(f['physical_source'] is False for f in fixtures)
    return bound, fixtures


def run():
    assert not RECORD.exists(), 'R10Y_NATIVE_COMPONENT_ALREADY_RETAINED'
    bound, fixtures = runtime()
    observed = read(diagnosis.RECORD)
    assert diagnosis.binding(diagnosis.RECORD)['raw_sha256'] == 'sha256:3611f3c1136c3b9e9b30da36b9d52efa3f79edab3517fff21d805d426a31b5d5'
    out = EVIDENCE / ('r10y-native-calls-' + uuid.uuid4().hex)
    out.mkdir()
    print('R10Y_NATIVE_CALLS_ROOT ' + out.as_posix(), flush=True)
    before = entry._source_snapshot()
    write(out / 'source_before.json', before)
    write(out / 'declaration.json', dict(expected_calls=EXPECTED_COUNTS, original_results_regraded=False,
        historical_calls_use_original_api_and_raw_bytes=True, world_build_count=0, solver_step_count=0))
    core, counts, controls = ExactInputCore(bound['runtime']['path']), Counter(), []
    with (out / 'native_calls.jsonl').open('x', encoding='utf-8', newline='\n') as trace:
        def call(group, identity, method, request, expected=None, response=None, refuse=False):
            result, failure = None, None
            try:
                result = core._call_json_input(method, request)
            except LocomotionCoreError as error:
                failure = error.failure_code
            raw = core.raw_response
            trace.write(json.dumps(dict(group=group, identity=identity, method=method,
                request_raw_utf8=core._input_bytes(request).decode('utf-8'),
                response_raw_utf8=raw.decode('utf-8'), failure_code=failure),
                separators=(',', ':'), allow_nan=False) + '\n')
            trace.flush()
            counts[group] += 1
            if refuse:
                assert failure is not None and result is None, identity
                controls.append(dict(case=identity, failure_code=failure))
            else:
                assert failure is None, (identity, failure)
                if expected is not None:
                    assert result == expected, identity
                if response is not None:
                    assert raw == response, identity
        for fixture in fixtures:
            call('new_fixtures', fixture['id'], 'ss_' + fixture['method'] + '_json',
                 fixture['request'], expected=fixture['expected'])
        for case in range(11):
            q = copy.deepcopy(fixtures[1]['request'])
            if case == 0: q['schema_version'] = 'sporespore_partial_fall_step_control_request_v1'
            elif case == 1: q['collection']['task_id'] = 'sporespore_measured_upright_recovery_to_standing_v1'
            elif case == 2: q['collection']['observation_source_binding']['source_route_id'] = 'unregistered'
            elif case == 3: q['collection']['observation']['controller_ownership']['recovery_controller_id'] = 'sporespore_exact_s169_prone_to_standing_controller_v20'
            elif case == 4: q['step']['observation']['semantic_step'] += 1
            elif case == 5: q['step']['observation']['energy_balance']['cumulative_signed_external_work_j'] = 0.0
            elif case == 6: q['step']['memory']['phase'] = 'stance_dwell'
            elif case == 7: q['collection']['observation']['state']['ordered_joint_observations'][0]['position_rad'] = None
            elif case == 8: q['collection']['runtime_binding']['collector_id'] = 'unregistered'
            elif case == 9: q['collection']['descriptor']['torso_length_scale'] += 0.01
            else: q['collection']['observation']['controller_ownership']['fallback_controller_active'] = True
            call('negative_controls', 'step_' + str(case), 'ss_recovery_r10y_partial_step_control_v1_json', q, refuse=True)
        for case in range(6):
            q = copy.deepcopy(fixtures[0]['request'])
            if case == 0: q['schema_version'] = 'sporespore_r10q_upright_entry_control_request_v1'
            elif case == 1: q['collection']['observation']['state']['base_pose_world']['position_m']['y'] += .001
            elif case == 2: q['collection']['observation_source_binding']['source_route_id'] = 'unregistered'
            elif case == 3: q['entry']['original_request']['passive_request']['observation']['energy_balance']['initial_mechanical_energy_j'] += 1
            elif case == 4: q['collection']['task_id'] = 'sporespore_measured_partial_fall_to_standing_v1'
            else: q['entry']['prior']['schema_version'] = 'crossed'
            call('negative_controls', 'entry_' + str(case), 'ss_recovery_r10y_partial_entry_control_v1_json', q, refuse=True)
        for observation in observed['observations']:
            path = verify(observation['report'])
            count = 0
            for kind, packet in diagnosis.read_partial(path):
                if kind != 'packet':
                    continue
                original = packet['call']
                assert original['method'] == 'recovery_partial_fall_step_control_v1_json'
                assert packet['native_receipt'] == original['value']
                request = original['request']['utf8_text'].encode('utf-8')
                response = original['response']['utf8_text'].encode('utf-8')
                assert diagnosis.digest(request) == original['request']['raw_sha256']
                assert diagnosis.digest(response) == original['response']['raw_sha256']
                count += 1
                call('original_partial_calls', str(observation['seed']) + ':' + str(count),
                     'ss_' + original['method'], request, response=response)
            assert count == observation['partial_steps']
            print('R10Y_ORIGINAL_PARTIAL_REPLAY ' + json.dumps(dict(seed=observation['seed'], calls=count)), flush=True)
    assert counts == EXPECTED_COUNTS
    after = entry._source_snapshot()
    write(out / 'source_after.json', after)
    assert before == after
    result = dict(ok=True, native_calls=sum(counts.values()), populations=dict(counts), negative_controls=controls,
        original_api_response_bytes_identical=True, full_route_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    write(out / 'result.json', result)
    record = dict(schema_version='sporespore_r10y_partial_native_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_native_component', question_class='development'),
        runtime_binding=diagnosis.binding(BINDING), evidence_root=out.as_posix(), observed=result,
        source_bindings=[diagnosis.binding(p) for p in (Path(__file__), diagnosis.RECORD,
            ROOT / 'sdk/conformance/r10y_partial_recovery_diagnosis.py',
            ROOT / 'sdk/python/sporespore_locomotion.py',
            ROOT / 'sdk/recovery/r10y_partial_direct_neutral_development_design_v1.json')],
        retained_evidence=[diagnosis.binding(p) for p in sorted(out.iterdir()) if p.is_file()],
        preserved_initial_debug_failure=dict(evidence_root=(EVIDENCE / 'r10y-native-component-6bb26d8f7079460b84067d1ee9fb9fa5').as_posix(),
            classification='targeted_5_passed_full_debug_suite_aborted_on_existing_v56_test_stack_overflow',
            execution=diagnosis.binding(EVIDENCE / 'r10y-native-component-6bb26d8f7079460b84067d1ee9fb9fa5/execution.json')))
    write(RECORD, record)
    return result


def audit(cold=False):
    record = read(RECORD)
    verify(record['runtime_binding'])
    for item in record['source_bindings'] + record['retained_evidence']:
        verify(item)
    bound, _ = runtime()
    out = Path(record['evidence_root'])
    assert read(out / 'source_before.json') == read(out / 'source_after.json')
    result = read(out / 'result.json')
    assert result == record['observed'] and result['ok'] is True
    core = ExactInputCore(bound['runtime']['path']) if cold else None
    counts, seen, controls = Counter(), set(), []
    with (out / 'native_calls.jsonl').open(encoding='utf-8') as stream:
        for line in stream:
            row = json.loads(line)
            identity = (row['group'], row['identity'])
            assert identity not in seen
            seen.add(identity)
            counts[row['group']] += 1
            envelope = json.loads(row['response_raw_utf8'])
            if row['failure_code'] is None:
                assert envelope['ok'] is True
            else:
                assert row['group'] == 'negative_controls' and envelope['ok'] is False
                assert envelope['failure_code'] == row['failure_code']
                controls.append(dict(case=row['identity'], failure_code=row['failure_code']))
            if core is not None:
                error = None
                try:
                    core._call_json_input(row['method'], row['request_raw_utf8'].encode('utf-8'))
                except LocomotionCoreError as failure:
                    error = failure.failure_code
                assert error == row['failure_code'] and core.raw_response == row['response_raw_utf8'].encode('utf-8'), identity
    assert counts == EXPECTED_COUNTS == result['populations'] == read(out / 'declaration.json')['expected_calls']
    assert len(seen) == result['native_calls'] == 1978 and controls == result['negative_controls']
    assert all(result[key] is False for key in ('full_route_integrated', 'complete_smoke_safety_gate_passed',
        'successor_physics_observed', 'physical_acceptance_authority', 'release_authority'))
    assert result['world_build_count'] == result['solver_step_count'] == 0
    return dict(ok=True, native_calls=1978, cold_replayed=1978 if cold else 0, negative_controls=17,
        original_partial_calls=1956, full_route_integrated=False, world_build_count=0, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--cold', action='store_true')
    args = parser.parse_args()
    assert not (args.run and args.cold)
    print('R10Y_NATIVE_COMPONENT ' + json.dumps(run() if args.run else audit(args.cold)), flush=True)
