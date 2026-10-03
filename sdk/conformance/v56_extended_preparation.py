"""Qualify the distinct V56 native component on finite exposed inputs.

Run under the locomotion operation lock. Original outputs remain exact. New
policy outputs on copied measurements do not predict a continued trajectory.
The original six reports and both consumed failures are never changed.
"""
import argparse
import collections
import copy
import gc
import hashlib
import json
from pathlib import Path
import uuid

import development_passive_entry_profile as entry
import development_recovery_refusal as native
import qsdk_r10f_l15_collection_retention as packet
import r10j_held_out_failure as original
from r10r_native_component import ExactInputCore, fixtures
from sporespore_locomotion import LocomotionCoreError

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
BINDING = ROOT / 'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json'
DESIGN = ROOT / 'sdk/recovery/r10s_extended_preparation_design_v1.json'
DIAGNOSIS = ROOT / 'sdk/recovery/r10r_support_transfer_diagnosis_v1.json'
RECORD = ROOT / 'sdk/recovery/v56_extended_preparation_component_v1.json'
ARCHIVE = EVIDENCE / 'r10r-physical-source-b1e19895ec4941e9a054988425936887/source-archive.json'
ARCHIVE_SHA = 'sha256:a9b0f5a5827d5f7660ed30dabc082d4cf7a2bbd2e3ec8f99fc21bc411a71f1bb'
POLICY = 'sporespore_balanced_wave_recovery_extended_preparation_v1'
PARENT = 'sporespore_balanced_wave_recovery_initialized_zero_brake_v1'
MEMORY = 'sporespore_balanced_wave_recovery_extended_preparation_memory_v1'
RECEIPT = 'sporespore_recovery_extended_preparation_controller_step_receipt_v1'
read, binding = original.read, original.binding


def require(value, code):
    if not value: raise ValueError('V56_COMPONENT_' + code)


def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False); stream.write('\n')


def verified(item):
    path = Path(item['path'])
    if not path.is_absolute(): path = ROOT / path
    actual = binding(path)
    require(actual['raw_sha256'] == item['raw_sha256'], 'FILE_BYTES:' + str(path))
    if 'byte_length' in item: require(actual['byte_length'] == item['byte_length'], 'FILE_LENGTH')
    return path


def memory_schema(policy): return policy.removesuffix('_v1') + '_memory_v1'


def comparable(out):
    """Only declared identities, receipt hash and V56's explicit bound differ."""
    value = copy.deepcopy(out)
    value['next_memory']['schema_version'] = '<memory>'
    receipt = value['actuation']['receipt']
    receipt['schema_version'], receipt['policy_id'] = '<receipt>', '<policy>'
    value['actuation'].pop('receipt_sha256')
    transfer = receipt.get('recovery_support_plane', {}).get('measured_support_transfer')
    if transfer is not None: transfer.pop('maximum_preparation_commands', None)
    return value


def check_refusal(q, out, code):
    require(out['actuation']['safe_no_actuation'] is True and out['next_memory'] == q['memory'], 'REFUSAL_MEMORY')
    require(out['actuation']['receipt']['controller_error'] == code, 'REFUSAL_REASON')
    commands = out['actuation']['ordered_commands']
    require(len(commands) == 8 and all(c['target_velocity_rad_s'] == 0 for c in commands), 'REFUSAL_COMMANDS')


