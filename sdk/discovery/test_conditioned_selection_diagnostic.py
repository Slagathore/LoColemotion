"""Check full-population diagnosis, timing boundaries and real corruption stimuli."""
import copy
from contextlib import ExitStack
from itertools import islice
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import conditioned_selection_diagnostic as reader


class SelectionDiagnosticControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parent = reader.read(reader.PARENT)
        cls.evidence = (reader.ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
        cls.physical = cls.evidence/cls.parent["attempt_id"]/"physical"
        cls.trials, cls.contract = reader.check_population(cls.parent)
        cls.directory = cls.physical/"left_075_train_006_frozen"
        cls.trial = next(t for t in cls.trials if t["trial_id"] == cls.directory.name)
        cls.row = next(islice(reader.read_jsonl(cls.directory/"controller.jsonl"), 100, None))
        cls.plan = reader.learner.contract()

    def setUp(self):
        guards = ExitStack()
        self.addCleanup(guards.close)
        for name in ["MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"]:
            guards.enter_context(patch.object(mujoco, name, side_effect=AssertionError("No worlds in selection diagnosis")))

    def frames(self, count=61):
        return [dict(step=i, position=[i*reader.DT*self.plan["desired_forward_velocity_m_s"], 0.],
            proposed=1, logical=1, reason="current_case_retrieval", proposal_applied=True,
            support_count=4, nonzero=True, correction=[.1]*8, slew_clamps=0, absolute_clamps=0,
            speed_clamps=0, prediction=None, support_distance=.5) for i in range(count)]

    def windows(self, frames, first=None):
        final=[len(frames)*reader.DT*self.plan["desired_forward_velocity_m_s"],0.]
        return reader.summarize_windows(frames, final, first, self.plan)

    def test_complete_parent_and_all_forty_trials_regenerate(self):
        path=Path(os.environ["CONDITIONED_SELECTION_DIAGNOSTIC_RECORD"])
        result=reader.verify_record(path,self.evidence,Path(os.environ["QUADRUPED_TEST_CORE"]),
            Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"]))
        self.assertTrue(result["ok"])
        self.assertEqual((result["source_trials"],result["controller_rows"],result["internal_samples"]),(40,57600,288000))
        self.assertTrue(all(result[k] is False for k in reader.AUTHORITY))
        record=reader.read(path)
        self.assertEqual(sum(t["original_outcome"]=="negative" for t in record["trials"]),14)
        self.assertTrue(all(t["official_quality_m_s"] is None for t in record["trials"] if t["original_outcome"]=="negative"))
        print(json.dumps(result,sort_keys=True))

    def test_actual_proposed_expert_prediction_survives_shuffling(self):
        row=copy.deepcopy(self.row)
        row["selection"]["role"].update(id="shuffled",mode="shuffled")
        d=row["selection"]["decision"]
        d.update(mode="shuffled",logical_action_index=2,proposed_action_index=1,candidate_index=3)
        d["predictions"]=[dict(action_index=1,quality_m_s=-.1,support_distance=.2),
            dict(action_index=2,quality_m_s=-.9,support_distance=.8)]
        frame=reader.describe(row,"shuffled",100)
        self.assertEqual((frame["logical"],frame["proposed"],frame["prediction"],frame["support_distance"]),(2,1,-.1,.2))
        d["proposed_action_index"]=2
        with self.assertRaisesRegex(ValueError,"shuffled association"):
            reader.describe(row,"shuffled",100)

    def test_real_clock_state_role_and_nonfinite_mutations_refuse(self):
        changes=[
            (lambda r:r.__setitem__("outer_step",99),"order/clock"),
            (lambda r:r["selection"]["role"].__setitem__("id","disabled"),"crossed role"),
            (lambda r:r["resolution_request"]["provider_request"]["state"].__setitem__("sample_time_s",0.),"state join"),
            (lambda r:r["resolution"]["ordered_commands"][0].__setitem__("applied_correction_rad_s",float("nan")),"finite corrections"),
            (lambda r:r["selection"]["decision"]["predictions"][0].__setitem__("support_distance",float("nan")),"prediction domain")]
        for change,message in changes:
            row=copy.deepcopy(self.row);change(row)
            with self.assertRaisesRegex(ValueError,message):
                reader.describe(row,"frozen",100)

    def test_support_gaps_are_not_direct_expert_switches(self):
        frames=self.frames(6)
        for f,action in zip(frames,[1,None,2,1,1,None]):
            f["proposed"]=action
        result=reader.summarize_frames(frames)
        self.assertEqual(result["direct_expert_switches"],1)
        self.assertEqual(result["first_expert_switch_step"],3)
        self.assertEqual(result["transitions"],{"1->None":2,"None->2":1,"2->1":1})
        self.assertEqual(sum(result["support_count_histogram"].values()),6)
        self.assertIsNone(reader.summarize_frames([])["mean_switch_applied_correction_l1_rad_s"])

    def test_first_violation_equality_and_end_of_horizon_are_censored(self):
        frames=self.frames()
        for i in [0,1,31,60]:frames[i]["prediction"]=0.
        result=self.windows(frames,151)["counts"]
        self.assertEqual(result,dict(predicted_correction_starts=4,proposal_not_applied=0,
            starts_after_first_violation=2,right_censored=0,crosses_first_violation=1,
            complete_pre_failure_windows=1))
        self.assertEqual(self.windows(frames,150)["counts"]["complete_pre_failure_windows"],0)
        unfailed=self.windows(frames)["counts"]
        self.assertEqual((unfailed["right_censored"],unfailed["complete_pre_failure_windows"]),(1,3))

    def test_disabled_and_mixed_windows_do_not_become_fixed_expert_errors(self):
        frames=self.frames()
        frames[0]["prediction"]=0.
        single=self.windows(frames)["prediction_minus_actual_window_quality_m_s"]
        self.assertEqual(single["constant_proposal"]["count"],1)
        self.assertAlmostEqual(single["constant_proposal"]["mean_absolute"],0.)
        frames[15]["proposed"]=2
        mixed=self.windows(frames)["prediction_minus_actual_window_quality_m_s"]
        self.assertEqual((mixed["constant_proposal"]["count"],mixed["mixed_or_withdrawn"]["count"]),(0,1))
        frames[0]["proposal_applied"]=False
        disabled=self.windows(frames)
        self.assertEqual(disabled["counts"]["proposal_not_applied"],1)
        self.assertEqual(disabled["counts"]["complete_pre_failure_windows"],0)

    def test_population_and_failed_episode_quality_cannot_be_filtered(self):
        changes=[
            lambda p:p["finite_outcomes"]["trials"].pop(),
            lambda p:p["finite_outcomes"]["trials"].reverse(),
            lambda p:p["finite_outcomes"]["trials"][0]["episode_metrics"].__setitem__("quality_m_s",0.),
            lambda p:p["finite_outcomes"].__setitem__("negative",0),
            lambda p:p["finite_outcomes"]["repertoire"].__setitem__("ranked_role_indices",[2])]
        for change in changes:
            value=copy.deepcopy(self.parent);change(value)
            with self.assertRaises(ValueError):reader.check_population(value)

    def test_raw_corruption_stimulus_reaches_resolved_file(self):
        original=reader.sha;hits=[]
        target=(self.directory/"trace.jsonl").resolve(strict=True)
        def corrupted(path):
            if Path(path).resolve(strict=True)==target:
                hits.append(str(path));return "0"*64
            return original(path)
        with patch.object(reader,"sha",side_effect=corrupted):
            with self.assertRaisesRegex(ValueError,"original raw bytes"):
                reader.analyze_trial(self.directory,self.trial,self.contract["selection"],self.plan)
        self.assertTrue(hits)


if __name__=="__main__":
    unittest.main(verbosity=2)
