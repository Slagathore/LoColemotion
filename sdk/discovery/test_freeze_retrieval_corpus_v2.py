"""Pure corpus/model record integration and rejection controls, zero worlds."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import mujoco
from freeze_retrieval_corpus_v2 import assemble,freeze,ROOT
from adaptation_provider.retrieval import flat_v2 as learner
import test_flat_retrieval as retrieval_fixtures


class CorpusControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        retrieval_fixtures.RetrievalControls.setUpClass()
        cls.core=retrieval_fixtures.RetrievalControls.core
        cls.episodes=copy.deepcopy(retrieval_fixtures.RetrievalControls.episodes)
        cls.raw=[]
        for i,episode in enumerate(cls.episodes):
            group=next(g for g in learner.contract()["groups"] if g["group_id"]==episode["group_id"])
            raw=dict(group_id=group["group_id"],cell=i%9,seed=group["seed"],hashes={k:"1"*64 for k in ["controller","trace","timing"]},
                provider_request_sha256="sha256:"+"2"*64,provider_response_sha256="sha256:"+"3"*64,resolution_receipt_sha256="sha256:"+"4"*64,
                descriptor_sha256=learner.contract()["descriptor_sha256"],expected_outer_rows=480,expected_internal_rows=2400)
            cls.raw.append(raw)
            episode["raw_episode_sha256"]=learner.digest(cls.core,raw)

    def build(self,episodes=None,raw=None):
        return assemble(self.core,self.episodes if episodes is None else episodes,self.raw if raw is None else raw,
            source_receipt_sha256="sha256:"+"5"*64,synthetic=True)

    def test_candidate_chapter_frozen_corpus_and_model_join(self):
        with patch.object(mujoco,"MjModel",side_effect=AssertionError("world")),patch.object(mujoco,"MjData",side_effect=AssertionError("data")):
            result=self.build()
        chapter=result["candidate_chapter"]
        self.assertEqual((chapter["success_count"],chapter["counterexample_count"]),(35,1))
        self.assertFalse(chapter["encyclopedia_promotion_authority"])
        self.assertEqual(result["model_candidate"]["model_artifact_sha256"],learner.digest(self.core,result["fitted_model"]))
        self.assertEqual(result["fitted_model"]["frozen_corpus_sha256"],learner.digest(self.core,result["frozen_corpus"]))
        self.assertTrue(result["fitted_model"]["synthetic"])

    def test_split_raw_binding_and_candidate_identity_corruptions_refuse(self):
        for change in [lambda r:r.pop(),lambda r:r[0].__setitem__("group_id","evaluation_0"),
                       lambda r:r[0].__setitem__("cell",8),lambda r:r[0].__setitem__("seed",7),
                       lambda r:r[0]["hashes"].__setitem__("trace","0"*64)]:
            raw=copy.deepcopy(self.raw);change(raw)
            with self.assertRaises(ValueError):self.build(raw=raw)
        episodes=copy.deepcopy(self.episodes);episodes[0]["group_id"]="calibration_0"
        with self.assertRaises(ValueError):self.build(episodes=episodes)

    def test_native_freeze_refuses_outside_campaign_root(self):
        with self.assertRaises(ValueError):freeze(ROOT,retrieval_fixtures.RetrievalControls.fixture.core_path)


if __name__=="__main__":unittest.main()
