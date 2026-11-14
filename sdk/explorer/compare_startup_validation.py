"""Fresh ABBA development timing through the existing owned Studio route."""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
EVIDENCE=ROOT.parent/'SporeSpore_Evidence'
ROLES=('original_first','native_first','native_second','original_second')
PATHS=('sdk/discovery','sdk/conformance','sdk/explorer','sdk/explorer/studio','sdk/python','sdk/adapters/mujoco','sdk')
for relative in PATHS:sys.path.insert(0,str(ROOT/relative))
sha=lambda path:hashlib.sha256(Path(path).read_bytes()).hexdigest()
read=lambda path:json.loads(Path(path).read_bytes())


def require(condition,message):
    if not condition:raise ValueError(message)


def write(path,value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,indent=2,allow_nan=False);stream.write('\n')


def compare(values):
    require(set(values)==set(ROLES),'Comparison role population')
    first=values[ROLES[0]]
    for role,row in values.items():
        require(math.isfinite(row['startup_s']) and row['startup_s']>0,'Comparison clock')
        require(row['frames']==first['frames'] and row['controls']==first['controls'],'Body or controller mismatch')
        require(type(row['calls']) is int and row['calls']>0 and row['calls']==first['calls'],'Validator population mismatch')
    gains=[1-values['native_'+suffix]['startup_s']/values['original_'+suffix]['startup_s'] for suffix in ('first','second')]
    return dict(exact_frames_and_controller_rows=True,validator_calls_per_world=first['calls'],
        pair_reduction_fractions=gains,mean_pair_reduction_fraction=sum(gains)/2,
        criterion_passed=all(v>0 for v in gains) and sum(gains)/2>=.05)


def controls():
    values={role:dict(startup_s=19. if role.startswith('native') else 20.,frames=[{'frame':1}],controls=[{'command':1}],calls=10) for role in ROLES}
    require(compare(values)['criterion_passed'],'Positive comparison control')
    mutations=[lambda v:v.pop('native_second'),lambda v:v['native_first'].update(startup_s=0),
        lambda v:v['native_first'].update(startup_s=float('nan')),lambda v:v['native_first'].update(frames=[]),
        lambda v:v['native_first'].update(controls=[]),lambda v:v['native_first'].update(calls=9)]
    for mutate in mutations:
        bad=copy.deepcopy(values);mutate(bad)
        try:compare(bad)
        except ValueError:continue
        raise ValueError('Comparison refusal control accepted')
    for a,b in [(19.9,19.9),(17.,20.1)]:
        bad=copy.deepcopy(values);bad['native_first']['startup_s']=a;bad['native_second']['startup_s']=b
        require(not compare(bad)['criterion_passed'],'Timing criterion control accepted')
    return dict(ok=True,checks=9,worlds_opened=0)


def audit(folder):
    from audit_live_godot import audit as audit_native
    from run_contact_sequence_native_v2 import validate_cleanup
    values={};audits={};bindings=0;source=None;runtime=None
    for role in ROLES:
        native=folder/role;receipt=read(native/'receipt.json');row=audit_native(native)
        require(row['native_frames']==360 and row['walking_steps']==119 and row['controller_rows']==118,'Native population')
        require(receipt['declaration']['seed']==74 and receipt['declaration']['serializer_cache_policy']=='clear_all','Native configuration')
        policy=role.split('_')[0];validation=row['native_source_validation']
        require(validation['policy']==policy,'Native role policy')
        source=source or receipt['source_commit'];runtime=runtime or receipt['runtime']
        require(receipt['source_commit']==source and receipt['runtime']==runtime,'Crossed source or runtime')
        for path,digest in receipt['dependency_binding'].items():require(sha(path)==digest,'Changed source: '+path)
        for item in receipt['runtime'].values():require(sha(item['path'])==item['sha256'],'Changed runtime')
        bindings+=len(receipt['dependency_binding']);validate_cleanup(read(folder/(role+'-owned')/'cleanup.json'))
        stream=[json.loads(line) for line in (native/'physical/stream.jsonl').read_text().splitlines()]
        frames=[{k:v for k,v in frame.items() if k not in ('session_id','physics_wall_time_s')} for frame in stream if frame['message_type']=='frame']
        retained=receipt['physical']['completed']['summary']['studio_live_walking']['controller_rows']
        values[role]=dict(startup_s=row['startup_through_handoff_wall_s'],frames=frames,controls=read(retained['path']),
            calls=validation['compiled_calls' if policy=='native' else 'original_calls'])
        audits[role]=row
    return dict(ok=True,source_commit=source,worlds_opened=4,solver_steps=1440,dependency_bindings=bindings,
        audits=audits,comparison=compare(values),reader_controls=controls(),physical_acceptance_authority=False,release_authority=False)


