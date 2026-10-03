"""Zero-world controls for the full-route discovery successor."""
import copy
import io
import json
import os
from pathlib import Path
import sys
import unittest
import recovery_discovery as D
import recovery_panel as P
import recovery_panel_reader as R
import test_recovery_discovery as A


class Controls(unittest.TestCase):
    test_job_owns_and_reaps_descendants = A.ContractControls.test_job_owns_and_reaps_descendants
    test_no_overwrite = A.ContractControls.test_no_overwrite

    def test_file_publication_controls(self):
        parent='synthetic-parent';child_id='synthetic-child'
        for name in ('good','digest','path','child','claim','reduced','duplicate','partial'):
            folder=FOLDER/('file-wire-'+name);folder.mkdir()
            path=folder/'worker-streamed-report.json';D.write_new(path,dict(synthetic=True))
            declaration=dict(attempt_id=parent,children=[dict(child_attempt_id=child_id)],report_publication='direct_file_v1')
            receipt=dict(ok=True,**D.binding(path),parent_attempt_id=parent,child_attempt_id=child_id,
                         transport_id='godot_4_7_sorted_full_precision_authoritative_json_v1',telemetry_reduced=False,
                         physical_acceptance_authority=False,release_authority=False)
            if name=='digest':receipt['raw_sha256']='sha256:'+'0'*64
            if name=='path':receipt['path']=str(folder/'crossed.json')
            if name=='child':receipt['child_attempt_id']='crossed'
            if name=='claim':receipt['release_authority']=True
            if name=='reduced':receipt['telemetry_reduced']=True
            if name=='partial':Path(str(path)+'.partial').write_text('incomplete',encoding='utf-8')
            line=R.FILE_MARKER+json.dumps(receipt)+'\n'
            (folder/'stdout.log').write_text(line*(2 if name=='duplicate' else 1),encoding='utf-8')
            if name=='good':self.assertEqual(path,R.retain_report(folder,declaration))
            else:
                with self.subTest(case=name),self.assertRaises(ValueError):R.retain_report(folder,declaration)

    def test_streaming_exact_bytes(self):
        engine=D.read(FOLDER/'manifest.json')['runtime']['images']['godot_engine']['path']
        D.process(FOLDER,'stream-controls',[engine,'--headless','--path',D.ROOT,'--script',
                  'res://sdk/discovery/test_recovery_report_file_v1.gd','--',FOLDER])
        self.assertTrue(D.read(FOLDER/'stream-controls-result.json')['ok'])
        fixture=D.read(D.HERE/'recovery_panel_transport_fixture_v1.json')
        D.verify_binding(fixture['report']);D.verify_binding(fixture['profile'])
        declaration=Path(D.read(FOLDER/'cells.json')[0]['folder'])/'declaration.json'
        output=FOLDER/'full-report-transport.json'
        D.process(FOLDER,'full-report-transport',[engine,'--headless','--path',D.ROOT,'--script',
                  'res://sdk/discovery/recovery_panel_reader_v1.gd','--','transport',declaration,fixture['report']['path'],output],timeout=1200)
        result=D.read(output)
        self.assertTrue(result['ok']);self.assertTrue(result['test_only'])
        self.assertEqual((0,0),(result['world_build_count'],result['solver_step_count']))
        self.assertEqual(fixture['expected_raw_sha256'],result['raw_sha256'])
        self.assertEqual(fixture['expected_byte_length'],result['byte_length'])
        D.verify_binding({k:result[k] for k in ('path','byte_length','raw_sha256')})

    def test_population_and_refusals(self):
        design=D.read(D.HERE/'recovery_panel_b_v1.json')
        self.assertEqual(16,len(P.cells(design)))
        for key,bad in [('phases',[True]),('phases',[360]),('phases',[140,140]),
                        ('maximum_workers',4),('maximum_solver_steps',999999),('impulse_ns',float('nan')),
                        ('allowed_recovery_entry_kinds',['partial']),('controller_variant','unknown')]+[(f,True) for f in D.FLAGS]:
            value=copy.deepcopy(design);value[key]=bad
            with self.subTest(key=key),self.assertRaises(ValueError):P.validate_design(value)
        successor=D.read(D.HERE/'recovery_panel_b_v2.json')
        self.assertEqual(16,len(P.cells(successor)))
        for bad in ('stdout_json_line_v1','unknown',True):
            value=copy.deepcopy(successor);value['report_publication']=bad
            with self.subTest(publication=bad),self.assertRaises(ValueError):P.validate_design(value)

    def test_native_identity_and_legacy_separation(self):
        engine=D.read(FOLDER/'manifest.json')['runtime']['images']['godot_engine']['path']
        output=FOLDER/'panel-identity-controls.json'
        D.process(FOLDER,'panel-identity-controls',[engine,'--headless','--path',D.ROOT,'--script',
                  'res://sdk/discovery/test_recovery_panel_v1.gd','--',output])
        result=D.read(output)
        self.assertTrue(result['ok']);self.assertTrue(all(result['checks'].values()))

    def test_both_role_pre_world_consumers(self):
        rows=D.read(FOLDER/'cells.json')
        for row in rows[:2]:
            folder=Path(row['folder']);value=D.read(folder/'preworld.json')
            self.assertTrue(value['ok'])
            self.assertEqual('DISCOVERY_WORLD_PERMISSION_REFUSED',value['guard']['failure_code'])
            self.assertEqual((0,0),(value['world_build_count'],value['solver_step_count']))
            prepared=D.read(folder/'prepared-context.json')
            self.assertTrue(prepared['synthetic_prefix_probe']['ok'])
            self.assertEqual(30,len(prepared['synthetic_prefix_probe']['transitions']))
        for row in rows:
            folder=Path(row['folder']);P.validate_cell(folder/'declaration.json',True)
            env=D.read(folder/'environment.json')['environment']
            self.assertEqual(str(90000+row['cell']['phase']),str(env['SPORESPORE_GODOT_RECOVERY_SEED']))

    def test_real_pool_launcher_both_roles_zero_world(self):
        import recovery_discovery_pool as pool
        operation=FOLDER/'launcher-operation-fixture.json'
        D.write_new(operation,dict(acquired=True,owner_process_id=os.getppid(),test_only=True,
                                  acquired_utc='2026-09-30T00:00:00.0000000Z'))
        pool.run(FOLDER,2,2,operation,qualification_only=True)
        for row in D.read(FOLDER/'cells.json')[:2]:
            declaration=D.read(Path(row['folder'])/'declaration.json')
            child=Path(declaration['children'][0]['evidence_path'])
            self.assertTrue(D.read(child/'launcher-preflight.json')['ok'])
            self.assertFalse((child/'world-claim.json').exists())
            self.assertFalse((child/'launch-reservation.json').exists())
            self.assertEqual(operation.read_bytes(),(child/'preflight-operation.json').read_bytes())

    def test_complete_native_consumer_positive_and_negative_fixtures(self):
        catalog=D.read(D.ROOT/'sdk/development/r10ap_report_fixture_catalog_v2.json')
        engine=D.read(FOLDER/'manifest.json')['runtime']['images']['godot_engine']['path']
        declaration=Path(D.read(FOLDER/'cells.json')[0]['folder'])/'declaration.json'
        valid={'partial','upright','ready','timeout','walking'}
        refusals=dict(partial_source='R10AF_CONTACT_REPORT_TRACE_LINK',
                      partial_owner='R10AP_RECOVERY_REPLAY_EVENT_INVALID',
                      partial_phase='R10AP_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',
                      partial_energy='R10AP_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',
                      walking_shutdown='R10AP_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
                      walking_memory='DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
                      walking_capture='R10AF_CONTACT_REPORT_RECORD_POPULATION',
                      walking_missing='R10AP_ENTRY_REPLAY_POST_HOLD_RETENTION')
        for name,case in catalog['cases'].items():
            with self.subTest(case=name):
                original=D.EVIDENCE/('development-recovery-smoke-'+case['declaration']['attempt_id'])/'declaration.json'
                self.assertEqual(case['declaration_raw_sha256'],D.binding(original)['raw_sha256'])
                report=Path(case['declaration']['children'][0]['evidence_path'])/'worker_report.json'
                output=FOLDER/('fixture-'+name+'.json')
                command=[engine,'--headless','--path',D.ROOT,'--script','res://sdk/discovery/recovery_panel_reader_v1.gd',
                         '--','fixture',declaration,report,output,original]
                if name in valid:D.process(FOLDER,'fixture-'+name,command,timeout=1200)
                else:
                    with self.assertRaises(ValueError):D.process(FOLDER,'fixture-'+name,command,timeout=1200)
                result=D.read(output)
                self.assertEqual(name in valid,result['ok'])
                if name not in valid:self.assertEqual(refusals[name],result['failure_code'])
                self.assertTrue(result['test_only'])
                self.assertEqual((0,0),(result['world_build_count'],result['solver_step_count']))


if __name__=='__main__':
    FOLDER=Path(sys.argv[1]);A.FOLDER=FOLDER
    output=io.StringIO()
    result=unittest.TextTestRunner(stream=output,verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    D.write_new(FOLDER/'panel-python-controls.json',dict(ok=result.wasSuccessful(),tests=result.testsRun,details=output.getvalue()))
    D.require(result.wasSuccessful(),'PANEL_CONTROLS:'+output.getvalue())
    D.process(FOLDER,'native-ownership-controls',[sys.executable,'-B','-X','utf8',D.ROOT/'tests/test_r10dg_native_process_observation.py'],timeout=300,test_stderr=True)
    D.process(FOLDER,'durable-host-controls',[sys.executable,'-B','-X','utf8',D.HERE/'test_recovery_discovery_host.py',FOLDER],timeout=600,test_stderr=True)
    D.require(D.read(FOLDER/'durable-host-controls.json')['ok'] is True,'PANEL_DURABLE_HOST_CONTROLS')
    D.write_new(FOLDER/'panel-safety-tests.json',dict(ok=True,python_tests=result.testsRun,native_ownership_tests=13,
                durable_host_tests=D.read(FOLDER/'durable-host-controls.json')['tests'],
                world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False))
