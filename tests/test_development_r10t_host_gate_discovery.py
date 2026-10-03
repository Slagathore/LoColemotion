"""One unchanged launcher test under its own R10T stage bound."""
import unittest
from test_development_r10t_launcher import R10TLauncher


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10TLauncher('test_actual_gate_selects_r10t_and_every_declared_test_exists')])
