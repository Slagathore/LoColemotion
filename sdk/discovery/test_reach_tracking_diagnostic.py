"""Boundary controls for posthoc reach tracking; no physical worlds."""
import copy
import unittest
import numpy as np
import reach_tracking_diagnostic_metrics as d


class TrackingControls(unittest.TestCase):
    def test_safe_window_excludes_entire_first_failing_command(self):
        self.assertEqual(d.safe_command_end(dict(internal_step=667)),133)
        self.assertEqual(d.safe_command_end(dict(internal_step=695)),138)
        self.assertEqual(d.safe_command_end(dict(internal_step=691)),138)
        self.assertEqual(d.safe_command_end(None),140)
        self.assertEqual(d.safe_command_end(dict(internal_step=7200)),140)
        for value in (0,-1,True,1.5):
            with self.assertRaises(ValueError):d.safe_command_end(dict(internal_step=value))

    def test_pure_vertical_translation_leaves_orientation_contribution_zero(self):
        value=d.geometry_change(.35,.01,.02,.4,.06,True)
        self.assertAlmostEqual(value["root_translation_contribution_m"],-.05)
        self.assertAlmostEqual(value["orientation_and_bounded_reach_contribution_m"],0.)
        self.assertAlmostEqual(value["remaining_joint_extension_clearance_m"],.01)
        self.assertFalse(value["causal_dynamic_effect_established"])

    def test_orientation_geometry_can_outweigh_body_lowering(self):
        value=d.geometry_change(.35,.10,.102,.4,.04,True)
        self.assertAlmostEqual(value["root_translation_contribution_m"],-.05)
        self.assertAlmostEqual(value["orientation_and_bounded_reach_contribution_m"],.11)
        self.assertAlmostEqual(value["minimum_clearance_change_m"],.06)

    def test_invalid_or_out_of_bounds_geometry_is_not_silently_clamped(self):
        with self.assertRaises(ValueError):d.geometry_change(.4,.03,.02,.4,.03,True)
        value=d.geometry_change(.4,.03,.02,.4,.03,False)
        self.assertAlmostEqual(value["remaining_joint_extension_clearance_m"],-.01)
        with self.assertRaises(ValueError):d.geometry_change(float("nan"),.03,.03,.4,.03,True)

    def test_orientation_vector_is_canonical_and_quaternion_sign_invariant(self):
        q=[np.sqrt(.5),0,0,np.sqrt(.5)]
        np.testing.assert_allclose(d.orientation_vector(q),[np.pi/2,0,0],rtol=0,atol=1e-12)
        np.testing.assert_allclose(d.orientation_vector([-x for x in q]),d.orientation_vector(q),rtol=0,atol=1e-12)
        self.assertEqual(d.orientation_vector([0,0,0,1]),[0,0,0])

    def test_nonunit_and_nonfinite_orientation_refused(self):
        for q in ([0,0,0,0],[1,0,0,1],[0,0,0,float("nan")]):
            with self.assertRaises(ValueError):d.orientation_vector(q)

    def rows(self):
        return [dict(command=i,prepared_time_s=i/120.,reach_tracking=dict(
            root_height_m=.4,com_height_m=.35,target_com_height_m=.34,com_height_error_m=.01,
            orientation_vector_rad=[0.,0.,0.],candidate_reference=None,
            feet=[dict(contact_site_id=site,minimum_clearance_m=.02,
                change_from_handoff=dict(remaining_joint_extension_clearance_m=.003))
                for site in ("front_left_foot","front_right_foot","rear_left_foot","rear_right_foot")]))
            for i in range(60,63)]

    def test_summary_keeps_exact_denominators_units_and_endpoints(self):
        value=d.tracking_summary(self.rows(),60,63)
        self.assertEqual(value["commands"],3)
        self.assertEqual([x["command"] for x in value["endpoints"]],[60,62])
        self.assertEqual(value["feet"]["front_right_foot"]["positive_minimum_clearance_commands"],3)
        self.assertAlmostEqual(value["com_height_error_m"]["mean"][0],.01)
        self.assertIsNone(value["candidate_reference"])
        rows=self.rows()
        for row in rows:
            row["reach_tracking"]["candidate_reference"]=dict(floor_reached=True,
                remaining_fixed_pose_gap_m=.02,requested_fixed_pose_lowering_m=.04)
        self.assertEqual(d.tracking_summary(rows,60,63)["candidate_reference"]["floor_reached_commands"],3)

    def test_missing_reordered_crossed_role_or_foot_population_refused(self):
        rows=self.rows()
        for invalid in (rows[:-1],list(reversed(rows)),[rows[0],rows[0],rows[2]]):
            with self.assertRaises(ValueError):d.tracking_summary(invalid,60,63)
        changed=copy.deepcopy(rows);changed[0]["reach_tracking"]["candidate_reference"]={}
        with self.assertRaises(ValueError):d.tracking_summary(changed,60,63)
        changed=copy.deepcopy(rows);changed[0]["reach_tracking"]["feet"].reverse()
        with self.assertRaises(ValueError):d.tracking_summary(changed,60,63)
        with self.assertRaises(ValueError):d.tracking_summary(rows,59,63)


if __name__=="__main__":unittest.main()
