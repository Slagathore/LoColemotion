"""Body-gain factorial, reference compatibility and real-ABI safety; zero worlds."""
import copy
import itertools
import json
import math
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco
from adaptation_provider import body_gain_feedback_v1 as model
from adaptation_provider import posture_feedback_v1 as prior
from body_gain_feedback_control import BodyGainFeedbackController
from posture_feedback_control import PostureFeedbackController
from audit_body_gain_proposal import validate_proposal
from audit_gpu_batch_execution import same_bits
import test_posture_feedback as prior_tests


class BodyGainControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        prior_tests.PostureControls.setUpClass()
        cls.f = prior_tests.PostureControls.f
        cls.old = prior_tests.PostureControls
        cls.d = model.definition()
        cls.c = dict(cls.f.c,provider=dict(kind="untrained_body_gain_feedback_v1",
            candidates=cls.d["candidates"],envelope_selection=cls.d["envelope_selection"]))

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in body-gain controls"))
            guard.start();self.addCleanup(guard.stop)

    def state(self):
        state=copy.deepcopy(self.f.rows[0]["request"]["state"])
        for j in state["ordered_joint_observations"]:
            j["position_rad"]=-.2 if j["joint_id"].endswith("hip") else .4
        for c in state["ordered_contact_observations"]:c.update(presence=True,bears_support=True)
        return state

    def test_complete_factorial_fixed_settings_and_geometry(self):
        model.validate_geometry(self.f.compiled,self.d)
        candidates=self.d["candidates"][1:]
        self.assertEqual([(c["attitude_gain_s_inv"],c["angular_damping"]) for c in candidates],
            list(itertools.product([3.,6.],[.5,1.])))
        self.assertEqual(len(self.d["candidates"]),5)
        for c in candidates:
            self.assertEqual([c[k] for k in ["maximum_absolute_correction_rad_s","maximum_slew_per_step_rad_s",
                "posture_gain_s_inv","velocity_gain_s_inv"]],[3.5,.08,8.,0.])
        self.assertEqual(self.d["legs"],self.old.d["legs"])
        self.assertEqual(self.d["posture_reference_rad"],self.old.d["posture_reference_rad"])
        self.assertTrue(all(self.d[k] is False for k in ["trained","training_data_authority",
            "physical_acceptance_authority","release_authority","equivalence_authority"]))

    def test_known_body_rotation_and_rate_have_independent_gain_effects(self):
        state=self.state();angle=.2
        state["base_pose_world"]["orientation_xyzw"]=dict(x=math.sin(angle/2),y=0.,z=0.,w=math.cos(angle/2))
        # Rotate the known body gyro (0.15, 0, -0.2) into the world by Rx(angle).
        state["base_twist_world"]["angular_velocity_rad_s"]=dict(x=.15,y=.2*math.sin(angle),z=-.2*math.cos(angle))
        command=self.f.rows[0]["request"]["command"]
        for candidate in self.d["candidates"][1:]:
            _,detail=model.feedback(state,command,candidate,self.d)
            kp,kd=candidate["attitude_gain_s_inv"],candidate["angular_damping"]
            expected=[-kp*math.sin(angle)-kd*.15,0.,kd*.2]
            for actual,wanted in zip(detail["requested_angular_velocity_body_rad_s"],expected):
                self.assertAlmostEqual(actual,wanted,places=12)
        self.assertEqual(state["base_pose_world"]["orientation_xyzw"]["y"],0.)

    def test_reference_preserves_parent_feedback_and_supported_posture_bits(self):
        command=self.f.rows[0]["request"]["command"];checked=0
        for row in self.f.rows:
            state=row["request"]["state"]
            try:expected=prior.feedback(state,command,self.old.d["candidates"][8],self.old.d)
            except ValueError:
                with self.assertRaises(ValueError):model.feedback(state,command,self.d["candidates"][1],self.d)
                continue
            actual=model.feedback(state,command,self.d["candidates"][1],self.d)
            self.assertTrue(same_bits(actual,expected));checked+=1
        self.assertGreater(checked,0)

    def test_no_support_produces_no_body_or_posture_correction(self):
        state=self.state();command=self.f.rows[0]["request"]["command"]
        for contact in state["ordered_contact_observations"]:contact.update(presence=False,bears_support=False)
        for candidate in self.d["candidates"][1:]:
            delta,detail=model.feedback(state,command,candidate,self.d)
            self.assertEqual(delta,[0.]*8)
            self.assertTrue(all(r["posture_regularization_delta_rad_s"]==[0.,0.] for r in detail["legs"]))
        state["base_pose_world"]["orientation_xyzw"]=dict(x=math.sin(.4),y=0.,z=0.,w=math.cos(.4))
        with self.assertRaisesRegex(ValueError,"tilt domain"):
            model.feedback(state,command,self.d["candidates"][4],self.d)

    def test_real_abi_all_corners_limits_fallback_and_independent_core_replay(self):
        controllers=[];original=copy.deepcopy(self.c)
        try:
            for i in range(5):
                controllers.append([BodyGainFeedbackController(core,self.f.compiled,self.c,i) for core in [self.f.core,self.f.baseline]])
            reference=PostureFeedbackController(self.f.core,self.f.compiled,self.old.c,8)
            self.addCleanup(reference.close)
            previous=[[0.]*8 for _ in range(5)];supported=withdrawn=0
            for row in self.f.rows:
                inputs=[row["request"]["state"],row["stability"],row["kinematics"]]
                parent_result=reference.step(*inputs);baseline=None
                for i,pair in enumerate(controllers):
                    value,independent=[c.step(*inputs) for c in pair]
                    self.assertTrue(same_bits(value,independent));validate_proposal(value,self.c,i,previous[i])
                    previous[i]=[r["applied_correction_rad_s"] for r in value["resolution"]["ordered_commands"]]
                    if i==0:
                        baseline=value["native_targets"];self.assertTrue(same_bits(baseline,row["native_targets"]))
                    elif value["feedback"]["status"]=="refused":
                        withdrawn+=1;self.assertTrue(same_bits(value["native_targets"],baseline))
                    else:supported+=1
                    if i==1:self.assertTrue(same_bits(value["native_targets"],parent_result["native_targets"]))
            self.assertEqual(len({pair[0].model_digest for pair in controllers}),5)
            self.assertEqual(self.c,original);self.assertGreater(supported,0);self.assertGreater(withdrawn,0)
            print(json.dumps(dict(real_abi_decisions=5*len(self.f.rows),independent_cores=2,
                supported_feedback_decisions=supported,withdrawn_feedback_decisions=withdrawn,
                baseline_and_reference_target_bits=True,world_build_count=0)))
        finally:
            for pair in controllers:
                for c in pair:c.close()

    def test_changed_family_or_host_envelope_refuses_before_session(self):
        for change in [lambda c:c["provider"].__setitem__("maximum_absolute_correction_rad_s",4.),
            lambda c:c["provider"]["candidates"][4].__setitem__("angular_damping",2.),
            lambda c:c["provider"]["candidates"].pop()]:
            altered=copy.deepcopy(self.c);change(altered)
            with self.assertRaisesRegex(ValueError,"host family/envelope"):
                BodyGainFeedbackController(self.f.core,self.f.compiled,altered,4)
        for key,value in [("attitude_gain_s_inv",4.),("posture_gain_s_inv",4.),("maximum_slew_per_step_rad_s",.1)]:
            bad=copy.deepcopy(self.d["candidates"][4]);bad[key]=value
            with self.assertRaisesRegex(ValueError,"frozen factorial"):model.validate_candidate(bad)

    def test_corrupt_response_and_crossed_envelope_cannot_bypass_resolver(self):
        c=BodyGainFeedbackController(self.f.core,self.f.compiled,self.c,4)
        try:
            row=self.f.rows[0];value=c.step(row["request"]["state"],row["stability"],row["kinematics"])
            for change in [lambda r:r["provider_response"].__setitem__("request_sha256","sha256:"+"0"*64),
                lambda r:r["provider_response"]["provenance"].__setitem__("direct_world_access_used",True)]:
                altered=copy.deepcopy(value["resolution_request"]);change(altered)
                result=self.f.core.resolve_adaptation_v1(altered)
                self.assertTrue(result["deterministic_baseline_fallback_used"])
                self.assertTrue(all(same_bits(r["baseline_canonical_target_velocity_rad_s"],r["final_canonical_target_velocity_rad_s"])
                    for r in result["ordered_commands"]))
            altered=copy.deepcopy(value)
            altered["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"][0]["maximum_absolute_correction_rad_s"] = .25
            with self.assertRaisesRegex(ValueError,"envelope/history"):validate_proposal(altered,self.c,4,[0.]*8)
        finally:c.close()

    def test_changed_parent_pin_or_false_model_authority_refuses(self):
        original=Path.read_text
        for change in [lambda d:d["parent_implementation"].__setitem__("sha256","0"*64),
            lambda d:d.__setitem__("trained",True),lambda d:d.__setitem__("release_authority",True)]:
            changed=json.loads(original(model.CONTRACT,encoding="utf-8"));change(changed)
            with patch.object(Path,"read_text",autospec=True,side_effect=lambda p,*args,**kw:
                    json.dumps(changed) if p==model.CONTRACT else original(p,*args,**kw)):
                with self.assertRaises(ValueError):model.definition()


if __name__ == "__main__":unittest.main()
