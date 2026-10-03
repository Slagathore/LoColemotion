"""Close the original incomplete R10BI execution without rerunning its identity."""
import argparse
import json
import re
import subprocess

import r10bi_rolling_contact_path as I

C = I.C
RUN = C.EVIDENCE/'r10bi-rolling-contact-e1db132bacca402b8b3de857a0b45930'
RECORD = C.ROOT/'sdk/recovery/r10bi_incomplete_execution_closure_v1.json'
FREEZE = '5e9345d99bb4aba680692f5df1747a0318efbe33'


def derive():
    declaration = C.read(I.STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert (RUN/'original_source.py').read_bytes() == I.C.ROOT.joinpath('sdk/conformance/r10bi_rolling_contact_path.py').read_bytes()
    assert (RUN/'original_declaration.json').read_bytes() == I.STUDY.read_bytes()
    for path in [I.STUDY, C.ROOT/'sdk/conformance/r10bi_rolling_contact_path.py']:
        committed = subprocess.check_output(['git', 'show', FREEZE+':'+path.relative_to(C.ROOT).as_posix()], cwd=C.ROOT)
        assert committed == path.read_bytes()
    execution = C.read(RUN/'execution.json'); assert execution['returncode'] == 1
    assert (RUN/'stdout.json').read_bytes() == b'' and not I.RESULT.exists()
    stderr = (RUN/'stderr.txt').read_text(encoding='utf-8')
    progress = [(int(step), float(gap)) for step, gap in re.findall(r'^R10BI step (\d+): gap ([0-9.]+)$', stderr, re.MULTILINE)]
    assert [row[0] for row in progress] == list(range(1, 94))
    assert 'result, second = S.statics.lp' in stderr
    assert "AssertionError: (2, 'The problem is infeasible. (HiGHS Status 8: model_status is Infeasible; primal_status is None)')" in stderr
    return dict(schema_version='sporespore_r10bi_incomplete_execution_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='retained_incomplete_model_execution_closure', question_class='development'),
        source_commit=FREEZE, declaration=C.bind(I.STUDY), implementation=C.bind(I.__file__), auditor=C.bind(__file__),
        execution=[C.bind(path) for path in sorted(RUN.iterdir()) if path.is_file()],
        status='incomplete_model_execution', failure='unhandled_secondary_velocity_lp_assertion',
        logged_admitted_step_count=len(progress), last_logged_gap_m=progress[-1][1],
        complete_result_published=False, complete_trajectory_retained=False,
        independently_replayed_model_steps=0, complete_result_adopted=False,
        claim_limit='Progress lines are retained observations of this failed process. They do not replace full per-node artifacts or an independently replayed path. Do not rerun or overwrite the R10BI identity.',
        successor_requirements=['Retain completed step records incrementally and exact failed LP/probe inputs.',
            'Use a distinct prospective numerical successor with unchanged physical/task thresholds and explicit solver changes.'],
        **declaration['claim_boundary'])


def audit():
    observed = C.read(RECORD); assert observed == derive()
    return dict(ok=True, status=observed['status'], logged_admitted_step_count=observed['logged_admitted_step_count'],
        complete_result_adopted=False, world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); args = parser.parse_args()
    if args.create:C.write_new(RECORD, derive())
    print(json.dumps(audit(), indent=2))
