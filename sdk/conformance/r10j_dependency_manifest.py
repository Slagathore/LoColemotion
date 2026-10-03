"""Conservative complete local source key for the R10J production route.

The key includes all tracked/owned source and JSON inputs under the SDK,
adapters, scripts and tests rather than guessing which dynamic import runs.
Release bookkeeping and the explicitly named output records are outside the
physical route key. The committed graph binds those separately.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import r10j_campaign_authority as authority
import qsdk_r10f_l14_runtime_binding as runtime

ROOT = authority.ROOT
PREFIXES = ('sdk/', 'scripts/', 'tests/', 'addons/')
SUFFIXES = ('.py', '.ps1', '.gd', '.gdextension', '.json', '.rs', '.toml', '.lock',
            '.godot', '.cfg', '.tscn', '.tres', '.cs', '.csproj', '.props', '.targets',
            '.h', '.hpp', '.c', '.cpp', '.inc', '.glsl', '.gdshader')
OUTPUTS = {
    authority.MANIFEST_PATH, authority.AUTHORITY_PATH, authority.QUALIFICATION_PATH, authority.GHOST_PATH,
    'sdk/recovery/r10j_campaign_infrastructure_implementation_v1.json',
    'sdk/recovery/r10j_campaign_infrastructure_implementation_v2.json',
    'sdk/recovery/r10j_campaign_infrastructure_implementation_v3.json',
    'sdk/recovery/r10j_campaign_infrastructure_implementation_v4.json',
    'sdk/recovery/r10j_held_out_physical_closure_v1.json',
    'sdk/recovery/r10j_release_gate_adoption_v1.json',
}


def included(path):
    return ((path.startswith(PREFIXES) or path == 'project.godot') and
            path.endswith(SUFFIXES) and path not in OUTPUTS and not path.startswith('sdk/release/'))


def source_paths():
    result = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '-c', '-o', '--exclude-standard', '-z'],
                            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    paths = sorted(set(result.stdout.decode().rstrip('\0').split('\0')))
    return [p for p in paths if included(p)]


def identity(path):
    with path.open('rb') as stream:
        digest = 'sha256:'+hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(byte_length=path.stat().st_size, raw_sha256=digest)


def snapshot():
    authority.require(ROOT.resolve() == authority.EXPECTED_ROOT.resolve() and
                      authority.git('remote', 'get-url', 'origin') == authority.REMOTE, 'MANIFEST_REPOSITORY')
    sources = [dict(path=p, **identity(ROOT / p)) for p in source_paths()]
    binding_path = ROOT / 'sdk/development/recovery_candidates/r10i-joint-pose-entry-core-v1.runtime.json'
    binding = authority.parse(binding_path.read_bytes())
    external = [dict(path=image['path'], **identity(Path(image['path']))) for image in runtime.IMAGES.values()]
    external.append(dict(path=binding['runtime']['path'], **identity(Path(binding['runtime']['path']))))
    key_input = dict(source_files=sources, runtime_files=sorted(external, key=lambda p:p['path']))
    key = authority.sha(json.dumps(key_input, sort_keys=True, separators=(',', ':')).encode())
    return dict(schema_version='sporespore_r10j_dependency_manifest_v1',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                                  authority_mode='prospective_dependency_closure', question_class='finite decision'),
                production_route_key=key, source_path_count=len(sources),
                inclusion=dict(prefixes=list(PREFIXES), suffixes=list(SUFFIXES), extra_paths=['project.godot'],
                               separately_bound_output_paths=sorted(OUTPUTS),
                               release_bookkeeping_excluded_prefix='sdk/release/'),
                **key_input, physical_execution_authorized=False,
                physical_acceptance_authority=False, release_authority=False)


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
