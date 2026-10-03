"""Durable R10V host and exact owned cancellation; production and zero-world lanes are explicit.

The detached host owns a kill-on-close job. Its gated child cannot start the
supervisor until job membership is established. No retry or receipt repair exists.
"""
import argparse
from datetime import datetime,timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid
import development_passive_entry_profile as source
import r10s_launch_component as files
import r10v_windows_job as win

ROOT,EVIDENCE=files.ROOT,files.EVIDENCE
SCRIPT=Path(__file__).resolve()
PROBE=ROOT/'sdk/conformance/r10v_host_probe_v2.ps1'
SCHEMA='sporespore_r10v_durable_host_request_v2'
CLAIMS=dict(physical_acceptance_authority=False,release_authority=False)
PYTHON=Path('C:/Program Files/Python311/python.exe')
PWSH=Path('C:/Program Files/PowerShell/7/pwsh.exe')
WRAPPER=ROOT/'sdk/run_r10v_durable_recovery.ps1'
LAUNCHER=ROOT/'sdk/run_development_recovery_smoke.ps1'
PROFILE=ROOT/'sdk/development/recovery_candidates/r10v-v56-post-recovery-hold-integrated-v2.json'
CONTRACT=ROOT/'sdk/development/r10v_production_host_contract_v2.json'
PREFIX='r10v-production-host-'
LANES=('zero_world_host_probe','production_interface_probe','production_gate','production_smoke')


def require(value,code):
    if not value:raise ValueError('R10V_HOST_'+code)


def write(path,value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,separators=(',',':'));stream.write('\n');stream.flush();os.fsync(stream.fileno())


def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def binding(path):return files.bind(path)
def utc():return datetime.now(timezone.utc).isoformat()


def runtime(item, canonical):
    require(item==binding(canonical),'CANONICAL_RUNTIME')
    files.verify(item)


def source_bindings():
    return [binding(p) for p in (SCRIPT,Path(win.__file__),PROBE,WRAPPER,LAUNCHER,PROFILE,CONTRACT,ROOT/'sdk/r10v_host_progress.ps1')]


def command(path, value):
    script=PROBE if value['lane']=='zero_world_host_probe' else WRAPPER
    return [str(PWSH),'-NoLogo','-NoProfile','-File',str(script),'-Request',str(path)]


def request(path):
    path=Path(path).resolve();v=read(path)
    require(path.parent.parent==EVIDENCE.resolve() and path.name=='request.json','REQUEST_PATH')
    require(type(v.get('invocation_id')) is str and path.parent.name==PREFIX+v['invocation_id']
        and len(v['invocation_id'])==32 and all(x in '0123456789abcdef' for x in v['invocation_id']),'INVOCATION_ID')
    require(v['schema_version']==SCHEMA and v['lane'] in LANES,'LANE_NOT_IMPLEMENTED')
    runtime(v['runtime'],PWSH);runtime(v['python_runtime'],PYTHON)
    require(Path(sys.executable).resolve()==PYTHON.resolve(),'HOST_PYTHON_IMAGE')
    require(v['claims']==CLAIMS,'CLAIMS')
    require(v['command']==command(path,v),'COMMAND')
    require(v['bindings']==source_bindings(),'SOURCE_BINDINGS')
    for item in v['bindings']:files.verify(item)
    fixed=read(CONTRACT)
    if v['lane']=='zero_world_host_probe':
        require(type(v['deadline_seconds']) is int and 2<=v['deadline_seconds']<=120,'DEADLINE')
        require(type(v['hold_seconds']) in (int,float) and 0<=v['hold_seconds']<=90,'HOLD')
        require(v['probe_case'] in ('success','nonzero','missing_terminal','malformed_terminal','hang','orphan'),'CASE')
    else:
        require(v['probe_case'] in (('success','python_nonzero','python_timeout') if v['lane']=='production_interface_probe' else ('success',)) and v['hold_seconds']==0,'PRODUCTION_PROBE_OPTIONS')
        require(type(v['deadline_seconds']) is int and v['deadline_seconds']==fixed['lane_deadlines_seconds'][v['lane']],'DEADLINE')
    require(v['candidate_profile']==binding(PROFILE),'CANDIDATE')
    require(type(v['attempt_id']) is str and len(v['attempt_id'])==32
        and all(x in '0123456789abcdef' for x in v['attempt_id']) and v['attempt_id']!=v['invocation_id'],'ATTEMPT')
    require(type(v['seed']) is int and v['seed'] in (41345,41346,41341,41343),'SEED')
    if v['seed']==41345:require(v['prerequisite_root'] is None,'PAIR_PREREQUISITE')
    else:
        require(type(v['prerequisite_root']) is str,'SINGLE_PREREQUISITE')
        import r10v_development as development
        import development_recovery_candidate as candidate
        development.qualify_prerequisite(Path(v['prerequisite_root']),candidate.reference_for_path(PROFILE),paired=True)
    if v['lane'] in ('production_gate','production_smoke'):
        require(type(v.get('prehost_qualification')) is dict,'PREHOST_REQUIRED')
        import r10v_prehost_qualification as qualification
        require(qualification.verify(v['prehost_qualification']['path'])['receipt']==v['prehost_qualification'],'PREHOST_BINDING')
    else:require(v.get('prehost_qualification') is None,'PROBE_PREHOST_NOT_ALLOWED')
    return v


