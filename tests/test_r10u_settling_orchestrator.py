"""New orchestrator terminal boundaries on copied R10S native events; no physics."""
import json
import os
import unittest
import uuid

from development_recovery_candidate_test_support import ROOT, selected, arguments
from r10s_launch_component import bind
from recovery_post_completion_hold_probe import retained_report
import test_development_passive_entry_replay as shared


class SettlingOrchestrator(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        previous = os.environ.get('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE')
        os.environ['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = 'sdk/development/recovery_candidates/r10u-v56-post-recovery-hold-integrated-v2.json'
        try: selection = selected()
        finally:
            if previous is None: os.environ.pop('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE', None)
            else: os.environ['SPORESPORE_DEVELOPMENT_TEST_CANDIDATE'] = previous
        cls.root = ROOT.parent/'SporeSpore_Evidence'/('r10u-settling-orchestrator-'+uuid.uuid4().hex)
        cls.root.mkdir()
        print('R10U_SETTLING_ORCHESTRATOR_ROOT', cls.root, flush=True)
        cases, references = [], []
        for label, filename, phase, baseline in [
            ('phase245_upright','r10s_phase245_development_negative_closure_v1.json','measured_upright_stabilization',False),
            ('phase246_upright','r10s_phase246_development_pair_closure_v1.json','measured_upright_stabilization',False),
            ('phase241_partial','r10s_phase241_development_positive_closure_v1.json','measured_partial_fall_recovery',False),
            ('phase243_prone','r10s_phase243_development_positive_closure_v1.json','offset_bound_recovery_epoch',False),
            ('no_kick','r10s_phase246_development_pair_closure_v1.json','no_kick_neutral_stance_entry',True)]:
            role = 'matched_no_kick_continuation' if baseline else 'kick_passive_recovery_resume'
            report, reference = retained_report(bind(ROOT/'sdk/recovery'/filename), role)
            transitions = [t for t in report['passive_entry']['orchestrator_transitions']
                if t['state_before']['phase']==phase and t['advance'].get('ok')
                and t['advance']['state_after']['phase'] != phase]
            assert len(transitions)==1,(label,len(transitions))
            source = {}
            if 'upright' in label:
                rows = [r for r in report['stance_entry']['readiness_rows'] if r['purpose']=='post_recovery_entry']
                assert len(rows)==1
                source = rows[0]['source']
            cases.append(dict(case_id=label, transition=transitions[0], source=source))
            references.append(reference)
        path = cls.root/'retained_terminal_inputs.json'
        path.write_bytes((json.dumps(dict(cases=cases),separators=(',',':'))+'\n').encode())
        (cls.root/'original_report_bindings.json').write_bytes((json.dumps(references,indent=2)+'\n').encode())
        run = shared.PassiveEntryReplay._run_retained.__func__(cls,
            'res://tests/test_r10u_settling_orchestrator.gd', ['--', str(path), *arguments(selection)], 'orchestrator', 120)
        cls.result = shared.marker(run,'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')
        (cls.root/'result.json').write_bytes((json.dumps(cls.result,indent=2)+'\n').encode())
        assert cls.result['ok'],cls.result

    def check_group(self,prefix):
        checks = {k:v for k,v in self.result['checks'].items() if k.startswith(prefix)}
        self.assertTrue(checks)
        self.assertTrue(all(checks.values()),checks)

    def test_retained_terminal_boundaries(self): self.check_group('recovery_source_')
    def test_hold_and_clock_accounting(self): self.check_group('hold_')
    def test_fresh_walking_handoff(self): self.check_group('handoff_')
    def test_unaffected_branches(self): self.check_group('preservation_')
    def test_refusals(self): self.check_group('guards_')


if __name__=='__main__': unittest.main()
