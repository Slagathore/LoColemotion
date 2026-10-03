"""Check the R10AB DLL exports and replay original partial calls byte-for-byte.

All inputs are supplied records or labeled synthetic fixtures. Historical replay
selects the first and last packet of each observed phase; it is not a full-route
replay. The complete core suite supplies separate regression coverage. No engine world
is constructed. Historical calls keep their original API and raw input bytes.
Run this command under the repository native-operation lock.
"""
import argparse
import base64
import subprocess
import r10y_first_support_closure as previous
import r10z_first_support_closure as z_previous
import r10aa_first_support_closure as aa_previous
import r10y_hold_report_component as history
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
BINDING = ROOT / 'sdk/development/recovery_candidates/r10ab-partial-downward-rise-core-v1.runtime.json'
RECORD = ROOT / 'sdk/recovery/r10ab_partial_native_component_v1.json'
EXPECTED_COUNTS = dict(new_fixtures=5, negative_controls=18, original_partial_calls=24)


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


def verify_frozen_build(bound):
    snapshots = [Path(r['path']) for r in bound['build_evidence_files'] if Path(r['path']).name == 'source_snapshot.json']
    assert len(snapshots) == 1
    snapshot = read(snapshots[0])
    assert snapshot['head'] == bound['build_source_parent_commit']
    assert snapshot['remote'] == 'https://github.com/Slagathore/sporespore.git'
    replacements = {r['path']: r for r in snapshot['changed_files']}
    tracked = []
    for row in bound['source_files']:
        assert not Path(row['path']).is_absolute() and '..' not in Path(row['path']).parts
        if row['path'] in replacements:
            changed = replacements[row['path']]
            assert not changed['deleted']
            raw = base64.b64decode(changed['replacement_base64'], validate=True)
            assert diagnosis.digest(raw) == changed['raw_sha256'] and history.raw_matches(raw, row)
        else:
            tracked.append(row)
    request = ''.join(snapshot['head']+':'+r['path']+'\n' for r in tracked).encode()
    process = subprocess.run(['git','cat-file','--batch'],input=request,cwd=ROOT,capture_output=True,check=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    assert not process.stderr
    raw,cursor = process.stdout,0
    for row in tracked:
        end=raw.index(b'\n',cursor);header=raw[cursor:end].split()
        assert len(header)==3 and header[1]==b'blob'
        length=int(header[2]);blob=raw[end+1:end+1+length];cursor=end+2+length
        assert history.raw_matches(blob,row) or (b'\r\n' not in blob and history.raw_matches(blob.replace(b'\n',b'\r\n'),row)),row['path']
    assert cursor==len(raw)


def runtime():
    bound = read(BINDING)
    assert bound['core_test_count'] == 461
    verify_frozen_build(bound)
    for item in bound['build_evidence_files'] + [bound['runtime'], bound['compiled_fixtures']]:
        verify(item)
    fixtures = [json.loads(line.partition(' ')[2]) for line in verify(bound['compiled_fixtures']).read_text(encoding='utf-8').splitlines()
                if line.startswith('R10AB_PARTIAL_FIXTURE ')]
    assert [f['id'] for f in fixtures] == ['partial_entry', 'partial_step_1', 'partial_step_2', 'partial_step_3', 'partial_step_63']
    assert all(f['physical_source'] is False for f in fixtures)
    return bound, fixtures


def run():
    assert not RECORD.exists(), 'R10AB_NATIVE_COMPONENT_ALREADY_RETAINED'
    bound, fixtures = runtime()
    assert bound['source_files'] == build.sources()
    observed = read(diagnosis.RECORD)
    assert diagnosis.binding(diagnosis.RECORD)['raw_sha256'] == 'sha256:3611f3c1136c3b9e9b30da36b9d52efa3f79edab3517fff21d805d426a31b5d5'
    out = EVIDENCE / ('r10ab-native-calls-' + uuid.uuid4().hex)
    out.mkdir()
    print('R10AB_NATIVE_CALLS_ROOT ' + out.as_posix(), flush=True)
    before = entry._source_snapshot()
    write(out / 'source_before.json', before)
    write(out / 'declaration.json', dict(expected_calls=EXPECTED_COUNTS, original_results_regraded=False,
        historical_calls_use_original_api_and_raw_bytes=True, coverage='First and last packet of every observed prior phase in four retained V20 trajectories and the R10Y/R10Z/R10AA trajectories; complete 461-test core suite is separate regression coverage. No full trajectory success is inferred.', world_build_count=0, solver_step_count=0))
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
        for case in range(12):
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
            elif case == 10: q['collection']['observation']['controller_ownership']['recovery_controller_id'] = 'sporespore_exact_s169_partial_load_seeking_controller_v23'
            else: q['collection']['observation']['controller_ownership']['fallback_controller_active'] = True
            call('negative_controls', 'step_' + str(case), 'ss_recovery_r10ab_partial_step_control_v1_json', q, refuse=True)
        for case in range(6):
            q = copy.deepcopy(fixtures[0]['request'])
            if case == 0: q['schema_version'] = 'sporespore_r10q_upright_entry_control_request_v1'
            elif case == 1: q['collection']['observation']['state']['base_pose_world']['position_m']['y'] += .001
            elif case == 2: q['collection']['observation_source_binding']['source_route_id'] = 'unregistered'
            elif case == 3: q['entry']['original_request']['passive_request']['observation']['energy_balance']['initial_mechanical_energy_j'] += 1
            elif case == 4: q['collection']['task_id'] = 'sporespore_measured_partial_fall_to_standing_v1'
            else: q['entry']['prior']['schema_version'] = 'crossed'
            call('negative_controls', 'entry_' + str(case), 'ss_recovery_r10ab_partial_entry_control_v1_json', q, refuse=True)
        retained_entries = {str(row['seed']): row for row in read(ROOT / 'sdk/core/contracts/r10z_retained_partial_entries_v1.json')['entries']}
        assert len(retained_entries) == 4
        verified_entries = set()
        populations = [(str(o['seed']), verify(o['report']), diagnosis.read_partial) for o in observed['observations']]
        populations.append(('r10y_phase248', previous.CHILD/'worker_report.json', previous.partial_records))
        populations.append(('r10z_phase248', z_previous.CHILD/'worker_report.json', z_previous.partial_records))
        populations.append(('r10aa_phase248', aa_previous.CHILD/'worker_report.json', aa_previous.partial_records))
        for label, path, reader in populations:
            selected, first, last = {}, {}, {}
            for kind, packet in reader(path):
                if kind == 'declaration' and label in retained_entries:
                    passive = packet['entry_request']['passive_request']
                    retained = retained_entries[label]
                    assert retained['report'] == diagnosis.binding(path)
                    assert retained['descriptor'] == passive['declaration']['initialization']['descriptor']
                    assert retained['observation'] == passive['observation']
                    verified_entries.add(label)
                if kind != 'packet':
                    continue
                phase = packet['native_receipt']['step']['prior_phase']
                first.setdefault(phase, packet)
                last[phase] = packet
            for packet in list(first.values()) + list(last.values()):
                step = packet['native_receipt']['step']['memory']['total_steps_observed']
                selected[step] = packet
            for step, packet in sorted(selected.items()):
                original = packet['call']
                assert original['method'] in ('recovery_partial_fall_step_control_v1_json', 'recovery_r10y_partial_step_control_v1_json', 'recovery_r10z_partial_step_control_v1_json', 'recovery_r10aa_partial_step_control_v1_json')
                assert packet['native_receipt'] == original['value']
                request = original['request']['utf8_text'].encode('utf-8')
                response = original['response']['utf8_text'].encode('utf-8')
                assert diagnosis.digest(request) == original['request']['raw_sha256']
                assert diagnosis.digest(response) == original['response']['raw_sha256']
                call('original_partial_calls', label+':'+str(step), 'ss_'+original['method'], request, response=response)
            print('R10AB_ORIGINAL_BOUNDARY_REPLAY '+json.dumps(dict(population=label,partial_steps=sorted(selected))),flush=True)
        assert verified_entries == set(retained_entries)
    assert counts == EXPECTED_COUNTS
    after = entry._source_snapshot()
    write(out / 'source_after.json', after)
    assert before == after
    result = dict(ok=True, native_calls=sum(counts.values()), populations=dict(counts), negative_controls=controls,
        original_api_response_bytes_identical=True, full_route_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    write(out / 'result.json', result)
    record = dict(schema_version='sporespore_r10ab_partial_native_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_native_component', question_class='development'),
        runtime_binding=diagnosis.binding(BINDING), evidence_root=out.as_posix(), observed=result,
        source_bindings=[diagnosis.binding(p) for p in (Path(__file__), diagnosis.RECORD,
            ROOT / 'sdk/conformance/r10y_partial_recovery_diagnosis.py',
            ROOT / 'sdk/python/sporespore_locomotion.py',
            ROOT / 'sdk/recovery/r10ab_downward_rise_kernel_contract_v1.json',
            ROOT / 'sdk/core/contracts/r10z_retained_partial_entries_v1.json', previous.RECORD, aa_previous.RECORD, Path(aa_previous.__file__))],
        retained_evidence=[diagnosis.binding(p) for p in sorted(out.iterdir()) if p.is_file()],
        prior_kernel_component=diagnosis.binding(ROOT/'sdk/recovery/r10ab_downward_kernel_component_v1.json'),
        prior_r10z_closure=diagnosis.binding(z_previous.RECORD),
        core_tests=461, targeted_composition_tests=6)
    write(RECORD, record)
    return result


def audit(cold=False):
    record = read(RECORD)
    verify(record['runtime_binding'])
    for item in record['source_bindings'] + record['retained_evidence'] + [record['prior_kernel_component'], record['prior_r10z_closure']]:
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
    assert len(seen) == result['native_calls'] == 47 and controls == result['negative_controls']
    assert all(result[key] is False for key in ('full_route_integrated', 'complete_smoke_safety_gate_passed',
        'successor_physics_observed', 'physical_acceptance_authority', 'release_authority'))
    assert result['world_build_count'] == result['solver_step_count'] == 0
    return dict(ok=True, native_calls=47, cold_replayed=47 if cold else 0, negative_controls=18,
        original_partial_calls=24, full_route_integrated=False, world_build_count=0, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--cold', action='store_true')
    args = parser.parse_args()
    assert not (args.run and args.cold)
    print('R10AB_NATIVE_COMPONENT ' + json.dumps(run() if args.run else audit(args.cold)), flush=True)
