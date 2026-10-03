"""Cold endpoint checks of the unchanged R10S native startup component for R10T."""
import unittest
import uuid
import sys
from pathlib import Path

# Each production stage starts a fresh interpreter with no inherited test path.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10s_startup_component as component
import r10t_startup_history as history

class StartupReceipt(unittest.TestCase):
    def test_fresh_v56_startup_key_and_original_terminal_bytes(self):
        out=component.EVIDENCE/('r10t-startup-receipt-'+uuid.uuid4().hex);out.mkdir()
        print('R10T_STARTUP_RECEIPT '+str(out),flush=True)
        before=component._source_snapshot();component.write(out/'source_before.json',before)
        result=history.audit(cold=True);component.write(out/'result.json',result)
        after=component._source_snapshot();component.write(out/'source_after.json',after)
        self.assertEqual(before,after)
        self.assertEqual((1800,131400,3600,5400,0),tuple(result[k] for k in
            ['fresh_v56_startup_cases','fresh_v56_startup_step_calls','legacy_terminal_byte_checks','cold_terminal_replays','refused_startup_cases']))
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])

if __name__=='__main__':unittest.main()
