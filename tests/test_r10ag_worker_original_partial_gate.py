"""Bounded R10AG original_partial zero-world worker sequence."""
import unittest
import test_development_r10ag_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10AGWorker("test_original_partial_worker")])

if __name__ == "__main__": unittest.main()
