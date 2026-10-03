"""Declare a distinct R10X source key before its first physical consumption.

R10V v23 and its consumed populations remain unchanged. The complete outer
manifest additionally binds every conservative source/runtime dependency.
"""
import argparse
import json
from pathlib import Path
import re

import r10x_dependency_manifest as dependencies
import r10x_campaign_authority as authority

ROOT = authority.ROOT
BASE = ROOT / 'sdk/recovery/r10w_v56_walking_entry_contract_v9.json'
SELECTORS = [ROOT/'sdk/conformance/development_recovery_candidate.py',
             ROOT/'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd']


def declare(reason):
    authority.require(Path(authority.git('rev-parse','--show-toplevel')).resolve()==ROOT
        and authority.git('remote','get-url','origin')==authority.REMOTE,'SOURCE_KEY_REPOSITORY')
    authority.require(not authority.CLAIM_PATH.parent.exists()
        and not list(authority.EVIDENCE.glob('r10x-production-ghost-*/campaign_claim.json')),
        'SOURCE_KEY_POPULATION_CONSUMED')
    authority.require(type(reason) is str and bool(reason.strip()),'SOURCE_KEY_REASON')
    versions=list((ROOT/'sdk/recovery').glob('r10x_v56_walking_entry_contract_v*.json'))
    previous=max(versions,key=lambda p:int(re.search(r'_v(\d+)\.json$',p.name)[1])) if versions else BASE
    version=int(re.search(r'_v(\d+)\.json$',previous.name)[1])+1 if versions else 1
    target=ROOT/'sdk/recovery'/f'r10x_v56_walking_entry_contract_v{version}.json'
    authority.require(not target.exists(),'SOURCE_KEY_IDENTITY_REUSED')
    for path in SELECTORS:
        raw=path.read_bytes().decode('utf-8')
        text,count=re.subn(r'r10[vwx]_v56_walking_entry_contract_v\d+\.json',target.name,raw)
        authority.require(count==1,'SOURCE_KEY_SELECTOR')
        path.write_bytes(text.encode('utf-8'))
    original=json.loads(BASE.read_bytes())
    files={row['path'] for row in original['bound_source_files']}
    files.add(BASE.relative_to(ROOT).as_posix())
    files.update(path for path in dependencies.source_paths() if 'r10x' in path)
    files.discard(target.relative_to(ROOT).as_posix())
    files.difference_update(dependencies.OUTPUTS)
    value=dict(original,schema_version=f'sporespore_r10x_v56_walking_entry_contract_v{version}',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='prospective_campaign_source_binding',question_class='finite decision'),
        compatibility_scope='R10X campaign admission and prefix mapping over unchanged R10V native behavior and task predicates.',
        source_key_complete=True,predecessor_contract=previous.relative_to(ROOT).as_posix(),
        predecessor_contract_sha256=dependencies.identity(previous)['raw_sha256'],source_revision_reason=reason,
        dependency_coverage='Complete R10W v9 input population plus every current R10X non-output input. The outer R10X dependency manifest independently binds all conservative source and runtime inputs. Qualification and launch authority remain separate.',
        bound_source_files=[dict(path=path,**dependencies.identity(ROOT/path)) for path in sorted(files)])
    with target.open('x',encoding='utf-8',newline='\r\n') as stream:
        json.dump(value,stream,indent=2);stream.write('\n')
    return dict(path=target.relative_to(ROOT).as_posix(),**dependencies.identity(target),source_files=len(files),
        world_build_count=0,solver_step_count=0,physical_execution_authorized=False,physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--reason',required=True)
    print(json.dumps(declare(parser.parse_args().reason)))
