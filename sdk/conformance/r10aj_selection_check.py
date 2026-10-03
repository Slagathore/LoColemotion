"""Prospective candidate selection and pure prefix/report interfaces, no world."""
import argparse
import copy
import json
from pathlib import Path

import development_recovery_candidate as candidate
import r10aj_development as identity
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tests"))
import r10aj_preflight_fixture as new_identity
import r10af_contact_frame_report as report_reader
import r10aj_selection as admission


def fixture():
    reference=identity.reference()
    selected=candidate.selection(reference)
    declaration=new_identity.fixture('a'*40)
    declaration['candidate_profile']=reference
    declaration['r10aj_development']=identity.context(identity.SINGLE,declaration['source_snapshot']['head'],reference)
    identity.validate_declaration(declaration)
    # Reuse only this pinned two-step zero-world fixture, never a physical report.
    template=identity.EVIDENCE/'development-recovery-smoke-595c8e3a5bd742b5ba626f9ddf485f1d/children/kick_passive_recovery_resume/frame-fixtures.json'
    assert identity.sha(template)=="sha256:4b8d90190887a469039e47daf3beb5c24e723193ea9dc1c58f9e37587eff95b1"
    fixture_value=json.loads(template.read_text(encoding='utf-8'))
    assert fixture_value['world_build_count']==fixture_value['solver_step_count']==0
    report=copy.deepcopy(fixture_value['report'])
    assert report['synthetic_fixture'] is True and report['solver_step_count']==2
    report.update(r10aj_development=copy.deepcopy(declaration[identity.CONTEXT_KEY]),
        source_commit=declaration['source_snapshot']['head'],parent_attempt_id=declaration['attempt_id'],
        child_attempt_id=declaration['children'][0]['child_attempt_id'])
    identity.validate_report_header(report,declaration)
    expected=report_reader.replay_report(report,declaration,identity)
    new=selected['diagnostic_schedule']
    admission.native_schedule(new)
    negative_schedules=[]
    for key in ('walking_entry_profile_id','walking_start_profile_id','walking_policy_id','walking_policy_contract_sha256',
                'runtime_sha256','diagnostic_capture_profile_id','coverage_argument'):
        mutated=copy.deepcopy(new);mutated[key]='crossed'
        negative_schedules.append(dict(name=key,schedule=mutated))
    for key in ('after_interaction_steps','maximum_steps_per_child'):
        mutated=copy.deepcopy(new);mutated['limits'][key]+=1
        negative_schedules.append(dict(name=key,schedule=mutated))
    for row in negative_schedules:
        try:admission.native_schedule(row['schedule'])
        except ValueError:pass
        else:raise AssertionError('Crossed schedule admitted')
    old_profile=identity.ROOT/'sdk/development/recovery_candidates/r10ab-partial-downward-rise-integrated-v2.json'
    try:candidate.selection(candidate.reference_for_path(old_profile))
    except ValueError as error: historical_refusal=str(error)
    else:raise AssertionError('Consumed source key was admitted')
    return dict(reference=reference,selection=selected,declaration=declaration,report=report,
        diagnostic_expected=expected,negative_schedules=negative_schedules,
        historical_reference=candidate.reference_for_path(old_profile),historical_refusal=historical_refusal,
        prefix_selection=identity.prefix_selection(identity.SEED,identity.PREFIX_PROFILE),
        source_key=dict(path=candidate.R10AJ_ROUTE_ENTRY_PATH.relative_to(identity.ROOT).as_posix(),
            raw_sha256=identity.sha(candidate.R10AJ_ROUTE_ENTRY_PATH)),
        scope='Candidate admission and synthetic interfaces only; worker authorization remains refused and full launch safety qualification remains pending.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare',type=Path);parser.add_argument('--verify',type=Path)
    args=parser.parse_args()
    if args.prepare:
        value=fixture()
        with args.prepare.open('x',encoding='utf-8',newline='\n') as stream:
            json.dump(value,stream,indent=2);stream.write('\n')
        print(json.dumps(dict(ok=True,negative_schedules=len(value['negative_schedules']),historical_refusal=value['historical_refusal'])))
    elif args.verify:
        value=json.loads(args.verify.read_text(encoding='utf-8-sig'))
        fixed=json.loads((args.verify.parent/'fixture.json').read_text())
        assert value['ok'] is True and all(value['checks'].values())
        assert value['selection']==fixed['selection']
        assert value['diagnostic_replay']==fixed['diagnostic_expected']
        assert value['prefix_selection']==fixed['prefix_selection']
        identity.validate_report_header(value['published_report'],fixed['declaration'])
        assert report_reader.replay_report(value['published_report'],fixed['declaration'],identity)==fixed['diagnostic_expected']
        print(json.dumps(dict(ok=True,native_checks=len(value['checks']),python_godot_selection_equal=True,
            fresh_prefix_phase=248,consumed_r10ab_key_refused=True,diagnostic_report_replayed=True,
            combined_incomplete_controller_report_refused=True,combined_positive_controller_replay_proven=False,
            world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)))
    else:parser.error('--prepare or --verify required')
