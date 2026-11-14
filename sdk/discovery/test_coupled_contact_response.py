"""Analytical, finite-difference and refusal controls; no native worlds."""
import itertools
import math
import unittest

import numpy as np

from test_actuation_recovery_mechanics import specimen
import coupled_contact_response as c


def rigid_body():
    s=specimen();s['bodies']=s['bodies'][:1];s['joints']=[];s['bodies'][0]['mass_kg']=2.
    return c.CoupledBody(s)


class CoupledResponseControls(unittest.TestCase):
    def close(self,left,right,tol=1e-9):np.testing.assert_allclose(left,right,rtol=tol,atol=tol)

    def test_floating_mass_matches_independent_body_kinetic_energy(self):
        model=c.CoupledBody(specimen());v=np.array([.3,-.7,.2,.4,-.2,.5,.8,-.3])
        p=model.prepare([.4,-.2,.8],[.5,.5,.5,.5],[.3,-.6],v)
        energy=0.
        for i,(linear,angular) in enumerate(p['body_jacobians']):
            w=p['frame']['rotations'][i].T @ (angular @ v)
            energy+=.5*model.tree.mass[i]*np.dot(linear @ v,linear @ v)+.5*np.dot(model.inertia[i]*w,w)
        self.close(.5*v @ p['mass'] @ v,energy)
        self.assertGreater(np.min(np.linalg.eigvalsh(p['mass'])),0.)

    def test_bias_power_matches_mass_metric_derivative(self):
        model=c.CoupledBody(specimen());v=np.array([.3,-.7,.2,.4,-.2,.5,.8,-.3]);q=np.array([.3,-.6]);h=1e-6
        p=model.prepare([.4,-.2,.8],[0,0,0,1],q,v)
        def mass(sign):
            speed=np.linalg.norm(v[3:6]);angle=sign*h*speed
            quat=[*(v[3:6]/speed*math.sin(angle/2)),math.cos(angle/2)]
            return model.prepare(np.array([.4,-.2,.8])+sign*h*v[:3],quat,q+sign*h*v[6:],v)['mass']
        self.close(v @ p['bias'],.5*v @ ((mass(1)-mass(-1))/(2*h)) @ v,1e-7)

    def test_gravity_accelerates_whole_tree_without_internal_motion(self):
        model=c.CoupledBody(specimen());p=model.prepare([0,1,0],[.5,.5,.5,.5],[.3,-.6],np.zeros(8))
        result=c.response(model,p,np.zeros(8),[],.01)
        self.close(result['velocity'],[0,-.098,0,0,0,0,0,0])

    def test_internal_motor_does_not_create_free_root_wrench(self):
        model=c.CoupledBody(specimen());p=model.prepare([0,1,0],[0,0,0,1],[.3,-.6],np.zeros(8),gravity=[0,0,0])
        applied=np.r_[np.zeros(6),[1.,-2.]];result=c.response(model,p,applied,[],.01)
        self.close(p['mass'] @ result['velocity'],applied*.01)
        self.assertGreater(np.linalg.norm(result['velocity'][3:6]),0.)

    def test_joint_and_root_wrench_uses_same_virtual_work(self):
        model=c.CoupledBody(specimen());v=np.arange(8)*.1;p=model.prepare([0,1,0],[0,0,0,1],[.3,-.6],v)
        point=[1.5,.6,.2];force=np.array([.2,3.,-.1]);torque=np.array([.1,-.3,.4])
        linear,angular=model.jacobian(p['frame'],'distal',point)
        self.close(v @ model.wrench(p,'distal',point,force,torque),force @ (linear @ v)+torque @ (angular @ v))

    def test_coupled_torso_support_cancels_one_sided_turning_response(self):
        model=rigid_body();p=model.prepare([0,1,0],[0,0,0,1],[],np.zeros(6),gravity=[0,-10,0])
        applied=np.array([0,0,0,0,0,1.]);contacts=[dict(body_id='root',point=[x,0,0],normal=[0,1,0],gap=0.,friction=0.) for x in (-1.,1.)]
        both=c.response(model,p,applied,contacts,.01);one=c.response(model,p,applied,contacts[1:],.01)
        self.assertTrue(both['solver']['converged']);self.close(both['velocity'],np.zeros(6),2e-9)
        self.close(one['velocity'][[1,5]],[-.07,.07],2e-9)
        self.close(np.sum(both['contact_impulses'],axis=0),[0,.2,0],2e-9)

    def test_separating_contact_does_not_pull_the_body_down(self):
        model=rigid_body();p=model.prepare([0,1,0],[0,0,0,1],[],[0,1,0,0,0,0],gravity=[0,0,0])
        hit=dict(body_id='root',point=[0,0,0],normal=[0,1,0],gap=0.,friction=.5)
        r=c.response(model,p,np.zeros(6),[hit],.01)
        self.close(r['contact_impulses'][0],[0,0,0]);self.close(r['velocity'],p['velocity'])

    def test_positive_gap_requires_approach_and_friction_opposes_slip(self):
        model=rigid_body();p=model.prepare([0,1,0],[0,0,0,1],[],[1,-1,0,0,0,0],gravity=[0,0,0])
        hit=dict(body_id='root',point=[0,1,0],normal=[0,1,0],gap=.02,friction=.5)
        r=c.response(model,p,np.zeros(6),[hit],.01);self.close(r['contact_impulses'][0],[0,0,0])
        hit['gap']=0.;r=c.response(model,p,np.zeros(6),[hit],.01);impulse=r['contact_impulses'][0]
        self.assertTrue(r['solver']['converged']);self.assertLess(impulse[0],0.)
        self.assertLessEqual(abs(impulse[0])+abs(impulse[2]),.5*impulse[1]+1e-9)

    def test_nonnegative_solver_matches_exhaustive_active_sets(self):
        rng=np.random.default_rng(74)
        for _ in range(20):
            x=rng.normal(size=(4,4));a=x.T @ x+.2*np.eye(4);b=rng.normal(size=4);best=None
            for mask in itertools.product((False,True),repeat=4):
                selected=np.flatnonzero(mask);v=np.zeros(4)
                if len(selected):v[selected]=np.linalg.solve(a[np.ix_(selected,selected)],-b[selected])
                if np.min(v)<-1e-10:continue
                score=.5*v @ a @ v+b @ v
                if best is None or score<best[0]:best=score,v
            found=c.nonnegative_quadratic(a,b);self.assertTrue(found['converged']);self.close(found['solution'],best[1])

    def test_penetration_uses_declared_recovery_time(self):
        model=rigid_body();p=model.prepare([0,1,0],[0,0,0,1],[],np.zeros(6),gravity=[0,0,0])
        hit=dict(body_id='root',point=[0,1,0],normal=[0,1,0],gap=-.001,friction=0.)
        result=c.response(model,p,np.zeros(6),[hit],.001,penetration_recovery_time=.02)
        self.close(result['velocity'][1],.05,2e-9)
        with self.assertRaises(ValueError):c.response(model,p,np.zeros(6),[hit],.01,penetration_recovery_time=.001)

    def test_solver_reports_iteration_exhaustion(self):
        result=c.nonnegative_quadratic(np.eye(3),[-1,-2,-3],maximum_iterations=1)
        self.assertFalse(result['converged']);self.assertGreater(result['kkt_residual'],0.)

    def test_refuses_invalid_contacts_and_nonphysical_metrics(self):
        model=rigid_body();p=model.prepare([0,1,0],[0,0,0,1],[],np.zeros(6));hit=dict(body_id='root',point=[0,0,0],normal=[0,1,0],gap=0.,friction=.5)
        for key,value in [('body_id','absent'),('normal',[0,2,0]),('gap',float('nan')),('friction',-1.),('point',[0,0])]:
            with self.subTest(key=key),self.assertRaises(ValueError):c.response(model,p,np.zeros(6),[hit|{key:value}],.01)
        with self.assertRaises(np.linalg.LinAlgError):c.nonnegative_quadratic(-np.eye(2),[1,2])
        with self.assertRaises(ValueError):c.nonnegative_quadratic([[1,2],[0,1]],[1,2])

    def test_prepared_native_velocity_rotates_local_angular_axes(self):
        from evaluate_coupled_contact_response import native_velocity,TRANSFORM
        q=[math.sqrt(.5),0,0,math.sqrt(.5)]
        row=dict(qpos=[0,0,0,*q],qvel=[1,2,3,1,0,0,.4,-.2])
        result=native_velocity(row)
        self.close(result,np.r_[TRANSFORM.T @ [1,2,3],TRANSFORM.T @ [0,1,0],[.4,-.2]])

    def test_retained_contact_conversion_preserves_body_and_ground_order(self):
        from evaluate_coupled_contact_response import prepare,TRANSFORM
        model=c.CoupledBody(specimen());p=model.prepare([0,1,0],[0,0,0,1],[.3,-.6],np.zeros(8))
        state=dict(base_pose_world=dict(position_m=dict(x=0,y=1,z=0),orientation_xyzw=dict(x=0,y=0,z=0,w=1)),
            base_twist_world=dict(linear_velocity_m_s=dict(x=0,y=0,z=0),angular_velocity_rad_s=dict(x=0,y=0,z=0)),
            ordered_joint_observations=[dict(position_rad=v,velocity_rad_s=0.) for v in [.3,-.6]])
        creature=dict(spec=dict(velocity_gains=[2,3],force_ranges=[[-1,1],[-2,2]],geom_names=['ground','root_geom','upper_geom','distal_geom']))
        hit=dict(geom=[0,3],position_m=[2,3,0],frame=[0,0,1],distance_m=-.001)
        row=dict(request=dict(state=state),native_targets=[2,-2],native_observation=dict(xipos=np.vstack((np.zeros(3),p['frame']['centers'] @ TRANSFORM.T)).tolist(),contacts=[hit]))
        _,force,contacts,checks=prepare(model,creature,row,dict(friction=.5))
        self.close(force,np.r_[np.zeros(6),[1,-2]]);self.close(checks['geometry_error_m'],0.)
        self.assertEqual(contacts[0]['body_id'],'distal');self.close(contacts[0]['normal'],[0,1,0])
        hit.update(geom=[3,0],frame=[0,0,-1]);self.assertEqual(prepare(model,creature,row,dict(friction=.5))[2],contacts)
        hit['geom']=[2,3]
        with self.assertRaises(ValueError):prepare(model,creature,row,dict(friction=.5))


if __name__=='__main__':unittest.main()
