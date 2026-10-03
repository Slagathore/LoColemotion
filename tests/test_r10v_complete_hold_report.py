"""Complete R10V hold reports and cold replay, with supplied synthetic poses."""
import copy
import json
import os
from pathlib import Path
import subprocess
import time
import unittest
import uuid
import test_development_r10v_complete_report as shared
import test_development_r10v_preparation_report as preparation

class CompleteHoldReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=shared.EVIDENCE/('r10v-complete-hold-report-'+uuid.uuid4().hex);cls.out.mkdir()
        cls.before=shared.entry._source_snapshot();shared.write(cls.out/'source_before.json',cls.before)
        print('R10V_COMPLETE_HOLD_REPORT_ROOT',cls.out,flush=True)
        cls.reference=shared.candidate.reference_for_path(shared.PROFILE)
        shared.candidate.selection(cls.reference)
        exposed=preparation.exposed_input()
        segment=next(s for s in exposed['segments'] if s['id']=='v50_hold_stance_entry')
        cls.hold=dict(source_report=exposed['source_report'],original_result_regraded=False,
            synthetic_counterfactual_only=True,physical_values_are_supplied_not_simulated=True,
            segment=dict(id='v50_post_recovery_settling',start=segment['start'],initial_contact_by_limb=segment['traces'][-1]['contact_by_limb']),
            sample=segment['samples'][-1],trace=segment['traces'][-1],readiness=segment['readiness'][-1])
        runtime=shared.native.read(shared.ROOT/'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json')
        old=shared.native.read(shared.native.Q_BINDING)
        fixtures=[shared.native.fixtures(old['compiled_fixtures']['path'],'R10Q_UPRIGHT_FIXTURE')[0],
                  *shared.native.fixtures(runtime['compiled_fixtures']['path'],'R10R_UPRIGHT_FIXTURE')]
        cls.fixtures=cls.out/'source-fixtures.jsonl'
        cls.fixtures.write_text(''.join('R10V_SOURCE_FIXTURE '+json.dumps(f)+'\n' for f in fixtures),encoding='utf-8')
    @classmethod
    def tearDownClass(cls):
        after=shared.entry._source_snapshot();shared.write(cls.out/'source_after.json',after)
        assert after==cls.before,'R10V_HOLD_REPORT_SOURCE_DRIFT'
    def run_case(self,timeout):
        directory=self.out/('timeout' if timeout else 'ready');directory.mkdir()
        declared=shared.declaration(self.reference,self.before['head'])
        shared.write(directory/'declaration.json',declared)
        shared.write(directory/'input.json',dict(self.hold,timeout=timeout))
        command=[str(shared.GODOT),'--headless','--path',str(shared.ROOT),'--script',
            'res://tests/test_r10v_complete_hold_report.gd','--',str(self.fixtures),str(directory/'fixture.json')]
        environment=dict(os.environ,SPORE_R10V_FIXTURE_DECLARATION=str(directory/'declaration.json'),SPORE_R10V_HOLD_REPORT_INPUT=str(directory/'input.json'))
        started=time.monotonic()
        with (directory/'stdout.log').open('xb') as stdout,(directory/'stderr.log').open('xb') as stderr:
            try:
                result=subprocess.run(command,cwd=shared.ROOT,env=environment,stdout=stdout,stderr=stderr,timeout=420,creationflags=subprocess.CREATE_NO_WINDOW)
            except subprocess.TimeoutExpired:
                shared.write(directory/'execution.json',dict(command=command,timed_out=True,direct_process_killed_and_reaped=True,world_build_count=0,solver_step_count=0));raise
        shared.write(directory/'execution.json',dict(command=command,exit_code=result.returncode,seconds=time.monotonic()-started,world_build_count=0,solver_step_count=0))
        self.assertEqual('',(directory/'stderr.log').read_text())
        fixture=json.loads((directory/'fixture.json').read_bytes())
        self.assertTrue(fixture['ok'],dict(failure={k:v for k,v in fixture['failure'].items() if not isinstance(v,(dict,list))},evaluator_failure=fixture['failure'].get('retained_failure',{}).get('evaluator_failure_code'),checks={k:v for k,v in fixture['checks'].items() if not v}))
        self.assertEqual(0,result.returncode)
        report=fixture['active']['report'];path=directory/'worker_report.json';shared.write(path,report)
        replay=shared.entry.run_replay(path)
        self.assertTrue(replay['ok'] and replay['complete_report_timeline_replayed'])
        self.assertEqual(report['solver_step_count'],replay['transition_count'])
        self.assertEqual(240 if timeout else 30,replay['stance_entry_replay']['replayed_post_recovery_hold_commands'])
        compiled=shared.LocomotionCore(runtime_path()).compile_bounded_quadruped(report['configuration']['base_descriptor'])
        measured=shared.finite.measure(report,compiled);shared.write(directory/'finite-task.json',measured)
        self.assertFalse(measured['finite_task_predicates_passed'])
        self.assertFalse(measured['entry']['initial_recovery_ready'])
        self.assertEqual('timeout' if timeout else 'bounded_hold',measured['entry']['post_recovery']['handoff'])
        shared.write(directory/'replay.json',replay)
        return directory,report
    def test_ready_hold_full_report(self):self.run_case(False)
    def test_timeout_hold_full_report(self):self.run_case(True)

def runtime_path():return shared.entry.binding(shared.candidate.selection(shared.candidate.reference_for_path(shared.PROFILE)))['runtime']['path']
if __name__=='__main__':unittest.main()
