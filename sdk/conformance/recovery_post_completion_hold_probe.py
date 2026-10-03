"""Retain and audit a zero-world V50 interface study; never launch a physical worker."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path[:0] = [str(ROOT/'tests'), str(ROOT/'sdk/python')]
from r10s_launch_component import bind, read, verify
import test_development_passive_entry_replay as shared
from development_recovery_candidate_test_support import selected, arguments

STUDY = ROOT/'sdk/recovery/r10t_post_recovery_hold_interface_study_v1.json'
SCRIPT = ROOT/'sdk/trace_analysis/recovery_post_completion_hold_probe_v1.gd'
SOURCE = ROOT/'sdk/recovery/r10s_v56_walking_entry_contract_v8.json'
PROFILE = 'sdk/development/recovery_candidates/r10s-v56-extended-preparation-integrated-v1.json'
ROLE = 'kick_passive_recovery_resume'
CLAIMS = dict(world_build_count=0, solver_step_count=0, counterfactual_frozen_measurements=True,
    predicted_settling=False, complete_route_proven=False, held_out_population_declared=False,
    physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def write(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def validate_identity():
    assert Path(git('rev-parse', '--show-toplevel')).resolve() == ROOT
    assert git('remote', 'get-url', 'origin') == 'https://github.com/Slagathore/sporespore.git'


def retained_report(closure_reference, role):
    verify(closure_reference)
    closure = read(closure_reference['path'])
    verify(closure['evidence_manifest'])
    refs = [r for r in read(closure['evidence_manifest']['path'])['files']
            if r['path'].endswith('/children/'+role+'/worker_report.json')]
    assert len(refs) == 1
    verify(refs[0])
    return read(refs[0]['path']), refs[0]


def extract(study):
    cases, references = [], []
    for case in study['terminal_population']:
        report, reference = retained_report(case['closure'], ROLE)
        rows = [r for r in report['stance_entry']['readiness_rows'] if r['purpose'] == 'post_recovery_entry']
        assert len(rows) == 1
        row = rows[0]
        assert row['source']['readiness']['ready'] is case['original_ready']
        native = row['source']['packet']['native_source']
        cases.append(dict(case_id=case['case_id'], global_semantic_step=row['global_semantic_step'],
            source=row['source'], model_instance_id=native['model_instance_id'],
            body_population_instance_sha256=native['body_population_instance_sha256']))
        references.append(reference)
    baseline, reference = retained_report(study['hold_template_closure'], 'matched_no_kick_continuation')
    hold = baseline['stance_entry']['hold_control_rows'][0]
    command = hold['step']['sample_receipt']['request']['command']
    assert command['gait_amplitude'] == 0 and command['desired_planar_velocity_task_m_s'] == dict(x=0, y=0, z=0)
    references.append(reference)
    return dict(schema_version='sporespore_post_completion_hold_probe_input_v1',
        commands_per_terminal=240, command_template=command, cases=cases), references


def archive_sources(out):
    paths = [ROOT/r['path'] for r in read(SOURCE)['bound_source_files']]
    for r in read(SOURCE)['bound_source_files']:
        assert bind(ROOT/r['path'])['raw_sha256'] == r['raw_sha256'], r['path']
    paths = sorted(set(paths + [STUDY, SCRIPT, Path(__file__), SOURCE,
        ROOT/'tests/test_post_completion_hold_refusal_decoding.gd']))
    refs = []
    for path in paths:
        destination = out/'source'/path.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open('xb') as stream:
            stream.write(path.read_bytes())
        assert bind(destination)['raw_sha256'] == bind(path)['raw_sha256']
        refs.append(dict(original=bind(path), archived=bind(destination)))
    write(out/'source_archive.json', refs)
    return refs


def run():
    validate_identity()
    study = read(STUDY)
    assert study['claim_boundary'] == CLAIMS
    os.environ['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = PROFILE
    selection = selected()
    inputs, reports = extract(study)
    out = EVIDENCE/('post-completion-hold-interface-'+uuid.uuid4().hex)
    out.mkdir()
    print('POST_COMPLETION_HOLD_ROOT', out, flush=True)
    sources = archive_sources(out)
    write(out/'retained_interface_inputs.json', inputs)
    write(out/'declaration.json', dict(ledger_scope=study['ledger_scope'], study=bind(STUDY), probe=bind(SCRIPT), runner=bind(__file__),
        report_bindings=reports, source_archive=bind(out/'source_archive.json'),
        source_commit=git('rev-parse', 'HEAD'), claim_boundary=CLAIMS))
    class Run:
        root = out
    result = shared.PassiveEntryReplay._run_retained.__func__(Run,
        'res://sdk/trace_analysis/recovery_post_completion_hold_probe_v1.gd',
        ['--', str(out/'retained_interface_inputs.json'), *arguments(selection)], 'probe', 180)
    unchanged = all(bind(r['original']['path']) == r['original'] for r in sources)
    write(out/'source_unchanged.json', dict(unchanged=unchanged))
    lines = [shared.parse_json(line.split(' ', 1)[1]) for line in result.stdout.decode().splitlines()
             if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
    if len(lines) == 1:
        write(out/'result.json', lines[0])
    write(out/'retention_manifest.json', dict(files=[bind(p) for p in sorted(out.rglob('*')) if p.is_file()]))
    assert unchanged
    assert result.returncode == 0 and len(lines) == 1 and b'ERROR:' not in result.stdout+result.stderr, (
        result.returncode, result.stdout[-3000:], result.stderr[-3000:])
    return audit(out)


def audit(out):
    validate_identity()
    for item in read(out/'retention_manifest.json')['files']:
        verify(item)
    declaration = read(out/'declaration.json')
    assert declaration['claim_boundary'] == CLAIMS
    for reference in declaration['report_bindings']:
        verify(reference)
    archived = read(out/'source_archive.json')
    for row in archived:
        verify(row['archived'])
        assert row['original']['raw_sha256'] == row['archived']['raw_sha256']
    assert read(out/'source_unchanged.json') == dict(unchanged=True)
    execution = read(out/'probe.execution.json')
    assert execution['returncode'] == 0 and not execution['timed_out'] and execution['source_unchanged']
    result = read(out/'result.json')
    assert result['ok'] and result['input_unmodified']
    for key, value in CLAIMS.items():
        if key != 'sdk1_score':
            assert result[key] == value
    assert result['input_raw_sha256'] == bind(out/'retained_interface_inputs.json')['raw_sha256']
    assert result['native_calls_sha256'] == bind(out/'native_calls.jsonl')['raw_sha256']
    assert len(result['cases']) == 4 and sum(c['native_commands'] for c in result['cases']) == 960
    summaries = {c['case_id']: c for c in result['cases']}
    # Read retained native bytes independently; reproduce counts and target metrics.
    metrics = {key: dict(count=0, negatives=0, maximum_error=0., maximum_change=0., previous=None) for key in summaries}
    with (out/'native_calls.jsonl').open(encoding='utf-8') as stream:
        for line in stream:
            row = json.loads(line)
            m = metrics[row['case_id']]
            if 'negative' in row:
                response = json.loads(row['raw_response'])
                if row['negative'] == 'crossed_body_clock':
                    assert response['ok'] is True
                    assert response['value']['actuation']['safe_no_actuation'] is True
                    assert response['value']['actuation']['failure_codes'] == ['FRAME_INVALID']
                    assert response['value']['next_memory'] == row['request']['memory']
                else:
                    assert response['ok'] is False
                m['negatives'] += 1
                continue
            request, native = row['session_request'], row['session_result']
            raw = row['stateless_raw_response']
            assert native['ok'] and native['value']['actuation']['safe_no_actuation'] is False
            # Preserve the established V50 host parser as well as exact native bytes.
            assert native['value'] == row['stateless_host_value']
            assert 'sha256:'+hashlib.sha256(raw.encode()).hexdigest() == native['native_step_transport_verification']['raw_native_response_sha256']
            assert row['command'] == m['count']+1 == request['state']['semantic_step']
            assert request['command']['gait_amplitude'] == 0
            assert request['command']['desired_planar_velocity_task_m_s'] == dict(x=0, y=0, z=0)
            targets = [c['clamped_target_position_rad'] for c in native['value']['actuation']['ordered_commands']]
            error = max(abs(t-j['position_rad']) for t, j in zip(targets, request['state']['ordered_joint_observations'], strict=True))
            if m['previous'] is None: m['first_error'] = error
            else: m['maximum_change'] = max(m['maximum_change'], max(abs(t-p) for t, p in zip(targets, m['previous'], strict=True)))
            m.update(count=m['count']+1, previous=targets, last_error=error, maximum_error=max(m['maximum_error'], error))
    for key, m in metrics.items():
        case = summaries[key]
        assert case['ok'] and all(case['checks'].values()) and m['count'] == 240 and m['negatives'] == 3
        for recorded, calculated in [('first_target_error_rad','first_error'), ('last_target_error_rad','last_error'),
                ('maximum_target_error_rad','maximum_error'), ('maximum_between_command_target_change_rad','maximum_change')]:
            assert math.isclose(case[recorded], m[calculated], rel_tol=0, abs_tol=1e-12)
    return dict(ok=True, evidence_root=out.as_posix(), cases=result['cases'], native_commands=960,
                stateless_byte_comparisons=960, negative_native_calls=12, **CLAIMS)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--run', action='store_true')
    group.add_argument('--audit', type=Path)
    args = parser.parse_args()
    print('POST_COMPLETION_HOLD_INTERFACE '+json.dumps(run() if args.run else audit(args.audit)))
