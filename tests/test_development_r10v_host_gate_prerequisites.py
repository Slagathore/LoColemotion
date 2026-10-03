"""One unchanged launcher test under its own R10V stage bound."""
import unittest
from test_development_r10v_launcher import R10VLauncher


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10VLauncher('test_later_stages_refuse_without_the_required_retained_positive_result')])
