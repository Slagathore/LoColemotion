"""The first R10AA kicked post-entry role use the selected actual V56 adapter and reader controls."""
import unittest
import test_development_v50_measured_body_adapter as native
class KickedAdapter(native.MeasuredBodyAdapter):
    segment = "walking_resume"
    @classmethod
    def _run_retained(cls, script, arguments, label, timeout):
        reference = native.selected()['candidate_profile']
        return super()._run_retained("res://tests/test_r10aa_measured_body_adapter.gd", arguments + ["--r10aa-segment=" + cls.segment,
                                   "--candidate-profile=" + reference['resource']], label, timeout)
    def test_declared_recovery_limits_and_bound_runtime(self):
        # The post-completion hold adds 240 commands to the inherited route.
        selection = native.selected()
        limits = native.candidate.limits(selection)
        self.assertEqual((320, 30, 1, 240, 3400, 3752), tuple(limits[k] for k in (
            "maximum_precondition_steps", "walking_prefix_steps", "interaction_steps",
            "maximum_passive_descent_steps", "after_interaction_steps", "maximum_steps_per_child")))
        self.assertEqual("sporespore_exact_s169_prone_to_standing_controller_v20", selection["post_kick_controller_id"])
        self.assertEqual("", native.candidate.walking_memory_transition_id(selection["diagnostic_schedule"]))
        binding = native.candidate.read(native.candidate.resource_path(selection["candidate"]["runtime_binding"]))
        runtime = next(f for f in binding["source_files"] if f["path"] == "sdk/core/src/runtime.rs")
        self.assertEqual(runtime["raw_sha256"], native.candidate.sha(native.ROOT / runtime["path"]))
        self.assertEqual(native.selected()['candidate_profile'], self.result['candidate_profile'])
if __name__ == "__main__": unittest.main()
