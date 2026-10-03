"""Reopen the shortened context-cache diagnostic against retained observations."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from showcase_model import sha,StreamIdentity
SDK=Path(__file__).resolve().parents[2]


def audit(folder):
    closure=json.loads((SDK/'explorer/showcase_closure_v1.json').read_text())
    old_binding=closure['engines']['godot_jolt']['stream'];old_path=Path(old_binding['path'])
    if sha(old_path)!=old_binding['sha256']:raise ValueError('Historical stream digest mismatch')
    receipt=json.loads((folder/'receipt.json').read_text());physical=receipt['physical']
    stream=folder/'physical/stream.jsonl'
    if receipt['ok'] is not True or sha(stream)!=physical['stream_sha256']:raise ValueError('New receipt or stream mismatch')
    old=[json.loads(line) for line in old_path.read_text().splitlines()]
    new=[json.loads(line) for line in stream.read_text().splitlines()]
    frames=[row for row in new if row['message_type']=='frame']
    prior=[row for row in old if row['message_type']=='frame'][:360]
    guard=StreamIdentity(new[0]['session_id'],'godot_jolt',receipt['source_commit'],False)
    for row in new:guard.accept(row)
    if len(frames)!=360 or guard.last_frame!=360 or new[-1]!=physical['completed']:raise ValueError('Native population or finalization')
    fields=['frame_index','simulation_time_s','phase','ordered_bodies','ordered_body_ground_contacts','applied_impulses']
    differences=[]
    for baseline,observed in zip(prior,frames,strict=True):
        changed=[key for key in fields if baseline.get(key)!=observed.get(key)]
        if changed:differences.append(dict(frame=observed['frame_index'],fields=changed))
    if differences:raise ValueError('Retained observation difference: '+str(differences[:3]))
    if any(row['applied_impulses'] for row in frames):raise ValueError('Unexpected kick in shortened prefix')
    summary=physical['completed']['summary']
    if summary['physical_acceptance_authority'] is not False or summary['release_authority'] is not False:raise ValueError('Diagnostic overclaim')
    return dict(ok=True,source_commit=receipt['source_commit'],compared_frames=360,compared_fields=fields,
        differing_frames=0,simulated_seconds=3.0,original_prefix_wall_seconds=prior[-1]['physics_wall_time_s'],
        cached_prefix_wall_seconds=frames[-1]['physics_wall_time_s'],
        observed_elapsed_ratio=prior[-1]['physics_wall_time_s']/frames[-1]['physics_wall_time_s'],
        cached_realtime_factor=3.0/frames[-1]['physics_wall_time_s'],last_phase=frames[-1]['phase'],
        cache=summary['studio_context_cache'],cost=summary['cost'],
        physical_acceptance_authority=False,release_authority=False,
        interpretation='One shortened development prefix. Retained body poses, contacts, phases and scheduled-event samples match; this does not prove bitwise internal solver equivalence, complete recovery behavior, or a controlled performance advantage.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('folder',type=Path)
    args=parser.parse_args();print(json.dumps(audit(args.folder),indent=2))
