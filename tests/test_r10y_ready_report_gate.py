"""One complete R10Y ready report in a separately bounded gate process."""
import unittest
import test_r10y_complete_hold_report as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10YCompleteHoldReport("test_ready_hold_complete_report")])

if __name__ == "__main__": unittest.main()
