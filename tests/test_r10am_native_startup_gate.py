"""Actual native startup preflight on the clean pushed gate source; no reservation."""
import json,sys,unittest,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10am_startup_check as check
import r10am_selection_check as selection

class R10AMNativeStartupGate(unittest.TestCase):
    def test_clean_native_helper_preflight_before_reservation(self):
        # The real safety supervisor owns the operation lock. Never nest it here.
        selection.candidate.selection(selection.identity.reference())
        out=check.fixture.identity.EVIDENCE/('r10am-startup-preflight-'+uuid.uuid4().hex)
        out.mkdir();print('R10AM_STARTUP_GATE_ROOT '+str(out),flush=True)
        result=check.run(out,require_clean_success=True)
        self.assertIs(result['native_preflight_passed'],True)
        self.assertEqual(0,result['world_build_count']);self.assertEqual(0,result['solver_step_count'])
        self.assertIs(result['physical_acceptance_authority'],False)
        print(json.dumps(result),flush=True)

if __name__=='__main__':unittest.main()