def exercise(out, cold=False):
    """Reconstruct a deterministic receipt stream against immutable originals."""
    runtime, design, diagnosis = read(BINDING), read(DESIGN), read(DIAGNOSIS)
    require(runtime['core_test_count'] == 414 and len(runtime['source_files']) == 103, 'BUILD_POPULATION')
    for item in runtime['source_files'] + runtime['build_evidence_files'] + [runtime['runtime']]: verified(item)
    require(design['controller_change']['new_policy_id'] == POLICY
        and design['controller_change']['preparation_limit_commands_after'] == 360
        and design['preserved']['maximum_walking_commands'] == 1600, 'DESIGN')
    require(binding(ARCHIVE)['raw_sha256'] == ARCHIVE_SHA, 'PREDECESSOR_ARCHIVE')
    archive = read(ARCHIVE)
    for item in archive['files']:
        verified(dict(path=item['archive_path'], raw_sha256=item['raw_sha256'], byte_length=item['byte_length']))
    descriptor_binding = read(ROOT/'sdk/recovery/r10j_held_out_physical_closure_v1.json')['cells'][2]['report']
    descriptor = native.integers(read(verified(descriptor_binding))['configuration']['base_descriptor'])
    core = ExactInputCore(runtime['runtime']['path'])
    counts, digest, byte_count = collections.Counter(), hashlib.sha256(), 0
    boundary_cases, original_roots, summaries = [], [], []
    failed_input, ready_input, first_input = None, None, None
    stream = None if cold else (out/'native_receipts.jsonl').open('xb')

    def retain(lane, identity, q, value, raw, method='ss_balanced_wave_policy_step_json'):
        nonlocal byte_count
        counts[lane] += 1
        row = dict(lane=lane, identity=identity, method=method,
            request_sha256=native.digest(core._input_bytes(q)), raw_response_sha256=native.digest(raw),
            native_ok=json.loads(raw)['ok'], safe_no_actuation=value.get('actuation', {}).get('safe_no_actuation'))
        encoded = (json.dumps(row, sort_keys=True, separators=(',', ':'), allow_nan=False)+'\n').encode()
        if stream is not None: stream.write(encoded)
        digest.update(encoded); byte_count += len(encoded)
        return value

    def call(lane, identity, q, expected_sha=None):
        value = core.balanced_wave_policy_step_with_measured_body(q['policy_id'], q)
        raw = core.raw_response
        if expected_sha: require(native.digest(raw) == expected_sha, 'ORIGINAL_RESPONSE:' + identity)
        retain(lane, identity, q, value, raw)
        return value, raw

    def request(row, policy):
        q = native.integers(dict(copy.deepcopy(row['request']), descriptor=descriptor))
        q.update(schema_version='sporespore_balanced_wave_policy_step_request_v3', policy_id=policy)
        q['memory']['schema_version'] = memory_schema(policy)
        return q

    try:
        profiles = [core.balanced_wave_policy_profile(policy, descriptor) for policy in [PARENT, POLICY]]
        require([{k:v for k,v in p.items() if k not in ['schema_version','policy_id']} for p in profiles][0]
            == [{k:v for k,v in p.items() if k not in ['schema_version','policy_id']} for p in profiles][1], 'PROFILE_LIMITS')
        initial = [core.balanced_wave_policy_initial_memory(policy, descriptor) for policy in [PARENT, POLICY]]
        require(initial[1]['schema_version'] == MEMORY, 'INITIAL_IDENTITY')
        require({k:v for k,v in initial[0].items() if k != 'schema_version'}
            == {k:v for k,v in initial[1].items() if k != 'schema_version'}, 'INITIAL_MEMORY')
        for source in diagnosis['histories']:
            report = read(verified(source['report']))
            rows = report['development_walking_entry']['rows']
            require(len(rows) == source['walking_commands'], 'HISTORY_POPULATION')
            original_roots.append(source['report'])
            previous, zero_start, stop = None, [], []
            with core.create_balanced_wave_policy_session(POLICY, descriptor) as session:
                for row in rows:
                    identity = source['id'] + ':' + str(row['session_local_step'])
                    old_policy = row['native_output']['actuation']['receipt']['policy_id']
                    old_q = request(row, old_policy)
                    old, _ = call('original_walking', identity, old_q, row['raw_native_response_sha256'])
                    parent = old if old_policy == PARENT else call('v55_on_v54_inputs', identity, request(row, PARENT))[0]
                    q = request(row, POLICY)
                    if previous is not None: require(native.integers(previous) == q['memory'], 'NEW_MEMORY_CHAIN')
                    value, raw = call('v56_copied_input', identity, q)
                    require(value['actuation']['safe_no_actuation'] is False
                        and packet.same(comparable(parent), comparable(value)), 'UNCHANGED_COMMAND_ARITHMETIC:' + identity)
                    t = value['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
                    require(t['maximum_preparation_commands'] == 360 and value['actuation']['receipt']['schema_version'] == RECEIPT, 'EXPLICIT_LIMIT')
                    session_q = {k:v for k,v in q.items() if k not in ['policy_id','descriptor']}
                    session_q['schema_version'] = 'sporespore_balanced_wave_policy_session_step_request_v3'
                    session_value = session.step_with_measured_body(session_q)
                    require(core.raw_response == raw and packet.same(session_value, value), 'SESSION_BYTES')
                    retain('v56_session', identity, session_q, session_value, core.raw_response, 'ss_balanced_wave_policy_session_step_json')
                    if first_input is None: first_input = copy.deepcopy(q)
                    if q['command']['gait_amplitude'] == 0:
                        if q['memory']['last_semantic_step'] is None:
                            zero_start.append(row['session_local_step'])
                            require(all(abs(c['target_velocity_rad_s']) <= .25 for c in value['actuation']['ordered_commands']), 'INITIAL_FEEDBACK_CAP')
                        else:
                            stop.append(row['session_local_step'])
                            require(all(c['target_velocity_rad_s'] == 0 for c in value['actuation']['ordered_commands']), 'STOP_BRAKE')
                    if t['preparation_released_this_command'] and t['planned_swing_limb_id'] == 'rear_left' and ready_input is None:
                        ready_input = copy.deepcopy(q)
                    previous = value['next_memory']
                require(not session.closed, 'SESSION_LIFETIME')
            require(session.closed, 'SESSION_CLOSED')
            require(zero_start == [1] and len(stop) == (120 if source['positive'] else 0), 'START_STOP_POPULATION')
            if not source['positive']:
                failure = report['detail']['portable_step_receipt']['development_native_step_failure']
                failed = dict(request=json.loads(failure['request']['utf8_text']))
                q = request(failed, failure['expected_policy_id'])
                value, _ = call('original_refusals', source['id'], q, failure['response']['raw_sha256'])
                check_refusal(q, value, 'FRAME_INVALID:measured_support_transfer_preparation_timeout')
                if source['id'] == 'r10r_kicked_phase246': failed_input = request(failed, POLICY)
            if source['id'] == 'r10r_kicked_phase246':
                packets = report['passive_entry']['entry_packets'] + report['r10r_upright_recovery']['step_packets']
                require(len(packets) == 616, 'ORIGINAL_RECOVERY_POPULATION')
                for index, p in enumerate(packets):
                    original_call = p['call']; q = original_call['request']['utf8_text'].encode()
                    raw = original_call['response']['utf8_text'].encode()
                    require(native.digest(q) == original_call['request']['raw_sha256']
                        and native.digest(raw) == original_call['response']['raw_sha256'], 'RECOVERY_TRANSPORT')
                    value = core._call_json_input('ss_'+original_call['method'], q)
                    require(core.raw_response == raw and packet.same(value, p['native_receipt']), 'ORIGINAL_RECOVERY_BYTES')
                    retain('original_r10r_recovery', str(index), q, value, raw, 'ss_'+original_call['method'])
                del packets
            summaries.append(dict(id=source['id'], original_policy=source['native_policy'],
                commands=len(rows), original_bytes_exact=True, v56_parent_arithmetic_exact=True,
                stateless_session_bytes_equal=True, initialized_feedback_commands=zero_start,
                stopping_commands=len(stop), new_physics_predicted=False))
            print('V56_HISTORY_PASSED', source['id'], len(rows), flush=True)
            del report, rows
            gc.collect()

        require(failed_input is not None and ready_input is not None and first_input is not None, 'BOUNDARY_SOURCES')
        for count in [239, 240, 241, 359, 360, 361]:
            q = copy.deepcopy(failed_input)
            q['memory']['measured_support_transfer']['preparation_commands'] = count
            q['memory']['measured_support_transfer']['ready_dwell_commands'] = 0
            value, raw = call('v56_nonready_boundary', str(count), q)
            if count < 360:
                require(value['actuation']['safe_no_actuation'] is False
                    and value['next_memory']['measured_support_transfer']['preparation_commands'] == count+1, 'EXTENDED_COMMAND')
            else: check_refusal(q, value, 'FRAME_INVALID:measured_support_transfer_' + ('preparation_timeout' if count == 360 else 'memory_domain'))
            boundary_cases.append(dict(case='nonready_'+str(count), synthetic_memory=True, request=q, raw_response_utf8=raw.decode()))
        for count in [240, 241, 359, 360]:
            q = copy.deepcopy(ready_input)
            q['memory']['measured_support_transfer'].update(preparation_commands=count, ready_dwell_commands=5)
            value, raw = call('v56_ready_boundary', str(count), q)
            t = value['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
            require(value['actuation']['safe_no_actuation'] is False and t['preparation_released_this_command'] is True
                and t['next_memory']['preparation_commands'] == t['next_memory']['ready_dwell_commands'] == 0, 'SIX_READY_RELEASE')
            boundary_cases.append(dict(case='ready_'+str(count), synthetic_memory=True, request=q, raw_response_utf8=raw.decode()))
        for name in ['crossed_memory', 'fresh_used_counter', 'stale_clock', 'missing_body_frame', 'caller_limit_override']:
            q = copy.deepcopy(first_input if name == 'fresh_used_counter' else failed_input)
            if name == 'crossed_memory': q['memory']['schema_version'] = memory_schema(PARENT)
            elif name == 'fresh_used_counter': q['memory']['measured_support_transfer']['preparation_commands'] = 1
            elif name == 'stale_clock': q['memory']['last_semantic_step'] += 1
            elif name == 'missing_body_frame': q.pop('measured_body_frame')
            else: q['memory']['measured_support_transfer']['maximum_preparation_commands'] = 999
            error = None
            try:
                value, raw = call('negative_controls', name, q)
                require(value['actuation']['safe_no_actuation'] is True and value['next_memory'] == q['memory']
                    and all(c['target_velocity_rad_s'] == 0 for c in value['actuation']['ordered_commands']), 'NEGATIVE_ACCEPTED:' + name)
                error = value['actuation']['receipt']['controller_error']
            except LocomotionCoreError as failure:
                error, raw = failure.failure_code, core.raw_response
                # A typed ABI rejection has no actuation payload or solver side effect.
                retain('negative_abi_controls', name, q, {}, raw)
            boundary_cases.append(dict(case=name, synthetic_invalid_input=True, request=q,
                raw_response_utf8=raw.decode(), failure_code=error))
        old_fixture = read(ROOT/'sdk/development/recovery_candidates/r10r-upright-direct-rise-core-v1.runtime.json')['compiled_fixtures']
        old_rows = fixtures(verified(old_fixture), 'R10R_UPRIGHT_FIXTURE')
        new_rows = fixtures(verified(runtime['compiled_fixtures']), 'R10R_UPRIGHT_FIXTURE')
        require(packet.same(old_rows, new_rows) and len(new_rows) == 3, 'ORIGINAL_R10R_FIXTURES')
        for f in new_rows:
            value = core._call_json_input('ss_'+f['method']+'_json', f['request'])
            require(packet.same(value, f['expected']), 'ORIGINAL_R10R_PUBLIC_ABI')
            retain('original_r10r_fixtures', f['id'], f['request'], value, core.raw_response, 'ss_'+f['method']+'_json')
    finally:
        if stream is not None: stream.close()
    return dict(ok=True, profiles=profiles, initial_memories=initial, descriptor_source=descriptor_binding,
        histories=summaries, original_reports=original_roots, populations=dict(counts),
        recorded_native_step_calls=sum(counts.values()), profile_and_initial_memory_calls=4,
        native_receipt_stream_sha256='sha256:'+digest.hexdigest(), native_receipt_stream_bytes=byte_count,
        boundary_cases=boundary_cases, old_r10r_fixture_source=old_fixture, predecessor_source_archive=binding(ARCHIVE),
        synthetic_boundary_cases=10, malformed_input_controls=5, original_recovery_calls=616,
        physical_world_count=0, solver_step_count=0, physical_response_predicted=False,
        complete_route_integrated=False, physical_execution_authorized=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def create():
    require(not RECORD.exists(), 'RECORD_EXISTS')
    out = EVIDENCE/('v56-native-component-'+uuid.uuid4().hex); out.mkdir()
    print('V56_COMPONENT_ROOT', out, flush=True)
    before = entry._source_snapshot()
    write(out/'source_before.json', before)
    sources = [binding(p) for p in [Path(__file__), BINDING, DESIGN, DIAGNOSIS,
        ROOT/'sdk/python/sporespore_locomotion.py', ROOT/'sdk/conformance/development_recovery_refusal.py',
        ROOT/'sdk/conformance/r10r_native_component.py', ROOT/'sdk/conformance/r10j_held_out_failure.py']]
    write(out/'declaration.json', dict(sources=sources, physical_world_count=0, solver_step_count=0,
        finite_history_count=6, one_original_and_one_v56_and_one_session_call_per_completed_walking_row=True,
        v54_rows_also_replayed_with_v55=True, counterfactual_physics_predicted=False))
    observed = exercise(out)
    write(out/'result.json', observed)
    after = entry._source_snapshot(); write(out/'source_after.json', after)
    require(before == after and sources == [binding(item['path']) for item in sources], 'SOURCE_CHANGED')
    record = dict(schema_version='sporespore_v56_extended_preparation_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='finite_native_component_qualification',question_class='development'),
        status='native_component_verified_actual_adapter_route_pending', evidence_root=out.as_posix(),
        runtime_binding=binding(BINDING), design=binding(DESIGN), observed=observed,
        source_bindings=sources, retained_evidence=[binding(p) for p in sorted(out.iterdir()) if p.is_file()])
    write(RECORD, record)
    return observed


def audit(cold=False):
    record = read(RECORD)
    for item in record['retained_evidence'] + record['source_bindings']:
        verified(item)
    out = Path(record['evidence_root'])
    require((out/'source_before.json').read_bytes() == (out/'source_after.json').read_bytes(), 'SOURCE_SNAPSHOT')
    result = read(out/'result.json')
    require(packet.same(result, record['observed']), 'RESULT')
    require(binding(out/'native_receipts.jsonl')['raw_sha256'] == result['native_receipt_stream_sha256'], 'RECEIPT_STREAM')
    if cold: require(packet.same(exercise(out, cold=True), result), 'COLD_RECONSTRUCTION')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--create', action='store_true'); parser.add_argument('--cold', action='store_true'); args = parser.parse_args()
    result = create() if args.create else audit(args.cold)
    print('V56_COMPONENT_PASSED '+json.dumps(dict(native_step_calls=result['recorded_native_step_calls'],
        histories=6, original_recovery_calls=616, synthetic_boundaries=10, negative_controls=5,
        physical_world_count=0, sdk1_score='14/20')), flush=True)
