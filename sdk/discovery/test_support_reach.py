"""Analytical, randomized, malformed-input and reference-bound controls; no worlds."""
import copy,math,unittest
from unittest.mock import patch
import numpy as np
import support_reach_geometry as g
import audit_support_reach_component as task
from support_reach_force_policy import Policy,make_profile


class ReachControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parent=task.read(task.parent.CLOSURE)
        cls.folder=task.ROOT.parent/"SporeSpore_Evidence"/cls.parent["attempt_id"]/"physical"/task.TRIALS[0]
        cls.compiled=task.read(cls.folder/"compiled.json")
        cls.spec=cls.compiled["morphology"]["morphology_spec"]
        cls.inputs=task.read(cls.folder/"inputs.json")
        cls.bounds=[[-.72,.72],[-.15,1.1]]

    def solve(self,a=0.,b=1.,bounds=None):
        return g.capsule_minimum(.44,a,b,[.18,.17],.04,bounds or self.bounds)

    def reference(self,gap=.04,supported=False,previous=.4):
        reaches=[dict(contact_site_id=x+"_foot",minimum_clearance_m=gap,
            minimizing_joint_positions_rad=[-.2,0.]) for x in g.LIMBS]
        support={r["contact_site_id"]:supported for r in reaches}
        return g.support_reference(reaches,support,.44,.4,.4,previous,g.reference_parameters())

    def test_upright_unconstrained_minimum_and_witness(self):
        r=self.solve();self.assertAlmostEqual(r["minimum_clearance_m"],.05)
        np.testing.assert_allclose(r["minimizing_joint_positions_rad"],[0.,0.],atol=1e-14)
        self.assertFalse(r["dynamic_feasibility_established"])

    def test_pitch_alignment_attains_universal_bound(self):
        r=self.solve(math.sin(.3),math.cos(.3))
        self.assertAlmostEqual(r["minimum_clearance_m"],.05)
        np.testing.assert_allclose(r["minimizing_joint_positions_rad"],[-.3,0.],atol=1e-14)

    def test_joint_bounds_prevent_unconstrained_minimum(self):
        r=self.solve(bounds=[[.4,.7],[.2,.5]])
        self.assertGreater(r["minimum_clearance_m"],r["unconstrained_clearance_lower_bound_m"])
        np.testing.assert_allclose(r["minimizing_joint_positions_rad"],[.4,.2],atol=1e-14)

    def test_inverted_leg_uses_proximal_capsule_endpoint(self):
        r=self.solve(0.,-1.,[[-.01,.01],[-.01,.01]])
        self.assertEqual(r["lowest_capsule_endpoint"],"knee")
        self.assertAlmostEqual(r["minimum_clearance_m"],.44+.18*math.cos(.01)-.04)

    def test_vertical_projection_zero_has_constant_height(self):
        r=self.solve(0.,0.)
        self.assertAlmostEqual(r["minimum_clearance_m"],.4)
        self.assertAlmostEqual(r["unconstrained_clearance_lower_bound_m"],.4)

    def test_random_bounded_minima_dominate_independent_dense_grid(self):
        rng=np.random.default_rng(104242001)
        for _ in range(64):
            angle=float(rng.uniform(-math.pi,math.pi));scale=float(rng.uniform(.1,1))
            a,b=scale*math.sin(angle),scale*math.cos(angle)
            low=rng.uniform(-2.,.2,2);high=low+rng.uniform(.1,1.6,2);bounds=np.c_[low,high].tolist()
            r=self.solve(a,b,bounds)
            h=np.linspace(*bounds[0],81)[:,None];k=np.linspace(*bounds[1],81)[None,:]
            knee=.44+.18*(a*np.sin(h)-b*np.cos(h))
            distal=knee+.17*(a*np.sin(h+k)-b*np.cos(h+k))
            sampled=float(np.minimum(knee,distal).min()-.04)
            self.assertLessEqual(r["minimum_clearance_m"],sampled+1e-12)
            qh,qk=r["minimizing_joint_positions_rad"]
            knee=.44+.18*(a*math.sin(qh)-b*math.cos(qh))
            attained=min(knee,knee+.17*(a*math.sin(qh+qk)-b*math.cos(qh+qk)))-.04
            self.assertAlmostEqual(r["minimum_clearance_m"],attained,places=12)

    def test_kinematic_witnesses_and_vertical_translation(self):
        model=g.ReachModel(self.spec);q=[0.]*8
        first=model.evaluate([0.,.44,0.],[0.,0.,0.,1.],q)
        shifted=model.evaluate([1.,.54,2.],[0.,0.,0.,1.],q)
        for a,b in zip(first,shifted,strict=True):
            self.assertAlmostEqual(b["minimum_clearance_m"]-a["minimum_clearance_m"],.1)
            self.assertAlmostEqual(b["current_clearance_m"]-a["current_clearance_m"],.1)

    def test_nonfinite_or_invalid_geometry_is_refused(self):
        for args in ((.44,0.,1.,[.18,.17],-.04,self.bounds),(.44,2.,0.,[.18,.17],.04,self.bounds),
            (.44,0.,1.,[.18,float("nan")],.04,self.bounds),(.44,0.,1.,[.18,.17],.04,[[0.,0.],[-.1,1.]])):
            with self.assertRaises(ValueError):g.capsule_minimum(*args)

    def test_crossed_joint_axis_is_refused(self):
        spec=copy.deepcopy(self.spec);spec["joints"][0]["axis_parent_unit"]={"x":1.,"y":0.,"z":0.}
        with self.assertRaises(ValueError):g.ReachModel(spec)

    def test_crossed_anchor_or_contact_geometry_is_refused(self):
        spec=copy.deepcopy(self.spec);spec["joints"][0]["anchor_child_m"]["y"]+=.001
        with self.assertRaises(ValueError):g.ReachModel(spec)
        spec=copy.deepcopy(self.spec);spec["contact_sites"][0]["radius_m"]+=.001
        with self.assertRaises(ValueError):g.ReachModel(spec)

    def test_reference_rate_and_absolute_lowering_bound(self):
        previous=.4
        for _ in range(1000):
            r=self.reference(gap=.3,previous=previous);following=r["target_com_height_m"]
            self.assertLessEqual(following,previous+1e-12);self.assertGreaterEqual(following,.3-1e-12)
            self.assertLessEqual(previous-following,.2/120.+1e-12);previous=following
        self.assertAlmostEqual(previous,.3)
        self.assertFalse(r["realized_body_height_bounded"])

    def test_reference_does_not_raise_after_contact(self):
        r=self.reference(supported=True,previous=.35)
        self.assertEqual(r["target_com_height_m"],.35)
        self.assertEqual(r["reference_joint_positions_rad"],[0.]*8)

    def test_only_airborne_posture_references_change(self):
        reaches=[dict(contact_site_id=x+"_foot",minimum_clearance_m=.1,minimizing_joint_positions_rad=[-.2,.1]) for x in g.LIMBS]
        support={x+"_foot":x!="front_right" for x in g.LIMBS}
        r=g.support_reference(reaches,support,.44,.4,.4,.4,g.reference_parameters())
        self.assertEqual(r["reference_joint_positions_rad"],[0.,0.,-.2,.1,0.,0.,0.,0.])

    def test_unresolved_gap_is_not_erased_by_reference_floor(self):
        r=self.reference(gap=.3,previous=.3)
        self.assertAlmostEqual(r["remaining_fixed_pose_gap_m"],.2)
        self.assertFalse(r["dynamic_feasibility_established"])
        self.assertFalse(r["collision_free_path_established"])

    def test_invalid_memory_or_reference_input_is_refused(self):
        with self.assertRaises(ValueError):self.reference(previous=.2)
        with self.assertRaises(ValueError):self.reference(gap=float("nan"))
        with self.assertRaises(ValueError):self.reference(supported=1)

    def test_profile_parameter_or_capability_drift_is_refused(self):
        original=make_profile(self.compiled,self.inputs)
        for path in ("reference_parameters","parameters"):
            p=copy.deepcopy(original);p[path][next(iter(p[path]))]=999.
            with self.assertRaises(ValueError):Policy(None,p)
        p=copy.deepcopy(original);p["trained"]=True
        with self.assertRaises(ValueError):Policy(None,p)

    def test_profile_source_binding_drift_is_refused(self):
        p=make_profile(self.compiled,self.inputs);p["source_bindings"]["support_reach_geometry.py"]="0"*64
        with self.assertRaises(ValueError):Policy(None,p)

    def test_contract_scope_and_authority_drift_is_refused(self):
        c=task.declaration()
        for key in task.DENIALS:
            changed=copy.deepcopy(c);changed[key]=True
            with patch.object(task,"read",return_value=changed):
                with self.assertRaises(ValueError):task.declaration()


if __name__=="__main__":unittest.main()
