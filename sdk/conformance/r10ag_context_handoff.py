"""Selected-runtime context handoff required before R10AG population reservation."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
import r10ag_development as identity
import r10ag_host_runtime as host
import development_recovery_candidate as candidate
ROOT,EVIDENCE=identity.ROOT,identity.EVIDENCE
PRODUCER='r10ag_context_producer.json'
CONSUMER='r10ag_pre_world_receipt.json'

def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def bind(path):
    path=Path(path).resolve()
    return dict(path=path.as_posix(),byte_length=path.stat().st_size,raw_sha256=identity.sha(path))
def write(path,value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as f:
        json.dump(value,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
def require(value,code):
    if not value:raise ValueError('R10AG_CONTEXT_HANDOFF_'+code)
def verify_binding(value):require(bind(value['path'])==value,'RETAINED_BYTES')
def zero(value):
    require(all(type(value.get(k)) is int and value[k]==0 for k in ['world_build_count','solver_step_count']),'ZERO_WORLD')
    require(all(value.get(k) is False for k in ['physical_acceptance_authority','release_authority']),'NO_CLAIMS')
def check_source(value):
    identity.validate_declaration(value);host.validate_binding(value['runtime'])
    selected=candidate.selection(identity.reference())
    require(selected['worker_selection']['worker']==value['worker_resource'],'WORKER_RESOURCE')
    images=value['runtime']['images'];host.bind_runtime(images['godot_console']['path'],images['powershell_host']['path'])
    return selected

def native(root,name,script,args,environment):
    output=root/(name+'.json');require(not output.exists(),'OUTPUT_EXISTS')
    command=[host.expected_binding()['images']['godot_engine']['path'],'--headless','--path',str(ROOT),
        '--script','res://'+script,'--',*map(str,args),str(output)]
    env={k:v for k,v in os.environ.items() if not k.startswith('SPORESPORE_GODOT_RECOVERY_')};env.update(environment)
    write(root/(name+'.command.json'),dict(command=command,working_directory=str(ROOT),timeout_seconds=180,
        environment=environment,source_key=bind(candidate.R10AG_ROUTE_ENTRY_PATH)))
    with (root/(name+'.stdout.log')).open('xb') as stdout,(root/(name+'.stderr.log')).open('xb') as stderr:
        process=subprocess.Popen(command,cwd=ROOT,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,env=env,
            creationflags=subprocess.CREATE_NO_WINDOW)
        timed_out=False
        try:code=process.wait(timeout=180)
        except subprocess.TimeoutExpired:
            timed_out=True
            killed=subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=30,
                creationflags=subprocess.CREATE_NO_WINDOW)
            write(root/(name+'.timeout-kill.json'),dict(exit_code=killed.returncode))
            code=process.wait(timeout=30)
    write(root/(name+'.execution.json'),dict(exit_code=code,timed_out=timed_out,process_id=process.pid))
    require(code==0 and not timed_out,'NATIVE_EXIT:'+name)
    require((root/(name+'.stderr.log')).read_bytes()==b'','NATIVE_STDERR:'+name)
    result=read(output);require(result['ok'] is True,'NATIVE_RESULT:'+name);zero(result)
    return result

def expectation(result):
    capture=result['capture'];raw=capture['utf8_text'].encode('utf-8')
    require(capture['utf8_byte_length']==len(raw) and capture['raw_sha256']=='sha256:'+hashlib.sha256(raw).hexdigest(),'CAPTURE_HASH')
    inner=json.loads(capture['utf8_text']);context=json.loads(inner['source_context']['utf8_text'])
    runtime=context['runtime_profile_receipt']['runtime_identity']
    require(runtime['r10ag_diagnostic_only'] is True and runtime['r10ag_candidate_profile']==identity.reference()
        and runtime['r10ag_runtime_contract_sha256']==host.CONTRACT_SHA,'CAPTURE_RUNTIME')
    expected=dict(raw_capture_binding={k:capture[k] for k in ['utf8_byte_length','raw_sha256']},
        collection_identity=json.loads(inner['expected_identity']['utf8_text']))
    require(result['expectation']==expected and result['runtime_preflight']['ok'] is True,'PRODUCER_EXPECTATION')
    return expected

def prepare(proposal_path):
    proposal_path=Path(proposal_path).resolve();value=read(proposal_path);check_source(value)
    require(value.get('prepared_context_expectation') is None and 'r10ag_context_producer' not in value,'PROPOSAL_CONTEXT')
    root=proposal_path.parent/'r10ag_context_production';root.mkdir()
    result=native(root,'producer','sdk/adapters/godot/gdscript/r10ag_prepare_launch_context_v1.gd',[proposal_path],{})
    expected=expectation(result)
    record=dict(schema_version='sporespore_r10ag_context_producer_receipt_v1',proposal=bind(proposal_path),
        source_key=bind(candidate.R10AG_ROUTE_ENTRY_PATH),runtime=value['runtime'],expected_context=expected,
        artifacts=[bind(p) for p in sorted(root.iterdir()) if p.is_file()],world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)
    path=proposal_path.parent/PRODUCER;write(path,record)
    return dict(ok=True,expectation=expected,producer=bind(path))

def verify_producer(declaration_path):
    declaration_path=Path(declaration_path).resolve();value=read(declaration_path)
    ref=value['r10ag_context_producer'];require(Path(ref['path']).resolve()==declaration_path.parent/PRODUCER,'PRODUCER_PATH');verify_binding(ref)
    receipt=read(ref['path']);zero(receipt)
    require(receipt['source_key']==bind(candidate.R10AG_ROUTE_ENTRY_PATH) and receipt['runtime']==value['runtime'],'PRODUCER_SOURCE')
    verify_binding(receipt['proposal'])
    for item in receipt['artifacts']:verify_binding(item)
    proposal=read(receipt['proposal']['path']);expected=dict(value);del expected['r10ag_context_producer'];expected['prepared_context_expectation']=None
    require(proposal==expected,'PROPOSAL_DECLARATION')
    result=read(declaration_path.parent/'r10ag_context_production/producer.json')
    require(expectation(result)==receipt['expected_context']==value['prepared_context_expectation'],'DECLARATION_CONTEXT')
    return receipt

def validate_consumer(result,value):
    zero(result)
    require(result['ok'] is True and result['authority_claim_replaced_by_read_only_identity'] is True,'CONSUMER_SCOPE')
    require(result['construction_boundary_reached'] is True and result['configuration']['ok'] is True
        and result['runtime_preflight']['ok'] is True,'PRE_WORLD_SEQUENCE')
    require(result['construction_guard']['failure_code']=='R10AG_NATIVE_WORLD_QUALIFICATION_PENDING'
        and result['construction_guard']['world_build_count']==0,'WORLD_GUARD')
    compare=result['comparison'];require(compare['ok'] is True and compare['expected_capture_binding_matched'] is True
        and compare['expected_capture_binding']==value['prepared_context_expectation']['raw_capture_binding'],'CONSUMER_CONTEXT')
    require(result['terminal_code']=='QSDK_R10F_L9_CHILD_ARM_SETUP_INVALID:kick_passive_recovery_resume','CONSUMER_STOP')
    require(result['candidate_profile']==value['candidate_profile'],'CONSUMER_PROFILE')

def consume(declaration_path,environment_path):
    path=Path(declaration_path).resolve();value=read(path);check_source(value);verify_producer(path)
    environment_path=Path(environment_path).resolve();environment=read(environment_path)['environment']
    require(all(type(k) is str and k.startswith('SPORESPORE_GODOT_RECOVERY_') and type(v) is str for k,v in environment.items()),'ENVIRONMENT')
    require(environment['SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256']==identity.sha(path),'ENVIRONMENT_DECLARATION')
    root=path.parent/'r10ag_pre_world_consumption';root.mkdir()
    result=native(root,'consumer','sdk/adapters/godot/gdscript/r10ag_pre_world_consumer_v1.gd',[path],environment)
    validate_consumer(result,value)
    record=dict(schema_version='sporespore_r10ag_pre_world_handoff_receipt_v1',declaration=bind(path),environment=bind(environment_path),
        producer=value['r10ag_context_producer'],source_key=bind(candidate.R10AG_ROUTE_ENTRY_PATH),
        artifacts=[bind(p) for p in sorted(root.iterdir()) if p.is_file()],
        authority_claim_replaced_by_read_only_identity=True,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)
    target=path.parent/CONSUMER;write(target,record);return dict(ok=True,receipt=bind(target))

def verify(declaration_path):
    path=Path(declaration_path).resolve();value=read(path);verify_producer(path)
    receipt=read(path.parent/CONSUMER);zero(receipt)
    require(receipt['declaration']==bind(path) and receipt['source_key']==bind(candidate.R10AG_ROUTE_ENTRY_PATH)
        and receipt['producer']==value['r10ag_context_producer'],'CONSUMER_RECEIPT')
    verify_binding(receipt['environment'])
    for binding in receipt['artifacts']:verify_binding(binding)
    validate_consumer(read(path.parent/'r10ag_pre_world_consumption/consumer.json'),value)
    return bind(path.parent/CONSUMER)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare',type=Path);mode.add_argument('--consume',type=Path);mode.add_argument('--verify',type=Path)
    parser.add_argument('--environment',type=Path);args=parser.parse_args()
    result=prepare(args.prepare) if args.prepare else consume(args.consume,args.environment) if args.consume else dict(ok=True,receipt=verify(args.verify))
    print(json.dumps(result,separators=(',',':')))
