"""Run the unchanged test_complete_native_preparation_retention_and_independent_replay in its own bounded process."""
import unittest
from test_development_r10t_preparation_report import R10TPreparationReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10TPreparationReport("test_complete_native_preparation_retention_and_independent_replay")])
