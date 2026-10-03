"""Replay an exposed refusal and reject corrupted copies; no physical retry."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import development_recovery_refusal as refusal


class StartupRefusal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = ROOT.parent / "SporeSpore_Evidence/development-recovery-smoke-28741bb836464b7194943c960a8f65bb"
        cls.declaration, cls.supervisor, cls.report, cls.core = refusal.reopen(path)
        cls.descriptor = cls.report["passive_entry"]["walking_runtime_preflight"]["configuration"]["base_descriptor"]

    def test_exact_native_refusal_and_independent_unreachable_leg(self):
        result = refusal.reproduce(self.report, self.descriptor, self.core)
        self.assertEqual("FRAME_INVALID:anchored_body_pose_unreachable_endpoint", result["reported_controller_error"])
        self.assertEqual(8, result["zero_motor_commands"])
        legs = result["startup_reach_bounds"]
        self.assertEqual(["rear_right"], [r["limb_id"] for r in legs if r["impossible_for_every_permitted_body_shift"]])
        self.assertAlmostEqual(.35831501586955056, legs[3]["minimum_required_reach_m"], places=12)
        self.assertEqual(0, result["new_world_count"])
        self.assertFalse(result["original_observation_regraded"])

    def test_corrupt_raw_bytes_or_side_effect_claim_refused(self):
        for field in ("raw", "motor_application_permitted", "adapter_clock_advanced", "adapter_memory_advanced"):
            report = copy.deepcopy(self.report)
            failure = report["detail"]["portable_step_receipt"]["development_native_step_failure"]
            if field == "raw":
                failure["response"]["utf8_text"] += " "
            else:
                failure[field] = True
            with self.assertRaisesRegex(ValueError, "RECOVERY_REFUSAL_(RAW_response|REFUSAL_SIDE_EFFECT)"):
                refusal.reproduce(report, self.descriptor, self.core)

    def test_rehashed_request_cannot_inherit_native_response(self):
        report = copy.deepcopy(self.report)
        failure = report["detail"]["portable_step_receipt"]["development_native_step_failure"]
        request = json.loads(failure["request"]["utf8_text"])
        request["memory"]["anchored_body_pose"]["origin_world_m"]["y"] -= .02
        raw = json.dumps(request, separators=(",", ":")).encode()
        failure["request"].update(utf8_text=raw.decode(), utf8_byte_length=len(raw), raw_sha256=refusal.digest(raw))
        with self.assertRaisesRegex(ValueError, "NATIVE_RESPONSE_CHANGED"):
            refusal.reproduce(report, self.descriptor, self.core)


if __name__ == "__main__":
    unittest.main()
