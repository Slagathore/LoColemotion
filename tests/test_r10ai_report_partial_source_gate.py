"""Fresh complete Python report-consumer case: partial_source."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'sdk/conformance'))
import r10ai_report_gate as gate

class ReportCase(unittest.TestCase):
    def test_complete_consumer(self):
        self.assertEqual('partial_source', gate.run_case('partial_source')['case'])

if __name__ == '__main__': unittest.main()
