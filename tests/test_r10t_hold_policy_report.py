"""Pure policy-report routing of an actual retained synthetic native hold."""
import hashlib
import json
import unittest
import uuid
from pathlib import Path
import test_development_passive_entry_replay as shared
SOURCE=shared.ROOT.parent/'SporeSpore_Evidence/r10t-complete-hold-report-dfacaa712cb54fa39d2e956553452d29/ready/worker_report.json'
SHA='sha256:3cf10e700b3de42c8eb985ad8691e3679b65bb4b85f00fc06287e1610bb96b5f'
class HoldPolicyReport(unittest.TestCase):
    def test_post_hold_identity_and_crossed_fields(self):
        self.root=shared.entry.EVIDENCE/('r10t-hold-policy-report-'+uuid.uuid4().hex);self.root.mkdir()
        print('R10T_HOLD_POLICY_REPORT_ROOT',self.root,flush=True)
        raw=SOURCE.read_bytes();self.assertEqual(SHA,'sha256:'+hashlib.sha256(raw).hexdigest())
        original=json.loads(raw)
        value=dict(source_report=dict(path=SOURCE.as_posix(),raw_sha256=SHA),original_attempt_reclassified=False,
            report=dict(retained_arm=dict(walking_sessions=original['retained_arm']['walking_sessions'])))
        (self.root/'input.json').write_text(json.dumps(value)+'\n',encoding='utf-8')
        result=shared.PassiveEntryReplay._run_retained.__func__(self,'res://tests/test_r10t_hold_policy_report.gd',['--',str(self.root/'input.json'),str(self.root/'result.json')],'policy',90)
        observed=json.loads((self.root/'result.json').read_bytes())
        self.assertEqual(0,result.returncode,result.stderr.decode())
        self.assertTrue(observed['ok'],observed)
        self.assertEqual(15,len(observed['checks']))
        self.assertEqual((0,0),(observed['world_build_count'],observed['solver_step_count']))
if __name__=='__main__':unittest.main()
