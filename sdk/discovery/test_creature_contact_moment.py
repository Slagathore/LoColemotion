"""Independent distance minimizers, rigid-tree witnesses and refusal controls."""
import copy
from contextlib import ExitStack
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco
import numpy as np

import creature_contact_moment as subject
from creature_contact_envelope import orientation_grid
from creature_batch import bridge, compile_creature
from creature_righting import recovery_descriptor
from showcase_model import S169, generated


def convex_minimum(function):
    # Independent one-dimensional convex minimization, including endpoints.
    low,high=0.,1.;ratio=(math.sqrt(5)-1)/2
    left=high-ratio*(high-low);right=low+ratio*(high-low)
    fl,fr=function(left),function(right)
    for _ in range(90):
        if fl<fr:
            high,right,fr=right,left,fl
            left=high-ratio*(high-low);fl=function(left)
        else:
            low,left,fl=left,right,fr
            right=low+ratio*(high-low);fr=function(right)
    return math.sqrt(max(0.,min(fl,fr,function(0.),function(1.))))


def pair_reference(first,second):
    v=second[1]-second[0];den=float(v @ v)
    def distance(t):
        point=first[0]+t*(first[1]-first[0])
        u=float(np.clip((point-second[0]) @ v/den,0,1)) if den else 0.
        delta=point-second[0]-u*v
        return float(delta @ delta)
    return convex_minimum(distance)


def box_reference(segment,half):
    def distance(t):
        point=segment[0]+t*(segment[1]-segment[0])
        delta=point-np.clip(point,-half,half)
        return float(delta @ delta)
    return convex_minimum(distance)


class MomentControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))

    def setUp(self):
        trap=ExitStack();self.addCleanup(trap.close)
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            trap.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Physics in moment controls")))

    def spec(self,descriptor=S169):
        return compile_creature(self.core,descriptor,recovery_descriptor=recovery_descriptor(descriptor))["compiled"]["morphology"]["morphology_spec"]

    def test_segment_analytic_degenerate_parallel_and_near_parallel_cases(self):
        a=np.array([[[0.,0.,0.],[1.,0.,0.]]]*6)
        b=np.array([[[.5,-1.,0.],[.5,1.,0.]],[[0.,2.,0.],[1.,2.,0.]],
                    [[2.,0.,0.],[3.,0.,0.]],[[.5,0.,3.],[.5,0.,3.]],
                    [[0.,-1e-12,0.],[1.,1e-12,0.]],[[.2,0.,0.],[.8,0.,0.]]])
        np.testing.assert_allclose(subject.segment_segment_distance(a,b),[0.,2.,1.,3.,0.,0.],rtol=0,atol=1e-14)
        np.testing.assert_allclose(subject.segment_segment_distance(b,a),[0.,2.,1.,3.,0.,0.],rtol=0,atol=1e-14)
        self.assertEqual(subject.segment_segment_distance(np.zeros((1,2,3)),np.ones((1,2,3)))[0],math.sqrt(3))

    def test_segment_random_minima_match_independent_convex_search(self):
        rng=np.random.Generator(np.random.PCG64(1061130))
        a=rng.uniform(-2,2,(128,2,3));b=rng.uniform(-2,2,(128,2,3))
        actual=subject.segment_segment_distance(a,b)
        expected=[pair_reference(x,y) for x,y in zip(a,b)]
        np.testing.assert_allclose(actual,expected,rtol=0,atol=2e-12)
        transform=np.array([[0.,-1.,0.],[0.,0.,1.],[-1.,0.,0.]])
        np.testing.assert_allclose(actual,subject.segment_segment_distance(a @ transform+7.,b @ transform+7.),rtol=0,atol=3e-15)

    def test_box_analytic_inside_crossing_face_edge_and_point_cases(self):
        lines=np.array([[[0.,0.,0.],[.5,.5,.5]],[[-2.,0.,0.],[2.,0.,0.]],
                        [[-2.,2.,0.],[2.,2.,0.]],[[2.,2.,2.],[3.,3.,3.]],
                        [[2.,0.,0.],[2.,0.,0.]],[[1.,-2.,0.],[1.,2.,0.]]])
        np.testing.assert_allclose(subject.segment_box_distance(lines,[1.,1.,1.]),[0.,0.,1.,math.sqrt(3),1.,0.],rtol=0,atol=1e-14)

    def test_box_random_minima_match_independent_convex_search(self):
        rng=np.random.Generator(np.random.PCG64(1061131));half=np.array([.4,.7,1.1])
        values=rng.uniform(-2,2,(128,2,3))
        expected=[box_reference(x,half) for x in values]
        np.testing.assert_allclose(subject.segment_box_distance(values,half),expected,rtol=0,atol=2e-12)
        np.testing.assert_allclose(subject.segment_box_distance(-values[:,:,::-1],half[::-1]),expected,rtol=0,atol=2e-12)

    def test_moment_sign_friction_bounds_and_center_of_mass(self):
        points=np.array([[[1.,-2.,0.],[-1.,-2.,0.],[0.,-2.,0.]]])
        n,low,high=subject.moment_bounds(points,[[0.,0.,0.]],[0.,1.,0.],[0.,0.,1.],.5)
        np.testing.assert_allclose(n,[[1.,-1.,0.]],atol=0,rtol=0)
        np.testing.assert_allclose(low,[[0.,-2.,-1.]],atol=0,rtol=0)
        np.testing.assert_allclose(high,[[2.,0.,1.]],atol=0,rtol=0)
        shifted=subject.moment_bounds(points,[[.5,0.,0.]],[0.,1.,0.],[0.,0.,1.],0.)
        np.testing.assert_allclose(shifted[0],n-.5,rtol=0,atol=0)
        neg=subject.moment_bounds(points,[[0.,0.,0.]],[0.,1.,0.],[0.,0.,-1.],.5)
        np.testing.assert_allclose(neg[2],-low,rtol=0,atol=0)

    def test_contact_moments_match_scalar_world_tree_over_32_bodies(self):
        rng=np.random.Generator(np.random.PCG64(1061132))
        poses=np.vstack((np.zeros(8),np.full(8,.9),np.full(8,-.9),rng.uniform(-.9,.9,(5,8))))
        for descriptor in [S169]+[generated(i) for i in range(15000,15031)]:
            spec=self.spec(descriptor);model=subject.PoseContacts(spec,poses)
            for axis in ([1.,0.,0.],[0.,0.,1.]):
                for up in orientation_grid([0.,15.,45.,90.],axis):
                    actual=model.evaluate(up,axis,.8)
                    for i,pose in enumerate(poses):
                        expected=subject.scalar_features(spec,pose,up,axis,.8)
                        self.assertAlmostEqual(actual["floor_height_m"][i],expected["floor_height_m"],places=13)
                        for name in ("normal","friction"):
                            np.testing.assert_allclose(actual[name][i],expected[name],atol=3e-12,rtol=0)
                        for key in actual["masks"]:self.assertEqual(int(actual["masks"][key][i]),expected["masks"][key])

    def test_clearance_pairs_exclude_only_connected_bodies_and_detect_overlap(self):
        spec=self.spec();model=subject.PoseContacts(spec,np.zeros((1,8)))
        self.assertEqual(len(model.pairs),28)
        self.assertTrue(model.clear[0])
        self.assertNotIn((0,1),model.pairs);self.assertNotIn((1,2),model.pairs)
        self.assertIn((0,2),model.pairs);self.assertIn((1,3),model.pairs)
        spec["joints"][2]["anchor_parent_m"]=copy.deepcopy(spec["joints"][0]["anchor_parent_m"])
        folded=subject.PoseContacts(spec,np.zeros((1,8)))
        self.assertFalse(folded.clear[0])
        self.assertLess(folded.gaps[0,folded.pairs.index((1,3))],-.01)

    def test_clearance_gaps_match_independent_scalar_distances(self):
        poses=np.random.Generator(np.random.PCG64(1061133)).uniform(-.9,.9,(8,8))
        model=subject.PoseContacts(self.spec(),poses)
        for pi in range(len(poses)):
            for i,(left,right) in enumerate(model.pairs):
                if left==0:
                    expected=box_reference(model.ends[right][pi],model.geometry.shapes[0][1])-model.geometry.shapes[right][1][1]
                else:
                    expected=pair_reference(model.ends[left][pi],model.ends[right][pi])-model.geometry.shapes[left][1][1]-model.geometry.shapes[right][1][1]
                self.assertAlmostEqual(model.gaps[pi,i],expected,places=12)

    def test_tied_support_features_input_ownership_and_summary_counts(self):
        spec=self.spec();poses=np.array([[0.]*8,[.9]*8,[-.9]*8])
        model=subject.PoseContacts(spec,poses);up=[0.,-1.,0.];axis=[0.,0.,1.]
        result=model.evaluate(up,axis,.8)
        self.assertEqual(int(result["masks"]["contact"][0]),1)
        self.assertEqual(int(result["contact_features"][0].sum()),4)
        groups,_=model.summary(result,axis)
        mask=int(sum(1<<x for x in model.distal))
        expected=(result["masks"]["normal_positive"]&mask)!=0
        self.assertEqual(groups["distal_all"]["clear_positive_normal_poses"],int(np.count_nonzero(expected&model.clear)))
        poses[:]=0.;spec["bodies"][0]["mass_kg"]=1000.
        np.testing.assert_array_equal(result["normal"],model.evaluate(up,axis,.8)["normal"])
        with self.assertRaises(ValueError):model.minimum_gap[0]=0.
        result["normal"][:]=0.
        self.assertFalse(np.all(model.evaluate(up,axis,.8)["normal"]==0.))

    def test_invalid_geometry_numeric_and_force_domains_refuse(self):
        for values in ([],[[[True]*3]*2],[[[math.nan]*3]*2],np.zeros((1,3,3))):
            with self.assertRaises(ValueError):subject.segment_segment_distance(values,values)
        with self.assertRaises(ValueError):subject.segment_box_distance(np.zeros((1,2,3)),[1.,0.,1.])
        for axis,mu in (([0.,2.,0.],.8),([0.,1.,0.],.8),([0.,0.,1.],True),([0.,0.,1.],-1.)):
            with self.assertRaises(ValueError):subject.moment_bounds(np.zeros((1,1,3)),[[0.,0.,0.]],[0.,1.,0.],axis,mu)
        wrong=self.spec();wrong["bodies"][1]["collision"]={"kind":"box","size_m":{"x":.1,"y":.1,"z":.1}}
        with self.assertRaises(ValueError):subject.PoseContacts(wrong,np.zeros((1,8)))



    def test_declaration_scope_and_population_changes_refuse(self):
        import json
        here=Path(subject.__file__).parent
        c=subject.declaration(here/"creature_contact_moment_v1.json")
        artifact=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"moment-declaration-controls";artifact.mkdir()
        for i,(key,value) in enumerate((("trained",True),("physical_started",True),
                ("release_authority",True),("dynamic_feasibility_established",True),
                ("body_count",333),("friction_coefficient",1.))):
            forged=copy.deepcopy(c);forged[key]=value
            path=artifact/f"bad_{i}.json";path.write_text(json.dumps(forged),encoding="utf-8")
            with self.assertRaises(ValueError):subject.declaration(path)

    def test_retained_native_xml_policy_and_digest_refusals(self):
        import hashlib
        creature=compile_creature(self.core,S169,recovery_descriptor=recovery_descriptor(S169))
        self.assertEqual(subject.native_filter(creature),dict(robot_self_collisions_enabled=False,
                         ground_collisions_enabled=True,sliding_friction_coefficient=.95))
        wrong=copy.deepcopy(creature);wrong["model_xml"]+=" "
        with self.assertRaises(ValueError):subject.native_filter(wrong)
        wrong=copy.deepcopy(creature);wrong["model_xml"]=wrong["model_xml"].replace('contype="2"','contype="3"')
        wrong["binding"]["model_xml_sha256"]=hashlib.sha256(wrong["model_xml"].encode()).hexdigest()
        with self.assertRaises(ValueError):subject.native_filter(wrong)

    def test_retained_input_corruption_and_archive_escape_refuse(self):
        import hashlib,json
        folder=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"moment-archive-controls";folder.mkdir()
        archive=folder/"retained";(archive/"computation").mkdir(parents=True)
        owner=dict(ok=True,source_runtime_unchanged=True,world_build_count=0,solver_steps=0,physical_started=False)
        result=dict(ok=True,world_build_count=0,solver_steps=0)
        for name,value in (("receipt.json",owner),("declaration.json",{}),("computation/result.json",result)):
            (archive/name).write_text(json.dumps(value),encoding="utf-8")
        digest=lambda name:hashlib.sha256((archive/name).read_bytes()).hexdigest()
        reference=dict(archive_relative_path="retained",receipt_sha256=digest("receipt.json"),
            declaration_sha256=digest("declaration.json"),result_sha256=digest("computation/result.json"))
        self.assertEqual(subject.read_archive(reference,folder)[0],archive.resolve())
        (archive/"computation/result.json").write_text("{}",encoding="utf-8")
        with self.assertRaises(ValueError):subject.read_archive(reference,folder)
        reference["archive_relative_path"]="../retained"
        with self.assertRaises(ValueError):subject.read_archive(reference,folder)


if __name__=="__main__":
    unittest.main()
