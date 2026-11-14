"""Actuator inertia, implicit feedback and native parameter binding controls."""
import copy
import unittest
import xml.etree.ElementTree as ET

import numpy as np

import coupled_contact_response as c
from evaluate_coupled_contact_response import actuator_parameters
from test_actuation_recovery_mechanics import specimen


def native_fixture():
    morphology=specimen()
    root=ET.fromstring('<mujoco><option timestep=".001" integrator="implicitfast"/>'
        '<worldbody><geom type="plane" friction=".8 .005 .0001" solref=".02 1"/>'
        '<body/></worldbody><actuator/></mujoco>')
    for i,j in enumerate(morphology['joints']):
        ET.SubElement(root.find('worldbody/body'),'joint',dict(name=j['joint_id'],type='hinge',damping='0',armature=str(.01*(i+1))))
        ET.SubElement(root.find('actuator'),'velocity',dict(name=j['joint_id']+'_motor',joint=j['joint_id'],
            gear='1 0 0 0 0 0',ctrllimited='false',kv=str(i+2),forcelimited='true',forcerange='-3 3'))
    return dict(model_xml=ET.tostring(root,encoding='unicode'),compiled=dict(morphology=dict(morphology_spec=morphology)),
        spec=dict(ordered_joints=['hip','knee'],ordered_actuators=['hip_motor','knee_motor'],velocity_gains=[2.,3.],force_ranges=[[-3.,3.]]*2))


