"""Read-only diagnostic of Git subprocesses under Godot's helper stdio modes."""
import json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
rows=[]
for args in [('rev-parse','--show-toplevel'),('remote','get-url','origin'),('branch','--show-current'),('status','--porcelain'),('rev-parse','HEAD'),('rev-parse','origin/main'),('ls-remote','origin','refs/heads/main')]:
    try:
        value=subprocess.check_output(['git',*args],cwd=root,text=True,timeout=45,creationflags=subprocess.CREATE_NO_WINDOW).strip()
        rows.append(dict(arguments=args,ok=True,value=value))
    except Exception as error:
        rows.append(dict(arguments=args,ok=False,error=str(error),type=type(error).__name__))
print(json.dumps(dict(diagnosis_only=True,stderr_available=sys.stderr is not None,stdin_available=sys.stdin is not None,checks=rows,world_build_count=0,solver_step_count=0)))
