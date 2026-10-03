"""Audit retained complete R10Z upright/hold reports without native execution.

Source keys are checked against their original commit plus retained replacement
bytes. This preserves historical checks when later prospective keys are added;
it does not qualify the current checkout or authorize a physical launch.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

import r10z_report_component as prior

native = prior.native
ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10z_hold_report_component_v1.json'
KEY = ROOT / 'sdk/recovery/r10z_v56_walking_entry_contract_v3.json'
REPORTS = EVIDENCE / 'r10z-complete-hold-report-0bf2f9e2e87c4ab09eabd6e9c7afd39a'
WRAPPERS = [EVIDENCE / 'r10z-hold-report-check-d53027162607483497933da75b304cec']


def raw_matches(raw, row):
    return len(raw) == row['byte_length'] and 'sha256:' + hashlib.sha256(raw).hexdigest() == row['raw_sha256']


def retained_source_key(key, folder):
    """Reconstruct exactly the source bytes bound before the observed test.

    Git can normalize text line endings. For unchanged tracked text, either the
    stored blob or its CRLF checkout must match the original raw digest exactly.
    Replacement bytes are decoded verbatim; no normalization is allowed there.
    """
    before = native.read(folder / 'source_before.json')
    assert before == native.read(folder / 'source_after.json')
    assert before['remote'] == 'https://github.com/Slagathore/sporespore.git'
    assert re.fullmatch(r'[0-9a-f]{40}', before['head'])
    rows = native.read(key)['bound_source_files']
    assert len({row['path'] for row in rows}) == len(rows)
    replacements = {row['path']: row for row in before['changed_files']}
    tracked = []
    for row in rows:
        assert not Path(row['path']).is_absolute() and '..' not in Path(row['path']).parts
        if row['path'] in replacements:
            replacement = replacements[row['path']]
            assert replacement['deleted'] is False
            raw = base64.b64decode(replacement['replacement_base64'], validate=True)
            assert 'sha256:' + hashlib.sha256(raw).hexdigest() == replacement['raw_sha256']
            assert raw_matches(raw, row), row['path']
        else:
            tracked.append(row)
    requests = ''.join(before['head'] + ':' + row['path'] + '\n' for row in tracked).encode()
    completed = subprocess.run(['git', 'cat-file', '--batch'], input=requests, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, cwd=ROOT, timeout=60, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
    assert completed.stderr == b''
    output, cursor = completed.stdout, 0
    for row in tracked:
        end = output.index(b'\n', cursor)
        header = output[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob', row['path']
        size = int(header[2])
        raw = output[end + 1:end + 1 + size]
        cursor = end + 2 + size
        assert output[cursor - 1:cursor] == b'\n'
        if not raw_matches(raw, row):
            raw.decode('utf-8')  # Only text may have a Git checkout conversion.
            raw = raw.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
        assert raw_matches(raw, row), row['path']
    assert cursor == len(output)
    return len(rows)


def observations():
    assert prior.audit()['ok']
    assert retained_source_key(KEY, REPORTS) == 1403
    counts = {}
    for branch, commands, dwell in (('upright', 0, 0), ('ready', 30, 30), ('timeout', 240, 0)):
        directory = REPORTS / branch
        execution = native.read(directory / 'execution.json')
        assert execution['exit_code'] == 0
        assert execution['world_build_count'] == execution['solver_step_count'] == 0
        assert (directory / 'stderr.log').read_bytes() == b''
        marker = 'R10Z_UPRIGHT_REPORT_FIXTURE '
        lines = [line[len(marker):] for line in (directory / 'stdout.log').read_text(encoding='utf-8').splitlines()
                 if line.startswith(marker)]
        assert len(lines) == 1 and json.loads(lines[0]) == dict(ok=True, failure={}, active_failure='')
        cold = prior.retained_replay(directory)
        measured = native.read(directory / 'replay.json')
        for result in (cold, measured):
            assert result['ok'] is True and result['complete_report_timeline_replayed'] is True
            assert result['initial_global_semantic_step'] == 0 and result['transition_count'] == 575 + commands
            assert (result['entry_observation_count'], result['upright_observation_count'],
                    result['partial_observation_count']) == (240, 63, 0)
            hold = result['stance_entry_replay']
            assert hold['replayed_post_recovery_hold_commands'] == commands
            assert hold['recomputed_readiness_samples'] == commands + 1
            assert hold['post_recovery_ready_dwell'] == dwell
            assert result['finite_recovery_task']['cycle_and_stop_boundary_reached'] is False
            assert result['physical_acceptance_authority'] is result['release_authority'] is False
        assert measured['finite_walking_measurement']['status'] == 'walking_not_reached'
        counts[branch] = dict(transitions=575 + commands, hold_commands=commands,
            readiness_samples=commands + 1, consecutive_ready=dwell)
    wrapper = WRAPPERS[0]
    assert native.read(wrapper / 'execution.json')['exit_code'] == 0
    lock = native.read(wrapper / 'lock.json')
    assert lock['acquired'] is True and lock['test_only'] is False
    final_log = (wrapper / 'stderr.log').read_text(encoding='utf-8')
    assert 'Ran 3 tests' in final_log and final_log.rstrip().endswith('OK')
    return dict(ok=True, complete_report_tests=3, complete_reports=counts,
        historical_partial_prone_source_key_inputs=1392, tested_source_key_inputs=1403,
        full_upright_and_post_recovery_hold_reports_checked=True,
        preparation_and_walking_reports_checked=False, launcher_supervision_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        current_checkout_qualified=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for folder in (REPORTS, *WRAPPERS) for p in sorted(folder.rglob('*')) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10z_hold_report_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_complete_upright_hold_reports', question_class='development'),
        prior_report_component=native.diagnosis.binding(prior.RECORD),
        source_key=native.diagnosis.binding(KEY),
        retained_source_key_revisions=[native.diagnosis.binding(ROOT / 'sdk/recovery' /
            f'r10z_v56_walking_entry_contract_v{i}.json') for i in (2, 3)],
        auditor=native.diagnosis.binding(Path(__file__)),
        retained_evidence=[native.diagnosis.binding(p) for p in files],
        evidence_scope='Supplied synthetic upright poses and fresh native hold sessions; no phase-248 physical branch or behavior is asserted.',
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
    print('R10Z_HOLD_REPORT_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
