"""Analytical, optimization and refusal controls; no simulator construction."""
import unittest
import numpy as np
from causal_force_allocator import project_force,allocate,cross_matrix


class AllocatorControls(unittest.TestCase):
    def close(self,a,b):np.testing.assert_allclose(a,b,atol=1e-10,rtol=1e-10)

    def allocation(self,points,desired,**overrides):
        n=len(points)
        inputs=dict(points=np.array(points).reshape(n,3),normals=[[0.,1.,0.]]*n,
            origin=[0.,0.,0.],desired=desired,torque_map=np.zeros((1,3*n)),torque_bias=[0.],
            lower=[-100.],upper=[100.],previous=np.zeros((n,3)),weights=[1.]*6,
            friction=1.,cap=100.,regularization=.001,actuation_weight=1.,iterations=300)
        inputs.update(overrides)
        return allocate(**inputs)

    def test_projection_interior_unchanged(self):self.close(project_force([.2,2.,.3],[0.,1.,0.],.5,3.),[.2,2.,.3])
    def test_projection_polar_cone_is_zero(self):self.close(project_force([1.,-3.,0.],[0.,1.,0.],.5,3.),[0.,0.,0.])
    def test_projection_analytic_cone_boundary(self):self.close(project_force([3.,1.,0.],[0.,1.,0.],1.,10.),[2.,2.,0.])
    def test_projection_cap_and_tangent(self):self.close(project_force([8.,4.,0.],[0.,1.,0.],.5,2.),[1.,2.,0.])
    def test_zero_friction_and_zero_cap(self):
        self.close(project_force([3.,2.,4.],[0.,1.,0.],0.,5.),[0.,2.,0.])
        self.close(project_force([3.,2.,4.],[0.,1.,0.],1.,0.),[0.,0.,0.])
    def test_rotated_cone_projection(self):self.close(project_force([1.,3.,0.],[1.,0.,0.],1.,10.),[2.,2.,0.])
    def test_projection_variational_inequality(self):
        rng=np.random.default_rng(971)
        for _ in range(100):
            x=rng.normal(size=3)*4;mu=.7;cap=2.
            p=project_force(x,[0.,1.,0.],mu,cap)
            for _ in range(10):
                h=rng.uniform(0,cap);angle=rng.uniform(-np.pi,np.pi);radius=rng.uniform(0,mu*h)
                feasible=np.array([radius*np.cos(angle),h,radius*np.sin(angle)])
                self.assertLessEqual(float((x-p) @ (feasible-p)),1e-12)
    def test_projection_bad_numeric_types_and_normal(self):
        for f,n,mu,cap in (([True,0,0],[0,1,0],1,2),([0,0,0],[0,2,0],1,2),
            ([0,0,0],[0,1,0],-1,2),([0,np.nan,0],[0,1,0],1,2),([0,0,0],[0,1,0],1,-2)):
            with self.assertRaises(ValueError):project_force(f,n,mu,cap)
    def test_cross_product_orientation(self):self.close(cross_matrix([1,2,3]) @ [4,5,6],np.cross([1,2,3],[4,5,6]))
    def test_single_contact_closed_form(self):
        r=self.allocation([[0,0,0]],[0,10,0,0,0,0])
        self.close(r["forces"],[[0,10/1.001,0]])
        self.assertEqual(r["wrench_map_rank"],3)
    def test_two_contacts_keep_rank_deficiency_residual(self):
        r=self.allocation([[-1,0,0],[1,0,0]],[0,10,0,4,0,0])
        self.assertEqual(r["wrench_map_rank"],5)
        self.assertAlmostEqual(r["wrench_error"][3],-4.)
        self.assertFalse(r["dynamic_feasibility_established"])
    def test_four_contact_symmetric_weight_distribution(self):
        r=self.allocation([[-1,0,-1],[-1,0,1],[1,0,-1],[1,0,1]],[0,40,0,0,0,0])
        self.close(r["forces"][:,1],[40/4.001]*4)
        self.close(r["forces"][:,[0,2]],np.zeros((4,2)))
    def test_actuator_interval_penalty_changes_solution(self):
        r=self.allocation([[0,0,0]],[0,10,0,0,0,0],torque_map=[[0.,1.,0.]],lower=[-1.],upper=[1.],actuation_weight=100.)
        self.close(r["forces"][0,1],110/101.001)
        self.assertGreater(r["torque_interval_violation"][0],0.)
    def test_force_cap_infeasibility_remains_visible(self):
        r=self.allocation([[0,0,0]],[0,10,0,0,0,0],cap=2.)
        self.close(r["forces"],[[0,2,0]]);self.close(r["wrench_error"],[0,-8,0,0,0,0])
    def test_no_contact_retains_unsatisfied_wrench_and_torque(self):
        r=self.allocation([], [0,10,0,0,0,0],normals=np.empty((0,3)),torque_bias=[2.],lower=[-1.],upper=[1.])
        self.assertEqual(r["iterations"],0);self.close(r["wrench_error"],[0,-10,0,0,0,0])
        self.close(r["torque_interval_violation"],[1.])
    def test_optimizer_rejects_invalid_interval_or_budget(self):
        for kwargs in (dict(lower=[2.],upper=[1.]),dict(iterations=True),dict(iterations=0),dict(regularization=0.)):
            with self.assertRaises(ValueError):self.allocation([[0,0,0]],[0]*6,**kwargs)
    def test_input_arrays_remain_unchanged(self):
        p=np.array([[0.,0.,0.]]);original=p.copy()
        self.allocation(p,[0,10,0,0,0,0]);self.close(p,original)


if __name__=="__main__":unittest.main()
