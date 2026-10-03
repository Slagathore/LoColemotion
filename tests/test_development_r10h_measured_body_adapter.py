"""Both R10H post-entry roles use the unchanged actual V50 adapter and reader controls."""
import unittest
import test_development_v50_measured_body_adapter as native
class KickedAdapter(native.MeasuredBodyAdapter):
    segment = "walking_resume"
    @classmethod
    def _run_retained(cls, script, arguments, label, timeout):
        return super()._run_retained(script, arguments + ["--r10h-segment=" + cls.segment], label, timeout)
class MatchedAdapter(KickedAdapter):
    segment = "matched_continuation"
if __name__ == "__main__": unittest.main()
