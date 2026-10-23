"""Geometry, feedback direction and real-ABI controls without new worlds."""
import copy
import itertools
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco

from adaptation_provider import stance_feedback_v1 as model
from stance_feedback_control import StanceFeedbackController
from cpu_motor_task import ROOT, declaration, sha
from portable_search_control import bridge
from audit_gpu_batch_execution import same_bits

ATTEMPT = "sdk2-cpu-motor-challenge-cb4a0973db81433893c77efe198475bb"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


class StanceFeedbackControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.d = model.definition(); cls.c = declaration()
        cls.c["provider"] = dict(kind="untrained_stance_feedback_v1", candidates=cls.d["candidates"],
            maximum_absolute_correction_rad_s=.25, maximum_slew_per_step_rad_s=.02)
        cls.evidence = ROOT.parent/"SporeSpore_Evidence"; cls.folder = cls.evidence/ATTEMPT/"physical"
        cls.closure = read(ROOT/"sdk/discovery/cpu_motor_challenge_closure_v1.json")
        cls.bindings = {r["evidence_relative_path"]: r["sha256"] for r in cls.closure["artifacts"]}
        cls.compiled = read(cls.folder/"compiled.json")
        paths = [cls.folder/"compiled.json"] + list(cls.folder.glob("*/controller.jsonl"))
        assert len(paths) == 5
        for path in paths:
            assert sha(path) == cls.bindings[path.relative_to(cls.evidence).as_posix()]
        with (cls.folder/"start_002_baseline/controller.jsonl").open() as stream:
            cls.rows = [json.loads(line) for line in itertools.islice(stream, 128)]
        cls.core = bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        cls.baseline = bridge.LocomotionCore(Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))

    def setUp(self):
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guard = patch.object(mujoco, name, side_effect=AssertionError("No worlds in feedback controls"))
            guard.start(); self.addCleanup(guard.stop)

    def test_exact_geometry_matches_all_retained_native_frames(self):
        model.validate_geometry(self.compiled, self.d)
        maximum_position_error = maximum_jacobian_error = 0.
        frames = 0
        for path in sorted(self.folder.glob("*/controller.jsonl")):
            with path.open() as stream:
                for line in stream:
                    row = json.loads(line); state = row["request"]["state"]
                    angles = {r["joint_id"]: r["position_rad"] for r in state["ordered_joint_observations"]}
                    base = state["base_pose_world"]; rotate = model.rotation(base["orientation_xyzw"])
                    origin = model.vector(base["position_m"])
                    bodies = {r["body_id"]: r["pose_world"] for r in row["stability"]["ordered_body_states"]}
                    native = {r["actuator_id"]: r for r in row["kinematics"]}
                    for leg in self.d["legs"]:
                        point, jacobian = model.foot_geometry(leg, angles[leg["id"]+"_hip"], angles[leg["id"]+"_knee"])
                        expected = [a+b for a,b in zip(origin, model.transform(rotate, point), strict=True)]
                        distal = bodies[leg["id"]+"_distal"]
                        local = model.transform(model.rotation(distal["orientation_xyzw"]), [0., -leg["lower_length_m"]/2, 0.])
                        measured = [a+b for a,b in zip(model.vector(distal["position_m"]), local, strict=True)]
                        maximum_position_error = max(maximum_position_error, max(abs(a-b) for a,b in zip(expected, measured)))
                        for column, joint in enumerate(["hip", "knee"]):
                            observation = native[leg["id"]+"_"+joint+"_motor"]
                            arm = [a-b for a,b in zip(measured, model.vector(observation["joint_anchor_world_m"]))]
                            derivative = cross(model.vector(observation["joint_axis_world_unit"]), arm)
                            predicted = model.transform(rotate, [jacobian[0][column], jacobian[1][column], 0.])
                            maximum_jacobian_error = max(maximum_jacobian_error, max(abs(a-b) for a,b in zip(predicted, derivative)))
                    frames += 1
        self.assertEqual(frames, 1920)
        self.assertLess(maximum_position_error, 1e-10)
        self.assertLess(maximum_jacobian_error, 1e-10)
        print(json.dumps(dict(retained_geometry_frames=frames, maximum_position_error_m=maximum_position_error,
            maximum_jacobian_error_m_per_rad=maximum_jacobian_error, world_build_count=0)))

    def test_jacobian_finite_difference_and_singular_damping(self):
        leg = self.d["legs"][0]; eps = 1e-6
        for hip, knee in itertools.product([-.6, 0., .6], [0., .4, 1.]):
            _, jacobian = model.foot_geometry(leg, hip, knee)
            for column in range(2):
                plus = model.foot_geometry(leg, hip+(eps if column == 0 else 0), knee+(eps if column == 1 else 0))[0]
                minus = model.foot_geometry(leg, hip-(eps if column == 0 else 0), knee-(eps if column == 1 else 0))[0]
                for axis in range(2):
                    self.assertAlmostEqual((plus[axis]-minus[axis])/(2*eps), jacobian[axis][column], delta=1e-9)
        self.assertEqual(model.inverse_velocity([[0.,0.],[0.,0.]], [.1,.1], .03), [0.,0.])
        result = model.inverse_velocity([[1.,0.],[0.,1.]], [.2,-.3], .03)
        for observed, expected in zip(result, [.2/(1+.03**2), -.3/(1+.03**2)]):
            self.assertAlmostEqual(observed, expected, places=14)
        _, jacobian = model.foot_geometry(leg, 0., 0.)
        self.assertEqual(model.inverse_velocity(jacobian, [0.,1.], .03), [0.,0.])

    def controlled_state(self):
        state = copy.deepcopy(self.rows[0]["request"]["state"])
        for r in state["ordered_joint_observations"]:
            r["position_rad"] = -.2 if r["joint_id"].endswith("hip") else .4
        for r in state["ordered_contact_observations"]:
            r.update(presence=True, bears_support=True)
        return state

    def test_attitude_rate_directions_and_support_gating(self):
        candidate = self.d["candidates"][4]; state = self.controlled_state()
        command = self.rows[0]["request"]["command"]
        delta, detail = model.feedback(state, command, candidate, self.d)
        self.assertEqual(delta, [0.]*8)
        # Positive x body tilt must request negative x angular correction.
        state["base_pose_world"]["orientation_xyzw"] = dict(x=math.sin(.1), y=0., z=0., w=math.cos(.1))
        delta, detail = model.feedback(state, command, candidate, self.d)
        self.assertLess(detail["requested_angular_velocity_body_rad_s"][0], 0)
        self.assertGreater(detail["legs"][0]["requested_foot_velocity_xy_m_s"][1], 0)
        self.assertLess(detail["legs"][1]["requested_foot_velocity_xy_m_s"][1], 0)
        self.assertTrue(any(v != 0 for v in delta))
        for row in state["ordered_contact_observations"]:
            row.update(presence=False, bears_support=False)
        delta, _ = model.feedback(state, command, candidate, self.d)
        self.assertEqual(delta, [0.]*8)
        state = self.controlled_state(); state["base_twist_world"]["angular_velocity_rad_s"]["z"] = .2
        _, detail = model.feedback(state, command, candidate, self.d)
        self.assertLess(detail["requested_angular_velocity_body_rad_s"][2], 0)

    def test_body_feedback_is_invariant_to_world_yaw(self):
        state = self.controlled_state(); command = self.rows[0]["request"]["command"]
        state["base_twist_world"]["angular_velocity_rad_s"] = dict(x=.2, y=.1, z=-.3)
        state["base_twist_world"]["linear_velocity_m_s"] = dict(x=.1, y=.02, z=.03)
        candidate = self.d["candidates"][10]
        expected, _ = model.feedback(state, command, candidate, self.d)
        turned = copy.deepcopy(state); angle = .7
        q = dict(x=0., y=math.sin(angle/2), z=0., w=math.cos(angle/2)); rotate = model.rotation(q)
        turned["base_pose_world"]["orientation_xyzw"] = q
        for key in ["angular_velocity_rad_s", "linear_velocity_m_s"]:
            turned["base_twist_world"][key] = dict(zip(["x","y","z"], model.transform(rotate, model.vector(state["base_twist_world"][key]))))
        for key in ["forward_axis_world_unit", "lateral_axis_world_unit"]:
            turned["task_frame"][key] = dict(zip(["x","y","z"], model.transform(rotate, model.vector(state["task_frame"][key]))))
        actual, _ = model.feedback(turned, command, candidate, self.d)
        for a,b in zip(expected, actual): self.assertAlmostEqual(a,b,places=12)
        # Speed-domain membership must also be invariant under world yaw.
        for speed in [9.9, 10.1]:
            value = [.8*speed, 0., .6*speed]
            state["base_twist_world"]["linear_velocity_m_s"] = dict(zip(["x","y","z"], value))
            turned["base_twist_world"]["linear_velocity_m_s"] = dict(zip(["x","y","z"], model.transform(rotate, value)))
            for test_state in [state, turned]:
                if speed < 10.:
                    model.feedback(test_state, command, candidate, self.d)
                else:
                    with self.assertRaisesRegex(ValueError, "speed domain"):
                        model.feedback(test_state, command, candidate, self.d)

    def test_invalid_geometry_candidate_and_observation_refuse(self):
        for change in [lambda c: c["descriptor"].__setitem__("leg_length_scale", 99.),
            lambda c: c["morphology"]["morphology_spec"]["joints"][0]["axis_parent_unit"].__setitem__("z", -1.)]:
            compiled = copy.deepcopy(self.compiled); change(compiled)
            with self.assertRaises(ValueError): model.validate_geometry(compiled, self.d)
        candidate = copy.deepcopy(self.d["candidates"][4]); candidate["attitude_gain_s_inv"] = 7.
        with self.assertRaises(ValueError): model.validate_candidate(candidate)
        for change in [lambda s: s["base_pose_world"]["orientation_xyzw"].__setitem__("w", 2.),
            lambda s: s["ordered_joint_observations"][0].__setitem__("position_rad", math.nan),
            lambda s: s["ordered_contact_observations"][0].__setitem__("presence", False),
            lambda s: s["base_twist_world"]["angular_velocity_rad_s"].__setitem__("x", 21.)]:
            state = self.controlled_state(); change(state)
            with self.assertRaises(ValueError): model.feedback(state, self.rows[0]["request"]["command"], self.d["candidates"][4], self.d)

    def test_real_abi_baseline_bits_and_independent_core_feedback_replay(self):
        controllers = [StanceFeedbackController(core, self.compiled, self.c, cell)
            for core, cell in [(self.core, 0), (self.core, 4), (self.baseline, 4)]]
        applied = refused = 0; previous = [0.]*8
        try:
            for row in self.rows:
                state = row["request"]["state"]
                old, new, independent = [c.step(state, row["stability"], row["kinematics"]) for c in controllers]
                self.assertTrue(same_bits(old["native_targets"], row["native_targets"]))
                self.assertTrue(same_bits(new, independent))
                resolution = new["resolution"]
                if resolution["deterministic_baseline_fallback_used"]:
                    refused += 1
                    self.assertTrue(same_bits(new["native_targets"], old["native_targets"]))
                else:
                    applied += 1
                    for value, prior in zip(resolution["ordered_commands"], previous):
                        self.assertLessEqual(abs(value["applied_correction_rad_s"]), .25)
                        self.assertLessEqual(abs(value["applied_correction_rad_s"]-prior), .020000000001)
                previous = [r["applied_correction_rad_s"] for r in resolution["ordered_commands"]]
            self.assertGreater(applied, 0); self.assertGreater(refused, 0)
            print(json.dumps(dict(real_abi_steps=len(self.rows), applied=applied, refused=refused, independent_replay=True)))
        finally:
            for c in controllers: c.close()

    def test_corrupt_response_and_unsupported_tilt_restore_exact_baseline(self):
        controller = StanceFeedbackController(self.core, self.compiled, self.c, 4)
        try:
            row = self.rows[0]
            result = controller.step(row["request"]["state"], row["stability"], row["kinematics"])
            request = result["resolution_request"]
            for change in [lambda r: r["provider_response"].__setitem__("request_sha256", "sha256:"+"0"*64),
                lambda r: r["provider_response"]["provenance"].__setitem__("direct_world_access_used", True)]:
                altered = copy.deepcopy(request); change(altered)
                outcome = self.core.resolve_adaptation_v1(altered)
                self.assertTrue(outcome["deterministic_baseline_fallback_used"])
                self.assertTrue(all(same_bits(r["final_canonical_target_velocity_rad_s"], r["baseline_canonical_target_velocity_rad_s"])
                    for r in outcome["ordered_commands"]))
            altered = copy.deepcopy(request["provider_request"])
            altered["state"]["base_pose_world"]["orientation_xyzw"] = dict(x=math.sin(.4),y=0.,z=0.,w=math.cos(.4))
            response, detail = controller.response(altered)
            self.assertIsNone(response); self.assertEqual(detail["status"], "refused")
        finally: controller.close()

    def test_all_candidates_bind_distinct_models_and_preserve_inputs(self):
        models = []
        original = copy.deepcopy(self.c)
        for cell in range(12):
            controller = StanceFeedbackController(self.core, self.compiled, self.c, cell)
            try:
                models.append(controller.model_digest)
                r = self.rows[0]
                result = controller.step(r["request"]["state"], r["stability"], r["kinematics"])
                self.assertIn(result["resolution"]["fallback_reason"], ["none", "provider_absent", "safe_no_actuation"])
            finally: controller.close()
        self.assertEqual(len(set(models)), 12)
        self.assertEqual(self.c, original)


if __name__ == "__main__":
    unittest.main()
