"""Independent switching-motor and full-coordinate elimination controls."""
import copy,unittest
from unittest.mock import patch
import numpy as np
import switching_contact_component as s
import contact_priority_component as old
from dynamic_qp_solver_v2 import solve as full_solve
import test_contact_priority_component as fixtures

class SwitchingControls(unittest.TestCase):
    def setUp(self):
        self.fixture=fixtures.PriorityControls();self.fixture.setUp()
        self.base=self.fixture.build()
        self.pattern=np.zeros((5,2),dtype=int)
    def scalar(self):
        n=7
        return dict(n=n,j=1,k=0,mass=np.eye(n),contact=np.zeros((0,n)),
            selector=np.eye(n)[:,6:],bias=np.zeros(n),passive=np.zeros(n),
            gains=np.array([600.]),force_ranges=np.array([[-1.,1.]]),
            state_velocity=np.zeros(n),state_joints=np.zeros(1))
    def test_01_constant_pattern_matches_previous_affine_recurrence(self):
        b=self.base;r=s.affine_steps(b,self.pattern);y=np.array([.02,-.03])
        a0=r[0]["acceleration_matrix"] @ y+r[0]["acceleration_offset"]
        _,old_rows=old.held_maps(b["mass"],np.r_[np.zeros(6),b["gains"]],1/600.,5)
        for new,prior in zip(r,old_rows,strict=True):
            np.testing.assert_allclose(new["acceleration_matrix"] @ y+new["acceleration_offset"],prior["acceleration"] @ a0,atol=1e-12)
    def test_02_saturated_motor_enters_unsaturated_regime_during_hold(self):
        b=self.scalar();pattern,rows=s.clipped_prediction(b,[.0048])
        np.testing.assert_equal(pattern[:,0],[1,1,0,0,0])
        velocity=2/600.
        expected=[1/600.,velocity]
        for _ in range(3):velocity=(velocity+.0048)/2;expected.append(velocity)
        np.testing.assert_allclose([r["velocity"][6] for r in rows],expected,atol=1e-15)
        np.testing.assert_allclose(rows[-1]["joint_position"],[sum(expected)/600.],atol=1e-15)
    def test_03_switching_affine_map_matches_clipped_scalar_oracle(self):
        b=self.scalar();pattern,rows=s.clipped_prediction(b,[.0048]);maps=s.affine_steps(b,pattern)
        for row,a in zip(rows,maps,strict=True):
            np.testing.assert_allclose(a["acceleration_matrix"] @ [.0048]+a["acceleration_offset"],row["acceleration"],atol=1e-13)
            np.testing.assert_allclose(a["velocity_matrix"] @ [.0048]+a["velocity_offset"],row["velocity"],atol=1e-15)
    def test_04_float_regime_codes_refused(self):
        with self.assertRaises(ValueError):s.pattern_values(np.zeros((5,2)),5,2)
    def test_05_malformed_pattern_refused(self):
        with self.assertRaises(ValueError):s.pattern_values(np.zeros((4,2),dtype=int),5,2)
    def test_06_unknown_regime_refused(self):
        a=self.pattern.copy();a[0,0]=2
        with self.assertRaises(ValueError):s.pattern_values(a,5,2)
    def test_07_elimination_satisfies_full_dynamics(self):
        qp=s.build(self.base,self.pattern);y=np.array([.01,-.02]);x=qp["transform"] @ y+qp["offset"];n=self.base["n"]
        np.testing.assert_allclose(qp["full"]["A"][:n] @ x,qp["full"]["lower"][:n],atol=1e-12)
    def test_08_reduced_objective_equals_full_up_to_constant(self):
        qp=s.build(self.base,self.pattern);f=qp["full"];r=qp["reduced"]
        off=qp["offset"];constant=.5*off @ f["P"] @ off+f["q"] @ off
        for y in (np.zeros(2),np.array([.04,-.03])):
            x=qp["transform"] @ y+off
            self.assertAlmostEqual(.5*x @ f["P"] @ x+f["q"] @ x,.5*y @ r["P"] @ y+r["q"] @ y+constant,places=10)
    def test_09_full_certificate_recovers_equality_multipliers(self):
        qp=s.build(self.base,self.pattern);r=s.solve_pattern(qp)
        self.assertTrue(r["accepted"]);self.assertTrue(r["full_certificate"]["accepted"])
        f=qp["full"];np.testing.assert_allclose(f["P"] @ r["full_x"]+f["q"]+f["A"].T @ r["full_y"],0.,atol=2e-7)
    def test_10_reduced_and_full_optimizers_agree(self):
        qp=s.build(self.base,self.pattern);a=s.solve_pattern(qp);f=qp["full"]
        b=full_solve(f["P"],f["q"],f["A"],f["lower"],f["upper"])
        self.assertTrue(a["accepted"] and b["accepted"]);np.testing.assert_allclose(a["full_x"],b["x"],atol=2e-6,rtol=0)
    def test_11_proposal_is_never_transferable(self):
        qp=s.build(self.base,self.pattern,False);r=s.solve_pattern(qp)
        self.assertTrue(r["accepted"])
        with self.assertRaises(ValueError):s.verify(qp,r)
    def test_12_force_cap_infeasibility_yields_no_command(self):
        support,active=self.fixture.contact();support["target"][1]=1000.
        b=self.fixture.build("contact",items=[support],active=[active]);r=s.compute(b)
        self.assertFalse(r["accepted"]);self.assertIsNone(r["prediction"]);self.assertIsNone(r["selected"])
    def test_13_full_primal_corruption_refused(self):
        qp=s.build(self.base,self.pattern);r=s.solve_pattern(qp);r["full_x"][0]+=.001
        with self.assertRaises(ValueError):s.verify(qp,r)
    def test_14_full_dual_corruption_refused(self):
        qp=s.build(self.base,self.pattern);r=s.solve_pattern(qp);r["full_y"][0]+=.001
        with self.assertRaises(ValueError):s.verify(qp,r)
    def test_15_all_five_joint_states_remain_constrained(self):
        b=self.fixture.build("joint");qp=s.build(b,self.pattern)
        for i in range(5):
            self.assertEqual(qp["full"]["row_names"].count("joint_position_"+str(i)),2)
            self.assertEqual(qp["full"]["row_names"].count("joint_velocity_"+str(i)),2)
    def test_16_command_bounds_survive_reduction(self):
        qp=s.build(self.base,self.pattern);r=s.solve_pattern(qp);v=s.verify(qp,r)
        self.assertTrue(np.all(v["target"]>=self.base["envelope"]["lower_target"]-2e-6))
        self.assertTrue(np.all(v["target"]<=self.base["envelope"]["upper_target"]+2e-6))
    def test_17_strict_support_not_traded_for_posture(self):
        support,active=self.fixture.contact();task=copy.deepcopy(self.fixture.item);task["target"][1]=100.
        b=self.fixture.build("combined",items=[task,support],active=[active]);r=s.compute(b)
        self.assertTrue(r["accepted"]);np.testing.assert_allclose(r["prediction"]["support_errors"]["support_foot"],0.,atol=2e-6)
    def test_18_pattern_search_has_finite_declared_bound(self):
        patterns=[]
        for i in range(9):
            a=self.pattern.copy();a[0]=[i%3-1,i//3-1];patterns.append((str(i),a))
        with patch.object(s,"initial_patterns",return_value=patterns),patch.object(s,"solve_pattern",return_value=dict(accepted=False)):
            r=s.compute(self.base)
        self.assertFalse(r["accepted"]);self.assertEqual(r["patterns_tried"],8);self.assertEqual(len(r["attempts"]),16)
    def test_19_active_native_joint_limit_refuses_before_search(self):
        b=self.fixture.build(joints=[2.001,0.]);r=s.compute(b)
        self.assertFalse(r["accepted"]);self.assertEqual(r["attempts"],[]);self.assertIsNone(r["prediction"])
    def test_20_model_predictions_have_no_physical_authority(self):
        r=s.compute(self.base);self.assertTrue(r["accepted"])
        self.assertTrue(r["prediction"]["model_only"]);self.assertFalse(r["prediction"]["physical_acceptance_authority"])
        self.assertFalse(r["prediction"]["contact_persistence_established"])
        self.assertFalse(s.parameters()["global_optimality_established"])

if __name__=="__main__":unittest.main()
