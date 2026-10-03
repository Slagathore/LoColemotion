"""One complete R10AA upright report in a separately bounded gate process."""
import unittest
import test_r10aa_complete_hold_report as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10AACompleteHoldReport("test_direct_upright_complete_report")])

if __name__ == "__main__": unittest.main()
