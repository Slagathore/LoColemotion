"""Fresh complete Python report-consumer case: timeout."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10aj_report_gate as gate

class ReportCase(unittest.TestCase):
    def test_complete_consumer(self):
        self.assertEqual('timeout', gate.run_case('timeout')['case'])

if __name__ == '__main__': unittest.main()
