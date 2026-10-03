"""Fresh AG worker segment and independent native reader, zero physics."""
import unittest
import test_development_r10ap_worker as worker
import r10ap_gate_support as native
class R10APSegmentReader(unittest.TestCase):
    setUpClass=classmethod(worker.R10APWorker.setUpClass.__func__)
    tearDownClass=classmethod(worker.R10APWorker.tearDownClass.__func__)
    run_worker=worker.R10APWorker.run_worker
    run_godot=native.run_godot
    def test_actual_worker_segment_and_crossed_sources(self):
        self.run_worker('fresh-segment','test_development_r10ap_worker_hooks.gd','partial')
        result=self.run_godot('reader','test_development_r10ap_segment_reader.gd',self.out/'fresh-segment.json',180)
        self.assertEqual(303,result['replay']['transition_count'])
        self.assertEqual(240,result['replay']['entry_observation_count'])
        self.assertEqual(63,result['replay']['partial_observation_count'])
        self.assertFalse(result['full_report_checked'])
if __name__=='__main__':unittest.main()
