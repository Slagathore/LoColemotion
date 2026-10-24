"""Phase, measurement timing, population and retained-evidence refusal controls."""
import copy
from contextlib import ExitStack
from itertools import islice
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
import uuid

import mujoco
import phase_contact_diagnostic as reader


class PhaseContactControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = Path(__file__).with_name("phase_contact_diagnostic_v1.json")
        cls.record = reader.read(cls.path)
        cls.evidence = reader.ROOT.parent/"SporeSpore_Evidence"
        cls.physical = cls.evidence/cls.record["source_attempt"]/"physical"
        cls.model = reader.feedback.definition()
        cls.geometry = reader.geometry_inputs(cls.physical/"models/left_075")
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/("phase-refusals-"+uuid.uuid4().hex)
        cls.output.mkdir()
        cls.trial = cls.physical/"left_075_train_003_vertical_immediate"
        cls.rows = list(islice(reader.read_jsonl(cls.trial/"controller.jsonl"), 96))
        cls.trace = list(islice(reader.read_jsonl(cls.trial/"trace.jsonl"), 480))

    def setUp(self):
        guards = ExitStack()
        self.addCleanup(guards.close)
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guards.enter_context(patch.object(mujoco, name, side_effect=AssertionError("No worlds in phase diagnosis")))

    def frame(self, row=None, samples=None):
        return reader.describe_frame(self.rows[32] if row is None else row,
            self.trace[160:165] if samples is None else samples, self.model, *self.geometry)

    def test_full_parent_and_all_roles_regenerate_without_worlds(self):
        result = reader.verify_record(self.path, self.evidence, self.core, self.baseline)
        self.assertTrue(result["ok"])
        self.assertEqual((result["source_trial_count"], result["controller_rows"], result["internal_samples"],
            result["leg_evaluations"], result["joint_command_response_pairs"]), (16, 1536, 7680, 6144, 12288))
        self.assertEqual((result["world_build_count"], result["solver_steps"]), (0, 0))
        self.assertTrue(all(result[k] is False for k in reader.AUTHORITY))
        self.assertEqual(sum(t["original_outcome"] == "positive" for t in self.record["trials"]), 2)
        self.assertFalse(self.record["roles_or_starts_excluded"])
        self.assertEqual(self.record["original_repertoire"]["ranked_role_indices"], [])
        print(json.dumps(result, sort_keys=True))

    def test_phase_boundaries_and_wrap_match_independent_schedule(self):
        # Offsets are the published wave order, expressed independently of the helper.
        offsets = {"rear_left": 0, "front_left": 90, "rear_right": 180, "front_right": 270}
        for limb, offset in offsets.items():
            for cycle in [0, 1, 9]:
                for local, expected in [(0, "swing"), (71, "swing"), (72, "stance"), (359, "stance")]:
                    self.assertEqual(reader.phase(cycle*360+offset+local, limb), (local, expected))
        for gait, limb in [(True, "rear_left"), (-1, "rear_left"), (1.5, "rear_left"), (0, "unknown")]:
            with self.assertRaisesRegex(ValueError, "Phase input domain"):
                reader.phase(gait, limb)
        for i in [0, 71, 72, 90, 95]:
            frame = reader.describe_frame(self.rows[i], self.trace[i*5:i*5+5], self.model, *self.geometry)
            self.assertEqual([l["local_phase_step"] for l in frame["legs"]],
                [(i-offsets[name]) % 360 for name in reader.geometry.LEGS])

    def test_phase_receipt_context_and_clock_cannot_be_substituted(self):
        mutations = [
            (lambda x: x["output"]["actuation"]["receipt"]["forward_velocity_foot_placement"]["ordered_limb_corrections"][0].__setitem__("local_phase_step", 0), "receipt/memory mismatch"),
            (lambda x: x["resolution_request"]["provider_request"]["controller_context"]["controller_memory"].__setitem__("last_semantic_step", 0), "provider memory join"),
            (lambda x: x["request"]["state"].__setitem__("semantic_step", 33), "controller clock"),
            (lambda x: x["feedback"]["legs"][0]["raw_combined_rad_s"].__setitem__(0, 10.), "feedback replay"),
            (lambda x: x["request"]["state"]["ordered_contact_observations"][0].__setitem__("normal_load_n", 1.), "unavailable contact load"),
        ]
        for mutate, message in mutations:
            row = copy.deepcopy(self.rows[32])
            mutate(row)
            with self.assertRaisesRegex(ValueError, message):
                self.frame(row=row)

    def test_response_uses_actual_end_of_command_and_rejects_crossed_timing(self):
        frame = self.frame()
        for i, leg in enumerate(frame["legs"]):
            targets = self.rows[32]["native_targets"][2*i:2*i+2]
            after = self.trace[164]["qvel"][6+2*i:8+2*i]
            self.assertEqual(leg["joint_velocity_rad_s"]["observed_after"], after)
            self.assertEqual(leg["end_of_command_error_rad_s"], [a-b for a, b in zip(after, targets)])
        for mutate, message in [
            (lambda x: x.pop(), "five-substep order"),
            (lambda x: x[0].__setitem__("step", 162), "five-substep order"),
            (lambda x: x[0]["before_qvel"].__setitem__(6, 10.), "prepared observation join"),
            (lambda x: x[2]["ctrl"].__setitem__(0, 10.), "held command join"),
            (lambda x: x[2]["before_qvel"].__setitem__(6, 10.), "substep continuity"),
            (lambda x: x[4]["qvel"].__setitem__(6, float("nan")), "native response domain")]:
            samples = copy.deepcopy(self.trace[160:165])
            mutate(samples)
            with self.assertRaisesRegex(ValueError, message):
                self.frame(samples=samples)

    def test_strata_keep_denominators_zero_groups_and_missing_stance_runs(self):
        for trial in self.record["trials"]:
            strata = trial["by_phase_contact"]
            self.assertEqual(sum(s["leg_observations"] for s in strata.values()), 384)
            self.assertEqual(sum(s["joint_commands"] for s in strata.values()), 768)
            self.assertEqual(sum(s["internal_joint_samples"] for s in strata.values()), 3840)
            for leg in trial["by_limb"]:
                self.assertEqual(sum(leg["phase_contact_counts"].values()), 96)
        empty = reader.aggregate([])
        self.assertIsNone(empty["rms_end_error_rad_s"])
        self.assertIsNone(empty["mean_absolute_end_error_rad_s"])
        values = ["stance_missing", "stance_missing", "swing_missing", "stance_missing", "stance_support"]
        self.assertEqual(reader.longest_missing_stance([dict(stratum=v) for v in values]), 2)

    def test_complete_population_outcomes_and_pre_failure_boundary_refuse(self):
        parent = reader.read(reader.PARENT)
        for mutate, message in [
            (lambda x: x["finite_outcomes"]["trials"].pop(), "complete source population"),
            (lambda x: x["finite_outcomes"]["trials"][2].__setitem__("outcome", "negative"), "identity/outcome"),
            (lambda x: x["finite_outcomes"]["trials"][0]["native_metrics"]["first_physical_violation"].__setitem__("internal_step", 480), "crosses first violation")]:
            value = copy.deepcopy(parent)
            mutate(value)
            with self.assertRaisesRegex(ValueError, message):
                reader.check_trials(value)

    def test_original_file_hashes_and_prefix_order_refuse(self):
        original_sha = reader.sha
        for target, message in [(reader.PARENT, "parent closure changed"),
            (self.physical/"models/left_075/model.xml", "original input changed")]:
            with patch.object(reader, "sha", side_effect=lambda p: "0"*64 if Path(p) == target else original_sha(p)):
                with self.assertRaisesRegex(ValueError, message):
                    reader.analyze(self.evidence)
        original_rows = reader.read_jsonl
        def altered(path):
            values = original_rows(path)
            if Path(path).name == "trace.jsonl":
                first, second = next(values), next(values)
                yield second
                yield first
            yield from values
        with patch.object(reader, "read_jsonl", side_effect=altered):
            with self.assertRaisesRegex(ValueError, "raw prefix order/count"):
                reader.analyze(self.evidence)

    def test_diagnostic_counts_authority_and_bindings_cannot_be_promoted(self):
        mutations = [lambda x: x.__setitem__("causal_authority", True),
            lambda x: x.__setitem__("joint_response_error_is_campaign_tracking_quality", True),
            lambda x: x["trials"][0]["by_phase_contact"]["stance_missing"].__setitem__("leg_observations", 0),
            lambda x: x["implementation_bindings"][0].__setitem__("sha256", "0"*64)]
        # The integration test verifies the entire parent. These mutations each
        # recompute the sixteen-trial diagnostic against the original raw files.
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
