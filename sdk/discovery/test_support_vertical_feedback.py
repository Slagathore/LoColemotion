"""Independent composition equations, retained-input ABI and fail-closed controls."""
import copy
import itertools
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
from adaptation_provider import support_vertical_feedback_v1 as model
from adaptation_provider import body_height_feedback_v1 as parent
from audit_gpu_batch_execution import same_bits
from audit_support_vertical import validate_proposal
from body_height_feedback_control import BodyHeightFeedbackController
from cpu_height_activation_task import declaration as reference_declaration
from cpu_support_vertical_task import declaration, ROOT
from portable_search_control import bridge
from support_vertical_control import SupportVerticalController
import test_body_height_feedback as fixtures


class SupportVerticalFeedbackControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.BodyHeightControls.setUpClass()
        cls.f = fixtures.BodyHeightControls.f
        cls.d = model.definition()
        cls.c = declaration()
        cls.old = reference_declaration()
        cls.cores = [bridge.LocomotionCore(Path(os.environ[k]))
            for k in ["QUADRUPED_TEST_CORE", "PORTABLE_BATCH_BASELINE_CORE"]]
        closure = json.loads((ROOT/"sdk/discovery/cpu_height_activation_closure_v1.json").read_text())
        path = ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical/left_075_train_001_height_immediate/controller.jsonl"
        with path.open(encoding="utf-8") as stream:
            cls.rows = [json.loads(line) for line in itertools.islice(stream, 120)]

    def setUp(self):
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guard = patch.object(mujoco, name, side_effect=AssertionError("No worlds in composition controls"))
            guard.start()
            self.addCleanup(guard.stop)

    def state(self):
        state = copy.deepcopy(self.rows[0]["request"]["state"])
        state["base_pose_world"] = dict(position_m=dict(x=0., y=.45, z=0.), orientation_xyzw=dict(x=0., y=0., z=0., w=1.))
        state["base_twist_world"] = dict(linear_velocity_m_s=dict(x=0., y=0., z=0.), angular_velocity_rad_s=dict(x=0., y=0., z=0.))
        for joint in state["ordered_joint_observations"]:
            joint.update(position_rad=-.2 if joint["joint_id"].endswith("_hip") else .4, velocity_rad_s=0.)
        for contact in state["ordered_contact_observations"]:
            contact.update(presence=True, bears_support=True)
        return state

    def baseline(self, knee=-1.):
        return dict(ordered_commands=[dict(actuator_id=name+"_motor",
            combined_canonical_target_velocity_rad_s=0. if name.endswith("_hip") else knee)
            for name in model.geometry.JOINTS])

    def evaluate(self, state=None, baseline=None):
        return model.feedback(self.state() if state is None else state, self.rows[0]["request"]["command"],
            self.d["candidates"][3], self.d, self.baseline() if baseline is None else baseline)

    def test_family_parent_geometry_and_limits_stay_fixed(self):
        model.validate_geometry(self.f.compiled, self.d)
        self.assertEqual(self.d["candidates"][:3], parent.expected_candidates())
        new, old = self.d["candidates"][3], self.d["candidates"][2]
        self.assertEqual({k:v for k,v in new.items() if k not in ["id", "support_vertical_compensation"]},
            {k:v for k,v in old.items() if k != "id"})
        self.assertEqual((new["maximum_absolute_correction_rad_s"], new["maximum_slew_per_step_rad_s"]), (3.5, .08))
        self.assertEqual(self.d["height_control"], parent.SETTINGS)
        self.assertFalse(self.d["composition_rule"]["measured_contact_forces_used"])
        for key in ["trained", "training_data_authority", "physical_acceptance_authority", "release_authority", "equivalence_authority"]:
            self.assertFalse(self.d[key])

    def test_opposition_direction_and_independent_damped_normal_equation(self):
        for body_height, knee in [(.45, -1.), (.3, 1.)]:
            state = self.state()
            state["base_pose_world"]["position_m"]["y"] = body_height
            delta, detail = self.evaluate(state, self.baseline(knee))
            reference, _ = parent.feedback(state, self.rows[0]["request"]["command"], self.d["candidates"][2], self.d)
            self.assertNotEqual(delta, reference)
            for leg, receipt in zip(self.d["legs"], detail["legs"], strict=True):
                self.assertTrue(receipt["vertical_opposition"])
                _, jacobian = model.geometry.foot_geometry(leg, -.2, .4)
                extra = receipt["vertical_compensation_delta_rad_s"]
                target = receipt["vertical_compensation_target_xy_m_s"]
                baseline_y = receipt["baseline_foot_velocity_xy_m_s"][1]
                self.assertEqual(target, [0., -baseline_y])
                damping = self.d["jacobian_damping_m"]
                for i in range(2):
                    lhs = sum((sum(jacobian[k][i]*jacobian[k][j] for k in range(2))
                        +(damping*damping if i == j else 0.))*extra[j] for j in range(2))
                    rhs = sum(jacobian[k][i]*target[k] for k in range(2))
                    self.assertAlmostEqual(lhs, rhs, places=14)
                projected_y = sum(a*b for a,b in zip(jacobian[1], extra, strict=True))
                self.assertLess(projected_y*baseline_y, 0.)
                self.assertLessEqual(abs(projected_y), abs(baseline_y)+1e-14)

    def test_helpful_zero_and_unsupported_baselines_add_nothing(self):
        state = self.state()
        expected, _ = parent.feedback(state, self.rows[0]["request"]["command"], self.d["candidates"][2], self.d)
        for knee in [0., 1.]:
            actual, detail = self.evaluate(state, self.baseline(knee))
            self.assertTrue(same_bits(actual, expected))
            self.assertTrue(all(not r["vertical_opposition"] and r["vertical_compensation_delta_rad_s"] == [0., 0.]
                for r in detail["legs"]))
        for contact in state["ordered_contact_observations"]:
            contact.update(presence=False, bears_support=False)
        actual, detail = self.evaluate(state)
        self.assertEqual(actual, [0.]*8)
        self.assertTrue(all(not r["vertical_opposition"] for r in detail["legs"]))
        state["ordered_contact_observations"][0].update(presence=True, bears_support=True)
        _, detail = self.evaluate(state)
        self.assertEqual([r["vertical_opposition"] for r in detail["legs"]], [True, False, False, False])

    def test_reference_bits_and_yaw_invariance_on_retained_inputs(self):
        for row in self.rows:
            args = [row["request"]["state"], row["request"]["command"], self.d["candidates"][2], self.d]
            self.assertTrue(same_bits(model.feedback(*args, None), parent.feedback(*args)))
        state = self.state()
        expected, _ = self.evaluate(state)
        state["base_pose_world"]["orientation_xyzw"] = dict(x=0., y=math.sin(.35), z=0., w=math.cos(.35))
        actual, _ = self.evaluate(state)
        for a,b in zip(expected, actual, strict=True):
            self.assertAlmostEqual(a, b, places=13)

    def test_invalid_baseline_identity_values_and_state_domain_refuse(self):
        for mutate in [lambda b:b["ordered_commands"].pop(),
            lambda b:b["ordered_commands"][0].__setitem__("actuator_id", "rear_right_knee_motor"),
            lambda b:b["ordered_commands"][0].__setitem__("combined_canonical_target_velocity_rad_s", float("nan"))]:
            baseline = self.baseline()
            mutate(baseline)
            with self.assertRaises(ValueError):
                self.evaluate(baseline=baseline)
        for mutate in [lambda s:s["gravity_world_m_s2"].__setitem__("x", .1),
            lambda s:s["base_pose_world"].__setitem__("orientation_xyzw", dict(x=math.sin(.4), y=0., z=0., w=math.cos(.4)))]:
            state = self.state()
            mutate(state)
            with self.assertRaises(ValueError):
                self.evaluate(state)
        candidate = dict(self.d["candidates"][3], maximum_absolute_correction_rad_s=4.)
        with self.assertRaisesRegex(ValueError, "frozen family"):
            model.feedback(self.state(), self.rows[0]["request"]["command"], candidate, self.d, self.baseline())

    def test_real_abi_compensates_actual_baselines_and_matches_independent_core(self):
        pairs = []
        reference = BodyHeightFeedbackController(self.cores[0], self.f.compiled, self.old, 2)
        self.addCleanup(reference.close)
        compensated = 0
        try:
            pairs = [[SupportVerticalController(core, self.f.compiled, self.c, i) for core in self.cores] for i in range(4)]
            previous = [[0.]*8 for _ in pairs]
            for row in self.rows:
                args = [row["request"]["state"], row["stability"], row["kinematics"]]
                old = reference.step(*args)
                for i, pair in enumerate(pairs):
                    value, independent = [controller.step(*args) for controller in pair]
                    self.assertTrue(same_bits(value, independent))
                    validate_proposal(value, self.c, i, previous[i])
                    previous[i] = [c["applied_correction_rad_s"] for c in value["resolution"]["ordered_commands"]]
                    if i == 1:
                        self.assertTrue(same_bits(value["native_targets"], old["native_targets"]))
                        self.assertTrue(same_bits(value["feedback"], old["feedback"]))
                    if i in [2, 3] and value["feedback"]["status"] == "supported":
                        compensated += sum(leg["vertical_opposition"] for leg in value["feedback"]["legs"])
            self.assertGreater(compensated, 0)
            print(json.dumps(dict(real_abi_decisions=480, independent_cores=2,
                compensated_leg_observations=compensated, reference_target_bits=True, world_build_count=0)))
        finally:
            for pair in pairs:
                for controller in pair:
                    controller.close()

    def test_corrupt_provenance_and_baseline_withdraw_without_stale_offsets(self):
        controller = SupportVerticalController(self.cores[0], self.f.compiled, self.c, 2)
        self.addCleanup(controller.close)
        row = self.rows[0]
        value = controller.step(row["request"]["state"], row["stability"], row["kinematics"])
        for mutate in [lambda r:r["provider_response"].__setitem__("request_sha256", "sha256:"+"0"*64),
            lambda r:r["provider_response"]["provenance"].__setitem__("direct_world_access_used", True)]:
            altered = copy.deepcopy(value["resolution_request"])
            mutate(altered)
            resolution = self.cores[0].resolve_adaptation_v1(altered)
            self.assertTrue(resolution["deterministic_baseline_fallback_used"])
            self.assertTrue(all(same_bits(c["baseline_canonical_target_velocity_rad_s"], c["final_canonical_target_velocity_rad_s"])
                for c in resolution["ordered_commands"]))
        request = copy.deepcopy(value["resolution_request"]["provider_request"])
        request["deterministic_baseline"]["ordered_commands"].pop()
        response, detail = controller.response(request)
        self.assertIsNone(response)
        self.assertEqual(detail["status"], "refused")

    def test_changed_parent_rule_and_false_authority_refuse(self):
        original = Path.read_text
        for mutate in [lambda d:d["parent_implementation"].__setitem__("sha256", "0"*64),
            lambda d:d["composition_rule"].__setitem__("target_xy_m_s", "[1, 1]"),
            lambda d:d.__setitem__("trained", True), lambda d:d.__setitem__("release_authority", True)]:
            changed = json.loads(original(model.CONTRACT, encoding="utf-8"))
            mutate(changed)
            with patch.object(Path, "read_text", autospec=True,
                    side_effect=lambda p,*args,**kw:json.dumps(changed) if p == model.CONTRACT else original(p,*args,**kw)):
                with self.assertRaises(ValueError):
                    model.definition()


if __name__ == "__main__":
    unittest.main()
