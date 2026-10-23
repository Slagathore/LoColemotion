"""Retained trajectory, denominator and counterfactual-boundary controls."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import contextual_action_credit_diagnostic as diagnostic


class ActionCreditControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core = Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline = Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.closure = diagnostic.ROOT/"sdk/discovery/gpu_contextual_influence_closure_v1.json"
        cls.evidence = diagnostic.ROOT.parent/"SporeSpore_Evidence"
        cls.record = json.loads(cls.closure.read_text())
        cls.c = diagnostic.declaration()
        cls.model = diagnostic.load_candidate(diagnostic.bridge.LocomotionCore(cls.core), cls.c)
        cls.trial = diagnostic.trial_plan(cls.c)[0]
        path = cls.evidence/cls.record["attempt_id"]/"physical"/cls.trial["trial_id"]/"controller.jsonl"
        cls.rows = []
        with path.open() as stream:
            for line in stream:
                row = json.loads(line)
                if row["outer_step"] > 60:
                    break
                cls.rows.append(row)

    def diagnose(self, rows):
        return diagnostic.diagnose_rows(rows, self.model, self.trial["mode_order"])

    def test_full_retained_population_and_original_decisions_without_worlds(self):
        with patch.object(mujoco, "MjModel", side_effect=AssertionError("world")), \
                patch.object(mujoco, "MjData", side_effect=AssertionError("data")):
            result = diagnostic.analyze(self.closure, self.evidence, self.core, self.baseline)
        self.assertEqual(result["controller_rows"], 17280)
        self.assertEqual(result["world_build_count"], 0)
        self.assertTrue(result["input_reader_verified"])
        memory = [result["totals"][mode] for mode in diagnostic.contextual.EPISODIC]
        self.assertEqual(sum(m["completed_feedback_updates"] for m in memory), 176)
        self.assertEqual(sum(m["changed_selections"] for m in memory), 27)
        self.assertEqual(sum(m["selections_with_matching_context_feedback"] for m in memory), 84)
        for key in ["physical_acceptance_authority", "release_authority", "training_data_authority",
                    "counterfactual_outcome_authority", "causal_action_credit_identified"]:
            self.assertFalse(result[key])
        for group in result["groups"].values():
            for mode, data in group["modes"].items():
                self.assertEqual(data["controller_rows"], 960)
                for window in data["windows"]:
                    self.assertLess(window["observed_at_step"], 960)
                    self.assertNotIn("alternative_outcome", window)
                if mode in diagnostic.contextual.EPISODIC:
                    self.assertEqual(data["completed_observed_windows"], data["completed_feedback_updates"])
        output = Path(os.environ["EXPLORER_TEST_OUTPUT"])/"diagnostic.json"
        with output.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(result, stream, indent=2, allow_nan=False)
            stream.write("\n")

    def test_missing_rows_crossed_modes_and_partial_rounds_refuse(self):
        for mutate in [lambda rows: rows.pop(0), lambda rows: rows.pop(),
                       lambda rows: rows[0].update(mode="episodic")]:
            rows = copy.deepcopy(self.rows)
            mutate(rows)
            with self.assertRaisesRegex(ValueError, "clock|rounds"):
                self.diagnose(rows)

    def test_changed_feedback_context_and_future_credit_refuse(self):
        for kind in ["outcome", "cue", "future"]:
            rows = copy.deepcopy(self.rows)
            row = next(r for r in rows if r["mode"] == "episodic" and r["outer_step"] == 30)
            if kind == "outcome":
                row["resolution"]["next_memory"]["opaque_state"]["records"][-1]["observed_quality_m_s"] += .01
            elif kind == "cue":
                row["resolution_request"]["provider_request"]["provider_memory"]["opaque_state"]["active"]["start_cue"]["vector"][0] += .01
            else:
                early = next(r for r in rows if r["mode"] == "episodic" and r["outer_step"] == 1)
                early["resolution"]["next_memory"]["opaque_state"]["records"] = copy.deepcopy(row["resolution"]["next_memory"]["opaque_state"]["records"])
            with self.assertRaisesRegex(ValueError, "arithmetic|continuity|future"):
                self.diagnose(rows)

    def test_zero_feedback_is_observed_and_unobserved_is_not_an_outcome(self):
        common = dict(changed=True, all_feedback_actions=[1], supported_feedback_actions=[1],
                      frozen_feedback_offset_m_s=-.01)
        result = diagnostic.decision_summary([
            dict(common, selected_feedback_offset_m_s=None),
            dict(common, selected_feedback_offset_m_s=0.),
            dict(common, selected_feedback_offset_m_s=-.02)])
        self.assertEqual(result["changed_selections"], 3)
        self.assertEqual(result["changed_with_feedback_for_both_choices"], 2)
        self.assertEqual(result["changed_from_negative_feedback_to_unobserved_action"], 1)
        self.assertIsNone(diagnostic.distribution([])["mean"])
        with self.assertRaisesRegex(ValueError, "Nonfinite"):
            diagnostic.distribution([float("nan")])

    def test_correlated_different_actions_do_not_identify_a_common_cause(self):
        cue = dict(phase=[0]*4, contact_mask=15, vector=[0.]*6)
        left = [dict(start_step=i*30, applied_action=1, cue=cue, prediction_error_m_s=value)
                for i, value in enumerate([.01, .02, .03])]
        right = [dict(w, applied_action=2) for w in left]
        result = diagnostic.paired_errors(left, right, self.model.plan())
        self.assertEqual(result["different_action_matching_context_pairs"], 3)
        self.assertAlmostEqual(result["different_action_error_correlation"], 1.)
        self.assertFalse(result["common_error_identified"])
        self.assertFalse(result["counterfactual_outcome_authority"])
        self.assertIsNone(diagnostic.correlation([(1., 2.), (1., 3.)]))
        self.assertIsNone(diagnostic.correlation([(1., 2.)]))
        right[0] = dict(right[0], cue=dict(cue, contact_mask=0))
        self.assertEqual(diagnostic.paired_errors(left, right, self.model.plan())["matching_context_pairs"], 2)


if __name__ == "__main__":
    unittest.main()
