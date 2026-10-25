"""Analytic and independent identities for unactuated floating-base dynamics."""
import copy,math,unittest
import numpy as np
from floating_base_dynamics import FloatingDynamics,skew
from floating_base_dynamics_checks import verify_state
from actuation_recovery_mechanics import rotation
from contact_posture_reference import quaternion_product
from test_actuation_recovery_mechanics import specimen,vector


def free_spec(offset=(0.,0.,0.)):
    return dict(schema_version="sporespore_morphology_spec_v1",
        coordinate_frame_id="right_handed_x_forward_y_up_z_right_si_v1",
        bodies=[dict(body_id="root",parent_body_id=None,mass_kg=3.,
            center_of_mass_local_m=vector(*offset),inertia_diagonal_kg_m2=vector(2.,3.,4.))],joints=[])


class DynamicsControls(unittest.TestCase):
    def close(self,a,b,tol=1e-9):np.testing.assert_allclose(a,b,atol=tol,rtol=tol)
    def setUp(self):
        self.m=FloatingDynamics(specimen(),[.01,.02])
        self.p=np.array([.3,.4,-.2]);self.q=np.array([.2,-.1,.15,math.sqrt(.9275)])
        self.j=np.array([.31,-.47]);self.v=np.linspace(-.35,.42,8);self.a=np.linspace(.2,-.13,8);self.g=[0.,-9.8,0.]
        self.f=self.m.tree.kinematics(self.p,self.q,self.j)
    def evaluate(self,m=None,p=None,q=None,j=None,v=None,a=None,g=None,w=()):
        return (m or self.m).evaluate(self.p if p is None else p,self.q if q is None else q,
            self.j if j is None else j,self.v if v is None else v,self.a if a is None else a,self.g if g is None else g,w)
    def test_01_free_body_inertia(self):
        m=FloatingDynamics(free_spec(),[]);f=m.tree.kinematics([0,0,0],[0,0,0,1],[])
        self.close(m.mass_matrix(f),np.diag([3,3,3,2,3,4]))
    def test_02_offset_center_parallel_axis(self):
        r=np.array([.5,.2,-.1]);m=FloatingDynamics(free_spec(r),[]);f=m.tree.kinematics([0,0,0],[0,0,0,1],[])
        expected=np.block([[3*np.eye(3),-3*skew(r)],[3*skew(r),np.diag([2,3,4])-3*skew(r) @ skew(r)]])
        self.close(m.mass_matrix(f),expected)
    def test_03_asymmetric_body_gyroscopic_moment(self):
        m=FloatingDynamics(free_spec(),[]);f=m.tree.kinematics([0,0,0],[0,0,0,1],[])
        self.close(m.inverse_dynamics(f,[0,0,0,1,2,3],[0]*6,[0,0,0]),[0,0,0,6,-6,2])
    def test_04_constant_translation_has_no_bias(self):
        m=FloatingDynamics(free_spec((.5,.2,-.1)),[]);f=m.tree.kinematics([0,0,0],[0,0,0,1],[])
        self.close(m.inverse_dynamics(f,[2,-3,4,0,0,0],[0]*6,[0,0,0]),[0]*6)
    def test_05_freefall_requires_no_input(self):
        self.close(self.m.inverse_dynamics(self.f,[0]*8,[*self.g,0,0,0,0,0],self.g),[0]*8)
    def test_06_planar_two_link_joint_inertia(self):
        f=self.m.tree.kinematics([0,0,0],[0,0,0,1],[.31,-.47]);c=math.cos(-.47)
        self.close(self.m.mass_matrix(f)[6:,6:],[[6.25+3*c+.01,1.75+1.5*c],[1.75+1.5*c,1.75+.02]])
    def test_07_planar_two_link_velocity_bias(self):
        f=self.m.tree.kinematics([0,0,0],[0,0,0,1],[.31,-.47]);u,w=.7,-.4;k=1.5*math.sin(-.47)
        self.close(self.m.inverse_dynamics(f,[0]*6+[u,w],[0]*8,[0,0,0])[6:],[-k*(2*u*w+w*w),k*u*u])
    def test_08_planar_two_link_gravity(self):
        f=self.m.tree.kinematics([0,0,0],[0,0,0,1],[.31,-.47])
        self.close(self.m.inverse_dynamics(f,[0]*8,[0]*8,[0,-10,0])[6:],
            [40*math.cos(.31)+15*math.cos(.31-.47),15*math.cos(.31-.47)])
    def test_09_joint_inertia_is_explicit_and_diagonal(self):
        other=FloatingDynamics(specimen(),[.11,.22]);difference=np.diag([0]*6+[.1,.2])
        self.close(other.mass_matrix(self.f)-self.m.mass_matrix(self.f),difference)
        self.close(other.inverse_dynamics(self.f,self.v,self.a,self.g)-self.m.inverse_dynamics(self.f,self.v,self.a,self.g),difference @ self.a)
        self.assertAlmostEqual(other.kinetic_energy(self.f,self.v)-self.m.kinetic_energy(self.f,self.v),.5*self.v @ difference @ self.v)
    def test_10_recursive_acceleration_matches_mass_columns(self):
        for angle in (-.8,0.,.7):
            f=self.m.tree.kinematics(self.p,self.q,[angle,.4])
            for i in range(8):
                self.close(self.m.inverse_dynamics(f,[0]*8,np.eye(8)[i],[0,0,0]),self.m.mass_matrix(f)[:,i])
    def test_11_energy_kinematic_gravity_identities(self):
        r=verify_state(self.m,self.p,self.q,self.j,self.v,self.a,self.g,[])
        self.assertLess(r["maximum_errors"]["kinetic_power_w"],2e-7)
        self.assertLess(r["maximum_errors"]["potential_gradient"],2e-7)
    def test_12_external_virtual_work_and_joint_restriction(self):
        w=[dict(body_id="distal",point=[.4,.5,-.2],force=[2,-3,4],torque=[.1,.2,.3]),
           dict(body_id="root",point=[1,2,3],force=[-1,2,0],torque=[.3,0,.1])]
        r=verify_state(self.m,self.p,self.q,self.j,self.v,self.a,self.g,w)
        self.assertLess(r["maximum_errors"]["external_virtual_power_w"],1e-10)
    def test_13_passive_damping_only_dissipates_joint_power(self):
        s=specimen();s["joints"][0]["passive_damping_nms_per_rad"]=.6
        m=FloatingDynamics(s,[.01,.02]);expected=np.zeros(8);expected[6]=-.6*self.v[6]
        self.close(m.passive_force(self.v),expected);self.assertLess(self.v @ expected,0.)
    def test_14_translation_invariance(self):
        x=self.evaluate();y=self.evaluate(p=self.p+[10,-4,2])
        for key in ("mass_matrix","bias","inverse_dynamics"):self.close(x[key],y[key])
    def test_15_world_rotation_covariance(self):
        r=rotation([0,0,1],.7);t=np.eye(8);t[:3,:3]=t[3:6,3:6]=r
        q=quaternion_product([0,0,math.sin(.35),math.cos(.35)],self.q)
        x=self.evaluate();y=self.evaluate(p=r @ self.p,q=q,v=t @ self.v,a=t @ self.a,g=r @ self.g)
        self.close(y["mass_matrix"],t @ x["mass_matrix"] @ t.T)
        self.close(y["bias"],t @ x["bias"]);self.close(y["inverse_dynamics"],t @ x["inverse_dynamics"])
    def test_16_nonzero_child_anchor(self):
        s=specimen();s["joints"][0]["anchor_child_m"]=vector(.2,.3,-.1)
        r=verify_state(FloatingDynamics(s,[.01,.02]),self.p,self.q,self.j,self.v,self.a,self.g,[])
        self.assertLess(r["maximum_errors"]["com_bias_acceleration_m_s2"],2e-7)
    def test_17_branched_tree(self):
        s=specimen();s["bodies"][2]["parent_body_id"]="root";s["joints"][1]["parent_body_id"]="root"
        r=verify_state(FloatingDynamics(s,[.01,.02]),self.p,self.q,self.j,self.v,self.a,self.g,[])
        self.assertLess(r["maximum_errors"]["angular_bias_acceleration_rad_s2"],2e-7)
    def test_18_invalid_joint_inertia_refused(self):
        for x in ([],[.01],[.01,-.02],[.01,float("nan")],[True,False]):
            with self.subTest(x=x),self.assertRaises(ValueError):FloatingDynamics(specimen(),x)
        with self.assertRaises(TypeError):FloatingDynamics(specimen())
    def test_19_invalid_state_refused(self):
        for change in (dict(v=[0]*7),dict(v=[float("nan")]*8),dict(a=[True]*8),dict(q=[0,0,0,0]),dict(g=[0,float("inf"),0])):
            with self.subTest(change=change),self.assertRaises(ValueError):self.evaluate(**change)
    def test_20_invalid_wrench_refused(self):
        for w in (dict(body_id="missing",point=[0]*3,force=[0]*3,torque=[0]*3),
                  dict(body_id="root",point=[0]*3,force=[float("nan")]*3,torque=[0]*3)):
            with self.subTest(w=w),self.assertRaises(ValueError):self.evaluate(w=[w])
    def test_21_supported_static_free_body_balance(self):
        m=FloatingDynamics(free_spec((.5,0,0)),[])
        r=m.evaluate([0,0,0],[0,0,0,1],[],[0]*6,[0]*6,[0,-10,0],
            [dict(body_id="root",point=[.5,0,0],force=[0,30,0],torque=[0,0,0])])
        self.close(r["required_generalized_input"],[0]*6)
    def test_22_unactuated_units_and_authority(self):
        r=self.evaluate();self.assertEqual(r["generalized_force_units"],["N"]*3+["N m"]*5)
        for k in ("base_is_actuated","controller_changed","native_dynamics_equivalence_established","dynamic_feasibility_established","held_contact_guaranteed","recovery_benefit_established"):self.assertIs(r[k],False)
        self.assertEqual(r["world_build_count"],0);self.assertEqual(r["solver_steps"],0)


if __name__=="__main__":unittest.main()
