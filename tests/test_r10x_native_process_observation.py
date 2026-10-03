"""Prospective native-observer component; no SDK world or qualification."""
import ctypes
from ctypes import wintypes
import datetime
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Load a private fixture module. Never change the original discovery module's
# RUNNER: its seven CIM-route tests must remain independent and unchanged.
spec = importlib.util.spec_from_file_location(
    '_r10x_private_relationship_fixture', ROOT/'tests/test_qsdk_r10f_l15_launch_relationship.py')
legacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(legacy)
legacy.RUNNER = ROOT/'tests/test_r10x_native_process_observation.ps1'


class NativeLaunchRelationshipTests(legacy.LaunchRelationshipTests):
    """Same actual launcher and two readers, same seven tests and time bounds."""


class NativeObservationTests(unittest.TestCase):
    def observe(self, pids, repeat=1):
        return legacy.powershell('Observe', dict(pids=pids, repeat=repeat))

    def test_native_selection_requires_l15_context_before_launch(self):
        value = legacy.powershell('RejectMissingContext', dict(python=str(legacy.PYTHON)))
        self.assertIs(value['refused'], True, value)

    def test_exact_pid_parent_creation_and_image(self):
        value = self.observe([os.getpid()])['observations'][0]
        self.assertTrue(value['accepted'], value)
        node = value['node']
        self.assertEqual(os.getpid(), node['process_id'])
        self.assertEqual(os.getppid(), node['parent_process_id'])
        self.assertEqual(os.path.normcase(sys.executable), os.path.normcase(node['executable_path'].replace('/', os.sep)))
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.GetCurrentProcess.restype = wintypes.HANDLE
        kernel.GetProcessTimes.argtypes = [wintypes.HANDLE]+[ctypes.POINTER(wintypes.FILETIME)]*4
        kernel.GetProcessTimes.restype = wintypes.BOOL
        times = [wintypes.FILETIME() for _ in range(4)]
        self.assertTrue(kernel.GetProcessTimes(kernel.GetCurrentProcess(), *[ctypes.byref(t) for t in times]))
        ticks = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
        seconds, fraction = divmod(ticks, 10_000_000)
        stamp = datetime.datetime(1601, 1, 1) + datetime.timedelta(seconds=seconds)
        self.assertEqual(stamp.strftime('%Y-%m-%dT%H:%M:%S')+f'.{fraction:07d}Z', node['created_utc'])

    def test_invalid_and_unavailable_pids_refused(self):
        rows = self.observe([0, -1, 2147483647])['observations']
        self.assertEqual(3, len(rows))
        self.assertTrue(all(row['accepted'] is False for row in rows), rows)

    def test_exited_owned_process_refused(self):
        # Keep the original process object/handle while checking its dead PID.
        with subprocess.Popen([sys.executable, '-B', '-c', 'pass'], cwd=ROOT,
                              creationflags=subprocess.CREATE_NO_WINDOW) as child:
            self.assertEqual(0, child.wait(timeout=10))
            row = self.observe([child.pid])['observations'][0]
            self.assertIs(row['accepted'], False, row)

    def test_ancestry_guard_real_and_synthetic_refusals(self):
        with subprocess.Popen([sys.executable, '-B', '-c', 'pass'], cwd=ROOT,
                              creationflags=subprocess.CREATE_NO_WINDOW) as child:
            self.assertEqual(0, child.wait(timeout=10))
            value = legacy.powershell('Guard', dict(parent=os.getpid(), exited=child.pid))
        self.assertEqual(dict(self=True, parent=True, reversed=False, zero_root=False,
                              zero_candidate=False, unavailable=False, exited=False), value['real'])
        self.assertEqual(dict(sixteen_nodes=True, seventeen_nodes=False, cycle=False,
                              newer_parent=False), value['synthetic'])
        self.assertEqual(0, value['world_build_count'])
        self.assertEqual(0, value['solver_step_count'])

    def test_repeated_native_reads_complete_with_cim_unavailable(self):
        value = self.observe([os.getpid()], repeat=32)
        self.assertTrue(value['observations'][0]['accepted'], value)
        self.assertEqual(1, value['successful_reads'])
        self.assertEqual(32, value['native_batch']['SuccessfulReads'])
        # Read throws unless both native handle closures succeed. Whole-process
        # handle counts also include CLR/PowerShell allocations, so retain them
        # as diagnostics rather than attributing them to this observer.
        self.assertEqual(0, value['world_build_count'])
        self.assertEqual(0, value['solver_step_count'])
        print('R10X_NATIVE_HANDLE_OBSERVATION '+json.dumps(value), flush=True)


if __name__ == '__main__':
    unittest.main()
