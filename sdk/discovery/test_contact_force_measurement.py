"""Analytical frame/constraint cases and zero-world solver-stage rejection controls."""
import copy
from types import SimpleNamespace as NS
import unittest

import numpy as np
import contact_force_measurement as m


def fixture():
    metadata=dict(stage=m.STAGE,timestep_s=.01,ground_geom_id=0,cone="elliptic",
        geoms=[dict(id=i,name="geom"+str(i),body_id=i,body_name="body"+str(i)) for i in range(6)],
        site_mapping=[dict(contact_site_id="site"+str(i),geom_id=i+1,geom_name="geom"+str(i+1),
                           body_name="body"+str(i+1)) for i in range(4)])
    contact=NS(geom=np.array([0,1]),pos=np.array([1.,2.,3.]),frame=np.array([0.,0.,1.,1.,0.,0.,0.,1.,0.]),
               dist=-.001,dim=3,efc_address=0,exclude=0,friction=np.ones(5),adhesion=0.)
    data=NS(qpos=np.array([0.,0.,1.]),qvel=np.zeros(3),ctrl=np.array([.5]),time=0.,
            contact=[contact],ncon=1,nefc=3,efc_force=np.array([10.,2.,3.]),
            efc_id=np.array([0,0,0]),efc_type=np.array([7,7,7]),sensordata=np.array([2.]))
    api=FakeApi()
    return metadata,data,api


class FakeApi:
    def __init__(self): self.calls=[];self.mutate=False
    def mj_step1(self,model,data):self.calls.append("prepare")
    def mj_step2(self,model,data):
        self.calls.append("complete");data.time+=.01;data.qpos[0]+=.001
    def mj_contactForce(self,model,data,index,out):
        self.calls.append("force");out[:]=[10.,2.,3.,0.,0.,0.]
        if self.mutate:data.qpos[0]+=1.


def captured():
    metadata,data,api=fixture();stepper=m.ContactStepper(api,NS(),data,metadata)
    stepper.prepare(1);sample,timing=stepper.complete(1)
    trace={k:sample[k] for k in ("step","before_qpos","before_qvel","qpos","qvel","ctrl","nefc")}
    trace.update(time_s=sample["integrated_time_s"],batch_contacts=sample["ncon"],
                 contacts=[dict(world=0,**{k:c[k] for k in
                    ("native_index","geom","distance_m","position_m","frame")}) for c in sample["contacts"]])
    return metadata,sample,trace,timing


