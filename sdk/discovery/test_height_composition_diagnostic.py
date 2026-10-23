"""Independent projection oracles and retained-evidence refusal controls."""
import copy
from contextlib import ExitStack
import itertools
import json
import math
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import mujoco
import height_composition_diagnostic as reader


class CompositionControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("height_composition_diagnostic_v1.json")
        cls.record = reader.read(cls.path)
        cls.evidence = reader.ROOT.parent/"SporeSpore_Evidence"
        cls.physical = cls.evidence/cls.record["source_attempt"]/"physical"
        cls.model = reader.height.definition()
        cls.geometry = reader.geometry_inputs(cls.physical/"models/left_075")
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("composition-refusals-"+uuid.uuid4().hex)
        cls.output.mkdir()
        cls.trial = cls.physical/"left_075_train_001_height_immediate"
        with (cls.trial/"controller.jsonl").open(encoding="utf-8") as stream:
            cls.rows = [json.loads(line) for line in itertools.islice(stream, 120)]

    def setUp(self):
        guards = ExitStack()
        self.addCleanup(guards.close)
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guards.enter_context(patch.object(mujoco, name, side_effect=AssertionError("No worlds in composition diagnosis")))

    def test_complete_native_population_and_diagnostic_regenerate_without_worlds(self):
        result = reader.verify_record(self.path, self.evidence, self.core, self.baseline)
        self.assertTrue(result["ok"])
        self.assertEqual((result["controller_rows"], result["internal_samples"], result["leg_evaluations"]), (480, 2400, 1920))
        self.assertEqual(result["source_trial_count"], 12)
        self.assertEqual(result["supported_leg_observations"], [250, 249, 248, 247])
        self.assertTrue(all(result[k] is False for k in reader.AUTHORITY))
        self.assertEqual((result["world_build_count"], result["solver_steps"]), (0, 0))
        self.assertEqual([t["original_outcome"] for t in self.record["trials"]], ["positive", "negative", "negative", "negative"])
        self.assertEqual(self.record["original_repertoire"]["ranked_role_indices"], [])
        self.assertTrue(self.record["requested_motion_excludes_baseline_gait_objective"])
        self.assertFalse(self.record["discrepancy_is_campaign_tracking_quality"])
        self.assertFalse(self.record["actuator_torques_are_contact_forces"])
        print(json.dumps(result, sort_keys=True))

    def test_projection_matches_independent_finite_difference(self):
        maximum = 0.
        for leg, hip, knee, velocity in itertools.product(self.model["legs"], [-.4, 0., .4], [0., .3, .8],
                [[1., 0.], [0., 1.], [-.7, 1.3], [0., 0.]]):
            def point(h, k):
                a, b = leg["upper_length_m"], leg["lower_length_m"]
                return [a*math.sin(h)+b*math.sin(h+k), -a*math.cos(h)-b*math.cos(h+k)]
            epsilon = 1e-7
            plus = point(hip+epsilon*velocity[0], knee+epsilon*velocity[1])
            minus = point(hip-epsilon*velocity[0], knee-epsilon*velocity[1])
            numerical = [(a-b)/(2*epsilon) for a, b in zip(plus, minus)]
            _, jacobian = reader.geometry.foot_geometry(leg, hip, knee)
            predicted = reader.project(jacobian, velocity)
            maximum = max(maximum, max(abs(a-b) for a, b in zip(numerical, predicted)))
        self.assertLess(maximum, 1e-8)
        print(json.dumps(dict(independent_projection_checks=144, maximum_finite_difference_error_m_s=maximum)))

    def test_opposing_velocity_is_algebra_not_a_physical_counterfactual(self):
        jacobian = [[.4, .2], [.1, -.2]]
        baseline = reader.project(jacobian, [1., 1.])
        feedback = reader.project(jacobian, [0., -1.])
        combined = reader.project(jacobian, [1., 0.])
        self.assertLess(baseline[1], 0.)
        self.assertGreater(feedback[1], 0.)
        self.assertLess(combined[1], feedback[1])
        for i in range(2):
            self.assertAlmostEqual(combined[i], baseline[i]+feedback[i], places=15)
        for j, v in [([[1.], [2.]], [0., 1.]), (jacobian, [float("nan"), 0.]),
                     ([[float("inf"), 0.], [0., 1.]], [0., 1.])]:
            with self.assertRaisesRegex(ValueError, "Projection shape/finite domain"):
                reader.project(j, v)

    def test_native_pose_feedback_receipt_and_measurement_semantics_refuse(self):
        row = self.rows[50]
        reader.describe_frame(row, self.model, *self.geometry)
        mutations = [
            (lambda x: x["feedback"]["legs"][0]["raw_combined_rad_s"].__setitem__(0, 10.), "feedback calculation"),
            (lambda x: x["resolution"]["ordered_commands"][0].__setitem__("proposed_correction_rad_s", 10.), "proposed-command join"),
            (lambda x: next(b for b in x["stability"]["ordered_body_states"] if b["body_id"] == "front_right_distal")["pose_world"]["position_m"].__setitem__("y", 10.), "endpoint mismatch|below geometric bound"),
            (lambda x: x["request"]["state"]["ordered_contact_observations"][0].__setitem__("normal_load_n", 1.), "measured normal load"),
            (lambda x: x["activation_probe"].__setitem__("activation_step", 16), "step/activation"),
        ]
        for mutate, message in mutations:
            value = copy.deepcopy(row)
            mutate(value)
            with self.assertRaisesRegex(ValueError, message):
                reader.describe_frame(value, self.model, *self.geometry)

    def test_complete_population_and_common_pre_failure_interval_refuse(self):
        parent = reader.read(reader.PARENT)
        for mutate, message in [
                (lambda x: x["finite_outcomes"]["trials"].pop(), "source population"),
                (lambda x: x["finite_outcomes"]["trials"][4].__setitem__("role", "baseline"), "immediate population"),
                (lambda x: x["finite_outcomes"]["trials"][4]["native_metrics"]["first_physical_violation"].__setitem__("internal_step", 600), "crosses first violation")]:
            value = copy.deepcopy(parent)
            mutate(value)
            with self.assertRaisesRegex(ValueError, message):
                reader.check_trials(value)

    def test_original_artifacts_and_raw_order_refuse(self):
        original_sha = reader.sha
        for target, message in [(reader.PARENT, "parent closure changed"),
                (self.physical/"models/left_075/model.xml", "original input changed")]:
            with patch.object(reader, "sha", side_effect=lambda p: "0"*64 if Path(p) == target else original_sha(p)):
                with self.assertRaisesRegex(ValueError, message):
                    reader.analyze(self.evidence)
        original_rows = reader.read_jsonl
        def altered(path):
            values = list(original_rows(path))
            if Path(path) == self.trial/"trace.jsonl":
                values[0], values[1] = values[1], values[0]
            return values
        with patch.object(reader, "read_jsonl", side_effect=altered):
            with self.assertRaisesRegex(ValueError, "raw population/order"):
                reader.analyze(self.evidence)

    def test_result_authority_quality_and_source_binding_changes_refuse(self):
        mutations = [lambda x: x.__setitem__("causal_authority", True),
            lambda x: x.__setitem__("discrepancy_is_campaign_tracking_quality", True),
            lambda x: x.__setitem__("source_negative", 0),
            lambda x: x["trials"][0].__setitem__("baseline_opposes_requested_vertical", 0),
            lambda x: x["trials"][0]["mean_vertical_discrepancy_m_s"].__setitem__("unclamped_sum", 0.),
            lambda x: x["implementation_bindings"][0].__setitem__("sha256", "0"*64)]
        # The integration control above verifies the full parent. Every altered
        # record below still recomputes the diagnostic from all original files.
        with patch.object(reader, "verify_parent", return_value=None):
            for mutate in mutations:
                value = copy.deepcopy(self.record)
                mutate(value)
                path = self.output/(uuid.uuid4().hex+".json")
                path.write_text(json.dumps(value, allow_nan=False), encoding="utf-8", newline="\n")
                with self.assertRaisesRegex(ValueError, "diagnostic record changed"):
                    reader.verify_record(path, self.evidence, self.core, self.baseline)
        with patch.object(reader, "verify_parent", side_effect=ValueError("Parent refusal")):
            with self.assertRaisesRegex(ValueError, "Parent refusal"):
                reader.verify_record(self.path, self.evidence, self.core, self.baseline)


if __name__ == "__main__":
    unittest.main()
