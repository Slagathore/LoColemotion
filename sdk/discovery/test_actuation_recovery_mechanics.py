"""Analytical and corruption controls for portable recovery mechanics; zero worlds."""
import copy
import math
import unittest
import numpy as np
import actuation_recovery_mechanics as m


def vector(x,y,z):return dict(x=x,y=y,z=z)


def specimen():
    bodies=[dict(body_id=name,parent_body_id=parent,mass_kg=mass,
        center_of_mass_local_m=vector(0. if i==0 else .5,0.,0.),
        inertia_diagonal_kg_m2=vector(1.,1.,1.))
        for i,(name,parent,mass) in enumerate((("root",None,1.),("upper","root",2.),("distal","upper",3.)))]
    joints=[dict(joint_id=name,parent_body_id=parent,child_body_id=child,joint_type="revolute",
        anchor_parent_m=vector(1.,0.,0.),anchor_child_m=vector(0.,0.,0.),
        axis_parent_unit=vector(0.,0.,1.),lower_limit_rad=-math.pi,upper_limit_rad=math.pi,
        passive_damping_nms_per_rad=0.)
        for name,parent,child in (("hip","root","upper"),("knee","upper","distal"))]
    return dict(schema_version="sporespore_morphology_spec_v1",
        coordinate_frame_id="right_handed_x_forward_y_up_z_right_si_v1",bodies=bodies,joints=joints)


