"""One bounded R10AF ready report case; inherited native checks unchanged."""
import unittest
import test_r10af_complete_phases as cases


def load_tests(loader, tests, pattern):
    return unittest.TestSuite([cases.R10AFCompletePhases('test_ready_hold')])


if __name__ == '__main__': unittest.main()
