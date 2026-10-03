"""Read-only audit of retained R10AD integration controls; no safety qualification."""
import argparse,base64,hashlib,json,re,subprocess
from pathlib import Path
import r10ac_startup_invalid_closure as shared
ROOT,EVIDENCE=shared.ROOT,shared.EVIDENCE
RECORD=ROOT/'sdk/recovery/r10ad_integration_component_v1.json'
RUNS=[EVIDENCE/'r10ad-integration-73965e4a87b7416a926b149ea9965f11',
      EVIDENCE/'r10ad-integration-df52c540cfbd463c8c32d53f25e4cebb']
NATIVE=EVIDENCE/'r10ad-native-interfaces-4e8803b80eca48c0a450befbdc88d0a0'
HOST=EVIDENCE/'r10ad-host-check-9cb7ee146d9146e599af9c4c65c4d1f1'
LAUNCH=EVIDENCE/'r10ad-launch-guard-1b6ee47131b04b5991e58de61ea67ec0'
AUTHORITY=EVIDENCE/'r10ad-launch-guard-ee3c79c10c7a40d1bbd156bb371ef832'
CLAIMS=dict(candidate_worker_reader_dispatch_verified=True,native_permission_refusals_verified=True,
    retained_startup_refusal_verified=True,complete_combined_controller_replay_proven=False,
    complete_safety_gate_qualified=False,new_population_reserved=False,physical_execution_authorized=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20',full_program_score='14/25')

def require(value,code):
    if not value:raise ValueError('R10AD_INTEGRATION_'+code)

def snapshot_key(folder,revision):
    """Reconstruct the tested bytes from its base commit and retained replacements.

    Historical controls never become qualification of the current working tree.
    """
    before=folder/('source_before.json' if folder in (LAUNCH,AUTHORITY) else 'source-before.json')
    after=folder/('source_after.json' if folder in (LAUNCH,AUTHORITY) else 'source-after.json')
    source=shared.read(before);require(source==shared.read(after),'SOURCE_CHANGED')
    replacements={row['path']:row for row in source['changed_files']}
    for row in replacements.values():
        if not row['deleted']:
            raw=base64.b64decode(row['replacement_base64'],validate=True)
            require('sha256:'+hashlib.sha256(raw).hexdigest()==row['raw_sha256'],'SNAPSHOT_HASH')
    key_path=f'sdk/recovery/r10ad_v56_walking_entry_contract_v{revision}.json'
    key=ROOT/key_path
    require(base64.b64decode(replacements[key_path]['replacement_base64'])==key.read_bytes(),'TESTED_KEY')
    rows=shared.read(key)['bound_source_files']
    require(len(rows)==len({row['path'] for row in rows}),'DUPLICATE_INPUT')
    originals=[row for row in rows if row['path'] not in replacements]
    command=subprocess.run(['git','cat-file','--batch'],cwd=ROOT,capture_output=True,check=True,timeout=60,
        input=''.join(source['head']+':'+row['path']+'\n' for row in originals).encode(),creationflags=subprocess.CREATE_NO_WINDOW)
    require(command.stderr==b'','GIT_STDERR');raw=command.stdout;cursor=0;blobs={}
    for row in originals:
        end=raw.index(b'\n',cursor);header=raw[cursor:end].split()
        require(len(header)==3 and header[1]==b'blob','GIT_BLOB')
        size=int(header[2]);blobs[row['path']]=raw[end+1:end+1+size];cursor=end+2+size
    require(cursor==len(raw),'GIT_TAIL')
    for row in rows:
        name=row['path']
        if name in replacements:
            require(not replacements[name]['deleted'],'DELETED_INPUT')
            variants=[base64.b64decode(replacements[name]['replacement_base64'])]
        else:
            data=blobs[name];variants=[data,data.replace(b'\n',b'\r\n')] if b'\r\n' not in data else [data]
        require(any(len(data)==row['byte_length'] and 'sha256:'+hashlib.sha256(data).hexdigest()==row['raw_sha256'] for data in variants),'TESTED_INPUT:'+name)
    return dict(source_key=key_path,source_files=len(rows),owned_dirty_source=True,base_commit=source['head'])

def observed():
    counts=[dict(native=4,host=7,startup=4,transport=3),dict(launch=10,authority=17)]
    for folder,stages in zip(RUNS,counts):
        lock=shared.read(folder/'operation-lock.json')
        require(lock['acquired'] is True and lock['released'] is True,'LOCK')
        receipts=shared.read(folder/'stages.json');require([r['stage'] for r in receipts]==list(stages),'STAGE_POPULATION')
        for row in receipts:
            require(row['exit_code']==0,'STAGE_EXIT')
            log=(folder/(row['stage']+'.stderr.log')).read_text(encoding='utf-8-sig')
            require(re.findall(r'^Ran (\d+) tests in [0-9.]+s\s*$',log,re.M)==[str(stages[row['stage']])]
                and len(re.findall(r'^OK\s*$',log,re.M))==1 and 'FAILED' not in log and 'skipped=' not in log,'STAGE_TESTS')
    native=shared.read(NATIVE/'selection/native.json')
    require(native['ok'] is True and len(native['checks'])==30 and all(v is True for v in native['checks'].values()),'NATIVE_SELECTION')
    permission=shared.read(AUTHORITY/'test_native_pure_permission_and_real_helper_parent_probe/result.json')
    require(permission['ok'] is True and len(permission['checks'])==30 and all(v is True for v in permission['checks'].values()),'NATIVE_PERMISSION')
    require(permission['world_build_count']==permission['solver_step_count']==0,'ZERO_WORLD')
    for label in ['worker-parse','reader-parse','selection','capture','observer','report']:
        require(shared.read(NATIVE/(label+'.execution.json'))==dict(exit_code=0,timed_out=False),'NATIVE_PROCESS')
        require((NATIVE/(label+'.stderr.log')).read_bytes()==b'','NATIVE_STDERR')
    require(shared.read(HOST/'supervisor-declaration-interface.json')['seed']==62248,'SUPERVISOR_SEED')
    keys=[snapshot_key(NATIVE,1),snapshot_key(HOST,1),snapshot_key(LAUNCH,2),snapshot_key(AUTHORITY,2)]
    return dict(test_executions=45,distinct_tests=35,inherited_guard_tests_repeated=10,
        native_selection_checks=30,native_permission_checks=30,tested_source_keys=keys,
        seed=62248,exposed_prefix_phase=248,world_build_count=0,solver_step_count=0)

def audit(record):
    require(record['claim_boundary']==CLAIMS,'CLAIMS')
    for binding in record['bindings']+[record['auditor']]:shared.verify_binding(binding)
    require(record['observed']==observed(),'OBSERVATIONS')
    return dict(ok=True,**record['observed'],**CLAIMS)

def create():
    require(not RECORD.exists(),'ALREADY_RECORDED')
    folders=RUNS+[NATIVE,HOST,LAUNCH,AUTHORITY]
    paths=[p for folder in folders for p in sorted(folder.rglob('*')) if p.is_file()]
    paths += [ROOT/f'sdk/recovery/r10ad_v56_walking_entry_contract_v{v}.json' for v in (1,2)]
    record=dict(schema_version='sporespore_r10ad_integration_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='retained_zero_world_integration_controls',question_class='development'),
        auditor=shared.bind(__file__),bindings=[shared.bind(p) for p in paths],observed=observed(),claim_boundary=CLAIMS,
        remaining=['Complete combined controller replay and report/auditor/retention controls for R10AD',
            'Declare and run the complete applicable safety graph including the real native startup preflight before reservation',
            'Freeze clean pushed source, then execute the distinct contact-frame diagnostic',
            'Use measured data for a justified recovery successor, paired commissioning, official qualification, held-out decision and M07 adoption'])
    audit(record);shared.write_new(RECORD,record);return audit(record)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true');args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(shared.read(RECORD))))