class ActuatorResponseControls(unittest.TestCase):
    def close(self,a,b):np.testing.assert_allclose(a,b,rtol=1e-10,atol=1e-10)

    def prepared(self,velocity=None):
        model=c.CoupledBody(specimen())
        p=model.prepare([0,1,0],[0,0,0,1],[.3,-.6],np.zeros(8) if velocity is None else velocity,gravity=[0,0,0])
        return model,p

    def test_scalar_implicit_solution_with_armature_and_damping(self):
        model,p=self.prepared([0.]*6+[.3,-.7]);p['mass']=np.diag([1.]*6+[2.,3.]);p['bias']=np.zeros(8)
        gains=np.array([4.,6.]);damping=np.array([.7,.9]);target=np.array([.8,-.2]);armature=np.array([.5,.2]);dt=.01
        a=c.velocity_actuation(p['velocity'][6:],target,gains,[[-100,100]]*2,damping)
        result=c.response(model,p,a['applied'],[],dt,joint_armature=armature,joint_velocity_derivative=a['velocity_derivative'])
        inertia=np.array([2.,3.])+armature
        expected=(inertia*p['velocity'][6:]+dt*gains*target)/(inertia+dt*(gains+damping))
        self.close(result['velocity'],np.r_[np.zeros(6),expected])
        self.assertEqual(result['model'],'inelastic_coupled_friction_pyramid_actuator_v2')

    def test_force_caps_remove_motor_derivative_but_keep_passive_damping(self):
        velocity=np.full(5,.25);demand=np.array([-3.,-2.,0.,2.,3.]);targets=velocity+demand/2
        a=c.velocity_actuation(velocity,targets,[2.]*5,[[-2.,2.]]*5,[.5]*5)
        self.close(a['motor'],[-2,-2,0,2,2]);self.close(a['velocity_derivative'],[-.5,-.5,-2.5,-.5,-.5])
        self.close(a['applied'][6:],np.clip(demand,-2,2)-.125)
        for i in (0,2,4):
            v=velocity.copy();v[i]+=1e-6
            shifted=c.velocity_actuation(v,targets,[2.]*5,[[-2.,2.]]*5,[.5]*5)
            self.assertAlmostEqual((shifted['applied'][6+i]-a['applied'][6+i])/1e-6,a['velocity_derivative'][i],places=7)

    def test_saturated_scalar_step_uses_clipped_force(self):
        model,p=self.prepared([0.]*6+[.5,-.5]);p['mass']=np.diag([1.]*8);p['bias']=np.zeros(8)
        a=c.velocity_actuation(p['velocity'][6:],[10,-10],[20,20],[[-2,2]]*2,[3,3])
        r=c.response(model,p,a['applied'],[],.01,joint_armature=[.1,.1],joint_velocity_derivative=a['velocity_derivative'])
        self.close(r['velocity'][6:],(1.1*p['velocity'][6:]+.01*np.array([2,-2]))/1.13)

    def test_zero_capacity_and_zero_gain_actuators(self):
        a=c.velocity_actuation([1,-1],[4,4],[2,0],[[0,0],[-2,2]],[.5,0])
        self.close(a['motor'],[0,0]);self.close(a['applied'][6:],[-.5,0]);self.close(a['velocity_derivative'],[-.5,0])

    def test_internal_impulse_uses_reflected_inertia_without_root_wrench(self):
        model,p=self.prepared();applied=np.r_[np.zeros(6),[2.,-1.]];armature=[.2,.3]
        r=c.response(model,p,applied,[],.01,joint_armature=armature,joint_velocity_derivative=[0.,0.])
        mass=p['mass']+np.diag([0.]*6+armature)
        self.close(mass @ r['velocity'],.01*applied)
        self.close((mass @ r['velocity'])[:6],np.zeros(6))
        self.close(.5*r['velocity'] @ mass @ r['velocity'],.5*r['velocity'] @ p['mass'] @ r['velocity']+
                   .5*np.dot(armature,r['velocity'][6:]**2))

    def test_implicit_braking_dissipates_energy_for_stiff_feedback(self):
        model,p=self.prepared([.1,.2,-.1,.2,-.3,.1,.8,-.4]);armature=[.01,.03]
        mass=p['mass']+np.diag([0.]*6+armature);p['bias']=np.zeros(8)
        for gain in (1.,100.,10000.):
            a=c.velocity_actuation(p['velocity'][6:],[0,0],[gain]*2,[[-1e6,1e6]]*2,[.3,.4])
            r=c.response(model,p,a['applied'],[],.01,joint_armature=armature,joint_velocity_derivative=a['velocity_derivative'])
            self.assertLess(r['velocity'] @ mass @ r['velocity'],p['velocity'] @ mass @ p['velocity'])

    def test_contact_impulses_obey_friction_and_modified_balance(self):
        model,p=self.prepared([.5,-.2,.1,.1,0,0,.2,-.3]);p['gravity'][1]=-60.
        contacts=[dict(body_id=body,point=p['frame']['centers'][i].tolist(),normal=[0,1,0],gap=0.,friction=.5)
                  for i,body in enumerate(model.tree.body_ids)]
        a=c.velocity_actuation(p['velocity'][6:],[.8,-.2],[10,20],[[-3,3]]*2,[.1,.2])
        r=c.response(model,p,a['applied'],contacts,.01,joint_armature=[.01,.02],joint_velocity_derivative=a['velocity_derivative'])
        self.assertTrue(r['solver']['converged']);self.close(r['balance_residual'],np.zeros(8))
        for force in r['contact_impulses']:
            self.assertGreaterEqual(force[1],0.);self.assertLessEqual(abs(force[0])+abs(force[2]),.5*force[1]+1e-10)

    def test_zero_corrections_preserve_legacy_prediction_and_inputs(self):
        model,p=self.prepared([.1,.2,0,.2,0,.1,.4,-.3]);original=copy.deepcopy(p)
        force=np.r_[np.zeros(6),[1,-2]];legacy=c.response(model,p,force,[],.01)
        same=c.response(model,p,force,[],.01,joint_armature=[0,0],joint_velocity_derivative=[0,0])
        np.testing.assert_array_equal(legacy['velocity'],same['velocity'])
        self.assertEqual(legacy['model'],'inelastic_coupled_friction_pyramid_v1')
        for key in ('velocity','mass','bias','gravity'):np.testing.assert_array_equal(p[key],original[key])

    def test_invalid_actuator_parameters_and_partial_metric_refuse(self):
        args=[[0,0],[1,1],[2,2],[[-3,3]]*2,[0,0]]
        for index,value in ((0,[0]),(1,[float('nan'),0]),(2,[-1,2]),(3,[[1,2],[-2,2]]),(4,[0,-1])):
            bad=copy.deepcopy(args);bad[index]=value
            with self.subTest(index=index),self.assertRaises(ValueError):c.velocity_actuation(*bad)
        model,p=self.prepared()
        for fields in (dict(joint_armature=[0,0]),dict(joint_velocity_derivative=[0,0]),
                       dict(joint_armature=[-.1,0],joint_velocity_derivative=[0,0]),
                       dict(joint_armature=[0,0],joint_velocity_derivative=[0,1]),
                       dict(joint_armature=[float('nan'),0],joint_velocity_derivative=[0,0])):
            with self.subTest(fields=fields),self.assertRaises(ValueError):c.response(model,p,np.zeros(8),[],.01,**fields)

    def test_native_parameters_preserve_order_and_distinct_joint_inertias(self):
        self.assertEqual(actuator_parameters(native_fixture()),dict(armature=[.01,.02],damping=[0.,0.],
            gains=[2.,3.],force_ranges=[[-3.,3.],[-3.,3.]]))

    def test_native_parameter_mismatches_and_unsupported_dynamics_refuse(self):
        for path,key,value in (('.//joint','armature','-.1'),('.//joint','armature','nan'),('.//joint','damping','1'),
                               ('.//joint','stiffness','2'),('.//velocity','gear','2 0 0 0 0 0'),
                               ('.//velocity','joint','knee'),('.//velocity','kv','4'),('.//velocity','forcerange','-4 4'),
                               ('.//velocity','ctrllimited','true'),('option','integrator','Euler')):
            fixture=native_fixture();xml=ET.fromstring(fixture['model_xml']);xml.find(path).set(key,value)
            fixture['model_xml']=ET.tostring(xml,encoding='unicode')
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):actuator_parameters(fixture)
        for tag in ('default','tendon','equality'):
            fixture=native_fixture();xml=ET.fromstring(fixture['model_xml']);ET.SubElement(xml,tag)
            fixture['model_xml']=ET.tostring(xml,encoding='unicode')
            with self.subTest(tag=tag),self.assertRaises(ValueError):actuator_parameters(fixture)

    def reader_fixture(self):
        from test_check_coupled_contact_response import fixture
        rows,plan,result,expected=fixture()
        plan.update(actuator_aware=True,variants=['free','feet','all','actuator'],
            comparison_variants=dict(reference='all',candidate='actuator'))
        plan['criterion']=dict(minimum_relative_error_reduction_per_body=.2)
        plan['validation']['maximum_motor_force_error_nm']=1e-5;result['maximum_motor_force_error_nm']=0.
        for row in rows:
            a=copy.deepcopy(row['predictions']['all']);a.update(root_angular_error_rad_s=.25,motor_force_nm=[0.]*8);a['velocity'][3]=.25
            row['predictions']['actuator']=a;row['native_motor_force_nm']=[0.]*8
            summary=copy.deepcopy(result['summaries'][row['batch']]['all'])
            summary.update(mean_root_angular_error_rad_s=.25,maximum_root_angular_error_rad_s=.25)
            result['summaries'][row['batch']]['actuator']=summary
        return rows,plan,result,expected

    def test_reader_compares_declared_variants_and_keeps_valid_negative(self):
        from check_coupled_contact_response import aggregate
        args=self.reader_fixture();answer=aggregate(*args)
        self.assertTrue(answer['retained_state_screen_passed'])
        self.assertEqual(answer['relative_error_reduction_by_batch'],{'0':.5,'1':.5,'2':.5})
        self.assertEqual(answer['descriptive']['0']['worse_than_reference_samples'],0)
        args[1]['comparison_variants']=dict(reference='actuator',candidate='all')
        self.assertFalse(aggregate(*args)['retained_state_screen_passed'])

    def test_reader_refuses_forged_force_and_invalid_comparison(self):
        from check_coupled_contact_response import aggregate
        args=self.reader_fixture();args[0][0]['predictions']['actuator']['motor_force_nm'][0]=1e-4
        with self.assertRaises(ValueError):aggregate(*args)
        args[2]['maximum_motor_force_error_nm']=1e-4
        self.assertFalse(aggregate(*args)['retained_state_screen_passed'])
        for candidate in ('absent','all'):
            args=self.reader_fixture();args[1]['comparison_variants']['candidate']=candidate
            with self.subTest(candidate=candidate),self.assertRaises(ValueError):aggregate(*args)


if __name__=='__main__':unittest.main()
