"""Mandatory unchanged legacy differential, without an unrelated native fixture."""
import unittest
import test_development_v32_walking_policy as shared


class LegacySourceDifferential(unittest.TestCase):
    test_legacy_source_suite_has_no_new_failures = shared.WalkingPolicy.test_legacy_source_suite_has_no_new_failures


if __name__ == '__main__':
    unittest.main()
