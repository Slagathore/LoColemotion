"""Run the unchanged test_a_prone_confirmation_report_without_walking in its own bounded process."""
import unittest
from test_development_r10t_branch_complete_report import R10TBranchCompleteReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10TBranchCompleteReport("test_a_prone_confirmation_report_without_walking")])
