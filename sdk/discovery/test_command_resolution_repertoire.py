"""Dense-window source joins, finite denominators and unchanged support controls."""
import copy
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import command_resolution_repertoire as reader
from adaptation_provider.retrieval import feedback_flat_v1 as sparse


class CommandResolutionControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_path=Path(os.environ["QUADRUPED_TEST_CORE"])
        cls.baseline_path=Path(os.environ["PORTABLE_BATCH_BASELINE_CORE"])
        cls.core=reader.bridge.LocomotionCore(cls.baseline_path)
        cls.parent=reader.read(reader.PARENT)["result"]
        cls.original=next(e for e in cls.parent["corpus"]["episodes"] if e["outcome"]=="positive")
        source=next(s for s in cls.parent["corpus"]["source_ledger"] if s["episode_id"]==cls.original["episode_id"])
        path=reader.ROOT.parent/"SporeSpore_Evidence"/cls.parent["parent_attempt_id"] /"physical"/source["trial_id"]/"controller.jsonl"
        cls.rows=list(reader.read_jsonl(path));cls.plan=reader.learner.contract()

    def setUp(self):
        for name in ["MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"]:
            guard=patch.object(mujoco,name,side_effect=AssertionError("No worlds in dense fitting"))
            guard.start();self.addCleanup(guard.stop)

    def test_declaration_preserves_outcome_horizon_domain_and_finite_denominators(self):
        declaration=reader.declaration()
        self.assertEqual((declaration["source_trials"],declaration["fitted_immediate_episodes"],declaration["eligible_episodes"],declaration["negative_episodes"]),(32,24,15,9))
        self.assertEqual(declaration["expected_case_count"],15*(1440-30+1))
        self.assertFalse(declaration["overlapping_examples_are_independent_trials"])
        self.assertFalse(declaration["context_estimator_refitted"])
        old=sparse.contract();new=reader.learner.contract()
        for key in ["actions","feature_scales","phase_bin_steps","decision_window_steps","nearest_neighbors","maximum_support_distance","minimum_predicted_gain_m_s","minimum_height_m","maximum_tilt_rad","groups","archive","fitting","authority"]:
            self.assertEqual(old[key],new[key])

    def test_every_complete_window_rejoins_and_original_sparse_windows_stay_exact(self):
        episode=reader.expand_episode(self.original,self.rows,self.plan)
        self.assertEqual([w["start_step"] for w in episode["windows"]],list(range(1411)))
        self.assertEqual(episode["metrics"],self.original["metrics"])
        self.assertEqual(episode["raw_episode_sha256"],self.original["raw_episode_sha256"])
        for old in self.original["windows"]:self.assertEqual(episode["windows"][old["start_step"]],old)
        window=episode["windows"][1]
        a=self.rows[1]["request"]["state"]["base_pose_world"]["position_m"]
        b=self.rows[31]["request"]["state"]["base_pose_world"]["position_m"]
        expected=-abs((b["x"]-a["x"])/.25-.2)-.25*abs((b["z"]-a["z"])/.25)
        self.assertEqual(window["quality_m_s"],expected)
        self.assertEqual(episode["windows"][-1]["end_position_xz_m"],self.original["windows"][-1]["end_position_xz_m"])

    def test_negative_episodes_remain_censored_and_cannot_supply_windows(self):
        original=next(e for e in self.parent["corpus"]["episodes"] if e["outcome"]=="negative")
        episode=reader.expand_episode(original,None,self.plan)
        self.assertEqual(episode["outcome"],"negative");self.assertEqual(episode["failure_code"],original["failure_code"])
        self.assertEqual(episode["windows"],[]);self.assertIsNone(episode["metrics"]["quality_m_s"])
        with self.assertRaisesRegex(ValueError,"must not supply"):reader.expand_episode(original,self.rows,self.plan)
        bad=copy.deepcopy(original);bad["metrics"]["quality_m_s"]=0.
        with self.assertRaisesRegex(ValueError,"Failed source"):reader.expand_episode(bad,None,self.plan)

    def test_chronology_canonical_context_and_original_quality_corruption_refuse(self):
        for change in [lambda r:r.pop(),lambda r:r[1].__setitem__("outer_step",2),
            lambda r:r[1]["request"]["state"].__setitem__("semantic_step",9),
            lambda r:r[1]["resolution_request"]["provider_request"]["controller_context"]["controller_memory"].__setitem__("last_semantic_step",9)]:
            rows=copy.deepcopy(self.rows);change(rows)
            with self.assertRaises(ValueError):reader.expand_episode(self.original,rows,self.plan)
        original=copy.deepcopy(self.original);original["windows"][0]["quality_m_s"] += .1
        with self.assertRaisesRegex(ValueError,"original sparse window"):reader.expand_episode(original,self.rows,self.plan)

    def test_sparse_and_dense_fitters_cannot_silently_accept_each_others_sampling(self):
        episodes=copy.deepcopy(self.parent["corpus"]["episodes"])
        kwargs=dict(frozen_corpus_id="synthetic_sampling_refusal",frozen_corpus_sha256="sha256:"+"0"*64,source_receipt_sha256="sha256:"+"1"*64,synthetic=False)
        with self.assertRaisesRegex(ValueError,"Missing/reordered training window"):reader.learner.fit(self.core,episodes,**kwargs)
        index=next(i for i,e in enumerate(episodes) if e["outcome"]=="positive")
        episodes[index]=reader.expand_episode(episodes[index],self.rows,self.plan)
        with self.assertRaisesRegex(ValueError,"Window step"):sparse.fit(self.core,episodes,**kwargs)
        self.assertEqual(sparse.CONTRACT.name,"feedback_contract_v1.json")
        self.assertEqual(reader.learner.CONTRACT.name,"feedback_dense_contract_v1.json")

    def test_changed_declaration_parent_and_stride_refuse(self):
        value=copy.deepcopy(reader.declaration());value["state_support_distance_preserved"]=2.
        with patch.object(reader,"read",return_value=value):
            with self.assertRaisesRegex(ValueError,"declaration/parent"):reader.declaration()
        with patch.object(reader,"PARENT_SHA","0"*64):
            with self.assertRaisesRegex(ValueError,"declaration/parent"):reader.declaration()
        value=copy.deepcopy(self.plan);value["training_window_stride_steps"]=2
        with patch.object(reader.learner._runtime,"contract",return_value=value):
            with self.assertRaisesRegex(ValueError,"stride/horizon"):reader.learner.contract()

    def test_full_parent_verification_and_dense_fit_keep_all_failures_without_worlds(self):
        result=reader.run(reader.ROOT.parent/"SporeSpore_Evidence",self.core_path,self.baseline_path)
        self.assertTrue(result["ok"]);self.assertEqual(result["worlds_opened"],0)
        self.assertEqual(result["case_count"],21165)
        self.assertEqual(len(result["source_ledger"]),32);self.assertEqual(len(result["source_bindings"]),24)
        ledger=result["model"]["ordered_episode_ledger"]
        self.assertEqual(sum(e["outcome"]=="negative" for e in ledger),9)
        by_id={e["episode_id"]:e for e in ledger}
        self.assertTrue(all(by_id[c["episode_id"]]["outcome"]=="positive" for c in result["model"]["ordered_cases"]))
        self.assertEqual(result["groups"],self.parent["groups"])
        self.assertEqual(result["evaluation"],self.parent["evaluation"])
        self.assertEqual(result["complete_condition_defaults"],self.parent["complete_condition_defaults"])
        self.assertEqual(len(result["first_response_support"]),8)
        self.assertFalse(result["context_estimator_refitted"])
        self.assertFalse(result["overlapping_cases_are_independent_trials"])
        root=Path(os.environ["EXPLORER_TEST_OUTPUT"])
        with (root/"tested-command-resolution-analysis.json").open("x",encoding="utf-8",newline="\n") as stream:
            json.dump(result,stream,indent=2,allow_nan=False);stream.write("\n")


if __name__ == "__main__":unittest.main()
