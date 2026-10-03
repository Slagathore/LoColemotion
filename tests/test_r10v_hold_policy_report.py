"""Pure policy-report routing of an actual retained synthetic native hold."""
import hashlib
import json
import unittest
import uuid
from pathlib import Path
import test_development_passive_entry_replay as shared
SOURCE=shared.ROOT.parent/'SporeSpore_Evidence/r10v-complete-hold-report-64f7e8e39ed143e684fb997ed173f1ac/ready/worker_report.json'
SHA='sha256:2ac33e4f45cc18abfec092ee5e8efbb05fbf0ed087cb572e0dfd02ac4cca3a9a'
class HoldPolicyReport(unittest.TestCase):
    def test_post_hold_identity_and_crossed_fields(self):
        self.root=shared.entry.EVIDENCE/('r10v-hold-policy-report-'+uuid.uuid4().hex);self.root.mkdir()
        print('R10V_HOLD_POLICY_REPORT_ROOT',self.root,flush=True)
        raw=SOURCE.read_bytes();self.assertEqual(SHA,'sha256:'+hashlib.sha256(raw).hexdigest())
        original=json.loads(raw)
        value=dict(source_report=dict(path=SOURCE.as_posix(),raw_sha256=SHA),original_attempt_reclassified=False,
            report=dict(retained_arm=dict(walking_sessions=original['retained_arm']['walking_sessions'])))
        (self.root/'input.json').write_text(json.dumps(value)+'\n',encoding='utf-8')
        result=shared.PassiveEntryReplay._run_retained.__func__(self,'res://tests/test_r10v_hold_policy_report.gd',['--',str(self.root/'input.json'),str(self.root/'result.json')],'policy',90)
        observed=json.loads((self.root/'result.json').read_bytes())
        self.assertEqual(0,result.returncode,result.stderr.decode())
        self.assertTrue(observed['ok'],observed)
        self.assertEqual(15,len(observed['checks']))
        self.assertEqual((0,0),(observed['world_build_count'],observed['solver_step_count']))
if __name__=='__main__':unittest.main()
