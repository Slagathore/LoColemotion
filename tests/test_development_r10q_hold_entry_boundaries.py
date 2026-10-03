"""R10Q-selected native hold boundaries using immutable exposed measurements."""
import unittest
import test_recovery_v50_hold_entry_boundaries as shared

class R10QV50HoldEntryBoundaries(shared.V50HoldEntryBoundaries):
    @classmethod
    def _run_retained(cls, script, arguments, label, timeout):
        return super()._run_retained("res://tests/test_development_r10q_hold_entry_boundaries.gd", arguments, label, timeout)

if __name__ == '__main__':
    unittest.main()
