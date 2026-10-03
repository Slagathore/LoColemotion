"""Actual helper transport probe, launched by Godot with uncaptured stderr."""
import json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'sdk/conformance'))
import r10ad_startup_transport as transport
command=['git','ls-remote','origin','refs/heads/main']
rows=[]
for mode in ['inherited_stderr_before','explicit_pipes','inherited_stderr_after']:
    if mode=='explicit_pipes':
        rows.append(dict(mode=mode,receipt=transport.run_captured(command,cwd=root)))
    else:
        try:
            value=subprocess.check_output(command,cwd=root,text=True,timeout=45,creationflags=subprocess.CREATE_NO_WINDOW)
            rows.append(dict(mode=mode,exit_code=0,stdout=value))
        except subprocess.CalledProcessError as error:
            rows.append(dict(mode=mode,exit_code=error.returncode,stdout=error.output))
value=dict(diagnosis_only=True,comparisons=rows,world_build_count=0,solver_step_count=0,
    physical_acceptance_authority=False,release_authority=False)
print(json.dumps(value,separators=(',',':')))
