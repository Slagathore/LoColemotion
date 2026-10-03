"""One complete R10Z timeout report in a separately bounded gate process."""
import unittest
import test_r10z_complete_hold_report as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10ZCompleteHoldReport("test_timeout_hold_complete_report")])

if __name__ == "__main__": unittest.main()
