"""Transport failure receipts and timeout ownership; no physics."""
import sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ad_startup_transport as transport

class StartupTransport(unittest.TestCase):
    def test_nonzero_retains_both_streams(self):
        command=[sys.executable,'-B','-c','import sys; print("out"); print("err",file=sys.stderr); sys.exit(7)']
        with self.assertRaises(transport.CommandRefused) as raised:
            transport.checked_output(command,cwd=ROOT)
        receipt=raised.exception.receipt
        self.assertEqual(7,receipt['exit_code']);self.assertFalse(receipt['timed_out'])
        self.assertEqual('out',receipt['stdout'].strip());self.assertEqual('err',receipt['stderr'].strip())
    def test_timeout_retains_output_and_terminates_child(self):
        command=[sys.executable,'-B','-c','import time; print("started",flush=True); time.sleep(20)']
        with self.assertRaises(transport.CommandRefused) as raised:
            transport.checked_output(command,cwd=ROOT,timeout_seconds=1)
        self.assertTrue(raised.exception.receipt['timed_out'])
        self.assertIn('started',raised.exception.receipt['stdout'])
    def test_explicit_streams_and_success(self):
        command=[sys.executable,'-B','-c','import sys; print("success" if sys.stdin.read()=="" else "bad"); print("retained",file=sys.stderr)']
        result=transport.run_captured(command,cwd=ROOT)
        self.assertEqual(0,result['exit_code']);self.assertEqual('success',result['stdout'].strip())
        self.assertEqual('retained',result['stderr'].strip())

if __name__=='__main__':unittest.main()
