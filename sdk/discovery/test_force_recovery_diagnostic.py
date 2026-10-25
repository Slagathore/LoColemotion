"""Analytical accounting and exact-clock corruption controls; no worlds."""
import copy
import unittest
import numpy as np
import force_recovery_diagnostic_metrics as d
from test_actuation_recovery_mechanics import specimen
from actuation_recovery_mechanics import RigidTree


class DiagnosticControls(unittest.TestCase):
    def close(self,a,b):np.testing.assert_allclose(a,b,rtol=0,atol=1e-12)
    def intervals(self):return np.array([[[-10.],[10.]],[[-8.],[8.]],[[-5.],[5.]],[[1.],[2.]]])

    def test_positive_request_telescoping_errors(self):
        r=d.decompose_loss([12.],self.intervals())
        self.close([v[0] for v in r["incremental_absolute_error"].values()],[2,2,3,3])
    def test_negative_request_and_opposite_sign_slew_interval(self):
        r=d.decompose_loss([-12.],self.intervals())
        self.close([v[0] for v in r["incremental_absolute_error"].values()],[2,2,3,6])
    def test_reachable_request_has_no_loss(self):
        r=d.decompose_loss([1.5],self.intervals());self.close(r["absolute_errors"],np.zeros((4,1)))
    def test_singleton_saturation_interval(self):
        values=self.intervals();values[-1]=[[2.],[2.]]
        r=d.decompose_loss([9.],values);self.close(r["projections"][:,0],[9,8,5,2])
    def test_nonnested_or_inverted_intervals_refused(self):
        for index,value in (((2,0,0),-9.),((3,0,0),3.)):
            values=self.intervals();values[index]=value
            with self.assertRaises(ValueError):d.decompose_loss([2.],values)
    def test_nonfinite_torque_refused(self):
        with self.assertRaises(ValueError):d.decompose_loss([np.nan],self.intervals())
    def test_contact_force_sign_reverses_with_ground_side(self):
        contact=dict(position_m=[1.,2.,3.],force_on_geom2_canonical_n=[0.,4.,0.],
            torque_on_geom2_canonical_nm=[0.,0.,2.],body_ids=[0,1],body_names=["world","robot"])
        one=d.wrench_about(d.robot_wrenches(dict(contacts=[contact])),[0.,0.,0.])
        contact.update(body_ids=[1,0],body_names=["robot","world"])
        other=d.wrench_about(d.robot_wrenches(dict(contacts=[contact])),[0.,0.,0.])
        self.close(one,[0,4,0,8,0,6]);self.close(other,-one)
    def test_robot_internal_contact_cancels_total_wrench(self):
        contact=dict(position_m=[1.,2.,3.],force_on_geom2_canonical_n=[2.,4.,6.],
            torque_on_geom2_canonical_nm=[1.,2.,3.],body_ids=[1,2],body_names=["a","b"])
        self.close(d.wrench_about(d.robot_wrenches(dict(contacts=[contact])),[.2,.3,.4]),np.zeros(6))
    def test_wrench_origin_shift_has_correct_moment(self):
        w=[dict(point=[1.,0.,0.],force=[0.,2.,0.],torque=[0.,0.,3.])]
        self.close(d.wrench_about(w,[0,0,0]),[0,2,0,0,0,5])
        self.close(d.wrench_about(w,[1,0,0]),[0,2,0,0,0,3])
    def test_no_contact_is_zero_not_missing(self):self.close(d.wrench_about([], [0,0,0]),np.zeros(6))
    def test_native_prepared_pose_conversion(self):
        tree=RigidTree(specimen());q=[1.,2.,3.,1.,0.,0.,0.,.2,-.3]
        a=d.prepared_frame(tree,q);b=tree.kinematics([1.,3.,-2.],[0,0,0,1],[.2,-.3])
        for key in a:self.close(a[key],b[key])
    def test_prepared_join_refuses_shifted_clock_or_control(self):
        control=dict(outer_step=60,request=dict(state=dict(semantic_step=60)),native_targets=[1.],
            native_observation=dict(time_s=.5,qpos=[1.],qvel=[2.]))
        sample=dict(step=301,prepared_time_s=.5,integrated_time_s=.501,before_qpos=[1.],before_qvel=[2.],ctrl=[1.])
        trace=dict(step=301,time_s=.501,before_qpos=[1.],before_qvel=[2.],ctrl=[1.])
        d.join_control(control,sample,trace,60)
        for key,value in (("step",302),("prepared_time_s",.501),("before_qpos",[2.]),("ctrl",[2.])):
            changed=copy.deepcopy(sample);changed[key]=value
            with self.assertRaises(ValueError):d.join_control(control,changed,trace,60)
    def test_vector_statistics_keep_denominators_and_units_separate(self):
        r=d.vectors([[1.,-2.],[3.,2.]])
        self.assertEqual(r["count"],2);self.close(r["mean"],[2,0]);self.close(r["mean_absolute"],[2,2])
        self.close(r["rms"],[np.sqrt(5),2])
    def test_empty_population_is_missing_not_zero(self):self.assertIsNone(d.vectors([]))


if __name__=="__main__":unittest.main()
