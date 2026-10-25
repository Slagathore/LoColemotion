"""Independent point derivatives, balance, force and actuator constraints."""
import copy,math,unittest
import numpy as np
import actuation_recovery_mechanics as mechanics
from test_actuation_recovery_mechanics import specimen,vector
from test_floating_base_dynamics import free_spec
from floating_base_dynamics import FloatingDynamics
from contact_posture_reference import retract
import dynamic_inverse_dynamics_v2 as d


class InverseDynamicsControls(unittest.TestCase):
    def setUp(self):
        self.spec=specimen();self.spec["contact_sites"]=[dict(contact_site_id="foot",body_id="distal",local_center_m=vector(.2,0.,0.),radius_m=.1)]
        self.model=FloatingDynamics(self.spec,[.01,.02]);self.p=np.array([.3,.4,-.2])
        self.q=np.array([.2,-.1,.15,math.sqrt(.9275)]);self.j=np.array([.31,-.47]);self.v=np.linspace(-.35,.42,8)
        self.frame=self.model.tree.kinematics(self.p,self.q,self.j);self.params=d.parameters()
        self.local=np.array([.2,-.1,.07]);self.point=self.frame["positions"][2]+self.frame["rotations"][2] @ self.local
        self.motion=self.model.motion(self.frame,self.v,np.zeros(8))
    def close(self,a,b,tol=2e-7):np.testing.assert_allclose(a,b,atol=tol,rtol=tol)
    def item(self,n,target=None,weight=10.):
        return dict(name="acceleration",jacobian=np.eye(n),bias=np.zeros(n),target=np.zeros(n) if target is None else np.array(target),weight=weight)
    def active(self,model,frame,body,point,name="foot"):
        return dict(contact_site_id=name,body_id=body,point=point,jacobian=model.jacobians(frame,body,point)[0])
    def free(self,mass=3.):
        spec=free_spec();spec["bodies"][0]["mass_kg"]=mass;spec["contact_sites"]=[]
        model=FloatingDynamics(spec,[]);frame=model.tree.kinematics([0.,0.,0.],[0.,0.,0.,1.],[])
        return model,frame
    def calculate(self,model,frame,active,lower,upper,velocity=None,target=None):
        return d.compute(model,frame,np.zeros(model.size) if velocity is None else velocity,[0.,-9.8,0.],
            [self.item(model.size,target)],active,lower,upper,self.params)
    def test_01_material_point_velocity(self):
        jac,vel,_=d.point_kinematics(self.model,self.frame,self.motion,"distal",self.point);self.close(jac @ self.v,vel,1e-12)
        h=1e-6;frames=[self.model.tree.kinematics(*retract(self.p,self.q,self.j,s*h*self.v)) for s in (-1,1)]
        points=[f["positions"][2]+f["rotations"][2] @ self.local for f in frames]
        self.close((points[1]-points[0])/(2*h),vel)
    def test_02_material_point_bias_acceleration(self):
        h=1e-6;velocities=[]
        for sign in (-1,1):
            frame=self.model.tree.kinematics(*retract(self.p,self.q,self.j,sign*h*self.v))
            point=frame["positions"][2]+frame["rotations"][2] @ self.local
            motion=self.model.motion(frame,self.v,np.zeros(8))
            velocities.append(d.point_kinematics(self.model,frame,motion,"distal",point)[1])
        bias=d.point_kinematics(self.model,self.frame,self.motion,"distal",self.point)[2]
        self.close((velocities[1]-velocities[0])/(2*h),bias)
    def contacts(self,present=False):
        return [dict(contact_site_id="foot",presence=present,bears_support=present,
            point_world_m=vector(*self.point),normal_world_unit=vector(0.,1.,0.))]
    def test_03_com_bias_derivative(self):
        items,_=d.tasks(self.model,self.frame,self.v,self.q,self.contacts(),self.frame["whole_body_com"],[0.,0.],self.params)
        com=items[0];h=1e-6;vel=[]
        for sign in (-1,1):
            f=self.model.tree.kinematics(*retract(self.p,self.q,self.j,sign*h*self.v))
            motion=self.model.motion(f,self.v,np.zeros(8));vel.append(np.average(motion["com_velocity"],axis=0,weights=self.model.tree.mass))
        self.close((vel[1]-vel[0])/(2*h),com["bias"])
        self.close(com["jacobian"] @ self.v,np.average(self.motion["com_velocity"],axis=0,weights=self.model.tree.mass),1e-12)
    def test_04_unactuated_flight_is_free_fall(self):
        model,frame=self.free();r=self.calculate(model,frame,[],[],[])
        self.close(r["acceleration"],[0.,-9.8,0.,0.,0.,0.]);self.assertEqual(r["forces"].shape,(0,3))
    def test_05_static_support_regularized_analytic_optimum(self):
        model,frame=self.free();r=self.calculate(model,frame,[self.active(model,frame,"root",[0.,0.,0.])],[],[])
        h=100.+self.params["acceleration_regularization"];reg=self.params["force_regularization"]
        expected=-3.*reg*29.4/(h+9.*reg)
        self.close(r["acceleration"][1],expected);self.close(r["forces"][0,1],29.4+3.*expected)
    def test_06_normal_force_cap(self):
        model,frame=self.free(100.);r=self.calculate(model,frame,[self.active(model,frame,"root",[0.,0.,0.])],[],[])
        self.close(r["forces"][0,1],70.);self.close(r["acceleration"][1],-9.1)
    def test_07_inscribed_friction_pyramid(self):
        model,frame=self.free();r=self.calculate(model,frame,[self.active(model,frame,"root",[0.,0.,0.])],[],[],target=[100.,0.,0.,0.,0.,0.])
        force=r["forces"][0];self.assertLessEqual(abs(force[0]),self.params["friction_coefficient"]/math.sqrt(2.)*force[1]+2e-6)
        self.assertLessEqual(np.linalg.norm(force[[0,2]]),self.params["friction_coefficient"]*force[1]+2e-6)
    def test_08_hard_joint_torque_intervals(self):
        r=self.calculate(self.model,self.frame,[],[.2,.3],[.4,.5],self.v)
        self.assertTrue(np.all(r["requested_torque"]>=np.array([.2,.3])-2e-6))
        self.assertTrue(np.all(r["requested_torque"]<=np.array([.4,.5])+2e-6))
    def test_09_actual_motor_projection(self):
        env=mechanics.command_envelope([.5,.5],[1.,1.],[0.,0.],[1.,1.],[.08,.08])
        gains=[10.,5.];ranges=[[-2.,2.],[-2.,2.]];bounds=mechanics.torque_envelope(env,self.v[6:],gains,ranges)
        r=self.calculate(self.model,self.frame,[],*bounds,self.v)
        command=mechanics.command_for_torque(env,self.v[6:],gains,ranges,r["requested_torque"])
        self.close(command["predicted_torque"],r["requested_torque"],2e-6)
        self.assertTrue(np.max(np.abs(command["proposal"]))<=.08+1e-12)
    def test_10_rank_deficient_duplicate_support(self):
        model,frame=self.free();active=[self.active(model,frame,"root",[0.,0.,0.],str(i)) for i in range(2)]
        r=self.calculate(model,frame,active,[],[]);self.close(r["forces"][0],r["forces"][1])
        self.assertTrue(r["solver"]["accepted"])
    def test_11_contact_and_airborne_tasks_are_explicit(self):
        air,absent=d.tasks(self.model,self.frame,self.v,self.q,self.contacts(),self.frame["whole_body_com"],[0.,0.],self.params)
        support,active=d.tasks(self.model,self.frame,self.v,self.q,self.contacts(True),self.frame["whole_body_com"],[0.,0.],self.params)
        self.assertEqual(len(absent),0);self.assertEqual(len(active),1)
        self.assertEqual(air[-1]["name"],"airborne_foot");self.assertEqual(support[-1]["name"],"support_foot")
        self.assertTrue(self.params["contact_acceleration_is_soft_task"])
    def test_12_invalid_contact_semantics_refused(self):
        contacts=self.contacts();contacts[0]["bears_support"]=True
        with self.assertRaises(ValueError):d.tasks(self.model,self.frame,self.v,self.q,contacts,self.frame["whole_body_com"],[0.,0.],self.params)
    def test_13_parameter_mutation_refused(self):
        p=copy.deepcopy(self.params);p["maximum_normal_force_n"]=71.
        with self.assertRaises(ValueError):d.problem(self.model,self.frame,self.v,[0.,-9.8,0.],[],[],[-1.,-1.],[1.,1.],p)
    def test_14_recursive_inverse_dynamics_with_transferred_forces(self):
        active=[self.active(self.model,self.frame,"distal",self.point)]
        r=self.calculate(self.model,self.frame,active,[-2.,-2.],[2.,2.],self.v)
        inverse=self.model.inverse_dynamics(self.frame,self.v,r["acceleration"],[0.,-9.8,0.])
        external=self.model.generalized_wrenches(self.frame,[dict(body_id="distal",point=self.point,force=r["forces"][0],torque=[0.,0.,0.])])
        self.close(inverse-external-self.model.passive_force(self.v),np.r_[np.zeros(6),r["requested_torque"]],2e-6)

if __name__=="__main__":unittest.main()
