"""One existing R10Z original_partial worker case under its unchanged child deadline."""
import unittest
import test_development_r10z_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10ZWorker("test_original_partial_worker")])

if __name__ == "__main__": unittest.main()
