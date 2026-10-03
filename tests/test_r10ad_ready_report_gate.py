"""One bounded R10AD ready report case; inherited native checks unchanged."""
import unittest
import test_r10ad_complete_phases as cases


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([cases.R10ADCompletePhases('test_ready_hold')])


if __name__ == '__main__': unittest.main()
