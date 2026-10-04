"""Build a separately named optimized diagnostic engine; never launch physics.

Keep dev_build=yes and every existing instrumentation patch. Only the explicit
optimization level changes. A fresh suffix isolates generated objects/binaries,
and the original retained runtime is verified before and after the build.
"""
import argparse
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

SDK = Path(__file__).resolve().parents[2]
ROOT = SDK.parent
sys.path.insert(0, str(SDK / 'explorer'))
from showcase_owner import jobs
from showcase_model import sha
from run_mujoco_sandbox import invoke, write


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build', action='store_true')
    args = parser.parse_args()
    def git(*words):
        return subprocess.check_output(['git', *words], cwd=ROOT, text=True).strip()
    if Path(git('rev-parse', '--show-toplevel')).resolve() != ROOT or git('remote', 'get-url', 'origin') != 'https://github.com/Slagathore/LoColemotion.git':
        raise RuntimeError('Repository identity')
    source = git('rev-parse', 'HEAD')
    if args.build and (git('status', '--porcelain') or git('ls-remote', 'origin', 'refs/heads/main').split()[0] != source):
        raise RuntimeError('Build requires clean pushed source')
    folder = args.output.resolve()
    if not folder.is_relative_to(ROOT.parent / 'SporeSpore_Evidence'):
        raise ValueError('Durable evidence root required')
    cfg = json.loads(args.config.read_text(encoding='utf-8-sig'))
    checkout = Path('C:/Users/Cole/CodeStuff/dependencies/godot-sporespore-4.7-r10ac-contact-frames-v7')
    if (checkout / 'custom.py').exists():
        raise RuntimeError('Unexpected local build-option overrides')
    if shutil.disk_usage(checkout).free < 30 * 2**30:
        raise RuntimeError('Build needs 30 GiB of free workspace')
    folder.mkdir(parents=True, exist_ok=False)
    suffix = 'stsp_' + hashlib.sha256(str(folder).encode()).hexdigest()[:8]
    names = [f'godot.windows.editor.dev.x86_64.{suffix}{tail}.exe' for tail in ['', '.console']]
    if any((checkout / 'bin' / name).exists() for name in names):
        raise RuntimeError('Prospective build image already exists')
    checker = SDK / 'conformance/r10ac_contact_frame_patch.py'
    inputs = [Path(__file__), SDK / 'explorer/showcase_owner.py', SDK / 'explorer/showcase_model.py',
              SDK / 'explorer/studio/run_mujoco_sandbox.py', SDK / 'conformance/r10v_windows_job.py',
              checker, SDK / 'conformance/r10ac_contact_sampling_component.py',
              SDK / 'conformance/r10ac_support_loss_diagnosis.py',
              SDK / 'adapters/godot/engine_patches/godot_4_7_jolt_contact_frames_v7.patch']
    binding = lambda: {str(p): sha(p) for p in inputs}
    original = {str(Path(cfg[key]).resolve()): sha(Path(cfg[key])) for key in ['recovery_engine', 'recovery_console', 'recovery_dll']}
    command = [sys.executable, '-B', '-m', 'SCons', '-C', str(checkout), 'platform=windows',
               'target=editor', 'dev_build=yes', 'debug_symbols=no', 'accesskit=no', 'd3d12=no',
               'optimize=speed', f'extra_suffix={suffix}', 'verbose=yes', '-j4']
    receipt = dict(schema_version='sporespore_studio_optimized_godot_build_v1',
                   ledger_scope=dict(subsystem='explorer', engine_scope='godot_jolt', authority_mode='development', question_class='development'),
                   source_commit=source, source_binding=binding(), preserved_runtime=original,
                   command=command, checkout=str(checkout), maximum_build_wall_seconds=5400,
                   world_build_count=0, solver_step_count=0, physical_acceptance_authority=False,
                   release_authority=False, ok=False)
    create = jobs.api('CreateMutexW', [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
    release = jobs.api('ReleaseMutex', [W.HANDLE])
    handle = jobs.checked(create(None, False, 'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'))
    acquired = False
    try:
        if jobs.wait(handle, 0) not in (0, 128):
            raise RuntimeError('Native operation mutex occupied')
        acquired = True
        write(folder / 'declaration.json', receipt)
        env = dict(EXPLORER_TEST_CORE=cfg['core'], EXPLORER_TEST_OUTPUT=str(folder), PYTHONDONTWRITEBYTECODE='1')
        invoke([sys.executable, '-B', str(SDK / 'explorer/test_showcase.py')], folder / 'ownership-and-stream', env, 90)
        check_command = [sys.executable, '-B', str(checker), '--verify-checkout', str(checkout)]
        invoke(check_command, folder / 'source-before', {}, 90)
        before = json.loads((folder / 'source-before/stdout.log').read_text())
        receipt['engine_source'] = before
        if binding() != receipt['source_binding']:
            raise RuntimeError('Build source drift')
        if args.build:
            started = time.monotonic()
            invoke(command, folder / 'compile', dict(PYTHONDONTWRITEBYTECODE='1'), 5400)
            receipt['build_wall_seconds'] = time.monotonic() - started
            invoke(check_command, folder / 'source-after', {}, 90)
            if json.loads((folder / 'source-after/stdout.log').read_text()) != before:
                raise RuntimeError('Engine source changed during build')
            # Verbose MSVC output verifies the actual optimization switch.
            log = (folder / 'compile/stdout.log').read_text(encoding='utf-8', errors='replace')
            if '/O2' not in log or '/Od ' in log:
                raise RuntimeError('Compiler optimization evidence missing or crossed')
            receipt['artifacts'] = []
            for key, name in zip(['recovery_engine', 'recovery_console'], names):
                original_path = checkout / 'bin' / name
                destination = folder / name
                if not original_path.is_file():
                    raise RuntimeError(f'Missing newly named engine image: {name}')
                shutil.copy2(original_path, destination)
                receipt['artifacts'].append(dict(role=key, path=str(destination), sha256=sha(destination), byte_length=destination.stat().st_size))
                cfg[key] = str(destination)
            cfg['source_commit'] = source
            write(folder / 'config.json', cfg)
        if binding() != receipt['source_binding'] or any(sha(Path(path)) != digest for path, digest in original.items()):
            raise RuntimeError('Source or original runtime changed')
        receipt['ok'] = True
    except BaseException as exc:
        receipt['error'] = f'{type(exc).__name__}: {exc}'
    finally:
        write(folder / 'receipt.json', receipt)
        if acquired:
            release(handle)
        jobs.close(handle)
    print(json.dumps(dict(ok=receipt['ok'], error=receipt.get('error'), output=str(folder), built=bool(receipt.get('artifacts')))))
    return 0 if receipt['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
