"""Finite-difference, contact-witness, fallback and profile-boundary controls."""
import copy
import unittest
import numpy as np
import contact_posture_reference as p
from contact_posture_force_policy import make_profile,Policy,PROVIDER
from audit_support_reach_native_closure import ROOT,CLOSURE,read


class PostureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        record=read(CLOSURE)
        folder=ROOT.parent/"SporeSpore_Evidence"/record["attempt_id"]/"physical/force_hold_nominal_train_001"
        cls.compiled=read(folder/"compiled.json");cls.inputs=read(folder/"inputs.json")
        cls.spec=cls.compiled["morphology"]["morphology_spec"]

    def setup_state(self,neutral=False):
        model=p.PostureReference(self.spec);position=np.array([.1,.44,-.2]);orientation=np.array([0.,0.,0.,1.])
        joints=np.zeros(8) if neutral else np.array([-.2,.4]*4)
        frame=model.tree.kinematics(position,orientation,joints);contacts=[]
        for site,definition in model.sites.items():
            index=model.tree.index[definition["body_id"]]
            point=frame["positions"][index]+frame["rotations"][index]@p.m.xyz(definition["local_center_m"])-[0.,definition["radius_m"],0.]
            contacts.append(dict(contact_site_id=site,presence=True,bears_support=True,
                point_world_m=dict(zip("xyz",point)),normal_world_unit=dict(x=0.,y=1.,z=0.)))
        return model,position,orientation,joints,frame,contacts

    def test_point_jacobian_matches_all_fourteen_finite_differences(self):
        model,pos,ori,q,frame,_=self.setup_state();tree=model.tree;body="front_right_distal";i=tree.index[body]
        local=np.array([.013,-.08,.007]);point=frame["positions"][i]+frame["rotations"][i]@local
        jac=p.point_jacobian(tree,frame,body,point);numeric=np.zeros_like(jac);eps=1e-7
        for j in range(14):
            delta=np.eye(14)[j]*eps
            values=[]
            for sign in (1,-1):
                state=p.retract(pos,ori,q,sign*delta);f=tree.kinematics(*state)
                values.append(f["positions"][i]+f["rotations"][i]@local)
            numeric[:,j]=(values[0]-values[1])/(2*eps)
        np.testing.assert_allclose(jac,numeric,rtol=0,atol=1e-8)

    def test_com_jacobian_matches_all_fourteen_finite_differences(self):
        model,pos,ori,q,frame,_=self.setup_state();jac=p.com_jacobian(model.tree,frame);numeric=np.zeros_like(jac);eps=1e-7
        for j in range(14):
            delta=np.eye(14)[j]*eps
            values=[model.tree.kinematics(*p.retract(pos,ori,q,sign*delta))["whole_body_com"] for sign in (1,-1)]
            numeric[:,j]=(values[0]-values[1])/(2*eps)
        np.testing.assert_allclose(jac,numeric,rtol=0,atol=1e-8)

    def test_world_rotation_retraction_and_quaternion_sign(self):
        model,pos,ori,q,_,_=self.setup_state();delta=np.zeros(14);delta[3:6]=[.1,-.2,.3]
        a=p.retract(pos,ori,q,delta);b=p.retract(pos,-ori,q,delta)
        np.testing.assert_allclose(p.m.quaternion_rotation(a[1]),p.m.quaternion_rotation(b[1]),atol=1e-12)
        np.testing.assert_allclose(p.orientation_vector(a[1]),delta[3:6],atol=1e-12)

    def test_bounded_reference_has_linear_and_nonlinear_contact_witness(self):
        model,pos,ori,q,frame,contacts=self.setup_state()
        r=model.compute(pos,ori,q,contacts,frame["whole_body_com"]+[.02,-.04,.01],[0.]*8)
        self.assertEqual(r["status"],"solved");reference=r["reference_joint_positions_rad"]
        self.assertTrue((reference>=model.bounds[:,0]-p.TOL).all() and (reference<=model.bounds[:,1]+p.TOL).all())
        self.assertLessEqual(r["nonlinear_witness"]["maximum_contact_displacement_m"],.0005)
        self.assertFalse(r["dynamic_feasibility_established"]);self.assertFalse(r["root_motion_issued"])

    def test_observed_joint_limit_violation_is_explicit_fallback(self):
        model,pos,ori,q,frame,contacts=self.setup_state();q[0]=-.73
        r=model.compute(pos,ori,q,contacts,frame["whole_body_com"],[0.]*8)
        self.assertEqual(r["status"],"observed_joint_limit_violation")
        self.assertEqual(r["reference_joint_positions_rad"],[0.]*8)
        self.assertFalse(r["linear_contact_verified"]);self.assertEqual(r["observed_out_of_bounds_joint_indices"],[0])

    def test_unsupported_state_does_not_claim_floating_base_control(self):
        model,pos,ori,q,frame,contacts=self.setup_state()
        for r in contacts:r.update(presence=False,bears_support=False)
        r=model.compute(pos,ori,q,contacts,frame["whole_body_com"],[0.]*8)
        self.assertEqual(r["status"],"unsupported");self.assertTrue(r["legacy_bounded_reference_used"])
        self.assertFalse(r["nonlinear_contact_verified"])

    def test_missing_reordered_or_invalid_contact_flags_refused(self):
        model,pos,ori,q,frame,contacts=self.setup_state()
        for changed in (contacts[:-1],list(reversed(contacts))):
            with self.assertRaises(ValueError):model.compute(pos,ori,q,changed,frame["whole_body_com"],[0.]*8)
        changed=copy.deepcopy(contacts);changed[0]["presence"]=False
        with self.assertRaises(ValueError):model.compute(pos,ori,q,changed,frame["whole_body_com"],[0.]*8)

    def test_invalid_orientation_normal_or_fallback_refused(self):
        model,pos,ori,q,frame,contacts=self.setup_state()
        with self.assertRaises(ValueError):model.compute(pos,[0,0,0,0],q,contacts,frame["whole_body_com"],[0.]*8)
        changed=copy.deepcopy(contacts);changed[0]["normal_world_unit"]["y"]=.9
        with self.assertRaises(ValueError):model.compute(pos,ori,q,changed,frame["whole_body_com"],[0.]*8)
        with self.assertRaises(ValueError):model.compute(pos,ori,q,contacts,frame["whole_body_com"],[10.]*8)

    def test_straight_leg_singularity_retains_low_priority_bent_reference(self):
        model,pos,ori,q,frame,contacts=self.setup_state(neutral=True)
        r=model.compute(pos,ori,q,contacts,frame["whole_body_com"]+[0.,-.03,0.],[0.]*8)
        self.assertEqual(r["status"],"solved")
        self.assertGreater(np.linalg.norm(r["reference_joint_positions_rad"]),1e-6)
        self.assertFalse(r["nonlinear_priority_guaranteed"])
        self.assertTrue(r["virtual_base_is_not_actuated"])

    def test_distinct_profile_binds_posture_parameters_and_sources(self):
        profile=make_profile(self.compiled,self.inputs)
        self.assertEqual(profile["posture_parameters"],p.parameters())
        self.assertIn("contact_posture_reference.py",profile["source_bindings"])
        self.assertEqual(PROVIDER,"configured_contact_posture_recovery_v1")
        self.assertFalse(profile["physical_acceptance_authority"])

    def test_profile_parameter_or_source_mutation_refused(self):
        profile=make_profile(self.compiled,self.inputs)
        for key in ("posture_parameters","source_bindings"):
            changed=copy.deepcopy(profile);changed[key]={}
            with self.assertRaises(ValueError):Policy(object(),changed)

    def test_unrelated_morphology_cannot_use_declared_reference(self):
        spec=copy.deepcopy(self.spec);spec["joints"][0]["axis_parent_unit"]={"x":1.,"y":0.,"z":0.}
        with self.assertRaises(ValueError):p.PostureReference(spec)

    def test_all_retained_posture_inputs_preserve_numerical_constraints(self):
        import json
        record=read(CLOSURE)
        root=ROOT.parent/"SporeSpore_Evidence"/record["attempt_id"]/"physical"
        for trial in ("reach_hold_left_075_train_001","reach_hold_nominal_train_001"):
            model=p.PostureReference(self.spec);count=0
            with (root/trial/"controller.jsonl").open(encoding="utf-8") as stream:
                for step,line in enumerate(stream):
                    if step<60:continue
                    row=json.loads(line);state=row["request"]["state"];pose=state["base_pose_world"]
                    contacts=row["resolution_request"]["provider_request"]["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
                    decision=row["force_reference"]["decision"]
                    with self.subTest(trial=trial,command=step):
                        r=model.compute(p.m.xyz(pose["position_m"]),[pose["orientation_xyzw"][k] for k in "xyzw"],
                            [j["position_rad"] for j in state["ordered_joint_observations"]],contacts,
                            decision["target_com"],decision["support_reference"]["reference_joint_positions_rad"])
                        ref=np.array(r["reference_joint_positions_rad"])
                        self.assertTrue((ref>=model.bounds[:,0]-p.TOL).all() and (ref<=model.bounds[:,1]+p.TOL).all())
                        if r["status"]=="solved":
                            self.assertLessEqual(r["nonlinear_witness"]["maximum_contact_displacement_m"],.0005)
                            self.assertLessEqual(np.max(abs(r["linear_solution"]["linear_contact_residual"]),initial=0),p.TOL)
                        else:self.assertFalse(r["linear_contact_verified"])
                    count+=1
            self.assertEqual(count,1380)


if __name__=="__main__":unittest.main()