class ContactMeasurementControls(unittest.TestCase):
    def setUp(self):
        self.metadata,self.data,self.api=fixture()
        self.contact=m.geometry(self.data)[0]
        self.stepper=m.ContactStepper(self.api,NS(),self.data,self.metadata)

    def test_world_basis_transpose(self):
        self.assertEqual(m.world_vector(self.contact["frame"],[10.,2.,3.]),[2.,3.,10.])

    def test_torque_and_force_canonical_rotation(self):
        x=m.enrich(self.contact,[10.,2.,3.,4.,5.,6.],self.metadata)
        self.assertEqual(x["force_on_geom2_canonical_n"],[2.,10.,-3.])
        self.assertEqual(x["torque_on_geom2_canonical_nm"],[5.,4.,-6.])

    def test_positive_force_on_geom2(self):
        x=m.enrich(self.contact,[10.,2.,3.,0.,0.,0.],self.metadata)
        load=m.summarize_loads([x],self.metadata)["mapped_distal_ground_loads"][0]
        self.assertEqual(load["normal_load_n"],10.);self.assertEqual(load["force_canonical_n"],[2.,10.,-3.])

    def test_negative_force_on_geom1(self):
        self.contact["geom"]=[1,0];x=m.enrich(self.contact,[10.,2.,3.,0.,0.,0.],self.metadata)
        load=m.summarize_loads([x],self.metadata)["mapped_distal_ground_loads"][0]
        self.assertEqual(load["force_canonical_n"],[-2.,-10.,3.])

    def test_zero_contacts_is_measured_zero(self):
        loads=m.summarize_loads([],self.metadata)
        self.assertEqual(len(loads["mapped_distal_ground_loads"]),4)
        self.assertTrue(all(x["normal_load_n"]==0. and x["contact_indices"]==[] for x in loads["mapped_distal_ground_loads"]))

    def test_other_ground_contact_retained(self):
        self.contact["geom"]=[0,5];x=m.enrich(self.contact,[10.,0.,0.,0.,0.,0.],self.metadata)
        loads=m.summarize_loads([x],self.metadata)
        self.assertEqual(loads["other_contact_indices"],[0])
        self.assertTrue(all(x["normal_load_n"]==0. for x in loads["mapped_distal_ground_loads"]))

    def test_multiple_contacts_on_one_distal_geom(self):
        x=m.enrich(self.contact,[10.,2.,3.,0.,0.,0.],self.metadata);y=copy.deepcopy(x);y["native_index"]=1
        load=m.summarize_loads([x,y],self.metadata)["mapped_distal_ground_loads"][0]
        self.assertEqual(load["contact_indices"],[0,1]);self.assertEqual(load["normal_load_n"],20.)

    def test_elliptic_dimensions(self):
        for dim in (1,3,4,6):
            c=dict(self.contact,dim=dim)
            self.assertEqual(m.decode_constraint(c,list(range(1,dim+1)),"elliptic"),
                             list(range(1,dim+1))+[0.]*(6-dim))

    def test_pyramidal_dimensions(self):
        self.assertEqual(m.decode_constraint(dict(self.contact,dim=1),[9.],"pyramidal"),[9.,0.,0.,0.,0.,0.])
        for dim in (3,4,6):
            c=dict(self.contact,dim=dim,friction=[.5,1.,2.,3.,4.])
            values=[3.,1.]*(dim-1)
            self.assertEqual(m.decode_constraint(c,values,"pyramidal"),
                [4.*(dim-1)]+[2*x for x in c["friction"][:dim-1]]+[0.]*(6-dim))

    def test_inactive_contact_has_zero_wrench(self):
        self.contact["efc_address"]=-1
        self.assertEqual(m.decode_constraint(self.contact,[99.]*6,"elliptic"),[0.]*6)

    def test_adhesion_preserves_signed_net_load(self):
        self.contact["adhesion_n"]=12.
        self.assertEqual(m.decode_constraint(self.contact,[10.,2.,3.],"elliptic")[0],-2.)

    def test_invalid_frame_refused(self):
        for frame in ([1.]*9,[1.,0.,0.,0.,1.,0.,0.,0.,-1.]):
            with self.assertRaises(ValueError):m.validate_frame(frame)

    def test_nonfinite_wrench_refused(self):
        with self.assertRaises(ValueError):m.enrich(self.contact,[math_nan(),0.,0.,0.,0.,0.],self.metadata)

    def test_flex_geometry_refused(self):
        self.contact["geom"]=[-1,1]
        with self.assertRaises(ValueError):m.enrich(self.contact,[0.]*6,self.metadata)

    def test_bad_constraint_extent_refused(self):
        for address in (-2,2):
            with self.assertRaises(ValueError):m.decode_constraint(dict(self.contact,efc_address=address),[1.]*3,"elliptic")

    def test_protocol_samples_after_completion(self):
        self.stepper.prepare(1);sample,timing=self.stepper.complete(1)
        self.assertEqual(self.api.calls,["prepare","complete","force"])
        self.assertEqual(sample["prepared_time_s"],0.);self.assertEqual(sample["integrated_time_s"],.01)
        self.assertEqual(sample["before_qpos"],[0.,0.,1.]);self.assertEqual(sample["qpos"],[.001,0.,1.])
        self.assertTrue(all(v>=0 for v in timing.values()))

    def test_completion_before_prepare_refused(self):
        with self.assertRaises(ValueError):self.stepper.complete(1)
        self.assertEqual(self.api.calls,[])

    def test_double_prepare_refused(self):
        self.stepper.prepare(1)
        with self.assertRaises(ValueError):self.stepper.prepare(1)
        self.assertEqual(self.api.calls,["prepare"])

    def test_double_completion_refused(self):
        self.stepper.prepare(1);self.stepper.complete(1)
        with self.assertRaises(ValueError):self.stepper.complete(1)
        self.assertEqual(self.api.calls.count("complete"),1)

    def test_skipped_step_refused(self):
        with self.assertRaises(ValueError):self.stepper.prepare(2)
        self.stepper.prepare(1)
        with self.assertRaises(ValueError):self.stepper.complete(2)
        self.assertEqual(self.api.calls,["prepare"])

    def test_changed_prepared_state_geometry_or_time_refused(self):
        for kind in ("qpos","frame","time"):
            metadata,data,api=fixture();stepper=m.ContactStepper(api,NS(),data,metadata);stepper.prepare(1)
            if kind=="qpos":data.qpos[0]+=1.
            elif kind=="frame":data.contact[0].frame[0]+=.1
            else:data.time+=.01
            with self.assertRaises(ValueError):stepper.complete(1)
            self.assertEqual(api.calls,["prepare"])
            with self.assertRaises(ValueError):stepper.prepare(1)

    def test_mutating_contact_readout_refused(self):
        self.api.mutate=True;self.stepper.prepare(1)
        with self.assertRaises(ValueError):self.stepper.complete(1)
        self.assertTrue(self.stepper.poisoned)


def math_nan():return float("nan")


if __name__=="__main__":unittest.main()
