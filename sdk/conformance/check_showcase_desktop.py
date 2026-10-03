"""Zero-world checks of the shipped desktop UI against a relocated SDK."""
import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk',type=Path,required=True)
    parser.add_argument('--config',type=Path,required=True)
    parser.add_argument('--recording',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    sys.path.insert(0,str(args.sdk/'explorer'))
    from showcase_owner import Owner, jobs
    cfg=json.loads(args.config.read_text(encoding='utf-8-sig'))
    args.output.mkdir(parents=True,exist_ok=False)
    project=args.output/'app'
    (project/'sdk/explorer').mkdir(parents=True)
    shutil.copytree(args.sdk/'recovery',project/'sdk/recovery')
    for name in ['showcase.gd','recovery_evidence.gd']:
        shutil.copy2(args.sdk/'explorer'/name,project/'sdk/explorer'/name)
    shutil.copy2(Path(__file__).with_suffix('.gd'),project/'check.gd')
    (project/'project.godot').write_text('[application]\nconfig/name="Explorer desktop verification"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    results=[]
    for mode in ['editing','replay']:
        folder=args.output/mode;folder.mkdir();(folder/'commands').mkdir()
        owner=Owner(cfg,folder) if mode=='editing' else None
        if mode=='replay':
            for name in ['status.json','frame.json','preview.json','scene.json']:
                shutil.copy2(args.recording/name,folder/name)
        command=[cfg['godot'],'--path',str(project),'--script','res://check.gd','--','--channel',str(folder)]
        if mode=='replay':command+=['--replay-check']
        job=jobs.Job();child=None
        try:
            with (folder/'stdout.log').open('w',encoding='utf-8') as out,(folder/'stderr.log').open('w',encoding='utf-8') as err:
                child=subprocess.Popen(command,cwd=project,stdout=out,stderr=err);job.add(child)
                deadline=time.monotonic()+45
                while child.poll() is None:
                    if time.monotonic()>deadline:raise TimeoutError('Desktop verification deadline')
                    for path in sorted((folder/'commands').glob('*.json')):
                        value=json.loads(path.read_text());path.rename(path.with_suffix('.consumed'))
                        if owner is None or value['kind'] not in ('generate','edit'):
                            raise RuntimeError('Zero-world checker refuses native commands')
                        owner.command(value)
                    time.sleep(.03)
                if child.returncode:raise RuntimeError(f'{mode} UI check failed: {folder}')
            report=json.loads((folder/'desktop-check.json').read_text())
            if report['ok'] is not True or report['world_build_count']!=0 or report['native_launch_count']!=0:raise RuntimeError('Invalid desktop check')
            results.append(report)
        finally:
            if owner:owner.close()
            job.close()
            if child:child.wait(timeout=10)
    print(json.dumps(dict(ok=True,results=results,world_build_count=0),indent=2))


if __name__=='__main__':main()
