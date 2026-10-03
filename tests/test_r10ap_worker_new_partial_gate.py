"""Bounded R10AP new_partial zero-world worker sequence."""
import unittest
import test_development_r10ap_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10APWorker("test_new_partial_worker")])

if __name__ == "__main__": unittest.main()