def prepare(case='success',hold=0.2,deadline=30,*,lane='zero_world_host_probe',seed=41345,prerequisite_root=None,prehost_qualification=None):
    require(lane in LANES,'LANE_NOT_IMPLEMENTED')
    prehost=None
    if lane in ('production_gate','production_smoke'):
        require(prehost_qualification is not None,'PREHOST_REQUIRED')
        import r10v_prehost_qualification as qualification
        prehost=qualification.verify(prehost_qualification)['receipt']
    else:require(prehost_qualification is None,'PROBE_PREHOST_NOT_ALLOWED')
    root=EVIDENCE/(PREFIX+uuid.uuid4().hex);root.mkdir();path=root/'request.json'
    if lane!='zero_world_host_probe':
        require(case in (('success','python_nonzero','python_timeout') if lane=='production_interface_probe' else ('success',)),'PRODUCTION_PROBE_OPTIONS')
        hold=0;deadline=read(CONTRACT)['lane_deadlines_seconds'][lane]
    snapshot=source._source_snapshot()
    if lane=='production_smoke':
        import r10v_development_launch as guard
        guard.current_freeze(snapshot['head'])
    value=dict(schema_version=SCHEMA,lane=lane,invocation_id=root.name.removeprefix(PREFIX),
        attempt_id=uuid.uuid4().hex,seed=seed,prerequisite_root=None if prerequisite_root is None else str(Path(prerequisite_root).resolve()),
        candidate_profile=binding(PROFILE),probe_case=case,hold_seconds=hold,deadline_seconds=deadline,
        created_utc=utc(),runtime=binding(PWSH),python_runtime=binding(PYTHON),bindings=source_bindings(),
        source_snapshot=snapshot,prehost_qualification=prehost,claims=CLAIMS)
    value['command']=command(path,value)
    write(path,value);request(path);return path


def supervisor_context(path, pid, *, register=False, live=True):
    path=Path(path).resolve();v=request(path);root=path.parent
    started=read(root/'supervisor_started.json');assigned=read(root/'job_assigned.json');host=read(root/'host_started.json')
    require(started['request']==assigned['request']==host['request']==binding(path),'SUPERVISOR_REQUEST')
    require(started['supervisor_identity']['pid']==pid and assigned['host_identity']==host['host_identity'],'SUPERVISOR_IDENTITY')
    if live:
        require(win.alive(started['supervisor_identity']) and win.alive(assigned['host_identity'])
            and win.alive(assigned['worker_identity']) and win.current_in_job(),'SUPERVISOR_NOT_OWNED_OR_LIVE')
        require(source._source_snapshot()==v['source_snapshot'],'SUPERVISOR_SOURCE_DRIFT')
    value=dict(schema_version='sporespore_r10v_production_host_context_v1',request=binding(path),
        invocation_id=v['invocation_id'],attempt_id=v['attempt_id'],lane=v['lane'],seed=v['seed'],
        host_identity=assigned['host_identity'],worker_identity=assigned['worker_identity'],
        supervisor_identity=started['supervisor_identity'],physical_acceptance_authority=False,release_authority=False)
    if register:write(root/'supervisor_context.json',value)
    else:require(read(root/'supervisor_context.json')==value,'SUPERVISOR_CONTEXT')
    return value


