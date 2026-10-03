"""Retained full-report, retention, runtime and workflow controls; no qualification."""
import argparse,json,re
from pathlib import Path
import r10ad_integration_component as inputs
shared=inputs.shared
ROOT,EVIDENCE=inputs.ROOT,inputs.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10ad_complete_integration_component_v1.json'
RUNS=[EVIDENCE/'r10ad-integration-f41d25253f404b3ab7eab863dc7f8de0',EVIDENCE/'r10ad-integration-89479b59e8da463c96f75bc3a0ff799a']
HEADER=EVIDENCE/'r10ad-smoke-reader-fbb7bb675d544639a938f610af043ed8'
RETENTION=EVIDENCE/'r10ad-retention-check-01b8a29a867b4fda8f240146c312a807'
PARTIAL=EVIDENCE/'r10ad-complete-report-17ed6b3cac4e42588a8bb448dec1d2a3'
PHASES=[(EVIDENCE/name,branch,steps) for name,branch,steps in [
 ('r10ad-complete-phases-c4fdd03ba9e24a60a2707c0e4b04e2b6','upright',575),
 ('r10ad-complete-phases-ef75e4cfa13f4a229f7db3f33be9f822','ready',605),
 ('r10ad-complete-phases-be30df9e5fa04bb08abe6ac9e36aff71','timeout',815),
 ('r10ad-complete-phases-8ab15fa275f84ac0a513cdd01e13c77b','walking',607)]]
RUNTIME=EVIDENCE/'development-r10ab-runtime-49afbc3c5f8348eba1e7be96039d9928'
WORKFLOW=EVIDENCE/'r10ad-workflow-audit-832da1cc29e5435992b72ca31066d3ce'
CLAIMS=dict(complete_synthetic_controller_contact_replay_verified=True,actual_compact_writer_controls_verified=True,
    actual_runtime_entrypoint_controls_verified=True,synthetic_workflow_with_named_doubles_verified=True,
    complete_safety_gate_qualified=False,new_population_reserved=False,physical_execution_authorized=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20',full_program_score='14/25')

def require(value,code):
    if not value:raise ValueError('R10AD_COMPLETE_INTEGRATION_'+code)

def observed():
    specs=[dict(headers=8,retention=1,report=1,upright=1,ready=1,timeout=1,walking=1),dict(runtime=4,workflow=3)]
    for root,stages in zip(RUNS,specs):
        lock=shared.read(root/'operation-lock.json');require(lock['acquired'] is True and lock['released'] is True,'LOCK')
        receipts=shared.read(root/'stages.json');require([r['stage'] for r in receipts]==list(stages),'STAGES')
        for row in receipts:
            log=(root/(row['stage']+'.stderr.log')).read_text(encoding='utf-8-sig')
            require(row['exit_code']==0 and re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$',log,re.M)==[str(stages[row['stage']])]
                and len(re.findall(r'^OK\s*$',log,re.M))==1 and 'FAILED' not in log and 'skipped=' not in log,'TESTS')
    first=shared.read(HEADER/'source-before.json');second=shared.read(WORKFLOW/'source-before.json')
    for root,prefix,reference in [(HEADER,'source-',first),(RETENTION,'source_',first),(PARTIAL,'source-',first),
            *[(root,'source-',first) for root,_,_ in PHASES],(RUNTIME,'r10ad-source-',second),(WORKFLOW,'source-',second)]:
        require(shared.read(root/(prefix+'before.json'))==shared.read(root/(prefix+'after.json'))==reference,'SOURCE_STABILITY')
    keys=[inputs.snapshot_key(HEADER,3),inputs.snapshot_key(WORKFLOW,4)]
    cases=[(PARTIAL,'partial',575)]+[(root/branch,branch,count) for root,branch,count in PHASES]
    for root,branch,count in cases:
        receipt=shared.read(root/'complete-replay.json')
        require(receipt['ok'] is True and receipt['controller_and_diagnostic_replay_passed'] is True
            and receipt['complete_report_timeline_replayed'] is True and receipt['transition_count']==count
            and receipt['r10ac_contact_frame_replay']['diagnostic_steps_replayed']==count,'COMPLETE_REPLAY:'+branch)
        require(receipt['world_build_count']==receipt['solver_step_count']==0 and receipt['physical_acceptance_authority'] is False
            and receipt['release_authority'] is False,'NO_WORLD_OR_CLAIM')
        labels=['fixture','replay']+(['controller-missing','capture-missing','source-crossed'] if branch=='partial' else ['shutdown','memory','capture'] if branch=='walking' else [])
        for label in labels:
            execution=shared.read(root/(label+'.execution.json'))
            require(execution['returncode']==(0 if label in ('fixture','replay') else 1) and execution['timed_out'] is False,'NATIVE_EXECUTION')
            require((root/(label+'.stderr.txt')).read_bytes()==b'','NATIVE_STDERR')
    retention=shared.read(RETENTION/'result.json')
    require(retention['ok'] is True and len(retention['cases'])==11 and all(r['passed'] is True for r in retention['cases']),'RETENTION')
    workflow=shared.read(WORKFLOW/'synthetic-dispatch-result.json')
    require(workflow['synthetic_workflow_only'] is True and workflow['external_boundaries_mocked'] is True
        and workflow['actual_physical_attempt'] is False and workflow['result']['ok'] is True
        and workflow['result']['r10ad_contact_frame_diagnostic']['all_tasks_positive'] is False,'WORKFLOW_SCOPE')
    return dict(test_executions=21,complete_report_branches={branch:count for _,branch,count in cases},
        compact_retention_controls=11,tested_source_keys=keys,world_build_count=0,solver_step_count=0)

def audit(record):
    require(record['claim_boundary']==CLAIMS,'CLAIMS')
    for binding in record['bindings']+[record['auditor']]:shared.verify_binding(binding)
    require(record['observed']==observed(),'OBSERVATIONS')
    return dict(ok=True,**record['observed'],**CLAIMS)

def create():
    require(not RECORD.exists(),'ALREADY_RECORDED')
    roots=RUNS+[HEADER,RETENTION,PARTIAL,RUNTIME,WORKFLOW]+[root for root,_,_ in PHASES]
    paths=[p for root in roots for p in sorted(root.rglob('*')) if p.is_file()]
    paths += [Path(inputs.__file__),ROOT/'sdk/recovery/r10ad_v56_walking_entry_contract_v3.json',ROOT/'sdk/recovery/r10ad_v56_walking_entry_contract_v4.json']
    record=dict(schema_version='sporespore_r10ad_complete_integration_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='retained_complete_synthetic_report_and_host_controls',question_class='development'),
        auditor=shared.bind(__file__),bindings=[shared.bind(p) for p in paths],observed=observed(),claim_boundary=CLAIMS,
        next_action='Bind final prospective source key, freeze clean and pushed, then run the complete 57-stage 203-test safety graph including native startup before reservation. These component receipts are not reusable qualification.')
    audit(record);shared.write_new(RECORD,record);return audit(record)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(shared.read(RECORD))))
