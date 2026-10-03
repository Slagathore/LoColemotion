"""Audit retained complete R10AB upright, ready-hold and timeout-hold reports.

Source bytes are reconstructed from the original commit plus the retained
replacement blobs, so a later prospective key never re-qualifies this run. This
consumer performs no native call, safety qualification or launch authority.
"""
import argparse
import base64
import json
from pathlib import Path
import subprocess

import r10ab_report_component_v3 as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ab_hold_report_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10ab_v56_walking_entry_contract_v4.json'
REPORTS = EVIDENCE / 'r10ab-complete-hold-report-380f46d08135438dbae0895599fb01df'
WRAPPERS = [EVIDENCE / 'r10ab-complete-hold-walking-check-6ae943c490d34aa082a6a5e05293178a']
MARKER = 'R10AB_UPRIGHT_REPORT_FIXTURE '
BRANCHES = (('upright', 0, 0), ('ready', 30, 30), ('timeout', 240, 0))
PRELIMINARY = (('finite', 11), ('host', 5))
BASE_TRANSITIONS = 575


def retained_source_key(key, folder):
    """Reconstruct exactly the source bytes bound before the observed test.

    Git can normalize text line endings, so an unchanged tracked text file may
    match either its stored blob or that blob's CRLF checkout. Replacement
    bytes for a dirty path are decoded verbatim and are never normalized.
    """
    snapshot = native.read(folder / 'source_before.json')
    assert snapshot == native.read(folder / 'source_after.json')
    assert snapshot['remote'] == 'https://github.com/Slagathore/sporespore.git'
    rows = native.read(key)['bound_source_files']
    assert len({row['path'] for row in rows}) == len(rows)
    replacements = {row['path']: row for row in snapshot['changed_files']}
    tracked = []
    for row in rows:
        assert not Path(row['path']).is_absolute() and '..' not in Path(row['path']).parts
        if row['path'] in replacements:
            replacement = replacements[row['path']]
            assert replacement['deleted'] is False
            raw = base64.b64decode(replacement['replacement_base64'], validate=True)
            assert native.diagnosis.digest(raw) == replacement['raw_sha256']
            assert native.history.raw_matches(raw, row), row['path']
        else:
            tracked.append(row)
    request = ''.join(snapshot['head'] + ':' + row['path'] + '\n' for row in tracked).encode()
    process = subprocess.run(['git', 'cat-file', '--batch'], input=request, cwd=ROOT,
        capture_output=True, check=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
    assert not process.stderr
    raw, cursor = process.stdout, 0
    for row in tracked:
        end = raw.index(b'\n', cursor)
        header = raw[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob', row['path']
        length = int(header[2]); blob = raw[end + 1:end + 1 + length]; cursor = end + 2 + length
        assert native.history.raw_matches(blob, row) or (b'\r\n' not in blob and
            native.history.raw_matches(blob.replace(b'\n', b'\r\n'), row)), row['path']
    assert cursor == len(raw)
    return len(rows)


def retained_group(folder, name, tests):
    """Confirm one locked wrapper leg ran its whole group to a clean report."""
    assert native.read(folder / (name + '.execution.json'))['exit_code'] == 0
    log = (folder / (name + '.stderr.log')).read_text(encoding='utf-8')
    assert 'Ran ' + str(tests) + ' test' in log and log.rstrip().endswith('OK')
    return tests


def observations():
    assert prior.audit()['ok']
    inputs = retained_source_key(KEY, REPORTS)
    counts = {}
    for branch, commands, dwell in BRANCHES:
        directory = REPORTS / branch
        execution = native.read(directory / 'execution.json')
        assert execution['exit_code'] == 0
        assert execution['world_build_count'] == execution['solver_step_count'] == 0
        assert (directory / 'stderr.log').read_bytes() == b''
        lines = [line[len(MARKER):] for line
                 in (directory / 'stdout.log').read_text(encoding='utf-8').splitlines()
                 if line.startswith(MARKER)]
        assert len(lines) == 1 and json.loads(lines[0]) == dict(ok=True, failure={}, active_failure='')
        cold = prior.retained_replay(directory)
        measured = native.read(directory / 'replay.json')
        for result in (cold, measured):
            assert result['ok'] is True and result['complete_report_timeline_replayed'] is True
            assert result['initial_global_semantic_step'] == 0
            assert result['transition_count'] == BASE_TRANSITIONS + commands
            assert (result['entry_observation_count'], result['upright_observation_count'],
                    result['partial_observation_count']) == (240, 63, 0)
            hold = result['stance_entry_replay']
            assert hold['replayed_post_recovery_hold_commands'] == commands
            assert hold['recomputed_readiness_samples'] == commands + 1
            assert hold['post_recovery_ready_dwell'] == dwell
            assert result['finite_recovery_task']['cycle_and_stop_boundary_reached'] is False
            assert result['physical_acceptance_authority'] is result['release_authority'] is False
        assert measured['finite_walking_measurement']['status'] == 'walking_not_reached'
        counts[branch] = dict(transitions=BASE_TRANSITIONS + commands, hold_commands=commands,
            readiness_samples=commands + 1, consecutive_ready=dwell)
    preliminary = 0
    for folder in WRAPPERS:
        assert native.read(folder / 'execution.json')['exit_code'] == 0
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
        preliminary = sum(retained_group(folder, name, tests) for name, tests in PRELIMINARY)
        retained_group(folder, 'hold', len(BRANCHES))
    return dict(ok=True, preliminary_tests=preliminary, complete_report_tests=len(BRANCHES),
        complete_reports=counts, tested_source_key_inputs=inputs,
        full_upright_and_post_recovery_hold_reports_checked=True,
        kicked_walking_report_checked=False, launcher_supervision_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        current_checkout_qualified=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for folder in (REPORTS, *WRAPPERS) for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10ab_hold_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_complete_upright_and_hold_reports', question_class='development'),
        prior_report_component=native.diagnosis.binding(prior.RECORD),
        source_key=native.diagnosis.binding(KEY),
        retained_source_key_revisions=[native.diagnosis.binding(ROOT / 'sdk/recovery' /
            f'r10ab_v56_walking_entry_contract_v{i}.json') for i in (1, 2, 3, 4)],
        auditor=native.diagnosis.binding(Path(__file__)),
        retained_evidence=[native.diagnosis.binding(p) for p in files],
        evidence_scope='Supplied synthetic upright poses and fresh native hold sessions; no phase-248 physical branch or settling behavior is asserted.',
        observed=result))
    return result


def audit():
    value = native.read(RECORD)
    for row in [value['prior_report_component'], value['source_key'], value['auditor'],
                *value['retained_source_key_revisions'], *value['retained_evidence']]:
        native.verify(row)
    result = observations()
    assert result == value['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10AB_HOLD_REPORT_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
