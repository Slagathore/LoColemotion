"""Read-only join of an isolated Studio layout and three fresh native UI runs."""
import argparse
import json
from pathlib import Path

from studio_layout import isolated_source
from audit_godot_interaction import audit_desktop as godot_audit
from audit_live_interaction import audit_desktop as mujoco_audit
from showcase_model import StreamIdentity,sha,impulse
from audit_live_godot import require


def rapier_audit(folder,layout):
    paths=list(folder.glob('native-*/receipt.json'));require(len(paths)==1,'One Rapier session')
    receipt=json.loads(paths[0].read_text());physical=receipt['physical']
    require(receipt['ok'] is True and receipt['physical_acceptance_authority'] is False and receipt['release_authority'] is False,'Rapier receipt authority')
    require(receipt['engine']=='rapier_parry' and receipt['preflight']['completed']['ok'] is True and receipt['preflight']['completed']['summary']['world_build_count']==0,'Rapier preflight')
    for relative,digest in receipt['source_binding']['files'].items():
        path=(layout/'sdk'/relative).resolve()
        require(path.is_relative_to(layout.resolve()) and sha(path)==digest,'Rapier isolated dependency')
    stream=paths[0].parent/'physical/stream.jsonl';require(sha(stream)==physical['stream_sha256'],'Rapier stream digest')
    guard=StreamIdentity(physical['hello']['session_id'],'rapier_parry',receipt['source_commit'],False)
    frames=[];kicks=[];completed=None
    for line in stream.read_text().splitlines():
        row=json.loads(line);kind=guard.accept(row)
        if kind=='frame':
            require(row['frame_index']==len(frames)+1,'Rapier contiguous frames')
            frames.append(row);kicks+=row['applied_impulses']
        if kind=='completed':completed=row
    require(completed==physical['completed'] and completed['ok'] is True and len(frames)==3172==physical['last_frame'],'Rapier completion')
    require(kicks==physical['applied_impulses'] and len(kicks)==1,'Rapier impulse population')
    commands=[json.loads(line) for line in (paths[0].parent/'physical/commands.jsonl').read_text().splitlines()]
    commands=[row for row in commands if row['message_type']=='apply_impulse']
    require(len(commands)==1,'Rapier sent command population')
    for key in ['command_id','impulse_n_s','apply_at_frame']:require(commands[0][key]==kicks[0][key],'Rapier command/application join')
    buttons=[json.loads(p.read_text()) for p in (folder/'commands').glob('*.consumed')]
    buttons=[row for row in buttons if row.get('kind')=='kick'];require(len(buttons)==1,'Rapier button population')
    require(impulse('audit',1,buttons[0]['magnitude'],buttons[0]['direction'],'audit')['impulse_n_s']==kicks[0]['impulse_n_s'],'Rapier button vector')
    require('SHOWCASE_NATIVE_UI_PASS engine=rapier_parry' in (folder/'ui.stdout.log').read_text() and not (folder/'ui.stderr.log').read_text().strip(),'Rapier desktop outcome')
    return dict(ok=True,source_commit=receipt['source_commit'],native_frames=len(frames),impulses=kicks,
                simulated_s=frames[-1]['simulation_time_s'],native_interval_wall_s=frames[-1]['physics_wall_time_s'],
                outcome=completed['outcome'],limits='Original Rapier finite route; scheduled transport lead retained. No next-step or cross-engine equivalence claim.')


def audit(layout,godot,mujoco,rapier):
    source=isolated_source(layout)
    results=dict(godot_jolt=godot_audit(godot),mujoco=mujoco_audit(mujoco),rapier_parry=rapier_audit(rapier,layout))
    for folder in [godot,mujoco,rapier]:
        status=json.loads((folder/'status.json').read_text())
        require(status['source_commit']==source and status['state']=='complete','Mixed isolated source or incomplete session')
        native=Path(status['native_directory']).resolve()
        require(native.parent==folder.resolve(),'Crossed native directory')
        require(json.loads((native/'receipt.json').read_text())['source_commit']==source,'Crossed native source freeze')
    return dict(schema_version='sporespore_studio_isolated_interface_audit_v1',
                ledger_scope=dict(subsystem='explorer',engine_scope='3e',authority_mode='development',question_class='development'),
                ok=True,source_commit=source,isolated_source=str(layout.resolve()),results=results,
                git_checkout_required=False,game_project_required=False,external_runtime_dependencies_required=True,
                physical_acceptance_authority=False,release_authority=False)


