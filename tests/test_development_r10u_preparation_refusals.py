"""Run the unchanged test_cold_reader_refuses_crossed_preparation_and_walking_links in its own bounded process."""
import unittest
from test_development_r10u_preparation_report import R10UPreparationReport

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10UPreparationReport("test_cold_reader_refuses_crossed_preparation_and_walking_links")])
