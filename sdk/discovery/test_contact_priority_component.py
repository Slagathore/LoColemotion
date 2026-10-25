"""Independent finite-hold and refusal controls for contact-priority feasibility."""
import copy,unittest
import numpy as np
import actuation_recovery_mechanics as m
import contact_priority_component as c
import dynamic_inverse_dynamics_v2 as old
from floating_base_dynamics import FloatingDynamics
from test_actuation_recovery_mechanics import specimen

class PriorityControls(unittest.TestCase):
    def setUp(self):
        self.model=FloatingDynamics(specimen(),[.01,.02]);self.n=self.model.size
        self.frame=self.model.tree.kinematics([0.,1.,0.],[0.,0.,0.,1.],[0.,0.])
        self.v=np.zeros(self.n);self.q=np.zeros(2);self.ranges=np.array([[-2.,2.],[-2.,2.]])
        self.env=m.command_envelope([0.,0.],[3.5,3.5],[0.,0.],[3.5,3.5],[.08,.08])
        self.gains=np.array([5.,8.]);self.caps=np.array([[-10.,10.],[-10.,10.]])
        self.item=dict(name="posture",jacobian=np.eye(self.n),bias=np.zeros(self.n),target=np.zeros(self.n),weight=1.)
    def build(self,mode="motor",items=None,active=None,**kw):
        values=dict(model=self.model,frame=self.frame,velocity=self.v,gravity=[0.,-9.8,0.],joints=self.q,
            joint_ranges=self.ranges,items=[self.item] if items is None else items,active=[] if active is None else active,
            envelope=self.env,gains=self.gains,force_ranges=self.caps,mode=mode)
        values.update(kw);return c.build(**values)
    def contact(self):
        point=self.frame["positions"][0];body=self.model.tree.body_ids[0]
        jac=self.model.jacobians(self.frame,body,point)[0]
        return dict(name="support_foot",jacobian=jac,bias=np.zeros(3),target=np.zeros(3),weight=10.),dict(
            contact_site_id="foot",body_id=body,point=point,jacobian=jac)
    def test_01_undamped_hold_is_semi_implicit_not_half_t_squared(self):
        h=.01;_,rows=c.held_maps(np.eye(8),np.zeros(8),h,5)
        for i,r in enumerate(rows,1):
            np.testing.assert_allclose(r["acceleration"],np.eye(8))
            np.testing.assert_allclose(r["velocity_after"],i*h*np.eye(8))
            np.testing.assert_allclose(r["position"],h*h*i*(i+1)/2*np.eye(8))
    def test_02_coupled_implicit_recurrence_matches_direct_motor_updates(self):
        mass=np.eye(8);mass[0,6]=mass[6,0]=.2;d=np.r_[np.zeros(6),5.,8.]
        effective,rows=c.held_maps(mass,d,.01,5);rhs=np.arange(8)/10.;a=np.linalg.solve(effective,rhs)
        v=np.zeros(8);q=np.zeros(8)
        for r in rows:
            actual=np.linalg.solve(effective,rhs-d*v);v+=.01*actual;q+=.01*v
            np.testing.assert_allclose(r["acceleration"] @ a,actual,atol=1e-14)
            np.testing.assert_allclose(r["velocity_after"] @ a,v,atol=1e-14)
            np.testing.assert_allclose(r["position"] @ a,q,atol=1e-14)
    def test_03_saturation_regimes_use_entire_command_interval(self):
        e=dict(lower_target=np.array([1.,-2.,-.5]),upper_target=np.array([2.,-1.,2.]))
        r,d,s=c.motor_regimes(e,np.zeros(3),[1.,1.,1.],[[-1.,1.]]*3)
        np.testing.assert_equal(r,[1,-1,0]);np.testing.assert_equal(d,[0.,0.,1.]);np.testing.assert_equal(s,[1.,-1.,0.])
    def test_04_exact_cap_boundary_uses_saturated_derivative(self):
        e=dict(lower_target=np.array([1.,-1.]),upper_target=np.array([1.,-1.]))
        r,d,_=c.motor_regimes(e,[0.,0.],[1.,1.],[[-1.,1.]]*2)
        np.testing.assert_equal(r,[1,-1]);np.testing.assert_equal(d,[0.,0.])
    def test_05_invalid_inertia_refused(self):
        with self.assertRaises(ValueError):c.held_maps(np.eye(8)+np.triu(np.ones((8,8)),1),np.zeros(8),.01,5)
    def test_06_invalid_timestep_refused(self):
        with self.assertRaises(ValueError):c.held_maps(np.eye(8),np.zeros(8),0.,5)
    def test_07_unordered_target_interval_refused(self):
        with self.assertRaises(ValueError):c.motor_regimes(dict(lower_target=[2.],upper_target=[1.]),[0.],[1.],[[-1.,1.]])
    def test_08_undeclared_constraint_mode_refused(self):
        with self.assertRaises(ValueError):self.build("tuned")
    def test_09_active_native_joint_limit_never_ignored(self):
        qp=self.build(joints=[2.001,0.]);r=c.compute(qp)
        self.assertFalse(r["accepted"]);self.assertIsNone(r["solver"]);self.assertIsNone(r["prediction"])
    def test_10_support_population_mismatch_refused(self):
        support,_=self.contact()
        with self.assertRaises(ValueError):self.build(items=[support])
    def test_11_contact_target_is_hard_in_both_contact_modes(self):
        support,active=self.contact()
        for mode in ("contact","combined"):
            qp=self.build(mode,items=[self.item,support],active=[active]);indices=[i for i,n in enumerate(qp["row_names"]) if n=="support_foot"]
            np.testing.assert_equal(qp["A"][indices,:self.n],support["jacobian"])
            np.testing.assert_equal(qp["lower"][indices],qp["upper"][indices]);self.assertEqual(len(indices),3)
    def test_12_all_five_predicted_joint_states_are_bounded(self):
        qp=self.build("joint")
        for i in range(5):
            self.assertEqual(qp["row_names"].count("joint_position_"+str(i)),2)
            self.assertEqual(qp["row_names"].count("joint_velocity_"+str(i)),2)
    def test_13_public_command_bounds_are_unchanged(self):
        qp=self.build();indices=[i for i,n in enumerate(qp["row_names"]) if n=="command"]
        np.testing.assert_equal(qp["lower"][indices],self.env["lower_target"])
        np.testing.assert_equal(qp["upper"][indices],self.env["upper_target"])
    def test_14_free_fall_and_held_motor_reconstruction(self):
        r=c.compute(self.build());self.assertTrue(r["accepted"])
        self.assertLess(r["prediction"]["maximum_recurrence_error"],1e-7)
        self.assertEqual(len(r["prediction"]["predicted_steps"]),5)
        com_jac=sum(self.model.tree.mass[i]*self.model.jacobians(self.frame,body,self.frame["centers"][i])[0]
            for i,body in enumerate(self.model.tree.body_ids))/sum(self.model.tree.mass)
        for row in r["prediction"]["predicted_steps"]:
            np.testing.assert_allclose(com_jac @ row["acceleration"],[0.,-9.8,0.],atol=1e-7)
    def test_15_corrupt_solution_rejected_independently(self):
        qp=self.build();r=c.compute(qp)["solver"];r["x"][0]+=.01
        with self.assertRaises(ValueError):c.verify(qp,r)
    def test_16_refused_solution_has_no_prediction(self):
        support,active=self.contact()
        support["target"][1]=1000.
        r=c.compute(self.build("contact",items=[support],active=[active]))
        self.assertFalse(r["accepted"]);self.assertIsNone(r["prediction"])
    def test_17_force_bounds_unchanged(self):
        support,active=self.contact();qp=self.build("contact",items=[support],active=[active])
        indices=[i for i,n in enumerate(qp["row_names"]) if n=="friction"]
        self.assertEqual(qp["upper"][indices[0]],70.);self.assertEqual(qp["lower"][indices[0]],0.)
        self.assertEqual(len(indices),5)
    def test_18_joint_position_buffer_is_explicit(self):
        qp=self.build("joint");indices=[i for i,n in enumerate(qp["row_names"]) if n=="joint_position_0"]
        np.testing.assert_allclose(qp["upper"][indices],self.ranges[:,1]-3.5/600.)
    def test_19_support_goal_cannot_be_traded_for_posture(self):
        support,active=self.contact();goal=copy.deepcopy(self.item);goal["target"][1]=100.
        r=c.compute(self.build("contact",items=[goal,support],active=[active]))
        self.assertTrue(r["accepted"]);np.testing.assert_allclose(r["prediction"]["support_errors"]["support_foot"],0.,atol=2e-6)
    def test_20_prediction_denies_physical_and_contact_persistence_authority(self):
        r=c.compute(self.build());self.assertTrue(r["prediction"]["model_only"])
        self.assertFalse(r["prediction"]["physical_acceptance_authority"])
        self.assertFalse(r["prediction"]["contact_persistence_established"])

if __name__=="__main__":unittest.main()
