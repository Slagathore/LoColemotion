"""Retained-evidence audit of R10AB candidate admission and two full reports.

This independent output consumer is bound separately from the pre-test worker
source key. It performs no native calls, safety qualification or physics.
"""
import argparse
import base64
import subprocess
import json
from pathlib import Path

import r10ab_facade_component as facade
import development_recovery_candidate as candidate
import r10ab_development as development

native = facade.native
ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ab_report_component_v1.json'
CANDIDATE = EVIDENCE / 'r10ab-candidate-6c9b39edc9744c21a9b9ebaa4c3f52a3'
REPORTS = EVIDENCE / 'r10ab-complete-report-35623b401fe94c1ca7bb6d3aa4900d0b'
WRAPPERS = [EVIDENCE/'r10ab-report-check-e0b9a5aa17a14d4e8614d05645dd946d']
KEY = ROOT / 'sdk/recovery/r10ab_v56_walking_entry_contract_v1.json'
PROFILE = ROOT / 'sdk/development/recovery_candidates/r10ab-partial-downward-rise-integrated-v1.json'
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


def frozen_key_sources(folder):
    """Verify the bytes actually tested, including dirty replacements, from Git.

    Later distinct source keys do not retroactively qualify this historical run.
    No current checkout bytes or selector pointer substitute for its snapshot.
    """
    snapshot = native.read(folder / 'source_before.json')
    assert snapshot == native.read(folder / 'source_after.json')
    assert snapshot['remote'] == 'https://github.com/Slagathore/sporespore.git'
    replacements = {r['path']: r for r in snapshot['changed_files']}
    tracked = []
    for row in native.read(KEY)['bound_source_files']:
        assert not Path(row['path']).is_absolute() and '..' not in Path(row['path']).parts
        if row['path'] in replacements:
            replacement = replacements[row['path']]
            assert not replacement['deleted']
            raw = base64.b64decode(replacement['replacement_base64'], validate=True)
            assert native.diagnosis.digest(raw) == replacement['raw_sha256']
            assert native.history.raw_matches(raw, row), row['path']
        else:
            tracked.append(row)
    request = ''.join(snapshot['head'] + ':' + r['path'] + '\n' for r in tracked).encode()
    process = subprocess.run(['git', 'cat-file', '--batch'], input=request, cwd=ROOT,
        capture_output=True, check=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
    assert not process.stderr
    raw, cursor = process.stdout, 0
    for row in tracked:
        end = raw.index(b'\n', cursor)
        header = raw[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob'
        length = int(header[2]); blob = raw[end+1:end+1+length]; cursor = end+2+length
        assert native.history.raw_matches(blob, row) or (b'\r\n' not in blob and
            native.history.raw_matches(blob.replace(b'\n', b'\r\n'), row)), row['path']
    assert cursor == len(raw)


def observations():
    assert facade.audit()['ok']
    for folder in (CANDIDATE, REPORTS):
        frozen_key_sources(folder)
    selected = native.read(CANDIDATE / 'input.json')['selection']
    assert selected['diagnostic_schedule']['walking_policy_id'] == development.ROUTE
    assert selected['worker_selection']['worker'].endswith('/r10ab_development_worker_v1.gd')
    assert selected['reader'].endswith('/r10ab_recovery_replay.gd')
    godot = native.read(CANDIDATE / 'godot.json')
    assert godot['ok'] is True and len(godot['checks']) == 31 and all(v is True for v in godot['checks'].values())
    assert native.read(CANDIDATE / 'godot.execution.json')['exit_code'] == 0
    assert (CANDIDATE / 'godot.stderr.log').read_bytes() == b''
    python = native.read(CANDIDATE / 'python.json')
    assert python['ok'] is True and python['context_refusals'] == 18 and python['result_population_refusals'] == 1
    assert python['single_result']['paired_commissioning_satisfied'] is False
    declared = native.read(REPORTS / 'synthetic-declaration.json')
    development.validate_context(declared['r10ab_development'], declared)
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
    assert refusal['ok'] is False and refusal['failure_code'] == 'R10AB_ENTRY_REPLAY_READINESS_RECOMPUTATION'
    for folder in WRAPPERS:
        assert native.read(folder / 'execution.json')['exit_code'] == 0
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
    return dict(ok=True, candidate_tests=2, godot_candidate_checks=31, python_context_refusals=18,
        python_result_population_refusals=1, complete_report_tests=2, complete_reports=counts,
        changed_readiness_refused=True, worker_source_key_files=1500,
        partial_and_prone_complete_reports_checked=True,
        full_upright_hold_and_walking_reports_checked=False, launcher_supervision_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for folder in (CANDIDATE, REPORTS, *WRAPPERS) for p in sorted(folder.rglob('*')) if p.is_file()]
    # The full pre-test key already binds the actual producer, reader, fixtures,
    # profile and population code. This closure adds the independent consumer.
    native.write(RECORD, dict(schema_version='sporespore_r10ab_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_candidate_and_complete_branch_reports', question_class='development'),
        facade_component=native.diagnosis.binding(facade.RECORD), source_key=native.diagnosis.binding(KEY),
        retained_source_key_revisions=[native.diagnosis.binding(ROOT / 'sdk/recovery' / f'r10ab_v56_walking_entry_contract_v{i}.json') for i in (1,)],
        auditor=native.diagnosis.binding(Path(__file__)), retained_evidence=[native.diagnosis.binding(p) for p in files],
        evidence_scope='Retained zero-world runs against their exact source snapshots; not current complete safety qualification or launch authority.',
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
    print('R10AB_REPORT_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
