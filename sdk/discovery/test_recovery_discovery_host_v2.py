"""Real Windows zero-world lifecycle controls; no Godot or solver launch."""
import copy
import io
import json
from pathlib import Path
import subprocess
import sys
import time
import unittest
import recovery_discovery_host_v2 as H

D, W = H.D, H.W
ROOTS = []


def until(predicate, timeout=150):
    end = time.monotonic()+timeout
    while time.monotonic() < end:
        value = predicate()
        if value: return value
        time.sleep(.1)
    raise AssertionError('fixture deadline')


def stop_identity(identity):
    # Keep the checked process handle open through termination: PID reuse
    # cannot redirect this test's cleanup to a different process.
    handle = W.open_process(0x1000 | 0x100000 | 1, False, identity['pid'])
    if not handle: return
    try:
        created, exited, kernel, user = (W.W.FILETIME() for _ in range(4))
        W.checked(W.times(handle, W.C.byref(created), W.C.byref(exited), W.C.byref(kernel), W.C.byref(user)))
        actual = (created.dwHighDateTime << 32) | created.dwLowDateTime
        if actual != identity['creation_filetime']: return
        terminate = W.api('TerminateProcess', [W.W.HANDLE, W.W.UINT])
        W.checked(terminate(handle, 125))
        W.wait(handle, 10000)
    finally: W.close(handle)


def start(case='success', hold=1, deadline=60):
    path = H.prepare('fixture', case=case, hold=hold, deadline=deadline)
    ROOTS.append(path.parent)
    H.launch(path)
    return path.parent


def terminal(root):
    until(lambda: (root/'published.json').exists())
    result = H.status(root)
    until(lambda: not W.alive(D.read(root/'launch.json')['host_identity']))
    if (root/'fixture-ready.json').exists():
        assert not W.alive(D.read(root/'fixture-ready.json')['child_identity'])
    return result


