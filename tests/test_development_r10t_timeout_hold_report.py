"""Run the unchanged test_timeout_hold_full_report in its own bounded process."""
import unittest
from test_r10t_complete_hold_report import CompleteHoldReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([CompleteHoldReport("test_timeout_hold_full_report")])
