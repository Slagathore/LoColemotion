"""Exact diagnostic comparison preserves type and signed-zero differences."""
import unittest
from audit_proximal_repeatability import differences
class DifferenceControls(unittest.TestCase):
    def test_01_identical_nested_values(self):self.assertEqual(differences({"x":[1.,2.]},{"x":[1.,2.]}),[])
    def test_02_signed_zero_is_preserved(self):
        d=differences([0.],[-0.]);self.assertEqual(len(d),1);self.assertEqual(d[0]["path"],"/0")
    def test_03_tiny_target_change_is_not_tolerated(self):
        d=differences({"target":[1.]},{"target":[1.+1e-15]});self.assertEqual(d[0]["path"],"/target/0")
    def test_04_type_and_population_changes_are_visible(self):
        self.assertTrue(differences([1],[1.]));self.assertTrue(differences([1.],[1.,2.]))
    def test_05_no_unchanged_leaf_is_reported(self):
        d=differences({"a":[1.,2.],"b":3},{"a":[1.,4.],"b":3});self.assertEqual(len(d),1);self.assertEqual(d[0]["path"],"/a/1")
if __name__=="__main__":unittest.main()
