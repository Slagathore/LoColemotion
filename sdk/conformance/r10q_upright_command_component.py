"""Audit the frozen command study and replay its actual original DLL calls."""
import argparse
import json
from pathlib import Path
import subprocess

from r10q_upright_command_diagnosis import ROOT, EVIDENCE, bind, read, write, LocomotionCore

STUDY = EVIDENCE / 'r10q-upright-command-diagnosis-385877a3a85645a98c3516fd695dca43'
RECORD = ROOT / 'sdk/recovery/r10q_upright_command_component_v1.json'
SOURCE = '9dcbd855abe9b0e862bf8ddb5cb74657450a7649'


def verify(binding):
    assert bind(binding['path']) == binding, binding['path']


def audit(cold):
    declaration, result = read(STUDY / 'declaration.json'), read(STUDY / 'result.json')
    assert result['ok'] is True and result['native_calls'] == 2322
    assert declaration['physical_world_count'] == declaration['solver_step_count'] == 0
    for item in [declaration['runtime'], declaration['dll'], declaration['fixture'],
                 *declaration['predecessor_closures'], *[p['report'] for p in declaration['population']],
                 result['native_calls_binding']]:
        verify(item)
    assert declaration['sources'] == result['source_after']
    archive = read(STUDY / 'source_archive.json')
    for source, retained in zip(declaration['sources'], archive, strict=True):
        verify(retained)
        assert source['raw_sha256'] == retained['raw_sha256']
    runtime = read(declaration['runtime']['path'])
    compiled_archive = read(STUDY / 'compiled_source_archive.json')
    for item, archived in zip(runtime['source_files'], compiled_archive, strict=True):
        assert item['path'] == archived['original_path']
        verify(archived['retained'])
        assert item['raw_sha256'] == archived['retained']['raw_sha256']
    core = LocomotionCore(declaration['dll']['path']) if cold else None
    fixed, ideal = 0, 0
    labels = set()
    with Path(result['native_calls_binding']['path']).open(encoding='utf-8') as stream:
        for line in stream:
            row = json.loads(line)
            label, request, response = row['label'], row['request'], row['response']
            key = json.dumps(label, sort_keys=True)
            assert key not in labels
            labels.add(key)
            assert response['controller_id'] == request['controller_id'] == label['controller']
            assert response['world_build_count'] == response['solver_step_count'] == 0
            if label['mode'] == 'fixed_input': fixed += 1
            else:
                assert label['mode'] == 'ideal_joint_tracking'
                ideal += 1
            if core is not None:
                assert core.recovery_plan_control_v1(request) == response
    assert (fixed, ideal) == (162, 2160)
    return dict(ok=True, fixed_input_calls=fixed, ideal_tracking_calls=ideal,
        native_responses_cold_replayed=2322 if cold else 0,
        controller_cases=[{k: v for k,v in case.items() if k != 'fixed_input'} for case in result['cases']],
        physical_world_count=0, solver_step_count=0, physical_response_predicted=False,
        physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    parser.add_argument('--cold', action='store_true')
    args = parser.parse_args()
    observed = audit(args.cold or args.create)
    if args.create:
        write(RECORD, dict(schema_version='sporespore_r10q_upright_command_component_v1',
            ledger_scope=dict(subsystem='recovery', engine_scope='3e_native_command_inputs_only',
                authority_mode='post_exposure_command_diagnosis', question_class='development'),
            source_commit=SOURCE, evidence_root=STUDY.as_posix(), observed=observed,
            retained_evidence=[bind(p) for p in sorted(STUDY.rglob('*')) if p.is_file()],
            auditor=bind(Path(__file__))))
    else:
        record = read(RECORD)
        for binding in record['retained_evidence'] + [record['auditor']]: verify(binding)
        expected = dict(record['observed'])
        if not args.cold: expected['native_responses_cold_replayed'] = 0
        assert observed == expected
    print('R10Q_UPRIGHT_COMMAND_COMPONENT ' + json.dumps(observed))


if __name__ == '__main__': main()
