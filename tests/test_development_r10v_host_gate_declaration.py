"""One unchanged launcher test under its own R10V stage bound."""
import unittest
from test_development_r10v_launcher import R10VLauncher


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([R10VLauncher('test_actual_initial_single_library_context_and_worker_declaration_agree')])
