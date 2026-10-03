"""Run the unchanged test_b_complete_partial_report_without_walking in its own bounded process."""
import unittest
from test_development_r10v_branch_complete_report import R10VBranchCompleteReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10VBranchCompleteReport("test_b_complete_partial_report_without_walking")])
