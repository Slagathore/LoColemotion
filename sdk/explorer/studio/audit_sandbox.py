"""Independently reopen retained sandbox observations; never grant acceptance."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from showcase_model import StreamIdentity, sha
from sandbox_spec import validate


def require(condition,message):
    if not condition:raise ValueError(message)


def audit(folder):
    receipt=json.loads((folder/'receipt.json').read_text())
    spec=validate(receipt['spec']);physical=receipt['physical']
    require(receipt['ok'] is True and receipt['physical_acceptance_authority'] is False and receipt['release_authority'] is False,'Receipt authority/outcome')
    require(receipt['preflight']['world_build_count']==0,'Preflight world')
    root=folder/'physical';summary=json.loads((root/'summary.json').read_text())
    require(summary==physical['completed']['summary'],'Summary differs from terminal stream receipt')
    require(sha(root/'stream.jsonl')==physical['stream_sha256'],'Stream digest')
    guard=StreamIdentity(physical['session_id'],'mujoco',receipt['source_commit'],False)
    kicks=[];frames=[];terminal=None;scene=None;latencies=[]
    with (root/'stream.jsonl').open() as stream:
        for line in stream:
            row=json.loads(line);kind=guard.accept(row)
            if kind=='scene':scene=row['scene']
            if kind=='completed':terminal=row
            if kind=='frame':
                frames.append(row);kicks.extend(row.get('applied_impulses',[]))
                require(math.isclose(row['simulation_time_s'],row['frame_index']/120,abs_tol=1e-12),'Simulated clock')
                require(all(p['apply_at_frame']==row['frame_index'] for p in row.get('applied_impulses',[])),'Impulse publication frame')
    require(terminal==physical['completed'] and terminal['ok'] is True,'Terminal identity')
    require(scene['descriptor']==spec['descriptor'] and summary['descriptor']==spec['descriptor'],'Descriptor identity')
    require(guard.last_frame==spec['steps']==summary['steps'],'Horizon')
    require(summary['world_build_count']==1 and summary['controller_session_closed'] is True and not summary['errors'],'World/session closure')
    require(summary['physical_acceptance_authority'] is False and summary['release_authority'] is False,'Summary authority')
    declared_impulses=spec['impulses']
    if receipt.get('interactive_impulses_allowed') is True:
        require(receipt.get('maximum_total_impulses')==16,'Interactive population bound')
        sent=physical['sent_impulses']
        require(len({p['command_id'] for p in sent})==len(sent),'Unique command identity')
        require(len({p['command_id'] for p in kicks})==len(kicks),'Unique application identity')
        observed_by_id={p['command_id']:p for p in kicks}
        declared_impulses=[]
        for packet in sent:
            observed=observed_by_id.get(packet['command_id'])
            require(observed is not None,'Sent command was not applied')
            step=packet.get('apply_at_frame')
            if packet.get('apply_when')=='next_native_step':
                require(receipt.get('interactive_application_policy')=='next_native_step' and step is None,'Interactive timing declaration')
                timing=observed['interaction_timing']
                require(timing['application_policy']=='next_native_step','Native timing policy')
                step=observed['apply_at_frame']
                require(step==timing['native_polled_after_frame']+1,'First available native step')
                clock=[timing[k] for k in ['owner_received_perf_counter_ns','owner_sent_perf_counter_ns','native_polled_perf_counter_ns','native_application_perf_counter_ns']]
                require(all(type(v) is int for v in clock) and 0<clock[0]<=clock[1]<=clock[2]<=clock[3],'Monotonic interaction timestamps')
                require(clock[:2]==[packet['owner_received_perf_counter_ns'],packet['owner_sent_perf_counter_ns']],'Owner timing identity')
                latencies.append(dict(command_id=packet['command_id'],applied_frame=step,
                    owner_receipt_to_native_application_ms=(clock[3]-clock[0])/1e6,
                    native_poll_to_application_ms=(clock[3]-clock[2])/1e6))
            declared_impulses.append(dict(step=step,vector_n_s=[packet['impulse_n_s'][a] for a in ['x','y','z']]))
        require(len(declared_impulses)<=16,'Interactive population overflow')
        require(all(type(p['step']) is int and 0<p['step']<=spec['steps'] and 0<math.sqrt(sum(v*v for v in p['vector_n_s']))<=8 for p in declared_impulses),'Interactive command bounds')
        logged=[json.loads(line) for line in (root/'commands.jsonl').read_text().splitlines()]
        require([p for p in logged if p['message_type']=='apply_impulse']==physical['sent_impulses'],'Interactive command retention')
    require(len(kicks)==len(declared_impulses)==summary['kicks'],'Impulse population')
    for observed,declared in zip(kicks,declared_impulses,strict=True):
        require(observed['apply_at_frame']==declared['step'],'Impulse timing')
        require([observed['impulse_n_s'][axis] for axis in ['x','y','z']]==declared['vector_n_s'],'Impulse vector')
    count=0;trace_kicks=[];maximum_ratio=0
    with (root/'controller-steps.jsonl').open() as trace:
        for line in trace:
            row=json.loads(line);require(row['step']==count,'Trace continuity')
            mapping=row['host_mapping'];application=row['application']
            require(mapping['semantic_step']==count and mapping['host_response_characterized_for_this_profile'] is False,'Mapping identity')
            require(application['portable_impulse_violation_count']==0,'Impulse cap readback')
            arrays=[application[k] for k in ['targets','cumulative_absolute_force_time_nms','portable_maximum_outer_impulse_nms']]
            require(all(len(a)==8 and all(math.isfinite(v) for v in a) for a in arrays),'Actuator population')
            require(arrays[0]==[c['host_target_velocity_rad_s'] for c in mapping['ordered_commands']],'Applied targets')
            for force_time,cap in zip(arrays[1],arrays[2],strict=True):
                require(cap>0 and 0<=force_time<=cap+1e-9,'Independent force-time cap')
                maximum_ratio=max(maximum_ratio,force_time/cap)
            require(all(p['apply_at_frame']==count+1 for p in row['impulses']),'Impulse applied in native trace step')
            trace_kicks.extend(row['impulses']);count+=1
    require(count==spec['steps'] and trace_kicks==kicks,'Trace and stream populations')
    final=next(b['position_m'] for b in frames[-1]['ordered_bodies'] if b['body_id']=='torso')
    require(all(math.isclose(final[a],summary['final_metrics'][a],abs_tol=1e-12) for a in ['x','y','z']),'Final pose readback')
    return dict(ok=True,steps=count,streamed_frames=len(frames),kicks=len(kicks),
        simulated_seconds=count/120,native_loop_wall_seconds=summary['native_loop_wall_seconds'],
        native_session_wall_seconds=physical['elapsed_s'],
        forward_advance_m=summary['final_metrics']['x']-summary['initial_metrics']['x'],
        final_tilt_rad=summary['final_metrics']['tilt_rad'],maximum_force_time_to_cap_ratio=maximum_ratio,
        interactive_latency=latencies,
        physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('folder',type=Path)
    args=parser.parse_args();print(json.dumps(audit(args.folder),indent=2))
