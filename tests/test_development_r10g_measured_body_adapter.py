"""Both R10G roles through the existing real V50 adapter and adversarial reader suite."""
import unittest
import test_development_v50_measured_body_adapter as native
class KickedAdapter(native.MeasuredBodyAdapter):
    segment = "walking_resume"
    @classmethod
    def _run_retained(cls, script, arguments, label, timeout):
        return super()._run_retained(script, arguments + ["--r10g-segment=" + cls.segment], label, timeout)
class MatchedAdapter(KickedAdapter):
    segment = "matched_continuation"
if __name__ == "__main__": unittest.main()
