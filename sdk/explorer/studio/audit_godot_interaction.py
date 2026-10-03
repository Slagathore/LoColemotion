"""Join desktop buttons to retained Godot inputs, native impulses and UI receipts."""
import argparse
import json
import math
from pathlib import Path

from audit_live_godot import audit, require
from showcase_model import impulse


def audit_rows(commands, native, shown, session):
    require(0<len(commands)==len(native)==len(shown)<=16,'Desktop impulse population')
    indexed=[{row['command_id']:row for row in rows} for rows in [commands,native,shown]]
    require(all(len(rows)==len(commands) for rows in indexed) and indexed[0].keys()==indexed[1].keys()==indexed[2].keys(),'Desktop impulse identity')
    result=[]
    for command_id,command in indexed[0].items():
        applied=indexed[1][command_id];ui=indexed[2][command_id]
        expected=impulse(session,1,command['magnitude'],command['direction'],command_id)
        require(expected['impulse_n_s']==applied['impulse_n_s'],'Desktop/native vector')
        require(ui['session_id']==session and ui['applied_frame']==applied['apply_at_frame'],'Desktop/native session and frame')
        pressed=ui['ui_pressed_ticks_usec'];observed=ui['ui_observed_ticks_usec']
        require(type(pressed) is int and type(observed) is int and 0<pressed<=observed,'Desktop monotonic clock')
        elapsed=(observed-pressed)/1000
        require(math.isclose(elapsed,ui['button_to_observed_application_ms'],abs_tol=1e-6),'Desktop latency calculation')
        result.append(dict(command_id=command_id,applied_frame=applied['apply_at_frame'],button_to_observed_application_ms=elapsed))
    return result


def audit_desktop(folder):
    sessions=list(folder.glob('godot-live-*/receipt.json'))
    require(len(sessions)==1,'One fresh Godot desktop session')
    result=audit(sessions[0].parent)
    receipt=json.loads(sessions[0].read_text())
    commands=[json.loads(p.read_text()) for p in sorted((folder/'commands').glob('*.consumed'))]
    commands=[row for row in commands if row.get('kind')=='kick']
    shown=json.loads((folder/'interaction.json').read_text())
    physical=receipt['physical'];session=physical['completed']['session_id']
    result['desktop_interaction']=audit_rows(commands,physical['applied_impulses'],shown,session)
    require('STUDIO_GODOT_LIVE_UI_PASS' in (folder/'ui.stdout.log').read_text(),'Desktop exercise outcome')
    require(not (folder/'ui.stderr.log').read_text().strip(),'Desktop error log')
    result['timing_limit']='Button-to-display uses one UI monotonic clock. No synchronization of Python and Godot clocks is assumed; owner-to-native milliseconds are not claimed.'
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('folder',type=Path)
    print(json.dumps(audit_desktop(parser.parse_args().folder),indent=2))
