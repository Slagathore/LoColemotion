"""Actual selected context and crossed-context refusals before any world."""
import unittest, uuid
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10ai_pre_world_check as check

class PreWorldGate(unittest.TestCase):
    def test_context_positive_and_crossed_source_refusals(self):
        out=check.fixture.identity.EVIDENCE/('r10ai-pre-world-check-'+uuid.uuid4().hex)
        out.mkdir();print('R10AI_PRE_WORLD_ROOT '+str(out),flush=True)
        result=check.run(out)
        self.assertIs(result['ok'],True)
        self.assertEqual(5,result['independent_native_processes'])
        self.assertIs(result['population_reserved'],False)
        self.assertEqual(0,result['world_build_count'])

if __name__=='__main__':unittest.main()
