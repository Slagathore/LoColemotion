"""Independent byte/population audit of V56; --cold repeats all native calls.

Cold mode must run under the repository operation lock. Default mode only
reads the bound runtime, sources, original reports and finite receipt stream.
"""
import argparse
import collections
import json
from pathlib import Path

import qsdk_r10f_l15_collection_retention as packet
import v56_extended_preparation as producer

EXPECTED = dict(original_walking=6367, v56_copied_input=6367, v56_session=6367,
    original_refusals=2, original_r10r_recovery=616, v55_on_v54_inputs=857,
    v56_nonready_boundary=6, v56_ready_boundary=4, negative_controls=3,
    negative_abi_controls=2, original_r10r_fixtures=3)


def audit(cold=False):
    r = producer.read(producer.RECORD)
    require = producer.require
    require(r['schema_version'] == 'sporespore_v56_extended_preparation_component_v1'
        and r['status'] == 'native_component_verified_actual_adapter_route_pending', 'RECORD_IDENTITY')
    for item in r['source_bindings'] + r['retained_evidence'] + [r['runtime_binding'], r['design']]: producer.verified(item)
    runtime = producer.read(producer.verified(r['runtime_binding']))
    for item in runtime['source_files'] + runtime['build_evidence_files'] + [runtime['runtime'], runtime['compiled_fixtures']]: producer.verified(item)
    require(len(runtime['source_files']) == 103 and runtime['core_test_count'] == 414
        and [s['stage'] for s in runtime['build_stages']] == ['core_tests','fixtures','adapter']
        and all(s['exit_code'] == 0 for s in runtime['build_stages']), 'BUILD')
    out = Path(r['evidence_root'])
    require((out/'source_before.json').read_bytes() == (out/'source_after.json').read_bytes(), 'SOURCE_STABLE')
    observed = producer.read(out/'result.json')
    require(packet.same(observed, r['observed']) and observed['ok'] is True, 'OBSERVED_RESULT')
    require(observed['populations'] == EXPECTED and sum(EXPECTED.values()) == observed['recorded_native_step_calls'] == 20594, 'POPULATIONS')
    for item in observed['original_reports'] + [observed['descriptor_source'], observed['old_r10r_fixture_source'], observed['predecessor_source_archive']]: producer.verified(item)
    archive = producer.read(producer.verified(observed['predecessor_source_archive']))
    require(len(archive['files']) == 583 and archive['source_contract_files'] == 493, 'PREDECESSOR_SOURCE_POPULATION')
    for item in archive['files']:
        producer.verified(dict(path=item['archive_path'],raw_sha256=item['raw_sha256'],byte_length=item['byte_length']))
    stream = producer.binding(out/'native_receipts.jsonl')
    require(stream['raw_sha256'] == observed['native_receipt_stream_sha256']
        and stream['byte_length'] == observed['native_receipt_stream_bytes'], 'RECEIPT_BYTES')
    counts, indexed = collections.Counter(), {}
    with (out/'native_receipts.jsonl').open(encoding='utf-8') as lines:
        for line in lines:
            call = packet.parse_json(line)
            identity = (call['lane'], call['identity'])
            require(identity not in indexed and call['lane'] in EXPECTED, 'CALL_IDENTITY')
            indexed[identity] = call; counts[call['lane']] += 1
            require(call['native_ok'] is (call['lane'] != 'negative_abi_controls'), 'NATIVE_ENVELOPE')
            expected_refusal = call['lane'] in ['original_refusals','negative_controls'] or (
                call['lane'] == 'v56_nonready_boundary' and call['identity'] in ['360','361'])
            expected_safe = None if call['lane'] in ['negative_abi_controls','original_r10r_recovery','original_r10r_fixtures'] else expected_refusal
            require(call['safe_no_actuation'] is expected_safe, 'CALL_ACTUATION')
    require(dict(counts) == EXPECTED, 'STREAM_POPULATIONS')
    cases = observed['boundary_cases']
    require([c['case'] for c in cases] == ['nonready_'+str(n) for n in [239,240,241,359,360,361]]
        + ['ready_'+str(n) for n in [240,241,359,360]]
        + ['crossed_memory','fresh_used_counter','stale_clock','missing_body_frame','caller_limit_override'], 'BOUNDARY_POPULATION')
    core = producer.ExactInputCore if cold else None
    for case in cases:
        name, request = case['case'], case['request']
        raw = case['raw_response_utf8'].encode()
        if name.startswith('nonready_'): lane, identity = 'v56_nonready_boundary', name.removeprefix('nonready_')
        elif name.startswith('ready_'): lane, identity = 'v56_ready_boundary', name.removeprefix('ready_')
        else: lane, identity = ('negative_abi_controls' if name in ['missing_body_frame','caller_limit_override'] else 'negative_controls'), name
        call = indexed[(lane,identity)]
        require(producer.native.digest(raw) == call['raw_response_sha256'], 'BOUNDARY_RESPONSE_BYTES')
        # The producer uses the ordinary binding's exact canonical input JSON.
        input_bytes = producer.ExactInputCore._input_bytes(request)
        require(producer.native.digest(input_bytes) == call['request_sha256'], 'BOUNDARY_REQUEST_BYTES')
        envelope = packet.parse_json(case['raw_response_utf8'])
        require(envelope['ok'] is call['native_ok'], 'BOUNDARY_ENVELOPE')
        if not envelope['ok']: continue
        value = envelope['value']
        require(value['actuation']['safe_no_actuation'] is call['safe_no_actuation'], 'BOUNDARY_ACTUATION')
        if call['safe_no_actuation']:
            require(value['next_memory'] == request['memory']
                and all(c['target_velocity_rad_s'] == 0 for c in value['actuation']['ordered_commands']), 'BOUNDARY_SAFE_STOP')
        else:
            t = value['actuation']['receipt']['recovery_support_plane']['measured_support_transfer']
            require(t['maximum_preparation_commands'] == 360, 'BOUNDARY_LIMIT')
            if lane == 'v56_ready_boundary':
                require(t['preparation_released_this_command'] is True and t['next_memory']['preparation_commands'] == t['next_memory']['ready_dwell_commands'] == 0, 'BOUNDARY_RELEASE')
            else: require(t['next_memory']['preparation_commands'] == int(identity)+1, 'BOUNDARY_COUNT')
    require(len(observed['histories']) == 6 and [h['commands'] for h in observed['histories']] == [1005,857,1170,1081,1130,1124]
        and sum(h['stopping_commands'] for h in observed['histories']) == 480, 'HISTORY_COUNTS')
    for h in observed['histories']:
        require(h['original_bytes_exact'] is True and h['v56_parent_arithmetic_exact'] is True
            and h['stateless_session_bytes_equal'] is True and h['new_physics_predicted'] is False, 'HISTORY_FLAGS')
    for key in ['physical_response_predicted','complete_route_integrated','physical_execution_authorized','physical_acceptance_authority','release_authority']:
        require(observed[key] is False, 'CLAIM_' + key)
    require(observed['physical_world_count'] == observed['solver_step_count'] == 0, 'NO_NEW_PHYSICS')
    if core is not None: require(packet.same(producer.exercise(out,cold=True),observed), 'COLD_RECONSTRUCTION')
    return dict(ok=True,core_tests=414,compiled_sources=103,native_step_calls=20594,
        cold_replayed=20594 if cold else 0,original_walking_calls=6367,original_refusals=2,
        original_r10r_recovery_calls=616,synthetic_boundaries=10,negative_controls=5,
        stop_commands=480,world_build_count=0,sdk1_score='14/20')


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--cold',action='store_true');args=parser.parse_args()
    print('V56_INDEPENDENT_AUDIT '+json.dumps(audit(args.cold)),flush=True)
