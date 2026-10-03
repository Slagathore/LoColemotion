"""Audit retained R10AF synthetic report integration; no launch qualification."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import r10af_development as identity
import r10af_contact_frame_report as diagnostic
import development_recovery_candidate as candidate
import r10af_detection_frame_component as previous
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

RECORD=ROOT/'sdk/recovery/r10af_report_integration_component_v1.json'
PARENT='7d3794c466e646b8bd1851a24d97596f6057ae14'
CHECKS={
    'classification':EVIDENCE/'r10af-contact-reader-component-e8bc0453e3a346cbbff1afccdacca323',
    'contact_report':EVIDENCE/'r10af-contact-report-0fa9eb2f70404155924f0967503e03f9',
    'walking_source':EVIDENCE/'r10af-walking-source-c36a4bf1ec874ff0ae0b232c5cfcb1e8',
    'partial':EVIDENCE/'r10af-complete-report-a454b0e90f3543fa94074717824f8803',
    'phases':EVIDENCE/'r10af-complete-phases-47f7d839a058497ab1187d7626d6324b',
}
CLAIMS=dict(synthetic_complete_report_replay_proven=True,walking_source_adapter_transport_proven=True,
    production_physical_dispatch_exercised=False,full_launch_path_proven=False,
    complete_safety_gate_qualified=False,physical_attempt_started_at_checkpoint=False,
    physical_execution_authorized=False,physical_acceptance_authority=False,release_authority=False,
    controller_changed=False,core_dll_changed=False,thresholds_changed=False,
    world_build_count=0,solver_step_count=0,sdk1_score='14/20',full_program_score='14/25')


def historical_classification():
    """Verify the immutable preceding component at its own committed source."""
    record=read(previous.RECORD)
    for value in [bind(previous.RECORD),record['auditor'],*record['bindings']]:
        path=Path(value['path'])
        if path.is_relative_to(ROOT):
            raw=subprocess.check_output(['git','cat-file','blob',PARENT+':'+path.relative_to(ROOT).as_posix()],
                cwd=ROOT,creationflags=subprocess.CREATE_NO_WINDOW)
            variants=[raw] if b'\r\n' in raw else [raw,raw.replace(b'\n',b'\r\n')]
            assert any(len(data)==value['byte_length'] and 'sha256:'+hashlib.sha256(data).hexdigest()==value['raw_sha256'] for data in variants),path
        else: assert bind(path)==value,path
    assert record['claim_boundary']==previous.CLAIMS
    assert record['observed']==previous.observations()
    return dict(ok=True,source_commit=PARENT,component=bind(previous.RECORD),
        original_component_reclassified=False,current_source_qualification=False)


def execution(directory,label,exit_code=0):
    value=read(directory/(label+'.execution.json'))
    assert value['returncode']==exit_code and value['timed_out'] is False
    assert value['world_build_count']==value['solver_step_count']==0
    assert not (directory/(label+'.stderr.txt')).read_bytes()
    return value


def replay_receipt(directory,label='replay'):
    marker='DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
    rows=[json.loads(line[len(marker):]) for line in (directory/(label+'.stdout.txt')).read_text(encoding='utf-8-sig').splitlines() if line.startswith(marker)]
    assert len(rows)==1
    return rows[0]


def observations():
    for directory in CHECKS.values():
        assert read(directory/'source-before.json')==read(directory/'source-after.json')
    fixed=read(CHECKS['classification']/'fixtures.json')
    assert fixed['ok'] is True and fixed['negative_refusals']==20 and len(fixed['positive_cases'])==6
    execution(CHECKS['classification'],'native');execution(CHECKS['classification'],'legacy-retention')
    contact=read(CHECKS['contact_report']/'fixtures.json');execution(CHECKS['contact_report'],'native')
    declaration=read(CHECKS['contact_report']/'declaration.json')
    assert diagnostic.replay_report(contact['report'],declaration,identity)==contact['replay']
    assert len(contact['negative_reports'])==7
    for report in contact['negative_reports']:
        try:diagnostic.replay_report(report,declaration,identity)
        except (ValueError,KeyError,TypeError):pass
        else:raise AssertionError('Crossed contact report accepted')
    walking=read(CHECKS['walking_source']/'fixtures.json');execution(CHECKS['walking_source'],'native')
    assert walking['ok'] is True and all(walking['checks'].values())
    assert len(walking['cases'])==6 and walking['negative_controls']==7
    scenarios={}
    for name,count in [('partial',575),('upright',575),('ready',605),('timeout',815),('walking',607)]:
        root=CHECKS['partial'] if name=='partial' else CHECKS['phases']
        directory=root if name=='partial' else root/name
        execution(directory,'fixture');execution(directory,'replay')
        fixed=read(directory/('partial.fixture.json' if name=='partial' else 'fixture.json'))
        assert fixed['ok'] is True
        if 'checks' in fixed: assert all(fixed['checks'].values())
        declaration=read(root/'synthetic-declaration.json')
        report=read(directory/'worker_report.json')
        receipt=replay_receipt(directory)
        expected=diagnostic.replay_report(report,declaration,identity)
        assert receipt==read(directory/'complete-replay.json')
        assert receipt['ok'] is True and receipt['complete_report_timeline_replayed'] is True
        assert receipt['controller_and_diagnostic_replay_passed'] is True
        assert receipt['transition_count']==expected['diagnostic_steps_replayed']==count
        assert receipt['r10af_contact_frame_replay']==expected
        assert receipt['world_build_count']==receipt['solver_step_count']==0
        assert receipt['physical_acceptance_authority'] is receipt['release_authority'] is False
        if name in ('ready','timeout','walking'):
            assert report['retained_arm']['orchestrator_state']['post_recovery_settling']['outcome']==('timeout' if name=='timeout' else 'ready')
        if name=='walking':
            assert receipt['walking_control_replay']['replayed_walking_steps']==2
            assert read(directory/'finite-task.json')['finite_task_predicates_passed'] is False
        scenarios[name]=dict(synthetic_steps=count,controller_and_contact_replay_passed=True,
            full_physical_route_proven=False)
    for root,labels in [(CHECKS['partial'],['controller-missing','capture-missing','source-crossed']),
            (CHECKS['phases']/'walking',['shutdown','memory','capture'])]:
        for label in labels:
            execution(root,label,1);assert replay_receipt(root,label)['ok'] is False
    selected=candidate.selection(identity.reference())
    assert selected['worker_selection']['worker']=='res://sdk/adapters/godot/gdscript/r10af_development_worker_v1.gd'
    return dict(scenarios=scenarios,complete_report_scenarios=5,damaged_complete_reports_refused=6,
        native_classification_cases=6,native_classification_refusals=20,
        contact_report_refusals=7,walking_adapter_cases=6,walking_source_refusals=7,
        legacy_contact_sources_preserved=True,source_unchanged_during_native_checks=True,
        selected_worker=selected['worker_selection']['worker'],selected_reader=selected['reader'])


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for value in record['bindings']+[record['auditor']]:assert bind(value['path'])==value,value['path']
    assert record['historical_classification']==historical_classification()
    assert record['observed']==observations()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    changed=subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=ROOT,text=True).splitlines()
    changed+=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
    paths={ROOT/name for name in changed if Path(name).suffix in ('.py','.gd','.json')}
    paths.update(ROOT/name for name in previous.SOURCES)
    paths.add(previous.RECORD)
    for directory in CHECKS.values(): paths.update(p for p in directory.rglob('*') if p.is_file())
    record=dict(schema_version='sporespore_r10af_report_integration_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_report_integration',question_class='development'),
        auditor=bind(__file__),bindings=[bind(p) for p in sorted(paths)],
        historical_classification=historical_classification(),observed=observations(),claim_boundary=CLAIMS,
        coverage_limits=[
            'All controller scenarios and contact frames are supplied synthetic inputs; this is not measured recovery or an effect comparison.',
            'Complete reports prove controller and contact reader integration. Separate production walking-source hooks prove adapter transport; no physical observer-to-controller path has been executed.',
            'The worker seed authorization and native-world construction remain closed pending fresh context handoff, single-use authority and complete applicable safety qualification.',
            'The two-command walking fixture proves session/report plumbing, not the finite four-cycle walking and stop predicates.',
            'Earlier classification evidence is verified at its original committed source; no consumed R10AE result or population is renewed.'])
    result=audit(record);write_new(RECORD,record);return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create',action='store_true');parser.add_argument('--historical-classification',action='store_true')
    args=parser.parse_args()
    print(json.dumps(historical_classification() if args.historical_classification else create() if args.create else audit(read(RECORD))))