def declaration_context(declaration, *, live=False):
    value=declaration.get('r10v_host');require(type(value) is dict,'DECLARATION_CONTEXT_MISSING')
    path=Path(value['request']['path']);files.verify(value['request']);v=request(path)
    require(v['lane']=='production_smoke' and v['attempt_id']==declaration['attempt_id']
        and v['seed']==declaration['seed'] and v['source_snapshot']['head']==declaration['source_snapshot']['head'],'DECLARATION_INVOCATION')
    expected=supervisor_context(path,value['supervisor_identity']['pid'],live=live)
    require(value==expected,'DECLARATION_CONTEXT_CROSSED')
    return expected


def validate_progress(path,v):
    if v['lane']=='zero_world_host_probe':return None
    root=path.parent;target=root/'progress.jsonl'
    require(target.is_file(),'PROGRESS_MISSING')
    rows=[json.loads(line) for line in target.read_text(encoding='utf-8').splitlines()]
    context=read(root/'supervisor_context.json')
    roles=['matched_no_kick_continuation','kick_passive_recovery_resume'] if v['seed']==41345 else ['kick_passive_recovery_resume']
    if v['lane']=='production_interface_probe':stages=[('interface',''),('interface_python','')]
    else:
        stages=[('safety_gate','')]
        if v['lane']=='production_smoke':stages += [('child',r) for r in roles]+[('replay',r) for r in roles]+[('final_audit','')]
        stages += [('publication','')]
    expected=[(stage,state,role) for stage,role in stages for state in ('start','end')]
    require([(x['stage'],x['state'],x['role']) for x in rows]==expected,'PROGRESS_SEQUENCE')
    for index,row in enumerate(rows):
        require(type(row['sequence']) is int and row['sequence']==index and row['context']==context
            and row['source_commit']==v['source_snapshot']['head']
            and row['runtimes']==dict(python=v['python_runtime'],powershell=v['runtime']),'PROGRESS_BINDING')
        if row['state']=='end' and row['stage'] in ('interface_python','replay','final_audit'):
            sub=row['subject'];start=rows[index-1]['subject']
            require(sub['process_identity']==start['process_identity'] and sub['exit_code']==0
                and sub['timed_out'] is False,'PROGRESS_PROCESS_RESULT')
            for name in ('stdout','stderr'):files.verify(sub[name])
        elif row['state']=='end' and row['stage']=='child':
            sub=row['subject'];files.verify(sub['envelope'])
            require(sub['exit_code']==0 and sub['child_attempt_id']==rows[index-1]['subject']['child_attempt_id'],'PROGRESS_CHILD_RESULT')
            proof=source.packet.parse_json(sub['launch_relationship']['payload_json'])
            require(proof['context']['parent_attempt_id']==v['attempt_id']
                and proof['context']['child_attempt_id']==sub['child_attempt_id']
                and proof['context']['role']==row['role'] and proof['process_chain'],'PROGRESS_CHILD_IDENTITY')
        elif row['state']=='end' and row['stage']=='publication':
            require(row['subject']['terminal']==binding(primary_path(path,v)),'PROGRESS_TERMINAL')
            files.verify(row['subject']['marker'])
    return binding(target)


def primary_path(path,v):
    if v['lane'] in ('zero_world_host_probe','production_interface_probe'):return path.parent/'probe_terminal.json'
    return EVIDENCE/('development-recovery-smoke-'+v['attempt_id'])/'supervisor_result.json'


