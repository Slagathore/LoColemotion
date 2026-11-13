"""Analytic reach, scalar-witness and refusal controls; no simulator may open."""
import copy
from contextlib import ExitStack
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco
import numpy as np
import creature_contact_envelope as subject
from actuation_recovery_mechanics import quaternion_rotation
from creature_batch import bridge, compile_creature
from creature_contact_reach import LimbGeometry
from creature_righting import recovery_descriptor
from showcase_model import S169, generated


class EnvelopeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))

    def setUp(self):
        trap = ExitStack(); self.addCleanup(trap.close)
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in reach controls")))

    def spec(self, descriptor=S169):
        return compile_creature(self.core, descriptor, recovery_descriptor=recovery_descriptor(descriptor))["compiled"]["morphology"]["morphology_spec"]

    def test_exact_interior_edges_and_flat_sinusoids(self):
        co = [[4.,-1.,0.,-2.,0.], [7.,0.,0.,0.,0.], [0.,0.,0.,1.,0.], [0.,1.,0.,0.,0.]]
        values, angles = subject.minimum_height(co, [[-1.44,1.44],[-.99,.99]])
        np.testing.assert_allclose(values, [1.,7.,math.cos(2.43),math.cos(1.44)],rtol=0,atol=2e-15)
        np.testing.assert_allclose(angles[0],[0.,0.],rtol=0,atol=1e-15)
        value,_=subject.minimum_height([[0.,0.,1.,0.,0.]], [[-math.pi/2,math.pi/2],[-.4,.3]])
        self.assertAlmostEqual(value[0],-1.,places=15)

    def test_random_rectangles_bound_an_independent_dense_grid(self):
        rng=np.random.Generator(np.random.PCG64(1061126))
        for _ in range(64):
            co=rng.uniform(-2.,2.,(1,5))
            bounds=np.sort(rng.uniform(-math.pi,math.pi,(2,2)),axis=1)
            actual,angles=subject.minimum_height(co,bounds)
            h=np.linspace(*bounds[0],201)[:,None];k=np.linspace(*bounds[1],201)[None,:]
            c,a,b,d,e=co[0]
            grid=c+a*np.cos(h)+b*np.sin(h)+d*np.cos(h+k)+e*np.sin(h+k)
            self.assertLessEqual(actual[0],float(grid.min())+1e-12)
            dh,dk=(bounds[:,1]-bounds[:,0])/400
            lipschitz=(math.hypot(a,b)+math.hypot(d,e))*dh+math.hypot(d,e)*dk
            self.assertLessEqual(float(grid.min())-actual[0],lipschitz+1e-12)
            wh,wk=angles[0]
            self.assertAlmostEqual(actual[0],c+a*math.cos(wh)+b*math.sin(wh)+d*math.cos(wh+wk)+e*math.sin(wh+wk),places=12)

    def test_compiled_32_body_witnesses_match_scalar_tree_and_bound_grid(self):
        quaternions=np.array([[0.,0.,0.,1.],[1.,0.,0.,0.],[.3,.5,-.2,.8],[-.7,.1,.4,.2]])
        quaternions/=np.linalg.norm(quaternions,axis=1)[:,None]
        rotations=[quaternion_rotation(q) for q in quaternions]
        up=np.array([r[1] for r in rotations])
        for descriptor in [S169]+[generated(i) for i in range(13000,13031)]:
            spec=self.spec(descriptor);model=subject.ContactEnvelope(spec);grid=LimbGeometry(spec)
            for limb in range(4):
                for domain in subject.DOMAINS:
                    result=model.evaluate(up,limb,domain)
                    sign=1 if grid.hips[limb,0]>=0 else -1
                    if domain=="inward":sign=-sign
                    allowed=np.ones(len(grid.poses),bool) if domain=="all" else np.all(grid.poses*sign>=-1e-12,axis=1)
                    for i,(q,r) in enumerate(zip(quaternions,rotations)):
                        height=result["evaluated_root_height_m"][i]
                        joints=np.zeros(8);joints[2*limb:2*limb+2]=result["witness_joint_angles_rad"][i]
                        frame=model.tree.kinematics([0.,height,0.],q,joints)
                        bi=model.limbs[limb]["distal"];shape=model.tree.bodies[bi]["collision"]
                        center=frame["positions"][bi];offset=frame["rotations"][bi][:,1]*shape["length_m"]/2
                        scalar=min((center-offset)[1],(center+offset)[1])-shape["radius_m"]
                        self.assertAlmostEqual(scalar,result["minimum_capsule_clearance_m"][i],places=12)
                        candidate=grid.candidates(limb,np.array([0.,height,0.]),r)
                        self.assertLessEqual(scalar,float(candidate[allowed,1].min()-grid.radii[limb])+2e-12)

    def test_inverted_reach_has_a_separate_link_length_formula(self):
        spec=self.spec();model=subject.ContactEnvelope(spec)
        expected=.06+spec["bodies"][1]["collision"]["length_m"]*math.cos(.9*1.6)
        expected+=spec["bodies"][2]["collision"]["length_m"]*math.cos(.9*(1.6+1.1))
        expected-=spec["bodies"][2]["collision"]["radius_m"]
        self.assertAlmostEqual(model.evaluate([[0.,-1.,0.]],0)["minimum_capsule_clearance_m"][0],expected,places=14)

    def test_asymmetric_limits_offsets_and_ownership(self):
        spec=self.spec();spec["joints"][0].update(lower_limit_rad=-.8,upper_limit_rad=1.3)
        spec["joints"][1]["anchor_parent_m"]["z"]=.012
        spec["joints"][1]["anchor_child_m"]["x"]=.017
        model=subject.ContactEnvelope(spec)
        up=np.array([[0.,-1.,0.],[.6,.8,0.]])
        before=model.evaluate(up,0)
        for i,theta in enumerate((math.pi,math.atan2(.6,.8))):
            q=[0.,0.,math.sin(theta/2),math.cos(theta/2)]
            joints=np.zeros(8);joints[:2]=before["witness_joint_angles_rad"][i]
            f=model.tree.kinematics([0.,before["evaluated_root_height_m"][i],0.],q,joints)
            shape=model.tree.bodies[2]["collision"]
            offset=f["rotations"][2][:,1]*shape["length_m"]/2
            scalar=min((f["positions"][2]-offset)[1],(f["positions"][2]+offset)[1])-shape["radius_m"]
            self.assertAlmostEqual(scalar,before["minimum_capsule_clearance_m"][i],places=12)
        spec["joints"][0]["upper_limit_rad"]=.1
        up[:]=0.
        again=model.evaluate([[0.,-1.,0.],[.6,.8,0.]],0)
        np.testing.assert_array_equal(before["minimum_capsule_clearance_m"],again["minimum_capsule_clearance_m"])
        angles=again["witness_joint_angles_rad"]
        self.assertTrue(np.all((angles[:,0]>=-.72-1e-12)&(angles[:,0]<=1.17+1e-12)))
        again["minimum_capsule_clearance_m"][:]=99.
        np.testing.assert_array_equal(before["minimum_capsule_clearance_m"],model.evaluate([[0.,-1.,0.],[.6,.8,0.]],0)["minimum_capsule_clearance_m"])

    def test_principal_rotation_grid_matches_rigid_rotations(self):
        from actuation_recovery_mechanics import rotation
        for axis in ([1.,0.,0.],[-1.,0.,0.],[0.,0.,1.],[0.,0.,-1.]):
            angles=[0.,15.,45.,90.,135.,180.]
            up=subject.orientation_grid(angles,axis)
            expected=np.array([rotation(axis,-math.radians(a)) @ [0.,-1.,0.] for a in angles])
            np.testing.assert_allclose(up,expected,rtol=0,atol=1e-15)

    def test_nonplanar_models_and_invalid_numeric_domains_refuse(self):
        model=subject.ContactEnvelope(self.spec())
        for up in ([[0.,0.,0.]],[[True,False,False]],[[0.,math.nan,0.]],[]):
            with self.assertRaises(ValueError):model.evaluate(up,0)
        for limb,domain in ((True,"all"),(4,"all"),(0,"unknown")):
            with self.assertRaises(ValueError):model.evaluate([[0.,-1.,0.]],limb,domain)
        for co,bounds in (([[True]*5],[[-1,1],[-1,1]]),([[0.,0.,0.,math.inf,0.]],[[-1,1],[-1,1]]),
                          ([[0.]*5],[[-4,1],[-1,1]]),([[0.]*5],[[0,0],[-1,1]])):
            with self.assertRaises(ValueError):subject.minimum_height(co,bounds)
        wrong=self.spec();wrong["joints"][1]["axis_parent_unit"]=dict(x=1.,y=0.,z=0.)
        with self.assertRaises(ValueError):subject.ContactEnvelope(wrong)
        for axis in ([0.,1.,0.],[2.,0.,0.]):
            with self.assertRaises(ValueError):subject.orientation_grid([0.,90.],axis)
        with self.assertRaises(ValueError):subject.orientation_grid([181.],[1.,0.,0.])

    def test_height_translation_does_not_claim_floor_feasibility(self):
        model=subject.ContactEnvelope(self.spec());up=subject.orientation_grid([0.,30.,60.],[1.,0.,0.])
        floor=model.evaluate(up,0)
        shifted=model.evaluate(up,0,root_height_m=floor["evaluated_root_height_m"]+.1)
        np.testing.assert_allclose(shifted["minimum_capsule_clearance_m"]-floor["minimum_capsule_clearance_m"],.1,rtol=0,atol=1e-15)
        self.assertGreater(model.evaluate([[0.,-1.,0.]],0,root_height_m=[10.])["minimum_capsule_clearance_m"][0],9.)

    def test_declared_body_population_and_scope_refusals(self):
        import json
        from showcase_model import FIELDS
        here=Path(subject.__file__).parent
        c=subject.declaration(here/"creature_contact_envelope_v1.json")
        native=json.loads((here/"creature_torso_target_v1.json").read_bytes())
        inherited=native["righting_spec"]["descriptors"]
        pool,duplicates=subject.body_population(inherited,list(FIELDS),14000,256)
        self.assertEqual(len(pool),334);self.assertEqual(len(duplicates),2)
        self.assertEqual([sum(x["origin"]==o for x in pool) for o in ("retained","corner","generated")],[16,62,256])
        self.assertEqual((pool,duplicates),subject.body_population(inherited,list(FIELDS),14000,256))
        before=copy.deepcopy(inherited)
        pool[0]["descriptor"]["torso_length_scale"]=1.
        self.assertEqual(inherited,before)
        artifact=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"envelope-declaration-controls"
        artifact.mkdir()
        for i,field in enumerate(("physical_started","trained","release_authority","dynamic_feasibility_established")):
            forged=copy.deepcopy(c);forged[field]=True
            path=artifact/f"bad_{i}.json";path.write_text(json.dumps(forged),encoding="utf-8")
            with self.assertRaises(ValueError):subject.declaration(path)
        with self.assertRaises(ValueError):subject.body_population(inherited,list(FIELDS),0,True)
        with self.assertRaises(ValueError):subject.body_population(inherited,list(reversed(FIELDS)),0,1)

    def test_retained_archive_corruption_and_traversal_refuse(self):
        import hashlib,json
        folder=Path(os.environ["EXPLORER_TEST_OUTPUT"])/"envelope-binding-controls";folder.mkdir()
        archive=folder/"retained";archive.mkdir()
        receipt=archive/"receipt.json";audit=archive/"independent-audit.json"
        receipt.write_text(json.dumps(dict(ok=True,audit=dict(ok=True),source_runtime_unchanged=True)),encoding="utf-8")
        audit.write_text("{}",encoding="utf-8")
        digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
        reference={"search":dict(archive_relative_path="retained",receipt_sha256=digest(receipt),independent_audit_sha256=digest(audit))}
        self.assertEqual(subject.bound_archive(reference,"search",folder)[0],archive.resolve())
        audit.write_text("[]",encoding="utf-8")
        with self.assertRaises(ValueError):subject.bound_archive(reference,"search",folder)
        wrong=copy.deepcopy(reference);wrong["search"]["archive_relative_path"]="../retained"
        with self.assertRaises(ValueError):subject.bound_archive(wrong,"search",folder)


if __name__=="__main__":
    unittest.main()
