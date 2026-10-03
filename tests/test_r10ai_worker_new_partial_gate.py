"""Bounded R10AI new_partial zero-world worker sequence."""
import unittest
import test_development_r10ai_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10AIWorker("test_new_partial_worker")])

if __name__ == "__main__": unittest.main()
