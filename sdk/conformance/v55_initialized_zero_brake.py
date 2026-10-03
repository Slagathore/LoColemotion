"""Run and independently audit finite V55 native component evidence.

The caller owns the operation lock. No physical route is constructed here.
Cold verification covers every retained regular-history output and each
synthetic startup terminal input, not every interior synthetic startup step.
"""
import argparse
import base64
import copy
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

import development_recovery_refusal as refusal
import r10n_zero_world_state_sweep as prior
from development_passive_entry_profile import _source_snapshot
from v52_extended_support_transfer import verify, fixture_rows
from sporespore_locomotion import LocomotionCoreError

ROOT = prior.ROOT
RUNTIME = ROOT / 'sdk/development/recovery_candidates/v55-initialized-zero-brake-core-v1.runtime.json'
RECORD = ROOT / 'sdk/recovery/v55_initialized_zero_brake_component_v1.json'
PREFLIGHT = ROOT.parent / 'SporeSpore_Evidence/development-v55-component-preflight-6ee81c5acf2e4486bca302e1e9c15881/preflight_failure.json'
FAILED_TEST = ROOT.parent / 'SporeSpore_Evidence/development-v55-component-0eedef7acac649338e601e6592da5e82'
AUDIT_DIAGNOSIS = ROOT.parent / 'SporeSpore_Evidence/development-v55-cold-audit-diagnosis-3ceb1ec53f2441968ac07ee85799b83e/diagnosis.json'
POLICY = 'sporespore_balanced_wave_recovery_initialized_zero_brake_v1'
MEMORY = 'sporespore_balanced_wave_recovery_initialized_zero_brake_memory_v1'
TEST = 'tests/test_development_v55_initialized_zero_brake.py'
CLAIMS = dict(world_build_count=0, solver_step_count=0, physical_route_integrated=False,
    physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
    original_attempt_reclassified=False, sdk1_score='14/20')


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False); stream.write('\n')


def run_tests():
    runtime = prior.failure.read(RUNTIME)
    dll = prior.verified(runtime['runtime'])
    for item in runtime['source_files']:
        verify(item)
    out = ROOT.parent / 'SporeSpore_Evidence' / ('development-v55-component-' + uuid.uuid4().hex)
    out.mkdir(); (out / 'v55').mkdir()
    before = _source_snapshot(); write(out / 'source_before.json', before)
    environment = os.environ.copy()
    environment.update(PYTHONPATH=str(ROOT / 'tests'), PYTHONDONTWRITEBYTECODE='1',
        SPORE_V55_DLL=str(dll), SPORE_V55_COMPONENT_ROOT=str(out / 'v55'))
    command = [sys.executable, '-B', '-m', 'unittest', '-f', '-v', 'test_development_v55_initialized_zero_brake']
    print('V55_COMPONENT_EVIDENCE '+out.as_posix(), flush=True)
    started = time.monotonic()
    try:
        with (out / 'stdout.log').open('xb') as stdout, (out / 'stderr.log').open('xb') as stderr:
            process = subprocess.run(command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                timeout=1800, creationflags=subprocess.CREATE_NO_WINDOW)
        write(out / 'execution.json', dict(command=command, exit_code=process.returncode,
            elapsed_seconds=time.monotonic()-started, runtime=runtime['runtime'], **CLAIMS))
    except subprocess.TimeoutExpired:
        write(out / 'execution.json', dict(command=command, timed_out=True, direct_process_killed_and_reaped=True))
        raise
    finally:
        after = _source_snapshot(); write(out / 'source_after.json', after)
        write(out / 'source-stability.json', dict(source_unchanged=before == after))
    prior.require(before == after, 'V55_SOURCE_DRIFT')
    prior.require(process.returncode == 0, 'V55_TESTS_FAILED:'+out.as_posix())
    return dict(ok=True, evidence_root=out.as_posix(), **CLAIMS)


