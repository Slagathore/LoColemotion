"""Independent contact-force decoding and completed-step capture; zero worlds."""
import copy
import ctypes
from contextlib import ExitStack
import math
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import mujoco
import numpy as np

import creature_contact_reactions as subject
import creature_capture as capture
from gpu_quadruped_model import split_contacts


def fixture(*, reverse=False, angle=0.):
    binding=dict(descriptor_sha256="fixture",body_shape_sha256="fixture",model_xml_sha256="fixture")
    frame=np.array([[0.,0.,1.],[1.,0.,0.],[0.,1.,0.]])
    force=np.array([1.,-.5,2.]);sign=-1. if reverse else 1.
    rotation=np.array([[math.cos(angle),-math.sin(angle),0.],[math.sin(angle),math.cos(angle),0.],[0.,0.,1.]])
    qpos=[0.,0.,0.,math.cos(angle/2),0.,0.,math.sin(angle/2)]+[0.]*8
    contacts=split_contacts(1,[0],[[1,0] if reverse else [0,1]],[-.01],[[1.,0.,0.]],nworld=1,capacity=1)[0]
    contacts[0]["frame"]=frame.reshape(-1).tolist()
    native=dict(cell=0,step=1,time_s=1/600,before_qpos=qpos,contacts=contacts)
    force_buffer=np.zeros(128);force_buffer[[0,3,7]]=[2.,1.,-.5]
    root_moment=np.cross([1.,0.,0.],sign*force)
    row=dict(schema_version=subject.SCHEMA,cell=0,step=1,time_s=native["time_s"],binding=binding.copy(),
        sampling_stage=subject.POLICY["sampling_stage"],cone=1,constraint_force=force_buffer.tolist(),
        generalized_constraint_force=np.concatenate((sign*force,rotation.T @ root_moment,np.zeros(8))).tolist(),
        center_of_mass=[0.,0.,0.],contacts=[dict(native_index=0,dim=3,friction=[.7,.7,0.,0.,0.],
            efc_address=[0,3,7]+[-1]*7,force_world=[*force,0.,0.,0.])])
    return row,native,binding,["ground"]+[f"body_{i}_geom" for i in range(1,10)]


