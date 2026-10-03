"""Run or audit V53 component validation; no physical worlds are constructed."""
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

RECORD = ROOT / 'sdk/recovery/v53_bounded_stop_velocity_component_v1.json'
RUNTIME = ROOT / 'sdk/development/recovery_candidates/v53-bounded-stop-velocity-core-v1.runtime.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, production_route_integrated=False,
    physical_execution_authorized=False, physical_acceptance_authority=False,
    release_authority=False, original_campaign_regraded=False, sdk1_score='14/20')


def require(ok, code):
    if not ok:
        raise ValueError('V53_COMPONENT_' + code)


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
    out = ROOT.parent / 'SporeSpore_Evidence' / ('development-v53-component-' + uuid.uuid4().hex)
    out.mkdir()
    for name in ('v53', 'v52_compat'):
        (out / name).mkdir()
    print('V53_COMPONENT_EVIDENCE ' + out.as_posix(), flush=True)
    before = _source_snapshot()
    write(out / 'source_before.json', before)
    environment = os.environ.copy()
    environment.update(PYTHONPATH=str(ROOT / 'tests'), PYTHONDONTWRITEBYTECODE='1',
        SPORE_V53_DLL=str(dll), SPORE_V52_DLL=str(dll),
        SPORE_V53_COMPONENT_ROOT=str(out / 'v53'), SPORE_V52_COMPONENT_ROOT=str(out / 'v52_compat'))
    command = [sys.executable, '-B', '-m', 'unittest', '-v',
        'test_development_v53_bounded_stop_velocity', 'test_development_v52_extended_support_transfer']
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
    require(record['schema_version'] == 'sporespore_v53_bounded_stop_velocity_component_v1', 'SCHEMA')
    require(record['status'] == 'native_component_verified_full_route_pending' and record['claim_boundary'] == CLAIMS, 'CLAIMS')
    design = read(verify(record['design']))
    require(design['selected_native_policy']['maximum_absolute_velocity_rad_s'] == .25, 'DESIGN_CAP')
    build = read(verify(record['runtime_binding']))
    require(build['runtime'] == record['runtime'] and build['core_test_count'] == 388
        and len(build['source_files']) == 93 and all(v['exit_code'] == 0 for v in build['build_stages']), 'BUILD')
    verify(record['runtime'])
    for item in build['build_evidence_files']:
        verify(item)
    previous = read(verify(record['predecessor_runtime_binding']))
    require(fixture_rows(previous['compiled_fixtures']) == fixture_rows(build['compiled_fixtures'])
        and len(fixture_rows(build['compiled_fixtures'])) == 6, 'RECOVERY_FIXTURE_BYTES')
    if current_sources:
        for item in record['source_files'] + build['source_files']:
            verify(item)
    paths = set()
    for item in record['retained_evidence']:
        require(item['path'] not in paths, 'DUPLICATE_EVIDENCE')
        paths.add(item['path'])
        verify(item)
    out = verify(record['execution']).parent
    execution = read(out / 'execution.json')
    require(execution['exit_code'] == 0 and execution['runtime'] == record['runtime'], 'EXECUTION')
    require(read(out / 'source-stability.json')['source_unchanged'] is True
        and read(out / 'source_before.json') == read(out / 'source_after.json'), 'SOURCE_STABILITY')
    require(re.search(r'Ran 12 tests in .*\n\nOK\s*$', (out / 'stderr.log').read_text(encoding='utf-8')) is not None, 'TEST_COUNT')
    v53 = out / 'v53'
    compatibility = read(v53 / 'v52-byte-compatibility.json')['populations']
    chains = read(v53 / 'copied-input-chains.json')
    require(chains['world_build_count'] == chains['solver_step_count'] == 0
        and chains['changed_measurements_simulated'] is False
        and chains['physical_acceptance_authority'] is False and chains['release_authority'] is False, 'CHAIN_CLAIMS')
    expected = {'matched_no_kick_continuation': (1109, []), 'kick_passive_recovery_resume': (1180, [94,95,96])}
    require({p['role'] for p in compatibility} == set(expected)
        and {p['role'] for p in chains['populations']} == set(expected), 'POPULATION')
    for population in compatibility:
        verify(population['source'])
        require(population['commands'] == len(population['response_hashes']) == expected[population['role']][0], 'V52_BYTES')
    for population in chains['populations']:
        count, clipped = expected[population['role']]
        require(population['commands'] == len(population['response_hashes']) == count
            and population['clipped_stopping_commands'] == clipped and population['zero_amplitude_commands'] == 121
            and population['stop_commands'] == 120 and population['hold_steps'] == [1] + list(range(count-119,count+1))
            and population['clipped_startup_commands'] == ([1] if population['role'] == 'matched_no_kick_continuation' else [])
            and population['stateless_session_equal'] is True, 'CHAIN')
    for name in [f'kick_passive_recovery_resume-stop-{n}.json' for n in (94,95,96)] + ['matched_no_kick_continuation-startup-1.json']:
        row = read(v53 / name)
        raw = row['raw_response_utf8'].encode()
        require('sha256:' + hashlib.sha256(raw).hexdigest() == row['raw_response_sha256'], 'RESPONSE_HASH')
        result = json.loads(raw)['value']
        require(result['actuation']['safe_no_actuation'] is False and row['request']['command']['gait_amplitude'] == 0, 'HOLD')
        guard = result['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['zero_amplitude_velocity_guard']
        require(guard['maximum_absolute_velocity_rad_s'] == .25 and guard['physical_acceptance_authority'] is False, 'GUARD')
        clipped = 0
        for command, old, detail in zip(result['actuation']['ordered_commands'], row['original_output']['actuation']['ordered_commands'], guard['ordered_commands']):
            limit = min(.25, old['maximum_target_speed_rad_s'])
            value = max(-limit, min(limit, old['target_velocity_rad_s']))
            require(command['target_velocity_rad_s'] == value and detail['bounded_velocity_rad_s'] == value
                and detail['original_velocity_rad_s'] == old['target_velocity_rad_s']
                and detail['effective_limit_rad_s'] == limit, 'EXACT_CAP')
            if value != old['target_velocity_rad_s']:
                clipped += 1
                require(command['velocity_saturated'] is True and command['safety_contribution_rad_s']
                    == old['safety_contribution_rad_s'] + (value - old['target_velocity_rad_s']), 'CLIP_DELTA')
        require(clipped > 0, 'CLIPPED_COMMAND')
    negatives = read(v53 / 'negative-controls.json')['controls']
    require([c['mutation'] for c in negatives] == ['parent_memory','bias_low','bias_high','clock','height','geometry'], 'NEGATIVES')
    for row in negatives + [read(v53 / 'unchanged-deadline.json')]:
        result = json.loads(row['raw_response_utf8'])['value']
        require(result['next_memory'] == row['request']['memory'] and result['actuation']['safe_no_actuation'] is True
            and all(c['target_velocity_rad_s'] == 0 for c in result['actuation']['ordered_commands']), 'SAFE_REFUSAL')
    packets = read(v53 / 'packet-refusals.json')['controls']
    require([c['mutation'] for c in packets] == ['nan_velocity','infinite_velocity','caller_override']
        and all(c['native_status'] != 0 and json.loads(c['raw_response_utf8'])['ok'] is False for c in packets), 'PACKET_REFUSALS')
    legacy = read(out / 'v52_compat/v51-byte-compatibility.json')
    require(legacy['completed_commands'] == 839 and legacy['original_refusal_reproduced'] is True, 'V51_BYTES')
    return dict(ok=True, core_tests_passed=388, native_tests_passed=12, v52_responses_byte_exact=2289,
        v51_responses_byte_exact=840, v53_copied_input_commands=2289, clipped_kicked_stop_commands=[94,95,96],
        current_sources_verified=current_sources, retained_evidence_files=len(paths), **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--current-sources', action='store_true')
    args = parser.parse_args()
    print('V53_BOUNDED_STOP_VELOCITY ' + json.dumps(run_tests() if args.run else audit(args.current_sources), separators=(',', ':')))
