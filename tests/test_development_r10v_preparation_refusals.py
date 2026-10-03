"""Run the unchanged test_cold_reader_refuses_crossed_preparation_and_walking_links in its own bounded process."""
import unittest
from test_development_r10v_preparation_report import R10VPreparationReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10VPreparationReport("test_cold_reader_refuses_crossed_preparation_and_walking_links")])