def verify_checkpoint(record,evidence_root=None):
    """Reopen retained bytes and recompute the native joins; never start physics."""
    from studio_portability import verify_files,within,SCOPE
    from studio_layout import source_files
    from portable_setup import verify as verify_setup
    require(record['schema_version']=='locolemotion_studio_portable_checkpoint_v1','Portable checkpoint schema')
    require(record['ledger_scope']==SCOPE,'Portable checkpoint ledger scope')
    for flag in ['physical_acceptance_authority','release_authority','binary_distribution_authorized']:
        require(record[flag] is False,'Portable checkpoint authority')
    root=Path(evidence_root or record['artifact_root']).resolve()
    locations=record['locations']
    required={locations['plan'],locations['launcher_readback']}
    for key in ['godot','mujoco','rapier','ui_preflight','ui_installed']:
        required.update(p.relative_to(root).as_posix() for p in within(root,locations[key]).rglob('*') if p.is_file())
    required.update(locations['installation']+'/'+name for name in ['dependencies.json','source/studio-layout.json','proof-pack/viewing-closure.json','installation.json'])
    require(required<={row['path'] for row in record['artifacts']},'Portable checkpoint artifact inventory incomplete')
    verify_files(root,record['artifacts'])
    installation=within(root,locations['installation'])
    source=isolated_source(installation/'source')
    require(source==record['source_commit'],'Portable checkpoint source')
    setup=verify_setup(installation,within(root,locations['python']))
    require(setup==record['setup_audit'],'Portable setup audit changed')
    native=audit(installation/'source',*[within(root,locations[key]) for key in ['godot','mujoco','rapier']])
    require(native==record['native_audit'],'Native installation audit changed')
    launcher=json.loads(within(root,locations['launcher_readback']).read_text())
    require(launcher['ok'] is True and launcher['source_commit']==source and launcher['exit_code']==0
            and launcher['prior_shortcut_preserved'] is True and launcher['world_build_count']==0,'Installed launcher readback')
    dependencies=json.loads((installation/'dependencies.json').read_text())
    install=json.loads((installation/'installation.json').read_text())
    rebuilt=json.loads((root/'python-rebuild-check.json').read_text())
    require(rebuilt==record['python_rebuild'] and rebuilt['ok'] is True,'Python rebuild identity')
    expected=dict(isolated_source_files=len(source_files(installation/'source')),
        native_images=len(dependencies['runtime_files']),python_runtime_files=len(dependencies['python_runtime']['files']),
        viewing_pack_files=setup['proof']['files_verified'],viewing_frames=setup['proof']['viewing_frames'],
        raw_viewing_source_streams=setup['proof']['raw_streams_verified'],omitted_scientific_dependencies=setup['proof']['missing_scientific_dependencies'],
        installed_shortcut=Path(install['shortcut']).stem,prior_shortcut_preserved=launcher['prior_shortcut_preserved'])
    require(expected==record['observed'],'Portable checkpoint summary differs from retained evidence')
    for key in ['ui_preflight','ui_installed']:
        folder=within(root,locations[key])
        require('STUDIO_UI_PASS worlds=0 native_workers=0' in (folder/'ui.stdout.log').read_text(),'Portable graphical UI result')
        require(not (folder/'ui.stderr.log').read_text().strip(),'Portable graphical UI error')
        require(json.loads((folder/'setup.json').read_text())['source_commit']==source,'Portable graphical UI source')
    plan=json.loads(within(root,locations['plan']).read_text())
    require(plan['source_commit']==source and len(plan['worlds'])==3,'Prospective portability scope')
    return dict(ok=True,source_commit=source,artifacts_verified=len(record['artifacts']),
                native_engines_verified=sorted(native['results']),viewing_frames=setup['proof']['viewing_frames'],
                worlds_opened_by_audit=0,physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ['layout','godot','mujoco','rapier']:parser.add_argument('--'+key,type=Path)
    parser.add_argument('--checkpoint',type=Path)
    parser.add_argument('--evidence-root',type=Path)
    args=parser.parse_args()
    if args.checkpoint:
        if any(getattr(args,k) for k in ['layout','godot','mujoco','rapier']):parser.error('Choose checkpoint or individual sessions')
        result=verify_checkpoint(json.loads(args.checkpoint.read_text()),args.evidence_root)
    else:
        if args.evidence_root or not all(getattr(args,k) for k in ['layout','godot','mujoco','rapier']):parser.error('Provide all four session/layout paths')
        result=audit(**{k:getattr(args,k) for k in ['layout','godot','mujoco','rapier']})
    print(json.dumps(result,indent=2))
