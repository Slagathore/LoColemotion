"""Claim one native diagnostic child before construction; replay only verifies it."""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path

import r10ac_development_launch as launch
import r10ac_development_v2 as identity
import r10ac_host_runtime as host

CLAIM = 'r10ac_native_world_claim_v1.json'
PREFIX = 'SPORESPORE_GODOT_RECOVERY_'


def require(ok, code):
    if not ok: raise ValueError('R10AC_NATIVE_WORLD_' + code)


def worker_image(pid):
    """Read the live process image while holding its process handle."""
    require(type(pid) is int and pid > 0 and os.name == 'nt', 'WORKER_PID')
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
    kernel.QueryFullProcessImageNameW.restype = wintypes.BOOL
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    handle = kernel.OpenProcess(0x1000, False, pid)
    require(bool(handle), 'WORKER_HANDLE')
    try:
        buffer = ctypes.create_unicode_buffer(32768); size = wintypes.DWORD(len(buffer))
        require(bool(kernel.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(size))), 'WORKER_IMAGE')
        return host.predecessor.file_identity(Path(buffer.value))
    finally:
        kernel.CloseHandle(handle)


def validate_worker(pid):
    require(type(pid) is int and pid == os.getppid(), 'HELPER_PARENT')
    expected = host.expected_binding()['images']['godot_engine']
    actual = worker_image(pid)
    require(Path(actual['path']).resolve() == Path(expected['path']).resolve()
        and actual['raw_sha256'] == expected['raw_sha256']
        and actual['byte_length'] == expected['byte_length'], 'RUNNING_IMAGE')
    return expected


def expected_claim(path, declaration, pid):
    child = declaration['children'][0]
    return dict(schema_version='sporespore_r10ac_native_world_claim_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='single_use_native_diagnostic_child_claim', question_class='development'),
        parent_attempt_id=declaration['attempt_id'], child_attempt_id=child['child_attempt_id'],
        role=child['role'], termination_nonce=child['termination_nonce'], worker_process_id=pid,
        worker_image=host.expected_binding()['images']['godot_engine'], source_commit=declaration['source_snapshot']['head'],
        declaration=launch.binding(path), launch_receipt=launch.binding(path.parent / launch.LAUNCH_FILE),
        population_reservation=launch.binding(launch.EVIDENCE / launch.TOKEN),
        source_key=launch.binding(launch.candidate.R10AC_ROUTE_ENTRY_PATH),
        maximum_world_builds=1, permission_scope='diagnostic_world_construction_only',
        physical_acceptance_authority=False, release_authority=False)


def claim(path, pid):
    path = Path(path).resolve()
    declaration = launch.declared(path)
    child = declaration['children'][0]
    expected_env = dict(AUTHORIZATION_SHA256=identity.sha(path), SOURCE_COMMIT=declaration['source_snapshot']['head'],
        PARENT_ATTEMPT_ID=declaration['attempt_id'], ATTEMPT_ID=child['child_attempt_id'],
        CHILD_ROLE=child['role'], TERMINATION_NONCE=child['termination_nonce'],
        SEED=str(identity.SEED), SEED_LABEL=identity.seed_identity(identity.SEED)['label'],
        SEED_SHA256=identity.seed_identity(identity.SEED)['sha256'], SUPERVISED_TERMINATION='1')
    require(all(os.environ.get(PREFIX + key) == value for key, value in expected_env.items()), 'CHILD_ENVIRONMENT')
    validate_worker(pid)
    launch.verify(path)
    launch.current_freeze(declaration['source_snapshot']['head'])
    runtime = host.expected_binding()
    host.bind_runtime(runtime['images']['godot_console']['path'], runtime['images']['powershell_host']['path'])
    target = Path(child['evidence_path']) / CLAIM
    value = expected_claim(path, declaration, pid)
    try:
        # Exclusive create and fsync. A partial write still blocks another claim.
        launch.write_new(target, value)
    except FileExistsError as error:
        raise ValueError('R10AC_NATIVE_WORLD_CHILD_ALREADY_CLAIMED') from error
    return dict(ok=True, claim=value, claim_binding=launch.binding(target),
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def verify(path, pid):
    """Historical verification never requires the exited worker to remain alive."""
    path = Path(path).resolve(); declaration = launch.declared(path)
    require(type(pid) is int and pid > 0, 'WORKER_PID')
    launch.verify(path)
    target = Path(declaration['children'][0]['evidence_path']) / CLAIM
    require(target.is_file(), 'CLAIM_REQUIRED')
    require(launch.same(launch.read(target), expected_claim(path, declaration, pid)), 'CLAIM_BINDING')
    return launch.binding(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--claim', type=Path); modes.add_argument('--verify', type=Path)
    modes.add_argument('--probe-worker', action='store_true')
    parser.add_argument('--worker-pid', type=int, required=True)
    args = parser.parse_args()
    try:
        result = (claim(args.claim, args.worker_pid) if args.claim else
            dict(ok=True, claim_binding=verify(args.verify, args.worker_pid)) if args.verify else
            dict(ok=True, worker_image=validate_worker(args.worker_pid), world_build_count=0, solver_step_count=0))
        print(json.dumps(result, separators=(',', ':')))
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), world_build_count=0, solver_step_count=0)))
        raise SystemExit(1)