class Controls(unittest.TestCase):
    def test_formal_route_bounds_and_command(self):
        path = H.prepare('fixture'); ROOTS.append(path.parent)
        value = D.read(path)
        value.update(mode='r10dh',case=None,hold_seconds=0,batch='declared-batch',maximum_cells=6,workers=1,deadline_seconds=18660)
        H.validate_shape(value)
        self.assertIn(str(D.ROOT/'sdk/conformance/run_r10dh_campaign.ps1'),H.command(path,value))
        for change in (dict(workers=2,deadline_seconds=9390),dict(maximum_cells=4,deadline_seconds=12480),dict(case='success')):
            with self.subTest(change=change),self.assertRaises(ValueError):H.validate_shape(dict(value,**change))

    def tearDown(self):
        for root in ROOTS:
            if (root/'launch.json').exists():
                identity = D.read(root/'launch.json')['host_identity']
                if W.alive(identity): stop_identity(identity)

    def test_success_and_no_reuse(self):
        root = start()
        with self.assertRaises(FileExistsError): H.launch(root/'request.json')
        result = terminal(root)
        self.assertEqual('complete', result['state'])
        self.assertTrue(result['result']['owned_cleanup_complete'])
        self.assertTrue(D.read(root/'fixture-ready.json')['in_job'])

    def test_nested_powershell_pool(self):
        for case in ('nested_pool', 'nested_pool', 'nested_pool', 'nested_coordinator', 'nested_orphan'):
            with self.subTest(case=case):
                root = start(case, hold=.1, deadline=120)
                result = terminal(root)
                self.assertEqual('failed' if case == 'nested_orphan' else 'complete', result['state'])
                if case == 'nested_orphan':
                    self.assertIn('HOST_ORPHAN_DESCENDANT', result['result']['error'])
                self.assertTrue(result['result']['owned_cleanup_complete'])
                for i in range(2):
                    leaf = D.read(root/('nested-leaf-'+str(i)+'.json'))
                    self.assertEqual(0, leaf['exit_code'])
                    self.assertFalse(W.alive(leaf['child_identity']))
                    cleanup = D.read(root/('nested-cleanup-'+str(i)+'.json'))
                    self.assertTrue(cleanup['cleanup_complete'])
                    self.assertEqual([], cleanup['remaining_owned_pids'])
                    for row in cleanup['before_termination']:
                        if row['identity'] is not None:
                            self.assertFalse(W.alive(row['identity']))

    def test_exact_selected_population(self):
        rows = [dict(cell=dict(cell_id=str(i)), folder=str(i)) for i in range(3)]
        source = dict(design=dict(maximum_workers=2))
        value = dict(selected_cells=rows[:2], maximum_cells=2, workers=2)
        H.validate_population(value, source, rows)
        for change in [dict(selected_cells=[]), dict(selected_cells=[rows[0], rows[0]]),
                       dict(selected_cells=[rows[0], dict(cell=dict(cell_id='crossed'))]), dict(workers=3)]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                H.validate_population(dict(value, **change), source, rows)

    def test_nonzero_missing_timeout_and_orphan(self):
        expected = dict(nonzero='HOST_COMMAND_NONZERO', missing='fixture-terminal.json',
                        hang='HOST_DEADLINE_EXCEEDED', orphan='HOST_ORPHAN_DESCENDANT')
        for case, error in expected.items():
            with self.subTest(case=case):
                root = start(case, deadline=30 if case == 'hang' else 60)
                result = terminal(root)
                self.assertEqual('failed', result['state'])
                self.assertIn(error, result['result']['error'])
                self.assertTrue(result['result']['owned_cleanup_complete'])
                self.assertTrue((root/'fixture-ready.json').exists())

    def test_owner_death_reaps_descendants(self):
        root = start('hang', deadline=30)
        until(lambda: (root/'fixture-ready.json').exists())
        child = D.read(root/'fixture-ready.json')['child_identity']
        worker = D.read(root/'job-assigned.json')['worker_identity']
        stop_identity(D.read(root/'launch.json')['host_identity'])
        until(lambda: not W.alive(child) and not W.alive(worker))
        self.assertEqual('lost_without_terminal', H.status(root)['state'])
        self.assertFalse((root/'published.json').exists())

    def test_exact_cancellation(self):
        root = start('hang', deadline=30)
        until(lambda: (root/'fixture-ready.json').exists())
        D.write_new(root/'cancel.json', dict(request=D.binding(root/'request.json'),
                     host_identity=D.read(root/'launch.json')['host_identity']))
        result = terminal(root)
        self.assertEqual('failed', result['state'])
        self.assertIn('HOST_OWNED_CANCELLATION', result['result']['error'])

    def test_crossed_cancellation_refused(self):
        root = start(hold=3)
        D.write_new(root/'cancel.json', dict(request=D.binding(root/'request.json'), host_identity={'pid': 1}))
        result = terminal(root)
        self.assertEqual('complete', result['state'])
        self.assertTrue((root/'cancel-refused.json').exists())

    def test_caller_job_loss_does_not_stop_host(self):
        path = H.prepare('fixture', hold=3, deadline=60); root = path.parent; ROOTS.append(root)
        job = W.Job()
        # The interactive caller's job explicitly permits breakaway. The
        # durable owner's descendant job does not permit it.
        info = W.Extended(); info.Basic.Flags = 0x2000 | 0x800
        W.checked(W.set_info(job.handle, 9, W.C.byref(info), W.C.sizeof(info)))
        script = "import sys,time;from pathlib import Path;sys.path.insert(0,sys.argv[1]);import recovery_discovery_host_v2 as H;p=Path(sys.argv[2]);\nwhile not (p.parent/'caller-permit').exists():time.sleep(.05)\nH.launch(p);time.sleep(60)"
        caller = subprocess.Popen([str(H.PYTHON), '-B', '-c', script, str(D.HERE), str(path)],
                                  cwd=D.ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                  creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            job.add(caller); (root/'caller-permit').write_text('assigned', encoding='utf-8')
            until(lambda: (root/'fixture-ready.json').exists())
            identity = D.read(root/'launch.json')['host_identity']
            self.assertNotIn(identity['pid'], job.pids())
            job.terminate(); caller.wait(timeout=10)
            self.assertTrue(W.alive(identity))
            self.assertEqual('complete', terminal(root)['state'])
        finally:
            job.close()
            if caller.poll() is None: caller.kill(); caller.wait(timeout=10)

    def test_claim_bounds_command_and_source_refusals(self):
        path = H.prepare('fixture'); ROOTS.append(path.parent); value = D.read(path)
        for key, bad in [(f, True) for f in D.FLAGS]+[('deadline_seconds', True), ('deadline_seconds', 100),
                         ('hold_seconds', True), ('hold_seconds', -1), ('case', 'physical')]:
            altered = copy.deepcopy(value); altered[key] = bad
            with self.subTest(key=key, bad=bad), self.assertRaises(ValueError): H.validate_shape(altered)
        # Each tampered request uses a separate fresh folder, preserving the
        # original refusal bytes and never mutating an active request.
        for key, bad, message in [('command', ['arbitrary.exe'], 'HOST_COMMAND'),
                                  ('bindings', [], 'HOST_SOURCE_BINDINGS')]:
            candidate = H.prepare('fixture'); ROOTS.append(candidate.parent)
            altered = D.read(candidate); altered[key] = bad
            candidate.write_text(json.dumps(altered), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, message): H.request(candidate)


class RetainedLiveStream(io.StringIO):
    def write(self, text):
        sys.stdout.write(text); sys.stdout.flush()
        return super().write(text)


if __name__ == '__main__':
    folder = Path(sys.argv[1]); output = RetainedLiveStream()
    result = unittest.TextTestRunner(stream=output, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    D.write_new(folder/'durable-host-controls.json', dict(ok=result.wasSuccessful(), tests=result.testsRun,
                details=output.getvalue(), fixtures=[r.as_posix() for r in ROOTS], bindings=H.fixed_bindings(),
                world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))
    raise SystemExit(0 if result.wasSuccessful() else 1)
