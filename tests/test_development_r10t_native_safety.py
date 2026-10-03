"""R10T budget for the unchanged shared native safety population."""
import functools
import unittest
from unittest.mock import patch
import test_development_recovery_smoke as original


class R10TNativeSafetySuite(unittest.TestSuite):
    def run(self, result, debug=False):
        # Only the default complete setup gets 300 seconds. The original test's
        # explicit 20-second unbound-worker refusal still overrides this default.
        native = functools.partial(original.native, timeout=300)
        with patch.object(original, 'native', native):
            return super().run(result, debug)


def load_tests(loader, tests, pattern):
    return R10TNativeSafetySuite(loader.loadTestsFromTestCase(original.DevelopmentSmoke))
