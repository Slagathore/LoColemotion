"""Zero-world process-containment fixture; never imports or launches Godot."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('folder',type=Path);p.add_argument('--child',action='store_true');a=p.parse_args()
    if a.child:
        time.sleep(30)
    else:
        deadline=time.monotonic()+20
        while not (a.folder/'permit.json').exists():
            if time.monotonic()>deadline: sys.exit(2)
            time.sleep(.01)
        with subprocess.Popen([sys.executable,'-B',str(Path(__file__).resolve()),str(a.folder),'--child'],cwd=Path(__file__).resolve().parents[2],creationflags=subprocess.CREATE_NO_WINDOW) as child:
            (a.folder/'descendant.json').write_text(json.dumps(dict(parent=os.getpid(),child=child.pid)))
            child.wait(timeout=35)
