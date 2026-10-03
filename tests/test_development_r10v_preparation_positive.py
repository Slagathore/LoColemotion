"""Run the unchanged test_complete_native_preparation_retention_and_independent_replay in its own bounded process."""
import unittest
from test_development_r10v_preparation_report import R10VPreparationReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10VPreparationReport("test_complete_native_preparation_retention_and_independent_replay")])
