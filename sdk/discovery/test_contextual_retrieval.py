"""Synthetic context, lifecycle and actual ABI controls; no physical outcomes."""
import copy
import json
import struct
import unittest
from unittest.mock import patch

import test_flat_retrieval as fixtures
from adaptation_provider.retrieval import contextual_v1 as provider


class ContextualControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.RetrievalControls.setUpClass()
        cls.f = fixtures.RetrievalControls
        cls.core, cls.model, cls.plan = cls.f.core, cls.f.model, cls.f.plan
        cls.config = provider.contract()

    def setUp(self):
        self.world = patch.object(fixtures.mujoco, "MjModel", side_effect=AssertionError("No test world"))
        self.data = patch.object(fixtures.mujoco, "MjData", side_effect=AssertionError("No test data"))
        self.world.start(); self.data.start()
        self.addCleanup(self.world.stop); self.addCleanup(self.data.stop)

    def request(self, step, mode="episodic", memory=None, previous=None):
        request = provider.bind_request(self.core, self.f.requests[step], self.model, mode)
        if memory is not None:
            request["provider_memory"] = copy.deepcopy(memory)
        if previous is not None:
            for limit, value in zip(request["safety_envelope"]["ordered_actuator_limits"], previous, strict=True):
                limit["previous_applied_correction_rad_s"] = value
        return request

    def resolve(self, request, mode="episodic", operation=None):
        call = provider.call_provider(self.core, request, self.model, mode, operation)
        self.assertIsNone(call["provider_error"], call)
        result = self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=call["provider_response"]))
        self.assertNotEqual(result["fallback_reason"], "invalid_provider_response")
        return call["provider_response"], result

    def advance(self, count, mode="episodic", operations=None):
        memory, previous, rows = None, None, []
        for step in range(count):
            request = self.request(step, mode, memory, previous)
            response, result = self.resolve(request, mode, (operations or {}).get(step))
            memory = result["next_memory"]
            previous = [row["applied_correction_rad_s"] for row in result["ordered_commands"]]
            rows.append(dict(step=step, request=request, response=response, result=result))
        return rows

    def rehash(self, memory):
        memory["opaque_state_sha256"] = provider.digest(self.core, memory["opaque_state"])

    def test_feedback_changes_only_a_revisited_context_and_preserves_base(self):
        before = self.model.document()
        ordinary = self.advance(361)
        shuffled = self.advance(361, "episodic_shuffled")
        for rows in [ordinary, shuffled]:
            self.assertEqual(rows[29]["result"]["next_memory"]["opaque_state"]["updates"], 0)
            self.assertEqual(rows[30]["result"]["next_memory"]["opaque_state"]["updates"], 1)
            for step in [0, 30, 330]:
                self.assertEqual(rows[step]["response"]["next_memory"]["opaque_state"]["active"]["action"], 1)
                self.assertFalse(any(d.startswith("context_feedback:") for d in rows[step]["response"]["diagnostics"]))
        state = ordinary[-1]["result"]["next_memory"]["opaque_state"]
        self.assertEqual(state["active"]["action"], 2)
        self.assertEqual(state["updates"], 12)
        self.assertEqual(state["records"][0]["residual_m_s"], -.15)
        self.assertEqual(state["records"][0]["cue"], provider.base.cue(self.f.requests[0], self.plan))
        self.assertNotEqual(state["records"][0]["cue"], provider.base.cue(self.f.requests[30], self.plan))
        control = shuffled[-1]["result"]["next_memory"]["opaque_state"]
        self.assertEqual(control["active"]["action"], 1)
        self.assertEqual(control["records"][0]["applied_action"], 1)
        self.assertEqual(control["records"][0]["credited_action"], 8)
        self.assertEqual(before, self.model.document())
        for name, rows in [("ordinary", ordinary), ("shuffled", shuffled)]:
            with (self.f.proof/("contextual-synthetic-"+name+".jsonl")).open("x", encoding="utf-8", newline="\n") as stream:
                for row in rows:
                    stream.write(json.dumps(row, allow_nan=False, separators=(",", ":"))+"\n")

    def test_exact_categories_distance_and_nearest_weighted_negative_records(self):
        query = provider.base.cue(self.f.requests[0], self.plan)
        records = []
        for index, (distance, residual) in enumerate([(0., -.12), (.1, .06), (.2, -.03), (.3, .15)]):
            cue = copy.deepcopy(query)
            cue["vector"][0] += distance*self.plan["feature_scales"][0]
            records.append(dict(credited_action=1, cue=cue, start_step=index*30, residual_m_s=residual))
        offsets = provider.contextual_offsets(query, records, self.plan, self.config)
        selected = offsets[1]
        self.assertEqual(selected["record_start_steps"], [0, 30, 60])
        distances = [provider.context_distance(query, row["cue"], self.plan) for row in records[:3]]
        weights = [1/(d*d+1e-6) for d in distances]
        self.assertEqual(selected["offset_m_s"], sum(w*r["residual_m_s"] for w,r in zip(weights,records))/sum(weights))
        self.assertLess(selected["offset_m_s"], 0.)
        for mutate in [lambda q: q["phase"].__setitem__(0, 1), lambda q: q.__setitem__("contact_mask", 7),
                       lambda q: q["vector"].__setitem__(3, 10.)]:
            other = copy.deepcopy(query); mutate(other)
            self.assertEqual(provider.contextual_offsets(other, records, self.plan, self.config), {})
        boundary = copy.deepcopy(query)
        # The yaw scale is exactly representable; .3/.2 rounds above 1.5.
        boundary["vector"][5] += 1.5*self.plan["feature_scales"][5]
        self.assertIsNotNone(provider.context_distance(query, boundary, self.plan))
        boundary["vector"][5] += 1e-9
        self.assertIsNone(provider.context_distance(query, boundary, self.plan))

    def test_memory_off_variants_preserve_frozen_decisions_and_real_clamps(self):
        for mode in ["frozen", "disabled", "shuffled"]:
            old_memory, memory, previous = None, None, None
            for step in range(61):
                old = provider.base.bind_request(self.core, self.f.requests[step], self.model, mode)
                if old_memory is not None:
                    old["provider_memory"] = old_memory
                original = provider.base.respond(self.core, old, self.model, mode)
                old_memory = original["next_memory"]
                request = self.request(step, mode, memory, previous)
                response, result = self.resolve(request, mode)
                memory = result["next_memory"]
                for key in ["status", "support_distance", "ordered_corrections", "diagnostics"]:
                    self.assertEqual(response[key], original[key])
                self.assertEqual(memory["opaque_state"]["records"], [])
                for row, limit in zip(result["ordered_commands"], request["safety_envelope"]["ordered_actuator_limits"], strict=True):
                    self.assertLessEqual(abs(row["applied_correction_rad_s"]), .25)
                    if mode != "disabled":
                        self.assertLessEqual(abs(row["applied_correction_rad_s"]-limit["previous_applied_correction_rad_s"]), .020000000000001)
                    self.assertLessEqual(abs(row["final_canonical_target_velocity_rad_s"]), row["maximum_target_speed_rad_s"])
                if mode == "disabled":
                    for actual, baseline in zip(result["ordered_commands"], request["deterministic_baseline"]["ordered_commands"], strict=True):
                        self.assertEqual(struct.pack("d", actual["final_canonical_target_velocity_rad_s"]),
                            struct.pack("d", baseline["combined_canonical_target_velocity_rad_s"]))
                previous = [row["applied_correction_rad_s"] for row in result["ordered_commands"]]

    def test_checkpoint_rollback_reset_and_window_censoring(self):
        rows = self.advance(63, operations={31: "checkpoint", 61: "rollback", 62: "reset"})
        state = rows[60]["result"]["next_memory"]["opaque_state"]
        self.assertEqual(state["updates"], 2)
        restored = rows[61]["result"]["next_memory"]
        self.assertEqual(restored["sequence"], 62)
        self.assertEqual(restored["opaque_state"]["updates"], 1)
        self.assertEqual(restored["opaque_state"]["last_step"], 61)
        self.assertEqual(restored["opaque_state"]["rollbacks"], 1)
        self.assertIsNone(restored["opaque_state"]["active"])
        self.assertTrue(rows[61]["result"]["deterministic_baseline_fallback_used"])
        reset = rows[62]["result"]["next_memory"]
        self.assertEqual((reset["reset_epoch"], reset["sequence"], reset["opaque_state"]), (1, 0, {}))
        _, resumed = self.resolve(self.request(63, memory=reset))
        self.assertEqual(resumed["next_memory"]["opaque_state"]["active"]["start_step"], 63)
        request = self.request(30, memory=rows[29]["result"]["next_memory"])
        request["state"]["base_pose_world"]["position_m"]["y"] = .1
        response, fallback = self.resolve(request)
        self.assertEqual(response["status"], "unsupported")
        self.assertEqual(fallback["next_memory"]["opaque_state"]["updates"], 0)
        self.assertIsNone(fallback["next_memory"]["opaque_state"]["active"])

    def test_malformed_future_crossed_and_stale_memory_refuse_without_erasure(self):
        valid = self.advance(31)[-1]["result"]["next_memory"]
        changes = [lambda o: o.__setitem__("component_sha256", "sha256:"+"0"*64),
            lambda o: o.__setitem__("mode", "frozen"), lambda o: o.__setitem__("seed", o["seed"]+1),
            lambda o: o.__setitem__("last_step", 29), lambda o: o.__setitem__("updates", 2),
            lambda o: o["records"][0].__setitem__("observed_at_step", 60),
            lambda o: o["records"][0].__setitem__("residual_m_s", 0.),
            lambda o: o["records"][0].__setitem__("credited_action", 8),
            lambda o: o["active"].__setitem__("start_step", 0),
            lambda o: o.__setitem__("checkpoint", dict(records=[], updates=1, evictions=0))]
        for change in changes:
            request = self.request(31, memory=valid)
            change(request["provider_memory"]["opaque_state"]); self.rehash(request["provider_memory"])
            call = provider.call_provider(self.core, request, self.model, "episodic")
            self.assertIsNotNone(call["provider_error"], change)
            result = self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
                provider_request=request, provider_response=call["provider_response"]))
            self.assertEqual(result["fallback_reason"], "provider_absent")
            self.assertEqual(result["next_memory"], request["provider_memory"])
        request = self.request(31, memory=valid)
        request["expected_provider_version"] += "_crossed"
        self.assertIsNotNone(provider.call_provider(self.core, request, self.model, "episodic")["provider_error"])
        request = self.request(31, memory=valid)
        request["provider_memory"]["opaque_state_sha256"] = "sha256:"+"0"*64
        self.assertIsNotNone(provider.call_provider(self.core, request, self.model, "episodic")["provider_error"])
        request = self.request(31, memory=valid)
        response = provider.respond(self.core, request, self.model, "episodic")
        response["provenance"]["model_sha256"] = "sha256:"+"0"*64
        result = self.core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=request, provider_response=response))
        self.assertEqual(result["fallback_reason"], "invalid_provider_response")
        self.assertEqual(result["next_memory"], valid)

    def test_full_capacity_evicts_oldest_and_checkpoint_fits_core_limit(self):
        initial = self.advance(31)[-1]["result"]["next_memory"]
        memory = copy.deepcopy(initial)
        opaque = memory["opaque_state"]
        record = opaque["records"][0]
        opaque["records"] = [dict(copy.deepcopy(record), start_step=i*30, observed_at_step=(i+1)*30) for i in range(64)]
        opaque.update(updates=64, evictions=0, last_step=1949)
        opaque["active"]["start_step"] = 1920
        opaque["checkpoint"] = provider.statistics(opaque)
        memory["sequence"] = 1950
        self.rehash(memory)
        request = self.request(0, memory=memory)
        # Explicit synthetic long clock; no claim of a 1,950-step physical run.
        request["state"].update(semantic_step=1950, sample_time_s=1950*self.plan["controller_dt_s"])
        request["deterministic_baseline"]["semantic_step"] = 1950
        for command in request["deterministic_baseline"]["ordered_commands"]:
            command["valid_through_step"] = 1950
        request["command"].update(valid_from_step=1950, valid_through_step=1950)
        _, result = self.resolve(request)
        after = result["next_memory"]["opaque_state"]
        self.assertEqual((after["updates"], after["evictions"], len(after["records"])), (65, 1, 64))
        self.assertEqual(after["records"][0]["start_step"], 30)
        self.assertEqual(after["checkpoint"]["records"][0]["start_step"], 0)
        self.assertEqual(after["checkpoint"]["updates"], 64)
        # Long finite decimal representations exercise the double-buffer bound.
        worst = copy.deepcopy(after)
        for rows in [worst["records"], worst["checkpoint"]["records"]]:
            for row in rows:
                row["cue"]["vector"] = [(-1.)**i*1.2345678901234567e123 for i in range(6)]
                row.update(observed_quality_m_s=-1.2345678901234567e123,
                    predicted_quality_m_s=-1.2345678901234567e122, residual_m_s=-.15)
        size = len(self.core.canonicalize_json(worst)["canonical_json"].encode())
        self.assertLessEqual(size, self.config["maximum_opaque_state_bytes"])
        with (self.f.proof/"contextual-capacity.json").open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(dict(synthetic=True, world_build_count=0, records=64, checkpoint_records=64,
                opaque_state_bytes=size, limit=65536), stream)


if __name__ == "__main__":
    unittest.main()
