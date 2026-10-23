"""Real-ABI causal prefix, action-response features and fail-closed lifecycle."""
import copy
import json
import math
from pathlib import Path
import unittest
from unittest.mock import patch
import mujoco
import test_gpu_repertoire_v2 as fixtures
from cpu_context_repertoire_task import declaration, trial_plan
from context_probe_control import ContextProbeController, context_features, PROBE_STEPS, DT, JOINTS
from body_height_feedback_control import BodyHeightFeedbackController
from audit_context_probe import validate_proposal
from audit_gpu_batch_execution import same_bits


class ContextProbeControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RepertoireControls.setUpClass()
        cls.f = fixtures.RepertoireControls
        cls.c = declaration()
        cls.plan = trial_plan(cls.c)[0]
        cls.native = cls.f.native(cls.plan, 0)
        cls.native.pop("contact_compatibility_copy", None)
        cls.rows = []
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("No world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("No data")):
            for index in range(3):
                controller = ContextProbeController(cls.f.core, cls.f.compiled, cls.c, index)
                try:
                    cls.rows.append([controller.step(*cls.f.observations(cls.native, step)) for step in range(66)])
                finally:
                    controller.close()
        for index, rows in enumerate(cls.rows):
            with (cls.f.root/("context-prefix-"+str(index)+".jsonl")).open("x", encoding="utf-8", newline="\n") as stream:
                for row in rows:
                    stream.write(json.dumps(row, allow_nan=False, separators=(",", ":"))+"\n")

    def setUp(self):
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guard = patch.object(mujoco, name, side_effect=AssertionError("No worlds in controls"))
            guard.start()
            self.addCleanup(guard.stop)

    def test_common_prefix_preserves_absent_provider_baseline_bits(self):
        baseline = BodyHeightFeedbackController(self.f.core, self.f.compiled, self.c, 0)
        try:
            for step in range(PROBE_STEPS):
                expected = baseline.step(*self.f.observations(self.native, step))
                for rows in self.rows:
                    for name in ["output", "composition", "native_targets"]:
                        self.assertTrue(same_bits(rows[step][name], expected[name]))
                    self.assertFalse(rows[step]["resolution"]["adaptation_applied"])
                    self.assertEqual(rows[step]["resolution"]["fallback_reason"], "provider_no_proposal")
        finally:
            baseline.close()

    def test_truthful_complete_history_is_private_and_retired_after_choice(self):
        for rows in self.rows:
            window = rows[64]["resolution_request"]["provider_request"]["history"]["ordered_entries"]
            self.assertEqual([entry["semantic_step"] for entry in window], list(range(64)))
            for entry, row in zip(window, rows[:64], strict=True):
                self.assertEqual(entry["state"], row["request"]["state"])
                self.assertEqual(entry["provider_status"], "no_proposal")
                self.assertFalse(entry["adaptation_applied"])
                self.assertEqual(entry["request_sha256"], row["resolution"]["request_sha256"])
            self.assertEqual(rows[65]["resolution_request"]["provider_request"]["history"]["ordered_entries"], [])
        self.assertNotEqual(self.rows[0][64]["resolution_request"]["provider_request"]["expected_model_sha256"],
                            self.rows[2][64]["resolution_request"]["provider_request"]["expected_model_sha256"])
        self.assertTrue(same_bits(self.rows[0][64]["context_probe"]["features"], self.rows[2][64]["context_probe"]["features"]))

    def test_first_influence_is_step_64_and_obeys_fresh_slew_history(self):
        for index, rows in enumerate(self.rows):
            previous = [0.]*8
            for row in rows:
                validate_proposal(row, self.c, index, previous)
                previous = [r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
            first = rows[64]
            values = [r["applied_correction_rad_s"] for r in first["resolution"]["ordered_commands"]]
            self.assertTrue(all(abs(v) <= .08 for v in values))
            if index:
                self.assertTrue(first["resolution"]["adaptation_applied"])
                self.assertTrue(any(v != 0 for v in values))
            else:
                self.assertEqual(values, [0.]*8)

    def test_known_joint_motion_and_issued_actions_have_expected_features(self):
        request = copy.deepcopy(self.rows[2][64]["resolution_request"]["provider_request"])
        entries = request["history"]["ordered_entries"]
        for step, state in enumerate([e["state"] for e in entries]+[request["state"]]):
            for joint in state["ordered_joint_observations"]:
                joint["position_rad"] = .25*step*DT
        for entry in entries:
            for command in entry["deterministic_baseline"]["ordered_commands"]:
                command["combined_canonical_target_velocity_rad_s"] = .5
        vector = context_features(request)
        self.assertEqual(len(vector["values"]), 16)
        for value in vector["values"][:8]:
            self.assertAlmostEqual(value, -.25, places=13)
        for value in vector["values"][8:]:
            self.assertAlmostEqual(value, .25, places=13)

    def test_condition_future_outcome_and_provider_identity_do_not_enter_features(self):
        request = copy.deepcopy(self.rows[1][64]["resolution_request"]["provider_request"])
        expected = context_features(request)
        request.update(condition_id="unobservable", future_outcome="negative", expected_model_id="unrelated", seed=0)
        for entry in request["history"]["ordered_entries"]:
            entry["request_sha256"] = "0"*64
            entry["resolution_receipt_sha256"] = "1"*64
        self.assertTrue(same_bits(expected, context_features(request)))

    def test_incomplete_future_invalid_or_nonbaseline_history_is_refused(self):
        for kind in ["missing", "future", "status", "position", "order", "clock"]:
            request = copy.deepcopy(self.rows[1][64]["resolution_request"]["provider_request"])
            entries = request["history"]["ordered_entries"]
            if kind == "missing": entries.pop(0)
            elif kind == "future": entries[-1]["semantic_step"] = 64
            elif kind == "status": entries[0]["provider_status"] = "applied"
            elif kind == "position": entries[0]["state"]["ordered_joint_observations"][0]["position_rad"] = float("nan")
            elif kind == "order": entries[0]["state"]["ordered_joint_observations"].reverse()
            else: request["state"]["sample_time_s"] += DT
            with self.assertRaises(ValueError): context_features(request)

    def test_partial_host_failure_closes_session_and_cannot_resume(self):
        controller = ContextProbeController(self.f.core, self.f.compiled, self.c, 2)
        with patch("context_probe_control.map_resolution", side_effect=ValueError("injected mapping failure")):
            with self.assertRaisesRegex(ValueError, "mapping failure"):
                controller.step(*self.f.observations(self.native, 0))
        self.assertTrue(controller.closed)
        with self.assertRaisesRegex(ValueError, "lifecycle/clock"):
            controller.step(*self.f.observations(self.native, 0))
        controller.close()

    def test_unsupported_feedback_withdraws_to_exact_current_baseline(self):
        controller = ContextProbeController(self.f.core, self.f.compiled, self.c, 2)
        try:
            for step in range(65): controller.step(*self.f.observations(self.native, step))
            state, stability, kinematics = self.f.observations(self.native, 65)
            state["base_pose_world"]["orientation_xyzw"] = dict(x=math.sin(.45), y=0., z=0., w=math.cos(.45))
            row = controller.step(state, stability, kinematics)
            self.assertEqual(row["feedback"]["status"], "refused")
            self.assertIsNone(row["resolution_request"]["provider_response"])
            for actual, baseline in zip(row["resolution"]["ordered_commands"],
                                        row["composition"]["canonical_actuation"]["ordered_commands"], strict=True):
                self.assertEqual(actual["applied_correction_rad_s"], 0.)
                self.assertTrue(same_bits(actual["final_canonical_target_velocity_rad_s"],
                                          baseline["combined_canonical_target_velocity_rad_s"]))
        finally:
            controller.close()


if __name__ == "__main__": unittest.main()
