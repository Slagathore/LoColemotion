"""Bind actual runtime bytes, Git blobs and external images without normalizing history."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
import r10dh_contract as C

sys.path.insert(0, str(C.ROOT / 'sdk/discovery'))
import recovery_discovery as D

MANIFEST = 'sdk/recovery/r10dh_dependency_manifest_v2.json'
QUALIFICATION = 'sdk/recovery/r10dh_zero_world_qualification_v2.json'
DEVELOPMENT_QUALIFICATION = 'sdk/recovery/r10dh_development_qualification_v2.json'
AUTHORITY = 'sdk/recovery/r10dh_execution_authority_v2.json'
GHOST = 'sdk/recovery/r10dh_production_ghost_closure_v2.json'
PREREGISTRATION = 'sdk/recovery/r10dh_preregistration_v2.json'
OUTPUTS = {MANIFEST, QUALIFICATION, DEVELOPMENT_QUALIFICATION, AUTHORITY, GHOST,
           'sdk/recovery/r10dh_held_out_physical_closure_v2.json',
           'sdk/recovery/r10dh_release_gate_adoption_v2.json'}
# Preserve original observed outputs; the successor has its own bindings.
OUTPUTS |= {name.replace('_v2.json', '_v1.json') for name in OUTPUTS}
PREFIXES = ('sdk/', 'scripts/', 'tests/', 'addons/')
SUFFIXES = ('.py', '.ps1', '.gd', '.gdextension', '.json', '.rs', '.toml', '.lock',
            '.godot', '.cfg', '.tscn', '.tres', '.cs', '.csproj', '.props', '.targets',
            '.h', '.hpp', '.c', '.cpp', '.inc', '.glsl', '.gdshader')
EXTRA = ('project.godot', '.gitattributes', 'AGENTS.md')


def included(path):
    return ((path in EXTRA or path.startswith(PREFIXES) and path.endswith(SUFFIXES))
            and path not in OUTPUTS and not path.startswith('sdk/release/'))


def source_paths():
    raw = subprocess.check_output(['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=C.ROOT)
    return sorted({p for p in raw.decode().split('\0') if p and included(p)})


def git_blobs():
    raw = subprocess.check_output(['git', 'ls-files', '--stage', '-z'], cwd=C.ROOT).decode()
    result = {}
    for row in raw.split('\0'):
        if not row: continue
        meta, name = row.split('\t', 1)
        mode, oid, stage = meta.split()
        C.require(stage == '0', 'UNMERGED_INDEX')
        result[name] = dict(git_blob_oid=oid, git_mode=mode)
    return result


def runtime():
    host = C.read(C.ROOT / 'sdk/development/r10ap_host_runtime_contract_v1.json')
    profile = C.read(D.PROFILE)
    candidate = C.read(C.ROOT / profile['runtime_binding'].removeprefix('res://'))
    images = {k: v for k, v in host['images'].items() if k != 'sdk_adapter'}
    images['candidate_dll'] = candidate['runtime']
    images['candidate_local_dll'] = dict(candidate['runtime'], path=(C.ROOT/candidate['local_build_path']).as_posix())
    images['git'] = D.binding(Path(shutil.which('git')).resolve())
    images['declaration_template'] = D.binding(D.TEMPLATE)
    for row in images.values(): D.verify_binding(row)
    C.require(images['candidate_dll']['raw_sha256'] == 'sha256:76d05482da331ee4ed423f82672e2bf429222cd0efdeafa2f4f20c50a6023b81', 'RETAINED_V28')
    return dict(images=images)


def keyed(sources, images, configuration):
    for rows in (sources, list(images['images'].values())):
        C.require(len({r['path'] for r in rows}) == len(rows), 'MANIFEST_DUPLICATE_PATH')
    payload = dict(source_files=sources, runtime=images, git_configuration=configuration)
    return dict(schema_version='sporespore_r10dh_dependency_manifest_v1', ledger_scope=C.SCOPE,
                production_route_key=C.sha(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()),
                inclusion=dict(prefixes=list(PREFIXES), suffixes=list(SUFFIXES), extra=list(EXTRA),
                    graph_bound_outputs=sorted(OUTPUTS), release_bookkeeping_prefix='sdk/release/'),
                **payload, physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False)


def snapshot():
    D.repository(); blobs = git_blobs(); sources = []
    for name in source_paths():
        row = D.binding(C.ROOT/name); row['path'] = name
        row.update(blobs.get(name, dict(git_blob_oid=None, git_mode=None)))
        sources.append(row)
    configuration = {}
    for name in ('core.autocrlf', 'core.eol'):
        p = subprocess.run(['git', 'config', '--get', name], cwd=C.ROOT, capture_output=True, text=True)
        C.require(p.returncode in (0, 1), 'GIT_CONFIGURATION')
        configuration[name] = p.stdout.strip() if p.returncode == 0 else None
    return keyed(sources, runtime(), configuration)


def validate(value):
    C.require(C.same(value, snapshot()), 'DEPENDENCY_KEY_CHANGED')
    return value['production_route_key']


def archive(folder, value):
    path = Path(folder)/'source.zip'
    with zipfile.ZipFile(path, 'x', zipfile.ZIP_DEFLATED, compresslevel=1) as z:
        for row in value['source_files']:
            raw = (C.ROOT/row['path']).read_bytes()
            C.require(C.sha(raw) == row['raw_sha256'] and len(raw) == row['byte_length'], 'ARCHIVE_SOURCE_DRIFT')
            z.writestr(row['path'], raw)
    return D.binding(path)


if __name__ == '__main__':
    print(json.dumps(snapshot(), indent=2))
