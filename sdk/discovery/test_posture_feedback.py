"""Posture objective, factorial ownership and real-ABI controls without worlds."""
import copy
import itertools
import json
import math
import unittest
from unittest.mock import patch
import mujoco

from adaptation_provider import posture_feedback_v1 as model
from adaptation_provider import stance_feedback_v1 as parent
from posture_feedback_control import PostureFeedbackController
from stance_feedback_control import StanceFeedbackController
from audit_posture_proposal import validate_proposal
from audit_gpu_batch_execution import same_bits
import test_stance_feedback as parent_tests


class PostureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # This parent setup verifies retained source-stream hashes and loads
        # the two independently built cores; it creates no physical world.
        parent_tests.StanceFeedbackControls.setUpClass()
        cls.f = parent_tests.StanceFeedbackControls
        cls.d = model.definition()
        cls.c = dict(cls.f.c, provider=dict(kind="untrained_posture_feedback_v1",
            candidates=cls.d["candidates"], envelope_selection=cls.d["envelope_selection"]))

    def setUp(self):
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guard = patch.object(mujoco, name, side_effect=AssertionError("No worlds in posture controls"))
            guard.start(); self.addCleanup(guard.stop)

    def state(self):
        state = copy.deepcopy(self.f.rows[0]["request"]["state"])
        for joint in state["ordered_joint_observations"]:
            joint["position_rad"] = -.2 if joint["joint_id"].endswith("hip") else .4
        for contact in state["ordered_contact_observations"]:
            contact.update(presence=True, bears_support=True)
        return state

    def test_complete_factorial_and_parent_geometry_binding(self):
        model.validate_geometry(self.f.compiled, self.d)
        axes = ["maximum_absolute_correction_rad_s", "maximum_slew_per_step_rad_s", "posture_gain_s_inv"]
        observed = [tuple(c[k] for k in axes) for c in self.d["candidates"][1:]]
        self.assertEqual(observed, list(itertools.product([.25,3.5],[.02,.08],[0.,8.])))
        self.assertEqual(len(self.d["candidates"]), 9)
        self.assertNotIn("maximum_absolute_correction_rad_s", self.d)
        self.assertTrue(all(self.d[k] is False for k in ["trained", "training_data_authority",
            "physical_acceptance_authority", "release_authority", "equivalence_authority"]))
        self.assertEqual(self.d["legs"], parent.definition()["legs"])

    def test_biased_solve_satisfies_independent_normal_equations(self):
        damping = self.d["jacobian_damping_m"]; preferred = [self.d["candidates"][8]["posture_gain_s_inv"]*self.d["posture_reference_rad"][k] for k in ["hip","knee"]]
        for hip,knee,v in itertools.product([-.6,0.,.6],[0.,.4,1.],[[0.,0.],[.2,-.1]]):
            _, j = parent.foot_geometry(self.d["legs"][0], hip, knee)
            body = parent.inverse_velocity(j, v, damping)
            posture = model.posture_adjustment(j, preferred, damping)
            delta = [b+p for b,p in zip(body,posture)]
            # Independent normal equation for the explicitly declared objective.
            matrix = [[sum(j[r][i]*j[r][k] for r in range(2))+(damping*damping if i==k else 0.)
                for k in range(2)] for i in range(2)]
            rhs = [sum(j[r][i]*v[r] for r in range(2))+damping*damping*preferred[i] for i in range(2)]
            for i in range(2):
                self.assertAlmostEqual(sum(matrix[i][k]*delta[k] for k in range(2)), rhs[i], places=12)
            def objective(x):
                return sum((sum(j[r][i]*x[i] for i in range(2))-v[r])**2 for r in range(2)) \
                    + damping*damping*sum((x[i]-preferred[i])**2 for i in range(2))
            for i,step in itertools.product(range(2),[-1e-3,1e-3]):
                changed = list(delta); changed[i] += step
                self.assertGreater(objective(changed), objective(delta))
        self.assertEqual(model.posture_adjustment([[0.,0.],[0.,0.]],preferred,damping),preferred)

    def test_straight_leg_preference_can_bend_without_claiming_instant_vertical_motion(self):
        leg = self.d["legs"][0]
        point,j = parent.foot_geometry(leg,0.,0.)
        preferred = [self.d["candidates"][8]["posture_gain_s_inv"]*self.d["posture_reference_rad"][k] for k in ["hip","knee"]]
        delta = model.posture_adjustment(j,preferred,self.d["jacobian_damping_m"])
        self.assertLess(delta[0],0.); self.assertGreater(delta[1],0.)
        self.assertEqual(sum(j[1][i]*delta[i] for i in range(2)),0.)
        bent,_ = parent.foot_geometry(leg,.05*delta[0],.05*delta[1])
        self.assertGreater(bent[1],point[1])
        model.validate_geometry(self.f.compiled,self.d)
        changed = copy.deepcopy(self.f.compiled)
        changed["morphology"]["morphology_spec"]["joints"][0]["lower_limit_rad"] = -.2
        with self.assertRaisesRegex(ValueError,"Posture reference"):
            model.validate_geometry(changed,self.d)

    def test_zero_preference_preserves_parent_feedback_and_support_gate(self):
        command = self.f.rows[0]["request"]["command"]
        checked = 0
        for row in self.f.rows:
            state = row["request"]["state"]
            try:
                old,_ = parent.feedback(state,command,self.f.d["candidates"][4],self.f.d)
            except ValueError:
                with self.assertRaises(ValueError): model.feedback(state,command,self.d["candidates"][1],self.d)
                continue
            new,_ = model.feedback(state,command,self.d["candidates"][1],self.d)
            self.assertTrue(same_bits(new,old)); checked += 1
        self.assertGreater(checked,0)
        state = self.state()
        for c in state["ordered_contact_observations"]: c.update(presence=False,bears_support=False)
        delta,detail = model.feedback(state,command,self.d["candidates"][8],self.d)
        self.assertEqual(delta,[0.]*8)
        self.assertTrue(all(r["posture_regularization_delta_rad_s"]==[0.,0.] for r in detail["legs"]))

    def test_posture_feedback_remains_invariant_under_world_yaw(self):
        state = self.state(); command = self.f.rows[0]["request"]["command"]
        state["base_twist_world"]["angular_velocity_rad_s"] = dict(x=.2,y=.1,z=-.3)
        candidate = self.d["candidates"][8]
        expected,_ = model.feedback(state,command,candidate,self.d)
        turned = copy.deepcopy(state); angle = .7
        quaternion = dict(x=0.,y=math.sin(angle/2),z=0.,w=math.cos(angle/2))
        rotate = parent.rotation(quaternion); turned["base_pose_world"]["orientation_xyzw"] = quaternion
        for key in ["angular_velocity_rad_s","linear_velocity_m_s"]:
            turned["base_twist_world"][key] = dict(zip(["x","y","z"],parent.transform(rotate,parent.vector(state["base_twist_world"][key]))))
        for key in ["forward_axis_world_unit","lateral_axis_world_unit"]:
            turned["task_frame"][key] = dict(zip(["x","y","z"],parent.transform(rotate,parent.vector(state["task_frame"][key]))))
        actual,_ = model.feedback(turned,command,candidate,self.d)
        for a,b in zip(actual,expected): self.assertAlmostEqual(a,b,places=12)

    def test_real_abi_all_corners_bounds_fallback_and_independent_core_replay(self):
        controllers = []
        original = copy.deepcopy(self.c)
        try:
            for i in range(9):
                controllers.append([PostureFeedbackController(core,self.f.compiled,self.c,i) for core in [self.f.core,self.f.baseline]])
            old = StanceFeedbackController(self.f.core,self.f.compiled,self.f.c,4)
            self.addCleanup(old.close)
            previous = [[0.]*8 for _ in range(9)]; supported = withdrawn = 0
            for row in self.f.rows:
                inputs = [row["request"]["state"],row["stability"],row["kinematics"]]
                parent_result = old.step(*inputs)
                baseline = None
                for i,pair in enumerate(controllers):
                    value,independent = [c.step(*inputs) for c in pair]
                    self.assertTrue(same_bits(value,independent))
                    validate_proposal(value,self.c,i,previous[i])
                    previous[i] = [r["applied_correction_rad_s"] for r in value["resolution"]["ordered_commands"]]
                    if i == 0:
                        baseline = value["native_targets"]
                        self.assertTrue(same_bits(baseline,row["native_targets"]))
                    elif value["feedback"]["status"] == "refused":
                        withdrawn += 1; self.assertTrue(same_bits(value["native_targets"],baseline))
                    else:
                        supported += 1
                    if i == 1: self.assertTrue(same_bits(value["native_targets"],parent_result["native_targets"]))
            self.assertEqual(len({pair[0].model_digest for pair in controllers}),9)
            self.assertEqual(self.c,original)
            self.assertGreater(supported,0); self.assertGreater(withdrawn,0)
            print(json.dumps(dict(real_abi_decisions=9*len(self.f.rows),independent_cores=2,
                supported_feedback_decisions=supported,withdrawn_feedback_decisions=withdrawn,
                baseline_and_parent_target_bits=True,world_build_count=0)))
        finally:
            for pair in controllers:
                for c in pair: c.close()

    def test_changed_family_or_host_envelope_refuses_before_session(self):
        for change in [lambda c:c["provider"].__setitem__("maximum_absolute_correction_rad_s",2.),
            lambda c:c["provider"]["candidates"][8].__setitem__("maximum_slew_per_step_rad_s",.5),
            lambda c:c["provider"]["candidates"].pop()]:
            altered = copy.deepcopy(self.c); change(altered)
            with self.assertRaisesRegex(ValueError,"host family/envelope"):
                PostureFeedbackController(self.f.core,self.f.compiled,altered,8)
        bad = copy.deepcopy(self.d["candidates"][8]); bad["posture_gain_s_inv"] = 3.
        with self.assertRaisesRegex(ValueError,"frozen factorial"): model.validate_candidate(bad)

    def test_corrupt_response_and_crossed_envelope_cannot_bypass_resolver(self):
        c = PostureFeedbackController(self.f.core,self.f.compiled,self.c,8)
        try:
            row = self.f.rows[0]
            value = c.step(row["request"]["state"],row["stability"],row["kinematics"])
            for change in [lambda r:r["provider_response"].__setitem__("request_sha256","sha256:"+"0"*64),
                lambda r:r["provider_response"]["provenance"].__setitem__("direct_world_access_used",True)]:
                altered = copy.deepcopy(value["resolution_request"]); change(altered)
                result = self.f.core.resolve_adaptation_v1(altered)
                self.assertTrue(result["deterministic_baseline_fallback_used"])
                self.assertTrue(all(same_bits(r["baseline_canonical_target_velocity_rad_s"],r["final_canonical_target_velocity_rad_s"])
                    for r in result["ordered_commands"]))
            altered = copy.deepcopy(value)
            altered["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"][0]["maximum_absolute_correction_rad_s"] = .25
            with self.assertRaisesRegex(ValueError,"envelope/history"): validate_proposal(altered,self.c,8,[0.]*8)
        finally: c.close()


if __name__ == "__main__": unittest.main()
