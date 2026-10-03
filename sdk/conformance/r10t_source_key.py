"""Declare a fresh R10T zero-world source key before a development attempt.

Each invocation creates a distinct contract. Prior keys and retained test records
are never rewritten; an actual R10T reservation closes this development helper.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
EVIDENCE=ROOT.parent/'SporeSpore_Evidence'
BASE=ROOT/'sdk/recovery/r10s_v56_walking_entry_contract_v8.json'
SELECTORS=[ROOT/'sdk/conformance/development_recovery_candidate.py',
           ROOT/'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd']

def sha(path):return 'sha256:'+hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def put(path,value):
    with path.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,indent=2);stream.write('\n')
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()

def declare(reason):
    assert Path(git('rev-parse','--show-toplevel')).resolve()==ROOT
    assert git('remote','get-url','origin')=='https://github.com/Slagathore/sporespore.git'
    assert not list(EVIDENCE.glob('r10t_*consumption_v1.json')), 'R10T population already reserved'
    previous=sorted((ROOT/'sdk/recovery').glob('r10t_v56_walking_entry_contract_v*.json'),
                    key=lambda p:int(re.search(r'_v(\d+)\.json$',p.name)[1]))[-1]
    revision=int(re.search(r'_v(\d+)\.json$',previous.name)[1])+1
    target=previous.with_name('r10t_v56_walking_entry_contract_v'+str(revision)+'.json')
    assert not target.exists()
    # Freeze selector references before hashing their actual bytes.
    for path in SELECTORS:
        raw=path.read_bytes();text=raw.decode('utf-8')
        text,n=re.subn(r'r10t_v56_walking_entry_contract_v\d+\.json',target.name,text)
        assert n==1,(path,n)
        path.write_bytes(text.encode('utf-8'))
    paths={x['path'] for x in read(BASE)['bound_source_files']}
    paths.add(BASE.relative_to(ROOT).as_posix())
    tracked=git('ls-files','--cached','--others','--exclude-standard').splitlines()
    owned=[name for name in tracked if 'r10t' in name and Path(name).suffix in ['.gd','.py','.json']]
    paths.update(owned)
    # Live publication code is part of this route's host boundary as well.
    publication_sources=['sdk/process/ExactJsonV1.cs','sdk/exact_json_transport.ps1',
        'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1',
        'tests/test_exact_json_transport.py','tests/test_exact_json_transport.ps1',
        'sdk/qsdk_r10f_l15_launch_relationship.ps1',
        'sdk/conformance/qsdk_r10f_l15_retained_integrity_failure.py',
        'tests/test_qsdk_r10f_l15_publication.py','tests/test_qsdk_r10f_l15_publication.ps1',
        'sdk/conformance/qsdk_r10f_physical_closure.py']
    paths.update(publication_sources)
    paths.update(['sdk/run_development_interfaces.ps1','sdk/run_development_recovery_smoke.ps1',
                  'sdk/conformance/development_recovery_smoke.py'])
    # Pin each new/changed source to its current line-ending bytes for clean checkout.
    attrs=ROOT/'.gitattributes';data=attrs.read_bytes()
    for name in sorted(set(owned+publication_sources+[p.relative_to(ROOT).as_posix() for p in SELECTORS]+
                           ['sdk/run_development_interfaces.ps1','sdk/run_development_recovery_smoke.ps1',
                            'sdk/conformance/development_recovery_smoke.py',target.relative_to(ROOT).as_posix()])):
        raw=(ROOT/name).read_bytes() if (ROOT/name).exists() else b''
        ending='crlf' if b'\r\n' in raw else 'lf'
        line=(name+' text eol='+ending).encode()
        if line not in data.splitlines():data+=line+b'\n'
    attrs.write_bytes(data);paths.add('.gitattributes')
    contract=read(previous)
    contract['schema_version']='sporespore_r10t_v56_walking_entry_contract_v'+str(revision)
    contract['source_key_complete']=True
    contract['predecessor_contract']=previous.relative_to(ROOT).as_posix()
    contract['predecessor_contract_sha256']=sha(previous)
    contract['source_revision_reason']=reason
    contract['dependency_coverage']='Complete predecessor dependency population plus all R10T production, test, contract, source-key and launch files; current bytes of shared affected sources. Declaration is not qualification. No physical reservation exists.'
    contract['bound_source_files']=[dict(path=name,raw_sha256=sha(ROOT/name)) for name in sorted(paths)]
    put(target,contract)
    return dict(ok=True,contract=target.relative_to(ROOT).as_posix(),raw_sha256=sha(target),
                source_files=len(paths),source_commit=git('rev-parse','HEAD'),
                world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--reason',required=True)
    print(json.dumps(declare(parser.parse_args().reason)))
