"""Bounded R10AP original_partial zero-world worker sequence."""
import unittest
import test_development_r10ap_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10APWorker("test_original_partial_worker")])

if __name__ == "__main__": unittest.main()
