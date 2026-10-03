"""Contained Godot live stream with commands applied at the next native step."""
import json
from pathlib import Path
import socket
import time
import uuid

from showcase_owner import Owner, OwnedChild, SDK, write
from showcase_model import PROTOCOL, StreamIdentity, impulse, sha


class GodotLiveOwner(Owner):
    walking_steps = 119
    probe_impulses = False
    presentation_owner = None

    def stream_run(self, engine, folder, validate, request=None, project=None):
        if validate:
            return super().stream_run(engine, folder, validate, request, project)
        presentation = self.presentation_owner or self
        folder.mkdir()
        session = uuid.uuid4().hex
        listener = socket.socket()
        listener.bind(('127.0.0.1', 0)); listener.listen(1); listener.settimeout(.1)
        config = dict(id=session, parent_id=uuid.uuid4().hex, phase=request['phase'],
                      connect=f'127.0.0.1:{listener.getsockname()[1]}', validate_only=False,
                      permit=str(folder/'contained.permit'), output=str(folder/'recovery.json'),
                      source_commit=self.config['source_commit'], images={})
        for role, key in [('engine','recovery_engine'), ('console','recovery_console')]:
            config['images'][role] = dict(self.identity[key], length=Path(self.config[key]).stat().st_size)
        write(folder/'recovery_config.json', config)
        command = [self.config['recovery_console'], '--headless', '--path', str(project),
                   '--script', 'res://sdk/explorer/native_recovery/worker.gd']
        guard = StreamIdentity(session, engine, self.config['source_commit'], False)
        started = time.monotonic(); peer = None; child = None
        completed = None; hello = None; pending = b''; total = 0; sent = []; kicks = []
        probe_frames = [841,1441] if self.probe_impulses else []
        drops = 0; last_presentation = 0.0; presentation_writes = 0; presentation_cost_s = 0.0
        try:
            child = OwnedChild(command, SDK, dict(SPORESPORE_EXPLORER_CONFIG=str(folder/'recovery_config.json')), folder)
            with (folder/'stream.jsonl').open('xb') as retained, (folder/'commands.jsonl').open('x',encoding='utf-8') as commands:
                while completed is None:
                    if self.stop.is_set():raise RuntimeError('Live Godot cancelled')
                    if time.monotonic()-started > 180:raise TimeoutError('Live Godot wall limit')
                    if peer is None:
                        if child.process.poll() is not None:raise RuntimeError('Live Godot exited before connecting')
                        try:peer, _ = listener.accept()
                        except socket.timeout:continue
                        peer.settimeout(.01);peer.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
                    try:
                        block=peer.recv(65536)
                        if not block:raise RuntimeError('Live Godot stream closed without completion')
                    except socket.timeout:block=b''
                    if block:
                        retained.write(block);retained.flush();pending+=block;total+=len(block)
                        if total>268435456 or len(pending)>4194304:raise RuntimeError('Live stream byte bound')
                    while b'\n' in pending:
                        line,pending=pending.split(b'\n',1);row=json.loads(line);kind=guard.accept(row)
                        if kind=='hello':
                            hello=row
                            if row.get('command_capabilities',{}).get('next_native_step_torso_impulse') is not True:raise RuntimeError('Live capability missing')
                            presentation.publish(state='running',native_session=session,event='Fresh Godot physics: standing up, then live walking with your kicks.')
                        elif kind=='scene':write(presentation.folder/'scene.json',dict(row['scene'],session_id=session))
                        elif kind=='frame':
                            if guard.last_frame>241+self.walking_steps:raise RuntimeError('Live step limit')
                            self.frame=row;kicks.extend(row.get('applied_impulses',[]))
                            presentation.frame=row
                            now=time.perf_counter()
                            # Retain every native frame above; only the replaceable
                            # display snapshot is coalesced to the viewer's 30 Hz.
                            if now-last_presentation>=1/30 or guard.last_frame==241+self.walking_steps:
                                if not write(presentation.folder/'frame.json',row,presentation=True):drops+=1
                                presentation_cost_s+=time.perf_counter()-now
                                presentation_writes+=1;last_presentation=now
                            if row.get('applied_impulses'):write(presentation.folder/'impulse-events.json',dict(session_id=session,impulses=kicks))
                            if probe_frames and guard.last_frame>=probe_frames[0]:
                                frame=probe_frames.pop(0)
                                self.commands.put(dict(command_id=f'live-probe-{frame}',magnitude=.25,
                                    direction='right' if frame==841 else 'left',owner_received_perf_counter_ns=time.perf_counter_ns()))
                        elif kind=='completed':completed=row
                        elif kind=='error':raise RuntimeError(str(row.get('error')))
                        else:raise RuntimeError('Unexpected live Godot message')
                    while not self.commands.empty() and completed is None:
                        incoming=self.commands.get_nowait()
                        if guard.last_frame<241:raise ValueError('Wait for live walking before kicking')
                        packet=impulse(session,guard.last_frame,incoming['magnitude'],incoming['direction'],incoming.get('command_id',uuid.uuid4().hex))
                        del packet['apply_at_frame'];packet['apply_when']='next_native_step'
                        packet['owner_observed_frame']=guard.last_frame
                        commands.write(json.dumps(packet)+'\n');commands.flush();sent.append(packet)
                        peer.sendall((json.dumps(packet)+'\n').encode())
                peer.shutdown(socket.SHUT_RDWR)
                if child.process.wait(timeout=20)!=0:raise RuntimeError('Live Godot nonzero exit')
            if completed.get('ok') is not True or guard.last_frame!=241+self.walking_steps:raise RuntimeError('Live Godot incomplete')
            if {p['command_id'] for p in sent}!={p['command_id'] for p in kicks}:raise RuntimeError('Live command was not observed applied')
            return dict(completed=completed,hello=hello,last_frame=guard.last_frame,applied_impulses=kicks,sent_impulses=sent,
                        stream_sha256=sha(folder/'stream.jsonl'),elapsed_s=time.monotonic()-started,
                        presentation_frames_coalesced_due_to_file_lock=drops,
                        display_snapshot_profile=dict(maximum_hz=30,writes=presentation_writes,publication_wall_s=presentation_cost_s,all_native_frames_retained=True))
        finally:
            if peer is not None:peer.close()
            listener.close()
            if child is not None:child.close()