def validate_primary(path,v):
    primary=primary_path(path,v);require(primary.is_file(),'SUPERVISOR_TERMINAL_MISSING')
    try:terminal=read(primary)
    except json.JSONDecodeError as error:raise ValueError('R10V_HOST_SUPERVISOR_TERMINAL_MALFORMED') from error
    if v['lane'] in ('zero_world_host_probe','production_interface_probe'):
        expected=dict(invocation_id=v['invocation_id'],ok=True,world_build_count=0,solver_step_count=0)
        if v['lane']=='production_interface_probe':
            expected['interface_receipt']=binding(path.parent/'interface_receipt.json')
            interface=read(path.parent/'interface_receipt.json')
            context=supervisor_context(path,interface['host_context']['supervisor_identity']['pid'],live=False)
            require(interface['host_context']==context and interface['worker']=='res://sdk/adapters/godot/gdscript/r10v_recovery_worker_v1.gd'
                and interface['seed']==v['seed'] and interface['world_build_count']==interface['solver_step_count']==0,'INTERFACE_SELECTION')
        require(terminal==expected,'SUPERVISOR_TERMINAL')
    else:
        context=read(path.parent/'supervisor_context.json')
        require(context==supervisor_context(path,context['supervisor_identity']['pid'],live=False),'TERMINAL_CONTEXT')
        require(terminal.get('schema_version')=='sporespore_sdk1_development_recovery_smoke_run_v1'
            and terminal.get('ok') is True and terminal.get('failure_code')==''
            and Path(terminal['output_root']).resolve()==primary.parent
            and terminal.get('r10v_host')==context,'SUPERVISOR_TERMINAL')
        require(terminal.get('physical_acceptance_authority') is False and terminal.get('release_authority') is False
            and terminal.get('official_qualification_passed') is False,'SUPERVISOR_CLAIMS')
        require(terminal.get('run_smoke_requested') is (v['lane']=='production_smoke'),'SUPERVISOR_MODE')
        marker=(primary.parent/'published_marker.txt').read_text(encoding='utf-8').strip()
        prefix='DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
        require(marker.startswith(prefix) and source.packet.same(source.packet.parse_json(marker[len(prefix):]),terminal),'SUPERVISOR_PUBLICATION')
        if v['lane']=='production_gate':
            require(terminal.get('physical_attempt_started') is False and terminal.get('children')==[],'GATE_PHYSICAL_ACTIVITY')
    validate_progress(path,v)
    return binding(primary)


def event(root,kind,**data):
    path=root/'events.jsonl'
    with path.open('a',encoding='utf-8',newline='\n') as stream:
        stream.write(json.dumps(dict(utc=utc(),event=kind,**data),separators=(',',':'))+'\n');stream.flush();os.fsync(stream.fileno())


def launch(path):
    path=Path(path).resolve();v=request(path);root=path.parent
    require(source._source_snapshot()==v['source_snapshot'],'SOURCE_CHANGED_BEFORE_LAUNCH')
    write(root/'launch_reservation.json',dict(request=binding(path),created_utc=utc(),retry_authorized=False))
    command=[str(PYTHON),'-B',str(SCRIPT),'--host',str(path)]
    with (root/'host.stdout.txt').open('xb') as out,(root/'host.stderr.txt').open('xb') as err:
        # Break away from a caller job or refuse; never silently inherit caller lifetime.
        process=subprocess.Popen(command,cwd=ROOT,stdin=subprocess.DEVNULL,stdout=out,stderr=err,
            close_fds=True,creationflags=0x01000000|0x00000008|0x00000200)
    actual=win.identity(process.pid);require(actual is not None,'HOST_IDENTITY')
    actual.pop('running')
    write(root/'launch.json',dict(request=binding(path),host_identity=actual,command=command,created_utc=utc()))
    return dict(root=str(root),host_identity=actual)


def gated_worker(path):
    path=Path(path).resolve();v=request(path);root=path.parent
    deadline=time.monotonic()+15
    while not (root/'job_assigned.json').exists():
        require(time.monotonic()<deadline,'JOB_ASSIGNMENT_TIMEOUT');time.sleep(0.05)
    assigned=read(root/'job_assigned.json')
    require(assigned['worker_identity']==win.current_identity() and assigned['request']==binding(path),'JOB_ASSIGNMENT_IDENTITY')
    require(win.current_in_job(),'WORKER_NOT_IN_JOB')
    require(source._source_snapshot()==v['source_snapshot'],'SOURCE_CHANGED_BEFORE_COMMAND')
    environment={k:x for k,x in os.environ.items() if not k.startswith('SPORESPORE_GODOT_RECOVERY_')}
    child=subprocess.Popen(v['command'],cwd=ROOT,env=environment,stdin=subprocess.DEVNULL,
        stdout=sys.stdout,stderr=sys.stderr,creationflags=subprocess.CREATE_NO_WINDOW)
    actual=win.identity(child.pid);require(actual is not None,'SUPERVISOR_START_IDENTITY');actual.pop('running')
    write(root/'supervisor_started.json',dict(request=binding(path),supervisor_identity=actual,command=v['command']))
    event(root,'supervisor_started',pid=child.pid,command=v['command'])
    code=child.wait();event(root,'supervisor_exited',pid=child.pid,exit_code=code)
    return code


