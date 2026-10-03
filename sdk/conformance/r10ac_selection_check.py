"""Prospective candidate selection and pure prefix/report interfaces, no world."""
import argparse
import copy
import json
from pathlib import Path

import development_recovery_candidate as candidate
import r10ac_development_v2 as identity
import r10ac_development_identity_check as original_identity
import r10ac_contact_report_check as report_fixture
import r10ac_contact_frame_report as report_reader
import r10ac_selection as admission


def fixture():
    reference=identity.reference()
    selected=candidate.selection(reference)
    declaration=original_identity.fixture()['cases'][0]['declaration']
    declaration['candidate_profile']=reference
    declaration['r10ac_development']=identity.context(identity.SINGLE,declaration['source_snapshot']['head'],reference)
    identity.validate_declaration(declaration)
    report=report_fixture.make_report(declaration,[0,1,2,3])
    expected=report_reader.replay_report(report,declaration,identity)
    # The complete schedule has only admission aliases and declaration metadata
    # changed. Native laws, task hash, capture profile and all step limits match.
    design=json.loads(identity.DESIGN.read_text())
    assert identity.sha(identity.DESIGN)==identity.DESIGN_SHA
    old=json.loads((identity.ROOT/'sdk/development/recovery_schedules/r10ac-contact-frame-diagnostic-v1.json').read_text())['schedules']['r10ac-contact-frame-diagnostic-v1']
    new=selected['diagnostic_schedule']
    assert {k for k in new if new[k]!=old[k]}=={'walking_entry_profile_id','walking_start_profile_id','coverage_basis','coverage_argument'}
    assert {k for k in new['coverage_basis'] if new['coverage_basis'][k]!=old['coverage_basis'][k]}=={'successor_design','successor_design_sha256'}
    assert new['coverage_basis']['successor_design_sha256']==identity.DESIGN_SHA
    assert selected['worker_selection']['worker']==design['integration_selection']['capture_worker']
    assert selected['reader']==design['integration_selection']['reader']
    assert selected['diagnostic_reader_requires_declaration'] is True
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
        source_key=dict(path=candidate.R10AC_ROUTE_ENTRY_PATH.relative_to(identity.ROOT).as_posix(),
            raw_sha256=identity.sha(candidate.R10AC_ROUTE_ENTRY_PATH)),
        scope='Candidate admission and synthetic interfaces only; worker authorization remains refused and combined positive controller replay remains pending.')


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
