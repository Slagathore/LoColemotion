"""Height direction, geometric target, reference bits and real-ABI withdrawal; zero worlds."""
import copy
import json
import math
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco
from adaptation_provider import body_height_feedback_v1 as model
from adaptation_provider import body_gain_feedback_v1 as parent
from body_height_feedback_control import BodyHeightFeedbackController
from body_gain_feedback_control import BodyGainFeedbackController
from audit_body_height_proposal import validate_proposal
from audit_gpu_batch_execution import same_bits
import test_body_gain_feedback as fixtures


class BodyHeightControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.BodyGainControls.setUpClass();cls.old=fixtures.BodyGainControls;cls.f=cls.old.f
        cls.d=model.definition()
        cls.c=dict(cls.f.c,provider=dict(kind="untrained_body_height_feedback_v1",candidates=cls.d["candidates"],
            envelope_selection=cls.d["envelope_selection"],ground_domain=cls.d["ground_domain"]))

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in body-height controls"))
            guard.start();self.addCleanup(guard.stop)

    def state(self):
        state=self.old.state(self)
        state["base_pose_world"]=dict(position_m=dict(x=0.,y=.45,z=0.),orientation_xyzw=dict(x=0.,y=0.,z=0.,w=1.))
        state["base_twist_world"]=dict(linear_velocity_m_s=dict(x=0.,y=0.,z=0.),angular_velocity_rad_s=dict(x=0.,y=0.,z=0.))
        return state

    def evaluate(self,state):
        return model.feedback(state,self.f.rows[0]["request"]["command"],self.d["candidates"][2],self.d)

    def test_family_geometry_and_host_owned_ground_domain(self):
        model.validate_geometry(self.f.compiled,self.d)
        self.assertEqual([c["height_enabled"] for c in self.d["candidates"]],[False,False,True])
        self.assertEqual(self.d["height_control"],dict(nominal_target_height_m=.4,minimum_target_height_m=.28,
            reach_margin_m=.01,height_gain_s_inv=3.,vertical_damping=.5,maximum_vertical_velocity_m_s=.2))
        self.assertFalse(self.d["ground_domain"]["measured_terrain_height"])
        for key in ["trained","training_data_authority","physical_acceptance_authority","release_authority","equivalence_authority"]:
            self.assertFalse(self.d[key])
        for change in [lambda c:c["provider"]["ground_domain"].__setitem__("height_m",1.),
            lambda c:c["provider"].__setitem__("maximum_absolute_correction_rad_s",4.),
            lambda c:c["provider"]["candidates"][2].__setitem__("maximum_slew_per_step_rad_s",.1)]:
            c=copy.deepcopy(self.c);change(c)
            with self.assertRaisesRegex(ValueError,"host family/envelope"):
                BodyHeightFeedbackController(self.f.core,self.f.compiled,c,2)

    def test_reference_feedback_preserves_parent_bits_on_retained_inputs(self):
        for row in self.f.rows:
            args=[row["request"]["state"],row["request"]["command"]]
            try:expected=parent.feedback(*args,self.old.d["candidates"][1],self.old.d)
            except ValueError:
                with self.assertRaises(ValueError):model.feedback(*args,self.d["candidates"][1],self.d)
            else:self.assertTrue(same_bits(model.feedback(*args,self.d["candidates"][1],self.d),expected))

    def test_height_direction_damping_and_damped_normal_equation(self):
        state=self.state();delta,detail=self.evaluate(state);h=detail["height_control"]
        self.assertAlmostEqual(h["requested_vertical_velocity_m_s"],-.15,places=14)
        self.assertEqual(h["target_height_m"],.4)
        self.assertGreater(h["requested_foot_velocity_body_m_s"][1],0.)
        # Independently check (J^T J + lambda^2 I) dq = J^T v for the added translation.
        for leg,receipt in zip(self.d["legs"],detail["legs"]):
            _,j=model.body.foot_geometry(leg,-.2,.4);extra=receipt["height_translation_delta_rad_s"]
            velocity=h["requested_foot_velocity_body_m_s"][:2];lam=self.d["jacobian_damping_m"]
            for i in range(2):
                lhs=sum((sum(j[k][i]*j[k][n] for k in range(2))+(lam*lam if i==n else 0.))*extra[n] for n in range(2))
                rhs=sum(j[k][i]*velocity[k] for k in range(2))
                self.assertAlmostEqual(lhs,rhs,places=13)
        state["base_twist_world"]["linear_velocity_m_s"]["y"]=-.1
        self.assertAlmostEqual(self.evaluate(state)[1]["height_control"]["requested_vertical_velocity_m_s"],-.1,places=14)
        state["base_pose_world"]["position_m"]["y"]=.3
        self.assertEqual(self.evaluate(state)[1]["height_control"]["requested_vertical_velocity_m_s"],.2)

    def test_roll_reach_cap_target_floor_and_vertical_speed_bound(self):
        state=self.state();angle=.58
        state["base_pose_world"]["orientation_xyzw"]=dict(x=math.sin(angle/2),y=0.,z=0.,w=math.cos(angle/2))
        _,detail=self.evaluate(state);h=detail["height_control"]
        anchor=self.d["legs"][0]["hip_anchor_body_m"]
        expected=self.d["distal_capsule_radius_m"]+.4*math.cos(angle)-abs(anchor["z"])*math.sin(angle)-.01
        self.assertAlmostEqual(h["reach_limited_height_cap_m"],expected,places=14)
        self.assertTrue(h["reach_cap_below_minimum_target"])
        self.assertEqual(h["target_height_m"],.28)
        self.assertEqual(h["requested_vertical_velocity_m_s"],-.2)
        self.assertTrue(h["vertical_velocity_limited"])
        self.assertGreater(h["target_height_m"],h["reach_limited_height_cap_m"])

    def test_yaw_invariance_no_support_and_invalid_observation_withdrawal(self):
        state=self.state();delta,_=self.evaluate(state)
        state["base_pose_world"]["orientation_xyzw"]=dict(x=0.,y=math.sin(.35),z=0.,w=math.cos(.35))
        actual,_=self.evaluate(state)
        for a,b in zip(delta,actual):self.assertAlmostEqual(a,b,places=13)
        for contact in state["ordered_contact_observations"]:contact.update(presence=False,bears_support=False)
        self.assertEqual(self.evaluate(state)[0],[0.]*8)
        for change in [lambda s:s["gravity_world_m_s2"].__setitem__("x",.1),
            lambda s:s["base_pose_world"]["position_m"].__setitem__("y",float("nan")),
            lambda s:s["base_pose_world"].__setitem__("orientation_xyzw",dict(x=math.sin(.4),y=0.,z=0.,w=math.cos(.4)))]:
            altered=self.state();change(altered)
            with self.assertRaises(ValueError):self.evaluate(altered)

    def test_real_abi_all_roles_independent_cores_reference_and_fallback_bits(self):
        controllers=[]
        try:
            controllers=[[BodyHeightFeedbackController(core,self.f.compiled,self.c,i) for core in [self.f.core,self.f.baseline]] for i in range(3)]
            reference=BodyGainFeedbackController(self.f.core,self.f.compiled,self.old.c,1);self.addCleanup(reference.close)
            previous=[[0.]*8 for _ in range(3)];supported=withdrawn=0
            for row in self.f.rows:
                args=[row["request"]["state"],row["stability"],row["kinematics"]]
                old=reference.step(*args);baseline=None
                for i,pair in enumerate(controllers):
                    value,independent=[c.step(*args) for c in pair]
                    self.assertTrue(same_bits(value,independent));validate_proposal(value,self.c,i,previous[i])
                    previous[i]=[x["applied_correction_rad_s"] for x in value["resolution"]["ordered_commands"]]
                    if i==0:baseline=value["native_targets"];self.assertTrue(same_bits(baseline,row["native_targets"]))
                    elif value["feedback"]["status"]=="refused":withdrawn+=1;self.assertTrue(same_bits(value["native_targets"],baseline))
                    else:supported+=1
                    if i==1:self.assertTrue(same_bits(value["native_targets"],old["native_targets"]))
            self.assertGreater(supported,0);self.assertGreater(withdrawn,0)
            self.assertEqual(len({pair[0].model_digest for pair in controllers}),3)
            print(json.dumps(dict(real_abi_decisions=3*len(self.f.rows),independent_cores=2,
                supported_feedback_decisions=supported,withdrawn_feedback_decisions=withdrawn,baseline_and_reference_target_bits=True,world_build_count=0)))
        finally:
            for pair in controllers:
                for controller in pair:controller.close()

    def test_corrupt_provenance_response_and_envelope_cannot_bypass_resolver(self):
        controller=BodyHeightFeedbackController(self.f.core,self.f.compiled,self.c,2)
        try:
            row=self.f.rows[0];value=controller.step(row["request"]["state"],row["stability"],row["kinematics"])
            for change in [lambda r:r["provider_response"].__setitem__("request_sha256","sha256:"+"0"*64),
                lambda r:r["provider_response"]["provenance"].__setitem__("direct_world_access_used",True)]:
                altered=copy.deepcopy(value["resolution_request"]);change(altered)
                result=self.f.core.resolve_adaptation_v1(altered)
                self.assertTrue(result["deterministic_baseline_fallback_used"])
                self.assertTrue(all(same_bits(r["baseline_canonical_target_velocity_rad_s"],r["final_canonical_target_velocity_rad_s"]) for r in result["ordered_commands"]))
            altered=copy.deepcopy(value);altered["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"][0]["maximum_absolute_correction_rad_s"]=.25
            with self.assertRaisesRegex(ValueError,"envelope/history"):validate_proposal(altered,self.c,2,[0.]*8)
        finally:controller.close()

    def test_changed_parent_geometry_settings_and_false_authority_refuse(self):
        original=Path.read_text
        for change in [lambda d:d["parent_implementation"].__setitem__("sha256","0"*64),
            lambda d:d["height_control"].__setitem__("height_gain_s_inv",4.),
            lambda d:d.__setitem__("trained",True),lambda d:d.__setitem__("release_authority",True)]:
            changed=json.loads(original(model.CONTRACT,encoding="utf-8"));change(changed)
            with patch.object(Path,"read_text",autospec=True,side_effect=lambda p,*args,**kw:json.dumps(changed) if p==model.CONTRACT else original(p,*args,**kw)):
                with self.assertRaises(ValueError):model.definition()
        compiled=copy.deepcopy(self.f.compiled);compiled["morphology"]["morphology_spec"]["contact_sites"][0]["radius_m"]+=.01
        with self.assertRaisesRegex(ValueError,"capsule radius"):model.validate_geometry(compiled,self.d)


if __name__=="__main__":unittest.main()
