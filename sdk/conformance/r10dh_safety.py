"""Actual native consumers, complete retained fixtures and real launcher refusal path."""
import json
from pathlib import Path
import r10dh_contract as C
import r10dh_campaign as Campaign
from r10dh_dependency_manifest import D

VALID = ('partial','upright','ready','timeout','walking','prone')
REFUSALS = dict(partial_source='R10AF_CONTACT_REPORT_TRACE_LINK',
    partial_owner='R10AP_RECOVERY_REPLAY_EVENT_INVALID',partial_phase='R10AP_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',
    partial_energy='R10AP_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',walking_shutdown='R10AP_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
    walking_memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY',walking_capture='R10AF_CONTACT_REPORT_RECORD_POPULATION',
    walking_missing='R10AP_ENTRY_REPLAY_POST_HOLD_RETENTION',prone_source='R10AF_CONTACT_REPORT_TRACE_LINK')
READER = 'res://sdk/adapters/godot/gdscript/r10dh_campaign_reader_v1.gd'
PRONE_FOLDER = C.EVIDENCE/'development-recovery-smoke-d3e30e9749d64d5d80192310167f8c0e'
PRONE_SHA = 'sha256:f68b472e743de21e4feb47726449b227e9c0f9e9ac84097163e5c1b17e5aff65'


def fixtures(root):
    catalog=C.read(C.ROOT/'sdk/development/r10ap_report_fixture_catalog_v2.json')
    C.require(set(catalog['cases']) == set(VALID[:-1]) | (set(REFUSALS)-{'prone_source'}), 'FIXTURE_CATALOG_POPULATION')
    cases=[]
    for name,case in catalog['cases'].items():
        declaration=C.EVIDENCE/('development-recovery-smoke-'+case['declaration']['attempt_id'])/'declaration.json'
        C.require(D.binding(declaration)['raw_sha256']==case['declaration_raw_sha256'], 'FIXTURE_DECLARATION')
        report=Path(case['declaration']['children'][0]['evidence_path'])/'worker_report.json'
        cases.append((name,'fixture',declaration,report))
    prone=PRONE_FOLDER/'children/kick_passive_recovery_resume/worker-streamed-report.json'
    C.require(D.binding(prone)['raw_sha256']==PRONE_SHA,'PRONE_FIXTURE_BYTES')
    cases.append(('prone','panel_fixture',PRONE_FOLDER/'declaration.json',prone))
    cases.append(('prone_source','panel_fixture',PRONE_FOLDER/'declaration.json',root/'prone-corrupt.json'))
    return cases


def validate_native(root, value):
    expected=fixtures(root)
    C.require(value.get('ok') is True and value.get('world_build_count')==value.get('solver_step_count')==0, 'NATIVE_SAFETY')
    C.require([r['name'] for r in value['fixtures']] == [r[0] for r in expected], 'NATIVE_FIXTURE_POPULATION')
    for row,(name,mode,declaration,report) in zip(value['fixtures'],expected):
        C.require(row['input']==D.binding(report) and row['declaration']==D.binding(declaration), 'NATIVE_FIXTURE_BINDING')
        D.verify_binding(row['output']); D.verify_binding(row['process'])
        C.require(row['output']==D.binding(root/('fixture-'+name+'.json'))
            and row['process']==D.binding(root/('fixture-'+name+'.process.json')), 'NATIVE_FIXTURE_PATH')
        v=C.read(row['output']['path']); proc=C.read(row['process']['path'])
        C.require(proc['timed_out'] is False and proc['exit_code']==(0 if name in VALID else 1), 'NATIVE_FIXTURE_PROCESS')
        for stream in ('stdout','stderr'):D.verify_binding(proc[stream])
        C.require(v['test_only'] is True and v['world_build_count']==v['solver_step_count']==0
            and v['ok'] is (name in VALID), 'NATIVE_FIXTURE_RESULT')
        if name not in VALID:C.require(v['failure_code']==REFUSALS[name], 'NATIVE_FIXTURE_REFUSAL')
    for name in ('identity','stream'):
        v=C.read(root/(name+'-controls.json'))
        C.require(v['ok'] is True, 'NATIVE_'+name)
    metadata=C.read(root/'prone-metadata-fixture.json')
    C.require(metadata['test_only'] is True and metadata['input']['raw_sha256']==PRONE_SHA
        and metadata['measurement']['finite_task_predicates_passed'] is True
        and metadata['measurement']['recovery']['entry_kind']=='prone','PRONE_METADATA_FIXTURE')
    transport=C.read(root/'full-report-transport.json')
    fixture=C.read(C.ROOT/'sdk/discovery/recovery_panel_transport_fixture_v1.json')
    C.require(transport['ok'] is True and transport['test_only'] is True
        and transport['world_build_count']==transport['solver_step_count']==0
        and transport['raw_sha256']==fixture['expected_raw_sha256']
        and transport['byte_length']==fixture['expected_byte_length'], 'FULL_REPORT_TRANSPORT')
    D.verify_binding({k:transport[k] for k in ('path','byte_length','raw_sha256')})
    for row in C.read(root/'cells.json'):
        child=Path(row['folder'])/'children'/row['cell']['role']
        leaf=C.read(child/'preflight-leaf-result.json'); clean=C.read(child/'preflight-owned-cleanup.json')
        C.require(leaf['ok'] is True and leaf['exit_code']==0 and clean['cleanup_complete'] is True, 'REAL_LAUNCHER_PREFLIGHT')
        C.require(not (child/'world-claim.json').exists() and not (child/'launch-reservation.json').exists(), 'ZERO_WORLD_CLAIMS')


