"""R10AE actual v7 host/DLL boundary; no-argument entrypoints must refuse."""
import json
import os
import subprocess
import time
import unittest
import test_r10ab_runtime as base
import r10ae_host_runtime as host
import r10ae_selection_check as fixtures


class R10AERuntime(base.R10ABRuntime):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        expected=host.expected_binding()
        cls.host=host.bind_runtime(expected['images']['godot_console']['path'],expected['images']['powershell_host']['path'])
        cls.declaration=cls.root/'synthetic-runtime-declaration.json'
        declaration=fixtures.fixture()['declaration'];declaration['runtime']=cls.host
        cls.declaration.write_text(json.dumps(declaration,indent=2)+'\n',encoding='utf-8')
        cls.before=base.shared.entry._source_snapshot()
        (cls.root/'r10ae-source-before.json').write_text(json.dumps(cls.before),encoding='utf-8')

    @classmethod
    def tearDownClass(cls):
        after=base.shared.entry._source_snapshot()
        (cls.root/'r10ae-source-after.json').write_text(json.dumps(after),encoding='utf-8')
        assert cls.before==after

    @classmethod
    def _run_retained(cls,script,arguments,name,timeout):
        command=[cls.host['images']['godot_engine']['path'],'--headless','--path',str(base.shared.ROOT),'--script',script,*arguments]
        environment={k:v for k,v in os.environ.items() if not k.startswith('SPORESPORE_GODOT_RECOVERY_')}
        start=time.monotonic();record=dict(command=command,timeout_seconds=timeout,timed_out=False)
        try:
            with (cls.root/(name+'.stdout.txt')).open('xb') as out,(cls.root/(name+'.stderr.txt')).open('xb') as err:
                result=subprocess.run(command,cwd=base.shared.ROOT,stdout=out,stderr=err,timeout=timeout,
                    creationflags=subprocess.CREATE_NO_WINDOW,env=environment)
                record['returncode']=result.returncode
        except subprocess.TimeoutExpired:
            record['timed_out']=True
            raise
        finally:
            record['elapsed_seconds']=time.monotonic()-start
            (cls.root/(name+'.execution.json')).write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
        return subprocess.CompletedProcess(command,result.returncode,(cls.root/(name+'.stdout.txt')).read_bytes(),(cls.root/(name+'.stderr.txt')).read_bytes())

    def test_actual_godot_profile_context_and_single_role_contract(self):
        run=self._run_retained('res://tests/test_r10ae_runtime_contract.gd',
            ['--',*base.arguments(self.selection),str(self.declaration)],'contract',60)
        result=base.shared.marker(run,'DEVELOPMENT_RECOVERY_CANDIDATE_CONTRACT ')
        self.assertIs(result['ok'],True,result['checks'])
        self.assertTrue(all(result['checks'].values()),result['checks'])

    def test_unbound_worker_and_reader_refuse_without_starting_a_world(self):
        for name,script,reason in [('worker',self.selection['worker_selection']['worker'],b'DEVELOPMENT_CANDIDATE_DECLARATION_INVALID'),
                ('reader',self.selection['reader'],b'R10AE_REPLAY_ARGUMENTS')]:
            run=self._run_retained(script,[],'unbound_'+name,60)
            self.assertEqual(1,run.returncode,run.stdout+run.stderr)
            self.assertNotIn(b'SPORESPORE_GODOT_RECOVERY_READY ',run.stdout)
            self.assertIn(reason,run.stdout+run.stderr)
            if name=='reader':
                rows=[json.loads(line.split(' ',1)[1]) for line in run.stdout.decode().splitlines()
                    if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
                self.assertEqual(1,len(rows));self.assertEqual(0,rows[0]['world_build_count'])
                self.assertEqual(0,rows[0]['solver_step_count']);self.assertIs(rows[0]['ok'],False)


if __name__=='__main__':unittest.main()
