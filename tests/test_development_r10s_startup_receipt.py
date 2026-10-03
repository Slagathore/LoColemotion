"""Cold endpoint checks of the source-bound R10S native startup component."""
import unittest
import uuid
import r10s_startup_component as component

class StartupReceipt(unittest.TestCase):
    def test_fresh_v56_startup_key_and_original_terminal_bytes(self):
        out=component.EVIDENCE/('r10s-startup-receipt-'+uuid.uuid4().hex);out.mkdir()
        print('R10S_STARTUP_RECEIPT '+str(out),flush=True)
        before=component._source_snapshot();component.write(out/'source_before.json',before)
        result=component.audit(cold=True);component.write(out/'result.json',result)
        after=component._source_snapshot();component.write(out/'source_after.json',after)
        self.assertEqual(before,after)
        self.assertEqual((1800,131400,3600,5400,0),tuple(result[k] for k in
            ['fresh_v56_startup_cases','fresh_v56_startup_step_calls','legacy_terminal_byte_checks','cold_terminal_replays','refused_startup_cases']))
        self.assertFalse(result['physical_acceptance_authority'] or result['release_authority'])

if __name__=='__main__':unittest.main()
