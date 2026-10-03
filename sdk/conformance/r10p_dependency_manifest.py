"""Complete conservative R10P source/runtime key. Snapshotting opens no world.

Every source or JSON input under the SDK, scripts, tests and addons is included.
The explicit output records and release bookkeeping are bound by the committed
authority graph instead, avoiding a self-referential manifest or ghost key.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import qsdk_r10f_l14_runtime_binding as runtime
import r10p_campaign_authority as authority

ROOT = authority.ROOT
PREFIXES = ('sdk/', 'scripts/', 'tests/', 'addons/')
SUFFIXES = ('.py', '.ps1', '.gd', '.gdextension', '.json', '.rs', '.toml', '.lock',
            '.godot', '.cfg', '.tscn', '.tres', '.cs', '.csproj', '.props', '.targets',
            '.h', '.hpp', '.c', '.cpp', '.inc', '.glsl', '.gdshader')
OUTPUTS = {
    authority.MANIFEST_PATH, authority.AUTHORITY_PATH, authority.QUALIFICATION_PATH, authority.GHOST_PATH,
    'sdk/recovery/r10p_campaign_infrastructure_implementation_v1.json',
    'sdk/recovery/r10p_held_out_physical_closure_v1.json',
    'sdk/recovery/r10p_release_gate_adoption_v1.json',
}
RUNTIME_BINDING_PATH = 'sdk/development/recovery_candidates/v55-initialized-zero-brake-core-v1.runtime.json'


def included(path):
    return ((path.startswith(PREFIXES) or path == 'project.godot') and path.endswith(SUFFIXES)
            and path not in OUTPUTS and not path.startswith('sdk/release/'))


def source_paths():
    result = subprocess.run(['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    paths = sorted(set(result.stdout.decode('utf-8').rstrip('\0').split('\0')))
    return [path for path in paths if included(path)]


def identity(path):
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(byte_length=path.stat().st_size, raw_sha256=digest)


def keyed_manifest(sources, external):
    """Pure key construction shared with source and runtime corruption controls."""
    for rows in (sources, external):
        authority.require(len({row['path'] for row in rows}) == len(rows), 'MANIFEST_DUPLICATE_PATH')
    key_input = dict(source_files=sorted(sources, key=lambda row: row['path']),
                     runtime_files=sorted(external, key=lambda row: row['path']))
    key = authority.sha(json.dumps(key_input, sort_keys=True, separators=(',', ':')).encode())
    return dict(schema_version='sporespore_r10p_dependency_manifest_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='prospective_dependency_closure', question_class='finite decision'),
        production_route_key=key, source_path_count=len(sources),
        inclusion=dict(prefixes=list(PREFIXES), suffixes=list(SUFFIXES), extra_paths=['project.godot'],
            separately_bound_output_paths=sorted(OUTPUTS), release_bookkeeping_excluded_prefix='sdk/release/'),
        **key_input, physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False)


def snapshot():
    authority.require(ROOT.resolve() == authority.EXPECTED_ROOT.resolve()
        and Path(authority.git('rev-parse', '--show-toplevel')).resolve() == ROOT.resolve()
        and authority.git('remote', 'get-url', 'origin') == authority.REMOTE, 'MANIFEST_REPOSITORY')
    sources = [dict(path=path, **identity(ROOT / path)) for path in source_paths()]
    bound = authority.parse((ROOT / RUNTIME_BINDING_PATH).read_bytes())
    external = [dict(path=image['path'], **identity(Path(image['path']))) for image in runtime.IMAGES.values()]
    dll = dict(path=bound['runtime']['path'], **identity(Path(bound['runtime']['path'])))
    authority.require(authority.same(dll, bound['runtime'])
        and dll['raw_sha256'] == 'sha256:c9303b0e7209f63c8b132a271d1ec32ce69f8768409f22d1f4cee6fcd12a5437',
        'MANIFEST_V55_RUNTIME')
    external.append(dll)
    return keyed_manifest(sources, external)


def validate(manifest):
    current = snapshot()
    authority.require(authority.same(manifest, current), 'DEPENDENCY_MANIFEST_DRIFT')
    return current['production_route_key']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['snapshot', 'validate'])
    args = parser.parse_args()
    try:
        value = snapshot() if args.command == 'snapshot' else dict(production_route_key=validate(
            authority.parse((ROOT / authority.MANIFEST_PATH).read_bytes())))
        print(json.dumps(dict(ok=True, result=value), allow_nan=False))
        return 0
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), physical_execution_authorized=False)))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
