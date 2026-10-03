"""Real nested Python/PowerShell jobs; no Godot or physical world is opened."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import time
import recovery_discovery as D
import recovery_discovery_host_v2 as H


def nested_leaf(root, index, hold):
    ready = root/('nested-ready-'+str(index)+'.json')
    stop = root/('nested-stop-'+str(index))
    permit = root/('nested-permit-'+str(index)+'.json')
    job = H.W.Job(); child = None
    try:
        with (root/('nested-'+str(index)+'.stdout')).open('xb') as out, (root/('nested-'+str(index)+'.stderr')).open('xb') as err:
            child = subprocess.Popen([str(H.PWSH), '-NoProfile', '-File', str(H.NESTED),
                '-ReadyPath', str(ready), '-StopPath', str(stop), '-StartPermit', str(permit)], cwd=D.ROOT,
                stdin=subprocess.DEVNULL, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
            job.add(child)
            D.write_new(permit, dict(leaf_pid=child.pid, job_bound=True))
            identity = H.W.identity(child.pid)
            limit = time.monotonic()+45
            while not ready.exists() and time.monotonic()<limit: time.sleep(.05)
            D.require(ready.exists() and D.read(ready)['in_job'], 'NESTED_CHILD_NOT_CONTAINED')
            time.sleep(hold); stop.write_text('complete', encoding='utf-8')
            code = child.wait(timeout=15)
            rows = []
            for pid in job.pids():
                observed = H.W.identity(pid)
                try: image = D.image_path(pid) if observed is not None else None
                except (ValueError, OSError): image = None
                rows.append(dict(pid=pid, identity=observed, image=image))
            D.write_new(root/('nested-leaf-'+str(index)+'.json'), dict(exit_code=code,
                child_identity=identity, before_close=rows, world_build_count=0, solver_step_count=0))
            D.require(code == 0, 'NESTED_CHILD_NONZERO')
            H.Cleanup.drain(job, H.W, root/('nested-cleanup-'+str(index)+'.json'))
    finally:
        job.close()
        if child is not None and child.poll() is None: child.wait(timeout=15)


if __name__ == '__main__':
    path = Path(sys.argv[1]); v = H.request(path); root = path.parent
    if v['case'] in ('nested_pool', 'nested_orphan', 'nested_coordinator'):
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(nested_leaf, root, i, v['hold_seconds']) for i in range(2)]
            for future in futures: future.result()
        if v['case'] == 'nested_orphan':
            child = subprocess.Popen([str(H.PYTHON), '-c', 'import time;time.sleep(60)'],
                cwd=D.ROOT, stdin=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
            D.write_new(root/'fixture-ready.json', dict(child_identity=H.W.identity(child.pid), in_job=H.W.current_in_job()))
    else:
        stop = root/'fixture-child-stop'
        code = ('import sys,time;from pathlib import Path;p=Path(sys.argv[1]);end=time.monotonic()+60;'
                '\nwhile not p.exists() and time.monotonic()<end:time.sleep(.02)')
        child = subprocess.Popen([str(H.PYTHON), '-c', code, str(stop)], cwd=D.ROOT,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
        D.write_new(root/'fixture-ready.json', dict(child_identity=H.W.identity(child.pid), in_job=H.W.current_in_job()))
        if v['case'] == 'hang': time.sleep(60)
        else: time.sleep(v['hold_seconds'])
        if v['case'] != 'orphan':
            stop.write_text('complete', encoding='utf-8'); child.wait(timeout=15)
    if v['case'] not in ('nonzero', 'missing'):
        D.write_new(root/'fixture-terminal.json', dict(ok=True, request=D.binding(path), world_build_count=0, solver_step_count=0))
    raise SystemExit(7 if v['case'] == 'nonzero' else 0)
