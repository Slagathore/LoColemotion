"""Run the unchanged test_b_complete_partial_report_without_walking in its own bounded process."""
import unittest
from test_development_r10u_branch_complete_report import R10UBranchCompleteReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10UBranchCompleteReport("test_b_complete_partial_report_without_walking")])