class MechanicsControls(unittest.TestCase):
    def setUp(self):
        self.model=m.RigidTree(specimen())
        self.frame=self.model.kinematics([0.,0.,0.],[0.,0.,0.,1.],[0.,0.])

    def close(self,a,b,tol=1e-10):np.testing.assert_allclose(a,b,rtol=tol,atol=tol)

    def test_zero_pose_anchors_centers_and_mass_weighted_center(self):
        self.close(self.frame["positions"],[[0,0,0],[1,0,0],[2,0,0]])
        self.close(self.frame["anchors"],[[1,0,0],[2,0,0]])
        self.close(self.frame["centers"],[[0,0,0],[1.5,0,0],[2.5,0,0]])
        self.close(self.frame["whole_body_com"],[1.75,0,0])

    def test_child_rotates_about_parent_anchor(self):
        f=self.model.kinematics([0,0,0],[0,0,0,1],[math.pi/2,0])
        self.close(f["positions"],[[0,0,0],[1,0,0],[1,1,0]])
        self.close(f["centers"][2],[1,1.5,0])

    def test_nonzero_child_anchor_preserves_shared_joint(self):
        spec=specimen();spec["joints"][0]["anchor_child_m"]=vector(.2,.3,.4)
        model=m.RigidTree(spec);f=model.kinematics([.1,.2,.3],[0,0,0,1],[.7,-.4])
        self.close(f["positions"][1]+f["rotations"][1] @ m.xyz(spec["joints"][0]["anchor_child_m"]),
                   f["anchors"][0])

    def test_force_and_free_contact_torque_have_correct_sign(self):
        w=dict(body_id="distal",point=[2.5,0,0],force=[0,3,0],torque=[0,0,2])
        self.close(self.model.wrench_torques(self.frame,[w]),[6.5,3.5])
        w["force"]=[0,-3,0];w["torque"]=[0,0,-2]
        self.close(self.model.wrench_torques(self.frame,[w]),[-6.5,-3.5])

    def test_root_force_and_unrelated_joint_have_zero_generalized_effect(self):
        w=dict(body_id="root",point=[2.5,0,0],force=[0,3,0],torque=[0,0,2])
        self.close(self.model.wrench_torques(self.frame,[w]),[0,0])
        w["body_id"]="upper"
        self.close(self.model.wrench_torques(self.frame,[w]),[6.5,0])

    def test_equal_opposite_internal_contact_preserves_joint_effect(self):
        w=dict(body_id="distal",point=[2.5,0,0],force=[0,3,0],torque=[0,0,0])
        other=dict(w,body_id="upper",force=[0,-3,0])
        self.close(self.model.wrench_torques(self.frame,[w,other]),[0,1.5])

    def test_gravity_torque_and_whole_body_wrench(self):
        self.close(self.model.gravity_torques(self.frame,[0,-10,0]),[-55,-15])
        self.close(self.model.gravity_wrench(self.frame,[0,-10,0],self.frame["whole_body_com"]),[0,-60,0,0,0,0])

    def test_jacobian_matches_finite_differences_of_attached_point(self):
        q=np.array([.31,-.47]);h=1e-6;local=np.array([.3,.2,.1])
        f=self.model.kinematics([.4,.2,-.1],[.2,0,0,math.sqrt(.96)],q)
        point=f["positions"][2]+f["rotations"][2] @ local
        linear,angular=self.model.jacobian(f,"distal",point)
        for i in range(2):
            delta=np.eye(2)[i]*h
            plus=self.model.kinematics([.4,.2,-.1],[.2,0,0,math.sqrt(.96)],q+delta)
            minus=self.model.kinematics([.4,.2,-.1],[.2,0,0,math.sqrt(.96)],q-delta)
            p=plus["positions"][2]+plus["rotations"][2] @ local
            n=minus["positions"][2]+minus["rotations"][2] @ local
            self.close((p-n)/(2*h),linear[:,i],1e-8)
            skew=((plus["rotations"][2]-minus["rotations"][2])/(2*h)) @ f["rotations"][2].T
            self.close([skew[2,1],skew[0,2],skew[1,0]],angular[:,i],1e-8)

    def test_gravity_matches_potential_energy_gradient(self):
        q=np.array([.31,-.47]);g=np.array([2.,-9.8,3.]);h=1e-6
        frame=self.model.kinematics([0,0,0],[0,0,0,1],q)
        torque=self.model.gravity_torques(frame,g)
        def energy(x):
            f=self.model.kinematics([0,0,0],[0,0,0,1],x)
            return float(np.sum(self.model.mass*(f["centers"] @ g)))
        self.close([(energy(q+np.eye(2)[i]*h)-energy(q-np.eye(2)[i]*h))/(2*h)
                    for i in range(2)],torque,1e-8)

    def test_rigid_rotation_and_translation_preserve_generalized_torque(self):
        quaternion=[.5,.5,.5,.5];r=m.quaternion_rotation(quaternion);offset=np.array([3.,-2.,1.])
        f=self.model.kinematics(offset,quaternion,[0,0])
        w=dict(body_id="distal",point=offset+r @ np.array([2.5,0,0]),
               force=r @ np.array([0,3,0]),torque=r @ np.array([0,0,2]))
        self.close(self.model.wrench_torques(f,[w]),[6.5,3.5])
        self.close(self.model.gravity_torques(f,r @ np.array([0,-10,0])),[-55,-15])

    def test_model_owns_its_input_bytes(self):
        spec=specimen();model=m.RigidTree(spec);spec["joints"][0]["anchor_parent_m"]["x"]=99.
        self.close(model.kinematics([0,0,0],[0,0,0,1],[0,0])["anchors"][0],[1,0,0])

    def test_invalid_tree_axis_mass_inertia_and_joint_kind_refuse(self):
        changes=[lambda s:s["bodies"][1].__setitem__("mass_kg",-1.),
            lambda s:s["bodies"][1].__setitem__("inertia_diagonal_kg_m2",vector(10.,1.,1.)),
            lambda s:s["joints"][0].__setitem__("axis_parent_unit",vector(0.,0.,2.)),
            lambda s:s["joints"][0].__setitem__("joint_type","ball"),
            lambda s:s["bodies"][1].__setitem__("parent_body_id","distal"),
            lambda s:s["joints"].reverse()]
        for change in changes:
            spec=specimen();change(spec)
            with self.assertRaises(ValueError):m.RigidTree(spec)

    def test_nonfinite_wrong_shape_boolean_and_nonunit_pose_refuse(self):
        for value in ([float("nan"),0,0],[True,False,False],["1","2","3"],[1,2]):
            with self.assertRaises(ValueError):m.array(value,(3,),"bad")
        for q in ([0,0,0,2],[0,0,0,0],[0,0,float("nan"),1]):
            with self.assertRaises(ValueError):m.quaternion_rotation(q)
        with self.assertRaises(ValueError):self.model.jacobian(self.frame,"missing",[0,0,0])

    def test_correction_slew_and_final_speed_intersection(self):
        e=m.command_envelope([.9,-.9],[1,1],[.2,-.2],[.3,.3],[.08,.08])
        self.close(e["lower_correction"],[.12,-.28]);self.close(e["upper_correction"],[.28,-.12])
        self.close(e["lower_target"],[1,-1]);self.close(e["upper_target"],[1,-1])
        correction,target=m.resolve_correction(e,[100,-100])
        self.close(correction,[.28,-.28]);self.close(target,[1,-1])

    def test_invalid_previous_history_or_bounds_refuse(self):
        for args in (([0],[1],[.4],[.3],[.1]),([0],[0],[0],[1],[.1]),([0],[1],[0],[1],[-.1])):
            with self.assertRaises(ValueError):m.command_envelope(*args)

    def test_motor_force_limits_and_gain_are_distinct_from_target_speed(self):
        self.close(m.motor_torque([1,-1],[.5,-.5],[10,5],[[-3,3],[-4,4]]),[3,-2.5])
        with self.assertRaises(ValueError):m.motor_torque([0],[0],[0],[[-1,1]])
        with self.assertRaises(ValueError):m.motor_torque([],[],[],[])

    def test_saturated_interval_and_unreachable_request_remain_explicit(self):
        e=m.command_envelope([0],[.1],[0],[.1],[.1])
        r=m.command_for_torque(e,[10],[2],[[-3,3]],[7])
        self.close(r["lower_torque"],[-3]);self.close(r["upper_torque"],[-3])
        self.close(r["predicted_torque"],[-3]);self.close(r["torque_error"],[-10])
        self.assertFalse(r["held_interval_force_guaranteed"])

    def test_projected_torques_stay_in_reachable_intervals(self):
        e=m.command_envelope([.2,-.3],[1,1],[.1,-.1],[.4,.4],[.08,.08])
        lo,hi=m.torque_envelope(e,[.1,-.2],[3,5],[[-2,2],[-4,4]])
        for desired in np.linspace(-10,10,41):
            r=m.command_for_torque(e,[.1,-.2],[3,5],[[-2,2],[-4,4]],[desired,-desired])
            self.close(r["predicted_torque"],np.clip([desired,-desired],lo,hi))
            self.assertTrue(np.all(r["target"]>=e["lower_target"]) and np.all(r["target"]<=e["upper_target"]))

    def test_unclipped_static_joint_balance_never_claims_dynamic_feasibility(self):
        e=m.command_envelope([0,0],[100,100],[0,0],[100,100],[100,100])
        r=m.command_for_static_wrenches(self.model,self.frame,[],[0,-10,0],e,[0,0],[1,1],[[-100,100]]*2)
        self.close(r["target"],[55,15]);self.close(r["static_joint_balance_residual"],[0,0])
        self.assertFalse(r["dynamic_feasibility_established"]);self.assertFalse(r["capability_estimated"])

    def test_clipped_static_joint_balance_keeps_unfulfilled_request(self):
        e=m.command_envelope([0,0],[1,1],[0,0],[1,1],[1,1])
        r=m.command_for_static_wrenches(self.model,self.frame,[],[0,-10,0],e,[0,0],[1,1],[[-1,1]]*2)
        self.close(r["requested_torque"],[55,15]);self.close(r["static_joint_balance_residual"],[-54,-14])




class RetainedControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import actuation_recovery_mechanics_audit as audit
        cls.audit=audit;cls.c=audit.declaration()
        evidence=audit.ROOT.parent/"SporeSpore_Evidence"
        record=audit.read(audit.parent.CLOSURE);attempt=audit.parent.header(record,evidence)
        folder=attempt/"physical"/audit.TRIALS[0]
        controls=list(audit.read_jsonl(folder/"controller.jsonl"))
        cls.control=controls[1];cls.initial_control=controls[0];cls.unsupported_control=controls[-1]
        receipt=audit.read(attempt/"receipt.json")
        baseline=[name for name,digest in receipt["binding"]["runtime"].items()
                  if digest==receipt["contract"]["baseline_core_sha256"]]
        assert len(baseline)==1
        cls.core=audit.bridge.LocomotionCore(audit.Path(baseline[0]))
        cls.sample=list(audit.read_jsonl(folder/"contact-force.jsonl"))[5]
        cls.trace=list(audit.read_jsonl(folder/"trace.jsonl"))[5]
        cls.model=m.RigidTree(audit.read(folder/"compiled.json")["morphology"]["morphology_spec"])

    def test_synthetic_resolver_fixture_never_promotes_original_fallback(self):
        for control in (self.initial_control,self.unsupported_control):
            before=copy.deepcopy(control)
            request=self.audit.projection_fixture(self.core,control)
            original=control["resolution_request"]["provider_request"]
            self.assertNotEqual(request["expected_model_id"],original["expected_model_id"])
            self.assertNotEqual(request["provider_id"],original["provider_id"])
            self.assertEqual(request["provider_id"],request["provider_memory"]["provider_id"])
            self.assertEqual(request["history"]["ordered_entries"],[])
            self.assertEqual(request["state"],original["state"])
            self.assertTrue(control["resolution"]["deterministic_baseline_fallback_used"])
            envelope=self.audit.command_limits(control)
            np.testing.assert_allclose(self.audit.original_command(envelope,control,self.c),control["native_targets"])
            self.assertEqual(control,before)

    def test_declared_scope_tolerances_and_sources_cannot_be_relaxed(self):
        from unittest.mock import patch
        for change in (lambda v:v.__setitem__("dynamic_feasibility_established",True),
            lambda v:v.__setitem__("geometry_absolute_tolerance",1.),
            lambda v:v.__setitem__("expected_frames",1),
            lambda v:v.__setitem__("source_bindings",{})):
            value=copy.deepcopy(self.c);change(value)
            with patch.object(self.audit,"read",return_value=value):
                with self.assertRaises(ValueError):self.audit.declaration()

    def test_crossed_step_clock_state_and_applied_command_refuse(self):
        self.audit.join_frame(self.control,self.sample,self.trace,1)
        for change in (lambda v:v.__setitem__("step",7),
            lambda v:v.__setitem__("prepared_time_s",99.),
            lambda v:v["before_qpos"].__setitem__(0,99.),
            lambda v:v["ctrl"].__setitem__(0,99.)):
            value=copy.deepcopy(self.sample);change(value)
            with self.assertRaises(ValueError):self.audit.join_frame(self.control,value,self.trace,1)

    def test_native_geometry_cannot_be_replaced_by_a_different_frame(self):
        state=self.control["request"]["state"];pose=state["base_pose_world"]
        frame=self.model.kinematics(m.xyz(pose["position_m"]),
            [pose["orientation_xyzw"][k] for k in ("x","y","z","w")],
            [x["position_rad"] for x in state["ordered_joint_observations"]])
        native=self.control["native_observation"];self.audit.native_geometry(self.model,frame,native,self.c)
        for key in ("positions","centers","anchors","axes","rotations","whole_body_com"):
            changed=copy.deepcopy(frame);changed[key].flat[0]+=.01
            with self.assertRaises(ValueError):self.audit.native_geometry(self.model,changed,native,self.c)

    def test_contact_body_order_controls_signed_force_and_world_is_excluded(self):
        row=dict(contacts=[dict(body_ids=[0,3],body_names=["world","front_left_distal"],
            position_m=[1.,2.,3.],force_on_geom2_canonical_n=[2.,3.,4.],
            torque_on_geom2_canonical_nm=[5.,6.,7.])])
        forward=self.audit.contact_wrenches(row)
        np.testing.assert_allclose(forward[0]["point"],[1.,3.,-2.])
        row["contacts"][0]["body_ids"].reverse();row["contacts"][0]["body_names"].reverse()
        reverse=self.audit.contact_wrenches(row)
        self.assertEqual(len(forward),1);self.assertEqual(len(reverse),1)
        np.testing.assert_allclose(reverse[0]["force"],-forward[0]["force"])
        np.testing.assert_allclose(reverse[0]["torque"],-forward[0]["torque"])
        row["contacts"][0]["body_names"][1]="wrong"
        with self.assertRaises(ValueError):self.audit.contact_wrenches(row)


if __name__=="__main__":unittest.main()
