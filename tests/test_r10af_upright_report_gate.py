"""One bounded R10AF upright report case; inherited native checks unchanged."""
import unittest
import test_r10af_complete_phases as cases


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([cases.R10AFCompletePhases('test_direct_upright')])


if __name__ == '__main__': unittest.main()
