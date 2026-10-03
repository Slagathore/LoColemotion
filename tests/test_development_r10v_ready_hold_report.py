"""Run the unchanged test_ready_hold_full_report in its own bounded process."""
import unittest
from test_r10v_complete_hold_report import CompleteHoldReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([CompleteHoldReport("test_ready_hold_full_report")])