def run_native(root):
    root=Path(root); manifest=C.read(root/'manifest.json'); engine=manifest['runtime']['images']['godot_engine']['path']
    rows=C.read(root/'cells.json'); declaration=Path(rows[0]['folder'])/'declaration.json'
    D.process(root,'identity',[engine,'--headless','--path',C.ROOT,'--script',
        'res://sdk/adapters/godot/gdscript/test_r10dh_identity_v1.gd','--',root/'identity-controls.json'],timeout=180)
    D.process(root,'stream',[engine,'--headless','--path',C.ROOT,'--script',
        'res://sdk/discovery/test_recovery_report_file_v1.gd','--',root],timeout=180)
    # The inherited stream script chooses its own fixed output filename.
    D.write_new(root/'stream-controls.json',C.read(root/'stream-controls-result.json'))
    transport=C.read(C.ROOT/'sdk/discovery/recovery_panel_transport_fixture_v1.json')
    D.verify_binding(transport['report']);D.verify_binding(transport['profile'])
    D.process(root,'full-report-transport',[engine,'--headless','--path',C.ROOT,'--script',READER,'--','transport',
        declaration,transport['report']['path'],root/'full-report-transport.json'],timeout=1200)
    report=C.read(PRONE_FOLDER/'children/kick_passive_recovery_resume/worker-streamed-report.json')
    import r10dh_reader as Reader
    core=Reader.LocomotionCore(manifest['runtime']['images']['candidate_dll']['path'])
    measured=Reader.Measurements.measure(report,core.compile_bounded_quadruped(report['configuration']['base_descriptor']))
    D.write_new(root/'prone-metadata-fixture.json',dict(test_only=True,
        input=D.binding(PRONE_FOLDER/'children/kick_passive_recovery_resume/worker-streamed-report.json'),
        prefix=Reader.body_prefix(report,report['arm_id']),measurement=measured,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False))
    del core
    report['r10af_contact_frame_links']['records'][0]['source_trace']['semantic_step']=999
    D.write_new(root/'prone-corrupt.json',report);del report
    retained=[]
    for name,mode,original,report in fixtures(root):
        output=root/('fixture-'+name+'.json')
        command=[engine,'--headless','--path',C.ROOT,'--script',READER,'--',mode,declaration,report,output,original]
        try:D.process(root,'fixture-'+name,command,timeout=1200)
        except ValueError:
            if name in VALID:raise
        v=C.read(output)
        C.require(v['ok'] is (name in VALID),'FIXTURE_EXPECTATION_'+name)
        if name not in VALID:C.require(v.get('failure_code')==REFUSALS[name],'FIXTURE_CAUSE_'+name)
        retained.append(dict(name=name,input=D.binding(report),declaration=D.binding(original),
            output=D.binding(output),process=D.binding(root/('fixture-'+name+'.process.json'))))
        print('R10DH_NATIVE_FIXTURE_PASS '+name,flush=True)
    # Exercise the actual operation mutex, PowerShell launch context and nested
    # leaf ownership with world permission withheld for every declared cell.
    D.process(root,'real-launcher-preflight',[manifest['runtime']['images']['powershell_host']['path'],
        '-NoProfile','-File',C.ROOT/'sdk/conformance/run_r10dh_campaign.ps1','-Batch',root,
        '-MaximumCells',str(len(rows)),'-Workers','1','-QualificationOnly'],timeout=180*len(rows)+60)
    value=dict(ok=True,fixtures=retained,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)
    validate_native(root,value);D.write_new(root/'native-safety.json',value)
