"""Owned, time-bounded host-process fixture: no SDK, Godot, world or files."""

import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import sys
import threading


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode", choices=("self", "descendant", "worker"), required=True
    )
    parser.add_argument("--nonce", required=True)
    parser.add_argument("--marker", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    # Retain the real creation identity before readiness and owned termination.
    # A later PID-only query cannot distinguish PID reuse or an exited object.
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.GetCurrentProcess.argtypes = []
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    kernel.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
    kernel.GetProcessTimes.restype = wintypes.BOOL
    born, exited, system, user = (wintypes.FILETIME() for _ in range(4))
    if not kernel.GetProcessTimes(kernel.GetCurrentProcess(), ctypes.byref(born),
                                  ctypes.byref(exited), ctypes.byref(system), ctypes.byref(user)):
        raise ctypes.WinError(ctypes.get_last_error())
    identity = dict(pid=os.getpid(), creation_filetime=(born.dwHighDateTime << 32) | born.dwLowDateTime)
    print('QSDK_R10F_L15_NONPHYSICS_IDENTITY ' + json.dumps(identity), flush=True)
    if args.mode == "descendant":
        process = subprocess.Popen(
            [
                sys.executable,
                "-B",
                __file__,
                "--mode",
                "worker",
                "--nonce",
                args.nonce,
                "--marker",
                args.marker,
            ],
            cwd=root,
            creationflags=subprocess.CREATE_NO_WINDOW,
            stdin=subprocess.DEVNULL,
            stdout=sys.stdout,
            stderr=sys.stderr,
        )
        try:
            return process.wait(timeout=30)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
    ready = {
        "schema_version": "sporespore_godot_supervised_termination_ready_v1",
        "termination_protocol_id": "godot_4_7_gdscript_shutdown_containment_v1",
        "termination_nonce": args.nonce,
        "process_id": os.getpid(),
        "worker_receipt_emitted": True,
        "requested_exit_code": 0,
    }
    print(args.marker + json.dumps(ready, separators=(",", ":")), flush=True)
    threading.Event().wait(30)
    return 2  # The actual production launcher should terminate this owned tree.


if __name__ == "__main__":
    raise SystemExit(main())
