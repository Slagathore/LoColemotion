"""Durable R10V host and exact owned cancellation; current lane is zero-world only.

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
PROBE=ROOT/'sdk/conformance/r10v_host_probe.ps1'
SCHEMA='sporespore_r10v_durable_host_request_v1'
CLAIMS=dict(world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def require(value,code):
    if not value:raise ValueError('R10V_HOST_'+code)


def write(path,value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,separators=(',',':'));stream.write('\n');stream.flush();os.fsync(stream.fileno())


def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def binding(path):return files.bind(path)
def utc():return datetime.now(timezone.utc).isoformat()


def request(path):
    path=Path(path).resolve();v=read(path)
    require(path.parent.parent==EVIDENCE.resolve() and path.name=='request.json','REQUEST_PATH')
    require(path.parent.name=='r10v-host-'+v['invocation_id'] and len(v['invocation_id'])==32,'INVOCATION_ID')
    require(v['schema_version']==SCHEMA and v['lane']=='zero_world_host_probe','LANE_NOT_IMPLEMENTED')
    require(type(v['deadline_seconds']) is int and 2<=v['deadline_seconds']<=120,'DEADLINE')
    require(type(v['hold_seconds']) in (int,float) and 0<=v['hold_seconds']<=90,'HOLD')
    require(v['probe_case'] in ('success','nonzero','missing_terminal','malformed_terminal','hang'),'CASE')
    require(v['claims']==CLAIMS,'CLAIMS')
    require(v['command']==[v['runtime']['path'],'-NoLogo','-NoProfile','-File',str(PROBE),'-Request',str(path)],'COMMAND')
    for item in v['bindings']+[v['runtime'],v['python_runtime']]:files.verify(item)
    require(v['bindings']==[binding(SCRIPT),binding(Path(win.__file__)),binding(PROBE)],'SOURCE_BINDINGS')
    return v


def prepare(case='success',hold=0.2,deadline=30):
    root=EVIDENCE/('r10v-host-'+uuid.uuid4().hex);root.mkdir()
    path=root/'request.json';runtime=binding(Path(shutil.which('pwsh')).resolve())
    value=dict(schema_version=SCHEMA,lane='zero_world_host_probe',invocation_id=root.name.removeprefix('r10v-host-'),
        probe_case=case,hold_seconds=hold,deadline_seconds=deadline,created_utc=utc(),runtime=runtime,
        python_runtime=binding(Path(sys.executable).resolve()),bindings=[binding(SCRIPT),binding(Path(win.__file__)),binding(PROBE)],
        source_snapshot=source._source_snapshot(),command=[runtime['path'],'-NoLogo','-NoProfile','-File',str(PROBE),'-Request',str(path)],claims=CLAIMS)
    write(path,value);request(path);return path


def event(root,kind,**data):
    path=root/'events.jsonl'
    with path.open('a',encoding='utf-8',newline='\n') as stream:
        stream.write(json.dumps(dict(utc=utc(),event=kind,**data),separators=(',',':'))+'\n');stream.flush();os.fsync(stream.fileno())


def launch(path):
    path=Path(path).resolve();v=request(path);root=path.parent
    require(source._source_snapshot()==v['source_snapshot'],'SOURCE_CHANGED_BEFORE_LAUNCH')
    write(root/'launch_reservation.json',dict(request=binding(path),created_utc=utc(),retry_authorized=False))
    command=[sys.executable,str(SCRIPT),'--host',str(path)]
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
            worker=subprocess.Popen([sys.executable,str(SCRIPT),'--worker',str(path)],cwd=ROOT,
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
            if job.pids():
                failure=failure or 'R10V_HOST_ORPHAN_DESCENDANT';job.terminate()
            cleanup_deadline=time.monotonic()+10
            while job.pids() and time.monotonic()<cleanup_deadline:time.sleep(0.05)
            require(not job.pids(),'OWNED_CLEANUP_INCOMPLETE')
            event(root,'owned_cleanup_complete',owned_pids=[])
        if not failure:
            require(worker.returncode==0,'SUPERVISOR_NONZERO')
            require((root/'probe_terminal.json').is_file(),'SUPERVISOR_TERMINAL_MISSING')
            try:terminal=read(root/'probe_terminal.json')
            except json.JSONDecodeError as error:raise ValueError('R10V_HOST_SUPERVISOR_TERMINAL_MALFORMED') from error
            require(terminal==dict(invocation_id=v['invocation_id'],ok=True,world_build_count=0,solver_step_count=0),'SUPERVISOR_TERMINAL')
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
    receipt=dict(schema_version='sporespore_r10v_durable_host_result_v1',request=requested,
        host_identity=me,ok=not failure and cleanup_complete,failure_code=failure,
        worker_exit_code=None if worker is None else worker.returncode,owned_cleanup_complete=cleanup_complete,
        elapsed_seconds=time.monotonic()-started,completed_utc=utc(),source_unchanged=source._source_snapshot()==v['source_snapshot'],
        primary_terminal=binding(root/'probe_terminal.json') if (root/'probe_terminal.json').is_file() else None,
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
        require(result['schema_version']=='sporespore_r10v_durable_host_result_v1' and result['request']==binding(path)
            and result['host_identity']==identity,'TERMINAL_IDENTITY')
        require(type(result['ok']) is bool and result['owned_cleanup_complete'] is True,'TERMINAL_CLEANUP')
        require(result['logs']==[binding(root/n) for n in ('supervisor.stdout.txt','supervisor.stderr.txt')],'TERMINAL_LOGS')
        require(all(result.get(k)==x for k,x in CLAIMS.items()),'TERMINAL_CLAIMS')
        if result['primary_terminal'] is not None:files.verify(result['primary_terminal'])
        if result['ok']:
            require(result['source_unchanged'] is True and result['worker_exit_code']==0,'TERMINAL_SUCCESS')
            require(result['primary_terminal']==binding(root/'probe_terminal.json'),'TERMINAL_PRIMARY')
            require(read(root/'probe_terminal.json')==dict(invocation_id=v['invocation_id'],ok=True,world_build_count=0,solver_step_count=0),'TERMINAL_PRIMARY_CONTENT')
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
    parser.add_argument('--linger-caller',action='store_true');args=parser.parse_args()
    if args.host:return run_host(args.host)
    if args.worker:return gated_worker(args.worker)
    result=launch(args.launch) if args.launch else status(args.status)
    print(json.dumps(result),flush=True)
    if args.linger_caller:time.sleep(90)
    return 0


if __name__=='__main__':raise SystemExit(main())
