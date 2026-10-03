"""One existing R10Y new_prone worker case under its unchanged child deadline."""
import unittest
import test_development_r10y_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10YWorker("test_new_prone_worker")])

if __name__ == "__main__": unittest.main()
