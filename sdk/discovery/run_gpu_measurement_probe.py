"""Qualify and run the complete bounded measurement route with retained failures."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

from gpu_measurement_probe import CONTRACT, HERE, ROOT, load_contract, write_new
from audit_gpu_measurement_probe import audit

sys.path.insert(0, str(ROOT / 'sdk/explorer'))
from showcase_owner import OwnedChild, jobs


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def source_identity(clean):
    def git(*words):
        return subprocess.check_output(['git', *words], cwd=ROOT, text=True).strip()
    if (Path(git('rev-parse', '--show-toplevel')).resolve() != ROOT
            or git('remote', 'get-url', 'origin') != 'https://github.com/Slagathore/LoColemotion.git'
            or git('config', 'core.hooksPath') != '.githooks'):
        raise ValueError('Repository identity mismatch')
    source = git('rev-parse', 'HEAD')
    if clean and (git('status', '--porcelain') or git('ls-remote', 'origin', 'refs/heads/main').split()[0] != source):
        raise ValueError('Physical work requires clean pushed main')
    return source


def bindings():
    paths = list(HERE.glob('*.py')) + [CONTRACT]
    paths += [ROOT/'sdk/explorer'/name for name in ['showcase_owner.py', 'showcase_model.py', 'test_showcase.py']]
    paths += [ROOT/'sdk/conformance/r10v_windows_job.py', ROOT/'sdk/python/sporespore_locomotion.py']
    paths += [ROOT/'sdk/docs/figures/mujoco-force-sampling.csv']
    runtime = [Path(sys.executable), Path(sys.base_prefix)/'python311.dll']
    for package in ['mujoco', 'mujoco_warp', 'warp', 'numpy']:
        spec = importlib.util.find_spec(package)
        if not spec or not spec.origin:
            raise ValueError('Missing runtime package: '+package)
        directory = Path(spec.origin).parent
        runtime += [p for p in directory.rglob('*') if p.is_file() and p.suffix.lower()
                    in ['.py', '.pyd', '.dll', '.cu', '.h', '.hpp', '.cpp', '.ptx', '.lib', '.so']]
    # NumPy's external numerical libraries are part of the actual runtime too.
    numpy_libs = Path(importlib.util.find_spec('numpy').origin).parent.parent/'numpy.libs'
    runtime += list(numpy_libs.glob('*.dll'))
    return dict(source={str(p.relative_to(ROOT)): digest(p) for p in sorted(set(paths))},
                runtime={str(p): digest(p) for p in sorted(set(runtime))},
                gpu=subprocess.check_output(['nvidia-smi', '--query-gpu=index,uuid,name,driver_version', '--format=csv,noheader'], cwd=ROOT, text=True).strip())


def invoke(command, folder, timeout, env=None):
    folder.mkdir()
    child = OwnedChild(command, ROOT, dict(PYTHONDONTWRITEBYTECODE='1', **(env or {})), folder)
    started = time.monotonic()
    try:
        while child.process.poll() is None:
            if time.monotonic()-started > timeout:
                raise TimeoutError('Contained stage exceeded wall limit: '+folder.name)
            time.sleep(.05)
        if child.process.returncode:
            raise RuntimeError(f'Contained stage failed ({child.process.returncode}): {folder}')
    finally:
        child.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    source = source_identity(args.run)
    contract = load_contract()
    folder = ROOT.parent/'SporeSpore_Evidence'/('sdk2-gpu-measurement-'+uuid.uuid4().hex)
    folder.mkdir()
    print(str(folder), flush=True)
    receipt = dict(ledger_scope=contract['ledger_scope'], source_commit=source, contract=contract,
                   ok=False, physical_started=False, physical_acceptance_authority=False,
                   release_authority=False, training_data_authority=False)
    create = jobs.api('CreateMutexW', [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
    release = jobs.api('ReleaseMutex', [W.HANDLE])
    handle = jobs.checked(create(None, False, 'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'))
    acquired = False
    try:
        if jobs.wait(handle, 0) not in (0, 128):
            raise RuntimeError('Another native operation owns the mutex')
        acquired = True
        receipt['binding'] = bindings()
        write_new(folder/'declaration.json', receipt)
        invoke([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', str(HERE),
                '-p', 'test_actuation_measurement.py', '-v'], folder/'measurement-gate', 60)
        invoke([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', str(HERE),
                '-p', 'test_gpu_measurement_probe.py', '-v'], folder/'probe-gate', 60)
        invoke([sys.executable, '-B', '-m', 'unittest', 'test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant'],
               folder/'containment-gate', 60, dict(PYTHONPATH=str(ROOT/'sdk/explorer'), EXPLORER_TEST_OUTPUT=str(folder)))
        invoke([sys.executable, '-B', str(HERE/'gpu_measurement_probe.py'), '--check-only'], folder/'runtime-gate', 60)
        if bindings() != receipt['binding'] or source_identity(args.run) != source:
            raise RuntimeError('Qualification source/runtime drift')
        receipt['zero_world_gate_passed'] = True
        if args.run:
            physical = folder/'physical'
            # Claim is written once and never reused, even if construction fails.
            write_new(folder/'consumed.json', dict(source_commit=source, attempt_id=folder.name))
            receipt['physical_started'] = True
            invoke([sys.executable, '-B', str(HERE/'gpu_measurement_probe.py'), '--output', str(physical),
                    '--permit', str(physical/'contained.permit')], physical, contract['maximum_worker_wall_seconds'])
            receipt['audit'] = audit(physical)
            write_new(folder/'independent-audit.json', receipt['audit'])
        if bindings() != receipt['binding'] or source_identity(args.run) != source:
            raise RuntimeError('Execution source/runtime drift')
        receipt['ok'] = True
    except BaseException as exc:
        receipt['error'] = f'{type(exc).__name__}: {exc}'
    finally:
        if acquired:
            release(handle)
        jobs.close(handle)
        write_new(folder/'receipt.json', receipt)
    print(json.dumps(dict(ok=receipt['ok'], output=str(folder), error=receipt.get('error'),
                         physical_started=receipt['physical_started'])), flush=True)
    return 0 if receipt['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
