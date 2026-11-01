"""Retain the original containment assertions through the successor owner."""
import unittest
from unittest.mock import patch
import showcase_owner
from contained_stage_owner_v2 import OwnedChild
import test_showcase


class Containment(unittest.TestCase):
    def test_original_leaf_and_descendant_control_with_retained_handles(self):
        # The original assertion body stays immutable; only its owner is selected.
        with patch.object(showcase_owner,"OwnedChild",OwnedChild):
            control=test_showcase.Construction("test_real_job_owner_reaps_leaf_and_descendant")
            control.test_real_job_owner_reaps_leaf_and_descendant()


if __name__=="__main__":unittest.main()
