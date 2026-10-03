"""Real Windows host lifecycle controls. No Godot process or physical world."""
import ctypes as C
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest import mock
import copy
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10v_durable_host_v2 as h

SUITE=None
ROOTS=[]
BEFORE=None


def prepare(*args,**kwargs):
    path=h.prepare(*args,**kwargs);ROOTS.append(path.parent)
    if os.environ.get('SPORESPORE_R10V_PREHOST_ROOT'):
        registry=Path(os.environ['SPORESPORE_R10V_PREHOST_ROOT'])/'owned_requests.jsonl'
        with registry.open('a',encoding='utf-8') as stream:
            stream.write(json.dumps(h.binding(path))+'\n');stream.flush();os.fsync(stream.fileno())
    return path


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
    @classmethod
    def setUpClass(cls):
        global SUITE,BEFORE
        SUITE=h.EVIDENCE/('r10v-production-host-controls-'+uuid.uuid4().hex);SUITE.mkdir()
        BEFORE=h.source._source_snapshot();h.write(SUITE/'source_before.json',BEFORE)
        print('R10V_PRODUCTION_HOST_CONTROLS '+str(SUITE),flush=True)

    @classmethod
    def tearDownClass(cls):
        after=h.source._source_snapshot();h.write(SUITE/'source_after.json',after)
        h.write(SUITE/'lifecycle_roots.json',dict(roots=[str(p) for p in ROOTS],source_unchanged=after==BEFORE))
        assert after==BEFORE,'HOST_CONTROL_SOURCE_DRIFT'

    def test_production_lanes_require_prehost_before_any_reservation(self):
        for lane in ('production_gate','production_smoke'):
            with self.assertRaisesRegex(ValueError,'PREHOST_REQUIRED'):
                h.prepare(lane=lane)

    def test_prehost_stage_population_and_original_logs_are_required(self):
        import r10v_prehost_qualification as q
        root=SUITE/'synthetic-prehost-stages';root.mkdir()
        stages=[]
        for spec in q.specs():
            row=dict(id=spec['id'],passed=True,timed_out=False,exit_code=0,test_count=spec['tests'],expected_test_count=spec['tests'])
            for stream in ('stdout','stderr'):
                path=root/(spec['id']+'.'+stream+'.log')
                path.write_text('Ran '+str(spec['tests'])+' tests in 1.0s\n\nOK\n' if stream=='stderr' else '',encoding='utf-8')
                row[stream]=path.name;row[stream+'_sha256']=h.binding(path)['raw_sha256'].removeprefix('sha256:')
            stages.append(row)
        q.validate_stages(root,stages)
        with self.assertRaisesRegex(ValueError,'COMPLETE_STAGES'):q.validate_stages(root,stages[:-1])
        for key,value in [('passed',False),('timed_out',True),('exit_code',1),('test_count',0),('expected_test_count',True),('stdout','../crossed')]:
            changed=copy.deepcopy(stages);changed[0][key]=value
            with self.assertRaises(ValueError):q.validate_stages(root,changed)
        (root/stages[0]['stderr']).write_text('changed original log',encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'LOG_BYTES'):q.validate_stages(root,stages)

    def test_prehost_refuses_stale_dependencies_and_source(self):
        import r10v_prehost_qualification as q
        contract=h.read(q.CONTRACT);q.validate_timing_provenance(contract)
        crossed=copy.deepcopy(contract);crossed['startup_timing_evidence']['diagnostic_manifest']['path']='nonexistent-renamed-evidence.json'
        with self.assertRaisesRegex(ValueError,'TIMING_PROVENANCE'):q.validate_timing_provenance(crossed)
        root=h.EVIDENCE/('r10v-prehost-'+uuid.uuid4().hex);root.mkdir()
        path=root/'qualification.json'
        value=dict(schema_version='sporespore_r10v_prehost_qualification_v1',ok=True,dependencies={'synthetic':'old'},source_snapshot={},**q.CLAIMS)
        h.write(path,value)
        with mock.patch.object(q,'dependencies',return_value={'synthetic':'current'}):
            with self.assertRaisesRegex(ValueError,'DEPENDENCIES_CHANGED'):q.verify(path)
        with mock.patch.object(q,'dependencies',return_value=value['dependencies']):
            with self.assertRaisesRegex(ValueError,'SOURCE_CHANGED'):q.verify(path)
        h.write(SUITE/'synthetic-prehost-refusal-root.json',dict(path=str(root),physical_acceptance_authority=False))

    def test_prehost_cleanup_uses_exact_live_process_identity(self):
        import r10v_prehost_qualification as q
        root=SUITE/'synthetic-prehost-cleanup';root.mkdir()
        path=prepare()
        h.write(root/'owned_requests.jsonl',h.binding(path))
        h.write(path.parent/'host_started.json',dict(host_identity=h.win.current_identity()))
        self.assertFalse(q.owned_quiescent(root))
        crossed=dict(h.win.current_identity());crossed['creation_filetime']+=1
        (path.parent/'host_started.json').write_text(json.dumps(dict(host_identity=crossed)),encoding='utf-8')
        self.assertTrue(q.owned_quiescent(root))

    def test_actual_production_library_and_owned_python_process(self):
        path=prepare(lane='production_interface_probe');h.launch(path);v=terminal(path.parent)
        self.assertEqual(v['state'],'complete',v)
        context=h.read(path.parent/'supervisor_context.json')
        self.assertEqual(context,h.supervisor_context(path,context['supervisor_identity']['pid'],live=False))
        with self.assertRaisesRegex(ValueError,'SUPERVISOR_IDENTITY'):
            h.supervisor_context(path,context['supervisor_identity']['pid']+1,live=False)
        self.assertEqual(h.validate_progress(path,h.read(path)),v['result']['progress_log'])
        receipt=h.read(path.parent/'interface_receipt.json')
        self.assertEqual(receipt['fields']['r10v_host'],context)
        self.assertEqual(receipt['fields']['timeout_seconds_per_child'],1740)
        execution=h.read(path.parent/'interface_python.execution.json')
        self.assertEqual(execution['exit_code'],0);self.assertFalse(execution['timed_out'])
        self.assertIn('Python 3.11',(path.parent/'interface_python.stdout.txt').read_text())
        self.assertFalse(h.win.alive(execution['process_identity']))

    def test_production_python_nonzero_retained(self):
        path=prepare('python_nonzero',lane='production_interface_probe');h.launch(path);v=terminal(path.parent)
        self.assertEqual(v['state'],'failed')
        execution=h.read(path.parent/'interface_python.execution.json')
        self.assertEqual(execution['exit_code'],7);self.assertFalse(execution['timed_out'])
        self.assertFalse(h.win.alive(execution['process_identity']))
        self.assertFalse((path.parent/'probe_terminal.json').exists())

    def test_production_python_deadline_kills_and_retains_original_output(self):
        path=prepare('python_timeout',lane='production_interface_probe');h.launch(path)
        until(lambda:(path.parent/'published.json').exists(),seconds=90)
        v=terminal(path.parent);self.assertEqual(v['state'],'failed')
        execution=h.read(path.parent/'interface_python.execution.json')
        self.assertTrue(execution['timed_out']);self.assertEqual(execution['timeout_seconds'],30)
        self.assertFalse(h.win.alive(execution['process_identity']))
        self.assertIn('R10V_PYTHON_TIMEOUT',(path.parent/'supervisor.stderr.txt').read_text())

    def test_live_orphan_after_supervisor_exit_is_refused_and_killed(self):
        path=prepare('orphan');h.launch(path);v=terminal(path.parent)
        self.assertEqual(v['state'],'failed')
        self.assertEqual(v['result']['failure_code'],'R10V_HOST_ORPHAN_DESCENDANT')
        events=[json.loads(line) for line in (path.parent/'events.jsonl').read_text().splitlines()]
        self.assertTrue(any(x['event']=='owned_orphans_refused' for x in events))
        drain=next(x for x in events if x['event']=='owned_cleanup_drain')
        self.assertTrue(any(x is not None and x['running'] for x in drain['identities']))
        self.assertTrue(all(not h.win.alive({k:x[k] for k in ('pid','creation_filetime')}) for x in drain['identities'] if x is not None))

    def test_canonical_python_image_is_independently_required(self):
        path=prepare();v=h.read(path);v['python_runtime']=h.binding(h.PWSH)
        path.write_text(json.dumps(v),encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'CANONICAL_RUNTIME'):h.launch(path)
        self.assertFalse((path.parent/'launch_reservation.json').exists())

    def test_canonical_powershell_image_is_independently_required(self):
        path=prepare();v=h.read(path);v['runtime']=h.binding(h.PYTHON)
        path.write_text(json.dumps(v),encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'CANONICAL_RUNTIME'):h.launch(path)
        self.assertFalse((path.parent/'launch_reservation.json').exists())

    def test_crossed_production_command_refuses_before_process(self):
        path=prepare(lane='production_interface_probe');v=h.read(path);v['command'].append('-RunSmoke')
        path.write_text(json.dumps(v),encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'COMMAND'):h.launch(path)
        self.assertFalse((path.parent/'launch_reservation.json').exists())

    def test_incomplete_progress_cannot_be_a_completed_workflow(self):
        path=prepare(lane='production_interface_probe');h.write(path.parent/'supervisor_context.json',{})
        (path.parent/'progress.jsonl').write_text(json.dumps(dict(stage='interface',state='end',role=''))+'\n',encoding='utf-8')
        with self.assertRaisesRegex(ValueError,'PROGRESS_SEQUENCE'):h.validate_progress(path,h.read(path))

    def test_missing_production_host_context_cannot_authorize_declaration(self):
        with self.assertRaisesRegex(ValueError,'DECLARATION_CONTEXT_MISSING'):h.declaration_context({})

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
        h.write(path.parent/'host_result.json',dict(schema_version='sporespore_r10v_durable_host_result_v2',
            request=h.binding(path),host_identity=dict(identity,creation_filetime=2),ok=True,owned_cleanup_complete=True,logs=[]))
        with self.assertRaisesRegex(ValueError,'TERMINAL_IDENTITY'):h.status(path.parent)

    def unpublished_fixture(self):
        path=prepare();identity=dict(pid=os.getpid(),creation_filetime=1)
        h.write(path.parent/'launch.json',dict(request=h.binding(path),host_identity=identity))
        h.write(path.parent/'host_started.json',dict(request=h.binding(path),host_identity=identity))
        for name in ('supervisor.stdout.txt','supervisor.stderr.txt'):
            with (path.parent/name).open('x',encoding='utf-8') as stream:stream.write('synthetic terminal-consumer control')
        h.write(path.parent/'probe_terminal.json',dict(invocation_id=h.read(path)['invocation_id'],ok=True,world_build_count=0,solver_step_count=0))
        h.write(path.parent/'host_result.json',dict(schema_version='sporespore_r10v_durable_host_result_v2',
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
        h.write(path.parent/'host_result.json',dict(schema_version='sporespore_r10v_durable_host_result_v2',
            request=h.binding(path),host_identity=identity,ok=True,owned_cleanup_complete=False,logs=[]))
        with self.assertRaisesRegex(ValueError,'TERMINAL_CLEANUP'):h.status(path.parent)


if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(HostControls))
    record=dict(ok=result.wasSuccessful(),tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),
        roots=[str(p) for p in ROOTS],source_unchanged=h.source._source_snapshot()==BEFORE,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
    h.write(SUITE/'result.json',record);print(json.dumps(record),flush=True)
    raise SystemExit(0 if record['ok'] and record['source_unchanged'] else 1)
