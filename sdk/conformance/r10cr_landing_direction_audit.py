"""Post-exposure full replay of R10CR's saved numerical result.

The original CLI remains failed: its path-only presenter required a journal.
This independent audit does not rerun or regrade that invocation.
"""
import argparse
import json
from pathlib import Path
import r10cr_landing_direction as R

C=R.C
ORIGINAL=C.EVIDENCE/'r10cr-landing-direction-original-92513ac6a78f4e6ea8117f81bb936250'
AUDIT=C.ROOT/'sdk/recovery/r10cr_landing_direction_publication_audit_v1.json'


def audit():
    execution=C.read(ORIGINAL/'execution.json')
    assert execution['return_code']==1
    assert (ORIGINAL/'stderr.txt').read_text().rstrip().endswith("KeyError: 'journal'")
    assert (ORIGINAL/'original_source.py').read_bytes()==Path(R.__file__).read_bytes()
    assert (ORIGINAL/'original_declaration.json').read_bytes()==R.STUDY.read_bytes()
    result=C.read(R.RESULT)
    assert result['implementation']==C.bind(R.__file__) and result['declaration']==C.bind(R.STUDY)
    assert result==R.derive()
    return dict(schema_version='sporespore_r10cr_landing_direction_publication_audit_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='post_exposure_numerical_result_replay_without_original_cli_regrade',question_class='development'),
        implementation=C.bind(__file__),original_implementation=C.bind(R.__file__),declaration=C.bind(R.STUDY),result=C.bind(R.RESULT),
        original_execution=[C.bind(p) for p in sorted(ORIGINAL.iterdir()) if p.is_file()],
        original_cli_success=False,original_failure='path_only_presenter_required_absent_journal_after_complete_result_write',
        original_invocation_regraded=False,full_replay_passed=True,controls=result['controls'],summary=result['summary'],
        world_build_count=0,solver_step_count=0,controller_selected=False,physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');args=parser.parse_args()
    value=audit()
    if args.create:C.write_new(AUDIT,value)
    else:assert C.read(AUDIT)==value
    print(json.dumps(dict(ok=True,full_replay_passed=True,original_cli_success=False,summary=value['summary'],audit=C.bind(AUDIT)),indent=2))
