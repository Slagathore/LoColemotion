"""Safety controls for the reusable discovery lane; no physical worlds."""
import copy
import io
import os
import json
from pathlib import Path
import sys
import subprocess
import time
import unittest
import recovery_discovery as D
import recovery_discovery_reader as R


class ContractControls(unittest.TestCase):
    def setUp(self):
        self.design = D.read(D.HERE / 'recovery_batch_a_v1.json')

    def test_factorial_population(self):
        values = D.cells(self.design)
        self.assertEqual(24, len(values))
        self.assertEqual(24, len({v['cell_id'] for v in values}))
        for p in self.design['phases']:
            self.assertEqual(4, sum(v['phase'] == p for v in values))

    def test_refuses_claims(self):
        for flag in D.FLAGS:
            value = copy.deepcopy(self.design); value[flag] = True
            with self.assertRaises(ValueError): D.validate_design(value)

    def test_refuses_unbounded_and_nonfinite_inputs(self):
        for key, bad in [('phases',[360]),('phases',[True]),('phases',[140,140]),('impulses_ns',[float('nan')]),
                         ('impulses_ns',[0.0,10.0]),('tail_steps',100000),('maximum_solver_steps',100000),
                         ('timeout_seconds',0),('maximum_workers',32),('physics_hz',60),('direction','unknown'),
                         ('actuation_modes',['position_hold'])]:
            value = copy.deepcopy(self.design); value[key] = bad
            with self.subTest(key=key, bad=bad), self.assertRaises(ValueError): D.validate_design(value)

    def test_no_overwrite(self):
        path = FOLDER / 'exclusive-create-control.json'
        D.write_new(path, {'original':True})
        with self.assertRaises(FileExistsError): D.write_new(path, {'original':False})
        self.assertEqual({'original':True}, D.read(path))

    def test_reader_rejects_partial_and_claim_reports(self):
        for report in [{}, {'ok':True}, {'schema_version':'sporespore_recovery_discovery_observation_v1','ok':False}]:
            with self.assertRaises(ValueError): R.validate_report(report,{})

    def test_vectors_refuse_nan_and_shape(self):
        for value in [[0,1], [0,0,float('nan')], [False,0,0], ['0',0,0]]:
            with self.assertRaises(ValueError): R.vec(value)

    def test_retained_report_reader_and_adversarial_controls(self):
        fixture = D.read(D.HERE/'recovery_reader_fixture_v1.json')
        D.verify_binding(fixture['report']);D.verify_binding(fixture['declaration'])
        report = D.read(fixture['report']['path']);declaration=D.read(fixture['declaration']['path'])
        self.assertTrue(R.validate_report(report,declaration)['valid'])
        # Keep only the fields used by the pure validator to avoid cloning the
        # unrelated setup telemetry for every deliberate corruption.
        report.pop('setup_and_prefix');report.pop('setup_and_prefix_contact_frames')
        mutations = [lambda v:v['tail_rows'].pop(),
            lambda v:v['tail_rows'][0].update(global_step=999),
            lambda v:v['tail_rows'][0]['bodies'][0].update(instance_id=1),
            lambda v:v['tail_rows'][0]['motors'][0].update(maximum_impulse=999),
            lambda v:v['tail_rows'][0]['motors'][0].update(enabled=True),
            lambda v:v['disturbance'].update(application_count=1),
            lambda v:v.update(release_authority=True),
            lambda v:v['tail_rows'][0]['contacts'].update(capture_space_step_sequence=999)]
        for index,mutate in enumerate(mutations):
            bad=copy.deepcopy(report);mutate(bad)
            with self.subTest(control=index),self.assertRaises(ValueError):R.validate_report(bad,declaration)

    def test_native_cold_reader_roundtrip(self):
        fixture = D.read(D.HERE/'recovery_reader_fixture_v1.json')
        engine=D.read(FOLDER/'manifest.json')['runtime']['images']['godot_engine']['path']
        D.process(FOLDER,'reader-roundtrip',[engine,'--headless','--path',D.ROOT,'--script',
            'res://sdk/discovery/recovery_discovery_reader_v2.gd','--',fixture['report']['path'],FOLDER/'reader-roundtrip.json'])
        self.assertEqual(241,D.read(FOLDER/'reader-roundtrip.json')['row_count'])
        self.assertTrue(D.read(FOLDER/'reader-roundtrip.json')['ok'])
        original=D.read(fixture['report']['path'])
        bad=dict(disturbance=dict(baseline=original['disturbance']['baseline']),tail_rows=[])
        bad['disturbance']['baseline']['contacts']['capture_space_step_sequence']=271.5
        D.write_new(FOLDER/'reader-fractional-clock.json',bad)
        with self.assertRaises(ValueError):
            D.process(FOLDER,'reader-fractional',[engine,'--headless','--path',D.ROOT,'--script',
                'res://sdk/discovery/recovery_discovery_reader_v2.gd','--',FOLDER/'reader-fractional-clock.json',FOLDER/'reader-fractional-result.json'])
        self.assertFalse(D.read(FOLDER/'reader-fractional-result.json')['ok'])

    def test_job_owns_and_reaps_descendants(self):
        sys.path.insert(0,str(D.ROOT/'sdk/conformance'))
        import r10v_windows_job as W
        folder=FOLDER/'job-control';folder.mkdir()
        job=W.Job()
        proc=None
        try:
            proc=subprocess.Popen([sys.executable,'-B',str(D.HERE/'recovery_pool_fixture.py'),str(folder)],cwd=D.ROOT,
                                  stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=subprocess.CREATE_NO_WINDOW)
            job.add(proc)
            self.assertFalse((folder/'descendant.json').exists())
            D.write_new(folder/'permit.json',dict(job_bound=True))
            deadline=time.monotonic()+10
            while not (folder/'descendant.json').exists() and time.monotonic()<deadline:time.sleep(.02)
            child=D.read(folder/'descendant.json')['child']
            child_identity=W.identity(child)
            self.assertIn(proc.pid,job.pids());self.assertIn(child,job.pids())
            job.close();proc.wait(timeout=10)
            deadline=time.monotonic()+5
            while W.alive(child_identity) and time.monotonic()<deadline:time.sleep(.02)
            self.assertFalse(W.alive(child_identity))
        finally:
            job.close()
            if proc is not None and proc.poll() is None:proc.wait(timeout=10)

    def test_real_pool_launcher_zero_world(self):
        import recovery_discovery_pool as P
        operation=FOLDER/'launcher-operation-fixture.json'
        D.write_new(operation,dict(acquired=True,owner_process_id=os.getppid(),test_only=True,
                    acquired_utc='2026-09-30T00:00:00.0000000Z'))
        P.run(FOLDER,2,2,operation,qualification_only=True)
        for row in D.read(FOLDER/'cells.json')[:2]:
            child=Path(row['folder'])/'children'/D.ROLE
            self.assertTrue(D.read(child/'launcher-preflight.json')['ok'])
            self.assertFalse((child/'world-claim.json').exists())
            self.assertFalse((child/'launch-reservation.json').exists())
            self.assertEqual(operation.read_bytes(),(child/'preflight-operation.json').read_bytes())

    def test_all_pre_world_consumers(self):
        rows = D.read(FOLDER / 'cells.json')
        first = Path(rows[0]['folder'])
        value = D.read(first / 'preworld.json')
        self.assertTrue(value['ok'])
        self.assertEqual('DISCOVERY_WORLD_PERMISSION_REFUSED',value['guard']['failure_code'])
        self.assertEqual((0,0),(value['world_build_count'],value['solver_step_count']))
        prepared = D.read(first / 'prepared-context.json')
        self.assertTrue(prepared['synthetic_prefix_probe']['ok'])
        self.assertEqual(30,len(prepared['synthetic_prefix_probe']['transitions']))
        for row in rows:
            self.assertEqual(prepared,D.read(Path(row['folder']) / 'prepared-context.json'))
            env = D.read(Path(row['folder']) / 'environment.json')['environment']
            self.assertEqual(str(80000+row['cell']['phase']),str(env['SPORESPORE_GODOT_RECOVERY_SEED']))


