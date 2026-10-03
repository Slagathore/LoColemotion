"""Audit bounded live Godot observations, commands and the native step join."""
import argparse
import json
import math
import struct
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from showcase_model import StreamIdentity, sha


def require(value, detail):
    if not value:raise ValueError(detail)


def controls_valid(rows, handoff, count):
    # Command 1 belongs to the original full-route handoff. Every subsequent
    # live command has its exact portable input, output and motor readback.
    require(len(rows)==count-1,'Controller population')
    for local, row in enumerate(rows,2):
        require(row['local_step']==local and row['global_step']==handoff+local,'Controller step join')
        request=row['request'];output=row['native_output'];application=row['application']
        actuation=output['actuation'];commands=actuation['ordered_commands']
        require(request['state']['semantic_step']==local==actuation['semantic_step']==application['semantic_step'],'Controller clocks')
        require(actuation['safe_no_actuation'] is False and not actuation['failure_codes'],'Native actuation refused')
        require(output['next_memory']['last_semantic_step']==local,'Native memory clock')
        require(application['ok'] is True and application['applied_command_count']==len(commands)==8,'Motor population')
        motors=application['ordered_applications']
        require(len(motors)==8 and len({m['actuator_id'] for m in motors})==8,'Motor identities')
        for command,motor in zip(commands,motors,strict=True):
            require(command['actuator_id']==motor['actuator_id'],'Motor command identity')
            target=command['target_velocity_rad_s']
            require(math.isfinite(target) and abs(target)<=command['maximum_target_speed_rad_s']+1e-12,'Motor target finite/bounded')
            require(target==motor['controller_target_velocity_rad_s']==motor['host_applied_target_velocity_rad_s'],'Motor target changed')
            projected=struct.unpack('<f',struct.pack('<f',target))[0]
            require(motor['motor_target_velocity_readback_rad_s']==projected,'Exact binary32 motor target readback')
            cap=application['authorized_maximum_impulse_by_actuator_id'][motor['actuator_id']]
            require(motor['declared_maximum_impulse_nms']==motor['motor_maximum_impulse_readback_nms']==cap>0,'Exact authorized motor cap readback')
            require(motor['host_additional_clamp_applied'] is False,'Hidden motor clamp')


def kicks_valid(sent, kicks):
    require(len(sent)==len(kicks)<=16,'Impulse population')
    require(len({p['command_id'] for p in sent})==len(sent),'Repeated sent command')
    require(len({p['command_id'] for p in kicks})==len(kicks),'Repeated native impulse')
    by_id={p['command_id']:p for p in sent}
    for kick in kicks:
        packet=by_id[kick['command_id']]
        require(packet['apply_when']=='next_native_step' and 'apply_at_frame' not in packet,'Ambiguous owner timing')
        require(kick['application_policy']=='next_native_step','Crossed native policy')
        require(kick['apply_at_frame']==kick['native_polled_after_frame']+1,'Not the next native step')
        require(packet['owner_observed_frame']<=kick['native_polled_after_frame'],'Native application preceded request')
        require(packet['impulse_n_s']==kick['impulse_n_s'],'Impulse vector changed')


def audit(folder):
    receipt=json.loads((folder/'receipt.json').read_text())
    require(receipt['ok'] is True and receipt['physical_acceptance_authority'] is False and receipt['release_authority'] is False,'Receipt outcome/authority')
    physical=receipt['physical'];stream=folder/'physical/stream.jsonl'
    require(sha(stream)==physical['stream_sha256'],'Stream digest')
    rows=[json.loads(line) for line in stream.read_text().splitlines()]
    guard=StreamIdentity(rows[0]['session_id'],'godot_jolt',receipt['source_commit'],False)
    frames=[];kicks=[]
    for row in rows:
        kind=guard.accept(row)
        if kind=='frame':
            require(row['frame_index']==len(frames)+1,'Missing native frame')
            require(abs(row['simulation_time_s']-row['frame_index']/120)<1e-10,'Native simulation clock')
            require(len(row['ordered_bodies'])==9,'Native body population')
            for body in row['ordered_bodies']:
                require(all(math.isfinite(v) for v in [*body['position_m'].values(),*body['orientation_xyzw'].values()]),'Nonfinite native pose')
            for kick in row['applied_impulses']:
                require(kick['apply_at_frame']==row['frame_index'],'Impulse publication step')
            frames.append(row);kicks.extend(row['applied_impulses'])
    require(rows[-1]==physical['completed'] and rows[-1]['ok'] is True,'Native terminal receipt')
    summary=rows[-1]['summary'];live=summary['studio_live_walking'];handoff=live['handoff_completed_step'];count=live['walking_commands']
    require(handoff==241 and len(frames)==handoff+count==receipt['declaration']['maximum_outer_steps'],'Live horizon')
    require(live['contact_checks']==count and live['zero_world']['ok'] is True,'Contact population or zero gate')
    require(live['recovery_ledger_advanced_during_live_walking'] is False,'Recovery ledger claim')
    require('terminal_state' not in summary and 'setup_state_at_handoff' in summary,'Stale recovery state presented as terminal')
    require(summary['physical_acceptance_authority'] is False and summary['release_authority'] is False,'Native overclaim')
    require(summary['walking_shutdown']['ok'] is True,'Controller session shutdown')
    binding=live['controller_rows'];control_path=Path(binding['path']).resolve()
    require(control_path.is_relative_to((folder/'physical').resolve()) and sha(control_path)==binding['sha256'],'Controller file binding')
    controls=json.loads(control_path.read_text());require(binding['rows']==len(controls),'Controller row count')
    controls_valid(controls,handoff,count)
    sent=physical.get('sent_impulses',[])
    require(physical['applied_impulses']==kicks==live.get('impulses',[]),'Impulse retention join')
    kicks_valid(sent,kicks)
    live_frames=frames[handoff:]
    elapsed=frames[-1]['physics_wall_time_s']-frames[handoff-1]['physics_wall_time_s']
    torso=lambda frame:next(b for b in frame['ordered_bodies'] if b['body_id']=='torso')
    tilts=[math.acos(max(-1,min(1,1-2*(torso(f)['orientation_xyzw']['x']**2+torso(f)['orientation_xyzw']['z']**2)))) for f in live_frames]
    return dict(ok=True,source_commit=receipt['source_commit'],native_frames=len(frames),walking_steps=count,
        walking_simulated_s=count/120,walking_interval_wall_s=elapsed,walking_interval_realtime_factor=(count/120)/elapsed,
        startup_through_handoff_wall_s=frames[handoff-1]['physics_wall_time_s'],total_prefix_wall_s=frames[-1]['physics_wall_time_s'],
        controller_rows=len(controls),impulses=kicks,delta_world_x_m=torso(frames[-1])['position_m']['x']-torso(frames[handoff-1])['position_m']['x'],
        maximum_walking_torso_tilt_rad=max(tilts),final_torso_tilt_rad=tilts[-1],
        physical_acceptance_authority=False,release_authority=False,
        limits='Bounded development observation. Walking interval includes first-command handoff. No general recovery, real-time guarantee or controlled solver comparison.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('folder',type=Path)
    print(json.dumps(audit(parser.parse_args().folder),indent=2))
