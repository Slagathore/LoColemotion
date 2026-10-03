"""Zero-world child exercising the real detached host, including orphan cleanup."""
from pathlib import Path
import subprocess
import sys
import time
import recovery_discovery as D
import recovery_discovery_host as H

if __name__ == '__main__':
    path = Path(sys.argv[1]); v = H.request(path); root = path.parent
    # Ordinary fixture cases drain cooperatively so a short TerminateProcess
    # wait cannot replace the deliberately selected failure with a different
    # one. Owner-death, timeout and orphan controls still force job cleanup.
    stop = root/'fixture-child-stop'
    code = ('import sys,time;from pathlib import Path;p=Path(sys.argv[1]);end=time.monotonic()+60;'
            '\nwhile not p.exists() and time.monotonic()<end:time.sleep(.02)')
    child = subprocess.Popen([str(H.PYTHON), '-c', code, str(stop)], cwd=D.ROOT,
                             creationflags=subprocess.CREATE_NO_WINDOW)
    D.write_new(root/'fixture-ready.json', dict(child_identity=H.W.identity(child.pid), in_job=H.W.current_in_job()))
    if v['case'] == 'hang': time.sleep(60)
    else: time.sleep(v['hold_seconds'])
    if v['case'] != 'orphan':
        stop.write_text('complete', encoding='utf-8')
        child.wait(timeout=15)
    if v['case'] not in ('nonzero','missing'):
        D.write_new(root/'fixture-terminal.json', dict(ok=True, request=D.binding(path), world_build_count=0, solver_step_count=0))
    raise SystemExit(7 if v['case'] == 'nonzero' else 0)
