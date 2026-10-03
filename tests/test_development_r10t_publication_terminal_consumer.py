"""One unchanged publication case under its own R10T stage bound."""
import unittest
from test_qsdk_r10f_l15_publication import SupervisorPublication


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([SupervisorPublication('test_whole_terminal_consumer_keeps_valid_children_but_no_route_claim')])
