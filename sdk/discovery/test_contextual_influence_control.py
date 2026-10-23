"""Real host transactions on exposed retained inputs; no synthetic physics claim."""
import copy
import json
import unittest
from unittest.mock import patch

import test_gpu_retrieval_shadow as fixtures
import contextual_influence_control as host
from gpu_contextual_influence import declaration
from portable_search_control import Controller
from audit_gpu_contextual_influence import verify_influence, verify_episode_transition, same_bits


class HostControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.ShadowControls.setUpClass()
        cls.f = fixtures.ShadowControls
        cls.c = declaration()
        cls.inputs = []
        source = host.candidate_path(cls.c).parent.parent / "physical/train_0/controller.jsonl"
        with source.open(encoding="utf-8") as stream:
            for line in stream:
                row = json.loads(line)
                if row["cell"] == 0:
                    cls.inputs.append(row)
                    if len(cls.inputs) == 62:
                        break
        if len(cls.inputs) != 62:
            raise ValueError("Missing retained training inputs")

    def observations(self, step):
        row = self.inputs[step]
        return copy.deepcopy((row["request"]["state"], row["stability"], row["kinematics"]))

    def test_applied_history_private_feedback_and_independent_scalar_replay(self):
        modes = list(host.MODES)
        controller = host.InfluenceController(self.f.core, self.f.compiled, self.c, self.f.model, modes)
        baseline = Controller(self.f.oracle, self.f.compiled, self.c, 0)
        memories = [host.learner.empty_memory(self.f.oracle) for _ in modes]
        previous = [[0.]*8 for _ in modes]
        stats = [dict(rows=0, provider_errors=0, unexpected_fallbacks=0, resolved_nonzero_rows=0,
            statuses={}, new_action_selections=0, same_input_choices_changed_by_memory=0) for _ in modes]
        before = self.f.model.document()
        retained = []
        saw_carried = False
        try:
            for step in range(62):
                observation = self.observations(step)
                expected = baseline.step(*observation)
                rows = controller.step([copy.deepcopy(observation) for _ in modes])
                for cell, row in enumerate(rows):
                    self.assertTrue(all(same_bits(value, row["baseline_"+key] if key in ["resolution_request","resolution","native_targets"] else row[key])
                        for key,value in expected.items()))
                    memories[cell] = verify_influence(row,self.f.model,self.f.oracle,memories[cell],previous[cell],stats[cell])
                    if modes[cell] != "baseline":
                        limits = row["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"]
                        self.assertEqual([r["previous_applied_correction_rad_s"] for r in limits],previous[cell])
                        saw_carried |= any(v != 0. for v in previous[cell])
                    previous[cell] = [r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
                self.assertEqual(rows[0]["native_targets"],rows[1]["native_targets"])
                retained.extend(rows)
            self.assertTrue(saw_carried)
            self.assertTrue(all(s["provider_errors"] == s["unexpected_fallbacks"] == 0 for s in stats))
            self.assertGreater(controller.memories[modes.index("episodic")]["opaque_state"]["updates"],0)
            self.assertEqual(controller.memories[modes.index("frozen")]["opaque_state"]["updates"],0)
            self.assertEqual(before,self.f.model.document())
            # The independent reader must reject changed feedback even when
            # called without the separate provider replay check.
            feedback = next(r for r in retained if r["mode"] == "episodic"
                and r["resolution"]["next_memory"]["opaque_state"].get("records"))
            damaged = copy.deepcopy(feedback["resolution"])
            damaged["next_memory"]["opaque_state"]["records"][-1]["residual_m_s"] += .01
            with self.assertRaisesRegex(ValueError, "feedback join"):
                verify_episode_transition(feedback["resolution_request"]["provider_request"], damaged,
                    feedback["resolution_request"]["provider_response"], self.f.model, "episodic", {})
            selected = next(r for r in retained if r["mode"] == "episodic"
                and r["resolution"]["next_memory"]["opaque_state"].get("active", {}).get("start_step")
                    == r["resolution_request"]["provider_request"]["state"]["semantic_step"])
            damaged = copy.deepcopy(selected["resolution"])
            damaged["next_memory"]["opaque_state"]["active"]["start_cue"]["contact_mask"] ^= 1
            with self.assertRaisesRegex(ValueError, "Action-time context"):
                verify_episode_transition(selected["resolution_request"]["provider_request"], damaged,
                    selected["resolution_request"]["provider_response"], self.f.model, "episodic", {})
            with (self.f.root/"influence-host-retained-input-replay.jsonl").open("x",encoding="utf-8",newline="\n") as stream:
                for row in retained:
                    stream.write(json.dumps(row,allow_nan=False)+"\n")
        finally:
            controller.close()
            baseline.close()

    def test_provider_error_returns_exact_baseline_and_preserves_old_memory(self):
        modes = list(host.MODES)
        controller = host.InfluenceController(self.f.core,self.f.compiled,self.c,self.f.model,modes)
        original = host.learner.respond
        def fail_one(core,request,model,mode,operation):
            if mode == "frozen":
                raise RuntimeError("declared provider failure")
            return original(core,request,model,mode,operation)
        try:
            index = modes.index("frozen")
            for step in range(61):
                controller.step([self.observations(step) for _ in modes])
                if any(v != 0. for v in controller.previous[index]):
                    break
            self.assertTrue(any(v != 0. for v in controller.previous[index]))
            old_memory = copy.deepcopy(controller.memories[index])
            with patch.object(host.learner,"respond",side_effect=fail_one):
                rows = controller.step([self.observations(step+1) for _ in modes])
            row = rows[modes.index("frozen")]
            self.assertEqual(row["provider_error"]["type"],"RuntimeError")
            self.assertEqual(row["resolution"]["fallback_reason"],"provider_absent")
            self.assertTrue(same_bits(row["native_targets"],row["baseline_native_targets"]))
            self.assertEqual(controller.memories[index],old_memory)
            self.assertEqual(controller.previous[modes.index("frozen")],[0.]*8)
            self.assertTrue(all(r["provider_error"] is None for r in rows if r["mode"] != "frozen"))
        finally:
            controller.close()

    def test_partial_host_mapping_failure_closes_and_cannot_resume(self):
        controller = host.InfluenceController(self.f.core,self.f.compiled,self.c,self.f.model,list(host.MODES))
        initial = copy.deepcopy(controller.memories)
        with patch.object(host,"map_resolution",side_effect=ValueError("injected mapping failure")):
            with self.assertRaisesRegex(ValueError,"injected mapping failure"):
                controller.step([self.observations(0) for _ in host.MODES])
        self.assertTrue(controller.closed)
        self.assertEqual(controller.memories,initial)
        with self.assertRaisesRegex(ValueError,"lifecycle"):
            controller.step([self.observations(1) for _ in host.MODES])
        controller.close()


if __name__ == "__main__":
    unittest.main()
