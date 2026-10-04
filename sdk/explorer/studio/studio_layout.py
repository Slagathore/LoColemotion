"""Verify canonical development source or a complete isolated source projection."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[3]
CANONICAL=Path('C:/Users/Cole/CodeStuff/games/LoColemotion')
EVIDENCE=CANONICAL.parent/'SporeSpore_Evidence'
SCHEMA='sporespore_studio_isolated_source_v1'


def source_files(root):
    return sorted(p for p in root.rglob('*') if p.is_file() and p.name!='studio-layout.json'
                  and not {'target','__pycache__','.godot'}.intersection(p.relative_to(root).parts))


def isolated_source(root):
    if (root/'.git').exists() or (root/'project.godot').exists():raise ValueError('Isolated Studio must not contain a Git checkout or game project')
    value=json.loads((root/'studio-layout.json').read_text())
    if value['schema_version']!=SCHEMA or value['release_authority'] is not False or value['physical_acceptance_authority'] is not False:raise ValueError('Isolated source authority')
    source=value['source_commit']
    if len(source)!=40 or any(c not in '0123456789abcdef' for c in source):raise ValueError('Isolated source identity')
    expected={row['path']:row for row in value['files']}
    if len(expected)!=len(value['files']):raise ValueError('Repeated isolated source path')
    actual={p.relative_to(root).as_posix():p for p in source_files(root)}
    if actual.keys()!=expected.keys():raise ValueError('Isolated source population changed')
    for relative,path in actual.items():
        if not path.resolve().is_relative_to(root.resolve()):raise ValueError('Isolated source path escape')
        row=expected[relative]
        if path.stat().st_size!=row['byte_length'] or hashlib.sha256(path.read_bytes()).hexdigest()!=row['sha256']:raise ValueError('Isolated source changed: '+relative)
    return source


def verify_source(expected=None,physical=False,root=ROOT):
    root=root.resolve()
    if root!=CANONICAL.resolve():
        source=isolated_source(root)
    else:
        def git(*words):return subprocess.check_output(['git',*words],cwd=root,text=True).strip()
        if Path(git('rev-parse','--show-toplevel')).resolve()!=root or git('remote','get-url','origin')!='https://github.com/Slagathore/LoColemotion.git':raise RuntimeError('Repository identity')
        source=git('rev-parse','HEAD')
        if physical and (git('status','--porcelain') or git('ls-remote','origin','refs/heads/main').split()[0]!=source):raise RuntimeError('Physics requires clean pushed source')
    if expected is not None and source!=expected:raise RuntimeError('Studio source changed since launch')
    return source
