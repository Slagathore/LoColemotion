"""Run the unchanged test_cold_reader_refuses_crossed_preparation_and_walking_links in its own bounded process."""
import unittest
from test_development_r10t_preparation_report import R10TPreparationReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10TPreparationReport("test_cold_reader_refuses_crossed_preparation_and_walking_links")])
