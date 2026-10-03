"""One unchanged publication case under its own R10V stage bound."""
import unittest
from test_qsdk_r10f_l15_publication import SupervisorPublication


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([SupervisorPublication('test_actual_complete_early_and_full_pair_callers')])
