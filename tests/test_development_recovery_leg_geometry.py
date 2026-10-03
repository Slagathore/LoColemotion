"""Cold geometry checks: native contact classification is never replaced."""
import json
import math
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_leg_geometry as geometry


class LegGeometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.observed = geometry.observe()

    def test_complete_retained_population_and_exact_record(self):
        expected = json.loads((ROOT / 'sdk/development/recovery_leg_geometry_v11.json').read_text())
        self.assertEqual(expected, self.observed)
        self.assertEqual(267, self.observed['complete_observation_count'])
        self.assertEqual(1068, self.observed['reconstructed_body_origin_count'])
        self.assertFalse(self.observed['original_results_reclassified'])
        self.assertEqual(0, self.observed['world_build_count'])

    def test_contact_site_is_distinct_from_recorded_body_origin(self):
        rear = self.observed['samples'][0]['feet'][2]
        self.assertEqual(0.09776944667100906, rear['recorded_distal_body_origin_world_m'][1])
        self.assertGreater(rear['ideal_hinge_contact_site_center_world_m'][1], 0.15)
        # This is a descriptive residual, not a newly approved physical tolerance.
        self.assertGreater(self.observed['maximum_body_origin_residual_m'], 0.0)

    def test_geometry_units_axis_and_midpoint_distinction(self):
        self.assertEqual([0.0, -0.35], geometry.endpoint(0.0, 0.0, 0.2, 0.15))
        x, y = geometry.endpoint(math.pi/2, 0.0, 0.2, 0.15)
        self.assertAlmostEqual(0.35, x)
        self.assertAlmostEqual(0.0, y)
        self.assertEqual([1, 2, 3], geometry.rotate(dict(x=0, y=0, z=0, w=1), [1, 2, 3]))


if __name__ == '__main__':
    unittest.main()
