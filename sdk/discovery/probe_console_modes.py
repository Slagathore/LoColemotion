"""Bounded zero-world launch-interface diagnosis, with real owned processes."""
import subprocess
import time
import uuid
from pathlib import Path
import recovery_discovery as D
import recovery_discovery_host_v2 as H


def run():
    D.repository()
    root = D.EVIDENCE/('console-mode-interface-'+uuid.uuid4().hex); root.mkdir()
    D.write_new(root/'declaration.json', dict(source=D.binding(Path(__file__)),
        python=D.binding(H.PYTHON), powershell=D.binding(H.PWSH),
        cases=['python_no_window', 'python_detached', 'powershell_no_window',
               'powershell_detached', 'powershell_detached_noninteractive'],
        timeout_seconds=20, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False))
    print(root, flush=True)
    cases = [('python_no_window', [str(H.PYTHON), '-c', "print('READY',flush=True)"], subprocess.CREATE_NO_WINDOW),
             ('python_detached', [str(H.PYTHON), '-c', "print('READY',flush=True)"], subprocess.DETACHED_PROCESS),
             ('powershell_no_window', [str(H.PWSH), '-NoProfile', '-Command', "Write-Output 'READY'"], subprocess.CREATE_NO_WINDOW),
             ('powershell_detached', [str(H.PWSH), '-NoProfile', '-Command', "Write-Output 'READY'"], subprocess.DETACHED_PROCESS),
             ('powershell_detached_noninteractive', [str(H.PWSH), '-NoProfile', '-NonInteractive', '-Command', "Write-Output 'READY'"], subprocess.DETACHED_PROCESS)]
    for name, command, flags in cases:
        job = H.W.Job(); proc = None; timed_out = False; start = time.monotonic()
        try:
            with (root/(name+'.stdout')).open('xb') as out, (root/(name+'.stderr')).open('xb') as err:
                proc = subprocess.Popen(command, cwd=D.ROOT, stdin=subprocess.DEVNULL,
                    stdout=out, stderr=err, creationflags=flags)
                job.add(proc); identity = H.W.identity(proc.pid)
                try: code = proc.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    timed_out = True; job.terminate(); code = proc.wait(timeout=10)
                remaining = job.pids()
        finally:
            job.close()
            if proc is not None and proc.poll() is None: proc.wait(timeout=10)
        value = dict(command=command, creation_flags=flags, identity=identity,
            exit_code=code, timed_out=timed_out, elapsed_seconds=time.monotonic()-start,
            pre_close_members=remaining, stdout=D.binding(root/(name+'.stdout')),
            stderr=D.binding(root/(name+'.stderr')), world_build_count=0, solver_step_count=0)
        D.write_new(root/(name+'.json'), value)
        print(name, code, timed_out, round(value['elapsed_seconds'], 3), flush=True)


if __name__ == '__main__': run()
