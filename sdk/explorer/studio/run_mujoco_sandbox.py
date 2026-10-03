"""Qualify and optionally execute one fresh bounded exploratory native child."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import uuid

SDK=Path(__file__).resolve().parents[2]
ROOT=SDK.parent
sys.path.insert(0,str(SDK/'explorer'))
from showcase_owner import OwnedChild, jobs
from showcase_model import StreamIdentity, PROTOCOL, sha, impulse
from sandbox_spec import validate


def write(path,value):
    with path.open('x',encoding='utf-8') as out:json.dump(value,out,indent=2,allow_nan=False)


def source_binding(spec_path):
    paths=list((SDK/'explorer/studio').glob('*.py'))+list((SDK/'explorer/studio').glob('*.gd'))+list((SDK/'adapters/mujoco/sporespore_mujoco_adapter').glob('*.py'))
    paths += [SDK/'explorer/showcase_owner.py',SDK/'explorer/showcase_model.py',SDK/'explorer/test_showcase.py',SDK/'conformance/r10v_windows_job.py',SDK/'python/sporespore_locomotion.py',spec_path]
    paths += list(SDK.glob('*.json')) + list((SDK/'adapters/mujoco').glob('*.json'))
    paths += list((SDK/'explorer').glob('*.gd'))
    catalog=SDK/'explorer/studio/scenario_catalog_v1.json'
    if catalog.exists():
        paths.append(catalog)
        paths += [SDK/row['path'] for row in json.loads(catalog.read_text())['sources']]
    return {str(p.resolve()):sha(p) for p in sorted(set(paths))}


def runtime_binding(cfg):
    paths=[Path(cfg['core']),Path(cfg['mujoco_python'])]
    site=Path(cfg['mujoco_python']).parent.parent/'Lib/site-packages'
    for package in ['mujoco','numpy','numpy.libs']:
        folder=site/package
        paths += [p for p in folder.rglob('*') if p.suffix.lower() in ('.py','.pyd','.dll')]
    if len(paths)<4:raise ValueError('Native dependency inventory incomplete')
    return {str(p.resolve()):sha(p) for p in sorted(set(paths))}


def invoke(command,folder,env,timeout,stop=None):
    folder.mkdir()
    child=OwnedChild(command,ROOT,env,folder)
    try:
        deadline=time.monotonic()+timeout
        while child.process.poll() is None:
            if stop is not None and stop.is_set():raise RuntimeError('Cancelled during qualification')
            if time.monotonic()>deadline:raise TimeoutError('Qualification deadline')
            time.sleep(.05)
        code=child.process.returncode
        if code:raise RuntimeError(f'Qualification failed ({code}): {folder}')
    finally:child.close()


def physical(cfg,spec,spec_path,folder,env,source,*,stop=None,publish=None,commands=None):
    folder.mkdir();session=uuid.uuid4().hex
    server=socket.socket();server.bind(('127.0.0.1',0));server.listen(1);server.settimeout(.2)
    command=[cfg['mujoco_python'],'-B',str(SDK/'explorer/studio/mujoco_sandbox.py'),
        '--spec',str(spec_path),'--output',str(folder),'--connect',f'127.0.0.1:{server.getsockname()[1]}',
        '--session',session,'--source-commit',source,'--permit',str(folder/'contained.permit')]
    child=None;peer=None;started=time.monotonic();guard=StreamIdentity(session,'mujoco',source,False)
    kicks=[];completed=None;ready=False;sent=[]
    def cancelled():
        if stop is not None and stop.is_set():raise RuntimeError('Session cancelled; owned descendants reaped')
    def send(packet):
        with (folder/'commands.jsonl').open('a',encoding='utf-8') as out:out.write(json.dumps(packet)+'\n')
        peer.sendall((json.dumps(packet)+'\n').encode())
        if packet['message_type']=='apply_impulse':sent.append(packet)
    try:
        child=OwnedChild(command,ROOT,env,folder)
        while peer is None:
            cancelled()
            if time.monotonic()-started>60:raise TimeoutError('Native connect deadline')
            if child.process.poll() is not None:raise RuntimeError('Worker exited before connecting')
            try:peer,_=server.accept()
            except socket.timeout:continue
        peer.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
        peer.settimeout(.01);pending=b'';total=0
        with (folder/'stream.jsonl').open('xb') as stream:
            while completed is None:
                cancelled()
                while commands is not None and not commands.empty():
                    request=commands.get_nowait()
                    if len(sent)>=16 or guard.last_frame>=spec['steps']:
                        if publish:publish(dict(message_type='notice',text='Impulse refused: session is ending or its 16-kick limit was reached.'))
                        continue
                    # The native thread chooses its next step on receipt.
                    # The display frame is not an authoritative future clock.
                    packet=impulse(session,guard.last_frame,request['magnitude'],request['direction'],request['command_id'])
                    del packet['apply_at_frame']
                    packet.update(apply_when='next_native_step',
                        owner_received_perf_counter_ns=request['owner_received_perf_counter_ns'],
                        owner_sent_perf_counter_ns=time.perf_counter_ns())
                    send(packet)
                if time.monotonic()-started>150:raise TimeoutError('Native execution deadline')
                try:block=peer.recv(65536)
                except socket.timeout:continue
                if not block:raise RuntimeError('Native stream ended without terminal receipt')
                pending+=block;total+=len(block)
                if total>268435456 or len(pending)>4194304:raise RuntimeError('Stream bound exceeded')
                while b'\n' in pending:
                    line,pending=pending.split(b'\n',1);row=json.loads(line);kind=guard.accept(row)
                    stream.write(line+b'\n');stream.flush()
                    if kind=='hello' and (row.get('command_capabilities',{}).get('next_native_step_torso_impulse') is not True or row.get('interaction_timing_profile')!='studio_next_native_step_perf_counter_ns_v1'):
                        raise RuntimeError('Studio interactive transport capability missing')
                    if kind=='ready_to_start':
                        if ready:raise RuntimeError('Repeated native start gate')
                        ready=True
                        packets=[dict(schema_version=PROTOCOL,message_type='start',session_id=session)]
                        for index,item in enumerate(spec['impulses']):
                            packets.append(dict(schema_version=PROTOCOL,message_type='apply_impulse',session_id=session,
                                command_id=f'sandbox-{index}',target_body_id='torso',apply_at_frame=item['step'],
                                impulse_n_s=dict(zip(['x','y','z'],item['vector_n_s']))))
                        for packet in packets:send(packet)
                    if kind=='frame':kicks.extend(row.get('applied_impulses',[]))
                    if kind=='error':raise RuntimeError(str(row))
                    if kind=='completed':completed=row
                    if publish:publish(row)
        peer.shutdown(socket.SHUT_RDWR)
        if child.process.wait(timeout=15)!=0:raise RuntimeError('Worker exited nonzero')
        if not completed.get('ok') or guard.last_frame!=spec['steps'] or len(kicks)!=len(sent):raise RuntimeError('Incomplete sandbox population')
        return dict(ok=True,session_id=session,last_frame=guard.last_frame,applied_impulses=kicks,completed=completed,
            sent_impulses=sent,stream_sha256=sha(folder/'stream.jsonl'),elapsed_s=time.monotonic()-started)
    finally:
        if peer:peer.close()
        server.close()
        if child:child.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,required=True);parser.add_argument('--spec',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--run',action='store_true')
    args=parser.parse_args();spec=validate(json.loads(args.spec.read_text(encoding='utf-8-sig')))
    cfg=json.loads(args.config.read_text(encoding='utf-8-sig'))
    def git(*words):return subprocess.check_output(['git',*words],cwd=ROOT,text=True).strip()
    if Path(git('rev-parse','--show-toplevel')).resolve()!=ROOT or git('remote','get-url','origin')!='https://github.com/Slagathore/sporespore.git':raise RuntimeError('Repository identity')
    source=git('rev-parse','HEAD')
    if args.run and (git('status','--porcelain') or git('ls-remote','origin','refs/heads/main').split()[0]!=source):raise RuntimeError('Physics requires clean pushed source')
    output=args.output.resolve()
    if not output.is_relative_to(ROOT.parent/'SporeSpore_Evidence'):raise ValueError('Durable evidence root required')
    output.mkdir(parents=True,exist_ok=False)
    create=jobs.api('CreateMutexW',[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api('ReleaseMutex',[W.HANDLE])
    mutex=jobs.checked(create(None,False,'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'));acquired=False
    receipt=dict(ledger_scope=dict(subsystem='explorer',engine_scope='mujoco',authority_mode='development',question_class='development'),
        source_commit=source,spec=spec,source_binding=source_binding(args.spec),runtime_binding=runtime_binding(cfg),
        ok=False,physical_acceptance_authority=False,release_authority=False)
    env={'SPORESPORE_LOCOMOTION_LIBRARY':cfg['core'],'PYTHONDONTWRITEBYTECODE':'1','PYTHONPATH':str(SDK/'adapters/mujoco'),
        'EXPLORER_TEST_CORE':cfg['core'],'EXPLORER_TEST_OUTPUT':str(output)}
    try:
        if jobs.wait(mutex,0) not in (0,128):raise RuntimeError('Native operation mutex occupied')
        acquired=True;write(output/'declaration.json',receipt)
        for name,path in [('ownership-and-stream',SDK/'explorer/test_showcase.py'),('sandbox-boundary',SDK/'explorer/studio/test_sandbox.py')]:
            invoke([cfg['mujoco_python'],'-B',str(path)],output/name,env,90)
        invoke([cfg['mujoco_python'],'-B',str(SDK/'explorer/studio/mujoco_sandbox.py'),'--spec',str(args.spec.resolve()),'--output',str(output),'--check-only'],output/'native-preflight',env,90)
        receipt['preflight']=json.loads((output/'native-preflight/stdout.log').read_text())
        if receipt['preflight'].get('ok') is not True or receipt['preflight']['world_build_count']!=0:raise RuntimeError('Preflight scope')
        if source_binding(args.spec)!=receipt['source_binding'] or runtime_binding(cfg)!=receipt['runtime_binding']:raise RuntimeError('Qualification dependency drift')
        if args.run:receipt['physical']=physical(cfg,spec,args.spec.resolve(),output/'physical',env,source)
        if source_binding(args.spec)!=receipt['source_binding'] or runtime_binding(cfg)!=receipt['runtime_binding']:raise RuntimeError('Execution dependency drift')
        receipt['ok']=True
    except Exception as exc:receipt['error']=f'{type(exc).__name__}: {exc}'
    finally:
        write(output/'receipt.json',receipt)
        if acquired:release(mutex)
        jobs.close(mutex)
    print(json.dumps(dict(ok=receipt['ok'],error=receipt.get('error'),output=str(output),physical_ran='physical' in receipt)))
    return 0 if receipt['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
