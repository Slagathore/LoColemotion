"""Build one immutable candidate runtime; emit its source declarations as a patch.

Run under the repository operation lock. Durable compiler logs and DLL are
create-only. This script never applies its generated source patch or runs physics.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

import development_passive_entry_profile as entry
import development_recovery_candidate as candidate

ROOT = candidate.ROOT


def identity(path, display=None):
    return entry.runtime.file_identity(path, display_path=display or path.as_posix())


def sources():
    paths = {ROOT / name for name in ('sdk/Cargo.toml', 'sdk/Cargo.lock', 'sdk/core/Cargo.toml',
                                     'sdk/core/build.rs', 'sdk/adapters/godot/Cargo.toml')}
    for directory in ('sdk/core/src', 'sdk/core/contracts', 'sdk/adapters/godot/src'):
        paths.update(path for path in (ROOT / directory).rglob('*') if path.is_file())
    # Include compile-time source data, not just the Rust files that name it.
    for path in list(paths):
        if path.suffix == '.rs':
            for name in re.findall(r'include_(?:str|bytes)!\s*\(\s*"([^"]+)"', path.read_text()):
                included = (path.parent / name).resolve()
                candidate.require(included.is_relative_to(ROOT), 'BUILD_SOURCE_ESCAPE')
                paths.add(included)
    return [identity(path, path.relative_to(ROOT).as_posix()) for path in sorted(paths)]


def build_configuration(candidate_id, build_profile='debug', compiler_cache_key=None):
    """Explicit optimization choice; existing callers keep their debug build."""
    candidate.require(re.fullmatch(r'[a-z0-9][a-z0-9-]{0,79}', candidate_id) is not None, 'BUILD_ID')
    candidate.require(build_profile in ('debug', 'release'), 'BUILD_PROFILE')
    target = 'sdk/target/development-candidate-' + candidate_id
    if compiler_cache_key is not None:
        candidate.require(re.fullmatch(r'[0-9a-f]{64}', compiler_cache_key) is not None, 'BUILD_CACHE_KEY')
        target = 'sdk/target/development-compiler-cache-v1/' + compiler_cache_key
    common = ['--locked', '--manifest-path', 'sdk/Cargo.toml', '--target-dir', target]
    if build_profile == 'release':
        common.append('--release')
    return common, ROOT / target / build_profile / 'sporespore_godot_adapter.dll'


def build_environment():
    """Bind build-option values without putting their raw contents in logs."""
    names = ('RUSTFLAGS', 'CARGO_ENCODED_RUSTFLAGS', 'RUSTC', 'RUSTC_WRAPPER',
             'RUSTC_WORKSPACE_WRAPPER', 'CARGO_BUILD_TARGET', 'CARGO_INCREMENTAL',
             'PATH', 'LIB', 'LIBPATH', 'INCLUDE', 'CC', 'CXX', 'CFLAGS', 'CXXFLAGS', 'LDFLAGS')
    return {name: entry.digest(os.environ[name].encode()) if name in os.environ else None for name in names}


def compiler_cache_identity(build_profile, rustc_version, cargo_version, environment, configs):
    """Partition mutable compiler work, never reuse a qualification/evidence key.

    Cargo still performs its own dependency checking on EVERY invocation. The
    exact current source graph, fresh tests, fixtures and copied DLL are bound
    separately; a cache directory existing does not establish a valid build.
    """
    value = dict(schema_version='sporespore_development_compiler_cache_v1',
        build_profile=build_profile, rustc_version=rustc_version, cargo_version=cargo_version,
        build_environment=environment, repository_cargo_configurations=configs)
    key = entry.digest(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).removeprefix('sha256:')
    return dict(key=key, inputs=value, qualification_or_test_evidence_reused=False)


def copy_image_once(source, destination):
    """Independent file, not a hardlink into the mutable compilation directory."""
    candidate.require(source.resolve() != destination.resolve(), 'BUILD_COPY_ALIAS')
    candidate.require(destination.resolve().is_relative_to(ROOT / 'sdk/target')
                      or destination.resolve().is_relative_to(entry.EVIDENCE), 'BUILD_COPY_DESTINATION')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with source.open('rb') as image, destination.open('xb') as copy:
        shutil.copyfileobj(image, copy)
    candidate.require(candidate.sha(source) == candidate.sha(destination), 'BUILD_COPY')


def build(args):
    common, built = build_configuration(args.candidate_id, args.build_profile)
    compiled = built
    profile_path = ROOT / f'sdk/development/recovery_candidates/{args.candidate_id}.json'
    binding_path = ROOT / f'sdk/development/recovery_candidates/{args.candidate_id}.runtime.json'
    extension_path = ROOT / f'sdk/adapters/godot/development_candidate_runtimes/{args.candidate_id}.gdextension'
    candidate.require(not any(path.exists() for path in (profile_path, binding_path, extension_path)), 'BUILD_ID_CONSUMED')
    before = entry._source_snapshot()
    source_files = sources()
    rustc_version = subprocess.check_output(['rustc', '-vV'], cwd=ROOT, text=True).strip()
    cargo_version = subprocess.check_output(['cargo', '--version'], cwd=ROOT, text=True).strip()
    environment = build_environment()
    configs = [identity(path, path.relative_to(ROOT).as_posix())
               for path in (ROOT / '.cargo/config', ROOT / '.cargo/config.toml',
                            ROOT / 'sdk/.cargo/config', ROOT / 'sdk/.cargo/config.toml') if path.is_file()]
    cache = None
    if getattr(args, 'reuse_build_cache', False):
        cache = compiler_cache_identity(args.build_profile, rustc_version, cargo_version, environment, configs)
        common, compiled = build_configuration(args.candidate_id, args.build_profile, cache['key'])
        cache['compilation_directory'] = compiled.parent.parent.relative_to(ROOT).as_posix()
        cache['directory_existed_before_build'] = compiled.parent.parent.exists()
    run = entry.EVIDENCE / ('development-candidate-build-' + uuid.uuid4().hex)
    run.mkdir()
    (run / 'source_snapshot.json').write_text(json.dumps(before, indent=2) + '\n', encoding='utf-8')
    if cache is not None:
        (run / 'compiler_cache.json').write_text(json.dumps(cache, indent=2) + '\n', encoding='utf-8')
    # Refuse to overwrite a previously retained candidate image.
    candidate.require(not built.exists(), 'BUILD_IMAGE_EXISTS')
    print('CANDIDATE_BUILD_ROOT ' + run.as_posix(), flush=True)
    receipts = []

    def execute(name, command):
        start = time.monotonic()
        with (run / (name + '.stdout.log')).open('xb') as out, (run / (name + '.stderr.log')).open('xb') as err:
            process = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, timeout=600,
                                     creationflags=subprocess.CREATE_NO_WINDOW)
        result = dict(stage=name, command=command, exit_code=process.returncode,
                      elapsed_seconds=time.monotonic() - start)
        receipts.append(result)
        (run / (name + '.execution.json')).write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        print('CANDIDATE_BUILD_STAGE ' + json.dumps(result, separators=(',', ':')), flush=True)
        candidate.require(process.returncode == 0, 'BUILD_STAGE_' + name)

    execute('core_tests', ['cargo', 'test', *common, '-p', 'sporespore-locomotion-core', '--lib'])
    execute('fixtures', ['cargo', 'test', *common, '-p', 'sporespore-locomotion-core', '--lib', args.fixture_test, '--', '--nocapture'])
    execute('adapter', ['cargo', 'build', *common, '-p', 'sporespore-godot-adapter'])
    candidate.require(entry.packet.same(before, entry._source_snapshot()) and entry.packet.same(source_files, sources())
                      and environment == build_environment(),
                      'BUILD_SOURCE_CHANGED')
    if cache is not None:
        # Published runtime paths remain per-candidate even though compilation
        # is shared. Rebuilding the cache must never change an old candidate.
        copy_image_once(compiled, built)
    durable = run / 'sporespore_godot_adapter.dll'
    copy_image_once(built, durable)
    core_log = (run / 'core_tests.stdout.log').read_text()
    counts = re.findall(r'test result: ok\. (\d+) passed; 0 failed;', core_log)
    candidate.require(len(counts) == 1 and int(counts[0]) > 0, 'BUILD_TEST_COUNT')
    binding = dict(schema_version='sporespore_development_recovery_candidate_runtime_binding_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='development_runtime_artifact_binding', question_class='development'),
        build_source_parent_commit=before['head'], build_stages=receipts,
        rustc_version=rustc_version, cargo_version=cargo_version,
        runtime=identity(durable), local_build_path=built.relative_to(ROOT).as_posix(), source_files=source_files,
        compiled_fixtures=identity(run / 'fixtures.stdout.log'), core_test_count=int(counts[0]),
        build_evidence_files=[identity(path) for path in sorted(run.iterdir()) if path.is_file() and path != durable],
        default_godot_extension_changed=False, old_pinned_adapter_overwritten=False,
        world_build_count=0, solver_step_count=0, qualification_authority=False,
        physical_acceptance_authority=False, release_authority=False)
    if cache is not None:
        binding['compiler_cache'] = cache
    binding_raw = json.dumps(binding, indent=2, allow_nan=False) + '\n'
    extension_raw = ('[configuration]\nentry_symbol = "gdext_rust_init"\ncompatibility_minimum = "4.7"\nreloadable = false\n\n'
                     '[libraries]\nwindows.debug.x86_64 = "res://' + binding['local_build_path'] + '"\n')
    profile = dict(schema_version=candidate.contract()['profile_schema'], candidate_id=args.candidate_id,
        post_kick_controller_id=args.controller_id, runtime_binding='res://' + binding_path.relative_to(ROOT).as_posix(),
        runtime_binding_sha256=entry.digest(binding_raw.encode()), runtime_sha256=binding['runtime']['raw_sha256'],
        extension='res://' + extension_path.relative_to(ROOT).as_posix(), extension_sha256=entry.digest(extension_raw.encode()),
        coverage_question=args.question)
    patch = '*** Begin Patch\n'
    for path, raw in ((binding_path, binding_raw), (extension_path, extension_raw),
                      (profile_path, json.dumps(profile, indent=2) + '\n')):
        patch += '*** Add File: ' + path.as_posix() + '\n' + '\n'.join('+' + line for line in raw.splitlines()) + '\n'
    patch += '*** End Patch\n'
    (run / 'candidate.patch').write_text(patch, encoding='utf-8')
    print('CANDIDATE_SOURCE_PATCH ' + (run / 'candidate.patch').as_posix(), flush=True)


def argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('--candidate-id', required=True)
    parser.add_argument('--controller-id', required=True)
    parser.add_argument('--fixture-test', required=True)
    parser.add_argument('--question', required=True)
    parser.add_argument('--build-profile', choices=('debug', 'release'), default='release',
                        help='Default: optimized release compiler mode. Explicit debug remains available. Neither grants release/acceptance authority.')
    parser.add_argument('--reuse-build-cache', action='store_true',
                        help='Reuse mutable compiler work only; run fresh tests and publish independent create-only DLL copies.')
    return parser


if __name__ == '__main__':
    build(argument_parser().parse_args())
