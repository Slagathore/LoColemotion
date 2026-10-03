"""R10R-selected native joint boundaries using immutable exposed measurements."""
import unittest
import test_recovery_joint_pose_entry_boundaries as shared

class R10RJointPoseEntryBoundaries(shared.JointPoseEntryBoundaries):
    @classmethod
    def _run_retained(cls, script, arguments, label, timeout):
        return super()._run_retained("res://tests/test_development_r10r_joint_entry_boundaries.gd", arguments, label, timeout)

if __name__ == '__main__':
    unittest.main()
