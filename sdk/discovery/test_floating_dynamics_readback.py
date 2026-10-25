"""Zero-world controls for input-derived native model metadata."""
import copy,unittest
from floating_dynamics_readback_metadata import verify_metadata


class ReadbackControls(unittest.TestCase):
    def setUp(self):
        self.xml='<mujoco><option gravity="0 0 -9.8"/></mujoco>'
        self.rows=[dict(request=dict(state=dict(gravity_world_m_s2=dict(x=0.,y=-9.8,z=0.)))) for _ in range(66)]
        self.meta=dict(nv=14,nq=15,nbody=10,nu=8,joint_dof_addresses=[0,*range(6,14)],body_rootid=[0]+[1]*9,
            armature=[0.]*6+[.01]*8,damping=[0.]*14,higher_order_damping_nonzero=0,gravity=[0.,0.,-9.8])

    def check(self):return verify_metadata(self.meta,self.xml,self.rows)
    def test_01_actual_declared_gravity_accepted(self):self.assertEqual(self.check(),[0.,0.,-9.8])
    def test_02_different_consistent_declared_gravity_accepted(self):
        self.xml=self.xml.replace('9.8','9.81');self.meta['gravity'][2]=-9.81
        for row in self.rows:row['request']['state']['gravity_world_m_s2']['y']=-9.81
        self.assertEqual(self.check(),[0.,0.,-9.81])
    def test_03_original_hardcoded_assumption_refused(self):
        self.meta['gravity'][2]=-9.81
        with self.assertRaises(ValueError):self.check()
    def test_04_one_crossed_retained_state_refused(self):
        self.rows[-1]['request']['state']['gravity_world_m_s2']['y']=-9.81
        with self.assertRaises(ValueError):self.check()
    def test_05_changed_joint_inertia_refused(self):
        self.meta['armature'][-1]=0.
        with self.assertRaises(ValueError):self.check()
    def test_06_higher_order_damping_refused(self):
        self.meta['higher_order_damping_nonzero']=1
        with self.assertRaises(ValueError):self.check()
    def test_07_extra_or_missing_metadata_refused(self):
        self.meta['undeclared']=0
        with self.assertRaises(ValueError):self.check()
        del self.meta['undeclared'];del self.meta['gravity']
        with self.assertRaises(ValueError):self.check()
    def test_08_missing_explicit_gravity_refused(self):
        self.xml='<mujoco><option/></mujoco>'
        with self.assertRaises(ValueError):self.check()
    def test_09_nonfinite_gravity_refused(self):
        self.xml='<mujoco><option gravity="0 0 nan"/></mujoco>'
        with self.assertRaises(ValueError):self.check()
    def test_10_partial_state_population_refused(self):
        self.rows.pop()
        with self.assertRaises(ValueError):self.check()
    def test_11_general_coordinate_mapping_accepted(self):
        self.xml='<mujoco><option gravity="3 -5 4"/></mujoco>';self.meta['gravity']=[3.,-5.,4.]
        for row in self.rows:row['request']['state']['gravity_world_m_s2']=dict(x=3.,y=4.,z=5.)
        self.assertEqual(self.check(),[3.,-5.,4.])

if __name__=="__main__":unittest.main()
