"""One bounded R10AG timeout report case; inherited native checks unchanged."""
import unittest
import test_r10ag_complete_phases as cases


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([cases.R10AGCompletePhases('test_timeout_hold')])


if __name__ == '__main__': unittest.main()