if __name__ == '__main__':
    FOLDER = Path(sys.argv[1])
    manifest = D.read(FOLDER / 'manifest.json')
    output = io.StringIO()
    result = unittest.TextTestRunner(stream=output, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ContractControls))
    (FOLDER / 'python-controls.txt').write_text(output.getvalue(),encoding='utf-8')
    D.require(result.wasSuccessful(), 'PYTHON_CONTROLS:' + output.getvalue())
    engine = manifest['runtime']['images']['godot_engine']['path']
    D.process(FOLDER,'gd-controls',[engine,'--headless','--path',D.ROOT,'--script','res://sdk/discovery/test_recovery_discovery_v1.gd','--',FOLDER/'gd-controls.json'])
    gd = D.read(FOLDER/'gd-controls.json')
    D.require(gd['ok'] is True and all(gd['checks'].values()),'GD_CONTROLS')
    # Existing real Windows process observer, ownership, crossed-context and
    # termination tests remain applicable to the unchanged launch implementation.
    D.process(FOLDER,'native-ownership-controls',[sys.executable,'-B','-X','utf8',D.ROOT/'tests/test_r10dg_native_process_observation.py'],timeout=300,test_stderr=True)
    D.write_new(FOLDER/'safety-tests.json',dict(ok=True,python_tests=result.testsRun,gd_checks=len(gd['checks']),
                native_ownership_tests=13,world_build_count=0,solver_step_count=0,
                physical_acceptance_authority=False,release_authority=False))
