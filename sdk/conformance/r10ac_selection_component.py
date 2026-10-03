"""Audit distinct R10AC admission, real prefix dispatch and reader composition."""
import argparse
import json
from pathlib import Path

import r10ac_selection_check as check
import r10ac_development_v2 as identity
import r10ac_contact_frame_report as diagnostic
from r10ac_support_loss_diagnosis import binding, write

RECORD=identity.ROOT/'sdk/recovery/r10ac_selection_component_v1.json'
CHECK=identity.EVIDENCE/'r10ac-selection-check-6ae8230787e149b4ae276f5c4714f5d4'
EARLIER=[identity.EVIDENCE/p for p in ('r10ac-selection-check-47fa976f634f48f68d4e42e34cd5295f',
    'r10ac-selection-check-cf7ba997e7714905a5434f303979a8d7',
    'r10ac-selection-check-76a01d7a24c544e3bf24d73900f1a8f5')]
REGRESSION=identity.EVIDENCE/'r10ac-report-regression-e1ede0fb4aba4b9dbe52d067a047e2dd'
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
ARCHIVED={
    'sdk/conformance/r10ac_source_key.py':'key-source.py',
    'sdk/check_r10ac_selection.ps1':'wrapper-source.ps1',
    'sdk/conformance/development_recovery_candidate.py':'candidate-source.py',
    'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd':'startup-source.gd',
    'sdk/adapters/godot/gdscript/r10ac_development_seed_v2.gd':'seed-source.gd',
    'sdk/conformance/r10ac_selection_check.py':'check-source.py',
    'tests/test_r10ac_selection.gd':'test-source.gd'}


def checked_sources(folder):
    before=read(folder/'source-before.json')
    assert before==read(folder/'source-after.json')
    for row in before:
        source=(folder/ARCHIVED[row['path']] if folder in EARLIER and row['path'] in ARCHIVED
            else identity.ROOT/row['path'])
        bound=binding(source)
        assert bound['raw_sha256']=='sha256:'+row['sha256'].lower() and bound['byte_length']==row['bytes'],row['path']
    return before


def observations():
    for folder in (CHECK,*EARLIER,REGRESSION):
        checked_sources(folder)
        assert read(folder/'result.json')['ok'] is True
        names=['prepare','worker-parse','report','verify']
        if folder!=REGRESSION:names.append('reader-parse')
        for name in names:
            execution=read(folder/(name+'.execution.json'))
            assert execution['exit_code']==0 and (folder/(name+'.stderr.log')).read_bytes()==b''
            if name in ('worker-parse','reader-parse','report'):
                assert execution['timed_out'] is False and execution['stderr_bytes']==0
        assert read(folder/'lock.json')['acquired'] is True
        engine=read(folder/'engine.json')
        assert binding(engine['path'])['raw_sha256']==engine['raw_sha256']
    before=checked_sources(CHECK)
    assert len(before)==1726
    key=read(identity.ROOT/'sdk/recovery/r10ac_v56_walking_entry_contract_v4.json')
    assert len(key['bound_source_files'])==1725
    assert {row['path'] for row in key['bound_source_files']} < {row['path'] for row in before}
    fixture,native=read(CHECK/'fixture.json'),read(CHECK/'native.json')
    assert native['ok'] is True and len(native['checks'])==30 and all(native['checks'].values())
    assert native['selection']==fixture['selection']
    assert check.candidate.selection(identity.reference())==fixture['selection']
    assert native['prefix_selection']==identity.prefix_selection(61248,identity.PREFIX_PROFILE)
    identity.validate_report_header(native['published_report'],fixture['declaration'])
    assert diagnostic.replay_report(native['published_report'],fixture['declaration'],identity)==fixture['diagnostic_expected']
    assert native['diagnostic_replay']==fixture['diagnostic_expected']
    assert 'WALKING_ENTRY_CONTRACT_DRIFT' in fixture['historical_refusal']
    regression=read(REGRESSION/'native.json')
    assert regression['ok'] is True and len(regression['checks'])==52 and all(regression['checks'].values())
    for row in read(REGRESSION/'fixture.json')['positives']:
        assert regression['replays'][row['name']]==row['expected']
    assert len(regression['refusals'])==40 and all(row['ok'] is False for row in regression['refusals'].values())
    worker=(identity.ROOT/'sdk/adapters/godot/gdscript/r10ac_development_worker_v1.gd').read_text()
    assert 'func _authorized_seed_binding_v1' not in worker
    assert not list(identity.EVIDENCE.glob('r10ac*consumption*.json'))
    return dict(ok=True,native_selection_checks=30,source_key_inputs=1725,
        full_source_population_unchanged_during_checks=True,python_godot_selection_equal=True,
        real_prefix_facade_phase=248,consumed_r10ab_key_refused=True,
        native_control_and_simulated_task_unchanged=True,worker_and_reader_parse_passed=True,
        actual_worker_declaration_parser_roundtrip_checked=True,typed_seed_publication_checked=True,
        diagnostic_replay_with_v2_identity_checked=True,combined_incomplete_controller_report_refused=True,
        combined_positive_controller_replay_proven=False,default_reader_regression_checks=52,
        default_reader_positive_reports=3,default_reader_negative_reports=40,
        complete_safety_gate_passed=False,supervisor_integrated=False,launch_still_refused=True,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def capture():
    observed=observations()
    sources=[Path(__file__),identity.ROOT/'sdk/conformance/r10ac_support_loss_diagnosis.py',
        identity.ROOT/'sdk/recovery/r10ac_v56_walking_entry_contract_v1.json',
        identity.ROOT/'sdk/recovery/r10ac_v56_walking_entry_contract_v2.json',
        identity.ROOT/'sdk/recovery/r10ac_v56_walking_entry_contract_v3.json',
        identity.ROOT/'sdk/recovery/r10ac_v56_walking_entry_contract_v4.json']
    # The key binds the full executable population; avoid duplicating its 1725
    # records here. Its original before/after inventories are retained verbatim.
    sources += [identity.ROOT/p for p in ARCHIVED]
    files=[p for folder in (CHECK,*EARLIER,REGRESSION) for p in sorted(folder.iterdir()) if p.is_file()]
    write(RECORD,dict(schema_version='sporespore_r10ac_selection_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='prospective_diagnostic_selection_and_reader_composition',question_class='development'),
        source_bindings=[binding(p) for p in dict.fromkeys(sources)],retained_evidence=[binding(p) for p in files],observed=observed,
        scope='New R10AC entry/start admission aliases select unchanged V24/V56 native behavior under a distinct 1725-input key, including four shared reader dependencies absent from the inherited key and the new auditor. The actual prefix facade selects exposed phase 248. The combined reader requires controller and diagnostic success, and rejects a valid diagnostic with an incomplete controller report. Fresh publication normalizes the validated seed after the actual worker JSON declaration parser.',
        limits='Admission is not complete safety qualification. The worker still inherits launch refusal. A positive complete controller-plus-diagnostic report, supervisor/host-runtime/deadline integration and durable single-use reservation remain unproven. No world or held-out attempt ran.',
        next_action='Integrate the real supervisor, host runtime/deadlines, declaration/reader dispatch and single-use reservation; prove positive combined full-report replay and qualify the complete applicable safety graph before the declared fresh diagnostic.'))
    return observed


def audit():
    value=read(RECORD)
    for row in value['source_bindings']+value['retained_evidence']:assert binding(row['path'])==row
    observed=observations();assert observed==value['observed'];return observed


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--capture',action='store_true')
    print('R10AC_SELECTION_COMPONENT '+json.dumps(capture() if parser.parse_args().capture else audit()),flush=True)
