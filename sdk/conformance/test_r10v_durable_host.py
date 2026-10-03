"""Real Windows host lifecycle controls. No Godot process or physical world."""
import ctypes as C
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid
import r10v_durable_host as h

SUITE=h.EVIDENCE/('r10v-host-controls-'+uuid.uuid4().hex)
SUITE.mkdir()
ROOTS=[]
BEFORE=h.source._source_snapshot()
h.write(SUITE/'source_before.json',BEFORE)


def prepare(*args,**kwargs):
    path=h.prepare(*args,**kwargs);ROOTS.append(path.parent);return path


def until(predicate,seconds=30):
    end=time.monotonic()+seconds
    while time.monotonic()<end:
        result=predicate()
        if result:return result
        time.sleep(.1)
    raise AssertionError('LIFECYCLE_OBSERVATION_TIMEOUT')


def terminal(root):
    until(lambda:(root/'host_result.json').exists())
    value=until(lambda: (v if (v:=h.status(root))['state'] not in ('running','publishing') else None))
    until(lambda:not h.win.alive(h.read(root/'launch.json')['host_identity']))
    return value


def ready(root):
    until(lambda:(root/'probe_ready.json').exists())
    v=h.read(root/'probe_ready.json')
    ids=[h.win.identity(v[k]) for k in ('supervisor_pid','descendant_pid')]
    assert all(i is not None and i.pop('running') for i in ids)
    return ids


def kill_exact(identity):
    handle=h.win.checked(h.win.open_process(0x1000|1|0x100000,False,identity['pid']))
    try:
        values=[h.win.W.FILETIME() for _ in range(4)]
        h.win.checked(h.win.times(handle,*[C.byref(x) for x in values]))
        assert ((values[0].dwHighDateTime<<32)|values[0].dwLowDateTime)==identity['creation_filetime']
        kill=h.win.api('TerminateProcess',[h.win.W.HANDLE,h.win.W.UINT])
        h.win.checked(kill(handle,126));assert h.win.wait(handle,10000)==0
    finally:h.win.close(handle)


def assert_gone(test,ids):
    until(lambda:all(not h.win.alive(x) for x in ids))
    test.assertTrue(all(not h.win.alive(x) for x in ids))


