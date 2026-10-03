"""Desktop successor: edited-body MuJoCo exploration with retained native data."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import uuid

SDK=Path(__file__).resolve().parents[2];ROOT=SDK.parent
sys.path.insert(0,str(SDK/'explorer'))
from showcase_owner import Owner, jobs, write
from showcase_model import FIELDS, S169, impulse
from sandbox_spec import SCHEMA,validate
from run_mujoco_sandbox import source_binding,runtime_binding,invoke,physical
from scenario_catalog import load as load_catalog
from studio_layout import EVIDENCE,verify_source


class StudioOwner(Owner):
    def preview(self,descriptor):
        super().preview(descriptor)
        compiled=self.compiler.compile(descriptor)
        write(self.folder/'preview.json',dict(revision=self.preview_revision,descriptor=descriptor,
            compiled=compiled,runnable=True,fields=FIELDS))
        self.publish(event='Construction valid. MuJoCo exploration available; walking and recovery are unproven.')

    def command(self,value):
        if value.get('kind')=='start':verify_source(self.config['source_commit'],physical=True)
        if value.get('kind')=='start' and value.get('engine')=='godot_jolt':
            if self.session_thread and self.session_thread.is_alive():raise ValueError('A native session already owns the app')
            if self.descriptor!=S169 or value.get('phase')!=74:raise ValueError('Live Godot currently requires the exact S169 body at phase 74')
            self.stop.clear();self.frame={};self.godot_command_ids=set()
            while not self.commands.empty():self.commands.get_nowait()
            self.session_thread=threading.Thread(target=self.run_live_godot,daemon=False)
            self.session_thread.start()
        elif value.get('kind')=='start' and value.get('engine')=='mujoco':
            if self.session_thread and self.session_thread.is_alive():raise ValueError('A native session already owns the app')
            spec=validate(dict(schema_version=SCHEMA,descriptor=dict(self.descriptor),steps=value.get('steps',3600),
                phase_mode='clocked',impulses=[],realtime=True))
            self.stop.clear()
            while not self.commands.empty():self.commands.get_nowait()
            self.session_thread=threading.Thread(target=self.run_sandbox,args=(spec,),daemon=False)
            self.session_thread.start()
        else:
            if value.get('kind')=='kick':
                impulse('validation',1,value['magnitude'],value['direction'],'validation')
                value=dict(value,owner_received_perf_counter_ns=time.perf_counter_ns(),
                    command_id=value.get('command_id',uuid.uuid4().hex))
                if self.status.get('engine')=='godot_jolt':
                    if not self.session_thread or not self.session_thread.is_alive():raise ValueError('No live native session')
                    if self.status.get('state')!='running' or self.frame.get('session_id')!=self.status.get('native_session') or self.frame.get('frame_index',0)<242:raise ValueError('Wait for live walking before kicking')
                    command_id=value['command_id']
                    if not isinstance(command_id,str) or not 1<=len(command_id)<=96 or command_id in self.godot_command_ids or len(self.godot_command_ids)>=16:raise ValueError('This session accepts at most 16 uniquely identified kicks')
                    self.godot_command_ids.add(command_id)
                    self.commands.put(value)
                    return
            super().command(value)

    def run_live_godot(self):
        from godot_live_owner import GodotLiveOwner
        from run_godot_cache_diagnostic import execute
        from audit_live_godot import audit
        folder=self.folder/('godot-live-'+uuid.uuid4().hex);folder.mkdir()
        owner=None
        try:
            self.publish(state='preflight',engine='godot_jolt',native_session='',native_directory=str(folder),event='Checking the live Godot route before creating a fresh world…')
            owner=GodotLiveOwner(self.config,folder)
            owner.walking_steps=1800;owner.presentation_owner=self
            owner.commands=self.commands;owner.stop=self.stop
            args=argparse.Namespace(run=True,live_walking=True,walking_steps=1800,probe_impulses=False,bridge_profile=False)
            code=execute(args,self.config['source_commit'],folder,owner,self.config)
            receipt=json.loads((folder/'receipt.json').read_text())
            if code:raise RuntimeError(receipt.get('error','Live Godot route failed'))
            write(folder/'audit.json',audit(folder))
            self.publish(state='complete',event='Live Godot session complete. Your kicks and all native steps are retained for inspection.')
        except BaseException as exc:
            self.publish(state='stopped' if self.stop.is_set() else 'refused',event=f'{type(exc).__name__}: {exc}')
        finally:
            if owner is not None:owner.close()

    def run_sandbox(self,spec):
        self.frame={};folder=self.folder/('sandbox-'+uuid.uuid4().hex);folder.mkdir()
        spec_path=folder/'spec.json';write(spec_path,spec)
        create=jobs.api('CreateMutexW',[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE)
        release=jobs.api('ReleaseMutex',[W.HANDLE]);handle=jobs.checked(create(None,False,'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'))
        acquired=False
        receipt=dict(ledger_scope=dict(subsystem='explorer',engine_scope='mujoco',authority_mode='development',question_class='development'),
            source_commit=self.config['source_commit'],spec=spec,interactive_impulses_allowed=True,
            maximum_total_impulses=16,physical_acceptance_authority=False,release_authority=False,ok=False)
        receipt['interactive_application_policy']='next_native_step'
        receipt['coverage']=dict(entrypoints=['studio_view.gd kick button','StudioOwner.command','physical','InteractiveTransport.take_due_impulses','mujoco_sandbox.run'],
            covered=['edited descriptor construction','owned native launch','zero-world controller preflight',
                'bounded stepping','next-step bounded impulse command','native force-time cap readback',
                'native application timing','original solver-input retention','terminal no-claim publication'],
            not_covered=['arbitrary morphology','general recovery','Godot latency','Rapier latency','release acceptance'])
        env=dict(SPORESPORE_LOCOMOTION_LIBRARY=self.config['core'],PYTHONDONTWRITEBYTECODE='1',PYTHONPATH=str(SDK/'adapters/mujoco'),
            EXPLORER_TEST_CORE=self.config['core'],EXPLORER_TEST_OUTPUT=str(folder))
        try:
            if jobs.wait(handle,0) not in (0,128):raise RuntimeError('Another native operation owns the physics mutex')
            acquired=True
            receipt.update(source_binding=source_binding(spec_path),runtime_binding=runtime_binding(self.config))
            write(folder/'declaration.json',receipt)
            self.publish(state='preflight',engine='mujoco',native_session='',native_directory=str(folder),event='Checking construction, containment and controller boundaries…')
            for name,path in [('ownership-and-stream',SDK/'explorer/test_showcase.py'),('sandbox-boundary',SDK/'explorer/studio/test_sandbox.py')]:
                invoke([self.config['mujoco_python'],'-B',str(path)],folder/name,env,90,self.stop)
            invoke([self.config['mujoco_python'],'-B',str(SDK/'explorer/studio/mujoco_sandbox.py'),'--spec',str(spec_path),'--output',str(folder),'--check-only'],folder/'native-preflight',env,90,self.stop)
            receipt['preflight']=json.loads((folder/'native-preflight/stdout.log').read_text())
            if receipt['preflight'].get('ok') is not True or receipt['preflight']['world_build_count']!=0:raise RuntimeError('Zero-world preflight refused')
            if self.stop.is_set():raise RuntimeError('Cancelled before world construction')
            if source_binding(spec_path)!=receipt['source_binding'] or runtime_binding(self.config)!=receipt['runtime_binding']:raise RuntimeError('Qualification dependency drift')
            self.publish(state='running',event='Live edited-body exploration • fresh MuJoCo world • behavior unproven')
            impulse_events=[]
            def presentation(row):
                kind=row['message_type']
                if kind=='hello':self.publish(native_session=row['session_id'])
                elif kind=='scene':write(self.folder/'scene.json',dict(row['scene'],session_id=row['session_id']))
                elif kind=='frame':
                    if row.get('applied_impulses'):
                        impulse_events.extend(row['applied_impulses'])
                        # Pose snapshots may be coalesced; discrete events must
                        # remain available until the viewer has observed them.
                        write(self.folder/'impulse-events.json',dict(session_id=row['session_id'],impulses=impulse_events))
                    self.frame=row;write(self.folder/'frame.json',row,presentation=True)
                elif kind=='notice':self.publish(event=row['text'])
            receipt['physical']=physical(self.config,spec,spec_path,folder/'physical',env,self.config['source_commit'],stop=self.stop,publish=presentation,commands=self.commands)
            if source_binding(spec_path)!=receipt['source_binding'] or runtime_binding(self.config)!=receipt['runtime_binding']:raise RuntimeError('Execution dependency drift')
            receipt['ok']=True
            self.publish(state='complete',event='Exploration complete. Replay and inspect the retained native observation.')
        except BaseException as exc:
            receipt['error']=f'{type(exc).__name__}: {exc}'
            self.publish(state='stopped' if self.stop.is_set() else 'refused',event=receipt['error'])
        finally:
            write(folder/'receipt.json',receipt)
            if acquired:release(handle)
            jobs.close(handle)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,required=True)
    destination=parser.add_mutually_exclusive_group(required=True)
    destination.add_argument('--output',type=Path)
    destination.add_argument('--evidence-root',type=Path,help='Create a fresh Studio session for each desktop launch')
    parser.add_argument('--headless-ui',action='store_true');parser.add_argument('--ui-self-test',action='store_true')
    parser.add_argument('--exercise-sandbox',action='store_true')
    parser.add_argument('--exercise-godot-live',action='store_true')
    parser.add_argument('--exercise-engine',choices=['rapier_parry'],help='Exercise the unchanged Rapier route through Studio controls')
    parser.add_argument('--replay-test',type=Path,help='Zero-world replay UI check of an independently audited retained sandbox')
    args=parser.parse_args()
    source=verify_source(physical=not args.ui_self_test)
    cfg=json.loads(args.config.read_text(encoding='utf-8-sig'));cfg['source_commit']=source
    folder=(args.output if args.output else args.evidence_root/('studio-'+uuid.uuid4().hex)).resolve()
    if not folder.is_relative_to(EVIDENCE):raise ValueError('Durable evidence root required')
    folder.mkdir(parents=True,exist_ok=False);(folder/'commands').mkdir()
    project=folder/'app';(project/'sdk/explorer/studio').mkdir(parents=True);(project/'sdk/recovery').mkdir()
    for name in ['showcase.gd','recovery_evidence.gd']:shutil.copy2(SDK/'explorer'/name,project/'sdk/explorer'/name)
    shutil.copy2(SDK/'explorer/studio/studio_view.gd',project/'sdk/explorer/studio/studio_view.gd')
    for name in ['r10dh_release_gate_adoption_v2.json','r10dh_held_out_physical_closure_v2.json']:shutil.copy2(SDK/'recovery'/name,project/'sdk/recovery'/name)
    (project/'project.godot').write_text('[application]\nconfig/name="SporeSpore Studio"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    owner=StudioOwner(cfg,folder);write(folder/'catalog.json',load_catalog());ui=None;job=jobs.Job()
    if args.replay_test:
        if not args.ui_self_test:raise ValueError('Replay test requires zero-world UI test mode')
        from audit_sandbox import audit
        audit(args.replay_test)
        rows=[json.loads(line) for line in (args.replay_test/'physical/stream.jsonl').read_text().splitlines()]
        scene=next(row for row in rows if row['message_type']=='scene')
        frame=[row for row in rows if row['message_type']=='frame'][-1]
        write(folder/'scene.json',dict(scene['scene'],session_id=frame['session_id']))
        write(folder/'frame.json',frame)
        write(folder/'replay-test.json',dict(native_directory=str(args.replay_test.resolve()),native_session=frame['session_id']))
    try:
        command=[cfg['godot'],'--path',str(project),'--script','res://sdk/explorer/studio/studio_view.gd']
        if args.headless_ui:command.insert(1,'--headless')
        command+=['--','--channel',str(folder)]
        if args.ui_self_test:command+=['--self-test']
        if args.replay_test:command+=['--replay-test']
        if args.exercise_sandbox:command+=['--exercise-sandbox']
        if args.exercise_godot_live:command+=['--exercise-godot-live']
        if args.exercise_engine:command+=['--exercise-engine',args.exercise_engine]
        with (folder/'ui.stdout.log').open('w') as out,(folder/'ui.stderr.log').open('w') as err:
            ui=subprocess.Popen(command,cwd=project,stdout=out,stderr=err);job.add(ui)
            started=time.monotonic()
            while ui.poll() is None:
                if args.ui_self_test and time.monotonic()-started>45:raise TimeoutError('UI test deadline')
                if (args.exercise_sandbox or args.exercise_godot_live or args.exercise_engine) and time.monotonic()-started>240:raise TimeoutError('UI native diagnostic deadline')
                for path in sorted((folder/'commands').glob('*.json')):
                    value=json.loads(path.read_text(encoding='utf-8'));path.rename(path.with_suffix('.consumed'))
                    try:
                        if args.ui_self_test and value.get('kind') in ['start','kick']:raise ValueError('Zero-world UI test cannot launch physics')
                        owner.command(value)
                    except Exception as exc:owner.publish(event=str(exc))
                time.sleep(.03)
            return ui.returncode
    finally:
        try:owner.close()
        finally:
            job.close()
            if ui is not None:ui.wait(timeout=10)


if __name__=='__main__':raise SystemExit(main())