def run(contract_path,folder):
    from run_contact_sequence_native_v2 import invoke
    from run_creature_native import inventory
    contract=read(contract_path);plan=contract['prospective_comparison']
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
    source=git('rev-parse','HEAD')
    def unchanged():
        require(Path(git('rev-parse','--show-toplevel')).resolve()==ROOT and git('remote','get-url','origin')=='https://github.com/Slagathore/LoColemotion.git' and git('config','core.hooksPath')=='.githooks','Repository identity')
        require(git('rev-parse','HEAD')==source and not git('status','--porcelain') and git('ls-remote','origin','refs/heads/main').split()[0]==source,'Clean pushed freeze required')
        for item in contract['source_pins']+[contract['predecessor']]:require(sha(ROOT/item['path'])==item['sha256'],'Frozen source pin')
        for item in plan['runtime'].values():require(sha(EVIDENCE/item['archive_relative_path'])==item['sha256'],'Frozen runtime pin')
        require(sha(EVIDENCE/plan['helper']['archive_relative_path'])==plan['helper']['sha256'],'Frozen helper image')
    unchanged();require(plan['roles']==list(ROLES) and plan['maximum_worlds']==4 and plan['mean_reduction_minimum']==.05 and plan['both_pairs_must_improve'] is True,'Comparison plan')
    require(folder.resolve().is_relative_to(EVIDENCE.resolve()),'Durable evidence required');folder.mkdir(exist_ok=False)
    config={k:str(EVIDENCE/v['archive_relative_path']) for k,v in plan['runtime'].items()};config.update(source_commit=source,evidence_root=str(folder))
    write(folder/'config.json',config)
    result=dict(schema_version='locolemotion_studio_native_validation_comparison_owner_v1',ledger_scope=contract['ledger_scope'],
        source_commit=source,contract_sha256=sha(contract_path),ok=False,physical_acceptance_authority=False,release_authority=False)
    write(folder/'declaration.json',result);started=time.monotonic()
    env=dict(PYTHONPATH=';'.join(str(ROOT/p) for p in PATHS),PYTHONIOENCODING='utf-8',OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1')
    try:
        result['reader_controls']=controls()
        for role in ROLES:
            unchanged();print('Starting '+role,flush=True)
            invoke([sys.executable,'-B',str(ROOT/'sdk/explorer/studio/run_godot_cache_diagnostic.py'),'--config',str(folder/'config.json'),
                '--output',str(folder/role),'--live-walking','--walking-steps','119','--native-validator',str(EVIDENCE/plan['helper']['archive_relative_path']),
                '--native-validator-sha256',plan['helper']['sha256'],'--source-validation-policy',role.split('_')[0],'--run'],folder/(role+'-owned'),360,env)
        result['verification']=audit(folder);unchanged();result['ok']=True
    except BaseException as exc:result['error']=type(exc).__name__+': '+str(exc)
    finally:
        result['wall_s']=time.monotonic()-started;result['artifacts']=inventory(folder);write(folder/'receipt.json',result)
    print(json.dumps({k:v for k,v in result.items() if k!='artifacts'}),flush=True)
    return 0 if result['ok'] else 1


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--contract',type=Path);parser.add_argument('--output',type=Path)
    parser.add_argument('--audit',type=Path);parser.add_argument('--run',action='store_true');args=parser.parse_args()
    if args.run:raise SystemExit(run(args.contract.resolve(),args.output.resolve()))
    print(json.dumps(audit(args.audit.resolve()) if args.audit else controls(),indent=2))
