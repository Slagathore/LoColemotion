"""Retained-evidence audit of R10Y candidate admission and two full reports.

This independent output consumer is bound separately from the pre-test worker
source key. It performs no native calls, safety qualification or physics.
"""
import argparse
import json
from pathlib import Path

import r10y_facade_component as facade
import development_recovery_candidate as candidate
import r10y_development as development

native = facade.native
ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10y_report_component_v1.json'
CANDIDATE = EVIDENCE / 'r10y-candidate-3d32c4495c754ae096b12f3a8deb5fc6'
REPORTS = EVIDENCE / 'r10y-complete-report-60e496278bde40978d2bb6929b39e7e8'
INITIAL = [EVIDENCE / 'r10y-candidate-8c7b85f4242e478cb0567f5db6057b9c',
           EVIDENCE / 'r10y-candidate-35234504acbc4cd8b517a661c2381cc7']
WRAPPERS = [EVIDENCE / ('r10y-candidate-launch-' + suffix) for suffix in (
    'e9f2e385ee264cd78689213210de6079', '94283597f26047a49f1b2ea06fc40dd3', '169aa5026de541358ae80726d19eb9f9')]
WRAPPERS.append(EVIDENCE / 'r10y-report-launch-3c39c624a5e949fc91ecec36e87e641c')
KEY = ROOT / 'sdk/recovery/r10y_v56_walking_entry_contract_v3.json'
PROFILE = ROOT / 'sdk/development/recovery_candidates/r10y-partial-direct-neutral-integrated-v1.json'
MARKER = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '


def retained_replay(directory, expected_exit=0):
    report = directory / 'worker_report.json'
    replay = directory / 'passive_entry_replay'
    execution = native.read(replay / 'execution.json')
    assert execution['returncode'] == expected_exit and execution['timed_out'] is False
    assert execution['world_build_count'] == execution['solver_step_count'] == 0
    assert execution['physical_acceptance_authority'] is execution['release_authority'] is False
    assert execution['input_raw_sha256'] == native.diagnosis.binding(report)['raw_sha256']
    for name in ('stdout', 'stderr'):
        binding = native.diagnosis.binding(replay / (name + '.txt'))
        assert execution[name + '_binding'] == {k: binding[k] for k in ('byte_length', 'raw_sha256')}
    assert (replay / 'stderr.txt').read_bytes() == b''
    lines = [line[len(MARKER):] for line in (replay / 'stdout.txt').read_text(encoding='utf-8').splitlines() if line.startswith(MARKER)]
    assert len(lines) == 1
    return json.loads(lines[0])


def observations():
    assert facade.audit()['ok']
    fixed = native.read(KEY)
    assert fixed['source_key_complete'] is True and len(fixed['bound_source_files']) == 1270
    for row in fixed['bound_source_files']:
        native.verify(dict(row, path=(ROOT / row['path']).as_posix()))
    selected = candidate.selection(candidate.reference_for_path(PROFILE))
    assert selected['diagnostic_schedule']['walking_policy_id'] == development.ROUTE
    assert selected['worker_selection']['worker'].endswith('/r10y_development_worker_v1.gd')
    assert selected['reader'].endswith('/r10y_recovery_replay.gd')
    for folder in (CANDIDATE, REPORTS, *INITIAL):
        assert native.read(folder / 'source_before.json') == native.read(folder / 'source_after.json')
    godot = native.read(CANDIDATE / 'godot.json')
    assert godot['ok'] is True and len(godot['checks']) == 31 and all(v is True for v in godot['checks'].values())
    assert native.read(CANDIDATE / 'godot.execution.json')['exit_code'] == 0
    assert (CANDIDATE / 'godot.stderr.log').read_bytes() == b''
    python = native.read(CANDIDATE / 'python.json')
    assert python['ok'] is True and python['context_refusals'] == 18 and python['result_population_refusals'] == 1
    assert python['single_result']['paired_commissioning_satisfied'] is False
    declared = native.read(REPORTS / 'synthetic-declaration.json')
    development.validate_declaration(declared)
    counts = {}
    for branch, total, entry_count, partial, canonical in (('partial', 575, 240, 63, 0), ('prone', 286, 1, 0, 13)):
        assert native.read(REPORTS / (branch + '.execution.json'))['exit_code'] == 0
        assert (REPORTS / (branch + '.stderr.log')).read_bytes() == b''
        cold = retained_replay(REPORTS / branch)
        result = native.read(REPORTS / branch / 'result.json')
        for value in (cold, result):
            assert value['ok'] is True and value['complete_report_timeline_replayed'] is True
            assert value['initial_global_semantic_step'] == 0 and value['transition_count'] == total
            assert (value['entry_observation_count'], value['partial_observation_count'], value['canonical_observation_count']) == (entry_count, partial, canonical)
            assert value['physical_acceptance_authority'] is value['release_authority'] is False
            assert value['finite_recovery_task']['cycle_and_stop_boundary_reached'] is False
        assert result['finite_walking_measurement']['status'] == 'walking_not_reached'
        counts[branch] = dict(transitions=total, entry_samples=entry_count, partial_commands=partial, canonical_commands=canonical)
    refusal = retained_replay(REPORTS / 'partial-crossed-readiness', expected_exit=1)
    assert refusal['ok'] is False and refusal['failure_code'] == 'R10Y_ENTRY_REPLAY_READINESS_RECOMPUTATION'
    for folder, code in zip(WRAPPERS, (1, 1, 0, 0)):
        assert native.read(folder / 'execution.json')['exit_code'] == code
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
    assert 'Cannot infer the type of "crossed"' in (INITIAL[0] / 'godot.stderr.log').read_text(encoding='utf-8')
    checks = native.read(INITIAL[1] / 'godot.json')['checks']
    assert [k for k, v in checks.items() if v is not True] == ['publication_context_equal']
    return dict(ok=True, candidate_tests=2, godot_candidate_checks=31, python_context_refusals=18,
        python_result_population_refusals=1, complete_report_tests=2, complete_reports=counts,
        changed_readiness_refused=True, worker_source_key_files=1270,
        partial_and_prone_complete_reports_checked=True,
        full_upright_hold_and_walking_reports_checked=False, launcher_supervision_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for folder in (CANDIDATE, REPORTS, *INITIAL, *WRAPPERS) for p in sorted(folder.rglob('*')) if p.is_file()]
    # The full pre-test key already binds the actual producer, reader, fixtures,
    # profile and population code. This closure adds the independent consumer.
    native.write(RECORD, dict(schema_version='sporespore_r10y_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_candidate_and_complete_branch_reports', question_class='development'),
        facade_component=native.diagnosis.binding(facade.RECORD), source_key=native.diagnosis.binding(KEY),
        retained_source_key_revisions=[native.diagnosis.binding(ROOT / 'sdk/recovery' / f'r10y_v56_walking_entry_contract_v{i}.json') for i in (1, 2, 3)],
        auditor=native.diagnosis.binding(Path(__file__)), retained_evidence=[native.diagnosis.binding(p) for p in files],
        initial_refusals=['Synthetic Godot fixture lacked an explicit dictionary type.',
            'Synthetic comparison used the declaration integer validator in the reverse direction.'],
        observed=result))
    return result


def audit():
    value = native.read(RECORD)
    for row in [value['facade_component'], value['source_key'], value['auditor'], *value['retained_source_key_revisions'], *value['retained_evidence']]:
        native.verify(row)
    result = observations()
    assert result == value['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10Y_REPORT_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
