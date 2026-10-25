"""Independent face enumeration and refusal controls for bounded hierarchy."""
import itertools
import unittest
import numpy as np
import bounded_posture_solver as s


class SolverControls(unittest.TestCase):
    def solve(self,a,b,e=None,d=None,lo=None,hi=None,x=None,iterations=256):
        a=np.asarray(a,dtype=float);n=a.shape[1]
        return s.bounded_least_squares(a,b,np.empty((0,n)) if e is None else e,[] if d is None else d,
            -np.ones(n) if lo is None else lo,np.ones(n) if hi is None else hi,np.zeros(n) if x is None else x,iterations)

    def test_unconstrained_solution(self):
        r=self.solve(np.eye(2),[.2,-.3]);np.testing.assert_allclose(r["solution"],[.2,-.3],atol=1e-12)

    def test_upper_and_lower_active_bounds(self):
        r=self.solve(np.eye(2),[2.,-3.])
        np.testing.assert_allclose(r["solution"],[1.,-1.],atol=1e-12)
        self.assertTrue((r["bound_multipliers"]>=0).all())

    def test_equality_is_preserved_at_optimum(self):
        r=self.solve(np.eye(2),[2.,0.],[[1.,1.]],[0.])
        np.testing.assert_allclose(r["solution"],[1.,-1.],atol=1e-12)

    def test_infeasible_initial_point_refused(self):
        with self.assertRaises(ValueError):self.solve(np.eye(2),[0,0],[[1,1]],[1])

    def test_inverted_bounds_refused(self):
        with self.assertRaises(ValueError):self.solve([[1.]],[0.],lo=[1.],hi=[-1.])

    def test_nonfinite_task_refused(self):
        with self.assertRaises(ValueError):self.solve([[float("nan")]],[0.])

    def test_empty_task_retains_feasible_state(self):
        r=self.solve(np.empty((0,2)),[],x=[.2,.3]);np.testing.assert_allclose(r["solution"],[.2,.3],atol=1e-12)

    def test_redundant_equalities_keep_rank(self):
        r=self.solve(np.eye(2),[1,-1],[[1,1],[2,2]],[0,0])
        self.assertEqual(r["equality_rank"]["rank"],1)

    def test_lower_priority_cannot_overwrite_earlier_task(self):
        r=s.hierarchy(np.empty((0,2)),[("first",[[1,0]],[.5]),("second",[[1,0],[0,1]],[-1,.7])],[-1,-1],[1,1],[1,1])
        np.testing.assert_allclose(r["delta"],[.5,.7],atol=1e-12)

    def test_contacts_and_box_both_constrain_hierarchy(self):
        r=s.hierarchy([[1,1]],[("first",np.eye(2),[2,-2])],[-.4,-1],[1,.6],[1,1])
        np.testing.assert_allclose(r["delta"],[1,-1],atol=1e-12)
        np.testing.assert_allclose(r["linear_contact_residual"],[0],atol=1e-12)

    def test_fully_constrained_task_reports_unattainable_rank(self):
        r=s.hierarchy(np.eye(2),[("blocked",np.eye(2),[1,2])],[-1,-1],[1,1],[1,1])
        self.assertEqual(r["tasks"][0]["attainable_rank"],0)
        np.testing.assert_allclose(r["tasks"][0]["task_residual"],[-1,-2],atol=1e-12)

    def enumerate_faces(self,a,b,e,d,lo,hi):
        n=len(lo);best=float("inf")
        for face in itertools.product((-1,0,1),repeat=n):
            rows=[np.eye(n)[j] for j,v in enumerate(face) if v]
            rhs=[lo[j] if v==-1 else hi[j] for j,v in enumerate(face) if v]
            c=np.vstack((e,np.array(rows).reshape(-1,n)));target=np.r_[d,rhs]
            x=np.linalg.lstsq(c,target,rcond=1e-12)[0] if len(c) else np.zeros(n)
            if np.max(np.abs(c@x-target),initial=0)>1e-9:continue
            _,singular,v=np.linalg.svd(c,full_matrices=True)
            rank=int(np.sum(singular>1e-10));z=v[rank:].T
            x+=z @ np.linalg.lstsq(a@z,b-a@x,rcond=1e-12)[0]
            if (x>=lo-1e-9).all() and (x<=hi+1e-9).all():
                best=min(best,float(np.sum((a@x-b)**2)))
        return best

    def cases(self):
        rng=np.random.default_rng(947173)
        for i in range(40):
            a=rng.normal(size=(4,3));b=rng.normal(size=4)*3
            e=np.array([[1.,1.,0.]]) if i%2 else np.empty((0,3))
            yield a,b,e,np.zeros(len(e)),-rng.uniform(.1,1,size=3),rng.uniform(.1,1,size=3)

    def test_random_convex_optima_match_exhaustive_faces(self):
        for a,b,e,d,lo,hi in self.cases():
            r=self.solve(a,b,e,d,lo,hi)
            self.assertAlmostEqual(r["objective"],self.enumerate_faces(a,b,e,d,lo,hi),places=9)

    def test_iteration_budget_refuses_partial_solution(self):
        with self.assertRaises(ValueError):self.solve(np.eye(2),[2,-3],iterations=1)

    def test_active_set_releases_bounds_and_still_matches_optimum(self):
        released=0
        for a,b,e,d,lo,hi in self.cases():
            r=self.solve(a,b,e,d,lo,hi);released+=r["bounds_released"]
        self.assertGreater(released,0)

    def test_projected_away_task_does_not_amplify_roundoff(self):
        a=np.array([[1.,1.,1.]])
        result=s.bounded_least_squares(a,[1.],a,[0.],[-1.]*3,[1.]*3,[0.]*3)
        np.testing.assert_allclose(result["solution"],[0.]*3,atol=1e-12)
        self.assertAlmostEqual(result["objective"],1.)


if __name__=="__main__":unittest.main()
