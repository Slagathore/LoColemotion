from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "sdk/python"))

from sporespore_recovery_stance import (  # noqa: E402
    REQUEST_SCHEMA,
    STANCE_CONTROLLER_ID,
    RecoveryStanceControlError,
    plan_recovery_stance_control_v1,
)


ACTUATOR_IDS = [
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
]
JOINT_IDS = [value.removesuffix("_motor") for value in ACTUATOR_IDS]


class _FakeCore:
    def canonicalize_json(self, value: object) -> dict[str, str]:
        payload = json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
        return {"sha256": f"sha256:{hashlib.sha256(payload).hexdigest()}"}

    def recovery_collect_native_v3(self, request: object) -> dict[str, object]:
        assert isinstance(request, dict)
        observation = request["observation"]
        return {
            "support_status": "supported_exact",
            "supplied_native_post_step_observation_validated": True,
            "observation_sha256": self.canonicalize_json(observation)["sha256"],
        }

    def recovery_development_profile_v1(self) -> dict[str, object]:
        return {
            "schema_version": "sporespore_recovery_development_profile_v1",
            "profile_id": "sporespore_qsdk_r24d17_exact_s169_recovery_development_v1",
            "actuator_profile_id": (
                "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
            ),
            "actuator_profile_sha256": f"sha256:{'a' * 64}",
            "stance_pose": {
                "pose_id": "exact_s169_zero_joint_stance_pose_v1",
                "ordered_actuator_ids": ACTUATOR_IDS,
                "ordered_joint_ids": JOINT_IDS,
                "ordered_target_positions_rad": [0.0] * 8,
                "maximum_target_speed_rad_s": 0.75,
            },
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }

    def resolve_actuator_cap_profile_v1(
        self,
        profile_id: str,
        descriptor: object,
    ) -> dict[str, object]:
        assert profile_id.endswith("selected_s169_actuator_cap_profile_v1")
        assert descriptor == {"morphology_id": "qsdk_r05_generated_s169"}
        return {
            "support_status": "supported_exact",
            "profile_sha256": f"sha256:{'a' * 64}",
            "profile": {
                "ordered_caps": [
                    {
                        "actuator_id": actuator_id,
                        "joint_id": joint_id,
                        "maximum_outer_step_impulse_nms": 0.05 + index * 0.001,
                    }
                    for index, (actuator_id, joint_id) in enumerate(
                        zip(ACTUATOR_IDS, JOINT_IDS, strict=True)
                    )
                ]
            },
        }


def _request(
    core: _FakeCore,
    *,
    prior_phase: str = "raise_body",
    next_phase: str = "stance_handoff",
    transitioned: bool = True,
) -> dict[str, object]:
    collection = {
        "schema_version": "sporespore_recovery_native_collection_request_v3",
        "arm_kind": "candidate_command",
        "phase": prior_phase,
        "descriptor": {"morphology_id": "qsdk_r05_generated_s169"},
        "observation": {"semantic_step": 306, "fixture": "zero_world"},
    }
    observation_sha256 = core.canonicalize_json(collection["observation"])["sha256"]
    return {
        "schema_version": REQUEST_SCHEMA,
        "controller_id": STANCE_CONTROLLER_ID,
        "collection": collection,
        "handoff_or_stance_step": {
            "schema_version": "sporespore_recovery_step_receipt_v1",
            "support_status": "supported_exact",
            "refusal_reason": None,
            "observation_sha256": observation_sha256,
            "prior_phase": prior_phase,
            "next_phase": next_phase,
            "transitioned": transitioned,
            "classification": {
                "raised_body_gate": True,
                "safety_gate": True,
                "exclusive_stance_handoff_gate": prior_phase == "stance_handoff",
            },
            "memory": {
                "phase": next_phase,
                "phase_steps_observed": 0 if transitioned else 7,
                "terminal_failure_code": None,
            },
            "post_step_observation_only": True,
        },
    }


