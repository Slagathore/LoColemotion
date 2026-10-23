"""Actual ABI fitting/retrieval/memory tests using explicitly synthetic episodes."""
import copy
import json
import os
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "sdk/discovery"), str(ROOT / "sdk/python"), str(ROOT / "sdk")]
import mujoco
import test_portable_search as fixtures
from portable_search_control import Controller, contract as portable_contract, sha
from adaptation_provider.retrieval import learner


class RetrievalControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = learner.contract()
        c = portable_contract()
        c["core_sha256"] = sha(Path(os.environ["QUADRUPED_TEST_CORE"]))
        with patch.object(fixtures, "contract", return_value=c):
            fixtures.PortableSearchControls.setUpClass()
        cls.fixture = fixtures.PortableSearchControls
        cls.core = cls.fixture.core
        cls.compiled = cls.fixture.compiled
        cls.host_contract = c
        cls.requests = []
        host = Controller(cls.core, cls.compiled, c, 0)
        try:
            with patch.object(mujoco, "MjModel", side_effect=AssertionError("Test world")), \
                    patch.object(mujoco, "MjData", side_effect=AssertionError("Test data")):
                for step in range(480):
                    obs = cls.fixture.observations(cls.fixture.native("gpu", 0), step)
                    cls.requests.append(host.step(*obs)["resolution_request"]["provider_request"])
        finally:
            host.close()
        cls.episodes = []
        for group in cls.plan["groups"]:
            if group["partition"] != "train":
                continue
            for index, action in enumerate(cls.plan["actions"]):
                windows = []
                # Known synthetic outcomes make action 1 best and action 2 next.
                speeds = [0., .19, .15, .05, .04, .03, .02, .01, .005]
                for step in range(0, 480, 30):
                    end = [speeds[index] * .25, 0.]
                    windows.append(dict(start_step=step, cue=learner.cue(cls.requests[step], cls.plan),
                        start_position_xz_m=[0., 0.], end_position_xz_m=end,
                        quality_m_s=learner.quality([0., 0.], end, .25, cls.plan)))
                negative = group["group_id"] == "train_3" and index == 8
                cls.episodes.append(dict(episode_id=group["group_id"] + "_" + action["action_id"], group_id=group["group_id"],
                    action_id=action["action_id"], outcome="negative" if negative else "positive",
                    failure_code="synthetic_fall" if negative else None, raw_episode_sha256="sha256:" + "1" * 64,
                    synthetic=True, metrics=dict(mean_height_m=.43, lateral_displacement_m=.01,
                        quality_m_s=windows[0]["quality_m_s"]), windows=[] if negative else windows))
        cls.fit_args = dict(frozen_corpus_id="synthetic_casebook_only", frozen_corpus_sha256="sha256:" + "2" * 64,
                            source_receipt_sha256="sha256:" + "3" * 64, synthetic=True)
        cls.model = learner.fit(cls.core, cls.episodes, **cls.fit_args)
        cls.proof = Path(os.environ["EXPLORER_TEST_OUTPUT"]) / ("retrieval-fixture-" + uuid.uuid4().hex)
        cls.proof.mkdir()
        for name, value in [("synthetic-episodes", cls.episodes), ("synthetic-model", cls.model.document()),
                            ("model-binding", dict(model_sha256=cls.model.sha256, corpus=cls.fit_args, world_build_count=0))]:
            with (cls.proof / (name + ".json")).open("x", encoding="utf-8", newline="\n") as stream:
                json.dump(value, stream, allow_nan=False, separators=(",", ":"))

    def request(self, step, mode, memory=None, previous=None):
        request = learner.bind_request(self.core, self.requests[step], self.model, mode)
        if memory is not None:
            request["provider_memory"] = copy.deepcopy(memory)
        if previous is not None:
            for row, value in zip(request["safety_envelope"]["ordered_actuator_limits"], previous, strict=True):
                row["previous_applied_correction_rad_s"] = value
        return request

    def resolve(self, request, mode, operation=None):
        call = learner.call_provider(self.core, request, self.model, mode, operation)
        self.assertIsNone(call["provider_error"], call)
        resolution = self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=call["provider_response"]))
        self.assertNotEqual(resolution["fallback_reason"], "invalid_provider_response")
        return call["provider_response"], resolution

    def test_fit_is_immutable_complete_and_preserves_negative_ledger(self):
        document = self.model.document()
        self.assertTrue(document["synthetic"])
        self.assertEqual(len(document["ordered_episode_ledger"]), 36)
        self.assertEqual(len(document["ordered_cases"]), 560)
        self.assertEqual(sum(row["outcome"] == "negative" for row in document["ordered_episode_ledger"]), 1)
        self.assertLess(len(document["ordered_elites"]), len(document["ordered_episode_ledger"]))
        query = learner.cue(self.requests[0], self.plan)
        predictions = self.model.predictions(query)
        self.assertAlmostEqual(predictions[1]["quality_m_s"], -.01)
        document["ordered_cases"][0]["quality_m_s"] = -999.
        self.assertEqual(learner.digest(self.core, self.model.document()), self.model.sha256)
        with self.assertRaises(Exception):
            self.model.sha256 = "changed"

    def test_split_incomplete_identity_and_window_corruptions_refuse_fitting(self):
        for change in [lambda e: e.pop(), lambda e: e.append(e[0]),
                       lambda e: e[0].__setitem__("group_id", "evaluation_0"),
                       lambda e: e[0].__setitem__("group_id", "calibration_0"),
                       lambda e: e[0]["windows"].pop(),
                       lambda e: e[0]["windows"][0].__setitem__("quality_m_s", -.999),
                       lambda e: e[0]["windows"][0]["cue"]["vector"].__setitem__(0, float("nan"))]:
            episodes = copy.deepcopy(self.episodes)
            change(episodes)
            with self.assertRaises(Exception):
                learner.fit(self.core, episodes, **self.fit_args)
        for change in [lambda d: d.__setitem__("physical_acceptance_authority", True),
                       lambda d: d["ordered_cases"][0].__setitem__("episode_id", "evaluation_0"),
                       lambda d: d["ordered_cases"][0].__setitem__("action_index", 1)]:
            document = self.model.document()
            change(document)
            with self.assertRaises(ValueError):
                learner.FrozenModel.load(self.core, document)

    def test_real_resolver_enforces_absolute_slew_and_disabled_baseline(self):
        request = self.request(0, "frozen")
        response, result = self.resolve(request, "frozen")
        self.assertIn("selected_action:action_1", response["diagnostics"])
        self.assertEqual(result["fallback_reason"], "none")
        for row in result["ordered_commands"]:
            self.assertLessEqual(abs(row["applied_correction_rad_s"]), .02)
            self.assertLessEqual(abs(row["final_canonical_target_velocity_rad_s"]), row["maximum_target_speed_rad_s"])
        disabled = self.request(0, "disabled")
        _, result = self.resolve(disabled, "disabled")
        self.assertTrue(result["deterministic_baseline_fallback_used"])
        for actual, baseline in zip(result["ordered_commands"], disabled["deterministic_baseline"]["ordered_commands"], strict=True):
            self.assertEqual(struct.pack("d", actual["final_canonical_target_velocity_rad_s"]),
                             struct.pack("d", baseline["combined_canonical_target_velocity_rad_s"]))

    def test_episodic_outcomes_change_selection_without_mutating_base(self):
        frozen_digest = self.model.sha256
        choices = {}
        retained = []
        for mode in ["frozen", "episodic", "episodic_shuffled"]:
            memory = None
            previous = None
            for step in range(61):
                request = self.request(step, mode, memory, previous)
                response, result = self.resolve(request, mode)
                memory = result["next_memory"]
                previous = [row["applied_correction_rad_s"] for row in result["ordered_commands"]]
                retained.append(dict(mode=mode, step=step, request=request, response=response, resolution=result))
                if step in [0, 30, 60]:
                    choices[mode, step] = next(s for s in response["diagnostics"] if s.startswith("selected_action:"))
            opaque = memory["opaque_state"]
            self.assertEqual(opaque["updates"], 0 if mode == "frozen" else 2)
            self.assertEqual(sum(opaque["counts"]), 0 if mode == "frozen" else 2)
        self.assertEqual(choices["frozen", 0], choices["frozen", 30])
        self.assertNotEqual(choices["episodic", 0], choices["episodic", 30])
        self.assertEqual(choices["episodic_shuffled", 0], choices["episodic_shuffled", 30])
        self.assertEqual(self.model.sha256, frozen_digest)
        self.assertEqual(learner.digest(self.core, self.model.document()), frozen_digest)
        with (self.proof / "synthetic-episode-decisions.jsonl").open("x", encoding="utf-8", newline="\n") as stream:
            for row in retained:
                stream.write(json.dumps(row, allow_nan=False, separators=(",", ":")) + "\n")

    def test_model_keeps_frozen_configuration_and_rejects_crossed_memory(self):
        with patch.object(learner, "contract", side_effect=AssertionError("Mutable source contract at runtime")):
            request = self.request(0, "episodic")
            response, result = self.resolve(request, "episodic")
        request = self.request(1, "episodic", result["next_memory"])
        request["provider_memory"]["opaque_state"]["mode"] = "frozen"
        request["provider_memory"]["opaque_state_sha256"] = learner.digest(self.core, request["provider_memory"]["opaque_state"])
        call = learner.call_provider(self.core, request, self.model, "episodic")
        self.assertIn("Crossed episode", call["provider_error"]["message"])

    def test_checkpoint_rollback_and_reset_keep_monotonic_core_memory(self):
        memory = None
        previous = None
        for step in range(32):
            operation = "checkpoint" if step == 0 else "rollback" if step == 31 else None
            request = self.request(step, "episodic", memory, previous)
            response, result = self.resolve(request, "episodic", operation)
            memory = result["next_memory"]
            previous = [row["applied_correction_rad_s"] for row in result["ordered_commands"]]
        self.assertEqual(memory["sequence"], 32)
        self.assertEqual(memory["opaque_state"]["counts"], [0] * 9)
        self.assertEqual(memory["opaque_state"]["last_step"], 31)
        self.assertEqual(memory["opaque_state"]["rollbacks"], 1)
        self.assertTrue(result["deterministic_baseline_fallback_used"])
        request = self.request(32, "episodic", memory, previous)
        response, result = self.resolve(request, "episodic", "reset")
        self.assertEqual(result["fallback_reason"], "provider_reset")
        self.assertEqual(result["next_memory"]["reset_epoch"], 1)
        self.assertEqual(result["next_memory"]["sequence"], 0)
        self.assertEqual(result["next_memory"]["opaque_state"], {})

    def test_shuffled_control_matches_request_magnitudes_and_unsupported_refuses(self):
        normal, _ = self.resolve(self.request(0, "frozen"), "frozen")
        shuffled, _ = self.resolve(self.request(0, "shuffled"), "shuffled")
        for left, right in zip(normal["ordered_corrections"], shuffled["ordered_corrections"], strict=True):
            self.assertEqual(left["canonical_velocity_delta_rad_s"], -right["canonical_velocity_delta_rad_s"])
        request = self.request(0, "frozen")
        request["state"]["base_pose_world"]["position_m"]["y"] = .1
        response, result = self.resolve(request, "frozen")
        self.assertEqual(response["status"], "unsupported")
        self.assertTrue(result["deterministic_baseline_fallback_used"])

    def test_stale_memory_and_identity_errors_are_retained_then_fall_back(self):
        request = self.request(0, "frozen")
        response, result = self.resolve(request, "frozen")
        request["provider_memory"] = result["next_memory"]
        call = learner.call_provider(self.core, request, self.model, "frozen")
        self.assertIn("noncontiguous", call["provider_error"]["message"])
        self.assertIsNone(call["provider_response"])
        fallback = self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=call["provider_response"]))
        self.assertEqual(fallback["fallback_reason"], "provider_absent")
        request = self.request(0, "frozen")
        request["expected_model_sha256"] = "sha256:" + "0" * 64
        self.assertIsNotNone(learner.call_provider(self.core, request, self.model)["provider_error"])


if __name__ == "__main__":
    unittest.main()
