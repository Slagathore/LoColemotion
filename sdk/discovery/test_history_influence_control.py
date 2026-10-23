"""Real ABI history and host replay controls; retained inputs, zero new worlds."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import test_contextual_influence_control as fixtures
import contextual_influence_control as original
import history_influence_control as host
from audit_gpu_contextual_influence import same_bits


class HistoryControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.HostControls.setUpClass()
        cls.f = fixtures.HostControls
        cls.core, cls.model = cls.f.f.core, cls.f.f.model
        cls.raw = []
        path = Path(__file__).resolve().parents[2].parent/'SporeSpore_Evidence'
        path = path/'sdk2-gpu-contextual-influence-20fe9aa17fee473bbc8b1e67585b9e8e/physical/contextual_context_development_0/controller.jsonl'
        with path.open() as stream:
            for line in stream:
                row = json.loads(line)
                if row["outer_step"] >= 66:
                    break
                if row["mode"] == "disabled":
                    cls.raw.append(row)
        if len(cls.raw) != 66:
            raise ValueError("Complete history rollover inputs required")

    def setUp(self):
        self.world = patch.object(mujoco, "MjModel", side_effect=AssertionError("world"))
        self.data = patch.object(mujoco, "MjData", side_effect=AssertionError("data"))
        self.world.start(); self.data.start()
        self.addCleanup(self.world.stop); self.addCleanup(self.data.stop)

    def controller(self, cls=host.HistoryInfluenceController):
        return cls(self.core, self.f.f.compiled, self.f.c, self.model, list(host.MODES))

    def observations(self, step):
        row = self.f.inputs[step]
        return [copy.deepcopy((row["request"]["state"], row["stability"], row["kinematics"])) for _ in host.MODES]

    def resolve_with_history(self, row, window):
        request = host.history.attach(row["resolution_request"]["provider_request"], window)
        response = copy.deepcopy(row["resolution_request"]["provider_response"])
        response["request_sha256"] = host.learner.digest(self.core, request)
        resolved = self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=response))
        return request, resolved

    def test_full_64_entry_rollover_is_causal_and_real_abi_commands_are_identical(self):
        window = host.history.empty()
        for row in self.raw:
            step = row["outer_step"]
            request, resolved = self.resolve_with_history(row, window)
            self.assertEqual([e["semantic_step"] for e in request["history"]["ordered_entries"]], list(range(max(0, step-64), step)))
            self.assertTrue(same_bits(resolved["ordered_commands"], row["resolution"]["ordered_commands"]))
            following, boundary = host.history.append_resolved(self.core, request, resolved)
            self.assertIsNone(boundary)
            entry = following["ordered_entries"][-1]
            self.assertEqual(entry["request_sha256"], host.learner.digest(self.core, request))
            self.assertEqual(entry["resolution_receipt_sha256"], host.learner.digest(self.core, resolved))
            self.assertTrue(same_bits(host.history.final_velocities(entry),
                [r["final_canonical_target_velocity_rad_s"] for r in resolved["ordered_commands"]]))
            self.assertTrue(same_bits(request["history"], window))
            window = following
        self.assertEqual([e["semantic_step"] for e in window["ordered_entries"]], list(range(2, 66)))
        with (self.f.f.root/"causal-history-rollover.json").open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(dict(history=window, requests_verified=66, world_build_count=0,
                physical_acceptance_authority=False, release_authority=False), stream, indent=2, allow_nan=False)
            stream.write("\n")

    def test_current_future_missing_and_tampered_entries_fail(self):
        request, resolved = self.resolve_with_history(self.raw[0], host.history.empty())
        window, _ = host.history.append_resolved(self.core, request, resolved)
        for step in [0, 2]:
            bad = copy.deepcopy(self.raw[1]["resolution_request"]["provider_request"])
            bad["state"]["semantic_step"] = step
            with self.assertRaisesRegex(ValueError, "contiguous past"):
                host.history.attach(bad, window)
        for key, value in [("request_id", "wrong"), ("request_sha256", "sha256:"+"0"*64)]:
            bad = dict(resolved, **{key: value})
            with self.assertRaisesRegex(ValueError, "binding"):
                host.history.append_resolved(self.core, request, bad)
        bad = copy.deepcopy(resolved)
        bad["ordered_commands"][0]["final_canonical_target_velocity_rad_s"] += .01
        with self.assertRaisesRegex(ValueError, "projection"):
            host.history.append_resolved(self.core, request, bad)
        bad = copy.deepcopy(window)
        bad["ordered_entries"][0]["state"]["semantic_step"] = 1
        with self.assertRaisesRegex(Exception, "history_payload_step_mismatch"):
            self.resolve_with_history(self.raw[1], bad)

    def test_absent_and_rejected_applied_status_break_the_window_without_relabeling(self):
        request = copy.deepcopy(self.raw[0]["resolution_request"]["provider_request"])
        response = copy.deepcopy(self.raw[0]["resolution_request"]["provider_response"])
        response.update(status="applied", confidence=.5,
            ordered_corrections=[dict(actuator_id=r["actuator_id"], canonical_velocity_delta_rad_s=0.)
                for r in request["deterministic_baseline"]["ordered_commands"]])
        invalid = dict(response, request_id="crossed_request")
        # Invalid responses lose parsed status in the core receipt. A valid
        # applied response refused by the confidence gate retains its status.
        for proposal, expected_status in [(None, None), (invalid, None), (response, "applied")]:
            resolved = self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
                provider_request=request, provider_response=proposal))
            self.assertFalse(resolved["adaptation_applied"])
            self.assertEqual(resolved["provider_status"], expected_status)
            window, boundary = host.history.append_resolved(self.core, request, resolved)
            self.assertEqual(window, host.history.empty())
            self.assertEqual(boundary, "v1_unrepresentable_provider_status")

    def test_history_host_preserves_commands_and_keeps_worlds_private(self):
        current, prior = self.controller(), self.controller(original.InfluenceController)
        before = self.model.document()
        retained = []
        saw_speed_projection = False
        try:
            for step in range(4):
                rows = current.step(self.observations(step))
                reference = prior.step(self.observations(step))
                for cell, (row, other) in enumerate(zip(rows, reference, strict=True)):
                    self.assertTrue(same_bits(row["native_targets"], other["native_targets"]))
                    self.assertTrue(same_bits(row["resolution"]["ordered_commands"], other["resolution"]["ordered_commands"]))
                    self.assertTrue(same_bits(row["resolution"]["next_memory"], other["resolution"]["next_memory"]))
                    history = row["resolution_request"]["provider_request"]["history"]["ordered_entries"]
                    self.assertEqual([e["semantic_step"] for e in history], [] if cell == 0 else list(range(step)))
                    if history:
                        self.assertEqual(history[-1]["request_sha256"], retained[-6+cell]["resolution"]["request_sha256"])
                        self.assertTrue(same_bits(host.history.final_velocities(history[-1]),
                            [r["final_canonical_target_velocity_rad_s"] for r in retained[-6+cell]["resolution"]["ordered_commands"]]))
                    saw_speed_projection |= any(r["final_speed_clamped"] for r in row["resolution"]["ordered_commands"])
                retained.extend(rows)
            self.assertTrue(saw_speed_projection)
            current.histories[1]["ordered_entries"].clear()
            self.assertEqual(len(current.histories[2]["ordered_entries"]), 4)
            self.assertEqual(len(retained[-5]["resolution_request"]["provider_request"]["history"]["ordered_entries"]), 3)
            self.assertEqual(self.model.document(), before)
            with (self.f.f.root/"history-host-replay.jsonl").open("x", encoding="utf-8", newline="\n") as stream:
                for row in retained:
                    stream.write(json.dumps(row, allow_nan=False)+"\n")
        finally:
            current.close(); prior.close()

    def test_provider_error_and_partial_mapping_failure_preserve_boundaries(self):
        controller = self.controller()
        respond = host.learner.respond
        def fail_one(core, request, model, mode, operation):
            if mode == "frozen":
                raise RuntimeError("declared history provider failure")
            return respond(core, request, model, mode, operation)
        try:
            controller.step(self.observations(0))
            old = copy.deepcopy(controller.memories[2])
            with patch.object(host.learner, "respond", side_effect=fail_one):
                rows = controller.step(self.observations(1))
            self.assertTrue(same_bits(rows[2]["native_targets"], rows[2]["baseline_native_targets"]))
            self.assertEqual(controller.memories[2], old)
            self.assertEqual(controller.histories[2], host.history.empty())
            self.assertEqual(len(controller.histories[1]["ordered_entries"]), 2)
            retained = copy.deepcopy(controller.histories)
            with patch.object(host, "map_resolution", side_effect=ValueError("injected history mapping failure")):
                with self.assertRaisesRegex(ValueError, "injected"):
                    controller.step(self.observations(2))
            self.assertTrue(controller.closed)
            self.assertEqual(controller.histories, retained)
            with self.assertRaisesRegex(ValueError, "lifecycle"):
                controller.step(self.observations(3))
        finally:
            controller.close()


if __name__ == "__main__":
    unittest.main()