class RecoveryStanceControlTests(unittest.TestCase):
    def setUp(self) -> None:
        self.core = _FakeCore()

    def test_handoff_emits_exact_exclusive_stance_command(self) -> None:
        receipt = plan_recovery_stance_control_v1(
            self.core,
            _request(self.core),
        )
        self.assertEqual(receipt["support_status"], "supported_exact")
        self.assertEqual(receipt["controller_id"], STANCE_CONTROLLER_ID)
        self.assertEqual(receipt["phase"], "stance_handoff")
        self.assertEqual(receipt["owner"], "stance")
        self.assertFalse(receipt["recovery_controller_active"])
        self.assertTrue(receipt["stance_handoff_requested"])
        self.assertFalse(receipt["no_actuation_requested"])
        self.assertEqual(receipt["engine_identity_input_count"], 0)
        self.assertEqual(receipt["engine_specific_policy_branch_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        commands = receipt["ordered_commands"]
        self.assertEqual(len(commands), 8)
        self.assertEqual([item["actuator_id"] for item in commands], ACTUATOR_IDS)
        self.assertEqual([item["joint_id"] for item in commands], JOINT_IDS)
        self.assertEqual([item["target_position_rad"] for item in commands], [0.0] * 8)
        self.assertEqual(
            [item["maximum_target_speed_rad_s"] for item in commands],
            [0.75] * 8,
        )

    def test_stance_dwell_continuation_keeps_exclusive_owner(self) -> None:
        receipt = plan_recovery_stance_control_v1(
            self.core,
            _request(
                self.core,
                prior_phase="stance_dwell",
                next_phase="stance_dwell",
                transitioned=False,
            ),
        )
        self.assertEqual(receipt["phase"], "stance_dwell")
        self.assertEqual(receipt["phase_step"], 7)
        self.assertFalse(receipt["stance_handoff_requested"])
        self.assertEqual(receipt["owner"], "stance")

    def test_invalid_handoff_and_ownership_mutations_fail_closed(self) -> None:
        mutations = []

        extra_key = _request(self.core)
        extra_key["unexpected"] = True
        mutations.append((extra_key, "STANCE_REQUEST_KEYS"))

        wrong_controller = _request(self.core)
        wrong_controller["controller_id"] = "wrong"
        mutations.append((wrong_controller, "STANCE_CONTROLLER_ID"))

        matched_zero = _request(self.core)
        matched_zero["collection"]["arm_kind"] = "matched_zero_command"
        mutations.append((matched_zero, "STANCE_CANDIDATE_ARM"))

        wrong_digest = _request(self.core)
        wrong_digest["handoff_or_stance_step"]["observation_sha256"] = (
            f"sha256:{'f' * 64}"
        )
        mutations.append((wrong_digest, "STANCE_STEP_OBSERVATION_BINDING"))

        skipped_phase = _request(self.core)
        skipped_phase["handoff_or_stance_step"]["next_phase"] = "stance_dwell"
        skipped_phase["handoff_or_stance_step"]["memory"]["phase"] = "stance_dwell"
        mutations.append((skipped_phase, "STANCE_STEP_EDGE"))

        missing_handoff_gate = _request(self.core)
        missing_handoff_gate["handoff_or_stance_step"]["classification"][
            "raised_body_gate"
        ] = False
        mutations.append((missing_handoff_gate, "STANCE_HANDOFF_GATES"))

        missing_owner = _request(
            self.core,
            prior_phase="stance_handoff",
            next_phase="stance_dwell",
            transitioned=True,
        )
        missing_owner["handoff_or_stance_step"]["classification"][
            "exclusive_stance_handoff_gate"
        ] = False
        mutations.append((missing_owner, "STANCE_OWNERSHIP_GATE"))

        terminal_memory = _request(self.core)
        terminal_memory["handoff_or_stance_step"]["memory"]["terminal_failure_code"] = (
            "retained_failure"
        )
        mutations.append((terminal_memory, "STANCE_TERMINAL_MEMORY"))

        for request, code in mutations:
            with self.subTest(code=code):
                with self.assertRaisesRegex(RecoveryStanceControlError, f"^{code}$"):
                    plan_recovery_stance_control_v1(self.core, request)


if __name__ == "__main__":
    unittest.main()