class ReactionControls(unittest.TestCase):
    def setUp(self):
        traps=ExitStack();self.addCleanup(traps.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            traps.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in reaction controls")))

    def verify(self,row,native,binding,names):
        return subject.verify(row,native,binding,1,names)

    def test_01_decoder_matches_independent_native_pyramid_primitive(self):
        # The pinned Python wrapper passes mu.size() as dim, one too small.
        # Call the installed C primitive with its explicit contact dimension.
        native_library=ctypes.CDLL(str(Path(mujoco.__file__).parent/"mujoco.dll"))
        native_decode=native_library.mju_decodePyramid
        vector=np.ctypeslib.ndpointer(dtype=np.float64,ndim=1,flags="C_CONTIGUOUS")
        native_decode.argtypes=[vector,vector,vector,ctypes.c_int]
        native_decode.restype=None
        rng=np.random.default_rng(1061148)
        for dim in (1,3,4,6):
            for _ in range(24):
                friction=rng.uniform(.01,.9,5)
                count=1 if dim==1 else 2*(dim-1);pyramid=rng.uniform(0.,2.,count)
                raw=np.zeros(128);raw[5:5+count]=pyramid
                expected=np.zeros(6);native_decode(expected,pyramid,friction,dim)
                actual=subject.decode(raw.tolist(),[5]+[-1]*9,dim,friction.tolist(),0)
                np.testing.assert_allclose(actual,expected,rtol=1e-14,atol=1e-14)
        raw=np.arange(128,dtype=float);indices=[11,2,9,5,0,17]
        np.testing.assert_array_equal(subject.decode(raw,indices,6,[.7]*5,1),raw[indices])

    def test_02_world_frame_sign_and_local_free_joint_rotation(self):
        for reverse in (False,True):
            for angle in (0.,.7,math.pi/2):
                row,native,binding,names=fixture(reverse=reverse,angle=angle)
                result=self.verify(row,native,binding,names)
                sign=-1. if reverse else 1.
                np.testing.assert_allclose(result["force_by_geom"][1],sign*np.array([1.,-.5,2.]),atol=1e-14)
                np.testing.assert_allclose(result["moment_by_geom"][1],sign*np.array([0.,-2.,-.5]),atol=1e-14)

    def test_03_invalid_constraints_and_nonfinite_values_are_refused(self):
        base=dict(force=[0.]*128,addresses=[0,1,2]+[-1]*7,dim=3,friction=[.7]*5,cone=1)
        changes=[dict(dim=2),dict(dim=True),dict(cone=True),dict(cone=2),dict(friction=[-.1]*5),
                 dict(addresses=[0,0,1]),dict(addresses=[-2]*10),dict(addresses=[0,1,128]),
                 dict(force=[float("nan")]*128),dict(force=[0.]*127)]
        for change in changes:
            with self.assertRaises(ValueError):subject.decode(**dict(base,**change))
        with self.assertRaises(ValueError):subject.decode([0.]*128,[125]+[-1]*9,6,[.7]*5,0)
        np.testing.assert_array_equal(subject.decode([0.]*128,[-1]*10,3,[.7]*5,1),np.zeros(6))

    def test_04_crossed_missing_and_malformed_samples_are_refused(self):
        row,native,binding,names=fixture()
        changes=[lambda v:v.update(cell=1),lambda v:v.update(step=2),lambda v:v.update(time_s=0.),
                 lambda v:v.update(binding={}),lambda v:v.update(sampling_stage="prepared_before_control"),
                 lambda v:v.update(contacts=[]),lambda v:v["contacts"][0].update(native_index=1),
                 lambda v:v["contacts"][0].update(force_world=[0.]*6),
                 lambda v:v.update(center_of_mass=[float("nan")]*3)]
        for change in changes:
            broken=copy.deepcopy(row);change(broken)
            with self.assertRaises(ValueError):self.verify(broken,native,binding,names)
        for change in (lambda v:v["contacts"][0].update(geom=[1,2]),
                       lambda v:v["contacts"][0].update(frame=[0.]*9)):
            broken=copy.deepcopy(native);change(broken)
            with self.assertRaises(ValueError):self.verify(row,broken,binding,names)

    def test_05_free_root_reconciliation_and_inactive_contacts(self):
        row,native,binding,names=fixture()
        for index in (0,3,5):
            broken=copy.deepcopy(row);broken["generalized_constraint_force"][index]+=.01
            with self.assertRaisesRegex(ValueError,"free-root"):self.verify(broken,native,binding,names)
        row["contacts"][0].update(efc_address=[-1]*10,force_world=[0.]*6)
        row["generalized_constraint_force"]=[0.]*14
        np.testing.assert_array_equal(self.verify(row,native,binding,names)["force_by_geom"],np.zeros((10,3)))
        row["contacts"]=[];native["contacts"]=[]
        row["constraint_force"][0]=float("nan")
        with self.assertRaises(ValueError):self.verify(row,native,binding,names)

    def test_06_complete_stream_order_and_impulses(self):
        row,native,binding,names=fixture()
        c=dict(mode="route_ghost",capture_mode="full",righting_spec={},contact_reactions=subject.POLICY,
               cells=[dict(cell_id="reaction_fixture")],outer_steps=1,timestep_s=1/600)
        creature=dict(binding=binding,spec=dict(geom_names=names))
        reader=subject.Reader(c,[creature],[1])
        with self.assertRaises(ValueError):reader.finish()
        for step in range(1,6):
            row["step"]=native["step"]=step;row["time_s"]=native["time_s"]=step/600
            reader.consume(row,native)
        result=reader.finish();self.assertEqual(result["samples_verified"],5)
        np.testing.assert_allclose(result["cells"][0]["force_impulse_by_geom_ns"][1],np.array([1.,-.5,2.])/120,atol=1e-15)
        with self.assertRaises(ValueError):reader.consume(row,native)

    def test_07_real_engine_extractor_and_history_preserve_each_completed_step(self):
        import warp as wp
        import mujoco_warp as mjw
        from mujoco_warp._src.types import vec5
        wp.config.kernel_cache_dir=str(Path(os.environ["EXPLORER_TEST_OUTPUT"])/"reaction-warp-cache")
        wp.init()
        original_device=wp.get_device()
        def f(value,dtype=wp.float32):return wp.array(np.asarray(value),dtype=dtype,device="cpu")
        qpos=np.zeros((1,15));qpos[0,3]=1.
        contact=SimpleNamespace(worldid=f([0],wp.int32),geom=f([[0,1]],wp.vec2i),dist=f([-.01]),
            pos=f([[1.,0.,0.]],wp.vec3),frame=f([[[0.,0.,1.],[1.,0.,0.],[0.,1.,0.]]],wp.mat33),
            dim=f([3],wp.int32),friction=f([[.7,.7,0.,0.,0.]],vec5),
            efc_address=f([[0,1,2]+[-1]*7],wp.int32))
        data=SimpleNamespace(qpos=f(qpos),qvel=f(np.zeros((1,14))),ctrl=f(np.zeros((1,8))),
            sensordata=f(np.zeros((1,16))),time=f([0.]),nacon=f([1],wp.int32),nefc=f([3],wp.int32),
            overflow=f([0],wp.int32),contact=contact,naconmax=1,njmax=128,
            efc=SimpleNamespace(force=f(np.zeros((1,128)))),qfrc_constraint=f(np.zeros((1,14))),
            subtree_com=f(np.zeros((1,10,3)),wp.vec3))
        model=SimpleNamespace(opt=SimpleNamespace(cone=1));history=subject.History(wp,mjw,model,data)
        untouched={n:getattr(data,n).numpy().tobytes() for n in ("qpos","qvel","ctrl")}
        for sub in range(5):
            raw=np.zeros((1,128));raw[0,:3]=[sub+1.,1.,-.5]
            constraint=np.zeros((1,14));constraint[0,:6]=[1.,-.5,sub+1.,0.,-(sub+1.),-.5]
            wp.copy(data.efc.force,f(raw));wp.copy(data.qfrc_constraint,f(constraint))
            history.before(sub);history.after(sub)
        self.assertEqual(wp.get_device(),original_device)
        snapshots=history.read(dict(naconmax=1,njmax=128),1)
        self.assertEqual(len(snapshots),5)
        for sub,snap in enumerate(snapshots):
            np.testing.assert_allclose(snap["reaction.force_world"][0],[1.,-.5,sub+1.,0.,0.,0.],atol=0.)
            np.testing.assert_array_equal(snap["efc.force"][0,:3],[sub+1.,1.,-.5])
            _,native,binding,names=fixture()
            native.update(step=sub+1,time_s=(sub+1)/600,before_qpos=snap["before_qpos"][0].tolist(),
                          contacts=snap["contacts"][0])
            projected=subject.project(snap,native,binding,1)
            actual=self.verify(projected,native,binding,names)
            self.assertEqual(actual["force_balance_error"],0.)
            self.assertEqual(actual["moment_balance_error"],0.)
        self.assertEqual(untouched,{n:getattr(data,n).numpy().tobytes() for n in untouched})

    def test_08_capture_is_explicit_full_route_only_and_never_controller_input(self):
        c=dict(mode="route_ghost",capture_mode="full",righting_spec={},contact_reactions=copy.deepcopy(subject.POLICY))
        self.assertTrue(subject.enabled(c));self.assertIn("reactions",capture.streams(c,False))
        old=copy.deepcopy(c);old.pop("contact_reactions")
        self.assertFalse(subject.enabled(old));self.assertNotIn("reactions",capture.streams(old,False))
        for change in (lambda v:v.update(mode="development_discovery"),lambda v:v.update(capture_mode="compact_v1"),
                       lambda v:v["contact_reactions"].update(controller_input=True),
                       lambda v:v["contact_reactions"].update(every_internal_step=False),
                       lambda v:v["contact_reactions"].update(sampling_stage="prepared_before_control")):
            broken=copy.deepcopy(c);change(broken)
            with self.assertRaises(ValueError):subject.enabled(broken)


if __name__ == "__main__":
    unittest.main()
