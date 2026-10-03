"""One existing R10AA new_partial worker case under its unchanged child deadline."""
import unittest
import test_development_r10aa_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10AAWorker("test_new_partial_worker")])

if __name__ == "__main__": unittest.main()