def audit(out):
    out = Path(out).resolve()
    prior.require(out.parent == ROOT.parent / 'SporeSpore_Evidence' and out.name.startswith('development-v55-component-'), 'V55_EVIDENCE_ROOT')
    runtime = prior.failure.read(RUNTIME)
    preflight = prior.failure.read(PREFLIGHT)
    prior.require(preflight['matching_source_files'] == 95 and preflight['native_component_tests_started'] is False
        and preflight['runtime_binding'] == prior.failure.binding(RUNTIME), 'V55_RETAINED_PREFLIGHT')
    failed = prior.failure.read(FAILED_TEST/'execution.json')
    prior.require(failed['exit_code'] == 1 and failed['runtime'] == runtime['runtime']
        and prior.failure.read(FAILED_TEST/'source_before.json') == prior.failure.read(FAILED_TEST/'source_after.json')
        and 'Ran 5 tests' in (FAILED_TEST/'stderr.log').read_text(encoding='utf-8')
        and 'FAILED (failures=1)' in (FAILED_TEST/'stderr.log').read_text(encoding='utf-8'), 'V55_RETAINED_TEST_FAILURE')
    prior.require(runtime['core_test_count'] == 391 and len(runtime['source_files']) == 95
        and all(s['exit_code'] == 0 for s in runtime['build_stages']), 'V55_NATIVE_BUILD')
    core = refusal.RecordedCore(prior.verified(runtime['runtime']))
    for item in runtime['source_files'] + runtime['build_evidence_files']:
        verify(item)
    before, after = prior.failure.read(out/'source_before.json'), prior.failure.read(out/'source_after.json')
    prior.require(before == after and prior.failure.read(out/'source-stability.json')['source_unchanged'], 'V55_SOURCE_STABILITY')
    captured = {item['path']:item for item in before['changed_files']}
    prior.require(captured[TEST]['raw_sha256'] == refusal.digest((ROOT/TEST).read_bytes()), 'V55_EXECUTED_TEST_SOURCE')
    driver_path = Path(__file__).relative_to(ROOT).as_posix()
    executed_driver = base64.b64decode(captured[driver_path]['replacement_base64']).decode('utf-8')
    current_driver = Path(__file__).read_text(encoding='utf-8')
    prior.require(executed_driver.split('def run_tests():', 1)[1].split('\ndef audit(', 1)[0]
        == current_driver.split('def run_tests():', 1)[1].split('\ndef audit(', 1)[0], 'V55_EXECUTION_DRIVER_UNCHANGED')
    execution = prior.failure.read(out/'execution.json')
    prior.require(execution['exit_code'] == 0 and execution['runtime'] == runtime['runtime'], 'V55_EXECUTION')
    prior.require(re.search(r'Ran 7 tests in .*\n\nOK\s*$', (out/'stderr.log').read_text(encoding='utf-8')) is not None, 'V55_TEST_COUNT')
    design_path = ROOT/'sdk/recovery/r10o_initialized_zero_brake_successor_design_v1.json'
    design = prior.failure.read(design_path)
    prior.require(design['selected_native_policy']['policy_id'] == POLICY
        and design['preserved_requirements']['maximum_support_transfer_preparation_commands'] == 240
        and design['preserved_requirements']['minimum_support_release_ready_dwell'] == 6
        and design['preserved_requirements']['final_settled_samples'] == 30, 'V55_DESIGN')
    population_design = prior.failure.read(ROOT/'sdk/recovery/r10n_zero_world_state_sweep_design_v1.json')
    descriptor = refusal.integers(prior.failure.read(prior.verified(population_design['descriptor_source']))['configuration']['base_descriptor'])
    predecessor_path = ROOT/'sdk/development/recovery_candidates/v54-zero-velocity-brake-core-v1.runtime.json'
    predecessor = prior.failure.read(predecessor_path)
    fixtures = fixture_rows(runtime['compiled_fixtures'])
    prior.require(len(fixtures) == 6 and fixtures == fixture_rows(predecessor['compiled_fixtures']), 'V55_RECOVERY_FIXTURE_BYTES')
    identity = prior.failure.read(out/'v55/identity.json')
    prior.require(identity['profile'] == core.balanced_wave_policy_profile(POLICY, descriptor)
        and identity['predecessor'] == core.balanced_wave_policy_profile(prior.POLICY, descriptor), 'V55_NATIVE_PROFILE')
    compatibility = prior.failure.read(out/'v55/original-byte-compatibility.json')['populations']
    law = prior.failure.read(out/'v55/r10m-law-and-session.json')['populations']
    legacy = prior.failure.read(out/'v55/legacy-current-memory.json')['populations']
    timeout = prior.failure.read(out/'v55/unchanged-r10n-timeout.json')
    startup = prior.failure.read(out/'v55/startup-360-full-blend.json')['populations']
    cold_calls, original_count, startup_calls, complete_cases, refusals = 0, 0, 0, 0, {}

    def request(row):
        q = refusal.integers(dict(copy.deepcopy(row['request']), descriptor=descriptor))
        q.update(schema_version='sporespore_balanced_wave_policy_step_request_v3', policy_id=POLICY)
        q['memory']['schema_version'] = MEMORY
        return q

    def reproduce(q, expected):
        nonlocal cold_calls
        result = core.balanced_wave_policy_step_with_measured_body(POLICY, q)
        prior.require(refusal.digest(core.raw_response) == expected, 'V55_COLD_NATIVE_BYTES')
        cold_calls += 1
        return result

    def initial_memory():
        memory = core.balanced_wave_policy_initial_memory(POLICY, descriptor)
        for limb in memory['ordered_limb_memory']:
            limb['gait_step'] = 90; limb['evidence_gait_step_limit'] = 1530
        return memory

    for index, source in enumerate(population_design['populations']):
        report = prior.failure.read(prior.verified(source['report']))
        rows = report['development_walking_entry']['rows']
        expected = [r['raw_native_response_sha256'] for r in rows]
        failed = report['detail']['portable_step_receipt']['development_native_step_failure'] if source['includes_terminal_refusal'] else None
        if failed:
            expected.append(failed['response']['raw_sha256'])
        prior.require(compatibility[index]['id'] == source['id'] and compatibility[index]['report'] == source['report']
            and compatibility[index]['response_hashes'] == expected, 'V55_ORIGINAL_RESPONSE_POPULATION')
        original_count += len(expected)
        if index < 2:
            memory = initial_memory()
            chain = rows + [dict(request=json.loads(failed['request']['utf8_text']))]
            prior.require(len(legacy[index]['response_hashes']) == len(chain), 'V55_LEGACY_POPULATION')
            for row, digest in zip(chain, legacy[index]['response_hashes']):
                q = request(row); q['memory'] = memory
                result = reproduce(q, digest)
                prior.require(not result['actuation']['safe_no_actuation'], 'V55_LEGACY_NATIVE_VALID')
                memory = result['next_memory']
        elif index < 4:
            value = law[index-2]
            prior.require(value['id'] == source['id'] and len(value['response_hashes']) == len(rows)
                and value['initialized_feedback_commands'] == [1] and len(value['later_brake_commands']) == 120
                and value['session_and_stateless_equal'] is True, 'V55_LAW_POPULATION')
            memory = initial_memory()
            for row, digest in zip(rows, value['response_hashes']):
                q = request(row); q['memory'] = memory
                result = reproduce(q, digest)
                memory = result['next_memory']
                motors = result['actuation']['ordered_commands']
                if row['session_local_step'] == 1:
                    prior.require(all(abs(c['target_velocity_rad_s']) <= .25 for c in motors)
                        and motors == row['native_output']['actuation']['ordered_commands'], 'V55_INITIAL_FEEDBACK')
                elif row['request']['command']['gait_amplitude'] == 0:
                    prior.require(all(c['target_velocity_rad_s'] == 0 for c in motors), 'V55_LATER_BRAKE')
        else:
            prior.require(len(timeout['valid_response_hashes']) == len(rows), 'V55_TIMEOUT_HISTORY')
            memory = initial_memory()
            for row, digest in zip(rows, timeout['valid_response_hashes']):
                q = request(row); q['memory'] = memory
                result = reproduce(q, digest)
                memory = result['next_memory']
            q = request(dict(request=json.loads(failed['request']['utf8_text'])))
            q['memory'] = memory
            prior.require(q == timeout['request'], 'V55_ORIGINAL_TIMEOUT_INPUT')
            result = reproduce(q, refusal.digest(timeout['raw_response_utf8'].encode()))
            prior.require(result['actuation']['safe_no_actuation'] and result['next_memory'] == q['memory']
                and result['actuation']['receipt']['controller_error'] == 'FRAME_INVALID:measured_support_transfer_preparation_timeout', 'V55_TIMEOUT_PRESERVED')
        cases = startup[index]['cases']
        prior.require(startup[index]['id'] == source['id'] and [c['phase'] for c in cases] == list(range(360)), 'V55_STARTUP_PHASES')
        for case in cases:
            count = case['completed_calls']; startup_calls += count
            prior.require(1 <= count <= 73 and len(case['response_hashes']) == count, 'V55_STARTUP_CALLS')
            q = case['terminal_request']; original = request(rows[count-1])
            prior.require({k:v for k,v in q.items() if k != 'memory'} == {k:v for k,v in original.items() if k != 'memory'}, 'V55_STARTUP_MEASURED_SOURCE')
            prior.require(refusal.digest(case['final_raw_response_utf8'].encode()) == case['response_hashes'][-1], 'V55_STARTUP_TERMINAL_BYTES')
            result = reproduce(q, case['response_hashes'][-1])
            if case['first_refusal'] is None:
                prior.require(count == 73 and not result['actuation']['safe_no_actuation']
                    and result['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['reference_velocity_startup_scale'] == 1, 'V55_COMPLETE_STARTUP')
                complete_cases += 1
            else:
                code = case['first_refusal']['error']; refusals[code] = refusals.get(code, 0)+1
                prior.require(case['first_refusal']['command'] == count and result['actuation']['safe_no_actuation']
                    and result['next_memory'] == q['memory'] and result['actuation']['receipt']['controller_error'] == code, 'V55_STARTUP_REFUSAL')
        del report, rows
    prior.require(original_count == 4170 and cold_calls == 5970 and complete_cases + sum(refusals.values()) == 1800, 'V55_TOTAL_POPULATION')
    controls = prior.failure.read(out/'v55/crossed-packet-refusals.json')['controls']
    prior.require([c['mutation'] for c in controls] == ['memory', 'clock', 'body_frame', 'caller_override'], 'V55_NEGATIVE_CONTROL_POPULATION')
    for control in controls:
        try:
            result = core.balanced_wave_policy_step_with_measured_body(POLICY, control['request'])
        except LocomotionCoreError:
            prior.require(json.loads(core.raw_response)['ok'] is False, 'V55_NEGATIVE_ABI_REFUSAL')
        else:
            prior.require(result['actuation']['safe_no_actuation'] and result['next_memory'] == control['request']['memory'], 'V55_NEGATIVE_CONTROLLER_REFUSAL')
        prior.require(core.raw_response.decode() == control['raw_response_utf8'], 'V55_NEGATIVE_NATIVE_BYTES')
        cold_calls += 1
    diagnostic = prior.failure.read(AUDIT_DIAGNOSIS)
    prior.require(diagnostic['walking_command'] == 3 and diagnostic['memory_numerically_equal'] is True
        and diagnostic['copied_response_sha256'] != diagnostic['expected_response_sha256']
        and diagnostic['native_memory_response_sha256'] == diagnostic['expected_response_sha256'], 'V55_READER_DIAGNOSIS')
    reproduce(diagnostic['copied_request'], diagnostic['copied_response_sha256'])
    reproduce(diagnostic['native_memory_request'], diagnostic['native_memory_response_sha256'])
    return dict(schema_version='sporespore_v55_initialized_zero_brake_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_core_and_native_c_abi', authority_mode='finite_native_component_validation', question_class='development'),
        status='native_component_verified_physical_route_pending', design=prior.failure.binding(design_path),
        pre_execution_refusal=prior.failure.binding(PREFLIGHT),
        failed_test_attempt=[prior.failure.binding(p) for p in sorted(FAILED_TEST.rglob('*')) if p.is_file()],
        test_expectation_repair='The initialization cap is an upper bound, not a requirement that every motor saturate. Corrected both consumers to enforce <=0.25 and exact original V53 motor-command equality. Native DLL and scientific thresholds unchanged.',
        cold_auditor_diagnosis=prior.failure.binding(AUDIT_DIAGNOSIS),
        cold_auditor_correction='Thread exact native-emitted memory through every copied measurement sequence, as the component tests do. Re-normalizing old recorded memory can erase signed zero and cannot reconstruct the new native response bytes.',
        auditor=prior.failure.binding(Path(__file__)), test_source=prior.failure.binding(ROOT/TEST),
        executed_driver_raw_sha256=captured[driver_path]['raw_sha256'], execution_driver_function_unchanged=True,
        predecessor_runtime_binding=prior.failure.binding(predecessor_path), original_recovery_fixtures_byte_exact=6,
        runtime_binding=prior.failure.binding(RUNTIME), runtime=runtime['runtime'],
        evidence_root=out.as_posix(), execution=prior.failure.binding(out/'execution.json'),
        retained_evidence=[prior.failure.binding(p) for p in sorted(out.rglob('*')) if p.is_file()],
        source_files=[prior.failure.binding(ROOT/p) for p in [TEST, 'sdk/conformance/v55_initialized_zero_brake.py',
            'sdk/conformance/development_recovery_refusal.py', 'sdk/conformance/r10n_zero_world_state_sweep.py', 'sdk/python/sporespore_locomotion.py']],
        core_tests_passed=391, component_tests_passed=7, original_native_responses_byte_exact=4170,
        v55_r10m_commands_verified=2302, v55_legacy_current_memory_commands=1010,
        v55_r10n_valid_commands=857, v55_r10n_timeout_preserved=True,
        startup_cases=1800, startup_calls=startup_calls, complete_startup_blend_cases=complete_cases,
        startup_refusal_counts=refusals, cold_native_reproductions=cold_calls,
        cold_negative_control_reproductions=4,
        verification_limits=['Cold reproduction covers every regular-history command and all 1800 synthetic startup terminal inputs; interior synthetic startup steps are retained by response hashes and frozen test execution.',
            'The 360 synthetic gait clocks reuse five exposed measured sequences, not 360 physically generated prefix-phase handoff states.',
            'Copied measurements do not predict the physical response to changed motor commands. No recovery, locomotion or settled-stop acceptance follows.'], claim_boundary=CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--run', action='store_true')
    parser.add_argument('--create', action='store_true'); parser.add_argument('--evidence-root')
    args = parser.parse_args()
    if args.run:
        print(json.dumps(run_tests()))
    else:
        observed = audit(args.evidence_root if args.create else prior.failure.read(RECORD)['evidence_root'])
        if args.create:
            write(RECORD, observed)
        else:
            prior.require(observed == prior.failure.read(RECORD), 'V55_COMPONENT_RECONSTRUCTION')
        print(json.dumps({k:observed[k] for k in ['status', 'core_tests_passed', 'component_tests_passed',
            'original_native_responses_byte_exact', 'startup_cases', 'startup_calls', 'complete_startup_blend_cases',
            'startup_refusal_counts', 'cold_native_reproductions', 'claim_boundary']}))
