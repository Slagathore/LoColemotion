"""Fresh pre-host safety receipts; no physical execution or acceptance authority."""
import argparse
import json
import os
from pathlib import Path
import re
import time
import uuid
import development_passive_entry_profile as source
import development_recovery_candidate as candidate
import r10t_route_integration_component as files
import r10v_windows_job as win
import r10x_campaign_authority as authority
import r10x_dependency_manifest as manifest
import r10x_safety_gate as safety

ROOT,EVIDENCE=files.ROOT,files.EVIDENCE
CONTRACT=ROOT/'sdk/development/r10x_safety_stage_contract_v1.json'
PYTHON=Path('C:/Program Files/Python311/python.exe')
PWSH=Path('C:/Program Files/PowerShell/7/pwsh.exe')
CLAIMS=dict(world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def require(value,code):
    if not value: raise ValueError('R10X_PREHOST_'+code)


def specs():
    contract=files.read(CONTRACT)
    return [s for s in contract['stages'] if s['id'] in contract['prehost_stage_ids']]


def validate_timing_provenance(contract):
    files.verify(contract['inherited_timing_contract'])
    inherited=files.read(contract['inherited_timing_contract']['path'])
    require(contract['startup_timing_evidence']==inherited['startup_timing_evidence']
        and contract['native_startup_timeouts_seconds']==inherited['native_startup_timeouts_seconds'],'TIMING_PROVENANCE')
    for item in contract['startup_timing_evidence'].values(): files.verify(item)


def dependencies():
    validate_timing_provenance(files.read(CONTRACT))
    key=candidate.R10V_ROUTE_ENTRY_PATH
    value=files.read(key)
    require(value['source_key_complete'] is True,'INCOMPLETE_KEY')
    for item in value['bound_source_files']:
        require(files.bind(ROOT/item['path'])['raw_sha256']==item['raw_sha256'],'SOURCE_KEY_CHANGED')
    return dict(production_route_key=manifest.snapshot()['production_route_key'],source_key=files.bind(key),contract=files.bind(CONTRACT),
        python=files.bind(PYTHON),powershell=files.bind(PWSH))


def directory(path):
    path=Path(path).resolve()
    require(path.parent==EVIDENCE.resolve() and re.fullmatch(r'r10x-prehost-[0-9a-f]{32}',path.name),'ROOT')
    return path


def begin():
    key=dependencies();snapshot=source._source_snapshot()
    root=EVIDENCE/('r10x-prehost-'+uuid.uuid4().hex);root.mkdir()
    files.write_new(root/'request.json',dict(schema_version='sporespore_r10x_prehost_request_v1',
        dependencies=key,source_snapshot=snapshot,stage_specs=specs(),**CLAIMS))
    return dict(root=root.as_posix())


def validate_stages(root,stages):
    safety.validate_stages(root,stages,specs())


def source_compatible(original,current):
    """Only the clean F -> qualification-only Q -> authority-only A graph can reuse F.

    The caller independently verifies the exact complete dependency key. No
    recursive qualification or authority evaluation is performed here.
    """
    if authority.same(original,current): return True
    if not isinstance(original,dict) or not isinstance(current,dict): return False
    if any(x.get('status') != '' or x.get('changed_files') != [] for x in (original,current)): return False
    if original.get('remote') != authority.REMOTE or current.get('remote') != authority.REMOTE: return False
    start,end=original.get('head'),current.get('head')
    if not all(type(x) is str and re.fullmatch('[0-9a-f]{40}',x) for x in (start,end)): return False
    chain=authority.git('rev-list','--reverse',start+'..'+end).splitlines()
    if not 1<=len(chain)<=2: return False
    parent=start
    for commit,path in zip(chain,(authority.QUALIFICATION_PATH,authority.AUTHORITY_PATH)):
        if authority.git('show','-s','--format=%P',commit).split()!=[parent]: return False
        if authority.git('diff-tree','--no-commit-id','--name-only','-r',commit).splitlines()!=[path]: return False
        parent=commit
    return parent==end


def owned_quiescent(root):
    registry=root/'owned_requests.jsonl'
    require(registry.is_file(),'OWNED_REGISTRY_MISSING')
    entries=[json.loads(line) for line in registry.read_text(encoding='utf-8').splitlines()]
    require(entries and len({x['path'] for x in entries})==len(entries),'OWNED_REGISTRY')
    for item in entries:
        # Some negative controls intentionally cross request bytes. The registry
        # binds the path before launch; process ownership comes from original starts.
        request=Path(item['path']);require(request.parent.parent==EVIDENCE.resolve()
            and re.fullmatch(r'r10x-production-host-[0-9a-f]{32}',request.parent.name)
            and request.name=='request.json','OWNED_REQUEST_PATH')
        for name,keys in [('host_started.json',('host_identity',)),('job_assigned.json',('host_identity','worker_identity')),
                          ('supervisor_started.json',('supervisor_identity',))]:
            path=request.parent/name
            if path.exists():
                value=files.read(path)
                for key in keys:
                    if win.alive(value[key]): return False
    return True


def finish(root):
    root=directory(root);request=files.read(root/'request.json')
    failure='';stages=files.read(root/'stages.json')
    try:
        require(request['dependencies']==dependencies(),'DEPENDENCIES_CHANGED')
        require(request['source_snapshot']==source._source_snapshot(),'SOURCE_CHANGED')
        require(request['stage_specs']==specs(),'SPEC_CHANGED')
        validate_stages(root,stages)
    except Exception as error: failure=str(error)
    # Every owned test host has an independent bounded deadline and kill-on-close
    # job. Wait for those original owners; never infer cleanup from a test exit.
    end=time.monotonic()+150
    while not owned_quiescent(root) and time.monotonic()<end: time.sleep(.2)
    quiescent=owned_quiescent(root)
    if not quiescent: failure=failure or 'R10X_PREHOST_OWNED_PROCESS_STILL_LIVE'
    record=dict(schema_version='sporespore_r10x_prehost_qualification_v1',ok=not failure,
        request=files.bind(root/'request.json'),dependencies=request['dependencies'],
        source_snapshot=request['source_snapshot'],stages=stages,
        owned_registry=files.bind(root/'owned_requests.jsonl'),owned_cleanup_complete=quiescent,
        failure_code=failure,**CLAIMS)
    files.write_new(root/'qualification.json',record)
    require(not failure,'FAILED:'+failure)
    return verify(root/'qualification.json')


def verify(path, *, source_snapshot=None):
    path=Path(path).resolve();root=directory(path.parent)
    require(path.name=='qualification.json','RECEIPT_PATH')
    value=files.read(path)
    require(value.get('schema_version')=='sporespore_r10x_prehost_qualification_v1' and value.get('ok') is True,'NOT_PASSED')
    require(all(type(value.get(k)) is type(v) and value.get(k)==v for k,v in CLAIMS.items()),'CLAIMS')
    require(value['dependencies']==dependencies(),'DEPENDENCIES_CHANGED')
    require(source_compatible(value['source_snapshot'],source._source_snapshot() if source_snapshot is None else source_snapshot),'SOURCE_CHANGED')
    require(value['request']==files.bind(root/'request.json'),'REQUEST_BYTES')
    request=files.read(root/'request.json')
    require(request['dependencies']==value['dependencies'] and request['source_snapshot']==value['source_snapshot']
        and request['stage_specs']==specs(),'REQUEST_CONTEXT')
    require(value['owned_registry']==files.bind(root/'owned_requests.jsonl')
        and value['owned_cleanup_complete'] is True and owned_quiescent(root),'OWNED_CLEANUP')
    validate_stages(root,value['stages'])
    return dict(ok=True,receipt=files.bind(path),stages=value['stages'],**CLAIMS)


def import_stages(path,target):
    target=Path(target).resolve()
    require(target.parent==EVIDENCE.resolve() and re.fullmatch(r'r10x-(zero-world-check|production-ghost)-[0-9a-f]{32}',target.name),'TARGET')
    result=verify(path);root=Path(path).parent
    for stage in result['stages']:
        for stream in ('stdout','stderr'):
            with (target/stage[stream]).open('xb') as out:out.write((root/stage[stream]).read_bytes())
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser();mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--begin',action='store_true');mode.add_argument('--finish');mode.add_argument('--verify');mode.add_argument('--import-stages')
    parser.add_argument('--target');args=parser.parse_args()
    print(json.dumps(begin() if args.begin else finish(args.finish) if args.finish else
        verify(args.verify) if args.verify else import_stages(args.import_stages,args.target)))
