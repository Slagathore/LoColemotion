"""One existing R10Z original_prone worker case under its unchanged child deadline."""
import unittest
import test_development_r10z_worker as shared

def load_tests(loader, tests, pattern):
    return unittest.TestSuite([shared.R10ZWorker("test_original_prone_worker")])

if __name__ == "__main__": unittest.main()