class HostControls(unittest.TestCase):
    def test_normal_exit_retains_output_and_refuses_duplicate_launch_and_publication(self):
        path=prepare();h.launch(path);value=terminal(path.parent)
        self.assertEqual(value['state'],'complete')
        self.assertIn('R10V_ZERO_WORLD_PROBE_FINISHED',(path.parent/'supervisor.stdout.txt').read_text())
        self.assertTrue(h.read(path.parent/'probe_lock.json')['acquired'])
        with self.assertRaises(FileExistsError):h.launch(path)
        original=h.binding(path.parent/'host_result.json')
        with self.assertRaises(FileExistsError):h.write(path.parent/'host_result.json',{'ok':True})
        self.assertEqual(original,h.binding(path.parent/'host_result.json'))
        with self.assertRaises(FileExistsError):h.write(path.parent/'published.json',{'ok':True})

    def test_nonzero_original_exit_is_retained(self):
        path=prepare('nonzero');h.launch(path);v=terminal(path.parent)
        self.assertEqual(v['result']['worker_exit_code'],7)
        self.assertEqual(v['result']['failure_code'],'R10V_HOST_SUPERVISOR_NONZERO')

    def test_missing_terminal_is_not_promoted_from_exit_zero(self):
        path=prepare('missing_terminal');h.launch(path);v=terminal(path.parent)
        self.assertEqual(v['result']['worker_exit_code'],0)
        self.assertEqual(v['result']['failure_code'],'R10V_HOST_SUPERVISOR_TERMINAL_MISSING')

    def test_malformed_terminal_refused(self):
        path=prepare('malformed_terminal');h.launch(path);v=terminal(path.parent)
        self.assertEqual(v['result']['failure_code'],'R10V_HOST_SUPERVISOR_TERMINAL_MALFORMED')

    def test_killed_interactive_caller_does_not_kill_supervisor(self):
        path=prepare(hold=3)
        with (path.parent/'caller.stdout.txt').open('xb') as out,(path.parent/'caller.stderr.txt').open('xb') as err:
            caller=subprocess.Popen([sys.executable,str(h.SCRIPT),'--launch',str(path),'--linger-caller'],cwd=h.ROOT,
                stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
            try:
                ids=ready(path.parent)
                caller.kill();caller.wait(timeout=10)
                identity=h.read(path.parent/'launch.json')['host_identity']
                self.assertTrue(h.win.alive(identity))
                self.assertTrue(all(h.win.alive(i) for i in ids))
                self.assertEqual(terminal(path.parent)['state'],'complete')
            finally:
                if caller.poll() is None:caller.kill();caller.wait(timeout=10)

    def test_cancel_refuses_crossed_pid_and_only_kills_owned_tree(self):
        unrelated=subprocess.Popen([sys.executable,'-c','import time;time.sleep(90)'],cwd=h.ROOT,creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            path=prepare(hold=40);launched=h.launch(path);ids=ready(path.parent)
            # The real operation lock must still refuse a competing owner.
            command=". ./sdk/locomotion_operation_lock.ps1; $r=Enter-SporeSporeLocomotionOperationLock -Role conformance -TimeoutMilliseconds 0; if($r.acquired){Exit-SporeSporeLocomotionOperationLock -Receipt $r;exit 9};exit 0"
            probe=subprocess.run([h.read(path)['runtime']['path'],'-NoProfile','-Command',command],cwd=h.ROOT,capture_output=True)
            h.write(path.parent/'competing_lock.json',dict(exit_code=probe.returncode,stdout=probe.stdout.decode(),stderr=probe.stderr.decode()))
            self.assertEqual(probe.returncode,0)
            wrong=dict(launched['host_identity'],pid=unrelated.pid)
            with self.assertRaisesRegex(ValueError,'CANCEL_CROSSED_HOST'):h.cancel(path.parent,wrong)
            self.assertFalse((path.parent/'cancel.json').exists())
            self.assertIsNone(unrelated.poll())
            h.cancel(path.parent,launched['host_identity'])
            v=terminal(path.parent)
            self.assertEqual(v['result']['failure_code'],'R10V_HOST_CANCELLED')
            assert_gone(self,ids);self.assertIsNone(unrelated.poll())
        finally:
            unrelated.kill();unrelated.wait(timeout=10)

    def test_deadline_kills_all_owned_descendants(self):
        path=prepare('hang',deadline=10);h.launch(path);ids=ready(path.parent)
        v=terminal(path.parent)
        self.assertEqual(v['result']['failure_code'],'R10V_HOST_DEADLINE')
        assert_gone(self,ids)

    def test_host_loss_kills_descendants_and_stays_incomplete(self):
        path=prepare('hang');launched=h.launch(path);ids=ready(path.parent)
        kill_exact(launched['host_identity']);assert_gone(self,ids)
        self.assertEqual(h.status(path.parent)['state'],'incomplete')
        self.assertFalse((path.parent/'host_result.json').exists())

    def test_actual_source_drift_stops_owned_probe(self):
        path=prepare('hang');h.launch(path);ids=ready(path.parent)
        sentinel=h.ROOT/'sdk/conformance'/('.r10v-source-control-'+uuid.uuid4().hex+'.txt')
        try:
            with sentinel.open('x',encoding='utf-8') as stream:stream.write('deliberate zero-world source drift control\n')
            h.write(path.parent/'injected_source_drift.json',dict(binding=h.binding(sentinel),content=sentinel.read_text(),source_snapshot=h.source._source_snapshot()))
            v=terminal(path.parent)
            self.assertEqual(v['result']['failure_code'],'R10V_HOST_SOURCE_CHANGED_DURING_HOST')
            assert_gone(self,ids)
        finally:
            if sentinel.exists():sentinel.unlink()
        self.assertEqual(h.source._source_snapshot(),BEFORE)

    def test_stale_source_request_refused_before_launch(self):
        path=prepare();v=h.read(path);v['source_snapshot']['head']='0'*40
        path.write_text(json.dumps(v),encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'SOURCE_CHANGED_BEFORE_LAUNCH'):h.launch(path)
        self.assertFalse((path.parent/'launch_reservation.json').exists())

    def test_crossed_invocation_refused_before_launch(self):
        path=prepare();v=h.read(path);v['invocation_id']='0'*32
        path.write_text(json.dumps(v),encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'INVOCATION_ID'):h.launch(path)
        self.assertFalse((path.parent/'launch_reservation.json').exists())

    def test_crossed_terminal_host_identity_refused(self):
        path=prepare();identity=dict(pid=os.getpid(),creation_filetime=1)
        h.write(path.parent/'launch.json',dict(request=h.binding(path),host_identity=identity))
        h.write(path.parent/'host_started.json',dict(request=h.binding(path),host_identity=identity))
        h.write(path.parent/'host_result.json',dict(schema_version='sporespore_r10v_durable_host_result_v1',
            request=h.binding(path),host_identity=dict(identity,creation_filetime=2),ok=True,owned_cleanup_complete=True,logs=[]))
        with self.assertRaisesRegex(ValueError,'TERMINAL_IDENTITY'):h.status(path.parent)

    def unpublished_fixture(self):
        path=prepare();identity=dict(pid=os.getpid(),creation_filetime=1)
        h.write(path.parent/'launch.json',dict(request=h.binding(path),host_identity=identity))
        h.write(path.parent/'host_started.json',dict(request=h.binding(path),host_identity=identity))
        for name in ('supervisor.stdout.txt','supervisor.stderr.txt'):
            with (path.parent/name).open('x',encoding='utf-8') as stream:stream.write('synthetic terminal-consumer control')
        h.write(path.parent/'probe_terminal.json',dict(invocation_id=h.read(path)['invocation_id'],ok=True,world_build_count=0,solver_step_count=0))
        h.write(path.parent/'host_result.json',dict(schema_version='sporespore_r10v_durable_host_result_v1',
            request=h.binding(path),host_identity=identity,ok=True,owned_cleanup_complete=True,
            source_unchanged=True,worker_exit_code=0,primary_terminal=h.binding(path.parent/'probe_terminal.json'),
            logs=[h.binding(path.parent/name) for name in ('supervisor.stdout.txt','supervisor.stderr.txt')],**h.CLAIMS))
        return path

    def test_unpublished_terminal_remains_incomplete(self):
        path=self.unpublished_fixture()
        self.assertEqual(h.status(path.parent)['state'],'incomplete')

    def test_crossed_publication_refused(self):
        path=self.unpublished_fixture()
        h.write(path.parent/'published.json',dict(request=h.binding(path),host_identity={'pid':0},host_result=h.binding(path.parent/'host_result.json')))
        with self.assertRaisesRegex(ValueError,'PUBLICATION_BINDING'):h.status(path.parent)

    def test_terminal_cleanup_cannot_be_assumed(self):
        path=prepare();identity=dict(pid=os.getpid(),creation_filetime=1)
        h.write(path.parent/'launch.json',dict(request=h.binding(path),host_identity=identity))
        h.write(path.parent/'host_started.json',dict(request=h.binding(path),host_identity=identity))
        h.write(path.parent/'host_result.json',dict(schema_version='sporespore_r10v_durable_host_result_v1',
            request=h.binding(path),host_identity=identity,ok=True,owned_cleanup_complete=False,logs=[]))
        with self.assertRaisesRegex(ValueError,'TERMINAL_CLEANUP'):h.status(path.parent)


if __name__=='__main__':
    print('R10V_HOST_CONTROLS '+str(SUITE),flush=True)
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(HostControls)
    with (SUITE/'tests.stderr.txt').open('x',encoding='utf-8') as stream:
        result=unittest.TextTestRunner(stream=stream,verbosity=2).run(suite)
    after=h.source._source_snapshot();h.write(SUITE/'source_after.json',after)
    record=dict(ok=result.wasSuccessful() and after==BEFORE,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),
        roots=[str(p) for p in ROOTS],source_unchanged=after==BEFORE,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)
    h.write(SUITE/'result.json',record);print(json.dumps(record),flush=True)
    raise SystemExit(0 if record['ok'] else 1)
