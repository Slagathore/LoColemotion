"""Actual fitted-model host transactions using retained input, without physics."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import mujoco
import test_gpu_retrieval_shadow as fixtures
import retrieval_shadow_control as host
from audit_gpu_batch_execution import same_bits
from portable_search_control import Controller


class HostControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.ShadowControls.setUpClass()
        cls.f = fixtures.ShadowControls
        c = cls.f.c
        source = host.candidate_path(c).parent.parent / "physical/train_0/controller.jsonl"
        # These are exposed training inputs for a zero-world integration test.
        # They are not fresh calibration or evaluation observations.
        cls.inputs = []
        with source.open(encoding="utf-8") as stream:
            for line in stream:
                row = json.loads(line)
                if row["cell"] == 0:
                    cls.inputs.append(row)
                    if len(cls.inputs) == 62:
                        break
        if len(cls.inputs) != 62:
            raise ValueError("Missing retained component inputs")

    def observations(self, step):
        row = self.inputs[step]
        return copy.deepcopy((row["request"]["state"], row["stability"], row["kinematics"]))

    def test_carried_memory_checkpoint_rollback_reset_and_immutable_base(self):
        c = copy.deepcopy(self.f.c)
        # Abbreviated operation schedule only for this synthetic host test.
        c["shadow_operations"] = [dict(outer_step=0,operation="checkpoint"),
            dict(outer_step=31,operation="rollback"),dict(outer_step=32,operation="reset")]
        baseline = Controller(self.f.oracle, self.f.compiled, c, 0)
        controller = host.ShadowController(self.f.core, self.f.compiled, c, self.f.model)
        before = self.f.model.document()
        retained = []
        try:
            with patch.object(mujoco,"MjModel",side_effect=AssertionError("world")),patch.object(mujoco,"MjData",side_effect=AssertionError("data")):
                for step in range(62):
                    observations = self.observations(step)
                    expected = baseline.step(*observations)
                    actual = controller.step([observations])[0]
                    self.assertTrue(all(same_bits(value, actual[key]) for key,value in expected.items()))
                    self.assertTrue(all(item["provider_error"] is None for item in actual["shadow"]))
                    self.assertTrue(all(limit["previous_applied_correction_rad_s"] == 0.
                        for item in actual["shadow"] for limit in item["resolution_request"]["provider_request"]["safety_envelope"]["ordered_actuator_limits"]))
                    if step == 31:
                        for mode in c["shadow_operation_modes"]:
                            state = controller.memories[mode]["opaque_state"]
                            self.assertEqual(state["last_step"],31)
                            self.assertEqual(state["rollbacks"],1)
                            self.assertEqual(state["counts"],[0]*9)
                    if step == 32:
                        for mode in c["shadow_operation_modes"]:
                            self.assertEqual(controller.memories[mode]["reset_epoch"],1)
                            self.assertEqual(controller.memories[mode]["sequence"],0)
                            self.assertEqual(controller.memories[mode]["opaque_state"],{})
                    retained.append(actual)
            self.assertEqual(controller.memories["frozen"]["sequence"],62)
            self.assertEqual(controller.memories["episodic"]["sequence"],29)
            self.assertEqual(controller.memories["episodic"]["opaque_state"]["last_step"],61)
            self.assertEqual(before,self.f.model.document())
            with (self.f.root/"retained-input-host-replay.jsonl").open("x",encoding="utf-8",newline="\n") as stream:
                for row in retained:stream.write(json.dumps(row,allow_nan=False)+"\n")
        finally:
            controller.close();baseline.close()

    def test_provider_error_is_retained_without_changing_native_commands(self):
        controller = host.ShadowController(self.f.core,self.f.compiled,self.f.c,self.f.model)
        original = host.learner.respond
        def fail_one(core,request,model,mode,operation):
            if mode == "frozen":raise RuntimeError("declared component provider error")
            return original(core,request,model,mode,operation)
        try:
            with patch.object(host.learner,"respond",side_effect=fail_one):
                row = controller.step([self.observations(0)])[0]
            frozen = row["shadow"][0]
            self.assertEqual(frozen["provider_error"]["type"],"RuntimeError")
            self.assertEqual(frozen["resolution"]["fallback_reason"],"provider_absent")
            self.assertFalse(row["resolution"]["adaptation_applied"])
            self.assertEqual(controller.memories["frozen"]["sequence"],0)
            self.assertTrue(all(item["provider_error"] is None for item in row["shadow"][1:]))
            self.assertEqual(row["native_targets"],[r["host_target_velocity_rad_s"] for r in row["composition"]["host_mapping"]["ordered_commands"]])
        finally:controller.close()

    def test_invalid_host_transaction_closes_session_and_cannot_resume(self):
        controller = host.ShadowController(self.f.core,self.f.compiled,self.f.c,self.f.model)
        with patch.object(host,"shadow_round",side_effect=ValueError("injected host failure")):
            with self.assertRaisesRegex(ValueError,"injected host failure"):
                controller.step([self.observations(0)])
        self.assertTrue(controller.closed)
        with self.assertRaisesRegex(ValueError,"lifecycle"):
            controller.step([self.observations(1)])
        controller.close()


if __name__ == "__main__":unittest.main()
