"""Bounded R10AJ original_prone zero-world worker sequence."""
import unittest
import test_development_r10aj_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10AJWorker("test_original_prone_worker")])

if __name__ == "__main__": unittest.main()
