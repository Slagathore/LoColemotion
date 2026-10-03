"""Qualify a source-bound context cache; optionally run one 360-step prefix."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading

SDK=Path(__file__).resolve().parents[2];ROOT=SDK.parent
sys.path.insert(0,str(SDK/'explorer'))
from showcase_owner import Owner,jobs,write,source_binding as original_binding
from showcase_model import sha
from run_mujoco_sandbox import invoke
from materialize_godot_context_cache import materialize
from studio_layout import verify_source as verify_studio_source


def binding(project):
    paths=[p for p in project.rglob('*') if p.suffix in ['.gd','.json','.gdextension','.dll','.godot'] and '.godot' not in p.relative_to(project).parts]
    paths+=list((SDK/'explorer/studio').glob('*.py'))+list((SDK/'explorer/studio').glob('*.gd'))
    paths+=[SDK/'explorer/showcase_owner.py',SDK/'explorer/showcase_model.py',SDK/'conformance/r10v_windows_job.py']
    return {str(p.resolve()):sha(p) for p in sorted(set(paths))}


def verify_source(source, physical):
    verify_studio_source(source,physical)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--bridge-profile',action='store_true',help='Time unchanged native calls and exact JSON stringify in the isolated project')
    parser.add_argument('--live-walking',action='store_true',help='After original stand-up, measure the separate live walking path without recovery energy ledgers')
    parser.add_argument('--walking-steps',type=int,choices=[119,1800],default=119)
    parser.add_argument('--probe-impulses',action='store_true',help='Send two next-step commands after observed walking seconds 5 and 10')
    args=parser.parse_args()
    if (args.walking_steps!=119 or args.probe_impulses) and not args.live_walking:raise ValueError('Live walking option required')
    if args.probe_impulses and args.walking_steps!=1800:raise ValueError('Two-command probe requires the 15-second walking horizon')
    def git(*words):return subprocess.check_output(['git',*words],cwd=ROOT,text=True).strip()
    if Path(git('rev-parse','--show-toplevel')).resolve()!=ROOT or git('remote','get-url','origin')!='https://github.com/Slagathore/sporespore.git':raise RuntimeError('Repository identity')
    source=git('rev-parse','HEAD')
    if args.run and (git('status','--porcelain') or git('ls-remote','origin','refs/heads/main').split()[0]!=source):raise RuntimeError('Physics requires clean pushed source')
    folder=args.output.resolve()
    if not folder.is_relative_to(ROOT.parent/'SporeSpore_Evidence'):raise ValueError('Durable evidence root required')
    folder.mkdir(parents=True,exist_ok=False)
    cfg=json.loads(args.config.read_text(encoding='utf-8-sig'));cfg['source_commit']=source
    if args.live_walking:
        from godot_live_owner import GodotLiveOwner
        owner=GodotLiveOwner(cfg,folder);owner.walking_steps=args.walking_steps;owner.probe_impulses=args.probe_impulses
    else:owner=Owner(cfg,folder)
    return execute(args,source,folder,owner,cfg)


def execute(args,source,folder,owner,cfg):
    """Same qualified route for the CLI and the interactive desktop owner."""
    verify_source(source,args.run)
    create=jobs.api('CreateMutexW',[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api('ReleaseMutex',[W.HANDLE])
    handle=jobs.checked(create(None,False,'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'));acquired=False
    receipt=dict(ledger_scope=dict(subsystem='explorer',engine_scope='godot_jolt',authority_mode='development',question_class='development'),
        source_commit=source,runtime=owner.identity,ok=False,physical_acceptance_authority=False,release_authority=False,
        declaration=dict(seed=74,maximum_outer_steps=360,maximum_worlds=1,physical_wall_limit_seconds=180,
            question='Measure stand-up and walking-prefix timing and retained native observations for the exact declared context-cache source and engine images.',
            coverage='Fresh production entry, preparation, native stepping, context predicates and stand-up/walking prefix. No scheduled kick, full recovery, paired effect or acceptance.'))
    try:
        if jobs.wait(handle,0) not in (0,128):raise RuntimeError('Native operation mutex occupied')
        acquired=True
        invoke([sys.executable,'-B',str(SDK/'explorer/test_showcase.py')],folder/'ownership-and-stream',
            dict(EXPLORER_TEST_CORE=cfg['core'],EXPLORER_TEST_OUTPUT=str(folder)),90)
        if args.live_walking:
            invoke([sys.executable,'-B',str(SDK/'explorer/studio/test_live_godot.py')],folder/'live-audit-boundary',dict(EXPLORER_TEST_OUTPUT=str(folder)),30)
        project=owner.prepare_recovery(folder,'godot_jolt');receipt['wrapped_predicates']=materialize(project)
        if args.bridge_profile:
            from materialize_godot_bridge_profile import instrument
            receipt['bridge_profile_methods']=instrument(project)
            receipt['declaration']['telemetry_profile']='Full original capture plus native-call and authoritative-JSON-stringify timers; calls, arguments, results and solver inputs unchanged.'
        if args.live_walking:
            worker=project/'sdk/explorer/native_recovery/worker.gd'
            maximum=241+args.walking_steps
            raw=worker.read_text(encoding='utf-8')
            if raw.count('const STUDIO_MAX_STEPS:=360')!=1:raise ValueError('Diagnostic bound changed')
            worker.write_text(raw.replace('const STUDIO_MAX_STEPS:=360',f'const STUDIO_MAX_STEPS:={maximum}'),encoding='utf-8',newline='\n')
            shutil.copy2(worker,worker.with_name('worker_cached.gd'))
            shutil.copy2(SDK/'explorer/studio/godot_live_walking_worker.gd',worker)
            for name in ['godot_live_walking.gd','test_godot_live_walking.gd','godot_live_commands.gd']:
                shutil.copy2(SDK/'explorer/studio'/name,project/'sdk/explorer/studio'/name)
            receipt['declaration']['question']='Measure the separate native live walking loop, retained inputs, body observations and next-step commands without recovery energy ledgers.'
            receipt['declaration']['maximum_outer_steps']=maximum
            receipt['declaration']['walking_commands']=args.walking_steps
            receipt['declaration']['interactive_probe']=dict(enabled=args.probe_impulses,owner_observed_trigger_frames=[841,1441] if args.probe_impulses else [],magnitude_n_s=.25,application_policy='next_native_step_after_native_poll')
            receipt['declaration']['telemetry_profile']='Original stand-up; then native contact classification, original walking sampler/controller/command checks/motor application, complete controller rows and body stream. No recovery energy or orchestration ledger during live walking.'
            receipt['declaration']['presentation_profile']='All native frames and commands retained. Only the replaceable viewer snapshot is coalesced to 30 Hz; discrete impulse events remain cumulative. Desktop renders at most 60 FPS.'
            receipt['declaration']['uncovered_paths']=['post-kick recovery controller switch','other bodies','desktop kick-button integration','release acceptance','controlled maximum-throughput comparison']
            if owner.presentation_owner is not None:
                receipt['declaration']['uncovered_paths'].remove('desktop kick-button integration')
                receipt['declaration']['desktop_entrypoints']=['studio_view.gd kick button','StudioOwner.command','GodotLiveOwner.stream_run','godot_live_commands.gd','RigidBody3D.apply_central_impulse']
                receipt['declaration']['interactive_probe']['maximum_user_commands']=16
        # Test the generic exact-key cache in a minimal zero-world project.
        pure=folder/'cache-pure';pure.mkdir()
        for name in ['immutable_context_cache.gd','test_immutable_context_cache.gd']:shutil.copy2(SDK/'explorer/studio'/name,pure/name)
        (pure/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Studio context cache checks"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
        invoke([cfg['recovery_console'],'--headless','--path',str(pure),'--script','res://test_immutable_context_cache.gd'],folder/'cache-boundary',{},30)
        receipt['dependency_binding']=binding(project);write(folder/'declaration.json',receipt)
        timeout=threading.Timer(180,owner.stop.set);timeout.start()
        try:receipt['preflight']=owner.stream_run('godot_jolt',folder/'preflight',True,dict(phase=74),project)
        finally:timeout.cancel()
        check=receipt['preflight']['completed']
        if check.get('ok') is not True or check['summary']['world_build_count']!=0 or check['summary']['studio_context_cache_probe']['ok'] is not True:raise RuntimeError('Complete cached-route zero-world gate refused')
        if args.live_walking and check['summary']['studio_live_walking']['zero_world']['ok'] is not True:raise RuntimeError('Live walking safety gate refused')
        if args.live_walking and check['summary']['studio_live_walking']['command_zero_world']['ok'] is not True:raise RuntimeError('Live impulse safety gate refused')
        if binding(project)!=receipt['dependency_binding']:raise RuntimeError('Qualification source drift')
        for row in owner.identity.values():
            if sha(Path(row['path']))!=row['sha256']:raise RuntimeError('Runtime drift')
        if args.run:
            timeout=threading.Timer(180,owner.stop.set);timeout.start()
            try:receipt['physical']=owner.stream_run('godot_jolt',folder/'physical',False,dict(phase=74),project)
            finally:timeout.cancel()
            if receipt['physical']['last_frame']!=receipt['declaration']['maximum_outer_steps'] or receipt['physical']['completed']['ok'] is not True:raise RuntimeError('Native diagnostic incomplete')
        if binding(project)!=receipt['dependency_binding']:raise RuntimeError('Execution source drift')
        receipt['ok']=True
    except BaseException as exc:receipt['error']=f'{type(exc).__name__}: {exc}'
    finally:
        write(folder/'receipt.json',receipt)
        owner.close()
        if acquired:release(handle)
        jobs.close(handle)
    print(json.dumps(dict(ok=receipt['ok'],error=receipt.get('error'),output=str(folder),physical_ran='physical' in receipt)))
    return 0 if receipt['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
