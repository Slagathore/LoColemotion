"""Verify the R10Q native startup study; optionally replay every terminal input."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import development_recovery_refusal as native
from sporespore_locomotion import LocomotionCoreError

ROOT = Path(__file__).resolve().parents[2]
RECORD = ROOT / 'sdk/recovery/r10q_startup_sweep_component_v1.json'
WALK = 'sporespore_balanced_wave_recovery_initialized_zero_brake_v1'
HOLD = 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1'


def require(ok, code):
    if not ok:
        raise ValueError('R10Q_STARTUP_COMPONENT_' + code)


def read(path):
    return json.loads(Path(path).read_bytes())


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute():
        path = ROOT / path
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    require(digest == item['raw_sha256'] and path.stat().st_size == item['byte_length'], 'BINDING:' + str(path))
    return path


def inspect_cases(population, policy, budget, core=None):
    cases = population['cases']
    require([case['phase'] for case in cases] == list(range(360)), 'PHASE_POPULATION')
    failures, calls, cold = collections.Counter(), 0, 0
    for case in cases:
        hashes = case['response_hashes']
        require(1 <= len(hashes) <= budget and len(hashes) == case['completed_calls'], 'CALL_COUNT')
        q = case['terminal_request']
        raw = case['final_raw_response_utf8'].encode()
        require(native.digest(raw) == hashes[-1] and q['policy_id'] == policy, 'TERMINAL_BINDING')
        require(q['state']['semantic_step'] == len(hashes), 'TERMINAL_CLOCK')
        if policy == HOLD:
            require(q['command']['gait_amplitude'] == 0
                    and q['command']['desired_planar_velocity_task_m_s'] == dict(x=0, y=0, z=0), 'HOLD_COMMAND')
        refusal = case['first_refusal']
        envelope = json.loads(raw)
        if refusal is None:
            require(len(hashes) == budget and envelope['value']['actuation']['safe_no_actuation'] is False, 'FULL_BUDGET')
        else:
            require(refusal['command'] == len(hashes) and type(refusal['error']) is str and refusal['error'], 'REFUSAL_IDENTITY')
            failures[refusal['error']] += 1
            if envelope.get('ok') is True:
                out = envelope['value']
                require(out['actuation']['safe_no_actuation'] is True and out['next_memory'] == q['memory']
                        and len(out['actuation']['ordered_commands']) == 8
                        and all(c['target_velocity_rad_s'] == 0 for c in out['actuation']['ordered_commands']),
                        'REFUSAL_ACTUATION')
                require(out['actuation']['receipt']['controller_error'] == refusal['error'], 'REFUSAL_CODE')
            else:
                require(envelope.get('failure_code') == refusal['error'], 'ABI_REFUSAL')
        if core is not None:
            try:
                core.balanced_wave_policy_step_with_measured_body(policy, q)
            except LocomotionCoreError:
                require(refusal is not None, 'UNEXPECTED_COLD_ABI_FAILURE')
            require(core.raw_response == raw, 'COLD_NATIVE_BYTES')
            cold += 1
        calls += len(hashes)
    return dict(population=population['id'], phases=360, full_budget_cases=360-sum(failures.values()),
                refused_cases=sum(failures.values()), refusal_codes=dict(failures), step_calls=calls,
                cold_terminal_replays=cold)


def audit(record, cold=False):
    require(record['schema_version'] == 'sporespore_r10q_startup_sweep_component_v1', 'SCHEMA')
    for item in record['source_files'] + record['retained_evidence'] + [record['auditor']]:
        verify(item)
    runtime = read(verify(record['runtime_binding']))
    dll = verify(runtime['runtime'])
    for item in runtime['source_files']:
        verify(item)
    root = Path(record['evidence_root'])
    require((root/'source_before.json').read_bytes() == (root/'source_after.json').read_bytes(), 'SOURCE_DRIFT')
    declaration = read(root/'declaration.json')
    require(declaration['runtime']['raw_sha256'] == runtime['runtime']['raw_sha256']
            and declaration['startup_gait_phases'] == list(range(360))
            and declaration['walking_startup_commands'] == 73 and declaration['hold_commands'] == 240
            and declaration['maximum_phase_sweep_calls'] == 563400, 'DECLARATION')
    design = read(verify(declaration['population_design']))
    expected_ids = [p['id'] for p in design['populations']]
    require(len(expected_ids) == 5, 'EXPOSED_POPULATIONS')
    for item in [design['descriptor_source'], *[p['report'] for p in design['populations']]]:
        verify(item)
    original = read(root/'original-byte-compatibility.json')['populations']
    require([p['id'] for p in original] == expected_ids
            and sum(len(p['response_hashes']) for p in original) == 4170, 'ORIGINAL_COMPATIBILITY')
    stop = read(root/'r10m-law-and-session.json')['populations']
    require(len(stop) == 2 and all(p['initialized_feedback_commands'] == [1]
            and len(p['later_brake_commands']) == 120 and p['session_and_stateless_equal'] is True for p in stop),
            'STOP_COMPATIBILITY')
    core = native.RecordedCore(dll) if cold else None
    walking = read(root/'startup-360-full-blend.json')['populations']
    require([p['id'] for p in walking] == expected_ids, 'WALK_POPULATIONS')
    walk_results = [inspect_cases(p, WALK, 73, core) for p in walking]
    hold_results = [inspect_cases(read(root/('v50-hold-'+name+'.json')), HOLD, 240, core) for name in expected_ids]
    totals = dict(phase_cases=sum(p['phases'] for p in walk_results+hold_results),
        phase_step_calls=sum(p['step_calls'] for p in walk_results+hold_results),
        refused_cases=sum(p['refused_cases'] for p in walk_results+hold_results))
    require(totals == record['observed']['phase_totals'], 'RECORDED_TOTALS')
    claims = record['claim_boundary']
    require(claims == dict(world_build_count=0, solver_step_count=0, physical_prefix_phase_coverage=False,
        physical_response_predicted=False, physical_acceptance_authority=False, release_authority=False,
        original_results_regraded=False, complete_smoke_safety_gate_passed=False, sdk1_score='14/20'), 'CLAIMS')
    return dict(ok=True, walking=walk_results, hold=hold_results, **totals,
        terminal_inputs_cold_replayed=3600 if cold else 0, original_native_responses_preserved=4170,
        complete_stop_histories_checked=2, **claims)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--cold', action='store_true')
    args = parser.parse_args()
    print('R10Q_STARTUP_COMPONENT ' + json.dumps(audit(read(RECORD), args.cold), separators=(',', ':')))