def run_host(path):
    path=Path(path).resolve();v=request(path);root=path.parent
    require(not win.current_in_job(),'HOST_IN_CALLER_JOB')
    me=win.current_identity();write(root/'host_started.json',dict(host_identity=me,request=binding(path),started_utc=utc(),in_caller_job=False))
    requested=binding(path)
    started=time.monotonic();worker=None;job=None;failure='';cancel_seen=False
    try:
        require(source._source_snapshot()==v['source_snapshot'],'SOURCE_CHANGED_BEFORE_HOST')
        job=win.Job()
        with (root/'supervisor.stdout.txt').open('xb') as out,(root/'supervisor.stderr.txt').open('xb') as err:
            worker=subprocess.Popen([str(PYTHON),'-B',str(SCRIPT),'--worker',str(path)],cwd=ROOT,
                stdin=subprocess.DEVNULL,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
            job.add(worker)
            identity=win.identity(worker.pid);require(identity is not None,'WORKER_IDENTITY');identity.pop('running')
            write(root/'job_assigned.json',dict(worker_identity=identity,host_identity=me,request=binding(path),kill_on_job_close=True))
            event(root,'job_assigned',worker_identity=identity,owned_pids=job.pids())
            next_source_check=0
            while worker.poll() is None:
                if time.monotonic()-started>v['deadline_seconds']:
                    failure='R10V_HOST_DEADLINE';break
                if (root/'cancel.json').exists() and not cancel_seen:
                    cancel_seen=True
                    try:
                        cancel=read(root/'cancel.json')
                        require(cancel==dict(invocation_id=v['invocation_id'],host_identity=me,request=binding(path)),'CANCEL_IDENTITY')
                        failure='R10V_HOST_CANCELLED';break
                    except (ValueError,KeyError,TypeError) as error:event(root,'cancel_refused',reason=str(error))
                if time.monotonic()>=next_source_check:
                    require(binding(path)==requested,'REQUEST_CHANGED_DURING_HOST')
                    require(source._source_snapshot()==v['source_snapshot'],'SOURCE_CHANGED_DURING_HOST')
                    next_source_check=time.monotonic()+2
                time.sleep(0.1)
            if failure:
                event(root,'owned_termination',reason=failure,owned_pids=job.pids());job.terminate()
            worker.wait(timeout=10)
            remaining=job.pids()
            if remaining and not failure:
                event(root,'owned_cleanup_drain',owned_pids=remaining,identities=[win.identity(pid) for pid in remaining])
                drain_deadline=time.monotonic()+10
                while job.pids() and time.monotonic()<drain_deadline:time.sleep(0.05)
            if job.pids():
                event(root,'owned_orphans_refused',owned_pids=job.pids())
                failure=failure or 'R10V_HOST_ORPHAN_DESCENDANT';job.terminate()
            cleanup_deadline=time.monotonic()+10
            while job.pids() and time.monotonic()<cleanup_deadline:time.sleep(0.05)
            require(not job.pids(),'OWNED_CLEANUP_INCOMPLETE')
            event(root,'owned_cleanup_complete',owned_pids=[])
        if not failure:
            require(worker.returncode==0,'SUPERVISOR_NONZERO')
            validate_primary(path,v)
        require(binding(path)==requested,'REQUEST_CHANGED_AFTER_HOST')
        require(source._source_snapshot()==v['source_snapshot'],'SOURCE_CHANGED_AFTER_HOST')
    except (OSError,ValueError,KeyError,TypeError,subprocess.TimeoutExpired) as error:
        failure=failure or str(error)
    finally:
        if job is not None:
            if worker is not None and worker.poll() is None and worker.pid not in job.pids():
                worker.kill();worker.wait(timeout=10)
            if job.pids():
                job.terminate()
                if worker is not None:worker.wait(timeout=10)
                deadline=time.monotonic()+10
                while job.pids() and time.monotonic()<deadline:time.sleep(0.05)
            cleanup_complete=not job.pids();job.close()
        else:cleanup_complete=worker is None
    receipt=dict(schema_version='sporespore_r10v_durable_host_result_v2',request=requested,
        host_identity=me,ok=not failure and cleanup_complete,failure_code=failure,
        worker_exit_code=None if worker is None else worker.returncode,owned_cleanup_complete=cleanup_complete,
        elapsed_seconds=time.monotonic()-started,completed_utc=utc(),source_unchanged=source._source_snapshot()==v['source_snapshot'],
        primary_terminal=binding(primary_path(path,v)) if primary_path(path,v).is_file() else None,
        progress_log=binding(root/'progress.jsonl') if (root/'progress.jsonl').is_file() else None,
        logs=[binding(root/n) for n in ('supervisor.stdout.txt','supervisor.stderr.txt') if (root/n).exists()],**CLAIMS)
    write(root/'host_result.json',receipt)
    event(root,'terminal_written',binding=binding(root/'host_result.json'))
    write(root/'published.json',dict(request=requested,host_identity=me,host_result=binding(root/'host_result.json')))
    return 0 if receipt['ok'] else 1


def status(root):
    root=Path(root).resolve();path=root/'request.json';v=request(path);launched=read(root/'launch.json')
    require(launched['request']==binding(path),'LAUNCH_REQUEST')
    identity=launched['host_identity']
    if (root/'host_started.json').exists():
        started=read(root/'host_started.json')
        require(started['host_identity']==identity and started['request']==binding(path),'HOST_START_IDENTITY')
    if (root/'host_result.json').exists():
        require((root/'host_started.json').is_file(),'HOST_START_MISSING')
        result=read(root/'host_result.json')
        require(result['schema_version']=='sporespore_r10v_durable_host_result_v2' and result['request']==binding(path)
            and result['host_identity']==identity,'TERMINAL_IDENTITY')
        require(type(result['ok']) is bool and result['owned_cleanup_complete'] is True,'TERMINAL_CLEANUP')
        require(result['logs']==[binding(root/n) for n in ('supervisor.stdout.txt','supervisor.stderr.txt')],'TERMINAL_LOGS')
        require(all(result.get(k)==x for k,x in CLAIMS.items()),'TERMINAL_CLAIMS')
        if result['primary_terminal'] is not None:files.verify(result['primary_terminal'])
        if result.get('progress_log') is not None:files.verify(result['progress_log'])
        if result['ok']:
            require(result['source_unchanged'] is True and result['worker_exit_code']==0,'TERMINAL_SUCCESS')
            require(result['primary_terminal']==validate_primary(path,v),'TERMINAL_PRIMARY')
        if not (root/'published.json').exists():
            return dict(state='publishing' if win.alive(identity) else 'incomplete',host_identity=identity)
        require(read(root/'published.json')==dict(request=binding(path),host_identity=identity,host_result=binding(root/'host_result.json')),'PUBLICATION_BINDING')
        return dict(state='complete' if result['ok'] else 'failed',result=result,host_alive=win.alive(identity))
    return dict(state='running' if win.alive(identity) else 'incomplete',host_identity=identity)


def cancel(root,expected):
    root=Path(root).resolve();v=request(root/'request.json');launched=read(root/'launch.json')
    require(launched['host_identity']==expected,'CANCEL_CROSSED_HOST')
    require(status(root)['state']=='running','CANCEL_NOT_RUNNING')
    write(root/'cancel.json',dict(invocation_id=v['invocation_id'],host_identity=expected,request=binding(root/'request.json')))


def main():
    parser=argparse.ArgumentParser();mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--launch');mode.add_argument('--host');mode.add_argument('--worker');mode.add_argument('--status')
    mode.add_argument('--prepare',choices=LANES);mode.add_argument('--register-supervisor');mode.add_argument('--context')
    parser.add_argument('--supervisor-pid',type=int);parser.add_argument('--seed',type=int,default=41345)
    parser.add_argument('--prehost-qualification');parser.add_argument('--prerequisite-root');parser.add_argument('--linger-caller',action='store_true');args=parser.parse_args()
    if args.host:return run_host(args.host)
    if args.worker:return gated_worker(args.worker)
    if args.prepare:result=dict(request=str(prepare(lane=args.prepare,seed=args.seed,prerequisite_root=args.prerequisite_root,prehost_qualification=args.prehost_qualification)))
    elif args.register_supervisor or args.context:
        result=supervisor_context(args.register_supervisor or args.context,args.supervisor_pid,register=bool(args.register_supervisor))
    else:result=launch(args.launch) if args.launch else status(args.status)
    print(json.dumps(result),flush=True)
    if args.linger_caller:time.sleep(90)
    return 0


if __name__=='__main__':raise SystemExit(main())
