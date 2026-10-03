"""One unchanged launcher test under its own R10U stage bound."""
import unittest
from test_development_r10u_launcher import R10ULauncher


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10ULauncher('test_actual_initial_single_library_context_and_worker_declaration_agree')])
