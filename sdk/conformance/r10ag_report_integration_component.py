"""Audit R10AG synthetic integration; never qualify or launch a physical world."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import r10ag_development as identity
import r10ag_native_interface as interfaces
import r10ag_finite_task_audit as finite
import r10ag_replay_host as replay_host
import r10af_rise_diagnosis as diagnosis
from r10af_report_integration_component import execution, replay_receipt
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new
import development_recovery_candidate as candidate

RECORD = ROOT/'sdk/recovery/r10ag_report_integration_component_v1.json'
PARENT = 'b5ae32e9a59186c785f34edc9cdfb819c7c3e88c'
HISTORY = [EVIDENCE/name for name in (
    'r10ag-complete-report-ffd12ca7f07c4defa6aab92cb7bae6ef',
    'r10ag-complete-report-1f9ca3d2b6cd4d1a992f43337ec419c7',
    'r10ag-complete-phases-2c3c751ad3ad4627adbfca3910e3dc94')]
CLAIMS = dict(synthetic_complete_report_replay_proven=True,
    complete_physical_route_proven=False, full_launch_path_proven=False,
    complete_safety_gate_qualified=False, physical_attempt_started_at_checkpoint=False,
    physical_execution_authorized=False, physical_acceptance_authority=False,
    release_authority=False, core_dll_changed=False, thresholds_changed=False,
    selected_partial_controller_changed_from_r10af=True,
    world_build_count=0, solver_step_count=0, sdk1_score='14/20', full_program_score='14/25')


def historical_diagnosis():
    """Historical source is checked at its commit, never rebound to this route."""
    record = read(diagnosis.RECORD)
    for value in record['dependencies']+record['retained_evidence']:
        path = Path(value['path'])
        if path.is_relative_to(ROOT):
            raw = subprocess.check_output(['git','cat-file','blob',PARENT+':'+path.relative_to(ROOT).as_posix()], cwd=ROOT)
            variants = [raw] if b'\r\n' in raw else [raw,raw.replace(b'\n',b'\r\n')]
            assert any(len(v)==value['byte_length'] and 'sha256:'+hashlib.sha256(v).hexdigest()==value['raw_sha256'] for v in variants), path
        else:
            assert bind(path)==value, path
    assert record['claim_boundary']==diagnosis.CLAIMS
    return dict(source_commit=PARENT, record=bind(diagnosis.RECORD),
        source_and_retained_evidence_verified=True, original_result_regraded=False,
        current_source_qualification=False)


def source_admission():
    key = candidate.R10AG_ROUTE_ENTRY_PATH
    value = read(key)
    assert value['source_key_complete'] is True
    assert value['required_walking_policy_id']==candidate.R10AG_ROUTE_ID
    for row in value['bound_source_files']:
        actual = bind(ROOT/row['path'])
        assert (actual['byte_length'],actual['raw_sha256'])==(row['byte_length'],row['raw_sha256']),row['path']
    task = finite.contract()
    predecessor = read(ROOT/'sdk/recovery/r10ab_partial_downward_rise_finite_cycle_contract_v2.json')
    for field in ('limits','whole_walking_envelope','finite_walking_observable','settled_tail',
                  'partial_recovery','prone_recovery','upright_recovery','native_interaction','post_recovery_hold'):
        assert task[field]==predecessor[field],field
    composition = task['controller_composition']
    assert composition['partial_control_composition_id']=='sporespore_r10aa_partial_load_seeking_v23_v7_composition_v1'
    assert composition['partial_step_export']=='ss_recovery_r10aa_partial_step_control_v1_json'
    selected = candidate.selection(identity.reference())
    assert selected['worker_selection']['worker']=='res://sdk/adapters/godot/gdscript/r10ag_development_worker_v1.gd'
    assert selected['reader']=='res://sdk/trace_analysis/r10ag_recovery_replay.gd'
    assert selected['diagnostic_schedule']['coverage_basis']['task_contract_sha256']=='sha256:'+finite.TASK_SHA
    return dict(key=bind(key),bound_source_files=len(value['bound_source_files']),
        worker=selected['worker_selection']['worker'],reader=selected['reader'],task=bind(finite.TASK))


def observations(roots):
    roots={name:Path(path) for name,path in roots.items()}
    for name in ('partial','phases'):
        root=roots[name]
        assert read(root/'source-before.json')==read(root/'source-after.json')
    scenarios={}
    for name,count in [('partial',575),('upright',575),('ready',605),('timeout',815),('walking',607)]:
        root=roots['partial' if name=='partial' else 'phases']
        directory=root if name=='partial' else root/name
        execution(directory,'fixture');execution(directory,'replay')
        fixed=read(directory/('partial.fixture.json' if name=='partial' else 'fixture.json'))
        assert fixed['ok'] is True
        if 'checks' in fixed:assert all(fixed['checks'].values())
        report=read(directory/'worker_report.json')
        receipt=replay_receipt(directory)
        assert receipt==read(directory/'complete-replay.json')
        assert receipt['ok'] is True and receipt['complete_report_timeline_replayed'] is True
        contact=replay_host.independent_result(report,root/'synthetic-declaration.json',receipt)
        assert receipt['transition_count']==contact['diagnostic_steps_replayed']==count
        assert receipt['world_build_count']==receipt['solver_step_count']==0
        assert receipt['physical_acceptance_authority'] is receipt['release_authority'] is False
        recovery=finite.recovery_measurement(report)
        assert recovery['entry_kind']==('partial' if name=='partial' else 'upright')
        if name=='walking':
            assert receipt['walking_control_replay']['replayed_walking_steps']==2
            assert len(report['development_cycle_stop']['rows'])==2
            measured=read(directory/'finite-task.json')
            assert measured['finite_task_predicates_passed'] is False
            assert measured['predicates']['planned_cycles'] is False
            assert measured['predicates']['declared_entry_kind'] is False
        if name in ('ready','timeout','walking'):
            assert report['retained_arm']['orchestrator_state']['post_recovery_settling']['outcome']==('timeout' if name=='timeout' else 'ready')
        scenarios[name]=dict(synthetic_steps=count,controller_and_contact_replay_passed=True)
    for directory,labels in [(roots['partial'],['controller-missing','capture-missing','source-crossed']),
            (roots['phases']/'walking',['shutdown','memory','capture'])]:
        for label in labels:
            execution(directory,label,1);assert replay_receipt(directory,label)['ok'] is False
    controls=read(roots['controls']/'result.json')
    assert controls['returncode']==0 and controls['tests_passed']==14
    assert controls['source_before']==controls['source_after']
    stderr=(roots['controls']/'stderr.txt').read_text()
    assert 'Ran 14 tests' in stderr and stderr.rstrip().endswith('OK')
    return dict(scenarios=scenarios,complete_report_scenarios=5,damaged_complete_reports_refused=6,
        finite_boundary_and_cycle_controls=14,source_unchanged_during_each_run=True)


def audit(record):
    assert record['claim_boundary']==CLAIMS
    for value in record['bindings']+[record['auditor']]:assert bind(value['path'])==value,value['path']
    assert record['source_admission']==source_admission()
    assert record['historical_diagnosis']==historical_diagnosis()
    interfaces.audit()
    assert record['observed']==observations(record['evidence_roots'])
    return dict(ok=True,**record['observed'],**CLAIMS)


def create(roots):
    assert not RECORD.exists()
    admission=source_admission()
    paths={ROOT/row['path'] for row in read(candidate.R10AG_ROUTE_ENTRY_PATH)['bound_source_files']}
    paths.update([candidate.R10AG_ROUTE_ENTRY_PATH,interfaces.RECORD,diagnosis.RECORD])
    for root in [*map(Path,roots.values()),*HISTORY]:
        assert root.is_relative_to(EVIDENCE) and root.is_dir()
        paths.update(p for p in root.rglob('*') if p.is_file())
    record=dict(schema_version='sporespore_r10ag_report_integration_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_report_integration',question_class='development'),
        source_parent_commit=PARENT,auditor=bind(__file__),bindings=[bind(p) for p in sorted(paths)],
        source_admission=admission,historical_diagnosis=historical_diagnosis(),
        evidence_roots=roots,observed=observations(roots),claim_boundary=CLAIMS,
        retained_development_history=[dict(path=str(p),current_qualification=False) for p in HISTORY],
        coverage_limits=[
            'All controller trajectories and contact inputs are synthetic. No native dynamics or recovery success is established.',
            'Two fresh walking commands cover session, contact, cycle retention and readers, not four physical cycles or the physical settled stop.',
            'Earlier component snapshots and integration failures are retained, without qualification of their superseded bindings.',
            'Seed authorization and native world construction remain closed. Context handoff, one-use ownership and complete applicable safety qualification are still required.',
            'The consumed R10AF negative and its historical diagnosis remain unchanged.'])
    result=audit(record);write_new(RECORD,record);return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--create',action='store_true')
    for name in ('partial','phases','controls'):parser.add_argument('--'+name+'-root')
    args=parser.parse_args()
    roots={name:getattr(args,name+'_root') for name in ('partial','phases','controls')}
    if args.create:assert all(roots.values())
    print(json.dumps(create(roots) if args.create else audit(read(RECORD)),indent=2))
