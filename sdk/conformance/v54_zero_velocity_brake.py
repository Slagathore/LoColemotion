"""Run or audit V54 component validation; no physical worlds are constructed."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

from v52_extended_support_transfer import ROOT, read, binding, verify, fixture_rows

RECORD = ROOT / 'sdk/recovery/v54_zero_velocity_brake_component_v1.json'
RUNTIME = ROOT / 'sdk/development/recovery_candidates/v54-zero-velocity-brake-core-v1.runtime.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, production_route_integrated=False,
    physical_execution_authorized=False, physical_acceptance_authority=False,
    release_authority=False, original_campaign_regraded=False, sdk1_score='14/20')


def require(ok, code):
    if not ok:
        raise ValueError('V54_COMPONENT_' + code)


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def run_tests():
    # The caller owns the repository operation lock for this entire invocation.
    from development_passive_entry_profile import _source_snapshot
    runtime = read(RUNTIME)
    dll = verify(runtime['runtime'])
    for source in runtime['source_files']:
        verify(source)
    out = ROOT.parent / 'SporeSpore_Evidence' / ('development-v54-component-' + uuid.uuid4().hex)
    out.mkdir()
    for name in ('v54', 'v53_compat', 'v52_compat'):
        (out / name).mkdir()
    print('V54_COMPONENT_EVIDENCE ' + out.as_posix(), flush=True)
    before = _source_snapshot()
    write(out / 'source_before.json', before)
    environment = os.environ.copy()
    environment.update(PYTHONPATH=str(ROOT / 'tests'), PYTHONDONTWRITEBYTECODE='1',
        SPORE_V54_DLL=str(dll), SPORE_V53_DLL=str(dll), SPORE_V52_DLL=str(dll),
        SPORE_V54_COMPONENT_ROOT=str(out / 'v54'), SPORE_V53_COMPONENT_ROOT=str(out / 'v53_compat'), SPORE_V52_COMPONENT_ROOT=str(out / 'v52_compat'))
    command = [sys.executable, '-B', '-m', 'unittest', '-v',
        'test_development_v54_zero_velocity_brake', 'test_development_v53_bounded_stop_velocity', 'test_development_v52_extended_support_transfer']
    started = time.monotonic()
    try:
        with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
            process = subprocess.run(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                timeout=600, creationflags=subprocess.CREATE_NO_WINDOW)
        write(out / 'execution.json', dict(command=command, exit_code=process.returncode,
            elapsed_seconds=time.monotonic()-started, runtime=binding(dll), world_build_count=0, solver_step_count=0))
    except subprocess.TimeoutExpired:
        write(out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
        raise
    finally:
        after = _source_snapshot()
        write(out / 'source_after.json', after)
        write(out / 'source-stability.json', dict(source_unchanged=before == after))
    require(before == after, 'SOURCE_DRIFT')
    require(process.returncode == 0, 'TESTS_FAILED:' + out.as_posix())
    return dict(ok=True, evidence_root=out.as_posix(), world_build_count=0, solver_step_count=0)


def audit(current_sources=False):
    record = read(RECORD)
    require(record['schema_version'] == 'sporespore_v54_zero_velocity_brake_component_v1'
        and record['status'] == 'native_component_verified_full_route_pending'
        and record['claim_boundary'] == CLAIMS, 'CLAIMS')
    verify(record['auditor'])
    design = read(verify(record['design']))
    require(design['selected_native_policy']['policy_id'] == 'sporespore_balanced_wave_recovery_zero_velocity_brake_v1'
        and design['preserved_requirements']['stop_commands'] == 120
        and design['preserved_requirements']['final_settled_samples'] == 30, 'DESIGN')
    build = read(verify(record['runtime_binding']))
    require(build['runtime'] == record['runtime'] and build['core_test_count'] == 391
        and len(build['source_files']) == 94 and all(v['exit_code'] == 0 for v in build['build_stages']), 'BUILD')
    verify(record['runtime'])
    for item in build['build_evidence_files']:
        verify(item)
    previous = read(verify(record['predecessor_runtime_binding']))
    require(fixture_rows(previous['compiled_fixtures']) == fixture_rows(build['compiled_fixtures'])
        and len(fixture_rows(build['compiled_fixtures'])) == 6, 'RECOVERY_FIXTURE_BYTES')
    if current_sources:
        for item in record['source_files'] + build['source_files']:
            verify(item)
    seen = set()
    for item in record['retained_evidence']:
        require(item['path'] not in seen, 'DUPLICATE_EVIDENCE')
        seen.add(item['path']); verify(item)
    out = verify(record['execution']).parent
    execution = read(out / 'execution.json')
    require(execution['exit_code'] == 0 and execution['runtime'] == record['runtime'], 'EXECUTION')
    require(read(out / 'source-stability.json')['source_unchanged'] is True
        and read(out / 'source_before.json') == read(out / 'source_after.json'), 'SOURCE_STABILITY')
    require(re.search(r'Ran 18 tests in .*\n\nOK\s*$', (out / 'stderr.log').read_text(encoding='utf-8')) is not None, 'TEST_COUNT')
    # Verify compatibility inventories against the original retained responses,
    # not only the test program's summary count.
    totals = []
    for path, expected in [('v54/v53-byte-compatibility.json', 2302), ('v53_compat/v52-byte-compatibility.json', 2289)]:
        count = 0
        for population in read(out / path)['populations']:
            source = read(verify(population['source']))
            hashes = [row['raw_native_response_sha256'] for row in source['development_walking_entry']['rows']]
            require(population['response_hashes'] == hashes and population['commands'] == len(hashes), 'ORIGINAL_RESPONSE_BYTES')
            count += len(hashes)
        require(count == expected, 'COMPATIBILITY_POPULATION')
        totals.append(count)
    legacy = read(out / 'v52_compat/v51-byte-compatibility.json')
    require(legacy['completed_commands'] == 839 and legacy['original_refusal_reproduced'] is True, 'V51_BYTES')
    v54 = out / 'v54'
    chains = read(v54 / 'copied-input-chains.json')
    require(chains['world_build_count'] == chains['solver_step_count'] == 0
        and chains['changed_measurements_simulated'] is False
        and chains['physical_acceptance_authority'] is False and chains['release_authority'] is False, 'CHAIN_CLAIMS')
    expected = {'matched_no_kick_continuation': 1122, 'kick_passive_recovery_resume': 1180}
    require({p['role'] for p in chains['populations']} == set(expected), 'POPULATION')
    retained_holds = 0
    for population in chains['populations']:
        role = population['role']; count = expected[role]
        require(population['commands'] == len(population['response_hashes']) == count
            and population['braked_stopping_commands'] == list(range(1,121))
            and population['zero_amplitude_commands'] == 121 and population['stop_commands'] == 120
            and population['hold_steps'] == [1] + list(range(count-119,count+1))
            and population['changed_startup_commands'] == [1] and population['stateless_session_equal'] is True, 'CHAIN')
        for suffix in ['startup-1'] + ['stop-' + str(n) for n in range(1,121)]:
            row = read(v54 / (role + '-' + suffix + '.json'))
            raw = row['raw_response_utf8'].encode()
            require('sha256:' + hashlib.sha256(raw).hexdigest() == row['raw_response_sha256'], 'RESPONSE_HASH')
            result = json.loads(raw)['value']
            require(result['actuation']['safe_no_actuation'] is False and row['request']['command']['gait_amplitude'] == 0, 'HOLD')
            guard = result['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['zero_amplitude_motor_brake']
            require(guard['zero_applied_impulse_claim'] is False and guard['physical_acceptance_authority'] is False
                and len(guard['ordered_commands']) == 8, 'BRAKE_RECEIPT')
            for motor, old, detail in zip(result['actuation']['ordered_commands'], row['reference_output']['actuation']['ordered_commands'], guard['ordered_commands']):
                require(motor['actuator_id'] == detail['actuator_id'] == old['actuator_id']
                    and motor['mode'] == old['mode'] == 'position_velocity'
                    and motor['target_velocity_rad_s'] == detail['held_target_velocity_rad_s'] == 0
                    and detail['previous_target_velocity_rad_s'] == old['target_velocity_rad_s'], 'EXACT_BRAKE')
                if old['target_velocity_rad_s'] != 0:
                    require(detail['changed'] is True and motor['velocity_saturated'] is True
                        and motor['safety_contribution_rad_s'] == old['safety_contribution_rad_s'] - old['target_velocity_rad_s'], 'BRAKE_DELTA')
            retained_holds += 1
    negatives = read(v54 / 'negative-controls.json')['controls']
    require([c['mutation'] for c in negatives] == ['parent_memory','bias_low','bias_high','clock','height','geometry'], 'NEGATIVES')
    for row in negatives + [read(v54 / 'unchanged-deadline.json')]:
        result = json.loads(row['raw_response_utf8'])['value']
        require(result['next_memory'] == row['request']['memory'] and result['actuation']['safe_no_actuation'] is True
            and all(c['target_velocity_rad_s'] == 0 for c in result['actuation']['ordered_commands']), 'SAFE_REFUSAL')
    packets = read(v54 / 'packet-refusals.json')['controls']
    require([c['mutation'] for c in packets] == ['nan_velocity','infinite_velocity','caller_override']
        and all(c['native_status'] != 0 and json.loads(c['raw_response_utf8'])['ok'] is False for c in packets), 'PACKET_REFUSALS')
    return dict(ok=True, core_tests_passed=391, native_tests_passed=18,
        v53_responses_byte_exact=totals[0], v52_responses_byte_exact=totals[1], v51_responses_byte_exact=840,
        v54_copied_input_commands=2302, retained_zero_amplitude_commands=retained_holds,
        current_sources_verified=current_sources, retained_evidence_files=len(seen), **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('V54_ZERO_VELOCITY_BRAKE ' + json.dumps(run_tests() if args.run else audit(args.current_sources), separators=(',', ':')))
