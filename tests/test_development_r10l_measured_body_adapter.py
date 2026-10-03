"""Both R10L post-entry roles use the selected actual V52 adapter and reader controls."""
import unittest
import test_development_v50_measured_body_adapter as native
class KickedAdapter(native.MeasuredBodyAdapter):
    segment = "walking_resume"
    @classmethod
    def _run_retained(cls, script, arguments, label, timeout):
        reference = native.selected()['candidate_profile']
        return super()._run_retained(script, arguments + ["--r10l-segment=" + cls.segment,
                                   "--candidate-profile=" + reference['resource']], label, timeout)
    def test_declared_recovery_limits_and_bound_runtime(self):
        super().test_declared_recovery_limits_and_bound_runtime()
        self.assertEqual(native.selected()['candidate_profile'], self.result['candidate_profile'])
class MatchedAdapter(KickedAdapter):
    segment = "matched_continuation"
if __name__ == "__main__": unittest.main()
