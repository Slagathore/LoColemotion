"""Fresh complete Python report-consumer case: walking_capture."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10aj_report_gate as gate

class ReportCase(unittest.TestCase):
    def test_complete_consumer(self):
        self.assertEqual('walking_capture', gate.run_case('walking_capture')['case'])

if __name__ == '__main__': unittest.main()
